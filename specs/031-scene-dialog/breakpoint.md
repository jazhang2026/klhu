# Breakpoint — 031 scene dialog, unit side

**Feature**: `031-scene-dialog` | **Build**: `flutter analyze --no-pub` on 2026-11-05 | **Driver**: manual review

**Status**: CLOSED — all tasks done; device walk on OnePlus LE2115 completed 2026-11-10 with UX/persistence revision. 1063 tests pass; `flutter analyze` clean.

One writer, one build, one file: every device row appends here, and the number that
identifies a row is the driver's own key.

> **Revision 2026-11-10 (memory fix)**: The batch dialog was reworked from a multi-image concurrent generator to a sequential single-image-at-a-time dialog. Before advancing to the next prompt, the current image must be saved or cleared so its memory is released. See [spec.md](./spec.md) for the updated requirements.
>
> **Revision 2026-11-10 (generate all + background run)**: Added "Generate All" button (FR-011–FR-013). Generate All runs as a detached background task — user may close the dialog, switch apps, or use KalaHoo reading while it continues. Progress is restored on dialog reopen; completion notifies via banner/notification. Non-intrusive messaging while reading. See [spec.md](./spec.md) Q9, FR-011–FR-012, Edge Cases.
>
> **Revision 2026-11-10 (device walk — UX, persistence, memory)**: The dialog was reworked after the OnePlus walk: browsable prompt navigator, persistent image files, Klhu-album save/delete, Save All, saved badges, and removal propagation to chosen pictures. Details below.

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

## Device-walk revision — dialog UX, persistence, memory (2026-11-10, OnePlus LE2115)

Changes landed after the physical-device walk; all verified on device
(`flutter analyze` 0 errors, `flutter test` 1063 pass).

### Navigation & states (`lib/video_image_batch_dialog.dart`)

- Replaced the forward-only cursor with a **browsable prompt navigator** `‹ n / N ›`:
  every `[image_prompt]` is reachable in scene order with Prev/Next chevrons and a
  per-prompt status icon (pending / done / failed). The redundant under-image
  "Next" button was removed — one navigator serves all states.
- `_buildManualBody` shows the viewed prompt's state: Generate button while
  pending, spinner + `aiProgressGeneratingImage` while generating, full-size
  image on success, error + Retry on failure. `_generatingIndex` guards
  re-entrant Generate taps.
- The **Recent prompts** history section was removed entirely — scene-dialog
  prompts no longer enter or display prompt history.
- `_doneItems` is kept sorted by prompt index on every insert (manual,
  Generate All, state restore); a prompt has at most one result — regeneration
  replaces, never duplicates.
- `_firstPendingIndex()` drives the empty-state fallback; when all prompts are
  done the last result stays reviewable instead of an empty body.

### Image persistence & memory

- Generated images arrive as multi-MB `data:` URIs. New top-level
  `_materializeImageUrl()` decodes them once and writes to
  `app_flutter/scene_images/` (via `getApplicationDocumentsDirectory()`); only
  the file path is kept in memory and in the SharedPreferences batch state —
  fixes both the prefs bloat and the retained-base64 memory issue. Works in
  the Generate All isolate too (`_SpawnArgs.imageDirPath`).
- `_FullSizeImage`/`_MiniThumb` handle three URL forms: `data:` (legacy),
  `http(s)` (`CachedNetworkImage`), local path (`Image.file`).
- `_downloadImageBytes` short-circuits `data:`/local paths — no HTTP fetch for
  materialized images.

### Save / Delete / Save All

- **Save** writes the `HeldPicture` into `picturesDir` (video working copy) AND
  publishes to the public `Pictures/Klhu` album through `klhu/image_files`.
- Filenames are **deterministic**: `klhu_scene_<contentHash>_<promptIndex>` —
  exactly one persisted file per scene prompt; re-saving overwrites.
- `_SuccessItem` gained `savedUri`/`savedName`, persisted in `_BatchState`;
  `_doSave` now calls `_saveState()` so the Saved status survives reopen.
- Saved results show a green **Saved ✓** chip (unsaved show the Save button)
  and a ✓ badge on their Done-strip thumbnail.
- **Save All** button (before Done) saves every unsaved success in scene
  order; hidden once all are saved; `_savingAll` is setState-guarded.
- Save advances **linearly** to the next non-empty prompt (`i+1…`), not the
  first-pending fallback that jumped to the last prompt.
- **Delete** on a saved item removes the Klhu-album file (new `delete` channel
  method), the materialized working file, and calls `onRemoved(name)` so the
  host drops the matching `HeldPicture` from chosen pictures — no stale or
  duplicated thumbnails.

### Host integration (`lib/reading_view.dart`)

- `_openBatchImageDialog` tracks `currentHeld` (the live list, since
  `onChosen` replaces it mid-session); `onRemoved` filters both pending
  `newPictures` and already-merged `held`; the close-time merge dedupes by
  name against `currentHeld`.

### Native (`android/.../ImageFileStore.kt`)

- `upsert`: overwrites the existing Klhu-album `DISPLAY_NAME` via
  `openOutputStream(uri, "wt")`, else inserts (API 29+ MediaStore; pre-Q file
  overwrite). `findAlbumUri` helper queries `DISPLAY_NAME`+`RELATIVE_PATH`.
- `delete`: removes a previously returned `content://` or `file://` URI.

### i18n & misc

- Added `aiBatchSaveAll` ("Save all" / "全部儲存" / "全部保存" / "Guardar
  todo"); removed now-unused `aiBatchNext`.
- Fixed RenderFlex right-overflow: status-row texts wrapped in `Expanded`.
- `AGENTS.md` (repo root): documents the `frontend_server` OOM crash, its
  cache-corruption root cause, and the cleanup-first rule for agents.
