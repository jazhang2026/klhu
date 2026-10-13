# Quickstart: Head tags (`#` a title, `##` a subtitle)


> This feature's own device walk — every row's command, evidence and state — is `breakpoint.md`, beside
> these artifacts; its driver and fixture are `scripts/klhu_walk_head.py` and `scripts/klhu_head_fixture.txt`.

## Prerequisites

The line's own measured baseline, taken on **2026-10-13 09:05** on the checked-out tree (`35f34cc` + the
uncommitted 016-step fix: `lib/comment.dart`, `test/step_ranges_test.dart`, `test/reading_view_step_test.dart`,
`text.txt`), and every row below is read against it:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 00:57 +663: All tests passed!
message keys per ARB (four files)    → 110 each (this feature adds none)
```

Re-take it with the same two commands before reading any row. A row that fails while the baseline itself has
moved is a row about the baseline, not about this feature.

**Every row about a mark's look is read against the ladder** (spec FR-006/FR-007, amended 2026-10-13): the four
offered sizes in the reader's order, then the largest offered size at the **bold** weight and at the **black**
weight — `small 12 → medium 14 → large 18 → xlarge 24 → 24 bold → 24 black`. A title takes the rung **two** steps
above the reader's own, a subtitle the rung **one** step above, both clamped at the last; a comment takes the rung
one step **down**, the weight first. The five reader rungs and the six comment cases are tabled in
[`data-model.md`](./data-model.md) § The ladder.

Device: AVD `klhu` = `emulator-5554` (API 36), package `com.example.klhu`, the debug APK installed with
`adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`. The device rows need
`/usr/bin/python3` (3.12) — the default `python3` has no PIL, and the drivers import their siblings' modules.
Artifacts land under `/tmp`. A page's own text is read back from `uiautomator dump` (the RichText's text, on the
device, character for character); a read's is read back from `adb logcat | grep 'klhu speak'`; a frame's from
the renderer's own `klhu render slot=… span=… text=<n>` line.

## Automated checks

```
flutter analyze                                                            # clean
flutter test --concurrency=2                                               # 663 → 663 + this feature's cases
flutter test test/head_tag_test.dart test/comment_test.dart test/reading_view_head_test.dart \
             test/speech_resolver_test.dart test/step_ranges_test.dart \
             test/reading_view_comment_test.dart test/video_timeline_test.dart \
             test/video_painter_test.dart test/appearance_store_test.dart   # the files this feature touches
git diff --stat pubspec.yaml pubspec.lock android/ ios/ lib/l10n/          # empty (FR-010's no-key half)
```

## Scenarios

### 1. The recognition table — what is a mark, exactly — [unit]

**Steps**: run `flutter test test/head_tag_test.dart`.
**Expected**: `# Basic Spanish 1` → one level-1 mark, `markEnd == 2`, its painted span `Basic Spanish 1`;
`## Greetings` → one level-2 mark, `markEnd == 3`; and **no** mark for any of `#hashtag`, `#1 best`, `### note`,
`#### `, a lone `#`, a lone `##`, `# ` with whitespace alone after it, `  # Title` (a marker preceded by
whitespace), `#\tTitle`, `# Title #` (a trailing `#`-sequence) and an empty text.
**Evidence**: the case names in `test/head_tag_test.dart`; the suite line for that file.
Proves FR-001, FR-002, FR-014.

### 2. A mark's scope is its line, and a comment's words are the comment's — [unit]

**Steps**: run `test/head_tag_test.dart` (its scope group) with `displayOf`.
**Expected**: `text\n# Title\nmore` yields **one** mark, whose span is the `Title` line only: the lines around
it are painted and painted at the body's size; a `# ` line **inside** a comment's span (a comment that runs
onto a following line) yields no mark and is spoken as the comment's own characters; a mark standing on a line
that also carries a comment is still a mark, and the comment still rides the line.
**Evidence**: the cases' own assertions, with the spans' offsets.
Proves FR-008, FR-009.

### 3. The marker is painted nowhere and every offset still answers — [unit]

**Steps**: run the new group of `flutter test test/comment_test.dart` (015's own cases stay unmodified beside
it).
**Expected**: `displayOf`'s `text` is the content minus every mark's `[start, markEnd)` and every tag's
`[tag.start, tagEnd)`; `toContent(toDisplay(o)) == o` for every content offset outside an elided span and
`toDisplay(toContent(d)) == d` for every display offset; for a text with no tag and no mark `text == content`
and both mappings are the identity.
**Evidence**: the cases' names and the offsets they assert.
Proves FR-003, FR-010.

### 4. The ladder's six rungs, and the two rungs a reader's own choice derives — [unit]

**Steps**: run `flutter test test/appearance_store_test.dart` (the helper's cases) and the rung group of
`test/reading_view_head_test.dart`.
**Expected**: the ladder is `12 w400 → 14 w400 → 18 w400 → 24 w400 → 24 w700 → 24 w900` — its first four rungs the
offered sizes, its last two the top size at the weight 017's faces carry and at the one below — and for each
reader rung: `small` → marks `14 w400`/`18 w400`; `medium` → `18 w400`/`24 w400`; `large` → `24 w400`/**`24
w700`**; `xlarge` → **`24 w700`**/**`24 w900`**; and a **bold face at `xlarge`** → both marks `24 w900`, the
clamped pair SC-006 names and the only equal one in the ladder.
**Evidence**: the four cases' names; the asserted sizes and weights, exactly the six values above.
Proves FR-006, FR-007, SC-002, SC-006, INV-5.

### 5. The page paints the line at its rung, in the reader's own face — [unit]

**Steps**: run `flutter test test/reading_view_head_test.dart`.
**Expected**: with each reader rung in force and each of the six faces, a `#` line's spans carry the rung's
`fontSize` **and** its `fontWeight` in the reader's own family (never a second face, never a weight the ladder did
not give it) — so at `large` the title's span is 24 `w700` over a 24 `w400` body, and at a regular `xlarge` the
subtitle is `w700` and the title `w900`; no painted span's text contains the marker's characters; and a content
with unmarked shapes (`#hashtag`, `#1 best`, `### `, a lone `#`, a mid-line `#`, `  # Title`, `# Title #`) paints
exactly the spans the baseline painted.
**Evidence**: `tester.widgetList<RichText>` over the reading text
(`test/reading_view_appearance_test.dart:151-156`'s own pattern) and the span styles it reads.
Proves FR-005, FR-007, SC-003.

### 5b. A bold body's marks are bigger and lighter — and the ladder's top — [unit]

**Steps**: run the bold-body group of `test/reading_view_head_test.dart` with 017's `bold`, `serif-bold` and
`mono-bold` in force at each of the four sizes.
**Expected**: below `xlarge` a bold body's marks take the **regular** rungs above it — at `medium`: subtitle
`18 w400`, title `24 w400`, i.e. bigger and lighter than the body, which is what the reader's own chosen order
gives (their option 1, research D4); at `xlarge` a bold body's two marks are both `24 w900` and equal, asserted
as the exhausted top rather than as a difference; and no case paints a mark in a family the reader did not choose.
**Evidence**: the case names; the asserted sizes and weights.
Proves FR-006, FR-007, SC-006.

### 6. No read reaches the engine with a `#` in it — [unit]

**Steps**: run `flutter test test/speech_resolver_test.dart` (its comment group and the new mark group) and the
read group of `test/reading_view_head_test.dart`.
**Expected**: for a marked text the speeches' `text`s are the display's own words — `# Basic Spanish 1` yields
an utterance `Basic Spanish 1` and **never** a `#` — with the utterances' `start`/`end` still the content
offsets they were; a marked line that also carries a comment reads as the title's words plus the comment's,
with neither marker nor tag spoken; a line whose text is only `#` is read as written; and for every content
with no tag and no mark a speech's `display` is `null` and `text == content.substring(start, end)` exactly as
at the baseline (the re-cut of that file's own invariant case, with its new name).
**Evidence**: the cases' names; the `klhu speak` lines in row 10 for the device half.
Proves FR-004, FR-011.

### 7. The step list equals the same text with the markers written as spaces — [unit]

**Steps**: run `flutter test test/step_ranges_test.dart` — the reader's own content **unmodified** — plus the
marked variant added beside it.
**Expected**: the reader's own seven-line content yields the same seven steps as the 2026-10-12 fix produced
(unchanged, since it carries no `#`); a marked text's `stepRanges` is the same list of ranges, in the same
order, as the same text with `# ` written as `  `; the marks never become steps of their own, and the
highlight a step paints is the line's own span.
**Evidence**: the case names; the two lists' ranges, asserted equal.
Proves FR-011, SC-004.

### 8. A comment's own behaviour is untouched by a mark — [unit]

**Steps**: run `flutter test test/reading_view_comment_test.dart` (015's and 017's own cases) and the
dialogue group of `test/reading_view_head_test.dart`.
**Expected**: with a comment on a marked line, the comment's characters are painted at their own step down the
ladder (FR-015's) while the rest of the line carries the mark's rung — so at `large` the title's characters are 24
`w700` and its comment's 24 `w400`; a mark inside a 多人对话 turn is read as that turn's sentence in its role's
voice; and 014's Format action, the comment switch, the tap's resolution and the step's range are what they were.
**Evidence**: the two files' suite lines and the re-cut case names, where any.
Proves FR-012, FR-009.

### 8b. A bold body's comment is the same size and lighter — [unit]

**Steps**: run the comment cases of `test/appearance_store_test.dart` and of `test/reading_view_comment_test.dart`
with 017's `bold` in force at each of the four sizes, then with the regular `default` beside them.
**Expected**: with a bold face the comment's characters carry the sentence's own `fontSize` at `w400` (at a bold
`xlarge`: 24 `w400` beside 24 `w700`); with a regular face every case is what 017's own `quickstart.md` and
`breakpoint.md` hold — `24 → 18`, `18 → 14`, `14 → 12`, `small → 10`, at the same weight — so **none of 017's own
figures moves**, and the one behaviour the amendment changes is the bold case asserted here.
**Evidence**: the case names on both sides; both runs' suite lines; 017's figures quoted beside them.
Proves FR-015, SC-007.

### 9. The frame's block carries the mark's spans and the rung — [unit]

**Steps**: run `flutter test test/video_timeline_test.dart test/video_painter_test.dart`.
**Expected**: a slot's `text` contains no marker character and its `headings` name the lines that carry one, in
that text's own index space with their levels; a frame whose whole sentence is a title paints **one** run at the
rung's size **and** weight, carried onto the frame's own scale the way 017's comment size is (at `large`: the
title's 24 `w700` over the body's 24 `w400`); a frame whose sentence holds a title line over body lines paints them
separately; a comment riding a marked line paints at its own step down; and a content with no mark yields
`headings` empty and the block 012 paints today.
**Evidence**: the painter's own layout helpers and the cases that read the painted runs' sizes and weights.
Proves FR-013.

### 10. The page on the device: no marker on screen, none in the voice, and the ladder at each size — [device]

**Steps**: install the debug build; open a content whose first line is `# Basic Spanish 1` (the reader's own
title) with a `## Greetings` subtitle, a body and a comment line; `uiautomator dump` the page; read `adb logcat
| grep -E 'klhu (speak|read range)'`; screenshot; then repeat at each of the four Appearance sizes at the regular
face, and once more at `xlarge` with 017's **Bold** in force.
**Expected**: the dump's text carries **no** `#` and no `##`, and carries the title's and subtitle's own words;
every `klhu speak` line's quoted text is the line's own words with no `#`; the screenshots show the ladder's own
rows in the reader's own face — `small`: subtitle 14 / title 18; `medium`: 18 / 24; `large`: 24 regular / 24
**bold**; `xlarge`: 24 **bold** / 24 **black**; and at `xlarge` with Bold in force the title and the subtitle are
painted the same — the exhausted top `plan.md` names, with the picture the reader judges it by.
**Evidence**: the dump's text; the `klhu speak` lines; the five screenshots, in `breakpoint.md`.
Proves FR-003, FR-004, FR-005, FR-007, SC-001, SC-006.

### 11. ▶ and ⏭ through a marked text — [device]

**Steps**: on the same content press ▶ through every line, then ⏭ from the middle; read the app's own
`klhu read range` and `klhu speak` lines and the highlight's own rows out of a screenshot.
**Expected**: the highlight visits the same lines, in the same order, as on the same text with the markers
absent — the marks are never steps of their own; the read's ranges are the lines' own content ranges; and no
utterance carries a marker character, including the title's and the subtitle's own.
**Evidence**: the two log lines per press; the screenshots' highlight rows.
Proves FR-004, FR-011, SC-004.

### 12. The video's title frame — and the shapes that must not move — [device]

**Steps**: render a video of the marked content on the device; read the renderer's own
`klhu render slot=… span=… text=<n>` lines; extract the title frame and measure its ink box with the driver's
own `scan_frame` (the machinery 012's rows 32/49 and 015's row 22 use); render the same content with the marks
replaced by nothing and compare the frames of its unmarked lines; and render a **Chinese** content with a title
and a subtitle at `xlarge` (the ladder's two weight rungs) for the synthesised-weight picture.
**Expected**: the title's slot reports `text=<the title's own character count>` — **no** marker counted — and
its frame's ink box is taller and heavier than a body sentence's frame at the same scale, at the **rung's**
weight: measured twice, once at `large` (the title's 24 `w700` over a regular body) and once at a bold-faced
`xlarge` (the title's 24 `w900` over the body's 24 `w700`); a frame whose slot holds a title over body lines paints
the title line at its rung; the comment's line paints at its own step down; every frame of a sentence that carries
no mark is what 012 produces today; and the Chinese pair's two frames are the picture of what the platform
synthesises rather than a verdict on it.
**Evidence**: the `klhu render` lines; the measured ink boxes, written into this row and `breakpoint.md`.
Proves FR-013, SC-003, SC-005.

### 13. Structural: nothing added, nothing translated, nothing stored — [structural]

**Steps**: `git diff --stat pubspec.yaml pubspec.lock android/ ios/ lib/l10n/`; count the ARB keys; run
`flutter gen-l10n` then `git diff --stat lib/l10n`; run `flutter test test/l10n_keys_test.dart`; confirm the
Appearance control still offers **six faces and four sizes** and no new entry
(`git diff --stat lib/appearance_screen.dart`); grep the whole tree for a `#`-mark fixture that a sibling
driver's row would now read differently (`grep -rn "klhu speak\|klhu render" specs/*/scripts/*.py`).
**Expected**: the dependency and platform diff is empty; each of the four ARBs carries **110** keys (this
feature adds none); the regenerated Dart reproduces the committed files byte for byte; the key test passes; the
Appearance control is untouched — the ladder is derived, never offered (the reader's answer of 2026-10-13); and
every sibling driver's parser still matches the app's own lines, whose fields are **unchanged** in this feature.
**Evidence**: the commands' own output; the suite count read against the baseline's 663 with the difference
decomposed by file.
Proves FR-010, SC-003.

### 14. A bold body's comment, measured on the page — [device]

**Steps**: with 017's **Bold** in force, open a content whose sentence carries a comment; screenshot the page at
each of the four Appearance sizes; scan each PNG (Python + PIL) for the ink rows of the comment's line and of the
sentence's line; then repeat with the regular `default` face beside them and put 017's own measured pair next to it.
**Expected**: with Bold in force the comment's ink height **equals** the sentence's own at every size (the same
size at the regular weight — lighter, not smaller), and with the regular face the comment's ink is the one 017's
own row measured (strictly smaller at each size) — so the picture shows the amendment moving the bold case alone.
**Evidence**: the eight screenshots and the sixteen measured heights, in `breakpoint.md`.
Proves FR-015, SC-007.

## Troubleshooting

- **`uiautomator dump` shows the marker** — the page paints the *display*; a `#` in the dump means the span
  tree was built from the content instead of `_commentDisplay`, which is the first thing row 10 would catch.
  Check the build is the debug APK above `git rev-parse --short HEAD`.
- **A `klhu speak` line quotes `#`** — the speech's `text` came from the content rather than from the display
  (or a speech's `display` is null for a marked content). The resolver sets it on every path; a test that
  builds a `ParagraphSpeech` by hand has none, which is why row 6 pins both shapes.
- **The frame's `text=<n>` counts two more characters than the title has** — the block was built from the
  content's own slice rather than from the display's, or a mark's two characters were substituted rather than
  elided (research D1's refused alternative). 015's own row 22 reads the same figure the same way.
- **A mark paints at the wrong weight** — the **rung** is the whole answer: `w400` on the ladder's four size
  rungs, `w700` and `w900` on its two rungs at the top size, and never simply "the reader's own weight". Row 4's
  table is the expectation, and a bold body's marks being *lighter* than its body is by design (row 5b).
- **017's own figures seem to have moved** — they should not: its fixture and its rows use a **regular** face,
  which FR-015 leaves alone (row 8b runs both faces side by side). A moved 017 figure is a defect, not a
  permitted deviation.
- **A title and a subtitle look identical at `xlarge`** — expected only when the reader's own face is **bold**
  (the ladder's last rung, `plan.md`'s limit 1); at a regular `xlarge` they must differ (24 bold against 24
  black), and a tie there is a defect in the rung arithmetic.
- **A title's line looks indented on the page** — the elision is gone and the marker's characters are still in
  the painted string; a text with no `#` at all is the control (SC-003's shapes should be byte-identical).
- **The page's own screenshots disagree with the dump** — re-take the baseline first (`flutter analyze` +
  `flutter test --concurrency=2`): a suite that has moved since 663 makes every row here unreadable.
