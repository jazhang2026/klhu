/// The motion's own rule (spec 023 US1/US2/US4): quickstart scenarios 1–4 — the
/// inset framing the frame's tenth is measured on, the ten directions, the bound
/// on both axes read in the picture's and the frame's own pixels, the return to
/// the framing a cycle started from, and one clock per picture across sentences.
///
/// The rule is arithmetic, so these cases need no canvas, no device and no
/// render: a [PictureMotion] is built from a cover rect and a frame range, and
/// every claim is read off `windowAt`. The `Random` is seeded here on purpose —
/// the product is unseeded (the spec refuses a reproducibility rule), and a
/// seeded draw is what lets a case assert exact pixels.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/video_motion.dart';

/// The cover crop of a 4032×3024 photo in the 1920×1080 frame: `_coverSource`'s
/// own rect, recomputed here so the case does not rest on the painter.
const _cover43 = Rect.fromLTWH(0, 378, 4032, 2268);

/// The cover crop of a 1920×1080 photo in the 1920×1080 frame: the whole
/// picture — the aspect that used to have no room at all.
const _cover169 = Rect.fromLTWH(0, 0, 1920, 1080);

PictureMotion _motion({
  Rect cover = _cover43,
  int firstFrame = 0,
  int screenFrames = 100,
  int seed = 7,
}) =>
    PictureMotion.forPicture(
      cover: cover,
      firstFrame: firstFrame,
      screenFrames: screenFrames,
      random: math.Random(seed),
    );

/// How far a window's edges moved from the framing they started at, per axis,
/// as positive numbers.
(double, double, double, double) _moved(Rect base, Rect window) => (
      (window.left - base.left).abs(),
      (window.top - base.top).abs(),
      (base.width - window.width).abs(),
      (base.height - window.height).abs(),
    );

void main() {
  group('1. the inset framing, and the ten directions every picture has', () {
    test('the base is the cover crop inset by a twelfth per side', () {
      final motion = _motion();
      // 4032/12 = 336 across, 2268/12 = 189 down, on both sides.
      expect(motion.base, const Rect.fromLTWH(336, 567, 3360, 1890));
      expect(motion.base.center, _cover43.center,
          reason: 'the inset is centred, so the picture is not panned at rest');
      expect(motion.capX, closeTo(336, 1e-9));
      expect(motion.capY, closeTo(189, 1e-9));
    });

    test('the frame decides the caps, not the picture: 16:9 and 9:16 swap them',
        () {
      // The same photo in the 1080×1920 frame: cover 1701×3024 at x=1165.5.
      const coverPortrait = Rect.fromLTWH(1165.5, 0, 1701, 3024);
      final motion = _motion(cover: coverPortrait);
      expect(motion.capX, closeTo(motion.base.width / 10, 1e-9));
      expect(motion.capY, closeTo(motion.base.height / 10, 1e-9));
      // The long side of the frame is now the vertical one.
      expect(motion.capY, greaterThan(motion.capX));
    });

    test('every picture has all ten directions, the aspect it came in notwithstanding',
        () {
      expect(MotionDirection.values, hasLength(10));
      expect(
        MotionDirection.values.map((d) => d.name).toSet(),
        {'up', 'down', 'left', 'right', 'upLeft', 'upRight', 'downLeft', 'downRight', 'near', 'far'},
      );
      // A 16:9 picture in a 16:9 frame has no cover slack at all, and still
      // moves on both axes: the room is the inset's, not the crop's.
      final motion = _motion(cover: _cover169);
      final horizontal = motion.base.shift(const Offset(-1, 0));
      expect(horizontal.left, lessThan(motion.base.left));
      expect(motion.windowAt(0), motion.base);
    });
  });

  group('2. the picture moves, and it moves the way the cycle drew', () {
    test('two frames of one cycle do not show the same window', () {
      final motion = _motion();
      final first = motion.windowAt(0);
      final middle = motion.windowAt(25);
      expect(middle, isNot(first));
    });

    test('a pan shifts the window and keeps its size', () {
      for (var seed = 0; seed < 30; seed++) {
      final motion = _motion(screenFrames: 960, seed: seed);
      for (final cycle in motion.cycles) {
        if (cycle.direction.isZoom) continue;
        // The cycle's own middle is its peak.
        final peak = cycle.startFrame + cycle.period ~/ 2;
        final window = motion.windowAt(peak);
        expect(window.width, closeTo(motion.base.width, 1e-9),
            reason: 'a pan keeps the window\'s own size');
        final dx = window.center.dx - motion.base.center.dx;
        final dy = window.center.dy - motion.base.center.dy;
        if (cycle.direction.dx != 0) {
          expect(dx * cycle.direction.dx, greaterThan(0),
              reason: '${cycle.direction.name} travels its own way across');
        }
        if (cycle.direction.dy != 0) {
          expect(dy * cycle.direction.dy, greaterThan(0),
              reason: '${cycle.direction.name} travels its own way down or up');
        }
        if (cycle.direction.dx == 0) expect(dx, closeTo(0, 1e-9));
        if (cycle.direction.dy == 0) expect(dy, closeTo(0, 1e-9));
        return;
      }
      }
      fail('no pan was drawn in 30 motions of four cycles');
    });

    test('near shrinks the window, far grows it, and neither moves its centre',
        () {
      for (var seed = 0; seed < 30; seed++) {
      final motion = _motion(screenFrames: 960, seed: seed);
      for (final cycle in motion.cycles) {
        if (!cycle.direction.isZoom) continue;
        final peak = cycle.startFrame + cycle.period ~/ 2;
        final window = motion.windowAt(peak);
        expect(window.center.dx, closeTo(motion.base.center.dx, 1e-9));
        expect(window.center.dy, closeTo(motion.base.center.dy, 1e-9));
        if (cycle.direction == MotionDirection.near) {
          expect(window.width, lessThan(motion.base.width));
        } else {
          expect(window.width, greaterThan(motion.base.width));
        }
        return;
      }
      }
      fail('no zoom was drawn in 30 motions of four cycles');
    });
  });

  group('3. bounded, inside the picture, back where it started, never twice the same',
      () {
    test('every direction the draw can produce stays inside the frame\'s tenth',
        () {
      final seen = <MotionDirection>{};
      // Ten seeds of ten cycles each: every direction the product can draw is
      // exercised, and each cycle's own peak is measured.
      for (var seed = 0; seed < 40; seed++) {
        final motion = _motion(screenFrames: 720, seed: seed);
        for (final cycle in motion.cycles) {
          seen.add(cycle.direction);
          for (final frame in [
            cycle.startFrame,
            cycle.startFrame + cycle.period ~/ 4,
            cycle.startFrame + cycle.period ~/ 2,
            cycle.startFrame + cycle.period * 3 ~/ 4,
            math.min(cycle.startFrame + cycle.period, motion.endFrame - 1),
          ]) {
            final window = motion.windowAt(frame);
            final (movedX, movedY, shrunkX, shrunkY) = _moved(motion.base, window);
            // The frame's own tenth, in the picture's pixels.
            expect(movedX, lessThanOrEqualTo(motion.capX + 1e-6),
                reason: '${cycle.direction.name} across at $frame');
            expect(movedY, lessThanOrEqualTo(motion.capY + 1e-6),
                reason: '${cycle.direction.name} down at $frame');
            expect(shrunkX, lessThanOrEqualTo(motion.capX + 1e-6),
                reason: '${cycle.direction.name} width at $frame');
            expect(shrunkY, lessThanOrEqualTo(motion.capY + 1e-6),
                reason: '${cycle.direction.name} height at $frame');
          }
        }
      }
      expect(seen, MotionDirection.values.toSet(),
          reason: 'every direction must be reachable, and each one measured above');
    });

    test('no frame leaves the picture, and none leaves the cover crop', () {
      for (var seed = 0; seed < 20; seed++) {
        final motion = _motion(screenFrames: 400, seed: seed);
        for (var frame = motion.firstFrame; frame < motion.endFrame; frame++) {
          final window = motion.windowAt(frame);
          expect(window.left, greaterThanOrEqualTo(_cover43.left - 1e-6),
              reason: 'frame $frame, seed $seed: the frame must never show a gap');
          expect(window.top, greaterThanOrEqualTo(_cover43.top - 1e-6));
          expect(window.right, lessThanOrEqualTo(_cover43.right + 1e-6));
          expect(window.bottom, lessThanOrEqualTo(_cover43.bottom + 1e-6));
        }
      }
    });

    test('a cycle starts and ends exactly on the framing it started from', () {
      final motion = _motion(screenFrames: 720, seed: 5);
      for (final cycle in motion.cycles) {
        expect(motion.windowAt(cycle.startFrame), motion.base,
            reason: 'cycle at ${cycle.startFrame} must open at rest');
        final end = cycle.startFrame + cycle.period;
        if (end < motion.endFrame) {
          expect(motion.windowAt(end), motion.base,
              reason: 'cycle at ${cycle.startFrame} must close at rest');
        }
      }
    });

    test('two cycles in a row never draw the same direction', () {
      for (var seed = 0; seed < 20; seed++) {
        final motion = _motion(screenFrames: 720, seed: seed);
        for (var i = 1; i < motion.cycles.length; i++) {
          expect(motion.cycles[i].direction,
              isNot(motion.cycles[i - 1].direction),
              reason: 'seed $seed, cycle $i');
        }
      }
    });

    test('the amplitude is drawn between 10 % and 20 % of the allowance', () {
      for (var seed = 0; seed < 20; seed++) {
        final motion = _motion(screenFrames: 720, seed: seed);
        for (final cycle in motion.cycles) {
          final allowance = cycle.direction.isZoom
              ? math.max(motion.capX, motion.capY)
              : (cycle.direction.dx != 0 && cycle.direction.dy != 0)
                  ? math.min(motion.capX, motion.capY)
                  : (cycle.direction.dx != 0 ? motion.capX : motion.capY);
          expect(cycle.amplitude, greaterThanOrEqualTo(allowance * 0.10 - 1e-9));
          expect(cycle.amplitude, lessThanOrEqualTo(allowance * 0.20 + 1e-9));
        }
      }
    });
  });

  group('4. one clock per picture, and it does not restart at a sentence', () {
    test('a picture spanning sentences keeps counting through the boundary', () {
      final motion = _motion(screenFrames: 240, seed: 2);
      // The clock's own value inside the first cycle is not the resting framing,
      // so any frame a caller reads between slots carries the motion forward.
      final inside = motion.windowAt(30);
      expect(inside, isNot(motion.base));

      // A second picture, whose own range begins later, is at rest on its own
      // first frame whatever the first one was doing.
      final second = _motion(firstFrame: 360, screenFrames: 200, seed: 9);
      expect(second.windowAt(second.firstFrame), second.base);
      expect(second.windowAt(motion.endFrame - 1), second.base,
          reason: 'a frame before its own range is its resting framing');
    });

    test('a picture\'s last frame can land mid-cycle, and the next starts at rest',
        () {
      final motion = _motion(screenFrames: 100, seed: 4);
      expect(motion.cycles, hasLength(1));
      // 100 frames over two cycles of 50: the second is whole, so cut the range
      // short instead and read the cut frame.
      final cut = _motion(screenFrames: 200, seed: 4);
      expect(cut.windowAt(cut.endFrame - 1), isNot(cut.base),
          reason: 'the picture ended before its cycle returned');
      // Past its own range the motion clamps to its last frame: the renderer
      // never asks (the schedule's range bounds it), and a caller that does gets
      // the frame the picture actually ended on — never a seam or a gap.
      expect(cut.windowAt(cut.endFrame), cut.windowAt(cut.endFrame - 1));
      expect(cut.windowAt(cut.endFrame + 50), cut.windowAt(cut.endFrame - 1));
    });
  });
}
