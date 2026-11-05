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

### D3 — Batch generation is a modal dialog, not a page

The batch image-generation dialog is a `showDialog<void>` call from the Video page. It lists all image prompts, provides a provider/type selector at the top, and shows per-prompt generate/save/delete rows. Each generation runs independently via `AIProviderClient.generate()`.

### D4 — Generated images are temp until promoted

Images generated in the batch dialog live in the app's cache directory (same as the render's working directory). Tapping "Save" copies the image into the picture assignment via the existing `PictureAssignment` flow. The image prompt text itself is never saved back into the content file.

### D5 — No new dependency

All infrastructure already exists: `shared_preferences`, `http`, the AI provider client, the image preview dialog, the picture assignment store, the scene tag parser. Adding `image_prompt_tag.dart` and the batch dialog reuses everything.

## §3 Risks and reservations

- **R1** — Batch generation latency. Multiple image prompts can take many minutes total. The dialog must not block the UI thread; each generation runs independently and updates its row.
- **R2** — Provider image-model availability. Not all configured providers support image generation. The batch dialog should filter to image-capable providers only (or warn when the selected provider cannot generate images).
- **R3** — Scene-image prompt scoping edge cases. If the reader places an `[image_prompt]` line without a preceding `[scene]`, it is orphaned and skipped in the batch list. The parser must handle this gracefully.
- **R4** — Content change during batch session. If the reader edits the content while the batch dialog is open, the prompt list becomes stale. The dialog should detect content changes and either refresh or close with a warning.

## §4 What this research does not measure

- Provider rate limits for image generation (known from spec 029 research).
- The exact visual layout of the batch dialog (prototype and measure on device).
- How many image prompts a typical scene dialog contains (depends on the skill's output).
- The performance impact of generating multiple images in sequence (single-threaded per prompt for now).
