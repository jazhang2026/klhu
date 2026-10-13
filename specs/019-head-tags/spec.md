# Feature Specification: Head tags (`#` a title, `##` a subtitle)

**Feature Branch**: `019-head-tags`

**Created**: 2026-10-12

**Status**: Draft

**Input**: The reader's wish list carries the withdrawn item this feature is the remnant of. Quoted verbatim
from `text.txt` (item 018, and the dated note under it):

> 018（old）. 1. support mark down format.
>     include mark down tags in the text. reading and video display should support mark down format.
>     (2026-10-12 撤回：分析后不做。结构那一半（标题/列表/表格）与 app 已有的段/行结构重复建设；
>     而「永不画、永不读的字符」与逐句切分相冲突（URL/代码里的句末符会在标记内部切句）；
>     只有「强调(粗/斜)」一处是真缺口，将来若要做，只做那一块 ≈ 三分之一成本。)

The list's own line is quoted **as it now stands**: the reader marked its own number `（old）` in `text.txt`
themselves after the withdrawal, and the first pass of this spec quoted the earlier spelling — corrected here on
2026-10-12 and substring-checked again, line by line, against the file.

That item was **withdrawn on 2026-10-12** after the analysis it names, and **its markdown structure half is not this
feature's input**: emphasis, lists, links, inline code, tables, images, fenced code, thematic breaks, footnotes and
escaping are all out (see Out of scope). What survives is the half the reader asked for again, in chat, after the
withdrawal:

> also I like to use the head tag like in markdown: Title use #, Subtitle use ##. or other tags you can suggest.
>
> head 标签（#/##）我建议直接开 019 -- OK.
>
> continue to 019（#/## 标题）

and the fact they settled for the answer that made two marks cheap rather than the whole markdown subset:

> The title of the content: Basic Spanish 1.

— the first line of their own content (`Basic Spanish 1`, copied off their phone on 2026-10-12) is a title that
today is only "the first line". Nothing in this spec takes any other wording of theirs literally.

**Amendment, 2026-10-13 — the reader's own ask at the plan gate.** While reviewing this spec's plan the reader
asked, verbatim:

> 可否把加粗字体 计入 大一号，大二号。及计算小一号等。扩充可用字体数

— and answered the three questions it opened (the session below records them). What it changes: a mark's look is
no longer "a size, always bold" but a **ladder of rungs** the app derives from the reader's own choice, and a
comment's own step down now takes a **weight** before it takes a size. **The two marks, the required space, the
line's first character, the never-painted and never-spoken characters and the video's rule are untouched** — what
moves is how a mark's size and weight are derived (FR-006/FR-007 rewritten, FR-015 new, SC-006/SC-007 new, US4
new), and with them 017's shipped comment rule, which that feature's own records report with its date.

## Clarifications

### Session 2026-10-13

Three answers, put to the reader as numbered options once the ladder's shape was clear, each naming the wording
it settles. The reader's own words are quoted as given.

- **Q**: How is one "step" counted — does bold rank with a size, or sit after the sizes? **A**: *字号优先，字重只补顶部
  （推荐）：12→14→18→24r→24b（+24k）* — the ladder is the four offered sizes in the reader's own order and then the
  **largest** offered size at the heavier weights: `small 12 → medium 14 → large 18 → xlarge 24 regular → xlarge 24
  bold → xlarge 24 black`. A title is the **second** rung above the reader's own and a subtitle the **first**, each
  clamped at the ladder's last rung; the rung decides size and weight together. Settles FR-006 and FR-007, and
  refuses two shapes the reader was shown: the interleaved order — a step that is the same size, only bolder (their
  option 2, *"有的档很微妙"*) — and any rung **below** the reader's own for a mark (their option 3, refused: a
  subtitle lighter or smaller than the body is SC-002's own floor).
- **Q**: Does "扩充可用字体数" mean new rungs for the derivations, new entries in the reader's Appearance list, or
  both? **A**: *只扩派生用的档位（阶梯），不动 Appearance 列表* — the ladder grows from four rungs to six; the six
  faces and four sizes the reader picks from do not move, and the ladder's two heavier rungs (**bold**, already
  017's, and **black**) are values no control offers, exactly as 017's derived 10-point comment size is. Settles the
  new assumption A6 and FR-010's "no control, no key" half.
- **Q**: Does a comment's own step down (*"小一号"*) count a weight too — which would move 017's shipped rule? **A**:
  *要：正文已是粗体时，注释 = 同字号常规（改 017 已发货规则，需重测其设备行）* — the step down takes the **weight
  first** and the size second: from a bold body the comment is the same size at the regular weight, from a regular
  body it is one offered size down at the same weight (017's behaviour, unchanged), and below the smallest offered
  size it is 017's derived 10. Settles FR-015; that feature's own records carry the dated report.

**The number.** `create-new-feature.sh` numbers by counting directories, so it proposes **018** — the directory
withdrawn with item 018 on 2026-10-12. The reader named **019** in chat and their number is the one used. **018
stays free** for whatever they assign it to next, exactly as the withdrawal said it would.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A line that starts with `# ` is painted as a title, its marker never painted (Priority: P1)

A reader writes a title as `# Basic Spanish 1` and a subtitle as `## Greetings` on their own lines. On the reading
page the title is painted larger and heavier than the body — at a size derived from the size they chose in
Appearance, not a size of the app's own — and the `#` and `##` themselves are nowhere on the page: the mark is a
way to *say* "this is a title", and the page shows the title it makes, exactly as 015's tag is elided and the
comment it makes is shown.

**Why this priority**: it is the reader's ask, and the smaller half of it — the paint — is what they can see. The
recognition rule is this story's whole risk: every way of being wrong here is a reader's ordinary text changing
shape (a `#1` in a line, a `#` inside a footnote marker, a `### ` that only looks like a mark), and the shipping
content that must not change is named in SC-003.

**Independent Test**: with a content of one marked title, one marked subtitle and body lines, the page paints the
title and subtitle at the derived sizes and weights, their marker characters do not appear in any painted span,
and every unmarked line — including lines carrying `#` mid-line and `### ` — is painted exactly as today.

**Acceptance Scenarios**:

1. **Given** a content whose first line is `# Basic Spanish 1`, **When** the page is opened, **Then** the line is
   painted in the title's derived size and weight and no `#` is painted.
2. **Given** a line `## Greetings`, **When** the page is opened, **Then** it is painted as a subtitle — its own
   derived size, lighter than the title's, heavier than the body's.
3. **Given** the reader's Appearance size is `small`, **When** a title and a subtitle are painted, **Then** their
   sizes come from the app's own offered ladder (medium and large), not from a fixed or proportional size.
4. **Given** the reader's Appearance size is `xlarge`, **When** a title and a subtitle are painted, **Then** both
   are at the largest offered size and they are distinguished by weight — the subtitle at the ladder's **bold**
   rung and the title at its **black** rung (amended 2026-10-13: this scenario's "weight alone" now means those two
   heavier rungs, and the ladder is what puts them there).
5. **Given** the reader's typeface is any of the six faces, **When** a title is painted, **Then** it is painted in
   that same face: a mark changes size and weight, never the reader's chosen face.
6. **Given** a line `#hashtag`, a line `#1 best`, a line with a `#` in its middle, a line `### note`, and a line
   that is only `#`, **When** the page is opened, **Then** all five are painted exactly as they are written today.
7. **Given** the reader's Appearance size is `small` (amended 2026-10-13), **When** a title and a subtitle are
   painted, **Then** the subtitle is at `medium` and the title at `large` — both at the weight the reader's own face
   carries, because the ladder's heavier rungs sit at the largest offered size alone.
8. **Given** the reader's own face is a bold face (017) and their Appearance size is `xlarge` (amended 2026-10-13),
   **When** a title and a subtitle are painted, **Then** the ladder has no rung above the reader's own for the
   title: the subtitle takes the last rung and the title is clamped to it, so both paint at the largest offered size
   at the black weight — the case is named in the deliverable rather than discovered, and the reader's own remedies
   (a smaller size, or a regular face) are what the page offers.

---

### User Story 2 - The marker is never spoken: no read reaches the voice with a `#` in it (Priority: P1)

The same texts are read aloud, sentence by sentence (010), stepped (016) and rendered (012). Not one of those
paths may hand the engine a `#` or a `##`: the mark says "title", and a voice that reads "hash" — or stops — has
turned the reader's own label into noise. This is the same rule 015's tag already obeys, applied to the second
kind of character the reader writes but must never hear.

**Why this priority**: painting a mark without dropping it from the read ships a page that looks right and a voice
that says "hashtag hashtag" — the failure this feature exists to prevent, and the one the reader would hear
first. It is P1 alongside US1 for the reason 016's own page/read pair were: neither half is a usable feature.

**Independent Test**: read a marked text's title line, step through it with ▶, and continue with ⏭: the utterances
the engine receives are the title's own words, with the marker characters absent, and the step list is exactly what
it is on the same text with the markers written out as spaces.

**Acceptance Scenarios**:

1. **Given** the line `# Basic Spanish 1`, **When** its sentence is read, **Then** the utterance is `Basic Spanish
   1` and never contains `#`.
2. **Given** a marked title line that also carries a comment (`# Basic Spanish 1 [comment] 基础西语 1`), **When**
   the step that owns it is read, **Then** the read is the title's own words plus the comment's, with neither the
   marker nor the tag spoken.
3. **Given** a marked text, **When** ▶ is pressed through it, **Then** the highlight visits the same lines in the
   same order as on the same text with the markers absent — the marks never become steps of their own.
4. **Given** a line whose text is only `#`, **When** it is read, **Then** it is read as written (the marker rule
   does not fire): the app never silently drops the reader's characters.

---

### User Story 3 - The video's frames paint the marked line by the same rule (Priority: P2)

The reader renders their content as a video (012), one sentence per frame. A title line is its own sentence, so
its frame is a title frame: painted at the frame's own derived size and weight, marker absent — the same rule as
the page, carried to the frame's scale.

**Why this priority**: the video is where their titles are published, and the wish-list item this feature survives
from named both surfaces ("reading and video display should support mark down format"). It is P2 because the page
and the read (US1/US2) are the reader's daily surface and the frame is a second surface on the same rule.

**Independent Test**: render a marked content to a video and inspect the title's frame: it is painted larger and
heavier than its neighbouring sentence frames, at the frame's own scale, with the marker absent.

**Acceptance Scenarios**:

1. **Given** a marked title line, **When** the video is rendered, **Then** its frame paints the line as a title, at
   the frame's own derived size and weight, and no `#` is painted in the frame.
2. **Given** the same content rendered before and after this feature, **When** the frames are compared, **Then**
   the audio, the frame sequence and every unmarked line's frame are unchanged.

---

### User Story 4 - The ladder quiets a comment as well as it raises a mark (Priority: P2)

The reader whose text is bold (017) reads a bilingual content: their sentence's own characters are bold, and the
translation under it is **the same size at the regular weight** — quieter than the sentence, which is what a comment
is for, and without shrinking the page's own chosen size for it. A reader whose text is regular keeps exactly what
017 shipped: the comment one offered size down.

**Why this priority**: it is the reader's own answer of 2026-10-13 (*要：正文已是粗体时，注释 = 同字号常规*) and the
one part of this feature that moves a **shipped** rule — 017's FR-007/FR-008/FR-009 and its derived-size table — so
it is P2 behind the marks, and it is why this feature's plan owes that feature's records a dated report rather than
only a new rule of its own.

**Independent Test**: with a bold face in force, open a content whose sentence carries a comment: the comment's own
characters measure the same size as the sentence's and are painted at the regular weight; with a regular face in
force the same content's comment is one offered size down at the same weight — and in neither case does any other
paint, offset or read move.

**Acceptance Scenarios**:

1. **Given** a bold face in force and a comment under a sentence, **When** the page is opened, **Then** the
   comment's characters are the sentence's own size at the regular weight, and no offset moves (015's mapping and
   017's own FR-010 hold).
2. **Given** a regular face in force, **When** the same content is opened, **Then** the comment is one offered size
   down — 017's shipped behaviour, unchanged, and every figure its own device rows hold is unchanged.
3. **Given** the body's face changes from bold to regular and back, **When** the page is repainted, **Then** the
   comment's size and weight follow the ladder with nothing stored: the value is derived on every paint.

---

### Edge Cases

- **A reader whose own face is bold at `xlarge`** (amended 2026-10-13): the ladder is exhausted — no rung sits
  above the reader's own for the title — so the title and the subtitle are painted identically, both at the black
  rung, and *above* their body. The remedy is the reader's own (a smaller size, or a regular face); the case is
  named in the deliverable and pictured by a device row.
- **A reader whose own face is bold at `small`, `medium` or `large`** (amended 2026-10-13): their marks step up in
  **size** and are painted at their own rung's weight — i.e. the regular weight, so the marks are bigger and lighter
  than the body. A floor at the reader's own weight is the alternative: it ties the title and the subtitle at
  `large`, and it is refused in decision 9.
- **A Chinese title, and a title in `mono`/`serif`** (amended 2026-10-13): the black rung — and, for `mono`, the
  bold rung — is the platform's **synthesised** weight, because the device ships no matching face (its only CJK
  faces are two `Regular` files, and `mono` has only a `weight="400"` entry). A weight rung is therefore weaker
  there than a size rung, and the deliverable's rows picture it rather than asserting it.
- `#hashtag`, `#1 best` — no space after the marker: the reader's own text, painted as written.
- `### note`, `#### ` — more than two markers: the reader's own text (only `# ` and `## ` are marks).
- A line that is only `#` or `##`, or a marker followed by only whitespace: the reader's own text.
- A `#` in the middle of a line, or at the start of a line inside a paragraph (`text\n# Title\nmore`): the mark is
  recognised by the line it starts; the lines around it stay body text.
- A marker inside a comment's span (a comment that continues onto a following line): the comment's words are the
  comment's — no mark is recognised there.
- A marked line that is also the owner of a comment: the marker is dropped, the comment still rides the line (016's
  step, 015's comment rules).
- An empty text, and a text of one marked line alone: nothing to read beyond the line itself; the page shows the
  title by itself.
- A marker line in a content read in any of the four shipped locales: no new string exists to translate; the mark
  is the reader's text in every language.
- A line whose marker sits after leading whitespace (`  # Title`): not a mark, painted as written (the marker must
  be the line's first character).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A mark MUST be `#` or `##` as the **first character of a line**, immediately followed by one space
  and then at least one non-space character. No other spelling is a mark.
- **FR-002**: `### ` and longer runs MUST be the reader's own text, and so MUST a lone `#`/`##`, a marker followed
  by whitespace alone, a marker preceded by whitespace, and a trailing `#`-sequence (`# Title #`).
- **FR-003**: The marker's characters MUST never be painted: the reading page's display MUST elide the `#`/`##`
  and the space after it, exactly as 015's display elides a tag's characters (`lib/comment.dart`, `displayOf`).
- **FR-004**: The marker's characters MUST never reach the voice: no resolution handed to the engine MUST contain
  a `#` that is a mark, in any read path (a sentence read, a step, ⏭, a resume).
- **FR-005**: A marked line MUST be painted as a title (`# `) or a subtitle (`## `) — its own size and weight —
  and no other line MUST be affected.
- **FR-006**: A mark's look MUST come from the app's own **ladder of rungs** and from nothing else (amended
  2026-10-13, the reader's own answer): the four offered sizes in the reader's own order (`ReadingSize`: small 12,
  medium 14, large 18, xlarge 24), then the **largest** offered size at the **bold** weight (017's faces') and then
  at the **black** weight. The reader's own rung is the last rung not above their own choice; a title takes the
  **second** rung above it and a subtitle the **first**, each clamped at the ladder's last rung. Derived, never
  fixed, never a ratio, and never a rung below the reader's own.
- **FR-007**: The **rung** MUST decide a mark's size and its weight together, and the reader's chosen **typeface**
  MUST be the family every rung is painted in: a mark changes size and weight, never the reader's own face, and no
  rung is painted in a family the reader did not choose (017's faces remain the reader's to pick; the ladder's two
  heavier rungs at the largest size are values no control offers).
- **FR-008**: A mark's scope MUST be **the line it starts**, and nothing else: the rest of its paragraph and every
  following line MUST be painted as they are today.
- **FR-009**: A marker inside a comment's span MUST NOT be a mark: a comment's words are the comment's (015).
- **FR-010**: The reader's text MUST be untouched everywhere it is the reader's: the editor shows it as written,
  the stored text is byte-for-byte what the reader typed, and no setting, stored field or locale string is added
  (no new ARB key in any of the four shipped locales).
- **FR-011**: The read's own units MUST be exactly 016's: a marked line is a sentence like any other (its step is
  the line, its read its own range), the step list on a marked text MUST equal the step list on the same text with
  the markers written out as spaces, and the marks MUST never become steps of their own.
- **FR-012**: 015's comment behaviour and 014's Format action MUST be unchanged by a mark, including on a line
  that carries both a mark and a comment.
- **FR-013**: The video's frames (012) MUST paint a marked line by the same rule, derived from the frame's own
  scale, with the marker absent; the frame's audio, its sequence, and every unmarked frame MUST be unchanged.
- **FR-014**: A malformed or unclosed mark MUST be the reader's text, shown and read as written, never repaired
  and never silently removed (015's own rule for a malformed tag, taken again).
- **FR-015**: A comment's own step down MUST take the **weight first and the size second** (amended 2026-10-13, the
  reader's own answer; it amends 017's FR-007/FR-008/FR-009): from a body painted at a weight heavier than the
  regular one, the comment is the **same size at the regular weight**; from a regular body it is **one offered size
  down at the same weight** (017's shipped behaviour, unchanged); below the smallest offered size it is 017's
  derived 10. It MUST change no other paint and no offset, and it MUST hold in the page and in a video frame alike
  (017's own one-relationship rule).

### Key Entities

- **None.** This feature stores nothing, configures nothing and migrates nothing: it is a second rule for the text
  the reader already writes, inside the two seams the app already owns (015's display, 010/015's resolution).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a content whose title and subtitle lines are marked, the reading page paints each at its derived
  size and weight, and no painted span contains a marker character — checked on the device, in the page's own
  painted text, not only in a unit test.
- **SC-002** (amended 2026-10-13): For every rung a reader can stand on, the title is never smaller than the
  subtitle and the subtitle is never smaller than the body, and the two marks are never the same size **and**
  weight together — the one pair that is the same in both being the ladder's last rung (a bold face at `xlarge`),
  which the deliverable names (SC-006) rather than leaving to be discovered.
- **SC-003**: Every unmarked shape in the shipped suite is byte-identical to today: `#hashtag`, `#1 best`, `### `,
  a lone `#`, a mid-line `#`, a marker after whitespace, and a trailing `#` sequence all paint and read exactly as
  they do now.
- **SC-004**: On a marked text, the step list, the highlight sequence and the utterances other than the markers
  are identical to the same text with its markers written as spaces; on the reader's own content the step list is
  unchanged from the count the fix of 2026-10-12 produced.
- **SC-005**: A rendered video's title frame is painted at the frame's own derived size and weight with no marker
  character in it, and the frames of unmarked lines are unchanged — a device receipt, not a unit test alone.
- **SC-006** (amended 2026-10-13): For **every** one of the four offered sizes and every one of the six faces, the
  three levels are strictly ordered on the ladder — body, then subtitle, then title, with no equal pair — the single
  exception being a reader whose own face is bold at `xlarge`, whose two marks are painted identically *above* their
  body. That case is named in the deliverable and pictured by a device row, not discovered on the reader's device.
- **SC-007** (amended 2026-10-13): With a bold face in force, a comment's own characters measure the **same size** as
  its sentence's and are painted at the lower weight; with a regular face in force every figure 017's own device rows
  hold is unchanged — both measured on the device.

## Assumptions

- The reader writes their marks in the app's own editor (or pastes them into it); nothing in this feature parses
  markdown from any other source, and no import path exists.
- The reader's own content carries no `#` today — verified on the content copied off their phone on 2026-10-12 — so
  no existing content changes shape when the rule lands.
- The four offered sizes stay four, and the reader's Appearance list is untouched (the reader's answer of
  2026-10-13, *只扩派生用的档位（阶梯），不动 Appearance 列表*): the ladder gains rungs the app **derives** — the largest
  size at the bold and black weights — and no entry a control offers, the same shape as 017's derived comment size.
  **A6**.
- Bold — and the black rung above it — is **synthesised** by the platform wherever it ships no matching face: for
  every CJK word (the device's only CJK faces are `NotoSansCJK-Regular.ttc` and `NotoSerifCJK-Regular.ttc`) and for
  `mono`, `serif-monospace`, `casual` and `sans-serif-smallcaps` (a `weight="400"` entry apiece), while the default
  family's variable `Roboto` carries a real `wght` axis from 100 to 900 (the device's own `/system/etc/fonts.xml`,
  read 2026-10-13). So a weight rung is a synthesised difference where a size rung is a real one, and the walk
  pictures both rather than asserting either.
- 015's display and the resolution remain the only two places that know what a never-painted character is; this
  feature adds a second kind of such character inside them rather than a second pipeline.

## Out of scope

- The withdrawn item 018's markdown structure half: emphasis (`**`/`*`), lists, links, inline code, tables, images,
  fenced code blocks, thematic breaks, footnotes, HTML, escaping. The 2026-10-12 analysis and its dated note in
  `text.txt` stand: the block half duplicates the app's own paragraph/line structure, and never-painted characters
  that contain sentence delimiters (a URL, a code span) collide with the app's sentence unit. If the emphasis half
  is ever wanted it is its own item, at roughly a third of the whole.
- A third mark or a hierarchy below `##`, and any **spacing** rule a mark adds: no paragraph spacing, no
  line-height multiplier, no padding (amended 2026-10-13 — a marked line's own box is taller because its characters
  are bigger, which no rule can avoid; what this line refuses is a spacing rule *for* it).
- A new entry in the reader's Appearance list, a new offered size, and any control for the ladder's rungs (the
  reader's answer of 2026-10-13: *只扩派生用的档位（阶梯），不动 Appearance 列表* — the ladder is derived, never offered).
- Recognising marks in the editor's own text field beyond showing the text as written.
- Any change to 015's comment rules, 014's roles, 016's steps or 011's appearance contract; the marks ride them.
- The number 018 and the withdrawn directory: 018 stays free for the reader's own next assignment.

## Decisions this spec takes, and the alternatives

1. **The two marks, with a required space, at the line's first character** (FR-001, FR-002). The reader asked for
   `#` a title and `##` a subtitle and asked whether a mark affects one line; the space is what keeps their own
   prose safe — `#1 best`, `#hashtag` and `C#` stay text — and requiring the line's first character keeps
   `  # Title` text too. **Refused**: any number of levels (`###`+ is text, so a future third level is an addition
   rather than a change), leading whitespace tolerance (would make a wrapped body line a title), trailing-`#`
   closers, and repairing a malformed mark (FR-014: the reader's characters are never rewritten).
2. **A mark's scope is the line it starts** (FR-008) — the reader's own question, answered "yes, one line", and it
   is what makes `# Title` followed by body text *without* a blank line paint as a title plus body rather than
   swallowing the paragraph. **Refused**: paragraph scope (a mark would eat the text after it), document scope.
3. **The look is derived from the offered ladder, never fixed and never a ratio** (FR-006, FR-007): title two steps
   up, subtitle one, clamped at xlarge, both bold. **Refused**: fixed sizes (a title at the largest size would
   dwarf a body the reader chose at small — 011's contract says the reader's chosen size is the size that renders);
   proportional sizes (017's decision 2 already refused them for the comment for the same reason). **The honest
   limit**: at `xlarge` a title cannot grow, so the title/subtitle difference is weight alone — SC-002 makes that a
   named case rather than a discovery, and the deliverable carries the four-size table.
4. **The marker is not painted** (FR-003): the reader asked for the *format* to be supported, and the app's own
   precedent is that a tag's characters are elided while what they mark is shown (015's `displayOf` elides the
   tag; the comment's content is painted). **Refused**: showing the mark dimmed (then the page is not rendering
   the format, and the reader's own page would carry characters they did not mean to publish).
5. **The marker is never spoken** (FR-004): the alternative is what the app does today — reading the reader's
   characters as text — which for a mark is a voice saying "hash", or pausing on it. A mark exists to be a label;
   the second half of this feature is that no engine hears it.
6. **The reader's face and the app's bold weight, nothing new** (FR-007): a mark changes size and weight inside
   the face the reader chose in 017's six faces. **Refused**: a distinct heading face or a heading-specific
   setting (a new dimension in the appearance contract for a rule that needs none), and a third weight in code
   (the bold weight already rides the face).
7. **Marks are recognised outside comments only** (FR-009): a comment's words are the comment's, whatever they
   look like. **Refused**: mark recognition inside a comment's span (a comment could then restyle the page).
8. **Both halves ship together, both P1** (US1, US2): a page that renders a title while the voice reads "#" is the
   failure this feature exists to prevent. **Refused**: shipping the paint first (it would be a visible regression
   in the read, which is the app's primary surface).

## Decisions this spec takes in the amendment of 2026-10-13

9. **A mark's look is the ladder's rung, not a size plus a fixed weight** (FR-006, FR-007). The reader asked for
   bold to *count* as a bigger step, and the shape they chose puts the sizes first and the weights after them:
   `small → medium → large → xlarge regular → xlarge bold → xlarge black`, with a title two rungs above the
   reader's own and a subtitle one, clamped at the last. **Refused**, each as the reader was shown it: the
   **interleaved** order (a step that is the same size, only bolder — their option 2: *"有的档很微妙"*, and it
   turns a title into "the body, bolder"); a rung **below** the reader's own for a mark (their option 3: a subtitle
   lighter or smaller than the body breaks SC-002's floor and reads as a footnote); and a **floor** at the reader's
   own weight (it makes every mark also bold, which ties the title and the subtitle at `large` — the very tie this
   amendment exists to remove). **The honest limits, named rather than discovered**: a reader whose own face is
   bold at `xlarge` has nothing above them for the title, so their two marks paint identically (edge case, SC-006,
   pictured by a row); and for CJK — and for the families whose only entry is `weight="400"` — a **weight** rung is
   the platform's synthesised weight where a **size** rung is real.
10. **The ladder is derived, never offered** (A6, FR-010, the reader's answer of 2026-10-13): no size is added, no
    entry appears in the Appearance list, no locale string is added, and the black rung is a value no control
    offers — 017's derived 10-point comment size is the precedent. The consequence to accept: a reader cannot ask
    for a black title directly; they get it by having a title at the ladder's top, which is the rung's business and
    not a setting.
11. **A comment's own step down counts the weight first, the size second** (FR-015, US4). The reader's own answer:
    with a bold body the comment is the same size at the regular weight — *quieter* rather than smaller — and with a
    regular body it is exactly what 017 shipped. **Refused**: leaving 017's rule alone (then a bold reader's comment
    is a smaller bold line — the opposite of what a translation needs beside a bold sentence) and stepping the size
    down first for a bold body as well (the same complaint, one size later). **The blast radius is named**: it moves
    017's FR-007/FR-008/FR-009 and its derived-size table, so that feature's own records carry a dated
    supersession report and a re-measured row, and its SC-003's "measure smaller" becomes "never larger, and never
    the same size *and* weight" for the bold case.
