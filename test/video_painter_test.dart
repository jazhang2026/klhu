/// The frame painter (spec 012 US1): quickstart scenarios 7 and 9 — a frame per
/// slot with the highlight over exactly that slot's sentence, the text inside
/// the frame's margins, and nothing of the app or the device in the picture.
///
/// This file defines the API it tests: `lib/video_painter.dart` does not exist
/// yet (T006 is written before T010 implements it).
///
/// The paint claim is a pixel claim, so some assertions read the frame's own
/// bytes — but only the ones that are about *paint*: what the text says, where
/// it sits and which span is highlighted are asserted on the painter's own
/// geometry, which does not care which font the test host has installed.
library;

import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_timeline.dart';

const _content = 'One two. Three four.\n\n清晨的阳光。鸟儿歌唱。';

/// Deliberately not the app's colours: a frame the test can read back without
/// depending on the theme.
const _background = Color(0xFF101014);
const _highlight = Color(0xFFFFFF00);
const _ink = Color(0xFFF2F2F2);
const _style = TextStyle(fontSize: 14, color: _ink);

/// Two paragraphs, one per language: the frame shows the paragraph a sentence
/// belongs to, so a mixed content is what proves the window follows the slot.
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

final _plan = buildVideoPlan(
  title: 'Mixed',
  sentences: _sentences,
  audioMs: List.filled(_sentences.length, 1000),
  aspect: VideoAspect.landscape,
);

VideoPainter _painter() => VideoPainter(
      plan: _plan,
      readingStyle: _style,
      background: _background,
      highlight: _highlight,
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

/// True when every sampled pixel in the rectangle is [colour]. Sampled on a
/// stride: these bands are thousands of pixels wide and this is a test.
bool _bandIs(Uint8List rgba, int width, Rect rect, Color colour,
    {int stride = 4}) {
  for (var y = rect.top.round(); y < rect.bottom.round(); y += stride) {
    for (var x = rect.left.round(); x < rect.right.round(); x += stride) {
      if (_at(rgba, width, x, y) != colour) return false;
    }
  }
  return true;
}

/// The count of sampled pixels in [rect] that are [colour].
int _countOf(Uint8List rgba, int width, Rect rect, Color colour,
    {int stride = 2}) {
  var hits = 0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += stride) {
    for (var x = rect.left.round(); x < rect.right.round(); x += stride) {
      if (_at(rgba, width, x, y) == colour) hits++;
    }
  }
  return hits;
}

/// The same plan at another aspect.
VideoPlan _planFor(VideoAspect aspect) => buildVideoPlan(
      title: 'Mixed',
      sentences: _sentences,
      audioMs: List.filled(_sentences.length, 1000),
      aspect: aspect,
    );

/// A painter over [aspect] at the reader's own style — the four sizes the
/// appearance screen offers are 12/14/18/24, so the tests use those numbers.
VideoPainter _painterFor(
  VideoAspect aspect, {
  double fontSize = 14,
  String? family,
  String Function(String language)? languageLabel,
}) =>
    VideoPainter(
      plan: _planFor(aspect),
      readingStyle: TextStyle(fontSize: fontSize, color: _ink, fontFamily: family),
      background: _background,
      highlight: _highlight,
      languageLabel: languageLabel,
    );

/// The average advance of one character in [style] — what turns a column width
/// into a line length (the measure).
double _advanceOf(TextStyle style, String sample) {
  final painter = TextPainter(
    text: TextSpan(text: sample, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width / sample.length;
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

void main() {
  group('7. the highlight is the sentence being heard', () {
    test('a sentence slot highlights exactly that sentence', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[1]);
      expect(frame.paintedText, 'One two. Three four.');
      expect(frame.highlightRange, const TextRange(start: 9, end: 20));
      expect(frame.highlight, isNotNull);
      expect(frame.slot.text, 'Three four.');
    });

    test('two sentences of one paragraph highlight two different spans', () async {
      final painter = _painter();
      final first = await painter.paint(content: _content, slot: _plan.sentences[0]);
      final second = await painter.paint(content: _content, slot: _plan.sentences[1]);

      expect(first.paintedText, second.paintedText);
      expect(first.highlightRange, const TextRange(start: 0, end: 8));
      expect(second.highlightRange, const TextRange(start: 9, end: 20));
      expect(first.highlight, isNot(equals(second.highlight)));
    });

    test('a sentence in another language highlights its own paragraph', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[3]);
      expect(frame.paintedText, '清晨的阳光。鸟儿歌唱。');
      // 清晨的阳光。 is six characters, so its sibling starts at six.
      expect(frame.highlightRange, const TextRange(start: 6, end: 11));
    });

    test('the highlight stays inside the text column', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[1]);
      final column = frame.column;
      final band = frame.highlight!;
      expect(band.left, greaterThanOrEqualTo(column.left));
      expect(band.right, lessThanOrEqualTo(column.right + 0.01));
      expect(band.top, greaterThanOrEqualTo(column.top));
      expect(band.bottom, lessThanOrEqualTo(column.bottom + 0.01));
      expect(band.width, greaterThan(0));
      expect(band.height, greaterThan(0));
    });

    test('the title card names the content and highlights nothing', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.slots.first);
      expect(frame.slot.kind, VideoSlotKind.title);
      expect(frame.paintedText, 'Mixed');
      expect(frame.highlight, isNull);
      expect(frame.highlightRange, isNull);
    });
  });

  group('9. the frame carries no chrome and the text has margins', () {
    test('the frame is the plan\'s frame, and the text sits inside it', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[1]);
      expect(frame.image.width, _plan.width);
      expect(frame.image.height, _plan.height);

      final column = frame.column;
      // Margins on all four sides, and not token ones: the video is watched at
      // full screen without the app's padding around it.
      expect(column.left, greaterThan(_plan.width * 0.04));
      expect(_plan.width - column.right, greaterThan(_plan.width * 0.04));
      expect(column.top, greaterThan(_plan.height * 0.04));
      expect(_plan.height - column.bottom, greaterThan(_plan.height * 0.04));

      for (final line in frame.lineBoxes) {
        expect(line.left, greaterThanOrEqualTo(column.left - 0.01));
        expect(line.right, lessThanOrEqualTo(column.right + 0.01));
        expect(line.top, greaterThanOrEqualTo(column.top - 0.01));
        expect(line.bottom, lessThanOrEqualTo(column.bottom + 0.01));
      }
    });

    test('everything outside the column is the background and nothing else',
        () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[1]);
      final rgba = await _pixels(frame.image);
      final column = frame.column;

      // No app bar, no buttons, no status bar, no letterbox: the four bands
      // around the text are the background colour, all the way to the edges.
      final bands = <Rect>[
        Rect.fromLTRB(0, 0, column.left, _plan.height.toDouble()),
        Rect.fromLTRB(column.right, 0, _plan.width.toDouble(), _plan.height.toDouble()),
        Rect.fromLTRB(0, 0, _plan.width.toDouble(), column.top),
        Rect.fromLTRB(0, column.bottom, _plan.width.toDouble(), _plan.height.toDouble()),
      ];
      for (final band in bands) {
        expect(_bandIs(rgba, _plan.width, band, _background), isTrue,
            reason: 'something other than the background was painted at $band');
      }
    });

    test('the highlight is painted, and only where it belongs', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.sentences[1]);
      final rgba = await _pixels(frame.image);
      final band = frame.highlight!;

      expect(_countOf(rgba, _plan.width, band, _highlight), greaterThan(0));
      // Outside the column there is no highlight at all (FR-006: the video is
      // the app's own picture, and that picture has no chrome in it).
      final outside = Rect.fromLTRB(
          frame.column.right + 1, 0, _plan.width.toDouble(), _plan.height.toDouble());
      expect(_countOf(rgba, _plan.width, outside, _highlight), 0);
    });
  });

  group('8. the video opens with a title card naming the content', () {
    test('the card carries the content\'s name and the language it is read in',
        () async {
      final asked = <String>[];
      final painter = _painterFor(VideoAspect.landscape, languageLabel: (language) {
        asked.add(language);
        return language == 'en' ? 'English' : language;
      });
      final frame =
          await painter.paint(content: _content, slot: painter.plan.slots.first);

      expect(frame.slot.kind, VideoSlotKind.title);
      expect(frame.paintedText, 'Mixed\nEnglish');
      // The language the video opens in: its first spoken sentence's.
      expect(asked, ['en']);
      expect(frame.highlight, isNull);
      expect(frame.highlightRange, isNull);
    });

    test('the card is the name alone when no label is given', () async {
      final frame = await _painter().paint(content: _content, slot: _plan.slots.first);
      expect(frame.paintedText, 'Mixed');
      expect(frame.highlight, isNull);
    });

    test('the first sentence\'s frame is not the card', () async {
      final card = await _painter().paint(content: _content, slot: _plan.slots.first);
      final first = await _painter().paint(content: _content, slot: _plan.sentences.first);
      expect(first.paintedText, isNot(card.paintedText));
      expect(first.highlight, isNotNull);
      expect(first.highlightRange, const TextRange(start: 0, end: 8));
    });

    test('the label is painted smaller than the name', () {
      // The card is two sizes — the name, and its language under it — so the
      // ratio has to be a real one rather than equal to the name.
      expect(VideoPainter.titleLabelScale, greaterThan(0.1));
      expect(VideoPainter.titleLabelScale, lessThan(0.9));
    });
  });

  group('10. each aspect\'s frames are that aspect\'s frame', () {
    test('the frame measures the aspect exactly', () async {
      for (final aspect in VideoAspect.all) {
        final painter = _painterFor(aspect);
        final frame =
            await painter.paint(content: _content, slot: painter.plan.sentences[1]);
        expect(frame.image.width, aspect.width);
        expect(frame.image.height, aspect.height);
      }
    });

    test('the column is derived from the frame, and a 16:9 column is the narrower',
        () {
      final landscape = _painterFor(VideoAspect.landscape);
      final vertical = _painterFor(VideoAspect.vertical);
      expect(landscape.column.width, closeTo(min(1920 * 0.88, 1080), 0.01));
      expect(vertical.column.width, closeTo(min(1080 * 0.88, 1920), 0.01));
      // A column narrower than its frame is tall would set a line too long for
      // the eye in one go; a 16:9 frame therefore gets the narrower column
      // (research D6, FR-014/A3).
      expect(landscape.column.width / 1920,
          lessThan(vertical.column.width / 1080));
    });

    test('the text sits inside the column with margins, in both aspects',
        () async {
      for (final aspect in VideoAspect.all) {
        final painter = _painterFor(aspect);
        final frame =
            await painter.paint(content: _content, slot: painter.plan.sentences[1]);
        final column = frame.column;
        expect(column.left, greaterThan(aspect.width * 0.04));
        expect(aspect.width - column.right, greaterThan(aspect.width * 0.04));
        expect(column.top, greaterThan(aspect.height * 0.04));
        expect(aspect.height - column.bottom, greaterThan(aspect.height * 0.04));
        for (final line in frame.lineBoxes) {
          expect(line.left, greaterThanOrEqualTo(column.left - 0.01));
          expect(line.right, lessThanOrEqualTo(column.right + 0.01));
        }
        // The margins are the background to the edges, in this aspect too. The
        // one pixel either side of the column's own edge is antialiased by the
        // clip itself, so the claim is about the margin beyond that edge.
        final rgba = await _pixels(frame.image);
        expect(
            _dirt(
                rgba,
                aspect.width,
                Rect.fromLTRB(
                    0, 0, column.left.floor() - 1, aspect.height.toDouble()),
                _background),
            isNull,
            reason: 'the ${aspect.name} frame\'s left margin');
        expect(
            _dirt(
                rgba,
                aspect.width,
                Rect.fromLTRB(0, column.bottom.ceil() + 1,
                    aspect.width.toDouble(), aspect.height.toDouble()),
                _background),
            isNull,
            reason: 'the ${aspect.name} frame\'s bottom margin');
      }
    });
  });

  group('11. the video\'s text is the reader\'s own typeface and size', () {
    // The four sizes the appearance screen offers (011 US2).
    const sizes = [12.0, 14.0, 18.0, 24.0];

    test('the painted height follows the reader\'s size by its ratio', () async {
      // One line's height, not the block's: the block would grow with wrapping
      // as well as with the size, and SC-011 is about the size reaching the
      // frame rather than about how the paragraph happened to fall.
      final heights = <double>[];
      for (final size in sizes) {
        final painter = _painterFor(VideoAspect.landscape, fontSize: size);
        final frame =
            await painter.paint(content: _content, slot: painter.plan.sentences[1]);
        heights.add(frame.lineBoxes.first.height);
      }
      for (var i = 0; i < sizes.length; i++) {
        final expected = sizes[i] / sizes.first;
        final actual = heights[i] / heights.first;
        expect(actual, closeTo(expected, expected * 0.10),
            reason: 'text at ${sizes[i]} should stand ${expected}x the '
                '${sizes.first} one, and stood ${actual}x');
      }
    });

    test('the chosen typeface reaches the frame', () async {
      final painter = _painterFor(VideoAspect.landscape, family: 'serif');
      final frame =
          await painter.paint(content: _content, slot: painter.plan.sentences[1]);
      expect(frame.style.fontFamily, 'serif');
      // The reader's character size, mapped onto this frame (FR-014): not
      // overridden by the video.
      expect(frame.style.fontSize, closeTo(14 * painter.scale, 0.01));
    });

    test('two aspects differ in the frame, not in the type', () async {
      final landscape = _painterFor(VideoAspect.landscape, family: 'serif');
      final vertical = _painterFor(VideoAspect.vertical, family: 'serif');
      final a = await landscape.paint(content: _content, slot: landscape.plan.sentences[1]);
      final b = await vertical.paint(content: _content, slot: vertical.plan.sentences[1]);
      expect(a.style.fontFamily, b.style.fontFamily);
      expect(a.paintedText, b.paintedText);
      expect(a.highlightRange, b.highlightRange);
      expect(a.image.width, isNot(b.image.width));
    });
  });

  group('12. the smallest size is still legible on the smallest column', () {
    test('the glyph height and the line length clear the floor', () async {
      // The tightest case the app offers: `small` on the 1080-wide frame.
      final painter = _painterFor(VideoAspect.vertical, fontSize: 12);
      final frame =
          await painter.paint(content: _content, slot: painter.plan.sentences[1]);
      final em = frame.style.fontSize!;
      final measure = painter.column.width / _advanceOf(frame.style, 'n');
      // Deliberate: the floor's own numbers are worth seeing in the log when
      // this test is the one that fails.
      // ignore: avoid_print
      print('vertical/small: em=${em.toStringAsFixed(1)}px, '
          'measure=${measure.toStringAsFixed(1)} chars, '
          'column=${painter.column.width.toStringAsFixed(0)}px');

      expect(em, greaterThanOrEqualTo(VideoPainter.minimumEm.toDouble()),
          reason: 'the smallest offered size must clear the legibility floor');
      expect(measure, greaterThanOrEqualTo(30),
          reason: 'a small size still gets a readable line (A3)');
    });

    test('the floor is a real one, not a token', () {
      expect(VideoPainter.minimumEm, greaterThan(0));
      expect(VideoPainter.maxColumnFraction, lessThan(1));
    });
  });
}
