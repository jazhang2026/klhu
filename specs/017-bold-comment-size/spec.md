# Feature Specification: A bold face, and a comment one size down

**Feature Branch**: `017-bold-comment-size`

**Created**: 2026-10-12

**Status**: Draft

**Input**: the reader's wish list, `text.txt`, **item 016's own tail** (2026-10-12), quoted verbatim:

    add bold font option in Appearance selection.
    make comment is always one smaller size than the text if possible.

and the same day's chat follow-ups, quoted: **"在 Appearance 选字体时 有一个加粗字体的选项"** — the bold option
is a value in the picker's own **font list**, one more choice beside the faces already offered, not a switch
standing beside the picker; and **"comment 字体要比主字体小一号。有区别。"** — the comment's size must be one step
down **and visibly different**, which is the sentence that settles the smallest-size case below.

When this spec was written the two lines sat at the tail of the list's item **016** and the list's own item
**017** was the markdown item. The reader then edited the list themselves (2026-10-12, after 016's commit
`3db8df5`) so that it now reads:

   017. 1. add bold font option in Appearance selection.
        2. make comment is always one smaller size than the text if possible.

   018. 1. support mark down format. ...

so this directory's number and the list's own now **agree**, the two lines are the item this spec implements,
and the markdown item is **not** this feature's input and is covered by no requirement here (stated again under
Assumptions). Nothing about the feature changed with the renumbering: it is the same two lines, moved.

**And the shape of the bold option, settled the same day by the reader's own answer**, quoted —
**"选 A，不好的没必要做"**: the option is **one more entry in the font list** — the default family, in bold — and
the shapes that would sell a **synthesised** bold are declined rather than built, because on the device this app
was walked on only the default family has a real bold face for the text the reader reads. Decision 1 carries the
evidence; the alternatives it names were considered and refused, not overlooked.

*(**Both of those lines were settled again the same day.** The reader's answer of 2026-10-12 — quoted, **"形状
1。就这样。"** — extends the bold to **every** offered face: six values, `default`, `bold`, `serif`, `serif-bold`,
`mono`, `mono-bold`, in that order, with those names. It was given **after** the probe of the same day measured
what the platform actually does where no bold face ships, so it **supersedes** decision 1's "the default family
only" and this paragraph's "no `serif`-bold, no `mono`-bold". What still stands from decision 1 is its **shape**:
values of the existing `typeface` field rather than a switch, and the record's grammar untouched. The shape
refused in this second answer, with the cost it was put to the reader with, is recorded in decision 5.)*

## What this changes in the features that are already shipped

Neither change is a new screen or a new button; both land inside features that are already walked and green, and
each one edits a rule those features hold:

- **The bold faces** are three more values — a fourth, fifth and sixth — of 011's own `typeface` field. Its
  contract
  (`specs/011-reading-experience/contracts/appearance-format.md`) enumerates the three faces that exist and the
  read rules around them, so this feature **amends that contract** (the value table, the family table, read rule
  2's "one of the three names", and the round-trip and fallback cases) rather than inventing a second store. The
  record's grammar `<typeface>||<size>` is **unchanged**, and a record written by the shipped app still loads.
- **The comment's size** is a rule about how 015's comment is **painted**, in the two places it is painted: the
  page (015 FR-012) and a video frame (015 FR-013). This feature amends those two rules with a dated note and
  re-takes the measurements 015 took of a block's own ink, because a smaller comment line changes them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A bold face in the font list (Priority: P1)

A reader opens the appearance control, sees the faces on offer, and finds a bold one among them. They pick it and
the preview above the list shows the text in bold — in the candidate size they have chosen — and only then do
they apply it. From that moment the reading text is painted bold, on the page and in the videos they render, and
it is still bold after they restart the app.

**Why this priority**: it is the first of the two asks, it touches no other feature's behaviour, and everything
it needs already exists — a picker, a preview, a remembered record, a style the page and the video share.

**Independent Test**: open the appearance control, pick the bold face, apply it, and read the text: the reading
text is bold on the page; render a video of the same text and a frame of it is bold; force-stop and relaunch and
the text is still bold.

**Acceptance Scenarios**:

1. **Given** the appearance control is open, **When** the reader looks at the font list, **Then** a **bold** face
   is offered beside `default`, `serif` and `mono`, and the preview shows it before it is applied.
2. **Given** the bold face is applied, **When** the reading page paints the text, **Then** the text is painted in
   the bold weight of the face's own family.
3. **Given** the bold face is in force, **When** the app is force-stopped and relaunched, **Then** the text is
   bold again — the same record, the same grammar, one more value in it (011 SC-005).
4. **Given** a record written before this feature (`serif||xlarge`), **When** the app starts, **Then** that
   appearance is in force and nothing falls back — `bold` is a new value, not a new field.
5. **Given** the bold face at the largest offered size is in force, **When** the text is read to its end, **Then**
   every line is inside the page (011 FR-012, re-measured for this face rather than assumed).

### User Story 2 - A comment reads as a note, not as text (Priority: P2)

The reader is looking at a text where a foreign sentence is followed by its translation, marked as a comment. The
translation is there to be read, but it must not compete with the text: it is painted one size smaller than the
text it belongs to — always, at every offered size, in the video as well as on the page — while the text's own
layout, its highlight and its taps behave exactly as they did.

**Why this priority**: it is the second ask, and it is the one that moves measurements another feature holds, so
it is the one that must not be allowed to change anything except the paint.

**Independent Test**: with each of the four offered text sizes in force, screenshot the page and measure the
comment's own characters against the text's; do the same on one frame of a rendered video; then tap a point inside
a comment and confirm it selects the sentence it selected before this change.

**Acceptance Scenarios**:

1. **Given** a text at `medium` whose second sentence carries a comment, **When** the page is painted, **Then**
   the comment's own characters are painted at the next size down (`small`) and the text's own characters are not
   touched.
2. **Given** the same text at `small` — the smallest offered size — **When** the page is painted, **Then** the
   comment is still **visibly smaller** than the text: its size falls below the smallest offered size, to the
   derived size this spec fixes, because the reader asked for a difference and no size below `small` is offered.
3. **Given** a video of that text, **When** a frame painting the sentence is examined, **Then** the comment's
   characters in that frame are smaller than the sentence's (015 FR-013, amended).
4. **Given** the same text, **When** a point inside the comment is tapped, **Then** the same sentence is selected
   as before this change, and a step's range and the highlight's boundaries are the same (015 FR-012; this
   feature is a paint change and nothing else).
5. **Given** a content whose sentences carry no comment, **When** it is painted, **Then** it paints exactly what
   it painted before this feature — the no-regression rule 015 took for a content with no tag (015 SC-004).

### Edge Cases

- **The text at the smallest offered size**: there is no offered size below `small`, so "one smaller" has to be
  derived. The comment goes to the derived size this spec fixes (decision 2) and the rule is that the difference
  must be **visible**, not merely present in the code.
- **The comment's own legibility floor**: the derived value is the smallest size the app will paint a comment at,
  at the smallest offered text size; nothing in this feature paints text below it. (Why it is not zero: a comment
  nobody can read is a comment the reader has turned off with their eyes.)
- **A comment in a language whose glyphs the family falls back for** (`[注]` inside a Spanish sentence): the
  fallback family is asked for the same derived size — 015 FR-008's per-comment language rule is untouched.
- **A sentence and its comment at the largest size in a video frame**: the block's own lines and its ink box
  change (015's row 22 holds `(208, 864, 456, 964)` for its own fixture); the change is measured, not assumed,
  and that row's numbers are re-taken.
- **The bold face and the comment's derived size together**: the comment is not made bold by the face — the bold
  face is the text's own weight; a comment keeps the weight it is painted with today.
- **A face name the app does not offer** (`Helvetica||xlarge`, a hand-edited file, a name from a future build):
  that field falls back on its own — 011's read rule 2, with `bold` added to the list of names that do not fall
  back.
- **A Chinese sentence under any bold face**: the device ships no bold face for CJK (only `NotoSansCJK-Regular`
  and `NotoSerifCJK-Regular`), so a Chinese word is painted by the **fallback** face with its weight
  **synthesised** by the platform. Measured on 2026-10-12 (see `research.md`'s environment table): the synthesis
  is substantial rather than nominal — Chinese ink +51% at 30 pt and +64% at the app's own 14 pt, against the
  shipped real bold's Latin +47% — and it is the same paint whatever family is asked for: `mono-bold`'s Chinese
  is **pixel-identical** to `bold`'s. The reader saw those numbers and the probe's pictures and answered with
  decision 5; FR-005 still holds, and the walk's own screenshot remains the receipt for what it looks like.
- **The appearance control while a read is playing**: it is not offered (011's own idle-only rule, unchanged), so
  neither new
  value can be applied mid-read.

## Requirements *(mandatory)*

### Functional Requirements

**The bold face (US1)**

- **FR-001**: The appearance control's font list MUST offer **six** faces — `default`, `bold`, `serif`, `serif-bold`,
  `mono`, `mono-bold`, in that order —
  selectable and previewable the same way the existing faces are.
- **FR-002**: While a bold face is in force, the reading text MUST be painted in that face's family at weight
  700 — on the page **and** in a rendered video, which paints the reading style.
- **FR-003**: The bold face MUST be shown in the control's own preview before it is applied, in the candidate size
  the reader has picked (011 SC-004, for the new face).
- **FR-004**: The bold face MUST be remembered and restored across a restart exactly as the existing faces are,
  and the record's own grammar MUST NOT change: `bold`, `serif-bold` and `mono-bold` are three more values of the
  existing `typeface` field, so a
  record written before this feature still loads and one written after it still reads in the shipped app's own
  shape (011 SC-005, its contract amended).
- **FR-005**: Each bold face MUST render the app's content languages — English, Simplified Chinese and Spanish —
  without missing glyphs (011 FR-013).
- **FR-006**: Each bold face at the largest offered size MUST keep every line of the text inside the page (011
  FR-012). Bold is wider than regular, so this is **measured again for each of the three**, and the measurement
  replaces the one 011 holds.

**The comment's size (US2)**

- **FR-007**: The reading page MUST paint a comment's own characters one offered size below the reading text's
  size, and MUST NOT change any other paint of them (015 FR-012, amended: its elision rule is unchanged, and only
  the size is added).
- **FR-008**: A video frame that paints a sentence with its comment MUST paint the comment's characters one
  offered size below the sentence's, in the same relationship the page uses (015 FR-013, amended).
- **FR-009**: At the smallest offered text size the comment MUST still be painted visibly smaller than the text,
  falling to the derived size this spec fixes — no smaller offered size exists, and the reader's ask is a visible
  difference, not a nominal one.
- **FR-010**: The comment's smaller size MUST change **no offset**: the content's own characters, the display
  mapping, the highlight's boundaries, a tap's resolution, a step's range and the comment's own reading cut MUST
  all be exactly what they were before this feature (015 FR-012's mapping, 010's positions, 016's steps).
- **FR-011**: A content whose sentences carry no comment MUST be painted exactly as it was painted before this
  feature — the no-regression rule 015 took for its own change (015 SC-004).
- **FR-012**: The appearance control MUST NOT gain a comment-size picker: the relationship is **derived** from the
  text's own size, which is the ask; the control's own shape stays two rows (face, size).
- **FR-013**: This feature MUST NOT add a dependency and MUST NOT use the network (015's own no-dependency rule,
  kept).

### Key Entities *(include if feature involves data)*

- **ReadingTypeface**: the offered face of the reading text — a shipped value (011 US2) that gains three values,
  `bold`, `serif-bold` and `mono-bold` (its `default`, `serif` and `mono` in weight 700). Stored in the existing
  record's first field; the *only* new values this feature persists.
- **ReadingSize**: the offered character size — a shipped value that does **not** change: the comment's size is
  *derived* from it (the next size down, and a fixed value below the smallest), never stored and never offered.
- **Comment**: 015's entity, unchanged in storage, in the content and in the read. What changes is only the size
  it is painted at, in the two places it is painted.
- **ReadingAppearance**: the remembered face and size — unchanged in shape (`<typeface>||<size>`) and unchanged
  in what it means; `bold` is a value it can now hold.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader can see the text in the bold face **before** applying it, and after applying it no restart
  is needed for the reading text to be bold.
- **SC-002**: After a restart each of the three bold faces is still in force, and at the largest offered size no
  line of the shipped content is clipped — measured on the device, replacing 011's own measurement for the new
  faces.
- **SC-003**: With each of the four offered text sizes in force, a comment's own characters measure **smaller**
  than the text's — including at the smallest offered size, where the comparison is against the derived value this
  spec fixes. Measured, not eyeballed: the sizes are read off a painted page and a video frame.
- **SC-004**: A tap on the same point of a text with comments selects the same sentence before and after this
  change, and a step reads the same range — the paint changed, the offsets did not.
- **SC-005**: In one rendered video of a text with a comment, the comment's characters measure smaller than its
  sentence's, in the frame that paints them (015's own frame receipt, re-measured).
- **SC-006**: The feature adds no dependency and makes no network call (the structural receipt 012 already has).

## Assumptions

- Both changes are read as **small, contained edits to shipped behaviour**: no new screen, no new control beyond
  three more entries in the font list, no new stored value beyond three more face names.
- "One size smaller" reads as **the next size the app offers**, not a fixed ratio: `xlarge`→`large`,
  `large`→`medium`, `medium`→`small`, and below `small` at the fixed derived value decision 2 names.
- The reader's own word settled that the bold option is a **font-list entry** rather than a switch beside the
  picker (both answers agree on that shape), and their second answer of 2026-10-12 settled **which faces it
  covers**: all three, in six values — after the probe showed what the platform's synthesis actually does where no
  bold face ships, and after their eyes accepted it. A synthesised bold is therefore **offered, knowingly**, for
  `mono-bold` and for every Chinese word (decision 5); what is still declined is the switch, and any face or
  family name beyond the six.
- The comment is painted in the video as well as on the page (015 FR-013 already puts it in the frame), so the
  relationship is stated for both and measured in both.
- The list's markdown item is **not** this feature's input: it carried the number 017 when this spec was first
  written, and the reader's own edit of 2026-10-12 renumbered it to **018**, making these two changes item **017**
  — the same number this directory already had. It keeps its content and is owed 018 when it is specified.

## Out of scope

- Markdown of any kind: the wish list's own item 017, a separate feature.
- A weight **toggle** beside the three faces: the alternative put to the reader on 2026-10-12 and **refused**,
  because it costs the record a third field (011's "exactly two non-empty parts" rule, its three-parts-are-malformed
  case and the control's own height) for the coverage the six names already give.
- Any *new* family or face name beyond the six, and any bold faked outside the platform's own fallback rule.
- A reader-facing comment-size picker, or any second size dimension in the appearance control (FR-012).
- The comment's tag spellings, its own voice, its read/not-read setting, and the stored reading position: all
  015's and 016's, all untouched.
- Any change to the content's own characters, in the file or in the editor.

## Decisions this spec takes, and the alternatives

1. **Bold as a face, not as a switch — the reader's own choice of 2026-10-12** (*"选 A，不好的没必要做"*), taken
   after the device's own faces were checked. `bold` is a fourth value of `typeface`: one enum value, one ARB
   label, one weight at the paint, and **no new field in the record** — the cheapest shape, and the only one that
   offers a bold this app can actually paint.

   **What the walked device (API 36 emulator) actually holds** — read from `/system/fonts` and
   `/system/etc/fonts.xml`, not assumed:

   | family | a real bold face on the device | what bold would be |
   |---|---|---|
   | `sans-serif` (the default) | yes — `Roboto` as a variable font, its `wght` axis instanced up to 900 | **painted** |
   | `serif` | yes for Latin (`NotoSerif-Bold.ttf`, a `weight="700"` entry, and a `serif-bold` alias) | painted for Latin; **synthesised** for CJK (only `NotoSerifCJK-Regular.ttc` ships) |
   | `monospace` | **no** — `DroidSansMono.ttf`, the family's only entry, is `weight="400"` | **synthesised** in every script |
   | any CJK face | **none** — `NotoSansCJK-Regular.ttc` / `NotoSerifCJK-Regular.ttc` are the only ones | **synthesised** |

   **The alternatives, named and refused:** a weight **toggle** would give three faces × two weights, at the price
   of a third row in the control **and** a third field in the record's grammar (which would also change 011's read
   rules and its "three parts is malformed" case); a list of **six names** (`default / serif / mono / Bold /
   Serif Bold / Mono Bold`) reaches the same coverage with the record's grammar untouched. Both were declined on
   the evidence above rather than on taste: two thirds of what they would offer is a **synthesised** bold, and a
   reader who picks *Bold* should get a face, not a smear. `mono` is refused outright — the device has no bold
   face for it in any script. The cost is stated plainly: a reader who wants `serif` in bold cannot have it in
   this shape, and the bold Chinese word is painted by the platform's own synthetic weight (the edge case below,
   and FR-005's glyph coverage still holds). If the reader wants the combinations later, that is a change to this
   decision, not a bug in it.

   *(**Superseded in part, 2026-10-12:** the reader's later answer widened the offered bold from the default
   family to **every** face — decision 5. What stands here is the shape: values of the existing field, not a
   switch, and the grammar untouched.)*
2. **"One smaller" is the next offered size down; below the smallest it is a fixed derived value.** The four sizes
   are 12, 14, 18 and 24 points and their steps are not even, so a ratio would drift: `xlarge`'s comment is 18,
   `large`'s is 14, `medium`'s is 12 — and `small`'s is **10**, derived, because the reader's own sentence demands
   a visible difference and no size below `small` is offered to fall to. The alternative — a fixed ratio such as
   0.85 — gives a smoother look at every size but makes the sizes the app *offers* a fiction (the reader picks 24
   and the comment is 20.4). This spec takes the offered steps.
3. **The relationship is derived, never stored.** A comment's size is computed from the text's size at paint time.
   The alternative — storing a comment size per content or per device — is a second setting nobody asked for, and
   it would go stale the moment the text's own size changed.
4. **The video keeps the same relationship.** The comment is already painted in the frame with its sentence (015
   FR-013), so "one size smaller" is a rule about the frame too. The alternative — page only — would ship a page
   and a video that disagree about the same text, and 015's own row 22 measures the video's block, so the
   disagreement would be visible in a receipt the app already holds.

5. **The reader's answer of 2026-10-12, after the probe: every face gets its bold — and the six-name list is the
   shape.** *"形状 1。就这样。"*: six values of the existing field, ordered by family — `default`, `bold`, `serif`,
   `serif-bold`, `mono`, `mono-bold` — with those stored names. It rests on the probe of the same day, which
   measured what the platform does where no bold face ships: **the Chinese under any bold value is the fallback
   face with the weight synthesised**, the synthesis thickens about as much as the shipped real bold does
   (Chinese +51% ink at 30 pt, +64% at the app's own 14 pt, against the variable Roboto's Latin +47%), and it is
   the same paint whatever family is asked for (`mono-bold`'s Chinese is pixel-identical to `bold`'s). The reader
   saw those numbers and the pictures, which is what withdraws the earlier "bad ones need not be built".

   **The alternative refused with it:** a weight **switch** beside the three faces (3 × 2 combinations), costed as
   the record's **third field** — which moves 011's read rule 1 ("exactly two non-empty parts"), its
   "three parts are malformed" case, and the control's own height — for the same coverage the six names give with
   the record untouched. Also refused: any new family or face name beyond the six, and a comment-size picker
   (FR-012).

   **What it costs, said plainly:** the picker's own row grows from three chips to six; **three** labels replace
   one in the four ARBs (107 → 110, not 108); and the width guarantee (FR-006) is measured once per bold face
   rather than once. *(Corrected 2026-10-12 at the tasks stage: 011's layout case was expected to move and does
   **not** — it drags the list to its end and measures the last option, and the control scrolls, so it runs
   unmodified. The cases that do move are named in `plan.md`'s ripple 10 and in the tests' own rows.)*

