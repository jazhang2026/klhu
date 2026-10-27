# Implementation Plan: document extraction

**Feature**: `027-document-extraction` | **Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Input**: the deferred half of the reader's wish list item 025 — the PDF, DOC, DOCX and EPUB kinds the **TXT-first
cut** (2026-10-27) set aside from 025, plus the reader's third line about reading directly.

## What this plan builds, in one paragraph

An **input before the content pipeline**, taken up where the document-input feature's TXT-first cut stopped: the reader
picks a document of a deferred kind, the app extracts its text through the platform's own facilities (and OCR where the
text layer is absent), and the extracted text becomes reading content the library, the read and the renderer already
serve. The plan adds a platform extraction seam to the app's own code, grows the document seam to answer deferred kinds
through it, and lands the extracted text as an ordinary content — the read then walks it page by page, as 025's SC-002
half now does for every content.

## Technical Context

**Language/Version**: Dart (SDK `^3.13.3`), Flutter (Material 3), the existing `flutter_tts` engine.
**Primary Dependencies**: the reader's own `file_selector` surface (`lib/platform/picture_picker.dart`, spec 012's
picture-picker requirement) for the pick, and the platform's own text-extraction facilities behind a new platform seam
for the deferred kinds (this plan introduces the platform library the TXT-first cut deferred); OCR is new work and is
added by this plan's own seam (the spec's Q2 answer, carried into the next AI support).
**Storage**: the content store's own file-per-content + versioned `index.json` (008).
**Testing**: `flutter test` unit rows against the new platform's fake and the document seam's own fakes; device walk rows
on `emulator-5554`.
**Constraints**: one Flutter codebase (constitution I); on-device first (IV); simplicity/YAGNI (V).

## Constitution Check

- **I. Flutter Single Codebase**: PASS — the extraction seam is Dart behind a platform interface, the platform library
  lives under `lib/platform/`.
- **II. Spec-Driven**: PASS — spec 027 is approved at the plan gate this stage closes; the deferred kinds are the spec's
  Input.
- **III. Test-First**: PASS — the phases below are test-first by construction (RED rows before the seam's code).
- **IV. On-Device First**: PASS — no account, no backend, no analytics; the text and the OCR run on-device.
- **V. Simplicity**: PASS with the extraction entry — one platform seam, one function set, the OCR functions shared with
  the next AI support.

## Project Structure

### Documentation (this feature)

```text
specs/027-document-extraction/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── checklists/requirements.md
```

### Source Code (repository root) — the feature's own additions

```text
lib/platform/document_extractor.dart   NEW  the platform's own text extraction, behind the seam
lib/document_input.dart               ~   the extraction answer for a deferred kind (FR-001), OCR (FR-003)
lib/reading_view.dart                 ~   the landed text is read through the paged read (FR-002, SC-002)
test/document_extractor_test.dart     NEW  the platform seam's own table
```

No `contracts/` directory: the feature adds no interface another component implements — its seams are functions inside
the app (`lib/document_input.dart`) behind a platform interface, and the storage it lands in is already contracted by
008's `specs/008-content-storage/contracts/storage-format.md`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| The platform extraction library (constitution V said "no new dependency unless a later spec adds it") | the deferred kinds are not readable without a platform text-extraction capability; the TXT-first cut deferred that capability to this feature | none — the reader asked for the kinds, the cut only deferred the acceptance |

## Phases

### Phase 1: Foundational — the platform extraction seam every story reads

**Goal**: `lib/platform/document_extractor.dart` answers, for a deferred kind, what text the platform's own facilities
extract — and what they cannot (the OCR answer).

### Phase 2: The seam grows — the deferred kinds answer through it

**Goal**: `lib/document_input.dart` answers, for a deferred kind, what text the reader hears, in what segments, and what
if there is none (FR-001, FR-002, FR-003, with the OCR fallback the spec's Q2 answer).

### Phase 3: The landing and the read

**Goal**: the extracted text becomes an ordinary content (FR-004) and is read through the paged read the document-input
stage left in place (FR-002, SC-002).

### Phase 4: The device walk and the closing

**Goal**: the quickstart rows on one build, receipts in `breakpoint.md`.

## Phases (work order)

1. **The platform seam** — `lib/platform/document_extractor.dart` + `test/document_extractor_test.dart`: the platform's
   own extraction behind one function, the empty-answer shape for a kind it cannot read.
2. **The seam grows** — `lib/document_input.dart`: the deferred kinds through the platform seam, OCR where the text
   layer is absent (the spec's Q2).
3. **The landing** — the extracted text enters the content pipeline as a user content through the existing store, and the
   read walks it page by page.
4. **The device walk and the closing** — the plan's quickstart rows, one build, receipts in `breakpoint.md`.

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

## Risks this plan carries, and what answers each

1. **The extraction capability** — which platform facilities carry PDF/DOCX/EPUB text on device, and what a text-less
   document costs once OCR is in (research §3, the spec's Q2).
2. **The memory bound** — SC-002's page-by-page read on a genuinely large extracted document (025's FR-002, now in force
   through the paged read).
3. **The landing** — that the extracted text is ordinary (FR-004), already the document seam's answer.

## What this plan explicitly does not decide

- The final wording of the deferred kinds' strings in each locale (the tasks stage's, in the reader's own register).
- The platform's extraction API shape beyond the seam (the tasks stage's).
- The task order inside a phase — the tasks stage's.

## What a reviewer should argue with, in the order they cost something

1. **The platform library's shape** — which extraction capability carries the deferred kinds, and how the OCR answer
   (Q2) shares it with the next AI support.
2. **The memory bound** — the page-by-page read over extracted text.
3. **The landing** — that the extracted text is ordinary.
