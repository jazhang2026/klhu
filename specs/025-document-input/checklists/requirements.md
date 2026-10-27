# Specification Quality Checklist: Document input

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details as *decisions* — the draft names the three seams (input, page-by-page, direct)
      as the reader's own lines and points at the existing pipeline (`lib/services/content_store.dart`, `lib/segmenter.dart`,
      `lib/reader_service.dart`, `lib/video_renderer.dart`) only as evidence of what the tree already carries, never
      as a design instruction
- [x] Focused on user value — the item's own lines are the spine, quoted verbatim in `Input` (four lines, none
      reflowed, none dropped)
- [x] Written for non-technical stakeholders — "feed a document, get reading content", "read large documents page
      by page", "read the document directly"; the mechanism stays in the Clarifications' answers and the Assumptions
- [x] All mandatory sections completed — header, `Input`, the gap paragraph, Clarifications, User Scenarios & Testing,
      Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** as of 2026-10-25, when the reader answered all three
      open questions in the Clarifications table (Q1, Q2, Q3): use the phone's original document's page if
      possible, else bounded segments of the extracted text (2026-10-25); EPUB for now (2026-10-25); add OCR
      functions for this spec and the next AI support (2026-10-25). The answers are bound there in the reader's
      own words, and the requirements were re-cut against them (FR-001, FR-002, FR-003)
- [x] Requirements are testable and unambiguous — every FR names an observable (FR-001 the accepted set, FR-002 the
      memory bound, FR-003 the no-staging rule, FR-004 the ordinary-content behaviour); the four FR ids are stable
- [x] Success criteria are measurable — SC-001 (an import yields speaking content), SC-002 (a large document is read
      page by page, the read completes), SC-003 (no local copy of the picked document; the content is the extracted
      text)
- [x] Success criteria are technology-agnostic — they speak of reading, memory and content, not of a platform API
- [x] All acceptance scenarios are defined — two stories, two scenarios each, one edge case family
- [x] Edge cases are named rather than left to the plan — the supported-set refusal, the no-text-layer case, the
      partial final page, mixed language
- [x] Scope is bounded — OCR is **in** scope for this spec (the Q3 answer added the OCR functions; they are also
      carried into the next AI support), while translation, AI access and server storage are refused
- [x] Dependencies and assumptions stated — A1–A3 above

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — the three questions are answered (2026-10-25);
      the answers re-cut FR-001/FR-002/FR-003 wording in the same pass, and the acceptance scenarios were written
      against the re-cut requirements
- [x] User scenarios cover primary flows — yes: import → read → save (US1), large document page-by-page (US2)
- [x] Feature meets measurable outcomes defined in Success Criteria — drafted, to be re-measured at the walk
- [x] No implementation details leak into the specification — the file names cited are evidence of the existing tree,
      not decisions

## Notes

- The draft is whole against the item as written: the four requirement lines are all carried, and the third line is
  split into FR-002 (page-by-page) and FR-003 (direct) because the reader wrote them as one breath and the spec
  separates what is a mechanism from what is a behaviour.
- Nothing here supersedes an earlier spec; the feature adds an input in front of the content pipeline rather than
  changing any closed feature's contract.
- The 2026-10-25 answers closed the three open questions and re-cut the requirements in the same pass: FR-002 now
  names the phone's original pages (Q1) with bounded segments as the fallback, FR-001 names EPUB as the first-cut
  e-book format (Q2), and FR-003 names the added OCR functions (Q3, carried into the next AI support).
- What this stage does not answer, on purpose: the extraction mechanism for PDF/DOCX/epub, the driver's own
  mechanics, and the tasks that will prove FR-001–FR-004 and SC-001–SC-003. Those are the plan's and the tasks'.

## Checklist results

- Content Quality: 4/4 items checked
- Requirement Completeness: 8/8 items checked as of 2026-10-25 — the three open questions (Q1–Q3) are answered and
  bound in the spec's Clarifications; the requirement wording was re-cut against them
- Feature Readiness: 4/4 items checked

## Stage notes (2026-10-26, re-read against the walked row)

Each requirement is read against the row that claimed it — not against what the code contains.

| requirement | row that claimed it | what the walk shows |
|---|---|---|
| **FR-001** accepted types | row 1 (unit), row 4 (device) | TXT: accepted, imported, landed, read, rendered — row 4, 21/21; the accepted set this feature implements is now **TXT** (the FR-001 TXT-first cut, 2026-10-27). PDF/DOC/DOCX/EPUB: deferred with that cut to later document-extraction features, which take the wider list up — this feature accepts the supported set it can read and refuses the rest. |
| **FR-002** page by page | rows 2 (unit), 4 (device) | `documentSegments()` answers Q1 in its unit table, and has **no caller in `lib/`**. The read pipeline still holds what it is handed; nothing reads page by page. **Not met** as behaviour. |
| **FR-003** direct read + OCR | rows 1 (unit), 4 (device) | Direct: met, on the reader's own terms (Q4) — the bytes are read into memory and the platform's staged copy is burned once they are there; the app's cache held no copy of the document after the walk. OCR: `requiresOcr()` only; **not met** (Q3's answer is unimplemented). |
| **FR-004** ordinary content | rows 3 (unit), 4 (device) | Met for load/save/read/render: the import added exactly one `origin: user` content whose stored text is the document's, and it read and rendered like any other. Delete of an imported content: unproven (no row). |
| **SC-001** import yields speaking content | row 4 | Met for TXT: 141 chars stored byte-equal, one range `0..141`, 8 utterances in the document's own sentence order, render `sentences=8`, 1134 frames, 8 slots. |
| **SC-002** page-by-page, no memory exhaustion | rows 2, 4 | The read of a 141-char document ran to its end with `0` OOM lines — a real receipt for a *small* document, and no receipt at all for a large one, because paging is not wired. |
| **SC-003** no local copy survives the read | row 4, T010 | Met (Q4): the app's own store root holds no copy of the document, its cache holds none after the read, and the content is the extracted text. On the previous build the same check printed two leftover copies — one per pick — so this is a fixed defect with a red→green receipt, not a claim that was always true. |

### What landed

- the pick → read seam (`lib/document_input.dart`), the platform picker (`lib/platform/document_picker.dart`), the
  import tab on the reading page, and the four ARB keys in all four locales
- TXT extraction end to end: page, store, read, render — walked on the device
- the burn (T010): the platform's staged copy of the pick is deleted once its bytes are in memory, and only inside the
  app's own cache (Q4)
- `documentSegments()` and `requiresOcr()` as pure functions with their own unit table

### What is owed, and what each one needs decided

- **PDF/DOC/DOCX/EPUB extraction** — **RESOLVED BY DECISION** (FR-001's TXT-first cut, 2026-10-27): the four kinds
  are deferred to later document-extraction features, which take the wider accepted list up; the extraction itself is
  now owed by those features, not by 025. The app no longer accepts kinds it cannot read.
- **OCR (Q3)** — there is a predicate and no reader; quickstart row 3 stays `NOT WALKED`.
- **Paging in the read** — `documentSegments()` needs a caller in `reading_view`/`reader_service` before SC-002 means
  anything for a large document.
- **Delete of an imported content** — one row through the reader's own gesture, if FR-004's "deletable" is to have a
  device receipt.
