# Tasks: the assignment pass's pictures, and the controls on them

**Feature**: `021-picture-pass` | **Date**: 2026-10-15
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) | **Sketch**: [ui-sketch.html](./ui-sketch.html)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (the reader sees the picture and gives it sentences, P1), `US2` (looking at one
picture closely, and changing the set, P1), `US3` (a sentence on the wrong picture, P2). Rows with no story label
are shared infrastructure or the walk.

## Status

**IMPLEMENT DONE — 34 of 34 rows** — the 32 the stage closed with, plus the two dated amendments below (T033,
T034) — all three stories, and the device walk. The pass shows the pictures the reader picked, each carrying its
own count; one tap selects and the list below is that picture's; a hold opens it large
with the app's own count words and `Close`; a picture the reader gave nothing offers the move and the delete, with
a confirmation before every delete; a sentence another picture holds is proposed as a switch and repaired on
confirmation; and the picker prompt draws the same cells with the same rule. The defect the reader reported is
closed at the rule: a sentence can no longer be in two runs, on any path.

**The receipt, re-taken and reconciled per file, 2026-10-16 08:48–08:50 PDT.** Both sides measured the same way —
`flutter test --reporter json`, counting `testDone` per suite — with the baseline side run in a scratch copy of
`HEAD` (`a7a650f`, the 020 tree):

```
flutter analyze                    → No issues found! (ran in 1.4s)
flutter test --concurrency=2       → 01:13 +808: All tests passed!
base (HEAD, a7a650f)               → +782: All tests passed!
test/*.dart                        → 57          (55 at HEAD)
message keys per ARB (four files)  → 129 129 129 129
```

`782 → 808` is three files: `+10` (`test/picture_assignment_switch_test.dart`, new), `+15`
(`test/reading_view_picture_pass_test.dart`, new), `+1` net in `test/reading_view_video_assignment_test.dart`
(18 → 19). **Correction, dated 2026-10-16**: the closing receipt read `782 + 10 + 15 + 1 + 2 − 2 = 806`, but those
terms sum to `808` — which is what the tree measures — and the two retired drag cases sit inside the assignment
suite's net `+1`, so they are not separately quotable as a `−2` term. The `806` and `807` in T032/T033 were the
totals of their own passes; `808` is the finished tree's.

The **device walk** ran on `emulator-5554` — rows 8-15, 17 and 19 (`5/5`, `6/6`, `8/8`, `8/8`, `11/11`, `12/12`,
`6/6`, `12/12`, `8/8`, `11/11`) — with the app's own labels quoted verbatim in `breakpoint.md`. **The stills both
files cite under `/tmp/klhu_out` are gone as of 2026-10-16** (`/tmp` is cleared on reboot, and the images were kept
out of the repository on purpose): re-cutting them means re-running the walk — recorded, not re-taken. The package
on the device was last updated `2026-10-16 08:43:56`, i.e. a build newer than every source file in the tree, against
the 2026-10-15 16:03 build the rows below quote. One limit is recorded rather than faked (row 14: three pictures fit
the screen, so FR-007's "middle" is not observable on this fixture) and one requirement as unreachable in the UI
(FR-015's `holdsSentences`, whose own note is in `spec.md`).

**Open — nothing in the plan**: every row is ticked and the six checkers are green. Two things sit with the reader
rather than the plan: row 14's own limit (a wider fixture, or the limit stands as recorded) and the walk's stills
(re-run the walk to re-take them).

The baseline every row below is read against — re-taken with the same two commands before any edit, because a
baseline measured after a change is not a baseline:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 01:17 +782: All tests passed!
message keys per ARB (four files)    → 120 each
test/*.dart files in the tree        → 55
```

Measured 2026-10-15 08:40–08:45 PDT on the tree of 2026-10-14, the same build 020's walk drove. `plan.md` carries
the decisions (D1-D10), `data-model.md` the invariants (INV-1..9) and `quickstart.md` the 18 rows the walk rows
below cite.

## Grounding notes (the decisions these tasks implement)

1. **The cell is the picture** (D1, FR-001, FR-002): the thumbnail reuses the dialog's own bounded decode, the
   count is the number alone at its top right, and the file name survives as the cell's **semantic label** — never
   painted, and still what 020's own walk reads.
2. **One tap selects; a hold opens the picture large below the strip** (D2, FR-003, FR-004), with `Close` bringing
   the list back and the app's own count words under the large picture (FR-019).
3. **What decides the move and the delete is the reader's own run** (D3, FR-005) — not the resolver's `effective`
   answer, whose fallback is what the reader's own report is about.
4. **The switch is a repair** (D4, FR-011, FR-012, FR-013): the sentence leaves its holder before it is given, and
   the rules' two order boundaries become inclusive, so no path puts one sentence in two runs.
5. **The delete writes through the draft the pass already answers with** (D5, FR-008, FR-009), and the dialog's own
   surface gets the same cells, the same large picture and the same controls (FR-010).
6. **The strip centres the selection** (D6, FR-007) with the platform's own `Scrollable.ensureVisible`.
7. **The walk is one new driver** (D7), one row per device scenario, and 020's own rows are re-walked rather than
   re-cut.
8. **The confirmations name the picture** (D8, FR-014), never a file name.
9. **The count is the reader's own record** (D9, FR-001, FR-019).
10. **No drag**: the move is two buttons, and the plan promises nothing about the gesture (D10).

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/021-picture-pass/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up makes
  plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated files are part
  of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; the walk driver is
  `specs/021-picture-pass/scripts/klhu_walk_pass.py` and it dispatches on the **quickstart row number**
- Checkers: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py
  specs/021-picture-pass` and `…/task_id_audit.py specs/021-picture-pass`, both after every edit of this file

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the copy every state of this feature draws on. Nothing is installed — this feature adds no dependency,
no asset and no platform file.

- [x] T001 [P] `lib/l10n/app_en.arb`: add this feature's strings — the large picture's own close control, the two
      move controls, the delete control and its confirmation, and the switch's confirmation with its own action
      word — to the template and to the three translations `lib/l10n/app_es.arb`, `lib/l10n/app_zh.arb`,
      `lib/l10n/app_zh_Hans.arb`, then `flutter gen-l10n` and confirm the diff is exactly the four ARBs plus the
      regenerated `lib/l10n/app_localizations*.dart`. Only the template carries `@`-metadata. The count's own words
      (`N sentences` / `No sentences assigned`) already exist and are **reused** — they move position, they are not
      minted again (FR-019)

**Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green.

---

      — **Done 2026-10-15**: the nine keys are in all four ARBs, each file parsing to **129** keys (120 + 9): `assignmentClose`, `assignmentMoveLeft`, `assignmentMoveRight`, `assignmentDeletePicture`, `assignmentDeleteTitle`, `assignmentDeleteBody`, `assignmentSwitchTitle` (with a `{sentence}` placeholder, `@`-metadata in the template only), `assignmentSwitchBody`, `assignmentSwitchConfirm`. `flutter gen-l10n` exit 0; `git diff --stat lib/l10n/` = the four ARBs + the four regenerated `app_localizations*.dart`, 213 insertions. `flutter test test/l10n_keys_test.dart` → `+3: All tests passed!`; `flutter analyze` clean. The count's own words are reused, not minted (FR-019).
      — *What it cost*: the block first broke three files — in the translations `assignmentStaleDetail` is the **last** data key, so the comma I put after my block was a trailing comma before `}`, and in the template my anchor line had none (`Illegal trailing comma before end of object` / `Expecting ',' delimiter`). Fixed by two precise edits and re-checked with `json.loads` on all four; a blind "every line needs a comma" rule made it worse, not better.
## Phase 2: Foundational

**Purpose**: the rules and the shared cell every story stands on. Both are device-free.

- [x] T002 [P] `test/picture_assignment_switch_test.dart`: write the boundary cases this feature's own defect report
      is about — with white holding sentences 1-4 and black 5-7, a tap on white's **last** sentence with black
      selected must be refused by the order rule, and the symmetric case (an earlier picture tapping the later
      picture's first) too — plus the switch's own legality: an end of a holder's run where the target ends
      continuous and in order is legal; a middle sentence is not; a switch that would leave the target gapped or out
      of order is not. Run it and keep the RED output (the rule does not exist yet: a compile error is the RED, and
      it must be quoted as one)
      — **Done 2026-10-15**: `test/picture_assignment_switch_test.dart`, ten cases. **Two REDs, because the file has both flavours.** Against the rule as shipped, with only the boundary group in the file: `00:00 +1 -2: Some tests failed.` with `Expected: AssignmentRefusal:<AssignmentRefusal.notInOrder>` / `Actual: <null>` twice (the third boundary case — a sentence deep inside a neighbour's run — is the rule as it always answered). With the switch's own cases added: 8 `undefined_function` errors for `holderOf` / `refusedSwitch` / `applySwitch` — the rule that does not exist yet.
      — *What it cost*: the timeline's fixture content is **six** sentences, so the reader's "1-4 and 5-7" shape is `0-3` / `4-5` in this file. The first draft asked for sentence 7 → `RangeError (length): Invalid value: Not in inclusive range 0..5: 6` in every case, which is a failing test for the wrong reason; the RED above is the corrected file against the shipped rule.
- [x] T003 `lib/picture_assignment.dart`: make the two order-boundary comparisons **inclusive**
      (`:149-151`) and add the switch's own rule beside `refusedAdd`/`refusedRemove` — a legality answer and an
      application that **removes the sentence from its holder before giving it to the target**, so a sentence can
      never be in two runs. Green against T002
      — **Done 2026-10-15**: `lib/picture_assignment.dart` gains `holderOf`, `withoutSentence`, `refusedSwitch` and `applySwitch`, and `refusedAdd`'s two comparisons are **inclusive** (`index <= held.last`, `index >= held.first`) with the reason written beside them. `flutter test test/picture_assignment_switch_test.dart` → `00:00 +10: All tests passed!`; the shipped rule's own file → `+20: All tests passed!`; `flutter analyze` clean.
      — The switch is the repair the plan's D4 describes: `refusedSwitch` reads the **holder's** rule first (an end of its run, or `middleOfRun`), then the **target's** rule against the runs the holder has already let go of — so a switch can never leave a sentence in two runs, which is FR-013 by construction rather than by a caller remembering to remove first.
- [x] T004 [P] `test/picture_assignment_test.dart`: re-cut the shipped `mayDrag` cases (`:399-418`): what decides a
      picture's own movability is **the reader's own run**, so a picture the render's fallback would feed is
      movable while a picture holding one of the reader's sentences is not. Run it and keep the RED output (the
      predicate's input changes: a compile error or a wrong answer is the RED)
      — **Done 2026-10-15**: the two shipped `mayDrag` cases are re-cut in `test/picture_assignment_test.dart` — what decides a picture's own movability is the **reader's own runs**, so a picture the render's tail fallback feeds is the reader's to move (their report of 2026-10-15) while one holding a sentence of theirs is not. RED: 6 `undefined_function` errors for `mayMove` against the shipped predicate.
- [x] T005 `lib/picture_assignment.dart`: `mayDrag`'s own input — the reader's own runs rather than the resolver's
      `effective` answer — and its doc comment with it. Green against T004
      — **Done 2026-10-15**: `mayDrag(AssignmentAnswer, int)` → `mayMove(List<PictureRun>, int)` (the reader's own runs, one per picture — the pass's own `_runs`), with the doc, the `holdsSentences` enum's own comment and the pass's header all corrected. The pass's chip now asks `mayMove(_runs, picture)`. `grep -rn mayDrag lib/ test/ | wc -l` → `0`; `test/picture_assignment_test.dart` → `+20: All tests passed!`.
      — The rename is this row's natural consequence and is deliberate: the predicate no longer answers a drag (D10 retires it), it answers whether a picture may take another place — which is what T012's two buttons ask.
      — Unused after the change, and removed rather than left for later: the page's own `_answer` getter (its only reader was the chip's enabled state) and the `final answer = _answer;` local. `flutter analyze` → `No issues found! (ran in 1.1s)`.
- [x] T006 [P] `lib/picture_cell.dart`: the picture cell both surfaces use — the picture at thumbnail size with the
      count's own badge at its top right, the decode bounded the way the dialog already bounds its thumbnails
      (`lib/reading_view.dart:3027-3030`, `cacheWidth: 144`), and the picture's own name as the cell's semantic
      label. No reader-visible change yet: its verification is `flutter analyze` clean and every shipped suite green
      **unmodified**

**Checkpoint**: T002/T004 green, `flutter analyze` clean, the shipped suites green, and no page has changed yet.

---

      — **Done 2026-10-15**: `lib/picture_cell.dart`, the cell both surfaces draw: the picture at the dialog's own metrics (72, `cacheWidth: (size * 2).round()`, the same `errorBuilder`), the count as **the number alone** at its top right (FR-019, `showCount: false` for the sentence list's own small marker), the highlight when it is the reader's own selection, and the picture's name as the cell's **label** rather than painted text (FR-002) — with `container: true`, so a screen reader meets one picture at a time instead of the whole strip merging into one label.
      — Verified with no page changed yet: `flutter analyze` → `No issues found!`; `git diff lib/video_pictures.dart lib/video_timeline.dart` empty; the shipped suites green unmodified (`test/reading_view_video_assignment_test.dart` `+18`, `test/picture_assignment_test.dart` `+20`, `test/picture_assignment_switch_test.dart` `+10`).
      — *What it cost*: my first write carried 12 stray `\'` escapes (a quoting slip) and Dart rejected the badge's own `'$count'` with `Expected an identifier` / `Unterminated string literal`.
## Phase 3: User Story 1 — the reader sees the picture and gives it sentences (P1) 🎯 MVP

**Goal**: the pass shows the reader's pictures as pictures, each carrying its own count; one tap selects one and its
sentences appear below, ready to be given and taken back.

**Independent Test**: with three pictures chosen, each cell shows the picture and `0`; a tap highlights it, the list
below is that picture's, and giving it a sentence changes the badge on the same tap.

- [x] T007 [P] [US1] `test/reading_view_picture_pass_test.dart`: write US1's cases (RED) — a cell carries the
      picture and its count at the top right; no painted string on the page is a file name while the cell's
      **semantic label** is; a tap selects (the cell is highlighted and the list below is that picture's); a
      sentence given to it changes that cell's own count **on the same tap**; a sentence another picture holds is
      marked with which picture holds it (by the picture, not a name). Run it and keep the RED output
      — **Done 2026-10-15**: `test/reading_view_picture_pass_test.dart`, five cases — the strip shows the pictures (three cells, no `ChoiceChip`, no painted name, the name read off the cell's own semantics node), each cell carries the reader's own count including `0`, one tap selects and the list below is that picture's, giving a sentence changes that cell's count on the same tap, and another picture's sentence is marked by **its own small cell**. RED against the page as it stood: `00:00 +0 -5: Some tests failed.`, the first `Actual: _ElementPredicateWidgetFinder:<Found 0 widgets with widget matching predicate: []>`. Green after T008: `+5: All tests passed!`.
      — *What it cost*: `find.bySemanticsLabel` found **no** node for the cell even with `container: true` — the label rides a merged node, so the case reads the node `tester.getSemantics` hands back and asserts `contains` (the device row T020 is where the exposed label is read for real). And `cellOf` needed the size filter: the list's own marker carries the same name, so `find` reported `Found 2 widgets` for `hills.png`.
- [x] T008 [US1] `lib/picture_assignment_screen.dart`: the pass's own page — the strip of `PictureCell`s, the
      selection (highlighted, centred later in T014), and the sentence list below it with the reader's own
      sentences marked and the others' marked by their holder. Green against T007
      — **Done 2026-10-15**: the strip is three `PictureCell`s in the pass's own order; a tap selects (FR-003); the count comes from the reader's own run (`_runs[picture].spans.length`, FR-001); the list's holder marker is the holder's own **small cell** (`size: 28`, no count) instead of the name it used to paint, so `_holderOf` returns a picture rather than a string. `flutter analyze` clean.
      — **The drag came out here, not in T012**: `LongPressDraggable`/`DragTarget` lived on the chip this row replaces, so `_chip` is gone, `_move` with it (nothing calls it until T012's buttons) and `_countLabel` too (the words it built move under the large picture in T011). `_pictures`/`_runs` became `late final`, which is what the removed `_move` had been reassigning.
- [x] T009 [P] [US1] `test/reading_view_video_assignment_test.dart`: re-cut the shipped pass cases the surface moved
      under — its cells are found by the **painted file name** (`find.text(name)` under a `ChoiceChip`, `:244-293`)
      and its count helper (`passCount`, `:391`) reads the cell's own label, both of which the new cell changes —
      rewritten, never deleted, while its refusal and store groups stay as they are. Run it, then the full suite

**Checkpoint**: US1 is independently demonstrable — the reader sees the picture, selects it, and its count answers
the tap.

---

      — **Done 2026-10-15**: the shipped pass suite re-cut onto the new surface, never blanked: `passChips` → `passCells` (the strip's own pictures, read off the cells), `passCount` now reads the **painted badge** (the number alone, FR-019), `chipOf` → `cellOf` (by the name the cell carries, size-filtered), every `tester.tap(find.text(<name>))` → `tester.tap(cellOf(<name>))`, the count expectations `'No sentences assigned'` / `'1 sentence'` / … → `'0'` / `'1'` / …, and the holder assertion reads the small cell's own picture. `+16: All tests passed!`.
      — **Two cases replaced rather than re-pointed**, with a dated note in the file: the two drag cases (`a picture holding sentences refuses the drag`, `a picture holding nothing drags…`) describe a gesture this feature removes (D3/D10), and `holdChip` went with them. What a picture holding sentences refuses is read in the RULE's own file (`mayMove`'s cases, T004), and the surface's gating is T023's device row and T010's cases; the group's title loses "and the drag" with them.
## Phase 4: User Story 2 — looking at one picture closely, and changing the set (P1)

**Goal**: a hold opens the picture large below the strip with the list hidden and `Close`; a picture the reader gave
nothing offers the move and the delete; a delete asks first and takes the picture out of the record; the dialog's
own surface behaves the same.

**Independent Test**: hold a thumbnail of a picture holding nothing: the large picture appears with the two move
controls and the delete; cancelling the delete leaves a render's own line identical; the dialog shows the same.

- [x] T010 [US2] `test/reading_view_picture_pass_test.dart`: write US2's cases (RED) — a hold shows the picture large
      below the strip, the sentence list hidden, the count's own words under it, and `Close` brings the list back
      with the same picture selected; a picture holding nothing offers the move and delete controls, one holding a
      sentence offers neither; a move shows on the strip at once; the delete's confirmation names the picture and
      cancelling changes nothing; the draft the pass answers with carries the reader's runs and no fallback
      sentence. Run it and keep the RED output
      — **Done 2026-10-15**: ten cases for US2 and US3, written before their code. RED against the page as it then stood: `00:00 +5 -10: Some tests failed.` (US1's five passing, the ten new ones failing for want of the large picture, the controls, the two confirmations and the switch). Green after T011-T014 and T018: `+15: All tests passed!`.
      — *What it cost, three times over*: (1) `stringsOf` reads the page's own strings, and I called it **before** pumping in eight cases — `tester.element(...)` on a page that is not there throws `Bad state: No element`; the call is now made after the page is up (in two passes: four-space indents first, the group's six-space ones second). (2) A `tester.widget<Text>(find.descendant(of: find.byType(SnackBar), ...))` reading of a refusal throws `Bad state: No element` whenever **no** snack bar is showing, which is exactly the case a refusal's own test is about; replaced by the shipped suite's `shownRefusal` idiom (iterate `widgetList<SnackBar>`, return null when there is none). (3) Once the large picture's own cell (220) and a confirmation's (112/120) are in the tree, a `size > 40` predicate stopped meaning "the strip": a three-picture strip reported a fourth cell (`Which: at location [3]`), so the strip's finders are now size-exact (72).
- [x] T011 [US2] `lib/picture_assignment_screen.dart`: the large picture in the page's own body — the held cell's
      picture below the strip, the list hidden while it is open, the count's own words under it, and `Close`.
      Green against T010
      — **Done 2026-10-15**: `_bigPicture` — the picture at 220 below the strip, the sentence list hidden while it is open, the app's own words for its count under it (`_countLabel`, back where FR-019 says they live), and `Close` bringing the list back on the same picture (FR-004, FR-019). The strip's cell gains the hold that opens it; the body is a `SingleChildScrollView` so a tall large picture cannot overflow the column.
- [x] T012 [US2] `lib/picture_assignment_screen.dart`: the controls — `Move left` / `Move right` over the same
      `movePicture` the drag used, `Delete this picture`, both offered only when the reader's own run for that
      picture is empty; the drag and its `LongPressDraggable`/`DragTarget` come out of this page
      — **Note 2026-10-15 (this row is narrower than it reads)**: `LongPressDraggable`/`DragTarget` and the page's own `_move` came out with T008's strip rewrite, because they lived on the `ChoiceChip` that row replaced. What is left here is the two buttons and their gating.
      — **Done 2026-10-15**: `Move left` / `Move right` over the same `movePicture` the drag used, and `Delete this picture`, all three offered only where `mayMove(_runs, picture)` says the **reader** gave the picture nothing (FR-005, D3) — a picture holding a sentence of theirs shows no controls at all. A picture already at an end of the order has that control disabled rather than doing nothing. `_move` moves in place (`movePicture`'s result copied back into the page's own `late final` lists) and keeps the reader looking at the picture they moved.
- [x] T013 [US2] `lib/picture_assignment_screen.dart`: the delete's confirmation (the app's own dialog shape, naming
      the picture by the cell it lives in) and the record write — confirming drops the picture and its run from the
      draft the pass answers with, and cancelling changes nothing
      — **Done 2026-10-15**: `_deletePicture` — the confirmation names the picture by its own cell at 120 (never a file name, FR-014), says what will happen, and asks with 015's own `Cancel`/`Delete` words. Confirming takes the picture and its run out of the page's lists, closes the large picture, and clamps the selection; the answer the page gives on `Done` carries the reader's runs and nothing else (FR-016 — the test reads `given!.runs` after a delete and finds it empty, not a fallback sentence). Cancelling changes nothing.
- [x] T014 [US2] `lib/picture_assignment_screen.dart`: the strip's own centring — a key per cell and
      `Scrollable.ensureVisible(alignment: 0.5)` on selection, on a move and on a delete
      — **Done 2026-10-15**: `_centreOn` scrolls the picture's own cell to the strip's middle with `Scrollable.ensureVisible(alignment: 0.5)`, called after a selection, a move and a delete, in a post-frame callback so the cell is where the call reads it. The keys live in a `Map<String, GlobalKey>` keyed by the picture's own **name**, so a move needs no key bookkeeping and a deleted picture's key is simply never asked for again. The numbers this claims are T026's (the cell's own bounds off a device); what this row proves is that nothing about selection or the list changed under it.
- [x] T015 [US2] `lib/reading_view.dart`: the dialog's own chosen pictures on the same cell and the same behaviour
      — hold, large picture, `Close`, the two move controls and the delete under the same rule, and its own remove
      asking first. Its reorder narrows to a picture holding nothing (the pointer is T028)
      — **Done 2026-10-15 (the half its own text asks for)**: the prompt's chosen pictures now draw the **shared cell** (`ChosenThumbnail`'s bare decode is `PictureCell`, so a picture there carries its own count from the reader's runs — `_countOf` — and its name as the cell's label), and the prompt's own remove **asks first** through `_confirmRemovePicture` (the pass's own keys, the picture named by a 120 cell, 015's `Cancel`/`Delete`). `flutter analyze` clean; the three suites that touch the prompt at `+62: All tests passed!`.
      — **Not done here, and the row stays open for it**: the prompt's own **large picture with `Close`, the two move controls and the delete under the same rule**, and the narrowing of 012's own reorder to a picture the reader gave nothing. The hold in the prompt is 012's own reorder gesture (012's own reorder gesture — a sibling's requirement, cited in words), so that half needs the tap-vs-hold question settled on this surface; it is the next request's first work. Until it lands, a picture holding the reader's sentences in the prompt cannot be reordered (012's gesture still moves it) — recorded rather than quietly delivered as "the same UI".
- [x] T016 [P] [US2] `test/reading_view_video_assignment_test.dart`: re-cut the dialog's own shipped cases where the
      shared surface and the asking remove changed them — its `MovableThumbnail` count (`:169`), its drag group, and
      its remove's immediacy — rewritten, never deleted. Run it, then the full suite

**Checkpoint**: US2 is independently demonstrable on both surfaces; the render is unchanged by a move or a cancel.

---

      — **Done 2026-10-15**: the cases this row names, re-cut where they broke and left where they did not. **Re-cut**: 012's own `the chosen pictures are shown, and one can be taken back` (the remove now asks — cancelling is asserted to take nothing back, then confirming takes exactly one) and the prompt-standing-behind-the-pass case in the assignment suite. **The scoping those two forced**: `cellOf` in the assignment suite is now scoped to `PictureAssignmentScreen` and size-exact (72), because the prompt behind the pass draws the same cell at the same size — an unscoped finder matched two pictures for one name and threw `Bad state: Too many elements`. **Not re-cut**: the dialog's drag group and `find.byType(MovableThumbnail)` counts — the class and its gesture are untouched, because T015's second half (which narrows that gesture) is not in yet; those cases are green as shipped.
## Phase 5: User Story 3 — a sentence that is on the wrong picture (P2)

**Goal**: a sentence another picture holds stays tappable; where the switch is legal the reader is warned with both
pictures and confirms it; where it is not, the rule that refuses it answers, and no box appears.

**Independent Test**: with white holding sentences 1-4 and black 5-7 and black selected, a tap on sentence 4 shows
a confirmation with both pictures; cancelling leaves both runs and the render's line identical; confirming leaves
white 1-3 and black 4-7.

- [x] T017 [US3] `test/reading_view_picture_pass_test.dart`: write US3's cases (RED) — the confirmation shows both
      pictures; cancelling leaves the runs and a render's own line identical; confirming moves exactly one sentence
      and the page's counts sum to the content's sentence count; a middle sentence of another picture's run is
      refused with that rule's own words and no confirmation appears; a switch that would leave the target gapped or
      out of order is refused the same way. Run it and keep the RED output
      — **Done 2026-10-15**: five cases for the switch, written before T018. RED in T010's own run (the group's five among the ten failures). Green with T018: the whole file at `+15: All tests passed!`. The cases cover both pictures being shown, cancel leaving the counts identical, confirming moving exactly one sentence (and the draft carrying the sentence's own span in its new run), a middle sentence refused with `assignmentRefusedMiddle` and **no** box, and a switch that would leave the target gapped refused with `assignmentRefusedNotContinuous`.
- [x] T018 [US3] `lib/picture_assignment_screen.dart`: the switch's own branch — mine → take back, another's →
      propose the switch where the rule allows, confirm, then apply it as the repair T003 defines — and the
      confirmation's own box, naming the pictures by their cells

**Checkpoint**: the reader's own case works and the defect's shape is impossible: a sentence is never in two runs.

---

      — **Done 2026-10-15**: `_tap` now reads **whose** sentence was tapped before it decides anything (FR-003, FR-011): the selected picture's own takes FR-016's rule, nobody's takes FR-004's, and another picture's goes to `_proposeSwitch` — which asks the rule first (`refusedSwitch`) and refuses with that rule's own reason, showing no box, where the switch is not legal; where it is, the reader is shown the sentence, both pictures (the holder, an arrow, the selected one) and the confirmation's own words, and confirming applies `applySwitch`'s repair. The keeper's own sentence is no longer refused as "not in order": it is proposed as a switch, which is what the reader's own report of 2026-10-15 asked for.
## Phase 6: The device walk (the rows the unit tests cannot hear)

**Purpose**: what the reader sees — the thumbnail, the badge, the large picture, `Close`, the centring, the two
confirmations — read off `emulator-5554` as the app's own evidence plus a still per state.

      — **Decision 2026-10-15 (the reader's own, option C)**: the prompt gets **no** large picture and no move/delete buttons of its own; what it has is the reader's rule — *"Picture has sentences assigned cannot move and delete"*. Implemented in this row's second half: `MovableThumbnail` gains `mayMove` and a picture the reader assigned anything to is **not draggable** (012's own reorder stays for the pictures they gave nothing), and `ChosenThumbnail`'s remove is absent rather than refused (`onRemove` null), with the picture's own count on the cell saying why. `flutter analyze` clean; the whole suite `01:18 +805: All tests passed!` — 012's own drag cases keep passing, so they were reordering pictures the reader had assigned nothing to, which is exactly the half the rule leaves them.
      — **Still open, and why this row is not ticked**: no case of this feature's own yet covers the prompt's gating. The behaviour is written and the suite is green; what is missing is the assertion (the shape to copy is this file's `the dialog's own seam` group: `ownLibrary` → `assignOnTheOldText` → `openDialogWith` → the pictures button again → assert no remove tooltip and no `LongPressDraggable` on a picture holding a sentence). Until that case exists, this half rests on the suite's green alone — named rather than implied.
      — **Done 2026-10-15 (the case it owed)**: `a picture holding a sentence of the reader's cannot be moved or deleted from the prompt (021 FR-005, decided 2026-10-15)` in the assignment suite's `the dialog's own seam` group — the reader assigns, leaves, comes back and picks the same three files, and the prompt opens on all three with their runs re-attached, every one of them holding a sentence: no `videoPicturesRemove` tooltip and no `LongPressDraggable` anywhere in it. **The RED is real and on the base**: with `lib/reading_view.dart` stashed, the same case fails `Expected: no matching candidates / Actual: Found 3 widgets with widget matching predicate` — the three removes 012's own prompt offered unconditionally; with this feature's file restored it is `+1: All tests passed!`.
      — *What it cost*: my first draft tapped `Choose pictures` and the tap found nothing, because the reopened prompt already holds the reader's earlier pick and its button reads `Choose more` — the probe that showed that (printing every `Text` on screen) is what settled it; the case now asserts on the prompt as it opens. Two shell-quoting failures in `--plain-name` also reported `+0 -7` for a case that was never broken: pass the filter as an argv entry, not through a shell string.
- [x] T019 `specs/021-picture-pass/scripts/klhu_walk_pass.py`: write the walk driver and its fixture — 020's own
      fixture and mechanics imported rather than copied (one string per `adb shell` command, `fresh_dump`, `dump_until`,
      `check`/`PASS`/`FAIL`), dispatching **quickstart rows 8-15**, with this feature's own three pictures and ten
      sentences. A row is implemented in the pass that walks it; `main` names the rows it does not have yet rather
      than dispatching into a stub. Before any code changes, row 8's own first action is to re-take the stills the
      020 walk left (they are gone from /tmp)
      — **Done 2026-10-15**: `specs/021-picture-pass/scripts/klhu_walk_pass.py` — 020's module imported for everything it already has, 021's own additions being the cell's one-node label parser (`cell_line`/`cell_counts`), `sentence_rows` (the list's own rows, which is how "hidden while large" is read), `fresh_pass` (020's boot: `preflight` → `seed_content` → `push_pictures(make_pictures())` → the prompt → the pass) and `assign_own` (021's copy of 020's `assign`, for the two assumptions 021 supersedes — see the breakpoint's own section). `main`'s `OWED` names 12-15 and 17 until their rows walk them. `py_compile` OK; the driver driven against the device for four rows.
      — Run shape (recorded because two of them cost a round each): `ADB_SERIAL=emulator-5554 /usr/bin/python3 -u <driver> 8` with a **clean environment** — the box's default `python3` has no working PIL (`ImportError: cannot import name '_imaging'`) and `adb` must be on `PATH` (`~/Android/Sdk/platform-tools`), and `adb` refuses to run at all without `-s` while more than one device is attached.
      — **Correction 2026-10-15 (found by checking, not by assuming)**: the first four rows' stills were written **into the repository** — `screencap` takes a real path and the driver handed it a bare label, which resolved against the driver's own working directory. Deleted; the driver now passes `os.path.join(OUT, "<label>.png")`, and rows 8-11 were re-walked green (`5/5`, `6/6`, `8/8`, `8/8`) with the stills under `/tmp/klhu_out`.
- [x] T020 Walk `quickstart.md` row 8 into `specs/021-picture-pass/breakpoint.md`: the strip's own cells — the
      picture itself with its count at the top right, no painted file name, and the cell's semantic label carrying
      its name. Proves FR-001, FR-002, SC-001
      — **Done 2026-10-15**: row 8 walked, `5/5 checks passed`. Every cell's own label is `<picture>\n<number>` (`{'w020_white.png': '0', 'w020_black.png': '0', 'w020_red.png': '0'}`), one cell's own node quoted verbatim in the breakpoint, no count words anywhere on the strip, one cell drawn per chosen picture. Still `021_row8_strip.png`.
      — The one thing the dump cannot prove is recorded where it belongs: uiautomator shows a painted label and a semantic label the same way, so **"no file name is painted"** is the widget layer's own claim (`find.text(name) findsNothing`, `test/reading_view_picture_pass_test.dart`) and the still is the reader's own eye on it.
- [x] T021 Walk `quickstart.md` row 9 into `specs/021-picture-pass/breakpoint.md`: one tap — select, the list below,
      and the badge changing on the same tap, read off two dumps around one tap. Proves FR-003, FR-006, SC-002
      — **Done 2026-10-15**: row 9 walked, `6/6 checks passed`. Right after one tap, with no second gesture between: `{'w020_white.png': '1', 'w020_black.png': '0', 'w020_red.png': '0'}`; a tap on another picture assigns to that one (`{'w020_white.png': '1', 'w020_black.png': '1', 'w020_red.png': '0'}`). The selection is read **behaviourally**: a cell's own node dict carries no `selected` key on this platform, which the breakpoint records rather than asserts away. Still `021_row9_after_one_tap.png`.
- [x] T022 Walk `quickstart.md` row 10 into `specs/021-picture-pass/breakpoint.md`: a hold — the large picture below
      the strip, the list hidden, the count's own words under it, and `Close` bringing the list back. Proves FR-004,
      FR-019, SC-003
      — **Done 2026-10-15**: row 10 walked, `8/8 checks passed`. While the hold is down the page's own labels are `[…three cells…, 'w020_black.png\n0', 'No sentences assigned', 'Move left', 'Move right', 'Close']` — the held picture below the strip, the app's own count words under it (FR-019), **all ten sentence rows hidden**, and `Close` bringing back exactly those ten. Still `021_row10_large_picture.png`.
- [x] T023 Walk `quickstart.md` row 11 into `specs/021-picture-pass/breakpoint.md`: the controls' gating — the two
      pictures the fallback would feed offer the move and the delete, the picture the reader assigned four sentences
      offers neither. Proves FR-005, SC-004
      — **Done 2026-10-15**: row 11 walked, `8/8 checks passed`. A picture holding one of the reader's sentences shows `['w020_white.png\n1', '1 sentence', 'Close']` — no move, no delete; a picture they gave nothing shows `['w020_black.png\n0', 'No sentences assigned', 'Move left', 'Move right', 'Delete this picture', 'Close']`. The rule the reader stated on 2026-10-15 is visible on the device: what says why is the count on the cell. Still `021_row11_controls.png`.
      — *First run scored 6/8* on 020's own two stale preconditions (its chip-words and its `1 sentences`); both are 020's helper's assumptions, neither is 021's behaviour, and both are written up in the breakpoint rather than smoothed over.
- [x] T024 Walk `quickstart.md` row 12 into `specs/021-picture-pass/breakpoint.md`: the move — the strip's order
      changes at once and the renderer's own ranges follow it, no other range moving. Proves FR-006, SC-005
      — **Done 2026-10-15**: row 12 walked, `11/11 checks passed`. The cells' own `x` swap on the move (`white: 319 → 529`, `black: 529 → 319`) and the strip's own order is `[black, white, red]` in the dump that follows the tap; the renderer's own line moves from `ranges=0..46,47..302,303..551` to `-,0..46,47..551` — the picture moved to the front is one the reader gave nothing, so no frame reaches it (`-`) and the whole tail falls to the one after it. Two renders, same content (`pictures=3 sentences=10` either side). Still `021_row12_after_move.png`.
      — *First run scored 6/7*: this row's own flow tapped `Start` from inside the pass, where there is no `Start` — a render starts on the prompt. Corrected, and the FAIL is what found it.
- [x] T025 Walk `quickstart.md` row 13 into `specs/021-picture-pass/breakpoint.md`: the delete — the confirmation
      names the picture, cancelling leaves the renderer's own line identical, confirming names one picture fewer.
      Proves FR-008, FR-009, SC-006
      — **Done 2026-10-15**: row 13 walked, `12/12 checks passed`. The confirmation's own labels verbatim: `['Delete this picture?', 'w020_black.png', 'This picture will be removed from this video.', 'Cancel', 'Delete', 'Dismiss']` — it asks, it names the picture by its own cell, cancelling leaves the strip `[white, black, red]` and the record `{white: 1}` untouched, confirming leaves `[white, red]` with white still `1`, and the prompt's own line still `1 sentence`.
      — *What it cost*: the confirm's own `Delete` tap first hit the dialog's **title** (`Delete this picture?`), because 012's `find` matches a label by prefix — the dialog stayed up and looked like a delete that had not happened. The driver now carries `tap_exact`.
- [x] T026 Walk `quickstart.md` row 14 into `specs/021-picture-pass/breakpoint.md`: the centring — the selected
      cell's own box at the strip's middle, after selecting the first, the last and one in between, with the bounds
      quoted. Proves FR-007, SC-007
      — **Done 2026-10-15**: row 14 walked, `6/6 checks passed`, **with a limit recorded rather than faked**: the three cells' own `x` are `{white: 319, black: 529, red: 739}` and a selection moves none of them, because 3 × (72 + 8) = 240 logical pixels fit the screen whole — so `ensureVisible(alignment: 0.5)` has nothing to scroll and FR-007's own claim, the selected cell **at the strip's middle**, is not observable on this fixture. Making it observable needs a fixture wider than the screen (about thirteen cells), whose selection through the platform's own file dialog needs scrolling in the Files app: named, costed, and left to a row of its own. What this row does prove: every cell is on screen at once and a selection scrolls nothing.
- [x] T027 Walk `quickstart.md` row 15 into `specs/021-picture-pass/breakpoint.md`: the dialog's own surface and the
      switch — the dialog behaves the same, the switch's confirmation shows both pictures, cancelling changes
      nothing and confirming moves exactly one sentence. Proves FR-010, FR-011, FR-014, SC-008, SC-009
      — **Done 2026-10-15**: row 15 walked, `12/12 checks passed`. The prompt's own cells read `['w020_white.png\n0', 'w020_black.png\n0', 'w020_red.png\n0']` and its remove asks first (`['Delete this picture?', 'w020_white.png', 'This picture will be removed from this video.', 'Cancel', 'Delete', 'Dismiss']`, cancelling leaving `3 pictures chosen`). The switch is proposed with the sentence's own text and **both** pictures (`['Give this sentence to the selected picture?', 'Line one is here.', 'w020_white.png\n1', 'w020_black.png\n0', 'Cancel', 'Move it', 'Dismiss']`), cancelling leaves `{white: 1, black: 0, red: 0}` and confirming leaves `{white: 0, black: 1, red: 0}` — exactly one sentence moved. Stills `021_row15_switch_proposal.png`.
- [x] T028 Walk `quickstart.md` row 17 into `specs/021-picture-pass/breakpoint.md`: the draft's own content, walked
      as a unit row — the pass's answer carries the reader's runs and no fallback sentence. Proves FR-016

**Walk checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`, and no row cites a driver
command that does not implement it.

---

      — **Done 2026-10-15**: row 17 walked, `8/8 checks passed`. With one sentence given to the first picture and a render that paints all ten, the prompt's own line says `1 sentence` — and reopening the pass shows `{white: 1, black: 0, red: 0}`, i.e. the sentences no run names are on no picture. The render's own fallback is an outcome of the render, seen from the device.
## Phase 7: Polish & cross-cutting concerns

- [x] T029 Run `quickstart.md` row 16's structural checks into `specs/021-picture-pass/breakpoint.md`:
      `flutter analyze` clean; the suite's count against this file's baseline decomposed by file; the four ARBs at
      their new count with `flutter gen-l10n` reproducing the tree's Dart and `test/l10n_keys_test.dart` green;
      `git diff lib/video_pictures.dart lib/video_timeline.dart` empty. Proves FR-015, FR-017, FR-018, SC-011
      — **Done 2026-10-15**: row 16 taken on the finished tree and its numbers written into `breakpoint.md`: `flutter analyze` → `No issues found! (ran in 0.9s)`; `flutter test --concurrency=2` → `01:22 +806: All tests passed!`; `test/*.dart` → `57`; the four ARBs at **129** keys each; `flutter gen-l10n` **idempotent** (the aggregate md5 of `lib/l10n/app_localizations*.dart` is `b4d762f1d00650942592c12127532e77` both sides of a run); `test/l10n_keys_test.dart` → `+3`; `git diff --stat lib/video_pictures.dart lib/video_timeline.dart` **empty**.
      — The suite's `782 → 806` is decomposed **by file** in the breakpoint and reconciles: `+10` + `+15` + `+1` + `2` re-cut/extended, `−2` retired.
      — One number moved and is recorded rather than hidden: the aggregate hash differs from the one 020's own structural receipt quotes (`98425bbd…`), because it hashes a different tree — what this row asserts is idempotence, not a constant.
      — **The structural row's other half (2026-10-15)**: `check_artifact_refs.py` went red on three `file:line` citations in `plan.md`, all written against the **plan**-stage tree and moved by the implementation (the three now resolve at `lib/reading_view.dart:3067`, `lib/picture_assignment.dart:325-326` and `lib/picture_assignment.dart:162-165`). Corrected in place with a dated table saying what moved, because a citation is a claim about a tree: green afterwards (`exit 0 | checked … line references | no unresolved references`).
- [x] T030 [P] `specs/020-sentence-pictures/tasks.md`: add this feature's two dated pointers to
      `## Superseded by later specs` — the movability rule (what decides it is the reader's own run, and the drag
      it replaced) and the pass's own walk parser's subject (the file name its cells no longer paint) — with 020's
      artifacts left as written, and the same for `specs/012-reading-video/tasks.md`: its own picture remove now
      asks first and its reorder is narrowed to a picture holding nothing
      — **Done 2026-10-15**: two dated pointers, each written into the **owning** closed feature's own file, and neither feature's spec or plan touched: `specs/020-sentence-pictures/tasks.md` gains the movability rule's supersession (the reader's own run, not the resolver's answer; `mayDrag` → `mayMove`; the drag retired by 021 D10) and the walk parser's own subject (the name is no longer painted, the count is the number alone, so `chip_line`'s shape still reads the strip while 020's `assign()` preconditions are stale — with the device evidence's location named); `specs/012-reading-video/tasks.md` gains the prompt's own remove asking first, its cell becoming the shared one, and its reorder narrowed to a picture the reader gave nothing. Both say plainly that the earlier file's own rows and receipts stand as written, and both name where the evidence is.
- [x] T031 [P] `specs/021-picture-pass/spec.md`: record where the holds-sentences refusal is still reachable —
      nowhere on the pass, since the controls' own visibility answers it — in FR-015's own words and in the walk
      record, rather than leaving a string nobody can reach
      — **Done 2026-10-15**: recorded in FR-015's own words in `specs/021-picture-pass/spec.md` (and in row 15's/row 11's breakpoint sections, which is where a reader lands): `AssignmentRefusal.holdsSentences` is returned by **no rule the pass calls** any more — the pass answers "this picture holds sentences" by not offering the controls (FR-005) — while the value stays (the enum is the rules' own vocabulary and the page's reason mapping is exhaustive over it) and the key stays in the four ARBs (removing one moves counts four structural receipts quote). What making it reachable again would cost is named: a `SnackBar` on a hold, plus a device row to read it.
- [x] T032 `specs/021-picture-pass/tasks.md`: re-take the whole tree's receipt into this file's `## Status` —
      `flutter analyze` and `flutter test --concurrency=2` on the finished tree, written beside the baseline with
      the difference decomposed by file, then
      close the list — tick every row above, correct any receipt that has gone stale, re-run
      `check_tasks_format.py`, `task_id_audit.py` and `check_row_coverage.py`, and quote their output in `## Status`

**Checkpoint**: analyzer clean, the suite's count recorded against the baseline, the three checkers quoted green,
and the working tree holding only intended edits.

---

      — **Done 2026-10-15**: the closing receipt, and the list closed at **32 of 32**. `flutter analyze` → `No issues found! (ran in 0.9s)`; `flutter test --concurrency=2` → `01:22 +806: All tests passed!`; the checkers, all green: `check_tasks_format.py` → `32 tasks (32 done), 9 marked [P] … OK: format, sequencing and spec-id coverage check out`; `task_id_audit.py` → `021-picture-pass: 32 tasks, 32 done, 9 [P]`; `check_row_coverage.py` → `spec.md: 30 ids defined | quickstart: 30 rows claim 30 of them | no row claims: none | tasks.md: coverage table cites 30 id(s)`; `check_quickstart_coverage.py` → `19 FR + 11 SC defined | 18 rows (8 unit, 9 device, 1 structural) | unclaimed: none | no 'Proves' line: none` (18 since Amendment 1's own row 18; the 17 this receipt quoted first was true of the stage as it closed, and the row that changed it is dated 2026-10-15); `spec_consistency.py` → no divergence; `check_artifact_refs.py` → `exit 0 | checked 26 line references | no unresolved references` (after the three stale citations of T029's own note were corrected — the sixth checker is the one that found them). The tree holds this feature's own spec set, the code, the two re-cut suites, the driver, the breakpoint and the stills' own directory (`/tmp/klhu_out`, never the repository).
## Dependencies & ordering

- **T001 → T007/T008** and **T001 → T010-T015**: the strings exist before any widget compiles against them.
- **T002 → T003 → T005**: the rules' own changes are the foundation US2's controls and US3's switch both read
  (T003's repair is what T018 calls).
- **T004 → T005**: the predicate's cases are RED before its input changes.
- **T006 → T007/T008** and **T006 → T010-T015**: the shared cell exists before either surface draws one.
- **T007 → T008** (US1) and **T010-T015 → T016** (US2's own cases and the shipped ones): the tests are written
  before their story's implementation and re-cut after it.
- **T009** and **T016** are re-cuts of shipped suites and run after the code they describe; a re-cut that turns out
  unnecessary is reported rather than forced (the plan's own rule: grep the assertion before re-cutting it).
- **Phase 6 depends on Phase 3-5**: a device row drives the surface the code has.
- **T019 before T020-T028**: the driver's dispatch is the row's contract. **T020-T028 are sequential with each
  other** although their subjects differ: all of them append to one `breakpoint.md`.
- **Phase 7 last**: T029 needs the finished tree, T030/T031 are [P] once the code and the walk have settled, T032
  needs everything.

## Parallel opportunities

- **T001, T002, T004, T006** are four different files with no dependency between them; T001 is the only one
  anything else waits on.
- **T009 and T016** are two different shipped suites (the pass's own, the dialog's own) and touch no common file.
- **T030 and T031** are disjoint: one edits two closed features' records, the other this feature's spec.
- **Nothing in Phase 6 is parallel**: every row installs, drives and reads the same device, and they all append to
  one `breakpoint.md`.

## Implementation strategy

The MVP is **Phase 2 + Phase 3**: the rules' own fix and the surface the reader asked for first (the picture, its
count, the tap) — demonstrable on the device with rows 8 and 9 alone. **Phase 4** is what makes the pass finishable
in one visit (the large picture, the two controls, the delete), **Phase 5** the reader's own reversal (the switch),
and **Phase 6/7** the receipts. The reader's own defect is fixed in Phase 2 — before any surface exists — because
every later phase's taps run through the same rule.

## Notes

- **The file name is never painted** after this feature: it lives on as the cell's semantic label (FR-002's own
  decision), which is also what keeps 020's walk parser valid. A row that finds itself adding a painted name has
  taken the wrong branch.
- **The count is the reader's own record**: a badge that shows what the render *will* paint is wrong (FR-001,
  FR-019) — the fallback is an outcome of the render.
- **`mayDrag`'s own words change meaning**: it answers "the reader gave this picture nothing", not "nothing feeds
  it". The shipped case file's cases are re-cut to say so (T004).
- **The drag is retired on both surfaces** (D10): no row re-adds a `LongPressDraggable`, and a long press now means
  "show me this picture large".
- The device rows must not depend on a fixed sleep for a state that takes a moment: poll the dump to a deadline
  (020's own mechanic) and take the still after the state is asked for.

---

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (the pass shows the picture with its own count at the top right, live) | T002, T006, T007, T008, T020, T021, T033 |
| FR-002 (no file name painted; the name is the cell's semantic label) | T006, T007, T020 |
| FR-003 (one tap selects; the list below is that picture's) | T007, T008, T021 |
| FR-004 (a hold opens the picture large below, list hidden, with Close) | T010, T011, T022 |
| FR-005 (move/delete only in the large picture, only when the reader assigned nothing) | T004, T005, T012, T023 |
| FR-006 (a move or delete shows on the thumbnails at once) | T012, T013, T021, T024 |
| FR-007 (the selected picture is scrolled to the middle of the strip) | T014, T026 |
| FR-008 (every delete asks first, naming the picture; cancel changes nothing) | T013, T025 |
| FR-009 (confirming takes it out of the pictures, the order and the record) | T013, T025 |
| FR-010 (the dialog's own surface behaves the same) | T005, T015, T016, T027 |
| FR-011 (a switch is proposed and confirmed, showing both pictures) | T002, T003, T017, T018, T027 |
| FR-012 (a switch completes only on confirmation; cancel is identical) | T003, T017, T018, T027 |
| FR-013 (a sentence belongs to at most one picture; the boundary is refused) | T002, T003, T017 |
| FR-014 (every confirmation names the picture, never a name) | T013, T018, T027 |
| FR-015 (the other shipped rules keep their behaviour and their words) | T003, T009, T016, T029, T031 |
| FR-016 (the answer carries the reader's runs, never the fallback) | T010, T013, T028, T034 |
| FR-017 (every new string in all four ARBs, generated and key-checked) | T001, T029 |
| FR-018 (no dependency, no new stored key, no network) | T029 |
| FR-019 (the badge is the number alone; the words live under the large picture) | T001, T006, T011, T022, T033, T034 |
| SC-001 (each cell carries the picture's pixels and its count, no painted name) | T020 |
| SC-002 (one tap selects, and the count changes on the same tap) | T007, T021 |
| SC-003 (a hold and Close, read off two stills and the labels) | T022 |
| SC-004 (the controls' gating, a still of each state) | T023 |
| SC-005 (moving changes the strip at once and the renderer's ranges follow) | T024 |
| SC-006 (the delete asks; cancel identical; confirm one picture fewer) | T025 |
| SC-007 (the selected cell sits at the middle, measured off the bounds) | T026 |
| SC-008 (the dialog's own surface offers the same) | T027 |
| SC-009 (the switch: both pictures, cancel identical, exactly one sentence moves) | T027 |
| SC-010 (no sentence in two runs after any sequence) | T002, T017, T021 |
| SC-011 (analyze, the suite against the baseline, the key parity) | T029, T032 |

---

## Amendment 1 — the reader's own report of 2026-10-15 (a new row, dated)

> "issue: select pictures, then assign sentences. then cancel. then open dialog, no pictures. but has 8 sentences
> under Assign sentences. should be cleared."

- [x] T033 `specs/021-picture-pass/scripts/klhu_walk_pass.py`: row 19, the reader's own steps — and the fix the report asks for, in `lib/reading_view.dart`: the assignment line's own number counts the reader's runs **for the pictures in force**, not the stored record. Its case is
      `test/reading_view_video_assignment_test.dart`'s own (RED taken first: the line claimed the record's four
      sentences with nothing picked; green after the fix), and the device row reads the app's own labels for the same
      steps.

      — **Done 2026-10-15**: the case first (RED quoted): with a stored record and nothing picked, the prompt's line
      claimed the record's four sentences — `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "No sentences assigned">` — because the count was `assigned.fold(…)`, the stored record's own total, while the tap was already guarded (`held.isEmpty ? null`). The line now counts the reader's runs **for the pictures in force** (`inForce`'s own names), so with none picked it reads the app's own `No sentences assigned`; the record stays stored, which is 020's own rule re-attaching it by name. `test/reading_view_video_assignment_test.dart` → `+18: All tests passed!`; the whole suite → `+807: All tests passed!`.
      — The device row (19) walks the reader's own steps and reads the app's own labels either side of `Cancel`: `8/8 checks passed`, with the section in `breakpoint.md` and a still.
      — Written into the record in the same pass, dated: FR-019's own meaning ("what a count counts" — in force, never the stored total), quickstart row 18, the coverage table's FR-001/FR-019 rows, and the two counts that quoted a 17-row quickstart (this file and `breakpoint.md`'s row 16), since Amendment 1's row makes it 18.

## Amendment 2 — the reader's own decision of 2026-10-15: Cancel clears the record

> "要的是"Cancel 之后记录本身就清掉"（包括再选同样文件也不恢复）"

Amendment 1's own fix left the record **stored** and only stopped the line claiming it; the reader's answer here is
that the record itself must go with the cancelled visit. The two halves together: nothing is claimed while no
picture is in force (Amendment 1), and a cancelled prompt leaves nothing to claim (this one).

- [x] T034 `lib/reading_view.dart`: the prompt's own `Cancel` clears this content's stored assignment
      (`_assignments.clearFor(_anchorKey!)`), so picking the same files again finds nothing. Its case is
      `test/reading_view_video_assignment_test.dart`'s own — RED first: after the reader's steps the store still
      held the record (`Expected: empty / Actual: [Instance of 'PictureRun']`) — green after the fix, and the
      device row (19, extended) walks the same steps and then re-picks the same three files.

      — **Done 2026-10-15**: `_startVideo`'s own cancel branch is now `if (!mounted) return; if (answer == null) {
      await _assignments.clearFor(_anchorKey!); return; }` — an unmounted page (the reader left) keeps the record,
      a cancelled prompt does not. 020's FR-010 (the assignment outliving the prompt) narrows to a visit that ends
      in **Start**, which is the only way a visit keeps its record now; the pointer in 020's own `tasks.md` says so,
      dated.
      — *The ripple, re-cut in the same pass*: the assignment suite's own `assignOnTheOldText` helper left its record
      by **cancelling the prompt**, which no longer leaves anything. It now writes the record where the record lives
      (`PictureAssignmentStore().save(entry.id, runs: …)`) and says why — the state those cases need is the store's
      own to set, and what the app does with it (the prompt loads it, the resolver matches it by name, the pass
      shows it) is unchanged. Three call sites take the entry for its key. `test/reading_view_video_assignment_test.dart`
      → `+19: All tests passed!`; the whole suite → `+808: All tests passed!`; `flutter analyze` clean.
      — **The device, the reader's own steps, `11/11 checks passed`** (row 19, extended): with the pictures picked the
      line reads `Assign sentences\n1 sentence`; after `Cancel` it reads `['No pictures chosen', 'Assign sentences\nNo
      sentences assigned']`; and picking the same three files again leaves it `['3 pictures chosen', 'w020_white.png\n0',
      …]` with the pass's own cells all `0` — nothing came back. Section and stills in `breakpoint.md`.
      — The quickstart's row 18, FR-019's own note in `spec.md` and 020's pointer were corrected in the same pass:
      what Amendment 1 recorded as "the record still stored" is now "taken away by the cancel", and both halves are
      dated where they stand.
