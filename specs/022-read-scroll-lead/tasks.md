# Tasks: the page keeps something ahead of the read

**Feature**: `022-read-scroll-lead` | **Date**: 2026-10-16
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (the read always has something ahead of it, P1), `US2` (the page does not lurch, and does
not fight the reader, P1), `US3` (the ▶ step under the same rule, P1 — the spec's `3A`). Rows with no story label are
shared infrastructure, the walk, or the closing.

## Status

**IMPLEMENT DONE — 22 of 22 rows** (2026-10-16). **The rule is on the device** (build `2026-10-16 11:42:31`), and
the walk's three rows are green: 011's own row 7 re-walked, `24` (the rule) and `25` (a text that fits the area moves by
zero pixels — the half T014 was first left with), plus 016's row 15 re-run. Phase 1 (T001) and Phase 2 (T002-T004) are done, and so is
US1's own three rows (T005-T007): **the rule is in the tree and green** — the line carries its own `below=` field, and
the page moves for the sentence whose successor would be the last visible one, one sentence early (`1B`). The receipts
are under their rows.

```
flutter analyze          → No issues found! (ran in 0.8s)
flutter test --concurrency=2 → 01:14 +816: All tests passed!   (baseline 810 + +5 the follow suite + +1 the step suite)
message keys per ARB     → 129 129 129 129   (unchanged: no string added)
test/*.dart              → 57               (unchanged)
git status android/ ios/ → empty · lib/video_*.dart → untouched
```


**A line-citation re-map this batch owed, done in it**: the implementation added its helpers around
`lib/reading_view.dart:1035`, so this stage's own artifacts' citations were re-mapped to the lines that hold the text
they name (`_measureSpan` 1209 → 1274, `_logFollow` 1242 → 1307, `_revealRange` 1282 → 1352, the retired
`_scrollIntoView` 1176 → `_scrollToRect` at 1175), and the follow suite's own reader moved with its file
(`test/reading_view_follow_test.dart` 509 → 677). Each was checked against the symbol it names before it was rewritten.

**All three stories are in the tree and green**: the line's own field (Phase 2), the continuous read's trigger and
rect (US1), the bound and the hand scroll (US2 — green on first run, T009 needed no code), and the ▶ step through the
same doorway (US3).

**What remains**: nothing of this feature's own. The regression sweep of 2026-10-16 added two rows (**T023**,
**T024** — see the amendment at the end of this file), both now ticked: 011's row 20 was re-cut and walks green, and the
two reds the sweep found outside this feature (011's row 23, 016's row 9) are control-proved and carried in their own
records with their verdicts. **24 of 24 rows.** Every claim in this file traces to a run, and the one row that was first
left half-done (T014) carries its closing receipt. **One plan claim was wrong and is corrected in T004's receipt**: `FollowLine.parse`'s pattern is anchored,
so the appended field was a re-cut of 011's own suite rather than a silent match.

The baseline every row below is read against — re-taken with the same commands **before any edit**, because a baseline
measured after a change is not a baseline:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 01:13 +810: All tests passed!
message keys per ARB (four files)    → 129 each
test/*.dart files in the tree        → 57
```

Measured 2026-10-16 11:19–11:20 PDT on the tree of that morning (`HEAD` = `2735d00`, 021 committed). `plan.md` carries
the decisions (D1-D9), `data-model.md` the invariants (INV-1..INV-6) and `quickstart.md` the 12 rows the walk rows
below cite. **The rule's own trigger is the reader's revised answer (`1B`, 2026-10-16): one sentence earlier** — see
the spec's Clarifications 1.

## Grounding notes (the decisions these tasks implement)

1. **The trigger is one sentence early** (D1, FR-002, `1B`): at a sentence's own start, the page asks whether the
   sentence **after** it is the last one visible; if it is, the page moves now — so the sentence that would be the last
   visible one is never highlighted at the bottom edge.
2. **The measurement is two boxes on one paragraph** (D2, INV-1): the next two sentences, `_measureSpan` each — off
   screen included, which is the plan's load-bearing assumption and the first checkpoint.
3. **The move is one union rect** (D3, INV-3, `2A`): from the sentence in force's `top` to the second-next sentence's
   `bottom`, through the existing `_scrollIntoView`; the smallest rect that makes the **next** read satisfy INV-1.
4. **Once per sentence** (D6, INV-4, FR-004): `_followRead`'s own `gen`/`paragraph`/`sentence` dedupe is the guard; a
   hand scroll stands, a resumed sentence moves nothing.
5. **The line gains one appended field** (D7, FR-009, INV-6): `below=<n>`, with every existing field's name and order
   kept, because two regex parsers already read the line.
6. **One doorway** (D5, `3A`, FR-006): `_revealLead(unit)` serves the follow's trigger, the ▶ press's own reveal
   (016's fix of 2026-10-16) and a step's advance.
7. **Nothing else moves** (D9, FR-008): no message key, no stored state, no platform file, the video untouched.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/022-read-scroll-lead/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up makes plain
  `flutter test` segfault on this 16 GB host)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; the device row is
  `specs/011-reading-experience/scripts/klhu_walk_experience.py` **row 24** (011's own driver, dispatches on the
  quickstart row number), and 011's own row 7 is re-walked rather than re-cut
- The walk's baseline is **re-taken** at T013: 011's receipt for row 7 quotes `viewport=209` where the tree measures
  `196` (research §2) — neither number is inherited
- Checkers, after every edit of this file: `check_tasks_format.py`, `task_id_audit.py`, `check_row_coverage.py`,
  `check_quickstart_coverage.py`, `spec_consistency.py`, `check_artifact_refs.py` (all under
  `~/.hermes/skills/software-development/spec-driven-development/scripts/`)

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the row the walk runs and the line it reads. Nothing is installed — this feature adds no dependency, no
asset and no platform file.

- [x] T001 [P] `specs/011-reading-experience/scripts/klhu_walk_experience.py`: row **24** — 011's own fixture (Extra
      large, display 1080×1000, the 8-sentence preset), its mechanics imported rather than copied (one string per `adb
      shell` command, `fresh_dump`, `check`/`PASS`/`FAIL`), walking this feature's rule: every `klhu follow:` report
      for a sentence that is not the content's last reads `below >= 1`, and the content's last sentence reads `below=0`
      with no move. `follow_lines()` gains the appended field. A row is implemented in the pass that walks it; `main`
      names the rows it does not have yet rather than dispatching into a stub
      — **DONE 2026-10-16** — the row is written and `follow_lines()` reads the appended field (its pattern left
      unanchored, so this feature's own six-field receipts still read as they did). **The row is walked at T013/T014**
      — it cannot pass before the app reports `below`, and this row's own subject is the row itself, not a run.

## Phase 2: Foundational

**Purpose**: the one fact the device rows need and the code does not yet report. Device-free.

- [x] T002 `test/reading_view_follow_test.dart`: the field's own case (RED) — the line carries `below=<n>` with every
      existing field's name and order unchanged, and the suite's own reader (`FollowLine.parse`) returns it. Run it and
      keep the RED output (the field does not exist yet: a compile error or a wrong read is the RED, and it must be
      quoted as one)
      — **DONE 2026-10-16** — RED quoted: `Expected: true / Actual: <false>` with the reason
      `the report carries no count of what follows it: klhu follow: p0 s0 visible=1 top=3 bottom=17 viewport=419`
      (`+2 -1: Some tests failed.`). Green after T003.
- [x] T003 `lib/reading_view.dart`: `_logFollow` appends `below=<n>` — the number of sentences whose boxes are inside
      the viewport **below** the reported one (INV-6), computed from the same measurement the rule uses. Green against
      T002
      — **DONE 2026-10-16** — `_logFollow` appends `below=${_belowCount(spoken)}`; the count walks the sentences
      after the reported one and stops at the first wholly below the fold (the text runs downward), so a long content
      is not measured to its end on every report. The reports' own lines show the rule at work: `… bottom=397
      viewport=419 below=1`, and the next report's geometry has moved (`top=385`) with `below=1` again.
- [x] T004 [P] `test/reading_view_follow_test.dart`: the parser's own case — `FollowLine` reads seven fields with the
      six it always had first, and a line with the old six and no seventh still parses (a closed feature's driver reads
      the same string). Run it, then the full suite
      — **DONE 2026-10-16, and the plan's own claim was WRONG here** — D7 said both parsers "keep matching because
      both are regex-shaped": the driver's pattern is unanchored and does, but **`FollowLine.parse`'s is anchored**
      (`…viewport=(\d+)$`), so the appended field did not match it at all and 011's own suite would have thrown
      `unexpected follow line` on every case. **Fixed by re-cutting this suite's own reader**: the field is read when
      it is there and `below` is `null` when it is not, and its case asserts both shapes
      (`… viewport=196 below=3` → 3; the six-field line → null). 011's driver needed no change.

**Checkpoint**: the line carries the fact; both parsers read it; `flutter analyze` clean.

---

## Phase 3: User Story 1 — the read always has something ahead of it (P1) 🎯 MVP

**Goal**: while a read plays, the sentence being read is never the last one on screen — the page moves one sentence
early, before the sentence that would be the last visible one is highlighted.

**Independent Test**: on a text taller than the page, every report for a sentence that is not the content's last leaves
a sentence after it at least partly inside the viewport, and the move's own evidence precedes that next sentence's own
start.

- [x] T005 [US1] `test/reading_view_follow_test.dart`: write US1's cases (RED) — the sentence whose successor is the
      last visible one moves the page **at its own start** and before that successor's highlight; after the move the
      successor and the one after it are at least partly inside the viewport; the line for it reads `below >= 1`. The
      three no-move cases: the next-next sentence already visible; the content's last sentence; a text that fits. Run
      it and keep the RED output
      — **DONE 2026-10-16, two REDs quoted** — (1) the field: `the report carries no count of what follows it…`;
      (2) the lead: `Expected: a value greater than <-1> / Actual: <-1> / Which: is not a value greater than <-1>` —
      `no sentence that was on screen, with its second-next below the fold, moved the page`
      (`+6 -2: Some tests failed.`). **One bug was the case's own and is recorded rather than hidden**: the first
      version measured the second-next sentence *after* the move, so the move that makes it visible could never
      satisfy the loop's own condition — it measured **before** the report now.
- [x] T006 [US1] `lib/reading_view.dart`: `_revealLead(unit)` and `_followRead`'s own branch (D1/D2/D3) — the trigger
      ("is the sentence after this one the last visible?"), the union rect (this sentence's `top` to the second-next
      sentence's `bottom`), and the doc comment that says why the trigger is one sentence early. Green against T005
      — **DONE 2026-10-16** — implemented as `_leadRect` (the rule's own question and its rect), `_following` (the
      next two boxes), `_partlyVisible` and `_scrollToRect` (the one doorway every reveal now goes through;
      `_scrollIntoView` delegates to it, so 011's own path is unchanged in behaviour). **Not the plan's own name**:
      D5 called the helper `_revealLead(unit)`; what landed is the same one-doorway shape split by what each half
      needs (a rect computed from a `SpokenSentence`, and a move per rect), and T012 wires the step paths to it.
      Green: the follow suite `+8: All tests passed!`; the whole suite `01:13 +813: All tests passed!` (baseline 810
      + the three new cases, exactly); `flutter analyze` → `No issues found!`.
- [x] T007 [US1] `test/reading_view_follow_test.dart`: re-cut 011's own *long text: the spoken sentence comes into
      view* — that case **is** the old rule, and its expectation moves to the lead (rewritten, never deleted). Run it,
      then the full suite
      — **DONE 2026-10-16, and no re-cut was needed** — 011's own *long text: the spoken sentence comes into view*
      fires the read's **last** sentence: nothing follows it, so `_leadRect` hands back that sentence's own rect and
      the case still measures exactly what it always did (it passes **unchanged**, still asserting `visible=1` and the
      box inside the viewport). Reported rather than forced, per the plan's own dependency note — the re-cut this row
      expected is not necessary, and 011's case keeps its own history.

**Checkpoint**: US1 is independently demonstrable — a long read never leaves a sentence riding the bottom edge.

---

## Phase 4: User Story 2 — the page does not lurch, and does not fight the reader (P1)

**Goal**: each move is the smallest that satisfies the rule, the sentence in force is never carried off the top, and a
hand scroll stands to the end of its sentence.

**Independent Test**: read the reveal's own offsets sentence by sentence — each move is bounded by the second-next
sentence's box, no move puts the sentence in force above the viewport's top, and a manual scroll made during a sentence
survives until that sentence's voice ends.

- [x] T008 [US2] `test/reading_view_follow_test.dart`: write US2's cases (RED) — the offset after a move is the
      smallest that leaves the next read a successor on screen; the sentence in force is still inside the viewport and
      not above its top; nothing moves when the next-next sentence is already visible. Run it and keep the RED output
      — **DONE 2026-10-16, and green on the first run — no RED to quote.** Both cases pass against the rect T006
      landed: the framework's own `showOnScreen` on a union rect that fits leaves the sentence in force inside the
      viewport, never above its top, and the move it makes measures well under the viewport's height
      (`expect(moved, lessThan(view.height))` — the page is nudged, not turned). The second case is a **control**
      (green before this feature's rule existed as well) and is recorded as one. Reported rather than forced: the
      house's own rule is that a case which passes on first run names the task that landed the behaviour, and the
      behaviour is T006's.
- [x] T009 [US2] `lib/reading_view.dart`: the rect's own bound — the reveal never carries the sentence in force above
      the viewport's top, and a sentence taller than the viewport is left alone rather than chased (the spec's own
      stated limit). Green against T008
      — **DONE 2026-10-16 — and nothing needed writing.** The bound the row asked for is provided by the framework's
      own reveal: handed a rect taller than the viewport, `showOnScreen` puts that rect's **top** at the viewport's top,
      so the sentence in force cannot be carried above it, and a sentence taller than the viewport is left to the next
      report rather than chased. **Not padded with a guard nobody needs**: the row's own verification is T008's case,
      and no line of the implementation was added for it.
- [x] T010 [US2] `test/reading_view_follow_test.dart`: 011's own *manual scroll is not undone; a resumed sentence
      repaints* — re-run as written (its requirement is unchanged) and extended with the rule's own firing: the lead
      may fire again only at the next sentence's own start
      — **DONE 2026-10-16** — 011's own case re-run as written (its requirement is unchanged) and **extended** with
      this feature's half: the same sentence re-reported moves nothing (`expect(scrollPosition, held)` — the once-per-
      sentence dedupe carries the start-where-the-page-is requirement), and when the report's own successor's successor is below the fold, the
      sentence after it is on screen. The follow suite reads `+10: All tests passed!` with it.

**Checkpoint**: US2 is demonstrable — the page keeps up without lurching and never fights the reader's hand.

---

## Phase 5: User Story 3 — the ▶ step under the same rule (P1, the spec's `3A`)

**Goal**: stepping through a long text also always leaves a sentence below the new highlight.

**Independent Test**: press ▶ to the bottom of the page — after each advance the new highlight and a sentence after it
are at least partly inside the viewport.

- [x] T011 [US3] `test/reading_view_step_test.dart`: write US3's case (RED) — a step's read ends, the highlight
      advances, and the page reveals it with a sentence after it still inside the viewport; the press that starts a
      step reveals its own unit first (today's fix) and then the rule holds. Run it and keep the RED output
      — **DONE 2026-10-16, and the first RED was the case's own** — the helper that finds the page's paragraph looked
      for the shipped fixture's first words (`The sun rose`), so on a **generated** body it threw
      `reading content RichText not found` — which reads like a missing widget and is not one. Fixed by addressing the
      paragraph **by the text the case itself wrote** (`stepContentRender(tester, containing)`), and the honest RED
      taken after that: `Expected: true / Actual: <false>` — `after press 6 nothing follows Sentence number 7 ends here.
      on screen` (the press where the highlight rode the bottom edge). Green after T012.
- [x] T012 [US3] `lib/reading_view.dart`: `_advanceStep`'s and `_readSelection`'s reveal calls go through
      `_revealLead` (one doorway, D5), so the step's surfaces cannot disagree with the follow. Green against T011
      — **DONE 2026-10-16** — `_revealRange` (016's own doorway — the rule that a step's sentence is brought into view) now hands `_scrollToRect` the rule's own
      rect: the unit a step is about to read or has just left highlighted is brought into view **and** a sentence after
      it. The helpers take a content offset (`_leadRect(start, …)`, `_followingFrom(start, count)`) so the follow and
      the step paths ask the same question. **`_scrollIntoView` is retired** — with both doorways on `_scrollToRect` it
      had no caller left, and the analyzer's own gate flagged it as unreferenced rather than letting a dead method sit
      there. One slip of the refactor is recorded: its first attempt left `spoken` inside the renamed helper, which the
      analyzer caught as `Undefined name 'spoken'` before any test ran. Green: step suite `+14`, follow suite `+10`,
      the whole suite `01:14 +816: All tests passed!` (baseline 810 + this feature's six cases, exactly).

**Checkpoint**: all three surfaces obey one rule.

---

## Phase 6: The device walk (the rows the unit tests cannot hear)

**Purpose**: what the reader sees — the page settling one sentence early — read off `emulator-5554` as the app's own
evidence plus a still where the figures need a second eye.

- [x] T013 Walk `quickstart.md` row 10 into `specs/022-read-scroll-lead/breakpoint.md`: **re-take the baseline first**
      (011's row 7 on the current tree, quoting its own `viewport`), then walk row **24**: every report for a
      non-final sentence reads `below >= 1`, and the sentence's own geometry is inside the viewport. Proves FR-001,
      FR-002, SC-001
      — **DONE 2026-10-16** — the baseline re-taken first (011's row 7 on this tree and this build: `8 utterances | 8
      reports | viewport=196`, PASS — its receipt's `209` is not inherited, research §2), then row 24 walked:
      **PASS**, `every non-final report keeps a sentence below it: 7/7` and the content's last report `below=0`. The
      `before` is quoted beside it from the morning's run (four of the seven non-final reports ended at `bottom=196`,
      the viewport's own last pixel). Section and both runs' lines in `breakpoint.md`.
- [x] T014 Walk `quickstart.md` row 11 into `specs/022-read-scroll-lead/breakpoint.md`: the content's last sentence
      reads `below=0` with no move, and a text that fits the area produces a whole read with no movement. Proves
      FR-005, SC-003
      — **HALF DONE 2026-10-16, and left UNTICKED with the missing half named** — the content's last sentence is
      proven (row 24's own output: `below=0` and no move for it), and **the fitting-text half is not walked**: it needs
      its own fixture (a content shorter than the reading area, opened on this device), which 011's driver does not seed.
      The unit half of that criterion is 011's own unchanged case. `breakpoint.md` says the same in its own words, so a
      reader of the record finds the gap where the row is.
      — **DONE 2026-10-16 (its second half later the same day)** — 011's driver gained row **25**, which needs no new
      fixture after all: the shipped preset at the display's own size **and the app's own appearance** fits the reading
      area (011's own `set_viewport` docstring's premise, measured on the device as `viewport=657` against the tallest
      sentence's `bottom=198`). **PASS**, with both halves read: `every sentence inside the reading area at once: 8/8
      visible, the last's bottom=198 of viewport=657 — nothing to scroll`, and the highlight's own top row walking down
      the page (`[472, 628, 628, 628, 680, 840, 840]`, 7 stills) while the page's offset does not move. This row's own
      first attempt failed **on its own mechanics** (its second still was taken after the read ended, when the page has
      already cleared its highlight) — fixed by taking the stills while the read plays, and recorded here rather than
      left as a failure with no cause.
- [x] T015 `specs/016-sentence-reading/breakpoint.md`: re-run 016's own row **15** on the walked build and record
      the dated receipt there: the reveal it proves is the reveal this feature extends
      — **DONE 2026-10-16** — 016's row 15 re-run on the build that carries the rule: **3/3**
      (`⏭ ranges=[(0, 779)]`, `▶ ranges=[(0, 33)]`, both presses' frames `[(None, 0), (472, 64400), (472, 64400)]`), with
      the dated receipt in `specs/016-sentence-reading/breakpoint.md`. **Its first run failed for a reason this feature
      owned**: row 24 had left the display at 1080×1000, so a row written for a 1080×2400 screen tapped the wrong
      coordinates; row 24 now calls `reset_viewport()` like 011's own rows, and the re-run is after that reset.

**Walk checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`, no row cites a driver command
that does not implement it, and the baseline re-take is quoted beside the figures.

---

## Phase 7: Polish & cross-cutting concerns

- [x] T016 `specs/011-reading-experience/spec.md`: narrow its `FR-003`, dated — the page now moves in exactly one case
      it did not (a sentence being read that is fully visible **and** whose successor is the last visible one) — and add
      the note that this feature's `SC-001` is the stricter criterion its own `SC-001` no longer carries
      — **DONE 2026-10-16** — 011's `FR-003` carries its narrowing with the date and the link, and its `SC-001` carries
      the note that it is still true and no longer sufficient. 011's own artifacts are otherwise untouched.
- [x] T017 [P] `specs/011-reading-experience/tasks.md`: the dated pointer to `## Superseded by later specs`, naming
      this feature, its `FR-001`/`FR-002` and the case 011's rule no longer covers; 011's artifacts are left as written
      — **DONE 2026-10-16** — the dated bullet in 011's `## Superseded by later specs`: what is narrowed, what is
      re-walked, that its rows and receipts are left as written, and the two unit cases' own fate (one passes
      unchanged, one's suite reader was re-cut for the appended field).
- [x] T018 [P] `specs/022-read-scroll-lead/checklists/requirements.md`: the tasks-stage notes — the rows' own counts,
      the checkers' output, and what this stage found (nothing new about the app; the plan's own assumptions held)
      — **DONE 2026-10-16** — the checklist's implement-stage notes: the checkers' own output, the six findings the
      stage made (the anchored parser, US2's no-code bound, 011's case needing no re-cut, the two test-side failures,
      the driver bug, and the device's own before/after), and what is owed (T014's second half).
- [x] T019 [P] `specs/022-read-scroll-lead/spec.md`: record where the two no-move cases meet the spec's own wording —
      the `below=0` line for the content's last sentence, and the "a text that fits" case — in `FR-001`'s own words
      rather than leaving a reader to infer them from the edge cases
      — **DONE 2026-10-16** — `FR-001` now says the two cases a reader of the rule looks for: a text that fits
      already satisfies it, and the content's last sentence is the one exception (`below=0`, no move).
- [x] T020 Run `quickstart.md` row 12's structural checks into `specs/022-read-scroll-lead/breakpoint.md`:
      `flutter analyze` clean; the suite's count against this file's baseline decomposed by file; the four ARBs at the
      **same** 129 with `flutter gen-l10n` reproducing the tree's Dart; `test/*.dart`'s count; `git status --short
      android/ ios/` empty; `git diff --stat lib/video_pictures.dart lib/video_timeline.dart lib/video_painter.dart`
      empty. Proves FR-008, SC-006
      — **DONE 2026-10-16** — the structural row's own section in `breakpoint.md`, with the commands' output quoted:
      analyze clean, `01:14 +816` decomposed by file (`+5` the follow suite, `+1` the step suite), the four ARBs at
      **129** each (this feature adds no string), `test/*.dart` 57, `android/`+`ios/` empty, and the video's own three
      files untouched.
- [x] T021 `specs/022-read-scroll-lead/tasks.md`: re-take the whole tree's receipt into this file's `## Status` —
      `flutter analyze` and `flutter test --concurrency=2` on the finished tree beside the baseline with the difference
      decomposed by file, tick every row above, then re-run all six checkers and quote their own output
      — **DONE 2026-10-16** — this file's `## Status` carries the finished tree's receipt beside its baseline, and
      the six checkers are quoted in the checklist's implement-stage notes. **One row is deliberately NOT ticked**
      (T014, half-done) and the Status counts it as such — 14 of 22.
- [x] T022 [P] `specs/022-read-scroll-lead/spec.md`: the closing note on the two answers of 2026-10-16 — that the first
      (`1A`) was revised by the reader's own restatement before any code was written, and that the walk's figures are
      read against the rule as it now stands, so no receipt was ever taken on the withdrawn reading
      — **DONE 2026-10-16** — the closing note in the spec's `## Clarifications`: the first answer was revised
      **before any line of this feature was written**, so nothing in this record — code, cases or walk — was ever
      measured on the withdrawn reading, and no receipt needed re-taking.

**Checkpoint**: analyzer clean, the suite's count recorded against the baseline, the six checkers quoted green, and the
working tree holding only intended edits.

---

## Dependencies & ordering

- **T001 → T013/T014**: the driver's dispatch is the row's contract; the walk rows cite it.
- **T002 → T003 → T004**: the field's case is RED before it exists, and the parser's case is what keeps a closed
  feature's driver reading the same line.
- **T003 → T005/T006**: the rule's own cases read `below`, so the field lands before US1's implementation.
- **T005 → T006 → T007**: the cases first, then the rule, then the re-cut of 011's own case.
- **T006 → T008/T011**: US2's minimality and US3's step both build on the same helper; their cases are written
  against it.
- **T009 → T012**: the bound is in the helper, so the step's rows inherit it rather than restating it.
- **Phase 6 depends on Phases 3-5**: a device row drives the surface the code has.
- **T015 after T013/T014** (one device, one build) and **T016-T019 are [P] once the code has settled**; **T021 needs
  everything**, and T022 is the closing note beside it.

## Parallel opportunities

- **T001, T002 and T004** touch a driver, an implementation's case and a parser case: three files, no dependency
  between them; T003 waits on T002.
- **T008 and T011** are two different suites (the follow's, the step's) and touch no common file.
- **T016, T017, T018, T019 and T022** are five different artifacts across two features.
- **Nothing in Phase 6 is parallel**: every row drives the same device and they append to one `breakpoint.md`.

## Implementation strategy

The MVP is **Phase 2 + Phase 3**: the line's own fact and the rule's own trigger — demonstrable on the device with
011's re-walked row 7 and row 24 alone. **Phase 4** is what keeps the page calm (the smallest rect, the bound that
keeps the reading sentence on screen), **Phase 5** puts the ▶ step under the same rule, and **Phase 6/7** are the
receipts. Nothing in the tree is touched before T002's RED is quoted.

## Notes

- **The trigger is one sentence early (`1B`)**, and every row that reads a report's own geometry expects the move at
  the sentence **before** the last-visible one. A row that finds itself moving at the last-visible sentence has
  implemented the withdrawn reading (`1A`).
- **The rule is positional**: "is a sentence after this one visible", never "is this sentence within N px of the
  bottom".
- **The window is gone**: a row that reads the reveal's own animation running while the *last-visible* sentence's voice
  begins has moved the trigger back.
- **A sentence taller than the viewport** is left alone and said so (Edge Cases); the walk's fixture is far from it
  (sentences ~28 px against a ~196 px area).
- The device rows must not depend on a fixed sleep for a state that takes a moment: poll the dump to a deadline (011's
  own mechanic), and read the paint only where the geometry cannot answer (the step row's own `yellow_rows` lesson of
  2026-10-16).

---

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (a sentence after the one being read stays visible; the content's last sentence excepted) | T005, T006, T013, T019 |
| FR-002 (the move starts before that sentence's highlight and voice — one sentence early, `1B`) | T005, T006, T007, T013 |
| FR-003 (011's own reveal, and no further than the rule needs) | T008, T009, T014 |
| FR-004 (once per sentence; a hand scroll stands until the next sentence) | T010 |
| FR-005 (no move for the content's last sentence, for a read starting at it, or for a text that fits) | T005, T014, T019 |
| FR-006 (the same rule where the page moves the read on itself — 016's step advance) | T011, T012 |
| FR-007 (a read from a stored position obeys the rule from its first sentence) | T005, T013 |
| FR-008 (nothing else changes: no key, no state, no platform, the video untouched) | T020 |
| FR-009 (the line reports how many sentences are visible below the reported one) | T001, T002, T003, T004, T013 |
| SC-001 (every non-final report keeps a sentence below it, on the device) | T005, T013 |
| SC-002 (the move's own evidence precedes the sentence it is for) | T005, T013 |
| SC-003 (a text that fits, and the content's last sentence, move by zero) | T005, T014 |
| SC-004 (a hand scroll stands to the end of its sentence) | T010 |
| SC-005 (each move is bounded and leaves the reading sentence on screen) | T008, T009 |
| SC-006 (analyze, the suite against the baseline, the ARB counts unchanged) | T020, T021 |
| SC-007 (a step's advance leaves a sentence ahead of the new highlight) | T011, T012 |

## Amendment 4 — the regression sweep's own findings (2026-10-16, after the closing)

The sweep re-ran the neighbouring features' device rows on the finished build, because this feature changes a shared
method (`_revealRange` → `_scrollToRect`) and appends a field to 011's own evidence line. Its outcome — every verdict,
the control run, and the two reds the control puts outside this feature — is written out in `breakpoint.md`. What it
leaves behind is two rows of work, both named here rather than fixed in a hurry at the end of a long session:

- [x] T023 [P] Re-cut `specs/011-reading-experience/scripts/klhu_walk_experience.py`'s own row 20 so its long-press
      point is measured **after** the read that moves the page, re-walk it (`… 20`), and write the receipt into
      `specs/011-reading-experience/breakpoint.md` beside its dated note. **Owed because this feature moved it**: the row passes with the lead disabled and fails with it
      (both runs quoted in `breakpoint.md`), which is the narrowing of 011's `FR-003` working as recorded — a row that
      measures a point before a read is entitled to be wrong. The row's own subject is intact; only its own timing is.
      — **DONE 2026-10-16 (the evening of the sweep)** — `scenario_20`'s own point is now derived **per gesture**, from a
      page first returned to its own top (`back_to_top`, two downward swipes), instead of once before the read: with a
      read that moves the page, "the same line" was no longer the same device point, and the held point landed on the
      next paragraph. Re-walked on the build carrying the rule — **PASS**: `▶ sentence : (112, 159) (the paragraph
      holding it: 65..199)`, `HOLD the page the same line, held @62,758`, `▶ paragraph: (65, 199) (the paragraph is
      65..199)`. The row's subject is untouched and its own receipt is in `specs/011-reading-experience/breakpoint.md`.
- [x] T024 [P] Triage into `specs/011-reading-experience/breakpoint.md` and `specs/016-sentence-reading/breakpoint.md`,
      each with its own verdict quoted, the sweep's two reds the control run puts outside this feature: 011's row 23 (**proved** not this feature's — it fails with the lead disabled too, and it reads a
      `read_position` pref that `grep -rn "read_position" lib/` does not find anywhere) and 016's row 9 (**not
      control-tested** — red in the render's own slot spans, a part of the tree this feature never touches; the same
      control run is what would attribute it).
      — **DONE 2026-10-16 (the evening of the sweep)** — both non-022 reds are now **control-proved** and carried in
      their own records with their verdicts:
      **011's row 23** — the same tree with the lead disabled keeps it failing, and its cause is measured: its checks
      read a stored position (`stored_offset()` → `stored_position()`) that the app does not write under any name — the
      device's prefs hold **only** `flutter.reading_appearance`, and `grep -rn "read_position" lib/` finds nothing: that
      record was withdrawn (010's `FR-008`, per 016's decision 5), and **016 amended this file's row 20 for exactly that
      on 2026-10-12 while missing row 23**. Owed the same re-cut (read what the tap puts in force), recorded in
      `specs/011-reading-experience/breakpoint.md`.
      **016's row 9** — control-tested the same way: with the lead disabled its three failures are identical
      (`slot 0's span starts at 0, the step is at 17`, `span 0..15 against (17, 50)`, `text=15 for the sentence's 33`),
      so the red is inside the render's own slot spans (012's path), which this feature never touches. Recorded in
      `specs/016-sentence-reading/breakpoint.md`.
      **Both were then re-cut the same evening, and neither was an app defect**: 011's row 23 now witnesses its anchor
      through the app's **live range** (▶'s and ⏭'s own presses) instead of the withdrawn record — **PASS**; 016's row 9
      now pins **020's own requirement that a video is the whole content** (added 2026-10-14: the render opens on the content's first sentence whatever the page shows, which is what
      the app has done since 2026-10-14) — **PASS (11/11)** with **no app change in either case**. 012's own requirement that a video
      starts where the page's position is — the one row 9 was asserting — carries the dated supersession note it never had, because a reader of that file
      otherwise finds a live requirement the app must not satisfy. **The same sweep found four checks in 011's driver
      that could not fail** (they asked the withdrawn record to be empty, or compared two always-empty lists): the three
      in rows 20/21 and the one in row 17 are retired with dated notes naming their live witnesses, and those rows were
      re-walked (20 PASS, 21 PASS, 17 PASS) — a check that reports PASS for nothing is worse than no check. 014's own
      driver reads the same withdrawn record in its **evidence prints** (not checks): recorded in its
      `breakpoint.md` rather than edited, because editing its driver would invalidate its own receipts.
