# Tasks: A bold face, and a comment one size down

**Feature**: `017-bold-comment-size` | **Date**: 2026-10-12
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) |
**Data model**: [data-model.md](./data-model.md) | **Contract**: [011's appearance record](../011-reading-experience/contracts/appearance-format.md) (amended, dated) | **Validation**: [quickstart.md](./quickstart.md)
**Format**: `[ID] [P?] [Story] Description with file path`

## Status

**32/32 done (2026-10-12) — the implement stage is complete.** Phases 1-5 are closed: the six faces and the one
style seam, the comment's derived size in both paints, the two sibling features' records amended with dates, and
five device rows plus a structural row walked and green (`breakpoint.md`). The suite went 643 → **653 passing**
with the analyzer clean, and the siblings' own suites are green **unmodified** — which is FR-010's and FR-011's
receipt. **Nothing is owed**: the coverage table below maps every requirement to a ticked row. The baseline re-measured before the first
edit (T001, 12:52 on `3db8df5` + this feature's spec work): `flutter analyze` → `No issues found! (ran in 0.8s)`;
`flutter test --concurrency=2` → `00:57 +643: All tests passed!`. **The suite on the finished US1 tree: 643 → 647
passing, analyzer clean**, the four new cases being the store contract's three (`test/appearance_store_test.dart`
14 → `00:00 +17`) and the widget's own (`test/reading_view_appearance_test.dart` 6 → `00:03 +7`, cases 11-16
**unmodified**). The device rows 8, 9 and 12 all PASS (`breakpoint.md`). **US2 is closed too: the suite on the finished tree is 653 passing, analyzer clean** (six new cases: the store's
one, the page's four, the painter's one), with `test/comment_test.dart` (+42), 016's step suite (+11) and
`test/video_timeline_test.dart` (+15) all green **unmodified** — FR-010's and FR-011's receipts. **All five
device rows (8, 9, 10, 11, 12) are walked and green** (`breakpoint.md`), including 015's row 22 re-taken. Phase 5 closed it: the structural row (T027) with the key count at **110**, the two sibling receipts' dated
corrections (T028/T029), the suite re-taken (T031) and the checkers quoted (T030/T032).

**The walk's two files are owed by the walk rows, not by this list**:
`specs/017-bold-comment-size/scripts/klhu_walk_bold.py` (created by T009, extended by T024) and
`specs/017-bold-comment-size/breakpoint.md` (created by T010, appended to by every walk row).

## Grounding notes

- **D1** (research): the weight rides on the **face in code** — three more `ReadingTypeface` values, the record's
  grammar `<typeface>||<size>` untouched. T004 is the site; T002 is the grammar's own test.
- **D2**: the comment's size is **computed** from the text's size in one helper (24→18, 18→14, 14→12, 12→**10**),
  called by both paints and stored nowhere. T013/T016 are the helper and its cases.
- **D3**: the page's split comes from 015's **own** display resolution, never re-derived — FR-010's guard. T017
  and T018.
- **D4**: the frame's boundary is carried by a **nullable `VideoSlot` field**, filled by the two builders, because
  `start`/`end` are *content* offsets and the display elides the tag's characters. T019, T020, T015.
- **D5**: a bold value is its family at `w700`; `bold` alone names no family (the theme's own, which is the
  device's one real-bold family). T004, T007, T010.
- **D6**: 011's width guarantee is **re-measured per bold face** and its recovery is declared in advance. T011.
- **The reader's decision 5** (spec): six values, ordered by family, with the switch refused on its own cost. The
  three labels and the offered-list re-cut are that decision's footprint in code (T005, T002).
- **Corrected at this stage, and to be re-checked by the reviewer** (plan's ripple 10): the tests that move were
  found by grepping them. `test/reading_view_appearance_test.dart`'s `12.`/`13.`/`16.` do **not** pin the face set
  (they assert labels one per call, tap by name, and drag the list to its end) → **they run unmodified**. The two
  that do move are `test/appearance_store_test.dart:114-119` (which pins `['default', 'serif', 'mono']`) and
  `test/video_painter_test.dart`'s `_layoutOf`/`_stepsOf` helpers (one span → two, for a comment-carrying slot).

## Path conventions

Source `lib/`; tests `test/`; this feature's artifacts `specs/017-bold-comment-size/`; the generator is
`flutter gen-l10n` (its four generated Dart files are committed); the device is the AVD `klhu`
(`emulator-5554`, API 36, package `com.example.klhu`), installed with
`adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`; walk evidence lands in
`specs/017-bold-comment-size/breakpoint.md`; the walk driver is run **one quickstart row per invocation**
(`/usr/bin/python3 specs/017-bold-comment-size/scripts/klhu_walk_bold.py 8` — rows 8-12, the quickstart's own
numbers). The drivers need `/usr/bin/python3` (3.12): the default `python3` has no PIL.

## Phase 1: Setup

- [x] T001 Take the line's own baseline in `specs/017-bold-comment-size/quickstart.md`: `flutter analyze` and
      `flutter test --concurrency=2` on the checkout that is about to change, and confirm the pair the Status
      quotes (2026-10-12 11:22: analyzer clean, 643 passing) still reproduces; if it does not, the rows below are
      read against the number this row measures.

## Phase 2: Foundational

**Thin by construction, stated rather than filled.** The two stories touch disjoint code: US1 moves the face
list and the one style seam, US2 moves the comment's paint. The only file they share is
`lib/reading_view.dart`, where US1's seam change (T007) lands before US2's span split (T018) simply because US1
is P1 — no prerequisite is invented for it.

## Phase 3: User Story 1 — a bold face for every offered face (P1) 🎯 MVP

**Independent acceptance test**: open the appearance control on the device, pick each bold value, confirm it and
read: the record carries a two-part value (`bold||…`, `serif-bold||…`, `mono-bold||…`), the text is painted in
that family at weight 700, it survives a relaunch, and at `xlarge` the widest painted line is measured against
the page's width (quickstart rows 8, 9, 12).

### Tests for US1 ⚠️ (write first, run RED)

      **DONE 2026-10-12** — the baseline re-measured before the first edit, at 12:52 on `3db8df5` + this feature's
      spec work uncommitted: `flutter analyze` → `No issues found! (ran in 0.8s)`; `flutter test --concurrency=2`
      → `00:57 +643: All tests passed!`. **Both figures reproduce the pair `quickstart.md` carries**, so no
      earlier stage's number drifted and every row below is read against 643.
- [x] T002 [P] [US1] `test/appearance_store_test.dart`: re-cut the case that pins the offered name list
      (`:114-119`, `['default', 'serif', 'mono']` → the contract's six, with the case's own title) and add the
      three names' cases — a round-trip for each, `serif-bold||huge` → `(serif-bold, medium)`, `Helvetica||xlarge`
      → `(default, xlarge)` unchanged, and every offered face's `encode()` splitting into exactly two parts
      (INV-1/INV-2). **RED**: `byName` refuses the three names today, so the round-trips fail.
      **DONE 2026-10-12** — **RED as a compile/load error** (not an assertion failure), quoted:
      `Error: The getter 'weight' isn't defined for the type 'ReadingTypeface'` and `ReadingTypeface.bold,`
      `test/appearance_store_test.dart:194:21`, then `00:00 +0 -1: Some tests failed. / loading
      test/appearance_store_test.dart`. Green after T004: `flutter test test/appearance_store_test.dart` →
      `00:00 +17: All tests passed!` (14 → 17: the three names' round-trip, INV-1 over every offered face, and
      INV-9's families and weights). The re-cut case is the one that pins the offered list, its own title
      included.
- [x] T003 [P] [US1] `test/reading_view_appearance_test.dart`: the six labels offered; the preview painted in the
      bold weight **before** it is applied; with each bold value in force the reading text's and the editor's
      style carries that family at `FontWeight.w700` while the chrome's does not. **RED**: no bold label exists
      and no weight is set. The three shipped cases (`12.`, `13.`, `16.`) are **run unmodified** — and if one
      moves, it is re-cut and the deviation reported into `breakpoint.md`.

### Implementation for US1

      **DONE 2026-10-12** — **RED as an assertion failure**, and a *partial* one: `00:03 +6 -1`, the failure at
      the label loop's first missing chip (`expect(find.text(label), findsOneWidget)` → `findsNothing`), with
      cases 11-16 **passing** — which is the plan's own prediction (the shipped cases pin no set). Green after
      T004-T007: `flutter test test/reading_view_appearance_test.dart` → `00:03 +7: All tests passed!`, cases 11-16
      **unmodified**. Two test-side corrections on the way, both this pass's: the preview is the page's own
      **first paragraph** (011's `_previewText`), found by what it contains rather than by the whole content; and
      **`copyWith(fontFamily: null)` does not clear a family — it keeps the base style's**, so the assertion pins
      the *theme's own* family (which is what D5 means by "names no family"), read from the theme **before** the
      screen is pushed (an offstage route is invisible to `find`).
- [x] T004 [US1] `lib/appearance_store.dart`: the three values (`bold` with no family, `serif-bold` → `serif`,
      `mono-bold` → `monospace`), the weight each carries in code, and `all` in the contract's order (D1/D5).
      `decode`/`encode` are **not** touched — the grammar's own cases prove it.
      **DONE 2026-10-12** — `lib/appearance_store.dart`: the three values, `weight` as a code-only field on the
      face, `all` in the contract's order, and `familyFor`'s bold arms. `encode`/`decode` untouched (the
      grammar's own cases prove it), `flutter analyze` clean after the change.
- [x] T005 [US1] `lib/l10n/app_{en,es,zh,zh_Hans}.arb`: the three labels (`fontBoldLabel`,
      `fontSerifBoldLabel`, `fontMonoBoldLabel`), then `flutter gen-l10n` and the four regenerated
      `app_localizations*.dart` committed with them — 107 → **110** keys. This row precedes T006: the screen
      reads the keys this row creates.
      **DONE 2026-10-12** — the four ARBs gain `fontBoldLabel`, `fontSerifBoldLabel` and `fontMonoBoldLabel`
      (`Bold`/`Serif bold`/`Mono bold`, `加粗`/`衬线体加粗`/`等宽体加粗`, `Negrita`/`Serif negrita`/
      `Monoespaciada negrita`), `flutter gen-l10n` re-run, and each file re-counted: **110 keys** (107 + 3) in all
      four. This row preceded T006 on purpose: the screen reads the keys it creates.
- [x] T006 [US1] `lib/appearance_screen.dart`: `_faceLabel`'s three new cases and `_previewStyle`'s weight, so
      the candidate renders as it will be applied.
      **DONE 2026-10-12** — `lib/appearance_screen.dart`: `_faceLabel`'s three new cases and the candidate's weight
      in `_previewStyle`, so the preview renders as the page will.
- [x] T007 [US1] `lib/reading_view.dart`: the **one** style seam (`:2426-2439`) gains the weight — the rich text
      and the editor both go through it and neither reaches the chrome (011 FR-009).
      **DONE 2026-10-12** — `lib/reading_view.dart`'s one style seam (`_contentTextStyle`) gains the weight: the
      rich text and the editor both go through it, the chrome does not (011 FR-009), proven by T003's case 17.
- [x] T008 [US1] `specs/011-reading-experience/contracts/appearance-format.md`: the dated amendment — the field
      table's domain (`:38`), the family table's three rows (`:63-65`), read rule 2 (`:83`, "one of the three" →
      six), and the test list's round-trip/fallback cases. The grammar and read rules 1/3 do **not** move, and
      the row says so where it edits them.
      **DONE 2026-10-12** — `specs/011-reading-experience/contracts/appearance-format.md`, **seven dated edits in
      one pass**: the field table's domain (six names), the family table's three new rows (`bold`: none at `w700`;
      `serif-bold`: `serif`, the shipped real `NotoSerif-Bold.ttf`; `mono-bold`: `monospace` at `w700`, the weight
      **synthesised** — with the probe's date and the reader's decision named), read rule 2 ("one of the three" →
      **six**), and the test list's round-trip and per-field-fallback cases. The grammar and read rules 1/3 are
      untouched, and the amendment says so.
- [x] T009 [US1] `specs/017-bold-comment-size/scripts/klhu_walk_bold.py`: the walk driver for quickstart rows
      **8, 9 and 12** — one row per invocation, dispatching on the quickstart's own numbers, borrowing the
      sibling drivers' helpers (`011`'s screencap/scan chain, `015`'s frame scan) and making the artifacts'
      directories before a render runs.
      **DONE 2026-10-12** — `specs/017-bold-comment-size/scripts/klhu_walk_bold.py` (rows 8, 9, 12): it drives the
      shipped picker (`tap_control` matches a label EXACTLY, so `Serif` never answers for `Serif bold`), reads the
      record through `prefs_value`, force-stops and relaunches, and measures ink with PIL. `flutter build apk
      --debug` (5.6 s) + `adb install -r` → Success.
- [x] T010 [US1] Walk quickstart row 8 into `specs/017-bold-comment-size/breakpoint.md`: the appearance control
      lists six faces, each bold value's record reads a **two-part** value, and the text is still bold after a
      force-stop and relaunch (the prefs line + the page's own screenshot).
      **DONE 2026-10-12 — WALKED, PASS (12/12)**, quoted in `breakpoint.md` § Row 8: six chips offered; each bold
      value's record a **two-part** value (`bold||medium`, `serif-bold||medium`, `mono-bold||medium`); the family
      held still (6664 → 7622 ink pixels, +14.4%); the relaunch keeping the last record and painting **the same
      7622 ink pixels**. Two corrections the row made to itself in this pass, both recorded in `breakpoint.md` and
      carried into `quickstart.md`'s row 8: the first comparison measured the family as well as the weight, and
      the band and threshold now exclude the chrome.
- [x] T011 [US1] Walk quickstart row 9 into `specs/017-bold-comment-size/breakpoint.md`: `xlarge` with **each**
      bold face — the widest painted line's ink against the page's own width, three measurements, the figures
      recorded either way (D6; a clip is reported, not narrowed quietly).
      **DONE 2026-10-12 — WALKED, PASS (3/3)**, quoted in `breakpoint.md` § Row 9: at `xlarge` the ink's right edge
      is the column's own right bound (**1042 px**) in all six captures, so 011's guarantee holds for the three
      bold faces; the left ink drifts 10 px (`serif-bold`) and 1 px (`mono-bold`) — a bold glyph's side bearing,
      bounded and reported. The row corrected itself twice (its first baseline compared families; its second
      assertion bound the wrong edge) and **011's FR-012 now carries the dated re-measure in its own spec**.
- [x] T012 [US1] Walk quickstart row 12 into `specs/017-bold-comment-size/breakpoint.md`: a Chinese content under
      each bold value — three screenshots, and the finding the probe predicts (`mono-bold`'s Chinese painted
      exactly as `bold`'s), with FR-005's glyph coverage asserted rather than the look.

**Checkpoint (US1)**: T002/T003 green with the shipped cases unmodified; the six faces on the device with a
two-part record each; three width figures and three Chinese screenshots in `breakpoint.md`; 011's contract
amended with its date. **This is the MVP** — a reader can choose a bold face and read in it.

## Phase 4: User Story 2 — a comment one size below its text (P2)

**Independent acceptance test**: with each of the four offered sizes in force, the page's comment characters
measure smaller than the text's (at `small`, 10 against 12), a tap on the same point still selects the same
sentence, a rendered frame paints the comment smaller than its sentence, and 015's row 22's numbers are re-taken
(quickstart rows 10 and 11).

### Tests for US2 ⚠️ (write first, run RED)

      **DONE 2026-10-12 — WALKED, PASS (8/8)**, quoted in `breakpoint.md` § Row 12: a Chinese content under all six
      faces — `bold` 0.065 and `mono-bold` 0.065 (**0.00% apart**: the fallback face decides, as the probe
      predicted), `serif` 0.037 → `serif-bold` 0.050 (heavier: the weight is synthesised), `mono` = `default`
      0.047. FR-005's glyph coverage asserted, the paint's look left to the captures.
- [x] T013 [P] [US2] `test/appearance_store_test.dart`: the derived size's own cases — for every offered size the
      comment's points are **strictly** smaller than the text's (INV-3, the reader's "有区别" as an assertion),
      and equal to the next offered size down wherever one exists (INV-4). **RED**: no such helper exists.
      **DONE 2026-10-12** — **RED as a compile/load error** (`commentPoints` is not defined on `ReadingSize`), then
      green after T016: `flutter test test/appearance_store_test.dart` → `00:00 +18` (17 → 18).
- [x] T014 [P] [US2] `test/reading_view_comment_test.dart`: the page's painted comment span at each of the four
      sizes, the sentence's own characters unchanged beside it, and a content whose sentences carry no comment
      painting exactly what it painted before (one span, FR-011). Alongside it, the offset-bearing suites —
      `test/comment_test.dart` and 016's `test/reading_view_step_test.dart` — are **run unmodified** (FR-010's
      receipt). **RED**: the comment is painted at the text's size today.
      **DONE 2026-10-12** — **RED as a load error**, then green after T016-T018:
      `test/reading_view_comment_test.dart` → `00:04 +15` — the eleven shipped cases **unmodified** plus four new
      ones (the comment's span at `medium` and at `small`, a no-comment content as one span, and a tap inside the
      comment answering the comment). Two test-side corrections: the span reader takes the plain text it reads
      (a no-comment content paints a different string), and the file imports `appearance_store.dart`.
- [x] T015 [P] [US2] `test/video_painter_test.dart`: extend `_layoutOf`/`_stepsOf` (`:223`) so a
      comment-carrying slot recomputes as **two** spans, then the new cases — the block's second span begins
      exactly at `commentStart` and is smaller than the first, a slot with no comment is one span and its
      scroll claims are unchanged. **RED**: `commentStart` does not exist and the helper lays out one span.

### Implementation for US2

      **DONE 2026-10-12** — **RED as a compile error**, quoted: `Try correcting the name to the name of an
      existing getter, or defining a getter or field named 'commentStart'.` at
      `test/video_painter_test.dart`'s new call site. Green after T019/T020: `00:00 +26` (25 → 26), so **every
      shipped case passes unmodified** — a no-comment slot lays out exactly as it did (FR-011's receipt). The
      helper `_layoutOf`/`_stepsOf` learned the two-span shape and its call sites pass `slot.commentStart` through.
- [x] T016 [US2] `lib/appearance_store.dart`: the derived comment-size helper beside the sizes it derives from —
      the next offered size down, and 10 below the smallest (D2, spec decision 2).
      **DONE 2026-10-12** — `ReadingSize.commentPointsFor` and its `commentPoints` getter (017 D2): the next
      offered size down, and 10 below the smallest. One helper for both paints — the page's span split and the
      frame's block call the same function, so they cannot disagree.
- [x] T017 [US2] `lib/comment.dart`: the comment's own **display** ranges, taken from the resolution the page
      already performs, so the split needs no second opinion about where a comment begins (D3).
      **DONE 2026-10-12** — `CommentDisplay.commentSpans()` (017 D3): each comment's own characters as **display**
      offsets, derived through the existing `toDisplay`, so the mapping that answers a tap is the arithmetic that
      cuts the paint. No new index space, and nothing re-derived.
- [x] T018 [US2] `lib/reading_view.dart`: `_buildSpans()` gives those characters their own span with the derived
      size — and the display mapping, the highlight's boundaries and a step's range are asserted **unchanged**
      by the suites T014 re-runs (FR-010).
      **DONE 2026-10-12** — `lib/reading_view.dart`: `_buildSpans()` cuts the display at every boundary the
      highlight and the comments have and paints each run with `_spanPaint` (the yellow background and the derived
      size can cover the same run), with a one-span fallback for the empty case. The mapping is untouched: FR-010's
      receipts are `test/comment_test.dart` (+42) and 016's step suite (+11), both green **unmodified**.
- [x] T019 [US2] `lib/video_timeline.dart`: `VideoSlot` gains the nullable boundary inside its painted `text`,
      and both builders (`:331`, `:354`) fill it (D4).
      **DONE 2026-10-12** — `VideoSlot` gains the nullable `commentStart`, filled by the sentence builder
      (`own.text.length + 1`, the index past the line break) and inherited by the end hold. It is a named optional
      parameter, so 012's and 015's own slot constructions are untouched — `test/video_timeline_test.dart` green at
      +15 **unmodified**.
- [x] T020 [US2] `lib/video_painter.dart`: `_blockFor` lays out two spans when the boundary is set, the scroll
      maths still coming from that one layout — and every no-comment case in `test/video_painter_test.dart` is
      green **unmodified** (FR-011).
      **DONE 2026-10-12** — `lib/video_painter.dart`: `_blockFor` lays the slot out as two spans when the boundary
      is set (the comment at `_commentSizeOf`, the same derived relationship carried onto the frame's scale) and as
      one span when it is not, so the lines, the height and the scroll steps still come from one call. `paintedText`
      is unchanged — the renderer's own `text=` value does not move (015's row 22's `text=18` stands).
- [x] T021 [US2] `specs/015-comment-tag/spec.md`: the dated amendment of FR-012 (the page's paint) and FR-013
      (the frame's), naming this spec and the reader's words.
      **DONE 2026-10-12** — `specs/015-comment-tag/spec.md` (FR-012 and FR-013, both dated, naming the reader's own
      words) and `specs/015-comment-tag/data-model.md` (its `display` row's own note: the characters are unchanged
      and their size is not). FR-012's amendment says explicitly what still stands — the tag painted nowhere, the
      content where the reader wrote it, the mapping untouched, proved by 017's unmodified suites.
- [x] T022 [US2] `specs/015-comment-tag/quickstart.md`: row 22's expected numbers re-taken and rewritten in
      place, dated, with the new figures (its own row is this feature's device receipt, T026).
      **DONE 2026-10-12** — `specs/015-comment-tag/quickstart.md`: row 22 carries the re-taken figures with the
      date — `text=18` unchanged, the ink box `(208, 872, 420, 966)` at **94 px** tall and 172 px wide against the
      row's own recorded `(208, 864, 456, 964)`, 100 px tall and 248 px wide — and its "strictly taller than the
      same sentence with no comment" still holds.
- [x] T023 [US2] `specs/015-comment-tag/research.md`: its ink-box figures (`:499-500`) noted as superseded, dated
      — and the same note added to its `data-model.md` **only if** that file states the block's paint (check it;
      skip the note if it does not).
      **DONE 2026-10-12** — `specs/015-comment-tag/research.md`: its spike's figures (`:499-500`) noted as
      **superseded**, dated, with the new pair and a pointer to the row that took them. The row's conditional
      resolved to "it does state the paint": 015's `data-model.md`'s `display` row got its note in T021.
- [x] T024 [US2] `specs/017-bold-comment-size/scripts/klhu_walk_bold.py`: quickstart rows **10 and 11** added to
      the driver (the numbering is append-only: rows 8/9/12 already exist).
      **DONE 2026-10-12** — the driver's rows **10 and 11** appended (`ink_lines`, `yellow_band`, the content band,
      and 015's own render plumbing borrowed through `render_one`/`slot_of`/`box_of_frame`). Three driver
      corrections on the way, all recorded in `breakpoint.md`: the row-10 fixture (the comment now repeats its
      sentence's own word), the content band (the app bar's title is ink too), and `slot_of` answering a dict.
- [x] T025 [US2] Walk quickstart row 10 into `specs/017-bold-comment-size/breakpoint.md`: the page's measured
      comment size at `medium` and at `small` — four ink heights off two screenshots, and the same tap selecting
      the same sentence.
      **DONE 2026-10-12 — WALKED, PASS (4/4)**, quoted in `breakpoint.md` § Row 10: the same-word content paints
      27 px and 22 px at `medium`, 22 px and 18 px at `small` — the comment is the smaller line and it shrinks with
      the text (0.82 against the derived 0.83) — and a tap inside it paints the highlight over the comment's own
      line (`(560, 597)` over `(571, 589)`). **The first run of this row passed on a stale build and a
      glyph-shape difference**; the rebuild is in the record.
- [x] T026 [US2] Walk quickstart row 11 into `specs/017-bold-comment-size/breakpoint.md`: the frame's two ink
      boxes (the comment's smaller than its sentence's) **and 015's row 22 re-taken** — the figures written back
      into 015's own files by T022/T023.

**Checkpoint (US2)**: T013-T015 green with 015's and 016's offset suites unmodified; the page and a frame both
painting the comment one size down; 015's row 22's numbers re-taken and its records amended with dates.

## Phase 5: Polish & cross-cutting concerns

      **DONE 2026-10-12 — WALKED, PASS (11/11)**, quoted in `breakpoint.md` § Row 11: the frame's ink box
      `(208, 872, 420, 966)` — **94 px** tall against 015's recorded 100 px, and 172 px wide against 248 — with
      `text=18` unchanged and no tag in the frame; the file came off the device (130 091 B) with 100 of 100 frames
      accounted for. **015's row 22 is re-taken** and its figures are written back into its own files by T022/T023.
- [x] T027 Run quickstart row 13 into `specs/017-bold-comment-size/breakpoint.md`: the structural row —
      `git diff --stat pubspec.yaml pubspec.lock android/ ios/` empty, the four ARBs at **110** keys,
      `flutter gen-l10n` reproducing the committed Dart byte for byte, `test/l10n_keys_test.dart` green.
      **DONE 2026-10-12 — PASS (4/4)**, quoted in `breakpoint.md` § Row 13: `git diff --stat pubspec.yaml
      pubspec.lock android/ ios/` → **empty**; the four ARBs count **110** keys each; `flutter gen-l10n`
      reproduces the four committed `app_localizations*.dart` **byte for byte** (sha256 before == after); and
      `flutter test test/l10n_keys_test.dart` → `00:00 +3: All tests passed!`.
- [x] T028 [P] `specs/016-sentence-reading/tasks.md`: correct, dated, the receipts that quote **107** as the
      current count (the Status, T012's and T031's receipts), because this feature's three labels move it to 110
      — 107 is still the truth until T005 lands, and a standing 107 after it is a stale quote.
      **DONE 2026-10-12** — `specs/016-sentence-reading/tasks.md`: two **dated notes** where that file states the
      count as *current* — its Status's l10n sentence and T012's own receipt ("The four ARBs now count 107 …") —
      each naming this feature and the three labels, and each keeping the figure that row actually measured. The
      historical statements (its plan's `108 → 107` prose and its coverage table) are left as written: they record
      that feature's own change, and 107 was the truth then.
- [x] T029 [P] `specs/016-sentence-reading/breakpoint.md`: the same dated correction for the count that record
      quotes.
      **DONE 2026-10-12** — `specs/016-sentence-reading/breakpoint.md`: checked, and **no correction was owed**:
      `grep -c '107\|108 message\|message keys'` → **0**, so that record quotes no count and cannot go stale. The
      check is the receipt.
- [x] T030 Quote both list checkers in `specs/017-bold-comment-size/tasks.md`: run
      `check_tasks_format.py specs/017-bold-comment-size` and `task_id_audit.py specs/017-bold-comment-size`
      after this file's last edit and quote their own output in the Status verbatim.
- [x] T031 Re-take the suite on the finished tree and record it in `specs/017-bold-comment-size/tasks.md`'s
      Status: `flutter analyze`, `flutter test --concurrency=2`, and the per-file figures for the four files this
      feature touched, read against T001's baseline.
      **DONE 2026-10-12** — the suite re-taken on the finished tree, **measured per file**: `flutter analyze` →
      `No issues found! (ran in 0.8s)`; `flutter test --concurrency=2` → `00:57 +653: All tests passed!`; and this
      feature's own files one at a time — `test/appearance_store_test.dart` → `00:00 +18`,
      `test/reading_view_appearance_test.dart` → `00:03 +7`, `test/reading_view_comment_test.dart` → `00:04 +15`,
      `test/video_painter_test.dart` → `00:00 +26`, plus the three suites whose being **unmodified** is the
      receipt — `test/comment_test.dart` `00:00 +42`, `test/reading_view_step_test.dart` `00:02 +11`,
      `test/video_timeline_test.dart` `00:00 +15`. Baseline 643 → **653**.
      **DONE 2026-10-12** — both list checkers run after the ticks above, their own output quoted:
      `tasks.md: 32 tasks (30 done), 7 marked [P]` with `(setup/foundational/polish): 7`, `[US1]: 11`, `[US2]: 14`
      and `OK: format, sequencing and spec-id coverage check out` (exit 0); and
      `017-bold-comment-size: 32 tasks, 30 done, 7 [P]`. The two rows unticked at that moment are this row and T032
      itself, which is why the count reads 30: the closing pair quotes the same run, not a different one.
- [x] T032 Close the list in `specs/017-bold-comment-size/tasks.md`: every row ticked with its receipt, both
      checkers re-run after the closing edit and quoted, any false receipt corrected rather than left standing,
      and the handback naming what still needs a walk.
      **DONE 2026-10-12 — the list closes with every row ticked (32/32).** Both checkers re-run after this file's
      last edit and quoted: `tasks.md: 32 tasks (32 done), 7 marked [P]` … `OK: format, sequencing and spec-id
      coverage check out`, and `017-bold-comment-size: 32 tasks, 32 done, 7 [P]`. `check_quickstart_coverage.py` →
      `13 rows ([unit] 7, [device] 5, [structural] 1, untagged 0)`, `unclaimed: none`, `no 'Proves' line: none`.
      `check_artifact_refs.py` → 27 line references checked, **no unresolved references**. **No row still needs a
      walk**: the five device rows (8, 9, 10, 11, 12) and the structural row (13) are green in `breakpoint.md`. Two
      things were corrected rather than left standing: the Status's own "what is next" line, and a bare-name
      citation in `breakpoint.md` (re-pointed at `specs/015-comment-tag/research.md:499-500`).

## Dependencies & ordering

- **T005 → T006** (a label the screen reads must exist) and **T005 → T010** (the screen's labels are what the
  device row inspects); **T004 → T003's RED→green** (the tests are written first and pass only after T004).
- **T009 → T010/T011/T012**, **T024 → T025/T026**: the driver is created and extended before the rows it runs.
- **T016 → T014/T018**, **T019 → T015/T020**: the helper and the field exist before their rows can go green.
- **T022/T023 → T026**: the figures T026 measures are written into 015's own files by those rows.
- **T005 → T028/T029**: the older receipts' correction is only true once the labels exist.
- **T030 → T031 → T032**: the checkers are quoted after the last edit, then the suite, then the close.

## Parallel opportunities

- **T002 [P] T003 [P]** (two test files) and **T013 [P] T014 [P] T015 [P]** (three), since no two touch one file.
- **T028 [P] T029 [P]** (two files in a sibling spec).
- The implementation rows T004/T005/T006/T007 are one file each, but their order is fixed by compilation: T005
  precedes T006 (the labels), and T004 precedes T006's preview.

## Implementation strategy

US1 is the MVP and is finished end to end (tests, code, contract, device rows) before US2 starts: the two
stories share only `lib/reading_view.dart`, and US1's seam change is one line that US2's span split builds on.
Within each story the tests come first and are run RED for a named reason; the device rows follow the code, and
the sibling specs' records are amended in the same pass as the code that makes them false.

## Notes

- **A count that moves is named, not smoothed**: the ARB total (107 → 110) moves two sibling receipts (T028,
  T029), and the identity of the reported suite count moves with each row that adds or deletes a case.
- **The walk's rows are numbered by the quickstart** (8-12) and the driver dispatches on those numbers; T024
  appends rows 10/11 rather than inserting them, so no device row is renumbered.
- **FR-010's receipt is a suite that was not edited**: `test/comment_test.dart`, 016's step suite and the
  display-mapping cases are re-run as they stand, and a re-cut among them is the claim failing, not a stale test.
- **The comment is not made bold** by any bold face (the spec's own edge case): a comment's span carries the
  smaller size and the weight it carries today.

## Requirement coverage

| Id | Satisfied by |
|---|---|
| FR-001 | T002, T003, T004, T005, T006, T010 |
| FR-002 | T003, T007, T010 |
| FR-003 | T003, T006, T010 |
| FR-004 | T002, T004, T010 |
| FR-005 | T012 |
| FR-006 | T011 |
| FR-007 | T013, T014, T016, T018, T025 |
| FR-008 | T015, T019, T020, T026 |
| FR-009 | T013, T014, T025 |
| FR-010 | T014, T015, T018, T020 |
| FR-011 | T015, T020, T026 |
| FR-012 | T003, T006 |
| FR-013 | T027 |
| SC-001 | T003, T010 |
| SC-002 | T010, T011 |
| SC-003 | T014, T025 |
| SC-004 | T014, T018, T025 |
| SC-005 | T015, T020, T026 |
| SC-006 | T027 |

## Superseded by later specs

**2026-10-13 — a comment's step down now takes the weight first (019's `spec.md` FR-015, its US4 and its
decision 11).** The reader asked, while reviewing 019's plan: *"可否把加粗字体 计入 大一号，大二号。及计算小一号等。
扩充可用字体数"*, and answered the follow-up question for this feature with *"要：正文已是粗体时，注释 = 同字号常规
（改 017 已发货规则，需重测其设备行）"*. What that changes here:

- **FR-007/FR-008/FR-009 and the derived-size table (`data-model.md` § The comment's size) are superseded for a
  **bold** body only**: with a bold face in force a comment is the sentence's own size at the regular weight
  (24 w700 → 24 w400), where this feature shipped one offered size down at the same weight (24 → 18). With a
  **regular** body — every fixture and every row below — nothing moves: `24 → 18`, `18 → 14`, `14 → 12`,
  `small → 10`.
- **SC-003 and SC-005's *"measure smaller"* is the one sentence this makes false**, and only for the bold case:
  the invariant FR-015 leaves in force is *"never larger, and never the same size **and** weight"*. The numbers
  below are quoted as they were measured, on the face they were measured with.
- **No row here is re-cut or re-run**: rows 8-12 and their fixture use a **regular** face (and rows 8/9/12 do not
  carry a comment at all), so every figure stands. The new case has no row of this feature's to move, and is walked
  by **019's own row 8b** (`specs/019-head-tags/quickstart.md`), which that feature's plan names as this
  amendment's receipt. `breakpoint.md` carries the dated section beside its rows.
- **What is NOT this amendment's**: the ladder that raises a mark (019's FR-006/FR-007), the six faces the reader
  picks from, the record's grammar, and the 110 message keys — the ladder is derived on 019's side and adds no
  entry to any control.
