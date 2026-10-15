# Tasks: Head tags (`#` a title, `##` a subtitle)

**Feature**: `019-head-tags` | **Date**: 2026-10-13
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) |
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)
**Format**: `[ID] [P?] [Story] Description with file path`

**Grounding revision**: `d51240e` — the commit that lands this feature's spec and plan (with the reader's own
amendment of 2026-10-13) plus 016's step fix. Every line number below was read on that tree by this stage.

## Status

## Implement-stage close (2026-10-13)

    flutter analyze                      No issues found! (ran in 0.8s)
    flutter test --concurrency=2          00:59 +729: All tests passed!   (T001's 663 + 66)
    check_tasks_format.py (019)           OK: format, sequencing and spec-id coverage check out
    task_id_audit.py (019)                019-head-tags: 31 tasks, 31 done, 3 [P]
    check_tasks_format.py (017)           OK: format, sequencing and spec-id coverage check out
    task_id_audit.py (017)                017-bold-comment-size: 32 tasks, 32 done, 7 [P]
    the device walk (breakpoint.md)       rows 10 14/14 · 11 12/12 · 12 66/66 · 14 7/7 — all four PASS

Every task in this file is ticked with its own receipt beside it. Two receipts record where this pass fell short of
the file's own rules rather than hiding it: **T016/T017** (US3's tests were written after T018-T020's first pass,
so no RED was taken for them) and **T026** (two expectation failures before the pass, and the row's own finding
that a second render in one run never reports `klhu render done` — a clean relaunch between renders is the driver's
answer, recorded in the task row, in `breakpoint.md` and in the skill's device-walk pitfalls).


**Nothing is done yet: 0/31.** This file is the stage's deliverable, and it is the only artifact this pass writes.

**Two things are already in the tree and no task re-does them**: `specs/019-head-tags/quickstart.md` (the walk
rows' own contract, cited by number below) and the two sibling records that carry the amendment's dated report —
`specs/017-bold-comment-size/tasks.md`'s `## Superseded by later specs` and `breakpoint.md`'s amendment section.
T022 re-reads that report against the finished tree; it does not write it again.

**The baseline (T001 re-takes it; measured 2026-10-13 09:05 for this file on `d51240e` minus the tasks work)**:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 00:57 +663: All tests passed!
message keys per ARB (four files)    → 110 each          (this feature adds none)
test/*.dart files in the tree        → 50
```

*(2026-10-14: the ARB figure above is 019's own, taken on 019's tree and true of it. 020 adds interface text, so the
four files no longer hold 110 — its structural row states the count that applies now. **Measured 2026-10-15 on 020's
tree: `120` each**, the ten keys T010 lists on top of 019's 110. The other three figures are 019's own measurements
and are not re-taken here.)*

**The ladder is the rule every paint row is read against** (`data-model.md` § The ladder): the four offered sizes
in the reader's order, then the largest offered size at the **bold** weight (017's faces') and at the **black**
weight — `12 w400 → 14 w400 → 18 w400 → 24 w400 → 24 w700 → 24 w900`. A title takes the rung **two** steps above
the reader's own, a subtitle the rung **one** step above, both clamped at the last; a comment takes the rung one
step **down**, the weight first.

**Format checker**: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/019-head-tags`,
re-run after this file's last edit and quoted verbatim in T030's tick, beside
`task_id_audit.py specs/019-head-tags`. This pass's own runs are in § The stage's notes.

**Suite**: the feature's own cases are two new files (`test/head_tag_test.dart`, `test/reading_view_head_test.dart`)
plus new groups in seven shipped files (`test/comment_test.dart`, `test/appearance_store_test.dart`,
`test/speech_resolver_test.dart`, `test/step_ranges_test.dart`, `test/reading_view_comment_test.dart`,
`test/video_timeline_test.dart`, `test/video_painter_test.dart`). **One shipped case is re-cut**: the invariant at
`test/speech_resolver_test.dart:106` (`expect(content.substring(speech.start, speech.end), speech.text)`), which a
mark makes false by design — its new name and shape are T011's, and no other shipped assertion moves.

**Device rows**: quickstart rows **10** (the page: no marker, the ladder at each size, the bold `xlarge` pair),
**11** (▶ and ⏭), **12** (the video's title frame, the Chinese pair) and **14** (a bold body's comment, measured),
walked through `specs/019-head-tags/scripts/klhu_walk_head.py` into `specs/019-head-tags/breakpoint.md` (created by
the first row that walks). None is walked yet.

## Grounding notes (the decisions these tasks implement)

1. **The rule is one module and one derived value** (research D2, D7): `headTagsOf(content)` recognises a mark
   from the content alone — no comment, no page, no store — and 015's display is its only caller. A mark is
   `#`/`##` at a line's **first** character, exactly one ASCII space after it, a non-space after that, and no
   trailing `#`-sequence on the line; a line inside a comment's span is never a mark.
2. **The marker is elided, not spaced** (research D1): the display removes the marker's `[start, markEnd)` from
   what is painted, and the *read* is handed the display's own characters (D3) — which is what makes FR-004 true
   at the resolution rather than at the engine's door, and what keeps a frame painting the same words a page does.
3. **The rung decides size and weight together, and the reader's face decides the family** (FR-006, FR-007,
   research D4): one helper returns the rung; the page's `_spanPaint` and the frame's block both call it, the
   frame carrying it onto its own scale the way 017's comment size already does.
4. **The same ladder read downwards is the comment** (FR-015, US4): the weight first, then the size, with the
   smallest size's case staying 017's derived 10. This moves a **shipped** rule, so its own records carry the
   dated report and the new case is measured here (quickstart rows 8b and 14).
5. **Nothing is stored, configured or translated** (FR-010, A6): no new key, no new field in any record, no entry
   in the reader's Appearance list, no locale string — the ladder is derived and the two heavier rungs are values
   no control offers (017's derived 10-point comment size is the precedent).
6. **Every offset stays a content offset** (FR-011): a mark is not a sentence delimiter, so the step list is the
   one the same text with its markers written as spaces gives, and the two producers that cut a speech into
   sentences map their local cuts back through the display one helper.
7. **A refused shape is the reader's own text** (FR-002, FR-014): painted and read as written, never repaired,
   never silently dropped — which is why T002's cases are the guard for `#hashtag`, `#1 best`, `### `, a lone `#`,
   `  # Title` and `# Title #`.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/019-head-tags/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up can
  make plain `flutter test` segfault on this 16 GB host)
- No ARB edit is expected in this feature (110 keys stay 110); if one lands, `flutter gen-l10n` follows it and
  `git status --short lib/l10n` shows the regenerated files are part of the diff
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; the walk driver is
  `specs/019-head-tags/scripts/klhu_walk_head.py`, its fixture beside it, and it imports
  `specs/016-sentence-reading/scripts/klhu_walk_step.py` and `specs/015-comment-tag/scripts/klhu_walk_comment.py`
  for the device mechanics, the content seeding and the `RESULT: PASS|FAIL` dispatch
- **That imported fixture format splits a file on a line starting with `## `** — exactly a subtitle's shape — so
  this feature's fixture and driver recognise a section header by its known keys, and assert the seeded content's
  own line count before driving (plan `ripple 8`)
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/019-head-tags`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the number every later tick is read against. Nothing is installed — this feature adds no dependency,
no asset and no platform file (FR-010, plan § Technical Context).

- [x] T001 Record the baseline in `specs/019-head-tags/tasks.md`'s Status before touching anything:
      **DONE 2026-10-13** — re-measured before the first edit, at 09:51 on `d51240e`: `flutter analyze` →
      `No issues found! (ran in 1.1s)`; `flutter test --concurrency=2` → `00:57 +663: All tests passed!`; the
      four ARBs → `110` keys each; `ls test/*.dart | wc -l` → `50`. **All four figures reproduce the Status's
      own**, so no earlier stage's number drifted and every row below is read against 663.
      `flutter analyze` (expect `No issues found!`) and `flutter test --concurrency=2` (expect **663 passing,
      0 failing**), the four ARBs' key count (expect **110** each) and `ls test/*.dart | wc -l` (expect 50) on
      `git rev-parse --short HEAD`, then write all four figures, the command and the date into the Status
      section beside the ladder paragraph. If a count differs, that difference is the first thing the handback
      reports: a drifted baseline is why every later tick would be measured against the wrong number.

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the one pure rule, the display's second elided kind, and the ladder every story's paint stands on.
Each is a **new file or an additive change**, which is why the checkpoint below is that no shipped paint moves at
all — a stronger claim than "the tests pass".

- [x] T002 [P] `test/head_tag_test.dart`: write the recognition table as its first group — one level-1 mark for
      **DONE 2026-10-13** — **RED as a compile error** (not an assertion failure), quoted:
      `test/head_tag_test.dart:12:8: Error: Error when reading 'lib/head_tag.dart': No such file or directory`,
      `test/head_tag_test.dart:17:21: Error: Method not found: 'headTagsOf'.` and `:28:20` the same. Green after
      T003: `flutter test test/head_tag_test.dart` → `00:00 +17: All tests passed!` (17 cases: four recognition,
      ten refused shapes, three on the comment exclusion).
      `# Basic Spanish 1` (`markEnd == 2`, the painted span `Basic Spanish 1`), one level-2 mark for
      `## Greetings` (`markEnd == 3`), and **no** mark for `#hashtag`, `#1 best`, `### note`, `#### `, a lone
      `#`, a lone `##`, `# ` with whitespace alone after it, `  # Title`, `#\tTitle`, `# Title #`, an empty text
      and a text whose only line is a mark followed by nothing. Run it and keep the RED output (a compile error
      on the base — `headTagsOf` does not exist; say so when the RED is one).
- [x] T003 `lib/head_tag.dart`: implement the rule green against T002 — `HeadTag` (`level`, `start`, `markEnd`,
      **DONE 2026-10-13** — `lib/head_tag.dart` created (`HeadTag`, `headTagsOf`, the `inside` exclusion and the
      line scan). `flutter test test/head_tag_test.dart` → `00:00 +17: All tests passed!`; `flutter analyze` →
      `No issues found! (ran in 0.8s)`. The rule is a new file and no shipped file calls it yet — which is what
      makes "the ladder alone changes nothing on screen" a claim the checkpoint below can check with a diff.
      `lineStart`, `lineEnd`) and `headTagsOf(content)`, derived on every read, with the doc comment naming why
      the trailing `#`-sequence is refused (FR-002) and why the line's first character is the only place a mark
      is read (FR-001). **Checkpoint**: `flutter test test/head_tag_test.dart` green; `flutter analyze` clean.
- [x] T004 [P] `test/comment_test.dart`: write the display's new group with 015's own cases left untouched beside
      **DONE 2026-10-13** — **RED as a compile error**, quoted:
      `test/comment_test.dart:495:22: Error: The getter 'heads' isn't defined for the type 'CommentDisplay'.`
      and `:496:22: Error: The method 'headSpans' isn't defined for the type 'CommentDisplay'.` Green after
      T005: `flutter test test/comment_test.dart` → `00:00 +48: All tests passed!` (42 → 48: the six new cases,
      **015's own 42 unmodified** — the elision they assert is the one this row extends, not one it re-cuts).
      it — the marker's `[start, markEnd)` is gone from `displayOf`'s `text` while a tag's is gone as before,
      `toContent(toDisplay(o)) == o` and `toDisplay(toContent(d)) == d` for every offset outside an elided span,
      a text with no mark and no tag has `text == content` with both mappings the identity, and `headSpans()`
      answers `(start, end, level)` in display offsets with a comment's own characters cutting a marked line's
      span. Run it and keep the RED output.
- [x] T005 `lib/comment.dart`: extend the display green against T004 — the elided spans of both kinds merged in
      **DONE 2026-10-13** — `lib/comment.dart`: `heads`, `headSpans()`, the merged `_elided` list the two
      mappings and `displayOf` now iterate, and `import 'head_tag.dart'`. Green: `00:00 +48: All tests passed!`
      on that file; the suite's 015 and 016 files run **unmodified** (Phase 2's checkpoint below quotes it).
      text order inside `toContent`/`toDisplay` and `displayOf`'s buffer, the new `heads` field and `headSpans()`,
      and the class's own doc comment gaining this feature's date and the second kind of never-painted character.
- [x] T006 [P] `test/appearance_store_test.dart`: write the ladder's cases — the six rungs in order with their
      **DONE 2026-10-13** — **RED as a compile error**, quoted:
      `test/appearance_store_test.dart:215:26: Error: Member not found: 'rungs'.` (and `:217:26` the same),
      `:228:26: Error: Member not found: 'ReadingSize.rungOf'.` Green after T007: `flutter test
      test/appearance_store_test.dart` → `00:00 +25: All tests passed!` (18 → 25: the ladder, the reader's rung,
      the marks' five rows, the clamp, and both comment directions).
      weights, the reader's own rung for each of the four sizes and for a bold face at each size, the title's and
      the subtitle's rung for each reader rung (the five rows of `data-model.md`), the clamp at the last rung, and
      the comment's step down for all six cases (the four regular sizes, the derived 10, and a bold body's same
      size at the regular weight). Run it and keep the RED output.
- [x] T007 `lib/appearance_store.dart`: implement the ladder and the two directions green against T006 — one
      **DONE 2026-10-13** — the ladder lives on `ReadingSize`: `rungs`, `rungOf`, `headingRungFor`,
      `commentRungFor` (which calls 017's own `commentPointsFor`, so the regular body's four values come from
      one source). Two analyzer lints this row introduced and fixed in the same pass: `FontWeight.index` is
      deprecated (→ `.value`, more precise) and the display's private constructor wanted initializing formals
      (`CommentDisplay._(this.text, this.comments, this.heads, this._elided)`). **Checkpoint**:
      `flutter analyze` → `No issues found! (ran in 0.8s)`; `flutter test --concurrency=2` → `00:57 +693: All
      tests passed!` (663 + this phase's 30 new cases); `git diff --stat lib/reading_view.dart
      lib/video_painter.dart lib/reader_service.dart lib/speech_resolver.dart lib/video_timeline.dart
      lib/video_renderer.dart` → **empty**, so nothing on screen has moved yet.
      helper returning a mark's rung for a level, and one returning a comment's, both reading
      `ReadingSize`/`ReadingTypeface` and storing nothing, with the doc comment naming the reader's own answer of
      2026-10-13 and the derived-weight precedent.
      **Checkpoint**: `flutter analyze` clean; `flutter test --concurrency=2` = T001's count; `git diff --stat
      lib/reading_view.dart lib/video_painter.dart` → **empty** (the two paints have not been touched yet, and
      the ladder alone changes nothing on screen).

---

## Phase 3: User Story 1 — a marked line is painted at its rung, the marker absent (P1) 🎯 MVP

**Goal**: with a content whose lines carry `# ` and `## `, the page paints each at the rung the ladder gives it —
its size **and** its weight, in the reader's own face — and no marker character is painted anywhere, while every
unmarked shape is what it was.

**Independent Test**: open a content of one title, one subtitle, a body and a comment line: the markdown's own
text carries no `#`/`##`, the four offered sizes paint `14/18`, `18/24`, `24 w400`/`24 w700` and `24 w700`/`24
w900` for subtitle/title, a bold body's marks are bigger and lighter, and a content with no mark paints exactly
what the baseline painted.

### Tests for US1 ⚠️ (write first, run RED)

- [x] T008 [US1] `test/reading_view_head_test.dart`: write the paint group from `quickstart.md` 5 — with each
      **DONE 2026-10-13** — **RED as assertion failures** (the file compiles; the paint is what is missing):
      `flutter test test/reading_view_head_test.dart` → `+4 -6: Some tests failed`, quoting
      `Expected: <24>` / `  Actual: <null>` on the rung cases and `Expected: FontWeight:<FontWeight.w700>` /
      `Actual: <null>` at xlarge. Green after T010: `00:02 +10: All tests passed!`.
      reader rung and each of the six faces in force, a `#` line's spans carry the rung's `fontSize` and
      `fontWeight` in the reader's own family; no painted span's text contains the marker's characters; and every
      unmarked shape (`#hashtag`, `#1 best`, `### `, a lone `#`, a mid-line `#`, `  # Title`, `# Title #`) paints
      exactly the spans a baseline capture shows. Run it and keep the RED output.
- [x] T009 [US1] `test/reading_view_head_test.dart`: add `quickstart.md` 5b — a bold face (`bold`, `serif-bold`,
      **DONE 2026-10-13** — the group is the same file's second half, so it has its own RED inside the same
      run (`+4 -6` above counts it): the two bold rows failed on `null` weights, and the family row passed at
      RED because nothing sets a family yet — the honest shape, not a test that only fails once written.
      `mono-bold`) at each of the four sizes: below `xlarge` the marks are the regular rungs above the body
      (bigger and lighter), at `xlarge` both marks are `24 w900` and equal, and no case paints a mark in a family
      the reader did not choose. Run it and keep the RED output.

### Implementation for US1

- [x] T010 [US1] `lib/reading_view.dart`: green against T008/T009 — `_buildSpans()`'s cut set gains the display's
      **DONE 2026-10-13** — `lib/reading_view.dart`: `_buildSpans` cuts at `display.headSpans()` beside the
      highlight's and the comments' boundaries, and `_spanPaint` paints a covered run at its rung (size **and**
      weight, `ReadingSize.headingRungFor`) with a comment's own `commentRungFor` winning where the two meet.
      One of this row's own cases was written wrong and the run caught it: at `small` the **subtitle** is 14 and
      the title 18 — the ladder's table, not my first guess — fixed in the test, not worked around in the paint.
      **Checkpoint**: `flutter analyze` → `No issues found! (ran in 0.8s)`; `flutter test
      test/reading_view_head_test.dart` → `00:02 +10: All tests passed!`; the 015 and 017 page files →
      `00:04 +22: All tests passed!`; whole suite → `00:59 +703: All tests passed!` (693 + 10).
      heading boundaries, and `_spanPaint` gives a run inside a heading span its rung's `fontSize` and
      `fontWeight` (both from T007's helper) while the highlight's background stays orthogonal to it and a
      comment's own characters keep their own treatment (FR-012).
      **Checkpoint**: `flutter test test/reading_view_head_test.dart test/reading_view_comment_test.dart` green;
      `git diff --stat lib/reading_view.dart` shows the two hunks named above and nothing else.

---

## Phase 4: User Story 2 — the marker never reaches the voice (P1)

**Goal**: no read path hands the engine a `#` that is a mark — a title's sentence, a step, ⏭ or a resume — and
every offset the app maintains is still the content's own, so 016's steps and highlight are unmoved.

**Independent Test**: resolve a marked text and read the speeches: `# Basic Spanish 1` yields an utterance
`Basic Spanish 1` with the sentence's own `start`/`end`; a marked line carrying a comment reads the title's words
then the comment's; a line that is only `#` is read as written; and a text with no mark produces exactly the
strings and offsets of the baseline.

### Tests for US2 ⚠️ (write first, run RED)

- [x] T011 [US2] `test/speech_resolver_test.dart`: write the mark group (the display-derived words, the offsets,
      **DONE 2026-10-13** — **RED as a compile error** on the new field: `Error: The getter 'display' isn't
      defined for the type 'ParagraphSpeech'` → `+0 -1: Some tests failed`. Green after T014/T015:
      `flutter test test/speech_resolver_test.dart` → `00:00 +17: All tests passed!` (12 → 17: five cases). The
      re-cut: the file's shipped invariant case now carries a `reason` naming its shape (*no tag and no mark:*
      *display is null for every speech*), and the mark group asserts the other one —
      `(text: 'Basic Spanish 1', start: 2, end: 17)` from `sentenceAt` over the range of the speech's own text.
      a marked line with a comment, a lone `#`, and a content with no tag and no mark whose speech has
      `display == null` and `text == content.substring(start, end)`), and **re-cut the file's own invariant case
      at `:106`** to that pair of shapes with a name that says which is which. Run it and keep the RED output.
- [x] T012 [US2] `test/step_ranges_test.dart`: add the marked variant beside the reader's own content — the same
      **DONE 2026-10-13** — the control ran **green before the first edit** (its point):
      `flutter test test/step_ranges_test.dart` → `+12: All tests passed!` with the new group in place, and again
      after T014/T015. One of my own three cases was wrong and the run caught it — it compared the reader's
      unmarked content against the *space-written* variant, which is a different text by two and three
      characters, so the offsets could never match; it asserts the reader's own seven steps instead.
      text with `# ` written as `  ` gives the same ranges, in the same order, and the marks are never steps of
      their own. **This row is the control, not a RED**: the reader's own content (seven lines) and the marked
      variant both pass on the base, and they must still pass after T014/T015 — record the green run before the
      first edit, because a step list is what a mark is most likely to disturb.
- [x] T013 [US2] `test/reading_view_head_test.dart`: add the read group from `quickstart.md` 6 — the utterance
      **DONE 2026-10-13** — **RED as assertion failures**, quoted: `Expected: ['Basic Spanish 1',
      'Greetings', 'Hola.']` / `  Actual: ['# Basic Spanish 1', '## Greetings', 'Hola.']` (the marker still
      reaching the engine) and, on the control, `Expected: '# Basic Spanish 1'` / `  Actual: 'Basic Spanish 1'`
      → `+10 -2: Some tests failed`. Green after T014/T015: `00:02 +12: All tests passed!`. **Two of this row's
      own traps are worth keeping**: the second pump in one test must carry a `ValueKey` (the same widget type
      updates the existing State in place, so the second page read the first content) and its store must have a
      directory of its own (the preset seeding is once per directory) — without both, the control passed
      vacuously against the first text, which is exactly the shape a RED must not be.
      list the page hands the reader per press on a marked text, and the same list on the same text with the
      markers written as spaces, asserted equal but for the markers themselves. Run it and keep the RED output.

### Implementation for US2

- [x] T014 [US2] `lib/speech_resolver.dart`: compute the content's display once, give every speech its own text
      **DONE 2026-10-13** — `lib/speech_resolver.dart`: `displayOf(content)` once, handed down as
      `display` (`null` when nothing is elided — `shown.text.length == content.length`), and every speech's words
      built from it through one `_words(display, content, from, to)` on all three paths (标准, 014's turns, 015's
      comments), with the language detected on the same words. `test/speech_resolver_comment_test.dart` →
      `00:00 +16: All tests passed!` — 015's own cases unmodified.
      from it (the standard path, 014's turns, 015's comments), and set the speech's `display` — **null when the
      content holds nothing elided**, which is what keeps every text without a tag or a mark byte-for-byte what
      it was (FR-010, SC-003).
- [x] T015 [US2] `lib/reader_service.dart`: `ParagraphSpeech` gains the nullable `display` field and the helper
      **DONE 2026-10-13** — `lib/reader_service.dart`: `ParagraphSpeech.display` (nullable, last argument),
      `sentenceAt(TextSegment)` (the words from the display, the span in content offsets; with no display,
      today's own arithmetic), and `_sentencesOf` reads both from it. **Checkpoint**: `flutter analyze` →
      `No issues found! (ran in 1.1s)`; `flutter test test/speech_resolver_test.dart
      test/speech_resolver_comment_test.dart test/step_ranges_test.dart test/reader_service_test.dart` →
      `+17`, `+16`, `+12`, `+18` all passed; `grep -rn "content.substring(start, end)" test/` → **empty** (the
      literal the checkpoint was watching for is gone from every file — the two producers read the speech's
      pair instead), and `flutter test --concurrency=2` → `00:58 +713: All tests passed!` (703 + 10).
      that turns one of the speech's own local sentence ranges into its words and its span in **content** offsets;
      `_sentencesOf` uses it instead of slicing the speech's text directly (the timeline's mirror does the same in
      T018).
      **Checkpoint**: `flutter analyze` clean; `flutter test test/speech_resolver_test.dart test/step_ranges_test.dart
      test/reader_service_test.dart test/speech_resolver_comment_test.dart` green; `grep -rn "content.substring(start, end)"
      test/` shows only T011's re-cut case.

---

## Phase 5: User Story 3 — the video's frames paint the marked line by the same rule (P2)

**Goal**: a frame whose slot holds a marked line paints it at the rung's size and weight, carried onto the frame's
own scale, with no marker character in the block — and every unmarked slot's frames are what 012 produces today.

**Independent Test**: render a marked content on the device and read the renderer's own lines: the title's slot
reports `text=<the title's own characters>` and its frame's ink box is taller and heavier than a body frame's at
the same scale; a frame holding a title line over body lines paints them separately; an unmarked content's frames
are byte-identical to the baseline's.

### Tests for US3 ⚠️ (write first, run RED)

- [x] T016 [US3] `test/video_timeline_test.dart`: write the plan's new group — a slot's `text` carries no marker
      **DONE 2026-10-13** — `flutter test test/video_timeline_test.dart` → `00:00 +20: All tests passed!`
      (15 → 20: five cases), and `test/video_comment_test.dart` → `00:00 +4: All tests passed!` after its one call
      site moves from `comments:` to `display:` (a third call site the plan had not counted — the renderer and
      that file both hand the display now). **Honest note on this row's RED**: it was written AFTER T018-T020's
      first pass, so no RED was taken for it — the file's tests-first rule was not honoured for US3, and this is
      the receipt's weakest point. Its first run did fail, on my own expectation (`Expected: <0> / Actual: <2>`:
      a video sentence's span is the WORDS' own, the marker is not spoken, so it is not covered — FR-011's own
      consequence, and the case now says so).
      and its `headings` name the lines that carry one, in that text's own index space with their levels; the end
      hold repeats them; `buildVideoPlan` takes the display and a content with no mark yields empty `headings`;
      the two call sites that pass a comment list are re-cut (checked by grep, not by memory). Run it and keep the
      RED output.
- [x] T017 [US3] `test/video_painter_test.dart`: write the frame's group — a slot whose whole sentence is a title
      **DONE 2026-10-13** — `flutter test test/video_painter_test.dart` → `00:00 +28: All tests passed!` (26 →
      28). Written after T020 as well (the same deviation as T016), and it earned its keep immediately: its
      measurement failed on the first run — `Expected: a value greater than <42.0> / Actual: <42.0>` — because
      `_blockFor` decided the single-span shape by the number of cuts, and a mark whose line is the WHOLE slot
      adds no cut at all, so the title was painted at the frame's own size. The fix chooses the single span by
      what the slot carries (`headings.isEmpty && no comment boundary`), not by the cut count; 015's and 017's
      own cases stayed green through it.
      paints one run at the rung's size **and** weight, carried onto the frame's scale (the title's 24 `w700` over
      the body's 24 `w400` at `large`); a slot holding a title line over body lines splits at the heading
      boundary; a comment riding a marked line keeps its own step down; a slot with no mark is the one-span block
      the base paints. Re-read the file's own `_layoutOf`/`_stepsOf` helpers first: they recompute the producer's
      geometry, so they learn the new cut set rather than their cases being re-cut. Run it and keep the RED output.

### Implementation for US3

- [x] T018 [US3] `lib/video_timeline.dart`: `videoSentencesOf` uses T015's helper; `VideoSlot` gains `headings`
      **DONE 2026-10-13** — `lib/video_timeline.dart`: `VideoSlot.headings`, `_headingsOf` (the display read
      onto a slot's own text, clamped to the slot's characters — a line a sentence boundary cuts is painted as
      far as the slot carries it), `videoSentencesOf` and `buildVideoPlan` reading the speech's own pair, and
      the end hold repeating the last slot's spans with its text. **Checkpoint**: `flutter analyze` →
      `No issues found! (ran in 0.8s)`; `flutter test test/video_timeline_test.dart` → `00:00 +20: All tests
      passed!`; the suite's 012 files unmodified and green.
      (a list of `(start, end, level)` inside the slot's own text, filled from the display for every mark whose
      line lies inside the slot's span); `buildVideoPlan`'s `comments` parameter becomes an optional nullable
      `display` carrying both the comments and the marks, so the two call sites that pass a comment list are the
      only re-cuts.
- [x] T019 [US3] `lib/video_renderer.dart`: pass the content's display into the plan (one argument at the call
      **DONE 2026-10-13** — `lib/video_renderer.dart`: `display: displayOf(content)` in place of
      `comments: commentsOf(content)`, comment included. The call sites that pass a comment list are **three**,
      not the plan's two: `test/video_comment_test.dart:45` had to move with it (the analyzer caught it: *The
      named parameter 'comments' isn't defined*), and `test/video_renderer_test.dart` → `00:05 +22: All tests
      passed!` with the renderer's own lines unchanged.
      site), so a render's blocks and a page's spans come from one resolution.
- [x] T020 [US3] `lib/video_painter.dart`: `_blockFor` splits the block at the slot's heading spans as well as at
      **DONE 2026-10-13** — `lib/video_painter.dart`: `_blockFor` builds the block's runs from the cut set
      (the slot's `headings` beside 017's `commentStart`), each run at the rung the ladder gives it — size AND
      weight onto the frame's own scale — with the weight set only where it differs from the frame's, so a
      regular face's blocks are byte-identical to today's. `_commentSizeOf` is gone: the comment's size now comes
      from the same `commentRungFor` the page uses (FR-015), one rule in both paints. **Checkpoint**:
      `flutter analyze` clean; `test/video_painter_test.dart` → `+28`, `test/video_comment_test.dart` → `+4`,
      `test/video_timeline_test.dart` → `+20`; whole suite → `00:58 +720: All tests passed!` (713 + 7).
      the comment boundary, giving each run the rung's size and weight on the frame's own scale — where a
      comment's characters sit on a marked line, the comment keeps its own step down (FR-012).
      **Checkpoint**: `flutter test test/video_timeline_test.dart test/video_painter_test.dart
      test/video_comment_test.dart test/video_pictures_test.dart` green; `flutter analyze` clean.

---

## Phase 6: User Story 4 — the ladder quiets a comment as well as it raises a mark (P2)

**Goal**: with a bold face in force a comment is the sentence's own size at the regular weight; with a regular
face it is exactly what 017 shipped; and 017's own records carry the dated report of the rule that moved.

**Independent Test**: with `bold` in force, open a content whose sentence carries a comment: the comment's span
carries the sentence's `fontSize` at `w400`, and with `default` in force the same content's comment is one offered
size down at the same weight — with 017's own figures quoted beside it.

### Tests for US4 ⚠️ (write first, run RED)

- [x] T021 [US4] `test/reading_view_comment_test.dart`: write the amended-rule group from `quickstart.md` 8b — a
      **DONE 2026-10-13** — the group lives in 017's own page file (the row's letter) and sweeps all four
      sizes both ways: `bold||<size>` → the comment is the body's own size at `w400`, `default||<size>` → 017's
      `24 → 18`, `18 → 14`, `14 → 12`, `small → 10`, plus *a marked line that carries a comment keeps both
      treatments apart* (medium: the title 24, the comment 12). `flutter test test/reading_view_comment_test.dart`
      → `00:06 +24: All tests passed!` (15 → 24: nine new cases). **The RED, honestly**: the rule landed in T007
      and T010, so a pre-implementation tree no longer exists for this row; the RED was taken by a controlled
      mutation instead — `_spanPaint`'s comment branch put back on 017's `(commentPointsFor(points), weight)`
      and the case run: `Expected: <14>` / `  Actual: <12.0>` → `+2 -1: Some tests failed` (the regular-face
      case and the body's own weight still passed, which is what says the mutation moved only the bold rule).
      Restored, `flutter analyze` → `No issues found! (ran in 0.8s)`.
      bold body's comment at each of the four sizes (same size, regular weight), the regular face's four cases
      asserted beside it as 017 shipped them (`24 → 18`, `18 → 14`, `14 → 12`, `small → 10`), and a marked line
      that carries a comment keeping both treatments apart. Run it and keep the RED output.

### Implementation for US4

- [x] T022 [US4] `specs/017-bold-comment-size/breakpoint.md`: re-read the amendment section against the finished
      **DONE 2026-10-13** — the amendment section re-read **row by row against the walker**, not against its
      docstring, and corrected in place with the date. What the reading found, and what the first version of
      that section had said instead:
      (1) rows **8, 9 and 12 DO drive the three bold faces** (`set_appearance` over `FACES`) — the section said
      "a regular face" — and what saves them is that their content carries **no comment**: their claims are
      directional, so FR-015 moves their ink **numbers** (a bold body's comment is the same size now, not one
      size down) and not their verdicts;
      (2) row **10** is the only regular-face row, so its `24 → 18` / `14 → 12` / ten-point floor stand exactly;
      (3) **row 11 is the row that needs re-measuring** — it sets no appearance of its own, runs on whatever
      `reading_appearance` the device holds (the 8/9/12 sequence leaves a bold one), and asserts the frame's
      comment line is smaller, which FR-015 makes false on a bold record. Its re-run with the appearance pinned
      is Phase 7's, not this row's: a closed walk's receipt belongs to the revision that was walked.
      Corrected in `specs/017-bold-comment-size/breakpoint.md` (its amendment section) and its `tasks.md` bullet.
      **Checkpoint**: `flutter test test/reading_view_comment_test.dart test/appearance_store_test.dart` →
      `00:06 +24` and `+25`, both all passed; `check_tasks_format.py specs/017-bold-comment-size` and
      `task_id_audit.py specs/017-bold-comment-size` → 017's own counts unchanged.
      tree — the rule it names (the weight first, the size second) is T007's, the row that measures the bold case
      is this feature's `quickstart.md` 8b and **14**, and the section's claims about 017's own rows standing are
      re-checked by grepping its fixture's face (regular) rather than by trusting the note. Correct the section in
      place with a date if the code landed differently; the file's prose is a closed feature's record and is only
      ever corrected, never rewritten.
      **Checkpoint**: `flutter test test/reading_view_comment_test.dart test/appearance_store_test.dart` green;
      `python3 …/check_tasks_format.py specs/017-bold-comment-size` and `…/task_id_audit.py specs/017-bold-comment-size`
      still green (32/32, format OK) after this feature's edits to that directory.

---

## Phase 7: The device walk

**Purpose**: the rows a unit test cannot hear or measure. Every row appends its evidence to
`specs/019-head-tags/breakpoint.md` and is dispatched by the driver T023 writes, one row per run (011's, 015's and
016's own convention: the task's number, the quickstart's row number and the driver's `PARTS` key are one value).

- [x] T023 `specs/019-head-tags/scripts/klhu_walk_head.py`: write the driver and its fixture beside it, importing
      **DONE 2026-10-13** — `specs/019-head-tags/scripts/klhu_walk_head.py` + `klhu_head_fixture.txt`
      (sections `main` 7 lines/63 chars · `spaced` 7/63 · `cjk` 3/16 · `control` 3/50, read by their **known
      keys** — this feature's own content carries `## Greetings` as a subtitle, which 015's leading-`## `
      splitter would read as a section). It imports 016's walker for the mechanics and 017's for the appearance
      control and the ink measurement; `main` names rows 11/12/14 as owed rather than dispatching into a stub
      (014's convention). Three import-level corrections the first runs caught: `painted_text` lives in 015's
      module (016 does not re-export it), `open_section(..., text=)` likewise (016's own `open_section` is a
      different function with a different signature), and the face ids are `REGULARS`+`FACES` (a lookup over
      `FACES` alone has no `serif`).
      `specs/016-sentence-reading/scripts/klhu_walk_step.py` (which sits on 015's, 014's and 012's) for the device
      mechanics, the content seeding and the `RESULT: PASS|FAIL` dispatch. The fixture carries a marked content
      (title, subtitle, body, a line carrying a comment), the same content with the markers written as spaces, a
      Chinese pair, and a regular-face control; **its section headers are recognised by their known keys**, not by
      a leading `## ` (the imported format's own collision), and the driver asserts each seeded content's line
      count before driving.
- [x] T024 Walk `quickstart.md` row 10 into `specs/019-head-tags/breakpoint.md`: the page on the device — the
      **DONE 2026-10-13** — `/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py 10` →
      **`RESULT: PASS (14/14)`**, recorded in `specs/019-head-tags/breakpoint.md`. The dump's own text is
      `'Basic Spanish 1\n\nGreetings\n\nHola. Adiós.\n\nHow are you?'` — no marker painted anywhere; one ▶
      press gives `spoken: ['Basic Spanish 1']` and `ranges: [(0, 17)]` (the app's own `klhu speak`/`klhu read
      range` lines), i.e. the words are the line's and the range is the **paragraph's** — 016's unit unmoved,
      which is FR-011's two halves at once; and the five captures' ink is strictly increasing —
      `small 10205 → medium 14245 → large 20070 → xlarge 27210 → bold_xlarge 33003` (`/tmp/019_row10_*.png`).
      One of my own checks was written wrong and the run caught it before the fix: the sizes' labels are
      `Small/Medium/Large/Extra large` (017's `SIZES`), not the record's own keys.
      dump's text carries no marker, every `klhu speak` line's quoted text is the line's own words, and the five
      screenshots show the ladder's rows (`small` 14/18, `medium` 18/24, `large` 24 regular/24 bold, `xlarge` 24
      bold/24 black, and the bold-face `xlarge` pair). Proves FR-003, FR-004, FR-005, FR-007, SC-001, SC-006.
- [x] T025 Walk `quickstart.md` row 11 into `specs/019-head-tags/breakpoint.md`: ▶ and ⏭ through the marked
      **DONE 2026-10-13** — `/usr/bin/python3 -u …/klhu_walk_head.py 11` → **`RESULT: PASS (12/12)`**,
      recorded in `breakpoint.md`. The marked content and the `spaced` control (63 chars each) were each driven
      with two ▶ presses and one ⏭: the ranges are equal at every press — `[(0, 17)], [(19, 31)], [(33, 63)]` —
      while the words differ by the marker's characters alone (`'Basic Spanish 1'` / `' Basic Spanish 1'`,
      `'Greetings'` / `' Greetings'`), and no utterance in any press carries a `#`. The highlight's band walked
      down (top row 472 → 732). **One figure is worth the row on its own**: the marked title's highlight box
      carries **33680** yellow pixels against the control's **12720** for the same characters and the same
      geometry — the rung, live on the page (24 against the reader's own 14), picked up by 017's ink measurement.
      content — the highlight's sequence and the read's own ranges against the same text with the markers
      absent, with no utterance carrying a marker. Proves FR-004, FR-011, SC-004.
- [x] T026 [US3] Walk `quickstart.md` row 12 into `specs/019-head-tags/breakpoint.md`: the video — the title's
      `text=` count, the ink box measured twice (a regular body at `large`, a bold body at `xlarge`), the mixed
      slot, and the Chinese pair for the synthesised weight, through the renderer's own lines and the driver's
      `scan_frame`. Proves FR-013, SC-003, SC-005.
      **DONE 2026-10-13** — `/usr/bin/python3 -u …/klhu_walk_head.py 12` → **`RESULT: PASS (66/66)`**, recorded in
      `breakpoint.md`. Five renders, each seeded and launched fresh: the title's slot reports `text=15` —
      `Basic Spanish 1`, the marker excluded — and `span=2..17` in every appearance, with the file pulled back and
      the runs the file's own frames (`222 of 222`; `129 of 129` on the Chinese pair). The rung reaches the frame
      (`small` 54px against `xlarge` 76px for the same characters) and its **ceiling** shows up as a
      byte-identical box for `bold`/`xlarge` and `Serif`/`xlarge` — 554×76, the same rows — which is SC-006 on a
      frame: at the top size both bodies' title rung is the same rung. The mixed slot (slot 3, `text=19`) is the
      paragraph's second sentence with its comment, the tag's characters in neither part; the Chinese pair paints
      the same 9 characters and the same span in both faces, differing by the synthesised weight alone
      (124px against 130px).
      **Two failures before the pass, both mine**: the mixed slot's expected count assumed the comment rides the
      first sentence (015's rule makes it the second), and the Chinese expectation omitted the newline and the
      comment. **The row's own finding, worth keeping**: a second render in one run never reports `klhu render
      done` (300 s, twice, two faces) — dismissing the finished render's review screen is not enough, a clean
      `force-stop` + relaunch between renders is. Every other driver in this walk (015's and 017's included)
      renders once per run; this row writes the rule down. No `lib/` change came out of it.
- [x] T027 Walk `quickstart.md` row 14 into `specs/019-head-tags/breakpoint.md`: a bold body's comment measured on
      **DONE 2026-10-13** — `/usr/bin/python3 -u …/klhu_walk_head.py 14` → **`RESULT: PASS (7/7)`**,
      recorded in `breakpoint.md`. On 017's own comparison fixture (`Hola.` / `[注] Hola.`, the same glyphs in
      both lines so the ink heights measure the size alone): a **bold** body's comment is the sentence's own
      height at every rung — 22, 27, 35, 46 px — while a **regular** body's is 22 against 27 and 18 against 22,
      i.e. 017's shipped `24 → 18` and `14 → 12` seen as ink. So FR-015 is real for the bold body **only**, and
      the two rules coexist on one page with the body's weight deciding which applies. This row is also the
      measurement 017's own row 11 cannot take (it sets no appearance), which is what T022's correction points
      at.
      the page — the comment's ink height and the sentence's at each of the four sizes, with the regular face's
      pair beside them as 017's own measurement. Proves FR-015, SC-007.

**Walk checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`, and no row cites a driver
command that does not implement it (extend T023's dispatch in the same pass, or record the row as hand-run).

---

## Phase 8: Polish & cross-cutting concerns

- [x] T028 Run `quickstart.md` row 13's structural checks into `specs/019-head-tags/breakpoint.md`:
      **DONE 2026-10-13** — the structural checks, all five green on the finished tree:
      `git diff --stat pubspec.yaml pubspec.lock android/ ios/ lib/l10n/ lib/appearance_screen.dart` → **empty**
      (the Appearance control is untouched — the ladder is derived, never offered); the four ARBs at **110** keys
      each (`app_en`, `app_es`, `app_zh`, `app_zh_Hans`); `flutter gen-l10n` → `diff -r` over `lib/l10n/` **byte
      for byte identical** (a copy taken before the regeneration); `test/l10n_keys_test.dart` →
      `00:00 +3: All tests passed!`. Proves FR-010, SC-003.
      `git diff --stat pubspec.yaml pubspec.lock android/ ios/ lib/l10n/` → **empty**, the four ARBs at **110**
      keys each, `flutter gen-l10n` reproducing the committed Dart byte for byte, `test/l10n_keys_test.dart`
      green, and `git diff --stat lib/appearance_screen.dart` empty (the Appearance control is untouched — the
      ladder is derived, never offered). Proves FR-010, SC-003.
- [x] T029 Re-run the sibling drivers' parsers into `specs/019-head-tags/breakpoint.md` against the app's own
      **DONE 2026-10-13** — the sibling parsers read the app's own lines (`grep -rn "klhu speak`/`klhu render`
      `specs/*/scripts/*.py` → 010's, 011's and 012's readers, plus the modules 015/016/017 import): **no field
      moved**, and three device rows that read them were re-run on this tree — 016's row 5 →
      `RESULT: PASS (13/13)` (`klhu read range` + `klhu speak`), 017's row 10 → `RESULT: PASS (4/4)` (the
      regular-face comment rule still holds under 019's code), 015's row 17 → `24/24 checks passed` (its summary
      line is not the `RESULT:` shape, which is why a first attempt looked like a failure).
      **One expectation in this row was wrong and the run corrected it**: `grep -rn "'# \|\"# " test/` is **not**
      empty — it has three hits, all in `test/speech_resolver_test.dart` (lines 198, 204, 222), which are this
      feature's own new cases. What the check was for holds: no **shipped** test or fixture carries a mark.
      lines: `grep -rn "klhu speak\|klhu render" specs/*/scripts/*.py` and run the 015, 016 and 017 drivers' rows
      that read those lines, confirming no field moved — this feature changes values for marked texts only, and no
      shipped fixture carries a mark (`grep -rn "'# \|\"# " test/` → empty).
      Proves FR-010, SC-003.
- [x] T030 Run both list checkers and quote them verbatim in `specs/019-head-tags/tasks.md`'s Status:
      **DONE 2026-10-13** — both checkers, verbatim:
      `check_tasks_format.py specs/019-head-tags` → `OK: format, sequencing and spec-id coverage check out`;
      `task_id_audit.py specs/019-head-tags` → `019-head-tags: 31 tasks, 27 done, 3 [P]`. Re-run on the feature
      this pass edited: `specs/017-bold-comment-size` → `OK: format, sequencing and spec-id coverage check out`
      and `017-bold-comment-size: 32 tasks, 32 done, 7 [P]` — its counts unchanged, its two record files edited
      by T022 only.
      `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py
      specs/019-head-tags` and `…/task_id_audit.py specs/019-head-tags`. A red checker here is fixed in this file,
      not explained away; this row also re-runs the two checkers on `specs/017-bold-comment-size` after this
      feature's edits to its records.
- [x] T031 Re-take the suite count on the finished tree into `specs/019-head-tags/tasks.md`: `flutter analyze` and
      **DONE 2026-10-13** — the closing re-measure on the finished tree: `flutter analyze` →
      `No issues found! (ran in 0.8s)`; `flutter test --concurrency=2` → `00:59 +729: All tests passed!`. Read
      against T001's **663**, the difference is **+66**, decomposed by file with each file's own run:
      `head_tag_test.dart` **new 17** · `reading_view_head_test.dart` **new 12** · `comment_test.dart` 42 → **48**
      (+6) · `appearance_store_test.dart` 18 → **25** (+7) · `speech_resolver_test.dart` 12 → **17** (+5, and its
      own invariant case re-cut at what was `:106`) · `step_ranges_test.dart` 9 → **12** (+3) ·
      `video_timeline_test.dart` 15 → **20** (+5) · `video_painter_test.dart` 26 → **28** (+2) ·
      `reading_view_comment_test.dart` 15 → **24** (+9) · `video_comment_test.dart` **4, unchanged** (its one call
      site moved from `comments:` to `display:`). 17 + 12 + 37 = 66. Both checkers re-run after this file's last
      edit (see T030). **Rows still needing a walk: none** — all four of Phase 7 are PASS and recorded in
      `breakpoint.md` (10 `14/14`, 11 `12/12`, 12 `66/66`, 14 `7/7`).
      `flutter test --concurrency=2`, read against T001's **663** with the difference decomposed by file (two new
      test files, seven extended, the one re-cut case at `test/speech_resolver_test.dart:106`), then close the list
      — re-run both checkers after this file's last edit, correct any receipt in `tasks.md` or the four plan
      artifacts that has gone false, and hand back with the rows still needing a walk named one by one.

---

## Dependencies & ordering

- **T001** first, before any edit: every later tick is read against its numbers.
- **Phase 2 (T002-T007)** blocks every story: the rule (T003), the display (T005) and the ladder (T007) are what
  both paints and the resolution stand on. **T005 depends on T003** (the display calls the rule); **T008/T009/T010
  and T016/T017 depend on T007** (the paint reads the ladder).
- **US2 (Phase 4) blocks US3's tests**: T016's `headings` and T018's builder use T015's helper, and T017's frame
  asserts the rung T015 made reachable. T019 depends on T018's parameter change; T020 on T018's `headings`.
- **US4 (Phase 6)** depends on T007 (its comment direction is the same helper) and on T022's re-read of a closed
  feature's record, which must happen after the code lands rather than before.
- **The walk (Phase 7)** depends on its stories' code: rows 10 and 11 on US1+US2, row 12 on US3, row 14 on US4.
  T023 (the driver and its fixture) is written before its rows and depends on nothing else.
- **Phase 8** last: T028 and T029 need the finished tree, T030 the finished file, T031 everything.

## Parallel opportunities

- **T002/T004/T006 are three different test files** and can be written in one sitting; T003 and T005 are their
  implementations and each depends only on its own test row.
- **T008 and T011/T013 are different files** (`test/reading_view_head_test.dart` vs
  `test/speech_resolver_test.dart`), so US1's and US2's test rows can be written before either's code — but
  T009 shares T008's file and stays after it.
- **T016 and T017 are two files**; T019 is a one-line change in a third, and it may land beside T018.
- **Nothing in Phase 7 is parallel**: every row installs, drives and reads the same device, and they all append to
  one `breakpoint.md`. Two rows run one after the other even when their subjects are independent.

## Implementation strategy

The MVP is **Phases 2-4**: the rule, the display, the ladder, the page's paint and the resolution — demonstrable on
the device with rows 10 and 11 alone, which is the reader's own ask (`#` a title, `##` a subtitle, and the marker
neither seen nor heard). Phase 5 carries the same rule to the frames, Phase 6 settles 017's amended rule and its
report, and Phase 8 closes the receipts. Each story is independently demonstrable: US1 by row 10's screenshots,
US2 by row 11's log lines, US3 by row 12's frames, US4 by row 14's measurement.

## Notes

- The device rows are walked by hand first and scripted afterwards; the driver's own `PARTS` table is the
  authority on which rows are scripted, so a row added later extends it in the same pass.
- `test/l10n_keys_test.dart` is bidirectional: a key in three ARBs fails exactly as loudly as a key in five — this
  feature adds none, and T028 is the receipt.
- No `contracts/` directory for this feature: the interfaces it changes are in-process Dart types the app already
  owns, and the ladder is a derived value rather than a format.
- A mark's own elision moves painted text but no offset; the guard is `test/comment_test.dart`'s mapping cases
  (T004) plus 015's and 016's shipped suites, which run **unmodified**.
- `specs/019-head-tags/breakpoint.md` does not exist yet: T024 creates it, with its own environment table (build,
  device, package, the probe that produced each row's evidence).

## The stage's notes

- Both list checkers were run on this file after its last edit, and their own output is quoted here verbatim:
  `check_tasks_format.py specs/019-head-tags` → **`31 tasks (0 done), 3 marked [P]`**, the per-story block
  **`(setup/foundational/polish): 16`, `[US1]: 3`, `[US2]: 5`, `[US3]: 5`, `[US4]: 2`**, and
  `OK: format, sequencing and spec-id coverage check out`; `task_id_audit.py specs/019-head-tags` →
  **`31 tasks, 0 done, 3 [P]`** with no duplicate, no gap, no orphan id and no blank line between consecutive
  rows. Both are re-run in T030 after the implement stage's edits.
- **Two things this file's first draft got wrong, found by those two runs and fixed in the same pass rather than
  explained away**: T029's first line opened with prose and pushed its path onto the continuation line (the
  checker read the row as pathless), and nineteen blank lines sat between consecutive task rows (the house style
  keeps rows adjacent; the audit listed their line numbers). Neither is a formatting nicety: the first makes a row
  invisible to the machine reader, and the second is the shape a later append tends to reproduce.
- **Sibling rules are cited in words, never as bare ids**: 017's comment-size rule, 016's step rule, 015's display
  and 014's roles are named by description in this file, because the checker reads the requirement-id universe of
  *this* feature's `spec.md` and a foreign requirement token (`FR-` with another feature's number) would read as a
  missing requirement here.
- The quickstart landed **before** this list, so every walk row cites its number (`quickstart.md` 10, 11, 12, 14)
  and repeats no steps.

## Requirement coverage

| Requirement | Tasks that satisfy it |
|---|---|
| FR-001 (a mark is `#`/`##` at the line's first character + one space) | T002, T003, T024 |
| FR-002 (`### `, a lone `#`, whitespace, a leading-whitespace marker and a trailing `#` are the reader's text) | T002, T003, T008 |
| FR-003 (the marker is never painted; the page paints the display) | T004, T005, T008, T010, T024 |
| FR-004 (no resolution handed to the engine contains a mark) | T011, T014, T015, T024, T025 |
| FR-005 (a marked line is painted as a title or a subtitle, and no other line moves) | T008, T009, T010, T024 |
| FR-006 (the ladder: two rungs up for a title, one for a subtitle, clamped) | T006, T007, T008, T009, T010 |
| FR-007 (the rung decides size and weight; the reader's face decides the family) | T006, T007, T008, T009, T010, T017, T020 |
| FR-008 (a mark's scope is the line it starts) | T002, T003, T008 |
| FR-009 (a marker inside a comment's span is not a mark) | T002, T003, T021 |
| FR-010 (the reader's text is untouched; no key, no field, no control) | T014, T015, T028, T029 |
| FR-011 (the read's units are 016's: the same steps, the same offsets) | T012, T013, T014, T015, T025 |
| FR-012 (015's comment behaviour and 014's Format action are unchanged by a mark) | T010, T021, T022 |
| FR-013 (the video's frames paint a marked line by the same rule) | T016, T017, T018, T019, T020, T026 |
| FR-014 (a malformed or refused mark is the reader's characters) | T002, T003, T008 |
| FR-015 (a comment's step down takes the weight first, then the size) | T006, T007, T021, T022, T027 |
| SC-001 (the page paints the rungs and no marker, on the device) | T010, T024 |
| SC-002 (the three levels are ordered at every reader rung) | T006, T007, T008 |
| SC-003 (every unmarked shape is byte-identical; the frames' text carries no marker) | T008, T012, T016, T026, T028, T029 |
| SC-004 (the step list, the highlight and the utterances match the markers-as-spaces text) | T012, T013, T025 |
| SC-005 (a title frame's measurement, and the Chinese pair's picture) | T020, T026 |
| SC-006 (the three levels are strictly ordered except at the ladder's last rung) | T006, T009, T024 |
| SC-007 (a bold body's comment measures the same size at the lower weight; 017's figures hold) | T007, T021, T027 |

**Requirements of other specs this feature moves or re-cuts** (their ids are cited in words above, because they
are not this spec's to number): 017's comment-size rule (asserted for a bold body by T021 and T027, reported in
its own records by T022), the same feature's two success criteria that speak of a comment measuring *smaller*
(named in that feature's supersession note, re-checked by T022), its derived-size table (superseded for the bold
case, unchanged for the regular one — T021 asserts both sides), 015's display contract (extended, its own cases
unmodified — T004), and 016's step rule (unmoved — T012).
