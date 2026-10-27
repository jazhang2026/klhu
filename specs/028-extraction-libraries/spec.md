# Feature Specification: Extraction libraries

**Feature Branch**: `028-extraction-libraries`

**Created**: 2026-10-27

**Status**: Draft

**Input**: follow-up to 025/027 — the reader's deferred document kinds (PDF, DOC, DOCX, EPUB) need their text extraction mechanisms, and OCR for scanned documents.

## What this feature does

Features 025 and 027 built the infrastructure for document import and extraction:
- 025 added the TXT-first cut and the seam architecture
- 027 added the injectable `DocumentExtractor` and `OcrEngine` seams

This feature implements the actual platform libraries that those seams call:
- PDF text extraction (with page-by-page support)
- DOCX text extraction
- EPUB text extraction (with chapter/section support)
- OCR for scanned documents (for when text extraction fails)

## Clarifications

### The reader's answers — asked at this stage, answered by the research (2026-10-27)

|| # | the question as put | the answer in force | the alternative it refuses |
||---|---|---|---|
|| **Q1** | Which libraries for PDF, DOCX, EPUB, OCR? | **Specialized battle-tested libraries per format: flutter_pdf_text (PDF), docx_to_text (DOCX), epub_decoder (EPUB), flutter_native_ocr (OCR).** | a monolithic all-in-one package with unproven stability. |
|| **Q2** | Must OCR work for the deferred kinds only? | **OCR is for any image-based document, including PDFs with no text layer and images the reader picks.** | OCR limited to only one format. |

## User Scenarios & Testing

### User Story 1 - Extract text from PDF documents (Priority: P1)

As a KalaHoo Reading user, I want to import a PDF file and have its text extracted, so I can read it aloud.

**Why this priority**: PDF is the most common document format.

**Independent Test**: a PDF file is imported, its text is extracted, and it becomes readable content.

**Acceptance Scenarios**:

1. **Given** a PDF file, **When** the reader imports it, **Then** its text is extracted page by page.
2. **Given** a PDF with no text layer (scanned), **When** OCR runs, **Then** the text is recognized and readable.

### User Story 2 - Extract text from DOCX documents (Priority: P1)

As a KalaHoo Reading user, I want to import a DOCX file and have its text extracted, so I can read it aloud.

**Why this priority**: DOCX is a common office format.

**Independent Test**: a DOCX file is imported, its text is extracted, and it becomes readable content.

**Acceptance Scenarios**:

1. **Given** a DOCX file, **When** the reader imports it, **Then** its text is extracted.

### User Story 3 - Extract text from EPUB documents (Priority: P2)

As a KalaHoo Reading user, I want to import an EPUB file and have its text extracted, so I can read it aloud.

**Why this priority**: EPUB is the most common e-book format, but less common than PDF/DOCX.

**Independent Test**: an EPUB file is imported, its text is extracted chapter by chapter, and it becomes readable content.

**Acceptance Scenarios**:

1. **Given** an EPUB file, **When** the reader imports it, **Then** its text is extracted chapter by chapter.

### User Story 4 - OCR for scanned documents (Priority: P2)

As a KalaHoo Reading user, I want scanned documents (PDF or images) to be OCR'd, so I can read them aloud.

**Why this priority**: OCR enables scanned documents; the Q2 answer from 027 added this.

**Independent Test**: a scanned PDF is imported, OCR runs, and the recognized text becomes readable content.

**Acceptance Scenarios**:

1. **Given** a PDF with no text layer, **When** the reader imports it, **Then** OCR runs and the text is recognized.
2. **Given** an image file (PNG/JPG), **When** the reader imports it, **Then** OCR runs and the text is recognized.

## Edge Cases

- Encrypted PDFs are rejected (no password handling in MVP)
- Corrupted or malformed documents are rejected with a clear error message
- OCR fails silently (returns empty string) for unrecognizable images
- Large documents: extraction should handle them without memory issues
- Mixed-language documents: extracted text follows per-paragraph language detection (spec 003)

## Requirements

### Functional Requirements

- **FR-001**: The app MUST extract text from PDF files using `flutter_pdf_text`, with page-by-page support when the document has pages.
- **FR-002**: The app MUST extract text from DOCX files using `docx_to_text`.
- **FR-003**: The app MUST extract text from EPUB files using `epub_decoder`, with chapter/section support.
- **FR-004**: The app MUST perform OCR on image-based documents using `flutter_native_ocr`.
- **FR-005**: The app MUST integrate these libraries into the injectable `DocumentExtractor` and `OcrEngine` seams from 027.
- **FR-006**: The app MUST handle extraction failures gracefully (empty text, error messages).
- **FR-007**: The app MUST delete the temporary copy the platform stages for reading immediately after extraction (Q3 from 027).

### Key Entities

- **PdfExtractor**: Implementation of `DocumentExtractor` for PDF files using `flutter_pdf_text`.
- **DocxExtractor**: Implementation of `DocumentExtractor` for DOCX files using `docx_to_text`.
- **EpubExtractor**: Implementation of `DocumentExtractor` for EPUB files using `epub_decoder`.
- **NativeOcrEngine**: Implementation of `OcrEngine` using `flutter_native_ocr`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A PDF file imports successfully, its text is extracted, and it becomes readable content.
- **SC-002**: A DOCX file imports successfully, its text is extracted, and it becomes readable content.
- **SC-003**: An EPUB file imports successfully, its text is extracted chapter by chapter, and it becomes readable content.
- **SC-004**: A scanned PDF or image file imports successfully, OCR runs, and the recognized text becomes readable content.
- **SC-005**: No local copy of the imported document survives after extraction (temporary file deleted immediately).

## Assumptions

- **A1**: The libraries chosen are the specialized ones from research §4: flutter_pdf_text, docx_to_text, epub_decoder, flutter_native_ocr.
- **A2**: The injectable seam design from 027 is the integration point.
- **A3**: OCR is on-device only (no cloud services).
- **A4**: Encrypted PDFs are not supported in the MVP.

## Out of scope

- Encrypted PDF password handling
- DOC (legacy format) support — DOCX only for MVP
- Advanced EPUB features (annotations, media overlays)
- Cloud-based OCR services
- Image format support beyond PNG/JPG for OCR

## What this feature does not supersede

Nothing. It implements the platform libraries that 027's seams call; no earlier requirement is withdrawn, and the library, the read and the renderer keep their own contracts.
