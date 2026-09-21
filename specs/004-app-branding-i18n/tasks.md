# Tasks: App Branding and Internationalization

**Input**: Design documents from `/specs/004-app-branding-i18n/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Required by constitution (TDD) — tests written first and fail before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter project**: `lib/`, `android/`, `ios/`, `test/` at repository root
- Paths follow existing klhu project structure from specs 001-003

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add i18n dependencies and verify baseline

- [x] T001 Add flutter_localizations and intl dependencies via `flutter pub add flutter_localizations intl` and verify `flutter pub get` succeeds
- [x] T002 Confirm `flutter analyze` clean and full `flutter test` green on 003 code (77/77 tests) — baseline verification before 004 changes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core i18n infrastructure that MUST complete before ANY user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 [P] Create lib/l10n/ directory structure with app_en.arb and app_zh.arb files for English and Chinese translations
- [x] T004 [P] Implement lib/models/language_preference.dart: LanguagePreference model with load/save methods using shared_preferences (key: interface_language, values: en/zh-Hans, default: en)
- [x] T005 [P] Implement lib/services/localization_service.dart: LocalizationService for managing language preference loading/saving and locale resolution
- [x] T006 Configure MaterialApp in lib/main.dart to support dynamic locale switching via LocalizationService and flutter_localizations delegates
- [x] T007 [P] Write test/language_preference_test.dart: load/save round-trip, invalid value handling, default fallback (MUST FAIL before T004)
- [x] T008 [P] Write test/localization_service_test.dart: locale resolution, preference management, error handling (MUST FAIL before T005)

**Checkpoint**: Foundation ready - i18n infrastructure complete, user story implementation can now begin

---

## Phase 3: User Story 1 - App branding with localized titles and custom icon (Priority: P1) 🎯 MVP

**Goal**: App displays "KalaHoo"/"卡啦虎" titles based on language and uses custom icon from images/kalahu.jpeg

**Independent Test**: Launch app on Android emulator, verify "KalaHoo" title in English mode, "卡啦虎" in Chinese mode, custom icon displays on home screen, fallback to default icon when file missing

### Tests for User Story 1 (TDD - Constitution Required) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Write test/branding_test.dart: app title localization test (English/Chinese), icon file existence check, fallback behavior (MUST FAIL before implementation)
- [x] T010 [P] [US1] Write widget test for app icon display verification in reading_view_test.dart (MUST FAIL before implementation)

### Implementation for User Story 1

- [x] T011 [US1] Add app title translations to lib/l10n/app_en.arb (appTitle: "KalaHoo") and lib/l10n/app_zh.arb (appTitle: "卡啦虎")
- [x] T012 [US1] Configure Android app title localization in android/app/src/main/res/values/strings.xml (app_name: "KalaHoo") and android/app/src/main/res/values-zh/strings.xml (app_name: "卡啦虎")
- [x] T013 [US1] Configure iOS app title localization in ios/Runner/Info.plist (CFBundleDisplayName: "KalaHoo") and ios/Runner/zh-Hans.lproj/InfoPlist.strings (CFBundleDisplayName: "卡啦虎")
- [x] T014 [US1] Add custom app icon support: place images/kalahu.jpeg and configure android/app/src/main/res/mipmap-*/ and ios/Runner/Assets.xcassets/AppIcon.appiconset/ with fallback to default Flutter icon
- [x] T015 [US1] Integrate app title localization in lib/reading_view.dart AppBar using AppLocalizations.of(context)!.appTitle
- [x] T016 [US1] Add icon file existence check with fallback logic in app initialization
- [x] T017 [US1] Validate on Android emulator per quickstart scenarios 1-3 (icon display, English title, Chinese title)

**Checkpoint**: User Story 1 fully functional and testable independently — MVP branding complete

---

## Phase 4: User Story 2 - Language switching dropdown (Priority: P1)

**Goal**: Language dropdown shows current language in native name ("English"/"中文"), allows switching to available languages, persists preference, updates all UI within 1 second

**Independent Test**: Launch app, verify dropdown shows current language in native name, tap dropdown to see "English"/"中文" list, switch language, verify all UI updates within 1 second, restart app to verify persistence

### Tests for User Story 2 (TDD - Constitution Required) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T018 [P] [US2] Write widget test for language dropdown in test/reading_view_test.dart: current language display in native name, dropdown list shows native names, selection updates locale (MUST FAIL before implementation)
- [x] T019 [P] [US2] Write integration test for language switching flow: preference persistence, UI updates, TTS stopping on language change (MUST FAIL before implementation)

### Implementation for User Story 2

- [x] T020 [US2] Add native language name translations to lib/l10n/app_en.arb (englishNative: "English", chineseNative: "中文") and lib/l10n/app_zh.arb (englishNative: "English", chineseNative: "中文")
- [x] T021 [US2] Add all UI translation keys to lib/l10n/app_en.arb and lib/l10n/app_zh.arb (readButton, stopButton, editButton, doneButton, voiceButton, languageDropdown, hintText, etc.)
- [x] T022 [US2] Implement language dropdown widget in lib/reading_view.dart using DropdownButton with native language names, integrated in AppBar
- [x] T023 [US2] Wire language dropdown selection to LocalizationService.updateLanguage() and trigger MaterialApp locale rebuild
- [x] T024 [US2] Integrate language switching with existing ReaderService.stop() to stop TTS reading before language change
- [x] T025 [US2] Add UI text updates throughout lib/reading_view.dart to use AppLocalizations for all buttons, labels, and messages
- [x] T026 [US2] Handle rapid language switching by using latest selection only (debounce or state guard)
- [x] T027 [US2] Validate on Android emulator per quickstart scenarios 4-10 (dropdown behavior, switching, persistence, TTS integration, accessibility)

**Checkpoint**: User Stories 1 AND 2 both work independently — full i18n complete

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, accessibility, and validation

- [x] T028 [P] Add missing translation fallback logic with error logging in localization service
- [x] T029 [P] Add missing icon file fallback logic with error logging in app initialization
- [x] T030 [P] Implement language preference storage failure handling with fallback to English and user error message
- [x] T031 [P] Accessibility pass: verify language dropdown has proper semantic labels, minimum 44pt touch targets, screen reader announcements for native language names
- [x] T032 Run quickstart.md validation end-to-end on Android emulator (all 10 scenarios)
- [x] T033 Run `flutter analyze` clean and full `flutter test` green (including new 004 tests)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - No dependencies on US2
- **User Story 2 (Phase 4)**: Depends on Foundational completion - Can integrate with US1 but independently testable
- **Polish (Phase 5)**: Depends on US1 and US2 completion

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Independent of US2
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Builds on US1 branding but independently testable for language switching

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD constitution requirement)
- Translations before UI integration
- Service implementation before widget integration
- Core implementation before edge case handling
- Story complete before moving to next story

### Parallel Opportunities

- T003, T004, T005 can run in parallel (different files)
- T007, T008 can run in parallel (different test files)
- T009, T010 can run in parallel (different test files)
- T018, T019 can run in parallel (different test files)
- T028, T029, T030, T031 can run in parallel (different concerns)

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Write test/branding_test.dart: app title localization test, icon file existence check, fallback behavior"
Task: "Write widget test for app icon display verification in reading_view_test.dart"

# After tests fail, launch implementation tasks:
Task: "Add app title translations to lib/l10n/app_en.arb and lib/l10n/app_zh.arb"
Task: "Configure Android app title localization in android/app/src/main/res/values/strings.xml and values-zh/"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (branding)
4. **STOP and VALIDATE**: Test User Story 1 independently (icon + titles)
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → i18n foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP branding!)
3. Add User Story 2 → Test independently → Deploy/Demo (full i18n!)
4. Add Polish → Final validation
5. Each phase adds value without breaking previous work

### Sequential Team Strategy

With single developer (klhu approach):

1. Complete Setup + Foundational together
2. Complete User Story 1 (branding) → Validate
3. Complete User Story 2 (language switching) → Validate
4. Complete Polish → Final validation
5. Each story independently testable and demonstrable

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Tests written FIRST per constitution TDD requirement
- Each user story independently completable and testable
- Verify tests fail before implementing (constitution requirement)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Language dropdown uses native names ("English", "中文") for current and list display
- Future extensibility: dropdown design supports 2+ languages by extending the list