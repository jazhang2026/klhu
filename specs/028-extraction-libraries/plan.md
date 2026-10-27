# Implementation Plan: extraction libraries

**Feature**: `028-extraction-libraries` | **Spec**: [spec.md](./spec.md) | **Research**: research supplemented in 027

**Input**: follow-up to 025/027 — the reader's deferred document kinds (PDF, DOC, DOCX, EPUB) need their text extraction mechanisms, and OCR for scanned documents. The spec names the libraries: flutter_pdf_text (PDF), docx_to_text (DOCX), epub_decoder (EPUB), flutter_native_ocr (OCR).

## What this plan builds, in one paragraph

The **platform-library implementations** that 027's injectable seams call: four concrete extractors (PDF, DOCX, EPUB, OCR) that plug into the `DocumentExtractor` and `OcrEngine` interfaces. Each extractor is a self-contained implementation using its chosen battle-tested library, with page-by-page extraction where the format supports it, graceful failure handling, and immediate cleanup of temporary files. The plan adds four new platform-specific dependencies, wires them into the existing seam, and proves each works through unit tests.

## Technical Context

**Language/Version**: Dart (SDK `^3.13.3`), Flutter (Material 3), the existing `flutter_tts` engine.

**Primary Dependencies** (new for this feature):
- `flutter_pdf_text: ^0.9.0` — PDF extraction (Apache PdfBox on Android, Apple PDFKit on iOS)
- `docx_to_text: ^2.1.1` — DOCX extraction (pure Dart)
- `epub_decoder: ^0.1.4` — EPUB extraction (pure Dart)
- `flutter_native_ocr: ^0.1.0` — OCR (Apple Vision on iOS, Google ML Kit on Android)

**Existing Dependencies**: the reader's own `file_selector` surface, `flutter_tts` / `path_provider` for the engine and content directory.

**Storage**: the content store's own file-per-content + versioned `index.json` (008) — extracted text lands as a **user** content, loadable, savable, editable, deletable and readable exactly like hand-written content.

**Testing**: `flutter test` unit rows against each extractor with fakes for the underlying libraries; device walk rows on `emulator-5554` for OCR and real file extraction.

**Target Platform**: Android (validated), iOS (untested — no macOS on the dev host; the libraries support both).

**Performance Goals**: extraction completes within a reasonable timeout (10s for typical documents); page-by-page memory bound (SC-002) is inherited from 027's seam.

**Constraints**: one Flutter codebase (constitution I); on-device first (IV); simplicity/YAGNI (V — specialized libraries over monolithic); iOS 16+ / Android 10+ (API 29+) baseline.

**Scale/Scope**: typical documents (PDF, DOCX, EPUB); OCR for scanned documents and images.

## Constitution Check

- **I. Flutter Single Codebase**: PASS — the extractors are Dart wrappers around platform plugins; platform code stays under `lib/platform/`.
- **II. Spec-Driven**: PASS — spec 028 names the libraries and the FRs; no implementation without it.
- **III. Test-First**: PASS — the phases below are test-first by construction (RED rows before the extractor code).
- **IV. On-Device First**: PASS — all extraction and OCR runs on-device; no cloud services.
- **V. Simplicity**: PASS — specialized libraries per format, not a monolithic all-in-one package; each extractor is self-contained.

## Project Structure

### Documentation (this feature)

```text
specs/028-extraction-libraries/
├── plan.md              # This file
└── checklists/requirements.md
```

### Source Code (repository root) — the feature's own additions

```text
lib/platform/pdf_extractor.dart        NEW  PDF extraction using flutter_pdf_text
lib/platform/docx_extractor.dart       NEW  DOCX extraction using docx_to_text
lib/platform/epub_extractor.dart       NEW  EPUB extraction using epub_decoder
lib/platform/native_ocr_engine.dart    NEW  OCR using flutter_native_ocr
lib/document_input.dart               ~   inject the extractors into the seam
test/pdf_extractor_test.dart         NEW  PDF extractor's table
test/docx_extractor_test.dart        NEW  DOCX extractor's table
test/epub_extractor_test.dart        NEW  EPUB extractor's table
test/native_ocr_engine_test.dart     NEW  OCR engine's table
```

No `contracts/` directory: the extractors implement the interfaces already defined in 027 (`DocumentExtractor`, `OcrEngine`), and no new interface is introduced.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

## Phases

### Phase 1: PDF extraction

**Goal**: `lib/platform/pdf_extractor.dart` implements `DocumentExtractor` for PDF files using `flutter_pdf_text`, with page-by-page extraction support.

- Add `flutter_pdf_text` dependency to `pubspec.yaml`
- Implement `PdfExtractor` class implementing `DocumentExtractor`
- Unit test table with fakes for the underlying library
- Wire into `lib/document_input.dart`'s `DocumentExtractor` injection point

### Phase 2: DOCX extraction

**Goal**: `lib/platform/docx_extractor.dart` implements `DocumentExtractor` for DOCX files using `docx_to_text`.

- Add `docx_to_text` dependency to `pubspec.yaml`
- Implement `DocxExtractor` class implementing `DocumentExtractor`
- Unit test table with fakes for the underlying library
- Wire into `lib/document_input.dart`'s `DocumentExtractor` injection point

### Phase 3: EPUB extraction

**Goal**: `lib/platform/epub_extractor.dart` implements `DocumentExtractor` for EPUB files using `epub_decoder`, with chapter/section support.

- Add `epub_decoder` dependency to `pubspec.yaml`
- Implement `EpubExtractor` class implementing `DocumentExtractor`
- Unit test table with fakes for the underlying library
- Wire into `lib/document_input.dart`'s `DocumentExtractor` injection point

### Phase 4: OCR engine

**Goal**: `lib/platform/native_ocr_engine.dart` implements `OcrEngine` using `flutter_native_ocr`.

- Add `flutter_native_ocr` dependency to `pubspec.yaml`
- Implement `NativeOcrEngine` class implementing `OcrEngine`
- Unit test table with fakes for the underlying library
- Wire into `lib/document_input.dart`'s `OcrEngine` injection point

### Phase 5: Integration and device walk

**Goal**: the extractors are wired into the seam, and a device walk proves each format imports and extracts.

- Update `lib/document_input.dart` to provide default implementations for the injectable seams
- Device walk: import real PDF, DOCX, EPUB files and verify extraction
- Device walk: import a scanned PDF or image and verify OCR
- Receipts in `breakpoint.md`

### Phase 6: Closing pass

**Goal**: the stage is closed on its own numbers.

- `flutter analyze` clean
- `flutter test --concurrency=2` (baseline 915 + new tests)
- ARB key audit (no new keys in this feature)
- Artifact checkers
- Receipts in `breakpoint.md` and `checklists/requirements.md`

## Phases (work order)

1. **PDF extractor** — the most common format, battle-tested library
2. **DOCX extractor** — pure Dart, simple, no platform code
3. **EPUB extractor** — pure Dart, chapter/section support
4. **OCR engine** — platform-native, image-based
5. **Integration and device walk** — wire them together and prove on device
6. **Closing pass** — counts, receipts, checklist

## Gates, and the order they run

```bash
flutter analyze                                   clean, at every phase
flutter test --concurrency=2                      +this feature's own, never a red
check_tasks_format.py   specs/028-extraction-libraries   → (at the tasks stage)
task_id_audit.py        specs/028-extraction-libraries   → (at the tasks stage)
check_row_coverage.py   specs/028-extraction-libraries   → (at the tasks stage)
check_quickstart_coverage.py specs/028-extraction-libraries → (at the tasks stage)
spec_consistency.py     specs/028-extraction-libraries   → no divergence
check_artifact_refs.py  specs/028-extraction-libraries   → no unresolved references
```

Device walk: `ADB_SERIAL=emulator-5554` real document files, OCR on scanned PDF/image.

## Risks this plan carries, and what answers each

1. **Library compatibility** — each library is battle-tested (flutter_pdf_text 20 months, flutter_native_ocr 16 months), but platform updates can break things. Answered by unit tests with fakes and device walk validation.
2. **OCR accuracy** — the spec accepts platform-native OCR; if accuracy is insufficient, that's a follow-up feature, not a blocker.
3. **Memory usage for large documents** — the seam's page-by-page design (027) bounds this; the walk measures.
4. **Temporary file cleanup** — the plan explicitly calls out immediate deletion of the platform's staged copy (FR-007).
5. **Cost, stated plainly**: four new dependencies, each a specialized library; the integration is wiring into existing seams.

## What this plan explicitly does not decide

- The specific timeout values for extraction (tested at the walk)
- The exact error messages for each failure mode (left to the extractors' own design)
- Whether DOC (legacy format) is supported (deferred; out of scope per spec)

## What a reviewer should argue with, in the order they cost something

1. **Library choices** — the spec names flutter_pdf_text, docx_to_text, epub_decoder, flutter_native_ocr. The reviewer can weigh whether alternatives (qnox_pdf_text, textify, tesseract_ocr) are better.
2. **OCR scope** — the spec includes image files for OCR, not just scanned PDFs. The reviewer can weigh whether this overreaches.
3. **DOC exclusion** — the spec excludes legacy .doc format. The reviewer can weigh whether this should be in scope.
4. **EPUB's chapter support** — the spec requires chapter/section extraction. The reviewer can weigh whether this is necessary for MVP.

## Data model

No new data model: the feature plugs into 027's existing interfaces (`DocumentExtractor`, `OcrEngine`) and the existing content model from 008.
