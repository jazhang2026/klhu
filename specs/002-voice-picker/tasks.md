# Tasks: Voice Picker with Preview

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md` from `/specs/002-voice-picker/`

**Prerequisites**: 001-read-aloud done (Flutter SDK, emulator, `flutter_tts` 4.2.3 working); content rule: one language per paragraph

**Tests**: Required by constitution (TDD) — tests written first and fail before implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (mixed read/P1), US2 (picker/P1), US3 (per-language/P2)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: New dependency, verify baseline green

- [x] T001 Add `shared_preferences` dependency (`flutter pub add shared_preferences`), `flutter pub get`, confirm `flutter analyze` clean and 001 tests still green (DONE 2026-09-15: analyze clean, 25/25 green)
- [x] T002 Log raw `getVoices` output on Android emulator (name + locale per entry) to pin filter/match assumptions in `research.md` (DONE 2026-09-15: `debugPrint('klhu getVoices: ...')` in `voicesFor`, fires on picker open)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Resolver + store + TTS extension every story depends on

- [x] T003 [P] Write `test/language_test.dart`: pure EN → en, CJK present → zh-Hans, mixed-script paragraph → zh-Hans (CJK wins), empty/punctuation-only, future-rule extensibility (DONE 2026-09-15: 8/8 green)
- [x] T004 [P] Implement `lib/language.dart`: rule-table resolver `String → 'en' | 'zh-Hans'` (rule 1: CJK regex, fallback: en) (DONE 2026-09-15)
- [x] T005 [P] Write `test/voice_store_test.dart`: save/load round-trip per language, unparseable value ≡ no choice, key names `voice_en` / `voice_zh_Hans` (DONE 2026-09-15: 4/4 green)
- [x] T006 [P] Implement `lib/voice_store.dart`: shared_preferences load/save per-language VoiceChoice (`"<name>||<locale>"`) (DONE 2026-09-15)
- [x] T007 Write `test/reader_service_test.dart` (fake tts): getVoices parsing (malformed entries skipped), persisted-pair match → setVoice else default, speakParagraphs order, stop-first, generation-cancel on Stop (DONE 2026-09-15: 4/4 green)
- [x] T008 Extend `lib/reader_service.dart`: getVoices, setVoice, `speakParagraphs()` sequential with generation counter + stop-first (DONE 2026-09-15: TtsBackend seam + FakeReader updated, 41/41 green, analyze clean)

**Checkpoint**: `flutter test` green on language/store/service (DONE 2026-09-15: 41/41, analyze clean); foundation ready.

---

## Phase 3: User Story 1 - Mixed page reads per paragraph (Priority: P1) 🎯 MVP

**Goal**: Paragraph/page reads speak each paragraph in its own language's picked voice, in order; sentence tap uses enclosing paragraph's language; Stop halts <1s.

**Independent Test**: Android emulator, mixed EN/zh sample (languages separated by blank lines): Read page → EN paragraphs in EN voice, zh paragraphs in zh voice, in order; Stop halts mid-page.

- [x] T009 [US1] Write US1 widget cases in `test/reading_view_mixed_test.dart`: mixed page order, sentence tap inherits paragraph language, no mid-paragraph switch/repeat/skip, Stop halts (DONE 2026-09-15: 4/4 green)
- [x] T010 [US1] Wire resolver + picked voices into `lib/reading_view.dart` (paragraph ranges from segmenter → language.dart → voice_store choice → speakParagraphs) (DONE 2026-09-15: shared _readRange, 001 tests migrated to per-paragraph path, 45/45 green, analyze clean)
- [x] T011 [US1] Validate on Android emulator per SC-001 (PASS 2026-09-15: user pasted mixed EN/zh paragraphs, Read spoke both languages in order, Stop OK — note: no bundled mixed sample, paste-only for now)

**Checkpoint**: US1 fully functional and testable independently — MVP.

---

## Phase 4: User Story 2 - Pick a voice for my language (Priority: P1)

**Goal**: Picker reachable from reading screen lists installed voices per active language, tap previews sample line in that voice, choice persists across restart with fallback to OS default.

**Independent Test**: Android emulator: picker list matches getVoices for active language, tap → sample line in tapped voice <2s, restart → Read uses picked voice, missing voice → OS default, no crash/silence.

- [x] T012 [US2] Write `test/voice_picker_test.dart`: locale-prefix filter (en* / zh*), tap → preview in tapped voice, persist + restart uses choice, empty list + load-failure states, rapid-tap latest-wins, preview stops in-progress reading (DONE 2026-09-15: 5/5 green)
- [x] T013 [US2] Implement `lib/voice_picker_screen.dart` (list/preview/persist, loading/empty/error states) + AppBar voice action in `lib/reading_view.dart` (DONE 2026-09-15: previewVoice on Reader, 50/50 green, analyze clean; +in-picker EN/中文 SegmentedButton 2026-09-15, 53/53 green)
- [x] T014 [US2] Validate on Android emulator per SC-002..SC-005 (list match, preview <2s, restart persist, fallbacks) — iPhone pending — DONE 2026-09-15: list filter verified vs raw getVoices (~40 en*, 13 zh*, yue-HK correctly excluded), preview <2s, restart persist pass

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 - Separate voices per language (Priority: P2)

**Goal**: EN and zh-Hans keep independent choices; each previewed in its own sample line; each Read uses its own voice after restart.

**Independent Test**: Pick voice A for EN, switch sample to zh-Hans, pick voice B, restart, Read EN uses A and Read zh-Hans uses B.

- [x] T015 [US3] Extend `test/voice_picker_test.dart` with P2 cases: per-language independent choice, picker shows active language's choice, restart keeps both (DONE 2026-09-15: en+zh persist independently, 52/52 green)
- [x] T016 [US3] Wire per-language active selection in picker + reading view (choice keyed by content language) (DONE 2026-09-15: fell out of US1/US2 — VoiceStore per-language keys + picker language param + _activeLanguage)
- [x] T017 [US3] Validate on Android emulator per SC-004 (both languages, 100% of trials) (DONE 2026-09-15: EN + zh picks both survive restart, mixed read uses each)

**Checkpoint**: All stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T018 Edge-case pass: empty voice list, getVoices failure + retry, rapid preview taps, preview-during-reading, uninstall-clears (SC-005, no crash/silence anywhere) (DONE 2026-09-15: rapid-tap latest-wins + preview-stops-reading pass on emulator; empty/failure/uninstall covered by widget tests)
- [x] T019 TalkBack pass (DONE 2026-09-15 automated semantics: Voice action exposes tooltip+tap, rows expose tap+labels, selection merged as 'Selected', `test/voice_picker_semantics_test.dart` 2/2 green; selected marker Text('✓')→Icon(semanticLabel) for announcement. Manual double-tap deferred: emulator TalkBack activation succeeds ~1/10 across ALL buttons incl. system UI — emulator timing issue, not app; ear-check pending real device)
- [x] T020 `flutter analyze` clean, full `flutter test` green (DONE 2026-09-15: analyze clean, 55/55 green; quickstart EN+zh E2E covered by T011/T014/T017 emulator passes)

---

## Dependencies & Execution Order

- T001 → T002 → (T003..T008) → US1 (T009→T010→T011) → US2 (T012→T013→T014) → US3 (T015→T016→T017) → Polish (T018→T019→T020)
- T003/T004 pair, T005/T006 pair writable in parallel with T007 (different files); tests before implementation per task
- Stories sequential P1 → P1 → P2 (single developer); US1 is MVP
