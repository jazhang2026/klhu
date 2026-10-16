# Feature Specification: Sentence-by-sentence reading

**Feature Branch**: `016-sentence-reading`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description, `text.txt` (2026-10-09): "016. Sentence by sentence reading - change on Read
button function: if a sentence is selected, click Read button will read the selected sentence. if no sentence
is selected, click Read button will hightlight and read first sentence. after read one sentence, the next
sentence will be highlighted and ready to read. click Read button again will read the next sentence."

**Input (the same day, spoken)**: "我需要的是读完一句停 再一键读第二句。" — read one sentence, **stop**, then
one press of the same key reads the second. The stop is the point: the reader wants to take one sentence at a
time, at their own pace, without the app running on.

## Why this is a rule change and not a new button

The app already reads one unit at a time when the reader picks one: ▶ Read speaks the highlighted sentence and
stops (`lib/reading_view.dart:1068-1069`). What it does **not** do is stay put. When that read ends, the page
clears the highlight and the stored position with it (`lib/reading_view.dart:1394-1262`, the [`finally`] of
`_runRead`), because 011 FR-022 says the position lives only as long as the highlight that shows it:

> **FR-022**: 010's Continue Read position MUST be in force exactly while the highlight that shows it is
> painted … and the position MUST be dropped — in memory and on disk — wherever the highlight is cleared
> (Stop, the end of a read, entering EDIT).

So the gesture the reader wants — *one press, one sentence, stop, again* — is stopped by exactly one clause:
**the end of a read drops the highlight**. 016 narrows that clause for the step the reader asked for, and adds
the two rules that make a step a step: the highlight moves **ahead** to the next sentence when the read ends,
and ▶ with nothing highlighted starts at the first sentence instead of asking the reader to choose.

**This does not re-open 011's 2026-09-25 amendment.** That amendment removed a real duplication: with nothing
selected, ▶ read the **whole page** from the first sentence — the same range ⏭ Continue Read read — and two
buttons that read the same thing explain neither. A **step** is not that range: ▶ reads one sentence and ⏭
reads from there to the end. They differ in scope, which is the distinction the amendment was reaching for, and
its warning ("select a sentence or paragraph to read") is what 016 removes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One press, one sentence, at the reader's own pace (Priority: P1)

A reader who wants to follow a text closely presses ▶ and hears one sentence; the app stops, and the next
sentence sits highlighted on screen, ready. They think about it, then press ▶ again and hear that one. The
whole content is read this way, in order, one press at a time, and no press ever reads two sentences or
re-reads the last one.

**Why this priority**: it is the requested behaviour, and everything else here exists to keep it from breaking
what the other specs established.

**Independent Test**: with a three-sentence content open, press ▶ four times: the first three presses read
sentence 1, 2 and 3 in order and each ends by itself; the fourth explains that the text is finished instead of
reading anything.

**Acceptance Scenarios**:

1. **Given** a content of three sentences and nothing highlighted, **When** ▶ Read is pressed, **Then** the
   first sentence is read and the app **stops**; **the second sentence is highlighted**.
2. **Given** the app has stopped with the second sentence highlighted, **When** ▶ Read is pressed, **Then** the
   second sentence is read and the app **stops**; **the third sentence is highlighted**.
3. **Given** the app has stopped with the third sentence highlighted, **When** ▶ Read is pressed, **Then** the
   third sentence is read and the app **stops**; **no sentence is highlighted** — the text has been read to its
   end.
4. **Given** a sentence is highlighted by a tap, **When** ▶ Read is pressed, **Then** that sentence is read
   (011 FR-024 is unchanged: the gesture picks the unit).
5. **Given** a whole paragraph is highlighted by a long press, **When** ▶ Read is pressed, **Then** the whole
   paragraph is read and the app stops — the reader's own unit is not overruled by the stepping rule.
6. **Given** a content whose sentence carries a comment and the comments are being read, **When** ▶ Read is
   pressed once, **Then** the sentence **and its comment** are read, and one step later the next sentence
   follows (015's comment is part of its sentence's read, never a step of its own).

### User Story 2 - A step leaves nothing behind (Priority: P2)

The step is a new way to move through the text, and it must not break the ones already made: Stop still clears
everything, a pause still means "resume this sentence", the tracking highlight still follows what is spoken,
and the follow still keeps the spoken sentence on screen. What a step must **not** do is outlive the session:
the reader who force-stops the app and comes back wants the page they left, not a highlight they did not ask
for restored from last time.

**Why this priority**: these are the invariants 010, 011 and 015 were walked against; a stepper that kills one
of them trades a wanted feature for a wanted feature.

**Independent Test**: from a position a step reached, ⏭ Continue Read reads the sentences the steps have not
read, in order, to the end; Stop at any point clears the highlight and the position; a force-stop and relaunch
bring **nothing** back — no highlight, no previous position.

**Acceptance Scenarios**:

1. **Given** the second sentence is highlighted after a step, **When** ⏭ Continue Read is pressed, **Then** it
   reads from that sentence to the end of the text (010 FR-004), and not from the first sentence.
2. **Given** the second sentence is highlighted after a step, **When** the app is force-stopped and relaunched,
   **Then** **nothing of the previous state is remembered**: no sentence is highlighted, and there is no
   previous position for ⏭ to resume from — it reads from the first sentence (010 FR-005). The same holds when
   the highlight came from a **tap** (decision 5).
3. **Given** a read is parked by Pause and then resumed, **When** the interrupted sentence ends, **Then** the
   step's advance applies exactly as it does after a fresh step.
4. **Given** a read is underway, **When** Stop is pressed, **Then** the highlight and the position go, and ▶
   starts again at the first sentence.
5. **Given** a 多人对话 content, **When** ▶ is pressed, **Then** the step is one sentence of a turn, read in
   that turn's role's voice (014 unchanged), and the next step is the following sentence of the text.

### Edge Cases

- **A paragraph with no sentence delimiter** (`我的旅行日记`) is one sentence, and it is one step — the rule
  the read itself uses, since 011's 2026-10-09 amendment made a paragraph's end a sentence's end.
- **A step lands on a sentence that is off screen**: it is brought into view before the reader can press again
  (011 FR-002); a highlight the reader cannot see is a button they cannot aim.
- **The reader presses ▶ twice quickly**: the second press while a read is in flight changes nothing (011
  FR-025) and never queues a second sentence.
- **A tap while the step waits**: the tap sets a new selection (010 FR-002) and the next ▶ reads that; the step
  is not a mode the reader is locked into.
- **An empty text**: today's "nothing to read" message (010's row 7) is unchanged.
- **The text's last sentence carries the last comment**: the step reads the sentence and the comment, and the
  next press ends the text — the comment does not become a step of its own.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: ▶ Read with **nothing** highlighted MUST highlight the text's first sentence, bring it into view
  and read it. (Amends 011 FR-023, which asked the reader to select something instead.)
- **FR-002**: ▶ Read with a **sentence** highlighted MUST read exactly that sentence and no more (011 FR-024,
  unchanged).
- **FR-003**: ▶ Read with a **whole paragraph** highlighted (a long press, 003) MUST read that paragraph and
  stop. The reader's own gesture's unit is never overruled by the stepping rule.
- **FR-004**: When a read that ▶ started ends **by itself**, the page MUST move the highlight to the **next**
  sentence of the text and keep it there, ready for the next press, instead of clearing it. (Narrows 011
  FR-022's "the position is dropped at the end of a read".)
- **FR-005**: One step MUST be one sentence **plus that sentence's comment** when the comments are being read
  (015): the comment is part of its sentence's read, never a step of its own.
- **FR-006**: The next sentence MUST be resolved by the same rule the read uses — `lib/segmenter.dart`'s
  `sentenceRanges`, which cuts sentences inside paragraphs, so no step crosses a blank line and a paragraph
  with no delimiter is one step.
- **FR-007**: A step's highlight MUST be in force **for the rest of the session** — ⏭ Continue Read after a
  step MUST resume from the next unread sentence, not from the first (011 FR-022's condition, met in memory) —
  and **nothing is remembered across a restart, whoever set it** (the reader's choice, 2026-10-09): a
  force-stopped and relaunched app shows no highlight and holds no position, whether the position came from a
  step or from a **tap**. This retires 010's stored position; the amendment is recorded in 010's own spec, and
  what stays is the position's life inside a session (decision 5).
- **FR-008**: At the text's end — the last sentence has been read and the highlight has no next sentence — ▶
  MUST read nothing and clear the highlight and the position, and MUST show **no message**: nothing highlighted
  is the whole of what there is to say (the reader's own correction, 2026-10-09: "no sentence is highlighted …
  user can see it").
- **FR-009**: Stop MUST keep today's meaning: the highlight and the position go, and ▶ starts again at the
  first sentence. Entering EDIT, and any edit that changes the text, MUST do the same (011 FR-022).
- **FR-010**: Pause MUST keep today's meaning (it parks the read; Resume finishes the interrupted sentence,
  011 FR-021); a step's advance applies when a sentence's read ends by itself, parked or not.
- **FR-011**: In 多人对话 the step MUST be one sentence of a turn, read in the turn's role's voice, and the next
  step MUST be the following sentence of the text. 014's resolution is unchanged.
- **FR-012**: The sentence a step highlights MUST be brought into view (011 FR-001/FR-002) before the reader can
  press again — **and that includes the unit the press itself reads (2026-10-16)**: a step's read does not track, so
  nothing else reveals it, and the implementation carried this rule only for the *next* press (`_advanceStep`). The
  reader's own report of that day is the record: with the page away from the top and nothing highlighted, ⏭ Continue
  Read scrolled to the first sentence and read it, while ▶ Read read it with the page where it was. The press now
  reveals its own unit first; the reading's own lead (022) builds on that reveal.
- **FR-013**: The message that asks the reader to select something before reading MUST go, and its message key
  with it — `selectToReadMessage`, used at exactly one place, `reading_view.dart:1052`; a key the template drops
  may not be kept by a translation (`test/l10n_keys_test.dart`). **Nothing takes its place**: the text's end is
  silent (FR-008) and the empty-range message the app already has (`nothingToReadMessage`) is untouched. The
  app's key count goes **108 → 107**, and 015's row 16 receipt — walked against 108 — is corrected with its date
  in that spec's own record.
- **FR-014**: No new dependency and no platform change (011 FR-018's rule, kept).

### Key Entities

- **The step**: a sentence and its comment, read once, after which the following sentence holds the highlight
  and the position. Not a mode: a tap, a long press, Stop or ⏭ leave it at any time.
- **The position** (010): unchanged in shape — the anchor, the text's own length — and now reachable by
  stepping, because the highlight that shows it survives a step's end.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a content of N sentences, N presses of ▶ read sentences 1..N in order, one sentence per press,
  with no press reading two (measured on a device: the `klhu speak` lines of each press name exactly the
  sentence the highlight was on).
- **SC-002**: After the k-th press the highlight sits on sentence k+1 and is on screen; after the N-th press
  nothing is highlighted and the app says nothing — an unhighlighted page is the whole message (FR-008).
- **SC-003**: ⏭ Continue Read after a step reads only the sentences the steps had not read, in order, to the
  end — never the ones already heard.
- **SC-004**: A content whose sentence carries a comment reads both in the same press, and the next press
  starts at the following sentence.
- **SC-005**: Every device row 010 and 011 already have for ▶, ⏭, Pause/Resume, Stop, the follow and the stored
  position still passes, except the ones the amendment changes on purpose: ▶'s empty-selection warning (and its
  key), the drop of the highlight at the end of a **step**, and **nothing surviving a restart at all** — 010's
  stored position is retired with its own record's amendment (decision 5).

## Assumptions

- The reader wants ▶ to be the stepper and ⏭ to stay "read from here to the end" — the two buttons then differ
  in scope, not in target.
- "The next sentence is highlighted" is the reader's own wording, taken literally: the highlight always points
  at what the next press will read.
- A paragraph selection keeps its own meaning (011 FR-024); the step is what a **sentence**-scoped press does.
- The reader's pace is their own: nothing here reads a second sentence without a press.

## Out of scope

- Reading a sentence automatically after a delay ("auto-advance"), and any timer for it.
- Changing ⏭ Continue Read's meaning (it stays "from here to the end").
- The video (012) and the editor: a step's stored position is a position like any other, and a render from it
  already starts where the step left off — `video_timeline.dart:128` — which is the one path 011's own
  amendment left unwalked.
- Removed roles, the sheet, the picker, and 015's comment switch: untouched.

## Decisions this spec takes, and the alternatives

The FRs above take the recommendation in each line. Each is a place a different answer is defensible, and the
cost is written beside it so the choice is a choice.

1. **What the highlight shows while a step waits** — **(A, taken)** the **next** sentence, i.e. the highlight
   always points at what the next press reads (the reader's own words: "the next sentence will be highlighted
   and ready to read"). Alternative (B): leave it on the just-read sentence, so the highlight names what the
   reader has just heard. Cost of B: the next press's target is invisible, and the highlight and the position
   disagree about which sentence is "current".
2. **The text's end** — **(A, taken)** clear the highlight and the position and **say nothing at all**: an
   unhighlighted page is the whole message (FR-008 — the reader's own correction of 2026-10-09, *"no sentence is
   highlighted … user can see it"*), which keeps 011 FR-022 in force everywhere else. Alternative (B): wrap to the
   first sentence and keep stepping — nothing to explain, but a press at the end silently jumps the reader back to
   the beginning, and a reader following along loses their place. Alternative (C): leave the last sentence
   highlighted; the button then does nothing with no explanation until Stop. Cost of (A): **none — no string is
   added**: the count moves 108 → 107 because the warning's key goes and nothing takes its place (FR-013).
   *(Corrected 2026-10-09 in place: this line still read "say the text has ended … Cost of (A): one new message
   key", which is the reading FR-008 and FR-013 replaced the same day.)*
3. **A paragraph selected, then ▶** — **(A, taken)** read the paragraph and stop (FR-003), which respects
   011 FR-024's "the unit the gesture selected". Alternative (B): read it, then highlight the next paragraph's
   first sentence — the step continues, but the reader's unit was overruled. Alternative (C): ignore the
   paragraph selection and step by sentence — the reader's long press stops meaning anything when they press ▶.
4. **The empty-selection warning's key** — **(A, taken)** remove `selectToReadMessage` (used at exactly one
   place, `reading_view.dart:1052`) and let the text's end reuse `nothingToReadMessage`, which the app already
   shows when a read finds nothing ahead of it: the count drops **108 → 107**, and 015's row 16 — walked against
   108 — is corrected with its date in that spec's record, which is that row's own rule (a receipt that has gone
   false is fixed, not left standing). Alternative (B): add a distinct key for the text's end so the count stays
   108 — one more string to write and translate four times, for a sentence the app already has.
5. **What survives a restart** — **(B, taken — the reader's choice, 2026-10-09: "谁都别留,重启一律干净")**:
   **nothing** — no highlight and no position, whoever set it, from a step or from a tap. A relaunch is always a
   clean page and ⏭ starts at the first sentence (010 FR-005). The work: the restore path and the write path
   retire together — `_restoreAnchor`, `_persistAnchor`, the `read_position_*` record, the `Positions` store and
   `ReadingPosition` — because a record nothing restores is dead code, and this repo does not keep dead code. 010's
   FR-008 ("the position survives a restart") is amended in **010's own record** with its date, the way 011's
   amendments are, and 010's rows 9 and 14 with 011's row 8's restore half are re-cut as that amendment's rows.
   **Kept**: the position's life *inside* a session (010's FR-002/FR-004/FR-005) — a tap sets it, ⏭ reads from it,
   ▶ steps from it, and FR-005's first-sentence fallback is now also what a launch does. Alternative (A,
   declined): let a tap's position keep surviving while a step's does not. Declined because the reader asked for
   a clean page, and two positions with two lifetimes is the kind of subtlety that outlives its reason.
