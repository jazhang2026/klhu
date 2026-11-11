# Tasks: Scene Dialog

**Feature**: `031-scene-dialog` | **Date**: 2026-11-05
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (generate scene dialog content), `US2` (sequential image generation).

## Status

**CLOSED** — 11 of 11 tasks done (T001–T011). Tests pass; `flutter analyze` clean. Stage closed on unit-level
numbers; device walk pending live generation.

## Phase 1: Tag infrastructure

**Goal**: `[image_prompt]` line-level tag recognized alongside `[scene]`; `lib/scene_tag.dart` extended to expose
both scene headings and per-scene image prompts; both elided from reading and video display, never spoken.

- [x] T001 [P] `lib/image_prompt_tag.dart`: the `[image_prompt]` tag parser — parallels `lib/scene_tag.dart`;
  recognises four spellings per locale (`image_prompt` / `图像提示` / `圖像提示` / `imagem` / `prompt_img`);
  elided from reading and video display; never spoken (spec FR-001, Q1, Q2).
- [x] T002 [P] `lib/scene_tag.dart`: extend to expose both scene and image-prompt lines per scene — a scene's image
  prompt is the last `[image_prompt]` line before the next `[scene]` or EOF (spec FR-001, Q2).

## Phase 2: Scene dialog skill

**Goal**: the `scene_dialog` skill is added as a built-in in `AISkillStore`; it appears in the prompt dialog's
dropdown alongside Story/Dialogue/Lesson.

- [x] T003 [P] `lib/ai/skill_store.dart`: add the `scene_dialog` built-in skill with EN/ZH/ES templates and
  descriptions — template instructs AI to produce `[scene]` headings, `{role}：` dialog paragraphs, and
  `[image_prompt]` lines (spec FR-002, FR-003).
- [x] T004 `lib/reading_view.dart`: the scene_dialog skill appears in the prompt dialog's dropdown alongside the
  other built-in skills (spec FR-001).

## Phase 3: Sequential image generation UI

**Goal**: the Video page gains a "Create pictures" button (visible only when `[image_prompt]` tags exist); tapping
opens a sequential single-image generation dialog with Save/Clear memory discipline; a "Generate All" button runs
all remaining prompts automatically as a detached background task.

- [x] T005 `lib/video_image_batch_dialog.dart`: the sequential image-generation dialog — shows one `[image_prompt]`
  entry at a time; after generation, full-size image with Save and Clear buttons; advancing requires saving or
  clearing to free memory; AI provider + type (image-only) selector at top; "Done" strip of small saved thumbnails
  only (spec FR-005, FR-006, FR-007, FR-009, Q6).
- [x] T005b `lib/video_image_batch_dialog.dart`: **"Generate All"** button in dialog header — auto-runs all unsaved
  prompts sequentially using the same single-image memory discipline (full-size held per step, discarded after each);
  progress counter ("k / N done") displayed during run; on completion a summary snackbar reports success/failure
  counts; failed images appear as errored tiles in the "Done" strip with Retry/Delete; manual mode and Generate All
  are mutually exclusive (starting one cancels the other). Runs as a detached background task via Dart Isolate —
  closing the dialog or switching apps does not stop the run; re-opening the dialog restores state via SharedPreferences.
  Platform-appropriate notification on completion (spec FR-011, FR-012, Q9).
- [x] T006 `lib/reading_view.dart`: add "Create pictures" button to the Video page toolbar, shown only when
  `[image_prompt]` tags exist in the current content (spec FR-004, FR-010, Q5).
- [x] T007 `lib/picture_assignment.dart`: integration — saving a generated image from the sequential dialog promotes
  it into the picture assignment list; cleared images are discarded without promotion (spec FR-006, FR-007, FR-008, Q7).

## Phase 4: Testing & closing

**Goal**: unit and widget test coverage for the new tag parser and skill; structural row and closing pass.

- [x] T008 `test/ai_skill_test.dart`: add scene_dialog skill to the loaded skills list test (spec FR-002).
- [x] T009 `test/image_prompt_tag_test.dart`: unit tests for the `[image_prompt]` parser — spelling recognition,
  elision, scope (which scene a prompt belongs to) (spec FR-001).
- [x] T010 `specs/031-scene-dialog/breakpoint.md`: the structural row — the counts, the ARB keys, the artifact
  checkers.
- [x] T011 `specs/031-scene-dialog/quickstart.md`: the closing pass — the re-took counts, the receipts written.

## Dependencies & ordering

T001, T002, T003 → T004, T005, T005b (UI depends on parser + skill) → T006, T007 (toolbar + integration) → T008,
T009, T010, T011 (closing).

T005b can be developed in parallel with T009 once T005 is complete.

## Parallel opportunities

- **T001 with T002**: the parser extension and the new tag file are independent changes to related code.
- **T003 with T008**: skill definition and its test are different files.
- **T005 with T009**: dialog widget and tag parser tests are independent.
- **T005b with T009**: Generate All logic and tag parser tests are independent; both may run in parallel after T005 lands.

## Implementation strategy

- MVP = Phase 1 (tag parser) + Phase 2 (skill + dropdown) — the scene_dialog skill end-to-end for text generation.
- Phase 3 (sequential image dialog + Create pictures button) wraps the MVP into the full visual workflow.
- Phase 4 closes the stage on its own numbers.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (recognise [image_prompt] line-level tag, four spellings, grouped with preceding scene) | T001, T002, T009 |
| FR-002 (scene_dialog shipped as built-in skill with EN/ZH/ES templates and descriptions) | T003, T008 |
| FR-003 (scene_dialog template instructs AI to produce [scene], [image_prompt], {role}：) | T003 |
| FR-004 ("Create pictures" visible on Video page only when [image_prompt] tags exist) | T006 |
| FR-005 (dialog shows one prompt at a time; save/clear gating; full-size image; provider/type selector) | T005 |
| FR-006 (save promotes to picture list, discards full-size from memory, advances automatically) | T005, T007 |
| FR-007 (clear discards and frees memory immediately, advances automatically) | T005 |
| FR-008 (generated images NOT persisted into content file) | T007 |
| FR-009 (recent prompts deletable in dialog) | T005 |
| FR-010 (no [image_prompt] tags → "Create pictures" hidden; standard single-image path remains) | T006 |
| FR-011 ("Generate All" button; detached background task; same memory discipline; user may walk away) | T005b |
| FR-012 (progress indicator during run; summary notification on completion; errored tiles) | T005b |
| FR-013 (Done strip tappable; full-size view with Save/Delete/Retry; retry regenerates in-place) | T005, T005b |
