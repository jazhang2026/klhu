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

## §2 Decisions

### D1 — `[image_prompt]` is a line-level tag, not a content-format field

The tag sits on its own line, followed by prompt text. It is parsed, scoped to the preceding scene, and elided from reading and video — the same shape as `[scene]` and `[comment]`. No new content-model field is needed.

### D2 — Batch image generation is a modal dialog, not a new page

The batch dialog is a `showDialog` call from the Video page. It shares the same provider configuration as the edit-page AI dialog and reuses `AIProviderClient.generate()` per prompt. No new top-level route.

### D3 — Generated images are temp until promoted

Images generated in the batch dialog live in the app's cache directory. Tapping "Save" copies the image into the picture assignment list (the same flow as the existing "Choose pictures" → pick → assign). The image prompt text itself is never saved back into the content file.

### D4 — No new dependency

All infrastructure already exists: `shared_preferences`, `http`, the AI provider client, the image preview dialog, the picture assignment store. Adding `image_prompt_tag.dart` and the batch dialog reuses everything.

## §3 Risks and reservations

- **R1** — Batch generation latency. Multiple image prompts can take many minutes total. The dialog must not block the UI thread; each generation runs independently and updates its row.
- **R2** — Provider image-model availability. Not all configured providers support image generation. The batch dialog should filter to image-capable providers only (or warn when the selected provider cannot generate images).
- **R3** — Scene-image prompt scoping. A scene's image prompt is defined as the last `[image_prompt]` line before the next `[scene]` or EOF. If the reader places an `[image_prompt]` line without a preceding `[scene]`, it is orphaned and skipped in the batch list.

## §4 What this research does not measure

- Provider rate limits for image generation (known from spec 029 research).
- The exact visual layout of the batch dialog (prototype and measure).
- How many image prompts a typical scene dialog contains (depends on the skill's output).
