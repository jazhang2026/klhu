# Breakpoint — the device walk of 021 (`klhu_walk_pass.py`)

Device `emulator-5554` (AVD `klhu`), package `com.example.klhu`, debug build installed 2026-10-15 16:03 from the
tree of that afternoon. Every row below is the app's own evidence as the device reported it — the uiautomator dump's
own node labels, verbatim — plus a still per state under `/tmp/klhu_out` for the reader's own eye.

> **2026-10-16 — the stills are gone, and the build moved.** `/tmp` was cleared by a reboot, so every
> `/tmp/klhu_out/...` path quoted below is a record of an image that no longer exists; re-cutting it means re-running
> the walk. The package on the device was also re-installed today (`lastUpdateTime=2026-10-16 08:43:56`, an APK
> built 08:43:54 from this same tree) against the 2026-10-15 16:03 build the rows below were driven on. The quotes
> stand as taken; a re-run drives the newer build. **Done the same morning, 09:25–09:40**: the whole walk was
> driven again on the fixed build (`lastUpdateTime` 09:24:14) — rows 8-15, 17, 19 and 20, every one green
> (`5/5, 6/6, 8/8, 8/8, 11/11, 12/12, 6/6, 12/12, 8/8, 11/11, 9/9`) — so the stills named below exist as of
> 09:41, and the two rows this amendment added or re-cut carry both builds' own runs.

The driver imports **020's own module** for everything it already has (the ten-sentence fixture, the three pictures,
the prompt's flow, the pass, the dump readers) and adds 021's own: the **cell's own label** (the picture's name and
the number it carries in one node) and the two gestures no earlier row drives. Run as
`ADB_SERIAL=emulator-5554 /usr/bin/python3 -u specs/021-picture-pass/scripts/klhu_walk_pass.py 8` —
`/usr/bin/python3` because the driver chain imports PIL (3.12 has it; the box's default `python3` does not), and
`ADB_SERIAL` because this box has more than one device attached and `adb` refuses without it.

## Row 8 — the strip's own cells, each with its own count (FR-001, FR-002, SC-001)

`8/8: 5 checks passed`. The cells' own labels, as the device reports them:

```
{'w020_white.png': '0', 'w020_black.png': '0', 'w020_red.png': '0'}
one cell, as the device reports it: {'desc': 'w020_white.png\n0', 'text': '', 'enabled': True, 'x': 319, 'y': 409}
```

- **The name survives as the cell's own label and the number rides the same node** (`w020_white.png\n0`) — the
  shape 020's own `chip_line` parser reads, which is why 020's rows 6-11/16 are not invalidated by FR-002.
- The strip carries **no count words** (`No sentences assigned` is nowhere on it; the only label mentioning
  anything is the page's own `Assign sentences`) — FR-019's own half.
- The still: `/tmp/klhu_out/021_row8_strip.png` (the reader's eye; the *paint* claim — nothing draws the name as
  text — is the widget layer's own, `test/reading_view_picture_pass_test.dart`'s `find.text(name) findsNothing`).
- The prompt on the way there already shows the same cells: `w020_white.png\n0`, `Remove this picture`, … — T015's
  first half, seen on the device.

## Row 9 — one tap, and the badge answering that same tap (FR-003, FR-006, SC-002)

`6/6 checks passed`. One tap, then **one** dump with no second gesture between:

```
PASS 9: the tapped sentence's own picture carries 1 on that tap — cells after the tap:
      {'w020_white.png': '1', 'w020_black.png': '0', 'w020_red.png': '0'}
PASS 9: a tap on another picture assigns to **that** one — the selection is what a tap means —
      cells: {'w020_white.png': '1', 'w020_black.png': '1', 'w020_red.png': '0'}
```

- The count's own words are still absent from the strip after the tap.
- The selection itself is read **behaviourally** (the second tap lands on the picture the reader selected), because
  the dump's node dict for a cell carries no `selected` key — recorded rather than asserted away.
- The still: `/tmp/klhu_out/021_row9_after_one_tap.png`.

## Row 10 — a hold opens the picture large, and `Close` brings the list back (FR-004, FR-019, SC-003)

`8/8 checks passed`. While the hold is down, the page's own labels are:

```
['Back', 'Assign sentences', 'Done', 'w020_white.png\n0', 'w020_black.png\n0', 'w020_red.png\n0',
 'w020_black.png\n0', 'No sentences assigned', 'Move left', 'Move right', 'Close']
```

- The held picture is **below the strip** (its label appears a second time, after the strip's three) with the app's
  own words for its count under it (`No sentences assigned`) — FR-019's words land exactly where the reader asked.
- The sentence list is **hidden**: all ten sentence rows are gone while it is open, and `Close` brings back exactly
  the ten (`Line one is here.` … `Line ten ends it.`).
- The still: `/tmp/klhu_out/021_row10_large_picture.png`.

## Row 11 — the controls' gating (FR-005, SC-004)

`8/8 checks passed`. The reader's own run is one sentence on the first picture:

```
a picture holding a sentence of the reader's:  [..., 'w020_white.png\n1', '1 sentence', 'Close']        ← no move, no delete
a picture the reader gave nothing:             [..., 'w020_black.png\n0', 'No sentences assigned',
                                                'Move left', 'Move right', 'Delete this picture', 'Close']
```

- The rule is the reader's own of 2026-10-15 ("picture has sentences assigned cannot move and delete") and it is
  visible on the device: a picture holding a sentence offers neither control, and the count on its own cell is what
  says why.
- Still: `/tmp/klhu_out/021_row11_controls.png`.

## Row 12 — the move, and the renderer's own ranges following it (FR-006, SC-005)

`11/11 checks passed`. Two renders of the same content, one either side of one move:

```
the renderer's own line before the move: klhu render pictures=3 ranges=0..46,47..302,303..551 sentences=10
the cells' own x before the move:        {white: 319, black: 529, red: 739}
after tapping Move left on black:
the cells' own x after the move:         {white: 529, black: 319, red: 739}
the renderer's own line after the move:  klhu render pictures=3 ranges=-,0..46,47..551 sentences=10
```

- The thumbnails answer the move **at once** — the strip's own order is `[black, white, red]` in the same dump
  that follows the tap, and the cells' own `x` swap (319 ↔ 529).
- The renderer's own schedule **follows the new order**, and in exactly the way the rules predict: the picture now
  standing first is one the reader gave nothing, so no frame reaches it (`ranges=-`) and the tail the fallback
  splits lands entirely on the one after it (`47..551`) — against `47..302,303..551` before.
- Both renders are the same video's: `pictures=3` and `sentences=10` either side.
- Still: `/tmp/klhu_out/021_row12_after_move.png`.

## Row 13 — the delete asks first, and cancelling changes nothing (FR-008, FR-009, SC-006)

`12/12 checks passed`. The confirmation's own labels, verbatim:

```
['Delete this picture?', 'w020_black.png', 'This picture will be removed from this video.', 'Cancel', 'Delete', 'Dismiss']
```

- It **asks**, it names the picture by its own cell (a `w020_black.png` node, no file name painted anywhere), and
  `Cancel` leaves the strip's own order and the record exactly as they were.
- Confirmed, the picture is gone from the strip (`[w020_white.png, w020_red.png]`), the picture that held nothing
  took nothing with it (white still `1`), and the prompt's own line still reads `1 sentence`.
- The still of the question: `/tmp/klhu_out/021_row13_confirmation.png`.

## Row 14 — the selected cell, and where the strip can put it (FR-007, SC-007)

`6/6 checks passed`, **with the limit this fixture has recorded rather than faked**:

```
selecting white: the cells' own x = {white: 319, black: 529, red: 739}
selecting black: the cells' own x = {white: 319, black: 529, red: 739}
selecting red:   the cells' own x = {white: 319, black: 529, red: 739}
```

- What is proved: every cell of the fixture is on screen at once, and a selection scrolls nothing.
- What is **not** observable here: FR-007's own claim — the selected cell at the strip's *middle*. Three pictures
  at 72 + 8 spacing are 240 logical pixels, the strip fits the screen whole, so `ensureVisible(alignment: 0.5)` has
  nothing to scroll. Making it observable needs a fixture wider than the screen (about thirteen cells), whose
  selection through the platform's own file dialog needs scrolling in the Files app. The row says so in its own
  output and the tick repeats it; the unit half of the claim (the call is made on a selection, a move and a delete)
  is the page's own code, exercised by `test/reading_view_picture_pass_test.dart`.

## Row 15 — the prompt's own surface, and the switch across two pictures (FR-010, FR-011, FR-014, SC-008, SC-009)

`12/12 checks passed`:

```
the prompt's own cells:    ['w020_white.png\n0', 'w020_black.png\n0', 'w020_red.png\n0']
its remove asks first:     ['Delete this picture?', 'w020_white.png', 'This picture will be removed from this video.', 'Cancel', 'Delete', 'Dismiss']
cancelling takes nothing back: ['3 pictures chosen']
the proposal:              ['Give this sentence to the selected picture?', 'Line one is here.', 'w020_white.png\n1', 'w020_black.png\n0', 'Cancel', 'Move it', 'Dismiss']
cancelling:                cells {white: 1, black: 0, red: 0}
confirming:                cells {white: 0, black: 1, red: 0}
```

- The prompt draws the **same cells** the pass does, on the same one-node shape, and its own remove asks first.
- The switch is **proposed, not refused**: the sentence's own text, both pictures (the holder carrying `1`, the
  selected one carrying `0`), `Cancel` / `Move it` — cancelling leaves both counts identical and confirming moves
  exactly one sentence.
- Still of the proposal: `/tmp/klhu_out/021_row15_switch_proposal.png`.

## Row 17 — the answer carries the reader's runs, never the fallback (FR-016)

`8/8 checks passed`:

```
17: the record says 1 sentence, not the ten a render would paint — the labels mentioning sentences: ['Assign sentences\n1 sentence']
17: reopening shows the reader's own runs — the sentences no run names are on no picture — cells: {white: 1, black: 0, red: 0}
```

With one sentence given to the first picture and a render that would paint all ten, the record says **one** — the
render's own fallback is an outcome of the render, and this is the device's own view of the rule.

## Row 16 — the structural row (FR-015, FR-017, FR-018, SC-011)

Taken on the finished tree, 2026-10-15, against this file's own baseline (`782` passing, `55` test files, `120`
keys):

```
flutter analyze                   → No issues found! (ran in 0.9s)
flutter test --concurrency=2      → 01:22 +806: All tests passed!
test/*.dart                       → 57
keys per ARB (four files)         → 129 129 129 129        (120 + this feature's nine)
aggregate md5 of lib/l10n/app_localizations*.dart
    before `flutter gen-l10n`     → b4d762f1d00650942592c12127532e77
    after                         → b4d762f1d00650942592c12127532e77     ← the generator is idempotent
flutter test test/l10n_keys_test.dart → +3: All tests passed!
check_quickstart_coverage.py      → 19 FR + 11 SC · 18 rows (8 unit, 9 device, 1 structural)   ← 18 since Amendment 1's own row 18
git diff --stat lib/video_pictures.dart lib/video_timeline.dart → (empty: neither touched)
git diff --stat (the whole tree)  → 15 files changed, 995 insertions(+), 270 deletions(-)
```

- The suite's `782 → 806` decomposes by file and reconciles: `+10` `test/picture_assignment_switch_test.dart`,
  `+15` `test/reading_view_picture_pass_test.dart`, `+1` the prompt's own gating case in the assignment suite,
  `+2` the cases re-cut and extended in `test/reading_view_video_test.dart` and the assignment suite, `-2` the two
  drag cases this feature retires.
- The aggregate hash **moved with this feature's keys**: 020's own structural receipt quotes
  `98425bbdb8a43bd120c4e62711e002dc` for the same four files' generated Dart, and it is `b4d762f1…` now — the same
  statement about a different tree, not a contradiction. What the row asserts is that the generator is
  **idempotent**: the same value either side of a run.
- `lib/video_pictures.dart` and `lib/video_timeline.dart` are untouched, which is what FR-018's "no new dependency,
  no new stored key" rests on for the schedule's own rule.

## Row 16 re-taken — 2026-10-16 (what the amendments did to the receipt, and one correction)

```
flutter analyze                   → No issues found! (ran in 1.4s)
flutter test --concurrency=2      → 01:13 +808: All tests passed!
test/*.dart                       → 57          (55 at HEAD)
keys per ARB (four files)         → 129 129 129 129
git diff --stat lib/video_pictures.dart lib/video_timeline.dart → (empty, re-checked)
```

Both sides were measured the same way, so the difference reconciles **per file** rather than in aggregate: the
baseline side is a scratch copy of `HEAD` (`a7a650f`, the 020 tree), and both runs used `--reporter json`, whose
`testDone` events counted per suite give

```
base 782   →   now 808
  test/picture_assignment_switch_test.dart        0  →  10    +10   (new file)
  test/reading_view_picture_pass_test.dart        0  →  15    +15   (new file)
  test/reading_view_video_assignment_test.dart   18  →  19     +1   (net: the two drag cases retire inside it)
```

- **Corrected here too**: the 2026-10-15 block above reads `782 + 10 + 15 + 1 + 2 − 2 = 806`; its own terms sum to
  `808`, which is what the tree measures, and the retired drag cases are inside the assignment suite's net `+1`
  rather than a separate `−2` term. `806` and `807` were the totals of T032's and T033's own passes; `808` is the
  finished tree's.
- The assignment suite's `+1` net carries T015's gating case and both amendments' own cases (T033's `+18` and T034's
  `+19` are that file's total at those moments).
- Row 16's claims are unchanged: analyze clean, the generator idempotent, the locale keys at parity, the schedule's
  own files untouched.
- **The quickstart's own row count moved again — 19 rows, not 18 (2026-10-16, Amendment 3)**: this file's row 16
  block above quotes `18 rows (8 unit, 9 device, 1 structural)`, which was right when it was taken and is one row
  short now that Amendment 3's device row (the drop on a sentence-holder's cell, driver key `20`) is a row of the
  quickstart too. `check_quickstart_coverage.py` reads `19 rows (8 unit, 10 device, 1 structural)`; the row that
  makes it 19 is dated 2026-10-16.

## Row 19 — the assignment line with nothing picked (the reader's own report, amended in)

`8/8 checks passed`, on the reader's own steps: three pictures, one sentence, `Done`, `Cancel`, then the prompt again
without picking anything.

```
with the pictures picked:  ['Video format', …, '3 pictures chosen', 'w020_white.png\n1', 'Remove this picture',
                            'Choose more', 'Assign sentences\n1 sentence']
after Cancel, and opening it again:
                           ['Video format', …, 'No pictures chosen', 'Choose pictures',
                            'Assign sentences\nNo sentences assigned', 'Cancel', 'Start']
```

- The line says what is **in force** with the pictures there (`1 sentence`) and stops claiming it once they are not
  (`No sentences assigned`, beside the app's own `No pictures chosen`) — the reader's report was "no pictures. but
  has 8 sentences under Assign sentences. should be cleared", and the record itself stays **stored** (020's own rule
  re-attaches it by name when the same files are picked again), which is the half their report did not ask to lose.
- Still: `/tmp/klhu_out/021_row19_line_with_nothing_picked.png`.
- And the reader's own next step, with Amendment 2 in: **picking the same three files again brings nothing back** —
  the prompt reads `['3 pictures chosen', 'w020_white.png\n0', …]` and the pass's own cells are
  `{'w020_white.png': '0', 'w020_black.png': '0', 'w020_red.png': '0'}`. `11/11 checks passed` after the extension
  (still `/tmp/klhu_out/021_row19_repicked.png` for the re-picked state).
- This row's own first run scored 7/8 on a **check's** own wording, not the app's: the negative test
  `not on_screen(rows, "pictures chosen")` matched the app's own `No pictures chosen`. The check now asserts that
  label positively.

## Row 20 — a picture the reader gave nothing, dropped on the one that holds a sentence (Amendment 3, 2026-10-16)

The reader's own report: *"after assign sentence to some pictures, back to pictures chosen dialog, drag no sentence
picture to the position of picture with sentences failed. drag no sentence picture to position of other no sentence
picture works."* The same row was walked on the two builds either side of the fix — same steps, same fixture.

On the build of 2026-10-15 (`lastUpdateTime` 08:43:56, the tree before the fix) — **8/9**:

```
the cells once the pass answered Done:   {'w020_white.png': '1', 'w020_black.png': '0', 'w020_red.png': '0'}
the cells' own order, off the device's bounds:  ['w020_white.png', 'w020_black.png', 'w020_red.png']
hold the sentence-holder @(330,1173):    order unchanged            ← FR-005's own rule holds
hold w020_black.png @(540,1173) and drop it on w020_white.png @(330,1173):
   FAIL 20: the drop put the held picture where the sentence-holder stood — order:
   ['w020_white.png', 'w020_black.png', 'w020_red.png']             ← the reader's report, reproduced
```

On the fixed build (`lastUpdateTime` 09:24:14) — **9/9**:

```
PASS 20: the prompt's own cells carry the reader's counts — cells: {'w020_white.png': '1', 'w020_black.png': '0', 'w020_red.png': '0'}
PASS 20: before the move, the cells stand in the order the reader chose — ['w020_white.png', 'w020_black.png', 'w020_red.png']
PASS 20: a hold on the sentence-holder moves nothing (FR-005) — order: ['w020_white.png', 'w020_black.png', 'w020_red.png']
PASS 20: the drop put the held picture where the sentence-holder stood — order: ['w020_black.png', 'w020_white.png', 'w020_red.png']
PASS 20: and the sentence stayed with its own picture, by name (020 FR-010) — cells: {'w020_white.png': '1', 'w020_black.png': '0', 'w020_red.png': '0'}
```

- Stills: `/tmp/klhu_out/021_row20_before_the_drop.png` and `/tmp/klhu_out/021_row20_after_the_drop.png`.
- What the row asserts is the **order read off the device's own bounds**, never off a list the driver holds: 012's
  own rule is that the cells' order **is** the order the video draws the pictures in, so a move has to be read off
  the screen.
- The control it carries: a hold on the sentence-holder moves nothing, on **both** builds — the fix gives a
  sentence-holder's cell a **drop target**, never a hold of its own.

## What this walk cost, and what 020's own helpers still assume

- **Two of 020's own preconditions are stale under 021, and both were met on the first run of row 11** (it scored
  6/8 before this was seen): `assign()` asserts the chips read `No sentences assigned` where 021's cell carries the
  number alone (FR-019), and its closing check writes `1 sentences` where the app's own plural is `1 sentence`
  (020's own rows never assigned exactly one sentence). Neither is a defect of 021's behaviour, and neither is
  papered over: 021's driver carries its own `assign_own()` and says why. 020's module is left as it was written.
- A cell's own node dict has no `selected` key on this platform, so a row that needs "it is highlighted" reads the
  still or reads the selection behaviourally.
- **The stills first landed in the repository, and only a check found it**: `screencap(dest)` writes to `dest`
  exactly as given, and this driver passed a bare label (`021_row8_strip`), which the *relative* path resolved
  against the driver's own working directory — the repository root, four files of 75-130 KB. They are deleted, the
  driver now passes `os.path.join(OUT, "<label>.png")`, and all four rows were re-walked green afterwards
  (`5/5, 6/6, 8/8, 8/8`) with the stills where the tree's own rule says they live: `/tmp/klhu_out`, never in the
  repository. A row that names an artifact path is a claim about the filesystem, and this one was only true after
  it was checked.
