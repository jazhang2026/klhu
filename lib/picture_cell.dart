/// One picture as the reader meets it in a strip (spec 021 D1, FR-001, FR-002,
/// FR-019): the picture itself, its own count at the top right, and its file
/// name as the cell's **semantic label** — never painted.
///
/// Shared deliberately: the assignment pass's strip and the picker dialog's own
/// chosen pictures draw the same cell (FR-010), so a reader who has learned one
/// page has learned the other. What a tap or a hold *means* is not here: each
/// caller decides that.
///
/// The metrics are the dialog's own (`ChosenThumbnail`, `lib/reading_view.dart`):
/// 72 logical pixels, a bounded decode, and a picture nothing can decode shown
/// as what it is rather than crashing the page the reader is standing in.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'video_pictures.dart';

class PictureCell extends StatelessWidget {
  const PictureCell({
    super.key,
    required this.picture,
    required this.count,
    this.selected = false,
    this.size = 72,
    this.showCount = true,
  });

  final HeldPicture picture;

  /// How many sentences **the reader** gave this picture — their own record,
  /// not what the render will paint: the fallback is an outcome of the render
  /// (FR-001). The number alone is what the cell shows (FR-019); the app's own
  /// words for it live under the large picture.
  final int count;

  /// Whether this is the picture the reader is assigning to, which is what the
  /// strip's own highlight says.
  final bool selected;

  /// The cell's own edge, so a caller can draw it smaller (the sentence list
  /// marks another picture's sentence with a small cell).
  final double size;

  /// Whether the count is painted. False for the sentence list's small marker,
  /// which says which picture holds a sentence and not how many it holds.
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      // FR-002's own decision: the name is not painted, and this is where it
      // survives — the screen reader has what the eye no longer needs, and the
      // walk's own parser reads it here.
      //
      // Its own node (`container: true`), so a screen reader meets **one
      // picture at a time** instead of the whole strip merging into one label.
      container: true,
      label: picture.name,
      selected: selected,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(picture.path),
                fit: BoxFit.cover,
                cacheWidth: (size * 2).round(),
                errorBuilder: (context, error, stack) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, size: size / 4),
                ),
              ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.primary, width: 3),
                ),
              ),
            if (showCount)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
