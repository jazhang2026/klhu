# Implementation Plan: Voice Picker with Preview

**Branch**: `002-voice-picker` | **Date**: 2026-09-15 | **Spec**: `spec.md` (approved 2026-09-14)

**Input**: Feature specification from `/specs/002-voice-picker/spec.md` (per-paragraph mixed-language voices, picker list/preview/persist per language)

## Summary

Extend 001's read-aloud with two pieces. (1) A pure-Dart per-paragraph language
resolver (CJK presence → zh-Hans, else en; rule table for future languages) so
mixed EN/zh-Hans page reads speak each paragraph with its language's
picked voice, in order, one audio stream (sentence taps use the enclosing
paragraph's language). (2) A voice picker screen (AppBar
action from reading view) listing installed voices per active language via
flutter_tts getVoices, tap-to-preview a fixed sample line, persisting one
choice per language in shared_preferences. `ReaderService` gains
getVoices/setVoice and sequential multi-paragraph speak with stop-first.

## Technical Context

**Language/Version**: Dart (Flutter stable, 3.x, as in 001)

**Primary Dependencies**: `flutter_tts` 4.2.3 (getVoices, setVoice, setLanguage,
speak, stop); new `shared_preferences` (persist one voice id per language)

**Storage**: shared_preferences keys `voice_en`, `voice_zh_Hans` (value: name +
locale pair); uninstall clears (platform default)

**Testing**: `flutter_test` (unit: language resolver, voice filtering/matching;
widget: picker list/preview/persist, mixed read order, fallbacks)

**Target Platform**: iOS 16+, Android 10+ (API 29+), single codebase; validation
on Android emulator (iPhone pending, no macOS — as in 001)

**Project Type**: mobile-app (Flutter, no API backend)

**Performance Goals**: preview starts <2s after tap; Stop halts <1s (incl.
multi-paragraph); getVoices list renders with explicit loading/empty/error states

**Constraints**: Offline-capable; on-device TTS only; 44pt touch targets;
one audio stream (preview stops reading first, latest preview wins)

**Scale/Scope**: +3 Dart files (~voice_store, language resolver, picker screen),
ReaderService extended, reading view +1 AppBar action

## Constitution Check

- Flutter single codebase: PASS (no platform channels; thin wrappers only)
- Spec-driven: PASS (spec approved 2026-09-14 before this plan)
- Test-first: PASS (resolver + store + widget tests per story before implement)
- On-device first: PASS (no backend/accounts/analytics)
- Simplicity: PASS (one choice per language; no per-text/session voices, no rate/pitch UI)

## Project Structure

### Documentation (this feature)

```text
specs/002-voice-picker/
├── spec.md              # approved 2026-09-14
├── plan.md              # this file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (NEXT STEP, needs your approval of this plan)
```

### Source Code (repository root)

```text
klhu/
├── lib/
│   ├── main.dart                 # unchanged wiring (picker route added)
│   ├── segmenter.dart            # 001, unchanged (paragraph ranges feed resolver)
│   ├── language.dart             # NEW: per-paragraph resolver (rule table: CJK → zh-Hans else en)
│   ├── voice_store.dart          # NEW: load/save per-language VoiceChoice (shared_preferences)
│   ├── reader_service.dart       # EXTEND: getVoices, setVoice, speakParagraphs() sequential, stop-first
│   ├── voice_picker_screen.dart  # NEW: list/preview/persist per active language
│   └── reading_view.dart         # EXTEND: AppBar voice action, mixed read via resolver + picked voices
└── test/
    ├── language_test.dart        # unit: CJK-wins, pure EN, empty, punctuation-only
    ├── voice_store_test.dart     # unit: persist/round-trip, missing-voice fallback match
    ├── reader_service_test.dart  # unit (fake tts): order, stop-first, fallback to default
    └── voice_picker_test.dart    # widget: list filter, tap→preview, persist, empty/error states
```

## Phases

- Phase 0: research (getVoices shape, setVoice matching, persist keys) → `research.md` (done, in this plan step)
- Phase 1: data model + quickstart (done, in this plan step)
- Phase 2: `tasks.md` (NEXT STEP, needs your approval of this plan)
- Phase 3: implement story 1 (mixed read) → story 2 (picker) → story 3 (per-language) with tests, verify on Android emulator EN + zh-Hans
