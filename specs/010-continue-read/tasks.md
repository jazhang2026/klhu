# Tasks: Continue Read

**Feature**: `010-continue-read` | **Date**: 2026-09-24
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contract**: [contracts/read-position-format.md](./contracts/read-position-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete dependency), `[Story]` = `US1` (Continue Read, P1) or `US2` (sentence-granular pause/resume, P2).

## Status

**Not started (tasks generated 2026-09-24, plan reviewed the same day).** All tasks are
open; the implement stage ticks them as they complete and records any deviation inline.

Baseline to protect: **234 tests green, `flutter analyze` clean** on `main`
(`dd09278`) before any of this lands. Additions expected: ~10 store-contract cases,
~11 widget scenarios, ~5 service cases — the exact numbers are whatever the RED runs
produce, not a target.

## Grounding notes (decisions these tasks implement)

1. **The label key is renamed, not reused** (D9): `readPageButton` → `continueReadButton`
   in the template ARB and all three translations, plus the new `nothingToReadMessage`.
   `test/l10n_keys_test.dart` fails in both directions, so a half-rename cannot pass.
2. **The anchor is the resolved segment's start** (D1): tap = sentence, long-press =
   paragraph. No new gesture, no character-level position — `lib/segmenter.dart` already
   resolves both.
3. **Continue Read is the page read with an offset** (D2): `_readRange(anchor ?? 0,
   content.length, track: true)`. The `Read` (sentence) button stays (D3).
4. **The anchor is its own field, not the painted highlight** (D4/D8): the read's tracking
   repaint and Stop must not lose it; a restored anchor paints its sentence.
5. **Persistence is a `shared_preferences` record** keyed by content id, value
   `<offset>||<charCount>`, validated on read (D5/D6,
   [contracts/read-position-format.md](./contracts/read-position-format.md));
   `index.json` and its version are untouched.
6. **Any change to the visible text clears the anchor and deletes the key** (D7) — Done,
   Save, loading another content, emptied text. Text changes only in `lib/reading_view.dart`
   (`_doneEdit`, `_save`); the list screen only deletes.
7. **FR-011's split lives inside the service** (D12): `sentenceRanges` splits each
   paragraph speech into sentence utterances. `ParagraphSpeech`, `speakParagraphs` and the
   paragraph-indexed `onParagraphStart` keep their signatures and meaning, so 003's
   paragraph-level tracking and the 14 calling files are unchanged.
8. **The resume unit is observable only at the service seam.** The view-level pause test
   (`test/reading_view_pause_test.dart`) drives a fake `Reader` with its own
   paragraph-level queue, so it does **not** encode the real service's granularity and
   keeps passing; the 005 cases in `test/reader_service_test.dart` use single-sentence
   paragraphs, so they keep passing too. FR-011 needs **new** cases there with a
   multi-sentence paragraph (T009).
9. **Device evidence is two log lines** (D10): the view's resolved read range
   (`klhu read range: <start>..<end>`) and, added for FR-011, the service's per-utterance
   line (`klhu speak p<paragraph> s<sentence> "<text prefix>"`). `flutter_tts` never logs
   the utterance text, and a UI dump cannot show which characters were spoken.
10. **Tests first** (constitution III): every story's tests are written and run RED before
    that story's implementation. A compile error counts as RED — say so when it is one.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this spec: `specs/010-continue-read/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2`
  (the emulator being up makes plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the
  regenerated files are part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the one piece both stories' user-visible text depends on. Nothing is
installed — this feature adds no dependency (plan § Technical Context).

- [x] T001 Rename `readPageButton` → `continueReadButton` and add `nothingToReadMessage` in `lib/l10n/app_en.arb`
      (template) and the three translation ARBs `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`,
      `lib/l10n/app_es.arb` — en "Continue Read", zh/zh_Hans
      "继续朗读", es "Continuar leyendo"; the new message en "Nothing left to read from
      here", zh "从这里开始没有可朗读的内容", zh_Hans the same, es "No queda nada por leer
      desde aquí". Then `flutter gen-l10n` and confirm the diff is exactly the 4 ARBs + the
      4 regenerated `lib/l10n/app_localizations*.dart` files (D9)
      (deviation: the view's single reference to the old key moved in the same step — the tree
      would not compile otherwise, so T001 landed with one line of T006)

**Checkpoint**: `flutter analyze` clean (the view still references the old key — that
breaks at T006, which is expected and is why T001 lands first).

---

## Phase 2: Foundational (blocking prerequisite)

**⚠️ CRITICAL**: without a known-green baseline, no later "the suite is green" claim means
anything on this box (no CI in this repo).

- [x] T002 Record the baseline over the whole `test/` tree before touching anything:
      `flutter analyze` + `flutter test --concurrency=2` → 234 passing, 0 failing, and
      keep the tail of the output as the starting receipt for every later claim
      (deviation: it ran BEFORE T001, the reverse of the "Dependencies & ordering" line — the
      receipt's whole value is that it predates every edit, and T001 edits files)

**Checkpoint**: baseline receipt in hand; the tree is untouched.

---

## Phase 3: User Story 1 — Continue Read (P1) 🎯 MVP

**Goal**: the toolbar offers Continue Read; tapping (sentence) or long-pressing
(paragraph) sets the start position, visible as the highlight; Continue Read speaks from
there to the end of the text; with no position set it behaves exactly like the old page
read; the position survives a restart and is forgotten when the text changes.

**Independent Test**: install on `emulator-5554`, tap the third paragraph of the shipped
English pre-set, tap Continue Read — `logcat` shows `klhu read range: <tapped offset>..<len>`
(not `0..<len>`), the persisted record exists, and after a force-stop + relaunch the same
range is read again (quickstart scenarios 13–15).

### Tests for US1 ⚠️ (write first, run RED)

- [x] T003 [P] [US1] Write the record contract test `test/read_position_store_test.dart`
      from [contracts/read-position-format.md](./contracts/read-position-format.md): the
      save/load round-trip; a length mismatch returns null and leaves the stored value
      untouched; every malformed value (`214`, `214||`, `||334`, `a||b`, `-1||334`,
      `214||334||5`) returns null without throwing; `clear` then `load` is null; the key
      namespace cannot collide with `voice_*` or the language preference key; the second of
      two saves wins. Use `SharedPreferences.setMockInitialValues`. Run it and keep the RED
      output (the file `lib/read_position_store.dart` does not exist yet — a compile error
      is the RED, and it must be quoted as one)
- [x] T004 [P] [US1] Write the widget suite `test/reading_view_continue_test.dart` covering
      quickstart scenarios 1–11: the Continue Read label in all four locales; no position ⇒
      the old page-read sequence; tap sets the position and Continue Read starts there;
      long-press anchors the paragraph start; a tap while speaking stops and re-anchors;
      tracking from a position with the anchor retained; the empty range shows the
      localized message and speaks nothing; a text change (Done / Save / load another /
      empty) clears position and key; a fresh view restores the stored position, ignores a
      malformed value and a mismatched `charCount`; rapid taps leave the last position in
      force; mixed EN+ZH content reads per paragraph from a non-zero anchor. Record the
      speeches with their offsets (text + start/end), not just their text — the assertions
      are about the first speech's start. Run it and keep the RED output

### Implementation for US1

- [x] T005 [US1] Implement `lib/read_position_store.dart`: `ReadingPosition`
      (`contentKey`, `offset`, `charCount`) with the read rules of the contract as a pure,
      testable function, plus `ReadPositionStore` (`save`/`load`/`clear`) over
      `SharedPreferences`, malformed ⇒ null. Then run `test/read_position_store_test.dart`
      → T003's cases green
- [x] T006 [US1] Implement the anchor in `lib/reading_view.dart`: `_anchor` / `_anchorKey`
      fields (`int?` / `String?`), set on tap and long-press inside `_resolveAt` (the
      resolved segment's `start`), persisted through the store; restore on load (including
      the catalog-fallback path, keyed by the preset id) and paint the anchor's sentence;
      clear on every text change (Done, Save, load, emptied); `_readContinue` =
      `_readRange(_anchor ?? 0, _content.length, track: true)`; the localized
      `nothingToReadMessage` replaces the hardcoded `'Nothing to read.'`; one
      `debugPrint('klhu read range: $start..$end')` in `_readRange`; the toolbar's page
      button becomes `continueReadButton` (icon stays `Icons.skip_next`). Then run
      `test/reading_view_continue_test.dart` → T004's cases green
- [x] T007 [US1] Update the 30 `'Read page'` literals in `test/reading_view_test.dart` and
      the four other reading-view test files (`test/reading_view_edit_test.dart`,
      `test/reading_view_pause_test.dart`, `test/reading_view_mixed_test.dart`,
      `test/branding_test.dart`), plus the test names that say "Read page", to the new
      label; then `flutter analyze` + the full suite (`flutter test --concurrency=2`) →
      back to green at 234 + the new cases
      (deviation: two more changes the plan did not predict — the old **zh** literal `朗读全文`
      was a live assertion in `reading_view_pause_test.dart` and `branding_test.dart`, and the
      two files that reset the mocked prefs once at file scope needed it per test, because the
      view now *writes* a record that the next test otherwise restores)
- [x] T008 [US1] Device walk on `emulator-5554` per `specs/010-continue-read/quickstart.md` scenarios 13, 14, 15
      and 18, with PASS/FAIL rows and evidence lines written into
      `specs/010-continue-read/breakpoint.md`: tap a middle paragraph → Continue Read starts there; the record in
      `shared_prefs/FlutterSharedPreferences.xml`; force-stop + relaunch restores it; `pm clear` ⇒
      `klhu read range: 0..<len>`; the scope check
      (deviation: scenario 18's `grep -rn "Read page" lib/ test/` does match once — the new
      suite's own `findsNothing` guard, and nothing in `lib/`; the walk also found that the
      page's text is ONE semantics node, so "tap paragraph 3" is a position inside the block,
      not a node of its own)

**Checkpoint**: US1 is complete and independently demonstrable — the anchor is set,
persisted, restored and cleared, and the device walk proves the read starts where the user
pointed.

---

## Phase 4: User Story 2 — Sentence-granular pause/resume (P2)

**Goal**: pausing inside a long paragraph and resuming repeats only the sentence that was
in progress, never the paragraph from its top, and never a sentence already heard.

**Independent Test**: with a multi-sentence paragraph, pause during its second sentence,
resume — the second sentence is heard again from its start and the first is not
(quickstart scenario 12 at unit level; scenario 16 on the device).

### Tests for US2 ⚠️ (write first, run RED)

- [x] T009 [US2] Add the FR-011 cases to `test/reader_service_test.dart` (real
      `ReaderService`, `FakeTtsBackend` at the platform seam): one paragraph speech holding
      three sentences is spoken as three utterances in order; `onParagraphStart` fires
      **once** for that paragraph, on its first sentence; pause during the second utterance
      + resume replays the second utterance and not the first, then carries on to the
      third; a speech whose text begins mid-paragraph (an anchor range) splits with its
      remainder as the first sentence. Assert the two existing 005 pause/resume cases in the
      same file still pass. Run it and keep the RED output (today the whole paragraph is one
      utterance, so the sentence-level assertions fail)

### Implementation for US2

- [x] T010 [US2] Split the queue per sentence in `lib/reader_service.dart`: `sentenceRanges`
      from `package:klhu/segmenter.dart` cuts each `ParagraphSpeech.text` into whole-sentence
      utterances, each carrying its paragraph's language and picked voice and its paragraph
      index (what `onParagraphStart` reports, once per paragraph, on its first sentence);
      keep `_cursor`, the generation guard and the stop-first behaviour; replace the
      "paragraph granularity" wording in the `pause`/`resume` doc comments with the sentence
      rule; add the per-utterance `debugPrint('klhu speak p$p s$s "$prefix"')`. Then run
      `test/reader_service_test.dart` → T009 green, and the full suite → still green
- [x] T011 [US2] Device walk on `emulator-5554` per `specs/010-continue-read/quickstart.md` scenarios 16 and 17,
      with the rows written into `specs/010-continue-read/breakpoint.md`: pause inside a paragraph, resume — the
      next `klhu speak` line after the resume is the interrupted sentence and no earlier sentence of that
      paragraph is synthesized again; then a full pre-set read in EN, ZH and ES passes the listening check for
      sentence boundaries, with the engine's own `Synthesis request` lines as the cross-check
      (deviation: only scenario 17's machine half is claimed — 8 sentences / 8 utterances / 8
      engine requests per language, one engine locale per read. Nobody listened to the audio, so
      the human judgment of D12's accepted cost stays unverified and is marked as such)

**Checkpoint**: US1 and US2 work independently — the read starts where the user pointed, and
pause/resume is sentence-granular.

---

## Phase 5: Polish & cross-cutting concerns

- [x] T012 [P] Commit the walk driver to `specs/010-continue-read/scripts/` (a
      `continue_read_walk.py` with `ADB_SERIAL` / `KLHU_REPO` / `KLHU_OUT` parameters and
      imports relative to the spec dir) so the device evidence outlives the scratch copy,
      and point the re-run block of `specs/010-continue-read/quickstart.md` at it
      (deviation: the file is `klhu_walk_continue.py`, following `specs/008-content-storage/scripts/klhu_walk*.py`
      rather than this task's `continue_read_walk.py`; it carries parts 13–17, not 13–15)
- [x] T013 [P] Update `README.md`: the 010 row in the spec index and the one-line
      Continue Read / sentence-resume notes
- [x] T014 Tick the boxes in `specs/010-continue-read/tasks.md`, record any deviation
      inline (moved work, superseded steps) instead of leaving the list disagreeing with the
      tree, run the tasks-format checker over every directory under `specs/`, and finish with
      `flutter analyze` + `flutter test --concurrency=2`
      (deviation: no tasks-format checker script exists in this repo — `.specify/scripts/bash/`
      holds only the spec-kit helpers, and none was added for this; the check ran as an inline
      scan over every `specs/*/tasks.md`: each `- [ ]` / `- [x]` line carries a `T<digits>` id,
      and all nine files come back with every task ticked. The only lines that do not match the
      task shape are `tasks-template.md`'s two legend rows in `specs/004-…`, which are not tasks)

---

## Dependencies & ordering

- **T001 → T002 → T003/T004 → T005 → T006 → T007 → T008** is the US1 chain: the label key
  must exist before the view compiles, the store contract test must be RED before the store
  exists, and the device walk needs the built app.
- **T009 → T010 → T011** is the US2 chain and is **independent of US1**: the service change
  does not read the anchor, and US1's widget fakes carry their own granularity (grounding
  note 8). US2 can be done before, after or in parallel with US1 — the only shared file is
  `specs/010-continue-read/breakpoint.md` (different sections), which is why T008 and T011
  are not marked `[P]`.
- **T003 and T004 are [P]**: different new files, no dependency between them.
- **T012/T013 are [P]** once T008/T011 have produced their evidence.
- US2 after US1 is the recommended order (the resume proof is more convincing from an
  anchored read), but nothing breaks the other way round.

## Parallel opportunities

- T003 ‖ T004: the store contract and the widget suite are separate new files.
- T012 ‖ T013: a script and the README.
- Within US1, T005 → T006 → T007 are sequential: they are the same behaviour seen by
  successively larger parts of the suite, and T006's red-to-green is T004's suite.

## Implementation strategy

1. **MVP** = Phase 1 + Phase 2 + US1 (T001–T008): Continue Read with a persistent,
   visible start position, device-proven.
2. **Second increment** = US2 (T009–T011): sentence-granular resume, provable on its own
   (its tests never touch the anchor).
3. **Polish** = T012–T014: the written record, the README, the final ticks.
4. If US2's device listening check (scenario 17) says the sentence boundaries sound worse
   than the paragraph read, stop and revisit `research.md` D12's alternative (engine
   word-progress callbacks) before finishing the story — that is a decision, not a bug.

## Notes

- The `[P]` marks are about files, not about attention: `lib/reading_view.dart` is touched
  by T006 only, `lib/reader_service.dart` by T010 only — never both in one step.
- Keep the anchor out of `index.json`. Touching the content library's schema would send
  existing installs down its repair path (contract § Location).
- `flutter test` needs `--concurrency=2` while the emulator runs.
- Every RED claim in the transcript must quote the actual failure (assertion message or
  compile error); a test that was never seen failing is not evidence.

---

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 replace the page button with Continue Read | T001, T006, T007, T008 |
| FR-002 tap sets the start position | T004, T006 |
| FR-003 tap-and-hold sets the start position with feedback | T004, T006 |
| FR-004 reading continues from the set position | T004, T006, T008 |
| FR-005 no position ⇒ read from the beginning | T004, T006, T008 |
| FR-006 visual feedback when the position is set | T004, T006 |
| FR-007 clear the position when the content changes | T004, T006 |
| FR-008 persist the position across restarts | T003, T005, T006, T008 |
| FR-009 position beyond the text length degrades gracefully | T003, T004, T006 |
| FR-010 tracking from the set position | T004, T006, T009 |
| FR-011 pause/resume at sentence granularity | T009, T010, T011 |
| SC-001 Continue Read replaces Read Page in the UI | T001, T007, T008 |
| SC-002 position set by tap or tap-and-hold | T004, T006 |
| SC-003 reading begins at the set position | T004, T008 |
| SC-004 position persists across restarts | T003, T005, T008 |
| SC-005 feedback indicates the position is set | T004, T006 |
| SC-006 at most the interrupted sentence repeats | T009, T011 |
