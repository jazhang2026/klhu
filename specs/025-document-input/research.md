# Research: document input — what the tree carries, and the readings this plan takes

**Feature**: `025-document-input` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

## Baseline, measured on the checkout this plan starts from

```
flutter analyze                                   → No issues found! (…)
flutter test --concurrency=2                      → +901: All tests passed!   (baseline 857 + 44 scene rows)
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 135 135 135 135   (was 131 at the scene stage)
ls test/*.dart | wc -l                            → 66
ls lib/*.dart | wc -l                             → 45
```

The tree carries the reading pipeline this feature fronts: the content library
(`lib/services/content_store.dart`, one file per content + versioned `index.json`, spec 008), the segmenter
(`lib/segmenter.dart` — a paragraph with no delimiter is one sentence), the reader
(`lib/reader_service.dart` — sentences → utterances with the paragraph's language and voice, content offsets for
the highlight), and the renderer (`lib/video_renderer.dart` — frames to the engine's measured audio). The pick
surface the reader already has for pictures — `file_selector` through `lib/platform/picture_picker.dart`
(spec 012's picture-picker requirement) — is the same platform plugin the import can reuse; it is the one dependency this feature adds
no new line of.

## §1 What the tree already carries (the evidence the requirements rest on)

| need | where | what it answers |
|---|---|---|
| the pick | `lib/platform/picture_picker.dart`, `lib/picture_assignment*.dart` | the reader's own file-picking surface; `file_selector` is already a dependency, so the import's pick is not a new permission or plugin |
| the content | `lib/models/content.dart`, `lib/services/content_store.dart` | an imported text lands as a user content: id, name, language, origin, char count; guards (empty / too large) already exist |
| the read | `lib/segmenter.dart`, `lib/reader_service.dart`, `lib/speech_resolver.dart` | the text is cut into sentences; the read is sentence-granular; the landing needs no change |
| the video | `lib/video_renderer.dart`, `lib/video_timeline.dart`, `lib/video_painter.dart` | frames follow the engine's measured audio; the landing needs no change |

So the gap 025 names — input, page-by-page, direct — is three seams in front of all of this, and none of the closed
features' own behaviour moves.

## §2 Decisions

### D1 — The pick → read seam is one new module of pure functions: `lib/document_input.dart`

Given a picked document, the module answers: what text does the reader hear, in what segments, and what if there is
none. **Alternatives refused**: a pile of top-level functions across `reading_view.dart` and the store (the seam
would be smeared and untestable); a new store for imported content (FR-004 refuses — the landing is the existing
store).

### D2 — Page source: the phone's original document's pages, else bounded segments (Q1)

The read of a large document is page-by-page: the document's own pages where they exist, bounded segments of the
extracted text otherwise — one function, one answer, and the memory bound of SC-002 is the point.

### D3 — OCR is added here and shared with the next AI support (Q3)

The functions that read a document whose text cannot be extracted are added in this spec, and handed to the next
AI-support feature unchanged.

### D4 — The landing is the existing content store (FR-004)

Imported text becomes a user content through the existing ContentStore; no new store, no new schema version.

### D5 — The pick is the reader's own `file_selector` (no new picker; spec 012's picture-picker requirement)

Already a dependency; the import adds no permission, no plugin, no gallery screen.

## §3 The extraction landscape (design input, measured where measurable)

- **TXT** — trivial text; the pick is nearly the content.
- **EPUB (first cut, Q2)** — text/HTML content stream; a plain-text extraction path.
- **DOCX** — ZIP of XML; text via the package's own facilities or platform text.
- **PDF** — the text layer; where absent, the added OCR functions read the picture.
- **OCR** — the added functions; engine choice and scanned-document behaviour to be measured at the walk (the device
  facts), the API shape settled at the tasks stage.

## §4 Risks and reservations

- **R1** — the pick's platform behaviour on iOS (document picker needs entitlement/permission shape) — design input.
- **R2** — PDF/DOCX extraction capability on device — measured at the walk.
- **R3** — OCR availability and cost on device — measured at the walk.
- **R4** — the memory bound (SC-002) on a genuinely large document — measured at the walk.
- **R5** — the surface choice (reading page vs content list) — the tasks stage's; the plan does not fix it.

## What this research does not measure

The device-side numbers (extraction capability, OCR behaviour, memory) are design inputs here and become receipts at
the walk; nothing in this feature re-measures a closed feature's behaviour except where the landing moves it.
