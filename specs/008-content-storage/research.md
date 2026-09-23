# Research: Content Storage and Content Management

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-23

## Verified environment facts (grounding)

Everything below was checked against this checkout or the installed SDK — no
claim here is assumed.

| Fact | Evidence |
|---|---|
| Flutter 3.47.5 / Dart SDK `^3.13.3` | `flutter --version`; `pubspec.yaml` `environment:` |
| Existing deps: `flutter_tts ^4.2.3`, `shared_preferences ^2.5.5`, `intl ^0.20.3` | `pubspec.yaml` |
| `path_provider 2.1.6` resolves in this project | `flutter pub add path_provider --dry-run` → `+ path_provider 2.1.6` (android 2.3.1, foundation 2.6.0) |
| Declared assets: only `images/kalahu.jpeg` | `pubspec.yaml` `flutter: assets:` |
| `TextField` accepts `undoController` | `packages/flutter/lib/src/material/text_field.dart:887`, passed to `EditableText` at `:1695` |
| `UndoHistoryController` exposes `undo()`, `redo()`, `value.canUndo` | `packages/flutter/lib/src/widgets/undo_history.dart:361-390` |
| The undo stack has **no length cap** (`_UndoStack.push` appends; undo-then-edit truncates the tail) | `widgets/undo_history.dart:399-438` |
| Reading view state machine: `_Mode {read, edit, speaking, paused}`; `_enterEdit` seeds the controller, `_doneEdit` commits to `_content` | `lib/reading_view.dart:147-163` |
| The three samples are `SampleTexts.en / zhHans / es`, `all` = the list | `lib/sample_texts.dart` |
| Sample buttons are ARB strings now (`sampleEn/Zh/Es`), inside a `Wrap` | `lib/reading_view.dart` §body; `lib/l10n/app_en.arb` |
| Existing persistence: `SharedPreferences` via `VoiceStore` (`voice_en`/`voice_es`/`voice_zh_Hans`) and `LanguagePreference` (`interface_language`) | `lib/voice_store.dart`, `lib/models/language_preference.dart` |
| iOS deployment target **15.0** (constitution says iOS 16+ baseline) | `ios/Runner.xcodeproj/project.pbxproj:363,490,542` |
| Android `minSdk = flutter.minSdkVersion` (no explicit floor in the project) | `android/app/build.gradle.kts:22` |
| Tests are flat under `test/`, 152 green | `ls test/`; `flutter test --concurrency=2` |
| Reading language is detected per paragraph, not stored per content | `lib/language.dart` `detectLanguage` |

## Decisions

### D1 — Storage backend: one file per content + a JSON index

**Decision**: `SharedPreferences` keeps only small scalars (as today). Content
text lives in one file per saved content under the app documents directory
(`getApplicationDocumentsDirectory()`), with a small `index.json` holding the
metadata list.

**Rationale**: `SharedPreferences` is a single key→string map parsed into memory
at startup; the spec allows ~1 MB per content and many contents (SC-005), so
putting texts there would load the whole library for every launch and inflate
the pref XML that other features (voices, language) also read. Splitting index
from text also lets the list render without reading any text (SC-005), and a
damaged file costs one entry instead of the library.

**Alternatives considered**:
- *Single JSON blob in `SharedPreferences`* — rejected: whole library in memory
  at cold start, and one bad byte loses everything.
- *`sqflite`* — rejected: a schema, migrations and a heavier native dependency
  for two fields of text plus timestamps. YAGNI (constitution V).
- *File per content with metadata inside the file* — rejected: listing would
  have to open and parse every file just to draw the list.

### D2 — New dependency: `path_provider: ^2.1.6`

**Decision**: add exactly one dependency, `path_provider`.

**Rationale**: Dart has no API for the app documents directory on Android/iOS
without a plugin; it is the standard, first-party (`flutter/packages`) plugin
and it resolves cleanly here (verified above). No network, no backend — on-device
first is preserved (constitution IV).

**Alternatives considered**: `Directory.current`/`systemTemp` (wrong lifetime on
mobile, can be cleared by the OS); platform channels written in-tree (reimplements
a maintained plugin).

### D3 — Pre-set contents are data, not code

**Decision**: the three samples become `assets/content/presets.json`, loaded once
at startup through `rootBundle`, each entry carrying `id`, `language`, a
localized `name` map (`en`/`zh`/`es`, `en` fallback) and the `text`. `SampleTexts`
is **replaced** by that asset (no duplicated copies of the same text in Dart).

**Rationale**: FR-020 ("more pre-set contents without code changes") is only
satisfiable if the presets are data; the asset is also what makes a preset's
original text recoverable after deletion (D4).

**Alternatives considered**: keep `SampleTexts` in Dart and add presets as code
(rejected — a new preset would be a code change); presets seeded into storage on
first launch and edited thereafter (rejected — an app update could then never fix
a typo or add text to an existing preset).

### D4 — Deleting a pre-set content = a tombstone, not a file delete

**Decision**: the index remembers deleted preset ids (`deletedPresetIds`). A
deleted preset disappears from the list and comes back only if its id stops
being tombstoned (i.e. a reinstall / cleared data), matching the spec's edge case
"allow deletion but can be restored by app update or reinstallation".

**Rationale**: presets are read-only asset data; the only honest way to "delete"
one is to stop listing it. Deleting the asset is impossible and copying every
preset into storage just to delete the copy would duplicate 3 texts forever.

**Alternatives considered**: physically copying presets into the content store on
first launch (rejected: duplicate storage, and updates can't reach the copy);
hiding delete for presets (rejected: FR-018 requires preset management).

### D5 — Save semantics: preset → new content, user content → update in place

**Decision**: the reading view gains a Save action (EDIT mode, plus "save
changes" on leaving EDIT). `StorageService.save(content)` branches on origin:
a loaded **preset** is saved as a **new** user content (auto-named from the
edited text; the preset stays intact — FR-019/SC-010), while a loaded **user
content** is updated in place (FR-013), keeping its id and minting no new name.

**Rationale**: FR-019 says the original pre-set must survive the edit, and the
spec explicitly forbids a naming field (FR-008), so the new entry's name has to
be derived (D7).

**Alternatives considered**: fork-on-open (rejected: reading a preset would
silently create an entry); overwrite the asset (impossible).

### D6 — Undo: the Flutter text-field undo stack, surfaced as one toolbar action

**Decision**: pass an `UndoHistoryController` to the EDIT-mode `TextField`
(the controller is created lazily with `_editController` and disposed with it)
and put an Undo action next to Done in EDIT mode, enabled iff
`_undoController.value.canUndo`.

**Rationale**: the platform stack is already correct, keyboard- and
IME-aware, and verified present in this SDK (facts table). SC-008 asks for ≥10
undo steps; `_UndoStack` is uncapped, so the bound is really memory —
see the size guard in D10.

**Alternatives considered**: a hand-rolled `List<String>` snapshot stack
(rejected: reimplements correct IME/selection behavior and would fork undo
between the keyboard shortcut and the button). Note the spec's "undo limit"
edge case is satisfied where it actually exists: when the stack is exhausted
(`!canUndo`) the action is disabled, and an undo that lands on the oldest state
surfaces a localized SnackBar — the UI never advertises a number it cannot keep.

### D7 — Auto-generated names (FR-008) that are unique (edge case)

**Decision**: name = the first non-blank line of the text, whitespace collapsed,
truncated to 24 characters (ellipsis when cut); when that name already exists in
the same content set, append ` (2)`, ` (3)`, … . Creation time is stored
separately, so the name stays human and the timestamp sorts.

**Rationale**: it is descriptive without a naming dialog, stable across the
edit-save (an update keeps the name), and the collision rule is deterministic —
so it is unit-testable.

**Alternatives considered**: `Content 1`, `Content 2` (rejected: meaningless in a
reading list); timestamp-only (`2026-09-23 10:22`) (rejected: unreadable);
UUID in the name (rejected: noise in the UI).

### D8 — Ids without a new dependency

**Decision**: id = `c_<millisecondsSinceEpoch>_<4 hex from Random>`, plus a
uniqueness re-roll against the loaded index.

**Rationale**: FR-007 needs stable unique ids; `uuid` would be a second new
dependency for four characters of entropy we can generate with `dart:math`.

**Alternatives considered**: `uuid` package (rejected, see above); a monotonic
counter (rejected: collides after reinstall/restore or a clock change).

### D9 — Which content opens at launch

**Decision**: the index stores `lastOpenedId`; startup loads that content, and
falls back to the first preset when it is missing or was deleted.

**Rationale**: the spec's SC-004 is about persistence, but a content library that
forgets which text you were reading fails its purpose in practice; the fallback
keeps a deleted-last-content case from producing an empty page. This is the one
addition beyond the spec's text — it is small, additive and recorded here rather
than smuggled into implementation.

### D10 — Size and emptiness guards

**Decision**: refuse to save content that is empty/whitespace-only, and refuse
content over **100,000 characters** (`ContentTooLarge`), both with a localized
message and no write. The limit is checked *before* the write so nothing is
truncated silently.

**Rationale**: the spec's assumptions say "under 1 MB per content" and edge cases
require feedback for empty and oversized content. 100k characters is ≥300 KB in
UTF-8 for CJK (widest case here) and well inside 1 MB, and it bounds the undo
snapshots from D6 (each snapshot holds the whole value).

**Alternatives considered**: no limit (rejected: an accidental paste of a whole
book would be committed to storage and duplicated by undo history); a byte-based
limit (rejected: needs an encode pass on every keystroke-check to be exact).

### D11 — Corruption and storage-full handling (FR-010)

**Decision**: `index.json` carries `version: 1`. On an unparseable/unsupported
index the file is moved aside to `index.corrupt-<timestamp>.json` and the store
re-seeds from the presets, surfacing a localized error; a content whose text file
is missing/unreadable is listed as damaged and offers delete (spec edge case);
an index entry pointing at a deleted file is dropped on load. Write failures
(`FileSystemException`, incl. `ENOSPC`) are caught and reported to the user; the
in-memory state is not updated, so the UI never claims a save that did not land.

**Rationale**: the spec asks for graceful storage errors and corrupted-content
recovery; moving the bad index aside keeps the data recoverable by hand instead
of destroying evidence.

### D12 — Where the unified list lives, and the strings it needs

**Decision**: a `ContentListScreen` pushed from one new app-bar action in the
reading view (replacing the sample-button row); rows show the auto/preset name,
the language tag and the date, tap loads, a trailing delete icon opens an
`AlertDialog` (Cancel / Delete) whose body states the action cannot be undone.
New UI strings go into **all four** ARBs (`app_en`, `app_zh`, `app_zh_Hans`,
`app_es`) — spec 007's lesson: a string added to three of four files renders
English in the fourth interface.

**Rationale**: the list is a management surface (edit/delete/load), which does not
fit in an app bar menu; a pushed screen keeps the reading surface uncluttered
(SC-002/FR-003). The delete confirmation is a dialog rather than a swipe so it is
reachable by TalkBack and cannot fire accidentally.

**Alternatives considered**: a `BottomSheet` (rejected: cramped for rows plus
per-row actions, and swipe-to-delete has no accessible equivalent); reusing a
`Drawer` (rejected: competes with navigation the app does not have yet).

### D13 — Interfaces and contracts

**Decision**: document the **on-disk storage format** as the feature's contract
(`contracts/storage-format.md`): file layout, the index schema, version, the
error/repair states, and the invariants a test can assert. No HTTP/API contract
exists — the app is on-device only.

**Rationale**: the storage format is the one interface a future version (or a
tests-only reader) must agree on; the UI is asserted by widget tests, not by a
documented schema.

## Grounding corrections to the spec's assumptions

1. **"Local storage uses shared_preferences or file-based storage"** — resolved
   to file-based for text with `SharedPreferences` retained for scalars (D1).
2. **"Storage operations complete within 500ms"** — kept, but made measurable:
   the list draws from the index alone (no text reads, D1), so the timed path is
   index load + one file read on open/load; the quickstart measures those two,
   not an aggregate.
3. **"Edit history is limited to reasonable number of undo operations (e.g.
   10-20)"** — corrected: the platform stack is uncapped, so there is no number
   to document; SC-008's "≥10" holds a fortiori, and the real bound is the
   content-size guard (D10) that keeps each snapshot cheap.
4. **"Content list is extensible without code changes"** — precise reading: a new
   preset is a data edit (`presets.json`), not a code change; presets still ship
   with the app, so adding one is a release, not a runtime action.
5. **"What happens when user tries to delete a pre-set content? Allow deletion
   but can be restored by app update or reinstallation"** — implemented as the
   tombstone in D4; note a reinstall restores it, an edit-then-save does not
   (that produces a new user content, D5).
6. **Third language / four ARB files** — the spec was written as if the app had
   one Chinese ARB; it has `app_zh.arb` **and** `app_zh_Hans.arb`, so every new
   string lands in four files (D12).

## Open questions

None. Every `NEEDS CLARIFICATION` from the Technical Context is resolved above;
no `[NEEDS CLARIFICATION]` marker remains in the spec.
