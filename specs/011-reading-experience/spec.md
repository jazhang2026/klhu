# Feature Specification: Reading Experience

**Feature Branch**: `011-reading-experience`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "reading page: I like the page to automatically scroll when read out of view, so the highlighted sentence is always visible. contents list: I like to have a '+' icon to add a new content. reading page: I like to preview/select font and character size of the text. App should remember the user's choice."

**Input (amendment, 2026-09-24)**: "have the high light on sentence level to syne with pause/resume." — the
read-tracking highlight becomes the **sentence** being spoken (it was the whole paragraph, 003), so the
highlight, the spoken sentence and the resume point always name the same unit.

**Input (amendment, 2026-09-25)**: "if no highlighted sentence, Read button read whole page from first
sentence. This is duplicated with Continue Read button. Correct action: show warning: select
sentence/paragraph to read." and "with no highlighted content, click Continue Read button, it start
reading from previous highlighted sentence. Correct action: start reading from first sentence. Previous
highlighted history should be removed when high light is gone." — the two read buttons stop sharing one
fallback: ▶ reads a selection and asks for one when there is none, ⏭ keeps its read-from-the-first-
sentence fallback, and 010's position is in force exactly as long as the highlight that shows it
(FR-022/FR-023).

**Input (amendment, 2026-09-25, second pass)**: "tap to select one centence, click ▶: read one sentence.
tap hold to select one paragraph, click ▶: read paragraph. tap/tap hold to select content, click ⏭: read
to the end from the selected. click ⏭ read from first sentence if no high light." — the PAGE gesture
picks the unit (003's tap/long-press), ▶ reads that selection as it stands, and ⏭ reads from it to the
end of the text (FR-024). An earlier reading of this correction — that ▶'s own gesture picked the unit —
was wrong and is not what ships: ▶ has one press.

**Input (amendment, 2026-09-25, third pass)**: "we use single tap to select one sentence. but user may
also use single tap to scroll the content or reactive the screen when it's become dark. On real use, I
interupted the reading many times… I take what you proposed. Cost of step 2: sign off. When it's on
reading(include paused), tap on content should not stop the reading. no status change." — a touch on the
text while a read plays or is parked becomes a no-op, and the page's gestures are recognised only when
the touch was a gesture in its own right (FR-025). This supersedes 010 US1 scenario 5 ("a tap during a
read stops it, then continues from there"), whose `onTapDown` handler fired on the pointer-down — so a
scroll start and a fling-stop tap did it too, which is the interruption the user was hitting.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The page follows the read (Priority: P1)

A read that lasts longer than the screen leaves the listener behind: the yellow highlight advances
with the reading while the page stays where it is, so after the first screenful the sentence being
spoken is out of sight. While a read plays, the page scrolls by itself by just enough to keep the
highlighted sentence on screen, and it brings the sentence into view when a read starts from a
position that is already off-screen (a stored Continue Read position, a resumed read). A text that
fits on screen never moves, and a read that ends never jumps back to the top. The highlight marks the
**sentence** being spoken — never a larger block — so the sentence heard and the sentence seen are
always the same one, pause and resume included.

**Why this priority**: it is the only one of the three that changes the reading itself. The highlight
already ships (003, 010), but a highlight below the fold is worth nothing — without it every sentence
past the first screenful is heard and never seen. It also depends on nothing the other two stories
build.

**Independent Test**: open a text longer than one screen, start a read twice — with no position set
and with a position set far down the text — and watch the viewport: the highlighted sentence is on
screen at every utterance; then play a text that fits on screen and confirm the page never moves.

**Acceptance Scenarios**:

1. **Given** a text longer than the visible area and a read in progress, **When** the sentence being
   spoken is below the visible area, **Then** the page scrolls so that the whole sentence is visible
   before the next sentence is spoken
2. **Given** a stored start position far down a long text, **When** the user taps Continue Read,
   **Then** the page shows that position by the time its first sentence is spoken
3. **Given** a text that fits in the visible area, **When** a read plays from start to end, **Then**
   the page does not scroll at all
4. **Given** a read that has scrolled down the text, **When** the read ends or the user taps Stop,
   **Then** the page stays where it stopped
5. **Given** a read in progress, **When** the user scrolls the page by hand, **Then** the page stays
   where the user put it until the highlight moves to a different sentence
6. **Given** a sentence taller than the visible area, **When** it is spoken, **Then** the page keeps
   the start of that sentence visible (the whole sentence cannot fit on screen)
7. **Given** a read in progress, **When** a sentence is spoken, **Then** the yellow highlight covers
   exactly that sentence — not its whole paragraph — and moves to the next sentence as the read
   advances
8. **Given** a read paused mid-sentence, **When** the user resumes, **Then** the sentence repeated on
   resume is the sentence highlighted while it is spoken (the highlight and the resume point agree)

---

### User Story 2 - The text's typeface and character size, remembered (Priority: P2)

The reader controls how the text itself looks: a larger character size for comfort or eyesight, a
different typeface for a script they find easier to read. They can see the text in a candidate
setting before it is applied, and the app remembers what they chose for the next session.

**Why this priority**: it applies to every reading session and is pure user preference, but reading
works without it — and unlike the "+" shortcut in the contents list it introduces a new remembered
setting, so it is worth its own slice rather than riding along with the list work.

**Independent Test**: open the appearance control, preview and confirm a typeface and a size, see
the reading text change, restart the app, and see the same choice still in force; then leave the
control without confirming and confirm the previous choice survived.

**Acceptance Scenarios**:

1. **Given** the reading page, **When** the user opens the text appearance control, **Then** the
   offered typefaces and sizes are shown with a live preview of the text in the candidate setting
2. **Given** a previewed setting, **When** the user confirms it, **Then** the reading text renders in
   that typeface and size immediately
3. **Given** a confirmed setting, **When** the app is restarted or another content is opened,
   **Then** the text still renders in that typeface and size
4. **Given** a previewed setting, **When** the user leaves the control without confirming, **Then**
   the previous setting stays in force and nothing new is remembered
5. **Given** the largest offered size, **When** the text is displayed, **Then** no line is clipped
   and no line runs off the side of the page
6. **Given** the reading page in edit mode, **When** the user types, **Then** the text they type uses
   the same typeface and size they chose
7. **Given** a read in progress, **When** the user looks for the appearance control, **Then** it is
   not offered until the read is idle

---

### User Story 3 - Add a content from the contents list (Priority: P3)

From the contents list, a "+" control starts something new instead of opening something old: the
reading page opens with a blank editable text, the user writes, and Save creates a new entry in the
library under an auto-generated name.

**Why this priority**: the library can already gain content — open the reading page, Edit, write,
Save creates a new entry (008) — so "+" is a shortcut to a path that already exists rather than new
capability, and it can land last without blocking the other two stories. It is the one story the app
is not worse off without.

**Independent Test**: from the contents list, tap "+", type a sentence, tap Save, and find the new
entry in the list; repeat and leave without saving instead, and find the library unchanged.

**Acceptance Scenarios**:

1. **Given** the contents list, **When** the user taps the "+" control, **Then** the list closes and
   the reading page opens a blank text in edit mode, ready for typing
2. **Given** a new content with text typed, **When** the user taps Save, **Then** an entry is created
   with an auto-generated name (no name prompt) and appears in the contents list
3. **Given** a new content with nothing typed, or only spaces, **When** the user taps Save, **Then**
   the save is refused with the existing message and no entry is created
4. **Given** a new content with text typed, **When** the user leaves without saving, **Then** no entry
   is created and the contents list is unchanged
5. **Given** content was on screen before the "+" was tapped, **When** the new content is left
   unsaved, **Then** that earlier content and its saved state are unchanged

---

### Edge Cases

- A text shorter than the visible area: the page never scrolls during a read
- A sentence taller than the visible area: its beginning is kept visible; the whole sentence cannot fit
- The user scrolls by hand mid-read: the page is not pulled back until the highlight moves to another sentence
- A read ends, or Stop is tapped, after the page scrolled down: the page stays where it stopped
- Save is tapped on a new content holding only whitespace: refused with the existing "nothing to save"
  message; no entry, and no record of an empty content is written
- The remembered appearance names a typeface or size the app no longer offers: the default is used,
  with no error shown
- A typeface that cannot render one of the app's content languages: it must not be offered, so no
  offered setting can produce missing-glyph boxes in English, Simplified Chinese or Spanish
- The app's own chrome (app bar, buttons, dialogs, messages) does not follow the text appearance
- The largest offered size with the longest line in the shipped content: still inside the page
- Stop, or a read that ends on its own: the highlight goes and the position goes with it (FR-022), so the
  next ⏭ Continue Read starts at the first sentence — and ▶ asks for a selection again
- ▶ Read tapped with nothing highlighted: the prompt appears and nothing is spoken; the tap that selects a
  sentence clears the prompt (FR-023)
- ▶ Read held rather than tapped on one of the two buttons: nothing changes — the unit comes from what the
  page selected (a tapped sentence, a long-pressed paragraph), and ⏭ reads from the selection to the end of
  the text either way (FR-024)

## Requirements *(mandatory)*

### Functional Requirements

**The page follows the read**

- **FR-001**: System MUST scroll the reading page automatically so that the sentence being read is
  visible while a read is in progress
- **FR-002**: System MUST bring an off-screen sentence into view when a read starts from it — a
  stored Continue Read position, a resumed read, or any read whose first sentence is below the fold
- **FR-003**: System MUST NOT scroll when the sentence being read is already fully visible
- **FR-004**: System MUST leave the page where the read left it when the read ends, is stopped or is
  paused
- **FR-005**: System MUST NOT undo a manual scroll while the same sentence is being read, and MUST
  follow again from the next sentence
- **FR-020**: System MUST paint the reading highlight on the **sentence** being spoken — advancing
  with each sentence, never covering a neighbouring sentence or the whole paragraph — and MUST keep
  clearing it at the end of a read and on Stop, as today
- **FR-021**: A pause and its resume MUST leave the highlight on the sentence being repeated, so the
  highlighted sentence, the spoken sentence and 010's resume point are always the same unit

**The two read buttons** *(amendment, 2026-09-25)*

- **FR-022**: 010's Continue Read position MUST be in force exactly while the highlight that shows it
  is painted: the gesture that paints the highlight is the one that sets the position, and the position
  MUST be dropped — in memory and on disk — wherever the highlight is cleared (Stop, the end of a read,
  entering EDIT). A read MUST NOT resume from a position whose highlight is gone; with no position in
  force ⏭ reads from the first sentence, as 010 FR-005 requires. This narrows 010 FR-002/FR-004/FR-008:
  a position outlives a restart only while its highlight is up when the app is left.
- **FR-023**: ▶ Read MUST speak the highlighted sentence or paragraph, and MUST NOT read aloud when
  nothing is highlighted: the page asks the user to select a sentence or paragraph instead. Reading the
  text from its first sentence with nothing selected stays ⏭ Continue Read's fallback (010 FR-005,
  kept by FR-022), so no two buttons answer the same tap with the same read.
- **FR-024**: The unit ▶ Read speaks MUST be the unit the page's own gesture selected: a **tap** on the
  text selects its sentence and a **long-press** its paragraph (003, unchanged), and ▶ reads that
  selection as it stands — never a larger block than what is highlighted. ⏭ Continue Read MUST read
  from that selection to the end of the text, for a sentence selection and for a paragraph selection
  alike, and from the first sentence when no selection is in force (FR-022).
- **FR-025**: A touch on the reading text while a read is playing or paused MUST change nothing: it MUST
  NOT stop or pause the read, MUST NOT select a sentence or paragraph, MUST NOT move the Continue Read
  position, and MUST leave the page's controls as they are. A quick tap is also how a user wakes a
  dimmed display and how the page's own fling is stopped, so it cannot be an action on the text; ending
  a read stays with Pause and Stop. The idle gestures keep 003's meanings (tap = sentence, long-press =
  paragraph) and MUST be recognised only when the touch was that gesture in its own right — a touch that
  turns into a scroll MUST NOT select, and MUST NOT stop a read either.

**Text appearance**

- **FR-006**: Users MUST be able to choose the reading text's typeface from the typefaces the app offers
- **FR-007**: Users MUST be able to choose the reading text's character size from the sizes the app offers
- **FR-008**: Users MUST be able to preview a candidate typeface and size on the text before
  confirming it
- **FR-009**: System MUST apply the confirmed typeface and size to the reading text in both reading
  and editing, and MUST NOT apply them to the app's own chrome
- **FR-010**: System MUST remember the confirmed typeface and size across app restarts
- **FR-011**: System MUST fall back to the default appearance, without an error, when the remembered
  choice is malformed or no longer offered
- **FR-012**: The offered sizes MUST keep every line of the text inside the page at the largest
  offered size
- **FR-013**: The offered typefaces MUST render the app's content languages — English, Simplified
  Chinese and Spanish — without missing glyphs
- **FR-014**: System MUST offer the appearance control when the reading page is idle, and MUST NOT
  offer it while a read is playing

**Adding a content**

- **FR-015**: The contents list MUST offer a control that starts a new content
- **FR-016**: System MUST open a blank, editable text for a new content without loading an existing
  content first
- **FR-017**: System MUST create a new library entry with an auto-generated name when a new content is
  saved, with no name prompt
- **FR-018**: System MUST refuse to save an empty or whitespace-only new content with the existing
  message, and MUST create no entry
- **FR-019**: System MUST create no entry when a new content is left without saving, and MUST leave
  the content that was on screen before unchanged

### Key Entities *(include if feature involves data)*

- **ReadingHighlight**: the sentence (or paragraph) currently being spoken — a shipped value (003,
  010) that this feature reads to decide where the page must be. Not new, and not stored.
- **ReadingAppearance**: the remembered typeface and character size of the reading text, per device.
  The only new persisted value in this feature; it has no relationship to any content, so one choice
  covers every text.
- **DraftContent**: the blank, unsaved text a "+" starts. It lives in memory only — no library entry,
  no name and no stored record exists for it until Save succeeds.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: While a text longer than the visible area is read end to end, no sentence is spoken
  while its highlight sits outside the visible area
- **SC-002**: A read started at a position below the visible area shows that position on screen no
  later than its first spoken sentence
- **SC-003**: Reading a text that fits on screen moves the page by zero pixels
- **SC-004**: A reader can see the text in a candidate typeface and size before applying it
- **SC-005**: The chosen typeface and size are in force again after an app restart, and the largest
  offered size clips no line of the shipped content
- **SC-006**: A new content is created from the contents list in one tap plus Save, with no name
  prompt, and appears in the list
- **SC-007**: Leaving a new content unsaved, or saving it empty, adds no entry to the library
- **SC-008**: While a read plays, the highlighted text is exactly the sentence being spoken — checked
  per utterance, including the sentence a resume repeats
- **SC-009**: After a Stop and after a read that ended on its own, ▶ speaks nothing and shows the
  selection prompt while ⏭ starts at the text's first sentence — the same two outcomes as on a page that
  was never tapped (FR-022/FR-023)
- **SC-010**: A tapped sentence and a long-pressed paragraph are each read whole by ▶ and by nothing larger
  than themselves, and ⏭ reads from either selection to the end of the text (FR-023/FR-024)
- **SC-011**: With a read playing or paused, a tap, a long-press and a scroll drag on the text each leave
  the read in the state it was in and the page unchanged — no stop, no selection, no position — and a
  touch that turns into a scroll does not select either (FR-025)

## Assumptions

- The reading page shows one text in a single scrollable area and already paints a highlight while
  reading (003); this feature narrows that highlight from the spoken paragraph to the spoken sentence
  (amendment: FR-020/FR-021) and moves the page to follow it, rather than adding a second highlight.
- The manual selection highlight is unchanged: a tap still selects a sentence and a long-press its
  paragraph (003), and Continue Read still starts the read at that selection — which is the only state
  that holds a position (FR-022).
- Scrolling is animated and short; no reduced-motion setting is in scope for this version.
- The offered typefaces are a small set the app ships or the platform guarantees, each of which
  renders English, Simplified Chinese and Spanish.
- The offered sizes are a small fixed set from smallest to largest rather than a free numeric scale,
  so the largest is guaranteed to keep the text inside the page.
- The appearance is remembered per device, like the shipped voice and language preferences, not per
  content: opening a text in another language keeps the same appearance.
- New content names stay auto-generated from the text (008), so "+" adds no name field and no rename.
- The contents list keeps its shipped flows (open a content, delete with confirmation, empty and
  repaired states); "+" sits beside them.
- The empty-save refusal reuses 008's existing rule and its existing message ("There is nothing to
  save"); this feature adds no new error text.
- The contents list is reached from the reading page while it is idle, so "+" cannot be reached
  during a read — the shipped navigation, unchanged here.
- The reading page's toolbar keeps its shipped actions (Read, Continue Read, Pause/Resume, Stop,
  Edit); the appearance control is added to the page without removing or reordering them, and the page's
  own gestures carry the meanings (FR-024) — a read in flight owns the text, so a touch changes nothing
  until Pause or Stop (FR-025)

## Out of scope

- A per-content appearance: the choice is per device, not stored with the text
- Line spacing, margins, page width, themes, dark mode, or a free-form size slider
- Reduced-motion / animation settings
- Adding content from anywhere but the contents list: no import, file picker, share target or paste
  from another app
- Naming a new content by hand, or renaming an existing one
- Auto-scroll anywhere else: the contents list does not follow anything
- Following the read with the app's chrome (for example a progress indicator or a mini-map)
