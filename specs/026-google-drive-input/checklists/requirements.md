# Specification Quality Checklist: Google Drive document input

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-28
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details as *decisions* — the draft names the platform's own
  facilities (DocumentsUI, ContentResolver) as the reader's lines and points at the
  existing pipeline only as evidence of what the tree already carries.
- [x] Focused on user value — the item's own lines are the spine: pick a Drive file,
  get reading content; burn-after-read still applies.
- [x] Written for non-technical stakeholders — the mechanism stays in the Clarifications'
  answers and the Assumptions.
- [x] All mandatory sections completed — header, `Input`, the content:// paragraph,
  Clarifications, User Scenarios & Testing, Edge Cases, Requirements + Key Entities,
  Success Criteria, Assumptions, Out of scope.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — the reader's answers Q1–Q3 are bound here.
- [x] Requirements are testable and unambiguous — every FR names an observable
  (FR-001 the accepted Drive source, FR-002 the content:// fallback, FR-003 the refusal
  path, FR-004 the ordinary-content behaviour); the ids are stable.
- [x] Success criteria are measurable — SC-001 (Drive import yields speaking content),
  SC-002 (large doc paged read), SC-003 (no local copy survives).
- [x] Success criteria are technology-agnostic — they speak of reading, memory and
  content, not of a platform API.
- [x] All acceptance scenarios are defined — three stories, scenarios each, edge case family.

## Stage result (2026-10-28)

Native half implemented: `ContentUriReaderPlugin.kt` reads `content://` URIs through
Android's ContentResolver, registered in `MainActivity`. Dart side calls the method
channel `klhu/document_picker` / `readContentUri`. Unit tests pass (937 total). Local
TXT import verified end-to-end on phone (OnePlus 9 5G, Android 34). Full Drive import
walk blocked: Drive account contains only Google Docs format files, filtered by MIME
type. Uploading a `.docx`/`.txt`/`.pdf` to Drive enables the end-to-end walk.

| requirement | row that claimed it | what the walk shows |
|---|---|---|
| **FR-001** (Drive doc imports as ordinary content) | row 2 (unit), T002/T004 | Stub wired; local regression verified on device; Drive import awaits compatible file |
| **FR-002** (content:// fallback read) | row 1 (unit), T001/T002/T003 | Kotlin plugin compiles and registers; method channel wired; unit tests verify mock path |
| **FR-003** (refuse unreadable Drive picks) | row 1 (unit), T002/T003 | Empty bytes flow to extractText → OCR → refuse (same as local files) |
| **FR-004** (ordinary content behavior) | row 2 (unit), T002/T004 | Local TXT import verified: content appears in library, readable, renderable |
| **SC-001** (Drive import yields speaking content) | row 2, T002/T004 | Blocked: no compatible Drive file; local TXT import works |
| **SC-002** (large Drive doc paged read) | row 2, T002/T004 | Inherited from 027/028 documentUnits() page-by-page walk |
| **SC-003** (no local copy survives) | row 1, T002/T003 | burnCachedCopy no-op for content:// URIs (unit-tested) |
