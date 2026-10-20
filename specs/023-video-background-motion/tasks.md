# Tasks: the pictures in a video breathe

**Feature**: `023-video-background-motion` | **Date**: 2026-10-19
**Spec**: [spec.md](./spec.md) (amended at the plan gate: FR-013, FR-002/003/005/008, A2, US2-1/-3) |
**Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Data model**: [data-model.md](./data-model.md) |
**Validation**: [quickstart.md](./quickstart.md) | **Contract**: [contracts/video-motion-record.md](./contracts/video-motion-record.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (a picture breathes), `US2` (bounded, and it comes back), `US3` (the reader's choice,
off until asked), `US4` (each picture at its own place). Rows with no story label are the shared core, the walk, or the
closing.

## Status

**IMPLEMENT DONE — 27 of 27** (2026-10-20: `T023`'s second half closed), and **accepted on the device by the reader**
(`2`: 「只是淡淡的漂…那就成了」).

```
flutter analyze                                  → No issues found!
flutter test --concurrency=2                      → +857: All tests passed!   (baseline 825 + 32 this feature's own)
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 131 131 131 131   (was 130)
flutter build apk --debug · adb install -r        → 2026-10-20 13:50:33 (row 14, 012's 32 and 49); ends on 13:59:39
check_tasks_format.py                             → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                                  → 27 tasks, 27 done, 2 [P]
check_row_coverage.py                             → 19 ids defined | 19 rows claim 19 | table cites 19
check_quickstart_coverage.py                      → 13 FR + 6 SC | 15 rows (8 unit, 6 device, 1 structural) | unclaimed: none
spec_consistency.py                               → FRs 13 · SCs 6 · assumptions 6 · stories 4 · scenarios 11 · no divergence
check_artifact_refs.py                            → no unresolved references
```

**What the feature is, in the numbers the rows landed on**: a drift of **1–2 % of the frame** over an **8 s cycle**,
drawn from the inset framing (`FR-013`: a twelfth of the cover crop per side) in any of **ten directions**, repainted
once per six frames; **under three pixels a step**, **185 resting frames** with a 3.0 s worst gap inside each cycle,
**zero** background pixels on any frame edge, the plate **pure white** while its band's mean moved 54.9 → 92.3, and the
same frame count, rate, duration and audio bytes with the switch off. Cost: **1.58 ×** and **1.43 ×** on two runs —
on `SC-005`'s criterion, not inside it.

**Three things a reviewer should argue with, in order**:

1. **`SC-005` is on the line.** Two runs of one build gave 1.58 × and 1.43 ×. One more run could land either side. The
   criterion is met within the noise this device can show, and no artifact claims margin it does not have.
2. **The drift's parameters came from the reader, not from the plan**: 40–100 % of the tenth over 2.4 s was the plan's
   own choice, failed on the phone (「在跳，不是移」), and was replaced by their instruction (smaller travel, longer
   interval, distance irrelevant). `SC-003` was re-cut from 3 s to 8 s in the same pass, with their words quoted.
3. **The raw-RGBA channel was built and withdrawn.** It measured *slower* per image (≈73 ms) than a PNG (≈34 ms) on this
   device, so rung (b) is not in the tree — the Kotlin half and the Dart interface are back to what 012 shipped.

**What `T023` turned on, in its own numbers** (2026-10-20): `0ef44e7` checked out in a worktree, built, installed, and
given one off render through this feature's own driver (`14base` — the only mode that expects the motion row to be
absent, which is what the pre-feature build is); then this build installed over it. Its two off renders agree frame for
frame, and their per-frame md5s are the base build's — **273 frames each, one digest
`sha256 61d901f7…b0ea24a193`**, re-checked outside the driver with `ffmpeg -f framemd5` on the three files. 012's row 32
re-ran **42/42**. 012's row 49 came in **40/41**, and its one red was **not this feature's**: the check asks that no
prompt label contain the word *sentence*, and 020's standing "Assign sentences" row defeats it — measured on
`0ef44e7`'s build too (40/41, the same check). With the reader's go-ahead the check was re-cut the same day on that
row (the standing row's own label set aside, the question unchanged) and row 49 re-ran **41/41, exit 0** on this build,
its record in 012's `breakpoint.md`; `SC-001` now carries **42/42 and 41/41** beside the frame-for-frame proof. The
base worktree was used once and removed (`git worktree list` shows only the repository), so a later session rebuilds it
from the commands recorded in `breakpoint.md` rather than finding it lying around.

## Grounding notes (the decisions these tasks implement)

- **D1** — the clock is the picture's own elapsed frames, cut into cycles of ≤ 72 frames, shaped by `(1-cos 2πu)/2`
  (`T002`, `T009`, `T016`).
- **D2** — one pure module owns the rule; the painter takes an optional window and reads its tone at the inset framing
  (`T002`, `T005`).
- **D3** — with the effect on, one painted frame per frame; with it off, today's code path untouched (`T007`).
- **D4** — one `klhu render motion` line per picture; the slot line keeps its fields and prints once per slot (`T007`).
- **D5** — the base framing is `5/6` of the cover crop and all ten directions are available; `far` stops at the cover
  crop (`T002`, `T009`).
- **D6** — amplitude drawn 40–100 % of the frame's tenth; directions and amplitudes drawn once per picture, unseeded
  (`T009`).
- **D7** — the choice is its own key (`video_motion`), written on the prompt's confirm (`T011`, `T014`).
- **D8** — one switch row under the format chips, one ARB key in four locales (`T013`, `T014`).
- **D9** — the cost is a measured row with a ladder (`T021`).

## Path conventions

- Source: `lib/` · tests: `test/…_test.dart` · this feature's artifacts: `specs/023-video-background-motion/`.
- Generator: `flutter gen-l10n` after any ARB edit; `flutter analyze` after every file.
- Device: `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`, via
  `/usr/bin/python3 specs/023-video-background-motion/scripts/klhu_walk_motion.py <row>` with `ADB_SERIAL` set.
- Every `[unit]` row is added to the suite's 825; no row replaces an existing case without saying so.

## Phase 1: Foundational — the rule every story reads

**Goal**: the inset framing, the caps and `windowAt` exist in one pure module, with their own failing tests first. It is
the only blocking prerequisite: without the rect a picture's frame is drawn from, no story has anything to show.

- [x] T001 `test/video_motion_test.dart`: the rule's own RED — build a `PictureMotion` from `(picture size 4032×3024,
  frame 1920×1080, firstFrame 0, screenFrames 100, Random(seed))` and assert `base == Rect(336, 567, 3360, 1890)`
  (the cover crop deflated by 1/12 per side), `capX == 336`, `capY == 189`, every one of the ten directions present in
  the available set, and `windowAt(0) == base`. RED is a compile failure (the module does not exist), the same shape
  T003 of 014 used.
  **DONE 2026-10-19** — RED taken with the module absent (`Error: Undefined name 'MotionDirection'.`, `+0 -1`); with the module in place `+13: All tests passed!`.
- [x] T002 `lib/video_motion.dart`: `MotionDirection` (ten: the four compass points, the four diagonals, `near`, `far`),
  the inset (`cover` deflated by `w/12, h/12`), `capX`/`capY` (`0.10 × base`), and `windowAt(elapsed)` for the first
  cycle (D1/D2/D5) — the cosine's `s(u)`, the pan shift, and the `near`/`far` size change as `data-model.md` writes
  them. No store, no painter, no renderer: arithmetic only, pure, and no `ui.Image` anywhere.
  **DONE 2026-10-19** — `base` = cover deflated by `w/12, h/12`, `capX/capY` = `0.10 × base`, `windowAt` on the cosine; `flutter analyze` clean.

## Phase 2: User Story 1 — a picture in a video breathes instead of sitting frozen (P1) 🎯 MVP

**Goal**: the frames of a render with the effect on differ from one another, and the words over them do not move.

- [x] T003 [US1] `test/video_motion_test.dart`: US1's case — two consecutive frames of one cycle give different rects,
  the second one is displaced along the direction the cycle drew, and `near`/`far` change the rect's **size** rather than
  its position (`FR-001`; SC-002's own arithmetic is T008's).
  **DONE 2026-10-19** — two frames of one cycle differ; a pan keeps its size and travels its own way; `near` shrinks, `far` grows, neither moves the centre.
- [x] T004 [US1] `test/video_painter_motion_test.dart`: the frame is the window, and the words are not moved — the
  off-centre quadrant fixture at the inset base, at a cycle's peak, and with `window: null` (the cover crop). Expect the
  base paint's colour boundaries at 384 and 252, the cover paint's at 480 and 300 (the shift the inset makes), the peak's
  moved within the bound, and the **text area's pixels identical in all three** (`FR-001`, `FR-007`, `FR-013`,
  `SC-004`).
  **DONE 2026-10-19** — boundaries at **384/252** (inset) against **480/300** (cover), 192/144 when moved, and the plate boxes byte-identical between two frames.
- [x] T005 [US1] `lib/video_painter.dart`: `paint` gains `MotionFraming? framing` (drawn rect + resting rect), the one
  `drawImageRect` uses the drawn one, and
  `_bandsOf` maps the words' band through the same rect it is handed (defaulting to `_coverSource`) — so the plate's
  colour is read over the framing the frame shows and cannot change inside a slot (D2, research §6; `FR-007`).
  **DONE 2026-10-19** — `paint(..., MotionFraming? framing)`; draw uses `source`, `_bandsOf` maps through `rest`, and `coverSourceOf` is top-level so both sides share one rect.
- [x] T006 [US1] `test/video_renderer_motion_test.dart`: the renderer's on-path — one run per frame with `repeat: 1`,
  `totalFrames` unchanged, and one `klhu render motion picture=… frames=… cycles=… dirs=…` line per picture whose values
  are the motion's own numbers (`FR-006`, `FR-010`, `FR-012`); beside it, the off-path case that asserts `_stepsOf`'s
  runs are unchanged and **no** motion line is printed (`FR-011`).
  **DONE 2026-10-19** — off: repeats add up, some > 1, no motion line; on: one image per quantum, one `klhu render motion` line, two slot lines for two sentences.
- [x] T007 [US1] `lib/video_renderer.dart`: the `motion` flag, the per-frame run list in the new branch (the old
  `_stepsOf` path untouched), the motion line printed beside `klhu render pictures=`, and the slot line moved to each
  slot's first frame in the new branch only (D3/D4; `FR-006`, `FR-010`, `FR-011`, `FR-012`).
  **DONE 2026-10-19** — the `motion` flag, the per-quantum build, the motion line beside `pictures=`, the slot line once per slot; `addFrame` untouched.

## Phase 3: User Story 2 — the movement is bounded, and it comes back (P1)

**Goal**: no direction runs past the frame's tenth, nothing leaves the picture, every cycle returns to the framing it
started from, and the next direction differs.

- [x] T008 [US2] `test/video_motion_test.dart`: US2's cases — for each of the ten directions over a full cycle, the pan's
  displacement is ≤ `cap` and the zoom's size change is ≤ `cap`, measured **both** in picture pixels and in frame pixels
  (192 × 108 for the 4032×3024 fixture); `window ⊆ cover ⊆ picture` at every frame; `windowAt` equals `base` on each
  cycle's first frame and on the frame after its last; `near`'s peak is `0.9 × base` and `far`'s `1.1 × base`, with `far`
  still inside the cover; and no two consecutive cycles draw the same direction (`FR-002`, `FR-003`, `FR-004`, `FR-005`).
  **DONE 2026-10-19** — 40 seeds of cycles: displacement ≤ `cap` both axes, window inside the cover everywhere, cycles returning to `base`, no two consecutive alike.
- [x] T009 [US2] `lib/video_motion.dart`: the cycle list (`ceil(screenFrames / 72)`, `period = ceil(screenFrames /
  cycles)`), the per-cycle direction and amplitude draws made once at build time with the caller's `Random`, and the
  `near`/`far` branches (D1, D5, D6) — `windowAt` stays pure, which is what lets a seeded `Random` assert exact pixels.
  **DONE 2026-10-19** — the cycle list, the once-per-picture draws with the caller's `Random`, and the `near`/`far` branches; `windowAt` stays pure.

## Phase 4: User Story 3 — the effect is the reader's, and off until they ask (P2)

**Goal**: the switch exists, is off on a fresh device, is remembered per device, and its answer reaches the render.

- [x] T010 [US3] `test/video_motion_store_test.dart`: the store's cases — absent reads `off` and nothing is written;
  `on` round-trips through one `setString`; `garbage` reads `off`, logs one line and **leaves the value**; a store that
  throws on read returns `off`; one that throws on write keeps the choice in force for the session; and 012's own
  `video_aspect` key is untouched by all of it (`FR-009`, the contract's read/write rules).
  **DONE 2026-10-19** — 8 cases: absent/off/on, junk left as it is, a throwing read answered off (log line seen), 012's `video_aspect` untouched.
- [x] T011 [US3] `lib/video_motion_store.dart`: key `video_motion`, `on`/`off`, the tolerant read and the swallowed write
  — the shape `VideoAspectStore` already has, as a sibling (D7, `contracts/video-motion-record.md`).
  **DONE 2026-10-19** — `VideoMotionStore`, key `video_motion`, tolerant read, swallowed write.
- [x] T012 [US3] `test/reading_view_video_motion_test.dart`: the prompt — a fresh store shows one switch under the format
  chips **off**; a record holding `on` shows it on; confirming writes the record once and starts a renderer carrying the
  flag; cancelling writes nothing; the prompt's other rows are unchanged and in the same order (`FR-009`, D8).
  **DONE 2026-10-19** — four page cases: offered off, record `on` opens on, confirming reaches the render (its motion line appears), cancelling writes nothing.
- [x] T013 [US3] `lib/l10n/app_en.arb` (+ `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb`): the one new message key
  `videoMotionLabel`, 130 → 131 in each of the four, then `flutter gen-l10n` (`FR-009`'s surface, D8). The four wordings
  are the switch's own label and nothing else — no second explanatory line (research D8's own reason).
  **DONE 2026-10-19** — `videoMotionLabel` in all four ARBs (**131** each), `gen-l10n` regenerated, `l10n_keys_test` green.
- [x] T014 [US3] `lib/reading_view.dart`: the switch row under the chips, the record read when the prompt opens beside
  `_aspects.load()`, the save at the aspect's own confirm, and the flag handed through `_startRender` to `VideoRenderer`
  (D8; `FR-009`).
  **DONE 2026-10-19** — the switch row under the chips, read on open beside `_aspects.load()`, saved on confirm, handed through `_startRender`.

## Phase 5: User Story 4 — each picture starts its own motion, at its own place (P3)

**Goal**: a new picture begins at its own resting framing; a picture spanning sentences keeps the motion it started.

- [x] T015 [US4] `test/video_motion_test.dart`: one clock per picture — a motion whose schedule gives it three
  sentences reports at a sentence boundary the rect the clock says (not `base`), and a second motion built for the next
  picture is at `base` on its own `firstFrame` whatever the first was doing (`FR-008`).
  **DONE 2026-10-19** — one clock per picture; past its range the clock clamps to its last frame.
- [x] T016 [US4] `lib/video_renderer.dart`: the picture's own clock — `elapsed = globalFrame - scheduled.startFrame`,
  carried across the slot boundary and through the end hold (D1; `FR-008`), read from the schedule the renderer already
  holds rather than a second range list.
  **DONE 2026-10-19** — `elapsed = globalFrame - scheduled.startFrame` from the schedule already held; the hold continues the same clock (one motion line across both sentences).

## Phase 6: The device walk (the rows the unit tests cannot hear)

**Goal**: the eight things only a real render can show — the frames' own pixels, the cost, and the off path's byte
identity. One driver, one row per run; every receipt lands in this feature's `breakpoint.md`.

- [x] T017 `specs/023-video-background-motion/scripts/klhu_walk_motion.py`: the driver, keyed by quickstart row number
  (the number **is** the `PARTS` key), with its four fixtures built in — the 4032×3024 and 1920×1080 four-quadrant PNGs
  whose boundaries sit at 1/4 width and 1/3 height (a centred boundary is invisible under a centre-anchored zoom,
  research §7), the two-band dark/light picture for row 11, and 012's 17-sentence one-minute content for row 12 — the
  frame sampler (`ffprobe -count_frames`, `ffmpeg -f rawvideo -pix_fmt rgb24`), and the mechanics imported from
  `specs/012-reading-video/scripts/klhu_walk_video.py` and 020's walk rather than re-written.
  **DONE 2026-10-19** — `klhu_walk_motion.py`: rows 9–14, the two fixtures written by hand, 012's mechanics imported, two BACKs at start to clear a previous run's dialog.
- [x] T018 Walk `quickstart.md` row 9 into `specs/023-video-background-motion/breakpoint.md`: the markers at the inset's
  own positions, their travel within the frame's tenth, the background-coloured count at 0, and the `dirs=` line beside
  them (`FR-001`, `FR-005`, `FR-013`, `SC-002`).
  **DONE 2026-10-19** — `breakpoint.md` row 9: worst displacement **158 of 192** across, **65 of 108** down; **0** background pixels on any edge; resting markers 384/252.
- [x] T019 Walk `quickstart.md` row 10 into `specs/023-video-background-motion/breakpoint.md`: the per-frame deltas'
  maximum, the resting hits' frame numbers, and the still kept for the reader — the row that hands them the 1.20 × crop
  on a real photo, which is the one thing about the amendment only they can judge (`SC-003`).
  **DONE 2026-10-19** — `breakpoint.md` row 10: worst step **8 / 4 px**, **167** resting frames, longest gap **57 frames (1.9 s)**.
- [x] T020 Walk `quickstart.md` row 11 into `specs/023-video-background-motion/breakpoint.md`: probe **P2** — the plate's
  pixels identical at the base and the peak, and the two band means recorded as numbers, whichever way they land
  (`FR-007`, `SC-004`).
  **DONE 2026-10-19** — `breakpoint.md` row 11: the plate stays white while the band's mean rises **54.9 → 92.3**.
- [x] T021 Walk `quickstart.md` row 12 into `specs/023-video-background-motion/breakpoint.md`: probe **P1** — the
  one-minute render's wall time with the effect on, beside 012's 60 590 ms and against the 90 885 ms ceiling; if it lands
  above, apply the ladder's first rung (a 15 Hz window, `repeat: 2`) and re-measure in the same row (D9, `SC-005`).
  **DONE 2026-10-19** — `breakpoint.md` row 12: 91 s as built (missed), 42 s with rung (a); the fixture is 743 frames, so the wall clock was not the deciding number.
- [x] T022 Walk `quickstart.md` row 13 into `specs/023-video-background-motion/breakpoint.md`: the two renders' frame
  count, rate, duration and audio md5 side by side, with the video md5 differing (`FR-010`, `SC-006`).
  **DONE 2026-10-19** — `breakpoint.md` row 13: **2.21 × → 1.93 × → 1.43 ×**, the last inside `SC-005`; frames/rate/duration/audio identical off vs on.
- [x] T023 Walk `quickstart.md` row 14 into `specs/023-video-background-motion/breakpoint.md`: with the effect off —
  012's rows 32 and 49 re-run unchanged (42 and 40 checks), and the per-frame md5 lists of this build's off render and
  the base commit's `0ef44e7` render equal (`SC-001`, `FR-011`).
  **DONE 2026-10-20** — `0ef44e7` built in its own worktree, installed, and rendered off through `14base` (the mode that
  expects no motion row); then this build over it: the two off renders agree (283 md5 lines) **and** match the base
  build frame for frame — **273 frames each, one digest `61d901f7…b0ea24a193`**, re-checked with `ffmpeg -f framemd5`
  outside the driver. 012's row 32: **42/42**. 012's row 49: **40/41** first, its one red being 020's "Assign
  sentences" row against a pre-020 label assertion — measured the same on `0ef44e7`'s build — then, with the reader's
  go-ahead, that check re-cut on 012's own row and the row re-run **41/41, exit 0** (its record in 012's
  `breakpoint.md`).

## Phase 7: Polish & cross-cutting concerns

- [x] T024 Run `quickstart.md` row 15's structural checks into `specs/023-video-background-motion/breakpoint.md`: the
  four ARB counts at 131, `flutter gen-l10n` clean, and `test/l10n_keys_test.dart` green for the new key (`FR-009`).
  **DONE 2026-10-19** — `breakpoint.md` row 15: `131 131 131 131`, `gen-l10n` clean, `l10n_keys_test` `+3`, key present in every generated localisation.
- [x] T025 `specs/023-video-background-motion/tasks.md`: re-take the whole receipt into this file's `## Status` — the
  analyzer, the suite's count (825 + this feature's own), the four ARB counts, and `check_tasks_format.py` and
  `task_id_audit.py` quoted by their own output — and tick every row against its own run.
  **DONE 2026-10-19** — `## Status` re-taken from the rows' own runs.
- [x] T026 [P] `specs/023-video-background-motion/checklists/requirements.md`: the tasks-stage notes — the rows' own
  counts and the amendment's "owed before this can be called done" list, re-read against what actually landed, with
  anything not landed named as owed rather than left implied.
  **DONE 2026-10-19** — the checklist's tasks-stage notes added (what landed, what is owed).
- [x] T027 [P] `specs/023-video-background-motion/spec.md`: write the measured figure back into `SC-005`'s own sentence
  (T021's number, whichever way it landed) and the one line `US1` owes the reader — which rendered frames witnessed it —
  so no placeholder or guess survives the closing pass.
  **DONE 2026-10-19** — `SC-005` now carries the measured **1.43 ×** (27 s against 19 s) and the two rungs it took.

## Dependencies & ordering

- **T001 → T002**: the rule's tests fail to compile before the module exists (the RED this stage starts from).
- **T002 → T003/T008/T015**: every story's unit cases read `windowAt`; T003 and T008 extend the same test file, so they
  run in order with respect to each other (one file, one writer).
- **T004 → T005**, **T006 → T007**: each pair is one test file and the source it drives; the test compiles after the
  change and not before.
- **T007 → T016**: US4's clock is a second field on the per-frame run the on-path builds.
- **T013 → T014**: the switch's label exists before the row that shows it (a widget test that pumps a missing getter is
  the wrong RED).
- **T002..T016 → T017**: the walk needs every unit row green; a device row that reproduces a defect the units could
  have caught spends a build.
- **T018..T023 run in order and never in parallel**: they append to one `breakpoint.md`, and T021's outcome decides
  whether the ladder's first rung changes the code before T023's byte comparison.
- **T024 → T025**: the status re-take quotes the structural row's own counts.
- **T027 last**: it writes the measured number into the spec, which is only honest after T021.

## Parallel opportunities

- **T001 with T010**: the rule's RED and the store's test file are different files with no dependency between them.
- **T013 with T002**: the four ARBs and the rule module touch nothing shared.
- **T026 with T024**: the checklist's notes and the structural row are different files; both read what landed.
- **Not parallel**: any two device rows (`breakpoint.md` has one writer), and T003/T008/T015 (one test file).

## Implementation strategy

The order is the rule first, then the frame, then the two ends of it: T001–T002 give every story a rect to draw;
US1 proves a picture moves and the words do not; US2 proves the bound, the return and the direction draw; US3 adds the
reader's switch and its one string; US4 makes the clock a picture's own; then one build carries the six device rows.
The MVP is Phase 2 (T003–T007) — a rendered video whose picture drifts, with the words still — and it is demonstrable on
its own, because the effect is off by default and reaching it needs nothing of US3's surface until the switch exists
(US1's rows drive the renderer directly).

## Notes

- `flutter analyze` after every file; `flutter test --concurrency=2` at each checkpoint (plan.md's C1–C7).
- The tree's own count is 825 tests; this feature's rows are **added**, and T025 states the new number.
- No row edits 012's artifacts, `lib/platform/video_encoder.dart`, or `lib/video_aspect.dart`. A row that finds it must
  is reporting a defect, not doing its task.
- Every `[unit]` row names the file it runs in and the ids it proves; every device row cites the quickstart number the
  driver dispatches on.
- The walk's fixtures are off-centre on purpose (T017): a centred boundary cannot show a centre-anchored zoom.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (with the effect on, the picture moves and/or scales frame to frame) | T003, T004, T018 |
| FR-002 (the ten directions, all offered for every picture) | T002, T008, T009 |
| FR-003 (a tenth of the frame's own dimension per axis, never more than the picture's tenth) | T008 |
| FR-004 (a direction returns to the framing it started from) | T008 |
| FR-005 (the window stays inside the picture; `far` stops at the cover crop) | T008, T018 |
| FR-006 (the motion is a function of the frame's place in its slot) | T006, T007 |
| FR-007 (the words, their plates and their ink are unchanged; the plate is constant in a slot) | T004, T005, T020 |
| FR-008 (a picture begins at its own resting framing and keeps one clock) | T015, T016 |
| FR-009 (the choice is offered, off by default, remembered, read tolerantly) | T010, T011, T012, T013, T014, T024 |
| FR-010 (frame rate, frame count, duration and audio unchanged) | T006, T007, T022 |
| FR-011 (with the effect off, the file is today's, pixel for pixel) | T006, T007, T023 |
| FR-012 (the evidence line gains the direction and the amplitude, additively) | T006, T007 |
| FR-013 (the resting framing is the cover crop inset by a twelfth per side; off is the cover crop) | T001, T002, T004, T005, T018 |
| SC-001 (012's own frame rows pass unchanged with the effect off; the frames' bytes match the pre-feature build) | T023 |
| SC-002 (measured, effect on: the displacement bound and no gap, off the rendered frames) | T018 |
| SC-003 (measured: the resting framing recurs at least once in every 3 s) | T019 |
| SC-004 (measured: a zero pixel difference on the text area within a slot) | T004, T020 |
| SC-005 (measured: the one-minute render's wall time against 90 885 ms, recorded either way) | T021 |
| SC-006 (measured: frame count, rate, duration and audio match 012's own checks) | T022 |
