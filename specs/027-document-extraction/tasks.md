# Tasks: document extraction

**Feature**: `027-document-extraction` | **Date**: 2026-10-27
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (feed a deferred-kind document, get reading content), `US2` (read large documents page
by page).

## Status

Draft — opened by the TXT-first cut of 025 (2026-10-27), which deferred the PDF, DOC, DOCX and EPUB kinds here; the
tasks below are the seams the later feature builds, and none is done yet.

## Phase 1: Foundational — the seam every story reads

**Goal**: `lib/document_input.dart` answers, for a deferred kind, what text the reader hears, in what segments, and
what if there is none.

- [ ] T001 `specs/027-document-extraction/spec.md`: the deferred kinds — the accepted set this feature takes up from
  025's TXT-first cut, and the seams the later feature reads.

## Phase 2: User Story 1 — Feed a deferred-kind document, get reading content (Priority: P1) 🎯 MVP

**Goal**: an import of a deferred kind yields reading content the reader can open, read, save, edit and render.

- [ ] T002 [US1] `lib/document_input.dart`: the pick → read seam for a deferred kind, with the extraction the
  platform's own facilities carry and the OCR answer for an unextractable one.

## Phase 3: User Story 2 — Read large extracted documents page by page (Priority: P2)

**Goal**: no more than one page's text is held in memory at a time.

- [ ] T003 [US2] `lib/document_input.dart`: the page/segment answer for an extracted document (Q1).

## Phase 4: The landing and the closing

**Goal**: the extracted text becomes an ordinary content, and the stage is closed on its own numbers.

- [ ] T004 [US1] `lib/reading_view.dart`: the affordance for a deferred kind, and the landing of the extracted text as
  an ordinary content (FR-004).
- [ ] T005 `specs/027-document-extraction/breakpoint.md`: the structural row — the counts, the ARB keys, the artifact
  checkers.

## Dependencies & ordering

- T001 → T002, T003, T004.

## Parallel opportunities

- **T001 with T005**: the deferred kinds' spec and the stage's closing row are different files with no incomplete
  dependency between them.

## Implementation strategy

- The MVP is Phase 2; Phase 3 delivers the original item's hard constraint.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (deferred kinds: PDF, DOC, DOCX, EPUB) | T001, T002 |
| FR-002 (page-by-page: phone-original pages else bounded segments; memory bound) | T003, T004 |
| FR-003 (direct read; OCR where text cannot be extracted) | T002, T004 |
| FR-004 (imported content is an ordinary content) | T004 |
| SC-001 (import yields reading content the read speaks) | T002, T004 |
| SC-002 (page-by-page read completes) | T003, T004 |
| SC-003 (no local copy; content is the extracted text) | T002, T004 |
