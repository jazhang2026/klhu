# 019 device walk — a `#`/`##` ladder, a marker neither painted nor spoken

The rows a unit test cannot hear or measure, on `emulator-5554` against a debug build of the working tree's head
(`019-head-tags`, 2026-10-13, `flutter build apk --debug` → `✓ Built … app-debug.apk`, 16.3 s, installed with
`adb install -r` → `Success`; `pidof com.example.klhu` → `5236`, `mCurrentFocus` → `…/MainActivity`).

The driver is `scripts/klhu_walk_head.py`, dispatched one row per run
(`/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py <row>`); its fixture is
`scripts/klhu_head_fixture.txt`. Mechanics are 016's (`klhu_walk_step.py`, which sits on 015's, 014's and 012's);
017's module is imported for the one thing only it has — driving the appearance control and measuring ink.
Artifacts land in `$KLHU_OUT` (default `/tmp/klhu_out`), never in the repository.


### The walk's state, row by row

| quickstart row | state | what it proves | evidence |
|---|---|---|---|
| 10 | **WALKED — PASS** (`14/14`) | FR-003, FR-004, FR-005, FR-007, SC-001, SC-006 | the page's own dump, `klhu speak`/`klhu read range`, five ink figures |
| 11 | **WALKED — PASS** (`12/12`) | FR-004, FR-011, SC-004 | the marked content against the `spaced` control, three presses each |
| 12 | **WALKED — PASS** (`66/66`) | FR-013, SC-003, SC-005, SC-006 | five renders' own lines, the pulled files, the frame boxes |
| 14 | **WALKED — PASS** (`7/7`) | FR-015, SC-007 | the comment's ink height against its sentence's, both faces |

No row of this walk is `NOT WALKED`, and none passed by a figure this file does not quote.

The fixture's sections are read by their **known keys** (`main`, `spaced`, `cjk`, `control`) rather than by a
leading `## `: this feature's own content carries `## Greetings` as a **subtitle**, and 015's splitter would read
that line as a section of its own. The `spaced` control is the marked `main` with `# ` and `## ` written as spaces
— two and three characters, the markers' own lengths, so every offset in the two texts coincides.

---

## Row 10 — the page paints the ladder and hands the engine no marker

`/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py 10` → `RESULT: PASS (14/14)`

    fixture 'main': 7 lines, 63 chars      fixture 'spaced': 7 lines, 63 chars
    fixture 'cjk': 3 lines, 16 chars       fixture 'control': 3 lines, 50 chars
    PASS the fixture carries its four sections — keys: ['cjk', 'control', 'main', 'spaced']
    PASS the spaced control is the marked main with the markers written out — 63 chars against 63

**What the page paints** (the dump's own text, `main` = `# Basic Spanish 1 / ## Greetings / Hola. Adiós. / [注] How
are you?`):

    painted: 'Basic Spanish 1\n\nGreetings\n\nHola. Adiós.\n\nHow are you?'
    PASS 10: the page paints the title's own words (FR-005)
    PASS 10: the subtitle is painted too, as its own words
    PASS 10: no marker is painted anywhere (FR-003)

**What reaches the engine** (one ▶ Read press, the app's own `klhu speak` and `klhu read range` lines):

    spoken: ['Basic Spanish 1']        ranges: [(0, 17)]
    PASS 10: nothing spoken carries a marker (FR-004)
    PASS 10: the title reached the engine as its own words (FR-004) — 'Basic Spanish 1' against 'Basic Spanish 1'
    PASS 10: the range is the step's own — 016's unit unmoved (FR-011) — the app read [(0, 17)], the step is (0, 17)

The range is the **paragraph's own** (0..17, marker included) while the words are the line's: the marker is elided
from the paint and from the utterance, and 016's step unit is what the app logs. Both hold at once, which is
FR-011's whole point.

**The ladder, at the five pairs the row names** (one capture each, 017's own ink measurement):

    small        10205 ink px → /tmp/019_row10_small.png
    medium       14245 ink px → /tmp/019_row10_medium.png
    large        20070 ink px → /tmp/019_row10_large.png
    xlarge       27210 ink px → /tmp/019_row10_xlarge.png
    bold_xlarge  33003 ink px → /tmp/019_row10_bold_xlarge.png
    PASS 10: the ink grows with the rung (SC-001) — ink per rung: [('small', 10205), ('medium', 14245),
         ('large', 20070), ('xlarge', 27210), ('bold_xlarge', 33003)]

Strictly increasing through the four offered sizes, and the bold face at `xlarge` adds ink on top of the largest
regular rung — the two derived rungs of the ladder (24 w700 and 24 w900, 019 FR-006) are what those last two
figures separate. The five PNGs are the row's artifacts; the ink figures are what a reader can check without them.

**Proves**: FR-003, FR-004, FR-005, FR-007, SC-001, SC-006 (FR-007's and SC-006's bold/black halves are the last
two captures' ordering; the exact sizes are unit-level, in `test/reading_view_head_test.dart`).

---

## Row 11 — ▶ and ⏭ through the marked content, against the spaced control

`/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py 11` → `RESULT: PASS (12/12)`

Two runs of the same walk — the marked `main`, then the `spaced` control — each seeded fresh, opened, and driven
with two ▶ presses and one ⏭. Both contents are 63 characters, so every offset in the two texts coincides.

    marked  ▶ 1: ranges=[(0, 17)]  spoken=['Basic Spanish 1']        highlight top=472, 33680 px
    marked  ▶ 2: ranges=[(19, 31)] spoken=['Greetings']              highlight top=732,  4256 px
    marked  ⏭:   ranges=[(33, 63)] spoken=['Hola.', 'Adiós.']
    spaced  ▶ 1: ranges=[(0, 17)]  spoken=[' Basic Spanish 1']       highlight top=472, 12720 px
    spaced  ▶ 2: ranges=[(19, 31)] spoken=[' Greetings']             highlight top=680,  4144 px
    spaced  ⏭:   ranges=[(33, 63)] spoken=['Hola.', 'Adiós.']

    PASS 11: a ▶ press reads one step, and the steps are the content's own (FR-011)
    PASS 11: no utterance carries a marker, in any press (FR-004)
    PASS 11: ⏭ read the rest of the content (SC-004)
    PASS 11: the same text with the markers written out reads the same ranges
    PASS 11: and the same words — the markers alone differ
    PASS 11: the highlight walked down the page, not backwards

**What the pair is for**: the two walks' ranges are equal at every press — `[(0, 17)], [(19, 31)], [(33, 63)]` —
so eliding a marker moves no boundary 016 or 011 sees, while the words differ by exactly the marker's characters
(`'Basic Spanish 1'` against `' Basic Spanish 1'`, `'Greetings'` against `' Greetings'`). The ⏭ press reads the
rest as one range and two utterances, the comment's own text still no step of its own.

**A figure worth reading twice**: the marked title's highlight box carries **33680** yellow pixels against the
control's **12720** — the same characters, the same four presses' geometry. That is the rung, live on the page: at
`Serif`/`medium` the marked line is painted at 24 where the spaced line is painted at the reader's own 14, and 017's
ink measurement picks the difference up without being asked to. It is row 10's ladder seen from the highlight's own
side.

**Proves**: FR-004, FR-011, SC-004.

---

## Row 14 — a bold body's comment, measured on the page (and 017's regular pair beside it)

`/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py 14` → `RESULT: PASS (7/7)`

017's own comparison fixture: the comment repeats its sentence's own word (`Hola.` / `[注] Hola.`), so the two
lines hold the same glyphs and their ink **heights** measure the size alone (017's row 10 records why the fixture
is built this way). The line heights come from `ink_lines` over the reading band, the same measurement 017 took.

    bold     small   22px comment against 22px sentence
    bold     medium  27px against 27px
    bold     large   35px against 35px
    bold     xlarge  46px against 46px
    regular  medium  22px against 27px
    regular  small   18px against 22px
    PASS 14/bold <size>: a bold body's comment is the sentence's own size (FR-015)               x4
    PASS 14/regular <size>: a regular body's comment is still smaller — 017's own measurement     x2
    PASS 14: the comment grows with the size in both faces (SC-007's floor)

**Read the two columns together**: under a **bold** body the comment's line is the sentence's own height at
**every** rung — 22, 27, 35, 46 — because FR-015 steps the weight down (`24 w700 -> 24 w400`) and leaves the size
where it was; under a **regular** body the same pair is 27/22 and 22/18, which is 017's shipped `24 -> 18` and
`14 -> 12` seen as ink. The two rules therefore coexist on one page, and which one applies is decided by the body's
own weight.

**What this owes 017**: this row is the measurement 017's row 11 needs and cannot take itself (that row sets no
appearance and runs on whatever the device holds — `specs/017-bold-comment-size/breakpoint.md`'s amendment section
records the reading). What it shows is that the amendment is real **only** for the bold body: the regular pair
beside it is 017's own rule, unchanged, on the same device and the same fixture.

**Proves**: FR-015, SC-007.

---

---

## Row 12 — the video's frames paint the marked line by the same rule

`/usr/bin/python3 -u specs/019-head-tags/scripts/klhu_walk_head.py 12` → **`RESULT: PASS (66/66)`**

Five renders, each seeded and launched fresh: the marked `main` content at `Serif`/`small`, `Serif`/`xlarge` and
`Serif bold`/`xlarge`, then its mixed slot, then the Chinese pair at `Default`/`medium` and `Bold`/`medium`. Every
render pulled its file back and its runs were the file's own frames (`222 of 222`, `129 of 129` on the Chinese
pair), and no frame had a band or ink outside the column.

    view    slot 0 text=15 span=2..17 frames=55/222  ink box=(206, 910, 598, 964)  w 392px  h 54px
    xlarge  slot 0 text=15 span=2..17 frames=55/222  ink box=(206, 888, 760, 964)  w 554px  h 76px
    bold xl slot 0 text=15 span=2..17 frames=55/222  ink box=(206, 888, 760, 964)  w 554px  h 76px
    mixed   slot 3 text=19 span=39..45
    cjk/def slot 0 text=9  span=2..7  frames=129/129  ink box=(206, 840, 562, 964)  w 356px  h 124px
    cjk/bold slot 0 text=9 span=2..7  frames=129/129  ink box=(206, 832, 562, 962)  w 356px  h 130px

**The title's own characters, marker excluded (FR-013)**: every appearance reports `text=15` for a slot whose
painted characters are `Basic Spanish 1` — the `#` and its space are in neither the block nor the count — and the
span the renderer reports is `2..17`, the words' own range in **content** offsets (FR-011: 016's units unmoved, the
same pair row 10 saw on the page). The Chinese pair says the same thing in a language with no word spaces:
`text=9` = the title's 5 characters + the newline + the comment's 3, the marker's 2 excluded, span `2..7`.

**The rung reaches the frame (FR-006)**: `small` 54px against `xlarge` 76px for the same characters at the same
aspect — the ladder's size carried onto the frame's own scale.

**And its ceiling, on a frame (SC-006)**: `bold`/`xlarge` and `Serif`/`xlarge` produce a **byte-identical** box —
554×76, the same rows `(206, 888, 760, 964)`. That is the ladder's end: at the top size a bold body's title rung
and a regular body's title rung are the same rung (`24 w900`), because `rungOf(24, w700) + 2` clamps to the last
rung exactly as `rungOf(24, w400) + 2` does. The check was written as "at least as wide" and the run answered with
equality; the record says which it was.

**The mixed slot (FR-013)**: slot 3 reports `text=19` = `Adiós.` (6) + the newline + `How are you?` (12) — the
sentence the comment rides is the paragraph's **second** sentence (015's own rule), and the tag's characters are in
neither part. Its span is `39..45`, the sentence's own.

**The Chinese pair**: both faces paint the same 9 characters and the same span; the boxes differ by the synthesised
weight alone (124px against 130px — the CJK face has no real bold on this device, 017's own measurement). That
difference is 017's claim and only quoted here.

**The driver's own finding, recorded because it cost two runs**: the **second** render of one run never reports
`klhu render done` (300 s, twice, at two different faces). Dismissing the finished render's review screen is not
enough; a clean `force-stop` + relaunch between renders is, and with it all five renders in this row pass. No other
row in this walk (015's and 017's drivers included) renders twice in one run, so this row is where the rule is
written down: **one render per launch**.

**Proves**: FR-013, SC-003, SC-005, SC-006.

## Rows this walk still owes


`klhu_walk_head.py`'s `main` names them rather than dispatching into a stub (014's convention).
