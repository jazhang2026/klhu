# Breakpoint: Google Drive document input (026)

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28

**Status**: Stub implementation committed (2026-10-28). Native half for `readContentUri()`
not yet implemented. Full Drive import walk blocked.

## What is owed

1. **Android native half for `readContentUri()`** — a method channel in
   `android/src/main/kotlin/...` that calls `ContentResolver.openInputStream(uri)` and
   reads the stream into a `Uint8List`. Until this lands, `readContentUri()` returns empty
   bytes and Drive imports fail gracefully (same as current behaviour).
2. **Device walk on a signed-in device** — the emulator has `com.google.android.apps.docs`
   installed but no signed-in Google account, so DocumentsUI does not surface the Drive
   root. A real device (or emulator with a Google account) is needed for the full import
   walk.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — content:// read fallback | **NOT WALKED** (stub) | `burnCachedCopy` content:// no-op verified in unit test; `readContentUri` returns empty bytes (stub) — integration awaits native half |
| 2 — imported Drive content is ordinary | **NOT WALKED** (no Drive account) | Google Drive app installed on emulator but no signed-in account; DocumentsUI does not surface the Drive root |
| structural | **PASS** | `flutter analyze` clean; 934 tests; app_en 176 keys; all six checkers green |

## The structural row

```
flutter analyze                          → No issues found! (ran in 1.6s)
flutter test --concurrency=2             → 934 tests, All tests passed!
ARB keys                                 → app_en 176  app_zh 140  app_zh_Hans 140  app_es 140
check_tasks_format.py                    → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                         → 5 tasks, 5 done, 0 [P]
check_row_coverage.py                    → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py             → 7 FR + 5 SC defined | 2 rows ([unit] 2, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                      → no divergence
check_artifact_refs.py                   → no unresolved references
```

## Findings the reviewer must weigh

### F1 — `readContentUri()` is a stub

The Dart-side fallback is wired correctly: when `file.readAsBytes()` returns empty for a
`content://` URI, `readContentUri(file.path)` is called. The function currently returns
`Uint8List(0)` (TODO). The native half — a method channel calling
`ContentResolver.openInputStream(uri)` — is the remaining work. Without it, Drive files
flow through to `extractText` as empty bytes and the app shows "No text could be extracted"
(same as current behaviour for unreadable files).

### F2 — No signed-in Google account on this emulator

`adb shell pm list packages | grep com.google.android.apps.docs` confirms the Drive app
is installed, but `adb shell dumpsys account | grep -i "Account"` shows zero accounts.
DocumentsUI does not surface the Drive root without a signed-in account. A full import
walk requires either a real device with a signed-in Drive account or an emulator configured
with one.

### F3 — ARB key count change

app_en grew from 139 to 176 keys; app_zh/app_es/app_zh_Hans remain at 140. This is
unrelated to 026 (no new UI strings added) and likely reflects prior merges; no i18n
impact.
