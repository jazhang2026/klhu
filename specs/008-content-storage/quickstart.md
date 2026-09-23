# Quickstart: Content Storage and Content Management

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Date**: 2026-09-23

Validation guide: how to prove this feature works end to end. Implementation
detail lives in `tasks.md`; the storage schema lives in
[contracts/storage-format.md](./contracts/storage-format.md).

## Prerequisites

- Flutter 3.47.5 + the project's SDK (`flutter --version`)
- Android emulator `emulator-5554` running (AVD `klhu`, API 36) for the device rows
- Specs 001–007 in place: `flutter analyze` clean, `flutter test` green (152 tests
  before this feature's tests are added)

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get           # pulls path_provider (new)
flutter gen-l10n          # four locales
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Automated checks

```bash
flutter analyze
flutter test --concurrency=2          # emulator up ⇒ never the default concurrency on this box
flutter test test/content_store_test.dart --concurrency=1
```

Expected: analyze clean; all tests green, including the new
`content_store_test.dart`, `content_naming_test.dart`, `content_list_test.dart`,
and the extended `reading_view_edit_test.dart`.

## Validation scenarios

Rows marked **[device]** are walked on the emulator with `uiautomator dump`
(`~/.hermes/cache/scratch/klhu_ui.py`) and `adb logcat`; rows marked **[unit]**
are a path a healthy device cannot reach (disk-full, 100k-char paste) and are
proven in tests against an injected failing/inspectable store. Record PASS/FAIL
and any divergence in `breakpoint.md` next to this file.

### 1. Pre-set contents in a unified list; sample buttons gone — [device]

1. `adb shell pm clear com.example.klhu`, launch.
2. Open the Content action in the app bar.
3. **Expected**: three entries (English / Chinese / Spanish sample) with their
   localized names; **no** `EN sample` / `中文示例` / `ES sample` buttons remain on
   the reading page (FR-003, FR-004, FR-017, SC-002, SC-003).

### 2. Load a pre-set and read it — [device]

1. Tap the Chinese pre-set in the list.
2. **Expected**: the reading page shows that text; `Read page` speaks it with the
   Chinese voice (logcat `Synthesis request for locale …` on the TTS tag proves
   the language actually used).

### 3. Save user input, auto-named — [device]

1. `Edit` → type/replace text → `Save`.
2. **Expected**: back in the list, a new entry whose name is derived from the
   first line of the text (no naming dialog anywhere); its text reloads exactly
   (FR-001, FR-005, FR-008, FR-009, SC-001).

### 4. Persistence across restart — [device]

1. With at least one saved entry, `adb shell am force-stop com.example.klhu`,
   relaunch.
2. **Expected**: the library is unchanged (same entries, same names) and the last
   opened content is on screen (FR-006, SC-004; the last-opened behaviour is
   `research.md` D9).

### 5. Edit + undo — [device]

1. `Edit`, type a sentence.
2. Tap `Undo` → the sentence disappears; repeat until the oldest state.
3. **Expected**: each undo steps back exactly one edit; the action is disabled
   when there is nothing left to undo, and the last successful undo surfaces the
   "history exhausted" message (FR-012, SC-006, SC-008).

### 6. Save an edited **user** content — [device]

1. Load a saved entry, `Edit`, change it, `Save`.
2. **Expected**: the same entry is updated (same name, new `updatedAt`), no
   duplicate appears (FR-013).

### 7. Edit a pre-set → new content, original intact — [device]

1. Load the Spanish pre-set, `Edit`, append a line, `Save`.
2. **Expected**: a **new** entry holds the edit; loading the original pre-set
   still shows the untouched text (FR-019, SC-010).

### 8. Delete with a warning — [device]

1. Swipe-free path: tap the delete icon on an entry → the confirmation dialog
   states the action cannot be undone → `Cancel` → the entry is still there.
2. Delete again and confirm → the entry is gone.
3. Delete a **pre-set**, confirm, then restart the app.
4. **Expected**: cancel changes nothing (FR-016); confirm removes the entry
   (FR-014, FR-015, SC-007); the deleted pre-set stays gone after a restart while
   a reinstall brings it back (tombstone, `research.md` D4).

### 9. Guards: empty and oversized saves — [unit]

- Empty/whitespace-only: save is refused with a localized message and nothing is
  written.
- Over 100,000 characters: refused, message shown, **nothing truncated**
  (`research.md` D10; the spec's storage-limit edge case).

### 10. Storage errors and a corrupt index — [device] + [unit]

- **[device]** Write garbage into `index.json`
  (`adb shell run-as com.example.klhu sh -c 'echo notjson > \
  files/content/index.json'` — path as reported by the store), relaunch.
  **Expected**: the app starts, the three pre-sets are back, the bad file was
  moved aside as `index.corrupt-*.json`, and a localized error is shown
  (FR-010, `research.md` D11).
- **[unit]** A failing writer (disk full / `FileSystemException`) leaves the index
  and the in-memory list untouched and reports the failure.

### 11. Damaged entry — [device]

1. Delete one `contents/<id>.txt` behind the app's back
   (`adb shell run-as com.example.klhu rm files/content/contents/<id>.txt`).
2. Relaunch, open the list.
3. **Expected**: that entry is marked damaged and offers delete; the rest of the
   library is usable (spec edge case).

### 12. Unsaved changes when switching content — [device]

1. `Edit`, change something, then open the content list and pick another entry.
2. **Expected**: a confirm dialog (discard / cancel); cancel keeps the edit and
   the current content, discard loads the chosen one (`research.md` D5/D12).

### 13. Many entries, no slowdown — [unit] + [device]

- **[unit]** Seed ~50 entries; the list path reads only `index.json` (asserted by
  a store that counts text reads).
- **[device]** With the seeded library, opening the list stays ≤ 500 ms
  (measure the tap → list-visible interval once; note the `uiautomator dump`
  latency floor — see the caveat recorded in spec 007's `breakpoint.md`).

## Troubleshooting

**List is empty on first launch** — the catalog asset is missing from
`pubspec.yaml` (`assets/content/`), or every preset id is tombstoned.

**A save seems to do nothing** — check `adb logcat` for the store's error line;
guards (empty/oversized) and IO failures all report through the same localized
message and never write partially.

**Duplicate entries after editing a pre-set** — that is the specified behaviour
(FR-019): the edit becomes a new user content, the pre-set is never modified.

**Names look truncated** — by design: first line, ≤24 characters, ` (2)` suffix on
collision (`research.md` D7).

**Tests hang or crash on this machine** — always `--concurrency=2` while the
emulator is running (spec 007 note: `flutter_tester` segfaults otherwise).
