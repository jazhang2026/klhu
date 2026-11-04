# Quickstart: how 030 is walked

**Feature**: `030-ai-skills-for-content-generation` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

Rows for the plan's phases, in the order they run. Every row names the **one** thing it proves, the command that runs it, and the numbers it is expected to land on.

## Unit rows

### 1. The skill data model — [unit]

Test: `flutter test test/ai_skill_test.dart` (the `AISkill` model and `AISkillStore`).
Steps: `AISkill.fromJson` round-trips; `copyWith` creates a new instance; equality is by `(id, name)`. `AISkillStore.load()` returns the 3 built-ins on a fresh store; `upsert()` adds a custom skill; `delete()` removes a custom skill and returns `false` for built-in IDs.
Expected: 11 tests, all pass.
Proves FR-001, FR-002, FR-005, FR-006, FR-007.

**State 2026-11-04**: **PASS** — 11/11 tests pass. Quickstart row 1 **PASS**.

### 2. The post-processor — [unit]

Test: `flutter test test/ai_post_processor_test.dart`.
Steps: `postProcessAiText()` strips header filler lines ("Sure!", "Here's your story…"), strips footer filler lines ("Let me know!", "Hope this helps"), strips both, passes through text with no filler, handles empty/single-line input, preserves `{role}` and `[comment]` tags in content.
Expected: 10 tests, all pass.
Proves FR-004.

**State 2026-11-04**: **PASS** — 10/10 tests pass. Quickstart row 2 **PASS**.

### 3. i18n key coverage — [unit]

Test: `flutter test test/l10n_keys_test.dart`.
Steps: every key in `app_en.arb` exists in `app_zh.arb`, `app_zh_Hans.arb`, and `app_es.arb`; no key exists in a translation file that is absent from the template.
Expected: 3 tests, all pass.
Proves FR-009.

**State 2026-11-04**: **PASS** — 3/3 tests pass. Quickstart row 3 **PASS**.

### 4. Provider config widget with i18n — [widget]

Test: `flutter test test/ai_settings_test.dart`.
Steps: `AIProviderConfigScreen` renders with `AppLocalizations` delegates; four presets visible on load; Add Provider dialog opens and closes; Edit dialog shows API key field; user-added provider persists; selected provider is highlighted.
Expected: 5 tests, all pass.
Proves FR-009 (provider screen i18n).

**State 2026-11-04**: **PASS** — 5/5 tests pass. Quickstart row 4 **PASS**.
