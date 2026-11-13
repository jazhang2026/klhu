# Tasks: Tap-to-read — remove the Read button

**Input**: Design documents from `/specs/032-tap-to-read/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: INCLUDED — constitution III (test-first) requires failing widget tests before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)

## Path Conventions

- Single project: `lib/`, `test/`, `specs/` at repository root

---

## Phase 1: Setup

- [X] T001 Create git branch `032-tap-to-read` from the current working state

## Phase 2: Foundational (blocking prerequisites)

- [X] T002 [P] Add tap/long-press read helpers to `test/content_fixtures.dart` (or a shared test helper): `tapSentence(tester, text)`, `tapParagraph(tester, text)` built on the existing `offsetOf` at `test/content_fixtures.dart:129`

---

## Phase 3: User Story 1 — Tap a sentence, hear it (Priority: P1)

**Goal**: tap/long-press highlights AND reads immediately; the Read button is gone; a finished read keeps
its highlight and advances only the Continue Read anchor.

**Independent Test**: tap a sentence → only it is spoken, stays highlighted; tap again → repeats;
long-press → whole paragraph read and highlighted; no Read tooltip exists.

### Tests (write first — must fail before implementation)

- [X] T003 [US1] Rewrite `test/reading_view_step_test.dart` to drive reads by tapping sentence text via
  `offsetOf` instead of `find.byTooltip('Read')`; update `pressRead` helper at `:184-187`; change
  expectations: highlight stays on the read unit (no auto-advance), paragraph long-press reads immediately
  without a Read press
- [X] T004 [US1] Update `test/reading_view_test.dart`: "tap highlights the tapped sentence" now also speaks
  (`:124-146`); "Read speaks the highlighted sentence" becomes "tap speaks the sentence" (`:148-169`);
  "Read with nothing selected" case removed or repurposed (`:199+`); Stop/Pause tests retargeted to
  tap-initiated reads
- [X] T005 [P] [US1] Update Read-tooltip references in `test/reading_view_follow_test.dart`,
  `test/reading_view_comment_test.dart`, `test/reading_view_edit_test.dart`,
  `test/reading_view_video_test.dart`, `test/reading_view_video_assignment_test.dart`,
  `test/picture_assignment_switch_test.dart` — replace `find.byTooltip('Read')` presses with text taps

### Implementation

- [X] T006 [US1] In `lib/reading_view.dart`, make `_resolveAt` (`:1399-1412`) await `_readSelection()`
  after `_select(segment)` so tap/long-press reads immediately; update the stale "wait for a read action"
  doc comments on `_resolveAt`/`_select`/`_readSelection`
- [X] T007 [US1] In `lib/reading_view.dart` `_runRead` finally (`:1862-1891`): for stepped reads call the
  new `_advanceAnchor(_stepEndKey)` instead of `_advanceStep` — set `_anchor` to the next
  `stepRanges(_spoken)` start without touching `_highlight`; delete `_advanceStep` (`:1817-1831`)
- [X] T008 [US1] Remove the Read `IconButton` from the idle toolbar branch in `lib/reading_view.dart`
  (`:3694-3699`)
- [X] T009 [P] [US1] Drop `readButton` from `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb`,
  `app_es.arb`; run `flutter gen-l10n` to regenerate `app_localizations*.dart`

**Checkpoint**: US1 independently testable — `flutter test test/reading_view_step_test.dart
test/reading_view_test.dart` passes.

---

## Phase 4: User Story 2 — Continue Read loops the content (Priority: P1)

**Goal**: ⏭ reads to the end, then wraps to the first sentence and keeps reading until Pause/Stop;
pause/resume inside the loop keeps working; inter-unit Pause/Stop honoured (FR-010).

**Independent Test**: short content → `RecordingReader` speech sequence repeats from sentence 1;
Stop ends it; pause→resume continues and still wraps.

### Tests (write first — must fail before implementation)

- [X] T010 [US2] Extend `test/reading_view_continue_test.dart`: wrap-around sequence test; Stop-during-wrap
  test; pause→resume→wrap test; "⏭ after tap-read starts from next sentence" test (anchor semantics,
  spec FR-005)
- [X] T011 [P] [US2] Add a >4000-char (multi-unit) continue-read test proving Pause/Stop between units is
  honoured (FR-010) — new file `test/reading_view_paged_continue_test.dart` if the fixture doesn't fit
  existing files

### Implementation

- [X] T012 [US2] In `lib/reading_view.dart`: add `_continueReading`, `_readCompleted`, `_readFailed`,
  `_pausedReadFrom` fields (per `data-model.md`); set `_readFailed` in `_runRead`'s catch and
  `_readCompleted` in its finally for `last && !_readFailed && !stepped`; rewrite `_readContinue`
  (`:1489-1491`) as the `_driveContinue` loop; clear `_continueReading`/`_pausedReadFrom` in `_stop`,
  `_enterEdit`, `_adoptAnchor`
- [X] T013 [US2] In `lib/reading_view.dart` `_pauseResume` (`:3270-3289`): after resume's `_runRead`,
  re-enter `_driveContinue` from `_pausedReadFrom ?? 0` when `_continueReading` is armed; pass
  `last: _pausedReadFrom == null` to the resume `_runRead` call
- [X] T014 [US2] In `lib/reading_view.dart` `_readRange` non-step loop (`:1528-1567`): after each
  `_runRead`, return early when `_mode == _Mode.paused` (record `_pausedReadFrom`) or
  `_readGen != gen` (stopped/superseded)

**Checkpoint**: US2 independently testable — `flutter test test/reading_view_continue_test.dart` passes.

---

## Phase 5: User Story 3 — The rest of the page is unchanged (Priority: P2) + Polish

- [X] T015 [P] Update walk scripts `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` and
  `specs/025-document-input/scripts/klhu_walk_document.py` to drop `readButton` lookups / use text taps
- [X] T016 Run `flutter analyze --no-pub` — clean
- [X] T017 Run `flutter test --concurrency=2` — full suite green (clear `build/test_cache` first if the
  IDE crashed during an earlier run, per AGENTS.md)
- [X] T018 Device walk per `quickstart.md` — verify wrap, pause/resume, stop, tap/long-press on the `klhu`
  AVD; record results in `breakpoint.md` if issues found

## Dependencies

- T002 blocks all test tasks (helpers).
- T003–T005 (US1 tests) block T006–T009 (US1 impl) — tests must fail first.
- T006/T007/T008/T009 are sequential within US1 (same file except T009).
- US2 (T010–T014) depends on US1's `_readSelection`/tap path existing but not on US1's tests passing;
  safe to start after T006 lands.
- T015–T018 are cross-cutting; T018 last.

## Parallel opportunities

- T002 alone first; then T003+T005 can be drafted together (different files).
- T009 (l10n) runs parallel to T006–T008.
- T011 (paged test) can be written while T010 is being fleshed out.
- T015 (walk scripts) parallel to all test work.

## Implementation strategy

MVP = Phase 3 (US1): tap-to-read with no Read button — the feature's core. Phase 4 adds the wrap (US2),
which is independently shippable but required by the spec. Phase 5 is verification. Each phase ends green
on its own test files before the next begins.
