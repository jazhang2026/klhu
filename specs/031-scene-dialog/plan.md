# Implementation Plan: Scene dialog (031)

**Branch**: `031-scene-dialog` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

## Summary

Add a **scene dialog** content type and a **scene_dialog** skill. Each scene carries `[scene]` heading + dialog paragraphs + `[image_prompt]` line. Add a "Create pictures" button on the Video page that opens a batch image-generation dialog when `[image_prompt]` tags are present. Full i18n across EN/ZH/ES.

## Technical Context

**Language/Version**: Dart 3.13.4 (Flutter 3.47.5); single Flutter/Dart codebase.

**Dependencies**: none new — reuses `shared_preferences`, `http`, the existing AI provider infrastructure (`lib/ai/`), the existing `SceneTag` parser (`lib/scene_tag.dart`), and the existing picture assignment store (`lib/picture_assignment_store.dart`).

**Storage**: Generated images live in the app's cache during the batch session; promoted images go through the existing picture assignment flow (`lib/picture_assignment.dart`).

**Target Platform**: iOS 16+, Android 10+ (API 29+).

## Tasks

### Phase 1: Tag infrastructure

- [x] T001 [P] `lib/image_prompt_tag.dart`: the `[image_prompt]` tag parser — parallels `lib/scene_tag.dart`; recognises one spelling per locale (`image_prompt` / `图像提示` / `圖像提示` / `imagem` / `prompt_img`); elided from reading and video display; never spoken.
- [x] T002 [P] `lib/scene_tag.dart`: extend to expose both scene and image-prompt lines per scene (a scene's image prompt is the last `[image_prompt]` line before the next `[scene]` or EOF).

### Phase 2: Scene dialog skill

- [x] T003 [P] `lib/ai/skill_store.dart`: add the `scene_dialog` built-in skill with EN/ZH/ES templates and descriptions.
- [x] T004 `lib/reading_view.dart`: the scene_dialog skill appears in the prompt dialog's dropdown alongside Story/Dialogue/Lesson.

### Phase 3: Batch image generation UI

- [x] T005 `lib/video_image_batch_dialog.dart`: the batch image-generation dialog — lists all `[image_prompt]` entries, per-prompt generate/save/delete buttons, provider + type selector (image-only), recent prompts history.
- [x] T006 `lib/reading_view.dart`: add "Create pictures" button to the Video page toolbar, shown only when `[image_prompt]` tags exist in the current content.
- [x] T007 `lib/picture_assignment.dart`: integration — saving a generated image from the batch dialog promotes it into the picture assignment list.

### Phase 4: Testing & closing

- [x] T008 `test/ai_skill_test.dart`: add scene_dialog skill to the loaded skills list test.
- [x] T009 `test/image_prompt_tag_test.dart`: unit tests for the `[image_prompt]` parser (spelling recognition, elision, scope).
- [ ] T010 `specs/031-scene-dialog/breakpoint.md`: structural row.
- [ ] T011 `specs/031-scene-dialog/quickstart.md`: closing pass.

## Dependencies & ordering

T001, T002, T003 → T004, T005 (UI depends on parser + skill) → T006, T007 (toolbar + integration) → T008, T009, T010, T011 (closing).

## Parallel opportunities

- T001 with T002: the parser extension and the new tag file are independent changes to related code.
- T003 with T008: skill definition and its test are different files.
- T005 with T009: dialog widget and tag parser tests are independent.
