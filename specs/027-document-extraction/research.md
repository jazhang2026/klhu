# Research: document extraction — what the tree carries, and the readings this plan takes

**Feature**: `027-document-extraction` | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

## Baseline, measured on the checkout this plan starts from

```
flutter analyze                                   → No issues found!
flutter test --concurrency=2                      → +the deferred kinds' own, never a red
```

The tree already carries the seam 025 built: `lib/document_input.dart` answers, for a picked document, what text the
reader hears, in what segments, and what if there is none — including the extraction the platform's own facilities
carry and the OCR answer. The deferred kinds (PDF, DOC, DOCX, EPUB) are the reader's own list the TXT-first cut set
aside.

## §1 What the tree already carries (the evidence the requirements rest on)

| need | where | what it answers |
|---|---|---|
| the pick | `lib/platform/picture_picker.dart`, `lib/platform/document_picker.dart` | the reader's own file-picking surface; the import's pick is the same platform plugin the pictures use |
| the content | `lib/models/content.dart`, `lib/services/content_store.dart` | an imported text lands as a user content: id, name, language, origin, char count |
| the read | `lib/document_input.dart`, `lib/segmenter.dart`, `lib/reader_service.dart` | the text is cut into sentences; the read is sentence-granular; the landing needs no change |
| the video | `lib/video_renderer.dart`, `lib/video_timeline.dart`, `lib/video_painter.dart` | frames follow the engine's measured audio; the landing needs no change |

## §2 Decisions

### D1 — The extraction seam is the existing module, grown to the deferred kinds

The pick → read seam (`lib/document_input.dart`) already carries the extraction shape; the deferred kinds are the
same seam grown to PDF, DOC, DOCX and EPUB through the platform's own facilities.

### D2 — Page source: the phone's original document's pages, else bounded segments (Q1)

### D3 — OCR is added here and shared with the next AI support (Q2)

### D4 — The landing is the existing content store (FR-004)

### D5 — The pick is the reader's own `file_selector` (no new picker)

## §3 Risks and reservations

- **R1** — which platform facilities carry PDF/DOCX/EPUB text on device (Android vs the reader's own phone).
- **R2** — OCR availability and cost on device — measured at the walk.
- **R3** — the memory bound (SC-002) on a genuinely large extracted document — measured at the walk.

## §4 Library findings (2026-10-27 supplement)

### PDF extraction

**Recommended**: `flutter_pdf_text` (0.9.0)
- Android: Apache PdfBox (battle-tested, page-by-page support)
- iOS: Apple PDFKit (native, efficient)
- Supports page-by-page extraction (matches Q1 requirement)
- Lazy loading: text cached page-per-page
- Published 20 months ago, actively maintained

**Alternative**: `qnox_pdf_text` (0.1.2)
- Similar capabilities, also supports URLs
- Android: pdfbox-android, iOS: PDFKit
- Slightly newer (13 months ago)

### DOCX extraction

**Recommended**: `docx_to_text` (pure Dart)
- Pure Dart implementation, no platform dependencies
- Simple API: `docxToText(bytes)`
- Lightweight, cross-platform
- Good for .docx; .doc requires older format parser

**Alternative**: `doc_text_extractor` (2.1.1)
- Supports .doc, .docx, PDF, Google Docs
- Uses Syncfusion PDF extraction
- More heavyweight

### EPUB extraction

**Recommended**: `epub_decoder` (0.1.4)
- Pure Dart/Flutter, parses EPUB 2 & 3
- Lists sections/chapters in reading order
- Extracts text per section (matches page-by-page requirement)
- Get metadata: title, authors, language
- Published 23 months ago

**Alternative**: `sakura_epub` (0.1.3)
- Full EPUB reader with text extraction
- Built on epub.js and flutter_inappwebview
- More heavyweight, includes rendering

### OCR

**Recommended**: `flutter_native_ocr` (0.1.0)
- iOS: Apple Vision framework (native, no ML Kit)
- Android: Google ML Kit Text Recognition v2
- On-device, no internet required
- High accuracy, multiple languages
- Simple API: `recognizeText(imagePath)`

**Alternative**: `platform_text_recognition` (0.2.0)
- iOS: Apple Vision (no ML Kit/SPM deps)
- Android: Google ML Kit
- Avoids ML Kit on iOS (lighter build)
- Similar capabilities

**Alternative**: `tesseract_ocr` (0.5.0)
- Tesseract 4 on both platforms
- Supports 100+ languages
- Heavier, but more language options

### Unified approach option

**Consider**: `extract_text` (0.0.2)
- Single package for PDF, DOCX, TXT, and OCR
- Uses `read_pdf_text` for PDF
- Uses ML Kit for OCR (Android/iOS)
- Simple unified API: `ExtractText.fromFile(filePath)`
- Early version (0.0.2), may have stability concerns
- DOCX works on all platforms, PDF/OCR mobile only

### Recommendation

Use the individual specialized libraries:
- PDF: `flutter_pdf_text` (battle-tested, page-by-page)
- DOCX: `docx_to_text` (pure Dart, simple)
- EPUB: `epub_decoder` (sections/chapters)
- OCR: `flutter_native_ocr` (platform-native, accurate)

This approach:
- Uses battle-tested, specialized libraries for each format
- Provides fine-grained control per format
- Avoids single-point-of-failure in one monolithic package
- Aligns with the seam's injectable `DocumentExtractor` design

## What this research does not measure

The device-side numbers (extraction capability, OCR behaviour, memory) are design inputs here and become receipts at
the walk; nothing in this feature re-measures a closed feature's behaviour except where the landing moves it.
