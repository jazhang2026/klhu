# Research: Read-Along Language Learning (035)

All NEEDS CLARIFICATION items resolved; decisions below.

## R1 — Speech recognition plugin

- **Decision**: `speech_to_text: ^7.5.0` (stable, published 2026-09-14).
- **Rationale**: de-facto standard Flutter STT plugin; single API across Android/iOS/macOS; exposes `SpeechListenOptions(onDevice: true, localeId: ...)`, pauseFor/listenFor bounds, and final/partial result callbacks. Latest stable; 7.6.0 is beta-only.
- **Alternatives considered**: `flutter_speech_recognition` (newer, less mature); native `SpeechRecognizer`/`SFSpeechRecognizer` via method channel (re-invents the plugin); Vosk/whisper on-device (heavy model downloads — violates simplicity).

## R2 — On-device enforcement

- **Decision**: pass `onDevice: true` in listen options; treat "unscored attempt" as the degradation path when the platform can't honor it.
- **Rationale**: iOS honors it strictly (`requiresOnDeviceRecognition`); Android maps it to prefer-on-device (`EXTRA_PREFER_OFFLINE`) — not a hard guarantee, and offline language packs may be absent. There is no reliable Android API to query offline support; try/catch + unscored fallback is the plugin authors' recommended pattern.
- **Alternatives considered**: hard-fail when offline unsupported (worse UX, and offline support is queryable only by attempting); cloud STT fallback (rejected — spec forbids).

## R3 — Microphone permission

- **Decision**: `permission_handler: ^13.0.2`; request `Permission.microphone` lazily on first repeat attempt; manifest adds `RECORD_AUDIO`.
- **Rationale**: `speech_to_text` does not reliably request Android runtime permission itself; permission_handler is the established companion (used in plugin examples). iOS permission is handled by the plugin's SFSpeechRecognizer authorization but the same permission_handler call is harmless.
- **Alternatives considered**: manual `MethodChannel` permission request (reinventing); requesting at app start (violates lazy-request FR-009).

## R4 — TTS/mic sequencing (echo gate)

- **Decision**: `ReaderService` already awaits utterance completion (`awaitSpeakCompletion(true)` inside `speakParagraphs`). Learn reads the sentence through the same path, awaits its completion future, then opens the mic. No mic window opens during TTS.
- **Rationale**: reuse guarantees identical voice/language resolution (034) and the completion signal; no new TTS plumbing.
- **Alternatives considered**: acoustic echo cancellation (unnecessary complexity); fixed delay after speak() returns (unreliable — speak() may return before audio ends).

## R5 — Transcript comparison / scoring

- **Decision**: pure-Dart word-level diff in `lib/learn/speech_scorer.dart`.
  - Normalize: lowercase, strip punctuation, collapse whitespace.
  - Latin-script targets: whitespace tokens; CJK targets (zh): character bigrams/unigrams — no word segmentation dependency.
  - Alignment: LCS-based matching; accuracy = matched / target tokens; missed = unmatched target tokens; extra = unmatched recognized tokens.
  - Result: `{accuracy (0–1), transcript, missed[], extra[]}`.
- **Rationale**: deterministic, fully testable, zero dependencies; adequate for "did the learner say the sentence" feedback. True pronunciation scoring is out of scope (spec).
- **Alternatives considered**: Levenshtein on raw strings (no word detail — spec requires missed/extra words); ML-based scoring (rejected — no AI).

## R6 — Learn mode integration in ReadingView

- **Decision**: additive `_learn` state + `_LearnController` (`lib/learn/learn_controller.dart`) owned by `_ReadingViewState`; a toggle IconButton in the existing bottom control Row swaps the row to Learn controls (mic state, Stop→summary, exit toggle). Tap path branches: `_learnActive ? _learnTap(segment) : _resolveAt(...)`.
- **Rationale**: spec FR-001/FR-012 — mode toggle beside controls, zero changes to existing paths when Learn is off. Keeps the ~4900-line file from absorbing the state machine; controller is unit-testable with fake reader + fake recognizer.
- **Alternatives considered**: new `_Mode.learn` enum value (would tangle `_isSpeakingOrPaused`/wakelock/pause logic); separate screen (rejected — user chose in-page toggle).

## R7 — Sentence source & comment exclusion

- **Decision**: Learn taps resolve through the same `_segmentAt(..., resolveSentence)` path; the sentence's spoken range comes from `stepRanges`/speech resolution which already excludes comment characters. Learn never calls comment-reading paths.
- **Rationale**: comments are not sentences in the segmenter model; reusing resolution guarantees Learn reads exactly what a tap-read would, minus comments by construction.
- **Alternatives considered**: separate learn-specific segmenter (duplication, divergence risk).

## R8 — Language for recognition

- **Decision**: `localeId` for STT = the sentence's resolved read language (speech_resolver output: explicit override → detected). Map `zh`→`zh_CN`, `en`→`en_US`, `es`→`es_ES`; unsupported resolved languages → attempt marked unscored.
- **Rationale**: FR-008 — recognition must match what was read aloud.
- **Alternatives considered**: device default locale (mismatches read language); asking user per session (extra UI, spec silent).

## R9 — Session summary UI

- **Decision**: Stop in Learn mode ends the session and shows a modal bottom sheet / dialog listing each practiced sentence's best score, attempts, and unscored count; dismissing returns to normal controls.
- **Rationale**: FR-007; matches app's existing dialog patterns; no new route.
- **Alternatives considered**: persistent score badges only (chosen as complement — per-attempt score near sentence AND summary on Stop).

## Known limitations (accepted)

- Android on-device STT requires Google speech service + downloaded language packs; degradation = unscored attempts.
- Cantonese (if ever a read language) unsupported by STT → unscored.
- Scoring compares words/characters, not phonemes — mispronounced-but-correct words score high (documented MVP boundary).
- Speaker echo into mic during the learner's window is possible on loud devices; mitigated by post-TTS gating, verified on device walk.
- iOS/macOS on-device recognition requires the locale's offline model; same unscored fallback.
- `speech_to_text` Android 10 `stop()` quirk handled by plugin via `destroy` — acceptable.
- Learn sessions are not persisted (spec assumption); results vanish on leaving Learn.
- Backgrounding mid-cycle pauses the session; resume restarts current cycle cleanly (edge case in spec).

## Version pins

- `speech_to_text: ^7.5.0` — stable 2026-09-14 (>60 days old at plan date).
- `permission_handler: ^13.0.2` — stable 2026-09-04 (>60 days old).
- No other new dependencies.
- Android: `RECORD_AUDIO` only (BLUETOOTH* skipped per YAGNI; wired headsets still work via platform default mic routing where supported).

## Test strategy

- `speech_scorer_test.dart`: normalization, en/es word diffs, zh char diffs, edge cases (empty transcript, perfect match, total mismatch).
- `learn_session_test.dart`: cycle state machine 1→3, unscored attempts, sentence switching, stop/summary aggregation.
- `speech_recognizer_test.dart`: fake recognizer drives listen/stop/error paths (no platform channels).
- `reading_view_learn_test.dart`: widget tests with fake Reader + fake recognizer — toggle shows/hides controls, tap starts cycle, comments never spoken, stop shows summary.
- Device walk per quickstart.md on OnePlus 13.

## Open questions for tasks phase

- Exact placement of Learn toggle within the existing control Row (before ⏭? after Stop?) — decide in tasks with l10n labels.
- Whether per-attempt score renders inline on the sentence (colored badge) or in the control bar — decide in tasks; spec allows either ("on or beside").
- Summary sheet content layout — reuse existing dialog patterns.
- BCP-47 mapping table for supportedReadLanguages → localeId (en→en_US, zh→zh_CN or device, es→es_ES); Cantonese n/a.
- `listenFor`/`pauseFor` bounds per attempt (suggest listenFor ~15s, pauseFor ~3s — tune on device).
- Whether iOS permission strings are added now or deferred (Android is the verification target; adding both strings is cheap — recommend adding now).
- Session reset semantics: entering Learn fresh starts an empty session each time (recommended — sessions are ephemeral per spec).
- `_hint`/`_error` reuse for learn status text vs dedicated learn status line — decide in tasks to avoid disturbing existing hint behavior.

## Phase 1 artifacts

- data-model.md — PracticeAttempt / SentenceResult / LearnSession entities + state machine.
- quickstart.md — device + automated validation scenarios.
- contracts/ — skipped (internal app, no external interface; see plan.md Structure Decision).

## Constitution compliance (post-design)

- I: single Flutter codebase; STT plugin covers Android+iOS; seam in lib/learn.
- II: spec→plan→tasks order maintained.
- III: pure-Dart scorer + session machine + fakeable recognizer seam enable test-first.
- IV: on-device only; no network declared; RECORD_AUDIO permission is the only new platform ask.
- V: reuses ReadingView gestures, ReaderService TTS, 034 language resolution; no new screens.

PASS — no violations.

## Status

Plan complete. Ready for /speckit-tasks.

---

## Amendment (2026-11-18): STT dropped — voice detection + audio kept

Device testing on OnePlus 13 (ColorOS) and OnePlus 9 showed platform
speech recognition unusable in practice: `error_language_unavailable` /
`error_language_not_supported` / `error_client` across locales, missing
on-device packs, and no user-manageable fix inside the app. Live Caption
packs proved to be a different model and did not help.

**New approach**: record each repeat to a local audio file and detect
voice activity from the amplitude stream (energy VAD — language-agnostic,
no packs, no network). Kept audio is playable per attempt and from the
session summary; recordings are ephemeral per session.

- `speech_to_text` removed; `record ^7.1.2` (capture + amplitude) and
  `audioplayers ^6.8.1` (playback) added. `permission_handler` stays.
- `lib/learn/speech_recognizer.dart` → `lib/learn/voice_capture.dart`
  (`VoiceCapture` seam + `RecorderVoiceCapture` on `record`).
- `lib/learn/speech_scorer.dart` → `lib/learn/voice_activity.dart`
  (pure-Dart amplitude → voiced/not-voiced analysis).
- Session model: attempts carry `voiceDetected`, `duration`, `audioPath`,
  failure reason — transcript/accuracy/missed/extra removed.
- Same cycle contract: TTS → mic → ×3 → wait; echo gate unchanged.

## Amendment 2 (2026-11-18): single attempt per tap

The three-cycle repeat proved unstable on device. Simplified: each
sentence tap runs ONE read → record → voice-check cycle, then waits.
Re-taps append attempts; all recordings kept until Stop ends the session
and deletes them. `LearnSession` lost `cycleIndex`/`_runStart`;
`LearnController.practice` runs a single cycle.


---

## Amendment — final architecture (2026-11-18, device-verified)

The R1–R9 decisions below describe the abandoned STT design. What actually shipped:

- **No speech recognition at all.** Platform STT failed on real devices (ColorOS missing/broken language packs, `error_client`, `error_language_unavailable` even after pack downloads). Replaced by `record` plugin (`RecorderVoiceCapture`, AAC-LC `.m4a`, 16 kHz mono, echoCancel+noiseSuppress, `onAmplitudeChanged` @200 ms) + `audioplayers` for playback.
- **Voice detection is pure Dart** (`voice_activity.dart`): energy threshold ≈ -45 dB, min voiced ≈ 250 ms, window closes ~2 s after trailing silence or 20 s cap.
- **One read+record per tap** (3-cycle repeat dropped after instability). Taps during an in-flight cycle are ignored — no highlight, no abandoned attempts.
- **Mic opens paused before TTS** (`MediaRecorder.pause/resume`): nothing is written during the read, resume is instant → no clipped first syllables, no TTS in the file. Trade-off: mic indicator stays lit during reads.
- **Lifecycle hardening from device logs**: fresh `RecorderVoiceCapture` per Learn entry (disposed-recorder reuse caused "Recording failed"); recordings deleted on summary dismissal, not before (fixed ENOENT playback); `stop()` force-closes the window and awaits the in-flight attempt ≤5 s (last sentence keeps its recording); permission/encoder probes + recorder + output path all pre-warmed during TTS.
- **Result**: per-attempt voice/noVoice/failed + playable `.m4a`; Stop summary with counts and ▶ per recording; recordings deleted on dismiss/exit.
