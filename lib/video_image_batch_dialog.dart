/// Batch image generation dialog for scene-dialog contents (spec 031 FR-005).
///
/// Lists every `[image_prompt]` entry in the content, provides a provider
/// selector at the top, and generates one image per prompt independently.
/// After generation each row shows a thumbnail with save/delete buttons.
/// Saved images are written into [picturesDir] and returned so the caller
/// can merge them into the video's picture list.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:klhu/ai/provider_client.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/ai/prompt.dart';
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

/// Result returned when the user completes the batch dialog.
class _BatchImageResult {
  final List<HeldPicture> newPictures;

  const _BatchImageResult(this.newPictures);
}

/// The batch image generation dialog.
///
/// [imagePrompts] are the `[image_prompt]` tags parsed from the content.
/// [providers] are the configured AI providers (filtered to image-capable).
/// [picturesDir] is the directory where generated images are stored.
/// [onSaved] is called with the newly saved pictures so the caller can merge
/// them into the video's picture list.
class VideoImageBatchDialog extends StatefulWidget {
  final List<ImagePromptTag> imagePrompts;
  final List<AIProvider> providers;
  final Directory picturesDir;
  final void Function(List<HeldPicture> newPictures) onSaved;

  const VideoImageBatchDialog({
    super.key,
    required this.imagePrompts,
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
      final text = tag.promptIn('');
      // Re-read prompt from the original content using the tag's offsets.
      // We don't have the original text here, so we store the tag's contentStart.
      return _PromptRow(
        tag: tag,
        promptText: _extractPrompt(tag),
        spelling: tag.spelling,
      );
    }).toList();
  }

  /// Extract the prompt text from the original content using the tag's offsets.
  /// The caller passes the full content text.
  String _extractPrompt(ImagePromptTag tag) {
    // This is called during init where we don't have the content.
    // The actual text will be shown from the tag data passed in.
    // For now, return empty and let the caller pass the text.
    return '';
  }

  /// Rebuild rows with the actual prompt text from content.
  void _initRows(String content) {
    setState(() {
      _rows = widget.imagePrompts.map((tag) {
        return _PromptRow(
          tag: tag,
          promptText: tag.promptIn(content),
          spelling: tag.spelling,
        );
      }).toList();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    }
  }

  Future<void> _deleteImage(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    if (!row.saved) return;

    try {
      final path = row.result != null
          ? '${widget.picturesDir.path}${Platform.pathSeparator}batch_${row.result}'
          : null;
      if (path != null) {
        await File(path).delete();
      }
    } catch (e) {
      debugPrint('klhu batch delete failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _rows[index] = row.copyWith(saved: false, result: null);
    });
  }

  Future<List<int>> _downloadImageBytes(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      return await response.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final imageProviders = widget.providers.where((p) =>
        p.active && (p.imageModel != null || p.url.contains('generativelanguage')));
    final displayProviders = imageProviders.isNotEmpty
        ? imageProviders.toList()
        : widget.providers.where((p) => p.active).toList();

    return AlertDialog(
      title: Text(l10n.videoCreatePicturesButton ?? 'Create pictures'),
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
                  'AI Provider',
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
                  label: const Text('Generate'),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ),
              if (row.generating)
                const SizedBox(
                  width: 80,
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
                          tooltip: 'Save',
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
                          tooltip: 'Saved',
                          onPressed: null,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      if (row.saved)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
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
          : Image.network(
              url,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackPlaceholder(),
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
