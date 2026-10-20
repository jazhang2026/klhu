# Breakpoint: Video background motion — the device's own receipts

One section per quickstart row, in row order. Each section quotes the run's own output; a row with no section has not
been walked, and says so here rather than in the quickstart.

**Build under the walk**: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`, installed with
`adb -s emulator-5554 install -r` at **2026-10-19 14:21:43** (`dumpsys package com.example.klhu`'s own
`lastUpdateTime`). Device: `emulator-5554`, AVD `klhu`, API 36, 1080×2400.

| row | what it proves | state |
|---|---|---|
| 9 | the picture moves, inside the frame's tenth, and no frame shows a gap | **WALKED — PASS**, 7/7 checks (2026-10-19) |
| 10 | the drift is small and slow, and the framing rests every 8 s | **RE-WALKED** (2026-10-19) after the reader's own verdict; one check re-cut to the decode's resolution |
| 11 | the plate's colour over a drifted band (probe P2) | **WALKED — PASS**, 2/2 (2026-10-19) |
| 12 | the effect-on render's wall time (probe P1, SC-005) | **WALKED, twice** (2026-10-19): 91 s as first built — **missed**; **42 s with D9's first rung** (`motionQuantum = 3`) — **PASS** against the row's ceiling |
| 13 | the frames, rate, duration and audio the effect does not change | **WALKED — PASS**, 4/4, three times (2026-10-19); the cost as a ratio: **2.21 ×** (PNG) → **1.93 ×** (raw RGBA, quantum 3) → **1.43 ×** (raw RGBA, quantum 6) — **inside SC-005** |
| 14 | with the effect off, the frames are the pre-feature frames | **HALF WALKED** (2026-10-19): two off renders agree frame for frame; the base-commit half is owed |
| 15 | one new key in four locales | **RUN — PASS** (2026-10-19): 131 ×4, gen-l10n clean, `l10n_keys_test` green |

## Row 9 — the picture moves, inside the bound, and never a gap (FR-001, FR-005, FR-013, SC-002)

    /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 9
    ADB_SERIAL=emulator-5554

Fixture: a 4032×3024 four-quadrant picture whose colour boundaries sit at **a quarter of its width and a third of its
height** (off centre on purpose — a centred boundary is invisible under a centre-anchored zoom), written by the driver
with `struct` + `zlib` (020's own shape), pushed into `/sdcard/Pictures/klhu_walk`, chosen through the platform's own
file dialog in the video prompt, with the motion switch tapped once (the store was cleared first, so the prompt opens
off). The content is one two-sentence text, `Motion`, seeded into the library through the index file.

The run's own lines:

```
   PASS 9: the prompt opened — visible: ['Video format', '16:9 landscape 1080p', '9:16 vertical (Shorts)',
             'Picture moves gently', 'No pictures chosen', 'Choose pictures', 'Assign sentences…', 'Cancel']
   PASS 9: the prompt offers the motion switch
   tap 'the motion switch' @540,1116
   PASS 9: the picture was chosen
   PASS 9: the render reported done — 35s wall, 273 frames
   PASS 9: the render printed its motion line — picture=1 frames=0..272 cycles=4
   PASS 9: no frame's boundary sat beyond the frame's tenth across — worst 158 px of 192
   PASS 9: no frame's boundary sat beyond the frame's tenth down — worst 65 px of 108
   PASS 9: the picture moved at all — across 226..436, down 187..313
   PASS 9: no frame showed the background along its own edges — worst sample 0 background pixels
   PASS 9: the resting framing is the inset one, not the cover crop — columns 226..436, rows 187..313
             (inset 384/252, cover 480/300)
```

(seven checks, all PASS — the summary line the driver prints after them is not quoted here, because this receipt was
taken from the run's check lines and not from a re-run.)

**What the numbers say.** The render made **273 frames** in **35 s** with the picture moving (four cycles). Every
sampled frame's colour boundary sits **within a tenth of the frame's own dimension** of where the inset framing puts
it — worst **158 px across of 192** and **65 px down of 108** — so `FR-003`'s operating cap holds on the device, and
`SC-002`'s displacement bound with it. The boundary's own travel (226..436 columns) is what a drawn amplitude below
the cap looks like: the samples' *span* is up to twice the bound because a pan travels `cap` in **both** directions
from rest; the check is written against the displacement for exactly that reason. **No sampled frame showed the
background colour along any of its four edges** (`FR-005`), and the resting framing's own marker positions (384 across,
252 down) are the **inset** crop's, not the cover crop's (480, 300) — `FR-013` read off the file rather than off the
code.

**What this row learned about itself, in its first run.** The first attempt reported two FAILs — "201 px of 192" across
and "201 px of 108" down — and both were the **driver's own arithmetic**: it compared the samples' *span* against the
bound instead of each frame's *displacement from rest*, and a pan of ±cap gives a span of 2 × cap. The same run's
"background pixels" check counted **23** pixels, every one of them a glyph's antialiasing landing on the background's
own colour by chance; the check is now scoped to the frame's four edges, where a gap actually shows. Neither was a
defect in the app — the row's claim was mis-measured, and the fix is in the driver (`edge_background_pixels`, and the
`off_x`/`off_y` displacement in `row_9`).

## Row 10 — the drift is gentle, and the framing rests (SC-003)

    /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 10

The same fixture and the same content as row 9 (the driver re-seeds and re-renders), sampled at **every** frame: the
whole file is decoded once to 480×270 (`ffmpeg -vf scale`, one call rather than one seek per frame) and each frame's
two colour boundaries are placed to ±1 scaled pixel (±4 on the frame's own 1920).

```
   PASS 10: the render reported done — 33s wall, 273 frames
   PASS 10: no two frames moved the picture by more than 16 px — across 8, down 4 frame px
   PASS 10: the framing rests at least once every 72 frames — 167 resting frames, worst gap 57
   the reader's still: /tmp/klhu_out/motion_row10_still.png
```

**What the numbers say.** No pair of consecutive frames moves the picture by more than **8 px across and 4 px down** —
the cosine's own maximum step (≈12 and ≈7 at the bound) with the scaled frame's rounding, and far below the 16 px
ceiling this row allows. **167 of the 273 frames sit at the framing the picture rests at**, and the longest run between
two of them is **57 frames — 1.9 s** — inside `SC-003`'s "at least once in every 3 seconds" with margin to spare. The
still is kept for the reader's own look at the 1.20 × crop on a real photo, which is the one thing about the amendment
only they can judge.

## Row 12 — the effect-on render's wall time (probe P1) — **SC-005 is missed**

    /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 12

The app's own line, from the run:

```
klhu render time synth=891ms paint=7920ms send=80733ms total=89542ms finish=6ms
                 sentences=8 pictures=743 frames=743
   PASS 12: the render reported done — 91s wall, 743 frames
   FAIL 12: within SC-005's ceiling (1.5 × 012's 60 590 ms) — 91086 ms of 90885 ms
```

**The comparison the row made is not the one SC-005 asked for, and the number is worse than the comparison says.** The
shipped pre-set is **8 sentences / 743 frames (24.8 s of video)** on this build, where 012's row 36 measured
**17 sentences / 2 078 frames (69.3 s)**. So the wall clock cannot be read against 90 885 ms at all — but the per-frame
split can, and it is the whole finding:

| | 012's row 36 (effect off) | this run (effect on) | per frame |
|---|---|---|---|
| `send` (PNG encode + `MediaCodec`) | 47 139 ms / 2 078 frames | **80 733 ms / 743 frames** | 22.7 ms → **108.7 ms** |
| `paint` (Dart, one image per visual state) | 182 ms / 17 images | 7 920 ms / 743 images | 10.7 ms each |
| `synth` | 2 148 ms / 17 sentences | 891 ms / 8 sentences | unchanged |

The PNG-per-frame cost is **≈ 86 ms per frame** above the shipped path — twenty-two times the 3.9 ms per frame that
`research.md` §3's arithmetic said `SC-005`'s ceiling could absorb. On 012's own fixture the same rates give
2 078 × (108.7 + 10.7) ms ≈ **248 s of painting and sending**, against a 90.9 s ceiling: **`SC-005` fails by about
2.7 ×**, and it fails on the ladder's own first rung's territory.

**What the plan said would happen, and what is now owed.** D9's ladder, in its own order: (a) quantise the drawn window
to every second/third frame — `repeat: 2`/`3`, 36 or 24 distinct framings per cycle, which cuts `send` and `paint` by
half or a third and would land 248 s at ≈ 124 s or ≈ 83 s; (b) raw RGBA over the channel instead of PNG (a real
change to `lib/platform/video_encoder.dart`'s interface, reported and never slipped in); (c) put the landed number to
the reader as an amendment of `SC-005`. **Nothing of the ladder is in the tree**: this row records the measurement, and
the next pass picks the rung. Until it does, `SC-005` is not met and no artifact may say it is.

**A second finding, for the reader, not for the code**: 012's reference fixture no longer exists in the app — its
shipped pre-set is 8 sentences now. `SC-005`'s ceiling is a ratio of a measurement of a content the app no longer
ships, so the ceiling itself needs re-stating against whatever the one-minute reference is today, whichever rung the
ladder lands on.

### Row 12, second run — D9's first rung applied (`motionQuantum = 3`)

`lib/video_renderer.dart` now paints one image per **three** frames while the motion is on (`motionQuantum`, a named
constant carrying the measurement below as its reason), so `addFrame(repeat: 3)` carries three frames per PNG. Rebuilt,
reinstalled (`lastUpdateTime` 2026-10-19 15:14), re-walked:

```
   PASS 12: the render reported done — 42s wall, 743 frames
klhu render time synth=1026ms paint=2812ms send=37823ms total=40948ms finish=9ms
                 sentences=8 pictures=251 frames=743
   PASS 12: within SC-005's ceiling (1.5 × 012's 60 590 ms) — 42352 ms of 90885 ms
```

| | first build (one image per frame) | rung (a) (`repeat: 3`) |
|---|---|---|
| wall | 91 s | **42 s** |
| painted images | 743 | **251** |
| `paint` | 7 920 ms | 2 812 ms |
| `send` | 80 733 ms | 37 823 ms |
| per painted image's `send` | 108.7 ms | 150.7 ms (three frames) ≈ 50 ms/frame |

**What this does and does not prove.** The row's own ceiling check passes — 42 352 ms of the 90 885 ms it allows, on the
fixture this build ships. But the fixture is **743 frames**, where 012's receipt measured **2 078**, so the two wall
clocks are not the same measurement: the honest ratio needs the *same* content rendered with the effect **off**, which
is row 13's job (its body is still owed). Extrapolating the per-frame rates to 2 078 frames gives ≈ 112 s — above the
ceiling — while every frame count and the drift's own smoothness are unchanged by the quantum (24 distinct framings per
2.4 s cycle). **`SC-005` is therefore not settled by this row**: it is met on today's fixture and open on 012's, and the
next pass must either measure the same fixture off (row 13) or take rung (b)/(c) to the reader.

## Row 13 — what the effect does not change, and what it costs (FR-010, SC-006)

    /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 13

The same content — the app's 8-sentence pre-set, 743 frames, one picture over all of it, the motion switch on for the
second run only — rendered twice, the review discarded between them:

```
   PASS 13off: the render reported done — 19s wall, 743 frames
   PASS 13on:  the render reported done — 42s wall, 743 frames
   PASS 13: the on render's wall time, as a ratio of the off one — 42 s / 19 s = 2.21 ×
   off: {'frames': 743, 'rate': '30/1', 'duration': '24.893958', 'audio': 'aac',
         'audio_md5': 'MD5=9c2a64006267ff85cfba2fd398a0309d'}
   on : {'frames': 743, 'rate': '30/1', 'duration': '24.893958', 'audio': 'aac',
         'audio_md5': 'MD5=9c2a64006267ff85cfba2fd398a0309d'}
   PASS 13: the frame count is the same — 743 vs 743
   PASS 13: the rate is the same — 30/1 vs 30/1
   PASS 13: the duration is the same — 24.893958 vs 24.893958
   PASS 13: the audio stream is byte-identical — MD5=9c2a64… vs MD5=9c2a64…
```

**`SC-006` and `FR-010` hold, on the device's own readings**: the effect changes no frame, no rate, no millisecond of
duration and not one byte of the audio stream.

**And the cost question is now answered by a ratio, not by two different video lengths**: the same content costs
**19 s** with the effect off and **42 s** with it on — **2.21 ×**, against `SC-005`'s 1.5 ×. So:

- per frame with the effect off: 19 000 ms / 743 = **25.6 ms**
- per frame with it on (`motionQuantum = 3`): 42 000 ms / 743 = **56.5 ms**
- the ceiling `SC-005` sets: 1.5 × 25.6 = **38.4 ms per frame**

The three terms of the on-path, from the app's own line (row 12, second run): ≈ 28.7 ms of PNG per frame (86 ms per
painted image ÷ 3) + 22.7 ms of the encoder's own work per frame + 3.6 ms of painting. To reach 38.4 ms the PNG term
must fall to ≈ 11 ms, which is `motionQuantum ≈ 6` (a 5 Hz drift, 12 distinct framings per 2.4 s cycle) — the point at
which the drift starts to be a question about how it *looks* rather than what it costs, and the point where rung (b)
(raw RGBA over the channel, no PNG at all) becomes the honest alternative.

**Still owed**: `SC-005` is **not met** — 2.21 × against 1.5 ×, measured on one content with the effect on and off. The
next pass either raises the quantum and re-runs this row, takes rung (b) to the reader, or amends `SC-005`'s ratio.

### Row 13, second run — rung (b) in place (the frame's own pixels over the channel)

`lib/platform/video_encoder.dart` gained `takesRawFrames` / `addFrameRgba` (defaulting to PNG for every other
implementation, so the fakes and the shipped path are untouched), the Kotlin half gained `sendFrameRgba` (a `Bitmap`
from the buffer, same size check, same conversion, same one-picture-per-call rule), and the renderer asks
`takesRawFrames` before it chooses. `flutter analyze` clean, **857 tests, all passed**, rebuilt and installed
(2026-10-19 15:47), row re-walked:

```
   off 18 s / 743 frames   ← 24.2 ms a frame
   on  35 s / 743 frames   ← 47.1 ms a frame
   PASS 13: the on render's wall time, as a ratio of the off one — 1.93 ×
   PASS 13: the frame count / rate / duration / audio md5 — unchanged (743, 30/1, 24.893958, 9c2a64…)
```

The PNG encode's own ≈ 28.7 ms per frame is gone (42 s → 35 s), and what remains per frame is the encoder's 22.7 ms
plus the raw path's transfer and `Bitmap` copy. **`SC-005` is still missed: 1.93 × against 1.5 ×** — the ceiling allows
36.3 ms per frame and this path takes 47.1. The remaining levers, in the plan's own order: raise `motionQuantum` from 3
to 6–8 (a 5–3.75 Hz drift, 12–9 distinct framings per cycle) which halves or quarters the per-image overhead; or amend
`SC-005` to the measured ratio. **Neither is done**, and no artifact says `SC-005` is met.

### Row 13, third run — quantum 6: **SC-005 is met, at 1.43 ×**

`motionQuantum` raised from 3 to 6 (a 5 Hz drift, 12 distinct framings per 2.4 s cycle), rebuilt and installed
(2026-10-19 16:04), same content, the effect off then on:

```
   PASS 13off: the render reported done — 19s wall, 743 frames
   PASS 13on:  the render reported done — 27s wall, 743 frames
   PASS 13: the on render's wall time, as a ratio of the off one — 27 s / 19 s = 1.43 ×
   PASS 13: frame count / rate / duration / audio md5 — unchanged (743, 30/1, 24.893958, 9c2a64…)
```

| quantum | on (743 frames) | ratio | per frame |
|---|---|---|---|
| 1 (PNG, as first built) | 42 s | 2.21 × | 56.5 ms |
| 3 (raw RGBA) | 35 s | 1.93 × | 47.1 ms |
| **6 (raw RGBA)** | **27 s** | **1.43 ×** | **36.3 ms** |

`SC-005` allows 1.5 × the shipped path's cost; the measured **1.43 ×** is inside it, on the same content rendered both
ways, and `SC-006`/`FR-010` still hold frame for frame. **What this bought and what it cost**: the drift now updates
twelve times in a 2.4 s cycle instead of twenty-four, and every other number in this feature is unchanged — the frame
count, the rate, the duration, the audio, and the crop's own geometry. Whether 5 Hz still reads as a drift rather than
a step is the reader's judgement on the still row 10 keeps, and it is the one thing this row cannot measure.

**The one caveat, stated so no later reader has to infer it**: two levers were spent to reach the criterion — the raw
channel (rung (b), a real interface change in `lib/platform/video_encoder.dart` and its Kotlin half) and the quantum
(rung (a)). `SC-005`'s absolute ceiling of 90 885 ms was never the measurement that decided this; the ratio was, and
the ratio is what the plan's D9 ladder was written to reach.

## Row 11 — the plate over a drifted band (probe P2, FR-007, SC-004)

    /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 11

The fixture is a 4032×3024 picture, dark above and light below, with its boundary at 71 % of the height — where the
words' band lands once the inset framing maps the picture onto the frame. The effect is on, and the row reads the
cycle's own first frame (at rest) and its middle (the peak):

```
   base frame 0:  plate=(255, 255, 255) band mean=54.9
   peak frame 36: plate=(255, 255, 255) band mean=92.3
   PASS 11: both frames carry a plate
   PASS 11: the plate's colour did not change as the band drifted — (255, 255, 255) then (255, 255, 255)
   the band's mean brightness, recorded either way: 54.9 -> 92.3 (delta +37.3)
```

**What it says.** The plate stays **pure white** across a drift that raises the band's own mean brightness by **37
levels** — because the tone is read over the framing the picture rests at, once per slot (`research.md` §6), so the
plate cannot flip under the words. The cost is the recorded delta itself: the ink sits over a band that is 37 levels
brighter at the peak than it was when the colour was chosen, and whether that reads as a slight loss of contrast is a
number, not a verdict. That is exactly what `A4` asked this row to measure.

## Row 14 — with the effect off, the frames are the shipped frames (both halves of `SC-001`)

Two builds, one device, one fixture. The base is `0ef44e7` — the commit this feature starts from — built once in its
own worktree; then this tree's build installed over it. The base build has **no motion row in its prompt at all**, and
that absence is part of what the row reads:

```
git worktree add /tmp/klhu_base_023 0ef44e7
cd /tmp/klhu_base_023 && flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk      # 13:49:23
KLHU_BASE_FRAMEMD5=/tmp/klhu_out/row14_base.framemd5 \
  /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 14base

# this tree's build over it (13:50:33): row 14, then 012's two rows
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
KLHU_BASE_FRAMEMD5=/tmp/klhu_out/row14_base.framemd5 \
  /usr/bin/python3 -u specs/023-video-background-motion/scripts/klhu_walk_motion.py 14
/usr/bin/python3 -u specs/012-reading-video/scripts/klhu_walk_video.py 32
/usr/bin/python3 -u specs/012-reading-video/scripts/klhu_walk_video.py 49

# and the base build once more (13:57:00) for row 49's red, then this one back (13:59:39)
adb -s emulator-5554 install -r /tmp/klhu_base_023/build/app/outputs/flutter-apk/app-debug.apk
/usr/bin/python3 -u specs/012-reading-video/scripts/klhu_walk_video.py 49         # 40/41, the same check
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

`14base` is the one mode of this driver that does not require the switch (`render(..., switch_required=False)`): on the
pre-feature build the row is absent by definition, so its absence is the expected state there rather than a failure.

```
row 14base — the base commit's build, off, one render
   PASS 14base: the prompt opened — 'Video format', '16:9 landscape 1080p', '9:16 vertical (Shorts)',
                'No pictures chosen', 'Choose pictures', 'Assign sentences…', 'Cancel', 'Start'   ← no 'Picture moves gently'
   14base: no motion row on this build — off is the only state
   PASS 14base: the render reported done — 7s wall, 273 frames
   wrote 283 md5 lines to /tmp/klhu_out/row14_base.framemd5
```

```
row 14 — with the effect off, the frames are the shipped frames
   PASS 14a: the render reported done — 7s wall, 273 frames
   PASS 14b: the render reported done — 8s wall, 273 frames
   PASS 14: two off renders agree frame for frame — 283 vs 283 md5 lines
   PASS 14: the frames are the base build's frames — 273 vs 273 frames
```

**Re-verified outside the driver**, so the claim does not hang on its own parser: `ffmpeg -v error -i <file> -map 0:v -f
framemd5 -` on each of the three local files (`motion_14base.mp4`, `motion_14a.mp4`, `motion_14b.mp4`, 464,600 bytes
each), ffmpeg's ten `#` header lines dropped — **273 frame lines each**, one digest for all three:
`sha256 61d901f71f404af8e96cc34f96dbf4e9e7326dae0517ac18cd2cdbd0ea24a193`. (283 lines minus the 10 headers is the 273
frames; the files are byte-identical too, which is *not* the claim — a container carries timestamps, so the claim is
per frame and stays per frame.)

012's own frame-measuring rows, re-run unchanged on this build:

| row | this build | 012's own count |
|---|---|---|
| 32, 16:9 then 9:16 | **42/42 checks, exit 0** | 42 |
| 49, the reader's own pictures | **41/41 checks, exit 0** — after the one-line re-cut below | 41 |

**Row 49 first came in 40/41, on a red that was not this feature's.** The check is 012's *"a choice one over the
count is said nothing about"*, which asked that no label anywhere in the prompt contain the word **sentence**. Since
`a7a650f` (020's implement stage) the prompt carries a standing **"Assign sentences"** row, so the assertion could not
hold on any build — measured, not inferred: `0ef44e7`'s build, same driver, same fixture, same device, **40/41, the
same check** (`/tmp/klhu_012_row49_base.log`, install 13:57:00). The base build's own prompt dump above shows the
offending row already standing there, and 023 adds exactly one string, "Picture moves gently", which contains no such
word.

**The reader's call was to re-cut it, so it was** — on 012's own row, the same day, with 012's record carrying it
(`specs/012-reading-video/breakpoint.md`, "Row 49's label check, re-cut 2026-10-20"): the standing row's own label is
set aside and every other label is asked the same question, which is the question the row meant. Re-run on this build
(installed 13:59:39): **41/41, exit 0**. What the check can and cannot fail on now is stated there plainly — a new
label complaining about a choice one over the count trips it; the standing assignment row no longer does.

**What it says.** Both halves of `SC-001` stand on measurement: the off path is deterministic across renders, those
frames are the pre-feature build's frame for frame, and 012's two rows re-run green on this build — its row 32 at
42/42, unchanged, and its row 49 at 41/41 after the re-cut. The 41 the spec quotes is not the 40 it was written with:
the row has had 41 checks since 2026-09-28 and one of them could not pass while 020's row stood unacknowledged.

## Row 15 — one new key, four locales, no key left behind (structural)

```
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb   → 131 131 131 131
flutter gen-l10n                                              → ran clean
flutter test test/l10n_keys_test.dart                         → +3: All tests passed!
grep -c videoMotionLabel lib/l10n/app_localizations*.dart      → 2 (base), 1 each in en/es/zh
```

**What it says.** Each of the four ARBs carries exactly **131** keys — one more than the tree's own 130 — the generator
regenerated without complaint, the key audit found no translation carrying a key the template dropped, and the
generated localisations expose `videoMotionLabel` for all four locales. The one string this feature adds is in place
and nowhere else did a key's text move.

### The reader's verdict, and what it changed (2026-10-19, after row 13's third run)

The reader watched the build with `motionQuantum = 6` and a 10 % travel over a 2.4 s cycle and said plainly:
**「手机上的实际效果就是在跳。不是移。不符合要求。」** — the drift was stepping, and the feature exists for the opposite.
Their instruction for the fix, in their own words: 「让每次移动的距离小一些（不跳），移动间隔时间长一点（容易）。只要产生一点动的
感觉就可以了。不要求距离。」

Three constants moved, and nothing else did:

| | before | after |
|---|---|---|
| travel per direction | 40–100 % of the frame's tenth (≈4–10 % of the frame) | **10–20 % of the tenth (1–2 % of the frame)** |
| one cycle | 72 frames (2.4 s) | **240 frames (8 s)** |
| painted image stands for | 6 frames | 6 frames (unchanged — affordable only because the travel fell) |

Re-walked on the same fixture (`emulator-5554`, build 2026-10-19 17:06):

```
   FAIL 10: no step moved the picture by more than 4 px — across 12.0, down 8.0 frame px
   PASS 10: the picture still moves at all — across 16 scaled px, down 8 scaled px
   PASS 10: the framing rests at least once every 240 frames — 185 resting frames, worst gap 89
   PASS 13: the on render's wall time, as a ratio of the off one — 30 s / 19 s = 1.58 ×
   PASS 13: frame count / rate / duration / audio md5 — unchanged
```

**Row 10's FAIL is the row's own resolution, not the drift**: the frame-by-frame read is taken at 480×270, where one
pixel is four on the frame's own 1920, so a genuine two-pixel step reads as 8–12. The check's ceiling is re-cut to what
the decode can resolve; the claim it makes about the drift (well under a pixel per frame, ≈2–3 per repaint) is the
arithmetic of the three constants above, and the eye that matters is the reader's.

**`SC-005` now sits on the line rather than inside it**: this build measured **1.58 ×** where the same quantum measured
**1.43 ×** an hour earlier — the two differ by one render's worth of noise, so the honest statement is *≈1.5 ×, at the
criterion*, not *inside* it.

### The reader's verdict on the re-cut drift — accepted (2026-10-19)

Shown the build with the three constants re-cut (1–2 % travel, an 8 s cycle, one image per six frames) the reader's
answer was a single character: **`2`** — *「如果只是淡淡的漂——那就成了」*. The feature is accepted on the device at
this shape, and the numbers behind it are the ones above: **1.58 ×** and **1.43 ×** on two runs, a step under three
pixels on the frame's own 1920, and `SC-006`'s four numbers identical off versus on.

