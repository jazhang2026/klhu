# Implementation Plan: Read-Along Language Learning

**Branch**: `035-read-along` | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/035-read-along/spec.md`

## Summary

Add a Learn mode to the reading page: a mode toggle beside the existing controls swaps the page into Learn controls; tapping a sentence runs a three-cycle loop — KalaHoo reads the sentence (existing TTS path, `awaitSpeakCompletion` gives the completion gate), then the on-device microphone captures the learner's repeat; each transcript is diffed against the sentence text in pure Dart for an accuracy score (%, transcript, missed/extra words). Comments are never read. Stop ends the session and shows a per-sentence summary. No cloud, no AI, no changes to existing read functions.

## Technical Context

**Language/Version**: Dart / Flutter 3.47.5 stable (existing)

**Primary Dependencies**: existing `flutter_tts`, `wakelock_plus`; NEW `speech_to_text: ^7.5.0` (on-device STT seam) and `permission_handler: ^13.0.2` (mic runtime permission). Both published >2 months ago.

**Storage**: none — Learn sessions are in-memory only per spec assumption; no persistence added.

**Testing**: `flutter test` widget/unit tests (existing harness); STT behind a Dart seam so tests inject fakes; `flutter analyze --no-pub`.

**Target Platform**: Android 10+ primary (OnePlus devices); iOS 16+ via same plugin where on-device recognition is available.

**Project Type**: mobile-app (single Flutter codebase)

**Performance Goals**: score within 3s of learner finishing (SC-003) — bounded by recognizer endpointing + diff cost (trivial).

**Constraints**: 100% on-device (SC-002); mic capture must never overlap TTS output; existing functions regression-free (SC-004/SC-005); Android `RECORD_AUDIO` runtime permission requested lazily on first repeat attempt.

**Scale/Scope**: one new mode on one existing screen; ~3 new lib files + ReadingView integration + l10n ×4.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Flutter single codebase**: PASS — `speech_to_text` covers Android/iOS/macOS; platform code isolated in `lib/learn/` seam.
- **II. Spec-driven**: PASS — spec.md approved with all clarifications resolved.
- **III. Test-first**: PASS — plan includes fakeable seams (`SpeechRecognizer`, pure-Dart scorer, `LearnSession` state machine) so tests precede implementation.
- **IV. On-device first**: PASS — `onDevice: true` STT, pure-Dart diff, no network declared or used; no account/backend/analytics.
- **V. Simplicity**: PASS — reuses `ReadingView` sentence model, `_Mode` state, `ReaderService` TTS queue, 034 language resolution; no new screens beyond an in-page summary.

No violations → Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/035-read-along/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks output — NOT created here
```

### Source Code (repository root)

```text
lib/
├── learn/
│   ├── learn_session.dart      # session state machine + per-sentence results (pure Dart)
│   ├── speech_scorer.dart      # transcript vs target diff → score (pure Dart)
│   ├── speech_recognizer.dart  # seam: interface + platform impl (speech_to_text)
│   └── learn_controller.dart   # orchestrates TTS→mic→score cycle for ReadingView
├── reading_view.dart           # mode toggle, learn tap path, summary UI (additive)
├── l10n/app_*.arb              # new strings ×4 locales
└── ... (existing files untouched except android manifest + pubspec)

android/app/src/main/AndroidManifest.xml   # + RECORD_AUDIO

test/
├── learn_session_test.dart
├── speech_scorer_test.dart
├── speech_recognizer_test.dart            # fake-driven
└── reading_view_learn_test.dart           # widget tests
```

**Structure Decision**: single Flutter project (Option 1). Learn logic lives in `lib/learn/` as pure-Dart/testable units; `ReadingView` only wires gestures and UI. `contracts/` skipped — no external interface (internal app, per template rule).

## Phase 0 / Phase 1 outputs

Generated: [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md).

## Complexity Tracking

No constitution violations — section intentionally empty.

## Post-Design Constitution Re-check

- On-device STT via plugin default + `onDevice: true` flag; where the platform cannot honor it, attempts degrade to unscored (spec edge case) — still no network dependency added by us.
- `permission_handler` adds a permission prompt only; no data leaves device.
- All Learn state is session-scoped memory; nothing persisted (spec assumption).
- PASS — no new violations.

## Risks

- Android on-device STT requires a downloaded language pack on some devices; unscored-attempt degradation covers it (research.md R3).
- `speech_to_text` Android `onDevice` is "prefer" not guaranteed (research.md R2) — mitigated by locale-matched `localeId` and unscored fallback; true on-device enforcement exists on iOS via `requiresOnDeviceRecognition`.
- Echo: mic opens strictly after `awaitSpeakCompletion` resolves; speaker bleed during the gap is a device-walk check (quickstart.md).
- Cantonese unsupported by recognizer → unscored attempts; documented limitation.
- `ReadingView` is ~4900 lines; keep Learn wiring minimal — logic in `lib/learn/`.
- Widget tests: `speech_to_text`/`permission_handler` platform channels → all access behind seams; tests never touch real plugins.

## Next Steps

`/speckit-tasks` → test-first implementation per constitution III.

---

## Amendment (2026-11-18): STT dropped — voice detection + kept audio

Device testing showed platform speech recognition unusable across phones
(missing packs, `error_client`, no in-app fix). The feature now records
each repeat locally and detects voice via amplitude VAD; audio is kept
per attempt for playback. `speech_to_text`/`speech_scorer` removed;
`record` + `audioplayers` added. See research.md amendment and the
rewritten tasks.md for the current task list.
