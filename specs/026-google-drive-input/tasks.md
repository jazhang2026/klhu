# Tasks: Google Drive document input

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable.

## Status

IN PROGRESS — 5 of 5 tasks done (2026-10-28). Stub implementation committed; content:// fallback wired in document_picker.dart, tests added. Device walk: Google Drive app present on emulator but no signed-in account — Drive root not visible in DocumentsUI. Full Drive import walk requires a real device with signed-in Drive account or emulator setup with a Google account.

## Phase 1: Research

**Goal**: confirm the failure mode and identify the fallback path.

- [x] T001 `specs/026-google-drive-input/research.md`: measure that `XFile.readAsBytes()`
  fails for `content://` URIs on the target device; document the ContentResolver fallback.

## Phase 2: Implementation

**Goal**: the picker reads `content://` URIs through ContentResolver.

- [x] T002 [US1] `lib/platform/document_picker.dart`: add a `content://` read fallback in
  `FileDocumentPicker.pick()` — when `readAsBytes()` returns empty, read through the
  platform's ContentResolver; preserve burn-after-read (no-op for Drive URIs).
- [x] T003 [US1] `test/document_picker_test.dart`: test the fallback — a simulated
  `content://` URI yields bytes; `burnCachedCopy` is a no-op.

## Phase 3: Tests and closing

**Goal**: unit tests green, receipts written.

- [x] T004 [US1] `test/document_input_test.dart`: verify Drive-extracted bytes enter the
  content pipeline as ordinary content (FR-004).
- [x] T005 `specs/026-google-drive-input/breakpoint.md`: the structural row — counts,
  ARB keys, artifact checkers.

## Dependencies & ordering

- T001 → T002, T003, T004.
- T002 → T003 (implementation before its test).
- T003 → T004, T005.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (Drive doc imports as ordinary content) | T002, T004 |
| FR-002 (content:// fallback read) | T001, T002, T003 |
| FR-003 (refuse unreadable Drive picks) | T002, T003 |
| FR-004 (ordinary content behavior) | T002, T004 |
| SC-001 (Drive import yields speaking content) | T002, T004 |
| SC-002 (large Drive doc paged read) | T002, T004 |
| SC-003 (no local copy survives) | T002, T003 |
