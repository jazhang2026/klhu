# Tasks: document extraction

**Feature**: `027-document-extraction` | **Date**: 2026-10-27
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (feed a deferred-kind document, get reading content), `US2` (read large documents page
by page).

## Status

**CLOSED — 5 of 5 tasks run** (2026-10-27). The tasks stage's rows are all executed; the seams' rows are in
[breakpoint.md](./breakpoint.md) § The walk, row by row, and the stage closed on the unit's own numbers.

```
flutter analyze                     → No issues found! (ran in 1.2s)
flutter test --concurrency=2        → 915 tests, All tests passed!
ARB keys                            → app_en 139  app_es 139  app_zh 139  app_zh_Hans 139
check_tasks_format.py               → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                    → 5 tasks, 5 done, 0 [P]
check_row_coverage.py               → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py        → 4 FR + 3 SC defined | 2 rows ([unit] 2, [device] 0, [structural] 0, untagged 0) | unclaimed: none
spec_consistency.py                 → no divergence
check_artifact_refs.py              → no unresolved references
```

## Phase 1: Foundational — the seam every story reads

**Goal**: `lib/document_input.dart` answers, for a deferred kind, what text the reader hears, in what segments, and
what if there is none.

- [x] T001 `specs/027-document-extraction/spec.md`: the deferred kinds — the accepted set this feature takes up from
  025's TXT-first cut, and the seams the later feature reads.

## Phase 2: User Story 1 — Feed a deferred-kind document, get reading content (Priority: P1) 🎯 MVP

**Goal**: an import of a deferred kind yields reading content the reader can open, read, save, edit and render.

- [x] T002 [US1] `lib/document_input.dart`: the pick → read seam for a deferred kind, with the extraction the
  platform's own facilities carry and the OCR answer for an unextractable one.

## Phase 3: User Story 2 — Read large extracted documents page by page (Priority: P2)

**Goal**: no more than one page's text is held in memory at a time.

- [x] T003 [US2] `lib/document_input.dart`: the page/segment answer for an extracted document (Q1).

## Phase 4: The landing and the closing

**Goal**: the extracted text becomes an ordinary content, and the stage is closed on its own numbers.

- [x] T004 [US1] `lib/reading_view.dart`: the affordance for a deferred kind, and the landing of the extracted text as
  an ordinary content (FR-004).
- [x] T005 `specs/027-document-extraction/breakpoint.md`: the structural row — the counts, the ARB keys, the artifact
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
