# klhu Constitution

## Core Principles

### I. Flutter Single Codebase
One Flutter/Dart codebase ships to iPhone and Android. No platform-specific forks unless a capability (e.g. TTS voice) is unavailable in the shared plugin. Platform code isolated under `lib/platform/`.

### II. Spec-Driven (NON-NEGOTIABLE)
No implementation without an approved spec + plan + tasks under `specs/`. Constitution supersedes ad-hoc requests; amendments need version bump + date.

### III. Test-First (NON-NEGOTIABLE)
TDD: widget/unit tests written → user approved → tests fail → then implement. Every user story has an independent acceptance test (simulator/emulator run).

### IV. On-Device First
Text content and TTS run on-device by default. No account, no backend, no analytics in v1. Network use (if any) must be declared in spec.

### V. Simplicity
YAGNI. v1 = select text at 3 granularities + read aloud + stop/pause. No library, no cloud sync, no OCR unless a later spec adds it.

## Constraints
- Flutter stable, Dart. TTS via `flutter_tts` (or equivalent declared in plan).
- iOS 16+, Android 10+ (API 29+) baseline; confirm in plan.
- Accessibility: works with VoiceOver/TalkBack running; minimum touch target 44pt.

## Development Workflow
specify → clarify → plan → tasks → implement → simulator/emulator verify → user review. Each story independently demonstrable.

## Governance
All reviews verify constitution compliance. Complexity must be justified in plan.

**Version**: 1.0.0 | **Ratified**: 2026-09-14 | **Last Amended**: 2026-09-14
