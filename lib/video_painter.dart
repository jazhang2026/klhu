/// The frame painter: the video's own picture, drawn by the app (spec 012
/// FR-002/FR-006/FR-014/FR-027/FR-029, research D14/D16).
///
/// One `TextPainter` paints **one sentence** — the one being spoken, alone, at
/// the appearance the reader chose, mapped onto the video's frame instead of the
/// phone's screen (FR-014, A3). There is no band and no page window: with one
/// sentence in the frame there is nothing to highlight and nothing to scroll to
/// (2026-09-26's amendment, FR-002). A sentence taller than the frame's text
/// area is drawn whole, wrapped, and stepped upward a line at a time as its slot
/// elapses — never shrunk, never split (FR-029, D14).
///
/// Behind the words is the reader's own picture, filling the frame (cropped
/// where the shapes differ, never letterboxed) — **in its own colours**: nothing
/// veils or tints it (FR-027, D16 as amended on 2026-09-28). What the words sit
/// on is a **plate behind each painted line**, the line's own box, in the
/// opposite of the picture's own tone: black text on white over a light picture,
/// white text on black over a dark one — the reader's own rule of 2026-09-28, and
/// 21:1 either way. That tone is read from the picture **behind the painted
/// lines** — the band the words cover, not the whole picture, so a dark photo
/// with a bright sky is not plated in the sky's opposite (D16's second
/// amendment of 2026-09-28). With no picture scheduled the frame is the plain
/// background and the text alone, in the reader's own colour (FR-028).
///
/// Nothing of the app's chrome and nothing of the device is drawn: the frame
/// starts as the background and ends as the picture, the plates and the text,
/// which is what makes the video the app's own picture rather than a screen
/// recording.
///
/// The scaled style is a parameter rather than an ambient `Theme`, so a frame
/// can be painted without a `BuildContext` — the renderer paints in a loop, and
/// `reading_view.dart` remains the one place the reader's style is built (011
/// FR-009's seam).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:klhu/video_timeline.dart';

/// Whether a picture reads as light or dark — what decides the plate the words
/// sit on and the ink they are drawn in (FR-027, the reader's rule of
/// 2026-09-28).
enum PictureTone { light, dark }

/// How many pixels one tone read samples, spread over the bands it is asked
/// about: a phone-sized photo costs a bounded read rather than a full scan
/// (FR-027).
const int toneSampleBudget = 20000;

/// [picture]'s tone: **light** or **dark**, by the average luminance of its own
/// pixels over [bands] (FR-027).
///
/// The average is the perceptual one (`0.299R + 0.587G + 0.114B`), and
/// [VideoPainter.lightPictureFloor] is the line between the two tones: at or
/// above it the picture is light, so the plate is dark and the ink white.
///
/// [bands] are rectangles **in the picture's own pixels** — the band the words
/// cover, which is what the plate has to match (D16's amendment of 2026-09-28).
/// With none, the whole picture is read: what a caller with no text yet wants.
Future<PictureTone> pictureTone(
  ui.Image picture, {
  List<Rect> bands = const <Rect>[],
}) async {
  final data = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    // A picture whose pixels cannot be read is treated as dark, which puts the
    // white ink on a dark plate: the pair with the contrast a text needs.
    return PictureTone.dark;
  }
  return toneOfPixels(
    rgba: data.buffer.asUint8List(),
    width: picture.width,
    height: picture.height,
    bands: bands,
  );
}

/// The tone of a picture's pixels over [bands], **in the picture's own
/// coordinates** — the whole picture when none are given.
///
/// Pure arithmetic over a buffer, so a test can ask about one band of a picture
/// it built itself: no image, no GPU, no clock. A band that is empty or lies
/// outside the picture contributes nothing; if no band has a pixel in it, the
/// answer is dark, which is the pair a text can always read on.
PictureTone toneOfPixels({
  required Uint8List rgba,
  required int width,
  required int height,
  List<Rect> bands = const <Rect>[],
}) {
  final rects = bands.isEmpty
      ? <Rect>[Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble())]
      : bands;
  // The budget is shared out over the bands, so four painted lines cost what one
  // band of the same total area costs.
  final each = (toneSampleBudget / rects.length).ceil();
  var sum = 0.0;
  var seen = 0;
  for (final band in rects) {
    final left = math.max(0, band.left.floor());
    final top = math.max(0, band.top.floor());
    final right = math.min(width, band.right.ceil());
    final bottom = math.min(height, band.bottom.ceil());
    final bandWidth = right - left;
    final bandHeight = bottom - top;
    // A band that lies outside the picture — or that the clamps leave empty — has
    // no pixels to read: the other bands still answer. (Both sides have to be
    // checked before the area: a band entirely to the right of the picture has a
    // negative width and a positive height, whose product would look like area.)
    if (bandWidth <= 0 || bandHeight <= 0) continue;
    final area = bandWidth * bandHeight;
    final stride = math.max(1, (area / each).ceil());
    for (var i = 0; i < area; i += stride) {
      final at = ((top + i ~/ bandWidth) * width + left + i % bandWidth) * 4;
      sum += (0.299 * rgba[at] +
              0.587 * rgba[at + 1] +
              0.114 * rgba[at + 2]) /
          255;
      seen++;
    }
  }
  if (seen == 0) return PictureTone.dark;
  return (sum / seen) >= VideoPainter.lightPictureFloor
      ? PictureTone.light
      : PictureTone.dark;
}

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
    required this.lines,
    required this.scrollLines,
    required this.paintedText,
    required this.style,
    required this.picture,
    required this.plates,
    required this.tone,
    required this.inkColour,
    required this.plateColour,
  });

  /// The slot this frame belongs to.
  final VideoSlot slot;

  final ui.Image image;

  /// The frame's text area: the margins on all four sides leave this much room,
  /// and nothing of the text may leave it (FR-006).
  final Rect column;

  /// Each painted line's box, in frame coordinates **as drawn** — so a scrolled
  /// block's boxes are where the reader saw them, not where the block started.
  final List<Rect> lines;

  /// How many whole lines the block was stepped upward (D14): 0 for a sentence
  /// that fits, which is drawn still.
  final int scrollLines;

  /// What the frame shows: the slot's own sentence.
  final String paintedText;

  /// The style that text was painted in — the reader's own, mapped onto this
  /// frame (FR-014/SC-011), and never reduced for length (FR-029).
  final TextStyle style;

  /// The picture drawn behind the text, or null where the frame is the plain
  /// background (FR-028).
  final ui.Image? picture;

  /// The plate drawn behind each painted line, in frame coordinates **as
  /// drawn** — the plate the words sit on where a picture is behind them
  /// (FR-027). Empty where there is no picture: the frame is the plain
  /// background, and the text sits on it as it always has (FR-028).
  final List<Rect> plates;

  /// The picture's own tone, or null where the frame has no picture — and so
  /// nothing whose light or dark had to be read (FR-027).
  final PictureTone? tone;

  /// The colour the text was actually drawn in: the reader's own where the frame
  /// is the plain background, black over a light picture, white over a dark one
  /// (FR-027/FR-028).
  final Color inkColour;

  /// The colour of [plates], or null where nothing is plated.
  final Color? plateColour;
}

/// Paints one frame per slot at the plan's frame size.
class VideoPainter {
  VideoPainter({
    required this.plan,
    required this.readingStyle,
    required this.background,
  });

  final VideoPlan plan;

  /// The reader's own reading style (011's `_contentTextStyle`), unscaled.
  final TextStyle readingStyle;

  final Color background;

  /// The reading width the app lays its text out on (011's own viewport, a
  /// 360 dp phone — the reference device's screen minus the page's padding).
  /// The video's scale is this frame's column against it, so the reader's
  /// typeface and character size keep the proportion they chose (A3).
  static const double referenceColumnWidth = 360;

  /// How much **longer** a line is than the reader's own column: the reader's
  /// own request, from watching a render (2026-09-28 — "make the text line to be
  /// longer, will has less lines"), because a longer line is a sentence in fewer
  /// of them. The old rule kept this at 1 (a line no longer than the reader's own
  /// column), and it is the one number this file divides the letters by and
  /// multiplies the column's height bound by, so the wrap, the letters and the
  /// column can never disagree about it.
  static const double lineLengthGain = 1.4;

  /// The widest the column may be, as a fraction of the frame's width: the
  /// frame's own margins, which the text must stay inside whatever else changes.
  static const double maxColumnFraction = 0.92;

  /// The fraction of the frame's width the **letters'** own column is measured
  /// against: the rule the text area itself used while a line could not be longer
  /// than it (`min(0.88 × width, height)`).
  ///
  /// It is a separate number on purpose. The reader asked for longer lines
  /// (2026-09-28) and then, shown what that cost on a portrait frame, for the
  /// letters to keep the size they had: "竖屏也保持原来的字大小". Keeping the old
  /// fraction here is what makes that exact — the letters are the size their frame
  /// has always set them, and the column above is only wider, so the width a frame
  /// gives is width the *line* gets.
  static const double lettersColumnFraction = 0.88;

  /// The margin above and below the column, as a fraction of the frame's height:
  /// the vertical space is what a text block is laid out inside.
  static const double marginYFraction = 0.10;

  /// The smallest em the video may paint at the reader's smallest size, in frame
  /// pixels — A3's consequence, stated so it can be tested (quickstart 12): the
  /// video carries the size the reader chose, so the 1080-wide frame has to be
  /// generous enough that 12 pt still clears this.
  static const int minimumEm = 30;

  /// The plate the words sit on where a picture is behind them, and the ink on
  /// it: **the picture's own tone decides which pair** — the reader's rule of
  /// 2026-09-28, "black text on white background if the background image has
  /// light color, white text on black background if the background image has
  /// dark color" (FR-027).
  ///
  /// One plate per painted line, the line's own box, and nothing else between
  /// the picture and the text — the picture keeps its own colours. The plate is
  /// the opposite of the picture's tone, so the block reads against a surface
  /// the picture cannot camouflage, and the pair carries the strongest contrast
  /// a text can have: **21:1** either way, where spike S4's withdrawn veil
  /// needed four pictures and both aspects to show a 4.90:1 floor (D16).
  static const Color plateOnLightPicture = Color(0xFFFFFFFF);
  static const Color inkOnLightPicture = Color(0xFF000000);
  static const Color plateOnDarkPicture = Color(0xFF000000);
  static const Color inkOnDarkPicture = Color(0xFFFFFFFF);

  /// The average picture luminance at or above which a picture counts as light
  /// and gets the dark plate (FR-027). Half way: a picture the eye would call
  /// light half the time, decided the same way every render.
  static const double lightPictureFloor = 0.5;

  /// The text column, in frame coordinates.
  ///
  /// Its width is `min(maxColumnFraction × width, lineLengthGain × height)`:
  /// never the whole frame, and no more than the gain's worth of the frame's
  /// height — the column may be that much wider than the natural column above,
  /// which is what the extra characters on a line come from (the letters' own size
  /// is the natural column's, so the width the frame gives is width the line gets). The second bound is what makes a 16:9 frame's column narrower than a
  /// 9:16 one's (research D6) — a line is a thing the eye takes in at once, and it
  /// is the vertical extent a text block is really laid out inside. D6's own
  /// bound was the height itself, a line no longer than the block is tall, until
  /// the reader asked for longer lines and fewer of them (2026-09-28).
  double get columnWidth {
    final byWidth = plan.width * maxColumnFraction;
    final byHeight = plan.height * lineLengthGain;
    return byWidth < byHeight ? byWidth : byHeight;
  }

  /// The reader's character size, mapped onto this frame: the size of the frame's
  /// own **natural** column (`min(lettersColumnFraction × width, height)` — the
  /// rule the text area itself had while a line could not be longer than it).
  ///
  /// The letters therefore keep the size they have always had on this frame, and a
  /// longer line is more words on it rather than bigger ones (FR-014, A3). A frame
  /// with no width to give — a 9:16 frame, whose column is already 92% of its own
  /// width — keeps its letters rather than shrinking them for a line that has
  /// nowhere to grow, which is the reader's own answer of 2026-09-28 when the
  /// choice was put to them: "竖屏也保持原来的字大小" (keep the original character
  /// size on the portrait frame too).
  double get scale {
    final byWidth = plan.width * lettersColumnFraction;
    final natural = byWidth < plan.height ? byWidth : plan.height.toDouble();
    return natural / referenceColumnWidth;
  }

  double get _marginX => (plan.width - columnWidth) / 2;
  double get _marginY => plan.height * marginYFraction;

  Rect get column => Rect.fromLTRB(
      _marginX, _marginY, plan.width - _marginX, plan.height - _marginY);

  /// Paints [slot]'s frame, with [picture] behind it where the schedule has one.
  ///
  /// [progress] is the elapsed fraction of the slot, 0 at its first frame and 1
  /// at its last: it decides which line step a too-tall sentence is drawn at
  /// (D14). It defaults to 0 — the frame at the slot's start — so a caller that
  /// wants one still frame does not have to know about the scroll.
  Future<VideoFrame> paint({
    required VideoSlot slot,
    double progress = 0,
    ui.Image? picture,
  }) async {
    final frameRect =
        Rect.fromLTWH(0, 0, plan.width.toDouble(), plan.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, frameRect);
    final column = this.column;

    // The text's own geometry comes first, because where the words sit is what
    // the picture is read over (FR-027): the layout does not depend on the ink,
    // so it can be laid out before the tone is known and the tone asked for the
    // band it actually covers.
    final geometry = _blockFor(slot);

    // FR-029's scroll: the block is stepped up one line at a time, and the step
    // comes from the elapsed fraction of the slot (D14). Quantised on purpose —
    // a pixel-smooth scroll would need a repaint per frame, and one picture per
    // distinct visual state is what keeps the render's cost where S2 measured it.
    //
    // The epsilon is not decoration: the renderer's progress is `position /
    // positions`, and binary floating point cannot represent that exactly — at
    // 31/102 the product lands a hair *below* 31 and the step would repeat while
    // 32 was skipped. A millionth of a step is far below anything a caller means.
    final scaled = progress.clamp(0.0, 1.0) * (geometry.steps + 1);
    final scrollLines = geometry.steps == 0
        ? 0
        : (scaled + 1e-6).floor().clamp(0, geometry.steps);

    // A sentence that fits sits at the **bottom** of the area — the reader's own
    // request from watching a render (2026-09-28 — "move text block from top to
    // bottom") — so the picture has the frame above the words to itself. A
    // sentence taller than the area keeps FR-029's own shape instead: its first
    // line at the top, scrolling down through the block a line at a time, which is
    // also why the anchor is the block's own `steps` rather than the progress (a
    // too-tall block's first frame is not a block that fits).
    final double blockTop = geometry.steps == 0
        ? column.bottom - geometry.height
        : column.top - scrollLines * geometry.lineHeight;

    // FR-027: the picture's own tone decides the plate and the ink, so the words
    // read over any picture while the picture keeps its colours. With no picture
    // there is nothing to read against but the reader's own background, and the
    // text is the reader's own colour (FR-028).
    //
    // The tone is read over **the band the painted lines cover** rather than
    // over the whole picture (D16's amendment of 2026-09-28): a dark photograph
    // whose text sits under a bright sky is plated in white, not in black,
    // because the picture's average is not what is behind the words.
    final tone = picture == null
        ? null
        : await _toneOf(picture, _bandsOf(picture, column, blockTop, geometry));
    final inkColour = tone == null
        ? (readingStyle.color ?? inkOnLightPicture)
        : (tone == PictureTone.light ? inkOnLightPicture : inkOnDarkPicture);
    final plateColour = tone == null
        ? null
        : (tone == PictureTone.light ? plateOnLightPicture : plateOnDarkPicture);
    final block = tone == null ? geometry : _blockFor(slot, ink: inkColour);

    // The frame starts as the background: what a video with nothing scheduled is
    // made of (FR-028).
    canvas.drawRect(frameRect, Paint()..color = background);

    if (picture != null) {
      // The picture fills the frame — cropped, never letterboxed — and keeps its
      // own colours: nothing is drawn over the frame as a whole (FR-027).
      canvas.drawImageRect(picture, _coverSource(picture), frameRect, Paint());
    }

    // Nothing but the text area's own contents may reach the frame: the margins
    // are the background (or the picture) to the edges.
    canvas.clipRect(column);

    // FR-027: where a picture is behind the text, each painted line sits on a
    // plate — the line's own box, from the picture up to the text — in the
    // colour the picture's tone called for, and a scrolled block's plates are
    // kept inside the text area by the clip above.
    final plates = <Rect>[
      if (plateColour != null)
        for (final box in block.lines) box.shift(Offset(column.left, blockTop)),
    ];
    if (plates.isNotEmpty) {
      final plate = Paint()..color = plateColour!;
      for (final box in plates) {
        canvas.drawRect(box, plate);
      }
    }

    block.layout.paint(canvas, Offset(column.left, blockTop));

    final recording = recorder.endRecording();
    final image = await recording.toImage(plan.width, plan.height);
    recording.dispose();

    return VideoFrame(
      slot: slot,
      image: image,
      column: column,
      lines: [
        for (final box in block.lines) box.shift(Offset(column.left, blockTop)),
      ],
      scrollLines: scrollLines,
      paintedText: block.paintedText,
      style: block.style,
      picture: picture,
      plates: plates,
      tone: tone,
      inkColour: inkColour,
      plateColour: plateColour,
    );
  }

  /// The tone of [picture] over [bands] (the picture's own pixels): **light** or
  /// **dark**, which decides the plate and the ink the words are drawn in
  /// (FR-027).
  ///
  /// The picture's raw pixels are converted **once per picture** and kept while
  /// that picture is the one being painted: converting a whole frame's pixels for
  /// every frame of it would be the render's cost, not a rounding error, and a
  /// phone photo's RGBA is megabytes — so one picture's pixels at a time, which
  /// is the most a render may hold and is what the renderer's own in-order walk
  /// hands it. Each distinct band is read once and remembered after that, since
  /// the same picture is drawn behind a run of sentences and the words sit
  /// somewhere else in it each time (D16's amendment of 2026-09-28).
  Future<PictureTone> _toneOf(ui.Image picture, List<Rect> bands) async {
    if (!identical(_pixelsOf, picture)) {
      final data = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
      _pixelsOf = picture;
      _pixels = data?.buffer.asUint8List();
      _tones = <String, PictureTone>{};
    }
    final pixels = _pixels;
    if (pixels == null) return PictureTone.dark;
    final key = _bandKey(bands);
    final known = _tones[key];
    if (known != null) return known;
    final tone = toneOfPixels(
      rgba: pixels,
      width: picture.width,
      height: picture.height,
      bands: bands,
    );
    _tones[key] = tone;
    return tone;
  }

  /// The pixels of the picture [_toneOf] last read, and which picture they are.
  ui.Image? _pixelsOf;
  Uint8List? _pixels;

  /// The tones read out of [_pixels], by band ([_bandKey]).
  Map<String, PictureTone> _tones = <String, PictureTone>{};

  /// [bands] as a key: the same band again is a lookup rather than a second
  /// scan, and a band that has moved is a different answer.
  String _bandKey(List<Rect> bands) => bands
      .map((b) =>
          '${b.left.round()},${b.top.round()},'
          '${b.width.round()}x${b.height.round()}')
      .join(';');

  /// The parts of [picture] the words cover, in the picture's own pixels: [block]'s
  /// painted lines as they are drawn — shifted by [blockTop] and clipped to the
  /// text area — mapped through the same cover draw the frame uses (FR-027).
  ///
  /// This is the whole point of the band (D16's amendment of 2026-09-28): the
  /// tone has to be read where the words are, or a dark picture with a bright
  /// sky behind the text puts the black plate on the sky. The lines **as drawn**
  /// rather than the block's whole extent, so a sentence too tall for the frame
  /// is read over the part of the picture its words are actually over — at the
  /// cost that such a sentence, stepping through a region whose average crosses
  /// the floor, changes the plate mid-slot; either colour is still the strongest
  /// contrast a text can have, so the crossing is a change of look rather than a
  /// loss of legibility.
  List<Rect> _bandsOf(
    ui.Image picture,
    Rect column,
    double blockTop,
    _TextBlock block,
  ) {
    final source = _coverSource(picture);
    final scaleX = source.width / plan.width;
    final scaleY = source.height / plan.height;
    final bands = <Rect>[];
    for (final box in block.lines) {
      final visible = box.shift(Offset(column.left, blockTop)).intersect(column);
      if (visible.width <= 0 || visible.height <= 0) continue;
      bands.add(Rect.fromLTRB(
        source.left + visible.left * scaleX,
        source.top + visible.top * scaleY,
        source.left + visible.right * scaleX,
        source.top + visible.bottom * scaleY,
      ));
    }
    return bands;
  }

  /// How many whole-line steps [slot]'s text needs in this frame: 0 when the
  /// text fits and is drawn still (FR-029, D14).
  ///
  /// The renderer asks for this so it knows how many distinct pictures a
  /// sentence's run holds — one per line step, since the picture that is shown is
  /// the picture written and a picture per visual state is what keeps the cost
  /// where S2 measured it.
  int scrollSteps(VideoSlot slot) => _blockFor(slot).steps;

  /// The text this frame draws, laid out: what it says, its own style, its lines
  /// before the scroll, and the step count the scroll is quantised to.
  ///
  /// [ink] is the colour the words are drawn in — the tone's own over a picture,
  /// the reader's own otherwise (FR-027) — and it is a paint-time fact, so a
  /// block is laid out per frame rather than cached across tones.
  _TextBlock _blockFor(VideoSlot slot, {Color? ink}) {
    final style = readingStyle.copyWith(
      fontSize: (readingStyle.fontSize ?? 14) * scale,
      color: ink ?? readingStyle.color,
    );
    // A frame shows one thing — the slot's own sentence — in one style and one
    // span, drawn from the area's left edge (FR-029).
    final layout = TextPainter(
      text: TextSpan(text: slot.text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    )..layout(maxWidth: column.width);

    // The block's own lines, before the scroll: from the metrics rather than
    // from a selection, since every line of this text is drawn.
    final lines = <Rect>[];
    final metrics = layout.computeLineMetrics();
    var height = 0.0;
    for (final line in metrics) {
      lines.add(Rect.fromLTWH(
          line.left.toDouble(), height, line.width.toDouble(), line.height));
      height += line.height;
    }
    final lineHeight = metrics.isEmpty ? 0.0 : metrics.first.height;
    final overflow = height - column.height;

    return _TextBlock(
      paintedText: slot.text,
      style: style,
      layout: layout,
      lines: lines,
      height: height,
      lineHeight: lineHeight,
      steps: (overflow <= 0 || lineHeight <= 0)
          ? 0
          : (overflow / lineHeight).ceil(),
    );
  }

  /// The part of [picture] to draw so that it covers the frame: the whole of the
  /// shorter side and the centred part of the longer one, so the picture is
  /// cropped rather than letterboxed (FR-027).
  Rect _coverSource(ui.Image picture) {
    final frameAspect = plan.width / plan.height;
    final pictureAspect = picture.width / picture.height;
    if (pictureAspect > frameAspect) {
      // Wider than the frame: keep the full height, crop the sides.
      final width = picture.height * frameAspect;
      return Rect.fromLTWH(
          (picture.width - width) / 2, 0, width, picture.height.toDouble());
    }
    final height = picture.width / frameAspect;
    return Rect.fromLTWH(
        0, (picture.height - height) / 2, picture.width.toDouble(), height);
  }

  /// The same frame's bytes, for the encoder (FR-020: the picture shown is the
  /// picture written).
  Future<Uint8List> pngOf(ui.Image image) => pngBytesOf(image);
}

/// One slot's text, laid out ready to draw: what it says, the lines it occupies
/// before any scroll, and the step count its scroll is quantised to (D14).
class _TextBlock {
  _TextBlock({
    required this.paintedText,
    required this.style,
    required this.layout,
    required this.lines,
    required this.height,
    required this.lineHeight,
    required this.steps,
  });

  final String paintedText;
  final TextStyle style;

  /// The laid-out text, ready to paint at an offset.
  final TextPainter layout;

  /// Each line's box in **block** coordinates: y = 0 at the block's own top, and
  /// the frame's own top is added when the block is drawn.
  final List<Rect> lines;

  final double height;
  final double lineHeight;

  /// How many whole lines the block must move for its last line to reach the
  /// bottom of the text area; 0 when the text fits and is drawn still.
  final int steps;
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
