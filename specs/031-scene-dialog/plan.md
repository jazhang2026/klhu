# Implementation Plan: Scene dialog (031)

**Branch**: `031-scene-dialog` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

## Summary

Add a **scene dialog** content type and a **scene_dialog** skill. Each scene carries `[scene]` heading + dialog paragraphs + `[image_prompt]` line. Add a "Create pictures" button on the Video page that opens a sequential single-image generation dialog when `[image_prompt]` tags are present. Full i18n across EN/ZH/ES.

## Technical Context

**Language/Version**: Dart 3.13.4 (Flutter 3.47.5); single Flutter/Dart codebase.

**Dependencies**: none new — reuses `shared_preferences`, `http`, the existing AI provider infrastructure (`lib/ai/`), the existing `SceneTag` parser (`lib/scene_tag.dart`), and the existing picture assignment store (`lib/picture_assignment_store.dart`).

**Storage**: Generated images live in the app's cache during the session; only the currently active image is kept in memory at any time. Promoted images go through the existing picture assignment flow (`lib/picture_assignment.dart`). The previously generated image is disposed and its memory freed before loading the next prompt.

**Target Platform**: iOS 16+, Android 10+ (API 29+).

## Tasks

### Phase 1: Tag infrastructure

- [x] T001 [P] `lib/image_prompt_tag.dart`: the `[image_prompt]` tag parser — parallels `lib/scene_tag.dart`; recognises one spelling per locale (`image_prompt` / `图像提示` / `圖像提示` / `imagem` / `prompt_img`); elided from reading and video display; never spoken.
- [x] T002 [P] `lib/scene_tag.dart`: extend to expose both scene and image-prompt lines per scene (a scene's image prompt is the last `[image_prompt]` line before the next `[scene]` or EOF).

### Phase 2: Scene dialog skill

- [x] T003 [P] `lib/ai/skill_store.dart`: add the `scene_dialog` built-in skill with EN/ZH/ES templates and descriptions.
- [x] T004 `lib/reading_view.dart`: the scene_dialog skill appears in the prompt dialog's dropdown alongside Story/Dialogue/Lesson.

### Phase 3: Sequential image generation UI

- [x] T005 `lib/video_image_batch_dialog.dart`: the sequential image-generation dialog — shows one `[image_prompt]` entry at a time; after generation, **full-size image** with Save and Clear buttons; advancing requires saving or clearing to free memory (full-size image is disposed on both paths); AI provider + type (image-only) selector at top; "Done" strip of small saved thumbnails only.
- [x] T005b `lib/video_image_batch_dialog.dart`: **"Generate All"** button in dialog header; auto-runs all unsaved prompts sequentially using the same single-image memory discipline (full-size held per step, discarded after each); progress counter ("k / N done") displayed during run; on completion a summary snackbar reports success/failure counts; failed images appear as errored tiles in the "Done" strip with Retry/Delete; manual mode and Generate All are mutually exclusive (starting one cancels the other). **Runs as a detached background task** via Dart Isolate — closing the dialog or switching apps does not stop the run; re-opening the dialog restores state via SharedPreferences. Platform-appropriate notification on completion/success-failure count.
- [x] T006 `lib/reading_view.dart`: add "Create pictures" button to the Video page toolbar, shown only when `[image_prompt]` tags exist in the current content.
- [x] T007 `lib/picture_assignment.dart`: integration — saving a generated image from the sequential dialog promotes it into the picture assignment list.

### Phase 4: Testing & closing

- [x] T008 `test/ai_skill_test.dart`: add scene_dialog skill to the loaded skills list test.
- [x] T009 `test/image_prompt_tag_test.dart`: unit tests for the `[image_prompt]` parser (spelling recognition, elision, scope).
- [x] T010 `specs/031-scene-dialog/breakpoint.md`: structural row.
- [x] T011 `specs/031-scene-dialog/quickstart.md`: closing pass.

## Dependencies & ordering

T001, T002, T003 → T004, T005, T005b (UI depends on parser + skill) → T006, T007 (toolbar + integration) → T008, T009, T010, T011 (closing).

T005b can be developed in parallel with T009 once T005 is complete.

## Parallel opportunities

- T001 with T002: the parser extension and the new tag file are independent changes to related code.
- T003 with T008: skill definition and its test are different files.
- T005 with T009: dialog widget and tag parser tests are independent.
- T005b with T009: Generate All logic and tag parser tests are independent; both may run in parallel after T005 lands.
