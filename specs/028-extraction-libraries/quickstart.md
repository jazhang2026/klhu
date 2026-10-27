# Quickstart: how 028 is walked

**Feature**: `028-extraction-libraries` | **Plan**: [plan.md](./plan.md)

Rows for the plan's phases, in the order they run. Every row names the **one** thing it proves, the command that
runs it, and the numbers it is expected to land on. A row that cannot fail is not a row; a number nobody took is not
evidence.

## Unit rows

### 1. PDF extraction — a PDF yields its text — [unit]

Test: `flutter test test/pdf_extractor_test.dart`.
Steps: pass bytes of a PDF to `PdfExtractor`; it returns the extracted text (or empty on failure).
Expected: the extractor routes by kind, returns empty for non-PDF, handles malformed bytes gracefully.
Proves FR-001, FR-006.

### 2. DOCX extraction — a DOCX yields its text — [unit]

Test: `flutter test test/docx_extractor_test.dart`.
Steps: pass bytes of a DOCX to `DocxExtractor`; it returns the extracted text (or empty on failure).
Expected: the extractor routes by kind, returns empty for non-DOCX, handles malformed bytes gracefully.
Proves FR-002, FR-006.

### 3. EPUB extraction — an EPUB yields its text chapter by chapter — [unit]

Test: `flutter test test/epub_extractor_test.dart`.
Steps: pass bytes of an EPUB to `EpubExtractor`; it returns the extracted text from all sections (or empty on failure).
Expected: the extractor routes by kind, returns empty for non-EPUB, handles malformed bytes gracefully; text is plain
text (no HTML markup leaking into reading content).
Proves FR-003, FR-006.

### 4. OCR engine — an image yields its text via native OCR — [unit]

Test: `flutter test test/native_ocr_engine_test.dart`.
Steps: pass image bytes to `NativeOcrEngine`; it returns the recognized text (or empty on failure).
Expected: the engine handles empty and malformed bytes gracefully.
Proves FR-004, FR-006.

### 5. Integration — the seam routes by kind without an injected extractor — [unit]

Test: `flutter test test/document_input_test.dart` (the seam's own table).
Steps: call `extractText` with a deferred-kind byte blob and no injected extractor; the seam's `defaultExtractor`
routes to the right library; `requiresOcr` fires for a scanned PDF.
Expected: PDF → PdfExtractor, DOCX → DocxExtractor, EPUB → EpubExtractor, unextractable PDF → NativeOcrEngine.
Proves FR-001, FR-002, FR-003, FR-005, FR-006.

### 6. Temp-file cleanup after extraction — [unit]

Test: `flutter test test/pdf_extractor_test.dart` (the extractor's temp file is deleted in finally).
Steps: extract from a malformed PDF; confirm the temp file is gone afterwards.
Expected: no stray temp files remain after extraction (FR-007).
Proves FR-007.

## Closing

- The closing pass re-takes the counts (tests, ARB keys, artifact checkers) and writes the receipts in `breakpoint.md`.
