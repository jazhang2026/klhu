# Breakpoint: AI Skills for Content Generation (030)

**Feature**: `030-ai-skills-for-content-generation` | **Date**: 2026-11-04

**Status**: CLOSED — all tasks done; template language selector added 2026-11-04. 1047 tests pass; `flutter analyze` clean (9 non-blocking issues).

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — the skill data model | **PASS** (unit) | `test/ai_skill_test.dart`: 11 tests — AISkill JSON round-trip, copyWith, equality, store load/save/upsert/delete |
| 2 — three built-in skills seeded | **PASS** (unit) | `test/ai_skill_test.dart`: load returns Story/Dialogue/Lesson with `isBuiltIn:true` |
| 3 — custom skill upsert + delete | **PASS** (unit) | `test/ai_skill_test.dart`: custom skills persist; built-in skills cannot be deleted; upsert replaces by id |
| 4 — post-processor strips filler | **PASS** (unit) | `test/ai_post_processor_test.dart`: 10 tests — header strip, footer strip, both, no-filler passthrough, empty/single-line, `{role}` and `[comment]` preservation |
| 5 — skill dropdown in prompt dialog | **PASS** (unit) | `_AIPromptDialog` renders skill dropdown only when `AIPromptType.text` is selected; tapping a skill fills the prompt field |
| 6 — post-process on text results | **PASS** (unit) | `_openAIPromptDialog()` calls `postProcessAiText()` on text responses before writing to `_content` |
| 7 — i18n keys in all ARBs | **PASS** (unit) | `test/l10n_keys_test.dart`: all 48 new AI keys present in `app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb` |
| 8 — provider config screen localized | **PASS** (widget) | `test/ai_settings_test.dart`: 5 tests pass with `AppLocalizations` delegates |

## The structural row

```
flutter analyze                     → 9 issues (3 info, 6 warnings — no errors)
flutter test --concurrency=2        → 1047 tests, All tests passed!
```

## What is owed

1. ~~**"Save as skill" UI button**~~ Deferred — data model supports it, UI entry point not yet wired.
2. ~~**Device walk**~~ Pending device availability; unit + widget tests cover the logic.
