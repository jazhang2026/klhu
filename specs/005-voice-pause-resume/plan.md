# Implementation Plan: Voice List Improvements and Pause/Resume Functionality

**Branch**: `005-voice-pause-resume` | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-voice-pause-resume/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

This feature improves the voice picker user experience by displaying user-friendly voice names with characteristics (gender, age, dialect) in both English and Chinese, adds pause/resume functionality for page reading, and converts all primary action buttons from text to icons for better space efficiency and modern UI design. The voice mapping uses a static table approach as recommended, and pause/resume allows users to temporarily stop reading and continue from the paused position, with any other action while paused stopping the reading completely. Icon buttons include accessibility features (tooltips, semantic labels) and maintain 44pt touch targets.

## Technical Context

**Language/Version**: Flutter stable, Dart 3.13.3+

**Primary Dependencies**: flutter_tts (existing, for TTS pause/resume), shared_preferences (existing, for persistence), flutter_localizations (existing, for i18n)

**Storage**: shared_preferences for voice mapping persistence (if user chooses to prefer specific voices)

**Testing**: Flutter widget tests and unit tests

**Target Platform**: iOS 16+, Android 10+ (API 29+)

**Project Type**: Mobile app (Flutter single codebase)

**Performance Goals**: Reading stops completely within 500ms when non-Resume action taken while paused, 100% resume position accuracy

**Constraints**: On-device first (no backend), accessibility (VoiceOver/TalkBack), minimum 44pt touch targets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **Flutter Single Codebase**: Feature uses Flutter widgets and services that work on both iOS and Android
- ✅ **Spec-Driven**: Spec approved and plan being generated before implementation
- ✅ **Test-First**: TDD approach will be followed with tests written before implementation
- ✅ **On-Device First**: Voice mapping and pause/resume are local features, no backend required
- ✅ **Simplicity**: Feature focuses on voice display improvements and pause/resume, aligning with reading app purpose
- ✅ **Constraints**: iOS 16+, Android 10+ baseline maintained, accessibility support included

**Status**: PASS - No constitution violations

## Project Structure

### Documentation (this feature)

```text
specs/005-voice-pause-resume/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── models/
│   └── voice_mapping.dart         # Static voice mapping table
├── services/
│   └── voice_mapping_service.dart # Voice mapping lookup service
├── voice_picker_screen.dart       # Modified: display user-friendly names
└── reading_view.dart             # Modified: add pause/resume functionality and icon buttons

test/
├── voice_mapping_test.dart       # Voice mapping lookup tests
└── reading_view_pause_test.dart  # Pause/resume and icon button widget tests

lib/l10n/
├── app_en.arb                    # Modified: add voice characteristics translations
└── app_zh.arb                    # Modified: add voice characteristics translations
```

**Structure Decision**: Mobile app structure with existing lib/ and test/ directories. Voice mapping service and model added to support static mapping. Reading view modified for pause/resume state management.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
