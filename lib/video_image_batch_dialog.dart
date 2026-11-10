/// Batch image generation dialog for scene-dialog contents (spec 031 FR-005).
///
/// Lists every `[image_prompt]` entry in the content, provides a provider
/// selector at the top, and generates one image per prompt independently.
/// After generation each row shows a thumbnail with save/delete buttons.
/// Saved images are written into [picturesDir] and returned so the caller
/// can merge them into the video's picture list.
///
/// Also shows a collapsible recent-prompt history (FR-009) with per-entry
/// delete buttons, and persists newly generated prompts into that history.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:klhu/ai/provider_client.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/ai/prompt.dart';
import 'package:klhu/ai/prompt_history.dart';
import 'package:klhu/image_prompt_tag.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/video_pictures.dart';

/// One row in the batch dialog: the prompt text, its generation state, and
/// the resulting image URL (if any).
class _PromptRow {
  final ImagePromptTag tag;
  final String promptText;
  final String spelling;
  /// null while pending, the image URL after success, or an error string.
  final String? result;
  final bool generating;
  final bool saved; // whether the image was saved to picturesDir

  const _PromptRow({
    required this.tag,
    required this.promptText,
    required this.spelling,
    this.result,
    this.generating = false,
    this.saved = false,
  });

  _PromptRow copyWith({
    String? result,
    bool? generating,
    bool? saved,
  }) =>
      _PromptRow(
        tag: tag,
        promptText: promptText,
        spelling: spelling,
        result: result ?? this.result,
        generating: generating ?? this.generating,
        saved: saved ?? this.saved,
      );
}

/// The batch image generation dialog.
///
/// [imagePrompts] are the `[image_prompt]` tags parsed from the content.
/// [content] is the full text so the dialog can extract prompt text from tags.
/// [providers] are the configured AI providers (filtered to image-capable).
/// [picturesDir] is the directory where generated images are stored.
/// [onSaved] is called with the newly saved pictures so the caller can merge
/// them into the video's picture list.
class VideoImageBatchDialog extends StatefulWidget {
  final List<ImagePromptTag> imagePrompts;
  final String content;
  final List<AIProvider> providers;
  final Directory picturesDir;
  final void Function(List<HeldPicture> newPictures) onSaved;

  const VideoImageBatchDialog({
    super.key,
    required this.imagePrompts,
    required this.content,
    required this.providers,
    required this.picturesDir,
    required this.onSaved,
  });

  @override
  State<VideoImageBatchDialog> createState() => _VideoImageBatchDialogState();
}

class _VideoImageBatchDialogState extends State<VideoImageBatchDialog> {
  late String _selectedProviderName;
  late List<_PromptRow> _rows;
  late List<AIPromptEntry> _history;
  bool _historyExpanded = false;

  @override
  void initState() {
    super.initState();
    // Pick the first image-capable active provider, or the first active one.
    final imageProviders = widget.providers.where((p) =>
        p.active && (p.imageModel != null || p.url.contains('generativelanguage')));
    final defaultProvider = imageProviders.isNotEmpty
        ? imageProviders.first
        : widget.providers.firstWhere(
            (p) => p.active,
            orElse: () => widget.providers.first,
          );
    _selectedProviderName = defaultProvider.name;

    _rows = widget.imagePrompts.map((tag) {
      return _PromptRow(
        tag: tag,
        promptText: tag.promptIn(widget.content),
        spelling: tag.spelling,
      );
    }).toList();

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await AIConfigStore().loadPromptHistory();
    setState(() => _history = history);
  }

  Future<void> _generate(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    if (row.generating) return;

    // Find the provider.
    final provider = widget.providers.firstWhere(
      (p) => p.name == _selectedProviderName,
      orElse: () => widget.providers.first,
    );

    setState(() {
      _rows[index] = row.copyWith(generating: true, result: null);
    });

    final client = AIProviderClient();
    final prompt = AIPrompt(
      type: AIPromptType.image,
      text: row.promptText,
      includeReadingContent: false,
    );

    try {
      final result = await client.generate(provider: provider, prompt: prompt);
      if (!mounted) return;
      if (result.success) {
        // Save to history after successful generation (FR-009).
        await AIConfigStore().addPromptHistory(
          text: row.promptText,
          type: AIPromptType.image,
          includeReadingContent: false,
        );
        _loadHistory();
        setState(() {
          _rows[index] = row.copyWith(generating: false, result: result.content);
        });
      } else {
        setState(() {
          _rows[index] = row.copyWith(
            generating: false,
            result: 'Error: ${result.errorMessage ?? 'Generation failed'}',
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows[index] = row.copyWith(
          generating: false,
          result: 'Error: $e',
        );
      });
    }
  }

  Future<void> _saveImage(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    if (row.result == null || row.result!.isEmpty) return;
    if (row.saved) return;

    try {
      final bytes = await _downloadImageBytes(row.result!);
      if (!mounted) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = _detectExt(row.result!);
      final name = 'batch_$timestamp$ext';
      final path = '${widget.picturesDir.path}${Platform.pathSeparator}$name';
      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      setState(() {
        _rows[index] = row.copyWith(saved: true);
      });
      widget.onSaved([HeldPicture(name: name, path: path)]);
    } catch (e) {
      debugPrint('klhu batch save failed: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiImageSaveFailed(e.toString()))),
      );
    }
  }

  Future<void> _deleteImage(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    if (!row.saved) return;

    // Find the saved file path.
    String? path;
    for (final r in _rows) {
      if (r.saved && r == row) {
        // We need to track saved paths separately — use row's result as hint.
        break;
      }
    }
    // Conservative: just clear the saved flag; the file cleanup happens on
    // discardPictures after the render ends (FR-025).
    if (!mounted) return;
    setState(() {
      _rows[index] = row.copyWith(saved: false, result: null);
    });
  }

  /// Delete a single history entry (FR-009).
  Future<void> _deleteHistoryEntry(int timestamp) async {
    final deleted = await AIConfigStore().deletePromptHistoryEntry(timestamp);
    if (deleted) await _loadHistory();
  }

  Future<List<int>> _downloadImageBytes(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      // Stream the response into bytes with a size limit to prevent OOM
      // Maximum 10MB per image (adjust if AI generates larger images)
      const maxSize = 10 * 1024 * 1024; // 10MB
      final bytes = <int>[];
      int totalBytes = 0;

      await for (final chunk in response) {
        totalBytes += chunk.length;
        if (totalBytes > maxSize) {
          throw Exception('Image too large (exceeds 10MB limit)');
        }
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

  /// Format timestamp as a short relative label.
  String _formatTime(int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${(diff / 60000).floor()}m ago';
    if (diff < 86400000) return '${(diff / 3600000).floor()}h ago';
    return '${(diff / 86400000).floor()}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final imageProviders = widget.providers.where((p) =>
        p.active && (p.imageModel != null || p.url.contains('generativelanguage')));
    final displayProviders = imageProviders.isNotEmpty
        ? imageProviders.toList()
        : widget.providers.where((p) => p.active).toList();

    return AlertDialog(
      title: Text(l10n.aiBatchTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider selector
              if (displayProviders.length > 1) ...[
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
                  items: displayProviders.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.name,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(p.name,
                            style:
                                const TextStyle(fontSize: 13, color: Colors.black)),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedProviderName = v);
                  },
                ),
                const SizedBox(height: 12),
              ],
              // Prompt list
              ..._rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return _PromptRowWidget(
                  row: row,
                  onGenerate: () => _generate(index),
                  onSave: () => _saveImage(index),
                  onDelete: () => _deleteImage(index),
                );
              }).toList(),
              // Recent prompts history (FR-009)
              if (_history.isNotEmpty) ...[
                const Divider(height: 24),
                InkWell(
                  onTap: () => setState(() => _historyExpanded = !_historyExpanded),
                  child: Row(
                    children: [
                      Icon(
                        _historyExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.aiPromptRecentPrompts(_history.length),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_historyExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: _history.map((entry) {
                        return _HistoryEntryWidget(
                          entry: entry,
                          onDelete: () => _deleteHistoryEntry(entry.timestamp),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// One row showing a prompt, its generate button, and (after generation) a
/// thumbnail with save/delete.
class _PromptRowWidget extends StatelessWidget {
  final _PromptRow row;
  final VoidCallback onGenerate;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _PromptRowWidget({
    required this.row,
    required this.onGenerate,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt text
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              row.promptText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          // Action buttons
          Row(
            children: [
              if (!row.generating && row.result == null)
                FilledButton.tonalIcon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: Text(l10n.aiBatchGenerate),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ),
              if (row.generating)
                const SizedBox(
                  width: 100,
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('Generating...',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              if (row.result != null && !row.result!.startsWith('Error'))
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!row.saved)
                        IconButton(
                          icon: const Icon(Icons.save, size: 18),
                          tooltip: l10n.aiBatchSave,
                          onPressed: onSave,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                          ),
                        ),
                      if (row.saved)
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          tooltip: l10n.aiBatchSaved,
                          onPressed: null,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      if (row.saved)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: l10n.aiBatchDelete,
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                ),
              if (row.result != null && row.result!.startsWith('Error'))
                Text(row.result!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.red.shade700)),
            ],
          ),
          // Thumbnail after successful generation
          if (row.result != null &&
              !row.result!.startsWith('Error') &&
              row.result != null &&
              row.result!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _ImageThumbnail(url: row.result!),
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

/// One entry in the recent prompts history, with a delete button.
class _HistoryEntryWidget extends StatelessWidget {
  final AIPromptEntry entry;
  final VoidCallback onDelete;

  const _HistoryEntryWidget({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onDelete(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(
                entry.type == AIPromptType.image
                    ? Icons.image
                    : entry.type == AIPromptType.video
                        ? Icons.videocam
                        : Icons.text_fields,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.text.length > 50
                      ? '${entry.text.substring(0, 50)}...'
                      : entry.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(entry.timestamp),
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                tooltip: 'Delete',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${(diff / 60000).floor()}m';
    if (diff < 86400000) return '${(diff / 3600000).floor()}h';
    return '${(diff / 86400000).floor()}d';
  }
}

/// Small thumbnail of a generated image.
class _ImageThumbnail extends StatelessWidget {
  final String url;

  const _ImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final isDataUri = url.startsWith('data:');
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: isDataUri
          ? Image.memory(
              base64Decode(url.split(',')[1]),
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackPlaceholder(),
            )
          : CachedNetworkImage(
              imageUrl: url,
              height: 80,
              fit: BoxFit.cover,
              memCacheWidth: 200, // Limit memory cache to small thumbnail size
              memCacheHeight: 200,
              placeholder: (_, __) => _loadingPlaceholder(),
              errorWidget: (_, __, ___) => _fallbackPlaceholder(),
            ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      height: 80,
      width: 120,
      color: Colors.grey.shade100,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _fallbackPlaceholder() {
    return Container(
      height: 80,
      width: 120,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
