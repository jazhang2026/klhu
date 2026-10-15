# Tasks: Sentences assigned to pictures

**Feature**: `020-sentence-pictures` | **Date**: 2026-10-14
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) |
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)
**Format**: `[ID] [P?] [Story] Description with file path`

**Grounding revision**: `a3a25e1` — the commit that lands this feature's spec, checklist, sketch and plan, with the
amendments of 2026-10-14 below written into them by this stage. Every line number here was read on that tree.

## Status

**Thirty-nine of 39 are done; the list is closed (2026-10-15).** Every row of every phase carries its own
receipt: T001-T029 (passes 1, 2, 4, 5, 6, 7, 8 and 9 — the work before the stories, US1, US2, US5, the walk's
driver with **all nine** of its device rows, and 012's own row re-walked), T032-T034 (012's row re-walked, the two
list checkers, and the polish phase's checks) and T035-T039 (pass 3, the reader's own amendment of 2026-10-14: a
video is the whole content, its unit case and its device row included). **No row still needs a walk**: the nine
device rows of `quickstart.md` — 6, 7, 8, 9, 10, 11, 12, 13, 16 and 18 — were each walked on `emulator-5554`, and
each has a PASS with its own evidence in `breakpoint.md`.

**The closing receipt (2026-10-15 08:40-08:45 PDT, on the tree of 2026-10-14)**:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 01:17 +782: All tests passed!    (T001's 729 + 53)
message keys per ARB (four files)    → 120 each        (019's 110 + this feature's ten)
test/*.dart files in the tree        → 55
check_tasks_format.py               → 39 tasks (39 done), 5 marked [P]
task_id_audit.py                    → 020-sentence-pictures: 39 tasks, 39 done, 5 [P]
check_quickstart_coverage.py        → 17 FR + 11 SC defined | no 'Proves' line: none
check_row_coverage.py               → 28 ids defined | coverage table cites 28 id(s)
spec_consistency.py                 → no divergence
check_artifact_refs.py               → exit 0 | checked 58 line references | no unresolved references
```

**The 53 cases, decomposed by file**: three **new** files — `test/picture_assignment_test.dart` **20**,
`test/picture_assignment_store_test.dart` **8**, `test/reading_view_video_assignment_test.dart` **18** (46) — and
**seven** added across the two **extended** ones (`test/video_pictures_test.dart` 22 → **27** and
`test/video_renderer_test.dart` 22 → **24**). 729 + 46 + 7 = **782**.

**The baseline (T001 re-took and confirmed it; measured 2026-10-14 08:02 for this file on `a3a25e1`, before any
edit)**:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 00:59 +729: All tests passed!
message keys per ARB (four files)    → 110 each          (this feature adds 11)
test/*.dart files in the tree        → 52
```

## Implement pass 1 (2026-10-14) — setup, foundational, and the stored setting

Rows **T001-T007**: all of Phase 1, Phase 2 and Phase 3 — the rule, the schedule seam and the store, which is
the work every story stands on, taken as one pass because it is not a story's own.

    flutter analyze                      No issues found! (ran in 0.9s)
    flutter test --concurrency=2         01:00 +755: All tests passed!   (T001's 729 + 26)
    test/picture_assignment_test.dart    new, 14 cases
    test/picture_assignment_store_test.dart  new, 8 cases
    test/video_pictures_test.dart        012's 22 unchanged + this feature's 4 = 26
    lib/video_pictures.dart              git diff --stat → 70 insertions, 0 deletions
    check_tasks_format.py (020)          34 tasks (7 done), 4 marked [P] / OK: format, sequencing and spec-id coverage check out
    task_id_audit.py (020)               020-sentence-pictures: 34 tasks, 7 done, 4 [P]

**Three artifacts were corrected by this pass's own findings**, each dated in place rather than explained away:
D5's mechanism (a skipped picture keeps 012's **undrawn** entry — `plan.md`, `data-model.md` §3, `research.md`
§1), T004's row wording, and T002's own scope (row 4's unit half, taken here so US5's widget row has the answer
it asserts through the page).

## Implement pass 9 (2026-10-14) — the walk's rows 11 and 12, and 012's own row re-walked

Rows **T026-T027** and **T032** (Phase 7 and the polish phase): the stale warning read on the device, the
no-assignment render compared with 012's own, and 012's row 49 re-walked because 020 moves the dialog it drives.

    row 11                               12/12 checks passed (exit 0) — the warning on screen before any render
                                         (`1 assigned run no longer fits this text` / `w020_white.png: sentences 3`),
                                         no schedule line in the log while it is up, and its tap landing on the pass
                                         on the picture it named (read off the reader's own next tap)
    row 12                               10/10 checks passed (exit 0) — 012's own fixture, nothing assigned:
                                         `pictures=9 ranges=<eight>,- sentences=8`, **743 frames / 24.894 s**
    T032  012's row 49 re-walked           40/41, and the one that moved is 020's assignment line tripping that row's
                                         "no label mentions sentences" filter — pointer in 012's `tasks.md`, its
                                         artifacts otherwise as written. Its figures: **743 frames / 24766 ms**
    what row 12 settles                   SC-003 on the device: the same frame count 012's own row reaches, frame for
                                         frame. **012's row 31's 818 frames / 27.39 s no longer reproduce for
                                         either row** — the synthesis' own durations are the device's — and the
                                         deviation is named, not smoothed over
    rows still owed                      13, 16 (plus T030/T031/T033/T034, the polish phase's own checks)

## Implement pass 8 (2026-10-14) — the walk's rows 9 and 10

Rows **T024-T025** (Phase 7): the drag and the order the render walks, and the skip with the tail's fallback.

    row 9                                14/14 checks passed (exit 0) — the `-` picture dragged to the front, the
                                         render's own line the same three ranges one place along, and the hold on a
                                         picture holding sentences refused with its reason while the finger is down
    row 10                               14/14 checks passed (exit 0) — the skip (`-`), the gap keeping the picture
                                         before it, and the seven-sentence tail split 4 + 3 between the two pictures
                                         after it, every boundary on a sentence's own frame
    the drag's own mechanism              `input draganddrop` does not make a Flutter long-press drag on this device
                                         (probed); the driver injects `motionevent DOWN`, a 1.6s hold, MOVEs, `UP`
    taught by these rows                  a picture left empty is skipped only **between** two runs (one after the last
                                         run is fed by the fallback and drawn) — so a row that needs a gap says which
                                         sentences it wants (`assign_indices`); and a refusal must be read while the
                                         finger is down (its SnackBar lives about as long as the gesture)
    rows still owed                      11, 12, 13, 16

## Implement pass 7 (2026-10-14) — the walk's rows 7 and 8

Rows **T022-T023** (Phase 7): the two refusals, and the un-assign at the ends.

    row 7                                15/15 checks passed (exit 0) — both refusals with their own rules on screen,
                                         the chips unchanged, and the render's own line the same one before and after
    row 8                                14/14 checks passed (exit 0) — the holds refusal, the middle refusal, the ends
                                         going one at a time (2 → 1 → 0 sentences), and the freed picture no longer
                                         refused — both rows' own entries in breakpoint.md
    taught by these rows (driver)        ① rows are not isolated: the previous row's stored assignment is still in
                                         force for the same content id, so `seed_content` clears the settings first
                                         ② a review arrives with a transition — a tap read while it moves misses
                                         ③ `assign` closes the pass, so a row's own edits re-open it
                                         ④ a NOT FOUND in `hold`/`tap_chip`/`tap_row` now records a check
    rows still owed                      9, 10, 11, 12, 13, 16

## Implement pass 6 (2026-10-14) — the device walk, its driver and row 6

Rows **T020-T021** (Phase 7): the driver, and the first row walked on the emulator.

    the device                           emulator-5554 (klhu), com.example.klhu, debug APK rebuilt and installed
                                         15:0x on this tree — 012's `preflight` refuses an app older than the APK
    the driver                           specs/020-sentence-pictures/scripts/klhu_walk_assignment.py — 016's mechanics
                                         through 012's module, 012's own pick and `pull`, this feature's fixture and
                                         pictures, and the new `RENDER_PLAN_RE` parser
    row 6                                13/13 checks passed (exit 0); the app's own line verbatim and three frames
                                         sampled inside the three ranges — all in breakpoint.md's row 6 entry
    driver bugs paid for, fixed          ① a finished render's file is private (use 012's `pull`, not `adb pull`)
                                         ② `uiautomator dump` refuses while a window animates and 012's `dump` then
                                         pulls the previous XML — `fresh_dump`/`dump_until` answer it
    rows still owed                      7, 8, 9, 10, 11, 12, 13, 16 — named by `main` and by breakpoint.md

## Implement pass 5 (2026-10-14) — US5, end to end

Rows **T018-T019** (Phase 6): a content edited under an assignment is caught **before** the render, named, tappable
into the pass on the offending picture — and a render started anyway uses the runs that still fit.

    flutter analyze                      No issues found! (ran in 0.8s)
    flutter test --concurrency=2         01:17 +782: All tests passed!   (pass 4's 780 + 2)
    test/reading_view_video_assignment_test.dart         16 → **18** cases
    RED                                   behavioural, not a compile error: both cases failed on `Found 0 widgets
                                          with text "2 assigned runs no longer fit this text"` — the fixture reached
                                          the screen and the warning was not there
    the page's own claim, not the answer's
                                          `runsThatFit(answer, runs)` — the reader's runs minus the resolver's stale
                                          ones. **Not** `AssignmentAnswer.effective`, which carries FR-006's fallback
                                          (the render's own outcome, not the reader's decision, FR-011)
    what the warning can name              the picture, and how many sentences its lost run held. The sentences
                                          themselves are gone with the text the spans pointed at (SC-008's "naming the
                                          sentences involved" read strictly; put to the reader, annotated in place)
    ARB                                   es/zh/zh_Hans' `assignmentStaleDetail` reworded to read a **count**
                                          (`flutter gen-l10n`); the ten keys, their template and the total are unchanged
    device rows owed                      quickstart row 11 (Phase 7)

## Implement pass 4 (2026-10-14) — US2, end to end

Rows **T014-T017** (Phase 5): only continuous runs, only in order — each refusal told with the reason it broke, with
the assignment in force left exactly as it was, and the drag that moves a picture holding nothing.

    flutter analyze                      No issues found! (ran in 0.9s)
    flutter test --concurrency=2         01:04 +780: All tests passed!   (pass 3's 768 + 6 + 5 + 1)
    test/picture_assignment_test.dart                    14 → **20** cases
    test/reading_view_video_assignment_test.dart         11 → **16** cases
    test/video_pictures_test.dart                        26 → **27** cases
    RED                                   a before-tree built for the purpose: the pass file moved aside, the US2
                                          block cut out of the rule module, run, then both restored byte for byte
                                          (`sha256sum` checked). `flutter analyze` → 38 issues; `flutter test
                                          test/picture_assignment_test.dart` → `Method not found: 'mayDrag'` —
                                          the file does not load
    what the pass answers with now         `AssignmentDraft`: the pictures **and** their runs, because a picture
                                          holding nothing has no run to carry its place in the walk (FR-015)
    device rows owed                       quickstart rows 7, 8 and 9 (Phase 7); their unit halves are this pass's
                                          cases

## Implement pass 3 (2026-10-14) — the reader's own amendment

Rows **T035-T038** (Phase 9, appended): *a video is the whole content, whatever the page is showing* — the reader's
statement and answer at this file's own gate (`spec.md`'s Clarifications item 6, `plan.md`'s Amendment 2,
`checklists/requirements.md`'s Amendment 6).

    flutter analyze                      No issues found! (ran in 0.8s)
    flutter test --concurrency=2         01:05 +768: All tests passed!   (pass 2's 767 + this case)
    test/reading_view_video_assignment_test.dart  10 → **11** cases
    check_tasks_format.py (020)          39 tasks (17 done), 5 marked [P] / OK: format, sequencing and spec-id coverage check out
    task_id_audit.py (020)               020-sentence-pictures: 39 tasks, 17 done, 5 [P]
    check_quickstart_coverage.py (020)   17 FR + 11 SC defined / 18 rows ([unit] 7, [device] 10, [structural] 1) / unclaimed: none
    check_row_coverage.py (020)          28 ids defined / every defined id is a row's own claim
    spec_consistency.py (020)            FRs 17 · SCs 11 · stories 6 · scenarios 20, no divergence
    what it supersedes                   012 FR-004's first half, proven by a throwaway probe taken BEFORE the
                                         change: `sentences=1 … span=22..31` with the last sentence highlighted
    what it does not touch                010/011/016's own rule (the highlight still starts a **read**), and
                                         `test/video_timeline_test.dart`'s four start-point cases, which test the
                                         timeline's own API and stay true
    the pointer                            `specs/012-reading-video/tasks.md` `## Superseded by later specs`

**The device row is owed**: T039 (quickstart row 18) is walked in Phase 7's pass, with the rest of the walk — the
unit case above is the rule's own receipt until then.

## Implement pass 2 (2026-10-14) — US1, end to end

Rows **T008-T013**: the pass the reader assigns on, the keys it says things with, the dialog's own seam, and the
renderer's split. The story's own Independent Test is row 6's, and it is walked in Phase 7 — what this pass
establishes is that the runs a reader makes reach the frames.

    flutter analyze                      No issues found! (ran in 0.8s)
    flutter test --concurrency=2         01:04 +767: All tests passed!   (pass 1's 755 + 12)
    test/reading_view_video_assignment_test.dart  new, 10 cases
    test/video_renderer_test.dart        012's 22 unchanged + this feature's 2 = 24
    test/reading_view_video_test.dart    012's 2121-line page suite, 31 cases, **unmodified** and green
    message keys per ARB (four files)    110 → **120**, ten keys, `l10n_keys_test.dart` green both ways
    check_tasks_format.py (020)          34 tasks (13 done), 4 marked [P] / OK: format, sequencing and spec-id coverage check out
    task_id_audit.py (020)               020-sentence-pictures: 34 tasks, 13 done, 4 [P]
                                         *(pass 3 appended five rows after these runs: the file is at **39** with
                                         **17** done — the checkers are re-run at the end of this pass and their
                                         output is quoted in the section below.)*

**Two artifacts were corrected by this pass**: the ARB count (eleven keys and 121 → **ten keys and 120**:
`doneButton` already says "Done" and the plan's rule is to reuse it — T010, T030 and `quickstart.md` row 14
carried the old figure and are dated in place), and nothing else: D5's correction from pass 1 is what this
pass's renderer cases then read.

**Two decisions this pass took that the artifacts left to it** — both named in the rows that took them, and both
a reviewer's to overturn: the pass's own presentation (**an unassigned sentence is shown as unassigned**, not as
belonging to the picture before it), and the sentence list the pass shows (**the render's own**, from the page's
start point — so with a Continue Read anchor set, the pass opens at that sentence).

**The one decision this pass took that no artifact stated** — and the first thing a reviewer should argue with:
**a render whose runs are all stale is no assignment at all** (012's own split, FR-009), rather than a video in
which every picture is skipped. The warning still names every run (FR-014); what it does not do is hand the
reader a video with no pictures because the text moved.

**The amendment this stage produced, and what it moved.** The reader answered at the tasks gate on 2026-10-14
(**option A**): a run names its picture by the picture's own **file name**, not by the prompt's own path — because
012's shipped rule is that the picks are never remembered and the directory a pick was written into is deleted when
the prompt ends, so a path-keyed run could not outlive a visit (`research.md` D7; `spec.md` FR-010 and SC-006
rewritten in place, no new id; `checklists/requirements.md` Amendment 5). Everything else is this stage's own
corrections, each dated in the file it belongs to: `quickstart.md`'s row 14 (the four ARBs are **not** unchanged),
its row 12 (the comparison now names the figures 012's own records carry), and its two appended rows (15 and 16,
for FR-010, FR-013, SC-006 and SC-007, which had **no row at all**); `plan.md`'s file table (the split function has
one home, beside `buildPictureSchedule`) and its own amendment block.

**Format checker**: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/020-sentence-pictures`,
beside `task_id_audit.py specs/020-sentence-pictures`, re-run after this file's last edit and quoted verbatim in
T033's tick.

**T033's own quotes** (both list checkers, on this file as of 2026-10-14):

```
$ python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/020-sentence-pictures
tasks.md: 39 tasks (39 done), 5 marked [P]
  (setup/foundational/polish): 14
  [US1]: 7
  [US2]: 7
  [US3]: 1
  [US4]: 2
  [US5]: 3
  [US6]: 5

OK: format, sequencing and spec-id coverage check out

$ python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/task_id_audit.py specs/020-sentence-pictures
020-sentence-pictures: 39 tasks, 39 done, 5 [P]
```

**Suite**: the feature's own cases are three new files (`test/picture_assignment_test.dart`,
`test/picture_assignment_store_test.dart`, `test/reading_view_video_assignment_test.dart`) plus new groups in two
shipped files (`test/video_pictures_test.dart`, `test/video_renderer_test.dart`). **No shipped case is expected to
be re-cut**, and that is a claim the rows hold to a grep rather than to a hope: the dialog's own 2121-line suite
pins the picker's cells (`MovableThumbnail`, `ChosenThumbnail`, the remove tooltip — `findsNWidgets` on the window
it draws) and taps the actions by their labels, and nothing in it enumerates the dialog's *action set*; the
renderer's own suite constructs `VideoRenderer` with named optional parameters, so a new `runs:` parameter leaves
it compiling. A shipped case that does move is this claim failing, and the row that sees it says so instead of
re-cutting quietly.

**Device rows**: quickstart rows **6** (the line, the pass and the render's own ranges), **7** (the two refusals),
**8** (un-assigning at the ends and in the middle), **9** (the drag), **10** (the skip and the tail's fallback),
**11** (the stale warning before the render), **12** (no assignment is 012's video), **13** (the audio) and **16**
(the assignment outlives the prompt and re-attaches by name) — nine rows, walked through
`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` into `specs/020-sentence-pictures/breakpoint.md`
(created by the first row that walks). Row **14** is structural and is T030's, not the driver's.

## Grounding notes (the decisions these tasks implement)

1. **A run's key is the picture's own file name** (research D7, FR-010 as amended): `HeldPicture.name` — the
   reader's own basename, which `storePicks` keeps beside the sanitised copy's name — so a run re-attaches when the
   same file is picked again, and goes **stale** when it is not. Two picks carrying the same name: the **first in
   the pick order** takes the run.
2. **One resolver, read twice** (research D4): `assignmentsFor(sentences, runs, pictures)` answers the *effective
   runs* and the *stale runs* — the pass, the warning and the render all read the same answer (the **refusal
   reason** a proposed change is answered with is a second, separate call the pass makes, T016's),
   so the warning cannot disagree with what the render did.
3. **The split has exactly one home** (D3, and the plan's file table as corrected): a function **beside**
   `buildPictureSchedule` in `lib/video_pictures.dart`, which stays the no-assignment branch **verbatim** — its body
   does not move a line, which is what makes SC-003 a `git diff` rather than an assertion.
4. **The pass rides the dialog's own seam** (D6): `_askVideoFormat`'s answer gains the runs, and the page resolves
   the video's own sentence list **once**, from the same start point the render will use (`_anchor ?? 0`, the same
   `videoSentencesFrom` call with the same mode, removals, picks and `commentsRead`) — the pass shows the sentences
   the render will speak, never a second derivation of them.
5. **A skipped picture emits no `ScheduledPicture`** (D5): FR-007's skip is the absence of a range, which is the
   `-` the renderer's own line already prints for a picture it did not draw — no zero-length range, and no new log
   field (the assignment *is* the `ranges=` it already prints).
6. **The store is 015's shape** (FR-010/FR-013, `data-model.md` §2): one `shared_preferences` key,
   `content_picture_assignments`, a JSON object keyed by the content's own id, read tolerantly — a malformed entry
   is ignored while its siblings stand. Nothing here touches 015's own key.
7. **The walk's driver needs 012's machinery, not only 019's**: no other driver in the tree pushes pictures to the
   device or drives the platform's own file dialog (`make_pictures` / `push_pictures` / `choose_pictures` /
   `picture_at` live in `specs/012-reading-video/scripts/klhu_walk_video.py` alone), and **no driver at all** parses
   the renderer's own `klhu render pictures=… ranges=… sentences=…` line, which rows 6, 9, 10 and 12 read.

## Path conventions

- Source: `lib/`; tests: `test/`; this feature's own artifacts: `specs/020-sentence-pictures/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up can make
  plain `flutter test` segfault on this 16 GB host)
- l10n: the four ARBs (`lib/l10n/app_{en,es,zh,zh_Hans}.arb`) plus `flutter gen-l10n`, whose output is committed;
  `test/l10n_keys_test.dart` fails as loudly for a key a translation kept as for one it is missing
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`, the debug APK installed
  with `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`
- The walk: `/usr/bin/python3 -u specs/020-sentence-pictures/scripts/klhu_walk_assignment.py <row>` — the Python 3.12
  that has PIL, because the driver's import chain measures frames; the driver dispatches by the **quickstart row
  number**, so a row added later takes the next free number
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/020-sentence-pictures`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the number every later tick is read against. Nothing is installed — this feature adds no dependency, no
asset and no platform file (plan § Project rules).

- [x] T001 Record the baseline in `specs/020-sentence-pictures/tasks.md`'s Status before touching anything:
      `flutter analyze` (expect `No issues found!`), `flutter test --concurrency=2` (expect **729 passing, 0
      failing**), the four ARBs' message-key count (expect **110** each) and `ls test/*.dart | wc -l` (expect
      **52**) on `git rev-parse --short HEAD`, then write all four figures, the commands and the date into the
      Status section beside the amendment paragraph. This stage's own measurement is `2026-10-14 08:02` on
      `a3a25e1`: analyze clean in 1.2 s, `00:59 +729`, 110 keys each, 52 test files. If a count differs from that,
      the difference is the first thing the handback reports: a drifted baseline is why every later tick is read
      against the wrong number.
**DONE 2026-10-14** — re-taken before this pass's first edit, on `a3a25e1`: `flutter analyze` →
      `No issues found! (ran in 1.2s)`; `flutter test --concurrency=2` → `00:59 +729: All tests passed!`; the
      four ARBs → **110** message keys each; `ls test/*.dart | wc -l` → **52**. Every figure reproduces the
      Status's own, so no earlier stage's number had drifted and every row below is read against **729**. (The
      count of test files is the one figure this stage's own first draft got wrong — 51, counted by eye; the
      command says 52, and the Status now carries 52 for the same reason.)

---

## Phase 2: Foundational (the rule and the schedule seam)

**Purpose**: the two pure units every story stands on — the resolver and the split — each a new file or an additive
change, which is why the checkpoint below is `buildPictureSchedule`'s own body showing **no diff**, a stronger claim
than "the tests pass".

- [x] T002 [P] `test/picture_assignment_test.dart`: write the rule's own groups as the file's first half —
      **quickstart.md rows 1, 2 and 4's unit half** (row 4 taken here so US5's widget row can read the stale
      answer this row's own group answers with — see the tick). Row 1: a `PictureRun`'s spans are sentence spans of the content, ascending, no
      two runs naming a sentence, an empty `runs` list being the no-assignment state rather than an assignment of
      zero-length runs, and a run's picture being named by its **file name** (`HeldPicture.name`) — a run whose name
      is in no pick is `stale` and is never re-pointed, and it comes back into force when that name is picked again,
      with two same-name picks resolved by the first in the pick order (research D7, INV-8). Row 2:
      `assignmentsFor`'s six shapes in one table — the assigned run; a sentence between two runs (the previous
      picture); the tail with pictures after it (012's own even split, `each = n ~/ paths.length`, remainder first);
      the tail with none (the last assigned picture); a picture between two runs left with nothing (skipped); and
      `runs` empty (012's split, frame for frame). Run it and keep the RED output (a compile error on the base —
      `lib/picture_assignment.dart` does not exist; say so when the RED is one).
**DONE 2026-10-14** — written as the file's three groups (rows 1, 2 and **row 4's unit half**, taken here so
      US5's widget row can read the answer it asserts through the page): 14 cases.
      **RED as a compile error**, quoted: `test/picture_assignment_test.dart:11:8: Error: Error when reading
      'lib/picture_assignment.dart': No such file or directory`, `:34:1: Error: Type 'PictureRun' not found.`,
      `:42:16: Error: 'AssignmentAnswer' isn't a type.`, `:58:22: Error: Method not found: 'assignmentsFor'.`
      Green after T003: `flutter test test/picture_assignment_test.dart` → `00:00 +14: All tests passed!`.
      **Three expectations this row's own author wrote wrong, and the artifact decided each** (all three were
      corrected in the test, none in the code): (1) the "back into force" case picked two pictures, so with one
      assigned picture and none after it the tail is **not** left on the run — FR-006's second half gives it to
      the last assigned picture — and the case could not see the re-attach at all; it picks three now, so the
      tail has somewhere else to go. (2) The stale fixture edited `One!` for `One.` — the same length, so no
      span moved and nothing could go stale; the edit is `Twos.` for `Two.`, one character more **inside** the
      second sentence, which moves every span after it while the first sentence's own span stands. (3) A
      partially-matched run over a **single** picture lets the gap rule absorb the sentences the run lost, so the
      shrink is invisible; that case takes a second picture, and the shrink is then what the assertion reads.
- [x] T003 `lib/picture_assignment.dart`: implement green against T002 — `PictureRun` (`name`, `spans`), the
      resolver `assignmentsFor` answering the effective runs, the stale runs and the refusal reason in one answer
      (research D4), and the drag / un-assign predicates. The doc comments name why the key is the file name and not
      the prompt's own path (D7), why a stale run is dropped rather than re-pointed (FR-014), and which rule each
      refusal names (FR-012). **Checkpoint**: `flutter test test/picture_assignment_test.dart` green;
      `flutter analyze` clean; the file is new and nothing shipped calls it yet.
**DONE 2026-10-14** — `lib/picture_assignment.dart` created: `PictureRun` (the file name + the sentences'
      spans), `AssignedRun` (the render's own sentence indices), `AssignmentAnswer` (`none`/`isInForce`) and
      `assignmentsFor`, whose three rules are documented in the order they decide (matching by name → the tail →
      the gaps). Green: `flutter test test/picture_assignment_test.dart` → `00:00 +14: All tests passed!`;
      `flutter analyze` → `No issues found!`.
      **One lint this row introduced and fixed in the same pass**: `use_null_aware_elements` on the span-matching
      set (`if (bySpan[span] case final index?) index`) — replaced by the SDK's own suggestion, `?bySpan[span]`.
      **One decision this row took that the artifacts did not state, and it is the reviewer's to overturn**: a
      render whose runs are **all** stale is treated as *no assignment at all* (012's own split, FR-009) rather
      than as a video in which every picture is skipped — which is what FR-007 read alone would give. The
      warning still names every run (FR-014); what it does not do is produce a video with no pictures because the
      text moved. Its doc comment says so, and T029's device row is where it can be argued with.
- [x] T004 [P] `test/video_pictures_test.dart`: add **quickstart.md row 3**'s group beside 012's own cases, which
      stay untouched — with an assignment the ranges follow the runs, with none `buildPictureSchedule`'s own output
      comes back **compared as ranges and frames, not as a shape**, and a run holding nothing keeps 012's own
      **undrawn** entry for its picture (`frames == 0` — D5/FR-007 as corrected by this pass's own finding),
      which is what the renderer's own line prints as `-` for it. Run it and keep
      the RED output (a compile error for the new function on the base).
**DONE 2026-10-14** — the group added to `test/video_pictures_test.dart` **beside 012's own cases, which are
      unmodified**: four cases (the ranges follow the runs; a picture holding nothing; no runs at all; runs that
      hold nothing). **RED as a compile error**, quoted: `test/video_pictures_test.dart:40:8: Error: Error when
      reading 'lib/picture_assignment.dart': No such file or directory`, `:530:24: Error: Method not found:
      'buildAssignedSchedule'.`, `:534:11: Error: Method not found: 'AssignedRun'.` Green after T005:
      `flutter test test/video_pictures_test.dart` → `00:00 +26: All tests passed!` — **012's own 22 cases plus
      this feature's 4**, each counted from a run of that file alone.
      **The row's own wording was wrong about the mechanism, and this pass corrected it**: a picture holding
      nothing does not "emit no `ScheduledPicture`" — the `-` the renderer's own line prints comes from an entry
      that **is** in the schedule and is not drawn (`isDrawn == false`, `frames == 0`), which is exactly 012's own
      treatment of a picture that found no sentence. The case asserts that, and D5's correction is dated in
      `plan.md`, `data-model.md` §3 and `research.md` §1.
- [x] T005 `lib/video_pictures.dart`: implement the split **beside** `buildPictureSchedule` (D3) green against T004
      — the runs in, the same `PictureSchedule`/`ScheduledPicture` shape out, the picture's own frame maths reused
      rather than re-derived, `PictureSchedule.none` for no pictures. **Checkpoint**: `flutter analyze` clean;
      `flutter test --concurrency=2` = T001's count + this phase's new cases; `git diff lib/video_pictures.dart`
      shows the new function **beside** `buildPictureSchedule` and **not one changed line inside it** — the
      structural half of SC-003, checkable now rather than in T030.
**DONE 2026-10-14** — `buildAssignedSchedule` and its one helper (`_heldAfter`) added to
      `lib/video_pictures.dart` **beside** `buildPictureSchedule`, whose body took **no change at all**:
      `git diff --stat lib/video_pictures.dart` → `1 file changed, 70 insertions(+)` — the import and the new
      code, zero deletions. The no-assignment branch is that function's **own call** (`buildPictureSchedule(plan:
      plan, paths: paths)`), which is what makes SC-003's "frame for frame" a diff rather than an assertion; the
      picture's frame maths and the end hold are reused, not re-derived. Green: `00:00 +26: All tests passed!`;
      `flutter analyze` → `No issues found! (ran in 0.9s)`. **Checkpoint**: `git diff lib/video_pictures.dart`
      names the new function and nothing else — the structural half of SC-003, checkable now rather than at
      T030.

---

## Phase 3: The assignment as a stored setting (FR-010, FR-013 — no story of their own)

**Purpose**: clarification 4's decision, which the spec attaches to no user story: the assignment is a stored
setting of the content, read back on open and surviving a relaunch (FR-010), never a part of a rendered file
(FR-013). Its consumer is the pass (Phase 4), so it lands first and alone.

- [x] T006 [P] `test/picture_assignment_store_test.dart`: write **quickstart.md row 15** — one key per content: the
      store answers the runs the reader made for **this** content and nothing of another's; a malformed entry is
      ignored while its siblings stand; a content nothing was assigned on carries no entry, and clearing the runs
      leaves none behind. Assert the record's own shape (`{name, spans}` per run, in the pictures' display order,
      `data-model.md` §2), not the platform's file. Run it and keep the RED output.
**DONE 2026-10-14** — `test/picture_assignment_store_test.dart` written: eight cases over mocked
      `shared_preferences` (one key per content; each content answers its own; nothing assigned carries no entry;
      clearing leaves no entry; clearing one leaves the other; a malformed entry beside a good one; a run with no
      name or a span that is not a pair; a store that is not JSON, not an object, or an entry that is not an
      object; and a read that never rewrites what it could not read). **RED as a compile error**, quoted:
      `test/picture_assignment_store_test.dart:14:8: Error: Error when reading 'lib/picture_assignment.dart': No
      such file or directory`, `:15:8` the same for `lib/picture_assignment_store.dart`, `:29:22: Error: Undefined
      name 'PictureAssignmentStore'.` Green after T007: `00:00 +8: All tests passed!`.
- [x] T007 `lib/picture_assignment_store.dart`: implement green against T006 — 015's `RoleStore` shape
      (`lib/role_store.dart:132`): one `shared_preferences` key (`content_picture_assignments`), a JSON object keyed
      by the content's own id, read tolerantly, with the doc comment naming FR-010's two halves, FR-013's "a stored
      setting", and that 015's own key is untouched. **Checkpoint**: the store's file green; the suite at T001's
      count + T002's and T006's new cases.
**DONE 2026-10-14** — `lib/picture_assignment_store.dart` created in 015's `RoleStore`'s shape exactly
      (one `shared_preferences` key, a JSON object keyed by the content's own id, a tolerant read that never
      rewrites, and an entry that says nothing being dropped rather than emptied), with the one deliberate
      difference written into its doc comment: it is **not** 012's picks' store — the picks are never remembered —
      and what it remembers is the reader's decision about them, keyed by the pictures' own names (D7). Green:
      `00:00 +8: All tests passed!`; `flutter analyze` → `No issues found!`.
      **The pass's checkpoint, on the finished batch**: `flutter test --concurrency=2` → `01:00 +755: All tests
      passed!` against T001's **729** — the difference is exactly these three files' new cases (14 + 8 + 4 =
      **26**), so no shipped case moved; and `git diff --stat lib/video_pictures.dart` → 70 insertions, **no
      deletions** (the split is beside `buildPictureSchedule`, not inside it).

---

## Phase 4: User Story 1 — the reader assigns sentences to a picture, and the video shows it (P1) 🎯 MVP

**Goal**: a pass on the video dialog where each picked picture takes 0 or more continuous sentences, in order, and
the render paints each sentence's own assigned picture, in the reader's order.

**Independent Test**: assign 4/3/3 over a ten-sentence content with three pictures, render, and read the renderer's
own line: three ranges matching the runs, in order (quickstart row 6).

### Tests for US1 ⚠️ (write first, run RED)

- [x] T008 [US1] `test/reading_view_video_assignment_test.dart`: write the dialog's own seam and the pass's own
      behaviour — **quickstart.md row 6**'s widget half. The dialog gains one line beside the pick; it opens the
      pass; the page hands the pass the sentences **the render will speak** (the same list, from the same start
      point, resolved once — D6) and the pictures in their display order; the pass answers the reader's runs, the
      picture's own run is visible per picture, and `Done` returns them *(2026-10-14, in place: what `Done` returns
      is now an `AssignmentDraft` — the runs **and** the pictures' order, because a picture holding nothing has no
      run to carry its place in the walk (US2, FR-015). "The reader's runs" above means those runs, in the order the
      page showed; T015 re-cut this row's own cases for it.)*; the reader can leave without assigning and
      the render is then 012's. Run it and keep the RED output (a compile error on the base: the pass's file and the
      ARB keys do not exist yet — say so when the RED is one).
**DONE 2026-10-14** — `test/reading_view_video_assignment_test.dart` written: two groups, 10 cases. The
      pass's own widget is driven directly (the sentences it is handed, the taps, the counts, Done's answer,
      and the pop that answers nothing), and the dialog's seam is driven through the real page over 012's own
      harness — `ShortEngine`, `RecordingEncoder`, `PageFileStore`, `PagePlayer`, `PickingPictures`, `picked`,
      `redPng`/`bluePng`, `pixelOf` are **imported from `test/reading_view_video_test.dart`** rather than
      copied, because the fakes that prove the picks reach the frames are what prove the assignment does.
      **RED as a compile error**, quoted: `test/reading_view_video_assignment_test.dart:24:8: Error: Error when
      reading 'lib/picture_assignment_screen.dart': No such file or directory`, `:196:39: Error: Method not
      found: 'PictureAssignmentScreen'.`, `:221:27: Error: Undefined name 'PictureAssignmentScreen'.` (the same
      at `:232`, `:243`, `:259`, `:336`, `:429`, `:446`, `:468`). Green after T010-T012:
      `00:07 +10: All tests passed!`.
      **The pass's own look is this pass's decision**, and the artifacts left it here on purpose (research §4.4,
      the plan's Boundaries, the way 019's row 10 settled the ladder): the pictures across the top as chips each
      carrying its own count, the render's sentences down the page, a tap giving the sentence to the picture
      selected (and taking it back), `Done` answering the runs. Row 6's screenshot (T021) is where the reader
      sees it.
      **Four things this row's first run corrected, all in the harness rather than the code**: the route's own
      future is what the page's caller awaits, so a value `openPass` returned was always the pre-Done one — the
      answer is read from a field after Done now; `RecordingEncoder` records the frames it was **handed**, each
      once with the repeat it stands for, so indexing `frames` by frame number read `-2` (the video's first and
      last frames are the witnesses); a promoted local makes the second `!` unnecessary; and `chip.label` is
      non-nullable.
- [x] T009 [US1] `test/video_renderer_test.dart`: add the renderer's own group — the runs reach it, its schedule
      comes from the split function when they are in force and from `buildPictureSchedule` when they are not, and
      its `pictures=… ranges=… sentences=…` line keeps its **fields** (`lib/video_renderer.dart:286`), which is what
      the device rows read. Run it and keep the RED output.
**DONE 2026-10-14** — `test/video_renderer_test.dart` extended: the file's own `run`/`rendererFor`
      helpers gained `runs:`, and two cases joined it. **RED as a compile error**, quoted:
      `test/video_renderer_test.dart:285:7: Error: No named parameter with the name 'runs'.` with the run's own
      `00:00 +0 -1: loading … [E]`. Green after T013: `00:05 +24: All tests passed!` — **012's own 22 cases plus
      this feature's 2**.
      Both cases read the renderer's own line, captured by overriding `debugPrint` (the idiom
      `test/reading_view_follow_test.dart` established): with the reader's runs the two ranges meet at a
      sentence boundary and no frame is painted twice; with nothing assigned the same pictures split 012's own
      way, at a different boundary; and both lines end at the same frame, which is FR-008/SC-005 read off the
      renderer's own numbers. A picture the reader gave nothing prints as `-` (FR-007/D5's corrected
      mechanism), and its neighbour still reaches the seam.

### Implementation for US1

- [x] T010 [US1] `lib/l10n/app_{en,es,zh,zh_Hans}.arb` and the generated Dart: add this feature's own text to all
      four files (the pass's line and title, its "nothing assigned" label, its sentence-count plural, the remove
      label, the two refusals *and* the middle-removal and drag refusals, `Done`, and the warning's two strings —
      eleven keys, so 110 → **121** in each file — *(corrected 2026-10-14 in this pass's own tick: the list is
      **ten** keys, because `doneButton` already says "Done" and the plan's rule is to reuse the app's string
      rather than mint a second one; the count is **120**, and T030's structural row and `quickstart.md` row 14
      carry the same correction)*), re-run `flutter gen-l10n`, and confirm
      `test/l10n_keys_test.dart` green in both directions. Quote the measured per-file count: if the list of keys
      changes, the measured number is the receipt.
**DONE 2026-10-14** — the four ARBs gained this feature's text: **ten message keys each, 110 → 120**,
      `flutter gen-l10n` re-run (the four generated Dart files are in the diff) and `test/l10n_keys_test.dart`
      green in both directions. Measured per file: `app_en` **120**, `app_es` **120**, `app_zh` **120**,
      `app_zh_Hans` **120**.
      **The row's own list was one key too long, and the count it carried was corrected in this pass**: it
      listed a `Done` key, but `doneButton` already says "Done" — and the plan's own rule is to reuse the app's
      string rather than mint a second one for the same idea — so the pass uses it, the list is ten keys, and
      the total is **120**, not 121. T030's structural row and `quickstart.md` row 14 are corrected with it.
- [x] T011 [US1] `lib/picture_assignment_screen.dart`: the pass itself (A) — the pictures in their display order,
      each with its own run; the sentences in the render's own order; assigning a sentence to a picture; the run's
      own count; `Done` answering the runs. Its own file, its own widget, reached by one line in the dialog (D6).
      **Checkpoint**: `flutter test test/reading_view_video_assignment_test.dart` green; `flutter analyze` clean.
**DONE 2026-10-14** — `lib/picture_assignment_screen.dart` created: the pass (A) — the pictures in
      force as chips each carrying its own count, the render's own sentences down the page, a tap giving a
      sentence to the picture selected (or taking it back), `Done` answering the runs. Green:
      `flutter test test/reading_view_video_assignment_test.dart` → `00:07 +10: All tests passed!`;
      `flutter analyze` → `No issues found!`.
      **One presentation decision this file took, a reviewer's to overturn**: an unassigned sentence is shown
      plainly unassigned rather than as belonging to the picture before it (FR-006's fallback), because that
      fallback is an outcome of the render and not a decision of the reader's. The class's own doc comment says
      so and names research §4's open question; row 6's screenshot is where the reader can disagree.
- [x] T012 [US1] `lib/reading_view.dart`: the dialog's seam — the assignment line inside `_askVideoFormat`
      (`:1880`), the page's one resolution of the video's own sentence list (`videoSentencesFrom`, the same start
      point, mode, removals, picks and `commentsRead` the render uses), the answer gaining the runs,
      `_startRender(aspect, pictures:, runs:)` (`:1857`/`:2061`) and the `VideoRenderer` construction carrying them
      (`:2092`). **Checkpoint**: `flutter analyze` clean; `flutter test --concurrency=2` = the previous phase's
      count + this phase's cases; **every shipped case in `test/reading_view_video_test.dart` still green
      unmodified** (2121 lines; a moved case is the claim failing — report it, do not re-cut quietly).
**DONE 2026-10-14** — `lib/reading_view.dart`: the dialog's seam — the assignment line beside the pick
      (a `ListTile` whose subtitle is the count in force, disabled until a picture is chosen), `_assignSentences`
      resolving the video's own sentences **once** with the same call and the same parameters the render makes
      (`_anchor ?? 0`, the page's mode, removals, picks and `commentsRead`), the answer gaining `runs`, the store
      read when the prompt opens and written when the pass is confirmed (`_assignments.load`/`save(_anchorKey!)`,
      FR-010), `_startRender(aspect, pictures:, runs:)`, and the `VideoRenderer` construction carrying them.
      **Checkpoint**: `flutter analyze` → `No issues found! (ran in 0.8s)`; **`flutter test
      test/reading_view_video_test.dart` → `00:33 +31: All tests passed!` — 012's own 2121-line page suite, every
      case unmodified**, which is what "the dialog gained a line and nothing else moved" means here.
      **A behaviour worth knowing**: the pass shows the sentences **the render will speak**, which start at the
      page's own start point — so a reader with a Continue Read anchor set sees the pass from that sentence on,
      and assigns only what the video will cover.
- [x] T013 [US1] `lib/video_renderer.dart`: green against T009 — `runs` in as its own optional parameter, handed to
      the schedule builder in `_preparePictures` (`:448-458`) which chooses between the split function and
      `buildPictureSchedule`; no log field moves (`:286`), and no frame is painted differently when the runs are
      empty (SC-003's production half).
**DONE 2026-10-14** — `lib/video_renderer.dart`: `runs` in as an optional named parameter (012's own
      callers and tests pass none), and `_preparePictures` resolves them against **this render's** sentence list
      through `assignmentsFor`, handing `buildAssignedSchedule` the effective runs; with nothing in force the
      split is 012's own, because that function calls `buildPictureSchedule` — so the fallback is one call, not
      two branches that could drift. Green: `00:05 +24: All tests passed!`; `flutter analyze` → `No issues
      found!`.
      **The story's checkpoint, on the finished batch**: `flutter test --concurrency=2` → `01:04 +767: All tests
      passed!` against this pass's start of **755** (and T001's 729) — the difference is exactly this story's new
      cases (10 + 2 = **12**), so nothing shipped moved.

---

## Phase 5: User Story 2 — only continuous runs, only in order (P1)

**Goal**: a picture takes only sentences contiguous with its own, and no picture takes a sentence that starts before
an earlier picture's; an end sentence un-assigns, a middle one is refused; a picture holding nothing drags, one
holding sentences refuses.

**Independent Test**: drive both refusals and read the assignment in force before and after (quickstart row 7).

### Tests for US2 ⚠️ (write first, run RED)

- [x] T014 [US2] `test/picture_assignment_test.dart`: add the refusal group — each rule answers **which** rule it
      broke (`not continuous`, `not in order`, a middle removal, a picture holding sentences being dragged) and
      leaves the runs in force untouched (FR-012), with the accepted neighbours beside them (an end sentence off, the
      sentence right after a run on). Run it and keep the RED output.
      **DONE 2026-10-14** — the group is `what is refused, and why (FR-003, FR-004, FR-012, FR-016)`, six cases:
      continuity refused and accepted, the order rule refused from **both** sides (a sentence before an earlier
      picture's own, and one after a later picture's own), an end sentence taken back against a middle one refused,
      and `mayDrag` read on the resolver's own answer (a picture the tail fed refuses; a picture nothing reaches
      moves).
      **The rule reads order first, then continuity** — a sentence that breaks both is answered as *not in order*,
      the more useful reason of the two, and the choice is written in the code's own doc comment (FR-012 asks for
      the rule that was broken, not for all of them).
      **RED, taken on a tree built for it**: the pass file moved aside and the US2 block cut out of the rule module
      (both restored byte for byte afterwards — `sha256sum` checked, both `OK`), then `flutter analyze` → **38
      issues**, and `flutter test test/picture_assignment_test.dart` → `Error: Method not found: 'mayDrag'.` — the
      file does not even load, because `AssignmentRefusal`, `AssignmentDraft`, `refusedAdd`, `refusedRemove` and
      `mayDrag` are five names the old tree does not have.
      Green now: 14 → **20** cases in this file.
- [x] T015 [US2] `test/reading_view_video_assignment_test.dart`: add the pass's own group — each refusal is
      **shown** with its reason and the assignment does not move; an unassigned picture drags to another place and
      the pass shows the new order; a picture holding sentences refuses the drag with its reason; a middle sentence
      refuses removal and an end one does not. Run it and keep the RED output.
      **DONE 2026-10-14** — the group is `the pass's refusals, and the drag (US2)`, five cases: a sentence far from
      the run refused with its reason (the count unchanged, and the answer on `Done` still the run it was), the
      sentence next to the run accepted, a middle sentence refused against an end one taken back, a picture holding
      sentences refusing the hold — with its reason and the order unchanged — and a picture holding nothing dragged
      onto another chip (the hold-and-drop 012's own picker taught) so the answer comes back in the new order.
      **What the pass's answer had to become for that last case to be true**: an `AssignmentDraft` — the pictures
      **and** their runs — because a picture holding nothing has no run to carry its place in the walk (FR-015). That
      is a re-cut of the two earlier cases that read the old `List<PictureRun>` answer and of the dialog's own line
      with them; those rows' ticks above stand as the record of what ran then.
      **RED**: the same before-tree as T014's, and this file's own failure is `Undefined name
      'PictureAssignmentScreen'` — the pass is this row's subject, and it is not there.
      Green now: 11 → **16** cases in this file.

### Implementation for US2

- [x] T016 [US2] `lib/picture_assignment.dart`: green against T014 — the refusal reasons as one answer (D4), the
      continuity and order checks reading the same sentence list the resolver uses, and the drag predicate
      (`draggable`) refusing any picture that holds a sentence, assigned or fallen back to (FR-015 as amended
      2026-10-13). *(2026-10-14, in place: the predicate this row calls `draggable` is **`mayDrag`** in the tree —
      one name for one question, and the rule module needs no `Draggable`.)*
      **DONE 2026-10-14** — `AssignmentRefusal` (four reasons as a value: **which** rule was broken is the
      behaviour, and the pass turns it into the reader's own language with the key each case names), `refusedAdd`,
      `refusedRemove`, `mayDrag`, `AssignmentDraft`.
      **The two sources the rules read, and why they differ**: the refusals read the reader's own runs — what the
      pass edits and what it shows — while `mayDrag` reads the resolver's own answer, because FR-015 counts the
      sentences the **tail fallback** fed a picture, and a picture that holds nothing only looks free.
      **The one clause of the quickstart's row 5 this row did not own**: "moving one leaves every other picture's
      ranges identical" — a claim about the **schedule**, so it went to the schedule seam's group in
      `test/video_pictures_test.dart` (row 3's file): a picture holding nothing (a and c covering every sentence
      between them) moved to the front, the walk in the new order, the moved picture still painting nothing, and the
      other two's ranges compared **by name**. 26 → 27 cases there.
- [x] T017 [US2] `lib/picture_assignment_screen.dart`: green against T015 — the refusal shown where the tap
      happened, the drag started only from a picture the predicate allows, the un-assign at either end of a run, and
      nothing changed in the runs when a refusal is shown (FR-012). **Checkpoint**: `flutter analyze` clean;
      `flutter test --concurrency=2` = the previous phase's count + this phase's cases.
      **DONE 2026-10-14** — a refusal is shown as Material's own `SnackBar`, at the tap's own place and readable off
      the device screen (which is what row 7 walks); and the two gestures are split where they have to be: **every**
      chip takes a drop, while only a chip `mayDrag` allows **lifts**. That split is the whole reason a free picture
      can be dragged to where a picture with sentences sits — the first cut put the drop target on the movable chips
      alone and the row's own test caught it (the drag went nowhere and the order stood).
      **Checkpoint**: `flutter analyze` → `No issues found! (ran in 0.9s)`; `flutter test --concurrency=2` →
      `01:04 +780: All tests passed!` (pass 3's 768 + 6 + 5 + 1 = 780 — the previous phase's count plus this phase's
      cases, as the row asks).

---

## Phase 6: User Story 5 — a stale assignment is caught before the render (P2)

**Goal**: when the content's sentences have changed under an assignment, the app says so **before** the render
starts, names what no longer fits, and the telling is **tappable** — it opens the pass on the offending picture.

**Independent Test**: assign, edit the content so a run no longer fits, start a render: the warning comes before the
render's own line, names the sentences, and one tap reaches that picture (quickstart row 11).

### Tests for US5 ⚠️ (write first, run RED)

- [x] T018 [US5] `test/reading_view_video_assignment_test.dart`: add the warning's group — with a stale run, the
      warning appears **before** the render's own line, names the picture and its sentences, its tap opens the pass
      with that picture in view, and starting the render anyway drops the stale runs while the rest stand (FR-014).
      Its unit half (the stale answer itself) is T002's group, asserted here through the page. Run it and keep the
      RED output.
      **DONE 2026-10-14** — the group is `the stale warning, before the render (US5)`, two cases: a run that no
      longer fits is warned about **before** the render's own line (the app's own line is asserted absent while the
      warning is up), the warning names it, and the line that names it is the gesture that opens the pass on that
      picture; and a render started anyway uses the runs that still fit, over the content in force.
      **RED, and it is a behavioural one**: written first and run against the tree with no warning in it, both cases
      failed on `Found 0 widgets with text "2 assigned runs no longer fit this text"` — the fixture reached the
      screen and the warning was simply not there (no compile error anywhere: everything this row names already
      existed).
      **What the fixture had to be, and the three things it taught**:
        - a **user** content, not a pre-set: FR-014's story is a content *edited under* an assignment, and editing a
          pre-set makes new content with a new id (016's own rule), so the assignment would not follow it. The
          library is built with an empty catalog and `saveNew`, then `update`d between the two visits (016's own
          path).
        - a **new page** for the second visit: `pumpWidget` reuses the element tree, so the page kept the old text
          and every stored run matched it — which is exactly what the first run of this case reported (`stale=[]`).
          The two visits are separated by `pumpWidget(const SizedBox())`.
        - every store call runs inside `tester.runAsync`: real file work started on the test's own clock never calls
          back, and the case **hangs** instead of failing (012's own note; this pass paid for it once).
      Green now: 16 → **18** cases in this file.

### Implementation for US5

- [x] T019 [US5] `lib/reading_view.dart`: green against T018 — the stale runs read from the same resolver answer
      the render uses (D4), the warning shown before the render begins with its own strings, its tap opening the
      pass on the offending picture, and the render handed the **effective** runs so a dropped run cannot paint a
      frame nobody chose. **Checkpoint**: `flutter analyze` clean; `flutter test --concurrency=2` = the previous
      phase's count + this phase's cases.
      **DONE 2026-10-14** — `lib/reading_view.dart`: `_videoSentences()` (the one resolution both the pass and the
      warning read), `_warnStale` (an `AlertDialog`: the count in its title, one line per stale run naming the
      picture and how many sentences that run held, and two answers — the pass's own word to go and fix it, and
      Start to render anyway), the Start handler that runs the warning before anything is rendered, and `inView`
      through `_assignSentences` into the pass so the offending picture is the one the page opens on.
      **The trap this row walked into, and the rule it leaves behind**: `AssignmentAnswer.effective` is **not** what
      the page may hand back. It carries FR-006's **fallback** — the sentences no run names, which the render hands
      to pictures by its own rule — and the first cut passed exactly that to the pass, which then showed the reader
      sentences they had never assigned (the test caught it: the offending picture's chip read "2 sentences" where
      "No sentences assigned" is the truth) and would have written the fallback into the record as the reader's
      decision (FR-011). The page's own claim is `runsThatFit(answer, runs)`: the reader's runs minus the resolver's
      stale ones. The fallback stays where it belongs, in the render. Written in the function's own doc comment and
      in `data-model.md` §3 of this date.
      **What the warning can name, and what it cannot**: a stale run stores character spans (data-model §1) and the
      text they pointed at went with the edit, so **which** sentences it held cannot be recovered — the warning names
      the picture and how many sentences that run held. That is FR-014's own wording read strictly ("naming what no
      longer fits"); it is narrower than SC-008's "naming the sentences involved", both are annotated in place of
      this date, and the reading is put to the reader rather than settled quietly.
      **The ARB detail's wording was minted for another shape and is corrected in place**: the three translations
      read `{sentences}` as a sentence *number* (`第 {sentences} 句`, `oraciones {sentences}`), and this row is the
      first thing ever to pass it a **count**; es and both Chinese files are reworded to carry a count
      (`{picture}: {sentences} oraciones`, `{picture}：{sentences} 句`) and regenerated with `flutter gen-l10n` —
      the ten keys' own template is untouched.
      **What a dropped run's frames can and cannot prove, said plainly so row 11 is not over-claimed**: FR-006's
      fallback re-fills the sentences a dropped run held whenever a free picture follows it, so the render's own
      ranges are not necessarily different from the reader's own. The drop's proof is the resolver's own answer
      (asserted in the case) and what the page shows — the offending picture reads "No sentences assigned" while the
      run is still stored — not a frame-level difference. Store-side, the stale run stays stored until the reader's
      own Done replaces it, so the warning repeats on the next visit, which is what the spec's clarifications of
      2026-10-13 asked for.
      **Checkpoint**: `flutter analyze` → `No issues found! (ran in 0.8s)`; `flutter test --concurrency=2` →
      `01:17 +782: All tests passed!` (pass 4's 780 + this phase's 2).

---

## Phase 7: The device walk

**Purpose**: the rows a unit test cannot see — the pass on a phone, the frames the render actually paints, and the
two answers only the device gives (the schedule's own `ranges=…` line, and an assignment that outlives the prompt).
Every row appends its evidence to `specs/020-sentence-pictures/breakpoint.md` and is dispatched by the driver
**T020** writes, one row per run, the task's number, the quickstart's row number and the driver's `PARTS` key being
one value.

- [x] T020 `specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` and its fixture beside it: write the driver,
      importing **012's** `klhu_walk_video` for the pick (it is the tree's only module that pushes pictures to the
      device and drives the platform's own file dialog: `make_pictures`, `push_pictures`, `choose_pictures`,
      `picture_at`, plus `library_state`'s per-file hashes for row 16 and `probe`/`duration_s` for row 12) and
      **016's** `klhu_walk_step` (through 019's chain) for the read's mechanics and the `RESULT: PASS|FAIL`
      dispatch; add the **new parser** for the renderer's own `klhu render pictures=… ranges=… sentences=…` line,
      which no driver in the tree reads today; and a fixture holding a ten-sentence content with three pictures'
      worth of the row's own images. `main` names the rows it does not implement as owed rather than dispatching
      into a stub (014's convention).
      **DONE 2026-10-14, row 6 implemented** — the file is `klhu_walk_assignment.py`: 016's mechanics through
      012's module (which carries them), 012's own pick (`make_pictures`/`push_pictures`/`choose_pictures`/`pull`)
      and `preflight`, this feature's ten-sentence fixture and three solid-colour pictures (written with the
      standard library — the box's own `/usr/bin/python3` has no PIL and the driver must run on it), the seeder for
      the library (`run-as`, 012's `s2_seed` pattern), the pass's own gestures (a chip, then the next N sentence
      rows, then `Done`), and the **new parser** — `RENDER_PLAN_RE`, the only reader of
      `klhu render pictures=… ranges=… sentences=…` in the tree, with `-` read as "no frame reaches this picture"
      (D5). `main`'s owed list names 7, 8, 9, 10, 11, 12, 13, 16 rather than dispatching into stubs.
      **Two driver bugs the row's own runs paid for, both fixed and both written down in `breakpoint.md`**: a
      finished render's file is in the app's private storage (it comes back through `run-as` — an `adb pull` reads
      nothing, which the first run's frame checks read as `None`), and `uiautomator dump` refuses to write while a
      window animates, after which 012's `dump` pulls the **previous** XML — a stale screen read as the app's own
      answer (the third run read the prompt as `No sentences assigned` right after an assignment the render itself
      proves was in force). `fresh_dump`/`dump_until` are this driver's answer: delete the device's XML first, and
      poll the line that must change to a deadline.
- [x] T021 [US1] Walk `quickstart.md` row 6 into `specs/020-sentence-pictures/breakpoint.md`: the assignment line,
      the pass and the render's own ranges — seed the ten-sentence content, choose three pictures, assign 4/3/3
      through the pass, render, and read the app's own `klhu render pictures=3 ranges=…` line against the reader's
      runs, with a frame sampled inside each range to show each sentence's own picture. Leave one still per pass
      state (`/tmp/020_row6_*.png`) for the reader, as 019's row 10 did. Proves FR-001, FR-002, FR-006, SC-001.
      **WALKED 2026-10-14 15:12 PDT — `13/13 checks passed`, exit 0.** The record is
      `specs/020-sentence-pictures/breakpoint.md`'s row 6 entry, with the app's own line verbatim
      (`klhu render pictures=3 ranges=0..197,198..340,341..529 sentences=10`), the pass's own chips before Start
      (`w020_white.png 4 sentences`, `w020_black.png 3 sentences`, `w020_red.png 3 sentences`), and three frames
      sampled inside the three ranges, each reading a pixel **outside the text column**: `(255,255,255)` at frame
      20 (white), `(0,0,0)` at 218 (black), `(219,29,30)` at 361 (red). The ranges meet at sentence boundaries
      (`197+1=198`, `340+1=341`) and the first opens the video, which is FR-002/FR-006 read off the app's own
      schedule. Stills left for the reader: `/tmp/020_row6_pass_open.png`, `/tmp/020_row6_assigned.png`,
      `/tmp/020_row6_review.png`; the file itself at `/tmp/klhu_out/row6.mp4`.
- [x] T022 [US2] Walk `quickstart.md` row 7 into `specs/020-sentence-pictures/breakpoint.md`: the two refusals — a
      sentence not adjacent to its picture's run, and a later picture given a sentence that starts before an earlier
      picture's last one: each is refused with its own reason on screen and the assignment in force is **unchanged**,
      compared against the render's own line taken before and after. Proves FR-003, FR-004, FR-012, SC-002.
      **WALKED 2026-10-14 16:14 PDT — `15/15 checks passed`, exit 0.** Record in `breakpoint.md`'s row 7 entry. The
      reader's own assignment (white takes the first two sentences) renders as
      `klhu render pictures=3 ranges=0..98,99..302,303..551 sentences=10`; the fifth sentence is then refused with
      `Only the sentences next to the ones this picture already has can be added.` and the first sentence, on black,
      with `That sentence comes before sentences an earlier picture already has.` — each the **only** rule named on
      screen (FR-012). Nothing moved under either: the three chips read `2 sentences` / `No sentences assigned` /
      `No sentences assigned` before and after, and the page still paints the reader's own two as held. The render
      started again printed **the same line** (the row's own comparison), which is the assignment in force read off
      the render itself. Stills: `/tmp/020_row7_assigned.png`, `_refused_continuous.png`, `_refused_order.png`,
      `_review.png`.
      **And the row taught the walk two things about itself** (both fixed in the driver, both in `breakpoint.md`):
      rows are not isolated — row 6's stored assignment was still in force for the same content id, and row 7's
      first run read `8 sentences` because its own two taps took sentences *away* from row 6's four (so
      `seed_content` clears the app's settings first, and `assign` refuses a pass that does not open empty); and a
      review left up by a render **arrives with a transition**, so a tap at coordinates read while it moves misses
      (`dismiss_review` waits for the Discard row to stop moving).
- [x] T023 [US2] Walk `quickstart.md` row 8 into `specs/020-sentence-pictures/breakpoint.md`: un-assigning — an end
      sentence of a run is removed and the run stays continuous; a middle one is refused with that reason; and once
      the ends are gone the picture holds nothing and becomes draggable. Proves FR-016, SC-010.
      **WALKED 2026-10-14 16:22 PDT — `14/14 checks passed`, exit 0.** Record in `breakpoint.md`'s row 8 entry. The
      reader's own three sentences on white (the pass re-opened on them: `3 sentences` / `No sentences assigned` /
      `No sentences assigned`), then: the hold on a picture holding sentences is refused with `This picture holds
      sentences; un-assign them before moving it.` and nothing moved; the middle sentence is refused with
      `Only the first or last sentence of a picture can be removed.` and the run is untouched (all three still
      painted as white's, the chip still `3 sentences`); then the ends go one at a time — `2 sentences` →
      `1 sentence` → `No sentences assigned` — with the held set read off the page's own rows at each step; and the
      freed picture's hold shows **no** refusal at all, so it is free to move (the move itself is row 9's own
      evidence). Stills: `/tmp/020_row8_three.png`, `_refused_holds.png`, `_refused_middle.png`, `_freed.png`.
      **What the row taught the walk** (both fixed in the driver): `assign` confirms the pass, which **closes** it —
      so the row re-opens the pass for its own edits (`hold` on the prompt read as nothing found, first run); and
      `hold`/`tap_chip`/`tap_row` now record a check when they cannot find their target, so a missing label can
      never again shorten a row silently.
- [x] T024 [US2] Walk `quickstart.md` row 9 into `specs/020-sentence-pictures/breakpoint.md`: the drag — a picture
      with nothing assigned is dragged to the front, and the render's `pictures=… ranges=…` line shows the new order
      with **no other range moved**; a picture holding sentences refuses the drag and the order stands. Proves
      FR-015, SC-009.
      **WALKED 2026-10-14 16:57 PDT — `14/14 checks passed`, exit 0.** Record in `breakpoint.md`'s row 9 entry. The
      reader's own assignment (white 1-3, red 4-6) renders as
      `klhu render pictures=3 ranges=0..150,-,151..551 sentences=10` — the picture between the two runs is the `-`
      of D5; holding a picture that holds sentences says `This picture holds sentences; un-assign them before moving
      it.` (read while the finger is down) and the order stands; the free picture is then dragged to the front and
      the render's own line becomes `ranges=-,0..150,151..551 sentences=10` — **the same three ranges, in the same
      order, with the `-` one place along**: SC-009 exactly, read off the app's own schedule. Stills:
      `/tmp/020_row9_assigned.png`, `_refused.png`, `_moved.png`, `_review.png`.
      **The gesture, and what it cost the walk** (in the driver and in `breakpoint.md`): `input draganddrop` does
      **not** make a Flutter long-press drag on this device (probed: the order stood, no refusal appeared); the
      driver injects it by hand — `motionevent DOWN`, a real 1.6s hold, four MOVEs, `UP` — and reads a refusal
      **while the finger is down**, because a SnackBar's four seconds are about as long as the gesture itself
      (row 9's second run lost its refusal check to exactly that).
- [x] T025 [US3] Walk `quickstart.md` row 10 into `specs/020-sentence-pictures/breakpoint.md`: the skip and the
      tail's fallback — the middle picture left with nothing paints no frame and the render's own line prints its
      range as `-`; the tail left unassigned with a picture after it takes that picture, split the way 012 splits.
      Proves FR-006, FR-007, SC-004.
      **WALKED 2026-10-14 16:5x PDT — `14/14 checks passed`, exit 0.** Record in `breakpoint.md`'s row 10 entry. With
      white on sentences 1-3 and red on 7-9 (the gap in between named by no run), the renderer's own line is
      `klhu render pictures=3 ranges=0..302,-,303..551 sentences=10`: the middle picture is the `-` of D5, and the
      unassigned sentences kept the picture **before** them (white's range ends at frame 302, the frame before
      sentence 7's own start at 303), with red holding to the video's last frame (551 of 552). Then red's run was
      taken back through the pass: `ranges=0..150,151..351,352..551` — white's own run to the frame before sentence
      4's start (151), and the seven unassigned sentences split 4 + 3 between the two pictures after it, black
      ending exactly at the frame before sentence 8's start (352) — 012's own even split. Sentence boundaries were
      read from the renderer's slot lines through 012's own parser. Stills: `/tmp/020_row10_skip.png`,
      `/tmp/020_row10_tail.png`.
      **And it taught the walk one more thing**: a picture left empty is skipped only **between** two runs — one
      after the last run is fed by the fallback and drawn (row 9's first run assigned the last picture nothing and
      the render painted it), so a row that needs a gap says which sentences it wants (`assign_indices`).
- [x] T026 [US5] Walk `quickstart.md` row 11 into `specs/020-sentence-pictures/breakpoint.md`: the stale warning
      before the render — assign, edit the content so a run no longer fits, start a render: the warning is in the
      log **before** the render's own line, it names the sentences involved, and one tap lands on the pass with that
      picture in view. Proves FR-014, SC-008.
      **WALKED 2026-10-14 17:06 PDT — `12/12 checks passed`, exit 0.** Record in `breakpoint.md`'s row 11 entry. The
      reader's assignment (the first picture takes sentences 1-3), then the content rewritten under it (its first
      sentence replaced, written to the app's own file and the app force-stopped), then the same three files picked
      again and Start: the warning is on screen in the app's own words — `1 assigned run no longer fits this text` /
      `w020_white.png: sentences 3` — and the app's own schedule line is **not** in the log while it is up (SC-008's
      order, read on the device). The line that names the picture is the gesture: tapping it opens the pass on that
      picture with the stale run not in force (all three chips empty — `runsThatFit`), and the reader's next tap
      lands on **that** picture (`1 sentence` on it, the others still empty), which is "in view" read off the app
      rather than off a chip's selection the dump cannot show. Stills: `/tmp/020_row11_warning.png`, `_pass.png`,
      `_fixed.png`.
      **And it taught the walk**: after the content is rewritten the page carries the **new** text, so a tap must be
      read from the text in force (`sentences(text)`) — this row's first run tapped the seeded text's first sentence
      and found nothing.
- [x] T027 [US4] Walk `quickstart.md` row 12 into `specs/020-sentence-pictures/breakpoint.md`: no assignment is
      012's video — with pictures chosen and nothing assigned, render what 012's own row 49 renders and compare with
      the figures that row carries (012's row **31**: **818 frames**, ffprobe **27.39 s** for the same pre-set;
      row **49**: **eight ranges for eight sentences, one per sentence, the ninth picture in no range**). Proves
      FR-009, SC-003.
      **WALKED 2026-10-14 17:10 PDT — `10/10 checks passed`, exit 0.** Record in `breakpoint.md`'s row 12 entry.
      This row uses **012's own fixture** (the pre-set and its nine pictures through 012's own pick), because what it
      proves is that 020 did not move 012's render: with nothing assigned the renderer's own line is
      `klhu render pictures=9 ranges=0..76,77..146,147..237,238..347,348..428,429..494,495..609,610..742,-
      sentences=8` — nine pictures, eight ranges, one per sentence, the ninth in no range — and the file is **743
      frames / 24.894 s**, against 012's own row 49 re-walked on this tree the same day (T032: **743 frames /
      24766 ms**). **012's row 31's own 818 frames / 27.39 s do not reproduce on this emulator at all** — 012's own
      driver renders 743 too — so the difference is the synthesis' own durations (the voice's speed is the device's)
      and this row compares against row 49 as it renders today, naming the deviation instead of inheriting a stale
      number. Stills: `/tmp/020_row12_prompt.png`, `_review.png`; the file at `/tmp/klhu_out/row12.mp4`.
- [x] T028 Walk `quickstart.md` row 13 into `specs/020-sentence-pictures/breakpoint.md`: the audio does not move —
      the same content with and without an assignment: the same utterances, in the same order, and the same total
      duration in the render's own report. Proves FR-008, SC-005.
      **WALKED 2026-10-15 08:22-08:24 PDT — `9/9 checks passed`; the full receipt is in `breakpoint.md`'s Row 13
      section.** Two things this row's own runs settled, recorded there rather than smoothed: (1) the render path
      logs **no** `klhu speak` line — a render writes each sentence to a file (`synthesizeToFile`), so the row's
      utterances are read off the renderer's own slot lines' `span=` (this row's own wording named the speak lines,
      and the row prints what the log holds, which is none); (2) 012's even split of this fixture **is 4 / 3 / 3**,
      exactly the assignment its first run made, and the two schedule lines came out identical (check 4 red, `8/9`)
      — the row now assigns **2 / 4 / 4**, so the pictures really move and the audio is compared under a change.
      The audio's own evidence: `sentences=10` and the same ten spans both times, and the same
      `18400ms … frames=552` in the app's own report.
- [x] T029 Walk `quickstart.md` row 16 into `specs/020-sentence-pictures/breakpoint.md`: the assignment outlives the
      prompt — assign, render, leave the screen and relaunch, pick **the same files** again: the pass shows those
      runs back in force on the pictures carrying those names; then change one run, render again, and read both
      files: the second render's ranges differ exactly where the assignment differs and the **first file's own hash
      is unchanged** (012's `library_state`). Proves FR-010, FR-013, SC-006, SC-007.
      **WALKED 2026-10-15 08:25-08:28 PDT — `24/24 checks passed`; the full receipt is in `breakpoint.md`'s Row 16
      section.** The row keeps the first render (012's own `Save`), so "the first file" is a real file in the
      phone's album: `walk 020 ten sentences.mp4`, `sha256=2a81e007755fbf64…`, **unchanged** after the second
      render, with the app's own library 6 files → 6 files. The relaunch is `am force-stop` + start, not
      `hard_restart` (which is `pm clear` and would wipe the store this row is about). The move is one sentence
      (white's fourth → black), which leaves no unassigned stretch, so the difference is the assignment's own and
      not FR-006's fallback: `0..206,207..351,352..551` → `0..150,151..351,352..551`, red's two numbers unmoved.

**Walk checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`, and no row cites a driver
command that does not implement it (extend T020's dispatch in the same pass, or record the row as hand-run).

---

## Phase 8: Polish & cross-cutting concerns

- [x] T030 [US4] Run `quickstart.md` row 14's structural checks into `specs/020-sentence-pictures/breakpoint.md`:
      `flutter analyze` clean; the suite count against T001's; the four ARBs each at the count **T010** states (110
      → **120**, corrected 2026-10-14 with T010's own list — `doneButton` is reused, so the feature adds ten
      keys), `flutter gen-l10n` reproducing the committed Dart, `test/l10n_keys_test.dart` green; and
      `git diff lib/video_pictures.dart` showing the split function **beside** `buildPictureSchedule` with **no line
      of its own body changed**. Proves FR-009's second half, SC-003, research D3.
      **RUN 2026-10-15 08:40-08:45 PDT — every line of it is quoted verbatim in `breakpoint.md`'s T030 section.**
      `flutter analyze` → `No issues found! (ran in 1.2s)`; `flutter test --concurrency=2` → `01:17 +782`; the four
      ARBs at **120** each; `flutter gen-l10n` reproduces the tree's own Dart (the aggregate md5 of
      `lib/l10n/*.dart` is `98425bbdb8a43bd120c4e62711e002dc` before and after); `test/l10n_keys_test.dart` green
      (3 cases); and `git diff --stat lib/video_pictures.dart` → **70 insertions, 0 deletions** across the whole
      file — `buildAssignedSchedule` is appended after `buildPictureSchedule`'s closing brace and not one line of
      012's body moved. The suite's **53** cases are decomposed by file in `## Status`.
- [x] T031 [P] Correct the standing figures the message-key total moves, dated, in `specs/019-head-tags/quickstart.md`
      and `specs/019-head-tags/tasks.md`: 019's structural row expects 110 keys and its Status baseline quotes 110 —
      this pass has already written those two dated notes beside their lines (2026-10-14), so this row's work is to
      **verify** them against T010's measured count, correct the new number if the ARB list changed, and record the
      check in `specs/020-sentence-pictures/breakpoint.md`. 019's and 017's **dated measurements** are not edited
      otherwise: they were true of their own trees.
      **RUN 2026-10-15 08:45 PDT — the receipt is `breakpoint.md`'s T031 section.** The ARB list had **not** moved:
      `app_en.arb` went 110 → 120 with **all 110 of 019's keys still present** (none dropped, none renamed away) and
      exactly **ten** added, all of them this feature's own (`assignmentNothingAssigned`, `assignmentOpenButton`,
      `assignmentRefusedHoldsSentences`, `assignmentRefusedMiddle`, `assignmentRefusedNotContinuous`,
      `assignmentRefusedNotInOrder`, `assignmentRemoveSentence`, `assignmentSentenceCount`, `assignmentStaleDetail`,
      `assignmentStaleWarning`), and the three translations carry the template's own set item for item. Both of
      019's dated notes now name the measured figure — *“Measured 2026-10-15 on 020's tree: `120` each”* — so that
      row reads on its own; 019's own measurements are otherwise untouched, being true of its own tree.
- [x] T032 Re-run `specs/012-reading-video/scripts/klhu_walk_video.py` row 49 into
      `specs/020-sentence-pictures/breakpoint.md`: this feature adds a control to the dialog that row drives, so the
      row is re-walked on this tree and its own counts recorded (`40/40`-or-better, or the deviation named): the nine
      pictures, the eight ranges, `kw08` in no range, the ink over the white and the black picture. A row that moves
      **WALKED 2026-10-14 17:1x PDT — `40/41 checks passed`; the full receipt is in `breakpoint.md`'s T032 section.**
      **One check moved, and it is this feature's own doing**: 012's `49: a choice one over the count is said nothing
      about` asserts that **no** label on the prompt mentions the video's sentences, and 020's assignment line
      (`Assign sentences` / `N sentences` / `No sentences assigned`) does. The count itself is still said nothing
      about — the assertion's own filter tripped — so 012's artifacts are left as written and the pointer is one
      bullet in 012's `tasks.md` `## Superseded by later specs` (2026-10-14), exactly as this row instructs. **Its
      figures settle row 12**: 012's row 49 renders **743 frames / 24766 ms** today, the same frame count 020's
      no-assignment render reaches, where 012's row 31's record of 818 frames / 27.39 s no longer reproduces for
      either row.
      here is this feature having moved the dialog's own layout, and the handback says so instead of re-cutting 012's
      record.
- [x] T033 Run both list checkers and quote them verbatim in `specs/020-sentence-pictures/tasks.md`'s Status:
      `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py
      specs/020-sentence-pictures` and `…/task_id_audit.py specs/020-sentence-pictures`, both after this file's last
      edit. A red checker here is fixed in this file, not explained away.
- [x] T034 Re-take the suite count on the finished tree into `specs/020-sentence-pictures/tasks.md`:
      `flutter analyze` and `flutter test --concurrency=2`, read against T001's **729** with the difference
      decomposed by file (three new test files, two extended), then close the list — correct any receipt in this
      file or in the four plan artifacts that has gone false, and hand back with the rows still needing a walk named
      one by one.
      **CLOSED 2026-10-15 08:45 PDT.** `flutter analyze` → `No issues found! (ran in 1.2s)`;
      `flutter test --concurrency=2` → **`01:17 +782: All tests passed!`**, read against T001's **729** and
      decomposed in `## Status`: three new test files (20 + 8 + 18 = 46) and seven cases across the two extended
      ones (22 → 27, 22 → 24) — 729 + 46 + 7 = 782 exactly. The receipts this pass had left stale are corrected
      rather than explained away: T033's two quoted checker outputs now read `39 tasks (39 done)`, the Status
      block carries the closing figures, and **no row needs a walk** — all nine device rows are walked, each with
      its own PASS and its evidence in `breakpoint.md`.

---

## Phase 9: The reader's owner amendment (appended 2026-10-14; the numbering is append-only)

**Purpose**: the reader's own rule of that date — a video is the **whole content**, whatever the page is showing
(`plan.md`'s Amendment 2, FR-017, SC-011, User Story 6). It is not one of this feature's planned stories: it arrived
at this file's own gate, and its rows are appended after the last phase for the same reason the quickstart's are —
the walk driver dispatches on the row number.

- [x] T035 [US6] `test/reading_view_video_assignment_test.dart`: write quickstart row 17 — tap the content's last
      sentence on the page (the reader's own gesture, the page's position in force and painted), open the dialog,
      render, and read the renderer's own line: `sentences=3` and slot 0's `span=0..8`, whatever the page is on.
      **DONE 2026-10-14** — the case is in the file's dialog group, with the two helpers it needed
      (`tapSentenceInContent`, and `hasYellow` — copied from 010's own page test rather than imported, because it is
      the assertion that the page really is in the state the case is about).
      **Its "before" is a probe, not a guess**: taken *before* the code changed and deleted after its run, it read
      `klhu render pictures=0 ranges= sentences=1` and `klhu render slot=0/2 … span=22..31` for the same fixture
      with the last sentence tapped — the video held one sentence, which is what FR-017 forbids. The case would have
      failed on that tree on both of its assertions. Green now: `flutter test
      test/reading_view_video_assignment_test.dart` → `00:08 +11: All tests passed!` (10 + this one).
- [x] T036 [US6] `lib/reading_view.dart`: the one-line rule — `_startRender`'s start is the **content's first
      sentence** (a `const from = 0`, with the comment naming 012's superseded half), and `_assignSentences` resolves
      the pass's own sentence list from the same place, so a highlight can no longer hide sentences from the
      assignment page.
      **DONE 2026-10-14** — both call sites, and the pass's own doc comment with them. `from` had exactly one use in
      the method (`position: from`), so nothing else in the render path moved. **Checkpoint**: `flutter analyze` →
      `No issues found! (ran in 0.8s)`; the page's own suite (`test/reading_view_video_test.dart`) green unmodified
      with it — the highlight still decides what a **read** does, which is 010/011/016's half and is untouched.
- [x] T037 [US6] `lib/video_renderer.dart`: the `position` parameter's own doc says what it now means to the app —
      the video's first sentence, with the page always passing the content's first — and why the parameter stays
      (the timeline still starts where it is told, and 012's four start-point cases stay true).
      **DONE 2026-10-14** — the doc reflowed around its own two paragraphs; no behaviour in this file changed, and
      its own suite is green unmodified (`test/video_renderer_test.dart`, 24 cases).
      **The alternative this row rejected and the reason**: make the *renderer* ignore its `position` so no caller
      can start a video mid-text. Rejected — it would leave a dead parameter and re-cut 012's cases for no
      reader-visible gain, where the page is the only production caller and the rule reads better at the place the
      reader's own action lives.
- [x] T038 [P] [US6] `specs/012-reading-video/tasks.md`: the pointer in `## Superseded by later specs`, naming
      FR-017, SC-011 and the sentence of 012's spec the amendment falsifies (its FR-004 first half), with 012's own
      artifacts left as written. This row also carries this feature's own artifact sweep, because it is the same
      pass: `spec.md` (User Story 6, FR-017, SC-011, the Clarifications entry, the decision row), `plan.md`
      (Amendment 2, the counts, the tree), `quickstart.md` (rows 17 and 18) and the checklist's Amendment 6.
      **DONE 2026-10-14** — the pointer is in 012's file and every artifact above is dated in place.
      **What was checked before claiming no walk needs a re-cut**: `grep -rn 'sentences=\|slot=0/'` over 012's
      `breakpoint.md` → **no hits** (012's own record has neither line), and over every other spec's `breakpoint.md`
      → every render shows `span=0..`, i.e. they were all started with nothing highlighted, so no received figure
      depends on the superseded behaviour. 012's walk driver needed nothing.
- [x] T039 [US6] Walk `quickstart.md` row 18 into `specs/020-sentence-pictures/breakpoint.md`: with a sentence
      highlighted on the device, render and read the app's own `klhu render … sentences=` and `klhu render slot=0/…
      span=…` lines — the content's own count and its first sentence — and render the same content again with
      nothing highlighted to show the two lines identical.
      **WALKED 2026-10-15 08:31-08:34 PDT — `8/8 checks passed`; the full receipt is in `breakpoint.md`'s Row 18
      section.** The premise is app-written, not inferred: two presses of ▶ Read leave the page's own position on
      the content's **second** sentence, and the app's own `klhu read range` lines name both
      (`0..17`, then `18..37`). Every sentence of the content is still spoken (`sentences=10`, the same ten spans as
      row 13's), slot 0 opens at **frame 0** with `span=0..17`, and the two renders' own lines are identical —
      the row compares the app's **payload** (after the device's own logcat prefix), which is 012's and row 7's own
      way of comparing two of its lines across renders. Its first run compared the whole lines and read the
      device's timestamp as a difference (`6/7`); the app's own text was identical both times.

## Dependencies & ordering

- **T001** first, before any edit: every later tick is read against its numbers.
- **Phase 2 (T002-T005)** blocks every story: `assignmentsFor` (T003) is what the pass, the warning and the render
  all read, and the split (T005) is what turns its answer into frames. **T005 depends on T003** (the split reads the
  effective runs).
- **Phase 3 (T006-T007)** is independent of Phase 2 (a store over strings and spans) and must land before Phase 4
  (the pass reads it back on open).
- **US1 (Phase 4)** blocks the rest: the pass is the surface US2's refusals and US5's warning are shown on. **T010
  (the keys) must land before T011/T012** (the pass and the warning read them), and **T009's renderer group is green
  only after T013**.
- **US2 (Phase 5)** depends on US1's pass; **US5 (Phase 6)** depends on US1's dialog seam (T012) and on T002's stale
  answer.
- **Phase 7** depends on its stories' code: rows 6 on US1, rows 7-9 on US2, row 11 on US5, row 10 on Phase 2's
  resolver, row 12 on the untouched 012 path, row 16 on Phase 3's store. **T020** (the driver and its fixture) is
  written before its rows and depends on nothing else — but it is the row that imports 012's pick machinery, so it
  is also where a device-side pick problem shows up first.
- **Phase 8** last: T030 and T032 need the finished tree, T031 the measured key count, T033 the finished file, T034
  everything.

## Parallel opportunities

- **T002, T004 and T006 are three different test files** and can be written in one sitting; T003, T005 and T007 are
  their implementations, each depending only on its own test row.
- **T031 is disjoint from every `lib/` and `test/` file** (019's two records alone) and can run beside any of
  Phase 4-6's rows.
- **Nothing in Phase 7 is parallel**: every row installs, drives and reads the same device, and they all append to
  one `breakpoint.md`. Two rows run one after the other even when their subjects are independent.
- **T008 and T009 are two files** (`test/reading_view_video_assignment_test.dart` vs `test/video_renderer_test.dart`)
  and can be written before either's code; T014 and T015 then extend the same two files, so they stay after them.

## Implementation strategy

The MVP is **Phases 2-4**: the rule, the split, the store and the pass, demonstrable on the device with quickstart
row 6 alone — which is the reader's own ask (assign sentences to pictures, in order, continuous). US2 and US5 are
the two rules the reader's own words carry beyond it (the refusals, and the warning that leads to the fix), and
US3/US4 are the two ends of the feature's scope: a picture that carries nothing, and a render with no assignment.
Each story is independently demonstrable: US1 by row 6's ranges and frames, US2 by rows 7-9's lines, US3 by row 10's
`-`, US4 by row 12's figures, US5 by row 11's ordering of the warning against the render's own line.

## Notes

- The device rows are walked by hand first and scripted afterwards; the driver's own `PARTS` table is the authority
  on which rows are scripted, so a row added later extends it in the same pass.
- **US3 and US4 have no phase of their own, and that is a decision rather than an omission**: both stories' rules are
  answers the one resolver and the one split already give (quickstart rows 1-3, T002-T005), so a phase there would be
  a heading with no code in it. Their own receipts are the device rows T025 and T027 and the structural row T030.
- The pass's own look (the inside of (A)) is settled in the implement pass with a screenshot for the reader, the way
  019's row 10 settled the ladder's look; the behaviour is what the rows check.
- No `contracts/` directory for this feature: the interfaces it changes are in-process Dart types the app already
  owns, and the store's shape is `data-model.md` §2's.
- `specs/020-sentence-pictures/breakpoint.md` does not exist yet: T021 creates it, with its own environment table
  (build, device, package, the probe that produced each row's evidence).

## The stage's notes

- Both list checkers were run on this file after its last edit, and their own output is quoted here verbatim:
  `check_tasks_format.py specs/020-sentence-pictures` → **`34 tasks (0 done), 4 marked [P]`**, the per-story block
  **`(setup/foundational/polish): 14`, `[US1]: 7`, `[US2]: 7`, `[US3]: 1`, `[US4]: 2`, `[US5]: 3`**, and
  `OK: format, sequencing and spec-id coverage check out`; `task_id_audit.py specs/020-sentence-pictures` →
  **`34 tasks, 0 done, 4 [P]`** with no duplicate, no gap, no orphan id and no blank line between consecutive rows.
- **Sibling rules are cited in words, never as bare ids**: 012's own rule that the picks are never remembered, 015's
  display, 016's step rule, 017's comment-size ladder and 019's head tags are named by description here, because the
  checker reads the requirement-id universe of *this* feature's `spec.md` and a foreign id would read as a missing
  requirement here.
- The quickstart landed **before** this list (its rows were re-cut and two were appended in the same pass), so every
  walk row cites its number (`quickstart.md` 6-13 and 16) and repeats no steps.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (the video screen offers the assignment pass beside the pick, before the render) | T008, T011, T012, T021 |
| FR-002 (the pass shows the sentences in order and the pictures in their display order, each run visible) | T008, T011, T021 |
| FR-003 (a picture holds 0 or more sentences, each continuous with its own) | T002, T003, T014, T016, T022 |
| FR-004 (sentences are assigned in order across pictures) | T002, T003, T014, T016, T022 |
| FR-005 (a sentence belongs to at most one picture) | T002, T003, T014, T016 |
| FR-006 (each sentence paints its assigned picture; an unassigned one keeps the previous, and the tail falls back to 012's even split) | T002, T003, T004, T005, T021, T025 |
| FR-007 (a picture with nothing assigned is skipped unless the fallback feeds it) | T002, T003, T004, T005, T025 |
| FR-008 (the read is never truncated) | T028 |
| FR-009 (with no assignment the render is 012's, frame for frame) | T004, T005, T009, T013, T027, T030 |
| FR-010 (the assignment survives leaving, reopening and a relaunch, and re-attaches by file name) | T006, T007, T029 |
| FR-011 (the assignment is the reader's own; the app assigns nothing) | T002, T003, T014, T016 |
| FR-012 (each refusal is told, and leaves the assignment in force untouched) | T014, T016, T017, T022, T023 |
| FR-013 (the assignment is a stored setting; a written file is never edited) | T006, T007, T029 |
| FR-014 (a stale assignment is warned about before the render, named, and the warning is tappable) | T002, T003, T018, T019, T026 |
| FR-015 (only a picture holding nothing drags; the render walks the pass's order) | T015, T017, T024 |
| FR-016 (an end sentence un-assigns; a middle one is refused with the reason) | T015, T017, T023 |
| SC-001 (the frames carry the assigned pictures and the order, on the device) | T021 |
| SC-002 (both refusals are answered with their reason, assignment unchanged) | T014, T017, T022 |
| SC-003 (with no assignment the render is identical to 012's own row) | T004, T005, T009, T013, T027, T030 |
| SC-004 (a picture with nothing assigned appears in no frame) | T005, T025 |
| SC-005 (the audio is the content's own, with and without an assignment) | T028 |
| SC-006 (the assignment survives a relaunch and its runs are in force after the same files are picked again) | T006, T007, T029 |
| SC-007 (a second render differs exactly where the assignment differs; the first file is untouched) | T029 |
| SC-008 (a content edit warns before the render's own line and one tap reaches the picture) | T018, T019, T026 |
| SC-009 (dragging an unassigned picture changes the walk's order and no other range) | T015, T024 |
| SC-010 (a picture holding sentences refuses the drag; after un-assigning it moves) | T015, T017, T023, T024 |
| FR-017 (a video is the whole content, whatever the page is showing) | T035, T036, T037, T039 |
| SC-011 (with a sentence highlighted the render's own line holds every sentence) | T035, T039 |

**Requirements of other specs this feature moves or re-cuts** (their ids are cited in words above, because they are
not this spec's to number): 012's rule that the picks are never remembered (kept, and the reason the run's own key
changed — research D7), its `buildPictureSchedule` (the no-assignment branch, body unchanged — T005, T030), its
renderer's own log line (fields unchanged — T009, T013) and its row 49's walk (re-run by T032), 015's per-content
store shape (copied, its own key untouched — T007) and 019's structural row quoting the message-key total (corrected
with its date — T031).

**The four sections above were recovered verbatim on 2026-10-15, and this is the record of it.**
The 2026-10-14 polish pass truncated this file after `## Dependencies & ordering` and lost
`## Parallel opportunities`, `## Implementation strategy`, `## Notes` and `## The stage's notes`; the pass
re-read the requirement coverage table from this file's own greps and left a note saying their prose was **not**
restored. The text above is not a reconstruction: it is the file as this stage wrote it, read back out of the
record of that stage's own session (`@session:default/20261014_080023_aba79e`, the `write_file` of this path —
473 lines, 34 tasks, 4 `[P]`). Two things about it read as of its own date and are left that way on purpose,
per this repository's rule that a record keeps what was true of its tree: the checker output quoted in
`## The stage's notes` is the count at this file's first write (34 tasks, 0 done — the current figures are in
`## Status`), and `## Notes`'s line about `breakpoint.md` not existing yet is where that file stood before
T021 created it. The closing paragraph of the coverage table — the requirements of **other** specs this feature
moves or re-cuts — was lost with them and is restored here too, and the table itself is the one this pass
re-read, which now carries FR-017's and SC-011's rows as well.
