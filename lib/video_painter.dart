/// The frame painter: the video's own picture, drawn by the app (spec 012
/// FR-002/FR-006/FR-014, research D2).
///
/// One `TextPainter` paints the paragraph the current sentence belongs to, with
/// that sentence highlighted — the same reading text the page shows, at the
/// appearance the reader chose, mapped onto the video's frame instead of the
/// phone's screen (FR-014; A3). Nothing of the app's chrome and nothing of the
/// device is drawn: the frame starts as the background colour and ends as text
/// and one highlight, which is what makes the video the app's own picture
/// rather than a screen recording.
///
/// The scaled style is a parameter rather than an ambient `Theme`, so a frame
/// can be painted without a `BuildContext` — the renderer paints in a loop, and
/// `reading_view.dart` remains the one place the reader's style is built (011
/// FR-009's seam).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/video_timeline.dart';

/// One painted frame: the picture the reader watches during the render and the
/// encoder is handed, with the geometry the tests and the renderer both need.
///
/// [image] is the frame and [pngOf] is the same frame's bytes — one picture,
/// two consumers (FR-020).
class VideoFrame {
  const VideoFrame({
    required this.slot,
    required this.image,
    required this.column,
    required this.lineBoxes,
    required this.highlight,
    required this.highlightRange,
    required this.paintedText,
    required this.style,
  });

  /// The slot this frame belongs to.
  final VideoSlot slot;

  final ui.Image image;

  /// The text column, inside the frame's margins.
  final Rect column;

  /// Each painted line's box, in frame coordinates.
  final List<Rect> lineBoxes;

  /// The highlighted band, in frame coordinates; null on the title card.
  final Rect? highlight;

  /// The span [highlight] covers, relative to [paintedText].
  final TextRange? highlightRange;

  /// What the frame actually shows: the paragraph of the slot's sentence, or the
  /// content's name (and its language) on the title card.
  final String paintedText;

  /// The style that text was painted in — the reader's own, mapped onto this
  /// frame (FR-014/SC-011). On the title card this is the name's style; the
  /// language under it is [VideoPainter.titleLabelScale] of it.
  final TextStyle style;
}

/// Paints one frame per slot at the plan's frame size.
class VideoPainter {
  VideoPainter({
    required this.plan,
    required this.readingStyle,
    required this.background,
    required this.highlight,
    this.languageLabel,
  });

  final VideoPlan plan;

  /// The reader's own reading style (011's `_contentTextStyle`), unscaled.
  final TextStyle readingStyle;

  final Color background;
  final Color highlight;

  /// Names a language for the title card (`'en'` → `'English'`). The page
  /// supplies it from the app's own copy; without it the card carries the name
  /// alone, which is what the tests and any context-free caller get.
  final String Function(String language)? languageLabel;

  /// The reading width the app lays its text out on (011's own viewport, a
  /// 360 dp phone — the reference device's screen minus the page's padding).
  /// The video's scale is this frame's column against it, so the reader's
  /// typeface and character size keep the proportion they chose (A3).
  static const double referenceColumnWidth = 360;

  /// The widest the column may be, as a fraction of the frame's width.
  static const double maxColumnFraction = 0.88;

  /// The margin above and below the column, as a fraction of the frame's height:
  /// the vertical space is what a text block is laid out inside.
  static const double marginYFraction = 0.10;

  /// The smallest em the video may paint at the reader's smallest size, in frame
  /// pixels — A3's consequence, stated so it can be tested (quickstart 12): the
  /// video carries the size the reader chose, so the 1080-wide frame has to be
  /// generous enough that 12 pt still clears this.
  static const int minimumEm = 30;

  /// The title card's language under its name, relative to the name's size.
  static const double titleLabelScale = 0.55;

  /// The text column, in frame coordinates.
  ///
  /// Its width is `min(maxColumnFraction × width, height)`: never the whole
  /// frame, and never wider than the frame is tall. The second bound is what
  /// makes a 16:9 frame's column narrower than a 9:16 one's (research D6) — a
  /// column wider than its own height sets a line the eye cannot take in at one
  /// go, and it is the vertical extent a text block is really laid out inside.
  double get columnWidth {
    final byWidth = plan.width * maxColumnFraction;
    return byWidth < plan.height ? byWidth : plan.height.toDouble();
  }

  /// The reader's character size, mapped onto this frame.
  double get scale => columnWidth / referenceColumnWidth;

  double get _marginX => (plan.width - columnWidth) / 2;
  double get _marginY => plan.height * marginYFraction;

  Rect get column => Rect.fromLTRB(
      _marginX, _marginY, plan.width - _marginX, plan.height - _marginY);

  /// Paints [slot]'s frame over [content].
  Future<VideoFrame> paint({
    required String content,
    required VideoSlot slot,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, plan.width.toDouble(), plan.height.toDouble()),
    );
    final column = this.column;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, plan.width.toDouble(), plan.height.toDouble()),
      Paint()..color = background,
    );
    // Nothing but the column's own contents may reach the frame: the margins
    // are the background, to the edges (FR-006).
    canvas.clipRect(column);

    final text = slot.isSentence ? _paragraphOf(content, slot) : null;
    final label = slot.isSentence ? null : _titleLanguageLabel();
    final paintedText =
        text ?? (label == null ? plan.title : '${plan.title}\n$label');
    final style = readingStyle.copyWith(
      fontSize: (readingStyle.fontSize ?? 14) * scale,
    );
    // The card is two sizes — the name, and its language under it. Everything
    // else is one span, so the highlight's offsets are offsets into it.
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: text ?? plan.title, style: style),
          if (label != null)
            TextSpan(
              text: '\n$label',
              style: style.copyWith(fontSize: style.fontSize! * titleLabelScale),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: slot.isSentence ? TextAlign.start : TextAlign.center,
    )..layout(maxWidth: column.width);

    final range = text == null
        ? null
        : TextRange(
            start: (slot.start - _paragraphStart(content, slot))
                .clamp(0, paintedText.length),
            end: (slot.end - _paragraphStart(content, slot))
                .clamp(0, paintedText.length),
          );

    // Where the band would be if the text started at the column's top, and how
    // far down the text has to move for it to be on screen: a paragraph taller
    // than the frame is windowed around the sentence being heard, which is the
    // video's own self-scroll (FR-002).
    var textTop = column.top;
    Rect? highlight;
    if (range != null && !range.isCollapsed) {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      if (boxes.isNotEmpty) {
        var band = Rect.fromLTRB(
          boxes.first.left,
          boxes.first.top,
          boxes.first.right,
          boxes.first.bottom,
        );
        for (final box in boxes.skip(1)) {
          band = band.expandToInclude(
            Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
          );
        }
        if (painter.height > column.height) {
          final centred =
              column.top + (column.height - band.height) / 2 - band.top;
          final lowest = column.top - (painter.height - column.height);
          textTop = centred.clamp(lowest, column.top);
        }
        highlight = band.shift(Offset(column.left, textTop));
      }
    } else if (!slot.isSentence && painter.height < column.height) {
      // The title card sits in the middle of its frame.
      textTop = column.top + (column.height - painter.height) / 2;
    }

    if (highlight != null) {
      canvas.drawRect(highlight, Paint()..color = this.highlight);
    }
    painter.paint(canvas, Offset(column.left, textTop));

    final lineBoxes = <Rect>[
      for (final line in painter.computeLineMetrics())
        Rect.fromLTWH(
            column.left, textTop + line.baseline - line.ascent, column.width, line.height),
    ];

    final picture = recorder.endRecording();
    final image = await picture.toImage(plan.width, plan.height);
    picture.dispose();

    return VideoFrame(
      slot: slot,
      image: image,
      column: column,
      lineBoxes: lineBoxes,
      highlight: highlight,
      highlightRange: range,
      paintedText: paintedText,
      style: style,
    );
  }

  /// The language the video opens in — its first spoken sentence's — named for
  /// the reader, or null when there is nothing to name it with.
  ///
  /// The title card's language is the language of the sentence the video starts
  /// on (FR-004/A1), which is why it comes from the plan's first sentence rather
  /// than from the content's first paragraph: a video that opens at a
  /// highlighted sentence names *that* sentence's language.
  String? _titleLanguageLabel() {
    final label = languageLabel;
    if (label == null || plan.sentences.isEmpty) return null;
    final language = plan.sentences.first.language;
    if (language.isEmpty) return null;
    final name = label(language);
    return name.isEmpty ? null : name;
  }

  /// The same frame's bytes, for the encoder (FR-020: the picture shown is the
  /// picture written).
  Future<Uint8List> pngOf(ui.Image image) => pngBytesOf(image);

  /// The paragraph the slot's sentence belongs to — the text the frame shows.
  String? _paragraphOf(String content, VideoSlot slot) {
    for (final paragraph in paragraphRanges(content)) {
      if (slot.start >= paragraph.start && slot.end <= paragraph.end) {
        return content.substring(paragraph.start, paragraph.end);
      }
    }
    return slot.start < content.length
        ? content.substring(0, content.length)
        : null;
  }

  int _paragraphStart(String content, VideoSlot slot) {
    for (final paragraph in paragraphRanges(content)) {
      if (slot.start >= paragraph.start && slot.end <= paragraph.end) {
        return paragraph.start;
      }
    }
    return 0;
  }
}

/// The frame's bytes, as the encoder is handed them.
///
/// A top-level function because two callers need it without a painter: the
/// renderer, and anything checking that the bytes it sent are the picture it
/// showed (which has only the image, not the painter).
Future<Uint8List> pngBytesOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
