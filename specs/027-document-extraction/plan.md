# Implementation Plan: document extraction

**Feature**: `027-document-extraction` | **Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Input**: the deferred half of the reader's wish list item 025 — the PDF, DOC, DOCX and EPUB kinds the **TXT-first
cut** (2026-10-27) set aside from 025, plus the reader's third line about reading directly.

## What this plan builds, in one paragraph

An **input before the content pipeline**, taken up where the document-input feature's TXT-first cut stopped: the reader
picks a document of a deferred kind, the app extracts its text through the platform's own facilities (and OCR where the
text layer is absent), and the extracted text becomes reading content the library, the read and the renderer already
serve. The plan adds nothing to the content pipeline; it hands the existing seams a deferred kind.

## Technical Context

**Language/Version**: Dart (SDK `^3.13.3`), Flutter (Material 3), the existing `flutter_tts` engine.
**Primary Dependencies**: the reader's own `file_selector` surface (`lib/platform/picture_picker.dart`, spec 012's
picture-picker requirement) for the pick, and the platform facilities for text extraction; OCR is new work and is
added by this plan's own seam.
**Storage**: the content store's own file-per-content + versioned `index.json` (008).
**Testing**: `flutter test` unit rows against the new module's own fakes; device walk rows on `emulator-5554`.
**Constraints**: one Flutter codebase (constitution I); on-device first (IV); simplicity/YAGNI (V).

## Phases

### Phase 1: Foundational — the seam every story reads

**Goal**: `lib/document_input.dart` answers, for a deferred kind, what text the reader hears, in what segments, and
what if there is none.

### Phase 2: User Story 1 — Feed a deferred-kind document, get reading content

### Phase 3: User Story 2 — Read large extracted documents page by page

### Phase 4: The landing and the closing

## Gates, and the order they run

```bash
flutter analyze                                   clean, at every phase
flutter test --concurrency=2                      +the deferred kinds' own, never a red
check_tasks_format.py   specs/027-document-extraction   → (at the tasks stage)
task_id_audit.py        specs/027-document-extraction   → (at the tasks stage)
check_row_coverage.py   specs/027-document-extraction   → (at the tasks stage)
check_quickstart_coverage.py specs/027-document-extraction → (at the tasks stage)
spec_consistency.py     specs/027-document-extraction   → no divergence
check_artifact_refs.py  specs/027-document-extraction   → no unresolved references
```

Device rows: `ADB_SERIAL=emulator-5554 /usr/bin/python3 -u specs/027-document-extraction/scripts/<row>`.
