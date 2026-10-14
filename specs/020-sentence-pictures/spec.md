# Feature Specification: Sentences assigned to pictures

**Feature Branch**: `020-sentence-pictures`

**Created**: 2026-10-13

**Status**: Draft

**Input**: The reader's wish list, quoted verbatim:

> 020. Create video function: assign sentences to pictures.
>     display selected pictures from first to last.
>     When a picture is displayed, assign sentences to it.
>     a picture can have 0 or multiple sentences assigned to it.
>     only continuous sentences can be assigned to one picture.
>     sentences assigned must be in order.
>
>     Keep existing function if no assignment is made.

**The number.** `create-new-feature.sh` numbers by counting directories, so it proposes the next free number — this
feature is **020** by the reader's own list (`text.txt`), and its directory is `specs/020-sentence-pictures`.

**What already exists, and what this feature adds.** The video (012) already takes the reader's picked pictures and
walks them over the sentences while it renders: the picture follows the clock, and no reader decision stands between
a sentence and the picture painted under it. This feature adds **the reader's own assignment** — which pictures are
shown, in which order, and which sentences each one carries — and it changes nothing at all when no assignment is
made.

---

**The interface sketch, and what it decides.** `ui-sketch.html` beside this spec draws the video dialog as it is on
the device today (its own strings) and **three layouts** for the assignment pass — (A) one line in the dialog opening
a full-screen assignment page, (B) the runs expanded inside the dialog, (C) assigning after a render. The reader
asked for the sketch before the plan; **which layout is taken is decided, by the reader at the gate (2026-10-13): (A)** — one line in the dialog, opening a
full-screen assignment page. (B) the runs expanded inside the dialog and (C) assigning after a render are the
recorded alternatives. FR-001 fixes *where* the pass lives (the video screen, beside the pick); this is its shape.

## Clarifications

### Session 2026-10-13

Three questions the reader's own words leave open, put to them at the spec gate, with the answers recorded here
rather than in a plan:

1. **What does "0 sentences on a picture" mean on screen?** The reader's words allow it, so the spec has to say
   what the video does with such a picture. **Decided at the gate, by the reader (2026-10-13)**: the picture is **skipped** — *「0 句」图干脆跳过吧，理解成用户不想用*
   — nothing in the video shows it and no sentence is spoken over it. **The alternative recorded** (what the first
   version of this spec took): display it as a still. It was overturned because a still moment nobody asked for
   changes the video's pace, where a skip does not.
2. **What does a sentence with no picture show?** **Decided**: it keeps showing the picture of the sentence before
   it — the picture "stays until the reader says it changes" — so every sentence is still spoken (the read is never
   truncated) and no sentence paints a blank frame. **The alternative recorded**: drop unassigned sentences from the
   video (which would silently shorten the reader's own content, out of the question) or paint a blank frame for
   them (a flicker the reader did not ask for).
3. **Where is the assignment made?** **Decided**: on the video screen, where the pictures are already chosen, in the
   same pass — the reader picks pictures, then assigns sentences to them, then starts the render. **The
   alternative recorded**: a separate screen reached from the content's own menu (a second place to look for one
   decision).

4. **Can a video be changed after it is made, and what happens when the sentences change?** (The reader's own
   question at the gate, 2026-10-13: *"选图，分配句子，生成视频后，视频还能修改吗？句子变了是不是从头开始？"*)
   **Decided**: the assignment is a **stored setting**, not a part of the video — like the pictures themselves. So it
   can be changed at any time, and **every render is a fresh render**: the app never edits a file it has already
   written. Change the assignment and render again to get the new video; the old file is the old video. If the
   content's sentences have changed under an assignment, the assignment is re-read against the sentences as they are
   then — a run that no longer fits is dropped, with the reader told, and the rest stands (the edge cases). **The
   alternative recorded**: edit the rendered video itself (a non-linear editor). That is a different product, and
   this feature's own cost would be paid on every frame; recorded in Out of scope.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The reader assigns sentences to a picture and the video shows it (Priority: P1)

The reader picks three pictures for a content of ten sentences, gives the first picture the first four sentences,
the second the next three, and the third the last three, and starts the render. The video shows picture one while
sentences one to four are spoken, picture two for the next three, picture three for the last three — in that order,
with no picture appearing out of turn.

**Why this priority**: it is the reader's ask in full, and it is the whole visible feature: the assignment decides
what a frame shows, and until it works there is nothing to keep.

**Independent Test**: assign the sentences above, render, and read the renderer's own lines: each of the ten
sentences reports the picture the reader assigned it, and the ten reports are in the reader's order.

**Acceptance Scenarios**:

1. **Given** three picked pictures and a ten-sentence content, **When** the reader assigns 4/3/3 sentences in
   order and renders, **Then** every sentence's frame shows its own picture and the pictures appear first to last.
2. **Given** an assignment, **When** the reader re-renders without changing it, **Then** the same pictures carry the
   same sentences.
3. **Given** an assignment, **When** the reader clears it, **Then** the video is the one 012 produces today (see
   User Story 4).

---

### User Story 2 - Only continuous runs, only in order (Priority: P1)

The reader tries to give the first picture sentences 1, 2 and 5 — the app refuses, because 5 is not continuous with
1 and 2 — and then tries to give it sentences 6 and 7 after the second picture has been given 3 and 4: it refuses
that too, because the sentences must be in order across the pictures.

**Why this priority**: the two constraints are the reader's own words, and they are what makes the assignment a
partition rather than a set of lists — the thing the video's own clock can play.

**Independent Test**: drive the assignment control with both shapes above: the app answers each with the reason
(not continuous; not in order) and the assignment in force does not change.

**Acceptance Scenarios**:

1. **Given** a picture, **When** the reader tries to add a sentence that is not adjacent to the ones it already
   carries, **Then** it is refused and nothing changes.
2. **Given** two pictures with sentences, **When** the reader tries to give the second picture a sentence that
   starts before the first picture's last one, **Then** it is refused and nothing changes.
3. **Given** a picture with a run of sentences, **When** the reader adds the sentence right after the run, **Then**
   it is accepted and the run grows by one.

4. **Given** a picture with a run of sentences, **When** the reader un-assigns the sentence at either end of the run,
   **Then** it is removed and the run stays continuous; **When** the reader tries one in the middle, **Then** it is
   refused with that reason and nothing changes.
5. **Given** the pictures in the pass, **When** the reader drags one to another place, **Then** the pass shows the
   new order and a render walks it (FR-015).

---

### User Story 3 - A skipped picture, and a sentence with no picture (Priority: P2)

The reader leaves the second picture with no sentences and never assigns anything to the last two sentences. The
video never shows the second picture at all, and the last two sentences are spoken over the third picture — the
one before them — rather than over a blank frame.

**Why this priority**: the reader's words allow 0 sentences per picture, and this is where the video's own rules
have to be stated; it is P2 because the feature is already useful without it.

**Independent Test**: render the assignment above and read the renderer's own lines: no slot names the second
picture, and the last two sentences report the third picture.

**Acceptance Scenarios**:

1. **Given** a picture with no sentences, **When** the video renders, **Then** that picture is shown nowhere in
   it, and no frame paints it.
2. **Given** sentences the reader never assigned, **When** the video renders, **Then** they are spoken over the
   picture of the sentence before them, and no frame is blank.
3. **Given** the reader assigns a picture nothing, **When** the video renders, **Then** that picture is skipped and the video's length is the sentences' own.

---

### User Story 4 - With no assignment the video is the one 012 ships (Priority: P1)

The reader opens the video screen, picks pictures, assigns nothing, and starts the render. The video is the one they
would have got before this feature existed — same pictures, same order, same timing, same audio.

**Why this priority**: it is the reader's own last line (*"Keep existing function if no assignment is made"*), and it
is what makes this feature safe to ship to a reader who never touches the new control.

**Independent Test**: render one content with pictures chosen and no assignment, and compare the result with 012's own
device row for the same content and pictures: the frame counts, the durations and the renderer's lines agree.

**Acceptance Scenarios**:

1. **Given** picked pictures and no assignment, **When** the video renders, **Then** nothing about it differs from
   012's behaviour for the same inputs.
2. **Given** no pictures chosen at all, **When** the video renders, **Then** it is the text-only video of today.
3. **Given** an assignment that the reader then discards before rendering, **When** the render starts, **Then** the
   video is again the unassigned one.

---
### User Story 5 - A content that changed is caught before the render, and the prompt leads to the fix (Priority: P2)

The reader assigned sentences to three pictures last week, then edited the content: it now has two fewer sentences.
When they open the video screen and start a render, the app tells them before the render begins which sentences the
assignment no longer fits, and the telling is a thing they can tap: it opens the assignment page on the picture that
no longer fits, and they fix it there rather than hunting for it.

**Why this priority**: it is the reader's own refinement at the gate (*"句子变了，渲染前提示，可以点击进入改分配"*), and
it is what keeps a stale assignment from quietly producing a video nobody chose.

**Independent Test**: assign a run, edit the content so the run no longer fits, open the video screen and start a
render: the warning comes before the render's own line, it names the sentences involved, and tapping it opens the
assignment page with that picture in view; rendering anyway drops the run and keeps the rest.

**Acceptance Scenarios**:

1. **Given** an assignment a content edit has invalidated, **When** the reader starts a render, **Then** the warning
   appears before the render begins and names what no longer fits.
2. **Given** that warning, **When** the reader taps it, **Then** the assignment page opens with the offending
   picture in view, and the reader can fix the run there.
3. **Given** that warning, **When** the reader starts the render without changing anything, **Then** the runs that no
   longer fit are dropped and the rest of the assignment stands.


- **More pictures than sentences**: a content of two sentences with five pictures — the three pictures left
  unassigned are skipped (FR-007) and the reader may also give one picture both sentences. The app must not refuse
  the extra pictures, and it must not invent sentences for them.
- **More sentences than pictures**: ten sentences, one picture — the single picture may carry all ten (one run), or
  the reader may leave the tail unassigned, in which case FR-006's fallback needs a picture after it that has
  nothing assigned; with none, the tail stays on the last assigned picture (no picture is invented).
- **A content whose sentence list changes**: the reader edits the text after assigning. The assignment is read
  against the sentences as they are at render time; a run that no longer fits the content is not silently applied to
  other sentences — the reader is warned **before** the render, the warning opens the assignment page on that
  picture (FR-014), and rendering anyway drops the run and keeps the rest.
- **One sentence, one picture**: the smallest assignment there is; the video shows that picture for that one
  sentence and nothing else changes.
- **A picture the reader assigns twice**: impossible by construction — a sentence belongs to at most one picture
  (the order rule), and a second attempt is User Story 2's refusal, not a merge.
- **Reordering the pictures**: the reader's own words say *"display selected pictures from first to last"*; whether
  the order is the picking order or one the reader chooses is the plan's decision, and the spec requires only that
  the order be visible to the reader before they assign.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The video screen MUST offer an assignment pass beside the picture pick, before the render starts.
- **FR-002**: The assignment pass MUST show the content's sentences in order and the picked pictures in their
  display order, with each picture's own sentences visible.
- **FR-003**: A picture MUST be able to hold **0 or more** sentences, and every sentence it holds MUST be
  **continuous** with the ones it already holds.
- **FR-004**: Sentences MUST be assigned **in order**: no picture may hold a sentence that starts before a sentence
  already held by an earlier picture.
- **FR-005**: A sentence MUST belong to at most one picture.
- **FR-006**: The render MUST paint, for each sentence, the picture the reader assigned it; a sentence with no
assignment MUST keep the picture of the sentence before it, and the first sentence MUST paint the first picture.
**The fallback, refined by the reader at the gate (2026-10-13)**: when the sentences *after* the last assigned one
are unassigned **and** pictures with nothing assigned remain after it, those pictures take those sentences by
012's own even split (`buildPictureSchedule`) — *"沿用现在的方法：平均分配句子给没有句子的图"* — so an unassigned
tail is not one long hold on the last assigned picture.
- **FR-007**: A picture with no sentences MUST be **skipped** — no frame paints it and no sentence is spoken over
it — **unless** FR-006's fallback gives it sentences, in which case it is displayed with them. (The reader's own
answer at the gate, 2026-10-13; the fallback is the same reader's refinement of the same day.)
- **FR-008**: The read MUST never be truncated: every sentence of the content is still spoken, whether or not it was
  assigned.
- **FR-009**: With no assignment in force, the render MUST produce exactly what 012 produces today for the same
  content and pictures.
- **FR-010**: The assignment MUST survive leaving and reopening the video screen, and MUST survive a relaunch, as
  the pictures themselves do today.
- **FR-011**: The assignment MUST be the reader's own: no rule of this feature may assign a sentence to a picture
  the reader did not.
- **FR-012**: The refusals of User Story 2 MUST be told to the reader (which rule was broken), and MUST leave the
  assignment in force untouched.
- **FR-013**: The assignment MUST be a stored setting of the content, not a part of any rendered file: a render is
  always rendered fresh from the setting in force, and the app MUST never edit a video already written.
- **FR-014**: When the content's sentences have changed under an assignment, the app MUST warn the reader **before
the render starts**, naming what no longer fits, and the warning MUST be **tappable** — it opens the assignment
page with the offending picture in view, so the reader can fix it there and then. The reader may also start the
render without changing anything, in which case the runs that no longer fit are dropped (with the warning naming
them) and the runs that still fit stand (FR-011: nothing is assigned the reader did not assign).
- **FR-015**: Only a picture with **nothing assigned** may be reordered — by dragging it in the pass — and the
  render MUST walk the order the pass shows. A picture **carrying sentences MUST refuse the drag** (with the reason,
  FR-012) until its sentences are un-assigned (FR-016), and so MUST a picture FR-006's fallback feeds, because moving
  it would change which pictures the unassigned tail falls to. Moving an unassigned picture MUST NOT disturb any
  other picture's sentences: it holds none. (The reader's own rule at the gate, 2026-10-13: *"只有没分配到句子的图能改
  顺序。分配了句子图的不能改顺序。必须等分配的句子解除后才可以改顺序"*.)
- **FR-016**: A sentence already assigned to a picture MUST be un-assignable there. A sentence at either **end** of
  its picture's run is always removable; one in the **middle** MUST be refused with the reason (removing it would
  leave that picture's sentences non-continuous, FR-003), and the assignment in force MUST not change (FR-012).

### Key Entities

- **Picture assignment**: one picked picture plus the run of sentences it carries (possibly empty), and its place in
  the display order.
- **Assignment set**: the reader's pictures in display order with their runs — the whole of what the reader decided,
  and the only input this feature adds to a render.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With an assignment of N runs over M sentences, **every** sentence's own frame shows the picture its
  run names, and the renderer's own lines show the pictures first to last — measured on the device, one row.
- **SC-002**: The two refusals of User Story 2 are answered, with their reason, in every attempt — and the
  assignment in force is unchanged afterwards.
- **SC-003**: With no assignment, one content and one picture set render **identically** to 012's own device row for
  the same inputs (frame counts, durations, the renderer's lines).
- **SC-004**: A picture with no sentences appears in the video and no utterance is spoken over it.
- **SC-005**: The rendered video's audio is the content's own: the same utterances, in the same order, for the same
  total duration, with and without an assignment.
- **SC-006**: An assignment survives the app being stopped and relaunched, read back from the app's own stores.

---
- **SC-007**: The assignment survives a render and a relaunch and can be changed afterwards; a second render with a
  changed assignment produces a video whose frames differ from the first exactly where the assignment differs, and
  the first file is untouched.
- **SC-008**: A content edit that invalidates an assignment produces a warning **before** the render's own line,
  naming the sentences involved, and tapping it reaches the offending picture's assignment in one gesture —
  measured on the device, one row.
- **SC-009**: Dragging an unassigned picture changes the order the render walks, read off the renderer's own
  `pictures=… ranges=…` line, and no other picture's range moves.
- **SC-010**: A picture holding sentences refuses the drag, with the reason, and the order in force is unchanged;
  once its sentences are un-assigned it moves.


## Assumptions

- The pictures themselves, their picking, their holding and their copying are 012's, unchanged.
- The sentences are the ones the video already names (a paragraph's sentences, comments included as they are
  today); this feature assigns existing sentences and creates none.
- A render is the reader's own: the assignment is read at render time, and a render in flight is not changed by an
  edit made during it.
- The assignment is per content, as the pictures are (012's `RoleSettings` precedent for a per-content store).

## Out of scope

- Any change to how pictures are chosen, cropped, toned or copied.
- Any change to the sentences, the read, the voices or the audio pipeline.
- Picture-per-sentence transitions, animation between pictures, or effects (this feature decides *which* picture,
  never how the change is painted).
- Assigning pictures to a *step* or a *paragraph* rather than a sentence (the reader's words are sentences).
- Reordering the sentences themselves; the assignment follows the content's order, it never changes it.
- Editing a video that has already been written (a non-linear editor, cutting, re-ordering or patching a rendered
  file): this feature renders, it never edits a file it has produced.

## Decisions this spec takes, and the alternatives

| decision | alternative, and why not |
|---|---|
| An unassigned picture is **skipped** (FR-007) | **Display it as a still**: this spec's first version took it, and the reader overturned it at the gate. |
| A sentence with no picture keeps the previous picture (FR-006) | **Drop it from the video**: silently shortens the reader's content. **Paint a blank frame**: a flicker nobody asked for. |
| The assignment lives on the video screen, beside the pick (FR-001) | **A separate screen**: a second place to look for one decision, and the picker's own state would have to be carried there. |
| The refusals name the rule broken (FR-012) | **Silently ignore the attempt**: the reader cannot tell a refusal from a lost tap. |
| Contiguity and order are enforced at assignment time (FR-003/FR-004) | **Accept any shape and normalise it at render time**: the video would show something the reader never chose. |
| The pass's shape is **(A)**: a line in the dialog, opening a full-screen page (the sketch) | **Expand the runs inside the dialog** (B): it scrolls into a wall of sentences on a phone. **Assign after a render** (C): the first render is always the unassigned one, which is backwards. |
| A stale assignment is warned about **before** the render (FR-014) | **Warn after it, in the render's result**: the reader would get a video they did not choose and find out afterwards. **Silently drop it**: the reader's work disappears with no telling. |
| An unassigned **tail** falls back to 012's even split (FR-006) | **Hold it on the last assigned picture**: the reader assigned nothing there, so the tail is theirs, not the last picture's — and the refined rule is what the reader asked for by name (2026-10-13). |
| A picture with nothing assigned is skipped **unless the fallback feeds it** (FR-007) | **Always skip it**: it would make the fallback impossible. **Always show it**: a still nobody asked for, already overturned. |
| Un-assigning a **middle** sentence is refused (FR-016) | **Allow it and split the picture's run in two**: two runs on one picture is what the reader's own "only continuous" rule forbids. |
| **Only a picture with nothing assigned** is draggable (FR-015) | **Drag any picture and re-point the runs on drop**: the reader's sentences would be silently re-ordered by a gesture about pictures. **Rely on 012's `movePicture` elsewhere**: a second place to change the order is a second place to be wrong. |