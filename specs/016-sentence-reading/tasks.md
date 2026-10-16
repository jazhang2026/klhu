# Tasks: Sentence-by-sentence reading

**Feature**: `016-sentence-reading` | **Date**: 2026-10-12
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

**Grounding revision**: `409ffe1` — every line number below was read on that tree by this stage, not
carried over from the plan's table. Two of that table's own lines are corrected in § The stage's
corrections below.

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (one press, one sentence, at the reader's own pace, P1), `US2` (a
step leaves nothing behind, P2). Tasks with no story label are shared infrastructure, another feature's
records, the walk, or the receipts.

**`quickstart.md` exists as of 2026-10-12 and owns the walk's contract**: 016's plan stage handed back
`spec.md` + `plan.md` alone (the plan folds research into itself, and its §4 carries this feature's cases), so
`specs/016-sentence-reading/quickstart.md` was written at the review gate that followed this list — 14 rows, of
which 1-4 are `[unit]` (mirroring T002/T006-T008/T013-T014) and **5-11 the `[device]` rows** (T024-T030, one
row per row, dispatched by the driver under the quickstart's own row numbers).
`specs/016-sentence-reading/breakpoint.md` is created by the first row that walks. Nothing in this list was
re-cut to fit it.

## Status

**34/34 done (2026-10-12) — the implement stage is complete.** Phases 1-7 are closed: the stepper and the pure
rule, the record's retirement, the five other-feature records it made false, and the device walk — rows 5-11 all
PASS, 5-9 through this feature's own driver, 10 through 011's (two of its checks re-cut in place, dated) and 11
through 010's (its rows 9/14 replaced by this list's row 8). The walk's own record is
`specs/016-sentence-reading/breakpoint.md`. T005's own row says which of its two
pieces moved into T010/T011 and why.

**The baseline — T001 ran it before this feature's first edit** (the emulator being up can make plain
`flutter test` segfault on this host, so the house command is used):

```
flutter analyze                          → No issues found! (ran in 25.8s)
flutter test --concurrency=2             → 636 passing, 0 failing   (01:06  +636: All tests passed!)
test/*.dart files in the tree            → 49
```

That 636 is **this feature's baseline and its regression gate**: 016 adds cases and deletes a file and a
record, so the count at T033 is *not* compared to 636 as an equality — it is read against 636 with the
difference decomposed by file (T033's own job, and the reason T001 writes the number down before the first
edit).

**The tree reads 643 passing, 0 failing** (`flutter analyze` → **No issues found!**, 0.8 s) — T001's 636 plus
**16** cases of this feature's own, each measured **per file** rather than derived from the total:

```
flutter test test/comment_test.dart            → 00:00 +42   (015's shipped 32 + the 10 of T002)
flutter test test/reading_view_step_test.dart  → 00:02 +11   (T006's four, T007's two, T013's three, T014's two)
flutter test test/reading_view_continue_test.dart → 00:05 +16 (010's own, after T017's re-cut)
flutter test --concurrency=2                   → 00:57 +643: All tests passed!
```

That 643 is Phase 3's 652 + this pass's five new cases − eleven (the store's own file, deleted) − two (the
restore group's three cases became one) − one (011's seeded follow case, replaced) — and it is read against
T001's 636, never as an equality. Phase 2's seams added no case, and Phase 3's and Phase 4's re-cuts changed
shipped cases rather than adding any: the per-file numbers above are where a reviewer checks that. **The record
is gone from the tree**: `grep -rn read_position lib/ test/` names only three `isNull` assertions that exist to
catch its return, one dated note, and `test/appearance_store_test.dart:81`'s literal.

**Format checker**: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/016-sentence-reading`,
re-run **2026-10-12** after this pass's last tick and quoted verbatim:

```
tasks.md: 34 tasks (34 done), 5 marked [P]
  (setup/foundational/polish): 21
  [US1]: 7
  [US2]: 6

OK: format, sequencing and spec-id coverage check out
```

`task_id_audit.py specs/016-sentence-reading` → `016-sentence-reading: 34 tasks, 34 done, 5 [P]`, no duplicate,
gap or out-of-order id. T034 re-quoted both after this file's closing edit — the counts it prints are the ones
above — and § The stage's corrections item 4 holds the same pair from the stage's own pass (0 done at the time).

**Suite**: the feature's own cases are one new file (`test/reading_view_step_test.dart`, T006-T008,
T013-T014) plus one new group in `test/comment_test.dart` (T002); the shipped files this change re-cuts or
deletes are named one by one in T008 and T017-T018, and **no shipped file is re-cut without being named
there** — that is the claim those rows exist to keep honest.

**Device rows**: `specs/016-sentence-reading/quickstart.md`'s rows **5-9** (this feature's own, walked through
`specs/016-sentence-reading/scripts/klhu_walk_step.py`), **10** (011's rows 7/8/10/20 re-walked through 011's own
driver) and **11** (010's rows 13/15/16 re-walked, with 010's rows 9/14 replaced by T019's amendment row); every
row appends to `specs/016-sentence-reading/breakpoint.md`. **All of them are walked and green**: rows 5-9
through this feature's own driver (the stepper, the comment half, ⏭ after a step, the clean relaunch, a render
from a step's position), row 10 through 011's (two of its checks re-cut in place and dated), row 11 through
010's (rows 13/15/16, with 010's 9/14 replaced by this list's row 8). Artifacts under `/tmp`:
`016_row5_press{1,2,3}.png`, `016_row5_end.png`, `016_row8_{step,tap}_relaunch.png`, `016_row8_tap.png`,
`016_row9_step.mp4`.

## The stage's corrections

Four things this pass found by reading the tree and the artifacts against each other. Each is a claim a
reviewer should re-check, and each is *fixed* in this same pass rather than reported and left standing.

1. **The plan's §3.7 under-counts decision 5's ripple by a wide margin — and this is the biggest item in
   the list.** §3.7 names `_restoreAnchor`, `_persistAnchor`, the `read_position_*` key, "the `Positions` /
   `ReadingPosition` types" and two records (010's rows 9/14, 011's row 8). The tree says more:
   - the store's own file and its 11 cases: `lib/read_position_store.dart` (`ReadingPosition` at `:11`,
     `ReadPositionStore` at `:38` — **the plan calls it "the `Positions` store"; the class is
     `ReadPositionStore`**), used only at `lib/reading_view.dart:18`, `:385`, `:1032`;
   - **six shipped test files**, not two: `test/read_position_store_test.dart` (the contract's own 11 cases,
     gone with the file), `test/video_aspect_test.dart:11`/`:85-96` (a **compile error** — its namespace case
     calls `ReadPositionStore.keyFor`), `test/reading_view_continue_test.dart` (the restore group `:441-...`
     plus the record helpers at `:180`, `:453`, `:471`, `:484`), `test/reading_view_follow_test.dart:405` (a
     case that **seeds** a record and asserts it is restored), `test/reading_view_dialogue_test.dart:250`
     (`expect(afterTap, isNotNull)`), `test/reading_view_comment_test.dart:273`/`:290` and
     `test/reading_view_new_content_test.dart:195`/`:211` (each asserting the record's value);
   - two doc comments that name the retired type: `lib/appearance_store.dart:132`, `lib/video_aspect.dart:54`
     and `:65`;
   - four more features' records besides 010's and 011's: `specs/010-continue-read/contracts/read-position-format.md`
     (the contract itself), `specs/011-reading-experience/contracts/appearance-format.md:23`/`:28`/`:51`,
     `specs/014-dialogue-reading/` (breakpoint rows citing `read_position_dialogue_fixture` at `:386`,
     `:408`, `:413`, `:416`, `:420`, `:421`, `:425`, `:426`, `:429`, plus
     `specs/014-dialogue-reading/data-model.md:257` and `specs/014-dialogue-reading/quickstart.md:353`) and
     `specs/015-comment-tag/data-model.md:180`.
   Those are now T016-T018 (code and tests) and T019-T021 (the records), and the plan's §3.7 has been
   corrected in the same pass to carry them.
2. **Three lines still carry the pre-amendment wording** (the reader's 2026-10-09 corrections were applied
   to FR-008/FR-013/FR-007 but not to the prose that repeats them): the plan's §2.3 (`_hint = nothingToReadMessage`
   at the text's end, which FR-008 and the plan's own §2.5 say never happens), the plan's §4 case 2 ("the
   end-of-text message is up (SC-002)") and `spec.md`'s decision 2 ("say the text has ended", with a cost
   line about a new message key the amendment removed). All three are corrected in this pass; the spec's
   correction is dated in place, because FR-008 and decision 2 currently contradict each other and the
   implement stage reads both.
3. **The baseline was not known to this file before this pass** (`quickstart.md` — where 010-015 carry it —
   did not exist yet when this list was written): it is measured above, T001 re-takes it, and
   `specs/016-sentence-reading/quickstart.md` now carries the same figure in its Prerequisites (item 5).
4. **Both list checkers run clean on this file** (T034 re-quotes them after the closing edit):
   `check_tasks_format.py` → `tasks.md: 34 tasks (0 done), 5 marked [P]` with the per-story block and
   `OK: format, sequencing and spec-id coverage check out`; `task_id_audit.py` → `016-sentence-reading: 34
   tasks, 0 done, 5 [P]`, no duplicate, gap or out-of-order id.
5. **The two artifacts the plan stage owed are written, dated 2026-10-12, at the review gate that followed this
   list**: `specs/016-sentence-reading/quickstart.md` (the walk's own contract and the unit rows' steps — this
   list's Phase 6 cites its rows 5-11) and `specs/016-sentence-reading/checklists/requirements.md` (the specify
   stage's gate, which the implement stage reads). Neither was written in its own stage, and both say so at
   their head. Two deviations that checklist records for a reviewer to act on: the spec has no
   `## Clarifications` section (the 2026-10-09 round is recorded in its `Input` block and its decisions), and
   `.specify/feature.json` is still pinned at `specs/015-comment-tag` — re-pin it before any repo script runs.
   The spec's own correction (item 2, `spec.md`'s decision 2) is dated in place and carries the reader's
   words.
6. **The stage's four checkers, this pass's own run** (taken before the paragraph you are reading was added;
   T034 re-quotes the two list checkers after this file's closing edit):

   ```
   check_quickstart_coverage.py specs/016-sentence-reading            (exit 0)
     spec.md     : 14 FR + 5 SC defined
     quickstart  : 14 rows ([unit] 4, [device] 7, [structural] 3, untagged 0)
     unclaimed   : none
     no 'Proves' line: none

   spec_consistency.py specs/016-sentence-reading                     (exit 0; no fenced block diverges)
     FRs 14 · SCs 5 · stories 2 · scenarios 11 (US1 6, US2 5) · 6 bullets in User Scenarios (the edge cases)

   check_artifact_refs.py specs/016-sentence-reading
     documents checked 5 · scenarios in quickstart.md 14 · test/*.dart files in the tree 49
     unresolved 18 — every one of a tolerated class, none a false claim about this stage's own artifacts:
       · another spec's ids quoted in prose (011's FR-018/021/023/024/025, and `A1` in the checklist's shape
         note) — the script's own docstring says prose legitimately cites a sibling's ids. **2026-10-16, and the
         class still stands**: this file's entries were left exactly as written when a later feature's stage hit
         the same rule and wrote *its* citations in words (`specs/022-read-scroll-lead`) — the two readings are
         not in conflict, and neither is an error; what this amendment's own row cites is this feature's ids and
         the app's own lines;
       · a file this list creates and has not run yet (`test/reading_view_step_test.dart`,
         `specs/016-sentence-reading/scripts/klhu_walk_step.py`) — 015's plan cited `lib/comment.dart` the same
         way before its own T004 wrote it;
       · `spec.md`'s two cites written without `lib/` (`reading_view.dart:1052`, `video_timeline.dart:128`) —
         the identical shape 011's and 015's reviewed specs carry unresolved (3 in 015's whole directory, 12 in
         011's), so the reviewed record is left as the reader approved it.
   ```

7. **Two things Phase 2's implementation found, both corrected in the artifacts in the same pass.**
   - **`stepEnd` needs a second helper beside it.** The plan's §3.1 named one (`stepEnd`) and had the advance
     search `sentenceRanges(_content)` directly. Over the **tagged** text that list holds a range *inside* the
     comment (`Hola. [注] Hi.` yields `[注] Hi.`), and for a comment-headed text its first range is the comment's
     own characters — whose tag would then reach the engine, which 015 FR-005 forbids. A `>=` search off
     `stepEnd` cannot repair that either, because the first press takes the list's **first** range. So
     `lib/comment.dart` gained `stepRanges(text)` — the app's own sentences minus the ranges a comment's
     characters occupy — and T010 reads its candidates from it. The plan's §3.1 carries the correction.
   - **`_select` carries the selection, not the record.** The plan's §2.1 said the factored helper sets "the
     highlight, the anchor and the record"; decision 5 retires the record (T015), so a seam that wrote it would
     be work the next phase deletes. `_select` sets the highlight, the anchor and the read generation, and
     `await _persistAnchor()` stays at the gesture's own call site until T015 removes it. The plan's §2.1
     carries the correction.

## Grounding notes (decisions these tasks implement)

1. **The step is a range, and the range is the record of what was read** (spec FR-004/FR-006, plan §2.2/§2.3):
   ▶ does not need `track` — the advance is computed from the step's own range end against
   `sentenceRanges(_content)`, the same rule the read uses, so no step crosses a blank line.
2. **The step's range is the step, not the sentence** (plan §3.1, spec FR-005): 015 speaks a comment only
   when the read's range covers the comment's own span (`lib/speech_resolver.dart:190`), and a comment's span
   begins after its sentence's last character — so a step scoped to the sentence drops the comment silently,
   on exactly the texts that use it. T003's `stepEnd` is that fix, and T007 is its test.
3. **A step is durably in force inside the session and gone across a restart** (spec FR-007, decision 5,
   the reader's own `(B) 谁都别留,重启一律干净`): `_anchor` and `_clearAnchor` stay (010 FR-002/FR-004/FR-005 in
   memory); the write path, the restore path, the key, the store and its types retire — a record nothing
   restores is dead code, and this repo does not keep dead code (T015-T016).
4. **The end of the text is silent** (spec FR-008, the reader's own "user can see it"): nothing is shown.
   **Stop, an edit, leaving the page and the end of the text still clear the highlight** (FR-009) — the
   mitigation that makes 011 FR-022's narrowing survivable.
5. **The paragraph press keeps its meaning** (spec FR-003, plan §3.2): it uses `step == true` for the
   "do not clear" half only, and its advance is a no-op because the unit is the paragraph — the branch is
   deliberate, not incidental.
6. **⏭ is untouched** (plan §3.3): `_readContinue` keeps `track: true, step: false`, reads to the end and
   still drops the highlight and the position when it ends. The shipped case asserting exactly that
   (`test/reading_view_continue_test.dart:302`, "tracking follows the read, and the read takes the position
   with it") **stays unmodified**.
7. **One key leaves, nothing takes its place** (spec FR-013, plan §2.6): `selectToReadMessage`, used at
   exactly one place, `lib/reading_view.dart:1062`; the count moves **108 → 107** (counted in the four ARBs
   on `409ffe1`), and 015's row 16 receipt — walked against 108 — is corrected with its date in 015's own
   record (T022).
8. **Another feature's records are corrected, never deleted quietly** (plan §3.7, 015's own rule): 010's
   FR-008 is amended in 010's own record with its date and beside the ask that reversed it; 011's FR-022
   keeps its condition and loses its false last clause; a receipt that only *cited* the retired record keeps
   its behaviour and gains a dated note (T019-T021).
9. **Verification is the tree's own shape**: each story's cases are written and run RED before that story's
   code, then one device walk covers what a unit test cannot hear, then 010's and 011's own receipts are
   re-run as structural rows. A compile error counts as RED — say so when it is one.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/016-sentence-reading/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up can
  make plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated files are
  part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; this feature's walk
  driver is `specs/016-sentence-reading/scripts/klhu_walk_step.py`, its fixture beside it at
  `specs/016-sentence-reading/scripts/klhu_step_fixture.txt`
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/016-sentence-reading`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the number every later tick is read against. Nothing is installed — this feature adds no
dependency, no asset and no platform file (spec FR-014, plan §6).

- [x] T001 Record the baseline in `specs/016-sentence-reading/tasks.md`'s Status before touching anything:
      `flutter analyze` (expect `No issues found!`) and `flutter test --concurrency=2` (expect **636 passing,
      0 failing** — this file's Status figure) on `git rev-parse --short HEAD` (`409ffe1` as this list was
      written), then write both numbers, the command and the date into the Status section. If the count
      differs, that difference is the first thing the handback reports: a drifted baseline is the reason
      every later tick would be measured against the wrong number.

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the one pure rule and the three seams every story's branch stands on. Each seam is a
**behaviour-preserving** move of code that already exists, which is why the checkpoint below is that no
shipped test moves at all — a stronger claim than "the tests pass".


      **DONE 2026-10-12, before this feature's first edit** (the baseline has to run before any change, so it
      ran first, as the row asks): `flutter analyze` → **No issues found!**, `flutter test --concurrency=2` →
      **636 passing, 0 failing** (`01:06 +636: All tests passed!`) on `409ffe1`, with 49 `test/*.dart` files in
      the tree. Measured 2026-10-12 by the tasks stage before writing this file and re-read here — no drift
      against the Status figure, which is also `quickstart.md`'s Prerequisites number.
- [x] T002 [P] Write the pure rule's cases into `test/comment_test.dart` (a NEW group appended — "a step's
      own end (016)" — with none of 015's own cases touched): `stepEnd(content, commentsRead, sentence)`
      returns the sentence's own `end`; with the comments being read and the sentence the **owner** of a
      comment (015's `ownerStart`/`ownerEnd`), it returns that comment's `contentEnd`; with the comments off
      it returns the sentence's end; a sentence whose paragraph carries a comment belonging to an **earlier**
      sentence is not extended; a sentence after the comment in the same paragraph is itself; and a text with
      no comment answers every sentence's own end. Run it and keep the RED output.
      **RED expected as a compile error**: `stepEnd` does not exist yet — say so when the RED is one.

      **DONE 2026-10-12** — the new group "a step's own end (016)" appended to `test/comment_test.dart`: **10
      cases**, written from the spec's own examples (the helper builds its segments by `indexOf`, so no case
      carries a hand-counted offset): a sentence with no comment either way, an inline comment extending its
      owner only while it is read, a comment in its own paragraph, a comment after a later sentence of the same
      paragraph, a sentence in a later paragraph, every sentence of a tagless text, and the four candidate
      cases (a tagless text, an inline comment, a comment at the text head, and the next step starting after
      the step's own end). 015's own 32 cases are untouched.
      **RED receipt: a LOAD error, not an assertion failure** —
      `test/comment_test.dart:469: Error: Method not found: 'stepRanges'` (four sites) and `:486`/`:487:
      Error: Method not found: 'stepEnd'`, ending `00:00 +0 -1: Some tests failed` with
      `loading /…/test/comment_test.dart`: what a RED for a not-yet-written module looks like here.
- [x] T003 Implement `stepEnd` in `lib/comment.dart` (next to 015's own rule, and given the free function
      its own doc comment naming why it exists): the sentence's own end, or its own comment's `contentEnd`
      when the comments are being read and that sentence is the comment's owner. Green against T002.
      **Checkpoint**: `flutter test test/comment_test.dart` green, 015's own groups unmoved.

      **DONE 2026-10-12** — `lib/comment.dart` gains **two** functions, not the one the plan named (§ The
      stage's corrections item 7 says why): `stepRanges(text)` and `stepEnd(text, commentsRead, sentence)`.
      **42/42 green** (`flutter test test/comment_test.dart` → `00:00 +42: All tests passed!` — 015's 32 plus
      the 10 new), and all ten went green on their **first** run: no case was corrected against the code.
- [x] T004 Factor the gesture's selection out of `lib/reading_view.dart` into one `_select(TextSegment)`
      (`:1004-1014` today: `_highlight`, `_anchor`, and the record write that T015 retires), so the gesture
      and ▶ set a selection through the same code (plan §2.1). Behaviour-preserving.

      **DONE 2026-10-12** — `lib/reading_view.dart`'s `_resolveAt` tail is now `_select(segment)`
      (`lib/reading_view.dart:1016-1035`), body for body: the same `setState` (the read generation, the mode,
      the highlight, the anchor, the cleared error and hint). `await _persistAnchor()` stays at the gesture's
      own call site, which is why `_select` carries the selection alone.
      Behaviour-preserving: `git diff --stat test/` → empty, and the suite's count is T001's 636 plus T002's
      ten cases and nothing else.
- [x] T005 Give `lib/reading_view.dart`'s `_readRange` (`:1077`) the `step` parameter and factor
      `_revealRange(TextSegment)` out of `_followRead` (`:1142-1145`), with `_followRead` calling it
      (plan §2.2/§2.4) — 011 FR-002 and 016 FR-012 must reveal by one code path or a step's next sentence can
      be off screen while the highlight is on it.
      **Checkpoint**: `flutter analyze` clean; `flutter test --concurrency=2` = T001's count; `git diff --stat
      test/` → **empty** (both seams moved code and nothing else).

---

## Phase 3: User Story 1 — One press, one sentence, at the reader's own pace (P1) 🎯 MVP

**Goal**: ▶ reads exactly one unit per press and leaves the highlight on what the next press will read. With
nothing highlighted it starts at the first sentence; with a sentence it reads that sentence; with a paragraph
it reads the paragraph. When the read ends by itself the highlight moves **ahead** instead of clearing.

**Independent Test**: with a three-sentence content open, press ▶ four times: the first three presses read
sentences 1, 2 and 3 in order and each ends by itself; the fourth reads nothing, clears, and says nothing.

### Tests for US1 ⚠️ (write first, run RED)


      **DONE 2026-10-12 — landed in part; the remainder re-cut into T010 and T011 in this same pass.** What
      landed: the measurement is generalized to a content range (`_measureSpan(start, end)`,
      `lib/reading_view.dart:1263`, with `_measure` a one-line delegate) and the reveal is one doorway
      (`_scrollIntoView(geometry)`, called by `_followRead`) — 011 FR-002's behaviour, unchanged, still green in
      every follow case.
      What could not land here, and why: `_readRange`'s `step` flag and `_revealRange` have **no caller** until
      US1's advance exists, and the analyzer says so —
      `warning • A value for optional parameter 'step' isn't ever given` and
      `warning • The declaration '_revealRange' isn't referenced` while they sit here alone. This repo does not
      keep dead code, so they moved to the rows that use them (T010 the flag, T011 the reveal), and both rows
      were re-cut in this pass to say what they now carry.
      **Checkpoint**: `flutter analyze` → **No issues found!** (0.8 s); `flutter test --concurrency=2` →
      **646 passing, 0 failing** (`00:55 +646: All tests passed!`) = T001's 636 + T002's 10;
      `git diff --stat test/` names `test/comment_test.dart` alone.
- [x] T006 [US1] Write `test/reading_view_step_test.dart` (new file) from plan §4's cases 1-3: N presses of ▶
      read sentences 1..N in order, one per press, each ending by itself (SC-001); after each press the
      highlight sits on the **next** sentence, and after the last nothing is highlighted (FR-004, SC-002); a
      paragraph selected by a long press is read as a paragraph and stops there (FR-003). Run it and keep the
      RED output (on the base, press 1 speaks nothing and paints the warning).
      **DONE 2026-10-12** — `test/reading_view_step_test.dart` (new file), its US1 group written first: "each
      press reads one sentence, in order, and stops" (SC-001), "the highlight sits on the NEXT sentence, and is
      gone at the end" (SC-002, FR-004, FR-008), "with nothing highlighted · read the first sentence" (FR-001)
      and "a long press reads its paragraph and leaves it highlighted" (FR-003).
      **RED receipt: assertion failures with the base's own numbers** — `Expected: ['The sun rose over the quiet
      town.'] Actual: []` (the press spoke nothing), `Expected: <1> Actual: <0>` (no speech was handed over),
      `Expected: true Actual: <false>` (no highlight painted) — against the page that answers ▶ with 011
      FR-023's warning.
- [x] T007 [US1] Extend `test/reading_view_step_test.dart` with §3.1's own case — the first thing this
      feature must not get wrong: a content whose sentence carries a comment reads the sentence **and** the
      comment in one press, and the next press starts at the sentence **after the comment** (FR-005, SC-004),
      with a same-paragraph comment (015 allows it) and a paragraph-boundary case pinned beside it (plan
      §5 risk 2). Run it and keep the RED output.
      **DONE 2026-10-12** — the comment group (2 cases) in the same file, over two contents this file builds
      (`Hola.\n\n[注] How are you?\n\nAdiós.` and the inline `Hola. Adiós. [注] Fine.`): one press reads the
      sentence **and** its comment and the next press starts after the comment (`['Hola.', 'How are you?']` then
      `['Adiós.']`), and the inline comment rides the sentence before it (`['Hola.']` then `['Adiós.', 'Fine.']`).
      RED was the same shape (`Expected: ['Hola.', 'How are you?'] Actual: []`); both green with T010 — this is
      the case the feature exists not to break.
- [x] T008 [US1] Re-cut the three shipped cases that assert ▶'s warning in `test/reading_view_test.dart:199`
      (its assertions at `:225-226`), `test/reading_view_test.dart:229` (`:263-264`) and
      `test/reading_view_edit_test.dart:195` (`:217-218`) to "▶ reads the first sentence and highlights it"
      (FR-001 amends 011 FR-023). **Proves they are RED on the base** — the base paints the warning — and the
      two `findsNothing` cases beside them (`test/reading_view_edit_test.dart:223`,
      `test/reading_view_video_test.dart:558`) stay **unmodified**.

### Implementation for US1

      **DONE 2026-10-12** — the three cases re-cut, their names now saying what they assert:
      `test/reading_view_test.dart` "Read with nothing selected reads the first sentence" and "Read after a stop
      starts at the first sentence again" (FR-009), and `test/reading_view_edit_test.dart` "Read speaks the
      pending sentence, and the first one when there is none" (the tap-then-read half kept, `fake.spoken` now
      `[_firstSentence, _firstSentence]`). All three were **RED on the base in T006's own run**
      (`Expected: ['The sun rose over the quiet town.'] Actual: []`, three files). The two `findsNothing` cases
      beside them (`:223` and `test/reading_view_video_test.dart:558`) stay unmodified and no other shipped case
      moved.
      **Two corrections the run forced, both settled by an artifact rather than by the code**: (1) the re-cut
      first asserted that the just-read sentence stays painted — decision 1 (A) with FR-004 says the highlight
      points at what the **next** press reads, so it now asserts the first sentence is no longer painted and the
      second one is; (2) an `expect(fake.isSpeaking, isFalse)` was dropped because `FakeReader.speakParagraphs`
      sets `speaking = paragraphs.isNotEmpty` and never clears it — it measures the fake's bookkeeping, not the
      page's.
- [x] T009 [US1] Give `lib/reading_view.dart`'s `_readSelection` (`:1048-1059`) its three branches: nothing
      highlighted → `_select(firstSentence)` (`sentenceRanges(_content).first`) and read it (FR-001); a
      sentence → read exactly it (FR-002); a paragraph → read it and stop (FR-003). The message branch
      (`:1050-1057`) goes with this row — it is FR-013's code half, and its key can only be dropped after it
      (T012). Green against T006/T008.
      **DONE 2026-10-12** — `lib/reading_view.dart`'s `_readSelection` is three branches: nothing highlighted →
      `stepRanges(_content).first` put in force by T004's `_select` and read (FR-001), with an **empty text**
      still answering `nothingToReadMessage` (010's row 7 — FR-008's silence is the END of a text that had
      something to read, not an empty one); a sentence → read exactly it (FR-002); a paragraph → read it whole
      and stop (FR-003). The message branch went with it, which is what lets T012 drop the key. Green against
      T006/T008.
- [x] T010 [US1] Read the **step** rather than the sentence in `lib/reading_view.dart`: `_readSelection`
      passes `_readRange(seg.start, stepEnd(_content, _roles.commentsRead, seg), step: true)` (FR-005 through
      T003's helper), and the paragraph branch passes `step: true` for FR-004's "do not clear" half only
      (plan §3.2). Green against T007.
      **(Re-cut 2026-10-12 by Phase 2's pass)**: this row also lands `_readRange`'s `step` flag — T005 factored
      the seam but could not keep the flag, which had no caller and the analyzer rejected as dead code — and the
      step candidates come from `stepRanges(_content)` (T003's **second** helper, § The stage's corrections item
      7), not from a raw `sentenceRanges(_content)` call: over the tagged text that list holds a range *inside*
      the comment, and for a comment-headed text its first range is the comment's own characters.
      **DONE 2026-10-12** — the step's range is the **step** (FR-005): `_readSelection` hands `_readRange` the
      end `stepEnd(_content, _roles.commentsRead, seg)` and passes `step: true` — the flag T005 could not keep,
      landed here as this row was re-cut to say. `_readRange` records the step's own end in `_stepEndKey`, which
      is what the next step is searched from (so the finally needs no second `stepEnd` call), and the paragraph
      branch passes its own `seg.end` unchanged (FR-003). Green against T007.
- [x] T011 [US1] Put the advance in `lib/reading_view.dart`'s `_runRead` finally (`:1243-1252`): with
      `step == false` (today's ⏭) the path is **unchanged**; with `step == true` and the step's unit a
      sentence, take the first range of `sentenceRanges(_content)` whose `start` is at or after the step's own
      range end and set `_highlight`/`_anchor` to it **in memory**, then `_revealRange` it (FR-004, FR-012);
      with nothing found, clear both and show **nothing at all** (FR-008 — this is where §2.3's stale
      `nothingToReadMessage` line is deliberately not implemented); with the step's unit a paragraph, move
      nothing (FR-003). The whole branch sits behind the existing `gen == _readGen` guard, so a tap or a Stop
      that started a newer read can never be followed by an advance from the old one (plan §3.4).
      **(Re-cut 2026-10-12 by Phase 2's pass)**: this row also lands the reveal seam
      `_revealRange(TextSegment)` (`lib/reading_view.dart`) which T005 factored as far as it could go without a
      caller — the advance calls it, which is what makes it referenced rather than dead code — and it reads the
      candidates from `stepRanges(_content)` (T003's second helper, § The stage's corrections item 7).
      **DONE 2026-10-12** — the advance in `_runRead`'s finally: a step's read that ends by itself finds the
      first candidate of `stepRanges(_content)` starting at or after the step's own end, leaves it as the
      highlight **and** the anchor in memory (FR-004, FR-007) and reveals it through `_revealRange(TextSegment)`
      — the seam T005 factored, landed here as that row's own re-cut says (FR-012) — while the text's end clears
      both and **says nothing** (FR-008). A **paragraph** step keeps its highlight and its anchor and advances
      nothing (FR-003), and a read that is not a step (⏭) still drops both (011 FR-022). Two fields,
      `_steppedRead` and `_stepEndKey`, are what carry the step across a Pause/Resume, whose continuation
      enters through its own `_runRead` (FR-010). Green against T006/T007.
- [x] T012 [US1] Remove `selectToReadMessage` from `lib/l10n/app_en.arb:15`, `lib/l10n/app_zh.arb:15`,
      `lib/l10n/app_zh_Hans.arb:15` and `lib/l10n/app_es.arb:15`, run `flutter gen-l10n`, and record the
      count **108 → 107** in this file's Status (the four ARBs count 108 non-`@` keys on `409ffe1`). It
      cannot run before T009 — the page does not compile while its only call site remains.
      **Checkpoint**: `flutter test test/l10n_keys_test.dart` → 3 passing; `flutter analyze` clean; `git status
      --short lib/l10n` shows exactly the four ARBs and the regenerated `app_localizations*.dart`.

**US1 checkpoint**: `flutter test test/reading_view_step_test.dart test/reading_view_test.dart test/reading_view_edit_test.dart`
green; the warning and its key are gone from `lib/`; nothing else moved.

---

## Phase 4: User Story 2 — A step leaves nothing behind (P2)

**Goal**: the position a step leaves in force is a position **inside the session** and nothing more. ⏭ after a
step reads what the steps have not read; Stop still clears everything; a relaunch is always a clean page, and
the record, the store and the types behind it leave the tree.

**Independent Test**: from a position a step reached, ⏭ reads the sentences the steps have not read, in order,
to the end; Stop clears the highlight and the position; a force-stop and relaunch bring **nothing** back — no
highlight, no position — for a step **and** for a tap.

### Tests for US2 ⚠️ (write first, run RED)

      **DONE 2026-10-12** — `selectToReadMessage` removed from `lib/l10n/app_en.arb`, `app_zh.arb`,
      `app_zh_Hans.arb` and `app_es.arb` (each at `:15`), `flutter gen-l10n` regenerating the committed Dart.
      The four ARBs now count **107** message keys each (108 on `409ffe1`, counted in the same script)
      — *(dated note, 2026-10-12: [017](../017-bold-comment-size/spec.md) T005 added three labels, so the four
      count **110** today; the figure above is what this row measured, and the retirement it records is what took
      the tree from 108 to 107)*,
      `flutter test test/l10n_keys_test.dart` → **3 passing**, `flutter analyze` → **No issues found!** and
      `grep -rn 'selectToReadMessage' lib/ test/` → nothing (exit 1). 015's row 16 receipt, which reads 108, is
      corrected by T022 — not here, and not silently.
- [x] T013 [US2] Write US2's in-session half into `test/reading_view_step_test.dart`: ⏭ after a step reads
      only the sentences the steps had not read, in order, to the end (SC-003, FR-007's first half); Stop after
      a step clears the highlight and the position so ▶ starts at the first sentence (FR-009); a read parked
      by Pause finishes into the same advance (FR-010); in 多人对话 a step is one sentence of a turn in that
      turn's role's voice and the next step is the text's next sentence (FR-011). Run it and keep the RED
      output.
      **DONE 2026-10-12 — landed, with no RED of its own: every case went green on its first run because
      T006-T011 already landed the behaviour they assert** (the in-session `_anchor` ⏭ reads from, Stop's own
      clearing, and the two fields that carry a step across a Pause). The three cases in
      `test/reading_view_step_test.dart`'s US2 group: "⏭ after a step reads only the sentences the steps have
      not" (SC-003 — from the sentence the highlight sat on, to the end), "Stop clears the highlight, so the
      next press starts at the first sentence" (FR-009) and "a parked step advances when its sentence is
      resumed" (FR-010, through the fake's own park/release).
      **Re-cut in this pass — FR-011's dialogue case does not live here**: in 多人对话 the step's *range* is the
      same range (plan §3.6 — the resolution is 014's and unchanged), and reaching the mode in a widget test
      means 014's own toggle, role store and sheet helpers; the step is walked on the device instead —
      `quickstart.md` row 5's fixture carries a 多人对话 content, and rows 10/11 re-walk 011's and 014's own
      dialogue receipts on a build of this change.
- [x] T014 [US2] Write the relaunch half into `test/reading_view_step_test.dart`: a fresh view after a **step**
      and after a **tap** restores nothing — no highlight, no position, and ⏭ reads from the first sentence
      (FR-007, decision 5) — and neither path writes a `read_position_*` key at all (SC-005's retirement
      half). Run it and keep the RED output (on the base both halves fail: the base restores and writes).

### Implementation for US2

      **DONE 2026-10-12** — the two relaunch cases in `test/reading_view_step_test.dart`: "a relaunch after a
      step brings nothing back, and writes nothing" and "a relaunch after a TAP brings nothing back either"
      (FR-007, decision 5; both restart the way 010's own group does — the prefs map, then a brand new view).
      **RED receipt: an assertion failure on the value the base actually wrote** —
      `Expected: null / Actual: '34||334'`: a **tap** still wrote the position down on that tree, while the
      step's own case was already green (US1's `_select` never wrote one — T004/T009 landed that half). That
      single failure is the whole of this feature's record retirement, and T015 is what turns it green.
- [x] T015 [US2] Retire the write and restore path in `lib/reading_view.dart`: `_persistAnchor` (`:1023-1038`),
      `_restoreAnchor` (`:532-543`, called at `:525`), the gesture's call to it (`:1014`, which T004's
      `_select` now owns), the `_positions` field (`:385`) and the import (`:18`). `_anchor`, `_clearAnchor`
      (`:547-553`) and every in-session reader of them **stay** — 010 FR-002/FR-004/FR-005 are untouched.
      **DONE 2026-10-12** — `lib/reading_view.dart`: `_persistAnchor` (with the gesture's own call),
      `_restoreAnchor`, the `_positions` field, the `_anchorWrite` counter and the store's import all leave;
      `_adoptAnchor` becomes an in-memory `_anchor = null`, `_clearAnchor` clears the field alone, and the
      `previous` local its two call sites read only to clear the text being left went with them. `_anchor`,
      `_anchorKey` and `_clearAnchor` stay — the position's life **inside** a session (010 FR-002/FR-004/FR-005)
      is untouched, and no call site of the store remains. `flutter analyze` → **No issues found!** (0.8 s) is
      the receipt that nothing dangles.
- [x] T016 [US2] Delete `lib/read_position_store.dart` and `test/read_position_store_test.dart` (its 11
      cases), and correct the two doc comments that name the retired type in `lib/appearance_store.dart:132`
      and `lib/video_aspect.dart:54`/`:65` — a comment naming a type that left the tree is the drift this repo
      corrects in place, not the kind it keeps.
      **DONE 2026-10-12** — `lib/read_position_store.dart` and `test/read_position_store_test.dart` (its 11
      cases) are deleted, and the two doc comments naming the retired type are corrected:
      `lib/appearance_store.dart`'s store list and `lib/video_aspect.dart`'s (`:54` and the `read_position_*`
      line below it). `git status --short` lists the two deletions and nothing else untracked.
- [x] T017 [US2] Re-cut `test/reading_view_continue_test.dart` (010's own file) and
      `test/reading_view_follow_test.dart` (011's) where they assert or seed the retired record: the restore
      group (`:441-...` — "a fresh view restores the stored position" `:443`, "a malformed stored position is
      ignored" `:469`, "a stored position whose text length changed is ignored" `:481`) becomes "a fresh view
      restores nothing" (FR-007); the record helpers (`:180`, `:453`, `:471`, `:484`) and the four clearing
      cases (`:494`, `:521`, `:545`, `:565`) assert the **in-session** position instead of the record
      (FR-009); `test/reading_view_follow_test.dart:405`'s seed (`:266`) — a `read_position_*` record — is
      replaced by the in-session step that puts the same offset in force, which is also 011 FR-002's own case
      (FR-012). The ⏭ case at `:302` is **not** touched (note 6).
      **DONE 2026-10-12** — 010's and 011's own files re-cut: `test/reading_view_continue_test.dart` loses the
      `record()` helper and all eighteen of its uses, its group becomes "a relaunch is a clean page, and a text
      change forgets the place" with **one** case where the restore group's three stood ("a fresh view restores
      NOTHING — no highlight, ⏭ from the top": the prefs map is carried into a brand new view and asserted
      **empty**, then ⏭ reads from 0), and the four clearing cases assert the **in-session** position —
      `hasYellow` before the action, the read's own start after it — instead of a record that no longer exists.
      `test/reading_view_follow_test.dart`'s seeded case ("Continue Read from a stored position shows it first")
      is **replaced by a dated note** rather than deleted silently: its subject is what decision 5 retires, the
      reveal it proved lives on in the case above it, and its device half is `quickstart.md` row 10 — 011's own
      row 8, whose restore half T020 dates in 011's record.
- [x] T018 [US2] Re-cut the four remaining shipped files that name the record: `test/reading_view_dialogue_test.dart:250`
      (`:259`/`:270` — `afterTap` is `isNotNull` today and becomes null), `test/reading_view_comment_test.dart`
      (the helper at `:194`, the assertions at `:273`/`:290`), `test/reading_view_new_content_test.dart`
      (`:104`, `:195`, `:211`) and `test/video_aspect_test.dart` (`:11`'s import, `:85-96`'s namespace case —
      the store's `keyFor` leaves the tree and with it the `read_position_*` row of that comparison, while the
      case keeps its claim about the keys the app **does** keep). `test/appearance_store_test.dart:81` stays
      **unmodified**: it names the prefix as a literal, not the store.
      **Checkpoint**: `flutter analyze` clean; `grep -rn "read_position" lib/ test/` → exactly one hit,
      `test/appearance_store_test.dart:81`'s literal; the full suite green with no case asserting a stored
      position.

---

## Phase 5: The other features' records (010's amendment, its own group)

**Purpose**: decision 5 is the one place this spec reaches outside its own feature, so its record work is its
own group. Nothing here is deleted quietly: an amended requirement keeps the ask that reversed it beside it,
and a receipt that only cited the retired record keeps its behaviour and gains a dated note.

      **DONE 2026-10-12** — the four remaining shipped files: `test/video_aspect_test.dart` loses the store's
      import and the `read_position_*` row of its namespace comparison (the compile error the plan's §4 named),
      `test/reading_view_dialogue_test.dart`'s "it keeps the highlight, and nothing is written down" drops the
      prefs reads and asserts the highlight alone, and `test/reading_view_comment_test.dart` (its
      `storedPosition` helper + two assertions) and `test/reading_view_new_content_test.dart` (the same helper,
      two assertions and the re-open tail, which now expects a **clean page**) are re-cut the same way.
      `test/appearance_store_test.dart:81` stays unmodified: it names the prefix as a literal.
      **Suite, measured per file after this pass** (`flutter analyze` → **No issues found!**):
      `test/reading_view_step_test.dart` → `00:02 +11`, `test/comment_test.dart` → `00:00 +42`,
      `test/reading_view_continue_test.dart` → `00:05 +16`, and the whole tree `00:57 +643: All tests passed!` —
      which is Phase 3's 652 + this pass's 5 new US2 cases − the deleted `test/read_position_store_test.dart`
      (11) − the restore group's 3-for-1 (−2) − follow's seeded case (−1) = **643**, each number from its own
      run.
      **One correction the run forced, settled by 011's own FR-024**: the new clear-page case first asserted the
      paragraph's first sentence stayed painted after a long press; a long press paints the **whole paragraph**,
      which is the unit the gesture selected — the assertion was corrected to the paragraph's own span (the same
      class of mistake T008's re-cut recorded).
- [x] T019 [P] Amend `specs/010-continue-read/spec.md`: FR-008 ("System MUST persist start position across app
      restarts", `:77`) is **withdrawn with its date** and the reader's own words that reversed it (016
      decision 5, 2026-10-09) written beside the original; then re-cut the receipts the amendment falsifies —
      `specs/010-continue-read/quickstart.md` rows 9 and 14 (`:142`, `:198`),
      `specs/010-continue-read/breakpoint.md` rows 9 and 14 (`:39`, `:44`) — and mark
      `specs/010-continue-read/contracts/read-position-format.md` retired at its head, with the date and the
      feature that retired it.
      **DONE 2026-10-12** — 010's own record, amended in place and dated: `specs/010-continue-read/spec.md`'s
      FR-008 is struck through with the reader's own words of 2026-10-09 (*"(B) 谁都别留,重启一律干净"*), the ask
      that reversed it, and what stands where it did (a position's life inside a session); `quickstart.md` row
      9 becomes "A relaunch is a clean page — [unit]" (its three cases are one now) and row 14 says plainly that
      it is **not re-walked** because there is no record to survive, naming 016's row 8 as its replacement;
      `breakpoint.md` rows 9 and 14 each carry the dated amendment marker and keep their historical PASS; and
      `contracts/read-position-format.md` opens with a RETIRED banner naming the feature, the date and what left
      the tree.
      **Left standing on purpose**: 010's own `tasks.md` T003/T005 cite `lib/read_position_store.dart` and its
      test file — they are the record of what ran then, and the contract's banner plus FR-008's amendment are
      what tell a reader the file is gone. `check_artifact_refs.py specs/010-continue-read` lists them among its
      unresolved; that is the honest state of a historical receipt, not a drift to hide.
- [x] T020 [P] Replace the clause 016 makes false in `specs/011-reading-experience/spec.md`: FR-022's last
      sentence (`:222-223`, "a position outlives a restart only while its highlight is up when the app is
      left") — its condition stays, the restart half goes, dated; `specs/011-reading-experience/breakpoint.md`
      row 8 (`:37`) loses its restore half as that amendment's row and keeps its off-screen-reveal half;
      `specs/011-reading-experience/contracts/appearance-format.md` (`:23`, `:28`, `:51`) stops naming the
      retired record as a live sibling.
      **DONE 2026-10-12** — 011's record: FR-022's last clause is struck through and replaced (dated) — the
      condition above it stands and is now the whole rule; `breakpoint.md` row 8 keeps its off-screen-reveal half
      and its PASS and gains the dated note retiring its **restore** half (its re-walk is 016's quickstart row
      10, and this feature's own row 8 is what asserts the in-session reveal now); and
      `contracts/appearance-format.md` stops naming the retired record in four places — the store list, the
      grammar example, the namespace list and read rule 5 — each with the date and the decision that retired it.
- [x] T021 [P] Date the receipts that only **cited** the retired record in `specs/014-dialogue-reading/breakpoint.md`
      and `specs/014-dialogue-reading/data-model.md` rather than rewriting them, in the spec that owns each —
      one note for the 014 rows at `:386`, `:408`, `:413`, `:416`, `:420`, `:421`, `:425`, `:426`, `:429`
      (the behaviours they prove, a tap anchors a sentence and a read continues from it, still hold; the
      line they read it off does not) — and a dated line at `specs/014-dialogue-reading/quickstart.md:353` and
      `specs/015-comment-tag/data-model.md:180`.
      **DONE 2026-10-12** — the receipts that only **cited** the record, dated rather than rewritten:
      `specs/014-dialogue-reading/breakpoint.md` gains one note beside the block that reads the store off the
      device (its nine `read_position_dialogue_fixture` rows keep their PASS and their behaviour; what moved is
      the line they read it off — the in-session highlight and `klhu read range`, which is what 016's row 8
      asserts); `specs/014-dialogue-reading/data-model.md`'s `ReadingPosition` row is marked retired with the
      rule it leaves untouched; `specs/014-dialogue-reading/quickstart.md` row 26's steps no longer name the
      stored record and carry the same dated note; and `specs/015-comment-tag/data-model.md`'s entity row loses
      the type with a dated line saying this feature never needed it to change.
- [x] T022 [P] Correct 015's key-count receipt in `specs/015-comment-tag/quickstart.md:337` in place with its
      date, because 016 is what moved the number (FR-013) — row 16, 108 → **107**, with the key removed named — and
      the same correction in `specs/015-comment-tag/breakpoint.md`'s § Deviations, where that row's own
      correction of 109 → 108 already lives.

---

## Phase 6: The device walk

**Purpose**: the rows a unit test cannot hear — `specs/016-sentence-reading/quickstart.md`'s rows **5-11**,
whose steps and expected evidence are that file's own. Every row appends its evidence to
`specs/016-sentence-reading/breakpoint.md` and is dispatched under its quickstart row number by the driver T023
writes, one row per run (011's and 015's own convention — `klhu_walk_step.py 5` is quickstart row 5).

      **DONE 2026-10-12** — 015's key-count receipt, corrected in place by the feature that moved the number:
      `specs/015-comment-tag/quickstart.md` row 16 now reads **107** keys each, naming what 016 removed
      (`selectToReadMessage`, 011 FR-023's warning, whose only call site it took away) and confirming 015's own
      addition (`commentsReadLabel`) is untouched; `specs/015-comment-tag/breakpoint.md`'s § Deviations opens
      with the same correction and its date. 015's own task list is not re-cut — nothing this feature added
      changed.
- [x] T023 Write the device driver `specs/016-sentence-reading/scripts/klhu_walk_step.py` and its fixture
      `specs/016-sentence-reading/scripts/klhu_step_fixture.txt`, importing 015's
      `specs/015-comment-tag/scripts/klhu_walk_comment.py` (which sits on 014's and 012's) for the device
      mechanics, the content seeding and the `RESULT: PASS|FAIL` dispatch. The fixture carries 011 row 23's
      shape (a title with no full stop over a punctuated paragraph — the step rule's own hard case), a content
      whose sentence carries a comment, and a 多人对话 content with a role tag.
      **DONE 2026-10-12** — `specs/016-sentence-reading/scripts/klhu_walk_step.py` and its fixture
      `specs/016-sentence-reading/scripts/klhu_step_fixture.txt` (four named sections: the stepper's own shape,
      a comment in its own paragraph, an inline comment, and a 多人对话 content with a comment). The driver
      imports 015's, which sits on 014's and 012's, and borrows 011's `screencap`/`yellow_rows` for the
      highlight; it adds per-press `klhu read range` + `klhu speak` pairs, the step rule computed from the
      fixture's own text, and the page's own end-state checks. **Rows 5 and 6 are implemented; `main` names
      7-9 as still owed** (a row is implemented in the pass that walks it). The interpreter is
      `/usr/bin/python3` — the chain pulls PIL in and this host's default `python3` has none (015's own note).
      Load build: `flutter build apk --debug` (13.8 s) + `adb -s emulator-5554 install -r` → Success.
- [x] T024 Walk quickstart row 5 into `specs/016-sentence-reading/breakpoint.md`: the stepper on the reader's own
      shape — its steps and expected evidence are that row's own (press ▶ three times, read the app's
      `klhu read range` and `klhu speak` lines for each press plus the highlight's rows from a screenshot, then
      a fourth press that reads nothing, clears the highlight and shows **nothing on the page**).
      Proves FR-001, FR-004, FR-008, FR-012, SC-001, SC-002.
      **DONE 2026-10-12 — WALKED, PASS (13/13)**, quoted in `breakpoint.md` § Row 5 with its screenshots. On the
      device, in order: `klhu read range: 0..15` + `A quiet morning` (highlight painted, top row 472);
      `17..50` + `The sun rose over the qu...`; `51..80` + `Birds sang in the tall t...`; then, once the third
      read finished, **0 yellow px and no message painted**; then a fourth press reading `0..15` again.
      **The row was re-cut by the run** (§ Deviations 1): the silent press is the third, not a fourth — the
      end is automatic and the press after it is FR-001's fresh start. `quickstart.md` row 5 was corrected in
      the same pass, and the widget case asserts the same reading. Proves SC-001, SC-002, FR-001, FR-004,
      FR-008, FR-012.
- [x] T025 Walk quickstart row 6 into `specs/016-sentence-reading/breakpoint.md`: the comment half — one press
      reads the sentence **and** its comment (`comment=1` in the comment's own voice), and the next press starts
      at the following sentence rather than inside the comment, including the content whose comment sits between
      two sentences of one paragraph. Proves FR-005, SC-004.
      **DONE 2026-10-12 — WALKED, PASS (6/6)**, quoted in `breakpoint.md` § Row 6. The comment's own paragraph:
      press 1 `klhu read range: 0..23` with `Hola.` then `How are you?` (comment=1) — the step is the whole
      step, not the sentence; press 2 `25..31` with `Adiós.` alone, starting at the sentence and never inside
      the comment's characters. The inline shape: press 1 `Hola.` alone, press 2 `Adiós.` then `Fine.`
      (comment=1) — the comment rides its owner. Three driver fixes on the way (a tap into the app bar, a
      stale per-press log window, and the app's own 24-character elision on its speak line) are recorded as
      driver notes, not device findings. Proves FR-005, SC-004.
- [x] T026 Walk quickstart row 7 into `specs/016-sentence-reading/breakpoint.md`: ⏭ after a step reads only the
      sentences the steps had not read, in order, to the end, never the ones already heard — the range's start is
      the sentence the highlight sat on, not 0. Proves SC-003, FR-007's in-session half.
      **DONE 2026-10-12 — WALKED, PASS (2/2)**, quoted in `breakpoint.md` § Row 7. Two steps (`0..15`, `17..50`)
      put the highlight on the paragraph's second sentence; ⏭ then read `51..80` — from the sentence the steps
      stopped on, never from 0 — with one utterance, `Birds sang in the tall t...`, and nothing already heard
      repeated. Proves SC-003, FR-007's in-session half.
- [x] T027 Walk quickstart row 8 into `specs/016-sentence-reading/breakpoint.md`: the clean relaunch — after a
      step and after a tap, `am force-stop` + relaunch shows no highlight, leaves **no** `read_position_*` record
      in `shared_prefs` at any point in the run, and ⏭ reads from the first sentence. This is the row 010's own
      9/14 are replaced by. Proves FR-007, decision 5, SC-005's retirement half.
      **DONE 2026-10-12 — WALKED, PASS (6/6)**, quoted in `breakpoint.md` § Row 8. After a step the store holds
      `read_position_step_main = None`, the relaunch paints 0 yellow px and ⏭ reads `0..80` from the first
      sentence; after a **tap** the tapped place IS in force (24608 yellow px painted) while the whole store
      holds **no `read_position` key at all** (`any read_position key anywhere: False`), and that relaunch paints
      nothing either. This is decision 5 on the device. Proves FR-007, decision 5, SC-005's retirement half.
- [x] T028 Walk quickstart row 9 into `specs/016-sentence-reading/breakpoint.md`: the render-from-a-position path
      (`lib/video_timeline.dart:128`) — a step's non-zero position rendered through
      `specs/012-reading-video/scripts/klhu_walk_video.py`, checking the file's own `klhu render slot=… span=…`
      line begins at the step's own sentence. This is the case 011's 2026-10-09 amendment left unwalked and the
      spec's Out of scope names; 012 has no row of its own for it, so a failure here is a finding.
      Proves FR-012's consequence off the page, SC-005.
      **DONE 2026-10-12 — WALKED, PASS (11/11)**, quoted in `breakpoint.md` § Row 9. One step put a NON-ZERO
      position in force (the press read `0..15`, the position moved to `17..50`); 012's own machinery then
      rendered it — the app said `Video made: klhu_video.mp4 (7 s)`, the page's own copy matched it, and the
      file came off the device at 271362B (`/tmp/016_row9_step.mp4`). **The file's first slot is
      `span=17..50 text=33 frames=77`**: the render starts at the step's own sentence — the path 011's
      2026-10-09 amendment left unwalked (`lib/video_timeline.dart:128`) — and paints that sentence's own 33
      characters, nothing added. Two driver fixes on the way (the artifacts' directory did not exist on this
      host; the step's own press reads the FIRST step and leaves the next in force) are driver notes, not
      findings.
- [x] T029 Walk quickstart row 10 into `specs/016-sentence-reading/breakpoint.md`: 011's rows 7, 8, 10 and 20
      re-walked on a build of this change through `specs/011-reading-experience/scripts/klhu_walk_experience.py`
      (one row per run). **(Half-landed 2026-10-12 — the run is in `breakpoint.md` § Row 10: 7 PASS, 10 PASS,
      8 CRASHES on `stored_offset()` after its reveal had already been shown, 20 FAILS on `the tap set no
      position` — both on the record step 016 retires, neither on a behaviour. The row stays open for the
      two-check re-cut in 011's driver, or for the reader's word that the amendment supersedes those two
      receipts as they stand.)** — the follow, the off-screen reveal, Stop's clearing and the gesture's unit are 011's own
      receipts and must be seen to survive the stepper, with row 8's restore half dated in 011's record by T020.
      Proves SC-005, FR-012.
      **DONE 2026-10-12 — WALKED, PASS (4 rows: 7, 8, 10, 20)**, quoted in `breakpoint.md` § Row 10. Two of the
      four needed a re-cut **in 011's driver** first, and both times the row's rule was kept and its witness
      moved: `stored_offset()` → the app's own live lines (row 8: ⏭ from a non-zero `112..334` with its first
      report revealed inside the reading area), and row 20's tapped offset → ▶'s own first range and the
      paragraph's span from that. Row 20's two state assumptions were re-cut as well, because 016 changed the
      state: the highlight **advances** after a step (FR-004), so ⏭ runs from `160..334` where the row expected
      the fixed point's own `112`, and "nothing in force" is reached by Stop (FR-009) — with Stop pressed ⏭
      reads `0..334` ✓. Its last block asserted the **old** FR-023; the run gives
      `▶ after the read : ranges=[(0, 33)] prompt=MISSING`, which is 016 FR-001 on the device, and the check is
      inverted to that rule — **011's spec (FR-023) and breakpoint (row 20) carry the dated amendment** in the
      same pass. Proves SC-005.
- [x] T030 Walk quickstart row 11 into `specs/016-sentence-reading/breakpoint.md`: 010's rows 13, 15 and 16
      re-walked through `specs/010-continue-read/scripts/klhu_walk_continue.py`, and rows 9/14 **replaced** by
      T027 (a relaunch restores nothing) rather than re-run as they stand — T019 writes the amendment those rows
      are replaced by. Proves SC-005, FR-007.

**Walk checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`, and no row cites a
driver command that does not implement it (extend T023's dispatch in the same pass, or record the row as
hand-run).

---

## Phase 7: Polish & cross-cutting concerns

      **DONE 2026-10-12 — WALKED, PASS (3 rows: 13, 15, 16)**, quoted in `breakpoint.md` § Row 11. 010's driver
      needed **no** re-cut: it *prints* the record rather than asserting on it (`persisted record: []` on row 13,
      `(none)` on row 15 — which is now the truth), and the three rows' own rules hold: `286..334` from a tapped
      middle paragraph with a real sentence start, `0..334` with no position in force (8 utterances), and the
      pause/resume repeat (`p0 s1` once for 7 sentences left, 7 engine requests). Rows 9 and 14 are **not**
      re-run: 010's FR-008 is withdrawn with its date and their replacement is this feature's row 8. Proves
      SC-005, FR-007, FR-009.
- [x] T031 Run the two structural checks into `specs/016-sentence-reading/breakpoint.md`: `git diff --stat
      pubspec.yaml pubspec.lock android/ ios/` → **empty** (FR-014) and the l10n half of FR-013 — the four
      ARBs' counts (107 each, 108 on `409ffe1`), `flutter gen-l10n` reproducing the committed Dart byte for
      byte, and `test/l10n_keys_test.dart` green.
      **DONE 2026-10-12** — the two structural checks, run on the finished tree (their numbers are also in the
      Status below): `git diff --stat pubspec.yaml pubspec.lock android/ ios/` → **empty** (FR-014: nothing
      installed, no platform file touched), and the l10n half of FR-013 — the four ARBs counted **107** message
      keys each **on this feature's own tree** *(updated 2026-10-12: [017](../017-bold-comment-size/spec.md) added
      three labels — `fontBoldLabel`, `fontSerifBoldLabel`, `fontMonoBoldLabel` — so the four ARBs now count
      **110**; 107 is what the tree held when this row ran, and 016's own receipt is unchanged)*, `flutter gen-l10n` reproduces the four committed `app_localizations*.dart` **byte for byte**
      (sha256 before == after) and `flutter test test/l10n_keys_test.dart` → **3 passing**.
- [x] T032 Run both list checkers and quote them verbatim in `specs/016-sentence-reading/tasks.md`'s Status:
      `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py
      specs/016-sentence-reading` and
      `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/task_id_audit.py
      specs/016-sentence-reading`. A red checker here is fixed in this file, not explained away.
      **DONE 2026-10-12** — both list checkers, quoted verbatim in the Status below:
      `tasks.md: 34 tasks (29 done), 5 marked [P]` with the per-story block and
      `OK: format, sequencing and spec-id coverage check out`; `016-sentence-reading: 34 tasks, 29 done, 5 [P]`,
      no duplicate, gap or out-of-order id. T034 re-quotes them after this file's closing edit.
- [x] T033 Re-take the suite count on the finished tree into `specs/016-sentence-reading/tasks.md`:
      `flutter analyze` and `flutter test --concurrency=2`, read against T001's **636** with the difference
      decomposed by file (this feature's new file and new group minus the deleted `test/read_position_store_test.dart`'s
      11 cases and the re-cut cases) — a bare total beside a changed suite is not a receipt.
      **DONE 2026-10-12** — the suite re-taken on the finished tree, **measured per file** and read against
      T001's 636: `flutter analyze` → **No issues found!** (0.8 s); `flutter test --concurrency=2` →
      **643 passing, 0 failing** (`00:57 +643: All tests passed!`); this feature's own files —
      `test/comment_test.dart` → `00:00 +42`, `test/reading_view_step_test.dart` → `00:02 +11`,
      `test/reading_view_continue_test.dart` → `00:05 +16`. The 652 → 643 difference is Phase 4's deletions and
      re-cuts, itemised in T018's receipt; nothing in `lib/` or `test/` has changed since T018, so this count is
      that run's, re-read rather than re-derived.
- [x] T034 Close the list in `specs/016-sentence-reading/tasks.md`: re-run both checkers after this file's last edit and quote their own output beside
      the closing receipts in `specs/016-sentence-reading/tasks.md`, correcting any receipt in this file that
      has gone false (the Status's counts, the format-checker block) rather than leaving it standing, and hand
      back with the rows that still need a walk named one by one.

      **DONE 2026-10-12 — the list closes with every row ticked.** Both checkers re-run after this file's last
      edit, quoted in the Status: `tasks.md: 34 tasks (34 done), 5 marked [P]` … `OK: format, sequencing and
      spec-id coverage check out`, and `016-sentence-reading: 34 tasks, 34 done, 5 [P]`. Two receipts were
      corrected in this pass rather than left standing (the Status's counts and the format-checker block), and
      **no row still needs a walk**: rows 5-11 all PASS in `breakpoint.md` — 5-9 through this feature's own
      driver, 10 through 011's (two of its checks re-cut in place, dated), 11 through 010's (its rows 9/14
      replaced by this list's row 8).

---

## Dependencies & ordering

- **T001** first, before any edit: every later tick is read against its numbers.
- **Phase 2 (T002-T005)** blocks both stories: `stepEnd` is what FR-005 needs, and the three seams are where
  both stories' branches land. **T012 depends on T009** — the key cannot be dropped while its only call site
  is in `lib/reading_view.dart`.
- **US1 (Phase 3)** blocks US2's tests: US2's relaunch case needs a step that first works (T013/T014 run
  against a tree where T011's advance exists).
- **US2 (Phase 4)** blocks Phase 5's records: 010's FR-008 and 011's FR-022 are amended for what the code now
  does, so the amendment is written after T015-T016, not before.
- **T022 depends on T012** (the count it corrects is the one T012 moves).
- **The walk (Phase 6)** depends on its stories' code: quickstart rows 5-8 on US1+US2, row 9 on 012's
  machinery as it stands, rows 10-11 on the re-walks' own features being untouched. T023 (the driver) depends on
  nothing but is written before its rows.
- **Phase 7** last: T031-T032 need the finished tree and the finished file, T033 needs everything, T034 needs
  the walk.

## Parallel opportunities

- **T002** is the only story-independent test row: `test/comment_test.dart` is a different file from the seams
  T004/T005 move, so it can be written while they are.
- **T019-T022 are four different features' records** — four files apart, no shared code, and each is a
  write-out of a decision already taken (that is what `[P]` marks here; none of them may precede T015/T016,
  which settle what the code does).
- **Nothing in Phase 6 is parallel**: every row installs, drives and reads the same device, and they all
  append to one `breakpoint.md`. Two rows run one after the other even when their subjects are independent.
- **T006/T007/T008 are not `[P]` against each other**: each writes into the same new file (T006 and T007) or
  re-cuts files whose cases T009/T010 must then make green (T008).

## Implementation strategy

The MVP is **Phases 2-3**: the pure step rule, the three seams and ▶'s three branches — demonstrable on the
device with row 1 alone, which is the reader's own ask ("读完一句停 再一键读第二句"). US2 then makes the step
session-scoped and retires the stored position, which is the largest single item in this list and the only one
that reaches other features' records; Phase 5 makes that reversal visible where it happened. Each story is
independently demonstrable: rows 1-4 for US1+US2 together, rows 6-7 as the other features' receipts.

## Notes

- The device rows are walked by hand first and scripted afterwards; the driver's own `PARTS` table is the
  authority on which rows are scripted, so a row added later extends it in the same pass.
- `test/l10n_keys_test.dart` is bidirectional: a key in three ARBs fails exactly as loudly as a key in five.
- No `contracts/` directory for this feature: the interfaces it changes are in-process Dart types the app
  already owns, and 010's own contract file retires with the store rather than being extended (T019).
- The read's `klhu read range` and `klhu speak` lines are device evidence only — no shipped test asserts
  either log line — so a row that rests on them says so (rows 1-4 all do).
- `specs/016-sentence-reading/breakpoint.md` does not exist yet: T024 creates it, with its own environment
  table (build, device, package, the probe that produced each row's evidence).

## Requirement coverage

| Requirement | Tasks that satisfy it |
|---|---|
| FR-001 (▶ with nothing highlighted reads the first sentence) | T006, T008, T009, T024 |
| FR-002 (▶ with a sentence highlighted reads exactly it) | T006, T009, T024 |
| FR-003 (a paragraph press reads the paragraph and stops) | T006, T010, T011 |
| FR-004 (the highlight moves ahead when a step's read ends) | T006, T011, T024 |
| FR-005 (a step is the sentence plus its comment) | T002, T003, T007, T010, T025 |
| FR-006 (the next sentence comes from `sentenceRanges`) | T002, T006, T011 |
| FR-007 (in force for the session; nothing across a restart) | T013, T014, T015, T027, T030 |
| FR-008 (the text's end is silent) | T011, T014, T024, T028 |
| FR-009 (Stop, an edit, leaving the page still clear it) | T013, T015, T017, T029 |
| FR-010 (Pause keeps its meaning; the advance still applies) | T013, T017 |
| FR-011 (a step in 多人对话 is one sentence of a turn) | T013, T023 |
| FR-012 (the step's sentence is brought into view) | T005, T011, T017, T024 |
| FR-013 (the warning and its key go; 108 → 107) | T009, T012, T022, T031 |
| FR-014 (no dependency, no platform change) | T001, T031 |
| SC-001 (N presses read sentences 1..N in order) | T006, T024 |
| SC-002 (the highlight sits on the next sentence; the end says nothing) | T006, T011, T024 |
| SC-003 (⏭ after a step reads only what the steps have not) | T013, T026 |
| SC-004 (a sentence with a comment reads both in one press) | T007, T025 |
| SC-005 (010's and 011's rows still pass, but for the amendment's own) | T017, T019, T020, T021, T029, T030 |

**Requirements of other specs this list moves or re-cuts** (their ids are the ones their own records use, and
every one of them is named above with the artifact that carries the change):

| Requirement | Where it changes | Tasks |
|---|---|---|
| 010 FR-005 (no position ⇒ read from the first sentence) | unchanged; it is now also what a launch does | T015, T019, T030 |
| 010 FR-008 (the position survives a restart) | **withdrawn**, dated, in 010's own record | T019, T027, T030 |
| 011 FR-022 (the position lives exactly while its highlight is up) | narrowed for a step; its restart clause replaced | T011, T013, T020 |
| 011 FR-023 (▶ asks for a selection instead) | amended by FR-001 | T008, T009 |
| 011 FR-024 (▶ reads the unit the gesture selected) | unchanged; the paragraph half is FR-003 | T006, T010 |
| 011 FR-025 (a touch during a read changes nothing) | unchanged; the `gen == _readGen` guard carries it | T011, T029 |
| 011 FR-018 (no new dependency) | kept as this feature's FR-014 | T001, T031 |
| 011 FR-021 (Pause parks and Resume finishes the sentence) | unchanged; the advance applies after it | T013, T017 |

---

## Amendment — the reader's own report of 2026-10-16 (a new row, dated)

> "reading page, when not on the top/not show first sentence and no tap, click Continue Read, it scroll to top,
> highlight first sentence the read. if click Read, no scroll to top happen before read first sentence. scroll happen
> after read first sentence and high light second sentence."

- [x] T035 `lib/reading_view.dart`: the press reveals the unit it is about to read — `_readSelection`'s three branches
  (nothing highlighted → the first step, a paragraph selection, a sentence selection) call `_revealRange` **before**
  `_readRange`, so FR-012's reveal covers the press's own unit and not only the next one (`_advanceStep` carried that
  half already). Its case is `test/reading_view_step_test.dart`'s own and its row is `klhu_walk_step.py`'s **15**,
  walked either side of the fix.
  - **Where the gap was, in the code's own terms**: a step reads with `step: true` and `track` stays false, so
    `onSentenceStart` is `null` — no sentence report reaches `_followRead` — and the step path's only reveal was
    `_advanceStep`'s, after the sentence had been spoken. ⏭ passes `track: true` and therefore revealed first, which
    is exactly the two-button comparison the reader reports.
  - **The case first, RED quoted**: a 400×600 viewport, twelve copies of the fixture's paragraph, nothing
    highlighted, the page jumped to `maxScrollExtent` so the first sentence is off screen —
    `Expected: a value less than <4361.0> / Actual: <4361.0> / Which: is not a value less than <4361.0>`, with the
    reason `▶ read the sentence with the page where it was: nothing brought it into view`. Green after the fix:
    `test/reading_view_step_test.dart` → `+13: All tests passed!`; the whole suite →
    `01:13 +810: All tests passed!`; `flutter analyze` → `No issues found!` (ran in 1.1s).
  - **The device, on two builds**: the new row **15** on the build of 09:24 — the tree before this fix — reads
    **2/3**: the control passes (⏭ starts at the first sentence `ranges=[(0, 779)]` and its frames paint the
    highlight `[(None, 0), (472, 64400), (472, 64400)]`), and ▶'s own check fails with `ranges=[(0, 33)]` and
    **every** frame blank (`[(None, 0), (None, 0), (None, 0)]`) — the reader's report, reproduced. On the fixed
    build (`lastUpdateTime=2026-10-16 11:01:36`) the same row reads **3/3**, that press's frames now
    `[(None, 0), (472, 64400), (472, 64400)]` beside the control's own. Section, frames and both presses' `klhu
    read range` lines in `breakpoint.md`.
  - **Two corrections the row's own first run forced, both in the row rather than in the app**: its first version
    expected ⏭'s range to be the first sentence where ⏭ reads to the **end** of the content (`(0, 779)`), and it
    pressed ▶ through `tap_any`, which found the *app bar's* own "Read" at `(263, 209)` — the trap this driver's
    `press_read` band guard exists for. Both were fixed before any verdict was read off the row: a row that fails
    for its own reasons proves nothing about the app.
  - **The line citations this fix owed, re-mapped in the same pass**: the fix adds ten lines at
    `lib/reading_view.dart:1041`, so every `reading_view.dart:<n>` citation with `n > 1035` was re-mapped through
    the diff's own hunks to the line that still holds the text it names — **58 citations across 27 files** in
    `specs/`, each verified before rewriting (the mapped line's text equals the cited line's text at the last
    commit). The citations the shift did not touch were checked the same way: **83 still hold their text, none had
    drifted before today.** Nothing was renumbered on a guess.
  - **What this owes 022**: nothing. This is the reveal that `specs/022-read-scroll-lead`'s third decision (`3A`)
    builds on, and that spec's own checklist already records this defect as one found while it was written.

