# Breakpoint — 031 scene dialog, unit side

**Feature**: `031-scene-dialog` | **Build**: `flutter analyze --no-pub` on 2026-11-05 | **Driver**: manual review

One writer, one build, one file: every device row appends here, and the number that
identifies a row is the driver's own key.

> **Revision 2026-11-10 (memory fix)**: The batch dialog was reworked from a multi-image concurrent generator to a sequential single-image-at-a-time dialog. Before advancing to the next prompt, the current image must be saved or cleared so its memory is released. See [spec.md](./spec.md) for the updated requirements.
>
> **Revision 2026-11-10 (generate all + background run)**: Added "Generate All" button (FR-011–FR-013). Generate All runs as a detached background task — user may close the dialog, switch apps, or use KalaHoo reading while it continues. Progress is restored on dialog reopen; completion notifies via banner/notification. Non-intrusive messaging while reading. See [spec.md](./spec.md) Q9, FR-011–FR-012, Edge Cases.

## What landed before the walk (unit side)

```
flutter analyze --no-pub                              → No issues found! (0.8 s)
flutter test --concurrency=2                          → +1061: All tests passed! (1:25)
grep -cE '^  "[\^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 136 136 136 136   (was 135)
ls test/*.dart | wc -l                                → 66   (was 65: test/image_prompt_tag_test.dart)
ls lib/*.dart | wc -l                                 → 33   (was 32: lib/image_prompt_tag.dart, lib/video_image_batch_dialog.dart)
```

The feature's own rows are **14** of the 1061 (14 in `test/image_prompt_tag_test.dart`, 2 updated in `test/ai_skill_test.dart`); the baseline 1045 are untouched.

```
check_tasks_format.py   specs/031-scene-dialog   → OK: format, sequencing and spec-id coverage check out
task_id_audit.py        specs/031-scene-dialog   → 11 tasks, 9 done, 2 [P]      (before the ticks below)
check_row_coverage.py   specs/031-scene-dialog   → quickstart 0 rows claim 0 of ?; no row claims: none
check_quickstart_coverage.py specs/031-scene-dialog → 0 rows ([unit] 0, [device] 0); unclaimed: none
```

## Unit tests — `test/image_prompt_tag_test.dart` (14 rows)

| row | group | what it measures |
|---|---|---|
| 1 | `isImagePromptSpelling` | recognises all four spellings, case-insensitive |
| 2 | `isImagePromptSpelling` | rejects unknown spellings |
| 3 | `imagePromptTagsOf` | finds one tag on its own line |
| 4 | `imagePromptTagsOf` | finds multiple tags |
| 5 | `imagePromptTagsOf` | skips tags inside comments |
| 6 | `imagePromptTagsOf` | empty text returns empty list |
| 7 | `imagePromptTagsOf` | no tag line returns empty list |
| 8 | `imagePromptTagsOf` | spelling is stored as written |
| 9 | `SceneWithPrompt` | pairs scene with its image prompt |
| 10 | `SceneWithPrompt` | scene without image prompt has null prompt |
| 11 | `SceneWithPrompt` | orphaned image prompt (before any scene) is skipped |
| 12 | `imagePromptMasked` | replaces tag line with spaces, keeps other text |
| 13 | `imagePromptMasked` | empty text returns empty string |
| 14 | `scenesWithPromptsOf` | convenience function pairs scenes with prompts |

All 14 pass.

## Updated unit tests — `test/ai_skill_test.dart` (2 rows updated)

| row | group | change |
|---|---|---|
| `load returns built-in skills when nothing stored` | `AISkillStore` | expects 4 skills (was 3), checks for `scene_dialog` id |
| `load merges custom skills with built-ins` | `AISkillStore` | expects 5 skills (was 4) |

Both pass.

## i18n keys added

```
videoCreatePicturesButton  →  EN: "Create pictures"  ZH: "创建图片"  ES: "Crear imágenes"
```

All four ARB files and all four generated Dart localization files carry the key.

## Files changed

| file | action |
|---|---|
| `lib/image_prompt_tag.dart` | new — tag parser, 5 spellings, elision, scene pairing |
| `lib/video_image_batch_dialog.dart` | new — sequential single-image dialog widget; **T005b extends** with detached background execution (Generate All), progress restoration on reopen, and non-intrusive notifications while reading/switching apps |
| `lib/ai/skill_store.dart` | modified — added `scene_dialog` built-in skill |
| `lib/reading_view.dart` | modified — import, "Create pictures" button, `_openBatchImageDialog` |
| `lib/l10n/app_*.arb` | modified — added `videoCreatePicturesButton` |
| `lib/l10n/app_localizations*.dart` | modified — added getter |
| `test/image_prompt_tag_test.dart` | new — 14 unit tests |
| `test/ai_skill_test.dart` | modified — updated counts |

## What this breakpoint does not measure

- The visual layout of the sequential dialog on device (prototype and measure on physical device).
- The actual image-generation flow end-to-end (provider connectivity, latency).
- The scene_dialog skill's output quality in the AI prompt dialog.
- i18n of the dialog widget itself (strings are currently literal English).
- Memory profiling across many scenes (≥ 8) on low-RAM devices to confirm OOM is resolved.

These are device-side items for the quickstart walk.
