# Implementation Plan: Read Language

**Branch**: `034-read-language` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/034-read-language/spec.md`

## Summary

Give every content a persisted read-language setting — a main-text default
(`auto` or en/zh-Hans/es) plus per-role overrides for dialogue — shown and
editable in the existing Text type dialog. Detection (`lib/language.dart`)
stays the "auto" answer; a single resolution seam
(`resolveReadLanguage`) applies override → detection at every point
`detectLanguage` runs for main text and role turns. Comments keep their own
per-comment detection, unchanged.

## Technical Context

**Language/Version**: Dart / Flutter stable

**Primary Dependencies**: none new — existing models, stores, l10n

**Storage**: content index record (`ContentStore` / `index.json`) gains two
optional fields; role overrides are a name→language map on the same record

**Testing**: `flutter_test` — unit tests for resolution + store round-trip,
widget tests for the Text type dialog and read-language evidence
(`RecordingReader`/`FakeReader` already capture per-speech language)

**Target Platform**: Android/iOS — pure Dart, no platform code

**Project Type**: mobile-app

**Performance Goals**: N/A — resolution is O(1) map lookup per unit

**Constraints**: no migration — absent fields mean "auto" (FR-007);
presets keep detection only (spec Assumptions)

**Scale/Scope**: ~6 files touched + l10n ×4 + tests

## Constitution Check

- I. Single codebase: PASS — pure Dart.
- II. Spec-driven: PASS.
- III. Test-first: PASS — resolution + dialog tests precede wiring.
- IV. On-device first: PASS — no network, no new deps.
- V. Simplicity: PASS — reuses Text type dialog, index record, existing
  detection; no new screens.

## Project Structure

### Documentation

```text
specs/034-read-language/
├── plan.md  research.md  data-model.md  quickstart.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks output
```

### Source Code

```text
lib/
├── models/content.dart          # readLang + roleLangs fields on SavedContent
├── services/content_store.dart  # index record read/write of the new fields
├── read_language.dart           # NEW: resolveReadLanguage seam + supported list
├── language.dart                # detectLanguage stays; resolveParagraphSpeeches
│                                #   gains an optional resolver param (default = detect)
├── speech_resolver.dart         # role turns resolve via seam
├── reading_view.dart            # Text type dialog: language rows + per-role picker;
│                                #   passes settings into resolution
└── l10n/app_*.arb + generated   # ~6 new keys × 4 locales

test/
├── read_language_test.dart      # NEW: resolution unit tests
├── content_store_language_test.dart (or extend existing store test)
└── reading_view_language_test.dart (or extend dialogue/text-type tests)
```

## Design notes

- **Storage shape**: `SavedContent` gains `readLang` (`'auto'`|lang, default
  `'auto'`) and `roleLangs` (`Map<String,String>`, default const {}). Both
  optional in `index.json`; `fromJson` tolerates absence → auto. Presets:
  `PresetContent` untouched — the page only offers overrides for saved
  contents (`isPreset == false`); dialog hides the language section for
  presets (spec Assumptions).
- **Resolution seam** (`lib/read_language.dart`):
  `resolveReadLanguage({required String detected, String main = 'auto',
  String? role, Map<String,String> roleLangs = const {}})` →
  role override → main override → detected. `supportedReadLanguages =
  ['en','zh-Hans','es']` shared by UI + validation.
- **Call sites**: `resolveParagraphSpeeches` gets an optional
  `languageFor` callback (default `detectLanguage`) so existing callers are
  unchanged; `ReadingView` passes a closure capturing the content's
  settings. Role turns in `speech_resolver.dart` resolve through the same
  seam — the role's *name* keys the override.
- **"Auto" display**: dialog shows the *effective* language — run
  `detectLanguage` on the content's main text (first paragraph is
  representative and cheap) for the auto row's subtitle; per-role auto
  shows `detectLanguage(role.turns.first.text)` as today.
- **Next-read semantics**: settings live in state + index; resolution runs
  per read — nothing to invalidate (FR-005 free).
- **Comments**: untouched — `comment.dart` keeps its own detection.

## Complexity Tracking

No constitution violations; no entries required.
