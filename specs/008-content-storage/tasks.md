# Tasks: Content Storage and Content Management

**Feature**: `008-content-storage` | **Date**: 2026-09-23
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contract**: [contracts/storage-format.md](./contracts/storage-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete dependency), `[Story]` = `US1`/`US2` from spec.md.

## Status (verified against the tree, 2026-09-23)

**T001–T026 are implemented and verified**: `flutter analyze` clean, `flutter test
--concurrency=2` green (217 tests, 0 failures). T027 and T028 are still open.

Deviations from the text of the tasks above, recorded rather than silently absorbed:

1. **T002 (and the localized-name parts of T016/T019/T020) — superseded.** The preset
   `name` maps were deliberately REMOVED: a pre-set's title is auto-generated from its
   own text by the same rule as user content (`contentNameFrom`), so no shipped catalog
   carries a translated label that can drift from the text it names. The catalog is
   `id`/`language`/`text`, and `content_list_screen`/`reading_view` regenerate the title
   from the catalog text.
2. **T017 was only half done at review time.** The tombstone and the preset⇒new-user
   branch existed in production but had no unit tests; `test/content_store_test.dart`
   gained a `pre-set management (US2, T017)` group: tombstone survives a restart, editing
   a pre-set leaves the catalog text byte-identical and writes no `contents/<preset>.txt`,
   and `saveEdited` updates a user entry in place with no duplicate.
3. **T022/T024/T025 landed late**, after the first US2 pass: `test/l10n_keys_test.dart`
   (template-key completeness + no dead keys in the three other ARBs), a semantics/size
   test in `test/content_list_test.dart`, and the 50-entry index-only test in
   `test/content_store_test.dart`.
4. **T025's device half** (list opens in ≤ 500 ms) is not measurable by dump-polling —
   one `uiautomator dump` costs ~2 s. It is carried to T027 as UNVERIFIED WITH REASON.
5. **T023**: the dead `sampleEn`/`sampleZh`/`sampleEs` keys are gone from all four ARBs
   and their assertions were re-pointed; `l10n_keys_test.dart` now fails if a key comes
   back only in the template.
### Verified after the device walk (2026-09-23)

- **T027 done** — `specs/008-content-storage/breakpoint.md` holds the 13
  scenarios with their evidence lines: 11 WALKED PASS, SC-009/SC-013's unit
  halves EVIDENCE-ONLY, SC-013's latency bar UNVERIFIED WITH REASON. Three
  divergences are recorded there (an unreproducible first-pass read, the silent
  index repair, `Save` writing an entry with no real change) plus the
  device-typing recipe that cost the most time.
- **The walk found a real gap and it is fixed**: the contract requires a
  moved-aside index to be *reported* (FR-010), and the store raised
  `lastError == indexRepaired` — but no screen ever read it. `reading_view`
  now surfaces it once via `_reportStorageSignal()` with the new localized key
  `libraryRepairedMessage` (all four ARBs + `gen-l10n`), falling back to
  `storageErrorMessage` for IO failures, and clears the signal so the next
  launch is quiet. Covered by the widget test `a repaired index is reported
  instead of silently resetting`, proven on device by scenario 10.
- **T028 done** — `README.md` is a real project README: features, the storage
  layout and its repair behaviour, the dev/test/build loop, the spec index and
  the known limitations (iOS untested, the latency bar unmeasured).
- Final state: `flutter analyze` clean, `flutter test --concurrency=2` →
  **218 passing, 0 failing**.

## Grounding notes (decisions these tasks implement)

1. **Storage** = one file per content + a versioned `index.json` in the app documents
   directory; `SharedPreferences` keeps only scalars (research D1, contract § Location).
2. **One new dependency**: `path_provider ^2.1.6`, verified resolvable in this
   project (research D2).
3. **Pre-sets are data**: `assets/content/presets.json`, declared in `pubspec.yaml`
   (research D3). Deleting one writes a **tombstone**, never a file delete (D4).
4. **Save branches on origin**: edited preset ⇒ **new** user entry, edited user
   entry ⇒ update in place (D5, FR-013/019, SC-010).
5. **Undo** = `TextField.undoController` + `UndoHistoryController`, disabled when
   `!value.canUndo`; the platform stack is uncapped, so SC-008's "≥10" holds and
   there is no number to advertise (research D6).
6. **Guards before any write**: empty/whitespace refused, > **100,000 characters**
   refused, nothing truncated (research D10).
7. **New UI strings land in all four ARBs** — `app_en`, `app_zh`, `app_zh_Hans`,
   `app_es` (spec 007's lesson; research D12).
8. **Tests are written first per story** (constitution III); every task below that
   says "test" must be seen failing before the implementation task beside it.
9. **Baseline**: `flutter analyze` clean and 152 tests green in `test/` before T001.

## Path conventions

- `MDL` = `lib/models/`, `SVC` = `lib/services/`, `L10N` = `lib/l10n/`; tests are flat in `test/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; run tests as
  `flutter test --concurrency=2` while the emulator is up, `flutter gen-l10n` after touching any `.arb`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: dependency, the preset data, and every new string — no logic.

- [x] T001 Add `path_provider: ^2.1.6` to `pubspec.yaml` and declare the new asset
      directory (`assets: - assets/content/`), then `flutter pub get`
- [x] T002 [P] Create `assets/content/presets.json` with the three pre-set contents
      (`preset_en_sample` / `preset_zh_sample` / `preset_es_sample`, each with
      `language`, a localized `name` map for `en`/`zh`/`es`, and `text` copied from
      `lib/sample_texts.dart`), per [contracts/storage-format.md](./contracts/storage-format.md)
      § Pre-set catalog. `lib/sample_texts.dart` stays in place until T021 — the text
      is intentionally duplicated for the duration of the US1 increment
- [x] T003 [P] `L10N`: add these 20 keys to **all four** ARBs (`app_en.arb`,
      `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb`), then `flutter gen-l10n`:
      `contentsButton` "Contents", `contentsTitle` "Contents",
      `currentContentLabel` "Reading: {name}", `saveButton` "Save",
      `undoButton` "Undo", `deleteButton` "Delete", `cancelButton` "Cancel",
      `discardButton` "Discard", `deleteConfirmTitle` "Delete this content?",
      `deleteConfirmMessage` "This cannot be undone.",
      `deletePresetConfirmMessage` "This cannot be undone. A deleted sample returns
      only if you reinstall the app.", `savedMessage` "Saved",
      `nothingToSaveMessage` "There is nothing to save",
      `undoExhaustedMessage` "Nothing more to undo",
      `contentTooLargeMessage` "Too long to save (limit: {limit} characters)",
      `storageErrorMessage` "Could not save. Check storage space and try again.",
      `unsavedChangesTitle` "Unsaved changes",
      `unsavedChangesMessage` "You have changes that are not saved.",
      `noContentsMessage` "No contents yet. Write something, then tap Save.",
      `damagedContentMessage` "This content is damaged"

**Checkpoint**: `flutter pub get` resolves; `flutter gen-l10n` is clean.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the model and the store's read/repair path — every story builds on these.

**⚠️ CRITICAL**: no user story work starts until this phase is green.

- [x] T004 [P] Create `lib/models/content.dart`: `ContentOrigin` enum (`preset`/`user`),
      `SavedContent` (id, name, language, origin, createdAt, updatedAt, charCount) and
      `ContentIndex` (`version`, `entries`, `deletedPresetIds`, `lastOpenedId`) with
      JSON encode/decode exactly as in [contracts/storage-format.md](./contracts/storage-format.md)
      (dates as UTC ISO-8601)
- [x] T005 Write `test/content_store_test.dart` — the store contract tests from
      [contracts/storage-format.md](./contracts/storage-format.md) § Invariants
      (index-only `list()`, save→restart round-trip, UTC timestamps, corrupt index
      moved aside and re-seeded, missing text file = damaged not fatal). **Must fail
      before T006**
- [x] T006 Implement `lib/services/content_store.dart`: constructor with an injectable
      directory (default `getApplicationDocumentsDirectory()/content`), `list()`,
      `read(entry)`, the atomic `.tmp` + rename write protocol for index and text,
      the repair path (move aside + localized error signal), and typed failures for
      IO errors (research D1/D11)

**Checkpoint**: foundation ready — the store reads, writes, repairs; US1 can start.

---

## Phase 3: User Story 1 — Save and manage page content (P1) 🎯 MVP

**Goal**: page text can be saved, listed, loaded back, edited with undo, re-saved and
deleted behind a confirmation warning, and the library survives a restart.

**Independent Test**: from a fresh install, edit the page, Save, `force-stop`, relaunch
→ the entry is in the list with its auto-generated name and loads byte-identical;
then undo an edit, re-save, delete with confirmation, and cancel a deletion.

### Tests for US1 (write first, must fail)

- [x] T007 [P] [US1] Write `test/content_naming_test.dart`: first non-blank line,
      whitespace collapsed, truncated to 24 chars with ellipsis, ` (2)`/` (3)`
      suffixes on collision within the same set (research D7)
- [x] T008 [P] [US1] Extend `test/content_store_test.dart`: `saveNew`/`update`/
      `delete`/`markOpened`, id uniqueness, empty-string and 100,000+ char refusals
      writing nothing, a failing writer leaving index and memory untouched (quickstart § 9/10)
- [x] T009 [P] [US1] Extend `test/reading_view_edit_test.dart`: EDIT mode shows Save +
      Undo; Undo disabled without history and reverts exactly one edit; Save calls the
      store seam; leaving EDIT with unsaved changes raises the discard/cancel dialog
- [x] T010 [P] [US1] Write `test/content_list_test.dart`: rows show name/language/date,
      tap loads the content into the reading view, the delete icon opens the
      confirmation dialog, `Cancel` keeps the entry, `Delete` removes it, empty state
      shows `noContentsMessage`

### Implementation for US1

- [x] T011 [US1] Implement `lib/content_naming.dart` (name from text + collision
      resolution; pure, no IO) — depends on T007
- [x] T012 [US1] Extend `lib/services/content_store.dart` with the mutating API:
      `saveNew`, `update`, `delete`, `saveEdited`, `markOpened`, guards applied before
      any write — depends on T006/T008
- [x] T013 [US1] Implement `lib/content_list_screen.dart`: index-backed list, tap =
      load, trailing delete icon → `AlertDialog` (`deleteConfirmTitle` /
      `deleteConfirmMessage`, Cancel/Delete), empty and damaged-entry states — depends on T010/T012
- [x] T014 [US1] Modify `lib/reading_view.dart`: new app-bar Content action opening the
      list, `currentContentLabel` caption for the loaded entry, Save + Undo actions in
      EDIT mode (lazily created `UndoHistoryController` disposed with the editor,
      `undoExhaustedMessage` SnackBar on the final undo), unsaved-change guard on
      content switch. Sample buttons stay for now — depends on T003/T012
- [x] T015 [US1] Modify `lib/main.dart`: construct the `ContentStore`, open the last
      used entry (fallback: first entry, else blank page — research D9), inject the
      store into `ReadingView` — depends on T006/T014

**Checkpoint**: US1 fully testable on its own — the app can save, load, edit, undo,
re-save and delete user content across restarts. **MVP.**

---

## Phase 4: User Story 2 — Pre-set content management (P1)

**Goal**: the three pre-sets appear in the same list, load and read like any other
content, and can be managed — editing one produces a new user content while the
original stays intact; the sample buttons are gone.

**Independent Test**: from a fresh install, open the list → three pre-sets with
localized names, no sample buttons on the reading page; load one, edit it, Save → a new
entry holds the edit and the pre-set still shows its original text; delete a pre-set,
confirm, restart → it stays gone.

### Tests for US2 (write first, must fail)

- [x] T016 [P] [US2] Write `test/preset_catalog_test.dart`: `assets/content/presets.json`
      parses, ids unique, every entry has all three localized names and non-empty text,
      a malformed entry is skipped without breaking the others (FR-017/020, research D3/D11)
- [x] T017 [P] [US2] Extend `test/content_store_test.dart`: first-launch seeding of the
      three pre-sets, `deletedPresetIds` tombstone surviving restart and suppressing
      re-seeding, editing a pre-set producing a **new** `user` entry while the catalog
      text stays byte-identical (FR-019, SC-010), preset text never written to `contents/`
- [x] T018 [P] [US2] Extend `test/reading_view_edit_test.dart` + `test/content_list_test.dart`:
      no `EN sample`/`中文示例`/`ES sample` buttons exist; the list shows the pre-set
      names in the current interface language; loading a pre-set then Save creates a new
      entry; the delete dialog for a pre-set states the reinstall consequence (SC-002, FR-018)

### Implementation for US2

- [x] T019 [US2] Extend `lib/services/content_store.dart`: load the catalog via
      `rootBundle` (localized-name resolution with `en` fallback), seed missing pre-sets
      into the index, honour `deletedPresetIds`, implement the `saveEdited` branch
      (preset ⇒ `saveNew`) — depends on T012/T016/T017
- [x] T020 [US2] Extend `lib/content_list_screen.dart`: pre-set rows (localized name +
      language tag, no file size), the `deletePresetConfirmMessage` variant of the
      dialog, and treated-per-origin delete (tombstone vs removal) — depends on T013/T019
- [x] T021 [US2] Modify `lib/reading_view.dart`: delete the sample-button `Wrap`; delete
      `lib/sample_texts.dart`; update every referencing test (`test/reading_view_test.dart`,
      `test/reading_view_edit_test.dart`, `test/reading_view_mixed_test.dart`,
      `test/reading_view_pause_test.dart`, `test/spanish_localization_test.dart`,
      `test/branding_test.dart`) to load text through the store/catalog — depends on T019

**Checkpoint**: both stories work together; every pre-set is manageable like user content.

---

## Phase 5: Polish & cross-cutting concerns

- [x] T022 [P] Write `test/l10n_keys_test.dart`: every template key exists in
      `app_zh.arb`, `app_zh_Hans.arb` and `app_es.arb` (the 007 regression class:
      a string added to three of four files renders English in the fourth)
- [x] T023 [P] Delete the now-unused `sampleEn`/`sampleZh`/`sampleEs` keys from
      `L10N/app_{en,zh,zh_Hans,es}.arb` and re-run `flutter gen-l10n`, then drop their
      assertions from `test/spanish_localization_test.dart` and `test/branding_test.dart`
- [x] T024 [P] Accessibility pass over `lib/reading_view.dart` and
      `lib/content_list_screen.dart`: localized tooltips on every new `IconButton`,
      `ListTile` rows ≥44pt, dialog buttons reachable without gestures; note anything
      a test cannot assert
- [x] T025 [P] Performance check in `test/content_store_test.dart`: 50 seeded entries
      asserted index-only (no text reads), plus a device measurement of opening the
      list (quickstart § 13)
- [x] T026 `flutter analyze` clean over `lib/` + `test/`, and the full suite green
      (`flutter test --concurrency=2`)
- [x] T027 Device walk of [quickstart.md](./quickstart.md) § 1–13 on `emulator-5554`;
      record PASS/FAIL, divergences and the [unit]-only rows in
      `specs/008-content-storage/breakpoint.md`
- [x] T028 Update `README.md`'s feature list for the content library and tick the
      completed boxes in this file

---

## Dependencies & ordering

- **Phase 1 → Phase 2 → US1 → US2 → Polish.** No user story starts before Phase 2.
- **T003 blocks T014/T018/T020** (the strings the new UI reads).
- **T004 blocks T006**, which blocks **T012**; **T012 blocks T013/T014/T015**.
- **T019 blocks T020/T021**; **T021 must land before T023** (the keys it removes are
  only dead once the buttons are gone).
- Tests (T007–T010, T016–T018) are TDD-first: each must be seen failing, then its
  implementation task turns it green.
- US2 depends on US1's store and list screen (T012/T013) — the two stories are P1 each
  but not independent of each other; US1 alone is the shippable increment.

## Parallel opportunities

- Phase 1: T002 and T003 in parallel (different files).
- US1 tests: T007/T008/T009/T010 in parallel (four files).
- US2 tests: T016/T017/T018 in parallel.
- Polish: T022/T023/T024/T025 in parallel.

## Implementation strategy

1. **MVP** = Phase 1 + Phase 2 + US1 (T001–T015): a working content library for
   user-written text, with the existing samples still reachable from the buttons.
2. **Increment 2** = US2 (T016–T021): pre-sets join the library, the buttons go away,
   `sample_texts.dart` is deleted.
3. **Increment 3** = Polish (T022–T028): string-completeness guard, dead-string
   removal, accessibility, performance, device validation, docs.

## Notes

- Never write partial state: guards run before the file system is touched, and the
  index is only replaced after the text file has landed (contract § Write protocol).
- Keep the reading view's state machine (`read/edit/speaking/paused`) — Save and Undo
  are actions inside `edit`, not new modes.
- Every new user-visible string, tooltip and dialog button comes from the ARB; no
  literal English in `lib/`.
- `flutter test` needs `--concurrency=2` on this machine while the emulator runs.

---

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 save page content | T006, T012, T014 |
| FR-002 load saved content | T006, T012, T013, T014 |
| FR-003 remove sample buttons | T021 |
| FR-004 unified selectable list | T013, T020 |
| FR-005 select and load any content | T010, T013 |
| FR-006 persist across restarts | T005, T006, T015 |
| FR-007 unique identifiers | T004, T008, T012 |
| FR-008 auto-generated names | T007, T011 |
| FR-009 list of all saved contents | T013 |
| FR-010 graceful storage errors | T005, T006, T008, T013 |
| FR-011 edit after loading | T009, T014 |
| FR-012 undo for edits | T009, T014 |
| FR-013 save edited content | T008, T012, T014 |
| FR-014 delete with confirmation | T010, T013 |
| FR-015 warning message | T003, T013 |
| FR-016 require confirmation | T010, T013 |
| FR-017 three pre-set contents | T002, T016, T019, T020 |
| FR-018 pre-sets manageable | T018, T019, T020 |
| FR-019 preserve pre-set originals | T017, T019 |
| FR-020 more pre-sets without code changes | T002, T016, T019 |
| SC-001 data integrity | T005, T008 |
| SC-002 sample buttons removed | T018, T021, T023 |
| SC-003 unified list | T013, T020 |
| SC-004 persistence | T006, T015, T017 |
| SC-005 many contents, no slowdown | T005, T025 |
| SC-006 edit with undo | T009, T014 |
| SC-007 delete confirmation | T010, T013 |
| SC-008 ≥10 undo steps | T014 (platform stack is uncapped — research D6) |
| SC-009 pre-sets manageable | T019, T020 |
| SC-010 pre-set originals preserved | T017, T019 |
