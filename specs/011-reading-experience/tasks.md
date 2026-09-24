# Tasks: Reading Experience

**Feature**: `011-reading-experience` | **Date**: 2026-09-24
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contract**: [contracts/appearance-format.md](./contracts/appearance-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete dependency), `[Story]` = `US1` (the read followed on screen, P1), `US2` (the text appearance, P2), `US3` ("+" adds a content, P3).

## Status

**Not started (tasks generated 2026-09-24, plan reviewed after the sentence-highlight amendment).**
All tasks are open; the implement stage ticks them as they complete and records any deviation inline.

Baseline to protect: **266 tests green, `flutter analyze` clean** (last measured 2026-09-24 at the end
of 010; T002 re-takes the receipt before the first edit, because a baseline measured after a change is
not a baseline). Additions expected: ~20 widget/unit scenarios across 5 new or rewritten files, ~8
service cases, one new store — the exact numbers are whatever the RED runs produce, not a target.

**One measured claim this list corrects**: the plan's test tree did not name a file for the "+"
story's unit rows. They land in a new `test/reading_view_new_content_test.dart`, and
`quickstart.md` gained scenario 19 to describe them (the plan's tree was updated in place the same
way).

## Grounding notes (decisions these tasks implement)

1. **The tracking highlight is the spoken sentence** (D2, FR-020/FR-021): `onParagraphStart(int)` is
   **replaced** by `onSentenceStart(SpokenSentence)` carrying `(paragraph, sentence, start, end)`. Not
   additive — after the amendment nothing consumes paragraph-granular tracking, so an extra parameter
   would be dead surface. This is a change to behaviour 003 shipped, so its tests are rewritten to pin
   the new unit, never deleted.
2. **The page follows what the highlight paints** (D1): one span, one measurement, one reveal. The
   box comes from the existing single `RichText`'s `RenderParagraph` (`getBoxesForSelection`, the same
   handle the tap path uses) and moves through `showOnScreen(rect:, duration:)` — no `ScrollController`,
   no offset arithmetic (constitution V).
3. **Faces are platform-guaranteed, sizes are app names** (D5/D6, contract): `default`/`serif`/`mono`
   mapped to platform family names, `small`/`medium`/`large`/`xlarge` → 12/14/18/24 with `medium` equal
   to today's `bodyMedium`. No font asset, no dependency, no network (constitution IV).
4. **The appearance is one `shared_preferences` key** (D4, contract):
   `reading_appearance = <typeface>||<size>`, read through a `ReadPositionStore`-shaped store that
   catches every failure and returns the defaults, held as a plain field (no constructor parameter —
   the prefs mock is the test seam).
5. **The style seam is one method** (D8/FR-009): `_contentTextStyle` in `lib/reading_view.dart` is the
   only place the reading text's style is built, and it is already shared by the rich text and the edit
   field. The app's chrome must not change.
6. **The list's add action returns a typed result** (D7): `ContentListResult` =
   `PickedContent(SavedContent)` | `NewContentRequest`; the page switches on it and drafts through the
   existing `_enterEdit()` (blank, unnamed, no entry until Save). The unsaved-edit guard stays in front
   of both paths.
7. **Device evidence is two log lines plus a pixel band** (D3): the service already logs
   `klhu speak p<i> s<j> "…"`; the view adds `klhu follow: p<i> s<j> visible=<0|1> top=<t> bottom=<b>
   viewport=<h>`, and the paint claim is counted inside that band (inside > 0, outside ~0) — a
   whole-screen yellow count cannot tell a sentence's span from a paragraph's.
8. **The 011 walk driver imports 010's helpers** (D10) instead of copying them; the spec-dir scripts
   are the committed home of the evidence (T021).
9. **New copy lands in all four ARBs at once** (D12): `test/l10n_keys_test.dart` fails in both
   directions, so a partially translated addition cannot pass.
10. **Tests first** (constitution III): every story's tests are written and run RED before that story's
    implementation. A compile error counts as RED — say so when it is one.
11. **Report, do not sweep** (research § Behaviour this feature changes): 003's, 005's and 010's
    artifacts still describe paragraph-level tracking. They are named in the final task and reported to
    the user; rewriting reviewed records is their call.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this spec: `specs/011-reading-experience/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2`
  (the emulator being up makes plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated
  files are part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/011-reading-experience`
  run over **every** directory under `specs/` (the checker ships with the skill, not with the repo)

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the one piece US2 and US3 both render from. Nothing is installed — this feature adds no
dependency and no asset (plan § Technical Context).

- [ ] T001 Add the new message keys to the template `lib/l10n/app_en.arb` and the three translations
      `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`, `lib/l10n/app_es.arb` — `addContentButton`,
      `appearanceButton`, `appearanceTitle`, `fontLabel`, `sizeLabel`, `previewLabel`,
      `fontDefaultLabel`, `fontSerifLabel`, `fontMonoLabel`, `sizeSmallLabel`, `sizeMediumLabel`,
      `sizeLargeLabel`, `sizeXLargeLabel` (D12) — then `flutter gen-l10n` and confirm the diff is
      exactly the 4 ARBs + the regenerated `lib/l10n/app_localizations*.dart`. The template keys must
      exist before any widget task compiles against them

**Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green (key parity in
both directions across the four ARBs).

---

## Phase 2: Foundational (blocking prerequisite)

**⚠️ CRITICAL**: without a known-green baseline, no later "the suite is green" claim means anything on
this box (no CI in this repo).

- [ ] T002 Record the baseline over the whole `test/` tree before touching anything: `flutter analyze`
      + `flutter test --concurrency=2` → the passing/failing counts, and keep the tail of the output as
      the starting receipt for every later claim (expected 266 passing, 0 failing; if it differs, the
      difference is the first thing to explain, not the last)
      (deviation note: run it BEFORE T001 — the receipt's whole value is that it predates every edit,
      and T001 edits four ARB files)

**Checkpoint**: baseline receipt in hand; the tree is untouched.

---

## Phase 3: User Story 1 — The read is followed on screen, sentence by sentence (P1) 🎯 MVP

**Goal**: while a read plays, the yellow highlight covers exactly the sentence being spoken, and the
page scrolls by itself so that sentence stays visible; a read started from an off-screen position shows
that position first; a text that fits never moves; a manual scroll is not undone; Stop and the end of a
read leave the page where it stopped.

**Independent Test**: install on `emulator-5554`, read the shipped English pre-set end to end with
`adb logcat -s flutter` — every `klhu follow:` line reads `visible=1` with `0 <= top < bottom <=
viewport` and the yellow pixels sit inside that band; then a text that fits on one screen moves the page
by nothing (quickstart scenarios 7–10).

### Tests for US1 ⚠️ (write first, run RED)

- [ ] T003 [P] [US1] Write the sentence-callback cases in `test/reader_service_test.dart` and migrate
      its six existing tracking drives (`:172`, `:183`, `:211`, `:244`, `:352`, `:397`) to the new
      seam: one `ParagraphSpeech` holding three sentences produces three reports in order with
      `(paragraph, sentence)` `(0,0)/(0,1)/(0,2)` and `start`/`end` equal to the sentence ranges of the
      text; a speech that begins mid-paragraph reports its remainder first; the pause/resume cases
      report the **interrupted** sentence again and nothing earlier. Run it and keep the RED output
      (today the callback is `onParagraphStart(int)` and reports once per paragraph — a compile error
      against the new shape is the RED, and it must be quoted as one)
- [ ] T004 [P] [US1] Write the new widget suite `test/reading_view_follow_test.dart` covering
      quickstart scenarios 2–6 against a fake `Reader`: a text that fits is never scrolled; a sentence
      below the fold is revealed and is inside the viewport when reported; Continue Read from a stored
      position reports that position first; a manual scroll survives until the next sentence (the
      repeated sentence of a resume does not move the page); reported offsets are inside the content
      and never go backwards within one generation; and each report paints exactly the reported span
      (the yellow probe the other suites already use). Run it and keep the RED output

### Implementation for US1

- [ ] T005 [US1] Implement the sentence-level tracking seam in `lib/reader_service.dart`:
      `SpokenSentence` (paragraph, sentence, `start`, `end`) as an immutable value; `_Utterance` gains
      the two absolute offsets (computed where `sentenceRanges` already cuts each speech);
      `onSentenceStart` replaces `onParagraphStart` on `Reader.speakParagraphs` and the private state;
      the callback fires once per sentence immediately before it is handed to the engine, generation-
      guarded as today; update the interface's doc comments (including the "003's tracking is
      paragraph-level" note). Then run `test/reader_service_test.dart` → T003 green
- [ ] T006 [US1] Implement the paint and the follow in `lib/reading_view.dart`: paint
      `TextSegment(unit.start, unit.end, SegmentUnit.sentence)` from the callback (replacing the
      paragraph span), then measure that box through `_textKey`'s `RenderParagraph`
      (`getBoxesForSelection`, the same handle `_resolveAt` uses) and, only when it is not fully inside
      the viewport, `showOnScreen(rect: …, duration: 200ms, curve: easeOut)` (D1); follow once per
      `(generation, paragraph, sentence)` and never re-follow the same one (D9); add the debug-only
      `debugPrint('klhu follow: p<i> s<j> visible=… top=… bottom=… viewport=…')` after the reveal
      settles (D3). Then run `test/reading_view_follow_test.dart` → T004 green
- [ ] T007 [P] [US1] Rewrite the tracking expectations in `test/reading_view_continue_test.dart` and
      its three siblings — `test/reading_view_mixed_test.dart`, `test/reading_view_test.dart`,
      `test/reading_view_pause_test.dart` — to sentence granularity:
      their fakes take the new callback, their drives report sentences, and their yellow-span
      assertions expect exactly the spoken sentence (rewritten, never deleted). Keep the two selection
      tests (`test/reading_view_edit_test.dart:168`, `:226`) exactly as they are (D11). Run the four
      files, then the full suite
- [ ] T008 [P] [US1] Update the fake `Reader` implementations in `test/reading_view_edit_test.dart`,
      `test/branding_test.dart`, `test/spanish_localization_test.dart`, `test/voice_picker_test.dart`
      and `test/voice_picker_semantics_test.dart` that only forward tracking, so their
      `speakParagraphs` matches the new contract (Dart rejects an override that omits a named parameter);
      confirm none of their expectations change by running each file, then the full suite →
      `flutter analyze` + `flutter test --concurrency=2` green
- [ ] T009 [US1] Device walk on `emulator-5554` per `specs/011-reading-experience/quickstart.md`
      scenarios 7–10, with PASS/FAIL rows and the raw evidence lines written into
      `specs/011-reading-experience/breakpoint.md`: the follow lines of a full read (one per sentence,
      `visible=1`, box inside the viewport), the yellow-pixel band check around a spoken sentence, a
      read started far down the text, a text that fits on screen (no scroll), and Stop mid-read
      (the page stays put). Cross-check every claim against the `klhu speak p<i> s<j>` lines and the
      engine's `Synthesis request` lines
      (deviation note: this task appends to `breakpoint.md`, so it is sequential with T015 and T020
      even though the story chains are independent)

**Checkpoint**: US1 is complete and independently demonstrable — the highlight and the speech name the
same sentence, and the page keeps that sentence on screen from the first utterance to the last.

---

## Phase 4: User Story 2 — The text's typeface and character size, remembered (P2)

**Goal**: a reading-page control previews the text in a candidate typeface and size and, on confirm,
applies it to the reading text (and the editor) and remembers it; dismissing changes nothing.

**Independent Test**: choose Serif + X-Large, confirm, see the text change, force-stop and relaunch —
the same look is back and `reading_appearance = serif||xlarge` is in the prefs file; then open the
screen, change both rows, go back, and find the record and the look untouched (quickstart 11–16).

### Tests for US2 ⚠️ (write first, run RED)

- [ ] T010 [P] [US2] Write the store contract test `test/appearance_store_test.dart` from
      [contracts/appearance-format.md](./contracts/appearance-format.md): the save/load round-trip; an
      absent key → `(default, medium)`; per-field fallback (`Helvetica||xlarge` → `(default, xlarge)`,
      `serif||huge` → `(serif, medium)`); every malformed shape (`''`, `serif`, `serif||`, `||xlarge`,
      `serif||xlarge||extra`) → the defaults without throwing; exactly one key written per confirm; the
      key collides with nothing else in the store; the second save wins; and the `medium` size constant
      equals the theme's `bodyMedium` size. Use `SharedPreferences.setMockInitialValues`. Run it and
      keep the RED output (the file `lib/appearance_store.dart` does not exist yet — a compile error is
      the RED, and it must be quoted as one)
- [ ] T011 [P] [US2] Write the widget suite `test/reading_view_appearance_test.dart` covering
      quickstart scenarios 11–15: the appearance action exists in all four locales and is disabled while
      a read plays; the offered sets are exactly three typefaces and four sizes; the largest size lays
      the longest shipped line out inside a 360 dp-wide viewport with no overflow; confirming styles the
      rich text **and** the edit field and leaves the app-bar title's style alone; a fresh view with the
      record in the mocked prefs renders the chosen family and size; dismissing after changing both rows
      writes no key and keeps the previous look. Run it and keep the RED output

### Implementation for US2

- [ ] T012 [US2] Implement `lib/appearance_store.dart`: `ReadingAppearance` (`typeface`, `size`) with
      the contract's read rules as a pure, testable function plus the name→point-size and
      name→platform-family tables; `AppearanceStore.load()`/`save()` over `SharedPreferences`, every
      failure caught → the defaults with a `debugPrint`, nothing repaired (D4). Then run
      `test/appearance_store_test.dart` → T010's cases green
- [ ] T013 [US2] Implement `lib/appearance_screen.dart`: a pushed screen mirroring
      `lib/voice_picker_screen.dart`, previewing the text on screen in the candidate style, with a
      typeface row and a size row (each showing the offered set from the store's constants), popping the
      chosen appearance on confirm and nothing on back (D8). Then run the screen's cases in
      `test/reading_view_appearance_test.dart` → the offered-set and preview rows green
- [ ] T014 [US2] Wire the appearance into `lib/reading_view.dart`: load the stored appearance on init
      (defaults on any failure), apply it inside `_contentTextStyle` so the rich text and the edit field
      both follow it and the app's chrome does not (FR-009), add the app-bar action (`Icons.format_size`,
      the ARB tooltip) that is **disabled while a read plays** (FR-014) and pushed to the appearance
      screen, and persist on confirm only (FR-008/FR-010). Then run
      `test/reading_view_appearance_test.dart` → T011 green, then the full suite
- [ ] T015 [US2] Device walk on `emulator-5554` per `specs/011-reading-experience/quickstart.md`
      scenario 16, with the rows in `specs/011-reading-experience/breakpoint.md`: choose Serif +
      X-Large, confirm, read `reading_appearance` out of
      `shared_prefs/FlutterSharedPreferences.xml`, force-stop + relaunch, and screenshot the page before
      and after switching back to Default — the text region must differ between the two shots, and the
      screenshots are kept for the reviewer to check the `xlarge` layout and the absence of missing
      glyphs in each language (glyph coverage is not machine-checkable through Flutter's API, so this
      row records the images rather than asserting a number)

**Checkpoint**: US1 and US2 work independently — the read follows on screen, and the text's look is the
user's choice and survives a restart.

---

## Phase 5: User Story 3 — "+" adds a content from the contents list (P3)

**Goal**: the contents list offers an add action that opens a blank, editable page; Save creates an
auto-named entry; an empty Save is refused with the existing message; leaving creates nothing.

**Independent Test**: from the contents list tap "+", type a sentence, Save — the row is in the list;
repeat and leave without saving, then save an empty draft — the library is unchanged both times
(quickstart 17 on the device, 19 at unit level).

### Tests for US3 ⚠️ (write first, run RED)

- [ ] T016 [P] [US3] Update `test/content_list_test.dart` for the add action and the typed route result
      (its two existing push sites at `:77`, `:133`): tapping the add action resolves to a
      new-content request rather than to a library entry, tapping a row still resolves to its entry, and
      going back still resolves to nothing. Run it and keep the RED output (the result type does not
      exist yet — a compile error is the RED, and it must be quoted as one)
- [ ] T017 [P] [US3] Write `test/reading_view_new_content_test.dart` for quickstart scenario 19: the
      add action's result opens the page blank, in EDIT, focused, with no entry created; Save with text
      creates an auto-named entry (no name prompt) and the text stays on screen; Save with nothing typed
      is refused with the existing "There is nothing to save" message and creates nothing; leaving the
      draft creates nothing and leaves the previously loaded content's saved text and stored position
      untouched. Run it and keep the RED output

### Implementation for US3

- [ ] T018 [US3] Implement the result type and the add action in `lib/content_list_screen.dart`:
      `ContentListResult` as a sealed value (`PickedContent(SavedContent)` | `NewContentRequest`), the
      row tap and the app-bar `Icons.add` action (the ARB tooltip) popping the right one (D7). Then run
      `test/content_list_test.dart` → T016 green
- [ ] T019 [US3] Implement the draft path in `lib/reading_view.dart`: switch on the route result —
      the entry path stays `_loadEntry`, the request path resets `_content`/`_loaded`/`_anchorKey`/
      `_anchor`/`_highlight` and reuses `_enterEdit()` for a blank focused editor, with the existing
      `_hasUnsavedEdits` + `_confirmDiscard()` guard in front of both (D7). Saving a draft goes through
      the shipped `_store.saveEdited(null, text)`, so an empty draft is refused by 008's rule and the
      message already exists (FR-018). Then run `test/reading_view_new_content_test.dart` → T017 green,
      then the full suite
- [ ] T020 [US3] Device walk on `emulator-5554` per `specs/011-reading-experience/quickstart.md`
      scenario 17, with the rows in `specs/011-reading-experience/breakpoint.md`: tap the add action
      (found by its exact tooltip in the app-bar band — a match there is a matching bug, not a control),
      type a sentence, Save, return to the list and confirm the new row and its auto-generated name;
      then repeat with an empty Save and confirm the refusal message and that the list gained no row

**Checkpoint**: all three stories are independently demonstrable; none of them needed another's code.

---

## Phase 6: Polish & cross-cutting concerns

- [ ] T021 [P] Commit the walk driver to `specs/011-reading-experience/scripts/klhu_walk_experience.py`
      (parts 7, 8, 9, 10, 16, 17 — one function each, `ADB_SERIAL` / `KLHU_REPO` / `KLHU_OUT` honoured,
      importing `specs/010-continue-read/scripts/klhu_walk_continue.py` for the shared device mechanics
      rather than copying them, D10) and point the re-run block of
      `specs/011-reading-experience/quickstart.md` at it
      (deviation note: the harness may produce these lines in a scratch copy first — the committed file
      is what the evidence is allowed to cite, and the quickstart's block must name the paths that exist
      in the tree)
- [ ] T022 [P] Update `README.md`: the 011 row in the spec index (drop any "spec only" wording) and the
      one-line notes for the three behaviours — the page follows the spoken sentence, the text's
      typeface/size is remembered, "+" adds a content — plus the re-run commands for the device rows
- [ ] T023 Tick the boxes in `specs/011-reading-experience/tasks.md`, record every deviation inline
      (moved work, superseded steps) instead of leaving the list disagreeing with the tree, then run the
      tasks-format checker over **every** directory under `specs/`
      (`python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/<each>`),
      report to the user (do not rewrite) the older artifacts that still describe paragraph-level
      tracking — `specs/003-reading-polish/` (spec/plan/tasks/quickstart/data-model),
      `specs/005-voice-pause-resume/spec.md` and `breakpoint.md`,
      `specs/010-continue-read/data-model.md`/`plan.md`/`quickstart.md` — and report the checker's
      standing findings for the older specs as well (001, 002, 003, 004, 005 and 007 fail it: one task
      with no path on its first line each, plus requirement ids the file never names because those specs
      carry no coverage table; 008, 009, 010 and 011 pass it) — and finish with `flutter analyze`
      + `flutter test --concurrency=2`

---

## Dependencies & ordering

- **T001 → T002 → T003/T004 → T005 → T006 → T007/T008 → T009** is the US1 chain: the ARB keys exist
  before widgets compile, the callback's cases are RED before the seam changes, and the walk needs a
  clean build.
- **T010/T011 → T012 → T013 → T014 → T015** is the US2 chain. It is independent of US1 in files but not
  in the tree: `lib/reading_view.dart` is touched by T006 and again by T014, so US2's implementation
  lands after US1's (or the other way round — never both in one step).
- **T016/T017 → T018 → T019 → T020** is the US3 chain: the result type must exist before the page can
  switch on it (`test/content_list_test.dart` and `lib/content_list_screen.dart` are the pair that
  moves together).
- **T003 ‖ T004** and **T010 ‖ T011** and **T016 ‖ T017**: separate new files with no dependency
  between them.
- **T007 ‖ T008**: disjoint file sets, both dependent only on T005.
- **T009, T015, T020 are sequential with each other** although their stories are independent: all three
  append to `specs/011-reading-experience/breakpoint.md`, and two writers to one evidence file are
  sequential by construction.
- **T021/T022 are [P]** once T009/T015/T020 have produced their evidence.

## Parallel opportunities

- T003 ‖ T004 (service cases vs the new widget suite).
- T007 ‖ T008 (the four tracking-expectation files vs the five signature-only fakes).
- T010 ‖ T011 (store contract vs view/screen suite).
- T016 ‖ T017 (list result vs the page's draft path).
- T021 ‖ T022 (a script and the README).

## Implementation strategy

1. **MVP** = Phase 1 + Phase 2 + US1 (T001–T009): the highlight tracks the spoken sentence and the page
   keeps it on screen — the one behaviour that changes reading itself, device-proven.
2. **Second increment** = US2 (T010–T015): the appearance screen and its remembered record.
3. **Third increment** = US3 (T016–T020): the "+" shortcut, which adds no new capability beyond 008's
   Edit ▸ Save path.
4. **Polish** = T021–T023: the committed walk driver, the README, the final ticks and the record-check.
5. If US2's device row shows a Han face that does not change with the typeface, that is the documented,
   measured limitation (research D5) — record it in `breakpoint.md` and carry on; bundling a CJK face is
   a separate decision, not a bug to fix inside this story.

## Notes

- The `[P]` marks are about files, not attention: `lib/reading_view.dart` is edited by T006, T014 and
  T019 in that order, and `lib/reader_service.dart` by T005 alone.
- Keep everything out of `index.json`: the content library's schema is version-locked and an unexpected
  version takes its destructive repair path (008's contract). The appearance is per-device view state.
- `flutter test` needs `--concurrency=2` while the emulator runs.
- Every RED claim in the transcript must quote the actual failure (assertion message or compile error);
  a test that was never seen failing is not evidence.
- A rewritten tracking test that passes before the change means it was not really rewritten — re-read
  the assertion, not the test name.
- The device rows must not depend on a fixed `sleep` for a moment that lasts seconds: poll
  `adb logcat -d | grep 'klhu speak'` and act on the line (the 010 walk's mechanic).

---

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 scroll so the sentence being read is visible | T004, T006, T009 |
| FR-002 bring an off-screen start position into view | T004, T006, T009 |
| FR-003 never scroll when the sentence is already visible | T004, T006, T009 |
| FR-004 leave the page where the read left it (end, Stop, pause) | T004, T006, T009 |
| FR-005 never undo a manual scroll; follow from the next sentence | T004, T006, T009 |
| FR-006 choose the reading text's typeface | T010, T011, T012, T013, T014, T015 |
| FR-007 choose the reading text's character size | T010, T011, T013, T014, T015 |
| FR-008 preview a candidate before confirming | T011, T013, T014 |
| FR-009 apply to the reading text and the editor, not the chrome | T011, T014 |
| FR-010 remember the choice across restarts | T010, T012, T014, T015 |
| FR-011 malformed or withdrawn choice falls back to the default | T010, T012 |
| FR-012 the largest offered size keeps lines inside the page | T010, T011 |
| FR-013 offered typefaces render EN, ZH-Hans and ES without missing glyphs | T011, T013, T015 |
| FR-014 the appearance control is idle-only | T011, T014 |
| FR-015 the contents list offers an add control | T016, T018, T020 |
| FR-016 a new content opens blank and editable, with nothing loaded | T017, T019, T020 |
| FR-017 saving a new content creates an auto-named entry, no name prompt | T017, T019, T020 |
| FR-018 an empty or whitespace-only save is refused with the existing message | T017, T019, T020 |
| FR-019 leaving a draft creates nothing and leaves the previous content unchanged | T017, T020 |
| FR-020 the highlight is the sentence being spoken, advancing and clearing | T003, T004, T005, T006, T007, T008, T009 |
| FR-021 a pause/resume leaves the highlight on the repeated sentence | T003, T004, T005, T007, T009 |
| SC-001 no sentence spoken while its position is outside the visible area | T004, T006, T009 |
| SC-002 a below-the-fold start position is shown by its first utterance | T004, T006, T009 |
| SC-003 a text that fits on screen moves the page by zero pixels | T004, T006, T009 |
| SC-004 a reader can see a candidate typeface and size before applying it | T011, T013 |
| SC-005 the choice is in force after a restart, and the largest size clips nothing | T010, T012, T014, T015 |
| SC-006 a new content is created in one tap plus Save and appears in the list | T017, T019, T020 |
| SC-007 leaving a new content unsaved, or saving it empty, adds no entry | T017, T019, T020 |
| SC-008 the highlighted text is exactly the sentence being spoken, resume included | T003, T004, T007, T009 |
