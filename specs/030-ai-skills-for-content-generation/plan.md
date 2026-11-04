# Implementation Plan: AI Skills for Content Generation

**Branch**: `030-ai-skills-for-content-generation` | **Date**: 2026-11-03 | **Updated**: 2026-11-04
**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## Summary

Add AI skills — pre-built prompt templates — to the AI prompt dialog so the reader can turn a simple request into properly formatted KalaHoo Reading content. Three shipped skills (Story, Dialogue, Lesson), an output post-processor that strips conversational header/footer, and full i18n across all AI screens.

## Status

**CLOSED** — all planned tasks done; i18n added 2026-11-04. 1047 tests pass; `flutter analyze` clean (9 non-blocking issues).

## Technical Context

**Language/Version**: Dart 3.13.4 (Flutter 3.47.5); single Flutter/Dart codebase.

**Dependencies**: none new — `shared_preferences` (already in), `http` (already in via spec 029).

**Storage**: SharedPreferences under key `ai_skills`; the three built-in templates are hardcoded in `lib/ai/skill_store.dart`.

**i18n**: all AI strings live in the ARB files (`app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb`) and are accessed via `AppLocalizations.of(context)`.

## Implementation

### Phase 1: Data model and persistence

| Task | File | Status |
|---|---|---|
| T001 `AISkill` model | `lib/ai/skill.dart` | ✅ done |
| T002 `AISkillStore` persistence | `lib/ai/skill_store.dart` | ✅ done |
| T003 Post-processor | `lib/ai/post_processor.dart` | ✅ done |

### Phase 2: Dialog integration

| Task | File | Status |
|---|---|---|
| T004 Skill dropdown in `_AIPromptDialog` | `lib/reading_view.dart` | ✅ done |
| T005 Post-process AI text results | `lib/reading_view.dart` | ✅ done |
| T006 i18n for all AI screens | `lib/l10n/*.arb` + generated files | ✅ done |

### Phase 3: Built-in skill templates

| Task | File | Status |
|---|---|---|
| T007 Three built-in skills | `lib/ai/skill_store.dart` | ✅ done |
| T008 Unit tests | `test/ai_skill_test.dart`, `test/ai_post_processor_test.dart` | ✅ done |

### Phase 4: Testing & closing

| Task | File | Status |
|---|---|---|
| T009 Widget test updates | `test/ai_settings_test.dart` | ✅ done |
| T010 `breakpoint.md` | `specs/030-ai-skills-for-content-generation/breakpoint.md` | ✅ done |
| T011 `quickstart.md` | `specs/030-ai-skills-for-content-generation/quickstart.md` | ✅ done |

## Dependencies & ordering

T001, T002, T003 → T004, T005, T006 → T007, T008 → T009, T010, T011.

## What is not in scope (deferred)

- **"Save as skill" UI button** — the data model supports it (`AISkillStore.upsert`); the dialog entry point is not yet wired up (see spec FR-005 edge case).
- **Image/video skills** — the `defaultType` field exists on `AISkill`; the dropdown is hidden for non-text types per FR-008.
- **Skill editing** — only delete is exposed; editing requires deleting and re-adding.
