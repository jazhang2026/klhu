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
}
