# Implementation Plan: AI Skills for Content Generation

**Branch**: `030-ai-skills-for-content-generation` | **Date**: 2026-11-03 | **Spec**: [specs/030-ai-skills-for-content-generation/spec.md](specs/030-ai-skills-for-content-generation/spec.md)

## Summary

Add AI skills — pre-built prompt templates — to the AI prompt dialog so the reader can turn a simple request into properly formatted KalaHoo Reading content. Three shipped skills (Story, Dialogue, Lesson) plus the ability for the reader to save custom skills. An output post-processor strips conversational header/footer from AI text responses.

## Technical Context

**Language/Version**: Dart 3.13.4 (Flutter 3.47.5); single Flutter/Dart codebase.

**Dependencies**: none new — `shared_preferences` (already in), `http` (already in via spec 029).

**Storage**: SharedPreferences under key `klhu_ai_skills`; the three built-in templates are hardcoded in source.

**Target Platform**: iOS 16+, Android 10+ (API 29+).

## Tasks

### Phase 1: Data model and persistence

- [ ] T001 [P] `lib/ai/skill.dart`: the `AISkill` class — `id`, `name`, `description`, `template`, `defaultType`, `isBuiltIn`.
- [ ] T002 [P] `lib/ai/skill_store.dart`: the SharedPreferences persistence layer — load all skills (seeded built-ins + custom), save, update, delete. Seed the three built-ins on first launch.
- [ ] T003 `lib/ai/post_processor.dart`: the output post-processor — strip conversational header/footer from raw AI text; returns cleaned text or the original if no split is found.

### Phase 2: Dialog integration

- [ ] T004 [P] `lib/reading_view.dart` (`_AIPromptDialog`): add the skill picker row above the prompt text field; show built-in + custom skills as chips; tapping a skill renders its template into the prompt field.
- [ ] T005 [P] `lib/reading_view.dart` (`_openAIPromptDialog`): integrate the post-processor — after `client.generate()` returns text, run `postProcess()` before applying the result to `_content`.
- [ ] T006 `lib/reading_view.dart` (`_AIPromptDialog`): add "Save as skill" action — long-press or a dedicated button that opens a small input dialog to name the skill, then calls `skillStore.save()`.

### Phase 3: Built-in skill templates

- [ ] T007 `lib/ai/skill_store.dart`: define the three built-in templates:
  - **Story**: "Write a short story about {{topic}}. Use descriptive language suitable for reading aloud."
  - **Dialogue**: "Write a dialogue between {{characters}} about {{topic}}. Format each speaker's line as `{speaker name}：content`. Do not include any narrative introduction or conclusion."
  - **Lesson**: "Create a bilingual lesson about {{topic}}. Write each sentence in the target language, followed by a [comment]English translation[/comment] tag on the same line. Use Spanish as the target language."
- [ ] T008 `test/ai_skill_test.dart`: unit tests for `AISkill` equality, `SkillStore` seed/load/save/delete, post-processor stripping behavior.

### Phase 4: Testing & closing

- [ ] T009 Widget test: `_AIPromptDialog` renders skill picker; tapping a skill fills the prompt; "Save as skill" persists a custom skill.
- [ ] T010 `specs/030-ai-skills-for-content-generation/breakpoint.md`: structural row — counts, ARB keys, artifact checkers.
- [ ] T011 `specs/030-ai-skills-for-content-generation/quickstart.md`: closing pass.

## Dependencies & ordering

T001, T002, T003 → T004, T005, T006 (dialog integration depends on model + store + processor) → T007, T008 (templates + tests) → T009, T010, T011 (closing).

## Parallel opportunities

- T001 with T002: the data class and the store are different files.
- T001 with T003: the model and the post-processor are independent.
- T004 with T005: dialog UI and the post-process integration point are different code locations.
- T007 with T008: template definitions and their tests are different files.
