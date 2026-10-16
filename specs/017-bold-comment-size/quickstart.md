# Quickstart: A bold face, and a comment one size down

## Prerequisites

The line's own measured baseline, taken on **2026-10-12 11:22** on the checked-out tree (`409ffe1` + 016's
commit `3db8df5`), and every row below is read against it:

```
flutter analyze                      → No issues found! (ran in 1.1s)
flutter test --concurrency=2         → 00:56 +643: All tests passed!
```

Re-take it with the same two commands before reading any row. A row that fails while the baseline itself has
moved is a row about the baseline, not about this feature.

Device: AVD `klhu` = `emulator-5554` (API 36), package `com.example.klhu`, the debug APK installed with
`adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`. The device rows need
`/usr/bin/python3` (3.12) — the default `python3` has no PIL, and the drivers import their siblings' modules.
Artifacts land under `$KLHU_OUT` (default `/tmp`).

## Automated checks

```
flutter analyze                                                            # clean
flutter test --concurrency=2                                               # 643 → 643 + this feature's cases
flutter test test/appearance_store_test.dart test/reading_view_appearance_test.dart \
             test/reading_view_comment_test.dart test/video_painter_test.dart   # the four files this feature touches
flutter gen-l10n && git diff --stat lib/l10n                                # the generated Dart reproduces byte for byte
git diff --stat pubspec.yaml pubspec.lock android/ ios/                     # empty (FR-013)
```

## Scenarios

### 1. The record's own value domain — [unit]

**Steps**: run `flutter test test/appearance_store_test.dart`.
**Expected**: `bold||xlarge` round-trips; `bold||huge` → `(bold, medium)`; `Helvetica||xlarge` →
`(default, xlarge)`; a pre-017 value (`serif||xlarge`) is untouched; a three-part value is still the defaults;
and for **every** offered face the encoded value splits into exactly two parts.
**Evidence**: the test names in `test/appearance_store_test.dart`; the suite line for that file.
Proves FR-004, INV-1, INV-2.

### 2. The control offers six faces, previews the bold, and grows no third row — [unit]

**Steps**: run `flutter test test/reading_view_appearance_test.dart`.
**Expected**: the offered sets are the contract's (**six** faces, four sizes — the existing `12.` case, re-cut to
six); the preview paints the candidate in the bold weight **before** it is applied (`SC-001`); the control's own
shape is still one face row plus the size row and Save. 011's own cases in that file are **run unmodified** —
`12.`/`13.`/`16.` iterate labels, tap by name and drag the list to its end, none of which pins three faces
(corrected 2026-10-12, `plan.md`'s ripple 10); the case that does pin the set is the store's
`test/appearance_store_test.dart:114-119`, and it is re-cut by row 1's tasks.
**Evidence**: the case names; the re-cut `12. the offered sets are the contract's; xlarge fits the width`.
Proves FR-001, FR-003, FR-012, SC-001.

### 3. The page and the editor are bold; the chrome is not — [unit]

**Steps**: run the appearance group of `test/reading_view_appearance_test.dart` (`13. confirming styles the text
and the editor, not the chrome`, extended).
**Expected**: with each bold value in force — `bold` (no family), `serif-bold` (`serif`), `mono-bold`
(`monospace`) — the reading text's and the editor's painted style carries that family at `FontWeight.w700`; the
app's chrome does not.
**Evidence**: the case's own assertions; the seam at `lib/reading_view.dart:2511-2439`.
Proves FR-002.

### 4. The comment is painted one step down, at every offered size — [unit]

**Steps**: run `flutter test test/reading_view_comment_test.dart`.
**Expected**: with each of the four sizes in force, the comment's own characters are painted at the next size
down (24→18, 18→14, 14→12, **12→10**), and the sentence's characters are not changed by it.
**Evidence**: the four cases' names; the style values they assert.
Proves FR-007, FR-009, SC-003, INV-3, INV-4.

### 5. A content with no comment paints exactly what it painted before — [unit]

**Steps**: run `flutter test test/reading_view_comment_test.dart` (015's own no-tag cases, unchanged) plus the
new one-span case.
**Expected**: one span, the same text, the same style as before this feature.
**Evidence**: 015's cases run as they stand, unmodified.
Proves FR-011, INV-5.

### 6. The same tap selects the same sentence, and a step reads the same range — [unit]

**Steps**: run `flutter test test/comment_test.dart test/reading_view_step_test.dart
test/reading_view_continue_test.dart` — **as they stand, re-cut nowhere**.
**Expected**: every offset-bearing test that passed at the baseline still passes: the display mapping, the tap's
resolution, a step's own range, the highlight's boundaries.
**Evidence**: those three files' suite lines, unchanged from the baseline figures.
Proves FR-010, SC-004, INV-7.

### 7. The video's block carries the boundary and paints two spans — [unit]

**Steps**: run `flutter test test/video_painter_test.dart`.
**Expected**: a slot with a comment lays out two spans, the second one at the smaller size, beginning exactly at
`commentStart`; a slot without one lays out a single span, as today; the bold face's weight reaches the frame
through the reading style it already copies.
**Evidence**: the painter cases' names, including group `10-12. the reader's own appearance`.
Proves FR-008, FR-002, INV-6.

### 8. The bold face on the device, and the record it writes — [device]

**Steps**: open the reading page, open the appearance control, pick **Bold**, confirm; read the record with
`adb shell run-as com.example.klhu cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml`;
screenshot the page; force-stop and relaunch.
**Expected**: the screen lists **six** faces; the preview is bold before confirming; each bold value's record reads
`reading_appearance = bold||<size>` (and `serif-bold||<size>`, `mono-bold||<size>` — all **two-part** values); and
the weight's own effect is measured with the **family held still** — `serif||medium` against
`serif-bold||medium`, the bold one carrying at least a quarter more ink (comparing `default` against a *named*
bold would measure the family change as well: monospace's narrower glyphs fit more per line, a correction this
row's first device run made on 2026-10-12). After a force-stop and relaunch the same text is painted with a
bold value in force.
**Evidence**: the prefs line; the page's own screenshot (`/tmp/017_row8_bold.png`); the page's text dump.
Proves FR-002, FR-004, SC-001, SC-002.

### 9. `xlarge` + bold: the widest painted line against the page's width — [device]

**Steps**: with **each** bold face and `xlarge` in force (three measurements), read the text to its end; measure
the widest painted line's ink against the page's own width (the driver's own scan of the page screenshot).
**Expected**: **the measurement itself** — no verdict is assumed (research D6). The figure is recorded either
way, and if a line clips, 011's FR-012 gets a dated note naming the face and weight it holds for and the reader
is given the options. Measured 2026-10-12: the right edge of the ink is **exactly the column's own right bound
(1042 px) in every one of the six captures**, and a bold face's ink starts **10 px** closer to the left margin
(`serif-bold` 321 against `serif` 331 at `xlarge`) — a bold glyph's smaller side bearing, not a layout change, so
the row bounds the left drift and asserts the right edge.
**Evidence**: the measured pair (widest line, page width) in this feature's `breakpoint.md`, with the date.
Proves FR-006, SC-002.

### 10. The comment's measured size on the page, at `medium` and at `small` — [device]

**Steps**: on a content whose sentence carries a comment, screenshot the page at `medium` and again at `small`;
scan each PNG (Python + PIL) for the ink rows of the comment's line and of the text's line.
**Expected**: the comment's ink height is **smaller** than the text's at both sizes, and at `small` the ratio
matches 10 against 12 rather than 12 against 12 (INV-3's "always visibly smaller").
**Evidence**: the two screenshots and the four measured heights, in `breakpoint.md`.
Proves FR-007, FR-009, SC-003.

### 11. The comment in a video frame — and 015's row 22 re-taken — [device]

**Steps**: render a video of a content whose sentence carries a comment (`klhu render`); scan the frame that
paints that slot for the sentence's ink and the comment's ink.
**Expected**: the comment's characters measure smaller than the sentence's; and **015's row 22's own numbers**
(`text=18`, the ink box `(208, 864, 456, 964)`) are re-measured here and written into 015's `quickstart.md` and
`research.md` with the date — this row *is* that re-take.
**Evidence**: the frame's two ink boxes; the updated 015 row.
Proves FR-008, SC-005.

### 12. A Chinese word in the bold face — [device]

**Steps**: on a content whose text is Chinese, apply **each** bold value and screenshot the page (three shots —
the probe of 2026-10-12 says the fallback face decides the paint, so expect them to look the same).
**Expected**: every glyph is present (FR-005), and the screenshot shows what the platform does with a face it has
no bold for — the synthetic weight. This row's receipt is the picture, not a verdict.
**Evidence**: `/tmp/017_row12_bold_zh.png`.
Proves FR-005.

### 13. Structural: nothing installed, three labels added — [structural]

**Steps**: `git diff --stat pubspec.yaml pubspec.lock android/ ios/`; count the ARB keys; `flutter gen-l10n` then
`git diff --stat lib/l10n`; `flutter test test/l10n_keys_test.dart`.
**Expected**: the diff is empty (FR-013); each of the four ARBs carries **110** keys (107 + `fontBoldLabel`, `fontSerifBoldLabel`, `fontMonoBoldLabel`);
the regenerated Dart reproduces the committed files byte for byte; the l10n key test passes.
**Evidence**: the four commands' own output.
Proves FR-013, SC-006.

## Troubleshooting

- **`No such file or directory: /tmp/klhu_out/...`** — 012's own drivers write into `video.OUT`; make the
  artifacts' directories before a render row runs (`os.makedirs(experience.OUT)` and `os.makedirs(video.OUT)`).
  This bit 016's driver on a fresh host.
- **A PNG scan finds no ink where the comment should be** — the comment's line may be off screen; scroll so the
  whole block is in view before capturing, and crop to the reading area rather than the whole screen (the toolbar
  and the system bars carry ink too).
- **The prefs file is not there** — `run-as` needs the debug package; `pm clear` wipes it, and a fresh install
  writes nothing until the reader confirms an appearance (011's own rule: nothing is written until a choice is
  confirmed).
- **The suite count differs from 643 at the baseline** — re-take `flutter analyze` + `flutter test` first, and
  read the rows against the number you measured, not the one above.
