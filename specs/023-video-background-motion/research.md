# Research: Video background motion

Grounding done on 2026-10-19, on the tree at `0ef44e7` (the `014` commit). Every fact below is either a line in this
checkout or a command run on this box. The reader amended the spec **at this stage's own gate** — their answer `B` to
the findings in `## Grounding corrections, and the amendment they led to` — so this file records both the findings and
what the amendment does with them.

## §1 — The baseline every row of this feature is read against

Measured on this tree, on this box, 2026-10-19:

| quantity | command | value |
|---|---|---|
| analyzer | `flutter analyze` | `No issues found!` (0.8 s), exit 0 |
| test suite | `flutter test --concurrency=2` | **825 tests, all passed**, 1:15, exit 0 |
| message keys per ARB, four files | `grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb` | **130** in each |
| test files | `ls test/*.dart \| wc -l` | **57** |
| Flutter / Dart | `flutter --version`, `pubspec.yaml:22` | Flutter 3.47.5 stable, Dart SDK `^3.13.3` |
| the two dependencies this feature touches | `pubspec.yaml:39-40` | `flutter_tts: ^4.2.3`, `shared_preferences: ^2.5.5` |
| the device | `adb devices` | `emulator-5554`, AVD `klhu`, API 36 |

The suite's count is the number every `[unit]` row of the quickstart is added to, and the four ARBs' 130 is what
this feature's one new key moves to 131 — the count 021's receipt already warned is **not** the file's line count
(`app_en.arb` carries 144 lines for 130 keys, because the `@`-metadata blocks are lines too).

## §2 — What the frame paints today, and what the cover crop's slack actually is

The picture is drawn by one call inside `VideoPainter.paint` (`lib/video_painter.dart:357`):

    canvas.drawImageRect(picture, _coverSource(picture), frameRect, Paint());   // :432

`_coverSource` (`:681`) returns **the whole of the shorter side and the centred part of the longer one** — so it fills
one of the frame's two dimensions *exactly*:

    if (picture.aspect > frame.aspect)   source = (pw - ph·fa)/2, 0,  ph·fa, ph     → slack on X only
    else                                 source = 0, (ph - pw/fa)/2,  pw, pw/fa    → slack on Y only

**A picture never has slack on both axes** — the crop fills one to the pixel, and the other keeps whatever the
picture's own aspect leaves over. Run with the app's own formula, on the 1920×1080 frame:

| picture | cover rect | slack X | slack Y |
|---|---|---|---|
| 4032×3024 (4:3) | 4032×2268 at y=378 | 0 | 756 |
| 4000×3000 (4:3) | 4000×2250 at y=375 | 0 | 750 |
| 1920×1080 (16:9) | 1920×1080 | 0 | 0 |
| 4032×1512 (8:3) | 2688×1512 at x=672 | 1344 | 0 |
| 1080×1920 in the **9:16** frame | 1080×608 at y=656 | 0 | 1312 |

That is why the spec as first approved could offer a picture only one pan axis, never a diagonal, and could treat 「远」
only as a cycle's return leg. **The amendment makes the room instead of inheriting it**: the framing is the cover crop
inset by a twelfth of itself per side (`k = 5/6`), which leaves a twelfth of the crop on each side — exactly a tenth of
the inset framing, which is exactly the frame's own tenth, because the inset framing fills the frame. Both axes then
have room. The inset cannot be applied per axis: the window is a rect drawn onto the frame's own aspect, so insetting
one axis alone would stretch the picture.

Arithmetic for the amendment (`base = k × cover`, `cap = 0.10 × base` per axis — the same number read in the picture's
pixels and in the frame's, because the base fills the frame):

| picture in the 16:9 frame | base framing | cap X | cap Y | the same in frame px | `near` (0.9 × base) | `far` (1.1 × base) |
|---|---|---|---|---|---|---|
| 4032×3024 | 3360×1890 at (336, 567) | 336 | 189 | 192 × 108 | 3024×1701 | 3696×2079 |
| 1920×1080 | 1600×900 | 160 | 90 | 192 × 108 | 1440×810 | 1760×990 |
| 4032×1512 | 2240×1260 | 224 | 126 | 192 × 108 | 2016×1134 | 2464×1386 |

In the 9:16 frame the same rule gives **108 px across and 192 px down**: the frame's long side travels more, its short
side less, and no code knows which aspect it is drawing. `far` stops at `1.1 × base = 0.9167 × cover`, i.e. **inside**
the cover crop — the frame still never shows the background (`FR-005`), and the cover crop is the outer wall.

## §3 — The render's own cost, and why SC-005 is the risk this plan carries

012's row 36 (spike S2, `specs/012-reading-video/breakpoint.md` row 36's own section) printed, on `emulator-5554`,
a 17-sentence / 69.3 s video:

    klhu render time synth=2148ms paint=182ms send=47139ms total=47340ms finish=11ms sentences=17 pictures=17 frames=2078

The split matters more than the total:

- **`paint` is per visual state** — 17 paints of 2078 frames, 182 ms, i.e. **10.7 ms per frame painted**.
- **`send` is per frame** — 2078 frames through `MediaCodec`, 47.1 s (≈ 22.7 ms each), and the PNG encode happens
  once per `addFrame(repeat: n)` call, i.e. 17 times today.

With the effect on, `FR-001` makes every frame a distinct state, so painting moves from 182 ms to ~2078 × 10.7 ms ≈
**22.2 s** and the PNG encode becomes per frame. That alone is **1.37 ×** the 60.6 s baseline, and `SC-005`'s ceiling
(1.5 × 60.6 s = **90.9 s**) leaves **≈ 8.0 s** — about **3.9 ms per extra PNG encode** — before the budget is missed.
Whether a 1920×1080 PNG encodes in under 3.9 ms in Dart is **not** something this checkout can answer: it is probe
`P1`, below, with its own `[device]` measuring row and a named ladder. The amendment does not change this arithmetic:
the inset is one rect per frame, not a second paint.

## §4 — Where the motion's clock comes from, and why nothing platform-side moves

- The scroll step already reads the frame's own place in its slot: `progress` is documented at
  `lib/video_painter.dart:353` and quantised at `:385-393`; the renderer splits a slot into one run per line step in
  `_stepsOf` (`lib/video_renderer.dart:503`) and paints at `:388`.
- The schedule names each picture's own first and last frame, **inclusive** at the end:
  `ScheduledPicture{startFrame, endFrame}` (`lib/video_pictures.dart:127-144`, `frames => endFrame - startFrame + 1`).
  So a picture's own elapsed frames are `globalFrame - scheduled.startFrame`, available in the renderer's loop
  without a second timeline — and a picture that spans several sentences keeps counting, which is `FR-008`'s second
  half, for free. A new picture starts at 0, which is its own resting framing, `FR-008`'s first half.
- The encoder already accepts **one image standing for N frames**: `addFrame(Uint8List png, {required int repeat})`
  (`lib/platform/video_encoder.dart:68`). The effect on means `repeat: 1` per frame; `totalFrames` is unchanged, so
  `FR-010`'s frame count, rate, duration and audio are the plan's own numbers, untouched. **No platform channel
  change and no Kotlin edit** — which is also why the constitution's first principle is not in play.
- The end hold (a `VideoSlotKind.hold` slot) already extends the last sentence's run
  (`lib/video_renderer.dart:324-337`); its frames continue the same picture, so the motion runs through the hold as
  one clock — the spec's own edge case.

## §5 — The stored choice, and why it is a second key rather than a field on 012's value

`VideoAspectStore` (`lib/video_aspect.dart:63`) owns exactly one key, `video_aspect` (`:66`), reads it tolerantly
(`VideoAspect.decode`, `:50`; the `catch` in `load`, `:75`) and writes one value per confirmed choice. 012's record
contract (`specs/012-reading-video/contracts/video-aspect-format.md`) enumerates its domain as
`landscape | vertical` and states that any value outside it reads as the default **without rewriting**. Putting the
effect's on/off into that value (`landscape+motion`) would make every existing read of that contract's domain a
lie and its "one value, no second key" invariant false. The store the app already uses for per-device view state
(`voice_*`, `interface_language`, `reading_appearance` — all `shared_preferences`) has room for a sibling key, so the
choice gets `video_motion`, its own contract file, and 012's contract is left alone. That is the shape `A5` asks the
plan to settle.

## §6 — A4's question, answered by construction: where the plate's colour is read

`A4` asks the plan to confirm that a moved band does not straddle a plate/ink boundary. The tone is read **per slot**
over the band the words cover — `_toneOf` (`lib/video_painter.dart:490`) with `_bandsOf` (`:540`), which maps the
text's line boxes through the drawing's own source rect (`:546`) — and cached by band key. If the band were re-read
from the *moved* window, the plate could flip colour mid-slot, which `FR-007` forbids and `SC-004` measures.

**Decision**: the tone is read from the **inset framing** — the cycle's resting window — once per slot. Three
consequences, all named:

1. The plate is constant within a slot **by construction**: the band key does not change, so the cached answer is
   returned (`FR-007`, `SC-004`).
2. With the effect on, the plate's colour can differ from the same picture's plate in an **off** render: the band is
   read over the inset framing, which shows a different part of the picture than the cover crop did. That is a
   consequence of `FR-013`, not a defect, and `SC-001` is untouched (the off path never reaches this code).
3. On a picture whose band average sits near the tone floor, the plate can be the less comfortable of the two colours
   over the drifted part of the band — up to **108 px down / 192 px across** on a 16:9 frame away from where it was
   read. Bounded, stated, and measured by row 11 rather than argued.

## §7 — What a device row can read out of the produced file

The walks already pull a render off the device and read it with the host's tools
(`specs/012-reading-video/scripts/klhu_walk_video.py:460` uses `ffprobe` for the frame count;
`specs/012-reading-video/scripts/klhu_probe_hiss.py:62` extracts raw audio). For this feature the frame's **pixels**
are the evidence, and two fixture shapes make them readable without a reference image:

- a **solid** picture on a **solid** background: a background-coloured pixel inside the frame is a gap (`FR-005`), and
  its count is a number, not an opinion;
- a **four-quadrant** picture (red / green / blue / yellow — the shape the painter's own tests use,
  `test/video_painter_test.dart:169`): the colour at each frame corner says *which part of the picture* is at that
  corner, so the window's position is read off the corners and its displacement is arithmetic, not eyeballing.

Extraction is `ffmpeg -ss <t> -frames:v 1 -f rawvideo -pix_fmt rgb24` into a byte buffer read by a few lines of
Python — no PIL needed for the scan, and the walk builds its own PNG fixtures the way 020's walk does
(`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py:191`, hand-written PNG via `struct` + `zlib`).

## Grounding corrections, and the amendment they led to

Two facts about this tree made two sentences of the first-approved spec unsatisfiable. **Both were put to the reader
at this stage's gate and they answered B**, so the spec now says what follows (`FR-002`, `FR-003`, `FR-005`, `FR-013`,
`A2` and `US2`'s third scenario were amended on 2026-10-19; the Clarifications carry the reader's own words). What is
left here is the finding, and what the amendment does with it — not a correction the code has to work around.

**1. The cover crop leaves no picture room on both axes, so the diagonals were offered to nobody.** The crop fills one
dimension to the pixel (§2's table). **What the amendment does**: the framing is inset by a twelfth per side before the
picture moves (`FR-013`), which gives both axes a tenth of the *frame* to travel — so all eight compass directions are
available for every picture. **What it costs**, and it is why this was the reader's decision rather than a repair: a
picture in a video with the effect on is shown **1.20 × tighter** than the same video shows it today (69.4 % of the
cover crop's area). Refused at the gate: a flat tenth per side (`k = 0.8`: 1.25 ×, for no direction `5/6` does not
already allow), and an inset sized for equal on-screen pixels on both axes (`k ≈ 0.64`: 1.56 × — a symmetry nobody
asked for, at the highest price of the three).

**2. A "farther" direction could only be a cycle's return leg.** From the cover crop — the widest framing that fills
the frame — there is nowhere to go outward without opening a gap. **What the amendment does**: with the inset as the
base, 「远」 becomes a direction of its own, travelling outward by a tenth of the frame and stopping at the cover crop
(`0.9167 ×` cover). It is still not a true zoom-out: the frame never shows the background, and the cover crop remains
the outer wall (`FR-005`). Refused at the gate, and refused before it: scaling the picture below the frame to buy
travel.

**3. `A5`'s "one key family" is the store, not the value.** `VideoAspectStore` owns one key and 012's contract
enumerates its domain; the family is `shared_preferences` itself. The effect's on/off therefore gets its own key
(`video_motion`) rather than a field in 012's value — see §5. No file of 012's changes; its artifacts are reported
as describing the old shape (which is still true of them).

## D1 — The motion's clock is the picture's own screen time in frames, and its shape is a cosine round trip

- **Decision**: one motion per *scheduled picture*, clocked by `globalFrame - scheduled.startFrame`. The picture's
  screen time is cut into `ceil(screenFrames / 72)` cycles of at most 72 frames (2.4 s at 30 fps, the shortest period
  that satisfies `SC-003`'s 3 s with margin); within a cycle `u = k / period` and the travel fraction is
  `s(u) = (1 - cos 2πu) / 2`, which is 0 at both ends and 1 at the middle. The last cycle of a picture may be cut
  short by its own end (the spec's "a slot that ends mid-cycle"). Every cycle's base framing is `FR-013`'s inset
  framing — one rect for the whole picture, which is what makes `FR-004` and `SC-003` true of it.
- **Rationale**: a frame's own index is the only clock that satisfies `FR-006` (frame-driven, nothing from a player),
  and it makes `FR-008` free: the same picture spanning sentences keeps counting, a new picture starts at 0. The
  cosine is chosen over a triangle or a sine because it comes to rest **and** leaves rest with zero velocity — the
  boundary between two cycles is invisible, which is what `FR-004`'s "returns to the exact framing" has to look like.
  Dividing the screen time into whole cycles (rather than "72 then a remainder") is what makes a short slot a
  *compressed* cycle instead of a truncated one.
- **Alternatives considered**: the slot's `progress` (lost the picture's own continuity across sentences, and restarts
  at every sentence — the very twitch `FR-008` forbids); a wall-clock timer (not frame-driven; `FR-006` fails and the
  video would not carry the motion); a linear ramp (velocity discontinuity at the cycle boundary, readable as a
  tick); 72 frames fixed with a partial remainder cycle (a short slot gets a sliver of a cycle, which reads as a jolt
  rather than a breath).

## D2 — The rule is one pure module; the painter is given a window, and keeps reading its tone at rest

- **Decision**: a new `lib/video_motion.dart` owns everything the motion *is* — the inset framing, the caps on the
  frame's own tenth, the ten directions, the drawn amplitude and direction per cycle, and `Rect windowAt(int
  elapsedFrame)` in picture pixels. `VideoPainter.paint` gains one optional parameter (`MotionFraming? framing` — the drawn rect and the resting one,
  because §6 reads the tone over the latter); when it is
  null the painter draws `_coverSource(picture)` exactly as today. The tone is read through the **inset framing**,
  per §6.
- **Rationale**: the motion is arithmetic over a picture's geometry, and a pure function of `(picture size, frame
  rect, elapsed frame)` is testable without a canvas, a device or a render — which is what lets the inset, the bound,
  the inside-the-picture rule and the return-to-base rule be `[unit]` rows with no fixture at all. The painter keeps
  one job (paint this window), and the off path is untouched by construction.
- **Alternatives considered**: the motion inside `VideoPainter` (a canvas class would then own a random draw and a
  cycle clock, and a pixel test would be the only way to check a rule that is arithmetic); the motion inside the
  renderer (the same rules would sit beside the timing code and be reachable from no unit test); moving the tone
  band with the window (§6 — `FR-007`/`SC-004` would then be assertions about a picture we cannot control).

## D3 — With the effect on, the renderer paints one frame at a time; the off path is untouched code

- **Decision**: `VideoRenderer` takes `motion: bool` (default false). Off: today's `_stepsOf` run building, today's
  lines, byte-identical output (`FR-011`). On: one run per frame, `repeat: 1`, `progress = k / span` for the text's
  own scroll, the window from `video_motion.dart` for the picture.
- **Rationale**: `FR-001` makes every frame a distinct visual state, so the run/`repeat` machinery has nothing to
  save with it on. Keeping the two paths separate is what lets `SC-001` be *measured* — the off run re-executes the
  pre-feature code, so "identical to today" is not a claim about a shared branch.
- **Alternatives considered**: quantise the picture's framing to every Nth frame from the start (fewer states, and it
  is the ladder's second rung — but it is a *cost* decision, made after `P1` measures, not a design default); reuse
  the run machinery by giving each frame its own run list entry but letting identical windows repeat (no two windows
  are identical while `s(u)` is moving).

## D4 — The evidence is one line per picture, and the slot line keeps its shape

- **Decision**: with the effect on, the renderer prints one
  `klhu render motion picture=<i> frames=<start>..<end> cycles=<n> dirs=<dir>:<px>,…` line per picture — each cycle's
  direction and its amplitude in the picture's own pixels — and the existing `klhu render slot=` line prints once per
  slot (at its first frame) with today's fields unchanged. With the effect off, neither the motion line nor any changed
  field appears. `FR-012` is what this satisfies; 012's own fields keep their names and meanings.
- **Rationale**: `FR-012` wants the *direction and the amplitude in the picture's pixels* so a row can witness the
  bound without knowing which direction was drawn. A per-frame slot line would be 2078 lines and would bury the
  17 lines 012's rows read; a per-picture line is the same 1-per-picture granularity the existing
  `klhu render pictures=` line already has, and it names every cycle, which is the granularity the bound is checked at.
- **Alternatives considered**: appending `motion=` to the slot line (printed per frame with the effect on: 2078
  lines, and 012's rows that count slot lines would read the on-path as broken); a second time line (two numbers for
  one render); storing the directions in the file's metadata (a container change, out of scope).

## D5 — The inset framing, and the ten directions it makes possible

- **Decision**: the base framing is `k = 5/6` of the cover crop, centred (`FR-013`); the available set is **all ten**
  directions for every picture — `up, down, left, right, upLeft, upRight, downLeft, downRight, near, far` — because
  each axis has a tenth of the frame to travel. `far` grows the window to at most `1.1 × base` (0.9167 × cover, still
  filling the frame); `near` shrinks it to `0.9 × base`; both zoom legs are measured like the pans, on the frame's own
  dimension. The drawn direction differs from the previous cycle's whenever the set holds more than one member.
- **Rationale**: the reader's answer `B` at the gate — the spec's Clarifications carry their words. `5/6` is the
  **exact** inset that makes the cap reachable on both axes: a twelfth of the crop per side is a tenth of the inset
  framing, and that framing fills the frame, so the frame's tenth is available with nothing left over. The price is the
  1.20 × magnification the reader accepted — against 1.25 × at `k = 0.8` for no extra direction, and 1.56 × for equal
  on-screen pixels.
- **Alternatives considered**: the crop's own slack decides (the first-approved reading, which offered no diagonal and
  no 「远」: refused at the gate); `k = 0.8` (a tenth per side: 1.25 ×, and it buys no direction `5/6` does not);
  `k ≈ 0.64` (equal on-screen pixels: 1.56 ×, the symmetry nobody asked for); insetting one axis only (impossible —
  the window is drawn onto the frame's aspect, so a one-axis inset stretches the picture).

## D6 — The power and pace of the drift: drawn between 40 % and 100 % of the cap, 2.4 s a cycle

- **Decision**: per cycle, `amplitude = cap × uniform(0.4, 1.0)` on the axis the direction travels, where `cap` is
  `0.10 × base` per axis — the frame's own tenth, §2's table — for the pans and for both zoom legs alike. Directions
  and amplitudes are drawn once per picture, when its motion is built, with one `math.Random()` per render.
- **Rationale**: the item asks for 轻微 and a cap; a full-cap move every cycle reads as a mechanism, a drawn
  amplitude reads as drift. The draws are made up front so `windowAt` is pure and a test can pass a seeded `Random`
  and assert exact numbers — while the product itself is deliberately unseeded (the spec refuses a reproducibility
  rule).
- **Alternatives considered**: always the full cap (visible rhythm, and every cycle the same size); always a fixed
  fraction (no variety at all, and the cap becomes decoration); seeded from the content (invents the reproducibility
  rule the spec refused).

## D7 — The choice is its own key in the app's per-device store, written on the prompt's confirm

- **Decision**: `lib/video_motion_store.dart` owns `video_motion` (`on` / `off`, default `off`), read once when the
  video prompt opens and written once when the reader confirms it — the same moment and shape as the aspect's own
  save (`lib/reading_view.dart:1975`). The contract is `contracts/video-motion-record.md`.
- **Rationale**: §5 and correction 3. Reading it with the prompt (not at app start) keeps the launch path unchanged;
  writing it on confirm means a cancelled prompt leaves the record it found, exactly as the aspect behaves.
- **Alternatives considered**: a field inside 012's `video_aspect` value (breaks that contract's domain and its
  single-value invariant); a second store family (nothing new is needed); saving on every toggle (a cancelled prompt
  would still change the device's default — the aspect does not, and two adjacent choices behaving differently is a
  surprise).

## D8 — The prompt gains one row under the format chips, and nothing else on screen moves

- **Decision**: a `SwitchListTile` directly under the aspect chips and above the pictures' divider
  (`lib/reading_view.dart:2034` is where the chips are built), labelled by one new ARB key in all four locales
  (`videoMotionLabel`), with the state read from the store when the prompt opens and saved on confirm.
- **Rationale**: the prompt is where the video is set up — the spec's own Clarifications fix that — and the row sits
  with the other per-video choice, above the reader's pictures, so the prompt's existing order (format → pictures →
  start) is preserved. One key, not two: the switch's state is the sentence, and a second explanatory line would be
  the longest text on the prompt.
- **Alternatives considered**: a third `ChoiceChip` beside the aspects (it would read as a *format*, and the two
  formats are mutually exclusive while this is independent); a checkbox in a separate settings page (the choice is
  per video setup, and the reader would have to leave the prompt to find it); the same switch on the reading page
  (a second surface for one decision).

## D9 — The cost has a measuring row and a ladder; the plan promises no number it has not taken

- **Decision**: `P1` is the wall time of the reference render with the effect on, measured by the quickstart's own
  `[device]` row against `SC-005`'s 90.9 s ceiling. If it lands above, the ladder is applied **in this order**, each
  rung measured before the next is considered: (a) quantise the drawn window to every second/third frame (a 15 or
  10 Hz drift — still 36 or 24 distinct framings per cycle, `repeat: 2`/`3`, and painting drops back to ~1/2 or ~1/3
  of 22.2 s); (b) hand the encoder raw RGBA instead of PNG (a platform-channel addition — a real change to
  `video_encoder.dart`'s interface, reported, never slipped in); (c) put the landed number to the reader as an
  amendment of `SC-005`. `SC-005` itself says the number is re-taken and recorded "whichever way it lands".
- **Rationale**: §3's arithmetic says the budget is 3.9 ms-per-PNG away from being missed, and nobody has measured a
  Dart PNG encode on this device. A plan that promised the budget would be a number invented before its measurement;
  the ladder is what makes the risk actionable at the moment the number lands instead of a re-plan.
- **Alternatives considered**: designing the quantisation in from the start (it buys cost at the price of the item's
  "每帧都在动" reading, and there is no measurement yet that says the price is owed); optimising the painter first
  (182 ms of 60.6 s — the wrong 0.3 %).

## Spikes

- **P1 — the effect-on render's wall time** (`[device]`, quickstart row 12). Measures the same one-minute reference
  content 012's row 36 used (`specs/012-reading-video/breakpoint.md` row 36), on `emulator-5554`, reading the app's
  own `klhu render time` line plus the host's wall clock. Ladder in D9. **Until it runs, `SC-005`'s budget is a
  ceiling the plan has not met** — the plan says so and no row claims it as passed before the number exists.
- **P2 — the plate's colour over a drifted band** (`[device]`, quickstart row 11). A high-contrast fixture (a
  half-dark, half-light picture with the text's band over the boundary) at the two extremes of one cycle: reads
  whether the plate stays legible where the band has drifted. Not a Go/No-Go — the answer is a recorded number
  (the pixels' mean brightness under the plate), because §6's decision trades a possible mid-slot flicker for a
  possible slight contrast loss and only this row can say how slight.

## Open questions

- **How the 1.20 × tighter crop reads on the reader's own pictures.** The gate's decision bought every direction with
  it; the number is the reader's to judge on a real photo, and quickstart row 10 hands them the still. If it reads too
  tight, `k` is one constant in `video_motion.dart` and `FR-013` is the one sentence to amend.
- **How gentle the drift reads.** 2.4 s at 40–100 % of the frame's tenth is this plan's judgement, not a measurement.
  The period (72 frames) and the amplitude's lower bound (0.4) are each one constant, so a re-tune is a two-line change
  and no re-plan.
- **Whether the prompt's one new row is enough explanation.** If the reader asks what the switch does on first sight,
  the answer is the spec's `US3` wording and the fix is a second ARB key, not a redesign.
