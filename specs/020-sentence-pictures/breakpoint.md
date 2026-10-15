# 020-sentence-pictures — the device walk's record

One entry per quickstart row, appended by the pass that walks it. The driver is
`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` (its `PARTS`/`ROWS`
key is the **quickstart's own row number**, so a row and its command are one
value), the device is `emulator-5554` (`klhu`), the package `com.example.klhu`,
and the evidence is the app's own lines plus the frames it wrote.

Rows owed as of 2026-10-14: 7, 8, 9, 10, 11, 12, 13, 16 — `main` names them, and
each is appended here in its own pass.

---

## Row 6 — the assignment line, the pass and the render's own ranges (T021)

*Walked 2026-10-14 15:12 PDT on the tree of that date (`git` working tree, the
debug APK built and installed 15:0x), row 6 of `quickstart.md`, driver
`klhu_walk_assignment.py 6`.*

**Setup**: the row's own content (ten sentences, `walk 020 ten sentences`, seeded
into the library through `run-as` — 012's `s2_seed` pattern) and three pictures
this driver writes itself (white / black / red, pushed to
`/sdcard/Pictures/klhu_walk_020`), chosen through the platform's own file dialog.

**What the reader did**: open the video prompt, choose 16:9 landscape, pick the
three pictures, open the assignment pass, give **4 / 3 / 3** sentences to the
three pictures in `w020_white / w020_black / w020_red` order, and start the
render.

**The app's own line** (logcat, verbatim):

```
10-14 15:12:41.786 I/flutter (15166): klhu render pictures=3 ranges=0..197,198..340,341..529 sentences=10
```

**What that is**: the schedule's own account of the render — three pictures in
the reader's own order, the three ranges meeting at sentence boundaries
(`197 + 1 = 198`, `340 + 1 = 341`), the whole ten sentences spoken. Read against
the pass's own chips before Start (`w020_white.png 4 sentences`,
`w020_black.png 3 sentences`, `w020_red.png 3 sentences`), the ranges are the
reader's runs.

**The frames themselves** (the video pulled out of the app's private storage and
sampled three times, each inside one range, reading a pixel **outside** the text
column — where only the picture can be):

| frame | inside | the frame's own off-column pixel | the picture |
|---|---|---|---|
| 20 | `0..197` | `(255, 255, 255)` | `w020_white.png` |
| 218 | `198..340` | `(0, 0, 0)` | `w020_black.png` |
| 361 | `341..529` | `(219, 29, 30)` | `w020_red.png` (220, 30, 30) |

Each sentence's own picture is therefore on the page and in the file; no frame
sampled carries a picture other than the one its range belongs to.

**Checks**: `13/13 checks passed` (exit 0). Proves FR-001, FR-002, FR-006, SC-001.

**Left for the reader** (stills, on this box):

- `/tmp/020_row6_pass_open.png` — the pass, open, on the render's own sentences
- `/tmp/020_row6_assigned.png` — the pass after 4/3/3, the three counts on the chips
- `/tmp/020_row6_review.png` — the review after the render
- `/tmp/klhu_out/row6.mp4` — the file itself
- `/tmp/klhu_out/row6_w020_*_frame*.png` — the three sampled frames

**Two things this row's own runs taught the driver** (both are its own bugs, both
fixed in the file above, and neither is an app fault):

- a finished render's file lives in the app's **private** storage, so it comes
  back through `run-as` (`012`'s `pull`) — an `adb pull` of that path reads
  nothing, and the first run's three frame checks read `None` for exactly that
  reason.
- `uiautomator dump` **refuses to write while a window is animating** ("could not
  get idle state") and 012's `dump` then pulls the *previous* XML: row 6's third
  run read the prompt's line as `No sentences assigned` right after an assignment
  the render itself proves was in force. The driver deletes the device's own XML
  before every dump (`fresh_dump`) and polls the prompt's line to a deadline
  (`dump_until`), so a refused dump is a missing file — and `dump`'s own retries
  do their job — instead of a stale screen read as the app's answer.

---

## Row 7 — the two refusals, and the runs they did not move (T022)

*Walked 2026-10-14 16:14 PDT, driver `klhu_walk_assignment.py 7`, the same device,
package and fixture as row 6 (the row's content re-seeded; the app's own settings
are cleared first, so a row starts from a known state).*

**The reader's own assignment**: white takes the first two sentences through the
pass, and the prompt's own line reads `Assign sentences\n2 sentences`. The first
render's own line is the schedule for those two — the tail past white's run falls
to the pictures after it, which is FR-006's fallback and not a run of the reader's:

```
10-14 16:14:05.599 I/flutter (26701): klhu render pictures=3 ranges=0..98,99..302,303..551 sentences=10
```

**Refusal 1 — not continuous (FR-003).** With white holding sentences 1-2, a tap on
the **fifth** sentence is refused, and the pass says which rule, verbatim:

```
Only the sentences next to the ones this picture already has can be added.
```

**Refusal 2 — not in order (FR-004).** With black selected, a tap on the **first**
sentence — before white's own last one — is refused, verbatim:

```
That sentence comes before sentences an earlier picture already has.
```

Each refusal is the **only rule named** on screen (FR-012's "each refusal is told"),
and nothing moved under either: the three chips read `2 sentences` /
`No sentences assigned` / `No sentences assigned` before **and** after, and the pass
still paints `Line one is here.` and `Line two says this.` as white's.

**The assignment in force, read off the render itself**: the render was started
again after the two refusals, and its own line is **the same line** — the row's own
check compares the two payloads (each line after its logcat prefix) and passes, so
the line quoted above is both of them. That is the row's own comparison, and the
reading that a refused edit changes nothing the render sees.

**Checks**: `15/15 checks passed` (exit 0). Proves FR-003, FR-004, FR-012, SC-002.

**Left for the reader**: `/tmp/020_row7_assigned.png`,
`/tmp/020_row7_refused_continuous.png`, `/tmp/020_row7_refused_order.png`,
`/tmp/020_row7_review.png`.

**What this row's runs taught the driver** (its own bugs, fixed in the file):

- **Rows are not isolated.** The assignment row 6 left stored is still in force for
  the same content id, and row 7's first run read `8 sentences` — its own two taps
  had *taken two sentences away* from row 6's four. `seed_content` now clears the
  app's settings first (which carries 020's own `content_picture_assignments`) and
  `assign` refuses to run unless the pass opens with three empty pictures.
- **The review arrives with a transition.** A tap at coordinates read while it is
  still moving misses; row 7's second run never found the page's own toolbar behind
  it. `dismiss_review` waits for the Discard row's coordinates to stop changing.

---

## Row 8 — un-assigning at the ends, refused in the middle, and the picture freed (T023)

*Walked 2026-10-14 16:22 PDT, driver `klhu_walk_assignment.py 8`, same device,
package and fixture; the app's settings cleared first, so the pass opened empty.*

**The reader's own run**: white takes the first three sentences; the prompt's own
line reads `Assign sentences\n3 sentences`, and the pass is opened again on that
run (its own chips read `3 sentences` / `No sentences assigned` / `No sentences
assigned` — FR-010 read through the page).

**A picture holding sentences refuses the hold** (FR-015), with its reason, verbatim:

```
This picture holds sentences; un-assign them before moving it.
```

and nothing moved under the refusal — the chips read the same three lines before
and after.

**The middle of the run refuses to go** (FR-016), with its own reason, verbatim:

```
Only the first or last sentence of a picture can be removed.
```

and the run is untouched by it: the page still paints all three of
`Line one is here.` / `Line two says this.` / `Line three is next.` as white's, and
the chip still reads `3 sentences`.

**The ends go, one at a time, and what is left is one run**:

| the reader taps | the page paints as held | the chip |
|---|---|---|
| `Line one is here.` (an end) | `Line two says this.`, `Line three is next.` | `2 sentences` |
| `Line three is next.` (the other end) | `Line two says this.` | `1 sentence` |
| `Line two says this.` (the last) | — | `No sentences assigned` |

**And the freed picture is no longer refused**: with nothing held, the same hold on
it shows no refusal at all (an earlier refusal's SnackBar lives about four seconds,
so the check waits it out first) — the picture is free to move, and the move itself
is row 9's own evidence.

**Checks**: `14/14 checks passed` (exit 0). Proves FR-016, SC-010 (the refusal half;
the drag itself is row 9).

**Left for the reader**: `/tmp/020_row8_three.png`,
`/tmp/020_row8_refused_holds.png`, `/tmp/020_row8_refused_middle.png`,
`/tmp/020_row8_freed.png`.

**What this row's runs taught the driver**: `assign` ends by confirming the pass,
which **closes** it — row 8's first run then tried to hold a chip *on the video
prompt* and read as nothing found. The pass is re-opened for the reader's own edits
(and, with `hold`/`tap_chip`/`tap_row` now recording a check when they cannot find
their target, a missing label can never again shorten a row silently).

---

## Row 10 — the skipped picture, and the tail that falls to the ones after it (T025)

*Walked 2026-10-14 16:5x PDT, driver `klhu_walk_assignment.py 10`, same device and
fixture (settings cleared first).*

**State 1 — a gap between two runs, and a picture left with nothing.** White takes
sentences 1-3 and red sentences 7-9, so sentences 4-6 are named by no run and the
picture between them is left empty. The renderer's own line:

```
klhu render pictures=3 ranges=0..302,-,303..551 sentences=10
```

- the middle picture is **in no frame**: its entry is the `-` the renderer prints
  for a picture nothing reaches (`isDrawn == false`, `frames == 0`, D5);

- and the unassigned sentences **kept the picture before them** (FR-006): white's
  range runs to frame **302**, which is the frame before sentence 7's own start
  (**303**) — so sentences 4-6 are white's, not the empty picture's;
- red runs to frame **551**, the video's own last frame (`total=552`), which is
  012's rule for the picture holding the last sentence.

**State 2 — the tail left unassigned, with pictures after it.** Red's run is taken
back through the pass (3 taps, the page's own gesture), so the last eight sentences
are unassigned with two pictures after the last run. The renderer's own line:

```
klhu render pictures=3 ranges=0..150,151..351,352..551 sentences=10
```

- white still holds its own run: `0..150`, ending at the frame before sentence 4's
  own start (**151**);

- the tail falls to the two pictures after it, **split the way 012 splits** (FR-006,
  012's own even split): the seven sentences go 4 + 3, so black's range is
  **151..351** — exactly sentences 4-7, which end at the frame before sentence 8's
  own start (**352**) — and red's is **352..551**.

The sentence boundaries in both states are read from the renderer's **slot lines**
through 012's own parser, not guessed: each slot's `frame=` paired with its
`span=`, in content order.

**Checks**: `14/14 checks passed` (exit 0). Proves FR-006, FR-007, SC-004.

**Left for the reader**: `/tmp/020_row10_skip.png`, `/tmp/020_row10_tail.png`.

**What this row's runs taught the driver**: a picture left empty is only *skipped*
when it sits **between** two runs — a picture after the last run is fed by the
fallback and drawn (row 9's first run assigned the last picture nothing and the
render painted it anyway). A row that needs a gap says which sentences it wants
(`assign_indices`: white 0-2 and red 6-8) rather than filling in order.

---

## Row 9 — the drag, and the order the render walks (T024)

*Walked 2026-10-14 16:57 PDT, driver `klhu_walk_assignment.py 9`, same device and
fixture (settings cleared first).*

**The reader's own assignment**: white takes sentences 1-3 and red 4-6, so the
picture **between** the two runs holds nothing — the only kind of picture that can
be dragged (one after the last run is fed by FR-006's fallback and holds sentences
in effect; row 9's first attempt assigned the *last* picture nothing and the render
painted it). The first render's own line:

```
10-14 16:56:13.939 I/flutter ( 4273): klhu render pictures=3 ranges=0..150,-,151..551 sentences=10
```

— the middle picture is the `-` of D5, exactly where the reader left it.

**The refusal** (FR-015): holding a picture that holds sentences says so, verbatim,
while the finger is down —

```
This picture holds sentences; un-assign them before moving it.
```

— and the order stands under it (`white, black, red`).

**The drag**: the free picture is dragged from the middle to the front. The pass
shows the new order, and the render's own line follows it, byte for byte:

```
10-14 16:57:38.978 I/flutter ( 4273): klhu render pictures=3 ranges=-,0..150,151..551 sentences=10
```

**What that is**: the same three ranges as before — `0..150` and `151..551` — in the
same order, with the `-` one place along. That is SC-009 read off the app's own
schedule: **the move changed the walk's order and no other range moved**.

**Checks**: `14/14 checks passed` (exit 0). Proves FR-015, SC-009.

**Left for the reader**: `/tmp/020_row9_assigned.png`, `/tmp/020_row9_refused.png`,
`/tmp/020_row9_moved.png`, `/tmp/020_row9_review.png`.

**How the gesture is injected, and what it cost**: `input draganddrop` does **not**
produce a Flutter long-press drag on this device (probed: the order stood and no
refusal appeared). What does — and what the driver uses — is the gesture by hand:
`input motionevent DOWN`, a real 1.6s hold, MOVEs in four steps to the target, `UP`.
A refusal is read **while the finger is still down**: it is a SnackBar (about four
seconds) and a whole gesture takes as long again, so a row that reads afterwards
misses the line it is checking (that is exactly how row 9's second run lost its
refusal check).

---

## Row 11 — the stale warning, before the render (T026)

*Walked 2026-10-14 17:06 PDT, driver `klhu_walk_assignment.py 11`, same device and
fixture (settings cleared first).*

**The reader's own assignment**: the first picture takes the first three sentences
(the prompt's own line reads `Assign sentences\n3 sentences`). Then the **content is
rewritten under it** — the same content id, its first sentence replaced by another
of a different length (`Something else entirely is here.`) — so the stored run's
spans match no sentence of the text in force. That is FR-014's own shape, and the
walk does it the way a reader would: it writes the content's own file and
force-stops the app, so what it reads next is the file.

**The reader comes back, picks the same three files, and presses Start.** The
warning is on screen, in the app's own words, verbatim:

```
1 assigned run no longer fits this text
w020_white.png: sentences 3
```

with the prompt's own two answers beside it (`Assign sentences` / `Start`), and
**no render has begun**: the app's own schedule line is not in the log yet — read
while the warning was up, which is the row's own claim of order (SC-008).

**The telling is the gesture**: the line that names the picture
(`w020_white.png: sentences 3`) was tapped, and the assignment pass opened on it —
with the stale run **not** in force (all three chips read `No sentences assigned`,
which is `runsThatFit` at work: the pass is handed the runs that still fit).

**"With that picture in view" read off the reader's own next tap**: a chip's
selection is not in the uiautomator dump, so the row gives **one sentence** through
the page instead — and it lands on the picture the warning named
(`1 sentence` on `w020_white.png`, the other two still `No sentences assigned`).
The pass did not merely open; it opened on the offending picture.

**Checks**: `12/12 checks passed` (exit 0). Proves FR-014, SC-008.

**Left for the reader**: `/tmp/020_row11_warning.png`, `/tmp/020_row11_pass.png`,
`/tmp/020_row11_fixed.png`.

**What this row's runs taught the driver**: after the content is rewritten, the
reader's page carries the **new** text — row 11's first run tapped the seeded
text's first sentence and found nothing on screen. `sentences(text)` takes the text
in force, and the row reads its taps from that.

---

## T032 — 012's own row 49, re-walked on this tree (020 moves the dialog, so it is re-read)

*Walked 2026-10-14 17:1x PDT: `KLHU_OUT=/tmp/klhu_out /usr/bin/python3 -u
specs/012-reading-video/scripts/klhu_walk_video.py 49` — 012's own driver, its own
fixture (the pre-set and its nine pictures), on the tree that carries 020.*

**40/41 checks passed.** The one check that moved is this feature's own doing, and
it is named here rather than re-cut in 012's file:

```
49: a choice one over the count is said nothing about — no label mentions the video's sentences
```

012's check is `not any("sentence" in label for label in rows)`, written to prove
that the prompt says nothing about a choice that is one over the count. 020 adds a
line to that prompt — the assignment line, whose own words contain "sentence"
(`Assign sentences` / `N sentences` / `No sentences assigned`) — so the check now
finds a label it was not written to allow. **The count is still said nothing
about**, which is what the row means; the assertion's own filter is what tripped.
Recorded as a pointer in 012's `tasks.md` (`## Superseded by later specs`), with
012's artifacts otherwise left as written (T032's own instruction).

**Its figures, and what they settle**: the same render 020's row 12 makes with
nothing assigned.

| | 012's row 49, today | 020's row 12, no assignment |
|---|---|---|
| the schedule line | (its own checks read the frames) | `pictures=9 ranges=0..76,77..146,147..237,238..347,348..428,429..494,495..609,610..742,- sentences=8` |
| frames | **743** | **743** |
| duration | **24766 ms** | 24.894 s (ffprobe) |

That is SC-003 read on the device: with no assignment the file is 012's own — the
same frame count, the same ranges, the ninth picture in no range.

**And 012's row 31's own numbers no longer reproduce** — it recorded **818 frames /
27.39 s** for the same pre-set on 2026-10-07, and neither 012's row 49 nor 020's row
12 reaches that today (743 frames / 24.77-24.89 s). The difference is in the
**synthesis' own durations** (a TTS voice's speed is the device's, not the app's)
and not in the schedule: 012's own driver, with 020's code out of the picture,
renders the same 743 frames. 012's record keeps its figures — they were true of its
own tree — and 020's row 12 now compares against row 49 as it renders today, with
the deviation named in its own tick instead of smoothed over.

---

## Row 12 — with no assignment the render is 012's own video (T027)

*Walked 2026-10-14 17:10 PDT, driver `klhu_walk_assignment.py 12`. This row is the
regression check 020 owes 012, so it uses **012's own fixture**: the tree's pre-set
and its nine pictures, pushed and chosen through the platform's own file dialog
(012's `make_pictures`/`push_pictures`/`choose_pictures`, and its own "Choose more"
for the last four). The app's settings are cleared first, so nothing is assigned
and nothing is remembered.*

**The reader assigns nothing** — the prompt's own line is untouched
(`No sentences assigned`) — and the render's own line is 012's own schedule:

```
10-14 17:10:32.759 I/flutter (15755): klhu render pictures=9 ranges=0..76,77..146,147..237,238..347,348..428,429..494,495..609,610..742,- sentences=8
```

Nine pictures, **eight ranges — one per sentence** — and the ninth picture in **no
range** (`-`): row 49's own shape, unchanged by this feature (FR-009, SC-003).

**Frame for frame, against 012's row 49 as it renders today** (T032's own re-walk of
that row, in this same record): 012's row 49 renders **743 frames / 24766 ms**; this
render is **743 frames / 24.894 s** (ffprobe on the file pulled out of the app).
The same file, by the app's own schedule and by the encoder's own count.

**What does not reproduce, and why that is not this feature**: 012's **row 31**
recorded **818 frames / 27.39 s** for the same pre-set on 2026-10-07, and neither
012's own row 49 nor this render reaches that today. The difference is in the
**synthesis' own durations** — the voice's speed is the device's, not the app's — and
012's own driver, with this feature's code out of the picture, renders the same 743
frames. 012's record keeps its figures (they were true of its own tree), and this
row compares against row 49 rendered today, with the deviation named here and in its
tick rather than smoothed over.

**Checks**: `10/10 checks passed` (exit 0). Proves FR-009, SC-003.

**Left for the reader**: `/tmp/020_row12_prompt.png`, `/tmp/020_row12_review.png`,
the file itself at `/tmp/klhu_out/row12.mp4`.

---

## Row 13 — the audio does not move (T028)

*Walked 2026-10-15 08:22-08:24 PDT on the tree of 2026-10-14 (the `git` working
tree), driver `klhu_walk_assignment.py 13`, the same device and fixture as rows
6-12 (the row's content re-seeded; the app's own settings are cleared first, so
nothing is assigned and nothing is remembered). The APK the device holds was built
2026-10-15 08:10:52 and installed 08:10:54, and **no source file in the tree is
newer than it** — the walk drives this tree's own build.*

**What the reader did**: pick the same three pictures twice. The first time
nothing is assigned (`No sentences assigned` on the prompt's own line), the second
time through the pass **2 / 4 / 4** — white the first two sentences, black the next
four, red the last four.

**The two renders' own lines** (logcat, verbatim):

```
10-15 08:22:22.254 I/flutter ( 8795): klhu render pictures=3 ranges=0..206,207..351,352..551 sentences=10
10-15 08:24:10.250 I/flutter ( 8795): klhu render pictures=3 ranges=0..98,99..302,303..551 sentences=10
```

The pictures moved — 012's own even split of this fixture's ten sentences over
three pictures is `0..206,207..351,352..551`, the reader's 2/4/4 is
`0..98,99..302,303..551` — and the audio did not: `sentences=10` both times.

**The render's own report, and the same video length twice**:

| | the app's own report | the utterances |
|---|---|---|
| nothing assigned | `18400ms 776933B frames=552` | ten, in order |
| the reader's 2/4/4 | `18400ms frames=552` | the same ten, in the same order |

**The utterances**, read off the renderer's own slot lines (`span=` is the
sentence's own characters inside the content), are the same list in both renders:

```
[(0, 17), (18, 37), (38, 57), (59, 80), (81, 95), (96, 113), (115, 132), (133, 154), (155, 173), (174, 191)]
```

against the fixture's own ten sentences' lengths `[17, 19, 19, 21, 14, 17, 17, 21,
18, 17]`: one span per sentence, in the content's own order, none missing and none
doubled (FR-008 — the read is never truncated), and the same list under an
assignment (SC-005). The spans' own gaps (`57 → 59`, the paragraph break) are the
content's whitespace, which no utterance covers.

**Checks**: `9/9 checks passed` (exit 0). Proves FR-008, SC-005.

**Two things this row's own runs taught, both recorded rather than smoothed over**:

- **The render path logs no `klhu speak` line.** This row's own wording names those
  lines as the audio's evidence, and the tree does not emit them: a render writes
  each sentence to a file (`SentenceSynthesizer.synthesizeToFile`), where a *read*
  speaks through `ReaderService`'s own line. The row's utterances are therefore
  read off the renderer's own slot lines' `span=`, which name the sentence each
  frame speaks (the driver's `spoken_spans`) — and the row prints whatever
  `klhu speak` lines the render's own log does hold, which is none.
- **012's even split of this fixture is 4 / 3 / 3** — exactly the assignment this
  row's **first** run made — and the two schedule lines came out **identical**
  (`ranges=0..206,207..351,352..551`, check 4 red, `8/9`). The row now assigns
  2 / 4 / 4: a row that compares the audio "with and without an assignment" has to
  make the pictures actually move, or it compares a render with itself. It also
  reads row 6's own `0..197,198..340,341..529` for its 4/3/3 — the fallback's split
  and the reader's are the same numbers for that assignment.

**Left for the reader**: `/tmp/020_row13_review.png` — the review after the second
render.

---

## Row 16 — the assignment outlives the prompt, and re-attaches by name (T029)

*Walked 2026-10-15 08:25–08:28 PDT on the tree of 2026-10-14, driver
`klhu_walk_assignment.py 16`, the same device, package and fixture as rows 6–13.
The phone's own album (`/sdcard/Movies/Klhu`) is emptied before the row and again
after it: this row keeps a video, and a walk that leaves the reader's gallery
holding a file of its own cannot tell an earlier run's from this one's.*

**What the reader did**: assign **4 / 3 / 3** through the pass (white the first four
sentences, black the next three, red the last three), render, **keep** the file,
leave the screen, have the app stopped and started again, pick the same three files
again, move **one sentence** (white's fourth → black), and render again.

**The first render's own line** (logcat, verbatim):

```
10-15 08:25:58.165 I/flutter (13340): klhu render pictures=3 ranges=0..206,207..351,352..551 sentences=10
```

read against the renderer's own slot lines — the ten sentences' own first frames,
`[0, 47, 99, 151, 207, 254, 303, 352, 404, 456]` over 552 frames — the three ranges
are white's four sentences (`0..206`, i.e. to the frame before sentence 5 opens at
207), black's next three (`207..351`) and red's last three (`352..551`): the
reader's runs, in the reader's order.

**Kept** (`Save` on the review): the file is in the album **and** in the phone's
video library under the content's own name — `walk 020 ten sentences.mp4` — pulled
out at `sha256=2a81e007755fbf64…`, and it is the render's own bytes (`776933B`).

**The relaunch** (`am force-stop` + start — *not* `hard_restart`, which is
`pm clear` and would wipe the very store this row is about): the app comes back on
the reader's own page, the same three files are picked again, and the pass opens
with **`{'w020_white.png': '4 sentences', 'w020_black.png': '3 sentences',
'w020_red.png': '3 sentences'}`** — the stored runs, back in force on the pictures
carrying those names, with nothing re-assigned by hand (FR-010, SC-006).

**The reader's own change, and the second render's own line**:

```
10-15 08:27:29.739 I/flutter (15879): klhu render pictures=3 ranges=0..150,151..351,352..551 sentences=10
```

White now ends on the **third** sentence's own last frame (`150`, where sentence 4
opens at `151`) and black opens on it: the difference is the one sentence the reader
moved, and **red's range is the same two numbers** (`352..551`). The assignment this
row makes leaves no unassigned stretch, so the difference is the assignment's own
and not FR-006's tail fallback.

**The files themselves** (both pulled off the device, one frame number read in both
— a pixel outside the text column, where only the picture can be):

| frame | in white's old range → black's new range | in red's own range |
|---|---|---|
| the first render's file | `156 → (255, 255, 255)` white | `357 → (219, 29, 30)` red |
| the second render's file | `156 → (0, 0, 0)` black | `357 → (219, 29, 30)` red |

so the two files differ exactly where the reader's assignment differs (`776933B`
`sha256=2a81e007755fbf64…` → `776291B` `sha256=ed4c1054694ef933…`) and nowhere else
that was sampled.

**The first file is untouched** (SC-007): the album's copy still hashes
`2a81e007755fbf64…`, the album still holds that one file (the second render kept
nothing — its review came down), and the app's own library was **neither added to
nor rewritten**: 6 files → 6 files, `changed: []` (FR-013).

**Checks**: `24/24 checks passed` (exit 0). Proves FR-010, FR-012, FR-013,
FR-016, SC-006, SC-007.

**Left for the reader**: `/tmp/klhu_out/row16_kept.mp4` (the file they kept),
`row16_first.mp4` / `row16_second.mp4` (the two renders), and the sampled frames
`row16_first_moved.png`, `row16_second_moved.png`, `row16_first_red.png`,
`row16_second_red.png`. The device is left as it was found: the album is empty
again and the row's content is out of the library.

---

## Row 18 — a sentence highlighted on the page does not cut the video (T039)

*Walked 2026-10-15 08:31-08:34 PDT on the tree of 2026-10-14, driver
`klhu_walk_assignment.py 18`, the same device, package and fixture as rows 6-13 and
16. This is the reader's own rule of 2026-10-14 (FR-017, SC-011, `plan.md`'s
Amendment 2) walked on the device: 012's FR-004 started a video where the page's
own position was, and this row is the case that falsified it.*

**What the reader did**: pick the same three pictures twice. The first time on the
page **as the app opens it** (nothing highlighted); then two presses of ▶ Read,
which is 016's own stepping gesture; then the same three files again, with the
sentence under the page's highlight.

**The first render, nothing highlighted** (the app's own line, verbatim after the
device's logcat prefix):

```
klhu render pictures=3 ranges=0..206,207..351,352..551 sentences=10
```

**The page's own position, named by the app twice.** A press reads **the sentence
in force** exactly (016's rule), so its own `klhu read range` line names it:

```
klhu read range: 0..17            the content's first sentence — the page had nothing selected
klhu read range: 18..37           the SECOND sentence — which is what was in force for that press
```

The second line is the row's own premise, app-written: after the first press the
position is on the content's **second** sentence, not the first — so 012's rule
would have started the video there and held nine sentences, and this render holds
ten. The page paints it, too: the screenshot's yellow band sits at row 472 with
**13456 yellow px** (`/tmp/020_row18_highlight.png`) — the reader sees the sentence
the position is on.

**The second render, that sentence highlighted** (logcat, verbatim):

```
10-15 08:33:33.519 I/flutter (22875): klhu render pictures=3 ranges=0..206,207..351,352..551 sentences=10
```

**The two renders' own lines are identical** — the same payload, character for
character, and the row compares the **payload** (after the device's own `": "`),
which is 012's and row 7's own way of comparing two of the app's lines across
renders: the prefix is the logcat's timestamp and process id, not the app's text.
The row's first run compared the whole lines and read that difference as a
failure (`6/7`); the app's own text was identical both times.

**What the render held, off the renderer's own slot lines**: the same ten
utterances, by span, as row 13's own list
(`[(0, 17), (18, 37), … (174, 191)]`), slot 0 at **frame 0** with
`span=0..17` — the content's own first sentence, characters 0 to 17 — and
`sentences=10`.

**Checks**: `8/8 checks passed` (exit 0). Proves FR-017, SC-011.

**Left for the reader**: `/tmp/020_row18_highlight.png` (the page with the sentence
painted), `/tmp/020_row18_review.png` (the review after the second render).

---

## T030 — row 14's structural checks, on the finished tree

*Run 2026-10-15 08:40–08:45 PDT on the tree of 2026-10-14 (the `git` working tree),
the same build the device rows drove. Row 14's own checks, each with the command
that produced it:*

```
flutter analyze                          → No issues found! (ran in 1.2s)
flutter test --concurrency=2             → 01:17 +782: All tests passed!
message keys per ARB (four files)        → 120 each
flutter gen-l10n, then the files again   → the generator reproduces the tree's own Dart:
                                           the aggregate md5 of lib/l10n/*.dart is
                                           98425bbdb8a43bd120c4e62711e002dc both before
                                           and after — it rewrites nothing
flutter test test/l10n_keys_test.dart    → 00:00 +3: All tests passed!
git diff --stat lib/video_pictures.dart  → 1 file changed, 70 insertions(+), 0 deletions(-)
```

**The suite count, against T001's 729, decomposed by file** (T034's own ask, read
here because both rows use the same run): the three **new** files are
`test/picture_assignment_test.dart` **20**, `test/picture_assignment_store_test.dart`
**8** and `test/reading_view_video_assignment_test.dart` **18** — 46 — and the two
**extended** files gained seven: `test/video_pictures_test.dart` 22 → **27** and
`test/video_renderer_test.dart` 22 → **24**. 729 + 46 + 7 = **782**, which is the
count the run above reports: the difference closes exactly.

**The split function is beside 012's, not inside it.** `git diff
lib/video_pictures.dart` is **70 insertions and no deletions in the whole file** —
`buildAssignedSchedule` and its one helper are appended after
`buildPictureSchedule`'s own closing brace, and not one line of 012's body moved
(FR-009's second half, SC-003, research D3). The new function's own comment says
why the no-assignment case is a **diff rather than a claim**: with no runs, or none
holding a sentence, it is literally `buildPictureSchedule`'s own call.

Proves FR-009's second half, SC-003, research D3.

---

## T031 — 019's dated key counts, verified against the measured number

*Run 2026-10-15 08:45 PDT. 019's two records quote **110** as the message-key total
(`quickstart.md`'s baseline block at its line 16 and its structural row at line 223
with the dated note beneath it; `tasks.md`'s baseline block at its line 42 with its
own dated note), and both notes already say, dated 2026-10-14, that 110 is 019's
own figure and no longer what the four files hold. This row's work was to **verify**
them against T010's measured count — and to correct the number if the ARB list had
moved. It had not:*

```
app_en.arb    HEAD 110 keys → 120 now
019's keys    110 of 110 still present; dropped or renamed away: none
              10 added, all this feature's own: assignmentNothingAssigned,
              assignmentOpenButton, assignmentRefusedHoldsSentences,
              assignmentRefusedMiddle, assignmentRefusedNotContinuous,
              assignmentRefusedNotInOrder, assignmentRemoveSentence,
              assignmentSentenceCount, assignmentStaleDetail, assignmentStaleWarning
app_es.arb / app_zh.arb / app_zh_Hans.arb   120 each, the template's own set, item for item
```

**What was corrected, and what was not**: both of 019's dated notes now carry the
measured figure — *“Measured 2026-10-15 on 020's tree: `120` each”* — so that row is
re-readable on its own without following a pointer into this feature. Nothing else
in 019's records moved: its own measurements (the 663-case suite, the 50-file test
tree, the `1.2s` analyzer run) were true of **its** tree and are left as written,
exactly as this repository's rule for a record of a closed stage requires. The
count's own arithmetic is T010's list plus 019's total — **120 = 110 + 10** — and
`doneButton` is 015's own word reused rather than minted again, which is why the
feature adds ten keys and not eleven.

Proves 019's structural row's own figure (the message-key total, read as the number that applies now) and this
feature's own key parity across all four ARBs — **cited in words rather than as an id**, because the foreign id
belongs to another specification's requirement universe and this feature's own checker reads its ids against
*this* `spec.md` (which is why `check_artifact_refs.py` went red on the first write of this section: it is right,
and the citation is what was wrong).
