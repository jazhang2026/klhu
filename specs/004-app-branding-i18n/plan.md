# Implementation Plan: App Branding and Internationalization

**Branch**: `004-app-branding-i18n` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-app-branding-i18n/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Implement app branding with localized titles ("KalaHoo" in English, "卡啦虎" in Chinese) and custom app icon (images/kalahu.jpeg), plus full internationalization support allowing users to switch between English and Chinese interface languages with persistence. This enhances app professional presentation and accessibility for bilingual users.

## Technical Context

**Language/Version**: Flutter stable (current 3.47.4), Dart

**Primary Dependencies**: flutter_localizations, intl packages (Flutter i18n), shared_preferences (already in use from spec 002)

**Storage**: shared_preferences for language preference persistence

**Testing**: flutter test (widget tests for language switching, integration tests for branding verification)

**Target Platform**: iOS 16+, Android 10+ (API 29+) - single Flutter codebase

**Project Type**: mobile-app

**Performance Goals**: Language switching completes within 1 second, UI updates responsive

**Constraints**: Offline-capable, no backend, single codebase for iOS/Android, accessibility compliant (VoiceOver/TalkBack)

**Scale/Scope**: ~10 UI elements requiring translation, 2 languages supported, app icon and title localization

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **Flutter Single Codebase**: Plan uses Flutter's single codebase approach with platform-specific configuration only for app icon/title
- ✅ **Spec-Driven**: Implementation follows approved spec 004 with plan, tasks, and test-first approach
- ✅ **Test-First**: All user stories will have independent acceptance tests on simulator/emulator before implementation
- ✅ **On-Device First**: All functionality runs on-device with no backend, analytics, or network requirements
- ✅ **Simplicity**: Feature adds essential branding and i18n without introducing unnecessary complexity

## Project Structure

### Documentation (this feature)

```text
specs/004-app-branding-i18n/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (not needed for this feature)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── l10n/                 # New: Internationalization files
│   ├── app_en.arb        # English translations
│   └── app_zh.arb        # Chinese translations
├── models/
│   └── language_preference.dart  # New: Language preference model
├── services/
│   └── localization_service.dart  # New: Localization management
└── reading_view.dart     # Modified: Add language dropdown integration

images/
└── kalahu.jpeg           # New: Custom app icon (user-provided)

android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml  # Modified: App title and icon

ios/
└── Runner/
    ├── Info.plist       # Modified: App title and icon
    └── Assets.xcassets/
        └── AppIcon.appiconset/  # Modified: Custom icon

test/
├── l10n_test.dart        # New: Translation tests
├── language_preference_test.dart  # New: Preference persistence tests
└── reading_view_test.dart  # Modified: Add language dropdown tests
```

**Structure Decision**: Single Flutter project structure following existing klhu architecture, adding i18n support under `lib/l10n/` and new localization service, with platform-specific configuration for app icon/title in android/ and ios/ directories.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations detected. Feature complexity is justified as essential branding and accessibility enhancement for bilingual users.