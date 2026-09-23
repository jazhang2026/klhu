# Device validation: Content Storage and Content Management (008)

**Feature**: `008-content-storage` | **Date**: 2026-09-23
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, en-US) |
| Build | `flutter build apk --debug`, `adb install -r`, `lastUpdateTime=2026-09-23 15:05:38` |
| Source | working tree on `4d9d1dd` (+38 uncommitted changes — spec 008 is not committed yet) |
| Baseline | `flutter analyze` clean; `flutter test --concurrency=2` → **218 passing, 0 failing** |
| Driver | `uiautomator dump` + `adb shell input` (`~/.hermes/cache/scratch/klhu_walk*.py`); every tap taken from the dump's own `bounds` centre, re-dumped after each transition |
| TTS proof | `adb logcat` — `GoogleTTSServiceImpl: Synthesis request for locale …` |

Rows are `WALKED` (device PASS plus the line that proves it), `EVIDENCE-ONLY`
(a path a healthy device cannot exhibit — proven by unit/widget tests) or
`UNVERIFIED WITH REASON`.

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 1 | Pre-sets in one list; sample buttons gone | **WALKED — PASS** | `pm clear`, launch: the reading page's row is `Read / Read page / Stop / Edit` with no `EN sample` / `中文示例` / `ES sample`. `Contents` lists exactly three rows: `The sun rose over the q…\nEnglish · Sep 23, 2026`, `El sol salió sobre el p…\nEspañol · …`, `清晨的阳光洒在安静的小镇上。鸟儿在高大的树上歌…\n中文 · …` |
| 2 | Load a pre-set and read it | **WALKED — PASS** | Tap the Chinese row → caption `Reading: 清晨的阳光…`, body shows the Chinese text. `Read page` (logcat, cleared first): `currentLocale = cmn-CN` ×5 → `For default lang zh-cn is name zh-CN-language (cmn-cn-x-ssa-server)` → `Synthesis request for locale zho-CHN and name zh-CN-language` → `TTS dispatch: cmn-cn-x-ssa-seanet-embedded`, one `Utterance ID has started` per paragraph. See Divergence 1 for the first (unreproducible) pass |
| 3 | Save user input, auto-named | **WALKED — PASS** | Edit the Spanish pre-set, new first line `MyReadingNotes`, `Save` → the list's newest row is exactly `MyReadingNotes` (`Español · Sep 23, 2026`): the title comes from the text, no naming dialog (FR-001/005/008/009) |
| 4 | Persistence across restart | **WALKED — PASS** | `am force-stop` + relaunch (pid 5472 → 5862): the same entries in the same order and the caption reopens on the last-opened content (`Reading: 清晨的阳光…` when that was the last pick). After SC10's repair, a relaunch reopens `Reading: The sun rose over the q…` |
| 5 | Edit + undo | **WALKED — PASS** | Entering EDIT: `Undo` present and **disabled**; typing enables it; one `Undo` removes exactly the typed text (`MARKER` gone) and disables itself again; two edits then repeated `Undo` → the control ends `disabled` and the SnackBar reads `Nothing more to undo` (FR-012, SC-006; SC-008's "≥10" is the platform stack's own, uncapped) |
| 6 | Save an edited **user** content (update in place) | **WALKED — PASS** | Reload `MyReadingNotes`, edit, `Save` → the list still holds **6** entries with the same name; no duplicate (FR-013) |
| 7 | Edit a pre-set → new content, original intact | **WALKED — PASS** | Editing the Spanish pre-set produced a **new** entry (`El sol salió sobre el p… (2)`, type `user`) while reopening the original still shows the shipped text with none of the edit (FR-019, SC-010); `contents/<preset-id>.txt` is never written (unit) |
| 8 | Delete with a warning | **WALKED — PASS** | User entry: dialog `Delete this content?` / `This cannot be undone.` — `Cancel` keeps the row, `Delete` removes it. Pre-set: dialog `Delete this content?` / `This cannot be undone. A deleted sample returns only if you reinstall the app.` — `Cancel` keeps it, `Delete` removes it; after a restart the two other pre-sets are intact and the entry stays gone, with `"deletedPresetIds":["preset_en_sample"]` in `index.json`; a `pm clear` (data-wiped launch) brings it back — exactly what the dialog promises (FR-014/15/16, SC-007) |
| 9 | Guards: empty and oversized saves | **EVIDENCE-ONLY** | No device path: both refusals are proven in `test/content_store_test.dart` (`saveNew refuses whitespace-only text and writes nothing`, `… refuses more than 100,000 characters and truncates nothing`, `exactly 100,000 characters is accepted`) against an injected store; the message is the localized `storageErrorMessage`/`nothingToSaveMessage` |
| 10 | Storage errors and a corrupt index | **WALKED — PASS** | `run-as … sh -c 'echo notjson > app_flutter/content/index.json'`, relaunch: the app starts on a re-seeded pre-set, **`The content library was repaired: a damaged index was replaced and the shipped samples are back.`** is on screen, the list holds the three pre-sets again, and `app_flutter/content/index.corrupt-1790201278170.json` exists. The failing-writer half is [unit]: `a failed write leaves the index and the library untouched` |
| 11 | Damaged entry | **WALKED — PASS** | `rm app_flutter/content/contents/c_1790199173623_0be4.txt`, relaunch, open the list: that row's subtitle reads `This content is damaged`, its `Delete` still works, and the other three entries are unaffected |
| 12 | Unsaved changes when switching content | **WALKED — PASS** | Edit without saving, then pick another entry: dialog `Unsaved changes` / `You have changes that are not saved.` with `Cancel` (the switch does not happen — the chosen content never loads) and `Discard` (the edit is dropped and the chosen content loads) |
| 13 | Many entries, no slowdown | **EVIDENCE-ONLY + UNVERIFIED (device half)** | [unit] PASS: 50 entries, the list path returns index metadata with **0** text reads (`many entries (T025, SC-005)`). [device] the ≤ 500 ms bar is **not measurable by dump-polling** — one `uiautomator dump` costs ~2 s (same caveat as spec 007); no stopwatch-free method was available on this box |

## Divergences (what the device showed that the tasks did not anticipate)

1. **Scenario 2, first pass read the Chinese page with the English voice.**
   First run: page held the Chinese pre-set, `Read page` produced three
   `Synthesis request for locale eng-USA and name en-US-language` utterances.
   Two controlled re-runs (relaunch → list → pick → read, nothing interleaved)
   produced `zho-CHN`/cmn-CN for every paragraph, and the same logcat window
   contained unattributed synthesis requests from before the walk started —
   i.e. the emulator was being used by hand while the first pass ran. The
   language path is script-based and deterministic (`detectLanguage` on the full
   paragraph), and an English engine voice can only mean the read ran over
   English text, so this is recorded as an environment artifact, not an app bug.
   Lesson for the walk: force-stop + relaunch before a read claim, and clear
   logcat immediately before the tap.
2. **The index repair was silent.** The contract requires that a moved-aside
   index be *reported* (FR-010), and the store raised the signal
   (`lastError = indexRepaired`) — but nothing in the UI ever read it, so the
   user's only evidence was their library shrinking. Fixed in this pass:
   `reading_view._reportStorageSignal()` surfaces the signal once, in the
   localized new key `libraryRepairedMessage` (all four ARBs) or
   `storageErrorMessage` for IO failures, and clears it. Verified on device by
   scenario 10's message line, and by the widget test `a repaired index is
   reported instead of silently resetting`.
3. **Editing a pre-set and pressing `Save` without changing the text still
   writes an entry** (scenario 3's first attempt). It created `… (2)` — useful
   proof that collision suffixes work on device, but worth knowing: `Save` is
   not gated on a real change, only on non-blank text.
4. **Pre-set titles are content-derived, not translated** (the T002 deviation
   recorded in `tasks.md`): the list shows `The sun rose over the q…`, not
   `English sample`, in every locale, and a seventh pre-set needs no ARB change.
5. **Device-typing recipe that cost the most time**: `adb shell input text`
   inserts **at the caret**; the caret is placed by tapping the character you
   want (a tap at the text's top-left corner gives offset 0). `Ctrl+A`
   (`input keycombination 113 29`), `KEYCODE_MOVE_HOME` (122) and
   `KEYCODE_MOVE_END` (123) are all **no-ops** in this TextField, so replacing a
   whole content needs a caret-first insertion plus `KEYCODE_ENTER` (66) to end
   the new first line. Also: in EDIT mode the field's text is **not** in the
   uiautomator dump, so the committed text is only observable after `Done`.

## Kept limitations

- **SC-008 (≥10 undo steps)** is not asserted as a count: the platform undo
  stack is uncapped and the button exposes only `canUndo`. The device run proved
  step-exact undo and self-disabling exhaustion (`Nothing more to undo`).
- **The ≤ 500 ms list-open bar** (scenario 13) is unmeasured on device: dump
  polling costs ~2 s per sample. The structural half of the claim — list latency
  independent of text size — is the [unit] index-only test.
- **iOS** is untested (no macOS on this host); the icon/spec 009 work inherits
  that gap.
- The walk drives `emulator-5554`, not the attached phone (`LE2115`): scenario 8
  and 10 wipe app data (`pm clear`, garbage index), which belongs on the
  disposable device.

## Re-running

The walk scripts are committed next to this file (`scripts/`), so the evidence
stays reproducible after the scratch copies are pruned. Each one re-dumps before
every tap and prints the line it relies on.

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter analyze && flutter test --concurrency=2      # 218 tests
flutter build apk --debug && adb -s emulator-5554 install -r \
  build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell pm clear com.example.klhu # fresh-install state

cd specs/008-content-storage/scripts
python3 klhu_walk.py a        # SC3 save/auto-name, SC4 restart persistence
python3 klhu_walk_a2.py       # SC6/SC7  (needs the library from klhu_walk.py a)
python3 klhu_walk_c.py        # SC12 guard, SC8 delete (user entry), SC11 damaged
python3 klhu_walk_e.py        # SC8 pre-set tombstone + wiped-data relaunch
python3 klhu_walk_f.py        # SC5 undo, exhaustion message
python3 klhu_walk_d.py        # SC11 + SC10 repair/report — DESTRUCTIVE, run last
```

`klhu_walk.py` is the shared driver (dump parsing, tap-by-bounds, logcat trace);
the `klhu_walk_*.py` scripts import its helpers. Scenario 1/2 were walked by hand
with the same helpers (`klhu_walk.py dump` / `tap`) plus the logcat trace.
