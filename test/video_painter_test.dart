/// The frame painter (spec 012 US2's amended frame): quickstart scenarios 7–12
/// and 44–46 — one slot's sentence alone in the frame at the reader's own size,
/// wrapped and stepped upward a line at a time where it is taller than the frame,
/// over the scheduled picture with the scrim between them, and the plain
/// background when nothing is scheduled.
///
/// This file defines the API it tests: `lib/video_painter.dart` still paints the
/// reading page's paragraph with a highlight band (T006's rows), and **T039
/// replaces those rows rather than extending them** — the band, the page window
/// and the column mapping are gone, because with one sentence in the frame there
/// is nothing to highlight and nothing to scroll to (FR-002, 2026-09-26). The
/// first run is a compile error: the RED this rewrite starts from.
///
/// The paint claims are pixel claims, so the picture, the scrim and the
/// background are read back from the frame's own bytes; the *text* claims are
/// asserted on the painter's own geometry (the line boxes it laid out), which
/// does not care which font the test host has installed.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_timeline.dart';

/// A sentence far taller than any frame's text area: the scroll's own case.
/// Built rather than spelled out — it has to be several screens of one sentence,
/// and the number only has to be big, not meaningful.
final String _tallText =
    List.filled(60, 'the quiet river runs beneath the old stone bridge').join(' ');

/// Two paragraphs, one per language: the frame shows the slot's own sentence, so
/// a mixed content is what proves the frame is not the paragraph it came from.
final _sentences = videoSentencesOf(const [
  ParagraphSpeech(
      text: 'One two. Three four.', language: 'en', voice: null, start: 0, end: 20),
  ParagraphSpeech(
      text: '清晨的阳光。鸟儿歌唱。',
      language: 'zh-Hans',
      voice: null,
      start: 22,
      end: 33),
]);

final _tallSentences = videoSentencesOf([
  ParagraphSpeech(
      text: _tallText,
      language: 'en',
      voice: null,
      start: 0,
      end: _tallText.length),
]);

/// Deliberately not the app's colours: a frame the test can read back without
/// depending on the theme. The background is also the scrim's own colour
/// (FR-027), which is what makes the composite computable here.
const _background = Color(0xFF101014);
const _ink = Color(0xFFF2F2F2);

VideoPlan _planFor(VideoAspect aspect, {bool tall = false}) {
  final sentences = tall ? _tallSentences : _sentences;
  return buildVideoPlan(
    title: 'Mixed',
    sentences: sentences,
    audioMs: List.filled(sentences.length, 1000),
    aspect: aspect,
  );
}

/// A painter over [aspect] at the reader's own style — the four sizes the
/// appearance screen offers are 12/14/18/24, so the tests use those numbers.
VideoPainter _painterFor(
  VideoAspect aspect, {
  bool tall = false,
  double fontSize = 14,
  String? family,
  String Function(String language)? languageLabel,
}) =>
    VideoPainter(
      plan: _planFor(aspect, tall: tall),
      readingStyle:
          TextStyle(fontSize: fontSize, color: _ink, fontFamily: family),
      background: _background,
      languageLabel: languageLabel,
    );

/// The frame's pixels, row-major RGBA.
Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Color _at(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
}

/// The first sampled pixel in [rect] that is not [colour], as `x,y colour`, or
/// null when the whole band is that colour. Named in a failure's reason: a
/// background claim is only useful if it says where it broke.
String? _dirt(Uint8List rgba, int width, Rect rect, Color colour,
    {int stride = 4}) {
  for (var y = rect.top.round(); y < rect.bottom.round(); y += stride) {
    for (var x = rect.left.round(); x < rect.right.round(); x += stride) {
      final found = _at(rgba, width, x, y);
      if (found != colour) return '$x,$y ${found.toARGB32().toRadixString(16)}';
    }
  }
  return null;
}

/// The contrast ratio between two colours, by WCAG's own formula: the claim
/// SC-004 makes about the words and the plate they sit on, worked out here
/// rather than taken from the painter.
double _contrast(Color a, Color b) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a), lb = luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// A light picture that is not white, so the plates it earns are the only white
/// in the frame: luminance 0.85, well over the painter's floor.
const _lightPicture = Color(0xFFFFDD66);

/// A dark picture that is not black, so the plates it earns are the only black
/// in the frame: luminance 0.17, well under it.
const _darkPicture = Color(0xFF331122);

/// True when [found] is within [tolerance] of [expected] on every channel: the
/// compositor rounds, and one channel's rounding is not a claim.
bool _near(Color found, Color expected, {int tolerance = 2}) {
  bool close(double a, double b) =>
      ((a - b).abs() * 255).round() <= tolerance;
  return close(found.r, expected.r) &&
      close(found.g, expected.g) &&
      close(found.b, expected.b);
}

Future<ui.Image> _imageOf(
    int width, int height, List<int> Function(int x, int y) colour) async {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rgb = colour(x, y);
      final i = (y * width + x) * 4;
      bytes[i] = rgb[0];
      bytes[i + 1] = rgb[1];
      bytes[i + 2] = rgb[2];
      bytes[i + 3] = 255;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      bytes, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

/// A picture of four solid quadrants — red, green, blue, yellow — so a frame it
/// is drawn into says *which* part of the picture each corner came from. A
/// letterboxed draw would show the plain background in the corners instead.
Future<ui.Image> _quadrants() => _imageOf(
    200,
    100,
    (x, y) => x < 100
        ? (y < 50 ? const [255, 0, 0] : const [0, 0, 255])
        : (y < 50 ? const [0, 255, 0] : const [255, 255, 0]));

/// A solid picture, for the scrim's own numbers.
Future<ui.Image> _solid(int side, Color colour) => _imageOf(side, side,
    (_, _) => [colour.r, colour.g, colour.b].map((c) => (c * 255).round()).toList());

/// A picture's pixels, row-major RGBA, in two bands: [top] over the top
/// [fraction] of the height, [bottom] below it. Built as a buffer rather than as
/// an image, because a band *is* a rectangle of pixels and the tone is read from
/// pixels (FR-027) — no decode, no GPU, no clock.
Uint8List _twoBands(
  Color top,
  Color bottom, {
  int width = 100,
  int height = 100,
  double fraction = 0.5,
}) {
  final bytes = Uint8List(width * height * 4);
  final split = (height * fraction).round();
  for (var y = 0; y < height; y++) {
    final argb = (y < split ? top : bottom).toARGB32();
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      bytes[i] = (argb >> 16) & 0xFF;
      bytes[i + 1] = (argb >> 8) & 0xFF;
      bytes[i + 2] = argb & 0xFF;
      bytes[i + 3] = 255;
    }
  }
  return bytes;
}

/// A picture that is [top] over the top [fraction] of its height and [bottom]
/// below: the reader's own case of 2026-09-28 — a photograph whose text sits on
/// a band whose light or dark is not its own.
Future<ui.Image> _banded(Color top, Color bottom,
    {int width = 108, int height = 192, double fraction = 0.2}) {
  final split = (height * fraction).round();
  return _imageOf(width, height, (x, y) {
    final argb = (y < split ? top : bottom).toARGB32();
    return [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF];
  });
}

/// What the painter lays out for [text], recomputed here at the frame's own
/// style and text area: the scroll claims are then about the text rather than
/// about the painter's own report.
TextPainter _layoutOf(VideoPainter painter, String text) => TextPainter(
      text: TextSpan(
        text: text,
        style: painter.readingStyle.copyWith(
          fontSize: (painter.readingStyle.fontSize ?? 14) * painter.scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: painter.column.width);

/// How many whole lines the block must move for its last line to reach the
/// bottom of the text area — the painter's own quantisation, recomputed.
int _stepsOf(VideoPainter painter, String text) {
  final layout = _layoutOf(painter, text);
  final overflow = layout.height - painter.column.height;
  if (overflow <= 0) return 0;
  final metrics = layout.computeLineMetrics();
  return (overflow / metrics.first.height).ceil();
}

void main() {
  group('7. the frame is the sentence being spoken, alone and whole', () {
    test('every slot\'s frame carries that slot\'s sentence and nothing else',
        () async {
      final painter = _painterFor(VideoAspect.landscape);
      for (final slot in painter.plan.sentences) {
        final frame = await painter.paint(slot: slot);
        expect(frame.paintedText, slot.text);
        expect(frame.paintedText, isNot(contains('\n\n')),
            reason: 'the frame is one sentence, not the paragraph it came from');
        // The same text laid out at the frame's own style and width has exactly
        // the lines the frame drew: nothing appended, nothing left out.
        final layout = _layoutOf(painter, slot.text);
        expect(frame.lines, hasLength(layout.computeLineMetrics().length));
        frame.image.dispose();
      }
    });

    test('the title card names the content and carries no sentence', () async {
      final asked = <String>[];
      final painter =
          _painterFor(VideoAspect.landscape, languageLabel: (language) {
        asked.add(language);
        return language == 'en' ? 'English' : language;
      });
      final card = await painter.paint(slot: painter.plan.slots.first);

      expect(card.slot.kind, VideoSlotKind.title);
      expect(card.paintedText, 'Mixed\nEnglish');
      // The language the video opens in: its first spoken sentence's.
      expect(asked, ['en']);
      for (final slot in painter.plan.sentences) {
        expect(card.paintedText, isNot(contains(slot.text)));
      }

      final first = await painter.paint(slot: painter.plan.sentences.first);
      expect(first.paintedText, painter.plan.sentences.first.text);
      expect(first.paintedText, isNot(contains('Mixed')));
      card.image.dispose();
      first.image.dispose();
    });

    test('the card is the name alone when no label is given', () async {
      final painter = _painterFor(VideoAspect.landscape);
      final card = await painter.paint(slot: painter.plan.slots.first);
      expect(card.paintedText, 'Mixed');
      expect(VideoPainter.titleLabelScale, lessThan(1));
      card.image.dispose();
    });
  });

  group('9. the frame is the video\'s own', () {
    test('the frame is the plan\'s frame, and the text sits inside it', () async {
      for (final aspect in VideoAspect.all) {
        final painter = _painterFor(aspect);
        final frame = await painter.paint(slot: painter.plan.sentences[1]);
        expect(frame.image.width, aspect.width);
        expect(frame.image.height, aspect.height);

        final column = frame.column;
        // Margins on all four sides, and not token ones: the video is watched
        // at full screen without the app's padding around it. The width's own
        // margin is the fraction the column rule leaves (`maxColumnFraction`
        // leaves 4%), and the vertical margins are the tenth of the frame the
        // block is laid out inside.
        expect(column.left, greaterThanOrEqualTo(aspect.width * 0.02));
        expect(aspect.width - column.right,
            greaterThanOrEqualTo(aspect.width * 0.02));
        expect(column.top, greaterThanOrEqualTo(aspect.height * 0.04));
        expect(aspect.height - column.bottom,
            greaterThanOrEqualTo(aspect.height * 0.04));

        for (final line in frame.lines) {
          expect(line.left, greaterThanOrEqualTo(column.left - 0.01));
          expect(line.right, lessThanOrEqualTo(column.right + 0.01));
          expect(line.top, greaterThanOrEqualTo(column.top - 0.01));
          expect(line.bottom, lessThanOrEqualTo(column.bottom + 0.01));
        }
        frame.image.dispose();
      }
    });

    test('everything outside the column is the background and nothing else',
        () async {
      final painter = _painterFor(VideoAspect.landscape);
      final frame = await painter.paint(slot: painter.plan.sentences[1]);
      final rgba = await _pixels(frame.image);
      final column = frame.column;
      final width = painter.plan.width.toDouble();
      final height = painter.plan.height.toDouble();

      // No app bar, no buttons, no status bar, no letterbox, and none of the
      // reading page's chrome: the four bands around the text are the
      // background colour, all the way to the edges.
      final bands = <Rect>[
        Rect.fromLTRB(0, 0, column.left.floor() - 1, height),
        Rect.fromLTRB(column.right.ceil() + 1, 0, width, height),
        Rect.fromLTRB(0, 0, width, column.top.floor() - 1),
        Rect.fromLTRB(0, column.bottom.ceil() + 1, width, height),
      ];
      for (final band in bands) {
        expect(_dirt(rgba, painter.plan.width, band, _background), isNull,
            reason: 'something other than the background was painted at $band');
      }
      frame.image.dispose();
    });

    test('the column is derived from the frame, and a 16:9 column is the '
        'narrower', () {
      final landscape = _painterFor(VideoAspect.landscape);
      final vertical = _painterFor(VideoAspect.vertical);
      expect(
          landscape.column.width,
          closeTo(
              min(1920 * VideoPainter.maxColumnFraction,
                  1080 * VideoPainter.lineLengthGain),
              0.01));
      expect(
          vertical.column.width,
          closeTo(
              min(1080 * VideoPainter.maxColumnFraction,
                  1920 * VideoPainter.lineLengthGain),
              0.01));
      // A 16:9 frame still gets the narrower column, as a fraction of the frame:
      // the frame's own height is what a line is laid out inside (D6, A3).
      expect(landscape.column.width / 1920,
          lessThan(vertical.column.width / 1080));
    });
  });

  group('10-12. the reader\'s own appearance', () {
    // The four sizes the appearance screen offers (011 US2).
    const sizes = [12.0, 14.0, 18.0, 24.0];

    test('the painted height follows the reader\'s size by its ratio', () async {
      // One line's height, not the block's: the block would grow with wrapping
      // as well as with the size, and SC-011 is about the size reaching the
      // frame rather than about how the sentence happened to fall.
      final heights = <double>[];
      for (final size in sizes) {
        final painter = _painterFor(VideoAspect.landscape, fontSize: size);
        final frame = await painter.paint(slot: painter.plan.sentences[1]);
        heights.add(frame.lines.first.height);
        frame.image.dispose();
      }
      for (var i = 0; i < sizes.length; i++) {
        final expected = sizes[i] / sizes.first;
        final actual = heights[i] / heights.first;
        expect(actual, closeTo(expected, expected * 0.10),
            reason: 'text at ${sizes[i]} should stand ${expected}x the '
                '${sizes.first} one, and stood ${actual}x');
      }
    });

    test('the chosen typeface reaches the frame, and the size is never reduced '
        'for length', () async {
      final tall = _painterFor(VideoAspect.landscape, family: 'serif', tall: true);
      final frame = await tall.paint(slot: tall.plan.sentences.single);
      expect(frame.style.fontFamily, 'serif');
      // The reader's character size, mapped onto this frame (FR-014).
      expect(frame.style.fontSize, closeTo(14 * tall.scale, 0.01));

      // The same size as a short sentence at the same style: a long sentence
      // wraps and scrolls instead of shrinking (FR-029).
      final short = _painterFor(VideoAspect.landscape, family: 'serif');
      final shortFrame = await short.paint(slot: short.plan.sentences[1]);
      expect(frame.style.fontSize, closeTo(shortFrame.style.fontSize!, 0.01));
      frame.image.dispose();
      shortFrame.image.dispose();
    });

    test('two aspects differ in the frame, not in the type', () async {
      final landscape = _painterFor(VideoAspect.landscape, family: 'serif');
      final vertical = _painterFor(VideoAspect.vertical, family: 'serif');
      final a = await landscape.paint(slot: landscape.plan.sentences[1]);
      final b = await vertical.paint(slot: vertical.plan.sentences[1]);
      expect(a.style.fontFamily, b.style.fontFamily);
      expect(a.paintedText, b.paintedText);
      expect(a.image.width, isNot(b.image.width));
      a.image.dispose();
      b.image.dispose();
    });

    test('the glyph height and the line length clear the floor', () async {
      // The tightest case the app offers: `small` on the 1080-wide frame.
      final painter = _painterFor(VideoAspect.vertical, fontSize: 12);
      final frame = await painter.paint(slot: painter.plan.sentences[1]);
      final em = frame.style.fontSize!;
      final measure = painter.column.width / _layoutOf(painter, 'n').width;

      expect(em, greaterThanOrEqualTo(VideoPainter.minimumEm.toDouble()),
          reason: 'the smallest offered size must clear the legibility floor');
      expect(measure, greaterThanOrEqualTo(30),
          reason: 'a small size still gets a readable line (A3)');
      frame.image.dispose();
    });

    test('the floor is a real one, not a token', () {
      expect(VideoPainter.minimumEm, greaterThan(0));
      expect(VideoPainter.maxColumnFraction, lessThan(1));
      // The reader's rule of 2026-09-28, written down outside any spike's
      // record: the plate is the opposite of the picture's own tone, and the ink
      // is the opposite of the plate.
      expect(VideoPainter.plateOnLightPicture, const Color(0xFFFFFFFF));
      expect(VideoPainter.inkOnLightPicture, const Color(0xFF000000));
      expect(VideoPainter.plateOnDarkPicture, const Color(0xFF000000));
      expect(VideoPainter.inkOnDarkPicture, const Color(0xFFFFFFFF));
      expect(VideoPainter.lightPictureFloor, 0.5);

      // And the pair is the contrast a text needs, by construction — which is
      // what SC-004 asks of every frame (D16 as amended):
      expect(
        _contrast(VideoPainter.inkOnLightPicture, VideoPainter.plateOnLightPicture),
        greaterThanOrEqualTo(4.5),
        reason: 'black on white',
      );
      expect(
        _contrast(VideoPainter.inkOnDarkPicture, VideoPainter.plateOnDarkPicture),
        greaterThanOrEqualTo(4.5),
        reason: 'white on black',
      );
    });
  });

  group('46. a tall sentence wraps and scrolls a line at a time', () {
    test('the block moves one line per step, from its first line to its last',
        () async {
      final painter = _painterFor(VideoAspect.vertical, tall: true);
      final slot = painter.plan.sentences.single;
      final column = painter.column;
      final steps = _stepsOf(painter, slot.text);
      expect(steps, greaterThan(3),
          reason: 'the fixture must not fit: this is the scroll\'s own case');
      // The painter's own count, for the renderer: one picture per line step
      // means the renderer has to be able to ask how many there are (T046).
      expect(painter.scrollSteps(slot), steps);

      final onScreen = <int>{};
      VideoFrame? first;
      VideoFrame? previous;
      late VideoFrame last;
      for (var position = 0; position <= steps; position++) {
        // The positions are equal slices of the slot (D14): the block moves a
        // line at a time as the slot elapses, never a pixel at a time.
        final frame =
            await painter.paint(slot: slot, progress: position / (steps + 1));
        expect(frame.scrollLines, position,
            reason: 'at ${position / (steps + 1)} of the slot');
        expect(frame.paintedText, slot.text,
            reason: 'the whole sentence is drawn at every step');
        for (var line = 0; line < frame.lines.length; line++) {
          final box = frame.lines[line];
          if (box.top >= column.top - 0.01 &&
              box.bottom <= column.bottom + 0.01) {
            onScreen.add(line);
          }
        }
        if (previous != null) {
          // A step is exactly one line: the move the line height states.
          expect(
            previous.lines.first.top - frame.lines.first.top,
            closeTo(previous.lines.first.height, 0.5),
            reason: 'the move from step ${position - 1} to $position',
          );
          if (!identical(previous, first)) previous.image.dispose();
        }
        first ??= frame;
        previous = frame;
        last = frame;
      }

      // The first line starts at the area's top; the last line is inside the
      // area at the end; and every line is fully on screen at some step.
      expect(first!.lines.first.top, closeTo(column.top, 0.01));
      expect(last.lines.last.bottom, lessThanOrEqualTo(column.bottom + 0.01),
          reason: 'no line is clipped at the end');
      expect(last.lines.last.bottom,
          greaterThan(column.bottom - last.lines.last.height),
          reason: 'the last step is the bottom: the block stops there');
      for (var line = 0; line < first.lines.length; line++) {
        expect(onScreen, contains(line),
            reason: 'line $line is never fully on screen');
      }

      // And the canvas really moved: the same sentence is not the same picture
      // at the first position and at the last.
      expect(
          await _pixels(first.image), isNot(equals(await _pixels(last.image))));
      first.image.dispose();
      last.image.dispose();
    });

    test('a sentence that fits is still, whatever the progress', () async {
      final painter = _painterFor(VideoAspect.vertical);
      final slot = painter.plan.sentences[1];
      expect(painter.scrollSteps(slot), 0,
          reason: 'a sentence that fits has nothing to scroll');
      for (final progress in [0.0, 0.5, 1.0]) {
        final frame = await painter.paint(slot: slot, progress: progress);
        expect(frame.scrollLines, 0);
        expect(frame.lines.last.bottom,
            closeTo(painter.column.bottom, 0.01),
            reason: 'a sentence that fits sits at the bottom of the area — the '
                'reader\'s own request of 2026-09-28 — and it is the same place '
                'whatever the progress, which is what makes it still');
        frame.image.dispose();
      }
    });
  });

  group('44. a picture is read for its own tone (FR-027)', () {
    test('a light picture is light, a dark picture is dark', () async {
      expect(await pictureTone(await _solid(64, const Color(0xFFFFFFFF))),
          PictureTone.light);
      expect(await pictureTone(await _solid(64, const Color(0xFF000000))),
          PictureTone.dark);
    });

    test('the floor is where the rule puts it: half way', () async {
      // The average is the perceptual one, so mid grey sits on the floor —
      // 0.502 by the formula, which is light — and a hair under it is dark.
      expect(await pictureTone(await _solid(64, const Color(0xFF808080))),
          PictureTone.light);
      expect(await pictureTone(await _solid(64, const Color(0xFF7F7F7F))),
          PictureTone.dark);
      expect(VideoPainter.lightPictureFloor, 0.5);
    });
  });

  group('44-c. the tone is read where the words are (FR-027, D16)', () {
    // The reader's own case of 2026-09-28: with the whole picture deciding, the
    // words over a dark part of a bright photograph — or the other way round —
    // are plated in the opposite of what is behind them. The band the painted
    // lines cover is what the plate has to match.
    const dark = Color(0xFF101010);
    const bright = Color(0xFFF0F0F0);

    test('a band reads the band, not the picture', () {
      final pixels = _twoBands(dark, bright);

      expect(
          toneOfPixels(rgba: pixels, width: 100, height: 100,
              bands: const [Rect.fromLTWH(0, 0, 100, 40)]),
          PictureTone.dark,
          reason: 'the top band is the dark one');
      expect(
          toneOfPixels(rgba: pixels, width: 100, height: 100,
              bands: const [Rect.fromLTWH(0, 60, 100, 40)]),
          PictureTone.light,
          reason: 'the bottom band is the bright one');
      expect(toneOfPixels(rgba: pixels, width: 100, height: 100),
          PictureTone.light,
          reason: 'the picture as a whole averages to light — most of it is '
              'bright — which is the answer that was wrong while the words were '
              'over the dark half');
    });

    test('a band outside the picture has nothing to read, and the rest answer',
        () {
      final pixels = _twoBands(dark, bright);

      expect(
          toneOfPixels(rgba: pixels, width: 100, height: 100,
              bands: const [Rect.fromLTWH(300, 300, 10, 10)]),
          PictureTone.dark,
          reason: 'no pixels at all is dark: the pair a text can always read on');
      expect(
          toneOfPixels(rgba: pixels, width: 100, height: 100,
              bands: const [
                Rect.fromLTWH(300, 300, 10, 10),
                Rect.fromLTWH(0, 60, 100, 40),
              ]),
          PictureTone.light,
          reason: 'and the band that does have pixels in it is still read');
    });

    test('the words\' own band decides the plate, though the picture is light',
        () async {
      final painter = _painterFor(VideoAspect.vertical);
      final slot = painter.plan.sentences.first;

      // The frame is 1080×1920 and the picture is its own shape, so the cover
      // draw is a plain scale and the sentence's band — the **bottom** of the text
      // area, where a sentence that fits now sits (2026-09-28) — is the dark fifth
      // of the picture, while the picture as a whole is mostly bright.
      final picture = await _banded(bright, dark, fraction: 0.8);
      expect(await pictureTone(picture), PictureTone.light,
          reason: 'the picture as a whole reads light');
      final frame = await painter.paint(slot: slot, picture: picture);

      expect(frame.tone, PictureTone.dark,
          reason: 'but the words sit in the dark band, and the band is what the '
              'plate has to match');
      expect(frame.plateColour, VideoPainter.plateOnDarkPicture);
      expect(frame.inkColour, VideoPainter.inkOnDarkPicture);
      for (final plate in frame.plates) {
        expect(plate.bottom, greaterThan(painter.plan.height * 0.8),
            reason: 'the plates are inside the band the tone was read from — the '
                'bottom of the frame, where the words are — which is what makes '
                'the two one claim');
      }

      // Drawn, not merely reported: the black plate is on the frame's pixels.
      final rgba = await _pixels(frame.image);
      final width = frame.image.width;
      var black = 0;
      for (var y = frame.plates.first.top.round();
          y < frame.plates.first.bottom.round();
          y++) {
        for (var x = frame.plates.first.left.round();
            x < frame.plates.first.right.round();
            x++) {
          if (_at(rgba, width, x, y) == VideoPainter.plateOnDarkPicture) black++;
        }
      }
      expect(black, greaterThan(0),
          reason: 'the plate the frame reports is the plate it drew');

      picture.dispose();
      frame.image.dispose();
    });

    test('and the other way round: a bright band over a dark picture', () async {
      final painter = _painterFor(VideoAspect.vertical);
      // Dark all over, with a bright band at the bottom, where the words sit.
      final picture = await _banded(dark, bright, fraction: 0.8);
      expect(await pictureTone(picture), PictureTone.dark,
          reason: 'the picture as a whole reads dark');
      final frame = await painter.paint(
          slot: painter.plan.sentences.first, picture: picture);

      expect(frame.tone, PictureTone.light,
          reason: 'the words are over the bright band');
      expect(frame.plateColour, VideoPainter.plateOnLightPicture);
      expect(frame.inkColour, VideoPainter.inkOnLightPicture);

      picture.dispose();
      frame.image.dispose();
    });
  });

  group('44-45. the picture, its tone, and the plate', () {
    test('the picture fills the frame in its own colours — no bars, no veil',
        () async {
      final painter = _painterFor(VideoAspect.vertical);
      final picture = await _quadrants();
      final frame = await painter.paint(
          slot: painter.plan.sentences[1], picture: picture);
      final rgba = await _pixels(frame.image);
      final w = frame.image.width, h = frame.image.height;

      // The picture is 2:1 into a 9:16 frame, so it is scaled to the frame's
      // height and cropped left and right: the frame's corners come from the
      // picture's four quadrants **exactly** — nothing is laid over them, which
      // is the reader's own requirement of 2026-09-28 ("Don't do any change to
      // the background images's color", FR-027). A bar anywhere would show the
      // plain background instead, and a veil would show a mixture.
      const margin = 12;
      final cases = <(int, int, Color, String)>[
        (margin, margin, const Color(0xFFFF0000), 'top-left/red'),
        (w - margin, margin, const Color(0xFF00FF00), 'top-right/green'),
        (margin, h - margin, const Color(0xFF0000FF), 'bottom-left/blue'),
        (w - margin, h - margin, const Color(0xFFFFFF00), 'bottom-right/yellow'),
      ];
      for (final (x, y, colour, what) in cases) {
        final found = _at(rgba, w, x, y);
        expect(_near(found, colour), isTrue,
            reason: '$what must keep the picture colour '
                '${colour.toARGB32().toRadixString(16)}, and read '
                '${found.toARGB32().toRadixString(16)}');
      }
      expect(frame.picture, same(picture));
      frame.image.dispose();
    });

    test('a light picture gets black text on a white plate', () async {
      final painter = _painterFor(VideoAspect.vertical);
      // A light picture that is not white, so the plates it earns are the only
      // white in the frame: the reader's rule of 2026-09-28, read off the frame
      // itself (FR-027).
      final picture = await _solid(400, _lightPicture);
      final frame = await painter.paint(
          slot: painter.plan.sentences[1], picture: picture);
      final rgba = await _pixels(frame.image);
      final w = frame.image.width, h = frame.image.height;

      expect(frame.tone, PictureTone.light);
      expect(frame.plateColour, VideoPainter.plateOnLightPicture);
      expect(frame.inkColour, VideoPainter.inkOnLightPicture);

      // FR-027 says *the line's own box*, and that is what the frame reports:
      // the device row and this test read the same geometry.
      expect(frame.plates, equals(frame.lines),
          reason: 'one plate per painted line, exactly the line\'s own box');

      final whiteInPlates = List.filled(frame.plates.length, 0);
      var outside = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (_at(rgba, w, x, y) != VideoPainter.plateOnLightPicture) continue;
          final which = frame.plates.indexWhere((p) => p.contains(
              Offset(x.toDouble() + 0.5, y.toDouble() + 0.5)));
          if (which < 0) {
            outside++;
          } else {
            whiteInPlates[which]++;
          }
        }
      }
      expect(outside, 0,
          reason: 'the picture is untouched everywhere but behind the lines');
      for (var i = 0; i < whiteInPlates.length; i++) {
        expect(whiteInPlates[i], greaterThan(0),
            reason: 'every plate the frame reports is drawn: line $i has '
                '${whiteInPlates[i]} white pixels (all: $whiteInPlates)');
      }
      frame.image.dispose();
    });

    test('a dark picture gets white text on a black plate', () async {
      final painter = _painterFor(VideoAspect.vertical);
      // A dark picture that is not black, so the plates it earns are the only
      // black in the frame (FR-027).
      final picture = await _solid(400, _darkPicture);
      final frame = await painter.paint(
          slot: painter.plan.sentences[1], picture: picture);
      final rgba = await _pixels(frame.image);
      final w = frame.image.width, h = frame.image.height;

      expect(frame.tone, PictureTone.dark);
      expect(frame.plateColour, VideoPainter.plateOnDarkPicture,
          reason: 'the plate is the opposite of the picture\'s own tone');
      expect(frame.inkColour, VideoPainter.inkOnDarkPicture);

      var outside = 0;
      final blackInPlates = List.filled(frame.plates.length, 0);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (_at(rgba, w, x, y) != VideoPainter.plateOnDarkPicture) continue;
          final which = frame.plates.indexWhere((p) => p.contains(
              Offset(x.toDouble() + 0.5, y.toDouble() + 0.5)));
          if (which < 0) {
            outside++;
          } else {
            blackInPlates[which]++;
          }
        }
      }
      expect(outside, 0,
          reason: 'the picture is untouched everywhere but behind the lines');
      for (var i = 0; i < blackInPlates.length; i++) {
        expect(blackInPlates[i], greaterThan(0),
            reason: 'every plate the frame reports is drawn: line $i has '
                '${blackInPlates[i]} black pixels (all: $blackInPlates)');
      }
      frame.image.dispose();
    });

    test('the words are the same words over any picture', () async {
      final painter = _painterFor(VideoAspect.vertical);
      final light = await painter.paint(
          slot: painter.plan.sentences[1],
          picture: await _solid(200, _lightPicture));
      final dark = await painter.paint(
          slot: painter.plan.sentences[1],
          picture: await _solid(200, _darkPicture));
      final withoutPicture =
          await painter.paint(slot: painter.plan.sentences[1]);

      // The picture changes what is behind the words — the plate and the ink —
      // never the words themselves or where they sit: the same text, laid out in
      // the same places, and the tone alone chooses the colours (FR-027).
      for (final frame in [light, dark]) {
        expect(frame.paintedText, withoutPicture.paintedText);
        expect(frame.lines, withoutPicture.lines);
      }
      expect(light.inkColour, isNot(dark.inkColour),
          reason: 'a light picture and a dark one cannot draw the same ink: '
              'each plate takes the opposite of its picture');
      expect(withoutPicture.plates, isEmpty,
          reason: 'with no picture there is nothing to protect the text from');
      expect(withoutPicture.inkColour, _ink,
          reason: 'and the words are the reader\'s own colour (FR-028)');
      light.image.dispose();
      dark.image.dispose();
      withoutPicture.image.dispose();
    });

    test('the ink reaches the canvas over the plate', () async {
      final painter = _painterFor(VideoAspect.vertical);
      final frame = await painter.paint(
          slot: painter.plan.sentences[1],
          picture: await _solid(200, _darkPicture));

      // Over a dark picture the ink is white, and it is drawn on the plate: the
      // first line's own box holds pixels that are the ink and not the plate.
      final rgba = await _pixels(frame.image);
      final band = frame.lines.first;
      var inkPixels = 0;
      for (var y = band.top.round(); y < band.bottom.round(); y++) {
        for (var x = band.left.round(); x < band.right.round(); x++) {
          if (_at(rgba, frame.image.width, x, y) == frame.inkColour) inkPixels++;
        }
      }
      expect(inkPixels, greaterThan(0),
          reason: 'the sentence must be painted over the plate, in the ink the '
              'tone called for');
      frame.image.dispose();
    });

    test('nothing chosen is a valid schedule — the plain background', () async {
      final painter = _painterFor(VideoAspect.vertical);
      final frame = await painter.paint(slot: painter.plan.sentences[1]);
      expect(frame.picture, isNull);
      expect(frame.paintedText, painter.plan.sentences[1].text);

      // Above the text it is the app's plain background: no picture, no plate,
      // and nothing delayed for want of one (FR-028).
      final rgba = await _pixels(frame.image);
      final top = Rect.fromLTRB(
          0, 0, frame.image.width.toDouble(), frame.column.top.floor() - 1);
      expect(_dirt(rgba, frame.image.width, top, _background), isNull,
          reason: 'with no picture the frame is the app\'s plain background');
      frame.image.dispose();
    });
  });
}
