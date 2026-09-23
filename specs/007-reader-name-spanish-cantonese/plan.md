# Implementation Plan: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Branch**: `007-reader-name-spanish-cantonese` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-reader-name-spanish-cantonese/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

> **Grounding corrections (2026-09-22, emulator-5554):** the engine has no `es-MX`
> voice (speech uses `es-US`; `es-MX` stays the UI locale) and it *does* ship 7
> `yue-HK` voices that the app's `startsWith('zh')` filter currently discards. See
> `research.md` § Grounding corrections and `tasks.md` § Grounding corrections before
> following the tree below.

## Summary

This feature enhances the app with three major improvements: updating app titles to "KalaHoo Reading" (English), "KalaHoo Lectura" (Spanish), and "卡啦虎朗读" (Chinese); adding Latin American Spanish (es-MX) language support with i18n translations and TTS aligned with US high school curriculum; and adding Cantonese (广东话) as a dialect option under Chinese voice selection. The app focuses on language learning use cases with proper pronunciation and dialect support.

## Technical Context

**Language/Version**: Flutter stable, Dart 3.13.4+

**Primary Dependencies**: flutter_tts (existing, for TTS), shared_preferences (existing, for persistence), flutter_localizations (existing, for i18n)

**Storage**: shared_preferences for language preference and dialect selections

**Testing**: Flutter widget tests and unit tests

**Target Platform**: iOS 16+, Android 10+ (API 29+)

**Project Type**: Mobile app (Flutter single codebase)

**Performance Goals**: Language switching completes within 500ms, TTS voice selection completes within 300ms

**Constraints**: On-device first (no backend), accessibility (VoiceOver/TalkBack), minimum 44pt touch targets

**Scale/Scope**: Extends existing English/Chinese support to Latin American Spanish (es-MX) and adds Cantonese dialect under Chinese

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **Flutter Single Codebase**: Feature uses Flutter widgets and services that work on both iOS and Android
- ✅ **Spec-Driven**: Spec approved and plan being generated before implementation
- ✅ **Test-First**: TDD approach will be followed with tests written before implementation
- ✅ **On-Device First**: Spanish language support and Cantonese dialect are local features, no backend required
- ✅ **Simplicity**: Feature extends existing localization infrastructure without adding unnecessary complexity
- ✅ **Constraints**: iOS 16+, Android 10+ baseline maintained, accessibility support included

**Post-Design Re-check**: ✅ PASS - No constitution violations introduced during design phase. Dialect structure under language selection maintains simplicity. Spanish support follows existing patterns.

## Project Structure

### Documentation (this feature)

```text
specs/007-reader-name-spanish-cantonese/
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
│   └── dialect_config.dart         # Dialect configuration model (Cantonese under Chinese)
├── services/
│   └── localization_service.dart    # Modified: add Spanish support
├── voice_picker_screen.dart        # Modified: add dialect options under Chinese
├── reading_view.dart              # Modified: handle new app titles
└── main.dart                      # Modified: updated app titles

lib/l10n/
├── app_en.arb                     # Modified: update app title to "KalaHoo Reading"
├── app_zh.arb                     # Modified: app title remains "卡啦虎朗读"
└── app_es_mx.arb                  # New: Latin American Spanish translations including "KalaHoo Lectura"

android/app/src/main/res/
├── values/strings.xml            # Modified: English app title "KalaHoo Reading"
├── values-zh/strings.xml          # Modified: Chinese app title "卡啦虎朗读"
└── values-es-rMX/strings.xml      # New: Latin American Spanish app title "KalaHoo Lectura"

ios/Runner/
├── Info.plist                     # Modified: base app title
└── es-MX.lproj/InfoPlist.strings  # New: Latin American Spanish app title "KalaHoo Lectura"

test/
├── spanish_localization_test.dart # Latin American Spanish language support tests
└── cantonese_dialect_test.dart    # Cantonese dialect tests
```

**Structure Decision**: Mobile app structure with existing lib/ and test/ directories. Localization infrastructure extended with Spanish ARB files and dialect configuration. Platform-specific app titles updated for Android and iOS.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
