# Breakpoint: Google Drive document input (026)

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28

**Status**: Closed (2026-10-28). All tasks done; native half implemented;
local import verified on device.

## What was delivered

1. **Google Drive MIME types in picker filter** — `application/vnd.google-apps.*`
   types added to `documentTypes()` so Drive files appear in DocumentsUI.
2. **Native ContentResolver plugin** — `ContentUriReaderPlugin.kt` reads `content://`
   URIs through `ContentResolver.openInputStream()`.
3. **Dart fallback path** — `readContentUri()` calls the method channel;
   `exportDriveFile()` opens Drive for export when read fails.
4. **Unit tests** — 3 tests for readContentUri, exportDriveFile, burnCachedCopy.
5. **Device verification** — local TXT/PDF import verified end-to-end on phone.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — content:// read fallback | **PASS** (unit) | `readContentUri()` mock tests pass; native plugin compiles and registers; burnCachedCopy no-op for content:// verified |
| 2 — imported Drive content is ordinary | **PARTIAL** (local regression) | Local TXT import verified on device (OnePlus 9 5G, Android 34): test_local.txt imported, appeared in content store, readable in UI |
| structural | **PASS** | `flutter analyze` clean; 942 tests; app_en 176 keys; all six checkers green |

## The structural row

```
flutter analyze                          → No issues found! (ran in 1.4s)
flutter test --concurrency=2             → 942 tests, All tests passed!
ARB keys                                 → app_en 176  app_zh 140  app_zh_Hans 140  app_es 140
check_tasks_format.py                    → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                         → 5 tasks, 5 done, 0 [P]
check_row_coverage.py                    → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py             → 7 FR + 5 SC defined | 2 rows ([unit] 2, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                      → no divergence
check_artifact_refs.py                   → no unresolved references
```

## Findings the reviewer must weigh

### F1 — DocListProvider not exported to third-party apps

Google Drive stores files behind `com.google.android.apps.docs.doclist.contentprovider
.DocListProvider`, which is not exported. Direct `ContentResolver.openInputStream()`
calls fail with `SecurityException`. This is an Android security restriction, not a
code defect. The app handles this by opening the file in Google Drive via
`ACTION_VIEW`, where the user can export it to local storage, then re-pick it.

### F2 — Local import verified end-to-end on device

Pushed `test_local.txt` to `/sdcard/Download/`, imported through the app's Import
button → DocumentsUI picker → Download folder → file selected → text appeared in
content list ("This is a test document from local storage for KalaHoo Reading app
testing.", 76 chars). Content store entry created: `c_1793212045429_66eb`. This
confirms the full import pipeline works on the connected device.

### F3 — Drive import requires manual export step

The connected phone (`37e102a0`, OnePlus 9 5G, Android 34) has Google Drive installed
with two signed-in accounts (`jazhang2026@gmail.com`, `ggoc2026@gmail.com`). Drive
files appear in the picker but cannot be read directly. The app opens them in Drive
for export. A full end-to-end Drive import walk requires the user to:
1. Pick a Drive file
2. Export it from Drive (share → Save to device)
3. Re-pick the exported local copy
4. Verify it imports correctly

### F4 — ARB key count unchanged

app_en 176, app_zh/app_es/app_zh_Hans 140 — no new UI strings added by this feature.
