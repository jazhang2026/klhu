# Quickstart: Continue Read

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

Validation guide. Every scenario names **how** it is proven: `[unit]` is a Dart
test, `[device]` runs on the emulator with the app installed, `[structural]` is a
file/artifact check. No implementation code here.

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) —
  `flutter emulators --launch klhu`, wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- Desktop tests only need the checkout; the suite is 234 tests green on
  `main` before this feature (2026-09-24).

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get
flutter gen-l10n                            # regenerates lib/l10n/app_localizations*.dart
flutter analyze
flutter test --concurrency=2                # full suite; the emulator being up can make
                                            # plain `flutter test` segfault on this 16 GB host
```

Device rows:

```bash
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am start -n com.example.klhu/.MainActivity
adb -s emulator-5554 logcat -s flutter        # debugPrint output, including the read range
```

Reading the persisted position (the same path the device rows below use):

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep read_position
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`reading_view.dart`, `reader_service.dart`, the new store file) |
| `flutter test --concurrency=2` | every `[unit]` scenario below, plus the 234-test baseline as a regression gate |
| `flutter test test/reader_service_test.dart` | FR-011's new cases (one utterance per sentence, resume at the interrupted one) |
| `git status --short lib/l10n` after `flutter gen-l10n` | the generated localizations are committed artifacts, and the regeneration is reproducible (no drift) |
| `grep -rn "Read page" lib/ test/` | the old label is gone from source and tests (SC-001) |

## Re-run the device rows

The `[device]` rows are scripted — one command per part, each printing its evidence and
ending with `RESULT: PASS|FAIL`:

```bash
cd specs/010-continue-read/scripts
python3 klhu_walk_continue.py 13      # tap a paragraph, Continue Read starts there
python3 klhu_walk_continue.py 14      # the record, then the same range after a restart
python3 klhu_walk_continue.py 15      # pm clear ⇒ 0..<len>, the pre-010 read
python3 klhu_walk_continue.py 16      # pause mid-paragraph, resume repeats that sentence
python3 klhu_walk_continue.py 17      # whole reads in EN, ZH and ES (machine half)
```

`ADB_SERIAL` (default `emulator-5554`), `KLHU_REPO` (default this repo) and `KLHU_OUT`
(default `/tmp`) override the defaults. The driver reads the pre-set text straight out of
`assets/content/presets.json`, so a logged offset is checked against the shipped asset, not
against a copy. Rows and divergences: [breakpoint.md](./breakpoint.md).

## Validation scenarios

### 1. The button is Continue Read, in every shipped locale — [unit]

Test: `test/reading_view_continue_test.dart`, "toolbar offers Continue Read".
Steps: pump the view with the English (then zh, zh_Hans, es) locale.
Expected: `find.byTooltip(<continueRead label>)` finds one widget in each locale and
`find.byTooltip('Read page')` finds nothing. Proves FR-001/SC-001 (I11).

### 2. With no position set, Continue Read reads the whole text — [unit]

Test: `test/reading_view_continue_test.dart`, "no position reads from the beginning".
Steps: load content, tap Continue Read without tapping the text first.
Expected: the same speech sequence the old page read produced (per paragraph, in order,
joined equal to the content). Proves FR-005 and pins the regression (I1).

### 3. A tap sets the position; Continue Read starts there — [unit]

Test: `test/reading_view_continue_test.dart`, "tap sets the start position".
Steps: load content, tap the second sentence, tap Continue Read.
Expected: the first paragraph speech starts exactly at the tapped sentence's offset; the
spoken ranges are contiguous through the end of the text; the tap's sentence carries the
highlight before the read starts. Proves FR-002/FR-004/SC-002/SC-003 (I2).

### 4. A long-press sets the position at the paragraph start — [unit]

Test: `test/reading_view_continue_test.dart`, "long-press sets the paragraph start".
Steps: load content, long-press inside the second paragraph, tap Continue Read.
Expected: the first speech starts at that paragraph's start offset (not at the sentence
inside it). Proves FR-003 (I3).

### 5. Setting a position during a read stops it, then continues from there — [unit]

Test: `test/reading_view_continue_test.dart`, "tapping while speaking stops and re-anchors".
Steps: start a read, tap a later paragraph while it is speaking, tap Continue Read.
Expected: the first read was stopped; the view is back in READ with the new position
highlighted; the new read starts at the new position. Proves spec US1 scenario 5.

### 6. Tracking follows the read from the position; the position survives the end — [unit]

Test: `test/reading_view_continue_test.dart`, "tracking from a position, position retained".
Steps: anchor at the last paragraph, Continue Read, drive the fake reader's
`onParagraphStart`, then finish.
Expected: the highlight follows each spoken paragraph, clears at the end, and Continue
Read again still starts at the anchored position (the anchor is not a bookmark).
Proves FR-010 (I4/I6).

### 7. Nothing left to read from the position — [unit]

Test: `test/reading_view_continue_test.dart`, "no content remains is explained".
Steps: drive the view to a position at/after the last readable character (empty range).
Expected: no speech is attempted and a **localized** message is shown (not the previous
hardcoded English string); no exception. Proves FR-009's second half and the spec's
"very end of text" edge case.

### 8. Changing the text clears the position, in memory and on disk — [unit]

Test: `test/reading_view_continue_test.dart`, "text change clears the position".
Steps: set a position, then (a) Edit → Done, (b) Edit → Save, (c) load another content,
(d) empty the text — after each, tap Continue Read and read the stored key.
Expected: each case reads from offset 0 and the `read_position_<key>` record is gone
(FR-007, I7).

### 9. The position survives a restart, and nothing else does — [unit]

Test: `reading_view_continue_test.dart` + `test/read_position_store_test.dart`.
Steps: set a position, capture the mocked prefs map, pump a **fresh** view with those
prefs, tap Continue Read. Then repeat with a malformed value, and with a `charCount` that
no longer matches the text.
Expected: the fresh view starts at the stored position and paints its segment; the
malformed and mismatched records are ignored (read from 0, nothing thrown, message-free).
Proves FR-008/SC-004 and the contract's read rules (I8/I9).

### 10. Rapid taps leave the last position in force — [unit]

Test: `reading_view_continue_test.dart`, "rapid taps: the last position wins".
Steps: tap three different sentences back to back without pumping between, then Continue
Read and read the record.
Expected: the third tap's offset is the one spoken and the one stored (I10).

### 11. Mixed-language content reads per paragraph from the position — [unit]

Test: `test/reading_view_continue_test.dart`, "mixed content from a non-zero position".
Steps: load a two-paragraph English+Chinese text, anchor in the second paragraph,
Continue Read.
Expected: exactly the paragraphs from the anchor on, each with its own paragraph language
(`en`, `zh-Hans`), the first clipped to the anchor. Proves FR-004 + the 002 language
rule still holds (I2).

### 12. Pausing inside a paragraph resumes at the interrupted sentence — [unit]

Test: new cases in `test/reader_service_test.dart` — the **real** `ReaderService` against
the file's `FakeTtsBackend` (the view-level `test/reading_view_pause_test.dart` drives a
fake `Reader` with its own queue and therefore cannot observe this; its 005 expectations
stand unchanged).
Steps: hand the service **one** `ParagraphSpeech` holding three sentences; let sentence 1
finish; pause during sentence 2; resume.
Expected: three utterances in order while reading; `onParagraphStart` fires exactly once
for that paragraph; after resume the next utterance is sentence 2 — sentence 1 is **not**
repeated — and the run still ends at sentence 3. Proves FR-011/SC-006 (I12/I13/I14).

### 13. On the device: tap a middle paragraph, Continue Read starts there — [device]

Steps (with the app installed and `logcat -s flutter` running):
1. Open the shipped English pre-set (fresh install opens it directly).
2. Tap inside the **third** paragraph; observe the sentence highlight (FR-006/SC-005).
3. Tap Continue Read.
4. Read `logcat`: `klhu read range: <start>..<end>` — `<start>` must equal the tapped
   sentence's offset in the text, `<end>` the text length, **not** `0..<len>`.
5. Cross-check the engine's own lines: the same `adb logcat` shows one
   `Synthesis request for locale …` per spoken sentence, so a read from the third
   paragraph produces visibly fewer of them than a full-page read (scenario 15).
6. The first spoken paragraph is the one that was highlighted by the tracking callback —
   never the first paragraph of the text.

Expected: reading starts at the position the user set, and the read completes to the end
of the text. This is the device proof of FR-004/FR-010 that a UI dump cannot give
(`research.md` D10).

### 14. On the device: the position survives a restart — [device]

Steps:
1. Tap a middle paragraph, confirm the record exists:
   `… shared_prefs/FlutterSharedPreferences.xml | grep read_position` → `<offset>||<charCount>`.
2. `adb shell am force-stop com.example.klhu`, then relaunch the app.
3. The content reopens; the anchored sentence is highlighted again (D8).
4. Tap Continue Read; `logcat` shows the same non-zero range as step 1.

Expected: FR-008/SC-004 on a real restart, with the persisted record as the artifact.

### 15. On the device: no position → unchanged previous behaviour — [device]

Steps: `pm clear com.example.klhu` (removes every record), open the app, tap Continue
Read immediately.
Expected: `logcat` shows `klhu read range: 0..<len>` and the read is the full-page read
the app shipped before this feature (FR-005 on device, mirroring scenario 2).

### 16. On the device: pause mid-paragraph, resume repeats only that sentence — [device]

Steps:
1. Open the shipped English pre-set, tap Continue Read, and let the first paragraph's
   first sentence finish while `adb logcat -s flutter` runs.
2. Tap Pause during the **second** sentence of that paragraph. The highlight shows which
   paragraph is being read; the pause lands inside it. Note the last
   `klhu speak p<i> s<j> "…"` line before the pause.
3. Tap Resume.
4. The next `klhu speak` line must be `s<the interrupted sentence>` of the same paragraph —
   not `s0` — and the engine's `Synthesis request …` lines after the resume must not
   repeat the sentences already heard.

Expected: the listener hears the interrupted sentence again from its start and nothing
already heard before it. This is the device proof of FR-011/SC-006 (I12).

### 17. On the device: a sentence-queued read still reads acceptably — [device]

Steps: play the whole English pre-set end to end with no pause, then a Chinese pre-set
and a Spanish one, listening for the sentence boundaries.
Expected: each sentence is spoken in its paragraph's language and picked voice, with no
voice flicker, no clipped word and no long silence at the boundaries, and the read ends at
the last sentence. This is the human judgment for `research.md` D12's accepted cost; the
machine-checkable half of the evidence is the completed read plus one
`Synthesis request …` line per sentence in `logcat`.

### 18. Structural: the old label is gone and nothing else moved — [structural]

```bash
grep -rn "Read page" lib/ test/          # no matches
git status --short lib/                  # reading_view.dart, read_position_store.dart,
                                         # reader_service.dart,
                                         # lib/l10n/* (4 ARBs + 4 generated files)
git status --short android/ ios/         # empty: no platform work in this feature
```

## Troubleshooting

- **`flutter test` segfaults** — the `klhu` emulator is running on a 16 GB host; use
  `flutter test --concurrency=2` (or stop the emulator for the desktop run).
- **No `klhu read range` line in `logcat`** — the line is a `debugPrint`, so it only
  exists in a debug build and only under `-s flutter`; a release APK is silent by design.
- **A resume repeats a whole paragraph** — the installed APK predates FR-011, or the
  service still queues paragraph-sized utterances: `test/reader_service_test.dart`'s
  FR-011 cases (scenario 12) are red on the old behaviour.
- **Resume re-starts *before* the interrupted sentence** — the unit index and the resume
  point have drifted apart: the `_cursor` the service keeps must point at the same sentence
  it last handed the engine.
- **No `read_position_*` key after tapping** — the tap must land **on the text** (a tap on
  padding or the app bar resolves no segment); and the record is only written when the
  text on screen has an id (a library entry or the shipped pre-set).
- **A restored position disappears after an edit** — that is FR-007, not a bug: any change
  to the visible text clears the position.
- **iOS**: no macOS on this host, so the iOS half is not validated. This feature adds no
  platform code (it uses `shared_preferences`, already shipping on both platforms), so the
  iOS exposure is limited to the same `NSUserDefaults` record.
