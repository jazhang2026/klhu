# Tasks: AI Skills for Content Generation

**Feature**: `030-ai-skills-for-content-generation` | **Date**: 2026-11-03
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (generate reading content from an AI prompt).

## Status

**CLOSED** — 11 of 11 tasks done (T001–T011). 1047 tests pass; `flutter analyze` clean (9 non-blocking issues).

## Phase 1: Data model and persistence

**Goal**: `lib/ai/skill.dart` holds the `AISkill` model (`id`, `name`, `description`, `template`, `defaultType`);
`lib/ai/skill_store.dart` persists user-added skills in SharedPreferences under key `ai_skills`; built-in skills
(Story, Dialogue, Lesson) are hardcoded in the store and protected from deletion.

- [x] T001 [P] `lib/ai/skill.dart`: the `AISkill` model — `id`, `name`, `description`, `template` (with `{{variable}}`
  placeholders), `defaultType`; built-in IDs are stable constants (spec FR-002, data-model).
- [x] T002 [P] `lib/ai/skill_store.dart`: the skill store — reads/writes user skills to SharedPreferences under
  `ai_skills`; exposes `builtInSkills` (Story/Dialogue/Lesson), `delete()` that returns false for built-ins (spec
  FR-005, FR-006, FR-007).
- [x] T003 `lib/ai/post_processor.dart`: the post-processor — strips 1–3 leading lines that look like conversational
  filler ("Sure!", "Here's your story…", "Let me know if you need anything!"); passes through the rest as-is if no
  clean split is found (spec FR-004, Q3).

## Phase 2: Dialog integration and i18n

**Goal**: the prompt dialog gains a skill dropdown below the provider dropdown (only when `AIPromptType.text`);
rendering a skill fills the prompt field with the templated text; all AI screen strings are localized (EN/ZH/ES).

- [x] T004 `lib/reading_view.dart`: the skill dropdown in `_AIPromptDialog` — shown only when type is `text` and at
  least one skill exists; tapping a skill renders its template into the prompt field replacing existing text (spec
  FR-001, FR-003, FR-008, Q2).
- [x] T005 `lib/reading_view.dart`: post-process the AI text result before it lands as content — run the
  post-processor on text responses; image/video responses bypass it (spec FR-004).
- [x] T006 `lib/l10n/*.arb` + generated files: localize all AI-screen strings — provider config, prompt dialog,
  skill names/descriptions, post-processor labels across English, Simplified Chinese, Traditional Chinese, and Spanish
  (spec FR-009, Q5).

## Phase 3: Built-in skill templates

**Goal**: the three shipped skills (Story, Dialogue, Lesson) have templates that produce KalaHoo-formatted output
with role tags, comment tags, scene tags, and head tags as appropriate.

- [x] T007 [P] `lib/ai/skill_store.dart`: add the three built-in skills — Story (narrative), Dialogue
  (multi-role `{role}` paragraphs), Lesson (bilingual with `[comment]` translations) — each with EN/ZH/ES templates
  and descriptions (spec FR-002, FR-003).
- [x] T008 `test/ai_skill_test.dart`, `test/ai_post_processor_test.dart`: unit tests for skill loading, templating,
  delete-protection, and the post-processor edge cases (no-filler pass-through, multi-line filler strip) (spec
  FR-004, FR-006, FR-007).

## Phase 4: Testing & closing

**Goal**: widget test coverage for the updated dialog, structural row, and closing pass.

- [x] T009 `test/ai_settings_test.dart`: widget test updates — the skill dropdown appears/disappears based on
  generation type; selecting a skill fills the prompt field (spec FR-001, FR-008).
- [x] T010 `specs/030-ai-skills-for-content-generation/breakpoint.md`: the structural row — the counts, the ARB keys,
  the artifact checkers.
- [x] T011 `specs/030-ai-skills-for-content-generation/quickstart.md`: the closing pass — the re-took counts, the
  receipts written.

## Dependencies & ordering

T001, T002, T003 → T004, T005, T006 → T007, T008 → T009, T010, T011.

## Parallel opportunities

- **T001 with T002**: the model class and the persistence layer are different files with no incomplete dependency.
- **T003 with T008**: the post-processor implementation and its unit tests are different files.
- **T007 with T008**: skill template definition and their tests are independent work streams.

## Implementation strategy

- MVP = Phase 1 (model + store + post-processor) + Phase 2 (dialog integration) — skills pickable and results post-processed.
- Phase 3 adds the three shipped templates and tests.
- Phase 4 closes the stage on its own numbers.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (skill dropdown shown when type=text and skills available) | T004, T009 |
| FR-002 (three built-in skills: Story, Dialogue, Lesson) | T002, T007 |
| FR-003 (tapping a skill renders its template into the prompt field) | T004 |
| FR-004 (post-processor strips conversational header/footer) | T003, T005, T008 |
| FR-005 (custom skills stored in SharedPreferences under `ai_skills`) | T002 |
| FR-006 (reader can delete custom skills via SkillStore.delete) | T002, T008 |
| FR-007 (built-in skills protected from deletion) | T002, T008 |
| FR-008 (skills hidden for image/video generation types) | T004, T009 |
| FR-009 (all AI screen strings localized) | T006 |
