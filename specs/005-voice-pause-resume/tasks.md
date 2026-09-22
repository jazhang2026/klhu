# Tasks: Voice List Improvements and Pause/Resume Functionality

**Input**: Design documents from `/specs/005-voice-pause-resume/`

**Prerequisites**: spec.md, plan.md, research.md, data-model.md, quickstart.md

**Tests**: Required by constitution (TDD) — tests written first and fail before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add i18n keys for voice characteristics and verify baseline

- [x] T001 Add voice characteristic translation keys to `lib/l10n/app_en.arb` (genderMale, genderFemale, ageYoung, ageOld, dialectStandard, etc.)
- [x] T002 Add voice characteristic translation keys to `lib/l10n/app_zh.arb` (male=男, female=女, young=年轻, old=年长, standard=标准音, etc.)
- [x] T003 Regenerate localizations: `flutter gen-l10n`
- [x] T004 Confirm `flutter analyze` clean and `flutter test` green on current code (92 tests) — baseline verification

## Phase 2: User Story 1 - User-Friendly Voice Names with i18n (Priority: P1)

**Goal**: Display user-friendly voice names with characteristics (gender, age, dialect) in English and Chinese via static mapping table

**Independent Test**: Open voice picker, verify voices display with user-friendly names in current language, unmapped voices fall back to system names

### Implementation for User Story 1

- [x] T005 [P] Create `lib/models/voice_mapping.dart`: VoiceMapping model with systemVoiceId, englishName, chineseName, gender, age, dialect fields
- [x] T006 [P] Create `lib/services/voice_mapping_service.dart`: VoiceMappingService with static lookup table for common TTS voices (Google, Samsung, iOS), fallback to system name
- [x] T007 [US1] Write `test/voice_mapping_test.dart`: lookup by system voice ID, fallback behavior, empty mapping handling (MUST FAIL before implementation)
- [x] T008 [US1] Write `test/voice_mapping_service_test.dart`: English and Chinese name retrieval, missing characteristics handling (MUST FAIL before implementation)
- [x] T009 [US1] Implement VoiceMappingService static table with 10+ common voices (en-US, en-GB, zh-Hans-CN variants)
- [x] T010 [US1] Update `lib/voice_picker_screen.dart`: use VoiceMappingService to display user-friendly names with characteristics
- [x] T011 [US1] Validate on Android emulator: voice picker shows "Female Voice 1 (Young, Standard)" in EN, "女声1 (年轻, 标准音)" in ZH

**Checkpoint**: User Story 1 complete — voice picker displays user-friendly names in both languages

## Phase 3: User Story 2 - Pause/Resume TTS Reading with Icon Buttons (Priority: P1)

**Goal**: Add pause/resume functionality for page reading, convert all action buttons to icons with accessibility features

**Independent Test**: Start page reading, tap Pause (button changes to Resume), tap Resume (reading continues), tap any other button (reading stops completely)

### Tests for User Story 2 (TDD - Constitution Required) ⚠️

- [x] T012 [P] [US2] Write `test/reading_view_pause_test.dart`: pause/resume state transitions, resume from correct position, stop on other action while paused (MUST FAIL before implementation)

### Implementation for User Story 2

- [x] T013 [US2] Create `lib/models/reading_state.dart`: ReadingState enum (idle, reading, paused) with currentParagraphIndex tracking
- [x] T014 [US2] Update `lib/reader_service.dart`: add pause() and resume() methods using flutter_tts API, track current paragraph index
- [x] T015 [US2] Update `lib/reading_view.dart`: add pause/resume state management, convert buttons to IconButton with tooltips
- [x] T016 [US2] Add semantic labels to icon buttons for screen reader accessibility
- [x] T017 [US2] Ensure language switch while paused triggers full stop (spec 004 requirement)
- [x] T018 [US2] Validate on Android emulator: pause/resume works correctly, icon buttons visible, tooltips show on long press

**Checkpoint**: User Story 2 complete — pause/resume functional with icon buttons

## Phase 4: Polish & Integration

**Purpose**: Edge cases, accessibility, and final validation

- [x] T019 [P] Add rapid pause/resume toggle guard (_isPausing/_isResuming flags)
- [x] T020 [P] Verify 44pt touch targets for all icon buttons (Material minimum)
- [x] T021 [US1+US2] Run full test suite: `flutter test` (expect 92+ tests)
- [x] T022 [US1+US2] Run `flutter analyze` (expect clean)
- [x] T023 Run quickstart.md validation scenarios 1-10 on Android emulator
- [x] T024 Update breakpoint.md with completion status

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **User Story 1 (Phase 2)**: Depends on Setup completion
- **User Story 2 (Phase 3)**: Depends on Setup completion - can start after US1 or in parallel with later US1 tasks
- **Polish (Phase 4)**: Depends on US1 and US2 completion

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD constitution requirement)
- Model/service first, then UI integration
- Core implementation before edge-case handling

## Completion Notes (2026-09-22)

Deviations from the plan, recorded so the checkboxes are honest:

- **T008** was covered by `test/voice_mapping_test.dart` (lookup/fallback/characteristics
  in both languages) instead of a separate service test file — one file, same contracts.
- **T013** shipped as a `_Mode` enum inside `lib/reading_view.dart` (`read`, `edit`,
  `speaking`, `paused`) rather than a separate model file; the paragraph cursor lives in
  `ReaderService.speakParagraphs`' own loop, which is what resume actually needs.
- **T014**: `flutter_tts.pause()` is a **toggle**, so `Reader` exposes `pause()` only; the
  view calls it for pause *and* resume. Resume does not re-issue a read.
- **T011/T018/T023**: voice-list labels dropped age/dialect/Local-Network suffixes after
  on-device measurement (see `voice-gender-evidence.md`) — the engine exposes neither, and
  every gender now comes from measured F0 + the engine's own voice manifest.
- Regression tests added for two live bugs found while validating:
  `test/reading_view_pause_test.dart` covers language-switch-while-paused (scenario 7) and
  `test/branding_test.dart` covers the app-bar Voice action staying English in the ZH UI.
- **Resume was reworked after a device report that it did not work** (second pass,
  2026-09-22): `flutter_tts`'s Android `pause()` is not a toggle and throws on the second
  call, so `ReaderService` now owns pause/resume (`Reader.resume()`, `TtsBackend.pause()`
  deleted) and resume is paragraph-granular: the interrupted paragraph is read again from
  its start, then the queue continues in order. Details and evidence in `breakpoint.md`.
