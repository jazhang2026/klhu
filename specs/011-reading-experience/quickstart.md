# Quickstart: Reading Experience

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

Validation guide. Every scenario names **how** it is proven: `[unit]` is a Dart test, `[device]` runs
on the emulator with the app installed, `[structural]` is a file/artifact check. No implementation
code here.

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) —
  `flutter emulators --launch klhu`, wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- Desktop tests only need the checkout; the suite is 266 tests green on `main` before this feature
  (measured 2026-09-24 with `flutter test --concurrency=2`).

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
adb -s emulator-5554 logcat -s flutter        # debugPrint output: the read range, the follow lines
```

Reading the persisted appearance (the same path the device rows below use):

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep reading_appearance
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`reading_view.dart`, `reader_service.dart`, `appearance_store.dart`, `appearance_screen.dart`, `content_list_screen.dart`) |
| `flutter test --concurrency=2` | every `[unit]` scenario below, plus the 266-test baseline as a regression gate |
| `flutter test test/reader_service_test.dart` | the sentence callback's cases (one call per sentence, in order, with the content offsets) |
| `flutter test test/appearance_store_test.dart` | the contract's read rules and write protocol (round-trip, per-field fallback, malformed, one write per confirm) |
| `flutter test test/l10n_keys_test.dart` | every new key exists in all four ARBs — the gate that stops an English fallback in one locale |
| `git status --short lib/l10n` after `flutter gen-l10n` | the generated localizations are committed artifacts and the regeneration is reproducible (no drift) |
| `grep -rn "klhu follow" lib/` | the follow evidence line exists in exactly one place (the layer that decides) and is debug-only |

## Re-run the device rows

The `[device]` rows are scripted — one command per part, each printing its evidence and ending with
`RESULT: PASS|FAIL`:

```bash
cd specs/011-reading-experience/scripts
python3 klhu_walk_experience.py 7      # the page follows a long read, sentence by sentence
python3 klhu_walk_experience.py 8      # a read started below the fold shows that position
python3 klhu_walk_experience.py 9      # a short text that fits on screen never scrolls
python3 klhu_walk_experience.py 10     # Stop mid-read: the page stays where it stopped
python3 klhu_walk_experience.py 16     # Serif + X-Large, the record, then the same look after a restart
python3 klhu_walk_experience.py 17     # "+" adds a content; an empty Save adds nothing
```

`ADB_SERIAL` (default `emulator-5554`), `KLHU_REPO` (default this repo) and `KLHU_OUT` (default
`/tmp`) override the defaults. The driver imports `specs/010-continue-read/scripts/klhu_walk_continue.py`
for the shared device mechanics and reads the pre-set text straight out of
`assets/content/presets.json`, so a logged offset is checked against the shipped asset. Rows and
divergences: [breakpoint.md](./breakpoint.md).

## Validation scenarios

### 1. The reader reports the sentence it speaks, with its offsets — [unit]

Test: new cases in `test/reader_service_test.dart` (the **real** `ReaderService` against the file's
`FakeTtsBackend`).
Steps: hand the service one `ParagraphSpeech` holding three sentences, plus an `onSentenceStart`
collector, and feed the collected units to the view.
Expected: three calls in order whose `(paragraph, sentence)` are `(0,0)`, `(0,1)`, `(0,2)` and whose
`start`/`end` are exactly the sentence ranges of the text; for each call the view paints exactly the
reported span — the yellow covers the sentence handed to the engine and moves with it (FR-020, SC-008).
Proves FR-001's mechanism and pins the amended unit (research D2/D11).

### 2. A text that fits on screen is never scrolled — [unit]

Test: `test/reading_view_follow_test.dart`, "short text: no scroll".
Steps: pump the page in a viewport taller than the text, drive `onSentenceStart` for every sentence,
`pumpAndSettle` between them.
Expected: the scroll position's offset is `0` after every report, and no reveal was requested.
Proves FR-003/SC-003.

### 3. A sentence below the fold is revealed — [unit]

Test: `test/reading_view_follow_test.dart`, "long text: the spoken sentence comes into view".
Steps: pump a text much taller than the viewport; report the last sentence; `pumpAndSettle`.
Expected: the offset increased, and the reported sentence's box (measured on the rendered paragraph)
is fully inside the viewport, `0 <= top < bottom <= viewport`. Proves FR-001/SC-001.

### 4. A read that starts below the fold shows that position first — [unit]

Test: `test/reading_view_follow_test.dart`, "Continue Read from a stored position".
Steps: seed the mocked prefs with a `read_position_*` record far down a long text, pump the view, tap
Continue Read.
Expected: the first report is the stored position, and it is inside the viewport by the time it is
reported. Proves FR-002/SC-002.

### 5. A manual scroll survives until the next sentence — [unit]

Test: `test/reading_view_follow_test.dart`, "manual scroll is not undone".
Steps: start a read, report a sentence, then scroll the page by hand; report **the same** sentence
again (a resume does exactly this), then the next one.
Expected: the same sentence does not move the page; the next sentence reveals at most itself; and the
resume that re-reports the interrupted sentence re-paints that sentence, so the highlight and the
utterance being repeated agree (FR-021). Proves FR-004/FR-005.

### 6. Reported offsets are always inside the content, and never go backwards — [unit]

Test: `test/reading_view_follow_test.dart`, "offsets are in range and monotonic per read".
Steps: report a whole read's worth of sentences (including a resumed one whose first utterance is a
paragraph remainder, the case the reader clips).
Expected: every `start`/`end` satisfies `0 <= start < end <= content.length` and no `start` is below
the previous report's `start` within one generation. Proves the data-model invariant and FR-004's
"nothing is skipped" reading of a resumed queue.

### 7. On the device: the page follows a long read, sentence by sentence — [device]

Steps (app installed, `adb logcat -s flutter` running, buffer cleared before the read):
1. Open the shipped English pre-set (fresh install opens it directly).
2. Tap Continue Read and let the read run to the end.
3. Read back every `klhu follow: p<i> s<j> visible=<0|1> top=<t> bottom=<b> viewport=<h>` line.
Expected: one line per sentence spoken (correlate with `klhu speak p<i> s<j>`), each with
`visible=1` and `0 <= top < bottom <= viewport`; and the paint half as a pixel claim: for a screenshot
taken while a sentence is spoken, the yellow pixel count **inside** that line's `top..bottom` band is
> 0 while the count **outside** it is ~0 — the highlight covers exactly the sentence being spoken and
nothing else (FR-020/SC-008).
This is the device proof of FR-001/SC-001 and of the amendment (research D3). It needs the app-side
line: nothing in `logcat` from the engine or the platform reports where the page is scrolled, and a
whole-screen yellow count cannot tell a sentence's span from a paragraph's.

### 8. On the device: a read started far down the text reveals its position — [device]

Steps: tap a late paragraph (sets the Continue Read position), tap Continue Read, and read the first
`klhu follow:` line.
Expected: the first line is that paragraph's first sentence with `visible=1`, and the `klhu read
range: <start>..<end>` line still starts at the tapped offset (010 unchanged). Proves FR-002/SC-002 on
a device, where the scroll only exists if it actually happened.

### 9. On the device: a text that fits on screen never moves — [device]

Steps: open a short pre-set (the Spanish sample fits on one screen on this AVD), start a read, note the
`klhu follow:` lines and take two `screencap`s, one before and one during the read.
Expected: every line has `visible=1` with no reveal (no offset change: the driver compares the
`klhu follow` geometry against the viewport and the two screenshots' text-region rows), and the yellow
pixel count is non-zero throughout. Proves FR-003/SC-003.

### 10. On the device: Stop mid-read leaves the page where it stopped — [device]

Steps: start a long read, wait until the page has scrolled (at least one line with an increased
`top`/`bottom` in a previous report), tap Stop, then screenshot twice a second apart.
Expected: the page does not return to the top; the highlight clears (010 behaviour) and the text
stays where it was. Proves FR-004.

### 11. The appearance control is idle-only and localized — [unit]

Test: `test/reading_view_appearance_test.dart`, "the action is offered when idle, disabled while
speaking".
Steps: pump the view in each of the four locales with a fake reader; start a read and drive the mode
to SPEAKING; look for the action.
Expected: `find.byTooltip(<appearance label>)` finds one widget in every locale while idle and the
action is disabled (`IconButton.onPressed == null`) while a read is playing. Proves FR-014 and the
l10n parity of the new keys.

### 12. The offered sets are the contract's, and the largest size still fits the width — [unit]

Test: `test/appearance_store_test.dart` + `test/reading_view_appearance_test.dart`.
Steps: read the offered typefaces and sizes off the store's constants; pump the reading page at
`xlarge` with the longest shipped pre-set line in a 360 dp-wide viewport.
Expected: exactly `default`/`serif`/`mono` and `small`/`medium`/`large`/`xlarge`; no overflow exception
in the render, and the paragraph's width stays within the viewport. Proves FR-007/FR-012 with the
numbers the contract states.

### 13. Confirming applies to the reading text and the editor, and not to the app's chrome — [unit]

Test: `test/reading_view_appearance_test.dart`, "the choice styles the text, not the app".
Steps: confirm `serif` + `large`, then read the resolved `TextStyle`s: the `RichText`'s root span
(READ), the `TextField`'s style (EDIT), and the app-bar title.
Expected: the text's span and the field carry `fontFamily` `serif` and `fontSize` 18; the app-bar
title keeps the theme's style (no family, its own size). Proves FR-006/FR-009.

### 14. Choosing, persisting and reloading an appearance — [unit]

Test: `test/appearance_store_test.dart` + `test/reading_view_appearance_test.dart`.
Steps: (a) load with nothing stored → `(default, medium)` and the shipped style; (b) confirm `serif`
+ `xlarge` and read the mocked prefs map; (c) pump a **fresh** view with those prefs.
Expected: (a) the theme's `bodyMedium` (14, no family); (b) exactly one key `reading_appearance` with
`serif||xlarge`; (c) the fresh view renders `serif` at 24. Proves FR-010/SC-005 and contract
invariants 1, 2, 6 and 7.

### 15. Dismissing the screen remembers nothing; malformed values fall back per field — [unit]

Test: `test/appearance_store_test.dart` + `test/reading_view_appearance_test.dart`.
Steps: (a) open the screen, change both rows, go back without confirming, read the prefs map and the
page's style; (b) load with `Helvetica||xlarge`, then `serif||huge`, then `serif`, then
`serif||xlarge||extra`.
Expected: (a) no key written and the previous look still in force; (b) `(default, xlarge)`,
`(serif, medium)`, and defaults for the two malformed shapes — never an exception, never a rewritten
record. Proves FR-008/FR-011/US2 scenario 4 and contract read rules 1–3.

### 16. On the device: a chosen look survives a restart — [device]

Steps:
1. Open the appearance screen, choose Serif and X-Large, confirm.
2. `… shared_prefs/FlutterSharedPreferences.xml | grep reading_appearance` → `serif||xlarge`.
3. `adb shell am force-stop com.example.klhu`, relaunch, screenshot the reading page.
4. Switch the typeface back to Default, screenshot again.
Expected: the record is in the prefs file, the relaunched app renders the larger serif text, and the
text region differs between the two screenshots (the pixel half of the claim). The reviewer eyeballs
the screenshots for the `xlarge` layout and for missing-glyph boxes in each language — glyph coverage
is not machine-checkable through Flutter's API, so this row records the screenshots rather than
asserting a number. Proves FR-006/FR-010/FR-013/SC-004/SC-005.

### 17. On the device: "+" adds a content, an empty Save adds nothing — [device]

Steps:
1. From the reading page, open the contents list; tap the add action (tooltip `<addContent label>`).
2. Type a short sentence and tap Save.
3. Return to the list.
4. Repeat (1), tap Save with nothing typed, then go back.
Expected: step 2 creates a row whose name is the typed text (auto-generated, no name prompt) and it is
at the top of the list; step 4 shows the existing "There is nothing to save" message and the list
gains no row; the prefs file gains no position record for the draft (it had no name). Proves
FR-015–FR-019/SC-006/SC-007.

### 18. Structural: what moved, and what must not have — [structural]

```bash
grep -rn "klhu follow" lib/                     # one site: the view's follow routine
grep -rn "onParagraphStart" lib/ test/          # no matches: the callback is replaced, not duplicated
git status --short lib/                         # reading_view.dart, reader_service.dart,
                                               # appearance_store.dart, appearance_screen.dart,
                                               # content_list_screen.dart, lib/l10n/* (4 ARBs + the
                                               # regenerated app_localizations*.dart)
git status --short test/                        # the 3 new files + the tracking tests that were
                                               # rewritten to sentence granularity (never deleted)
git status --short android/ ios/                 # empty: no platform work in this feature
git status --short assets/                       # empty: no font asset is added (research D5)
flutter test test/l10n_keys_test.dart            # key parity across all four ARBs
```

### 19. Adding a content from the list: request, save, refusal, discard — [unit]

Test: `test/reading_view_new_content_test.dart` + `test/content_list_test.dart` (the unit half of
scenario 17's device row).
Steps: from the list, tap the add action, then (a) type a sentence and Save; (b) Save with nothing
typed; (c) leave a fresh draft with Done/back; (d) after (c), check the content that was on screen
before the "+".
Expected: the add action resolves to a **new-content request**, not to a library entry; the page opens
blank, editable and focused with no entry created anywhere; (a) Save creates an entry whose name is the
typed text (auto-generated, no name prompt) and it appears in the list; (b) is refused with the
existing "There is nothing to save" message and creates nothing; (c) creates nothing and leaves the
library unchanged; (d) that earlier content keeps its stored position and its saved text.
Proves FR-015–FR-019 and SC-006/SC-007.

## Troubleshooting

- **`flutter test` segfaults** — the `klhu` emulator is running on a 16 GB host; use
  `flutter test --concurrency=2` (or stop the emulator for the desktop run).
- **No `klhu follow:` line in `logcat`** — the line is a `debugPrint`: debug builds only, and only
  under `-s flutter`. A release APK is silent by design.
- **The page does not follow** — the follow callback is installed by the page's own read actions
  (Read / Continue Read); a voice preview or a read started elsewhere never tracks, as in 003.
- **The highlight still covers the whole paragraph** — the old paragraph-metrics callback is still
  wired: after the amendment the tracking callback reports the sentence (D2/FR-020), and
  `grep -rn "onParagraphStart" lib/` must come back empty.
- **The highlight and the spoken sentence disagree after a pause** — the resume must re-report the
  interrupted sentence (010's rule) and re-paint it; a highlight that jumps to the previous or next
  sentence means the tracking callback and the queue cursor have drifted apart (FR-021).
- **Chinese under Serif looks like Chinese under Default** — measured, not a bug: the generic families
  fall back to the lang-tagged CJK family for Han text (`/system/etc/fonts.xml`, research D5). The
  Latin part of a mixed text does change; scenario 16 records what the screenshots show.
- **`reading_appearance` is missing after choosing** — the confirm must be tapped: dismissing the
  screen writes nothing by design (FR-008), and a value identical to the default is the same as no
  record.
- **A new row never appears after "+"** — the Save must succeed first: an empty or whitespace-only
  draft is refused with "There is nothing to save" and creates nothing (008's rule, FR-018).
- **A reading position lost after adding content** — expected: a draft has no name, so it writes no
  position; the content that was on screen keeps its own record (FR-019).
- **iOS**: no macOS on this host, so the iOS half is not validated. The feature adds no platform code
  (`shared_preferences` and a `fontFamily` string already ship on both), but the iOS family names in
  the contract's table are unverified here (research D5).
