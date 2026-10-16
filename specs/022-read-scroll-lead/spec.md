# Feature Specification: The page keeps something ahead of the read

**Feature Branch**: `022-read-scroll-lead`

**Created**: 2026-10-16

**Status**: Draft

**Input**: the reader's own message of 2026-10-16, quoted verbatim:

> fix verified on device.
> Add one change: On reading, auto scroll after read last sentence on screen. I like to start the auto scroll before highlight/read last sentence on screen. so the reading sentence is not the last sentence on screen unless its the last sentence of the content.

**How this stage reads it, said out loud so a misreading is visible.** The first sentence describes what the page does
**today** ("auto scroll after read last sentence on screen" — the page moves once the read has reached the bottom of the
screen); the second is the change ("start the auto scroll **before** highlight/read last sentence on screen"); the third
is the **invariant** the change exists to satisfy, and it is the reading this spec is written against: **while a
sentence is being read it must not be the last sentence visible on screen** — unless it is the content's last sentence.
The ask is about **reading** (the reading page's own read), not the video and not any other screen.

**The number, and what the wish list carries.** `create-new-feature.sh --dry-run --json` read `FEATURE_NUM` **022**, and
the directory is `specs/022-read-scroll-lead` — the script's own number and the list's next number agree. The wish list
(`text.txt`) carries **no item for this ask**: its last entry is **021**. So `Input` is this conversation, quoted above
and unedited, and the item is **offered** in the handback rather than written into the reader's own file by this stage.

**What the app does today, measured on the device (2026-10-16).** 011's own walk row 7 was re-run on the tree as it
stands — `emulator-5554`, Extra large, display 1080×1000 so the text is taller than the page, 011's own 8-sentence
preset:

```
klhu speak: 8 utterances | klhu follow: 8 reports | 5 frames | viewport=196 logical
first/last report: p0 s0 top=3 bottom=31, p2 s2 top=134 bottom=196
RESULT: PASS
```

The app's own evidence line, sentence by sentence, as it stood **while each sentence was spoken**:

```
klhu follow: p0 s0 visible=1 top=3   bottom=31  viewport=196
klhu follow: p0 s1 visible=1 top=37  bottom=65  viewport=196
klhu follow: p1 s0 visible=1 top=105 bottom=167 viewport=196
klhu follow: p1 s1 visible=1 top=134 bottom=196 viewport=196
klhu follow: p1 s2 visible=1 top=134 bottom=196 viewport=196
klhu follow: p2 s0 visible=1 top=168 bottom=196 viewport=196
klhu follow: p2 s1 visible=1 top=100 bottom=196 viewport=196
klhu follow: p2 s2 visible=1 top=134 bottom=196 viewport=196
```

**Read against the reader's words**: every report reads `visible=1` — 011's own rule (its `FR-003`: *never scroll while
the sentence being read is already fully visible*) is **satisfied at every sentence** — and in **four of the seven
non-final sentences** the reported box ends at `bottom=196`, the viewport's own last pixel, so the sentence being read
is the bottom-most thing on screen while it is spoken. That is the complaint, in the app's own numbers: the rule that
ships and the reader's own expectation are not in conflict, they are about **different things** — 011 asks whether the
spoken sentence is visible, the reader asks whether anything is visible **after** it.

*(One difference to reconcile, not to inherit: 011's own receipt for this row quotes `viewport=209` on the same fixture
where today's run reads `196`. Whichever is right, the plan's first row re-takes the baseline rather than carrying
either number forward.)*

**What already exists, and what this feature changes.** The follow ships and is walked (011: the trigger, the reveal,
the manual-scroll rule, the evidence line, a device row and four unit cases). This feature changes the follow's
**trigger** and its **target**, and nothing else: the page moves earlier (before the sentence that would be last is
highlighted and read) and it moves so that a sentence **after** the one being read is visible (FR-001, FR-002). The
voice, the highlight, the read's own order, the stored position, the video and every other screen are untouched.

**The mechanism this spec assumes, and why the change is small.** The page's text is a **single `RenderParagraph`**
(`_textKey`), so any sentence's box can be measured whether or not it is on screen (`_measureSpan`,
`lib/reading_view.dart:1274`), and the move itself is the framework's own reveal on that paragraph
(`_scrollIntoView`, `lib/reading_view.dart:1175`). Today's decision is one branch: while the spoken sentence is fully
visible, `_followRead` (`lib/reading_view.dart:1147`) logs and returns **without moving**. The lead is therefore a
different **trigger** and a different **rect** handed to the same reveal, and the moment to act at is the sentence's
own start callback — which the app already fires immediately before speaking that sentence
(`lib/reader_service.dart:37`) — no new scroll machinery, no new state, no
new string, no platform work. What it does need is **one more fact in the app's own evidence line**
(`_logFollow`, `lib/reading_view.dart:1307`): how many sentences' boxes are visible below the reported one, because the
rule this feature states cannot be read off today's six numbers (FR-009, SC-001).

## Clarifications

### Session 2026-10-16 — the four questions, and the reader's own answer

**Revised by the reader, 2026-10-16, after this stage's handover: "This is not changed."** The requirement above is
restated **unchanged**, and that overrules this stage's first reading of its own first question: `1A` starts the move
**with** the last-visible sentence's highlight, which is not "before" it. **`1B` is what stands for question 1** — the
move fires one sentence earlier — and the 200 ms window `1A` accepted (the reveal running while the reading sentence's
voice begins) is **refused as the design**. The rest of the answers are untouched: `2A` (the move minimal), `3A` (the ▶
step under the same rule), `4A` (the voice is not held). The first answer is left in place below as the argument it
came from, dated, with the revision marked against it.

**Answered by the reader, 2026-10-16: `1A 2A 3A 4A`** — quoted as given, and it is the four recommendations this stage
put (the binding is by the handback's own numbering: `1A` = the first question's recommended option, and the same holds
for the three that follow; the example token this entry first carried read `2B`, a typo, and the reader's own answer is
what corrects it). So **all four are requirements now, not recommendations**, and each entry below is left as it was
argued with the answer marked against it: `1A` keeps the trigger at the last-visible sentence's own start (one sentence
of headroom, with the reveal's own window recorded and kept), `2A` keeps the move minimal, `3A` puts the ▶ step under
the same rule, `4A` lets the move animate while the voice begins. Every alternative an entry refuses stays refused.
The reader also reported, in the same message, a **defect of the ▶ press** — with the page away from the top and
nothing highlighted, ▶ read the first sentence with the page where it was — which the tree confirms and which is fixed
as its own dated change in `specs/016-sentence-reading`'s record; it is the same reveal this feature's `3A` builds on.

**Closing note, 2026-10-16 (at the implement stage's close)**: the first answer `1A` was revised **before a line of this
feature was written** — the code, the tests and the walk were all taken against `1B` — so nothing in this record was ever
measured on the withdrawn reading, and no receipt had to be re-taken for it. The 200 ms window the withdrawn reading
accepted is refused here; the cost the reader's own answer carries (the page moves under the sentence **before** the
triggered one) is named in `plan.md`'s risks and is visible in the walk's own reports in `breakpoint.md`.

1. **[Answered `1A`, revised the same day to `1B` — see the paragraph above]** When the move starts — and the one window this question is really about.** The app already has the seam that
   makes "before the read" possible: the page is told a sentence is starting **immediately before** the engine is asked
   to speak it (`lib/reader_service.dart:37`, the call at `:570` and the `speak` at `:594`), so the page can act — and
   the reveal is animated (`_revealDuration`), so "the move started" and "the page has settled" are two different
   moments, and the choice below is about **which** of them the rule is judged on.
   **Recommended `1A`**: the move starts when the sentence that would be the **last one visible** becomes the sentence
   in force — the same event that paints its highlight. What the reader sees: one sentence of headroom, and a page that
   moves at most once per sentence. **What this reading leaves, said plainly**: for the reveal's own animation (a
   fraction of a second) that sentence is still at the bottom edge while its voice begins — the steady state the reader
   complained about is gone, the window is not.
   **The alternative that removes the window, `1B`**: trigger one sentence **earlier** — while the *previous* sentence
   is still being read — so the page has settled before the next sentence's highlight lands and that sentence is never
   at the edge at all. This is the **literal** reading of the reader's own words ("start the auto scroll **before**
   highlight/read last sentence on screen"), and its cost is the mirror image: the page then moves **under** the
   sentence the reader is in the middle of reading, once per sentence, where `1A` moves it under the sentence that has
   only just begun.
   **`1C` — today's trigger** (move only when the spoken sentence stops being fully visible): **refused**; it is the
   behaviour being reported, and it is the one that leaves the reading sentence at the bottom edge with nothing below
   it. **Settled on 2026-10-16**: the reader restated the requirement unchanged, so `1B` stands and FR-002's own wording
   ("before that sentence is highlighted") is what is written — the move fires at the sentence **before** the last
   visible one, and the window this entry recorded as accepted is refused.
2. **[Answered `2A`]** How far the page moves when it fires.** **Recommended `2A`**: **just enough** that the next sentence is visible —
   the reveal is handed the rect that covers the sentence being read **and** the one after it, so the page moves the
   smallest amount that satisfies the rule (011's own "just enough" character is kept; the reader sees the page settle
   by one sentence at a time). **The alternatives recorded**: **2B** — keep a cushion of roughly a third of the
   viewport ahead of the reading sentence: fewer moves, larger ones, and the sentences above the reading one leave the
   screen sooner; **2C** — a page turn (bring the reading sentence's box to the **top** of the viewport): the fewest
   moves and the largest lurches, and the reader loses the sentences they are still hearing the echo of.
3. **[Answered `3A`]** Whether the ▶ step read follows the same rule.** **Recommended `3A`**: **yes** — 016's step advance brings the
   next sentence's highlight into view (016's own step rule — the one that brings a step's sentence into view —
   through the same `_revealRange`, `lib/reading_view.dart:1352`), and a reader pressing ▶ at the bottom of the page meets the same bottom-edge
   situation, one press at a time. **The alternative recorded**: **3B** — steps keep today's rule and only a
   continuous read gets the lead: cheaper (016's row and its cases stay as written), and it leaves the reader to report
   the same thing about ▶ the next time they use it.
4. **[Answered `4A`]** Whether the move must finish before the voice starts.** **Recommended `4A`**: **no** — the move **starts** before
   the sentence's highlight and voice and animates while the sentence begins (011's reveal is animated,
   `_revealDuration`), so the reading never pauses. **The alternative recorded**: **4B** — hold the voice until the page
   settles, which reads as a deliberate gap before every sentence that triggers a move: refused as the default because
   a pause in the reading is louder than a moving page, and recordable later as a setting if the reader misses the
   trade.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The read always has something ahead of it (Priority: P1)

A read that is longer than one screen is listened to while the reader's eye follows the text. Today the page waits
until the spoken sentence no longer fits and then moves, so the sentence being read is the last one on screen just
before every move — the reader is always reading the bottom line. With this feature the page moves **before** that
sentence is highlighted and spoken, so what is being read always has a sentence below it, and the page settles by one
sentence at a time as the read goes on.

**Why this priority**: it is the whole ask, and it is the only change the reader made. It reuses 011's own machinery,
so it delivers value on its own with no other story's work.

**Independent Test**: on a text longer than the visible area, start a read and watch the app's own evidence line for
every sentence: the reported sentence is never the last one visible, and no sentence is spoken that is the bottom-most
thing on screen — except the content's last sentence. The same walk read on a text that fits the screen moves the page
by zero pixels.

**Acceptance Scenarios**:

1. **Given** a text longer than the visible area and a read playing, **When** the sentence being read is the last one
   currently visible, **Then** the page has already moved so that a sentence after it is visible, and this happened
   before that sentence's own voice began
2. **Given** a read playing near the end of the content, **When** the sentence being read is the content's **last**
   sentence, **Then** the page does not move (nothing follows it), which is the reader's own exception
3. **Given** a text that fits in the visible area, **When** a read plays from start to end, **Then** the page does not
   move at all (011's own scenario, re-run)
4. **Given** a read playing and the reader scrolls the page by hand, **When** the same sentence is still being read,
   **Then** the page stays where the reader put it (011's own rule, re-run), and the next sentence's own start is where
   the lead may move again
5. **Given** a read that starts from a stored position below the fold, **When** the read begins, **Then** the position
   is shown with a sentence after it visible before its own sentence is spoken

### User Story 2 - The page does not lurch, and does not fight the reader (Priority: P1)

The lead moves the page more often than today, so what it must **not** do is become a page that jumps: each move is the
smallest one the rule needs, it happens while the reader's attention is still on the sentence being read, and a scroll
the reader makes by hand is never undone inside the sentence it was made in.

**Why this priority**: the change trades a settled page for a page that keeps up; without this half the reader has
gained a few pixels below the fold and lost the page's calm.

**Independent Test**: run a long read and read the reveal's own offsets sentence by sentence: each move is bounded by
the next sentence's own box, no move puts the reading sentence above the viewport's top, and a manual scroll made
during a sentence stands until that sentence's voice ends.

**Acceptance Scenarios**:

1. **Given** a read playing, **When** the page moves for a sentence, **Then** the sentence being read is still on
   screen and the sentence after it is on screen too, and nothing above the reading sentence left the screen because of
   the move
2. **Given** a read playing and a manual scroll during the current sentence, **When** that sentence is still being
   spoken, **Then** the page does not move again; it may move again at the next sentence's own start

### Edge Cases

- **The content's last sentence** may be the last thing on screen — the reader's own exception (FR-005).
- **A text that fits on screen** never moves (011's own scenario 3): its reading sentence always has the sentences after
  it below it already.
- **A sentence taller than the viewport** cannot have anything below it on screen while it is read: the page shows it
  as it does today and the rule does not apply (011's own stated limit for a sentence that will not fit at all).
- **A read started at the very last sentence** (a stored position at the content's end): nothing after it exists, so no
  move, on the same exception as the content's last sentence.
- **A manual scroll that leaves the reading sentence off screen**: the lead reveals it as 011 does today (its `FR-002`
  path), and the headroom rule resumes at the sentence after it.
- **A read stopped or paused** between two sentences: the page stays where the last move left it (011's `FR-004`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: While a read plays, the page MUST keep at least one sentence **after** the sentence being read visible on
  screen — so the sentence being read is never the last one on screen. The exception is the content's **last** sentence:
  nothing follows it, so nothing is required of the page. **The two cases a reader of this rule looks for, said here
  rather than left to be inferred**: a text that fits in the visible area already satisfies it (every sentence after the
  one being read is on screen by definition, so the page never moves), and the content's last sentence is the one
  exception — the app's own line reads `below=0` for it and the page does not move for it.
- **FR-002**: The move MUST start **at the sentence before** the one that would be the last visible — that is, **before**
  that sentence's own highlight lands and before its voice begins (the reader's own words, read literally: *"start the
  auto scroll before highlight/read last sentence on screen"*, settled 2026-10-16). The app fires its sentence-start
  callback immediately before asking the engine to speak that sentence (`lib/reader_service.dart:37`), so firing at the
  **previous** sentence's start lets the reveal's own animation (200 ms) run while that previous sentence is being read,
  and the page has settled by the time the last-visible sentence's highlight lands. **The move MUST NOT begin at or
  after that highlight** — the window Clarifications 1 first accepted is refused.
- **FR-003**: The move MUST be 011's own reveal — the same measurement of a sentence's box and the same animated
  `showOnScreen` — and MUST move the page **no further than the rule needs** (Clarifications 2): no page turn, no jump
  to the top, and never a move that leaves the sentence being read off screen.
- **FR-004**: The lead MUST fire **once per sentence**, at that sentence's own start. A scroll the reader makes by hand
  while a sentence is being read MUST stand until that sentence's voice ends, on 011's own rule (`FR-005` of that spec).
- **FR-005**: The page MUST NOT move for the content's last sentence, for a read that starts at it, or for a text that
  fits in the visible area (011's own scenario 3 and `SC-003`).
- **FR-006**: The rule MUST apply wherever the page itself moves the read on without the reader's own choice of the next
  sentence — a continuous read, and (subject to Clarifications 3) 016's step advance, which reveals through the same
  code path.
- **FR-007**: A read that starts from a stored position (011's own `FR-002` path) MUST obey the rule from its first
  sentence: the position is shown with the sentence after it visible before that first sentence is spoken.
- **FR-008**: Nothing else may change: the voice and the read's own order, the highlight's own unit, the stored
  position, the video and its timeline, the contents list, the appearance settings, the stored state (no new key), the
  message keys (no new string) and the platform halves are all untouched.
- **FR-009**: The app's own evidence line MUST carry the fact this rule is about — how many sentences' boxes are visible
  below the sentence it reports — so that a walked row can check the rule on the device rather than infer it. The line's
  existing fields keep their own names and order.

### Key Entities *(include if feature involves data)*

- **The sentence in force**: the sentence being spoken and highlighted — the unit 011's follow already measures.
- **Its own box, and the next sentence's box**: two measurements of the same `RenderParagraph`, both available off
  screen; the rule is a relation between them and the viewport's own height.
- **No new stored state**: the rule is evaluated while a read plays and is not remembered anywhere.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On `emulator-5554`, on 011's own row-7 fixture (Extra large, display 1080×1000, the 8-sentence preset),
  **every** report for a sentence that is not the content's last shows at least one further sentence's box inside the
  viewport below it — **zero** reports in which the sentence being read is the bottom-most box on screen. Measured off
  the app's own extended line (FR-009), with the today's-run figures above as the "before".
- **SC-002**: For every sentence that triggers a move, the app's own evidence of that move precedes the `klhu speak`
  line of that same sentence — the move starts first, and a sentence is never spoken with nothing below it.
- **SC-003**: A text that fits the visible area moves the page by **zero** pixels in a whole read, and the content's
  last sentence triggers **no** move (011's own scenario 3 and `SC-003`, re-run).
- **SC-004**: A manual scroll made while a sentence is being read stands until that sentence's voice ends — 011's own
  case, re-run on this tree.
- **SC-005**: Each move is bounded by the rule: after it, the sentence being read is still inside the viewport and the
  next sentence's box is inside it too, and no move carries the reading sentence above the viewport's own top.
- **SC-006**: `flutter analyze` clean; the suite's own count recorded against this tree's closing number and decomposed
  by file; 011's four follow cases re-cut where the rule changes them and green where it does not; the four ARBs
  unchanged (this feature adds no string).
- **SC-007**: (Subject to Clarifications 3) a step read from ▶ advances with a sentence visible below the new highlight,
  and 016's own row for it re-walked.

## Assumptions

- **The reader reads along with the voice.** The whole point of the change is to see what is coming while hearing what
  is being said; a listener who never looks at the page loses nothing either way.
- **One `RenderParagraph` for the whole text** is what makes the lead cheap: any sentence's box is measurable while off
  screen (`lib/reading_view.dart:1274`), so the next sentence's geometry is available at the trigger. If that ever
  stops being true (a per-paragraph widget), the plan must say so before the implementation assumes it.
- **"On screen" means inside the page's own visible reading area** — the same area 011's evidence line reports as
  `viewport` (196 logical px at the walk's fixture).
- **The viewport holds more than two sentences at the walk's fixture** (sentences measure ~28 logical px there), so the
  rule is satisfiable on the device without pushing the reading sentence off screen.
- **The device walk's fixture is 011's own row 7** (Extra large, 1080×1000, the 8-sentence preset): it is the fixture
  the complaint was observed on, it already produces one report per sentence, and its `viewport` figure must be
  re-measured before it is quoted (209 in 011's receipt, 196 today).
- **The video is not in scope**: its sentences are painted into frames by its own schedule (012), where "on screen"
  has no meaning.
- **Nothing is owed to `text.txt`'s numbering**: the list has no item for this ask; the item is offered in the handback.

## Out of scope

- Any change to the **reading** itself: the voice, its timing, the order of sentences, the gap between them, or a pause
  held for the page to settle (Clarifications 4 records what was refused).
- The video, its review page, its timeline or its own sentence band.
- The contents list, the comment/head-tag surfaces, the appearance settings.
- A setting, a toggle or a per-content choice for the lead: one behaviour, and it is 011's own "just enough" character.
- Any progress indicator, mini-map or scrollbar for the reading page.
- iOS and any platform work: the change is Dart, on the page, with no plugin.

## What this feature supersedes, and the pointers it owes

- **011's own rule about when the page may move.** 011's `FR-003` states that the page MUST NOT scroll while the
  sentence being read is already fully visible, and its scenario 3 states that a text that fits never scrolls. The
  first is **narrowed**: the page now moves in exactly one case it did not before — a sentence being read that is fully
  visible **and** is the last one visible — while the fit-on-screen half stands unchanged. The pointer is one bullet in
  `specs/011-reading-experience/tasks.md`'s `## Superseded by later specs`, and 011's artifacts are left as written.
- **011's own receipts, which this feature re-measures rather than rewrites.** Its device row 7 was walked against the
  old trigger (the receipt above is today's re-run of it, and its own text quotes `viewport=209`), and its four unit
  cases in `test/reading_view_follow_test.dart` assert the follow as it behaves today: *short text: no scroll* and
  *manual scroll is not undone* are **unchanged requirements** and must stay green, while *long text: the spoken
  sentence comes into view* and *offsets are in range and never go backwards in one read* are the cases whose fixtures
  the new trigger moves. The plan names, per case, whether it is re-cut or re-run.
- **The evidence line's own format, which a closed feature parses.** `klhu follow:` is read by two parsers today —
  011's walk driver (`specs/011-reading-experience/scripts/klhu_walk_experience.py`) and 011's own case in
  `test/reading_view_follow_test.dart` — so the field FR-009 adds must be **appended** (existing names and order
  kept), and the plan must say whether those two parsers are extended or left (they read by regex, so a longer line
  keeps matching; a changed order would not).
- **016's step reveal, if Clarifications 3 answers yes.** 016's own step rule brings a step's sentence into view
  through the same code path, so `3A` re-cuts its row and its case; `3B` leaves them as written and owes nothing.
