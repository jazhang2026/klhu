# Implementation plan: the pictures in a video breathe

**Feature**: `023-video-background-motion` | **Spec**: [spec.md](./spec.md) | **Date**: 2026-10-19
**Research**: [research.md](./research.md) | **Data model**: [data-model.md](./data-model.md) |
**Contract**: [contracts/video-motion-record.md](./contracts/video-motion-record.md) | **Validation**:
[quickstart.md](./quickstart.md)

**The spec was amended at this stage's gate — the reader's answer `B` — and this plan implements the amended text.**
The plan's first pass found that a cover crop leaves a picture room on one axis only, so the item's diagonals could be
offered to nobody and 「远」 could only be a cycle's return leg. The reader's answer: **inset the framing before the
picture moves**, and read the bound on the frame's own dimension (long side more, short side less). The amendment's
ids are `FR-013` (the inset) plus rewritten `FR-002`, `FR-003`, `FR-005`, `FR-008`, `A2` and `US2`'s third scenario;
the Clarifications carry their own words, and [research.md](./research.md) § Grounding corrections records the finding
each one answers.

## Summary

Today a rendered video's picture is a still: `VideoPainter.paint` draws `_coverSource(picture)` into the frame
(`lib/video_painter.dart:432`) and the renderer paints **one image per visual state**, reusing it across the run's
frames (`lib/video_renderer.dart:324-337`). This feature makes the window that is drawn a function of the frame's own
number: a new pure module (`lib/video_motion.dart`) insets the cover crop by a twelfth per side (a 1.20 × tighter
framing, `FR-013`) and then turns `(that framing, the picture's elapsed frames)` into a source rect that drifts in any
of ten directions — eight compass points, nearer, farther — never more than a tenth of **the frame's** own dimension
and never outside the picture. The painter is handed that rect; the renderer paints one frame at a time when the
effect is on; the video prompt gains one switch, off by default, remembered per device. With the switch off, none of
this code runs and the file is the one the app produces today.

## Technical Context

| item | value | evidence |
|---|---|---|
| language / SDK | Dart, SDK `^3.13.3`; Flutter 3.47.5 stable | `pubspec.yaml:22`, `flutter --version` |
| dependencies | unchanged: `flutter_tts ^4.2.3`, `shared_preferences ^2.5.5`; **nothing added** | `pubspec.yaml:39-40` |
| storage | `shared_preferences`, one new key `video_motion` (`on` \| `off`) | research §5, the contract |
| testing | `flutter test --concurrency=2`, baseline **825 tests** (2026-10-19); `flutter analyze` clean | research §1 |
| target | Android `emulator-5554` (API 36); iOS is not validated on this box | research §1 |
| performance | `SC-005`: ≤ 90 885 ms (1.5 × 012's 60 590 ms) for the one-minute reference render, **to be measured** | research §3 |
| scale / scope | one picture rule, one store key, one prompt row, one painter parameter | below |

## Constitution Check

| principle (as the constitution names it) | gate |
|---|---|
| **I. Flutter Single Codebase** | **Pass.** All of it is Dart in `lib/`. No platform channel, no Kotlin, no Swift: the encoder already takes one image standing for N frames (`lib/platform/video_encoder.dart:68`), and the effect uses `repeat: 1`. |
| **II. Spec-Driven (NON-NEGOTIABLE)** | **Pass.** Everything implemented here is `FR-001`…`FR-013` / `SC-001`…`SC-006` of the amended spec. The amendment was the reader's own (`B`, this stage's gate), it is recorded in the spec's dated Clarifications entry with its refusals, and it left the ids in place rather than adding behaviour with none. |
| **III. Test-First (NON-NEGOTIABLE)** | **Pass.** The eight `[unit]` rows are written and run RED before their code (the new modules' tests are compile failures first); the device rows follow the code; every row names its file and its `FR`/`SC` ids, and the suite's count is added to, never replaced. |
| **IV. On-Device First** | **Pass.** Nothing leaves the device: no network, no account, no analytics. The motion is arithmetic done on the phone and written into the file, which is the spec's `FR-006`. |
| **V. Simplicity** | **Pass.** One pure module, one optional painter parameter, one renderer flag, one store key, one string. No new dependency, no new timeline, no second painter. Complexity Tracking is empty because there is nothing to justify. |

## Decisions the user can see

Each of these changes something the reader looks at, so each is stated here as well as in the handback. The gate's
choice among them is recorded in the specification's Clarifications; this section states what the plan now does.

1. **The switch, where it is, and its default.** One row under the two format chips, labelled by one new string, **off**
   on a fresh device and remembered afterwards. The consequence: the prompt the reader already knows gains one line;
   the chips, the pictures, their count and Start do not move.
2. **What a picture can do — the reader's `B`.** The framing is inset first, so **every picture gets all ten
   directions**: up, down, left, right, the four diagonals, nearer and farther. The price they accepted with it: with
   the effect on, a picture is shown **1.20 × tighter** than the same video shows it today — 69.4 % of the cover crop's
   area, and a 4032×3024 photo in a 16:9 frame loses 336 px of width and 189 px of height at rest. With the effect
   off, none of that applies. (`k = 5/6` is the exact inset that makes the frame's tenth reachable on both axes; the
   refused alternatives — a tenth per side at 1.25 ×, equal on-screen pixels at 1.56 × — are in the spec's entry.)
3. **How big and how fast the drift is.** A tenth of **the frame's** own dimension per direction — on 16:9 up to
   192 px across and 108 px down, on 9:16 the two swap — drawn between 40 % and 100 % of that each cycle, 2.4 s a
   cycle. The consequence: on the 4032×3024 photo the largest drift is 336 px sideways or 189 px down over 1.2 s, and
   most cycles are smaller; a one-minute video with one picture goes through ~29 cycles.
4. **What it costs.** One painted frame per frame instead of per visual state. `research.md` §3's arithmetic puts that
   at **1.37 ×** the old render before the per-frame PNG encode, inside `SC-005`'s 1.5 × ceiling by about 8 s — which
   is why the number is measured (`P1`) rather than promised, and why the first fallback (a 15 Hz drift, still 36
   distinct framings per cycle) is named in advance.

## Decisions

The numbering is [research.md](./research.md)'s own; this plan introduces no `D` of its own. One line each, with the
cost the reader or the next stage pays.

| # | decision | what it costs |
|---|---|---|
| D1 | The clock is the picture's own elapsed frames, cut into cycles of ≤ 72 frames, shaped by `(1-cos 2πu)/2` | a cycle that a short slot compresses; a picture's last cycle may be cut short |
| D2 | The rule is one pure module; the painter takes an optional window and keeps reading its tone at the **inset** framing | a source rect instead of `_coverSource` inside one call; the plate's colour can differ from an off render's; §6's small contrast trade |
| D3 | With the effect on, one painted frame per frame; with it off, today's code path, untouched | the cost of §3 (measured by `P1`) |
| D4 | Evidence is one `klhu render motion` line per picture; the slot line keeps its fields and prints once per slot | one more line family in the log; the on-path's slot lines are per slot, not per state |
| D5 | The base framing is `5/6` of the cover crop and all **ten** directions are available; `far` stops at the cover crop | the 1.20 × tighter crop, and `far`'s travel bounded by the inset rather than by a tenth of its own |
| D6 | Amplitude drawn 40–100 % of the frame's tenth; directions and amplitudes drawn once per picture, unseeded | variety, and a render that is not reproducible (the spec refuses one) |
| D7 | The choice is its own key, written on the prompt's confirm | one more record on the device; 012's contract untouched |
| D8 | One switch row under the format chips, one ARB key in four locales | one line on the prompt, 130 → 131 keys |
| D9 | The cost is a measured row with a ladder | `SC-005` is not claimed until row 12 runs |

## The ripple, file by file

- **`lib/video_painter.dart`** — `paint` gains `MotionFraming? framing` (the drawn rect **and** the resting one — §6's
  tone is read over the second, so one rect could not express it); the one `drawImageRect` call (`:432`) uses the first
  when it is given. `_toneOf`/`_bandsOf` map the words' band through **the inset framing** (`:546` is the cover draw they use
  today), so the plate's colour is constant within a slot (`FR-007`) and is read over the framing the frame shows —
  which is also why an on-render's plate can differ from an off-render's for the same picture.
  `scrollSteps` and the text geometry are untouched.
- **`lib/video_renderer.dart`** — a `motion` flag; the run list is built per frame in the new branch (the old
  `_stepsOf` path stays as it is); the picture's own `startFrame` comes from the schedule it already holds
  (`lib/video_renderer.dart:300`); the motion line is printed beside `klhu render pictures=`
  (`lib/video_renderer.dart:305`); the slot line moves to the slot's first frame in the new branch only. `addFrame`
  keeps its signature.
- **`lib/reading_view.dart`** — the prompt reads the record when it opens beside `_aspects.load()`
  (`lib/reading_view.dart:1943`), shows the switch at `lib/reading_view.dart:2034`, saves it with the aspect's own
  save (`lib/reading_view.dart:1975`), and hands the flag to `VideoRenderer` at `lib/reading_view.dart:2459` through
  `_startRender` (`lib/reading_view.dart:2422`).
- **`spec.md`** — amended at this gate, not by a later stage: the dated Clarifications entry, `FR-002`, `FR-003`,
  `FR-005`, `FR-008`, the new `FR-013`, `A2`, `US2`'s third scenario, and the Key Entities' framing. The amendment is
  the reader's; every later stage reads these ids.
- **012's own artifacts** — `specs/012-reading-video/contracts/video-aspect-format.md` still describes the format's
  record exactly as it is: this plan adds a **sibling** key and edits nothing of 012's. Its row 36 is re-taken by this
  feature's row 12, and its rows 32 and 49 are re-run by row 14; **those are reported, never re-cut** (they are true
  of the feature they belong to). Its cover crop is still what the app draws with the effect off, and still the outer
  wall with it on.
- **The l10n count** — 130 → 131 in each of the four ARBs; every receipt that quotes 130 is a figure about this tree
  before this feature, and row 15 states the new one.

## Project Structure

```
specs/023-video-background-motion/
├── spec.md                      (amended 2026-10-19 at this gate: FR-013, FR-002/003/005/008, A2, US2-3)
├── plan.md · research.md · data-model.md · quickstart.md          ← the plan stage
├── tasks.md                                                       ← the tasks stage (27 rows)
├── contracts/video-motion-record.md                               ← the plan stage
├── scripts/klhu_walk_motion.py                                    ← implement: rows 9-14, the fixtures
├── breakpoint.md                                                  ← implement: each row's own receipt
└── checklists/requirements.md     (the specify stage's, with this amendment's notes)

lib/
├── video_motion.dart            ** NEW ** the rule: the inset, caps, directions, cycles, windowAt (pure)
├── video_motion_store.dart      ** NEW ** the reader's choice, key video_motion
├── video_painter.dart           extended: paint(..., framing:) — tone read at the inset framing
├── video_renderer.dart          extended: motion flag, per-frame runs, the motion line
├── reading_view.dart            extended: the switch, the store, the flag
├── platform/video_encoder.dart  UNTOUCHED (addFrame's repeat already carries 1..n)
└── l10n/app_{en,zh,zh_Hans,es}.arb + generated   extended: one new key, 130 → 131

test/
├── video_motion_test.dart              ** NEW ** rows 1-4
├── video_painter_motion_test.dart      ** NEW ** row 5
├── video_renderer_motion_test.dart     ** NEW ** row 6 (with video_renderer_test.dart extended)
├── video_motion_store_test.dart        ** NEW ** row 7
└── reading_view_video_motion_test.dart ** NEW ** row 8
```

## What this re-measures

- **012's row 36**: 60 590 ms / 2078 frames for the one-minute reference render — re-taken with the effect **on**
  (this feature's row 12) and quoted beside it, never replaced. Its own receipt stays as it was.
- **012's rows 32 and 49** (42 and 40 checks): re-run with the effect **off** by row 14, expected to pass unchanged.
- **This tree's own baseline**: 825 tests, 130 ARB keys ×4, 57 test files — every row above is added to these, and the
  counts move only where a row says so (131 keys; spec 12 → **13** FRs).
- **The render's cost split** (paint 182 ms vs send 47.1 s): the number §3's arithmetic rests on, re-read from the same
  line `P1` quotes.

## Checkpoints

| # | after | what is true, and what to look at |
|---|---|---|
| C1 | rows 1–4 green | the rule is right before anything is painted: the inset, the ten, the bound, the return, one clock per picture |
| C2 | row 5 green | a frame shows the inset window and the words do not move — the first pixel evidence |
| C3 | row 6 green | a whole video renders with the effect on, and the off path's runs and lines are unchanged |
| C4 | rows 7–8 green | the prompt offers it, off by default, and its answer reaches the renderer |
| C5 | device rows 9–11 | the reader's own look: hand them the still of row 10 (the 1.20 × crop on a real photo) and the two frames of row 11 before going on |
| C6 | device rows 12–14 | the cost is a number; if `P1` is over the ceiling, the ladder's first rung is applied and re-measured **before** row 14 |
| C7 | row 15 + the closing pass | one key in four locales; `tasks.md` ticked; the handback's numbers are the rows' own |

## Risks, and what this plan does about them

- **The cost lands over `SC-005`'s ceiling.** `research.md` §3: painting alone is ~22.2 s of a 60.6 s baseline, leaving
  ~8 s for 2061 extra PNG encodes. Handled by `P1` + D9's ladder, measured in that order; the plan promises no figure.
- **The 1.20 × crop cuts something the reader wanted.** Accepted at the gate, and it is the one risk the reader can
  only judge on a real picture: row 10 hands them the still, and `k` is one constant if it reads too tight.
- **The plate sits on the wrong side of the tone floor where the band drifted.** `A4`'s own question; answered by
  reading the tone at the inset framing (§6) and measured by row 11, which records the contrast rather than hiding it.
- **A long single-picture video reads as a mechanical sway** (~29 identical-length cycles a minute). The variety is
  the drawn amplitude and direction; if it still reads mechanical on row 10's still, the period is one constant and
  the reader's word decides (open question in research).
- **A picture the schedule gives fewer than ~4 frames.** One compressed cycle over 2–3 frames is a 1–2 px move at most
  — below anything visible, and harmless; the rule never jumps (`data-model.md`, invariant 3).
- **The off path drifting by accident.** Guarded structurally (the new branch is chosen once, before the loop; the
  inset is computed only inside it) and by row 14's per-frame md5 comparison against the base commit's own render.

## Complexity Tracking

Empty. No constitution violation needs justifying: no dependency is added, no platform code is touched, no new store
family appears, and the one new module is the rule itself rather than a layer around it.
