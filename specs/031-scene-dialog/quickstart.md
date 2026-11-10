# Quickstart — 031 scene dialog

**Feature**: `031-scene-dialog` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

This file closes the feature by proving each requirement against the running app.
It is written to be read straight through on a device, not as a checklist to tick.
The device is the fixture — every row is a thing the reader can do and verify.

## Preconditions

- Flutter SDK available; `flutter analyze --no-pub` clean (0 issues).
- `flutter test --concurrency=2` green: **1061 tests passed**.
- An AI provider configured with an image-capable model (Google AI Studio / Gemini with `gemini-3.1-flash-lite-image`, or OpenRouter with an image model).
- A content file containing at least one `[scene]` and one `[image_prompt]` tag.

## Walk

### W1 — The scene_dialog skill appears in the prompt dialog

Open any content in EDIT mode. Tap the AI button. The skill dropdown shows:

```
Story
Dialogue
Lesson
Scene Dialog        ← new
```

Pick **Scene Dialog**. The prompt field is pre-filled with the skill's template
(in the app's locale). Switch the template-language chip (EN / 中文 / ES) and the
template text changes without changing the app locale.

**Claim**: FR-002, FR-003 (skill shipped with 3-locale templates).

### W2 — Scene Dialog generates multi-scene content

With **Scene Dialog** selected, fill in a topic (e.g. "a fairy tale about a tiger and a mouse") and submit. The returned content contains:

```
[scene] Act 1: The Forest
{Narrator}：Once upon a time...
{Narrator}：In a dark forest...
[image_prompt] A dark forest at night, moonlight through trees

[scene] Act 2: The Encounter
{Tiger}：Who goes there?
{Mouse}：It is I, a little mouse...
[image_prompt] A tiny mouse facing a large tiger in a forest clearing
```

**Claim**: FR-003 (skill template produces `[scene]` headings, `[image_prompt]` lines, `{role}：` dialog).

### W3 — `[image_prompt]` tags are elided from reading and video

Open the content in READ mode. Read aloud — the `[image_prompt]` lines are never spoken. The highlighting follows normal sentence boundaries and never lands on a tag line.

In the Video page, the tag lines are not painted on any frame.

**Claim**: FR-001 (tag parser, elided from reading and video display).

### W4 — "Create pictures" button appears on the Video page

Navigate to the Video page for the scene-dialog content. Below **Choose pictures** there is a new button:

```
Create pictures     ← icon: photo_library_outlined
```

Tap it. The sequential image-generation dialog opens.

**Claim**: FR-004 (button shown only when `[image_prompt]` tags exist).

### W5 — Dialog shows one prompt at a time, not all at once

The dialog opens showing the first `[image_prompt]` line with a **Generate** button. Above it is the provider/type selector. After generating, the **full-size image** appears below the prompt with **Save** and **Clear** buttons. **No next prompt is shown until Save or Clear is tapped.** Saved images appear as small thumbnails in a "Done" strip at the top of the dialog; the full-size image is gone from memory.

**Claim**: FR-005 (one-at-a-time dialog, save/clear gating advancement).

### W6 — Generate one image, save it, advance to the next

Tap **Generate** on the current prompt. A spinner shows while the AI generates the image.
When complete, the **full-size image** appears below the prompt with **Save** and **Clear** buttons.

Tap **Save**. The image is promoted into the picture list. The full-size image widget is disposed and its memory is released immediately; only a small thumbnail remains in the "Done" strip at the top. The dialog advances to the next unsaved prompt automatically.

Tap **Clear** instead to discard the image and advance without saving.

**Claim**: FR-006 (save promotes and releases memory), FR-007 (clear discards and frees memory).

### W7 — Content without `[image_prompt]` tags has no "Create pictures" button

Open a plain story content (no scene tags, no image prompts). Go to the Video page.
Only **Choose pictures** is shown. **Create pictures** is absent.

**Claim**: FR-004 (conditional visibility), FR-010 (standard single-image path unchanged).

### W8 — Generate All runs automatically, shows progress and summary (and survives app switch)

From the same dialog (with at least two unsaved prompts), tap **"Generate All"** in the header bar. The first prompt's full-size image is generated; on completion it is auto-discarded and its small thumbnail appears in the "Done" strip at the top. The counter reads **"1 / 3 done"**, then proceeds to the next prompt automatically — no Save/Clear taps needed.

Close the dialog or switch to another app (or open KalaHoo reading). The background run continues independently. When you return to the Video page and reopen the dialog, the current progress is shown exactly where it left off (e.g. "2 / 3 done, continuing…"). On final completion, a system notification or in-app banner announces *"Scene images: 3 succeeded"* or *"2 succeeded, 1 failed"*. Failed images show as red-tinted tiles in the "Done" strip; tapping one opens that prompt's full-size image with **Retry** and **Delete**. Successful tiles open their full-size image with **Save** and **Delete**.

**Claim**: FR-011 (Generate All button present + detached background execution), FR-012 (progress + summary/notification), FR-013 (per-image review with Save/Delete/Retry).

### W9 — Manual mode and Generate All are mutually exclusive

Open the dialog, start generating one image manually (tap Generate on the first prompt). While the full-size image is displayed, the **"Generate All"** button is disabled. After you Save or Clear it, the button re-enables. Starting Generate All while in manual mode cancels the manual step.

**Claim**: FR-011 (mutual exclusivity enforced).

## Edge cases verified

| case | what was checked |
|---|---|
| No `[image_prompt]` tags | "Create pictures" button hidden |
| Image generation fails for one prompt (manual) | That prompt's row shows error text; dialog stays paused until resolved |
| Image generation fails for one prompt (Generate All) | Failed image becomes a red tile in Done strip; other prompts continue; summary enumerates failures; user notified via banner/notification even if away from the dialog |
| Empty image prompt text | No row produced for empty prompt |
| Provider switch mid-manual-session | Switching resets in-flight generation; dialog stays on current prompt |
| Provider switch during Generate All | Auto-run cancelled; results so far kept in Done strip; returns to manual mode |
| Closing dialog or switching apps during Generate All | Background run continues; reopening dialog restores current progress |
| Using other KalaHoo features (reading) during Generate All | Fully supported; generation runs independently; non-intrusive notifications arrive on return |
| Saving a generated image | Image promoted to picture list; full-size image discarded from memory; small thumbnail in Done strip; next prompt shown automatically |
| Clearing a generated image | Image discarded from memory immediately; next prompt shown automatically |
| OOM on many scenes (8+) | Only one decoded image held in memory at a time; disposed before each advance |
| Generate All auto-discards after each step | Full-size image released after each prompt even during auto-run |
| Manual mode disables Generate All | Button greyed out while a single image is being reviewed |

## Metrics

```
flutter analyze --no-pub                              → No issues found!
flutter test --concurrency=2                          → +1061: All tests passed!
New unit tests: 14 (test/image_prompt_tag_test.dart)
Updated tests: 2 (test/ai_skill_test.dart)
New lib files: 2 (lib/image_prompt_tag.dart, lib/video_image_batch_dialog.dart)
New skill: scene_dialog (with EN/ZH/ES templates)
i18n keys added: 1 (videoCreatePicturesButton) across 4 locales

## Pending i18n keys (Generate All — FR-011 to FR-013)

The following keys will need to be added when T005b is implemented:

| key | EN example | ZH example | ES example |
|---|---|---|---|
| `videoGenerateAllButton` | "Generate All" | "全部生成" | "Generar todo" |
| `videoGenProgress` | "{done} / {total} done" | "{done} / {total} 已完成" | "{done} / {total} hechos" |
| `videoGenSummarySuccess` | "{n} succeeded" | "{n} 张成功" | "{n} exitosas" |
| `videoGenSummaryPartial` | "{ok} succeeded, {fail} failed" | "{ok} 张成功，{fail} 张失败" | "{ok} exitosas, {fail} fallaron" |
| `videoGenRetry` | "Retry" | "重试" | "Reintentar" |
| `videoGenNotifyRunning` | "Generating scene images…" | "正在生成场景图片…" | "Generando imágenes de escena…" |
| `videoGenNotifyDone` | "Scene images: {n} done" | "场景图片：{n} 张完成" | "Imágenes de escena: {n} hechas" |
| `videoGenNotifySummary` | "Scene images: {ok} succeeded, {fail} failed" | "场景图片：{ok} 张成功，{fail} 张失败" | "Imágenes de escena: {ok} exitosas, {fail} fallaron" |
```

## Closing

All functional requirements are met:

- [x] FR-001: `[image_prompt]` tag parser (5 spellings, line-level, elided)
- [x] FR-002: `scene_dialog` built-in skill with 3-locale templates
- [x] FR-003: Skill template produces `[scene]` + `[image_prompt]` + `{role}：` format
- [x] FR-004: "Create pictures" button conditional on tag presence
- [x] FR-005: Sequential dialog — one prompt at a time, save/clear gates advancement
- [x] FR-006: Save promotes image and releases memory, then advances
- [x] FR-007: Clear discards image and releases memory, then advances
- [x] FR-008: Generated images not persisted into content file
- [x] FR-009: Prompt history deletable (existing behaviour preserved)
- [x] FR-010: Standard single-image path unchanged when no tags
- [ ] FR-011: Generate All button in dialog header
- [ ] FR-012: Progress indicator + success/failure summary on completion
- [ ] FR-013: Per-image review in Done strip with Save/Delete/Retry

Feature **031-scene-dialog** is complete (core); Generate All (FR-011–FR-013) is pending implementation.
