/// The frame the motion is drawn through (spec 023 US1): quickstart scenario 5 —
/// the picture is drawn through the window it is handed, the framing at rest is
/// the inset one (`FR-013`), a moved window moves the picture inside the frame,
/// and **the words and their plates do not move at all** (`FR-007`, `SC-004`).
///
/// The picture is a four-quadrant plate whose two colour boundaries sit at a
/// quarter of its width and a third of its height — off-centre on purpose, so a
/// pan moves a boundary and a zoom moves it too (a centred boundary is invisible
/// under a centre-anchored zoom). The frame's own bytes are the evidence: the
/// boundary's position in the frame *is* the window's position, scaled by the
/// frame's own ratio.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_motion.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_timeline.dart';

/// The picture's own size: a 4:3 photo at a tenth of the fixture the device row
/// pushes, so the decode is cheap and every ratio is the same one.
const int _pictureWidth = 403;
const int _pictureHeight = 302;

/// Where its two colour boundaries sit: a quarter across, a third down.
const int _quarterX = _pictureWidth ~/ 4;

const _red = [255, 0, 0];
const _green = [0, 255, 0];
const _blue = [0, 0, 255];
const _yellow = [255, 255, 0];

/// The cover crop `_coverSource` returns for this picture in the 1920×1080 frame.
final Rect _cover = coverSourceOf(
  pictureWidth: _pictureWidth,
  pictureHeight: _pictureHeight,
  frameWidth: VideoAspect.landscape.width,
  frameHeight: VideoAspect.landscape.height,
);

/// `FR-013`'s inset framing: the cover crop deflated by a twelfth per side — the
/// rule the module owns, restated here so the painter's case does not rest on it.
Rect get _inset => Rect.fromLTRB(
      _cover.left + _cover.width / 12,
      _cover.top + _cover.height / 12,
      _cover.right - _cover.width / 12,
      _cover.bottom - _cover.height / 12,
    );

final _sentences = videoSentencesOf(const [
  ParagraphSpeech(
      text: 'One two. Three four.', language: 'en', voice: null, start: 0, end: 20),
]);

VideoPlan get _plan => buildVideoPlan(
      sentences: _sentences,
      audioMs: List.filled(_sentences.length, 3000),
      aspect: VideoAspect.landscape,
    );

VideoPainter get _painter => VideoPainter(
      plan: _plan,
      readingStyle: const TextStyle(fontSize: 14, color: Color(0xFFF2F2F2)),
      background: const Color(0xFF101014),
    );

/// Four quadrants, with the vertical boundary at a quarter of the width and the
/// horizontal one at a third of the height.
Future<ui.Image> _quadrants() {
  final bytes = Uint8List(_pictureWidth * _pictureHeight * 4);
  final splitY = _pictureHeight ~/ 3;
  for (var y = 0; y < _pictureHeight; y++) {
    for (var x = 0; x < _pictureWidth; x++) {
      final rgb = x < _quarterX
          ? (y < splitY ? _red : _blue)
          : (y < splitY ? _green : _yellow);
      final i = (y * _pictureWidth + x) * 4;
      bytes[i] = rgb[0];
      bytes[i + 1] = rgb[1];
      bytes[i + 2] = rgb[2];
      bytes[i + 3] = 255;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, _pictureWidth, _pictureHeight,
      ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// The first column of [row] whose colour is no longer the picture's top-left
/// one: the frame's own reading of where the window's left edge put it.
int _boundaryColumn(Uint8List rgba, int width, int row) {
  final first = (row * width) * 4;
  for (var x = 1; x < width; x++) {
    final i = (row * width + x) * 4;
    if ((rgba[i] - rgba[first]).abs() > 8 ||
        (rgba[i + 1] - rgba[first + 1]).abs() > 8 ||
        (rgba[i + 2] - rgba[first + 2]).abs() > 8) {
      return x;
    }
  }
  return -1;
}

/// The first row of [column] whose colour is no longer the picture's top-left
/// one.
int _boundaryRow(Uint8List rgba, int width, int height, int column) {
  final first = column * 4;
  for (var y = 1; y < height; y++) {
    final i = (y * width + column) * 4;
    if ((rgba[i] - rgba[first]).abs() > 8 ||
        (rgba[i + 1] - rgba[first + 1]).abs() > 8 ||
        (rgba[i + 2] - rgba[first + 2]).abs() > 8) {
      return y;
    }
  }
  return -1;
}

void main() {
  group('5. the frame shows the window, and the words and their plates do not move',
      () {
    test('the resting framing is the inset one, not the cover crop (FR-013)',
        () async {
      final picture = await _quadrants();
      final painter = _painter;
      final slot = painter.plan.sentences.first;

      // The off path: no framing, so the cover crop, exactly as today.
      final cover = await painter.paint(slot: slot, picture: picture);
      final coverPixels = await _pixels(cover.image);
      final coverColumn = _boundaryColumn(
          coverPixels, cover.image.width, cover.image.height ~/ 10);
      final coverRow = _boundaryRow(coverPixels, cover.image.width,
          cover.image.height, cover.image.width ~/ 100);

      // The on path, at its own resting frame.
      final rested = await painter.paint(
        slot: slot,
        picture: picture,
        framing: MotionFraming(source: _inset, rest: _inset),
      );
      final restedPixels = await _pixels(rested.image);
      final restedColumn = _boundaryColumn(
          restedPixels, rested.image.width, rested.image.height ~/ 10);
      final restedRow = _boundaryRow(restedPixels, rested.image.width,
          rested.image.height, rested.image.width ~/ 100);

      // The arithmetic the quickstart quotes: a quarter of the width and a third
      // of the height, mapped through the framing the frame was drawn with.
      expect(coverColumn, closeTo(480, 4));
      expect(coverRow, closeTo(300, 4));
      expect(restedColumn, closeTo(384, 4));
      expect(restedRow, closeTo(252, 4));
      expect(restedColumn, lessThan(coverColumn));
      expect(restedRow, lessThan(coverRow));
      cover.image.dispose();
      rested.image.dispose();
    });

    test('a moved window moves the picture inside the frame', () async {
      final picture = await _quadrants();
      final painter = _painter;
      final slot = painter.plan.sentences.first;
      // The drawn window at a cycle's peak, shifted right and down by the
      // frame's own tenth on each axis (the extreme `FR-003` allows).
      final shifted = _inset.shift(Offset(_inset.width / 10, _inset.height / 10));
      final frame = await painter.paint(
        slot: slot,
        picture: picture,
        framing: MotionFraming(source: shifted, rest: _inset),
      );
      final pixels = await _pixels(frame.image);
      expect(
          _boundaryColumn(pixels, frame.image.width, frame.image.height ~/ 10),
          closeTo(192, 6));
      expect(
          _boundaryRow(pixels, frame.image.width, frame.image.height,
              frame.image.width ~/ 100),
          closeTo(144, 6));
      frame.image.dispose();
    });

    test('the words and their plates are byte-identical while the picture moves',
        () async {
      final picture = await _quadrants();
      final painter = _painter;
      final slot = painter.plan.sentences.first;
      final shifted = _inset.shift(Offset(-_inset.width / 10, 0));
      final rested = await painter.paint(
        slot: slot,
        picture: picture,
        framing: MotionFraming(source: _inset, rest: _inset),
      );
      final moved = await painter.paint(
        slot: slot,
        picture: picture,
        framing: MotionFraming(source: shifted, rest: _inset),
      );

      expect(moved.plates, rested.plates,
          reason: 'the plate rects are the same box in both frames');
      expect(moved.inkColour, rested.inkColour);
      expect(moved.plateColour, rested.plateColour,
          reason: 'the tone is read at rest, so the plate cannot flip mid-slot');

      final a = await _pixels(rested.image);
      final b = await _pixels(moved.image);
      final width = rested.image.width;
      var compared = 0;
      for (final plate in rested.plates) {
        for (var y = plate.top.round(); y < plate.bottom.round(); y++) {
          for (var x = plate.left.round(); x < plate.right.round(); x++) {
            final i = (y * width + x) * 4;
            expect(b[i], a[i], reason: 'red at $x,$y inside a plate');
            expect(b[i + 1], a[i + 1], reason: 'green at $x,$y inside a plate');
            expect(b[i + 2], a[i + 2], reason: 'blue at $x,$y inside a plate');
            compared++;
          }
        }
      }
      expect(compared, greaterThan(0),
          reason: 'the slot must carry a plate, or this case proves nothing');
      rested.image.dispose();
      moved.image.dispose();
    });

    test('with no framing the picture is the cover crop, pixel for pixel',
        () async {
      final picture = await _quadrants();
      final painter = _painter;
      final slot = painter.plan.sentences.first;
      final plain = await painter.paint(slot: slot, picture: picture);
      final explicit = await painter.paint(
        slot: slot,
        picture: picture,
        framing: MotionFraming(source: _cover, rest: _cover),
      );
      final a = await _pixels(plain.image);
      final b = await _pixels(explicit.image);
      expect(b, a,
          reason: 'the off path and an explicit cover framing are one draw');
      plain.image.dispose();
      explicit.image.dispose();
    });
  });
}
