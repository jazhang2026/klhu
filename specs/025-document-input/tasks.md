# Tasks: document input

**Feature**: `025-document-input` | **Date**: 2026-10-26
**Spec**: [spec.md](./spec.md) (closed at the clarify stage, 2026-10-25, by the reader's answers Q1–Q3) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (feed a document, get reading content), `US2` (read large documents page by page).
Rows with no story label are the shared core, the walk, or the closing.

## Status

**CLOSED — 10 of 10 rows run** (2026-10-26). The tasks stage's rows are all executed; the walk's receipts are in
[breakpoint.md](./breakpoint.md), row by row, and the numbers below are the ones those runs printed.

```
flutter analyze                     → No issues found! (ran in 1.6s)
flutter test --concurrency=2        → 912 tests, All tests passed!
   the suite without this feature's two test files → 904  (this feature adds 8 cases)
ARB keys                            → app_en 154  app_es 140  app_zh 140  app_zh_Hans 140
check_tasks_format.py               → OK: format, sequencing and spec-id coverage check out
task_id_audit.py                    → 10 tasks, 10 done, 1 [P]
check_row_coverage.py               → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py        → 4 FR + 3 SC | 4 rows ([unit] 3, [device] 1) | unclaimed: none
spec_consistency.py                 → no divergence
device walk, one build (emulator-5554, build 16:51:27, walked 2026-10-26 16:53)
row 4 → 21/21   a real .txt through the app's own import tab and DocumentsUI's own roots: 141 chars
                stored byte-equal to the file, origin user, language zh-Hans; the app's cache held no
                copy of the document after the read; one press → one range 0..141 and 8 utterances;
                render sentences=8, 1134 frames, 8 slots
```

**What a reviewer should argue with first**: the feature's promise is narrower than the reader's own wish, which
named five kinds and asked for all three seams; this feature's accepted set is now **TXT** (the first-cut type its own
extraction reads — the FR-001 TXT-first cut of 2026-10-27), so the PDF, DOC, DOCX and EPUB kinds are deferred to later
document-extraction features rather than accepted-and-refused. `requiresOcr()` is a predicate with no caller; and
`documentSegments()` has **no caller in `lib/`**, so the read pipeline is unchanged and nothing reads page by page yet.
The items owed, each with the decision it needs, are in
[breakpoint.md](./breakpoint.md) § What is owed (item 1 closed by the cut; items 2–4 still open). The pick's own copy is
settled: Q4's answer (*内存副本只用于阅读，读完即焚*) re-worded FR-003/SC-003 and T010 burns the platform's staged
copy once the bytes are in memory.

## Grounding notes (the decisions these tasks implement)

- **D1** the pick → read seam is `lib/document_input.dart`, one module of pure functions.
- **D2** the page source (Q1): the phone's original document's page if possible, else bounded segments of the
  extracted text.
- **D3** the OCR functions added here, shared with the next AI support (Q3).
- **D4** the landing is the existing content store (FR-004).
- **D5** the pick reuses the reader's own `file_selector` (no new plugin).

## Path conventions

- Unit rows write tests under `test/` and source under `lib/`; a row's first line names the file it touches.
- Device rows cite the quickstart row they drive — `python3 specs/025-document-input/scripts/klhu_walk_document.py <row>` — and their evidence lands in `specs/025-document-input/breakpoint.md`.

## Phase 1: Foundational — the seam every story reads

**Goal**: `lib/document_input.dart` answers "given a picked document, what text does the reader hear, in what
segments, and what if there is none to read" with its own pure functions and its own test table.

- [x] T001 [P] `test/document_input_test.dart`: the seam's own RED — a supported text document yields its text (FR-001,
  FR-003), the no-text case answers nothing, and an unsupported kind is refused; the file fails to compile before
  `lib/document_input.dart` exists, which is this feature's RED.
- [x] T002 `lib/document_input.dart`: the pick → read seam — pure functions over the picked document: text
  extraction, the page/segment choice (Q1), the OCR fallback (Q3), the empty case.

## Phase 2: User Story 1 — Feed a document, get reading content (Priority: P1) 🎯 MVP

**Goal**: an import yields reading content the reader can open, read, save, edit and render — the ordinary-content
behaviour (FR-004, SC-001).

- [x] T003 [US1] `lib/document_input.dart` + `lib/services/content_store.dart`: the landing — the produced text
  becomes a user content through the existing ContentStore (FR-004); the read consumes it through the unchanged
  segmenter.

## Phase 3: The surface — the reader feeds a document

**Goal**: the reader reaches the import (reading page / content list), the strings are added, `flutter gen-l10n`,
the key audit stays green.

- [x] T003b `lib/reading_view.dart`: the import affordance — a button or menu item that opens the file picker
  and calls the document_input seam to extract and save the document.
- [x] T003c `lib/l10n/app_{en,zh,zh_Hans,es}.arb`: the import's strings — add keys for the import button,
  file picker dialog, and error messages; run `flutter gen-l10n` and audit stays green.

## Phase 4: User Story 2 — Read large documents page by page (Priority: P2)

**Goal**: no more than one page's text is held in memory at a time (FR-002, SC-002).

- [x] T004 [US2] `lib/document_input.dart`: the page/segment answer — the phone's original pages where they exist,
  bounded segments of the extracted text otherwise (Q1).

## Phase 5: The device walk

**Goal**: the plan's quickstart rows on one build, receipts in `specs/025-document-input/breakpoint.md`.

- [x] T005 `specs/025-document-input/scripts/klhu_walk_document.py`: the driver, keyed by the quickstart row
  (row 4, the end-to-end import) — re-cut at T006, where seeding was replaced by the reader's own import.
- [x] T006 `specs/025-document-input/breakpoint.md`: walk quickstart row 4 into it — the driver was **re-cut at the
  walk**: it now drives the reader's own path (a real `.txt` on `/sdcard/Download`, the app's own import tab,
  DocumentsUI's own roots → Downloads → the file) instead of seeding the store, which bypassed the import entirely.
  Walked 2026-10-26 16:23 on the 15:35:20 build: **20/20 checks, exit 0** — 141 chars stored byte-equal to the file,
  `origin: user`, one press → one range `0..141` and 8 utterances, render `sentences=8`, 1135 frames, 8 slots. The
  receipts and the four findings (F1–F4) are in breakpoint.md.

## Phase 6: Polish & cross-cutting / closing

- [x] T007 `specs/025-document-input/breakpoint.md`: the structural row — `flutter analyze`, the suite's count, the
  ARB keys, the artifact checkers. Re-taken in this pass: `No issues found! (1.6s)`; 908 tests (904 with this
  feature's test file moved aside — it adds 4, and the 901 in the Notes below was stale); ARB 154/140/140/140 with the
  four import keys in all four files; all five checkers green (numbers in `## Status`).
- [x] T008 `specs/025-document-input/spec.md`: write the walk's measured figures back into SC-001–SC-003's own
  sentences, and fold in the Q1/Q2/Q3 receipts — re-written in this pass from row 4's run, including what each
  criterion does NOT yet cover (PDF/DOCX/EPUB extraction, OCR, paging in the read).
- [x] T009 `specs/025-document-input/checklists/requirements.md`: the checklist's stage notes — what landed, what is
  owed, and each requirement read against the row that claimed it — re-read against the walked row in this pass; the
  four owed items now name the decision each needs.

## Phase 7: The reader's own reading of SC-003 — the pick is burned after the read (2026-10-26)

**Goal**: nothing of a picked document survives the read — the in-memory copy is for reading only (Q4, answered by
the reader during the walk when the measure showed `file_selector` leaving one copy per pick in the app's cache).

- [x] T010 `lib/platform/document_picker.dart` + `test/document_picker_test.dart`: the burn — `burnCachedCopy(path,
  {cacheRoot})` deletes the platform's staged copy once the bytes are in memory, and **only** a path inside the app's
  own cache directory (a file the reader owns is never touched). Unit: 4 cases (staged copy deleted; the reader's own
  file kept; empty/gone path answered; a sibling directory whose name merely starts with the cache root's refused).
  Row 4 gained the matching device check and was re-walked on the 16:51 build: **21/21**, the app's cache holding no
  copy of the document after the read (it printed two leftovers on the 15:35:20 build). Spec re-worded against Q4 in
  the same pass (FR-003, SC-003).

## Dependencies & ordering

- T001 → T002: the table cannot answer before the module exists — that is this stage's RED.
- T002 → T003, T002 → T004, T002 → T005: the seam feeds the landing, the page/segment choice and the walk.
- T003 → T003b → T003c: the landing enables the surface, which needs the strings.
- T003c → T005, T004 → T005, T005 → T006, T006 → T007, T007 → T008/T009.

## Parallel opportunities

- **T001 with T005**: the seam's RED and the driver's skeleton are different files with no incomplete dependency
  between them.
- **Not parallel**: T002 → T003/T004 (one module, sequential reads); T005 → T006 → T007 (one driver, one build).

## Implementation strategy

- The MVP is Phase 2: an import yields an ordinary content the reader can read, save, edit and render — demonstrable
  on its own, before the page/segment work of Phase 3.
- Then Phase 3, the walk, the closing.

## Notes

- `flutter analyze` after every file; `flutter test --concurrency=2` at each phase boundary.
- The tree's own count was measured, not assumed: 904 without this feature's two test files, 912 with them (the earlier
  figure of 901 was stale).

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (accepted type: TXT, first cut) | T001, T002, T003b |
| FR-002 (page-by-page: phone-original pages else bounded segments; memory bound) | T002, T004, T005 |
| FR-003 (direct read; OCR where text cannot be extracted) | T001, T002, T006, T010 |
| FR-004 (imported content is an ordinary content) | T003, T004 |
| SC-001 (import yields reading content the read speaks) | T003, T003b, T003c, T004 |
| SC-002 (page-by-page read completes) | T004, T005, T006 |
| SC-003 (no local copy; content is the extracted text) | T002, T006 |
