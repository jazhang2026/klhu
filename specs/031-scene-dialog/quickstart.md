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

Tap it. The batch image-generation dialog opens.

**Claim**: FR-004 (button shown only when `[image_prompt]` tags exist).

### W5 — Batch dialog lists all image prompts

The dialog shows:

```
AI Provider         [dropdown: Google AI Studio (Gemini) ▼]

─────────────────────────────────
 A dark forest at night, moonlight through trees
 [Generate]

─────────────────────────────────
 A tiny mouse facing a large tiger in a forest clearing
 [Generate]
```

Each `[image_prompt]` line from the content gets its own row. Clicking a different
provider in the dropdown switches the provider for all subsequent generations.

**Claim**: FR-005 (batch dialog lists every prompt, provider selector at top).

### W6 — Generate one image, save it, see it in the picture list

Tap **Generate** on the first prompt. A spinner shows while the AI generates the image.
When complete, a thumbnail appears below the prompt with **Save** and **Delete** buttons.

Tap **Save**. The image is written into the pictures directory. The button changes to a green checkmark.

Close the dialog. Return to the Video page — the newly saved image now appears in the picture list alongside any previously chosen pictures.

**Claim**: FR-006 (per-prompt independence), FR-007 (save promotes to picture list), FR-008 (generated images not persisted into content file).

### W7 — Content without `[image_prompt]` tags has no "Create pictures" button

Open a plain story content (no scene tags, no image prompts). Go to the Video page.
Only **Choose pictures** is shown. **Create pictures** is absent.

**Claim**: FR-004 (conditional visibility), FR-010 (standard single-image path unchanged).

## Edge cases verified

| case | what was checked |
|---|---|
| No `[image_prompt]` tags | "Create pictures" button hidden |
| Image generation fails for one prompt | That row shows error text; other rows unaffected |
| Empty image prompt text | No row produced for empty prompt |
| Provider switch mid-batch | Switching resets pending state; in-flight generations continue |
| Saving a generated image | Image promoted to picture list; content file untouched |

## Metrics

```
flutter analyze --no-pub                              → No issues found!
flutter test --concurrency=2                          → +1061: All tests passed!
New unit tests: 14 (test/image_prompt_tag_test.dart)
Updated tests: 2 (test/ai_skill_test.dart)
New lib files: 2 (lib/image_prompt_tag.dart, lib/video_image_batch_dialog.dart)
New skill: scene_dialog (with EN/ZH/ES templates)
i18n keys added: 1 (videoCreatePicturesButton) across 4 locales
```

## Closing

All functional requirements are met:

- [x] FR-001: `[image_prompt]` tag parser (5 spellings, line-level, elided)
- [x] FR-002: `scene_dialog` built-in skill with 3-locale templates
- [x] FR-003: Skill template produces `[scene]` + `[image_prompt]` + `{role}：` format
- [x] FR-004: "Create pictures" button conditional on tag presence
- [x] FR-005: Batch dialog with per-prompt generate/save/delete
- [x] FR-006: Independent per-prompt generation
- [x] FR-007: Save promotes image to picture list
- [x] FR-008: Generated images not persisted into content
- [x] FR-009: (Prompt history deletable — existing behaviour preserved)
- [x] FR-010: Standard single-image path unchanged when no tags

Feature **031-scene-dialog** is complete.
