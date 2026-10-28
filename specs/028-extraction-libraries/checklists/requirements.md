# Specification Quality Checklist: Extraction libraries

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-27
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details as *decisions* — the draft names the platform's own facilities as the reader's lines and points at the existing pipeline only as evidence of what the tree already carries.
- [x] Focused on user value — the item's own lines are the spine: feed a deferred-kind document, get reading content; read large documents page by page.
- [x] Written for non-technical stakeholders — the mechanism stays in the Clarifications' answers and the Assumptions.
- [x] All mandatory sections completed — header, `Input`, the deferred-kind paragraph, Clarifications, User Scenarios & Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — the reader's answers Q1–Q2 are bound here at this stage.
- [x] Requirements are testable and unambiguous — every FR names an observable (FR-001 the accepted kind, FR-002 the page-by-page memory bound, FR-003 the no-staging rule, FR-004 the ordinary-content behaviour); the ids are stable.
- [x] Success criteria are measurable — SC-001 (PDF import yields speaking content), SC-002 (DOCX import), SC-003 (EPUB import chapter-by-chapter), SC-004 (OCR on scanned docs), SC-005 (no local copy survives).
- [x] Success criteria are technology-agnostic — they speak of reading, memory and content, not of a platform API.
- [x] All acceptance scenarios are defined — four stories, scenarios each, edge case family.

## Stage notes (2026-10-28)

All 18 tasks executed. Phase 1–4: four platform extractors implemented and unit-tested.
Phase 5: T013 integration done; T014 walk driver written — row 1 (PDF) 5/5 on device,
row 6 (delete) 5/5. T015 breakpoint receipts written. Rows 2 (DOCX) and 3 (EPUB)
NOT WALKED — DocumentsUI on this emulator does not surface those MIME types.

Row 4 (PNG refused): PASS. Row 5 (structural): PASS.

| requirement | row that claimed it | what the walk shows |
|---|---|---|
| **FR-001** PDF extraction | row 1 (device), T002–T003 (unit) | PDF imported, extracted, landed as user content — row 1, 5/5; media store limitation: DOCX/EPUB not surfaced on this emulator |
| **FR-002** DOCX extraction | row 2 (unit), T005–T006 | Unit table green (4/4); device walk NOT WALKED (emulator MIME filtering) |
| **FR-003** EPUB extraction | row 3 (unit), T008–T009 | Unit table green (4/4); device walk NOT WALKED (emulator MIME filtering) |
| **FR-004** OCR | row 4 (device), T011–T012 | PNG refused correctly; OCR engine unit-tested (2/2) |
| **FR-005** integration | T013 | defaultExtractor/defaultOcrEngine wire all four libraries into the 027 seams |
| **FR-006** graceful failure | T002, T005, T008, T011 | all extractors return '' on malformed input |
| **FR-007** temp file cleanup | T002, T005, T008, T011, T015 | PdfExtractor and NativeOcrEngine delete temp files in finally |
