# Tasks: Tap-to-Resolve Read Aloud

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md` from `/specs/001-read-aloud/`

**Prerequisites**: Flutter SDK installed, `flutter create .` run in `klhu/`, `flutter_tts` added

**Tests**: Required by constitution (TDD) — tests written first and fail before implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (sentence/P1), US2 (paragraph/P2), US3 (page/P3)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Flutter scaffold + dependencies

- [x] T001 Install Flutter stable SDK and verify `flutter --version` (BLOCKS everything below)
- [x] T002 Run `flutter create .` in `klhu/` and confirm `flutter test` passes on scaffold
- [x] T003 Add `flutter_tts` dependency and bundled sample texts in `lib/sample_texts.dart` (EN + zh-Hans)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Segmenter + TTS service every story depends on

- [x] T004 [P] Implement `lib/segmenter.dart`: sentence ranges (EN + CJK punctuation), paragraph ranges (blank-line split), page range, tap-offset resolution + nearest-sentence rule
- [x] T005 [P] Implement `lib/reader_service.dart`: `flutter_tts` wrapper — setLanguage en-US/zh-Hans-CN per locale, speak, stop, error on missing voice
- [x] T006 [P] Write `test/segmenter_test.dart`: EN boundaries, zh-Hans boundaries (。！？；), mixed text, whitespace-tap resolution, offsets (MUST FAIL before T004)
- [x] T007 Implement `lib/reading_view.dart` shell: text display, paste field, Read/Stop/Read-page buttons (no story logic yet)

**Checkpoint**: `flutter test` green on segmenter; foundation ready.

---

## Phase 3: User Story 1 - Tap sentence, hear it read (Priority: P1) 🎯 MVP

**Goal**: Tap resolves enclosing sentence start-to-end, highlights, speaks it, Stop halts.

**Independent Test**: Simulator + emulator, EN and zh-Hans samples: tap in sentence → full-sentence highlight → Read speaks exactly it → Stop <1s.

- [x] T008 [US1] Write `test/reading_view_test.dart` P1 cases: tap→sentence highlight, Read speaks sentence, Stop halts (MUST FAIL before T009)
- [x] T009 [US1] Wire tap→`segmenter` sentence resolution→highlight→`reader_service.speak` + Stop in `lib/reading_view.dart` (single-RichText: fixes select font jump; explicit classic-sRGB root style: fixes red-48px fallback + inherited-white mispaint on device)
- [x] T010 [US1] Validate on Android emulator per SC-001..SC-004 (PASS 2026-09-14, EN+zh; fixed: Read-no-tap prompt, stop-on-text-switch) — iPhone simulator still pending (needs macOS)

**Checkpoint**: US1 fully functional and testable independently — MVP.

---

## Phase 4: User Story 2 - Tap paragraph, hear it read (Priority: P2)

**Goal**: Tap resolves enclosing paragraph start-to-end, highlights, speaks in order.

**Independent Test**: Tap in paragraph → full-paragraph highlight → Read speaks paragraph in order.

- [x] T011 [US2] Extend `test/reading_view_test.dart` with P2 cases (MUST FAIL before T012)
- [x] T012 [US2] Wire paragraph resolution (long-press → paragraph tap) in `lib/reading_view.dart`
- [x] T013 [US2] Validate on both emulators (Android PASS 2026-09-14)

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 - Read whole page (Priority: P3)

**Goal**: Read page resolves page start-to-end, reads top-to-bottom.

**Independent Test**: Tap Read page → page highlight → full page spoken in order, Stoppable.

- [x] T014 [US3] Extend `test/reading_view_test.dart` with P3 cases (MUST FAIL before T015)
- [x] T015 [US3] Wire Read-page action in `lib/reading_view.dart` (existed from shell; pinned by P3 tests)
- [x] T016 [US3] Validate on both emulators, incl. long-page responsiveness (Android PASS 2026-09-14: tap→highlight, Read→TTS started en-US + zh-Hans cmn-CN, Stop, EN/zh switch clears highlight, 441KB bench ~9ms/tap, no crash — iPhone still pending, needs macOS)

**Checkpoint**: All stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T017 VoiceOver/TalkBack pass: controls operable, no double-speaking (TalkBack automation PASS 2026-09-14: 6 buttons + reading text + field all in semantics tree, stable, no crash — ear-check for double-speaking + VoiceOver need human/macOS)
- [x] T018 Missing-voice + whitespace-tap error paths verified on both platforms (Android PASS 2026-09-14: missing-voice UI path unit-pinned via FailingReader→error line; whitespace tap→nearest-sentence highlight on device, no crash — both voices present on this emulator; iPhone pending)
- [x] T019 Run `quickstart.md` validation end-to-end (EN + zh-Hans, both emulators) (Android E2E PASS 2026-09-14: analyze clean, 25/25 tests, device tap/Read/Stop/switch/scroll/TalkBack/error paths verified EN+zh — iPhone simulator pending, needs macOS)

---

## Dependencies & Execution Order

- T001 → T002 → T003 → (T004..T007) → US1 (T008→T009→T010) → US2 → US3 → Polish
- T004/T005/T006 writable in parallel (different files); tests before implementation per task
- Stories sequential in priority order P1 → P2 → P3 (single developer)
