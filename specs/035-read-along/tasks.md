# Tasks: Read-Along Language Learning

**Input**: Design documents from `/specs/035-read-along/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Included — constitution principle III (tests before implementation).
**Amended**: STT removed; voice detection + kept audio (see research.md amendment).

> **Post-implementation amendments (2026-11-18, final)**: task text below predates three later changes — (1) one read+record attempt per tap replaced the 3-cycle loop (T006/T007/T011/T015/T018 wording), (2) the mic opens *paused* before TTS and resumes at read end, (3) lifecycle fixes: fresh recorder per Learn entry, recordings deleted on summary dismissal, graceful stop keeps in-flight attempt, busy taps ignored without highlight. All tasks are checked; `spec.md`/`data-model.md` are authoritative.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependencies)
- **[Story]**: US1=P1, US2=P1, US3=P2, US4=P3

## Path Conventions

- Flutter app: `lib/`, `test/` (new `lib/learn/` module)
- Tests: `test/` mirror paths (constitution III: tests precede code)

---

## Phase 1: Setup (deps + permissions)

- [x] T001 Create feature branch `035-read-along` from `main`
- [x] T002 Add `record: ^7.1.2` and `audioplayers: ^6.8.1` to `pubspec.yaml`; remove `speech_to_text`; run `flutter pub get`
- [x] T003 Add `android.permission.RECORD_AUDIO` to `android/app/src/main/AndroidManifest.xml`; add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist` and `macos/Runner/Info.plist` (no iOS speech key needed — no STT)
- [x] T004 [P] Add Learn l10n keys ×4 ARBs (`app_en`, `app_es`, `app_zh`, `app_zh_Hans`): `learnToggle`, `learnMode`, `learnStatusReading`, `learnStatusListening`, `learnStatusWaiting`, `learnStatusRecording`, `learnTapSentence`, `learnStop`, `learnStopTitle`, `learnSummaryVoiced`, `learnSummaryNoVoice`, `learnSummaryFailed`, `learnNoVoiceLabel`, `learnVoiceCapturedLabel`, `learnRecordingFailedLabel`, `learnPlayRecording`, `learnStopRecording`, `learnNoSpeechMsg`, `learnMicDeniedMsg`, `learnMicDeniedTitle`, `learnRecordFailedMsg`, `learnUnsupportedMsg` — run `flutter gen-l10n`

## Phase 2: Foundational — voice capture + session core

- [x] T005 [P] [US1] Test `test/voice_activity_test.dart`: `analyzeVoiceActivity(samples, sampleIntervalMs)` — silence-only → not voiced; loud burst ≥ minVoicedMs → voiced; threshold boundaries; empty list
- [x] T006 [P] [US1] Test `test/learn_session_test.dart`: `LearnSession` state machine + `LearnAttempt`/`SentenceResult` with `voiceDetected`, `duration`, `audioPath`, `failure`; 3-attempt lifecycle, re-practice appends, `sentenceCompleted`, `bestVoiceCount`, `noVoiceCount`, `totalAttempts`, `completedSentences`, `spokenSentences`
- [x] T007 [P] [US1] Test `test/learn_controller_test.dart` + fakes: `FakeVoiceCapture` (start/stop/amplitudes), mic permission stub; 3-cycle orchestration, wait-state, sentence switch mid-cycle, permission denial, capture error → failed attempt, session summary fields
- [x] T008 [US1] Implement `lib/learn/voice_activity.dart`: pure `analyzeVoiceActivity(List<double> dbSamples, {required double sampleIntervalMs, double thresholdDb = -45, double minVoicedMs = 250})` → `VoiceActivityResult{voiced, voicedMs, peakDb}`
- [x] T009 [US1] Implement `lib/learn/learn_session.dart`: `LearnState`, `AttemptStatus {voice, noVoice, failed}`, `AttemptFailure {permissionDenied, captureError}`, `LearnAttempt`, `SentenceResult`, `LearnSession` (startSentence/selectSentence/recordVoice/recordNoVoice/recordFailed/practiceAgain/stop/clear — no score fields)
- [x] T010 [US1] Implement `lib/learn/voice_capture.dart`: `VoiceCapture` seam (`start(path)`, `amplitudes` stream, `stop() → {path, duration}`), `CaptureError` enum, `RecorderVoiceCapture` on `record` plugin (`AudioEncoder.aacLc`, `onAmplitudeChanged`, `hasPermission` via permission_handler)
- [x] T011 [US1] Implement `lib/learn/learn_controller.dart`: TTS→await→lazy mic permission→record with VAD window (stop after 2s trailing silence or 15s cap)→analyze→×3→wait; `nextRecordingPath` seam for temp files; cleanup `deleteRecordings` on abandon/stop

## Phase 3: US1 — Learn mode entry (P1, MVP)

- [x] T012 [P] [US1] Test `test/reading_view_learn_test.dart` additions: toggle swaps control row; Learn tap → single read of tapped sentence (record fake speaks+records)
- [x] T013 [US1] Wire Learn toggle button into `reading_view.dart` idle control row (`_learnActive ? _learnControls : _normalControls`)
- [x] T014 [US1] Wire Learn tap routing: `_handleSentenceTap` branches when `_learnActive` → `_learnTap(segment)`; `commentsRead: false` for practice reads; resume normal read on Learn exit; abandon on dispose/text change

## Phase 4: US2 — Read-along cycle (P1)

- [x] T015 [P] [US2] Test: 3-cycle loop — TTS once → mic records → voiced result → repeat; only tapped sentence read; Learn status shows listening/recording states
- [x] T016 [US2] Implement per-attempt UI in `_learnControls`: status text + last attempt result (voiced / no voice / failed + duration) + play/stop button for the attempt's audio
- [x] T017 [P] [US2] Test: mic permission denied → attempts `failed(permissionDenied)`, cycles continue read-only, localized message shown
- [x] T018 [US2] Implement lazy mic permission request inside `LearnController.startSentence` (first repeat only); denial → unscored-equivalent failed attempts
- [x] T019 [P] [US2] Test: capture error mid-run → `failed(captureError)` attempt; next attempt retries

## Phase 5: US3 — Stop + summary (P2)

- [x] T020 [P] [US3] Test: Stop → summary sheet lists sentences with voiced/no-voice/failed counts + per-attempt play buttons; dismissal returns to normal controls
- [x] T021 [US3] Implement summary sheet in `reading_view.dart` (stateless dialog/bottom sheet over `LearnSession` snapshot; `AudioPlayer` play/stop per attempt file)
- [x] T022 [US3] Wire Stop button in Learn controls → `learn.stop()` → show summary → session cleared

## Phase 6: US4 — Re-practice (P3)

- [x] T023 [P] [US4] Test: tap already-practiced sentence → fresh 3-cycle run, attempts appended
- [x] T024 [US4] Implement: `selectSentence` re-entry appends attempts (already in session model — verify widget path)

## Phase 7: Polish & verification

- [x] T025 Run `flutter analyze --no-pub`; resolve all errors/warnings in changed files
- [x] T026 Run `flutter test --concurrency=2` (or memory-scoped variant); all green
- [ ] T027 Device walk on OnePlus 9 (`37e102a0`) per `quickstart.md`: record → voiced detection → playback works, no speech packs needed, all 3 languages
- [ ] T028 Commit on `035-read-along`; request merge approval (do NOT merge to `main` without user ok)

## Dependencies

- Phase 2 blocks all user stories (seams + session model)
- US1 (T012-T014) → US2 (T015-T019) → US3 (T020-T022)
- US4 (T023-T024) after US1+US2
- MVP = Phases 1-3

## Parallel Execution Examples

- Phase 2: T005/T006/T007 tests in parallel, then T008-T011 implementations
- Phase 3: T012 test parallel with nothing (depends on controller)
- Phase 4: T015/T017/T019 tests parallel; T016/T018 implementations
- Phase 5: T020 test → T021/T022 implementation

## Notes

- Constitution III: every `[P]` test task was written before its implementation task
- All platform access hidden behind seams (`VoiceCapture`, `MicPermission`,
  `nextRecordingPath`, `LearnSpeaker`) — widget/unit tests inject fakes,
  no platform channels exercised
- Audio files: temp dir via `path_provider`, one `.m4a` per attempt,
  deleted on session end — no persistence beyond the session
- `record`/`audioplayers` need no extra manifest entries beyond
  `RECORD_AUDIO` (already added); iOS needs no speech-recognition key
- Device matrix per spec: OnePlus 13 + OnePlus 9; OnePlus 9 is the primary
  retest target after the STT pivot
- Cancelled: STT seam (`speech_recognizer.dart`), `speech_scorer.dart`,
  accuracy/transcript/missed/extra fields, `speech_to_text` dependency
EOF

echo tasks updated