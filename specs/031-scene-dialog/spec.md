# Feature Specification: Scene dialog (031)

**Feature Branch**: `031-scene-dialog`

**Created**: 2026-11-05

**Status**: Draft

**Input**: the reader's wish list (`text.txt`), item 031 — a new content type called "scene dialog" where each scene carries a title, dialog text, and an image prompt; a new skill generates this format; a batch image-generation UI on the video page.

## What this feature does

Adds a **scene dialog** content type and a **scene_dialog** skill to the AI prompt dialog. Each scene carries three parts:
- a `[scene]` heading line (already parsed by `lib/scene_tag.dart`)
- dialog text (readable, highlightable, voice-able)
- an `[image_prompt]` line (never read, never shown in reading/video — just metadata for image generation)

On the Video page, if the content contains `[image_prompt]` tags, a **"Create pictures"** button appears under "Choose pictures" and opens a **batch image generation dialog** — one generation task per image prompt, with per-prompt generate/save/delete buttons. If no image prompts exist, the button falls back to the standard single-image AI prompt dialog.

## Clarifications

### The reader's answers

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | What is the content structure of a scene dialog? | A scene dialog is a sequence of scenes. Each scene is a `[scene] heading` line, followed by one or more dialog paragraphs, followed by an `[image_prompt] prompt text` line. The scene tag and image-prompt tag are both consumed by the existing parser and elided from reading and video display. Dialog paragraphs are ordinary text, formatted into turns if the content is in dialogue mode. | a new content-format field on `SavedContent`; the scene structure is purely a textual convention, no new DB column. |
| **Q2** | Where does the `[image_prompt]` tag live relative to `[scene]`? | `[image_prompt]` is a **line-level tag** like `[scene]`. It sits on its own line, followed by the prompt text on the same line. A scene's image prompt is the `[image_prompt]` line immediately before the next `[scene]` line (or before EOF). The parser groups it with the preceding scene's dialog. | nesting it inside the scene as a sub-element; the flat line tag model is consistent with every existing tag. |
| **Q3** | How does the scene_dialog skill differ from Story/Dialogue/Lesson? | The **scene_dialog** skill template generates a multi-scene structure with `[scene]` and `[image_prompt]` tags. It prompts the AI to produce one scene at a time, each with a title, dialog, and image prompt. Other skills (Story, Dialogue, Lesson) produce flat text with no scene structure. | combining scene_dialog into the Dialogue skill; keeping them separate avoids confusing a reader who only wants plain dialogue. |
| **Q4** | What happens when the reader opens a scene-dialog content in the reader? | Exactly the same as any other content: dialog paragraphs are read aloud with the assigned voices, `[scene]` and `[image_prompt]` lines are silently elided, highlighting follows the segmenter as usual. No new reader behaviour. | special-casing the scene dialog in the read pipeline. |
| **Q5** | On the Video page, when does "Create pictures" appear vs "Choose pictures"? | "Choose pictures" always appears (it opens the file picker). **"Create pictures"** appears below it **only when the current content contains `[image_prompt]` tags**. Tapping it opens the batch image-generation dialog. | a single button that does both; two distinct buttons keep the workflows separate. |
| **Q6** | What does the batch image-generation dialog look like? | A list of all `[image_prompt]` entries in the content. Each row shows: the prompt text, a generate button, and (after generation) the generated thumbnail with save/delete buttons. An AI provider dropdown and generation-type (image-only) selector appear at the top. | one big "generate all" button; per-prompt control lets the reader retry individual failures. |
| **Q7** | Are generated images persisted into the content? | **No.** Generated images are temporary working copies. They can be selected into the picture assignment after generation completes, but the `[image_prompt]` tags and generated-image references are not saved back into the content file. | embedding generated images into the text file; keeping them external matches the existing picture-assignment pattern. |
| **Q8** | What about recent prompts in the batch dialog? | Recent prompts are shown in a collapsible list (same as the edit-page prompt history). Generated image-prompt history entries are **deletable** (swipe or long-press), matching the existing prompt-history delete behaviour. | persistent non-deletable history; deletable history lets the reader clean up stale prompts. |

## User Scenarios & Testing

### User Story 1 — Generate a scene-dialog from a story idea (Priority: P1)

As a KalaHoo Reading user, I want to pick the "Scene Dialog" skill, enter a topic like "a fairy tale about a tiger and a mouse", and get back a multi-scene script with `[scene]` headings, dialog in `{role}：` format, and `[image_prompt]` lines — ready to assign to pictures and render as a video.

**Why this priority**: Scene dialog is the reader's first end-to-end flow that combines text generation, image generation, and video composition in one workflow.

**Independent Test**: open Edit → AI → pick Scene Dialog skill → submit → returned content contains `[scene]` and `[image_prompt]` tags → the content reads correctly with roles assigned → opening the Video page shows "Create pictures" → batch dialog lists all image prompts.

### User Story 2 — Generate images from scene prompts (Priority: P2)

As a KalaHoo Reading user, I want to tap "Create pictures" on the Video page, select an image provider, and generate images for each scene's `[image_prompt]` line. After generation, I can save or delete individual images and use them as the content's pictures.

**Why this priority**: The image-generation step is what makes the scene dialog workflow complete; without it the scenes have no visuals.

**Independent Test**: open Video page for a scene-dialog content → tap "Create pictures" → provider dialog opens → each image prompt shows a generate button → tapping generate produces an image → generated image appears as a thumbnail → saving it adds it to the picture list.

## Requirements

### Functional Requirements

- **FR-001**: The app MUST recognise `[image_prompt]` / `[图像提示]` / `[imagem]` as a line-level tag (one spelling per locale, four total including the English default), parsed alongside `[scene]` by the existing tag infrastructure (`lib/scene_tag.dart` extended, not replaced).
- **FR-002**: The scene dialog skill MUST be shipped as a built-in skill in `AISkillStore.builtInSkills` with templates in all three locales (EN, ZH, ES) and a `localizedDescriptions` map.
- **FR-003**: The scene dialog skill template MUST instruct the AI to produce `[scene]` heading lines, `[image_prompt]` lines, and dialog paragraphs in `{role}：` format.
- **FR-004**: The "Create pictures" button MUST appear on the Video page toolbar **only when** the current content contains at least one `[image_prompt]` tag.
- **FR-005**: Tapping "Create pictures" MUST open a batch image-generation dialog that lists every `[image_prompt]` entry in the content, each with its own generate button, and an AI provider + type (image-only) selector at the top.
- **FR-006**: Generating an image for one prompt MUST NOT affect the other prompts' buttons; each prompt is an independent generation task.
- **FR-007**: After generation, each prompt's row MUST show the generated image thumbnail with save and delete buttons. Saving promotes the image into the content's picture list.
- **FR-008**: Generated images MUST NOT be persisted into the content file; only the reader's manual selection into the picture list survives a save.
- **FR-009**: Recent prompts in the batch dialog MUST be deletable (same UX as the edit-page prompt history).
- **FR-010**: When the content has **no** `[image_prompt]` tags, the "Create pictures" button is hidden; the standard single-image AI prompt path remains available through the edit page's AI button.

## Edge Cases

- **No `[image_prompt]` tags**: the batch dialog never opens; "Create pictures" is absent from the video toolbar.
- **Image generation fails for one prompt**: that prompt's row shows an error state with a retry button; other prompts are unaffected.
- **Empty image prompt text**: the prompt is skipped in the batch list (empty tags produce no row).
- **Provider switch mid-batch**: switching the provider cancels any in-flight generations and resets all pending prompts.
- **Content changed after batch opened**: the batch dialog closes and reopens with the updated prompt list.
- **Saving a generated image**: the image is copied to the app's picture directory and added to the assignment list; the original temp file may be deleted after promotion.
