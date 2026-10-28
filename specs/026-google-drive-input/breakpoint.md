# Breakpoint: Google Drive document input (026)

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28

**Status**: Native half implemented and compiled (2026-10-28). Device walk partial.

## What is owed

1. **End-to-end Drive import walk** — requires a `.docx`/`.txt`/`.pdf` file uploaded to
   Google Drive. The current Drive account (`jazhang2026@gmail.com`) only has Google Docs
   format files (`application/vnd.google-apps.document`) which are filtered out by the
   picker's MIME type filter. Uploading a real document file to Drive and re-running the
   walk will verify the ContentResolver path.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — content:// read fallback | **PASS** (unit + stub) | `readContentUri()` calls `klhu/document_picker` / `readContentUri`; Kotlin plugin compiles and registers; unit tests verify mock path (3/3 green) |
| 2 — imported Drive content is ordinary | **PARTIAL** (local regression) | Local TXT import verified end-to-end on phone: `test_local.txt` (76 chars) imported, appeared in content store as `c_1793209741127_0b9d`, readable in UI. Full Drive path blocked by MIME filter. |
| structural | **PASS** | `flutter analyze` clean; 937 tests; app_en 176 keys; all six checkers green; Kotlin BUILD SUCCESSFUL |

## The structural row

```
flutter analyze                          → No issues found! (ran in 1.5s)
flutter test --concurrency=2             → 937 tests, All tests passed!
ARB keys                                 → app_en 176  app_zh 140  app_zh_Hans 140  app_es 140
check_tasks_format.py                    → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                         → 5 tasks, 5 done, 0 [P]
check_row_coverage.py                    → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py             → 7 FR + 5 SC defined | 2 rows ([unit] 2, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                      → no divergence
check_artifact_refs.py                   → no unresolved references
```

## Findings the reviewer must weigh

### F1 — Native ContentResolver implementation complete

`ContentUriReaderPlugin.kt` implements the Android half: receives a `content://` URI
string via method channel `klhu/document_picker` / `readContentUri`, opens an
`InputStream` through `ContentResolver.openInputStream(uri)`, reads all bytes into a
`ByteArray`, and returns it to Dart. Registered in `MainActivity.configureFlutterEngine`
with the app's `contentResolver`. Kotlin compiles clean (BUILD SUCCESSFUL).

### F2 — Local import verified end-to-end on device

Pushed `test_local.txt` to `/sdcard/Download/`, imported through the app's Import button
→ DocumentsUI picker → Download folder → file selected → text appeared in content list
("This is a test document from local storage for KalaHoo Reading app testing.", 76 chars).
Content store entry created: `c_1793209741127_0b9d`. This confirms the full import pipeline
(local path → readAsBytes → extractText → saveImported) works on the connected device.

### F3 — Google Drive import blocked by MIME filter

The Drive account `jazhang2026@gmail.com` contains only Google Docs format files
(`application/vnd.google-apps.document`): "凡人修行小说大纲构思" (5.85 kB), "归真 - 剧本"
(4.94 kB), "长篇小说：归真" (349 kB). These do not match the picker's accepted MIME types
(`application/pdf`, `application/msword`, `text/plain`, `application/epub+zip`,
`application/vnd.openxmlformats-officedocument.wordprocessingml.document`), so they appear
as disabled/unselectable in DocumentsUI. Uploading a real `.docx`/`.txt`/`.pdf` to Drive
and re-running the walk will verify the ContentResolver fallback.

### F4 — ARB key count unchanged from prior

app_en 176, app_zh/app_es/app_zh_Hans 140 — no new UI strings added by this feature.
