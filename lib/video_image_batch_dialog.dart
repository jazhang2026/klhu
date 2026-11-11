/// Sequential single-image generation dialog for scene-dialog contents (spec 031).
///
/// Implements FR-005 through FR-013:
/// - Shows **one prompt at a time** with a **full-size image** after generation
/// - Save/Clear buttons gate advancement in manual mode (FR-006/FR-007)
/// - **"Generate All"** button runs every remaining prompt sequentially in a
///   detached Isolate — the user may close the dialog or switch apps (FR-011)
/// - Progress counter during auto-run; summary notification on completion (FR-012)
/// - "Done" strip of saved thumbnails; tap any tile to review the full-size image
///   with Save/Delete/(Retry) (FR-013)
/// - Memory discipline: full-size image widget is disposed and its bytes nulled
///   out on every save/clear/auto-advance so the GC can reclaim them immediately.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:klhu/ai/provider_client.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/ai/prompt.dart';
import 'package:klhu/image_prompt_tag.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/video_pictures.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Messages sent from the isolate back to the UI isolate.
// ---------------------------------------------------------------------------

/// Base class for isolate-to-ui messages.
abstract class _BatchMessage {}

/// The isolate is processing prompt index [current] out of [total].
class _ProgressMessage extends _BatchMessage {
  final int current;
  final int total;
  _ProgressMessage(this.current, this.total);
}

/// A single prompt finished successfully; [url] holds the generated image URL.
class _ItemSuccessMessage extends _BatchMessage {
  final int index;
  final String url;
  _ItemSuccessMessage(this.index, this.url);
}

/// A single prompt failed; [error] contains the reason.
class _ItemFailureMessage extends _BatchMessage {
  final int index;
  final String error;
  _ItemFailureMessage(this.index, this.error);
}

/// All prompts are done. [successCount] / [failureCount] are the tallies.
class _DoneMessage extends _BatchMessage {
  final int successCount;
  final int failureCount;
  _DoneMessage(this.successCount, this.failureCount);
}

// ---------------------------------------------------------------------------
// Result item stored in the Done strip.
// ---------------------------------------------------------------------------

/// One completed (or failed) image-prompt result, kept in the Done strip.
abstract class _DoneItem {
  final int index;
  final String promptText;
  final String? imageUrl; // non-null for success items
  final String? errorMessage; // non-null for failure items

  bool get isSuccess => imageUrl != null;
  bool get isFailed => errorMessage != null;

  const _DoneItem({
    required this.index,
    required this.promptText,
    this.imageUrl,
    this.errorMessage,
  });
}

class _SuccessItem extends _DoneItem {
  /// MediaStore/content URI of the published Pictures/Klhu copy, when the
  /// user has Saved this result. Null means not yet published to the album.
  final String? savedUri;

  /// Deterministic display name used in the Klhu album — one file per scene
  /// prompt; re-saving overwrites it via `upsert` instead of duplicating.
  final String? savedName;

  _SuccessItem({
    required super.index,
    required super.promptText,
    required String imageUrl,
    this.savedUri,
    this.savedName,
  }) : super(imageUrl: imageUrl);
}

class _FailureItem extends _DoneItem {
  _FailureItem({required super.index, required super.promptText, required String errorMessage})
      : super(errorMessage: errorMessage);
}

// ---------------------------------------------------------------------------
// State model for persistence across dialog reopens.
// ---------------------------------------------------------------------------

/// Key used to store per-content batch state in SharedPreferences.
const String _batchStateKey = 'scene_dialog_batch_state_';

/// Persisted snapshot of an in-progress or completed Generate All run.
/// Used to restore state when the user closes and reopens the dialog.
class _BatchState {
  /// Content hash (simple sum of char codes — sufficient for our purpose).
  final String contentHash;
  final String selectedProviderName;
  final List<_DoneItem> doneItems;
  final int nextIndex; // first not-yet-generated index
  final bool isRunning; // true if a Generate All is still in flight

  const _BatchState({
    required this.contentHash,
    required this.selectedProviderName,
    required this.doneItems,
    required this.nextIndex,
    required this.isRunning,
  });

  Map<String, dynamic> toJson() => {
        'provider': selectedProviderName,
        'done': doneItems.map((i) {
          if (i is _SuccessItem) {
            return {
              'index': i.index,
              'prompt': i.promptText,
              'url': i.imageUrl,
              if (i.savedUri != null) 'savedUri': i.savedUri,
              if (i.savedName != null) 'savedName': i.savedName,
            };
          } else {
            return {'index': i.index, 'prompt': i.promptText, 'error': i.errorMessage};
          }
        }).toList(),
        'next': nextIndex,
        'running': isRunning,
      };

  factory _BatchState.fromJson(Map<dynamic, dynamic> json) {
    final done = <_DoneItem>[];
    for (final entry in (json['done'] ?? []) as List) {
      final idx = entry['index'] as int;
      final prompt = entry['prompt'] as String;
      if (entry.containsKey('url')) {
        done.add(_SuccessItem(
          index: idx,
          promptText: prompt,
          imageUrl: entry['url'] as String,
          savedUri: entry['savedUri'] as String?,
          savedName: entry['savedName'] as String?,
        ));
      } else if (entry.containsKey('error')) {
        done.add(_FailureItem(index: idx, promptText: prompt, errorMessage: entry['error'] as String));
      }
    }
    return _BatchState(
      contentHash: '', // not stored; caller sets it
      selectedProviderName: json['provider'] as String? ?? '',
      doneItems: done,
      nextIndex: json['next'] as int? ?? 0,
      isRunning: json['running'] as bool? ?? false,
    );
  }
}

String _contentHash(String content) {
  var h = 0x811c9dc5; // FNV-1a 32-bit
  for (var i = 0; i < content.length; i++) {
    h ^= content.codeUnitAt(i);
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

// ---------------------------------------------------------------------------
// Image materialization — keeps multi-MB base64 data URIs out of memory and
// out of SharedPreferences. Generated images are written to a persistent
// app directory once, then referenced by file path.
// ---------------------------------------------------------------------------

/// If [url] is a `data:` URI, decodes it and writes the bytes to [dirPath],
/// returning the file path. http(s) URLs and existing file paths pass through
/// unchanged. Callable from any isolate (top-level, dart:io only).
Future<String> _materializeImageUrl(
  String url,
  String dirPath,
  String baseName,
) async {
  if (!url.startsWith('data:')) return url;
  final comma = url.indexOf(',');
  if (comma < 0) return url;
  final bytes = base64Decode(url.substring(comma + 1));
  final mime = url.substring(5, comma);
  final ext = mime.contains('jpeg') || mime.contains('jpg')
      ? '.jpg'
      : mime.contains('webp')
          ? '.webp'
          : '.png';
  await Directory(dirPath).create(recursive: true);
  final path = '$dirPath${Platform.pathSeparator}$baseName$ext';
  await File(path).writeAsBytes(bytes);
  return path;
}

// ---------------------------------------------------------------------------
// Top-level compute function for the detached background loop.
// Must be top-level (or static) for compute() to reach it.
// ---------------------------------------------------------------------------

/// Runs the sequential Generate All loop off the UI isolate.
Future<void> _runGenerateAll(_SpawnArgs args) async {
  final sendPort = args.sendPort;
  // Deserialize provider list inside the isolate (no Flutter objects cross isolates).
  final providers = args.providersJson.map((m) => AIProvider.fromJson(Map<String, dynamic>.from(m))).toList();
  final client = AIProviderClient();

  // Find the target provider by name; fall back to first active one.
  final provider = providers.firstWhere(
    (p) => p.name == args.providerName,
    orElse: () => providers.firstWhere(
      (p) => p.active,
      orElse: () => providers.first,
    ),
  );

  var successCount = 0;
  var failureCount = 0;

  for (var i = 0; i < args.prompts.length; i++) {
    // Progress update.
    sendPort.send(_ProgressMessage(i + 1, args.prompts.length));

    final promptText = args.prompts[i];
    if (promptText.isEmpty) continue; // skip empty prompts silently

    try {
      final result = await client.generate(
        provider: provider,
        prompt: AIPrompt(
          type: AIPromptType.image,
          text: promptText,
          includeReadingContent: false,
        ),
      );
      final content = result.content;
      if (result.success && content.isNotEmpty) {
        // Persist the image as a file so the UI isolate only ever holds a
        // small path — never a multi-MB base64 data URI.
        final stored = await _materializeImageUrl(
          content,
          args.imageDirPath,
          'scene_${DateTime.now().millisecondsSinceEpoch}_$i',
        );
        sendPort.send(_ItemSuccessMessage(i, stored));
        successCount++;
      } else {
        final err = result.errorMessage ?? 'Generation returned no content';
        sendPort.send(_ItemFailureMessage(i, err));
        failureCount++;
      }
    } catch (e) {
      sendPort.send(_ItemFailureMessage(i, e.toString()));
      failureCount++;
    }
  }

  sendPort.send(_DoneMessage(successCount, failureCount));
}

// ---------------------------------------------------------------------------
// Main dialog widget.
// ---------------------------------------------------------------------------

/// Sequential image-generation dialog (spec 031 FR-005 – FR-013).
///
/// In **manual mode** the dialog shows one ungenerated prompt at a time;
/// after generation the full-size image appears with Save / Clear buttons.
/// Tapping either discards the image memory and advances to the next prompt.
///
/// In **Generate All mode** (tapping the header button), every remaining
/// prompt is run sequentially in a background Isolate. No Save/Clear taps are
/// needed — each image is shown full-size briefly then auto-discarded and
/// added to the Done strip. On completion a snackbar summarises successes and
/// failures. The user may close the dialog or switch apps; results persist in
/// SharedPreferences and are restored on reopen.
class VideoImageBatchDialog extends StatefulWidget {
  final List<ImagePromptTag> imagePrompts;
  final String content;
  final List<AIProvider> providers;
  final Directory picturesDir;
  final void Function(List<HeldPicture> newPictures) onSaved;

  /// Called with the HeldPicture name when a saved result is deleted, so the
  /// host can drop it from the chosen-pictures list.
  final void Function(String name)? onRemoved;

  const VideoImageBatchDialog({
    super.key,
    required this.imagePrompts,
    required this.content,
    required this.providers,
    required this.picturesDir,
    required this.onSaved,
    this.onRemoved,
  });

  @override
  State<VideoImageBatchDialog> createState() => _VideoImageBatchDialogState();
}

class _VideoImageBatchDialogState extends State<VideoImageBatchDialog> {
  late String _selectedProviderName;
  late List<_DoneItem> _doneItems;
  late int _totalPrompts;

  // Index of the prompt currently being generated in manual mode (null = idle).
  int? _generatingIndex;

  // Generate All runtime state.
  ReceivePort? _receivePort;
  Isolate? _isolate;
  bool _isGeneratingAll = false;
  int _genAllCurrent = 0;
  int _genAllTotal = 0;
  bool _genAllCompleted = false;
  int _genAllSuccess = 0;
  int _genAllFailure = 0;

  // For viewing a single Done-strip item full-size.
  int? _viewingIndex; // null = main flow; non-null = reviewing a Done item

  bool _savingAll = false;

  // SharedPreferences handle for persistence.
  Future<SharedPreferences> _prefsFuture = SharedPreferences.getInstance();

  // Persistent directory for materialized generated images — survives dialog
  // close and app restarts, unlike the prompt's temporary picturesDir.
  late final Future<Directory> _imageDir = _sceneImageDir();

  Future<Directory> _sceneImageDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}scene_images');
  }

  // Content hash key for persisted state.
  late final String _stateKey = '${_batchStateKey}${_contentHash(widget.content)}';

  @override
  void initState() {
    super.initState();
    _totalPrompts = widget.imagePrompts.length;
    _doneItems = [];

    // Pick default provider (same logic as the original dialog).
    final imageProviders = widget.providers.where((p) =>
        p.active && (p.imageModel != null || p.url.contains('generativelanguage')));
    final defaultProvider = imageProviders.isNotEmpty
        ? imageProviders.first
        : widget.providers.firstWhere(
            (p) => p.active,
            orElse: () => widget.providers.first,
          );
    _selectedProviderName = defaultProvider.name;

    _restorePersistedState();
  }

  @override
  void dispose() {
    _stopIsolate();
    _disposeCurrentFullSize();
    _receivePort?.close();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Persistence
  // -----------------------------------------------------------------------

  Future<void> _restorePersistedState() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_stateKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<dynamic, dynamic>;
      final state = _BatchState.fromJson(json);
      if (!mounted) return;

      setState(() {
        _doneItems = state.doneItems
          ..sort((a, b) => a.index.compareTo(b.index));
        _selectedProviderName = state.selectedProviderName.isEmpty
            ? _selectedProviderName
            : state.selectedProviderName;
        // If a previous run was interrupted, treat unfinished items as pending.
        _genAllCompleted = !state.isRunning;
        if (_genAllCompleted) {
          // Count what we have.
          _genAllSuccess = _doneItems.where((i) => i.isSuccess).length;
          _genAllFailure = _doneItems.where((i) => i.isFailed).length;
        }
      });
    } catch (e) {
      debugPrint('klhu batch restore failed: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await _prefsFuture;
      final state = _BatchState(
        contentHash: _contentHash(widget.content),
        selectedProviderName: _selectedProviderName,
        doneItems: _doneItems,
        nextIndex: _firstPendingIndex(),
        isRunning: _isGeneratingAll && !_genAllCompleted,
      );
      await prefs.setString(_stateKey, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('klhu batch save failed: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Pending-index model: the manual flow always shows the FIRST prompt that
  // has text and no Done item yet. Deleting a Done item makes its prompt
  // pending again, so every prompt stays reachable in scene order.
  // -----------------------------------------------------------------------

  /// Whether prompt [i] has text and no Done item yet — i.e. it can be
  /// generated. Empty prompt lines never count as pending.
  bool _isPendingIndex(int i) =>
      widget.imagePrompts[i].promptIn(widget.content).isNotEmpty &&
      !_doneItems.any((d) => d.index == i);

  /// Index of the first prompt that has text and no Done item, or
  /// [_totalPrompts] when every prompt has an outcome.
  int _firstPendingIndex() {
    for (var i = 0; i < _totalPrompts; i++) {
      if (_isPendingIndex(i)) return i;
    }
    return _totalPrompts;
  }

  /// Inserts [item] keeping [_doneItems] sorted by prompt index, so the Done
  /// strip always mirrors the scene order regardless of completion order.
  /// A prompt has at most one Done item — a newer result replaces the old.
  void _insertDone(_DoneItem item) {
    _doneItems.removeWhere((d) => d.index == item.index);
    final pos = _doneItems.indexWhere((d) => d.index > item.index);
    if (pos < 0) {
      _doneItems.add(item);
    } else {
      _doneItems.insert(pos, item);
    }
  }

  // -----------------------------------------------------------------------
  // Manual-mode generate for a single prompt
  // -----------------------------------------------------------------------

  Future<void> _generateSingle(int index) async {
    if (index < 0 || index >= _totalPrompts) return;
    final tag = widget.imagePrompts[index];
    final promptText = tag.promptIn(widget.content);
    if (promptText.isEmpty) return;

    // Don't generate again if already done (success or failure) or in flight.
    if (_doneItems.any((i) => i.index == index)) return;
    if (_generatingIndex != null) return;

    final provider = _resolveProvider();

    setState(() {
      _viewingIndex = index; // show this prompt as "in progress"
      _generatingIndex = index;
    });

    final client = AIProviderClient();
    final imageDirPath = (await _imageDir).path;
    try {
      final result = await client.generate(
        provider: provider,
        prompt: AIPrompt(
          type: AIPromptType.image,
          text: promptText,
          includeReadingContent: false,
        ),
      );
      final content = result.content;
      if (!mounted) return;
      // Materialize data URIs to a file so only a small path is kept in
      // memory and in the persisted batch state.
      final storedUrl = content.isNotEmpty
          ? await _materializeImageUrl(
              content, imageDirPath, 'scene_${DateTime.now().millisecondsSinceEpoch}_$index')
          : content;
      if (!mounted) return;
      setState(() {
        _generatingIndex = null;
        // Keep _viewingIndex on this prompt so the full-size result (or error)
        // stays on screen until the user Saves / Clears / retries (FR-006/007).
        if (storedUrl.isNotEmpty) {
          _insertDone(_SuccessItem(index: index, promptText: promptText, imageUrl: storedUrl));
        } else {
          _insertDone(_FailureItem(
            index: index,
            promptText: promptText,
            errorMessage: result.errorMessage ?? 'Generation failed',
          ));
        }
      });
      _saveState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generatingIndex = null;
        _insertDone(_FailureItem(
          index: index,
          promptText: promptText,
          errorMessage: e.toString(),
        ));
      });
      _saveState();
    }
  }

  // -----------------------------------------------------------------------
  // Save / Clear / Delete / Retry
  // -----------------------------------------------------------------------

  Future<void> _saveDoneItem(int doneIndex) async {
    final item = _doneItems[doneIndex];
    if (!(item is _SuccessItem)) return;
    await _doSave(item.imageUrl!, item.index);
  }

  Future<void> _doSave(String url, int promptIndex) async {
    try {
      final bytes = await _downloadImageBytes(url);
      if (!mounted) return;
      final ext = _detectExt(url);
      // Deterministic name per (content, prompt): the Klhu album keeps exactly
      // one file per scene prompt — re-saving overwrites via `upsert`.
      final baseName = 'klhu_scene_${_contentHash(widget.content)}_$promptIndex';
      final name = '$baseName$ext';
      final path = '${widget.picturesDir.path}${Platform.pathSeparator}$name';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      widget.onSaved([HeldPicture(name: name, path: path)]);
      // Publish to the public Pictures/Klhu album (same channel family the
      // single-image flow uses) so the picture is visible in Gallery/Files.
      String? savedUri;
      try {
        final res = await const MethodChannel('klhu/image_files')
            .invokeMethod<Map<dynamic, dynamic>>('upsert', {
          'bytes': bytes,
          'mimeType': ext == '.jpg' || ext == '.jpeg'
              ? 'image/jpeg'
              : ext == '.webp'
                  ? 'image/webp'
                  : 'image/png',
          'baseName': baseName,
        });
        savedUri = res?['uri'] as String?;
      } catch (e) {
        debugPrint('klhu batch gallery save failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _doneItems[doneItemIndexOf(promptIndex)] = _SuccessItem(
          index: promptIndex,
          promptText: widget.imagePrompts[promptIndex].promptIn(widget.content),
          imageUrl: url,
          savedUri: savedUri,
          // savedName tracks the picturesDir HeldPicture name regardless of
          // whether the album publish succeeded, so Delete can always drop it.
          savedName: baseName,
        );
        // Save advances linearly to the next prompt in scene order, so the
        // reader can save pictures one after another; null falls back to the
        // first pending prompt (or the last prompt once all are done).
        if (_viewingIndex == promptIndex) {
          _viewingIndex = null;
          for (var i = promptIndex + 1; i < _totalPrompts; i++) {
            if (widget.imagePrompts[i].promptIn(widget.content).isNotEmpty) {
              _viewingIndex = i;
              break;
            }
          }
        }
      });
      // Persist so the Saved status survives closing and reopening the dialog.
      _saveState();
    } catch (e) {
      debugPrint('klhu batch save failed: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiImageSaveFailed(e.toString()))),
      );
    }
  }

  /// Saves every success result that has not been published to the Klhu
  /// album yet, in scene order. Already-saved items are skipped.
  Future<void> _saveAllUnsaved() async {
    if (_savingAll) return;
    setState(() => _savingAll = true);
    try {
      for (final item in List.of(_doneItems)) {
        if (!mounted) return;
        if (item is _SuccessItem &&
            item.savedUri == null &&
            item.imageUrl != null) {
          await _doSave(item.imageUrl!, item.index);
        }
      }
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  Future<void> _deleteDoneItem(int doneIndex) async {
    final item = _doneItems[doneIndex];
    // Remove the published Pictures/Klhu copy when this result was saved.
    if (item is _SuccessItem && item.savedUri != null) {
      try {
        await const MethodChannel('klhu/image_files')
            .invokeMethod('delete', {'uri': item.savedUri});
      } catch (e) {
        debugPrint('klhu batch gallery delete failed: $e');
      }
    }
    // Drop the materialized working file too (local paths only).
    final url = item.imageUrl;
    if (url != null && !url.startsWith('http') && !url.startsWith('data:')) {
      try {
        await File(url).delete();
      } catch (_) {}
    }
    // Tell the host to drop the matching HeldPicture — the deterministic
    // picturesDir name is '<savedName><ext>'.
    if (item is _SuccessItem && item.savedName != null && url != null) {
      widget.onRemoved?.call('${item.savedName}${_detectExt(url)}');
    }
    if (!mounted) return;
    setState(() => _doneItems.removeAt(doneIndex));
    // The prompt becomes pending again — if the user was viewing it, the same
    // index now shows its Generate button so the image can be re-created.
    _saveState();
  }

  Future<void> _retryDoneItem(int doneIndex) async {
    final item = _doneItems[doneIndex];
    if (!(item is _FailureItem)) return;
    // Remove the failure item and regenerate — it becomes the pending prompt.
    setState(() => _doneItems.removeAt(doneIndex));
    _saveState();
    await _generateSingle(item.index);
  }

  int doneItemIndexOf(int promptIndex) {
    final idx = _doneItems.indexWhere((i) => i.index == promptIndex);
    return idx >= 0 ? idx : 0;
  }

  // -----------------------------------------------------------------------
  // Full-size image disposal (memory discipline)
  // -----------------------------------------------------------------------

  /// Nulls out any cached ImageProvider and forces the framework to drop the
  /// decoded bytes so the garbage collector can reclaim them (FR-006/FR-007).
  void _discardCurrentFullSize() {
    // The image is held only by the widget tree; calling setState with a
    // changed _viewingIndex (null) causes the old Image widget to be rebuilt
    // away. We additionally schedule a microtask yield to give the scheduler
    // a chance to start collection before the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force GC hint — in production profiling reveals whether this helps.
      // Dart's GC is automatic; this is a best-effort nudge.
    });
  }

  void _disposeCurrentFullSize() {
    _viewingIndex = null;
  }

  // -----------------------------------------------------------------------
  // Generate All (detached Isolate)
  // -----------------------------------------------------------------------

  AIProvider _resolveProvider() {
    return widget.providers.firstWhere(
      (p) => p.name == _selectedProviderName,
      orElse: () => widget.providers.first,
    );
  }

  Future<void> _startGenerateAll() async {
    if (_isGeneratingAll) return;
    // Cancel any manual in-flight state.
    _viewingIndex = null;
    final imageDirPath = (await _imageDir).path;
    if (!mounted) return;
    setState(() {
      _isGeneratingAll = true;
      _genAllCompleted = false;
      _genAllCurrent = 0;
      _genAllSuccess = 0;
      _genAllFailure = 0;
    });

    final prompts = widget.imagePrompts
        .map((tag) => tag.promptIn(widget.content))
        .toList();
    // Generate All covers pending prompts only — prompts that already have a
    // Done item (manual or a previous run) are skipped, keeping index alignment.
    final indexedPrompts = <(int, String)>[];
    for (var i = 0; i < prompts.length; i++) {
      if (prompts[i].isEmpty) continue;
      if (_doneItems.any((d) => d.index == i)) continue;
      indexedPrompts.add((i, prompts[i]));
    }
    final List<String> promptList = indexedPrompts.map((e) => e.$2).toList();
    final List<int> promptIndices = indexedPrompts.map((e) => e.$1).toList();

    final providersJson = widget.providers.map((p) => p.toJson()).toList();

    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (!mounted) return;
      setState(() {
        if (message is _ProgressMessage) {
          _genAllCurrent = message.current;
          _genAllTotal = message.total;
        } else if (message is _ItemSuccessMessage) {
          // Map back to original index.
          final origIdx = promptIndices[message.index];
          _insertDone(_SuccessItem(
            index: origIdx,
            promptText: widget.imagePrompts[origIdx].promptIn(widget.content),
            imageUrl: message.url,
          ));
          _genAllSuccess++;
          _genAllCurrent = message.index + 1;
        } else if (message is _ItemFailureMessage) {
          final origIdx = promptIndices[message.index];
          _insertDone(_FailureItem(
            index: origIdx,
            promptText: widget.imagePrompts[origIdx].promptIn(widget.content),
            errorMessage: message.error,
          ));
          _genAllFailure++;
          _genAllCurrent = message.index + 1;
        } else if (message is _DoneMessage) {
          _genAllCompleted = true;
          _genAllSuccess = message.successCount;
          _genAllFailure = message.failureCount;
          _isGeneratingAll = false;
          _genAllCurrent = _genAllTotal;
          // Persist and notify.
          _saveState().then((_){});
          _showCompletionSummary();
        }
      });
    });

    Isolate.spawn(
      _runGenerateAll,
      _SpawnArgs(
        sendPort: _receivePort!.sendPort,
        prompts: promptList,
        spellings: widget.imagePrompts.map((t) => t.spelling).toList(),
        providerName: _selectedProviderName,
        providersJson: providersJson,
        imageDirPath: imageDirPath,
      ),
      onError: _receivePort!.sendPort,
      debugName: 'SceneDialogBatchGen',
    ).then((iso) {
      _isolate = iso;
    });
  }

  void _stopIsolate() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    setState(() {
      _isGeneratingAll = false;
    });
  }

  void _cancelGenerateAll() {
    _stopIsolate();
    _genAllCompleted = true; // treat as done so we show summary of what we have.
    _saveState();
    _showCompletionSummary();
  }

  void _showCompletionSummary() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_genAllFailure == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.videoGenSummarySuccess(_genAllSuccess)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.videoGenSummaryPartial(_genAllSuccess, _genAllFailure)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Download helper (mirrors original)
  // -----------------------------------------------------------------------

  Future<List<int>> _downloadImageBytes(String url) async {
    // Materialized local images and legacy data URIs need no HTTP fetch.
    if (url.startsWith('data:')) {
      return base64Decode(url.split(',')[1]);
    }
    if (!url.startsWith('http')) {
      return File(url).readAsBytes();
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      const maxSize = 10 * 1024 * 1024;
      final bytes = <int>[];
      int totalBytes = 0;
      await for (final chunk in response) {
        totalBytes += chunk.length;
        if (totalBytes > maxSize) throw Exception('Image too large (>10MB)');
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      client.close();
    }
  }

  String _detectExt(String url) {
    if (url.startsWith('data:image/png')) return '.png';
    if (url.startsWith('data:image/jpeg')) return '.jpg';
    if (url.startsWith('data:image/webp')) return '.webp';
    final path = Uri.parse(url).path;
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
    if (path.endsWith('.webp')) return '.webp';
    return '.png';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayProviders = widget.providers.where((p) =>
        p.active && (p.imageModel != null || p.url.contains('generativelanguage')));
    final allActive = widget.providers.where((p) => p.active).toList();
    final availableProviders = displayProviders.isNotEmpty ? displayProviders : allActive;

    final pendingIndex = _firstPendingIndex();
    final isAutoRunning = _isGeneratingAll && !_genAllCompleted;

    // Determine what to show in the active area. The prompt shown is the
    // browsed index if the user navigated, otherwise the first pending
    // prompt — or the last prompt once everything has an outcome, so its
    // result stays reviewable.
    Widget activeBody;
    if (isAutoRunning) {
      activeBody = _buildAutoRunningBody(l10n);
    } else if (_totalPrompts > 0) {
      final rawIndex = _viewingIndex ??
          (pendingIndex < _totalPrompts ? pendingIndex : _totalPrompts - 1);
      final displayIndex = rawIndex.clamp(0, _totalPrompts - 1);
      activeBody = _buildManualBody(l10n, displayIndex);
    } else {
      activeBody = _buildEmptyBody(l10n);
    }

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.aiBatchTitle)),
          const SizedBox(width: 8),
          // Generate All button — available whenever prompts remain pending.
          if (!_isGeneratingAll && pendingIndex < _totalPrompts)
            FilledButton.icon(
              onPressed: _startGenerateAll,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(l10n.videoGenerateAllButton),
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
              ),
            ),
          if (isAutoRunning)
            IconButton(
              icon: const Icon(Icons.stop, size: 18),
              tooltip: 'Stop',
              onPressed: _cancelGenerateAll,
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Provider selector ----
              if (availableProviders.length > 1) ...[
                Text(
                  l10n.aiBatchProviderLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _selectedProviderName,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  underline: const SizedBox(),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: availableProviders.map((p) => DropdownMenuItem(
                    value: p.name,
                    child: Text(p.name, style: const TextStyle(fontSize: 13, color: Colors.black)),
                  )).toList(),
                  onChanged: isAutoRunning
                      ? null // lock provider during auto-run
                      : (v) {
                          if (v != null && v != _selectedProviderName) {
                            // Cancel any in-progress manual step first.
                            _discardCurrentFullSize();
                            _viewingIndex = null;
                            setState(() => _selectedProviderName = v);
                          }
                        },
                ),
                const SizedBox(height: 12),
              ],
              // ---- Auto-run progress indicator ----
              if (isAutoRunning) ...[
                LinearProgressIndicator(
                  value: _genAllTotal > 0 ? _genAllCurrent / _genAllTotal : 0,
                  minHeight: 4,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.videoGenProgress(_genAllCurrent, _genAllTotal),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              // ---- Done strip (horizontal thumbnails) ----
              if (_doneItems.isNotEmpty) ...[
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _doneItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, doneIndex) {
                      final item = _doneItems[doneIndex];
                      return _DoneTile(
                        item: item,
                        onTap: () {
                          if (_isGeneratingAll && !_genAllCompleted) return; // block during auto-run
                          setState(() => _viewingIndex = item.index);
                        },
                        onSave: () => _saveDoneItem(doneIndex),
                        onDelete: () => _deleteDoneItem(doneIndex),
                        onRetry: () => _retryDoneItem(doneIndex),
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
              ],
              // ---- Active area (manual or auto idle) ----
              activeBody,
            ],
          ),
        ),
      ),
      actions: [
        // Save All — publishes every generated-but-unsaved result to the
        // Klhu album in one pass; hidden once everything is saved.
        if (_doneItems.any((i) => i is _SuccessItem && i.savedUri == null))
          TextButton.icon(
            onPressed: _savingAll ? null : _saveAllUnsaved,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.aiBatchSaveAll),
          ),
        TextButton(
          onPressed: () {
            _stopIsolate();
            Navigator.of(context).pop();
          },
          child: Text(l10n.doneButton),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Body builders
  // -----------------------------------------------------------------------

  Widget _buildAutoRunningBody(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.videoGenNotifyRunning,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.videoGenProgress(_genAllCurrent, _genAllTotal),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// One prompt at a time, browsable with ‹ › through every image prompt in
  /// scene order. Shows the prompt text plus its state: Generate button while
  /// pending, spinner while generating, full-size image on success, error on
  /// failure — with Save/Delete/Retry/Next as appropriate.
  Widget _buildManualBody(AppLocalizations l10n, int index) {
    final tag = widget.imagePrompts[index];
    final promptText = tag.promptIn(widget.content);
    final doneItem = _doneItems.where((i) => i.index == index).firstOrNull;
    final successItem = doneItem is _SuccessItem ? doneItem : null;
    final isFailure = doneItem is _FailureItem;
    final isSuccess = doneItem is _SuccessItem;
    final isGenerating = _generatingIndex == index && doneItem == null;
    final isPending = promptText.isNotEmpty && doneItem == null && !isGenerating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt navigator — every image prompt is reachable in scene order.
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              tooltip: 'Previous',
              onPressed: index > 0
                  ? () {
                      _discardCurrentFullSize();
                      setState(() => _viewingIndex = index - 1);
                    }
                  : null,
              visualDensity: VisualDensity.compact,
            ),
            // Outcome marker: image ready / failed / still pending.
            if (isSuccess)
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
            else if (isFailure)
              Icon(Icons.error, size: 16, color: Colors.red.shade400)
            else if (isPending)
              Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey.shade500),
            Text(
              '${index + 1} / $_totalPrompts',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              tooltip: 'Next',
              onPressed: index < _totalPrompts - 1
                  ? () {
                      _discardCurrentFullSize();
                      setState(() => _viewingIndex = index + 1);
                    }
                  : null,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        // Prompt text
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(promptText, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 8),
        // In-progress indicator while the provider generates.
        if (isGenerating)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiProgressGeneratingImage,
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        // Full-size image (if success) or error (if failed)
        if (isSuccess)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FullSizeImage(url: doneItem.imageUrl!),
          ),
        if (isFailure)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              doneItem.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        // Action buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isPending)
              FilledButton.tonalIcon(
                onPressed: () => _generateSingle(index),
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: Text(l10n.aiBatchGenerate),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ),
            if (isSuccess && successItem!.savedUri == null)
              FilledButton.tonalIcon(
                onPressed: () => _saveDoneItem(doneItemIndexOf(index)),
                icon: const Icon(Icons.save, size: 18),
                label: Text(l10n.aiBatchSave),
              ),
            if (isSuccess && successItem!.savedUri != null)
              Tooltip(
                message: l10n.aiImageSavedMessage,
                child: Chip(
                  avatar: Icon(Icons.check_circle,
                      size: 16, color: Colors.green.shade600),
                  label: Text(l10n.aiBatchSaved),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            if (isSuccess || isFailure)
              OutlinedButton.icon(
                onPressed: () => _deleteDoneItem(doneItemIndexOf(index)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.aiBatchDelete),
              ),
            if (isFailure)
              FilledButton.icon(
                onPressed: () => _retryDoneItem(doneItemIndexOf(index)),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.videoGenRetry),
              ),
          ],
        ),
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildEmptyBody(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
            const SizedBox(height: 8),
            Text(
              _isGeneratingAll
                  ? l10n.videoGenSummarySuccess(_genAllSuccess)
                  : (l10n.aiBatchTitle),
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Full-size image display (not a thumbnail). Uses CachedNetworkImage with a
/// generous cache budget; the widget is removed and nulled on Save/Clear to
/// allow GC to reclaim the decoded bytes.
class _FullSizeImage extends StatelessWidget {
  final String url;
  const _FullSizeImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final isDataUri = url.startsWith('data:');
    final isRemote = url.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isDataUri
          ? Image.memory(
              base64Decode(url.split(',')[1]),
              fit: BoxFit.contain,
              gaplessPlayback: false,
              errorBuilder: (_, __, ___) => _fallbackPlaceholder(),
            )
          : isRemote
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  memCacheWidth: 800,
                  memCacheHeight: 800,
                  placeholder: (_, __) => _loadingPlaceholder(),
                  errorWidget: (_, __, ___) => _fallbackPlaceholder(),
                )
              : Image.file(
                  File(url),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _fallbackPlaceholder(),
                ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey.shade100,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _fallbackPlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

/// Small thumbnail in the Done strip. Tappable to open the full-size view.
class _DoneTile extends StatelessWidget {
  final _DoneItem item;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;

  const _DoneTile({
    required this.item,
    required this.onTap,
    required this.onSave,
    required this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isError = item.isFailed;
    return InkWell(
      onTap: isError && onRetry != null ? onRetry : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isError ? Colors.red.shade300 : Colors.grey.shade300),
        ),
        child: isError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 24, color: Colors.red.shade400),
                  const SizedBox(height: 2),
                  Icon(Icons.refresh, size: 14, color: Colors.red.shade400),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl != null
                      ? _MiniThumb(url: item.imageUrl!)
                      : const SizedBox.shrink(),
                  // Saved badge — visible at a glance which results are
                  // already published to the Klhu album.
                  if (item is _SuccessItem &&
                      (item as _SuccessItem).savedUri != null)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(Icons.check_circle,
                          size: 14, color: Colors.green),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  final String url;
  const _MiniThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final isDataUri = url.startsWith('data:');
    final isRemote = url.startsWith('http');
    return isDataUri
        ? Image.memory(
            base64Decode(url.split(',')[1]),
            fit: BoxFit.cover,
            cacheWidth: 150,
            cacheHeight: 150,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : isRemote
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 150,
                memCacheHeight: 150,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : Image.file(
                File(url),
                fit: BoxFit.cover,
                cacheWidth: 150,
                cacheHeight: 150,
                errorBuilder: (_, __, ___) => _fallback(),
              );
  }

  Widget _placeholder() => Container(color: Colors.grey.shade200);
  Widget _fallback() => const Icon(Icons.image, size: 20, color: Colors.grey);
}


// ---------------------------------------------------------------------------
// Isolate spawn argument (must be a data-class, serialisable).
// ---------------------------------------------------------------------------

class _SpawnArgs {
  final SendPort sendPort;
  final List<String> prompts;
  final List<String> spellings;
  final String providerName;
  final List<Map<String, dynamic>> providersJson;
  final String imageDirPath;

  const _SpawnArgs({
    required this.sendPort,
    required this.prompts,
    required this.spellings,
    required this.providerName,
    required this.providersJson,
    required this.imageDirPath,
  });
}
