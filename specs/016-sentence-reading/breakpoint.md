# Device Walk: Sentence-by-sentence reading (016)

**Rows**: [quickstart.md](./quickstart.md) rows 5-11 | **Driver**: [scripts/klhu_walk_step.py](./scripts/klhu_walk_step.py)
| **Fixture**: [scripts/klhu_step_fixture.txt](./scripts/klhu_step_fixture.txt) | **Walked**: 2026-10-12, row by row

Every row below appends its own evidence as it is walked; a row that is not walked yet says so and why.

## Environment

| What | Value |
|---|---|
| Device | AVD `klhu`, `emulator-5554` (API 36). The toolbar's own `▶ Read` node sits at `y=2261` in the dump. |
| Package | `com.example.klhu` |
| Build | this tree, `flutter build apk --debug` (13.8 s) + `adb -s emulator-5554 install -r` → **Success** |
| Interpreter | **`/usr/bin/python3` (3.12)** — the driver's import chain pulls PIL in (012's frame reads), and this host's default `python3` has none (015's own note, line 16) |
| Import chain | `klhu_walk_step.py` → `specs/015-comment-tag/scripts/klhu_walk_comment.py` → 014's → 012's; plus 011's `klhu_walk_experience.py` for `screencap`/`yellow_rows` |
| Artifacts | `$KLHU_OUT` (default `/tmp`) — screenshots `016_row5_press{1,2,3}.png`, `016_row5_end.png` |

```
$ export PATH=$HOME/Android/Sdk/platform-tools:$PATH
$ ADB_SERIAL=emulator-5554 /usr/bin/python3 -u klhu_walk_step.py 5
$ ADB_SERIAL=emulator-5554 /usr/bin/python3 -u klhu_walk_step.py 6
```

## Row 5 — the stepper: three presses, then a fourth that is silent — WALKED, **PASS (13/13)**

The fixture's `main` is 011 row 23's own shape — a title with no full stop over a punctuated paragraph
(`A quiet morning\n\nThe sun rose over the quiet town. Birds sang in the tall trees.`, 80 characters, three
steps) — and the pressure of this row is that a step is a *sentence*, never a line:

```
press 1: klhu read range: 0..15    klhu speak "A quiet morning"            highlight top row 472, 12000 px
press 2: klhu read range: 17..50   klhu speak "The sun rose over the qu..." highlight top row 576, 24608 px
press 3: klhu read range: 51..80   klhu speak "Birds sang in the tall t..." highlight top row 576, 18880 px
after press 3 (its read finished): 0 yellow px, and the page paints no message at all
press 4: klhu read range: 0..15    klhu speak "A quiet morning"            ← FR-001's fresh start
```

Each press read exactly one step's own range, exactly one utterance reached the engine, and the step being
read was painted (`yellow_rows` over the screenshot) — the title's band above the paragraph's, and the
paragraph's two sentences on the same line, which is why the third press's band top repeats at 576.
**The text's end is silent and automatic**: the *third* press is the one that ends it (the advance finds no
next step and clears), and the press after that is an ordinary fresh start — the end is not a mode.
Proves SC-001, SC-002, FR-001, FR-004, FR-008, FR-012.

## Row 6 — a step is the sentence plus its comment — WALKED, **PASS (6/6)**

```
fixture `comment` = "Hola.\n\n[注] How are you?\n\nAdiós."
  press 1: klhu read range: 0..23    klhu speak "Hola."  then  "How are you?" (comment=1)
  press 2: klhu read range: 25..31   klhu speak "Adiós."          ← the sentence AFTER the comment, at 25
fixture `inline_comment` = "Hola. Adiós. [注] Fine."
  press 1: klhu speak "Hola." alone  ← the comment belongs to the sentence before it, not to this press
  press 2: klhu read range for "Adiós."  klhu speak "Adiós." then "Fine." (comment=1) ← rides its owner
```

The first press's range (`0..23`) is the whole **step** — the sentence plus its comment's own span, which is
what makes the resolution speak it; the second press's range starts at the sentence (`25`), never inside the
comment's characters, which is the search key the plan's §5 risk 2 names. Proves FR-005, SC-004.

## Row 7 — ⏭ after a step reads only the sentences the steps have not — WALKED, **PASS (2/2)**

```
step 1: klhu read range: 0..15    klhu speak "A quiet morning"
step 2: klhu read range: 17..50   klhu speak "The sun rose over the qu..."
⏭     : klhu read range: 51..80   klhu speak "Birds sang in the tall t..."   ← one utterance, the third step
```

The two steps put the highlight on the paragraph's second sentence, and ⏭ read from **it** — `51..80`, never from
0 — and repeated nothing already heard. Proves SC-003, FR-007's in-session half.

## Row 8 — the clean relaunch: nothing comes back, and nothing was stored — WALKED, **PASS (6/6)**

```
after a step:  read_position_step_main = None                      ← nothing was written at all
force-stop + relaunch: 0 yellow px                                  ← no highlight comes back
⏭ after the relaunch:  klhu read range: 0..80, 3 utterances          ← from the first sentence (010 FR-005)
after a TAP:   tap the text @550,545 → 24608 yellow px (its place IS in force)
               read_position_step_main = None; any read_position key anywhere: False
force-stop + relaunch: 0 yellow px                                   ← nothing comes back after a tap either
```

This is the row that proves decision 5 on the device: the *tap* still puts a place in force — it is painted, and
⏭ would read from it — while the app's whole store holds **no `read_position` key at all**, so a relaunch is a
clean page for a step and for a tap alike. Proves FR-007, decision 5, SC-005's retirement half.

## Row 10 — 011's own receipts, re-walked — WALKED, **PASS (4 rows)**, two of them after a dated two-check re-cut

Four runs of `specs/011-reading-experience/scripts/klhu_walk_experience.py` against this build:

| 011's row | What the run said |
|---|---|
| 7 — the page follows a long read, sentence by sentence | **RESULT: PASS** |
| 10 — Stop mid-read leaves the page where it stopped | **RESULT: PASS** |
| 8 — a stored position that is off screen is revealed first | **passed only after the two-check re-cut below** — its first run crashed on `stored_offset()` *after* its behaviour had been shown: `tap painted (640, 792) device px`, `after the swipe: no yellow on screen`, `first report: p0 s0 visible=1 top=0 bottom=62 viewport=196` |
| 20 — no highlight means no read; the page's gesture picks the unit | **passed only after the two-check re-cut below** — its first run failed on `the tap set no position` (a `read_position_*` read) and, once that was in-session, on two of its own checks that assumed a press leaves nothing in force |

**The two-check re-cut, 2026-10-12** (011's driver, its own row's rule kept and its witness moved):

- `stored_offset()` → the app's own live lines. Row 8 asserts now that ⏭ runs from a **non-zero** sentence start
  (`112..334` in the run) with its first report inside the reading area (`yellow=(284, 452)`, area `284..798`);
  row 20 takes the tapped offset from ▶'s own first range, and the paragraph's span from **that**.
- Row 20's two state assumptions were re-cut as well, and both because 016 changed the state, not the rule: after
  a step the highlight **advances** (016 FR-004), so `⏭` runs from `160..334` where the row expected the fixed
  point's own `112`; and "nothing in force" is now reached by **Stop** (016 FR-009) rather than by a press that
  left nothing — with Stop pressed, `⏭` reads `0..334` ✓.
- Its last block asserted the **old** FR-023 (`▶` with nothing highlighted speaks nothing and asks for a
  selection): the run shows `▶ after the read : ranges=[(0, 33)] prompt=MISSING` — 016 FR-001 on the device. The
  check is inverted to that rule, and 011's spec (FR-023) and breakpoint (row 20) carry the dated amendment.

**011's rows 7, 8, 10 and 20 all PASS on this build.** Proves SC-005.

## Row 11 — 010's own receipts, re-walked — WALKED, **PASS (3 rows)**

```
row 13: klhu read range: 286..334   start is a sentence start inside the third paragraph: True
        persisted record: []        ← the record the row prints: empty, which is now the truth
row 15: klhu read range: 0..334     full-page read: start == 0 and end == text length: True   (8 utterances)
row 16: pause mid-paragraph · resume: ['p0 s1', 'p1 s0', 'p1 s1', 'p1 s2', 'p2 s0', 'p2 s1', 'p2 s2']
        7 utterances for 7 sentences left, 7 engine requests — the interrupted sentence repeated once
```

No re-cut was needed: 010's driver **prints** the record (`persisted record: []`), it does not assert on it, and
the three rows' own rules (a tap's range, the no-position fallback, the pause/resume sentence) all hold. Rows 9
and 14 are **not** re-run: they asserted the record's survival, 010's FR-008 is withdrawn with its date, and their
replacement is this feature's own row 8 (`breakpoint.md` § Row 8). Proves SC-005, FR-007, FR-009.

## Not walked yet, and why

| Row | State | Why |
|---|---|---|
| 9 — a render from a step's position | **NOT WALKED** | the driver implements rows 5-8; this row needs 012's render machinery (open the review, render, read the file's own `klhu render slot=…` line) |
| 11 — 010's rows 13/15/16 re-walked | **NOT WALKED** | runs 010's own driver against this build |

## Deviations

1. **The row-5 text was wrong about WHICH press is silent, and the run corrected it (2026-10-12).** The row
   said the fourth press reads nothing. It is the **third**: when the last sentence's own read finishes, the
   advance finds no next step and clears the highlight (FR-004 + FR-008), so the end is silent and automatic,
   and a further press is FR-001's fresh start. `quickstart.md` row 5 and `tasks.md` T024 were re-cut in the
   same pass; the widget case ("the highlight sits on the NEXT sentence, and is gone at the end") asserts the
   same reading, and the two now agree. **The app was right in both.**
2. **A driver fix, not a device finding: `tap_any` tapped the app bar.** A bare exact-'Read' search matched a
   node at `y=209` on the second press; the press now requires the toolbar's own band (`below=1800`), which is
   where the button is (`y=2261`).
3. **A driver fix, not a device finding: the log window is cleared per press.** The first run of row 6 read
   press 1's late comment line as press 2's second utterance (`['How are you?', 'Adiós.']`); `adb logcat -c`
   before each press and waiting for the press's own utterance count removed it — with the same fixture, press
   2 is `['Adiós.']` alone.
4. **The app's `klhu speak` line elides a long utterance.** `lib/reader_service.dart`'s `_logPrefix` collapses
   whitespace and keeps 24 characters with `...` — the driver compares in that form (`logged_text`), and the
   elision is why the title prints whole and the sentences do not.
5. **A stale comment in 014's driver, left as it is.** `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py`'s
   `read_from_top` docstring still describes `朗读` as refusing with `请先选择要朗读的句子或段落` when nothing is
   highlighted — the very message 016 removes (FR-013). It is a driver comment, not an artifact claim; this
   note is so a reader of that file is not misled, and a later pass that walks 014's rows again can fix the
   sentence in place.

## Row 15 — ▶ with the page away from the top (the reader's own report of 2026-10-16)

`3/3` on the fixed build, `2/3` on the one before it — the same row, the same steps, two builds:

```
fixture: this feature's own paragraph twelve times, X-Large, nothing highlighted,
         the reading area swiped so the first sentence is off screen

control ⏭ Continue Read   ranges=[(0, 779)]   frames (top, yellow px): [(None, 0), (472, 64400), (472, 64400)]
══════════════════════════ 2026-10-16, build 09:24 (before the fix) ═══════════════════════════
▶ Read                    ranges=[(0, 33)]    frames (top, yellow px): [(None, 0), (None, 0), (None, 0)]
   FAIL 15: and it was painted on screen while it was spoken — the page had brought it into view
             before speaking it (FR-012) — no frame of the press shows the highlight
══════════════════════════ 2026-10-16, build 11:01 (after the fix) ════════════════════════════
▶ Read                    ranges=[(0, 33)]    frames (top, yellow px): [(None, 0), (472, 64400), (472, 64400)]
   PASS 15: and it was painted on screen while it was spoken
```

- What the row asserts is the page's own **paint** (`yellow_rows`): the dump can show neither the scroll offset nor
  the highlight, which is why 011's own reading of a frame is the check here. The first frame of each press is blank
  on both builds — the reveal is animated (200 ms) and the frame is taken as the utterance starts — so the rule is
  read as "at least one frame of the press's own read shows the highlight", which is what "visible while it is
  spoken" means.
- Both presses read the same range, so the difference is the page's own state and not which unit was read: `0..33` is
  the content's first step in both.
- The frames are `/tmp/klhu_out/016_row15_{continue,read}_<n>.png` — `/tmp`, so they are lost to the next reboot
  (the 021 walk's own note of that morning is the same fact).

## Row 15 re-run — 2026-10-16, on the build that carries 022's rule (T015 of `specs/022-read-scroll-lead`)

The reveal this row proves is the reveal 022 extends (`_revealRange` now hands the reveal a rect that covers the unit
**and** a sentence after it), so the row was re-run on the first build carrying it (`lastUpdateTime=2026-10-16
11:42:31`) — **3/3**, the same figures as the day before:

```
⏭ Continue Read   ranges=[(0, 779)]   frames (top, yellow px): [(None, 0), (472, 64400), (472, 64400)]
▶ Read            ranges=[(0, 33)]    frames (top, yellow px): [(None, 0), (472, 64400), (472, 64400)]
RESULT: PASS (3/3)
```

- **Its first run of the day FAILED, and the reason was another row's own hygiene, not this one's**: 022's row 24 had
  left the display shrunk to 1080×1000, so this row — which is written for a 1080×2400 screen — tapped coordinates that
  no longer held the toolbar and failed `15: ▶ Read is on the page`. 022's row 24 now resets the display, and the row
  above is the re-run after the reset. Recorded here because a later reader of *this* row's history would otherwise see a
  failure with no cause attached.

## What this walk still owes

**2026-10-16: nothing at this moment — the paragraph above is the state of 2026-10-12, left as written.** Row 9 was
walked and `tasks.md`'s Phase 7 closed (T032-T034) long before this note; the row added since is row 15 above.

## Row 9 re-run, 2026-10-16 — red, and **not** 022's (its own sweep's control run)

022's regression sweep re-ran this file's device rows 5, 6, 7, 8, 9 and 15 on the build carrying its rule:
**5 (13/13), 6 (6/6), 7 (2/2), 8 (6/6) and 15 (3/3) pass**; row 9 does not — `RESULT: FAIL (8/11)`:

```
PASS 9: the press read the first step and left the SENTENCE AFTER it in force — the press read [(0, 15)] …, the position in force is (17, 50)
…
FAIL 9: the render STARTS at the step's own sentence (the unwalked path) — slot 0's span starts at 0, the step is at 17
FAIL 9: and that slot's span is the step's own sentence — span 0..15 against (17, 50)
FAIL 9: the text it paints is the sentence's own characters (no tag, no padding) — text=15 for the sentence's 33
```

**Control, made on 2026-10-16**: the same tree with 022's lead disabled (`_leadRect` returning `null`), built and
installed, then row 9 again — the **same three failures**, `RESULT: FAIL (8/11)`. So the red is inside the render's own
slot spans (012's path — the file's own subject: the render starting at the step's position), not 022's scrolling, and
not caused by anything 022 changed: 022 touches neither the slots, the render, nor the video. Carried as its own work in
`specs/022-read-scroll-lead/tasks.md` (`T024`); worth walking again when the render's start-at-the-step path is next
touched.

### Row 9 re-cut the same evening — the app was right, the row was stale

The row's three failing checks asked the render to **start** at the page's non-zero position — 012's `FR-004`. **020's
`FR-017` superseded that half** on 2026-10-14 (a video is the whole content, and the page's position "MUST NOT move a
video's start"), and the app has rendered from the content's first sentence since; the row was simply never re-cut, which
is why it read `FAIL (8/11)` for as long as it did. **No app change was needed or made.**

What the row pins now is the rule in force **and** the supersession itself — the press still leaves a non-zero position
in force, and the render's first slot is the content's own first sentence all the same:

```
PASS 9: the press read the first step and left the SENTENCE AFTER it in force — … the position in force is (17, 50)
the file's first slot: span=0..15 text=15 frames=48
PASS 9: the render opens on the content's own first sentence, whatever the page's position is (020 FR-017, which superseded 012 FR-004's other half)
PASS 9: and that slot's span is that first sentence
PASS 9: the text it paints is that sentence's own characters (no tag, no padding)
RESULT: PASS (11/11)
```

This is the second row this evening that was red for a reason **older than the sweep that found it** (the other is 011's
row 23): both were left behind by a documented amendment to another feature, and neither was anybody's app defect.
