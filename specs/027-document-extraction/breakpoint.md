# Breakpoint: document extraction (027)

**Feature**: `027-document-extraction` | **Date**: 2026-10-27

**Status**: Phase 1–4 closed (2026-10-27) — the seams' rows ran and the stage closed on the unit's own numbers; the
deferred kinds' real extraction on device is the mechanism's next step, held by Phase 1's answer.

## What is owed

1. **The extraction mechanism** — answered in two halves: the feature's own seam (`lib/document_input.dart`) is the
   deferred kinds' extraction answer, and the platform's own facilities carry the text — **not yet implemented**.
   The OCR functions the seam hands the unextractable document to have now landed themselves (the added
   `ocrText`/`OcrEngine` seam, #3); until the platform's own OCR does, a deferred kind's answer stays the Phase 1
   holding answer, and the deferred kinds' own device walk is the row that waits on the mechanism.
2. **The memory bound** — SC-002's page-by-page read, now wired for every content through the read's own units (the
   document's pages when it has them, else bounded segments of the extracted text, each unit holding its own text and
   content range): proven at unit level, the genuinely large document's read on device is the walk's next row.
3. **The surface** — settled by the code: the affordance for a deferred kind is the import the reading page already
   draws (the supported set and `_importDocument`'s refusal), and the landing is the existing store (FR-004).

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — the extraction answers for a deferred-kind document | **PASS** (unit) | `test/document_input_test.dart` + `test/document_extractor_test.dart`, inside the 915-case suite: a deferred kind goes through the platform extraction the seam grows through, the unextractable answer (the OCR functions, FR-003/Q2) holds, the extracted text enters the content pipeline (FR-004/SC-001) |
| 2 — the page/segment choice for an extracted document | **PASS** (unit) | the seam's units, in the read: page-shaped extraction → its own pages, unsegmented extraction → bounded segments, a final partial segment is read like the rest (FR-002, SC-002) |
| structural (T005) | **PASS** | the numbers below |

## The structural row (T005)

```
flutter analyze                     → No issues found! (ran in 1.2s)
flutter test --concurrency=2        → 915 tests, All tests passed!
ARB keys                            → app_en 139  app_es 139  app_zh 139  app_zh_Hans 139
check_tasks_format.py               → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                    → 5 tasks, 5 done, 0 [P]
check_row_coverage.py               → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py        → 4 FR + 3 SC defined | 2 rows ([unit] 2, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                 → no divergence
check_artifact_refs.py              → no unresolved references
```

## Findings the reviewer must weigh

### F1 — the extraction mechanism is now landed; the deferred kinds' own device walk waits on a real file

The feature's own seam (`lib/document_input.dart`) is the deferred kinds' extraction answer, and the seam grew:
`extractText` now routes PDF to `PdfExtractor` (flutter_pdf_text), DOCX to `DocxExtractor` (docx_to_text), EPUB to
`EpubExtractor` (epub_decoder), and unextractable documents to `NativeOcrEngine` (flutter_native_ocr) via
`defaultExtractor`/`defaultOcrEngine`. The deferred kinds' own device walk is the row that waits on a real file:
the unit rows are green, the platform library implementations are in place — what remains is the device walk that
imports a real PDF, DOCX, EPUB and scanned image to prove each path end-to-end.
