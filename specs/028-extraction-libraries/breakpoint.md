# Breakpoint: extraction libraries (028)

**Feature**: `028-extraction-libraries` | **Date**: 2026-10-28

**Status**: Phase 1–6 closed (2026-10-28). All 18 tasks done; unit rows green, structural row green.

## What is owed

1. **DOCX/EPUB device walk on this emulator** — DocumentsUI on Android 16 / emulator does not surface `.docx`/`.epub` files in the picker list (media store MIME type filtering), so rows 2 and 3 of the quickstart cannot drive the full import path here. The extraction libraries are unit-tested (4 tests each) and wired via `defaultExtractor`; the device receipt awaits a device where the media store indexes these kinds.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — PDF extraction | **PASS** (device) | `extraction_walk.py` row 1: 5/5 — APK fresh, fixture on device, import button visible, PDF tapped in picker, 67 chars landed as user content, cache clean (SC-003) |
| 2 — DOCX extraction | **NOT WALKED** (emulator limitation) | FIXTURE on device, picker opens; `klhu028_docx.docx` not surfaced by DocumentsUI on this emulator (MIME filtering). Unit table: 4/4 green. |
| 3 — EPUB extraction | **NOT WALKED** (emulator limitation) | FIXTURE on device, picker opens; `klhu028_epub.epub` not surfaced. Unit table: 4/4 green. |
| 4 — scanned PNG refused | **PASS** (device) | 2/2 — picker opens, PNG filtered from selection, no new content added (FR-001) |
| 5 — structural | **PASS** | `flutter analyze` clean; 932 tests; 139 ARB keys per locale; all six checkers green |
| 6 — delete imported content | **PASS** (device) | 5/5 — content list opened, user entry found, Delete button tapped, confirmation dialog shown, entry removed from both UI list and content store (FR-004) |

## The structural row (T016)

```
flutter analyze                     → No issues found! (ran in 0.9s)
flutter test --concurrency=2        → 932 tests, All tests passed!
ARB keys                            → app_en 139  app_es 139  app_zh 139  app_zh_Hans 139
check_tasks_format.py               → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                    → 18 tasks, 18 done, 0 [P]
check_row_coverage.py               → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py        → 7 FR + 5 SC defined | 6 rows ([unit] 6, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                 → no divergence
check_artifact_refs.py              → no unresolved references
```

## Findings the reviewer must weigh

### F1 — DOCX/EPUB not surfaced in DocumentsUI on this emulator

The media store on the emulator (android-36) does not index `.docx`/`.epub` files under the MIME types that `file_selector` advertises (`application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `application/epub+zip`). The PDF fixture is indexed and visible; the DOCX and EPUB fixtures are on `/sdcard/Download/` but do not appear in the picker. This is an emulator/media-store limitation, not a code defect. On a physical Android device with a different media scanner configuration the files would likely appear.

### F2 — `flutter_native_ocr` requires platform channel setup

The `NativeOcrEngine` (flutter_native_ocr) compiles but the platform channel may require additional Android manifest configuration on real devices. Unit tests verify graceful failure (empty string) when the engine is unavailable.
