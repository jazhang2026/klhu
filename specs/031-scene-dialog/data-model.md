# Data model: Scene dialog (031)

**Feature**: `031-scene-dialog` | **Spec**: [spec.md](./spec.md)

## §1 `[image_prompt]` tag — derived, not stored

The `[image_prompt]` tag is parsed on every open, just like `[scene]` and `[comment]`. It carries no persisted state. The parser in `lib/image_prompt_tag.dart` (new) produces a list of `ImagePromptTag` objects, each with:

| field | meaning |
|---|---|
| `spelling` | the exact spelling as written — `image_prompt`, `图像提示`, `imagem`, or `prompt_img` |
| `start` | offset of the opening `[` |
| `tagEnd` | offset just past the closing `]` |
| `contentStart` | offset of the first character of the prompt text (after the tag, separator, and spaces) |

The tag is elided from reading (never spoken, never highlighted) and from video display (never painted on screen), following the same rule as `[scene]` and `[comment]`.

## §2 Scene composition

A **scene** in a scene-dialog content is the span from one `[scene]` line to the next `[scene]` line (or EOF). It comprises:

1. The `[scene]` heading line (parsed by `lib/scene_tag.dart`)
2. One or more dialog paragraphs (parsed by `lib/dialogue.dart` if in dialogue mode)
3. An optional `[image_prompt]` line at the end (parsed by `lib/image_prompt_tag.dart`)

The scene tag parser is extended to return, for each scene, the associated `ImagePromptTag?` (null if no prompt line follows the scene's dialog).

## §3 `AISkill.scene_dialog`

The scene_dialog skill is a built-in `AISkill` entry in `lib/ai/skill_store.dart` with:
- `id: 'scene_dialog'`
- `localizedNames`: `{'en': 'Scene Dialog', 'zh': '场景对话', 'es': 'Diálogo de escenas'}`
- `localizedDescriptions`: per-locale one-liners
- `template`: EN prompt instructing the AI to produce `[scene]` headings, `[image_prompt]` lines, and `{role}：` dialog
- `localizedTemplates`: ZH and ES versions of the same template

## §4 What is not stored

The image prompts themselves are not persisted in SharedPreferences. Only the generated images (once promoted via the picture assignment flow) survive app restarts. The scene_dialog skill's template is stored in source code, not in prefs.
