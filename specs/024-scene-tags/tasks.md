# Tasks: scene tags (`[scene]`, `[场景]`, `[場景]`, `[escena]`)

**Feature**: `024-scene-tags` | **Date**: 2026-10-20
**Spec**: [spec.md](./spec.md) (re-cut at the plan gate the same day: the spelling set is four — the reader's
`please include: 場景、escena`) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (a boundary, never a word), `US2` (Format gives a tag its own paragraph), `US3` (one
picture per scene, in order), `US4` (a near miss stays the reader's text). Rows with no story label are the shared
core, the walk, or the closing.

## Status

**CLOSED — 35 of 35 rows run** (2026-10-22). Implemented, walked on the device, and recorded: the
feature's own receipts are in [breakpoint.md](./breakpoint.md), the stage's in the numbers below. The walk's own
receipts are in [breakpoint.md](./breakpoint.md), row by row; the numbers below are the ones those
runs printed.

```
flutter analyze                                   → No issues found! (1.1 s)
flutter test --concurrency=2                      → +901: All tests passed!   (1:19; baseline 857 + 44)
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 135 135 135 135   (was 131)
ls test/*.dart | wc -l                            → 65    (was 62)   ·   lib/*.dart → 32 (was 31)
flutter gen-l10n                                  → idempotent; test/l10n_keys_test.dart green
check_tasks_format.py   → OK: format, sequencing and spec-id coverage check out
task_id_audit.py        → 35 tasks, 35 done, 4 [P]
check_row_coverage.py   → 25 ids defined | 25 rows claim 25 | no row claims: none | table cites 25
check_quickstart_coverage.py → 15 rows ([unit] 9, [device] 6) | unclaimed: none
spec_consistency.py     → no divergence        check_artifact_refs.py → 68 references, none unresolved
```

```
device walk, one build (emulator-5554, 2026-10-22), driver keyed by quickstart row number
row 10 → 10/10   the page paints the twin, 43 chars byte-equal; 0 scanlines differ; widest
                 line gap 71 px on both pages
row 11 → 4/4     seven utterances on the fixture and on the twin, same texts, same order;
                 the app's ranges step from 34 to 56 across both tag lines, silently
row 12 → 5/5     24 chars → 25 (one line break); second press 25; one Undo back to 24
row 13 → 10/10   counts 0,0,0,0,0 → 2,3,1,0,0; six sentences; the fifth picture still moves;
                 the option absent on a tag-free content
row 14 → 5/5     plan pictures=5 ranges=(0,154),(155,272),(273,373),None,None sentences=7;
                 374 frames, 545877 bytes; no slot span reaches a tag line
```

**What a reviewer should weigh first**: the measured counts are **7 sentences and 2, 3, 1 owned**
where the quickstart says five and `2, 2, 1` — the shipped segmenter splits `「有人吗？」她说。` at the
`？` because `」` is not one of its closers, and 024 must not change that (FR-016). The twin splits
the same way, which is why SC-003's equality still holds; the fixture's own numbers are recorded
rather than the row being re-cut (breakpoint.md § Findings 1).

**T031's six re-runs, taken on the same build**: `klhu_walk_comment.py 17` 24/24 · `klhu_walk_head.py 10`
14/14 · `klhu_walk_step.py 5` 13/13 · `klhu_walk_assignment.py 6` 14/15 · `klhu_walk_pass.py 8` 5/5 ·
`klhu_walk_video.py 32` 41/41. The single failure is 020's own clean-page precondition reading the chip
wording 021 replaced (`No sentences assigned`); every count that row measures is its own, so SC-001's
identity holds on the device as well as in the suite. `T034`'s checklist notes and `T035`'s measured
figures (SC-002, SC-003, SC-005, SC-006, SC-008) are landed.

## Grounding notes (the decisions these tasks implement)

- **D1** the rule is 024's own module (`lib/scene_tag.dart`), a deliberate second copy of 015's shape — its own test
  table is the guard, so `T001`/`T003`/`T005` never read `lib/comment.dart`'s spellings.
- **D2** four spellings, one per shipped UI locale, all live in every content (`T001`, `T002`).
- **D3** recognition at a line's head, the rest of the line is the heading (`T002`).
- **D4** the whole line is the marker, its break included — the app's first rule that hides typed characters (`T002`,
  `T008`).
- **D5** speech is cut from a same-length space mask, handed to the four call sites (`T006`, `T010`–`T013`).
- **D6** painting rides `displayOf`'s one span list, as 019's marks do (`T008`).
- **D7** `formatForSceneTags` is 024's own pure function, composed with 014's in one press (`T017`, `T018`).
- **D8** the pairing is a pure function in 020's own file, taking the scenes' sentence ranges (`T020`).
- **D9** the option is a second AppBar action beside `Done`; four strings, 131 → 135 (`T021`, `T023`).
- **D10** nothing is stored; every surface derives the same answer on every open (no row writes a store).

## Path conventions

- Unit rows write tests under `test/` and source under `lib/`; a row's first line names the file it touches.
- Device rows cite the quickstart row they drive — `python3 specs/024-scene-tags/scripts/klhu_walk_scene.py <row>` — and
  their evidence lands in `specs/024-scene-tags/breakpoint.md`. The number **is** the driver's `PARTS` key.
- No row edits 014's, 015's, 019's, 020's or 021's own tests, and no row edits a closed spec's artifacts. The only
  edits to older files are the named seams below, each one line where the plan says one line.

## Phase 1: Foundational — the grammar every story reads

**Goal**: `lib/scene_tag.dart` answers the three questions the rest of the feature asks — where the tags are, what each
owns, and what the text looks like with them masked — with its own test table (D1).

- [x] T001 [P] `test/scene_tag_test.dart`: the grammar's own RED — one table, one line per shape: the four spellings
  (`[scene]`, `[SCENE]`, `[场景]`, `[場景]`, `[escena]`, `[ESCENA]`), a heading after the `]` (`[场景] 1：青石观蚁`,
  `[escena] 3：夜`), leading spaces, trailing spaces/tabs, `\r`, and the refusals (`［场景］`, `［場景］`, `[scenes]`,
  `[escenas]`, `[scene]` mid-sentence, `text [scene]`, `# [scene]`, unclosed, `[]`, `[comment]`, `[注]`, a tag inside a
  comment's span); then quickstart row 1's **twin content** — the fixture's three tags respelled `[場景] 1：…`,
  `[ESCENA]`, `[escena] 2：…` — owning the fixture's own sentences, spelling for spelling. Fails to compile before
  `lib/scene_tag.dart` exists: that is this feature's RED (`FR-001`, `FR-002`, `FR-007`, `SC-007`).
- [x] T002 `lib/scene_tag.dart`: the scanner — `SceneTag{spelling, start, markEnd, lineStart, headingStart, lineEnd}`
  (data-model §1) and `sceneTagsOf(text)` reading line by line: ASCII `[`/`]` only, the two ASCII spellings in any case,
  `场景`/`場景` as written, and the 015/019 `inside` seam (`lib/head_tag.dart:58`) so a tag inside a comment's span or on
  a marked line opens nothing (`FR-001`, `FR-002`, `FR-015`). No grammar table shared with `lib/comment.dart` (D1).
- [x] T003 `test/scene_tag_test.dart`: ownership's RED — quickstart row 2 — the preamble belongs to no scene; scenes 1–3
  own `他推门进来。`/`屋里很暗。`, `「有人吗？」她说。`/`门开了。`, `脚步声远了。`; a tag line's heading is owned by nobody; the
  two empty cases (a tag last in the text; two tags back to back) report `sentenceCount == 0`
  (`FR-003`, `FR-014`, `FR-017`, `SC-003`).
- [x] T004 `lib/scene_tag.dart`: `scenesOf(text)` → `List<Scene>` over `sentenceRanges` (`lib/segmenter.dart:93`): each
  scene's range is `[tag.lineEnd + 1, nextTag.lineStart)` or the text's end, ownership is decided by each sentence's
  **start** offset, the ordinal is 0-based in text order (data-model §2; `FR-003`, `FR-014`, `FR-017`).
- [x] T005 `test/scene_tag_test.dart`: the mask's RED — `sceneMasked` keeps the text's **length** and every offset; no
  delimiter survives inside a tag line (`[scene] 第一场。他说。` yields no sentence for `第一场。` and swallows none of
  `他说。`); each replaced run is spaces only; a tag-free text's mask is the text itself (data-model I1/I2/I4;
  `FR-005`, `FR-016`).
- [x] T006 `lib/scene_tag.dart`: `sceneMasked(text)` — every `[lineStart, lineEnd + 1)` replaced by spaces of the same
  length, and the last line's span when it carries no break (data-model §3; D5).

## Phase 2: User Story 1 — a scene tag is a boundary, never a word (P1) 🎯 MVP

**Goal**: the tag's characters are painted nowhere and spoken nowhere, and every derived list equals the same text's
with the tag lines deleted.

- [x] T007 [US1] `test/scene_tag_test.dart`: the painted string's RED — quickstart row 3 — `displayOf(fixture).text`
  **byte-equal** to the same content with the tag-line spans removed; no `[`, `场景`, `場景`, `scene`, `escena`,
  `青石观蚁` or `1：` anywhere; no double blank line where a tag stood; a text mixing a tag with a 015 comment and a
  019 mark keeps both of those elisions unchanged (`FR-004`, `SC-002`).
- [x] T008 [US1] `lib/comment.dart:386`: `displayOf` gains the third span kind — a scene span eliding
  `[lineStart, lineEnd + 1)`, carried in the same span list `CommentDisplay` already returns, `toDisplay`/`toContent`
  unchanged in shape (the one seam 015's tags and 019's marks ride; `FR-004`, `FR-016`).
- [x] T009 [US1] `test/scene_tag_test.dart`: silence's RED — quickstart row 4 — `sentenceRanges(sceneMasked(t))`,
  `stepRanges(sceneMasked(t))`, the video's slot list over the speeches and `turnsOf(sceneMasked(t))` each equal the
  deleted-line twin's (count, texts after trim, order, both directions), and the heading's own `。` starts nothing
  (`FR-005`, `SC-003`).
- [x] T010 [US1] `lib/reader_service.dart:450`: the speeches are cut from `sceneMasked(text)` — one call, the offset
  space unchanged, so highlights and slots need no remapping (`FR-005`).
- [x] T011 [US1] `lib/reading_view.dart`: ▶'s steps (`:1029`, `:1337`) and the page's own sentence list and taps
  (`:1224`, `:1242`) are cut from the masked text (`FR-005`).
- [x] T012 [US1] `lib/reading_view.dart`: `turnsOf`'s three call sites (`:1576`, `:1592`, `:1706`) take the masked text
  (`FR-005`).
- [x] T013 [US1] `lib/dialogue.dart`: **conditional on T009** — if a masked tag line still yields a turn (its emptiness
  test compares offsets rather than whitespace), trim in that one condition; if T009 is green this row's receipt says so
  and the file is not touched (research §4 R4; `FR-005`).
- [x] T014 [US1] `test/scene_tag_test.dart`: identity's case — quickstart row 5 — a sample of the app's own fixtures and
  012's pre-set text give the display string, step count, slot count and utterance list the shipped tests already pin,
  and `sceneMasked(t) == t` (`FR-016`, `SC-001`).
- [x] T015 [US1] `test/scene_tag_test.dart`: the seams' case — quickstart row 9 — a tag inside a comment's span is not a
  scene; a tag on a marked line is not a scene; a comment inside a tag line is the tag line's own text (the plan's
  pinned reading); and `toContent(toDisplay(t)) == t` holds for every shape (`FR-015`, `SC-007`).

## Phase 3: User Story 2 — Format gives a scene tag its own paragraph (P1)

**Goal**: one press puts a tag at a paragraph head, and the diff is blank lines only.

- [x] T016 [US2] `test/reading_view_scene_test.dart`: Format's RED — quickstart row 6 — a mid-paragraph tag gains a
  blank line before its line and nothing else changes (a line diff whose every changed line is empty); the press is
  idempotent; one Undo restores the input byte for byte; 014's own behaviour is unchanged on a text with no scene tag
  (`FR-006`, `SC-004`).
- [x] T017 [US2] `lib/scene_tag.dart`: `formatForSceneTags(text)` — a tag that does not already start a paragraph gains
  one blank line at its line's own start, and the text is otherwise byte-identical (D7; `FR-006`).
- [x] T018 [US2] `lib/reading_view.dart:736`: the Format press composes 014's pure function with 024's — one press, one
  undo step, and `lib/dialogue.dart`'s function untouched in its own file (`FR-006`, `SC-004`).

## Phase 4: User Story 3 — one picture per scene, in order (P2)

**Goal**: the i-th picture takes the i-th scene, inside 020's own run rules, asking first when anything would be
replaced.

- [x] T019 [US3] `test/picture_assignment_scene_test.dart`: the pairing's RED — quickstart row 7 — the N×M grid
  `{(0,1), (1,0), (1,1), (2,3), (3,2), (5,3), (3,5)}` on the fixture, each cell compared with the same assignment made
  through 020's own add/remove calls: `min(N, M)` runs, contiguous and ascending, no index twice, an empty scene
  consuming no picture, the preamble in no run, `null` when nothing pairs
  (`FR-009`, `FR-010`, `FR-013`, `FR-014`, `FR-017`, `SC-005`).
- [x] T020 [US3] `lib/picture_assignment.dart`: `assignScenesToPictures(scenes, pictureCount)` — pure, returning
  `List<PictureRun>?`, the i-th scene's sentence indices with the i-th picture in the scenes' own order, never writing a
  run 020's rules would refuse, and nothing marked as automatic (D8; `FR-009`, `FR-010`, `FR-011`, `FR-013`).
- [x] T021 [P] [US3] `lib/l10n/app_{en,zh,zh_Hans,es}.arb`: the option's four strings — its label, the question's title,
  its body (carrying the run count) and its confirm — 131 → 135 keys in each, then `flutter gen-l10n`. **Before T022**:
  the test pumps a page whose label is a generated getter, and a missing getter is the wrong RED (D9; `FR-008`,
  `FR-012`).
- [x] T022 [US3] `test/picture_assignment_screen_scene_test.dart`: the option's RED — quickstart row 8 — absent for a
  content with no scene, present with scenes, no question when nothing is assigned, a question naming how many runs go
  when something is, a refusal leaving `_runs` exactly as it was, and the label read from the ARBs (`FR-008`,
  `FR-011`, `FR-012`).
- [x] T023 [US3] `lib/picture_assignment_screen.dart:478`: the second AppBar action beside `Done`, with the page's own
  two-button dialog (`_askSwitch`'s shape, `:184`) for the replace question, and nothing offered when the content has no
  scene (`FR-008`, `FR-012`).

## Phase 5: User Story 4 — a near miss stays the reader's text (P3)

**Goal**: every shape the grammar refuses is painted, read and counted exactly as it is today.

- [x] T024 [US4] `test/scene_tag_test.dart`: the near misses' case — a content made only of `［场景］`, `［場景］`,
  `[scenes]`, `[escenas]`, `# [scene]` and tags mid-sentence gives `displayOf(t) == t`, zero scenes, and the same
  sentence/step counts `sentenceRanges(t)` and `stepRanges(t)` give on their own — the feature adds nothing to a text it
  does not recognise (`FR-007`, `FR-016`, `SC-007`).

## Phase 6: The device walk (what only a real build can show)

**Goal**: the five quickstart device rows on one build, every receipt in this feature's `breakpoint.md`. One driver, one
row per run, the number is the `PARTS` key.

- [x] T025 `specs/024-scene-tags/scripts/klhu_walk_scene.py`: the driver, keyed by quickstart row number (10–15), with
  `specs/024-scene-tags/scripts/klhu_scene_fixture.txt` written beside it (quickstart's own six-line fixture) and the
  deleted-line twin derived from it; 021's library seeding, file dialog and `uiautomator` dump helpers and 023's frame
  reads imported rather than re-written; two BACKs at start to clear a previous run's dialog.
- [x] T026 Walk `quickstart.md` row 10 into `specs/024-scene-tags/breakpoint.md`: the page's dump holds no `[场景]`,
  `[scene]`, `青石观蚁` or `1：` string, the band scan finds no gap of page background where a tag stood, and the
  deleted-line twin's screenshot comparison (`FR-004`, `SC-002`, `SC-006`).
- [x] T027 Walk `quickstart.md` row 11 into `specs/024-scene-tags/breakpoint.md`: **five** utterances on the fixture and
  on its deleted-line twin, the same texts in the same order, no blank or tag utterance, the highlight crossing each
  boundary in one step, and the elapsed times within one utterance (`FR-005`, `SC-003`, `SC-006`).
- [x] T028 Walk `quickstart.md` row 12 into `specs/024-scene-tags/breakpoint.md`: EDIT, Format, one Undo — the tag line
  stands alone after the press with no character changed, the text is the input again after one Undo, and a second press
  reports nothing to do (`FR-006`, `SC-004`).
- [x] T029 Walk `quickstart.md` row 13 into `specs/024-scene-tags/breakpoint.md`: five pictures, the option's label
  (absent for a no-scene content), the thumbnails' counts `2`, `2`, `1`, `0`, `0` after it, the sentence list under each
  picture, and a move that still works (`FR-008`, `FR-009`, `FR-011`, `FR-012`, `SC-005`, `SC-006`).
- [x] T030 Walk `quickstart.md` row 14 into `specs/024-scene-tags/breakpoint.md`: the renderer's own `klhu render` lines
  naming **five** slots, zero tag glyphs in any frame (16:9 and 9:16), the frame after a boundary opening the next
  sentence with no blank slot, and the frame count equal to the deleted-line twin's (`FR-004`, `FR-005`, `SC-006`,
  `SC-008`).
- [x] T031 Walk `quickstart.md` row 15 into `specs/024-scene-tags/breakpoint.md`: the five closed features' own rows
  re-run on a **tag-free** content — `klhu_walk_comment.py`, `klhu_walk_head.py`, `klhu_walk_step.py`,
  `klhu_walk_assignment.py`, `klhu_walk_pass.py`, `klhu_walk_video.py 32` — each count beside the number its own
  `quickstart.md` records, no row re-cut; a count that moves is a finding, recorded in `breakpoint.md` rather than fixed
  by editing that row (`FR-016`, `SC-001`).

## Phase 7: Polish & cross-cutting concerns

- [x] T032 `specs/024-scene-tags/breakpoint.md`: the structural row — `flutter analyze`, the suite's count (857 plus
  this feature's own, decomposed by file), the four ARBs at 135 with `flutter gen-l10n` idempotent,
  `test/l10n_keys_test.dart` green, `test/*.dart`'s and `lib/*.dart`'s counts, and the six artifact checkers quoted by
  their own output (`FR-016`, `SC-001`).
- [x] T033 `specs/024-scene-tags/tasks.md`: re-take `## Status` from the rows' own runs and tick each row against its
  own receipt — no tick on a neighbour's pass, and the checker numbers re-run rather than copied forward.
- [x] T034 [P] `specs/024-scene-tags/checklists/requirements.md`: the tasks-stage notes — what landed, what is owed, and
  each requirement read against the row that claimed it, with anything not landed named as owed rather than implied.
- [x] T035 [P] `specs/024-scene-tags/spec.md`: write the walk's measured figures back into `SC-002`, `SC-003`,
  `SC-005`, `SC-006` and `SC-008`'s own sentences (whichever way they land), and fold in the two new spellings' own
  receipts (row 1's twin content, row 14's frame scan), so no placeholder survives the closing pass.

## Dependencies & ordering

- **T001 → T002**: the table cannot compile before the module exists — that is this stage's RED.
- **T002 → T003/T007/T016/T017/T024**: every later unit row calls the scanner; T003's ownership and T017's Format
  function both read `sceneTagsOf`.
- **T003 → T004**, **T005 → T006**: each pair is one test file and the source it drives.
- **T004 → T019/T020**: the pairing takes the scenes' own sentence ranges (D8), so it cannot be written before
  `scenesOf` answers them.
- **T006 → T009/T010/T011/T012**: the mask exists before any consumer takes it.
- **T009 → T013**: R4's condition is read off T009's turn case — red means `lib/dialogue.dart` is edited, green means it
  is not.
- **T008 → T014/T015**: the identity and seam cases compare against the one elision.
- **T016 → T017 → T018**: the RED, the pure function, then the press that composes it.
- **T019 → T020**, and **T021 → T022 → T023**: the pairing and the option are separate surfaces, but the option's test
  pumps a page whose label is a generated getter.
- **T002..T024 → T025**: the walk needs every unit row green; a device row that reproduces a defect the units could have
  caught spends a build.
- **T025 → T026..T031, and T026..T031 run in order and never in parallel**: one `breakpoint.md`, one driver, one build.
- **T026..T031 → T032 → T033**, and **T031 → T035** (the measured figures are the walk's); T034 reads what landed.

## Parallel opportunities

- **T001 with T021**: the grammar's RED and the four ARBs are different files with no dependency between them.
- **T034 with T035**: the checklist's notes and the spec's measured sentences are different files.
- **Not parallel**: any two device rows (`breakpoint.md` has one writer), T003/T005/T007/T009/T014/T015/T024 (one test
  file, `test/scene_tag_test.dart`), and T010–T012 (one file's four seams read in order).

## Implementation strategy

The grammar first (T001–T006), so every story has a tag to read; then the two ends of US1 — the painted string and the
spoken lists (T007–T015); then Format (T016–T018); then the pairing and its page (T019–T023); the near-miss case closes
the rules (T024); one build carries the five device rows (T025–T031); the closing pass re-takes the numbers (T032–T035).
The MVP is Phase 2: a content whose tags vanish from the page, the read, the steps, the rows and the slots, with the
film's frames carrying no tag — demonstrable on its own, before anything pairs a picture with a scene.

## Notes

- `flutter analyze` after every file; `flutter test --concurrency=2` at each phase boundary.
- The tree's own count is 857 tests; this feature's rows are **added**, and T032 states the new number.
- No row edits 014's, 015's, 019's, 020's or 021's own tests, and no row edits a closed spec's artifacts. A row that
  finds it must is reporting a defect, not doing its task.
- Every `[unit]` row names the file it runs in and the ids it proves; every device row cites the quickstart number the
  driver dispatches on.
- Rows are append-only: a row added after the walk starts takes the next free number, and a quickstart expectation that
  moves is recorded in `breakpoint.md` rather than edited into the row that already ran.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (four spellings, one per shipped UI locale, all live in every content) | T001, T002 |
| FR-002 (recognised at a line's head; the rest of the line is the heading) | T001, T002 |
| FR-003 (a scene owns the sentences after its line, until the next tag) | T003, T004 |
| FR-004 (the tag, its heading and its break are painted nowhere) | T007, T008, T026, T030 |
| FR-005 (silent to every derived list; tag-free text's lists unchanged) | T005, T009, T010, T011, T012, T013, T027, T030 |
| FR-006 (Format gives a tag its own paragraph; blank lines only) | T016, T017, T018, T028 |
| FR-007 (a near miss is the reader's own text) | T001, T024 |
| FR-008 (the option is offered when scenes exist, absent when not) | T021, T022, T023, T029 |
| FR-009 (i-th picture with i-th scene, in each side's own order) | T019, T020, T029 |
| FR-010 (the result obeys 020's run rules) | T019, T020 |
| FR-011 (the result is an ordinary assignment) | T020, T022, T029 |
| FR-012 (ask first when anything would be replaced) | T021, T022, T023, T029 |
| FR-013 (min(N, M) of each; leftovers keep 020's meanings) | T019, T020 |
| FR-014 (the sentences before the first tag belong to no scene) | T003, T004, T019 |
| FR-015 (a tag inside a comment's span or on a marked line is not a scene) | T002, T015 |
| FR-016 (a content with no scene tag is unchanged on every surface) | T006, T014, T024, T031, T032 |
| FR-017 (the heading belongs to no scene and to no picture) | T003, T004, T019 |
| SC-001 (identity: byte-identical results for a tag-free content) | T014, T031, T032 |
| SC-002 (measured, elision: zero tag characters, byte equality with the deleted-line text) | T007, T026 |
| SC-003 (measured, silence: same count, text and order as the deleted-line content) | T003, T009, T027 |
| SC-004 (measured, Format: blank lines only, one Undo, a second press changes nothing) | T016, T018, T028 |
| SC-005 (measured, pairing: min(N, M) runs equal to the hand-made assignment, across the N×M grid) | T019, T020, T029 |
| SC-006 (device: no tag in any frame or on the page, no pause or slot at a boundary) | T026, T027, T029, T030 |
| SC-007 (measured, near misses: unchanged frame for frame and utterance for utterance) | T001, T015, T024 |
| SC-008 (measured, the item's own example: no characters, one run, heading in no sentence) | T030, T035 |
