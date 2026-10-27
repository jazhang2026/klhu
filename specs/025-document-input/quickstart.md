# Quickstart: how 025 is walked

**Feature**: `025-document-input` | **Plan**: [plan.md](./plan.md) | **Data model**: [data-model.md](./data-model.md)

Rows for the plan's phases, in the order they run. Every row names the **one** thing it proves, the command that
runs it, and the numbers it is expected to land on. A row that cannot fail is not a row; a number nobody took is not
evidence.

## Unit rows

### 1. The pick → read seam answers for a text document — [unit]

Test: `flutter test test/document_input_test.dart` (the seam's own table; fakes for the platform pick and the OCR).
Steps: a supported text document (TXT) yields its text; an unsupported kind is refused (FR-001); the produced text
enters the content pipeline (FR-004/SC-001).
Expected: the seam answers for the txt fixture; the refusal holds.
Proves FR-001, FR-003, FR-004, SC-001.

**State 2026-10-27**: the seam's accepted set is **TXT** — the FR-001 TXT-first cut closed this row's FR-001, and the
PDF, DOC, DOCX and EPUB kinds are the later document-extraction features' scope (breakpoint.md § What is owed, item 1).

### 2. The page/segment choice — the phone's original pages, else bounded segments — [unit]

Test: the same seam's table, on a multi-page-shaped text and on a long single-segment text.
Steps: page-shaped input → its own pages; unsegmented input → bounded segments; a final partial segment is read
like the rest (FR-002, SC-002).
Expected: the choice holds; no more than one page's text is held at a time.
Proves FR-002, SC-002.

### 3. The OCR path — a document whose text cannot be extracted — [unit]

**State 2026-10-26: NOT WALKED** — `requiresOcr()` is a predicate with its own test; nothing OCRs a document, so a
scanned page has no text to yield and this row cannot fail for the reason it was written (breakpoint.md § What is
owed 2).

**State 2026-10-27**: **PASS** (unit) — the seam's OCR functions now answer through an injected engine, so a scanned
page has text to yield and this row can fail for the reason it was written; the OCR'd text enters the content pipeline
like any other extracted text (FR-003, SC-003). The scanned document's read on device is the walk's next row (the
engine is the device's own measurement).

Test: the seam's OCR function against a scanned/picture-only input.
Steps: OCR yields the text; the OCR'd text enters the pipeline like any other extracted text (FR-003, SC-003).
Expected: the scanned document reads.
Proves FR-003, SC-003.

## Device rows

### 4. The import end to end — a real document through the seam, the read and the render — [device]

Driver: `specs/025-document-input/scripts/klhu_walk_document.py <row>` (written at the tasks stage; the plan fixed
the shape — one real document file, one read, one render). **Re-cut at the walk (2026-10-26)**: the first version
seeded the content store, which bypassed the import entirely — the driver now drives the reader's own path instead:
a real `.txt` pushed to `/sdcard/Download`, the app's own import tab, and DocumentsUI walked from its roots
(`Show roots` → `Downloads` → the file). The pick is the feature; a seeded store proves the store.
Steps: pick a real document, read it, render its video; the memory and the content behaviour on device — and, since
the reader's Q4 answer, that nothing of the document is left on disk (the app's cache holds no copy of the pick once
its bytes are read).
Expected: FR-001–FR-004 and SC-001–SC-003 on a real file.
Proves SC-001, SC-002, SC-003 (device half).

## Closing

- The closing pass re-takes the counts (tests, ARB keys, artifact checkers) and writes the receipts.
