# Tasks: extraction libraries

**Feature**: `028-extraction-libraries` | **Date**: 2026-10-27
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (PDF extraction), `US2` (DOCX extraction), `US3` (EPUB extraction), `US4` (OCR).

Rows with no story label are the shared core, the walk, or the closing.

## Status

**IN PROGRESS — 13 of 18 tasks done** (2026-10-27). Phase 1–4 complete: all four platform extractors implemented and tested.
Phase 5 in progress: T013 integration done (defaultExtractor/defaultOcrEngine wire the four libraries into the seam);
T014–T015 (device walk + receipts) remain.

## Grounding notes (the decisions these tasks implement)

- **D1** each extractor implements the 027 seam (`DocumentExtractor` or `OcrEngine`)
- **D2** the libraries are the specialized ones from research §4: flutter_pdf_text, docx_to_text, epub_decoder, flutter_native_ocr
- **D3** PDF and EPUB support page/chapter extraction (Q1 from 027)
- **D4** OCR handles scanned documents and images (Q2 from 027)
- **D5** temporary files are deleted immediately after extraction (FR-007)

## Path conventions

- Unit rows write tests under `test/` and source under `lib/platform/`; a row's first line names the file it touches.
- Device rows cite real document files and OCR test files; evidence lands in `breakpoint.md`.

## Phase 1: PDF extraction

**Goal**: `lib/platform/pdf_extractor.dart` implements `DocumentExtractor` for PDF files using `flutter_pdf_text`, with page-by-page extraction support.

- [x] T001 [US1] `pubspec.yaml`: add `flutter_pdf_text: ^0.9.0` dependency.
- [x] T002 [US1] `lib/platform/pdf_extractor.dart`: the PDF extractor — implements `DocumentExtractor`, extracts text page by page using flutter_pdf_text, handles encrypted PDFs (rejects with error).
- [x] T003 [US1] `test/pdf_extractor_test.dart`: the PDF extractor's test table — fakes for flutter_pdf_text, page-by-page extraction, encrypted PDF rejection, graceful failure.

## Phase 2: DOCX extraction

**Goal**: `lib/platform/docx_extractor.dart` implements `DocumentExtractor` for DOCX files using `docx_to_text`.

- [x] T004 [US2] `pubspec.yaml`: add `docx_to_text: ^1.0.1` dependency (2.1.1 doesn't exist).
- [x] T005 [US2] `lib/platform/docx_extractor.dart`: the DOCX extractor — implements `DocumentExtractor`, extracts text using docx_to_text, handles malformed DOCX files (rejects with error).
- [x] T006 [US2] `test/docx_extractor_test.dart`: the DOCX extractor's test table — fakes for docx_to_text, successful extraction, graceful failure.

## Phase 3: EPUB extraction

**Goal**: `lib/platform/epub_extractor.dart` implements `DocumentExtractor` for EPUB files using `epub_decoder`, with chapter/section support.

- [x] T007 [US3] `pubspec.yaml`: add `epub_decoder: ^0.1.4` dependency.
- [x] T008 [US3] `lib/platform/epub_extractor.dart`: the EPUB extractor — implements `DocumentExtractor`, extracts text chapter by chapter using epub_decoder, handles malformed EPUB files (rejects with error).
- [x] T009 [US3] `test/epub_extractor_test.dart`: the EPUB extractor's test table — fakes for epub_decoder, chapter-by-chapter extraction, graceful failure.

## Phase 4: OCR engine

**Goal**: `lib/platform/native_ocr_engine.dart` implements `OcrEngine` using `flutter_native_ocr`.

- [x] T010 [US4] `pubspec.yaml`: add `flutter_native_ocr: ^0.1.0` dependency.
- [x] T011 [US4] `lib/platform/native_ocr_engine.dart`: the OCR engine — implements `OcrEngine`, recognizes text from images using flutter_native_ocr, handles unrecognizable images (returns empty string).
- [x] T012 [US4] `test/native_ocr_engine_test.dart`: the OCR engine's test table — fakes for flutter_native_ocr, successful recognition, graceful failure.

## Phase 5: Integration and device walk

**Goal**: the extractors are wired into the seam, and a device walk proves each format imports and extracts.

- [x] T013 `lib/document_input.dart`: wire the extractors into the seam — provide default implementations for `DocumentExtractor` (routes by kind to PdfExtractor/DocxExtractor/EpubExtractor) and `OcrEngine` (NativeOcrEngine).
- [ ] T014 `specs/028-extraction-libraries/scripts/extraction_walk.py`: the device walk driver — import real PDF, DOCX, EPUB files and verify extraction; import a scanned PDF or image and verify OCR.
- [ ] T015 `specs/028-extraction-libraries/breakpoint.md`: walk receipts — the extraction results, OCR results, memory usage (SC-002), temporary file cleanup (SC-005).

## Phase 6: Closing pass

**Goal**: the stage is closed on its own numbers.

- [ ] T016 `specs/028-extraction-libraries/breakpoint.md`: the structural row — `flutter analyze`, the suite's count, the ARB keys, the artifact checkers.
- [ ] T017 `specs/028-extraction-libraries/spec.md`: write the walk's measured figures back into SC-001–SC-005's own sentences.
- [ ] T018 `specs/028-extraction-libraries/checklists/requirements.md`: the checklist's stage notes — what landed, what is owed, and each requirement read against the row that claimed it.

## Dependencies & ordering

- T001 → T002 → T003: PDF dependency, then implementation, then tests
- T004 → T005 → T006: DOCX dependency, then implementation, then tests
- T007 → T008 → T009: EPUB dependency, then implementation, then tests
- T010 → T011 → T012: OCR dependency, then implementation, then tests
- T001–T012 → T013: all extractors must exist before integration
- T013 → T014 → T015: integration before walk, walk before receipts
- T015 → T016 → T017 → T018: receipts before closing

## Parallel opportunities

- **T001, T004, T007, T010 with each other**: dependency additions to pubspec.yaml are independent.
- **T002, T005, T008, T011 with each other**: extractor implementations are independent files.
- **T003, T006, T009, T012 with each other**: test tables are independent files.
- **Not parallel**: T002 → T003 (implementation before its test), T005 → T006, T008 → T009, T011 → T012.

## Implementation strategy

- The MVP is the first two phases (PDF + DOCX extraction), as they are the most common formats.
- Then EPUB extraction (less common but still important).
- Then OCR (enables scanned documents).
- Then integration and device walk to prove it works end-to-end.
- Finally the closing pass.

## Notes

- `flutter analyze` after every file; `flutter test --concurrency=2` at each phase boundary.
- The tree's current count is 915 tests (027's baseline); this feature's rows are **added**, and the closing pass states the new number.
- Each extractor is responsible for cleaning up temporary files (FR-007) immediately after extraction.

## Requirement coverage

|| requirement | tasks |
||---|---|
|| FR-001 (PDF extraction with page-by-page) | T001, T002, T003, T013 |
|| FR-002 (DOCX extraction) | T004, T005, T006, T013 |
|| FR-003 (EPUB extraction with chapters) | T007, T008, T009, T013 |
|| FR-004 (OCR using flutter_native_ocr) | T010, T011, T012, T013 |
|| FR-005 (integration into 027's seams) | T013 |
|| FR-006 (graceful failure handling) | T002, T005, T008, T011 |
|| FR-007 (temporary file cleanup) | T002, T005, T008, T011, T015 |
|| SC-001 (PDF imports and extracts) | T002, T003, T014, T015 |
|| SC-002 (DOCX imports and extracts) | T005, T006, T014, T015 |
|| SC-003 (EPUB imports and extracts) | T008, T009, T014, T015 |
|| SC-004 (OCR on scanned docs/images) | T011, T012, T014, T015 |
|| SC-005 (no local copy survives) | T015 |
