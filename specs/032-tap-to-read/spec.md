# Feature Specification: Tap-to-read — remove the Read button

**Feature Branch**: `032-tap-to-read`

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description, `text.txt` (2026-11-12): "032. Change Read button function.
- Disable and hide Read button.
- When user tap or tap&hold to select a sentence or paragraph, it highlighted and start reading. No need to
  click the Read button
- Keep highlighted sentence/paragraph after reading. Don't auto highlight next sentence after reading.
- To read next sentence or any other sentence, user need to tap on the sentence to read it.
- Tap or tap&hold on the highlighted sentence/paragraph to repeat reading.
- User click Continue Reading button to read the rest of the content. This is not changed.
- When continue reading finished the last sentence, continue reading from the first sentence of the content."

**Input (the same day, spoken, clarifications)**: "let's just remove the Read button"; Continue Read
"automatically loop back and keep reading. Keep other functions."; after a tap-read, Continue Read starts
"from next sentence"; "tap the highlighted sentence to repeat reading" is only for the tap-to-read function —
Continue Read's own behaviour is unchanged; taps while a read is in progress are ignored.

## Why this is a gesture change and not a new button

016 made ▶ Read the stepper: one press read one sentence and left the *next* sentence highlighted. 032
removes the button itself: the tap that picks a sentence is now also the read command, so the page needs
one fewer control and one fewer press per sentence. What stays is everything the reader already relies on —
the highlight, the follow, Pause/Resume/Stop, and ⏭ Continue Read — with two deliberate changes: a finished
single-unit read leaves its highlight in place instead of advancing it, and Continue Read wraps to the
first sentence instead of ending at the last one.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tap a sentence, hear it (Priority: P1)

A reader browsing a text taps any sentence and hears exactly that sentence read aloud, with the sentence
highlighted while it speaks and still highlighted when it ends. Tapping the same sentence again repeats the
read; tapping a different sentence reads that one instead. Long-pressing selects and reads a whole paragraph.

**Why this priority**: it is the requested behaviour and the whole point of removing the button — the tap
that used to only highlight now does the reader's whole gesture.

**Independent Test**: open a three-sentence content, tap the second sentence: only that sentence is spoken,
the app stops, and the second sentence stays highlighted. Tap it again: the same sentence is spoken again.
Long-press a paragraph: the whole paragraph is spoken and stays highlighted.

**Acceptance Scenarios**:

1. **Given** a content of three sentences and nothing highlighted, **When** the reader taps the second
   sentence, **Then** the second sentence is highlighted, brought into view, and read; the app stops and the
   second sentence **remains highlighted** — no next sentence is auto-highlighted.
2. **Given** the second sentence highlighted after its read, **When** the reader taps it again, **Then** the
   second sentence is read again.
3. **Given** the second sentence highlighted, **When** the reader taps the third sentence, **Then** the third
   sentence is highlighted and read instead.
4. **Given** a paragraph of several sentences, **When** the reader long-presses inside it, **Then** the whole
   paragraph is highlighted and read, and the paragraph highlight remains afterwards.
5. **Given** a sentence that carries a comment with comments being read, **When** the reader taps it, **Then**
   the sentence and its comment are read in one go (015 unchanged).

---

### User Story 2 - Continue Read loops the content (Priority: P1)

A reader who wants to hear the rest of the text presses ⏭ Continue Read. It reads from the anchored
position to the end — highlighting each spoken sentence as today — and when the last sentence finishes it
continues from the first sentence, looping until the reader presses Pause or Stop.

**Why this priority**: it is the second half of the request and it changes an invariant ("a read ends at the
end of the text") that every earlier spec assumed.

**Independent Test**: on a two-sentence content, press ⏭ Continue Read: both sentences are spoken in order,
then the first sentence is spoken again, then the second — the read never stops on its own. Press Stop: the
read ends, the highlight and position clear, and nothing resumes.

**Acceptance Scenarios**:

1. **Given** nothing highlighted, **When** ⏭ Continue Read is pressed, **Then** it reads from the first
   sentence (010 FR-005 unchanged).
2. **Given** the second sentence was just tap-read, **When** ⏭ Continue Read is pressed, **Then** it reads
   from the **third** sentence to the end — the just-read sentence is not repeated.
3. **Given** ⏭ Continue Read reached the last sentence, **When** that sentence ends, **Then** the read
   continues from the first sentence without any further press.
4. **Given** ⏭ Continue Read is looping, **When** the reader presses Pause and later Resume, **Then** the
   interrupted sentence repeats and the loop continues; when the resumed read reaches the end it wraps again.
5. **Given** ⏭ Continue Read is looping, **When** the reader presses Stop, **Then** the read ends, the
   highlight and the position are cleared, and nothing restarts.

---

### User Story 3 - The rest of the page is unchanged (Priority: P2)

The toolbar loses the Read button and gains nothing: Continue Read, Pause/Resume, Stop, Edit, the video
actions, and every other control behave exactly as before. A tap or long-press while a read is speaking or
parked still does nothing.

**Why this priority**: the request is a surgical change to one gesture; regressions elsewhere are the main
risk.

**Independent Test**: walk every toolbar control and every read state on a device and confirm each behaves
as its own spec describes.

**Acceptance Scenarios**:

1. **Given** a read is speaking, **When** the reader taps the text, **Then** nothing happens — the read is
   not interrupted and the position does not move (011 FR-025 unchanged).
2. **Given** a read is paused, **When** the reader taps the text, **Then** nothing happens.
3. **Given** the reader is in EDIT mode, **When** they tap the text, **Then** the editor's own selection and
   editing behave normally — the read gesture does not fire.

---

### Edge Cases

- **Tap the last sentence, then ⏭**: the just-read last sentence has no next step, so the position clears and
  ⏭ reads from the first sentence — the same place the wrap would take it.
- **A paragraph whose last sentence was tap-read inside a longer paragraph**: n/a — a tap resolves a sentence,
  a long-press resolves the paragraph; each anchors the step after its own unit.
- **Empty text**: a tap resolves to an empty range; the read finds nothing and shows the existing
  "nothing left to read" message.
- **A step read interrupted by Pause then resumed**: the resumed sentence ends, the highlight stays on it,
  and the position still points at the next step (016 FR-010's parked-step rule, narrowed the same way).
- **Stop mid-wrap**: the wrap must not restart after Stop — the reader's Stop is final for that read.
- **Very long content (paged units)**: Pause and Stop must be honoured between read units, including inside a
  wrap loop — a parked or stopped loop never speaks another unit.
- **Rapid double-tap**: the second tap during a read in flight changes nothing (011 FR-025); during the brief
  voice-resolution window the last tap wins and only one read speaks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Read button MUST be removed from the reading page's controls and its label key retired; no
  read control may remain that reads a selected unit on press.
- **FR-002**: A tap on the reading text MUST resolve the tapped sentence, highlight it, bring it into view,
  and read exactly that sentence (plus its comment when comments are read, per 015), then stop.
- **FR-003**: A long-press MUST resolve the tapped paragraph, highlight it, bring it into view, and read the
  whole paragraph, then stop.
- **FR-004**: When a tap/long-press read ends by itself, the highlight MUST remain on the unit that was read.
  No next sentence or paragraph may be auto-highlighted (amends 016 FR-004 for the tap-to-read path).
- **FR-005**: The Continue Read position after a tap/long-press read MUST point at the first step **after**
  the unit just read, so ⏭ Continue Read resumes from the next unread sentence. When no step follows, the
  position is empty and ⏭ reads from the first sentence.
- **FR-006**: Tapping or long-pressing the already-highlighted sentence/paragraph MUST repeat its read.
- **FR-007**: ⏭ Continue Read MUST keep its current meaning — read from the position to the end of the text,
  highlighting each spoken sentence — and MUST then continue from the first sentence, looping until Pause or
  Stop. The loop MUST also apply when a paused read is resumed and reaches the end.
- **FR-008**: Pause, Resume and Stop MUST keep their meanings inside the wrap loop: Pause parks the read,
  Resume continues it (and the loop continues after it), Stop ends it for good — highlight and position
  cleared, nothing restarts.
- **FR-009**: A tap or long-press while a read is speaking or paused MUST do nothing (011 FR-025 unchanged).
- **FR-010**: Between units of a paged/segmented read, Pause and Stop MUST be honoured — no further unit may
  be spoken once the reader has parked or stopped the read.
- **FR-011**: No new dependency and no platform change.

### Key Entities

- **The tap-read unit**: a sentence (tap) or a paragraph (long-press), read once, leaving its highlight and
  advancing only the Continue Read position.
- **The wrap position**: the Continue Read anchor; `null` means "from the first sentence", which is also where
  a finished loop restarts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Reading any single sentence requires exactly one tap and zero toolbar presses; the spoken
  output contains only that sentence (plus its comment when enabled).
- **SC-002**: After every tap-read, the highlighted unit on screen is the unit just read — verified on device
  for sentence, paragraph, and last-sentence cases.
- **SC-003**: ⏭ Continue Read on a content of N sentences speaks sentences in order and, without any further
  press, begins again at sentence 1 — observed in the `klhu speak` log as a repeating sequence.
- **SC-004**: Stop during a wrap ends all speech within one sentence; no further `klhu speak` line appears.
- **SC-005**: Every pre-existing reading behaviour (Pause mid-sentence resume, follow/auto-scroll, EDIT,
  video actions, dialogue voices, comments) still passes its own spec's checks.

## Assumptions

- "Tap & hold" means the existing long-press paragraph gesture; tap remains sentence-granular.
- The wrap is unbounded: it repeats until Pause or Stop, including across a pause/resume cycle.
- FR-010's inter-unit guard is fixed as part of this feature because the wrap makes the latent bug reachable
  in normal use; it is a guard, not a redesign of paged reads.
- The Read button's removal includes its localised label key; no replacement control is added.
- Highlight and Continue Read position may now diverge after a tap-read (highlight = last read unit,
  position = next unread step); the "in force together" rule from 010/011 is amended for this path only.

## Out of scope

- Changing what a sentence, paragraph, comment or turn is (segmenter, 015, 014 untouched).
- The video render and its timeline (012): a render still starts from the position the page holds.
- Any new reading control, gesture, or setting.
