# Feature Specification: Scene dialog (031)

**Feature Branch**: `031-scene-dialog`

**Created**: 2026-11-05

**Status**: CLOSED

**Input**: the reader's wish list (`text.txt`), item 031 — a new content type called "scene dialog" where each scene carries a title, dialog text, and an image prompt; a new skill generates this format; a sequential image-generation UI on the video page (one image at a time, with save/clear before advancing).

## What this feature does

Adds a **scene dialog** content type and a **scene_dialog** skill to the AI prompt dialog. Each scene carries three parts:
- a `[scene]` heading line (already parsed by `lib/scene_tag.dart`)
- dialog text (readable, highlightable, voice-able)
- an `[image_prompt]` line (never read, never shown in reading/video — just metadata for image generation)

On the Video page, if the content contains `[image_prompt]` tags, a **"Create pictures"** button appears under "Choose pictures" and opens a **sequential image-generation dialog** — only one image is generated and displayed at a time. Before generating the next image, the current image must either be **saved** or **cleared**, ensuring its memory is released. A **"Generate All"** button in the dialog header lets the user kick off an automatic sequential run of every remaining prompt; images are generated one-by-one in the background using the same memory discipline (full-size image shown during generation, discarded immediately after). After generation completes (or is cancelled), the user can review each result individually — viewing the full image, deleting, or re-generating a single failed image. If no image prompts exist, the button falls back to the standard single-image AI prompt dialog.

## Clarifications

### The reader's answers

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | What is the content structure of a scene dialog? | A scene dialog is a sequence of scenes. Each scene is a `[scene] heading` line, followed by one or more dialog paragraphs, followed by an `[image_prompt] prompt text` line. The scene tag and image-prompt tag are both consumed by the existing parser and elided from reading and video display. Dialog paragraphs are ordinary text, formatted into turns if the content is in dialogue mode. | a new content-format field on `SavedContent`; the scene structure is purely a textual convention, no new DB column. |
| **Q2** | Where does the `[image_prompt]` tag live relative to `[scene]`? | `[image_prompt]` is a **line-level tag** like `[scene]`. It sits on its own line, followed by the prompt text on the same line. A scene's image prompt is the `[image_prompt]` line immediately before the next `[scene]` line (or before EOF). The parser groups it with the preceding scene's dialog. | nesting it inside the scene as a sub-element; the flat line tag model is consistent with every existing tag. |
| **Q3** | How does the scene_dialog skill differ from Story/Dialogue/Lesson? | The **scene_dialog** skill template generates a multi-scene structure with `[scene]` and `[image_prompt]` tags. It prompts the AI to produce one scene at a time, each with a title, dialog, and image prompt. Other skills (Story, Dialogue, Lesson) produce flat text with no scene structure. | combining scene_dialog into the Dialogue skill; keeping them separate avoids confusing a reader who only wants plain dialogue. |
| **Q4** | What happens when the reader opens a scene-dialog content in the reader? | Exactly the same as any other content: dialog paragraphs are read aloud with the assigned voices, `[scene]` and `[image_prompt]` lines are silently elided, highlighting follows the segmenter as usual. No new reader behaviour. | special-casing the scene dialog in the read pipeline. |
| **Q5** | On the Video page, when does "Create pictures" appear vs "Choose pictures"? | "Choose pictures" always appears (it opens the file picker). **"Create pictures"** appears below it **only when the current content contains `[image_prompt]` tags**. Tapping it opens the image-generation dialog. | a single button that does both; two distinct buttons keep the workflows separate. |
| **Q6** | What does the image-generation dialog look like? | A single active row shows the next ungenerated prompt with a generate button. After generation, the **full-size image** appears (not a thumbnail) so the reader can inspect it before deciding. Below the image are **Save** and **Clear** buttons. **The reader must tap Save or Clear before the next prompt becomes available.** After saving, the full-size image is discarded from memory and a small saved-thumbnail is added to the "Done" strip at the top of the dialog. After clearing, the image is discarded and memory is freed. An AI provider dropdown and generation-type (image-only) selector appear at the top. A **"Generate All"** button sits beside the provider selector — when tapped, it runs every remaining ungenerated prompt automatically, one at a time, showing a progress indicator; each image follows the same memory discipline (auto-discarded after generation) without requiring manual Save/Clear. | one big "generate all" button; per-prompt control lets the reader retry individual failures. |
| **Q7** | Are generated images persisted into the content? | **No.** Generated images are temporary working copies. They can be selected into the picture assignment after generation completes, but the `[image_prompt]` tags and generated-image references are not saved back into the content file. | embedding generated images into the text file; keeping them external matches the existing picture-assignment pattern. |
| **Q8** | What about recent prompts in the dialog? | Recent prompts are shown in a collapsible list (same as the edit-page prompt history). Generated image-prompt history entries are **deletable** (swipe or long-press), matching the existing prompt-history delete behaviour. | persistent non-deletable history; deletable history lets the reader clean up stale prompts. |
| **Q9** | What does "Generate All" do exactly? | It generates prompts sequentially (never more than one in-flight). After each image is produced, the full-size image is held briefly, then **automatically discarded from memory** while a small done-thumb is appended to the "Done" strip — the reader does NOT need to manually tap Save/Clear during auto-run. On completion, a summary message reports how many succeeded vs failed. Failed images appear as errored tiles in the "Done" strip; tapping a tile opens that prompt's **full-size image** with **Retry** and **Delete** buttons. Manual single-step mode and Generate All are mutually exclusive — starting one cancels the other. **Generate All runs as a detached background task:** once started, the user may close the dialog, switch to another app, or use KalaHoo reading. The server-side generation continues. When the user reopens the dialog for this content, the current progress (done strip + still-running counter) is restored automatically. | a fire-and-forget batch that holds all images in memory until the end. |

## User Scenarios & Testing

### User Story 1 — Generate a scene-dialog from a story idea (Priority: P1)

As a KalaHoo Reading user, I want to pick the "Scene Dialog" skill, enter a topic like "a fairy tale about a tiger and a mouse", and get back a multi-scene script with `[scene]` headings, dialog in `{role}：` format, and `[image_prompt]` lines — ready to assign to pictures and render as a video.

**Why this priority**: Scene dialog is the reader's first end-to-end flow that combines text generation, image generation, and video composition in one workflow.

**Independent Test**: open Edit → AI → pick Scene Dialog skill → submit → returned content contains `[scene]` and `[image_prompt]` tags → the content reads correctly with roles assigned → opening the Video page shows "Create pictures" → dialog shows first prompt; after saving/clearing each generated image, the next prompt advances automatically until all are done.

### User Story 2 — Generate images from scene prompts (Priority: P2)

As a KalaHoo Reading user, I want to tap "Create pictures" on the Video page, select an image provider, and generate images for each scene's `[image_prompt]` line. After generation, I can save or delete individual images and use them as the content's pictures.

**Why this priority**: The image-generation step is what makes the scene dialog workflow complete; without it the scenes have no visuals.

**Independent Test**: open Video page for a scene-dialog content → tap "Create pictures" → provider selector opens → first image prompt is shown with a generate button → tapping generate produces a full-size image → save promotes it to picture list and memory is freed, then next prompt appears automatically → repeat until all scenes have images.

### User Story 3 — Generate All images automatically (Priority: P2)

As a KalaHoo Reading user, I want to tap "Generate All" once and let the app produce every scene image sequentially in the background, so I don't have to manually tap generate for each scene. When it finishes, I want to see which succeeded and which failed, and be able to review, retry, or delete individual results. **I want to be able to walk away — use other apps or KalaHoo reading — while the background run continues.**

**Why this priority**: Automates the repetitive generate step while preserving memory safety and per-image control. Runs unobtrusively in the background.

**Independent Test**: open Video page for a multi-scene content → tap "Create pictures" → tap "Generate All" → progress counter advances ("1/6 … 4/6") → close the dialog or switch to another app → open KalaHoo reading for any content → after a few minutes the system notification or in-app banner shows "Scene images: 5/6 done" → reopen Video page → dialog restores to "5/6 done, continuing…" → at the end a summary says "4 succeeded, 2 failed" → the "Done" strip shows 4 green-tinted thumbnails and 2 red error tiles → tapping a green thumbnail opens the full-size image with Save/Delete → tapping a red tile opens the prompt with Retry/Delete → retrying the failed image regenerates it in place; saving promotes it and frees memory.

## Requirements

### Functional Requirements

- **FR-001**: The app MUST recognise `[image_prompt]` / `[图像提示]` / `[imagem]` as a line-level tag (one spelling per locale, four total including the English default), parsed alongside `[scene]` by the existing tag infrastructure (`lib/scene_tag.dart` extended, not replaced).
- **FR-002**: The scene dialog skill MUST be shipped as a built-in skill in `AISkillStore.builtInSkills` with templates in all three locales (EN, ZH, ES) and a `localizedDescriptions` map.
- **FR-003**: The scene dialog skill template MUST instruct the AI to produce `[scene]` heading lines, `[image_prompt]` lines, and dialog paragraphs in `{role}：` format.
- **FR-004**: The "Create pictures" button MUST appear on the Video page toolbar **only when** the current content contains at least one `[image_prompt]` tag.
- **FR-005**: Tapping "Create pictures" MUST open an image-generation dialog that shows **one prompt at a time**. The next prompt is locked until the current generated image is either **saved** or **cleared**, guaranteeing the previous image's memory is freed. After generation, the **full-size image** is displayed (not a thumbnail). An AI provider + type (image-only) selector sits at the top.
- **FR-006**: Saving an image MUST promote it into the picture list, **discard the full-size image from memory immediately**, add only a small saved-thumbnail to the "Done" strip, and advance to the next unsaved prompt automatically.
- **FR-007**: Clearing an image MUST discard it and **free its memory** immediately. After clearing, the dialog advances to the next unsaved prompt automatically. Deleted thumbnails in the "Done" strip do not free additional memory (already saved to disk).
- **FR-008**: Generated images MUST NOT be persisted into the content file; only the reader's manual selection into the picture list survives a save.
- **FR-009**: Recent prompts in the dialog MUST be deletable (same UX as the edit-page prompt history).
- **FR-010**: When the content has **no** `[image_prompt]` tags, the "Create pictures" button is hidden; the standard single-image AI prompt path remains available through the edit page's AI button.
- **FR-011**: The dialog MUST show a **"Generate All"** button in the header bar alongside the provider/type selector. Tapping it starts an automatic sequential generation of all unsaved/unfailed prompts as a **detached background task**. During auto-run, memory discipline is the same: only one full-size image is held in memory at any instant, and it is discarded immediately after each step (no Save/Clear gating required during auto-run). The user MAY close the dialog, switch to another app, or use other KalaHoo features (e.g. reading) while the background run continues.
- **FR-012**: While "Generate All" runs, the dialog (if open) MUST show a **progress indicator** (e.g. "3 / 8 done"). On completion (whether the user is present or has walked away), the app MUST deliver a **summary notification** — a persistent in-app banner if the dialog is visible, otherwise a system notification or badge (depending on platform capability) stating something like *"Scene images: 5 succeeded, 2 failed."* On the next open of the dialog for this content, the completed results are displayed in the "Done" strip; failed images appear as errored tiles.
- **FR-013**: After "Generate All" (or manual mode), each item in the "Done" strip MUST be tappable. Tapping an item opens that prompt's **full-size image** (only one at a time) with **Save**, **Delete**, and (if failed) **Retry** buttons. Saving deletes the full-size widget from memory and promotes the image to the picture list. Deleting removes it entirely. Retrying regenerates that single image in-place, following the same memory discipline.

## Edge Cases

- **No `[image_prompt]` tags**: the image dialog never opens; "Create pictures" is absent from the video toolbar.
- **Image generation fails for one prompt (manual mode)**: that prompt's row shows an error state with a retry button; the dialog remains paused at that prompt until resolved.
- **Image generation fails for one prompt (Generate All)**: that image becomes an errored tile in the "Done" strip; auto-run continues with remaining prompts; summary message enumerates all failures on completion.
- **Empty image prompt text**: the prompt is skipped in the sequence (empty tags produce no row).
- **Provider switch mid-manual-session**: switching the provider cancels any in-flight generation and resets to the current pending prompt.
- **Provider switch during Generate All**: switching cancels the running auto-sequence; results collected so far are kept in the "Done" strip; the dialog returns to the next pending prompt in manual mode.
- **Content changed after dialog opened**: the dialog closes and reopens with the updated prompt list.
- **Saving a generated image**: the image is copied to the app's picture directory and added to the assignment list; the original temp file is deleted after promotion and the image's memory is released.
- **Memory management**: after every save, clear, or auto-advance, the full-size image widget must be disposed and its underlying bytes must be nulled out so the Flutter garbage collector can reclaim them. Only the small "Done" strip thumbnails remain in view, keeping peak memory low even across many scenes (8+ images). This applies equally to manual mode and Generate All.
- **Generate All interrupted by app backgrounding**: on return, the dialog restores the in-progress state — completed images stay in the "Done" strip, the currently generating image is retried, and the user may resume or cancel. A status notification was shown when the app was backgrounded (if platform supports it).
- **User switches to another app during Generate All**: generation continues as a detached background task. When the user returns to KalaHoo, a system notification or in-app banner reports progress/completion. Reopening the dialog for this content shows the current state.
- **User uses other KalaHoo features (e.g. reading) during Generate All**: fully supported; generation runs independently in the background and does not block any other KalaHoo functionality. Progress notifications continue to arrive when the app regains foreground.
- **Tap a Done-strip tile while Generate All is still running**: not allowed; the user must wait for completion or cancel first.
