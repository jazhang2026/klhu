# Research: Scene dialog (031)

**Feature**: `031-scene-dialog` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

## §1 What the tree already carries

| need | where | what it answers |
|---|---|---|
| scene tag parsing | `lib/scene_tag.dart` | `[scene]` / `[场景]` / `[場景]` / `[escena]` — line-level tag, elided from reading and video; scene sentences assigned to pictures (spec 024) |
| role tag parsing | `lib/dialogue.dart` | `{name}：` prefix at paragraph head — derived on every read, never stored |
| comment tag parsing | `lib/comment.dart` | `[comment]` / `[注]` / `[註]` / `[nota]` — elided from reading and video display |
| AI skill system | `lib/ai/skill.dart`, `lib/ai/skill_store.dart` | three built-in skills (Story, Dialogue, Lesson) with per-locale templates and names |
| AI prompt dialog | `lib/reading_view.dart` (`_AIPromptDialog`) | type picker, provider picker, skill dropdown, prompt field, generate button |
| Image generation | `lib/ai/provider_client.dart` (`generate()` with `AIPromptType.image`) | routes to provider's image endpoint; returns URL or data URI |
| Image preview + save | `lib/reading_view.dart` (`_AIImagePreviewDialog`, `_saveImageToGallery`) | full-screen preview with MediaStore save |
| Picture assignment | `lib/picture_assignment.dart`, `lib/picture_assignment_store.dart` | assigns sentences to pictures; persists in SharedPreferences |
| Video page toolbar | `lib/reading_view.dart` (video review screen) | "Choose pictures" button, "Auto assign scenes" button |
| Provider config | `lib/ai/provider_config_screen.dart` | provider list with active/selected flags |

### Key code locations for 031 integration points

- **Video page picture selection** — `lib/reading_view.dart` lines 2644–2660: the "Choose pictures" `TextButton.icon`. The new "Create pictures" button goes here, below it, conditional on `[image_prompt]` tags.
- **Scene tag parsing** — `lib/scene_tag.dart`: the existing parser recognises `[scene]` lines and produces `Scene` objects with `first`/`last` ranges. Extending this to also capture `[image_prompt]` lines per scene is the core parser change.
- **AI image generation** — `lib/ai/provider_client.dart:generate()`: the existing `generate()` method already supports `AIPromptType.image`. Reusing it per-prompt is straightforward.
- **Picture assignment** — `lib/picture_assignment.dart`: generated images are promoted into the assignment via the same `PictureAssignment` model.

## §2 Decisions

### D1 — `[image_prompt]` is a line-level tag parallel to `[scene]`

The tag sits on its own line: `[image_prompt] prompt text here`. It is parsed by a new `lib/image_prompt_tag.dart`, following the exact same pattern as `lib/scene_tag.dart`: one spelling per locale, line-scoped, elided from reading and video. The four spellings are: `image_prompt` / `图像提示` / `imagem` / `prompt_img`.

### D2 — Scene-image prompt scoping rule

A scene's image prompt is the last `[image_prompt]` line that appears after the scene's `[scene]` line and before the next `[scene]` line (or EOF). If no `[image_prompt]` line exists in that span, the scene has no prompt (`null`). Orphaned `[image_prompt]` lines (not preceded by a `[scene]` in the same span) are skipped.

### D3 — Sequential single-image generation, not batch; runs detached from UI

The image-generation dialog shows **one prompt at a time**. After generating an image, the **full-size image** is displayed (not a thumbnail) so the reader can inspect it before deciding. The reader must tap **Save** (promote to picture list, discard full-size image from memory, advance) or **Clear** (discard, release memory, advance). Only then does the next prompt become available. Saved images accumulate as a strip of small thumbnails in the "Done" section at the top of the dialog — the full-size version is gone from memory. A **"Generate All"** button lets the reader kick off an automatic run of all remaining prompts; during auto-run the same memory rule applies — each image is shown full-size briefly, then auto-discarded, no Save/Clear needed.

**Generate All is a detached background task.** Once tapped, the sequential run continues even if the user closes the dialog, switches to another app, or opens a different KalaHoo feature (reading, video editing, etc.). The app delivers progress/status messages via notification or banner. When the user returns and reopens the dialog, the current state (done strip + in-flight counter) is restored automatically. This prevents holding multiple high-resolution decoded images in memory simultaneously, which caused the OOM crash.

### D4 — Generated images are temp until promoted

Images generated in the dialog live in the app's cache directory (same as the render's working directory). Tapping "Save" copies the image into the picture assignment via the existing `PictureAssignment` flow. The image prompt text itself is never saved back into the content file.

### D5 — No new dependency

All infrastructure already exists: `shared_preferences`, `http`, the AI provider client, the image preview dialog, the picture assignment store, the scene tag parser. Adding `image_prompt_tag.dart` and the sequential dialog reuses everything.

## §3 Risks and reservations

- **R1** — Memory pressure from multiple simultaneous images. **Mitigated**: the dialog now holds only one decoded image at a time. Before advancing to the next prompt, the previous full-size image widget is disposed and the image data is nulled out, giving the garbage collector a clear path to reclaim memory. This includes **after save** — the full-size image is discarded and replaced by a small thumbnail in the "Done" strip. During **Generate All**, the same rule applies: each generated image is held for only one cycle before being auto-discarded.
- **R2** — Garbage collection may not run immediately after disposal. On some devices (especially Android with lower RAM), the system may delay GC. **Mitigation**: explicitly dispose image controllers/widgets and null out state variables before advancing. Use `Image.memory(null)` or replace the image widget with empty placeholder to signal the framework that the old image can be collected. Consider adding a small `await Future.delayed(...)` after dispose if profiling shows GC delay.
- **R3** — Provider image-model availability. Not all configured providers support image generation. The dialog should filter to image-capable providers only (or warn when the selected provider cannot generate images).
- **R4** — Content change during session. If the reader edits the content while the dialog is open, the prompt list becomes stale. The dialog should detect content changes on open and refresh accordingly.
- **R5** — Generate All runs for an extended period (minutes for many scenes). The dialog must keep a stable in-flight state; cancelling mid-run must not leak the current image's memory. **Mitigation**: on cancel or provider switch, the current in-flight future is aborted and its result is discarded; the full-size image controller is cleared synchronously.
- **R6** — App backgrounding during Generate All. On return, the dialog should restore which images succeeded/failed/pending. **Mitigation**: persist the sequence state (index, results map) in a lightweight in-memory structure keyed to the dialog instance; rebuild on dialog reopen if the content hash matches. The task should also survive being moved to the background by the OS — use a background isolate or isolates with `compute` rather than tying the work to the main UI isolate.
- **R7** — iOS background-task limits. iOS restricts how long a background task can run without explicit permission. **Mitigation**: register a brief background task on app-enter-background, check completion status before suspending, and rely on the isolated computation continuing under iOS's allowed background-execution budget. For very long runs (20+ images), consider falling back to a periodic foreground-refresh approach where the app wakes periodically to push the next step. Android has looser constraints but still benefits from using `WorkManager` or a dedicated isolate.
- **R8** — Notifications while the user is reading elsewhere in KalaHoo. Progress banners must not interrupt the reading experience. **Mitigation**: show non-intrusive toasts/banners at natural breakpoints (between images); suppress them while the reading view is in active use; use the platform notification channel for completion-only alerts.

## §4 What this research does not measure

- Provider rate limits for image generation (known from spec 029 research).
- The exact visual layout of the sequential dialog (prototype and measure on device).
- How many image prompts a typical scene dialog contains (depends on the skill's output).
- The performance impact of generating multiple images in sequence (single-threaded per prompt for now).
