# Quickstart: how 027 is walked

**Feature**: `027-document-extraction` | **Plan**: [plan.md](./plan.md) | **Data model**: [data-model.md](./data-model.md)

Rows for the plan's phases, in the order they run. Every row names the **one** thing it proves, the command that
runs it, and the numbers it is expected to land on. A row that cannot fail is not a row; a number nobody took is not
evidence.

## Unit rows

### 1. The extraction answers for a deferred-kind document — [unit]

Test: `flutter test test/document_input_test.dart` (the seam's own table; fakes for the platform pick and the OCR).
Steps: a deferred-kind document (PDF, DOC, DOCX, EPUB) yields its extracted text; an unextractable document reaches the
OCR answer (FR-003); the extracted text enters the content pipeline (FR-004/SC-001).
Expected: the seam answers for a deferred-kind fixture; the OCR answer holds.
Proves FR-001, FR-003, FR-004, SC-001, SC-003.

**State 2026-10-27**: **PASS** — the seam answered through the phase's own fakes: a deferred kind goes through the
platform extraction the seam grows through, the unextractable answer (the OCR functions, FR-003/Q2) holds, and the
extracted text enters the content pipeline (FR-004/SC-001). The deferred kind's own extracted text is the platform
capability's answer until that lands (Phase 1's holding answer).

### 2. The page/segment choice for an extracted document — [unit]

Test: the seam's table, on a multi-page-shaped extracted text and on a long single-segment text.
Steps: page-shaped extraction → its own pages; unsegmented extraction → bounded segments; a final partial segment is
read like the rest (FR-002, SC-002).
Expected: the choice holds; no more than one page's text is held at a time.
Proves FR-002, SC-002.

**State 2026-10-27**: **PASS** — the seam's units now have a caller in the read (the paged read the document-input
stage left in): page-shaped extraction → its own pages, unsegmented extraction → bounded segments, and a final
partial segment is read like the rest (FR-002, SC-002).

## Closing

- The closing pass re-took the counts (tests, ARB keys, artifact checkers) and writes the receipts — **2026-10-27**:
  the numbers are in [breakpoint.md](./breakpoint.md) § The structural row (T005); both unit rows **PASS** at unit
  level and the stage closed on its own numbers.
- The deferred kinds' own device walk waits on the extraction mechanism (the seam's Phase 1 holding answer); when the
  platform's own facilities land, quickstart rows 1 and 2 gain their device halves.
