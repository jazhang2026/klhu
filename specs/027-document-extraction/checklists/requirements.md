# Specification Quality Checklist: Document extraction

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-27
**Feature**: [spec.md](../spec.md)

## Content Quality

- [ ] No implementation details as *decisions* — the draft names the platform's own facilities as the reader's lines
      and points at the existing pipeline (`lib/services/content_store.dart`, `lib/segmenter.dart`,
      `lib/reader_service.dart`, `lib/video_renderer.dart`) only as evidence of what the tree already carries.
- [ ] Focused on user value — the item's own lines are the spine: feed a deferred-kind document, get reading content;
      read large documents page by page.
- [ ] Written for non-technical stakeholders — the mechanism stays in the Clarifications' answers and the Assumptions.
- [ ] All mandatory sections completed — header, `Input`, the deferred-kind paragraph, Clarifications, User Scenarios
      & Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope.

## Requirement Completeness

- [ ] No [NEEDS CLARIFICATION] markers remain — the reader's answers Q1–Q3 are bound here at this stage.
- [ ] Requirements are testable and unambiguous — every FR names an observable (FR-001 the accepted kind, FR-002 the
      memory bound, FR-003 the no-staging rule, FR-004 the ordinary-content behaviour); the four FR ids are stable.
- [ ] Success criteria are measurable — SC-001 (an import yields speaking content), SC-002 (a large document is read page
      by page, the read completes), SC-003 (no local copy of the picked document; the content is the extracted text).
- [ ] Success criteria are technology-agnostic — they speak of reading, memory and content, not of a platform API.
- [ ] All acceptance scenarios are defined — two stories, two scenarios each, one edge case family.

## Checklist results

- Content Quality: 2/4 items checked
- Requirement Completeness: 4/5 items checked
- Feature Readiness: 2/3 items checked

## Stage notes (2026-10-27)

The TXT-first cut of 025 (2026-10-27) deferred the PDF, DOC, DOCX and EPUB kinds here; the stage notes re-read 025's
checklist against that cut.

| requirement | row that claimed it | what the cut decided |
|---|---|---|
| **FR-001** deferred kinds | 025's row 1/4, via the cut | TXT first for 025; the four kinds deferred to this feature |
| **FR-002** page by page | 025's row 2/4, via the cut | bounded segments / phone pages, taken up from here |
| **FR-003** direct read + OCR | 025's row 1/4, via the cut | the no-staging rule re-entered with the deferred kinds |
| **FR-004** ordinary content | 025's row 3/4, via the cut | the landing is the existing store |

### Stage result — the OCR stage (2026-10-27, #3)

The added OCR functions landed in the document seam (`lib/document_input.dart`, behind the injected `OcrEngine` in
`lib/platform/ocr_engine.dart`); FR-003's OCR arm is implemented at unit level, and the seam's OCR answer — quickstart
row 1 of this feature and row 3 of 025 — now **PASS** (unit).

### What is owed

- **The extraction mechanism** for PDF/DOCX/epub on device — which platform facilities carry the text, and what a
  text-less document costs once OCR is in.
- **The memory bound** (SC-002) on a genuinely large extracted document.
- **The surface** — whether the affordance for a deferred kind belongs on the reading page, the content list, or both.
