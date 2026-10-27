# Implementation Plan: document input

**Feature**: `025-document-input` | **Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Input**: the reader's wish list item 025 (quoted in the spec's `Input`) — input a document file to generate
reading content; PDF, DOC, DOCX, TXT and popular e-book formats; page-by-page reading for large files; direct
document reading — closed at the clarify stage by the reader's answers of 2026-10-25: **Q1** (the phone's original
document's page if possible, else bounded segments of the extracted text), **Q2** (EPUB, for now), **Q3** (add OCR
functions for this spec and the next AI support).

## What this plan builds, in one paragraph

An **input before the content pipeline**: the reader picks a document file, the app reads it — the phone's own
pages where the document has them, bounded segments of the extracted text otherwise, OCR where the text cannot be
extracted — and the text becomes reading content that the library, the read and the renderer already serve unchanged.
The plan adds one module of pure seams and rewires the existing surfaces to them; it moves no closed feature's
contract, because spec 025's FR-004 is that the imported content is an ordinary content.

## Technical Context

**Language/Version**: Dart (SDK `^3.13.3`), Flutter (Material 3), the existing `flutter_tts` engine.
**Primary Dependencies**: existing only — the reader's own `file_selector` surface (`lib/platform/picture_picker.dart`,
spec 012's picture-picker requirement) for the pick, `flutter_tts` / `path_provider` for the engine and the content
directory. No new dependency for the pick; OCR is new work and is added by this plan's own seam.
**Storage**: the content store's own file-per-content + versioned `index.json` (008) — imported text lands as a
**user** content, so it is loadable, savable, editable, deletable and readable exactly like hand-written content
(spec 025 FR-004).
**Testing**: `flutter test` unit rows against the new module's own fakes; device walk rows on `emulator-5554`.
**Target Platform**: Android (validated), iOS (untested — no macOS on the dev host; the seams are platform-neutral
where the platform allows).
**Performance Goals**: page-by-page memory bound (SC-002); the content-list latency bar stays ≤ 500 ms (008).
**Constraints**: one Flutter codebase (constitution I); on-device first (IV); simplicity/YAGNI (V — OCR is now in
because this spec added it, via Q3, and is also the next AI support's OCR); iOS 16+ / Android 10+ (API 29+) baseline
(constitution constraints).
**Scale/Scope**: large documents; PDF/DOCX/TXT + EPUB (first cut).

## Constitution Check

- **I. Flutter Single Codebase**: PASS — the import seam is Dart, platform code stays under `lib/platform/`.
- **II. Spec-Driven**: PASS — spec 025 is approved at the plan gate this stage closes; no implementation without it.
- **III. Test-First**: PASS — the phases below are test-first by construction (RED rows before the seam's code).
- **IV. On-Device First**: PASS — no account, no backend, no analytics; the text and the OCR run on-device.
- **V. Simplicity**: PASS with the Q3 amendment — OCR is added by this spec ("add OCR functions for this spec and the
  next AI support"); one seam, one function set, no second model beside it.

## Project Structure

### Documentation (this feature)

```text
specs/025-document-input/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── checklists/requirements.md
```

### Source Code (repository root) — the feature's own additions

```text
lib/document_input.dart              NEW  pick → read (pages / bounded segments / OCR) → text
lib/reading_view.dart                ~   the import surface (where the reader feeds a document)
lib/content_store.dart               ~   the landing (imported text becomes a user content)
lib/l10n/app_{en,zh,zh_Hans,es}.arb  +   the import's strings — key count moves, audit stays green
test/document_input_test.dart       NEW  the seam's own table
```

No `contracts/` directory: the feature adds no interface another component implements — its seams are functions
inside the app (`lib/document_input.dart`), and the storage it lands in is already contracted by 008's
`specs/008-content-storage/contracts/storage-format.md`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| OCR added inside this spec (constitution V said "no OCR unless a later spec adds it") | the reader's Q3 answer bound OCR to this spec *and* the next AI support; a later-only OCR would split the seam | none — the answer is the reader's own word, and the seam is shared with the AI feature |

## Phases

### Phase 1: Foundational — the seam every later phase reads

**Goal**: `lib/document_input.dart` answers "given a picked document, what text does the reader hear, in what
segments, and what if there is none to read" with its own pure functions and its own test table.

- Phase 1 owns: the pick resolution, the text extraction, the page/segment choice (Q1), the OCR fallback (Q3), and
  the empty/no-text case.

### Phase 2: The landing — imported text becomes an ordinary content

**Goal**: the text a read consumes is the text the import produced, and the produced content is served by the
library/read/renderer exactly like hand-written content (FR-004, SC-001).

### Phase 3: The surface — the reader feeds a document

**Goal**: the reader reaches the import (reading page / content list), the strings are added, `flutter gen-l10n`,
the key audit stays green.

### Phase 4: The device walk — what only a real build can show

**Goal**: the quickstart rows on one build, receipts in `breakpoint.md`.

### Phase 5: The closing pass — status, checklist, measured figures.

## Phases (work order)

1. **The seam, alone** — `lib/document_input.dart` (pick → segments → text, OCR included) + `test/document_input_test.dart`.
   `flutter analyze` clean, the new file's tests green, the existing suite untouched (SC-001's identity cousin: a
   tag-free/empty import path).
2. **The landing** — the produced text enters the content pipeline as a user content (FR-004); the read consumes it
   through the unchanged segmenter.
3. **The surface** — the import affordance, the strings, the keys audit, `flutter gen-l10n`.
4. **The device walk** — the plan's quickstart rows, one build, receipts in `breakpoint.md`.
5. **The closing pass** — `## Status` in `tasks.md`, the checklist's stage notes, the figures re-taken.

## Gates, and the order they run

```bash
flutter analyze                                   clean, at every phase
flutter test --concurrency=2                      +901 → +901+this feature's own, never a red
check_tasks_format.py   specs/025-document-input   → (at the tasks stage)
task_id_audit.py        specs/025-document-input   → (at the tasks stage)
check_row_coverage.py   specs/025-document-input   → (at the tasks stage)
check_quickstart_coverage.py specs/025-document-input → (at the tasks stage)
spec_consistency.py     specs/025-document-input   → no divergence
check_artifact_refs.py  specs/025-document-input   → no unresolved references
```

Device rows: `ADB_SERIAL=emulator-5554 /usr/bin/python3 -u specs/025-document-input/scripts/klhu_walk_document.py <row>`.

## Risks this plan carries, and what answers each

1. **OCR on device** (Q3) — which engine backs the added functions, and what a scanned document costs. Answered at
   research §3; the walk names the device's own.
2. **PDF/DOCX text extraction** — which platform facilities carry the text, and what a text-less document costs
   once OCR is in.
3. **The memory bound** (SC-002) — the page/segment choice (Q1) must hold on a large document; the walk measures.
4. **The landing** (FR-004) — the imported content behaving like hand-written content on the read and in the video.
5. **Cost, stated plainly**: the seam is small; the re-runs (closed features' receipts, where the read/land paths
   move) are the expensive part.

## What this plan explicitly does not decide

- The final wording of the import's strings in each locale (the tasks stage's, in the reader's own register).
- The driver's own mechanics (the tasks stage writes the driver; the quickstart rows name it).
- The task order inside a phase — the tasks stage's.

## What a reviewer should argue with, in the order they cost something

1. **D2's page source** — the phone's original pages if possible, bounded segments otherwise (Q1). The reviewer can
   weigh whether the import should *prefer* the document's own pagination or always segment.
2. **D3's OCR** — added here and shared with the next AI support; the reviewer can weigh the engine choice and the
   scanned-document path.
3. **FR-004's landing** — that the imported content is ordinary; the reviewer can weigh whether the library needs any
   new behaviour at all.
4. **The surface** — whether the import belongs on the reading page, the content list (`+` already means "new
   content"), or both; the plan does not fix it, the tasks stage does.
