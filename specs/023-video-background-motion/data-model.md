# Data model: Video background motion

Two things exist: **the reader's choice** (persisted, one per device) and **a picture's motion** (computed, one per
scheduled picture, alive only inside a render). Everything else here is derived from those two, and nothing is a new
file format — the motion is arithmetic over a picture, a frame rect and a frame number, and it never reaches the disk.

## `MotionChoice` — the reader's decision

**Purpose**: whether this render's pictures move (`FR-009`).

**Attributes**

| name | type | nullable | source |
|---|---|---|---|
| `on` | `bool` | no | the switch on the video prompt; `shared_preferences` key `video_motion`, value `on` \| `off` |
| (absent) | — | — | every failure path reads as `off`: a missing key, an unreadable one, a store that throws |

**Relationships**: none. It is per device, not per content, not per locale — the same choice governs every content's
next video, exactly as the remembered format does.

**Validation rules**: `FR-009` — absent or unreadable reads as `off` without rewriting the record; one write per
confirmed prompt; a cancelled prompt leaves the record it found. Read and write rules are the contract's:
[contracts/video-motion-record.md](./contracts/video-motion-record.md).

**Sample**: `video_motion = "on"` → the next prompt opens with the switch on, and every render started from it moves.

## `MotionDirection` — the ten directions every picture has

| value | what the window does | measured on |
|---|---|---|
| `up`, `down`, `left`, `right` | shifts along one axis, keeping its size | the frame's own tenth, that axis |
| `upLeft`, `upRight`, `downLeft`, `downRight` | shifts along both axes at once, keeping its size | the frame's own tenth, both axes |
| `near` | shrinks by up to a tenth of the frame, about its centre | the frame's own tenth, each axis |
| `far` | grows by up to a tenth of the frame, about its centre | the frame's own tenth, each axis |

**Why all ten, where the first-approved spec could offer one pan axis and no diagonal.** The framing is inset by a
twelfth of the cover crop per side before anything moves (`FR-013`), and a twelfth of the crop is a tenth of the inset
framing — a tenth of the frame, because the inset framing fills it. So each axis has exactly the room the bound allows:
no direction is short of travel, and none can leave the picture. `far` stops at `1.1 ×` the base framing, i.e.
`0.9167 ×` the cover crop, which still fills the frame — the 「no gap」 rule (`FR-005`) is what caps it, not a
direction's absence.

## `PictureMotion` — one picture's motion over its own screen time

**Purpose**: everything the picture does while it is on screen (`FR-001`, `FR-002`, `FR-003`, `FR-004`, `FR-006`,
`FR-008`, `FR-013`), computed once per scheduled picture and read per frame.

**Attributes**

| name | type | source |
|---|---|---|
| `cover` | `Rect` (picture pixels) | `_coverSource`'s own rect for this picture and this frame size |
| `base` | `Rect` (picture pixels) | `cover` deflated by `(cover.width / 12, cover.height / 12)` — `FR-013`'s inset framing |
| `capX`, `capY` | `double` | `0.10 × base.width`, `0.10 × base.height` — the frame's own tenth, in picture pixels |
| `firstFrame` | `int` | the schedule's `startFrame` for this picture (`lib/video_pictures.dart:139`) |
| `screenFrames` | `int` | the schedule's inclusive range: `endFrame - startFrame + 1` |
| `cycles` | `List<_Cycle>` | `ceil(screenFrames / 72)`, in order; each holds `startFrame`, `period`, `direction`, `amplitude` |

**Cycle arithmetic** (the whole rule, in one place)

    inset  = cover.width / 12, cover.height / 12            // → base = 5/6 × cover, both axes, by construction
    capX   = 0.10 × base.width,  capY = 0.10 × base.height  // the frame's own tenth

    cycles = max(1, ceil(screenFrames / 72))                // 72 frames = 2.4 s at 30 fps
    period = max(2, ceil(screenFrames / cycles))             // whole cycles; the last may be cut short
    u      = (elapsed - cycle.startFrame) / cycle.period      // 0 … 1
    s      = (1 - cos(2πu)) / 2                              // 0 at both ends, 1 at the middle

    pan  : window = base.shift(dx · s · amplitude, dy · s · amplitude)     // size kept
    near : window = base deflated by (s · capX / 2, s · capY / 2)           // size − s · cap, per axis
    far  : window = base inflated by (s · capX / 2, s · capY / 2)           // size + s · cap, per axis

`amplitude` for a pan is `cap × uniform(0.4, 1.0)` on the axis it travels (a diagonal draws one amplitude and uses it
on both axes). `direction` is drawn from the ten, and differs from the previous cycle's. Both draws happen **once,
when the motion is built**, with one `math.Random()` per render — so `windowAt(elapsed)` is pure, and a test can hand
it a seeded `Random` and assert exact pixels.

**Relationships**: one per `ScheduledPicture` that is `drawn`; none for a picture the schedule skips (`isDrawn` false);
none at all when the effect is off.

**Validation rules**: the invariants below — each is one `FR`'s observable, and each is a `[unit]` row in the
quickstart.

**Worked example** — a 4032×3024 photo in the 1920×1080 frame, on screen for 100 frames:

    cover  = 4032 × 2268 at (0, 378)
    base   = 3360 × 1890 at (336, 567)          // 336 and 189 px inset on each side — 8.33 % of the cover
    capX = 336, capY = 189                      // 192 px and 108 px once drawn into the frame
    cycles = ceil(100/72) = 2, period = 50      // two cycles of 1.67 s

    cycle 0 = downRight, amplitude drawn 0.62
      s = 1 → window = 3360 × 1890 at (336 + 208.3, 567 + 117.2) = (544.3, 684.2)
              right edge 3904.3 ≤ 4032 ✓, bottom 2574.2 ≤ 3024 ✓ — inside the picture
    cycle 1 = near, amplitude drawn 0.91
      s = 1 → window = 3360 − 2·152.9 = 3054 × 1718, about the centre — inside the base, so inside the picture
    both cycles are back at (336, 567) on their last frame     // FR-004, and the picture rests there (SC-003)

**A `far` cycle on the same picture**: at `s = 1` the window is `3360 + 336 = 3696 × 2079` at `(168, 472.5)` — inside
the cover rect (`0…4032`, `378…2646`), so the frame still shows only picture. That is the wall `FR-005` sets, and the
reason `far`'s travel is bounded by the inset rather than by a number of its own.

**A picture of the frame's exact aspect** (1920×1080 in the 1920×1080 frame): `cover` is the whole picture, `base` is
`1600 × 900`, `capX = 160`, `capY = 90` — every direction is available exactly as it is for a 4:3 photo: the inset,
not the picture's shape, is what makes the room.

## State machine — one cycle (the only mutable thing is the clock)

| state | event | next state | guard |
|---|---|---|---|
| `base` (window == the inset framing) | the cycle's first frame | `out` | `elapsed == cycle.startFrame` |
| `out` | each frame | `out` | `s(u) < 1` |
| `out` | the middle of the cycle | `return` | `s(u) == 1` (once, exactly) |
| `return` | each frame | `return` | `s(u) > 0` |
| `return` | the cycle's last frame | `base` | `s(u) == 0` |
| `base` | the cycle's last frame | `base` → the next cycle's `base` | a new direction is drawn then (never again inside a cycle) |

The picture's own last frame can land anywhere in that table (the spec's "a slot that ends mid-cycle"): the motion
stops there, and the next picture starts at its own `elapsed = 0`, i.e. at *its* inset framing.

## Invariants

Each is phrased so a test can assert it directly.

1. **The inset is equal on both axes, and centred** (`FR-013`): `cover.width - base.width == cover.width / 6` and the
   same on Y, so the base's aspect equals the cover's equals the picture's — no stretch; and `base`'s centre is
   `cover`'s centre.
2. **Inside the picture** (`FR-005`): `base ⊆ picture` and, for every `elapsed`, `window ⊆ cover ⊆ picture` — as rects
   in picture pixels. A pan keeps the window's size and shifts it; `near` shrinks it inside the base; `far` grows it
   toward the cover and never past it.
3. **The frame's tenth** (`FR-003`, `SC-002`): on each axis, a pan's shift is ≤ `cap` and a zoom's size change is
   ≤ `cap`; since `cap = 0.10 × base` and `base ≤ picture`, both bounds hold at once — the frame's tenth is the
   operating cap and the picture's tenth the outer one.
4. **Rest at the ends** (`FR-004`): `windowAt(cycle.startFrame) == base` and
   `windowAt(cycle.startFrame + cycle.period) == base`, for every cycle but the one the picture's own end cuts short.
5. **A picture begins at rest** (`FR-008`): `windowAt(firstFrame) == base`; and a picture spanning several slots keeps
   one clock — `windowAt` takes an absolute frame index, so crossing a sentence boundary changes nothing.
6. **Two cycles do not repeat a direction** (`FR-002`, `US2` scenario 2): with all ten always available,
   `cycles[i].direction != cycles[i-1].direction` for every `i > 0`.
7. **Purity** (`FR-006`): `windowAt` reads no clock, no store and no random source — the same `elapsed` on the same
   motion is the same rect, forever. This is what makes the motion a function of the frame's place in the file.
8. **The words and their plates do not move** (`FR-007`): the painter's text geometry, line boxes, plate rects and ink
   colour are unchanged by the motion; the tone is read through `base`, so the plate's colour cannot change inside a
   slot.
9. **Off is today** (`FR-011`, `FR-013`'s second sentence): with `MotionChoice.on == false` no `PictureMotion` is built,
   no inset exists, `VideoPainter` receives no window, and the renderer's run list is `_stepsOf`'s own — the
   pre-feature code, not a branch of the new one.
10. **The evidence is the model's own numbers** (`FR-012`): the `dirs=` field of the render's motion line is
    `cycles.map((c) => '${c.direction.name}:${c.amplitude.round()}')` — the same values `windowAt` uses, never a
    second computation.
11. **The choice cannot half-apply** (`FR-009`, `FR-010`): one boolean is read once per render, before the first frame;
    no frame of a render can be painted under a different answer, and the frame count, rate, duration and audio come
    from `VideoPlan` alone.
