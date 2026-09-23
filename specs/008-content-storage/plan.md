# Implementation Plan: Content Storage and Content Management

**Branch**: `008-content-storage` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-content-storage/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

> **Grounding notes (2026-09-23, verified in this checkout and SDK):** the spec's
> "shared_preferences **or** file-based" resolves to **file-based text + an index**
> for the reasons in `research.md` D1, which adds exactly one dependency
> (`path_provider ^2.1.6`, resolvability verified). The spec also reads as if the
> app had one Chinese ARB — it has `app_zh.arb` *and* `app_zh_Hans.arb`, so every
> new string lands in **four** ARB files. Undo is the platform text-field stack
> (`TextField.undoController`, present in this SDK), whose history is uncapped —
> so SC-008's "≥10" holds by construction and the real bound is the content-size
> guard (100,000 characters). See `research.md` § Grounding corrections.

## Summary

Replace the three hardcoded sample buttons with a persisted, managed content
library. Page text (pre-set and user-entered) is saved to local storage, listed
in one unified selectable list, and can be loaded, edited with undo, re-saved and
deleted behind a confirmation warning. The three current samples become pre-set
contents in that list: they behave like any other entry (load, edit, delete)
while their originals stay intact — editing a pre-set saves a **new** user
content. The library is data-driven (`assets/content/presets.json`), so more
pre-set contents are added without code changes. Technical approach: one file per
content plus a versioned JSON index in the app documents directory, a
`ContentStore` service behind a small model, a `ContentListScreen`, and
EDIT-mode Save/Undo actions in the reading view.

## Technical Context

**Language/Version**: Dart `^3.13.3` on Flutter 3.47.5 (stable)

**Primary Dependencies**: `flutter_tts ^4.2.3` (unchanged), `shared_preferences
^2.5.5` (scalars only: `lastOpenedId`, and the existing voice/language keys),
`flutter_localizations` + `intl ^0.20.3` (four ARB locales), **new**:
`path_provider ^2.1.6` (app documents directory)

**Storage**: Files under `getApplicationDocumentsDirectory()/content/`:
`index.json` (versioned metadata) + `contents/<id>.txt` (raw UTF-8 text). No
database, no network.

**Testing**: Flutter unit + widget tests under `test/` (`content_store_test.dart`,
`content_name_test.dart`, `content_list_test.dart`, additions to
`reading_view_edit_test.dart`); emulator walk per `quickstart.md`.

**Target Platform**: iOS 16+ / Android 10+ (API 29+) per the constitution; the
project currently builds with iOS deployment target 15.0 and Flutter's default
`minSdk` (`android/app/build.gradle.kts:22`) — untouched by this feature, both
inside the stated baseline.

**Project Type**: Mobile app, single Flutter codebase (`lib/` + `test/`)

**Performance Goals**: opening a content ≤ 500 ms; the list draws from the index
alone (no text reads), so list latency is independent of stored text size; save
of a typical page (≤ 5 KB) ≤ 100 ms

**Constraints**: On-device only (no account, backend, analytics, network);
accessibility (TalkBack/VoiceOver on every new action, 44pt minimum touch
targets); content ≤ 100,000 characters; data must survive app restart; corrupt
storage must degrade to a usable library with a visible message, never a crash

**Scale/Scope**: 1 new screen (`ContentListScreen`), 1 new service
(`ContentStore`), 1 new model, ~8 modified files, ~16 new localized strings ×
4 ARB files; content counts in the tens (SC-005), texts ≤ 100 KB

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **I. Flutter Single Codebase** — `path_provider` and `dart:io` are shared
  Flutter APIs; no platform fork, no `lib/platform/` code needed.
- ✅ **II. Spec-Driven** — spec reviewed 2026-09-23; this plan + `tasks.md`
  precede any implementation.
- ✅ **III. Test-First** — store/name/guard logic is unit-testable behind a
  `ContentStore` seam (directory injectable), the list and the edit/undo/save
  flows are widget-testable; the emulator walk covers persistence across restart.
- ✅ **IV. On-Device First** — nothing leaves the device; no network permission,
  no analytics; the new dependency is a path lookup only.
- ✅ **V. Simplicity** — no database, no migrations beyond a version field, no
  naming dialog, no tags/folders/search; unrequested scope (reading position,
  sync, export) is explicitly not built.
- ✅ **Constraints** — iOS 16+/Android 10+ baseline unchanged (project values
  verified above); every new action is an `IconButton`/`ListTile` with a
  localized tooltip and ≥44pt target; delete is a dialog, never a swipe-only
  affordance.

**Post-Design Re-check**: ✅ PASS — Phase 1 introduced no new dependency,
service or entity beyond those listed above; the storage contract is versioned;
the one addition beyond the spec's text (restoring the last opened content,
`research.md` D9) is additive, local, and recorded rather than smuggled.

## Project Structure

### Documentation (this feature)

```text
specs/008-content-storage/
├── plan.md                       # This file (/speckit-plan command output)
├── research.md                   # Phase 0 output (/speckit-plan command)
├── data-model.md                 # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── storage-format.md         # Phase 1 output: the on-disk contract
├── quickstart.md                 # Phase 1 output (/speckit-plan command)
└── tasks.md                      # Phase 2 output (/speckit-tasks command — NOT created here)
```

### Source Code (repository root)

```text
assets/
└── content/
    └── presets.json              # New: the 3 pre-set contents as data (D3)

lib/
├── models/
│   └── content.dart              # New: SavedContent (+ origin, timestamps, language)
├── services/
│   └── content_store.dart        # New: index + files, save/load/delete/rename-free
│                                 #      naming, size/empty guards, repair (D1/D7/D8/D10/D11)
├── content_list_screen.dart      # New: unified list, load + delete-with-warning (D12)
├── content_naming.dart           # New: auto-name + collision rule (D7), unit-tested
├── sample_texts.dart             # Removed: superseded by assets/content/presets.json
├── reading_view.dart             # Modified: drop sample buttons, add Content action,
│                                 #      EDIT-mode Save + Undo, unsaved-change guard
├── main.dart                     # Modified: build the store, load last/first content
├── l10n/app_{en,zh,zh_Hans,es}.arb   # Modified: ~16 new strings, all four files
└── l10n/app_localizations*.dart      # Regenerated (`flutter gen-l10n`)

pubspec.yaml                      # Modified: path_provider; declare assets/content/

test/
├── content_store_test.dart       # New: save/load/delete/persist/repair/guards
├── content_naming_test.dart      # New: auto-name truncation + collision suffix
├── content_list_test.dart        # New: unified list, delete confirmation
├── reading_view_edit_test.dart   # Modified: Save/Undo, preset→new, unsaved guard
└── (sample-button assertions removed from existing widget tests)
```

**Structure Decision**: Mobile app, existing `lib/` + flat `test/` layout
preserved (specs 001–007 convention). Storage and naming are separated from the
widgets so every rule in the spec (size/empty guards, name collisions, tombstoned
presets, repair of a corrupt index) is provable in unit tests without a device.
The reading view keeps its single state machine (`read/edit/speaking/paused`);
Save and Undo are new actions inside `edit`, not new modes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The single new dependency (`path_provider`) and the one addition
beyond the spec's text (opening the last used content, D9) are justified in
`research.md` § Decisions.
