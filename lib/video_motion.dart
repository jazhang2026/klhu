import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// The ten directions a picture in a video can take (spec 023 FR-002).
///
/// Eight compass points, and the two ends of the zoom axis. Every one of them
/// is available to **every** picture, because the framing is inset before the
/// picture moves (`PictureMotion.base`): a twelfth of the cover crop comes off
/// each side, which is a tenth of the inset framing, which is a tenth of the
/// frame — so both axes have exactly the room `FR-003` allows, and no axis has
/// room the bound would forbid.
enum MotionDirection {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0),
  upLeft(-1, -1),
  upRight(1, -1),
  downLeft(-1, 1),
  downRight(1, 1),
  near(0, 0),
  far(0, 0);

  const MotionDirection(this.dx, this.dy);

  /// The sign this direction travels on each axis; `0` on both for the zoom.
  final int dx;
  final int dy;

  /// Whether this direction changes the window's size rather than its place.
  bool get isZoom => this == near || this == far;
}

/// One cycle of a picture's motion: a direction, the travel drawn for it, and
/// the frames it owns.
///
/// A cycle always starts and ends at the picture's inset framing (`FR-004`), so
/// the framing recurs once per cycle — which is what `SC-003`'s "at least once
/// in every 3 seconds" measures.
class MotionCycle {
  const MotionCycle({
    required this.startFrame,
    required this.period,
    required this.direction,
    required this.amplitude,
  });

  /// The video's own frame number this cycle opens on.
  final int startFrame;

  /// How many frames one whole cycle takes (0 → 1 → 0).
  final int period;

  final MotionDirection direction;

  /// The travel at the cycle's peak, in the picture's own pixels, on the axis
  /// the evidence line quotes: the axis this direction travels for a pan, the
  /// frame's longer axis for the zoom (whose other axis changes by the same
  /// fraction of its own tenth, so both stay inside `FR-003`).
  final double amplitude;
}

/// One picture's motion over the frames it is on screen (spec 023).
///
/// The rule is pure: it is built once per scheduled picture from the picture's
/// cover crop and its own frame range, and `windowAt(frame)` is a function of
/// the video's frame number alone — no clock, no store, no random source
/// (`FR-006`). The directions and their amplitudes are drawn once, when the
/// motion is built, so a test can hand it a seeded [math.Random] and assert
/// exact pixels while the product itself stays unseeded (the spec refuses a
/// reproducibility rule).
class PictureMotion {
  PictureMotion._({
    required this.base,
    required this.capX,
    required this.capY,
    required this.firstFrame,
    required this.screenFrames,
    required this.cycles,
  });

  /// Builds one picture's motion from the rectangle the frame shows at rest.
  ///
  /// [cover] is `_coverSource`'s own rect for this picture and this frame size;
  /// [firstFrame] and [screenFrames] are the schedule's inclusive range for it,
  /// and [random] is the render's one source of variety.
  factory PictureMotion.forPicture({
    required Rect cover,
    required int firstFrame,
    required int screenFrames,
    required math.Random random,
  }) {
    // FR-013: a twelfth of the cover on each side, on both axes in the same
    // proportion — a one-axis inset would stretch the picture, because the
    // window is drawn onto the frame's own aspect.
    final insetX = cover.width / 12;
    final insetY = cover.height / 12;
    final base = Rect.fromLTRB(
      cover.left + insetX,
      cover.top + insetY,
      cover.right - insetX,
      cover.bottom - insetY,
    );
    // FR-003: a tenth of the frame, read on the picture's own pixels. The inset
    // framing fills the frame, so a tenth of it is a tenth of the frame.
    final capX = base.width / 10;
    final capY = base.height / 10;

    final frames = math.max(1, screenFrames);
    final count = math.max(1, (frames / framesPerCycle).ceil());
    final period = math.max(2, (frames / count).ceil());
    final cycles = <MotionCycle>[];
    MotionDirection? previous;
    for (var i = 0; i < count; i++) {
      final direction = _drawDirection(random, previous);
      previous = direction;
      cycles.add(MotionCycle(
        startFrame: firstFrame + i * period,
        period: period,
        direction: direction,
        amplitude: _drawAmplitude(direction, capX, capY, random),
      ));
    }
    return PictureMotion._(
      base: base,
      capX: capX,
      capY: capY,
      firstFrame: firstFrame,
      screenFrames: frames,
      cycles: cycles,
    );
  }

  /// How long one cycle takes when the picture stays on screen that long:
  /// **8 s at 30 fps**. The reader's own instruction of 2026-10-19 — 「移动间隔时间
  /// 长一点」 — after seeing a 2.4 s cycle on the phone: the drift is meant to be a
  /// slow breath, not a rhythm, so a cycle is long and the travel inside it is
  /// tiny (see [_drawAmplitude]). A picture on screen for less than a cycle
  /// compresses one into what it has.
  static const int framesPerCycle = 240;

  /// The framing the picture rests at: the cover crop inset by `FR-013`'s
  /// twelfth per side. Every cycle starts and ends here.
  final Rect base;

  /// The frame's own tenth on each axis, in the picture's pixels.
  final double capX;
  final double capY;

  /// The video's first frame this picture is drawn in, and how many frames it
  /// is drawn for (the schedule's inclusive range, as a count).
  final int firstFrame;
  final int screenFrames;

  /// The cycles this picture's screen time is cut into, in order.
  final List<MotionCycle> cycles;

  /// The first frame **after** this picture's last.
  int get endFrame => firstFrame + screenFrames;

  /// The window to draw for the video's [frame], in the picture's own pixels.
  ///
  /// `base` at a cycle's first frame, at its last, and outside the picture's
  /// range — so a caller that reaches past the range (the end hold's own frames)
  /// still draws a framing inside the picture.
  Rect windowAt(int frame) {
    if (screenFrames <= 1) return base;
    final elapsed = (frame - firstFrame).clamp(0, screenFrames - 1);
    final cycle = _cycleFor(elapsed);
    final u = (elapsed - (cycle.startFrame - firstFrame)) / cycle.period;
    // The cosine's own round trip: 0 at both ends and 1 at the middle, so the
    // window comes to rest without a step and leaves rest without a kick.
    final s = (1 - math.cos(2 * math.pi * u)) / 2;
    if (cycle.direction.isZoom) {
      // The size changes per axis by its own tenth (`FR-003`): a tenth of the
      // width across a tenth of the height down, each on `capX`/`capY`.
      final grow = cycle.direction == MotionDirection.far;
      final dx = (grow ? 1 : -1) * capX * s / 2;
      final dy = (grow ? 1 : -1) * capY * s / 2;
      return Rect.fromLTRB(
        base.left - dx,
        base.top - dy,
        base.right + dx,
        base.bottom + dy,
      );
    }
    return base.shift(Offset(
      cycle.direction.dx * cycle.amplitude * s,
      cycle.direction.dy * cycle.amplitude * s,
    ));
  }

  /// The cycle [frame] falls in, for the evidence a row may want to read.
  MotionCycle cycleAt(int frame) {
    if (cycles.isEmpty) {
      return const MotionCycle(
        startFrame: 0,
        period: 1,
        direction: MotionDirection.near,
        amplitude: 0,
      );
    }
    return _cycleFor((frame - firstFrame).clamp(0, screenFrames - 1));
  }

  /// The direction in force at [frame].
  MotionDirection directionAt(int frame) => cycleAt(frame).direction;

  MotionCycle _cycleFor(int elapsed) {
    var found = cycles.first;
    for (final cycle in cycles) {
      if (elapsed >= cycle.startFrame - firstFrame) found = cycle;
    }
    return found;
  }

  /// One direction, never the one before it: two cycles in a row that travel the
  /// same way read as a stutter rather than as drift (`US2` scenario 2).
  static MotionDirection _drawDirection(
      math.Random random, MotionDirection? previous) {
    final all = MotionDirection.values;
    var pick = all[random.nextInt(all.length)];
    while (pick == previous) {
      pick = all[random.nextInt(all.length)];
    }
    return pick;
  }

  /// The travel drawn for [direction] in `[0.10, 0.20]` of its own allowance —
  /// **1–2 % of the frame**, the reader's own instruction of 2026-10-19: 「每次移动
  /// 的距离小一些…只要产生一点动的感觉就可以了，不要求距离」. With an 8 s cycle and one
  /// painted image per `VideoRenderer.motionQuantum` frames, each visible step is
  /// under two pixels: the eye reads a drift, never a step, and the cost is a
  /// fraction of a per-frame render's.
  ///
  /// The allowance is the tenth of the axis it travels: full width across, full
  /// height down, the smaller of the two on a diagonal (so neither axis is
  /// overrun), and the frame's longer axis for the zoom (whose other axis
  /// changes by the same fraction of its own tenth).
  static double _drawAmplitude(
      MotionDirection direction, double capX, double capY, math.Random random) {
    final double allowance;
    if (direction.isZoom) {
      allowance = math.max(capX, capY);
    } else if (direction.dx != 0 && direction.dy != 0) {
      allowance = math.min(capX, capY);
    } else if (direction.dx != 0) {
      allowance = capX;
    } else {
      allowance = capY;
    }
    return allowance * (0.10 + 0.10 * random.nextDouble());
  }
}

/// What the painter is told about a picture that moves: the rect to draw, and
/// the framing the picture rests at.
///
/// Two rects rather than one because the plate's tone is read over the **resting**
/// framing (`research.md` §6): the words' band maps through [rest], so the plate
/// is constant inside a slot (`FR-007`) while [source] is what the frame shows.
class MotionFraming {
  const MotionFraming({required this.source, required this.rest});

  /// The part of the picture the frame draws now.
  final Rect source;

  /// The part of the picture the frame draws when the picture is at rest.
  final Rect rest;
}
