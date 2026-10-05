# Tasks: Multi-Role Dialogue Reading

**Feature**: `014-dialogue-reading` | **Date**: 2026-10-03
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (a dialogue reads as a dialogue, P1), `US2` (every role has its own
voice, P2), `US3` (the roles I confirmed are the roles in the text, P2), `US4` (the dialogue's video, P3),
`US5` (writing the format, P3). Tasks with no story label are shared infrastructure or the walk.

## Status

**Not started.** Nothing under `lib/` or `test/` has been touched for this feature; the working tree carries
only the specification stage's own files plus the unrelated in-flight edits that were already there when this
list was written.

The baseline this list is read against: **445 tests green** and `flutter analyze` clean, measured 2026-10-03
on `306e288` (the figure `quickstart.md`'s Prerequisites carries is 439, from 2026-10-01; the six extra tests
are the uncommitted 2026-10-02 edits that were already in the tree — the Spanish accent-less cases and the
appearance page's inset case — so the number moved before this feature touched anything, and the baseline is
the measured one). T002 records it; T036 closes the list with the same two numbers re-taken.

**Format checker**: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/014-dialogue-reading`
→ **OK (36 tasks, 28 done, 5 `[P]`)** — the receipt after the second device pass (T028, row 24),
re-run 2026-10-03; `task_id_audit.py` reports the same with no duplicate, gap or out-of-order id. It read
**OK (36 tasks, 0 done, 5 `[P]`)** when this file was written and is re-run after every structural edit; a
later edit that breaks the id sequence, pushes a path off a task's first line, or drops an id from the table
is what the receipt stops being true about.

**Device rows**: rows **23 WALKED — PASS (10/10)** and **24 WALKED — PASS (13/13)** on `emulator-5554`
against a debug build of the current code; the driver and the raw logcat lines are in `breakpoint.md`. Rows
25-28 and 33 are pending, each walked in the pass that implements it.

**Suite**: 445 at the baseline (T002) → **529 passing, 0 failing**, `flutter analyze` clean, after T025 —
83 new tests across the six new files (27 dialogue, 11 assignment, 12 role store, 12 resolver, 15 page, 6
video) plus one in the shipped `test/content_list_test.dart` (its delete now clears the content's role
settings). 012's own video tests and 008's own edit tests are green **unmodified** — the checkpoints for US4
and US5: the resolver change and the fourth toolbar button are additive, not re-cuts.

## Grounding notes (decisions these tasks implement)

1. **Roles resolve *into* `List<ParagraphSpeech>`** (D1, FR-019): the page (`lib/reading_view.dart:910`), the
   reader service (`lib/reader_service.dart:337`) and the video (`lib/video_timeline.dart:103`) all consume
   that one type, so the new resolver returns it and no consumer grows a second path.
2. **A turn is a paragraph, and the blank line is its boundary** (D2, FR-003/FR-004/FR-010, the reader's own
   correction of 2026-10-03): `turnsOf` maps `paragraphRanges` (`lib/segmenter.dart:71-108`), so a turn holds
   as many lines and sentences as its paragraph does, and the sentence cutter treats the turn's own `\n` as
   whitespace (`:53-59`) — no new speech path.
3. **The tag is read at the paragraph's head only, and the editor's Format press is the one thing that helps**
   (D3, D12, FR-004/FR-024): a tag anywhere else is ordinary text — spoken, braces and all — so the app
   neither guesses nor repairs, and `formatForDialogue` (rows 32-33) is the reader's own one-press remedy. The
   rule table lives in `plan.md` and `research.md` D3, byte-identical.
4. **The roles are proposed; the removals are the only state, and they carry the text's version** (D4,
   FR-006/FR-007/FR-008): `SavedContent.updatedAt` (`lib/models/content.dart:40`) is the version, and an edit
   to the text expires a removal — no new field.
5. **A role's voice is the reader's pick, else an assignment computed from the live voice list** (D5,
   FR-012–FR-017): nothing about a voice is stored except the pick; the assignment prefers the turn's language,
   then the same dialect (read from the voices' own locales, corrected 2026-10-03), then a gender that
   differs from the roles already placed, and is deterministic.
6. **The settings are one prefs key, keyed by the content's id, read tolerantly** (D6, FR-021): 012's store
   shape (`lib/video_record.dart`), and a malformed entry is ignored rather than repaired.
7. **The picker is the shipped one, with two additions, and the language-level picker is untouched** (D7,
   FR-012): an optional title and a first row meaning *follow the automatic assignment*, both present only
   when the page opens it for a role.
8. **The page gains one entry and two surfaces, and no new state** (D8, FR-001/FR-002/FR-020/FR-022): the type
   chooser and the role list, reachable from the reading page, while 标准 stays today's reading exactly.
9. **The video is one call-site substitution** (D9, FR-018): the same resolver, so a dialogue's frames carry
   the turn's content alone and its audio is the read's own per-role voices.
10. **Two log lines gain a field** (D10, the device rows' witness): the reader's `klhu speak …` gains the role
    and the voice, the renderer's `klhu render slot=…` gains the role. Additive, so 011's/012's rows and their
    checks keep working — no test asserts either line (`grep -rn 'klhu speak\|klhu render' test/` → nothing), so
    this is device evidence, not a unit assertion.
11. **Verification is the tree's own shape** (D11, constitution III): each story's `[unit]` file is written and
    run RED before that story's code, then one device walk covers the rows a unit test cannot hear (which voice
    the engine was given, whether a removal survives a restart), then 011's and 012's receipts are re-run as
    structural rows. A compile error counts as RED — say so when it is one.
12. **The shipped test files are NOT re-cut** (plan ripple note 1, corrected 2026-10-03): the page tests assert
    per label (`test/reading_view_video_test.dart:321-339`) and none enumerates the app bar's actions or counts
    the editor toolbar's buttons, so every new assertion lands in the six new files. The one file that could
    still move is `test/content_list_test.dart` (T018) — re-check and report, never quietly edit.
13. **New copy lands in all four ARBs at once** (T001): `test/l10n_keys_test.dart` fails in both directions, so
    a partially translated addition cannot pass.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/014-dialogue-reading/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up can
  make plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated files are
  part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; the walk driver
  lives at `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` and the fixture it pushes at
  `specs/014-dialogue-reading/scripts/klhu_dialogue_fixture.txt`
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/014-dialogue-reading`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the copy every state of this feature draws on. Nothing is installed — this feature adds no
dependency, no asset and no platform file (plan § Technical Context).

- [x] T001 Add this feature's message keys to the template `lib/l10n/app_en.arb` and the three translations
      `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`, `lib/l10n/app_es.arb` — the reading page's new entry
      and its title, the two types (`标准` / `多人对话`) and the one-line hint for the dialogue type, the role
      list's title and its empty message, a role's turn count and its voice label plus the *automatic* label
      (the list's own text when the role has no pick, and the picker's first row), the remove action with its
      confirmation title and message, the picker's title for a role (a placeholder), and the editor's Format
      button — then `flutter gen-l10n` and confirm the diff is exactly the four ARBs plus the regenerated
      `lib/l10n/app_localizations*.dart`. The template keys must exist before any widget task compiles against
      them, and only the template carries `@`-metadata (the generator rejects metadata in a translation file).
      The plan's estimate was ~18-25 keys; the count this lands is written into the tick, and every key
      `test/l10n_keys_test.dart` sees missing in any locale is a red check, not a shortcut.
      **DONE 2026-10-03**: 15 keys per ARB (90 → 105), all four in sync —
      `textTypeButton`, `textTypeTitle`, `textTypeStandard`, `textTypeDialogue`, `textTypeDialogueHint`,
      `roleListTitle`, `roleListEmptyMessage`, `roleTurnCount` (plural, int placeholder),
      `roleVoiceLabel`, `roleVoiceAutomatic`, `roleRemoveButton`, `roleRemoveConfirmTitle`,
      `roleRemoveConfirmMessage`, `rolePickerTitle` (String placeholder), `formatButton` — so the plan's
      ~18-25 was 15 in practice. `@`-metadata on the two placeholder keys, template only. `flutter gen-l10n`
      regenerated `app_localizations.dart` + `_en` + `_es` + `_zh` (the last covering both Chinese files, so
      the diff is four ARBs plus four generated files, not eight generated); `flutter test
      test/l10n_keys_test.dart` → 3 passing; `flutter analyze` → No issues found.

**Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green (key parity in both
directions across the four ARBs).

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the baseline receipt, and the two pure modules every story's layer sits on. Both are
device-free by construction, which is why they are the only genuinely shared work.

- [x] T002 Record the baseline over the whole `test/` tree before touching anything: `flutter analyze` (expect
      clean) and `flutter test --concurrency=2` (expect **439 passing, 0 failing** — `quickstart.md`'s
      Prerequisites figure), then write both numbers into the Status section of
      `specs/014-dialogue-reading/tasks.md` with the date and the command, and say which revision they were
      taken on (`git rev-parse --short HEAD`). If the count differs from 439, that difference is the first
      thing the handback reports: a drifted baseline is the reason every later tick would be measured against
      the wrong number.
      **DONE 2026-10-03, before T001** (the baseline has to be taken before the first edit, so this task ran
      first even though the list numbers it second — the reorder is recorded here rather than left implicit):
      `flutter analyze` → No issues found; `flutter test --concurrency=2` → **445 passing, 0 failing** on
      `306e288`. The count is 6 above the spec's 439 because the tree already carried uncommitted 2026-10-02
      edits (the Spanish accent-less cases and the appearance page's inset case), which is exactly the
      difference this task exists to catch. Written into the Status section.
- [x] T003 Write `test/dialogue_test.dart` from quickstart rows 1-5 and 12: the tag rule's accepted and refused
      shapes (the reader's own examples: `{May} : hello`, `{阿明} 你好` against `12:30`, `https://…`, `他说：`,
      `{May : hello`, `{} hello`, full-width braces), a turn's span excluding the prefix and covering the whole
      paragraph, the blank line as the only boundary, a paragraph with no tag as one narration turn never
      attributed to another role, a tag inside a paragraph read as ordinary text (braces included), roles in
      first-appearance order with their readable turn counts, and the language rule running per turn. Run it
      and keep the RED output.
      **DONE 2026-10-03** — `test/dialogue_test.dart`, 27 tests, all green (`flutter test test/dialogue_test.dart`).
      The cases are the spec's own examples (D3's accepted and refused lists, the reader's 2026-10-03 answers),
      not values read off the implementation. RED receipt: with `lib/dialogue.dart` moved aside the file fails
      to load — `00:00 +0 -1 … loading test/dialogue_test.dart`, a compile error rather than an assertion
      failure, which is what a RED for a new module is here; the module was written before its test in this
      pass, so the RED is taken by removing it, and that is the one deviation this task carries. Two cases the
      plan's wording did not settle and the code does: a turn's content ends at its last non-whitespace
      character even though `paragraphRanges` leaves the last paragraph's trailing spaces in, and no blank line
      is added before a tag that already heads its paragraph.
- [x] T004 [P] Write `test/role_assignment_test.dart` from quickstart rows 9-11: the ranking (the turn's
      language first, then the same dialect, then a gender that differs from the roles already placed), the
      same content assigning the same voices twice (determinism, asserted as a relationship between two runs),
      the gender-spreading case, and the too-few-voices bound where every role still has a voice and the
      sharing is visible. Run it and keep the RED output.
      **DONE 2026-10-03** — `test/role_assignment_test.dart`, 11 tests, all green. Same module-wide RED as
      T003 (no `lib/dialogue.dart` → the file does not load). One claim the implementation DISPROVED, fixed in
      `data-model.md` §4, `research.md` (the fact table and D5), `plan.md`, `quickstart.md` row 9 and this
      file: the ranking's "same dialect as the reader's pick" was written against `VoiceMapping.dialect`, and
      **no row of that table sets `dialect`** — deliberately (007 FR-010: a Cantonese voice is *named* by its
      dialect, so the field would only repeat the name). The signal the app really has is the voice's own
      LOCALE, which is what the engine is given before each utterance: rule 2 now reads `yue-HK` against
      `zh-CN`/`cmn-CN` (`_dialectFamily`, with `zh` and `cmn` collapsing as one list), so the rule is
      observable and the case "the dialect of that pick comes next" is a real one. A second gap the task's own
      wording had: the engine lists each voice twice (`…-local` / `…-network`) and the picker shows both under
      one name, so assigning the two rows to two roles would give the reader two voices that sound identical —
      candidates are deduped by the name the reader sees, which the tests pin.
- [x] T005 [P] Write `test/role_store_test.dart` from quickstart rows 13-14: the stored shape (the type, the
      removals with the text's version, the picks), a malformed entry ignored rather than repaired, a removal
      holding only against the text it was made on, a pick surviving a reload, and the two writers
      (the type/roles and the delete) each touching only their own content's entry. Run it and keep the RED
      output.
      **DONE 2026-10-03** — `test/role_store_test.dart`, 12 tests, all green. RED proven twice over: the file
      does not load without `lib/role_store.dart` (compile error), and one case failed against the first
      implementation for a real reason — clearing a role's last pick left the previous map in place, so
      `pickFor` still answered the old voice (`Expected: null / Actual: <Instance of 'VoiceChoice'>`,
      `test/role_store_test.dart:96`). Fixed in `_write` (an emptied `voices` map is removed, not left alone);
      the case that caught it is the one the row needed, which is why it stays as written.
- [x] T006 Implement `lib/dialogue.dart`: the tag rule as a table (the shape `lib/language.dart:29-74` uses),
      `turnsOf(content, [range])` mapping `paragraphRanges` to turns, the role proposal (distinct names in
      first-appearance order with readable turn counts, a removal applied against the text's version), and the
      assignment function over a live voice list. Pure Dart, no widget, no store, no I/O; every rule states its
      FR id in a comment, and the tag table is byte-identical to `plan.md`'s. Green against T003/T004/T005.
      **DONE 2026-10-03** — `lib/dialogue.dart` (~470 lines incl. the doc comments), `flutter analyze` clean,
      38 tests green across T003's and T004's files. Public surface: `RoleTag`, `roleTagAt`, `Turn`, `turnsOf`,
      `Role`, `rolesOf`, `tagOffsets`, `formatForDialogue`, `assignTurnVoices`, `languageOfVoice`. Three
      decisions the plan left open, all recorded in the file's own comments: (1) `turnsOf` takes
      `removed: Set<String>` so a removal turns a tag's paragraph into narration while leaving the span where
      it was — FR-007 needs a speaker change, not an offset change; (2) the turn's content is right-trimmed,
      because `paragraphRanges` (`lib/segmenter.dart:71-108`) trims the blank line but not the last paragraph's
      trailing spaces; (3) the candidate list is deduped by display name (see T004). Nothing here reads a
      store, a widget or a device — the module's only inputs are the text, the range and the installed voices.
- [x] T007 Implement `lib/role_store.dart`: one `shared_preferences` key (`content_roles`), a JSON object keyed
      by the content's id — `{type, removed: [{name, at}], voices: {<role>: {name, locale}}}` — shaped after
      `lib/video_record.dart:69-95`, tolerant of missing and stale entries, with the per-content read/write the
      page and the delete path call and a `clearFor(contentKey)` the delete uses. Green against T005.
      **DONE 2026-10-03** — `lib/role_store.dart` (~250 lines), `flutter analyze` clean, 12 tests green.
      Public surface: `RoleRemoval{name, at}`, `RoleSettings{isDialogue, removed, voices, none, isEmpty,
      removedFor(DateTime), pickFor(role)}`, `RoleStore{key, load, setDialogue, removeRole, setVoice,
      clearFor}`, injectable `prefs` like 012's store. The stored shape is exactly `data-model.md` §5's
      `{type, removed:[{name,at}], voices:{role:{name,locale}}}` — the pick carries no language field, so it is
      rebuilt on read from the locale (`languageOfVoice`, new in `lib/dialogue.dart`); a pick whose locale is
      no language the app reads (`fr-FR`) is dropped rather than half-read, so the role falls back to the
      assignment. An entry that says nothing is removed from the key, and an empty store removes the key
      itself — a content the reader undid every decision about costs nothing.

**Checkpoint**: the three RED files are green, `flutter analyze` clean, and no widget has been touched yet.

---

## Phase 3: User Story 1 — A dialogue reads as a dialogue (P1) 🎯 MVP

**Goal**: the type, the turns and the read. A content whose text tags its speakers reads as those roles'
turns, in the roles' voices, with the tags never spoken; 标准 stays the shipped reading exactly and switching
touches nothing but the setting. The per-role voices (US2) and the confirmation list (US3) come after.

**Independent Test**: quickstart row 23's read — 100 % of the utterances carry no tag and no role name, and a
roster line names which voice the engine was given (row 3's own line is the unit half).

### Tests for US1 ⚠️ (write first, run RED)

- [x] T008 [P] [US1] Write `test/speech_resolver_test.dart` from quickstart rows 6-8: 标准 mode returns exactly
      what `resolveParagraphSpeeches` returns for the same input (asserted as a relationship between the two
      calls, not as a snapshot of offsets), dialogue mode returns one `ParagraphSpeech` per turn whose text is
      the turn's content and whose language is that content's own, and a role's pick decides its voice whatever
      the turn's language is. Run it and keep the RED output.
      **DONE 2026-10-03** — `test/speech_resolver_test.dart`, 12 tests, all green. RED receipt: with
      `lib/speech_resolver.dart` absent the file does not load (`00:00 +0 -1 … loading
      test/speech_resolver_test.dart`). Two contracts the row's wording did not name and the test does:
      标准 never calls the installed-voice loader at all (a spy that flips a flag), and dialogue mode is
      asserted *against* `resolveParagraphSpeeches` — the standard case compares the two calls' outputs on four
      shapes rather than freezing offsets. It also asserts the tag is not inside any span
      (`content.substring(start, end) == text`, no `{` in any speech).
- [x] T009 [P] [US1] Write `test/reading_view_dialogue_test.dart` from quickstart rows 15 and 18: the entry is
      offered in 标准 too and shows the type alone; switching types never edits the text (the edit controller's
      value and 008's `updatedAt` unchanged), never clears the highlight, never writes a reading position, and
      touches only the `content_roles` entry; and for a content with no stored settings every shipped
      behaviour holds with the one added entry and no role list anywhere. Run it and keep the RED output.

### Implementation for US1

      **DONE 2026-10-03** — `test/reading_view_dialogue_test.dart`, 6 tests, all green (the file's own
      harness: a recording fake reader, the real page over a temp content store, a clean mock
      `shared_preferences` per test). Two cases failed first, for real reasons, and both were fixed in the test
      rather than the code: `store.list()` is real file IO and on the fake clock never calls back (`did not
      complete`) — it now runs inside `tester.runAsync`; and the reading-position assertion was wrong — a TAP
      is what writes the position (010), so the contract is "the value after the switch equals the value the
      tap wrote", not "no value". One case beyond the row's wording: the same tagged content is read in both
      modes side by side, so 标准 reading the text as written (tags and all) is pinned next to dialogue mode
      stripping the prefix.
- [x] T010 [US1] Implement `lib/speech_resolver.dart`: one function with two modes — 标准 delegates to
      `resolveParagraphSpeeches` (`lib/language.dart:110`) unchanged, 多人对话 returns `turnsOf`'s turns
      resolved into `ParagraphSpeech`s with each turn's detected language and its role's voice (the pick, else
      the assignment). The mode and the role settings are parameters, never globals; the file carries the one
      comment saying why a mode is read in one place (D1). Green against T008.
      **DONE 2026-10-03** — `lib/speech_resolver.dart` (~115 lines), `flutter analyze` clean, 12 tests green.
      `ReadingMode {standard, dialogue}` + `resolveSpeeches({content, start, end, mode, removed, picks,
      loadVoice, loadInstalled})` — the signature research D1 recorded, with the roles split into the two
      things the store actually holds (`removed`, `picks`) instead of an opaque `roles` object. 标准 is one
      call into `resolveParagraphSpeeches` and returns before touching anything else; 多人对话 builds the turns,
      loads each language's pick once (`loadVoice` is async, the assignment needs a sync lookup, so the picks
      are resolved per language first), then assigns. It also prints the assignment line (T012).
- [x] T011 [US1] Implement the page's entry and the type switch in `lib/reading_view.dart`: one app-bar action
      (the same shape as the appearance/voice/video actions at `:1923-1945`) opening the type chooser — the
      shipped either/or chooser shape (`:1400`'s aspect dialog) — and, in 多人对话, the role list's own
      surface; the store is read once per content and the read path calls the shared resolver instead of
      `resolveParagraphSpeeches` directly (`:910`); switching writes the type through `lib/role_store.dart`
      and re-resolves on the next read without moving the position, the highlight or 008's text. No new state
      beyond the loaded settings. Green against T009; quickstart rows 15, 18 and 26 hold.
      **DONE 2026-10-03** — `lib/reading_view.dart`. Added: the content-scoped `_roles`/`_rolesVersion`
      fields and the lazily-built `_roleStore` (the `_recordStore` pattern); `_setAnchorKey(key, {version})` now
      loads the settings for the text it is switching to (with the entry's `updatedAt` as the removal version,
      or the epoch for a shipped pre-set, whose text cannot change); `_loadRoles`, `_setDialogue` and
      `_openTextType` (a `ChoiceChip` chooser in the video-aspect dialog's shape, applied as the reader taps,
      with the dialogue hint — the role rows are T015); one new app-bar action
      (`Icons.forum_outlined`, tooltip from `textTypeButton`) placed after Contents and enabled while a read is
      in flight, since switching touches nothing (FR-020); and `_readRange` now calls `resolveSpeeches` with the
      mode, the removals for the current version and the picks, loading the device's voices through
      `reader.voicesFor` for the three languages — only 多人对话 ever calls that. 6 page tests green;
      `flutter analyze` clean; the whole suite green. Not yet offered: the role list (T015) and the removal
      action (T017).
- [x] T012 [US1] Add the role and the voice to the reader's per-read log line in `lib/reader_service.dart:481-484`
      (`klhu speak p2 s0 role=阿明 voice=… "<text>"`), keeping every existing field and its order so 011's and
      012's own greps keep matching. This is D10's witness for the device rows — no shipped test asserts the
      line, so its receipt is row 23's logcat output, not a unit test.

**Checkpoint**: rows 6-8, 15, 18 (unit) green; a dialogue content reads as its roles on the page; 标准 is
unchanged for a content with no stored type.

---

## Phase 4: User Story 2 — Every role has its own voice (P2)

**Goal**: the role list and the picker. Each role's row names its voice (the pick's, or the assignment's, by
the voice's own name), the reader can give a role a voice through the shipped picker, and clearing that pick
returns the role to the assignment.

**Independent Test**: quickstart row 27/28's device half — four picks produce four distinct voices and each
utterance's log line names its role's own voice — read against the assignment printed by row 24.

### Tests for US2 ⚠️ (write first, run RED)

      **DONE 2026-10-03** — `lib/reader_service.dart` + `lib/speech_resolver.dart`. The speak line is now
      `klhu speak p2 s0 role=阿明 voice=yue-hk-x-yud-local "…"` (role/voice omitted when null, so every existing
      line still reads the same and 011's/012's greps keep matching), and a dialogue read prints the assignment
      once: `klhu roles 阿明→yue-hk-x-yud-local(male) narration(zh-Hans)→cmn-cn-x-ccc-local …` (`os-default`
      where the engine has no such voice). **One claim the implementation had to change**: D10's example needs
      the ROLE on the speech, but D1 had explicitly rejected a role field on `ParagraphSpeech`/`_Utterance`
      ("three types, every consumer and every test fake changes"). The field can be optional, so it is:
      `ParagraphSpeech.role` is set by the resolver alone, `_Utterance` passes it through, and every existing
      construction site is untouched (the suite's 513 tests prove that). Recorded in `research.md` D1's
      alternatives, `data-model.md` §6 and `quickstart.md` row 23.
- [x] T013 [US2] Write the role list and the picker rows into `test/reading_view_dialogue_test.dart` from
      quickstart rows 16-17: one row per proposed role in first-appearance order, each with its turn count and
      its voice's name, plus the remove action; and the role's picker — titled with the role's name, its first
      row meaning *follow the automatic assignment*, tapping it clearing the pick so the list shows the
      assignment again — while the language-level picker is exactly today's screen (no title, no extra row).
      Run it and keep the RED output.

### Implementation for US2

      **DONE 2026-10-03** — five more cases in `test/reading_view_dialogue_test.dart` (11 in the file),
      all green after T014/T015. RED receipt: all five failed for the right reason before the code existed
      (`Found 0 widgets with text "阿明"`, `Found 0 widgets with text containing CCD`), while the shipped six
      stayed green. The voice names in the assertions are built by calling `VoiceMappingService.displayName`
      in the test rather than written out, so a rename in the mapping table cannot make the test wrong. One
      thing the cases needed and the row did not say: the role name and a voice's name appear on TWO surfaces
      once the picker is open (the list behind, the pushed screen in front), so every finder is scoped —
      `inChooser(...)` / `inPicker(...)` — which is why the first run of the pick cases found two matches.
- [x] T014 [US2] Add the two optional parameters to `lib/voice_picker_screen.dart`: a title for a role and a
      first row meaning *follow the automatic assignment* that clears the pick. Both are absent when the page
      opens the picker for the language path (`lib/reading_view.dart:1939`), so that screen's tests and
      semantics keep their meaning untouched (ripple note 5). Green against T013's picker rows.
      **DONE 2026-10-03** — `lib/voice_picker_screen.dart`. `title`, `clearable`, plus the two the plan's
      own table did not have: `initialSelection` (what to highlight — a role's pick is not in the
      `VoiceStore` this screen holds) and `onPick` (where a pick goes; without it a role's voice would be
      written as the language's, which FR-013 forbids). The *automatic* row is the ListView's first child
      when `clearable`, and clearing calls `onPick(null)`. **The language path passes none of the four** — it
      still reads and writes through `store` and its title is still `l10n.voiceButton` — and
      `test/voice_picker_test.dart` + `test/voice_picker_semantics_test.dart` are green *unmodified*, which is
      ripple note 5's guard read as a receipt rather than a promise. **Correction recorded**: research D7 and
      `data-model.md` §3.b both said "two additions"; both now carry the four, with the reason
      (corrected 2026-10-03 by the implementation).
- [x] T015 [US2] Implement the role list in `lib/reading_view.dart` on the surface T011 added: one row per
      role — name, readable turn count, and the voice's own name from the pick or the assignment (with the
      gender the app records where it has one, and no age anywhere, FR-016/FR-017) — opening
      `VoicePickerScreen` for that role and storing the pick through `lib/role_store.dart`; a role with no pick
      reads the assignment, recomputed per read from the live voice list (FR-012–FR-015). Green against T013.

**Checkpoint**: rows 9-11 and 16-17 green; `test/voice_picker_test.dart` and
`test/voice_picker_semantics_test.dart` still green *unmodified* — if either needs a re-cut, the language
path's guard failed and the difference is reported rather than edited away.

---

## Phase 5: User Story 3 — The roles I confirmed are the roles in the text (P2)

**Goal**: a proposal the reader can correct. Removing a role makes its paragraphs narration afterwards, the
removal is remembered for that version of the text, and editing the text makes the proposal live again.

**Independent Test**: quickstart row 29's device half — a removed name is still not a speaker after a restart
— plus rows 13-14's unit half for the version rule.

### Tests for US3 ⚠️ (write first, run RED)

      **DONE 2026-10-03** — `lib/reading_view.dart` + `lib/speech_resolver.dart` + `lib/role_store.dart`.
      The chooser now shows, under the type chips: the hint, then one row per proposed role — name, `2 turns ·
      普通话 CCC` (the count plus the voice's own display name, via `VoiceMappingService`; no age, FR-017) —
      with the empty message when the text tags nobody. A row opens `VoicePickerScreen` for that role, titled
      with its name, on the language of its first turn, with `clearable: true`, the page's pick as
      `initialSelection` and a sink that writes `RoleStore.setVoice` and refreshes the page's copy. The rows
      and the assignment are recomputed on open and after every change, through a new
      `resolveRoleVoices` in the resolver that shares `_assign` with the read — so the list and the reading
      cannot disagree (FR-016). `RoleSettings.withVoice` mirrors the store's shape for the page's own copy,
      and `_installedVoices()` replaced the read path's inline voice-list closure (both the list and the read
      use it). 11 page tests green; whole suite 518 green; `flutter analyze` clean. Not yet: the removal
      action (T017) — the row has no trailing button yet.
- [x] T016 [US3] Write the removal into `test/reading_view_dialogue_test.dart` from quickstart row 16's second
      half: removing a row takes it out of the list, stores the removal with the text's version, and
      re-resolves the content so the removed name's paragraphs are narration (not the previous speaker's, not
      a new role); after an edit that bumps `updatedAt` the name is proposed again. Run it and keep the RED
      output.

### Implementation for US3

      **DONE 2026-10-03** — two cases in `test/reading_view_dialogue_test.dart` (13 in the file). RED receipt:
      `Found 0 widgets with icon "IconData(U+0F27F)" descending from widgets with type "ListTile" that are
      ancestors of widgets with text "阿芳"` — the remove action did not exist. The expiry half was green
      before the code (the list already read `removedFor`), which is the point of writing both halves: one
      guards the new action, the other guards the versioning the action writes against. The read assertion
      uses `FakeReader.utterances` (added here): the *voice* is what no widget finder can see, and the
      expectation is `['cmn-cn-x-ccc-local', null]` — 阿芳's line is narration, whose voice is the reading
      voice (the OS default while no language pick exists), never the voice the assignment had given it.
- [x] T017 [US3] Implement the remove action in `lib/reading_view.dart`: a removable row with the shipped
      confirmation dialog shape (Cancel + filled confirm, `:735-753`) and its own keys, writing the removal
      through `lib/role_store.dart` with the content's `updatedAt`, and re-resolving the content afterwards
      without touching 008's text, its undo history or the stored position. Green against T016.
      **DONE 2026-10-03** — `lib/reading_view.dart` + `lib/role_store.dart` + one string. A trailing
      `IconButton` (`Icons.person_remove_outlined`, `l10n.roleRemoveButton` as its tooltip) on each role row,
      confirmed in the shipped dialog shape (`_confirmDiscard`'s: Cancel + `FilledButton`) with the three
      strings R7 already added (`roleRemoveConfirmTitle`, `roleRemoveConfirmMessage`, `roleRemoveButton`), then
      `RoleStore.removeRole(key, name:, at:)` and `RoleSettings.withRemoval` for the page's own copy. Nothing
      008 owns is touched (no text, no undo history, no stored position) and a read in flight is not stopped.
      The picker's title now uses the key R7 added for it, `l10n.rolePickerTitle(role)` ("Voice for 阿明"),
      which was otherwise a dead string; the test asserts it through the l10n, not as a frozen sentence.

      **The test found a real bug, in the version the removal is written against** (FR-007). The page has
      three ways of opening a content and they disagreed: `_loadCatalogFallback` versioned a pre-set by the
      epoch, `_loadEntry` (the pick-from-the-list path) by the seeded entry's `updatedAt`, and the save path
      by the saved entry's. So a removal made after opening a content from the list was **out of force** the
      next time it was opened the other way — silently, with the name quietly a role again. The test's
      `expect(content['removed'], [{'name': '阿芳', 'at': <the value>}])` is what surfaced it. Fixed with one
      line — a pre-set is versioned by the epoch whichever path opens it — because a pre-set's text cannot
      change (`saveEdited` on a pre-set saves a **new** content with its own id). Recorded in research D4 and
      `data-model.md` §5 as a correction, and the three call sites now say which version they pass and why.
      An earlier attempt (looking the seeded entry up in the fallback, so the entry's `updatedAt` could be
      used everywhere) was reverted: it made the no-storage fallback need storage, and 57 shipped tests failed
      on the extra IO round — the fallback is the path that must work when storage does not.
- [x] T018 [US3] Clear the content's role settings on delete in `lib/content_list_screen.dart:108`, beside the
      existing `widget.store.delete(entry)`: the store is the same direct shape the shipped page uses
      (`RoleStore()`, no new constructor parameter), so `test/content_list_test.dart` is expected to stay green
      unmodified — verify that by running it, and if the clear does need injection, re-cut that file's
      constructions and say so in the tick (plan ripple note 1's one open question).

**Checkpoint**: rows 13-14 and 16 green; the list, the removal and the delete all behave; the shipped list
tests are green or the deviation is written down.

---

## Phase 6: User Story 4 — The dialogue's video is the dialogue (P3)

**Goal**: the video of a dialogue sounds like the read and shows no tag. One call site moves onto the shared
resolver; the frames carry the turn's content by construction.

**Independent Test**: quickstart row 27's device half — sampled frames carry no tag and the per-slot audio is
the read's own per-role voice.

### Tests for US4 ⚠️ (write first, run RED)

      **DONE 2026-10-03** — `lib/content_list_screen.dart:108`, beside `widget.store.delete(entry)`:
      `await RoleStore().clearFor(entry.id)`, built directly (no new constructor parameter, as the row
      predicted). **The prediction that `test/content_list_test.dart` stays green unmodified did NOT hold, and
      the failure was informative**: the clear needs `shared_preferences`, and that file never mocked it, so
      two shipped delete tests died with `MissingPluginException(No implementation found for method getAll)`.
      The fix is NOT injection — it is the one line of harness every other page test file already has
      (`SharedPreferences.setMockInitialValues({})` in `setUp`), so the list's tests now run against the same
      environment its own code needs. That file also gained one case, `deleting a content clears its dialogue
      settings too` (11 in the file, all green), because the wiring is otherwise untested: a delete that leaks
      a roles entry is silent, and the store-level half was already covered by row 14. Answer to ripple note
      1's open question: no injection was needed, the harness was missing the mock.
- [x] T019 [P] [US4] Write `test/video_dialogue_test.dart` from quickstart rows 20-22: a dialogue content's plan
      carries per-slot the same voice the read resolves for that sentence (slot by slot, against the read's own
      call, D9), the slot count/frame counts/spans stay what 012's tests assert for the same text, no slot's
      text carries a tag, and the render's slot log line names the role. Run it and keep the RED output.

### Implementation for US4

      **DONE 2026-10-03** — `test/video_dialogue_test.dart`, 6 cases (rows 20, 21, 22). RED receipt: a compile
      error, not a failed expectation — `The named parameter 'mode' isn't defined`, `The named parameter
      'loadInstalled' isn't defined`, `The getter 'role' isn't defined for the type 'VideoSlot'`. The
      fixture is 014's own: `{阿明} 你好。我很好。` / `{阿芳} 我不好。` / `他说：我来了。` — one turn of two
      sentences (so a turn is more than one slot), a second role, and a narration paragraph. Row 20 asserts
      the video's slot voices against **the read's own `resolveSpeeches` answer** (per sentence: name, locale
      and language, plus the role), not against a written-out expectation, and then pins the fixture's own
      answer (`阿明`→ccc, `阿芳`→ccd, narration→null, i.e. the OS default) so the equality cannot be vacuous.
      **Two things the tests found**: (a) `VoiceChoice` is a plain value object with no `==`
      (`lib/voice_store.dart:4`), so a slot/read comparison must be field by field — an instance comparison
      fails on equal picks, and adding `==` to a shipped type used across the app is not this feature's call;
      (b) `VideoPlan.totalFrames` is `slots.last.endFrame`, which **includes the gaps between sentences**, so
      it is not the sum of the slots' frames (120 + 36 + 60 = 216 against a 180 sum). The assertion now states
      the real identity (`sum + gapFrames × (sentences − 1)`), which is 012's own arithmetic.
- [x] T020 [US4] Point `lib/video_timeline.dart:103` at the shared resolver instead of its own
      `resolveParagraphSpeeches` call, passing the content's type and role settings; the function's signature
      and the `List<ParagraphSpeech>` it consumes stay as they are, so its own tests keep their meaning. Green
      against T019.
      **DONE 2026-10-03** — `lib/video_timeline.dart` + `lib/video_renderer.dart` + `lib/reading_view.dart`.
      `videoSentencesFrom` no longer calls `resolveParagraphSpeeches` itself: it calls `resolveSpeeches` —
      the page's read — with four **optional** parameters (`mode`, `removed`, `picks`, `loadInstalled`) whose
      defaults are the standard read, so 012's own callers and tests pass none of them and keep their meaning
      (checkpoint: `video_timeline_test.dart`, `video_renderer_test.dart` and `reading_view_video_test.dart`
      are green **unmodified**). `render()` gained the same four and forwards them; the page passes its
      content's type, its live removals (`removedFor(_rolesVersion)`), its picks and `_installedVoices()`.
      `VideoSentence` and `VideoSlot` gained an optional `role` (copied from `ParagraphSpeech.role`,
      `videoSentencesOf` → `buildVideoPlan`, hold included), which is what T021's line prints. The
      `language.dart` import went with the old call — the timeline no longer resolves anything itself.
- [x] T021 [US4] Add the role to the renderer's per-slot log line in `lib/video_renderer.dart:348-350`, keeping
      the existing fields in place so 012's row 32's checks (`slot=i/n`, `text=n` through `span=`) keep
      matching. Additive; the evidence is row 27's logcat, not a unit assertion.

**Checkpoint**: rows 20-22 green; 012's own video tests still green unmodified.

---

## Phase 7: User Story 5 — Writing the format: one press puts every tag at the head of its own paragraph (P3)

**Goal**: the editor's Format button. One press inserts a blank line before every tag that is not already the
head of its own paragraph, changes nothing else, is one undo step, and is disabled when there is nothing to
do.

**Independent Test**: quickstart row 33 — the editor's own text dumped before and after the press, one Undo
restoring it byte for byte, then Done saving it.

### Tests for US5 ⚠️ (write first, run RED)

      **DONE 2026-10-03** — `lib/video_renderer.dart`'s per-slot line now carries
      `role=${run.slot.role ?? "narration"}`, placed **between `tone=` and `span=`**: 012's row 32 greps the
      line for `slot=i/n` and `text=n` … `span=`, and appending after `text=` would have broken a
      `text=(\d+)$`-style check. Everything 012 asserts on the line is untouched. No new unit assertion of
      the line itself: the quickstart's row 22 says "the existing log assertion, extended", and there is no
      existing log assertion in `test/video_renderer_test.dart` — the line has only ever been device
      evidence (row 32). Row 22's unit half is therefore the *slot* carrying its role (T019's third case),
      which is what the line prints; the line's own shape stays row 27's logcat.
- [x] T022 [US5] Add the Format transformation's cases to `test/dialogue_test.dart` from quickstart row 32: a
      tag already at a paragraph's head, two tags on one line, a tag on a paragraph's second line, a tag in the
      middle of a line, no tag at all, an unclosed brace, `{}`, full-width braces — the result has every tag as
      the first non-space characters of its own paragraph, the difference from the input is `\n\n` and nothing
      else, and a text with nothing to format comes back byte-identical. Run it and keep the RED output.
      **DONE 2026-10-03 — the cases already existed, verified rather than written.** The `Format (FR-024)`
      group in `test/dialogue_test.dart` (written with the module in T004's pass, lines 166-224) already covers
      every shape row 32 lists: a tag already heading its paragraph (byte-identical), two tags on one line, a
      tag on a paragraph's second line, a tag mid-line, no tag at all, an unclosed brace, `{}`, full-width
      braces, "only blank lines are added" (an exact `replaceAll('\n','')` comparison, which is the row's
      "no other character added, removed or reordered" made checkable), and idempotence with the roles
      afterwards. The first run was **green** — no RED to keep, because the transformation shipped with the
      module it belongs to; the RED this story actually has is the button (T023). **One wording correction**:
      the row says the difference is `\n\n`, but the implementation (and `data-model.md` §2.a, which is where
      the two-form rule was settled) inserts `\n\n` before a tag with content earlier on its line and a
      single `\n` before one that already begins a line — either way exactly one blank line, the smallest edit
      that makes the tag a paragraph head, and no extra blank line for the common "each turn on its own line"
      shape. Research D12's older wording said `\n\n` unconditionally and now carries the refinement.
- [x] T023 [US5] Add the button's own case to `test/reading_view_dialogue_test.dart` from quickstart row 32:
      opening a content with an inline tag in edit mode, reading the button's enabled state, pressing it,
      reading the controller's text back, and pressing Undo. Run it and keep the RED output.

### Implementation for US5

      **DONE 2026-10-03** — two cases in `test/reading_view_dialogue_test.dart` (15 in the file): the press
      itself and the disabled state. RED receipt: `Found 0 widgets with icon "IconData(U+0F27F)"` for the
      button, and the same for the disabled case. The press case reads the *controller's* text (the editor is
      a `TextField` over `_editController`), asserts the exact formatted string, then presses Undo and asserts
      the original. **The case found something the plan's one line hid**: the platform undo stack throttles
      pushes to one per 500 ms (`widgets/undo_history.dart`, `_kThrottleDuration`) and an Undo *inside* that
      window cancels the pending push instead of undoing it — and a change made in the same window as EDIT's
      own mount push coalesces with it, leaving one state and nothing to undo. Two probe runs showed the
      toolbar's Undo still disabled after the press. The fix is the wait 008's own edit tests already use
      (`test/reading_view_edit_test.dart:513-519`, whose comment names this exact trap). It is a real
      consequence, not a test artifact: a reader who presses Format within 500 ms of entering EDIT gets an
      undo-less press, the same way a keystroke in that window does. Row 33 now tells the device driver to
      wait > 500 ms between presses, or it will read the app as broken.
- [x] T024 [US5] Implement `formatForDialogue(String text)` in `lib/dialogue.dart` beside `turnsOf`, sharing
      the one tag grammar: `\n\n` inserted immediately before every tag occurrence that is not already the head
      of its own paragraph, the input returned unchanged otherwise, nothing else added, removed or reordered.
      Green against T022.
      **DONE 2026-10-03 — already implemented, verified against T022.** `formatForDialogue` lives in
      `lib/dialogue.dart` (line 236) from the pass that wrote the module whole; its docstring already states
      the two-form rule and the invariants. T022's cases are green against it, and the only edit it needed was
      none — the refinement was already recorded in `data-model.md` §2.a and is now also in research D12. It
      shares the tag grammar with `roleTagAt` (one `heads` set from `paragraphRanges` + `roleTagAt`, one scan
      for `{`), which is what the row asked for.
- [x] T025 [US5] Add the Format button to the edit toolbar in `lib/reading_view.dart` (`:2064-2083`, today Undo
      / Save / Done): it assigns `formatForDialogue`'s result to `_editController.value` once — one undo entry,
      the way `_enterEdit` seeds the stack at `:614` — and is disabled when the result equals the input, the
      pattern the Undo button already uses (`:2069`). It saves through 008's path (Save or Done) and its
      refusals are 008's own. Green against T023; quickstart row 33 holds.

**Checkpoint**: rows 32-33 green; the editor's toolbar offers four buttons and the shipped edit tests are
green unmodified.

---

## Phase 8: The device rows (the walk)

**Purpose**: the rows a unit test cannot hear — which voice the engine was given, whether a removal survives a
restart, whether a dialogue's video sounds like the read. One command per row, each printing its evidence and
ending `RESULT: PASS|FAIL` (012's convention).

      **DONE 2026-10-03** — `lib/reading_view.dart`: a fourth button in the toolbar's `editing` branch, the
      first of the four, with `Icons.format_line_spacing` and the tooltip R7 already wrote
      (`l10n.formatButton`, "Format" / "排版" — an unused string until now). It is wrapped in a
      `ValueListenableBuilder<TextEditingValue>` over `_editController` so the enabled state follows what the
      reader types: the page has no other listener on the editor's text (only the *undo* controller has one),
      so a bare `onPressed` computed at build time would go stale after the first keystroke. `_formatDialogue`
      assigns the result in one `controller.value = …` (one undo entry) and returns early when the press would
      change nothing. Nothing else changed: the toolbar's other three buttons, save path and refusals are
      008's. Shipped edit tests green **unmodified**, which is the checkpoint. Icon choice is mine and easy to
      swap: `format_line_spacing` (lines with spacing) — `auto_fix_high` (the wand) is the other candidate.
- [x] T026 Write the walk driver `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` and the fixture it
      pushes, `specs/014-dialogue-reading/scripts/klhu_dialogue_fixture.txt` (the reader's own four-role
      example: 旁白 / 阿明 / May / 阿芳, one turn to a paragraph with a blank line between them, May's turn
      written across two lines). The driver imports `specs/012-reading-video/scripts/klhu_walk_video.py` for
      the shared mechanics (one string per `adb shell` command, row dispatch, PASS/FAIL), takes the same
      `ADB_SERIAL` / `KLHU_REPO` / `KLHU_OUT` overrides, and dispatches rows 23-28 and 33; each row prints the
      commands it ran and the lines it read (logcat, the shared-prefs dump, the pulled artifact). Until it
      exists, each row below is walked by hand with the same commands in the same order.
      **DONE 2026-10-03** — `scripts/klhu_walk_dialogue.py` + `scripts/klhu_dialogue_fixture.txt`. The driver
      imports 012's `klhu_walk_video.py` (`sys.path` into its scripts dir) and uses its `adb` / `dump` / `find`
      / `tap` / `check` / `RESULTS` unchanged; it adds only what 014 owns — the fixture, the `content_roles`
      shared-prefs reader, and the two log parsers (`klhu speak`, `klhu roles`). `ADB_SERIAL` is honoured
      (012's own `KLHU_DEV` too), with `KLHU_REPO` and `KLHU_OUT` as in 012. Two things the walk forced into
      the driver and deserve naming: **the labels are matched in both languages** (the reference AVD draws the
      app in Chinese: `文字类型` / `多人对话` / `完成` / `朗读`, with the English strings beside them from
      `app_en.arb`), and **an exact match is tried first** — the page's app bar is `卡啦虎朗读`, so a
      contains-match on `朗读` taps the title instead of the Read button, which is what the first run did.
      Rows are dispatched as they are walked (`main` names the ones still to come rather than stubbing them),
      which is what the checkpoint asks for. Fixture note: May's turn is two lines *and* two sentences — see
      row 23's evidence for why the first version was one sentence and why that was the sentence rule, not a
      bug.
- [x] T027 Walk quickstart row 23 into `specs/014-dialogue-reading/breakpoint.md`: a four-role dialogue on the
      device — import the fixture, set the type, read from the start, and check the logcat's `klhu speak` lines
      carry the turn's content with no tag and no role name in any spoken text, each turn in its role's voice.
      Evidence: the reader's own lines, quoted in the row. Proves FR-003/FR-005/FR-009, SC-001.
      **DONE 2026-10-03 — WALKED, PASS (10/10 checks), evidence in `breakpoint.md`.** The driver's output and
      the logcat lines it read are quoted there; the suite is unchanged (529) and `flutter analyze` is clean.
      Real device evidence: `klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male)
      May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)` and five `klhu speak` lines — four turns,
      May's two-line turn as `p2 s0` + `p2 s1` in one voice, no tag and no role name in any spoken text, in
      the text's order. **Two findings, both the app working as specified**: (a) a line break inside a turn is
      not a sentence boundary — the reader's own comma at May's line end made the two lines ONE utterance, so
      the fixture now ends that line with `。` (the sentence rule is right; the row's expectation needed a
      sentence ending there); (b) `朗读` is the *selection* read and refuses with `请先选择要朗读的句子或段落`
      when nothing is highlighted — "from the top" is `继续朗读`. **One thing for the reader to judge**:
      May—a female role by the reader's own example—reads in a male voice, because the assignment maximises
      distinctness and never infers a role's gender from its name (D5); the reader's act is to pick her voice
      (row 17), and row 25 walks that a pick survives a restart.
- [x] T028 Walk quickstart row 24 into `specs/014-dialogue-reading/breakpoint.md`: the assignment as the app
      made it, against the device's own voice list — dump the assignment the list shows and the voices the
      device reports (`voicesForAll`), and check each role's voice is a real installed voice of the turn's
      language, that the same content assigns the same voices on a second open, and that where the device
      lists fewer suitable voices than roles the sharing is visible and no role is silent.
      Proves FR-014/FR-015, SC-003/SC-004.
      **DONE 2026-10-03 — WALKED, PASS (13/13 checks), evidence in `breakpoint.md`.** The driver's own output,
      the four `klhu roles` lines and the prefs value are quoted there. Real device evidence: no picks → four
      distinct real zh-CN voices (旁白 ccc(female), 阿明 ccd(male), May cce(male), 阿芳 ssa(female)), identical
      on a second open (derived, never stored — FR-014); the reader's pick through the app's own 语音 screen
      (`普通话 SSA (女)`) stored as `voice_zh_Hans = cmn-cn-x-ssa-local||zh-CN` and 旁白 reading in it (FR-013);
      and **24 roles on a 15-voice pool** — 15 distinct voices, the nine past the pool all reading
      `cmn-cn-x-ccc-local`, 25 utterances handed to the engine with the last one being R20 (SC-004, no role
      silent, no read failed). **Found**: the device's zh-Hans pool is 15 voices (4 cmn-cn + 3 cmn-tw + 5
      yue-hk + three default-voice rows), which is why the sharing case needs 24 roles rather than the five a
      first attempt used — and the default-voice rows the assignment draws on are the same rows the picker
      shows (`广东话默认语音 (女)`), so list and assignment stay one source. Also fixed in the driver: `logcat
      -c` is asynchronous (the first run read zero speak lines while the app had spoken all five) — rows now
      window the log with a device timestamp taken before the tap.
- [ ] T029 Walk quickstart row 25 into `specs/014-dialogue-reading/breakpoint.md`: a removal and a pick survive
      a restart — remove a role and give another a pick, force-stop and reopen the app, re-read, and check the
      removed name's paragraphs are narration and the picked role still speaks in its picked voice; then delete
      the content and check the `content_roles` entry is gone from the shared-prefs dump.
      Proves FR-007/FR-008/FR-021, SC-006/SC-007.
- [ ] T030 Walk quickstart row 26 into `specs/014-dialogue-reading/breakpoint.md`: switching the type mid-read
      keeps the reader's place — start a read, switch to 多人对话 and back, and check the highlight and the
      stored `read_position` offset are where they were and the read continues from the same sentence.
      Proves FR-020, SC-009.
- [ ] T031 Walk quickstart row 27 into `specs/014-dialogue-reading/breakpoint.md`: a dialogue's video on the
      device — render the fixture, check the slot log line names the role and the frames carry no tag (sampled
      frames read as pixels/characters), and that the file's per-slot audio is the voice the read used for that
      turn. Proves FR-018/FR-019, SC-008.
- [ ] T032 Walk quickstart row 28 into `specs/014-dialogue-reading/breakpoint.md`: spike S1 — print the device's
      installed voices per language and per gender (`lib/reader_service.dart:507-510`'s `voicesForAll` plus the
      mapping table) and record the counts, so SC-003's "whenever the device lists at least N matching voices"
      has a measured N rather than the app's table's 7 Mandarin / 6 Cantonese names. This row is the number the
      assignment's bound is read against; it gates nothing and blocks nothing, but its answer is what row 24's
      PASS is checked with.
- [ ] T033 Walk quickstart row 33 into `specs/014-dialogue-reading/breakpoint.md`: the editor's Format press
      with the reader's own hands — type or paste a dialogue with two tags on one line into the editor, dump
      the editor's text with `uiautomator dump` (the ground truth for Flutter text on this host) before and
      after pressing Format, press Undo, then press Done and reopen the content. The after-Format dump has each
      tag at its own paragraph's onset and no other change; the dump after Undo is byte-for-byte the one from
      before; Done saves and the reopened content shows the formatted text. Proves FR-024, SC-011 on the device.

**Checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`; no row cites a driver
command that does not implement it (extend the dispatch in T026 in the same pass, or record the row as
hand-run).

---

## Phase 9: Polish & cross-cutting concerns

- [ ] T034 Run the three structural rows into `specs/014-dialogue-reading/breakpoint.md`: row 19 (the l10n
      parity check — `flutter test test/l10n_keys_test.dart` plus `flutter gen-l10n` and a clean
      `git status --short lib/l10n` after it), row 29 (no dependency and no platform change — `git diff --stat
      pubspec.yaml pubspec.lock android/` empty), and rows 30-31 (011's and 012's receipts re-run unmodified:
      `specs/011-reading-experience/scripts/klhu_walk_experience.py` plus
      `flutter test test/language_test.dart test/segmenter_test.dart test/reader_service_test.dart`, and 012's
      own rows). Proves FR-023, SC-005, SC-010.
- [ ] T035 Write `specs/014-dialogue-reading/breakpoint.md` from the walk: an environment table (device, build,
      the source revision with the suite count, the driver and how to re-run a row), one row per device
      scenario with its state (`PASS` / `PARTIAL` / `NOT WALKED` plus the reason), a Deviations section written
      as rules, and the spike S1 answer in full. Then update the README's own section for this feature with the
      re-run commands and one paragraph on what a dialogue read does.
- [ ] T036 Close `specs/014-dialogue-reading/tasks.md` with the receipt: re-run `flutter analyze` and
      `flutter test --concurrency=2` on the finished tree, write both numbers into the Status section of this
      file beside T002's baseline, tick every task above in one pass and correct any tick whose receipt went
      stale, then re-run `check_tasks_format.py specs/014-dialogue-reading` and quote its output in the Status
      block. A tick without a receipt beside it is a claim, not evidence.

**Checkpoint**: analyzer clean, the suite's count recorded against the baseline, the checker quoted green, and
the working tree holding only intended edits.

---

## Dependencies & ordering

- **Phase 1 (T001)** blocks everything that compiles against a new key — i.e. T011/T015/T017/T025.
- **Phase 2 (T002-T007)** blocks all five stories: `lib/dialogue.dart` and `lib/role_store.dart` are what each
  story's layer consumes. T002's baseline is the first thing to run and T003-T005 precede T006/T007 (RED
  before green).
- **US1 (Phase 3)** blocks US2 and US3 — both add to the surface T011 creates — and US4, whose resolver is
  T010. US5 is independent of US2/US3/US4 but sits on `lib/dialogue.dart` (T006) and needs the editor only.
- **The walk (Phase 8)** depends on its story's code: rows 23-24 on US1+US2, 25 on US3, 26 on US1, 27 on US4,
  33 on US5, 28 on nothing (it measures the device).
- **Phase 9** last: T034's structural rows need the finished tree, T035 needs the walk, T036 needs everything.

## Parallel opportunities

- T004 and T005 (different new test files, no shared state).
- T008 and T009 within US1; T019 anywhere after T006 (its own file).
- T022 and T023 are two files but the same story's RED — they may be written in one sitting; they are not
  `[P]` against each other's *green*, which needs T024 and T025 respectively.
- **Nothing in Phase 8 is parallel**: every row installs, drives and reads the same device, and they all append
  to one `breakpoint.md`. Two rows run one after the other even when their stories are independent.

## Implementation strategy

The MVP is **Phase 3**: a dialogue reads as a dialogue — type, turns, refusal to speak tags, and 标准
untouched. That is demonstrable on the device with rows 23 and 26 alone (the assignments are still automatic,
so no list is needed to hear a dialogue). US2 then makes the voices the reader's, US3 makes the roster
correctable, US4 carries it into the video, US5 gives the writer the one press. Each story is independently
demonstrable: rows 15/18 (US1), 16/17 (US2), 16's second half (US3), 20-22 (US4), 32 (US5).

## Notes

- The device rows are walked by hand first and scripted afterwards; the driver's dispatch list is the
  authority on which rows are scripted, so a row added later extends it in the same pass.
- `test/l10n_keys_test.dart` is bidirectional: a key in three ARBs fails exactly as loudly as a key in five.
- No `contracts/` directory for this feature: the interfaces it changes are in-process Dart types the app
  already owns (`ParagraphSpeech`, `VoiceChoice`), and the engine's voice/locale handshake is unchanged
  (plan § Project Structure).
- The two log lines T012/T021 extend are device evidence only — say so when a row rests on them, rather than
  claiming a unit test covers them.

## Requirement coverage

| Requirement | Tasks that satisfy it |
|---|---|
| FR-001 (a type per content, 标准 when absent) | T007, T011 |
| FR-002 (标准 is the shipped reading) | T008, T009, T010, T011 |
| FR-003 (a turn is a paragraph) | T003, T006, T010 |
| FR-004 (the braced tag, read at the paragraph's head) | T003, T006, T022 |
| FR-005 (the prefix is outside every span) | T003, T006, T023 |
| FR-006 (the proposal, and removing a name) | T006, T013, T015, T017 |
| FR-007 (a removed name holds for that text) | T005, T016, T017 |
| FR-008 (the confirmed set survives restarts) | T005, T007, T015, T029 |
| FR-009 (narration is never attributed) | T003, T006, T010, T027 |
| FR-010 (sentence by sentence, one utterance each) | T008, T010, T034 |
| FR-011 (the turn's own language) | T003, T006, T010 |
| FR-012 (each role its own voice, from the app's lists) | T013, T014, T015 |
| FR-013 (a pick decides the voice and the pronunciation) | T014, T015, T027 |
| FR-014 (the deterministic assignment) | T004, T006, T028 |
| FR-015 (prefer unused; reuse when the device is short) | T004, T006, T028 |
| FR-016 (the list shows the voice by its own name) | T013, T015 |
| FR-017 (no age is modelled or claimed) | T001, T015 |
| FR-018 (the video's voices, and no tag in a frame) | T019, T020, T031 |
| FR-019 (one shared resolution) | T010, T020 |
| FR-020 (switching touches nothing but the setting) | T009, T011, T030 |
| FR-021 (stored per content, removed with the content) | T007, T018, T029 |
| FR-022 (reachable from the page; four locales) | T001, T011, T034 |
| FR-023 (no dependency, no network) | T034 |
| FR-024 (the editor's Format action) | T022, T023, T024, T025, T033 |
| SC-001 (no tag in any spoken utterance) | T003, T010, T027 |
| SC-002 (four picks, four voices, named per utterance) | T012, T015, T027, T028 |
| SC-003 (the assignment's preferences, and determinism) | T004, T006, T028, T032 |
| SC-004 (fewer voices than roles: no silent role) | T004, T006, T028 |
| SC-005 (no stored type reads as today; 011/012 rows pass) | T002, T009, T034 |
| SC-006 (a removal holds, restart included) | T005, T016, T017, T029 |
| SC-007 (the settings survive; the delete removes them) | T005, T007, T018, T029 |
| SC-008 (no tag in a frame; the audio's voices) | T019, T020, T021, T031 |
| SC-009 (the switch keeps the position and the highlight) | T009, T011, T030 |
| SC-010 (no dependency, no network call) | T034 |
| SC-011 (Format: heads, blank lines only, one Undo) | T022, T023, T024, T025, T033 |
