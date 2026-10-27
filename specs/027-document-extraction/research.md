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

## What this research does not measure

The device-side numbers (extraction capability, OCR behaviour, memory) are design inputs here and become receipts at
the walk; nothing in this feature re-measures a closed feature's behaviour except where the landing moves it.
