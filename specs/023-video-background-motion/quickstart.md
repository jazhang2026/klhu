# Quickstart: Video background motion

## Prerequisites

`export PATH=$HOME/development/flutter/bin:$PATH`, the emulator `emulator-5554` (AVD `klhu`, API 36) up, package
`com.example.klhu`, `adb` at `~/Android/Sdk/platform-tools`, and the host's `ffmpeg`/`ffprobe` (012's walks already
depend on both). Every row below is read against **this tree's own baseline, taken 2026-10-19 on commit `0ef44e7`**:

```
flutter analyze                                   → No issues found! (0.8 s), exit 0
flutter test --concurrency=2                      → 825 tests, all passed (1:15), exit 0
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb  → 130 keys in each of the four
ls test/*.dart | wc -l                            → 57
```

The device rows are driven by one script, one row at a time — the row number is the argument:

```
/usr/bin/python3 specs/023-video-background-motion/scripts/klhu_walk_motion.py <row>
```

(`/usr/bin/python3` because the driver's chain imports 012's and 020's walks, which need this box's system Python;
`ADB_SERIAL` defaults to `emulator-5554`, and this box has more than one device attached so it must be set.)

The fixtures are built by the walk itself, not shipped: a **four-quadrant** picture written as a PNG with `struct` +
`zlib` the way 020's walk writes its own (`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py:191`), with its
two colour boundaries **off-centre on purpose** — at **a quarter** of the width and **a third** of the height — so
that a pan moves a boundary and a zoom moves it too (a centred boundary would be invisible under a centre-anchored
zoom). The same picture is made at **4032×3024** (a 4:3 photo, so its cover crop is 4032×2268) and at **1920×1080**
(the frame's own aspect, cover crop = the whole picture), plus a two-band dark/light picture for row 11's plate
reading and 012's 17-sentence one-minute content for row 12.

## Automated checks

```
flutter analyze                                           → clean
flutter test --concurrency=2                              → 825 + this feature's own cases, 0 failing
flutter test test/video_motion_test.dart                  → the inset, the ten, the bound, the return, one clock per picture
flutter test test/video_painter_motion_test.dart          → the inset window is drawn; the words and the plate are not moved
flutter test test/video_renderer_motion_test.dart         → one frame per run with the effect on; today's runs with it off; the lines
flutter test test/video_motion_store_test.dart            → the choice, and every failure reading as off
flutter test test/reading_view_video_motion_test.dart     → the prompt's switch, and the answer reaching the renderer
flutter gen-l10n && flutter test test/l10n_keys_test.dart → the new key in four locales, no key left behind
/usr/bin/python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_artifact_refs.py specs/023-video-background-motion
/usr/bin/python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_quickstart_coverage.py specs/023-video-background-motion
```

## Scenarios

### 1. The inset is the same on both axes, and every picture gets the same ten directions — [unit]

Feed the rule the three shapes §2 of `research.md` measures — 4032×3024, 4032×1512 and 1920×1080 in the 1920×1080
frame — and then the same three in the 1080×1920 frame.

**Expected**: for every one of the six, the base framing is the cover rect deflated by exactly `cover.width / 12` and
`cover.height / 12` (`k = 5/6`), centred, with the picture's aspect unchanged; `capX` and `capY` are a tenth of **that
base**, which is a tenth of the frame (192 px and 108 px on the 16:9 frame, 108 px and 192 px on 9:16); and the
available set is **all ten** directions — the four compass points, the four diagonals, `near`, `far` — for a 16:9
picture in a 16:9 frame exactly as for a 4:3 one.
**Evidence**: `test/video_motion_test.dart` — the six base rects, their caps in both picture and frame pixels, and the
ten-member set, asserted as a set.
**Proves FR-002, FR-005, FR-013.**

### 2. No direction travels further than the bound, on either axis — [unit]

For each of the ten directions and for amplitudes drawn across the whole range, walk every frame of a cycle and read
`windowAt`.

**Expected**: on each axis, a pan's displacement is ≤ the frame's own tenth (336 and 189 picture px, i.e. 192 and
108 frame px for the 4032×3024 photo) and a zoom's size change is the same tenth (the 1920×1080 picture goes
1600×900 → 1440×810 at `near`'s peak and 1760×990 at `far`'s); nothing ever leaves the picture; and `far`'s peak
(3696×2079 for the photo) is still inside the cover crop (4032×2268), so `far` can never open a gap. The picture's
own tenth is never exceeded either, because the base is smaller than the cover.
**Evidence**: `test/video_motion_test.dart` — the extremes over a full cycle, per direction, printed as rects in both
picture and frame pixels.
**Proves FR-003.**

### 3. A direction runs out, comes back to where it started, and the next one differs — [unit]

Walk one picture's whole screen time (100 frames, so two cycles at 50), reading the window at every frame.

**Expected**: the window equals the inset base on the first frame of each cycle and on the frame after its last; it
reaches its extreme once, in the middle; a `near` cycle's peak is `0.9 × base` and a `far` cycle's is `1.1 × base` —
both legs measured on the frame's tenth, both back to `base` at the end; and the second cycle's direction differs from
the first's, for every pair of cycles.
**Evidence**: `test/video_motion_test.dart` — the boundary frames and the two peaks, printed as rects, with the drawn
direction beside each.
**Proves FR-004, FR-002.**

### 4. One clock per picture, and it does not restart at a sentence — [unit]

Build one motion for a picture the schedule gives 240 frames, and read it at the frames that fall inside each of its
three sentences (the same indices the renderer will hand it).

**Expected**: the window at a sentence boundary is the window the clock says, not the inset base — the motion runs
through the boundary; and a *second* picture's motion, built with its own `firstFrame`, is at rest on its own first
frame regardless of what the first picture was doing.
**Evidence**: `test/video_motion_test.dart` — the two motions' values at the same absolute frame.
**Proves FR-008.**

### 5. The frame shows the inset window, and the words and their plates do not move — [unit]

Paint one slot three times with the same picture: at the cycle's first frame (the inset base), at its peak, and — for
the off path — with no window at all. Use the off-centre four-quadrant picture and the two-band one.

**Expected**: the first paint shows the **inset** framing, not the cover crop — its colour boundaries land where a
1.20 × tighter crop puts them (384 and 252 on the 1080-high frame for the 4032×3024 fixture, against 480 and 300 for
the cover crop) — and the no-window paint shows the cover crop exactly as today (`FR-013`'s second sentence); the peak
paint moves both boundaries within the bound; and the **text area's pixels are identical in all three paints** —
glyphs, plates and ink, byte for byte — with the plate's colour unchanged between the two on-frames even where the
drifted band is darker.
**Evidence**: `test/video_painter_motion_test.dart` — the frame's own bytes, row by row, the text area compared
between the paints.
**Proves FR-001, FR-007, FR-013, SC-004.**

### 6. The renderer's two paths, and the evidence each prints — [unit]

Render one short content with a fake encoder: once with the effect off, once on.

**Expected**: off — the run list is exactly `_stepsOf`'s (one run per line step, `repeat` > 1), no `klhu render
motion` line is printed, and every field of the slot line is what it is today. On — one run per frame with
`repeat: 1`, `totalFrames` unchanged, and one `klhu render motion picture=<i> frames=<a>..<b> cycles=<n>
dirs=<dir>:<px>,…` line per picture whose directions and amplitudes are the motion's own numbers (`FR-012`), printed
beside 012's existing `pictures=`/`time` lines with their fields intact.
**Evidence**: `test/video_renderer_motion_test.dart` and the extended `test/video_renderer_test.dart` — the captured
`debugPrint` lines and the encoder's own `addFrame` calls, in order.
**Proves FR-006, FR-010, FR-011, FR-012.**

### 7. The stored choice, and every way it can fail — [unit]

Read the key absent, holding `on`, holding `off`, holding `garbage`, and with a store that throws on read and on
write.

**Expected**: absent → `off`, and nothing is written; `on` round-trips through one `setString`; `garbage` → `off`
with one logged line and the value **left as it is**; a throwing read → `off` and no prompt blocked; a throwing write
→ the choice still in force for the session. 012's own key is untouched by any of it.
**Evidence**: `test/video_motion_store_test.dart` — the in-memory `SharedPreferences` mock's contents after each
case, and the log line.
**Proves FR-009.**

### 8. The prompt offers the switch, and its answer reaches the render — [unit]

Open the video prompt on a fresh store; open it again with the record holding `on`; toggle it and confirm; toggle it
and cancel.

**Expected**: a fresh prompt shows one row under the format chips with the switch **off**; the record's `on` shows it
on; confirming `on` starts a renderer built with the effect on and writes the record once; cancelling writes nothing,
so the next prompt shows the record it found. The rest of the prompt — the chips, the pictures' count, their window,
Start — is unchanged and in the same order.
**Evidence**: `test/reading_view_video_motion_test.dart` — the switch's value, the injected renderer's own flag, the
store's write count.
**Proves FR-009.**

### 9. A real render's picture moves in every direction, stays inside the bound, and never shows a background — [device]

`klhu_walk_motion.py 9`. Builds the 4032×3024 four-quadrant picture, assigns it to a two-sentence content (one
picture over both sentences), turns the switch on, renders, pulls the file, and samples **every third frame** of the
picture's whole range:

```
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 <file>
ffmpeg -v error -i <file> -vf "select='not(mod(n\,3))'" -vsync 0 -f rawvideo -pix_fmt rgb24 -
```

For each sampled frame: the **column** at which the left quarter turns to the right three quarters, and the **row** at
which the top third turns to the bottom two thirds — between them, where the window sits *and* how tightly it is
cropped — plus the count of pixels equal to the app's background colour inside the frame.

**Expected**: at the cycle's first frames the markers sit at the **inset** crop's own positions (384 and 252, not the
cover crop's 480 and 300) — `FR-013` read off the file; within a sentence and across the two sentences the markers
move; over the whole range each marker's travel is within **192 frame px across and 108 down** (the frame's own
tenth); a `near`/`far` cycle moves the markers the other way (320 and 220 for `near`, 436 and 278 for `far`); the
background-coloured pixel count inside the frame is **0** in every sampled frame; and the motion line's own `dirs=`
values agree with the movement observed.
**Evidence**: `specs/023-video-background-motion/breakpoint.md` row 9 — the per-frame marker positions and the gap
counts, beside the `klhu render motion` line.
**Proves FR-001, FR-005, FR-013, SC-002.**

### 10. The drift is small and slow, and the picture comes to rest every 8 s — [device]

`klhu_walk_motion.py 10`. The same render, decoded once at 480×270 and read frame by frame.

**Expected**: **no step moves the picture by more than ~3 px on the frame's own 1920** (the decode's own resolution is
±4, so a reading of 12 at 480 wide is 3); the picture does move, by 1–2 % of the frame over the cycle; and the framing
that rests recurs once per **240-frame (8 s)** cycle — `SC-003` as the reader's instruction of 2026-10-19 re-cut it. The
still is kept for the reader's own look, and that is the only judgement this row cannot make.
**Evidence**: `breakpoint.md` row 10 — the step maxima, the resting hits' frame numbers, and the still.
**Proves SC-003.**

### 11. The plate's colour over a drifted band — [device] (probe P2)

`klhu_walk_motion.py 11`. A two-band picture (dark above, light below) with the boundary across the middle of the
text's band, the effect on, sampled at the cycle's base frame and at its peak.

**Expected**: the plate's own pixels are **identical** in the two frames (the same colour, the same rect — `FR-007`'s
strongest form), and the ink-over-picture contrast at the peak is recorded as a number: the mean brightness of the
band the words cover, at rest and at the peak, with the difference named. The band can drift up to **108 frame px
down or 192 across** between the two, so this is where §6's trade is measured rather than argued. A peak that leaves
the plate on the wrong side of the tone floor is a **recorded number**, not a failure.
**Evidence**: `breakpoint.md` row 11 — both frames' plate rects and colours, and the two band means.
**Proves FR-007, SC-004.**

### 12. The effect-on render's wall time — [device] (probe P1, and SC-005's number)

`klhu_walk_motion.py 12`. 012's own 17-sentence, one-minute content (its row 36's fixture), rendered on the same
device with the switch **on**. The driver times the prompt's `Start` to the app's done line on the host's clock, and
reads the app's own accounting:

```
klhu render time synth=…ms paint=…ms send=…ms total=…ms finish=…ms sentences=17 pictures=… frames=2078
```

**Expected**: the figure is **recorded whichever way it lands**, and compared with `SC-005`'s ceiling of
**90 885 ms** (1.5 × 012's measured 60 590 ms). `paint=` is read against 012's 182 ms — the arithmetic in
`research.md` §3 predicts ≈ 22 200 ms — and `frames=2078`, `sentences=17` are unchanged from the off render. A figure
above the ceiling is reported with the ladder's first rung applied and re-measured (a 15 Hz window: `repeat: 2`), not
quietly written up as a pass.
**Evidence**: `breakpoint.md` row 12 — both runs (off and on), the app's line quoted, the host's wall clock, and the
device's own model.
**Proves SC-005.**

### 13. What the effect does not change: frames, rate, duration, audio — [device]

`klhu_walk_motion.py 13`. The same content rendered twice — once off, once on — with `ffprobe` reading both files:
`nb_read_frames`, `r_frame_rate`, `duration`, and the audio stream's own md5
(`ffmpeg -v error -i <file> -map 0:a -f md5 -`).

**Expected**: the two files agree on the frame count, the rate, the duration to the millisecond and the audio's md5;
the video stream's own md5 differs (the pictures moved — that is what the bytes are supposed to say).
**Evidence**: `breakpoint.md` row 13 — the two `ffprobe` readings side by side and both md5s.
**Proves FR-010, SC-006.**

### 14. With the effect off, the frames are the pre-feature frames — [device]

`klhu_walk_motion.py 14`, plus one run of `14base` against the base commit's own build — the mode that expects the
motion row to be absent, writing its list to `KLHU_BASE_FRAMEMD5=<file>`. With the switch off: (a) re-run 012's own
frame-measuring rows — its row 32 (42 checks) and its row 49 (41 checks) — on the render this build makes of their
fixtures; (b) take the same content's **per-frame md5s** from this build's off render and from a render made by the base
commit `0ef44e7` (built once in a separate worktree), and compare them frame by frame:

```
ffmpeg -v error -i <file> -map 0:v -f framemd5 -
```

**Expected**: 012's row 32 passes **unchanged** (42/42, no re-cut) and its row 49 comes back **41/41** — after the
one-line re-cut of its own label check, needed because 020's standing "Assign sentences" prompt row had made the
assertion unpassable on **every** build (40/41 on the base commit's build included; re-cut and re-run 2026-10-20, its
own record in 012's `breakpoint.md`); and the two md5 lists are equal, frame
for frame — the off path is the same code and carries no inset, and this is the row that says so in evidence rather
than by inspection. The comparison is per **frame**, not per file: a container carries timestamps, so file-level
`sha256` is not a claim this feature can make and this row does not make it.
**Evidence**: `breakpoint.md` row 14 — 012's two counts, the re-cut's own record and its before/after runs, the two md5
lists' equality and their shared frame count.
**Proves SC-001, FR-011.**

### 15. One new key, four locales, no key left behind — [structural]

```
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb     → 131 in each (130 today)
flutter gen-l10n                                               → clean
flutter test test/l10n_keys_test.dart                          → green, the new key in all four
```

**Expected**: exactly one new message key exists in each of the four ARBs, its four wordings are the feature's own
(the switch's label), the generated localisation carries it for every locale, and no other key's text moved.
**Evidence**: the four counts, the generated file's own key list, the test's output — quoted in `breakpoint.md`
row 15.
**Proves FR-009.**

## Troubleshooting

- **Both markers frozen.** A render whose cycles drew `near`/`far` twice can still move them (320/436 and 220/278) —
  if nothing moves at all, check that the switch's value reached the renderer (`klhu render motion` present, `dirs=`
  non-empty), not just the prompt.
- **A background-coloured pixel inside the frame.** That is `FR-005` failing: read the motion line's cycle and the
  window arithmetic at that frame (`data-model.md`'s invariants 2 and 3), and check the picture the render loaded is
  the one the walk pushed (same basename, same size).
- **The markers are where the cover crop would put them, not the inset's.** That is `FR-013` failing: the render would
  be the pre-amendment framing — check `klhu render motion` was printed at all, and that the painter was handed
  `window: null` only on the off path.
- **`nb_read_frames` short by a few.** `ffprobe -count_frames` on a video the encoder has only just finished can race
  the file's flush; wait for the app's done line before pulling the file (012's walk already does).
- **The walk cannot find the device.** `ADB_SERIAL` — this box has more than one device attached, and a bare `adb`
  refuses rather than picking one.
