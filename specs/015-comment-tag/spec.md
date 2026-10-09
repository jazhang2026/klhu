# Feature Specification: Comment Tag (a translation shown and read with its sentence)

**Feature Branch**: `015-comment-tag`

**Created**: 2026-10-08

**Status**: Draft

**Input**: item **015** of `text.txt`, quoted verbatim:

> 015. besides the 角色前缀 tag. add a new tag for [comment](中文：[注]).
>     comment tag is used to manage the reading of the comment.
>     example: a spanish sentence followed by a comment of english translation.
>     the spanish sentence is read by the spanish voice.
>     the english translation will not be read. use can see it but not hear it.
>     [comment] tag will never be read. it is only for display and management.
>     to read or not read the comment can be set by user.
>     [comment] tag can also applied in standard mode contents.
>
>     comment tag will not be displayed in the video. the comment content will be in the video with the sentence.
>     research and help to design the new tag.

> **One line of that example is not taken literally (2026-10-08).** *"the english translation will not be read"*
> describes what the app does when the reader turns a content's comments **off**; the shipped default is to
> **read** them — the reader's own answer of the same day. FR-006 carries the rule and the Clarifications entry
> below records the reversal.

**Input (the reader's own answers, 2026-10-08)**: the three decisions the tag's design rested on were put to
the reader as numbered options once the research was done, and answered in one turn — how far a comment runs,
where the read/not-read switch lives and what it defaults to, and whether the marker itself is shown. All three
are recorded in the session below, and every one of them names the wording it settles.

**Input (the trailing paragraph of the same item)**: the block quoted above ends with *"one change for 014: the
reading sentence of the short video(9:16) in youtube is covered by the title and some icon. Need to move it up to
avoid being covered."* That paragraph is **not this feature's**: it is the amendment of 2026-10-08 that changed
where a portrait video frame rests its words, and it lives in `specs/014-dialogue-reading/spec.md` (its own
2026-10-08 amendment and Clarifications session). It is named here only because it sits inside the block quoted
above, so no later reader goes looking for the 9:16 change in this spec.

**Input (the reader's own amendment, 2026-10-08 — the tag's spellings, one per language the reader types in)**: *"[comment]
is for english and [注] is for simplified chinese. spanish and tradisional chinese should have their own words. when user
use their own language keyboard, it's not easy for them to type words in different locale."* The tag therefore has
**four spellings, one for each language the app's own locales are written in** — `[comment]` (English), `[注]`
(Simplified Chinese), `[註]` (Traditional Chinese) and `[nota]` (Spanish) — and **all four are recognised in every
content, whatever language the app itself is showing**: the reader types the spelling their own keyboard makes easy,
and a content's meaning does not change with the app's UI language. The two words are the reader's own answers of the
same day to numbered options (`[nota]`, `[註]`); `[comentario]`, `[註解]` and `[註釋]` were the options not taken. FR-001
carries the set and A1 carries the measurement; the Clarifications session below records both questions.

## Clarifications

### Session 2026-10-08

Three decisions, put to the reader as numbered options the same day the tag was researched, answered in one
turn. Each entry names the wording it settles, so a later reader sees the choice was deliberate rather than a
drift.

- **Q**: How far does a comment run — to the end of its own **line**, or to the end of its **paragraph**?
  **A**: *the end of its paragraph.* A blank line is the app's own unit for this text (`lib/segmenter.dart:71`,
  the ranges 014's turns are made of), so a comment needs no new division of the reader's text, and the
  spelling that reads naturally — the sentence, a blank line, then `[注] …` — is the one the rule favours. The
  consequence to accept, stated rather than discovered: an **inline** tag takes every following sentence of its
  paragraph with it — `Hola. [注] Hi. Adiós.` is one comment reading *"Hi. Adiós."*, so *Adiós.* is never a
  sentence of its paragraph read in its own right (it is the comment's own text, and its voice is the
  **comment's** own detected language's — A3; for this text that detection is `es`, the detector reading
  `Adiós.`'s accent; corrected 2026-10-09 on the device, `breakpoint.md` § Row 18) — and the reader's own remedy
  is the blank line that puts the comment in a paragraph of its own. Settles FR-002 and the edge case it creates.
- **Q**: Where does the read/not-read switch live, and what does a content with nothing stored do? **A**: *per
  content, and **read**.* The switch sits on the same surface the text type and the role list do (014's own
  sheet, reached from the reading page), the setting is stored in the same per-content store, and a content with
  nothing stored **reads its comments**. This **reverses the item's own example** (*"the english translation
  will not be read"*), which is now read as the switch-off state rather than as the shipped default — reversing
  it back is a one-line change of the store's absence rule plus a row's expectation. Settles FR-006.
- **Q**: Is the `[注]` marker itself displayed on the reading page? **A**: *no — the page hides it.* The
  comment's **content** is displayed and the marker's characters are painted nowhere (neither the page nor a
  video frame), which is the treatment 014 already gives a `{角色}` prefix *in a frame* — and deliberately the
  opposite of what 014's page does with that prefix, because a role prefix is the reader's own script (worth
  seeing) while a comment marker is punctuation between two languages. The consequence to accept: the page no
  longer paints the text byte-for-byte, so the plan owes the mapping from what is painted back to the content's
  own offsets (A4). Settles FR-005 and FR-012 and the display assumption A4.

### Session 2026-10-08 (second round — the tag's spellings, one per language the reader types in)

The reader's own amendment, quoted on the `Input` lines above. Two decisions follow from it, and both are recorded
here because they fix words the reader will type:

- **Q**: Which Spanish and Traditional Chinese words? **A**: *`[nota]` and `[註]`*, chosen from the numbered options
  of the same day — `[nota]` (four letters, no accent; the literal `[comentario]` was not taken) and `[註]` (the one
  traditional character form of 注; `[註解]` and `[註釋]` were not taken). This settles **FR-001's own sentence and
  A1**, rewritten in place rather than given new ids: the spelling set *is* the tag's recognition rule, so a second
  `FR-` would have tracked the same behaviour twice.
- **Q**: Is a spelling live only in the app's own language? **A**: *no — all four, in every content.* The reader's
  reason is a keyboard, not a locale: a Spanish reader on a Spanish keyboard must be able to write their own word
  whether the app is showing English or not, and a text must not change its meaning with the app's UI language. The
  alternative (only the current UI locale's spelling counts) would make one content read differently under two UI
  languages, which is the one thing a text's own marker cannot do.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The translation is a comment, and its marker is invisible (Priority: P1)

The reader writes a bilingual content — a Spanish sentence, a blank line, `[注] How are you?` — or pastes one
from elsewhere. The reading page shows the two languages and **no** `[注]`: what the tag marks is a *comment*,
and the tag itself is furniture. Editing the text is unchanged; the marker is what the app reads to know where
the comment starts and ends.

**Why this priority**: this is the feature's spine — without a rule for what a comment *is* there is nothing for
the read, the switch or the video to act on, and every later story is a consequence of this one. It is also the
story that decides the marker's fate in both directions (never spoken, never painted), which is the part of the
reader's own item that their answers of 2026-10-08 kept unchanged.

**Independent Test**: open a content with one Spanish sentence and one `[注]` comment, on the device: the page
paints both languages and no marker; the app's own per-utterance line names exactly one comment, whose content
is the paragraph after the tag and nothing else; and a `[注]` typed with full-width brackets is ordinary text
that the page shows as written.

**Acceptance Scenarios**:

1. **Given** a content whose second paragraph is `[注] How are you?`, **When** it is opened, **Then** the page
   shows the comment's content and no marker, and the app's own comment list names one comment belonging to the
   sentence before it.
2. **Given** the same content, **When** the tag is written `[comment]`, `[Comment]`, `[nota]`, `[Nota]` or `[註]`,
   **Then** each is the same marker as `[注]` (one tag, four spellings — one per language the app's own locales are
   written in, the ASCII ones case-insensitive), each is recognised whatever language the app is showing, and a near
   miss in any language (`[comentario]`, `[註解]`, `[comments]`) is ordinary text.
3. **Given** a content that carries no tag at all, **When** it is read, **Then** nothing about the read, the
   page or the video differs from the shipped app.
4. **Given** a tag typed with full-width brackets (`［注］`) or with a word before it (`see [注] …` on the same
   line as a sentence — a case decided by FR-002's boundary, not by the bracket), **When** the text is read,
   **Then** the reader's characters are what they are: a marker the rule refuses is displayed and read like any
   other characters rather than silently dropped.
5. **Given** a comment whose own paragraph is several lines long, **When** it is read, **Then** the comment's
   content is that whole paragraph — its line breaks included — and the sentence it belongs to is the last
   sentence that ended before the tag.

---

### User Story 2 - The comment is read after its sentence, in its own language's voice (Priority: P1)

The reader reads the content aloud: the Spanish sentence comes out in the Spanish voice, and the English comment
comes out right after it in the English voice — one text, two languages, two of the app's own voices. Nothing in
the reader's own text had to be normalised for that to happen.

**Why this priority**: it is the shipped default (the reader's answer of 2026-10-08) and the half of the item
that makes a comment worth having at all: a translation the reader cannot hear is a footnote, and the reader's
own example is *"the spanish sentence is read by the spanish voice"*. It is P1 beside US1 rather than below it
because the two are separable: US1 alone is a display feature, and this one is the read.

**Independent Test**: read a mixed content on the device and read the app's own per-utterance lines: the
sentence's utterance names the sentence's voice, the comment's own utterances name the voice the app has for the
comment's own detected language, and each comment's utterances come immediately after the sentence it belongs
to.

**Acceptance Scenarios**:

1. **Given** a Spanish sentence with an English `[注]` comment, **When** the content is read from the top,
   **Then** the sentence is spoken in the Spanish voice and the comment in the English one, in that order, and
   the app's own lines name both.
2. **Given** a comment of two sentences, **When** it is read, **Then** it is spoken one utterance per sentence
   — the app's own unit (010 FR-011), exactly as a paragraph is cut — and the highlight follows each sentence.
3. **Given** a content whose comment's language is the sentence's own language, **When** it is read, **Then**
   the comment is still a comment: its own content decides its language, and it is spoken by that language's
   pick.
4. **Given** a content whose comment was read, **When** the content is read a second time with nothing changed,
   **Then** the same utterances, in the same order, with the same voices (nothing about the read is random).
5. **Given** a comment at the very top of a content, before any sentence has ended, **When** the content is
   read, **Then** that comment belongs to no sentence: it is displayed, and it is never spoken (FR-003).

---

### User Story 3 - A content whose comments I do not want to hear (Priority: P2)

The reader has a bilingual text they want read in one language only — the translation is for their eyes. One
switch on the reading page's own settings sheet turns that content's comments off; the words stay on the page
exactly where they were.

**Why this priority**: the item asks for the switch in its own words (*"to read or not read the comment can be
set by user"*), and the reader's answer puts the default on the other side. It is P2 rather than P1 because the
default read already delivers the item's own example's *purpose*; the switch is one setting on a surface that
already exists, and nothing else in the feature depends on it.

**Independent Test**: on the device, turn one content's comments off, read it and read the app's own lines: none
of the comment's words appear among the utterances, the page still shows them, and a second content with the
setting untouched still reads its comments — then reopen the first content after a restart and the choice is
still in force.

**Acceptance Scenarios**:

1. **Given** a content with comments and nothing stored, **When** the settings sheet is opened, **Then** the
   switch reads *read* (the shipped default), and the content's comments are spoken.
2. **Given** the reader turns the switch off, **When** the content is read, **Then** no comment's words reach
   the engine — 100 % of the utterances are the sentences' own text — and the page is unchanged.
3. **Given** the switch is off, **When** the app is restarted, **Then** it is still off for that content.
4. **Given** two contents, one switched off, **When** each is read, **Then** the choice applied to one does not
   reach the other.
5. **Given** the reader turns the switch back on, **When** the content is read, **Then** the comments are spoken
   again, with nothing else about the read changed (the stored reading position, the highlight and the roles are
   where they were).
6. **Given** the reader deletes the content, **When** it is gone, **Then** its comment setting is gone with it.

---

### User Story 4 - A comment inside a role's turn, and in 标准 (Priority: P2)

The reader's dialogue has a speaker whose line needs a translation: `{阿明} 今日个天气真系唔错啊。` with
`[注] The weather is really nice today.` under it. The turn is still 阿明's and still one turn; the comment is
not spoken by 阿明 and does not change what language the turn is detected as. The same tag works in a 标准
content, which has no roles at all.

**Why this priority**: the item says the tag "can also applied in standard mode contents", and a dialogue is the
app's newest reading mode — the two tags sharing one text is the case the reader will actually write. It is P2
because US1–US3 already work in either mode: this story only fixes what the *other* tag does to a comment, and
it is the story that keeps 014's receipt honest.

**Independent Test**: in 多人对话, read a role's turn that carries a comment and read the app's own lines: the
turn's utterances are the turn's own text alone in 阿明's voice, the comment's utterance follows them in the
comment's language's voice, and the role list's turn count for 阿明 is one — while the same text set to 标准
reads the sentence in its language's voice and the comment after it.

**Acceptance Scenarios**:

1. **Given** a `{阿明}` turn whose paragraph carries a comment, **When** the content is read, **Then** the
   turn's own utterance contains no comment text, and the comment is read by its own language's voice.
2. **Given** the same turn, **When** its language is detected, **Then** the detection is the turn's own text
   without the comment (a Chinese turn with an English comment is still `zh-Hans`).
3. **Given** a paragraph that holds nothing but a comment, **When** the roles are proposed, **Then** it is not a
   turn: it adds no role, no turn count and no utterance.
4. **Given** a 标准 content with a comment, **When** it is read, **Then** the sentence is read exactly as the
   shipped app reads it and the comment is read after it (FR-010) — the mode is not a precondition for the tag.
5. **Given** a text whose comment holds a `{…}` pair inside it, **When** the reader presses the editor's Format
   action, **Then** the comment is untouched: Format moves role tags to paragraph heads and knows no other tag.

---

### User Story 5 - The comment in the video (Priority: P3)

The reader renders the content as a video. Every frame that shows a sentence also shows that sentence's
comment, and no frame ever shows a `[注]` — what the reader sees in the file is the sentence and its
translation, which is what the reader asked for in their own words.

**Why this priority**: it is the fourth thing the item asks for (*"comment tag will not be displayed in the
video. the comment content will be in the video with the sentence"*) and it rides on the resolution the first
four stories establish. P3 rather than P2 because 012 already ships the render pipeline: this story changes what
a frame's text is, not how a video is made.

**Independent Test**: render a content with one comment, sample its frames and read the app's own render lines:
every frame of the sentence's slot carries the comment's content and none carries a marker, and the file's own
audio carries the comment exactly when the read does.

**Acceptance Scenarios**:

1. **Given** a content with a comment and the default setting, **When** it is rendered, **Then** the frames of
   the sentence it belongs to paint the sentence **and** the comment's content, and no frame contains a marker.
2. **Given** the same content with the switch off, **When** it is rendered, **Then** the frames are what they
   were — the comment's content is still painted — while the file's audio carries no comment.
3. **Given** a comment inside a role's turn, **When** it is rendered, **Then** the frame paints the turn's
   sentence with the comment and no role name, and the audio is the read's own (one resolution).
4. **Given** a content with no tag at all, **When** it is rendered, **Then** the video is exactly what 012
   produces today.

---

### Edge Cases

- **An inline tag takes the rest of its paragraph.** `Hola. [注] Hi. Adiós.` — one comment, *"Hi. Adiós."*, and
  *Adiós.* is never a sentence of its paragraph read in its own right: it is the comment's own text, read in the
  comment's own detected language's voice (A3 — `es` for this text, the detector reading `Adiós.`'s accent;
  corrected 2026-10-09 on the device, `breakpoint.md` § Row 18). The boundary is the reader's own blank line
  (2026-10-08), so the remedy is writing the comment in a paragraph of its own.
- **A comment before any sentence.** A `[注] …` paragraph at the very top of a content: it belongs to no
  sentence — displayed, never spoken, and absent from a video (there is no slot to ride).
- **A paragraph that is only a comment, inside a dialogue.** No turn, no role, no count (US4 scenario 3): the
  same answer 014 gives a paragraph that is only a tag.
- **The second marker.** `[注] Hi. [注] more.` — the first tag opens the comment and the second is *inside* it,
  so it is the comment's own text and is displayed and read with it. There is nothing to nest.
- **A tag with a separator.** `[注]: Hi.`, `[注] : Hi.` and `[注] Hi.` are the same comment: the spaces and the
  single optional colon belong to the tag and are painted nowhere. A second colon is the comment's own
  (`[注]: note: read this` reads *note: read this*).
- **An empty comment.** `[注]` with nothing after it, or a paragraph holding only the marker: no content, so no
  utterance, no frame, and nothing to switch off — never a silent gap in a video.
- **Full-width brackets.** `［注］` typed with a Chinese IME's default brackets is ordinary text, displayed and
  read as written (014 declined a second delimiter pair on the same ground; a twin is one table row away).
- **A spelling from another language.** `[nota]` or `[註]` in a content the app is showing in English — or
  `[comment]` in one it is showing in Chinese — is the same tag: the four spellings are one set, recognised
  everywhere (2026-10-08), because the reader types with whatever keyboard their own language gave them.
- **A marker the rule refuses is not repaired.** `see [注] below` — where the tag sits mid-line — is
  nevertheless a comment from the tag to the paragraph's end, because the rule is mechanical and the reader's
  own text is the contract (014's A9, kept): the cure is the reader's own edit, and the page shows the tag's
  characters nowhere, so a comment in the wrong place is heard rather than seen.
- **A comment whose language the app does not read.** A comment in a fourth language: it is displayed and
  painted, and its utterance reads with whatever the app's own rule gives that text — the detection falls back
  to English, as it does for any paragraph today. The app does not refuse to read a content over a comment.
- **A very large content with many comments** (thousands): the read, the highlight and the video behave as they
  do for a long content without comments — a comment adds no stored entry, no per-comment file and no extra
  store write.
- **The stored reading position lands inside a tag.** The tag is no sentence, so the app's existing
  nearest-sentence rule answers it and the read never starts on a marker (010/011 unchanged).
- **A comment in the text the reader is still editing**: the text is what is read, and undo restores the
  previous text with its previous comments — nothing about the comments is stored separately (FR-015).
- **A comment and a role tag on the same paragraph.** `{阿明} 你好。[注] Hello.` and `[注] Hello.` in a paragraph
  that 阿明 does not head are two different texts: the first is 阿明's turn with a comment; the second is a
  comment-only paragraph belonging to the sentence before it. The role rule reads the paragraph's head only
  (014 FR-004), and the comment rule reads its own tag wherever it is.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A comment MUST be recognised by a **tag**: `[comment]`, `[注]`, `[註]` or `[nota]` — one spelling
  for each language the app's own locales are written in (2026-10-08) — in ASCII square brackets only, the ASCII
  spellings (`comment`, `nota`) matched case-insensitively. **All four MUST be recognised in every content**,
  whatever language the app itself is showing. The tag MAY be followed by spaces and one optional colon (ASCII or
  full-width) with spaces around it, and those characters belong to the tag. No other text is a comment: a content
  with no such tag reads, displays and renders exactly as today.
- **FR-002**: A comment's **content** MUST be the text that follows its tag to the **end of that paragraph** —
  the blank line that ends it (the reader's own answer of 2026-10-08) — including the line breaks inside it,
  ending at the paragraph's last non-whitespace character. The tag and its separator are outside it.
- **FR-003**: A comment MUST belong to the **last sentence that ends before its tag**, across paragraph
  boundaries, and MUST NOT be attributed to any other sentence. A comment with no sentence before it anywhere in
  the text belongs to nothing: it is displayed, is never spoken and appears in no video frame.
- **FR-004**: A comment's content MUST NOT be part of any sentence's span: it is never highlighted as part of a
  sentence, never part of a stored reading position, and never handed to the engine except as its own speech
  (FR-007).
- **FR-005**: The tag's own characters, and the separator that belongs to it, MUST NEVER reach the engine and
  MUST NEVER be painted — not on the reading page, not in a video frame — in either text type and whatever the
  read setting is (the reader's own answer of 2026-10-08).
- **FR-006**: A content MUST carry one setting for its comments — **read** or **not read** — remembered per
  content and per device; a content with nothing stored MUST read its comments (the shipped default), and the
  setting MUST be the reader's to change (US3).
- **FR-007**: With the setting on, a comment MUST be read as its own speech immediately after the sentence it
  belongs to, cut into sentences exactly as a paragraph is cut — one utterance per sentence (010 FR-011) — so
  011's highlight and 010's resume keep the unit they already have.
- **FR-008**: A comment's language MUST be detected from the comment's **own content** by the app's own rule
  table, and the voice it reads with MUST be the pick that language already has (002) — the same seam a
  paragraph uses, with no second mechanism.
- **FR-009**: The page, the reader service and the video MUST resolve the comments through **one** resolution
  (014's own one-resolution rule), so the same comment cannot be read on the page and silent in the file.
- **FR-010**: 标准 MUST read a text with comments exactly as it reads it today except for the comments
  themselves: the sentences keep their own spans, their own languages and their own voices, and the comment's
  content is spoken exactly when the setting is on. No existing content's reading changes.
- **FR-011**: In 多人对话, a turn's spoken content MUST exclude its comments: a comment inside a turn MUST NOT be
  spoken by that turn's role and MUST NOT change the turn's detected language, and a paragraph that is nothing
  but a comment MUST NOT become a turn (no utterance, no role, no turn count).
- **FR-012**: The reading page MUST display the text as written **except the tags**, whose characters are not
  painted: a comment's content is visible where the reader wrote it, with its own line breaks. The page's own
  tap, highlight and reading-position behaviour MUST keep working over that display: a tap inside a comment
  resolves to the sentence it belongs to when the comments are not read, and to the comment itself when they
  are; the highlight MUST cover a comment exactly when that comment is being read.
- **FR-013**: A video frame that paints a sentence MUST paint that sentence's comment's content with it, and no
  frame MUST paint a tag (the reader's own words: *"comment tag will not be displayed in the video. the comment
  content will be in the video with the sentence"*). A comment that belongs to no sentence is in no frame.
- **FR-014**: The comment setting MUST be reachable from the reading page's own settings surface — the sheet
  where the text type and the role list already live (the settings sheet 014's own entries sit on) — and every
  new string MUST exist in the app's four locale files.
- **FR-015**: The setting MUST be stored per content and per device the way 014's own settings are: one store
  keyed by the content's own id, read tolerantly, leaving 008's index, its schema and its repair path untouched,
  the content's own text unmodified, and MUST be removed when the content is deleted.
- **FR-016**: Changing the setting MUST NOT modify the content, MUST NOT move the stored reading position and
  MUST NOT change the roles or their voices.
- **FR-017**: The editor's Format action (014's own Format press) MUST leave every comment where it is: it moves role tags
  to the heads of their own paragraphs and knows no other tag.
- **FR-018**: The feature MUST NOT add a dependency and MUST NOT use the network; the comments are the reader's
  own text and the voices are the device's own (constitution IV).

### Key Entities *(include if feature involves data)*

- **Comment tag** — one marker in the reader's text: `[comment]`, `[注]`, `[註]` or `[nota]` (one spelling per
  language the app's own locales are written in), with its own start offset, the
  offset its content begins at, and the separator it swallows. Derived from the text on every read, never
  stored.
- **Comment** — one comment: its tag, its content span (to the end of its paragraph) and the sentence it
  belongs to (or nothing). Derived, never stored, and never a shape of its own in the content.
- **Comment setting** — per content: read or not read. What FR-015 stores, and the only thing this feature
  remembers; an absent setting is **read**.
- **Sentence** (010/011, unchanged) — the unit of speech, one utterance per sentence; a comment is a second
  speech beside its sentence, not a new unit.
- **Paragraph** (003/014, unchanged) — the app's own range between blank lines; it is both a turn's boundary
  (014 FR-003) and a comment's extent (FR-002).
- **Turn / Role** (014, unchanged) — a dialogue's per-speaker unit and the roster; a comment changes what a turn
  says, never who says it.
- **Content** (008, unchanged) — the reader's text; the comments are part of it and nothing about them is added
  to it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With nothing stored, a read of a content with comments sends the engine the sentences' own text
  **and** each comment's own content, the comment immediately after the sentence it belongs to — read from the
  app's own per-utterance line, 100 % of the utterances contain no marker characters of any of the tag's four
  spellings.
- **SC-002**: With the setting off, the same content's utterances contain none of the comments' words: the
  utterance sequence is the sentences' own, in order.
- **SC-003**: A mixed content reads in two languages: the sentence's utterance names the voice the app has for
  the sentence's language, the comment's utterances name the voice for the comment's own detected language, and
  the two differ where the two contents' languages differ.
- **SC-004**: A content with no tag at all reads exactly as the shipped app reads it — the same utterance
  sequence (011's and 012's own rows still pass unmodified).
- **SC-005**: In 多人对话, a turn that carries a comment reads as that turn alone in its role's voice: the turn's
  utterances contain no comment text, the comment is spoken by its own language's voice, and the role list's
  turn count for that role is unchanged by the comment.
- **SC-006**: The reading page paints no marker anywhere (a page with comments contains none of the tag's
  characters) and paints every comment's content; the highlight covers a comment exactly while it is read.
- **SC-007**: Every sampled frame of a video of a content with comments paints the comment's content with its
  sentence, and no sampled frame contains a marker (read from the file's own pixels).
- **SC-008**: The video's own audio carries each comment exactly when the read does, and its utterances are the
  read's own (one resolution — the same words, the same voices, the same order).
- **SC-009**: A tap inside a comment resolves to the sentence it belongs to while the comments are not read, and
  a read from there speaks that sentence — never a marker, never a gap.
- **SC-010**: The setting survives a restart, is per content (one content switched off leaves the other's alone),
  and is removed with the content.
- **SC-011**: The feature adds no dependency and makes no network call (the structural receipt 012 already has:
  the manifest diff and the app's own offline behaviour).

## Assumptions

- **A1 — one tag, four spellings, one bracket pair.** `[comment]` and `[注]` are the same marker (the item's own
  parenthesis), and the reader's amendment of 2026-10-08 added one spelling per language the app's own locales are
  written in: `[註]` (Traditional Chinese — the one traditional character form of 注) and `[nota]` (Spanish — four
  letters, no accent, the same "note" sense 注 carries). **All four are recognised in every content whatever
  language the app is showing**, because the reader types with their own keyboard (the Clarifications session above
  records the question and the answer). The ASCII spellings are case-insensitive. The brackets are ASCII `[` `]`
  only — a full-width twin is one table row away and is deliberately not taken (014's delimiter round, 2026-10-02).
  Measured over this checkout's own prose on 2026-10-08 (123,236 non-blank lines of `*.md`/`*.txt`, `find . -name
  '*.md' -o -name '*.txt'`), `[nota]`, `[Nota]`, `[註]` and `[comentario]` occur **nowhere at all**, 28 lines begin
  with `[`, and the only `[注]`/`[comment]` occurrences anywhere are the reader's own wish-list lines in `text.txt`
  and the files this feature wrote — no shipped content, asset, document or test uses any of the shapes.
- **A2 — the paragraph is the comment's extent (clarified 2026-10-08).** The unit is the app's own
  (`lib/segmenter.dart:71`, the same ranges 014's turns are cut on), so a comment costs no new division of the
  reader's text. The consequence to accept is the inline tag's reach (the edge cases).
- **A3 — a comment's language is its own.** A comment is written in the language it translates *into*, so
  detection runs on the comment's content alone (`lib/language.dart:96`), never on the paragraph it sits in.
- **A4 — the page hides the tag by eliding its characters, not by rewriting the text.** The content is
  untouched; what the page paints is the stored text minus the tag's characters (FR-005). The plan owes the
  mapping the page needs — the offsets its taps, highlight and reading position are expressed in are the
  content's own, and the display is now shorter — and this spec says only what the reader sees (FR-012).
- **A5 — the switch's home is the store that already exists.** 014's per-content store (`lib/role_store.dart`,
  one `shared_preferences` key for the whole app, tolerant reads) carries the setting; absence means **read**,
  so the store holds the reader's decisions and nothing else (FR-015).
- **A6 — the two tags do not see each other.** `[注]` carries no braces, so 014's role scan cannot propose it as
  a speaker; Format moves `{…}` only (FR-017). A comment inside a turn is the reader's own text and nothing
  more.
- **A7 — a frame stays one block per slot.** A comment rides with the sentence's block (FR-013), so a frame's
  "one sentence" is the sentence **and its comment**: 012's slot arithmetic, its scroll and its plate/tone rules
  are unchanged, and the block is simply taller where a comment is long.
- **A8 — the unit of speech does not change.** One utterance per sentence (010 FR-011); a comment is a second
  speech in the same unit family, which is what keeps 011's highlight, 010's resume point and 012's one-slot-per
  -sentence timeline working (FR-007, FR-009).
- **A9 — no account, no network, no new dependency, no platform code** (constitution IV, FR-018): this feature
  is pure Dart over the text it already has.
- **A10 — the reference devices** for the device rows are the AVD `emulator-5554` (API 36) and the reader's own
  phone where they run it, with the debug build's own evidence lines: the per-utterance `klhu speak` line
  (carrying the comment's own utterance and voice) and the renderer's own per-slot lines.

## Out of scope

- **Per-comment styling** — a different typeface, size, colour or italic for a comment, in the page or in the
  video: a comment is painted in the reader's own appearance, exactly like a sentence (011's/012's own rule).
- **Any second marker shape**: a displayed marker, a marker with an argument (`[注: es]`), a named comment type,
  a nesting or a closing tag. The tag is a marker and nothing else.
- **More than one comment per sentence**: the first tag opens the comment and every later tag in that paragraph
  is the comment's own text.
- **Translating or generating a comment** — the app never writes a comment; that is wish-list item 16, a
  feature of its own.
- **Per-comment audio files, a separate audio track, or a second file per comment**: the video stays one file
  with one mixed track (012 owns the file).
- **Styling or markup inside a comment** (bold, links, markdown) — a comment is the reader's own characters.
- **Comments shared between contents, or synced between devices** (no account, constitution IV): a comment
  belongs to the text that wrote it.
- **Anything about where a portrait video frame rests its words**: that is 014's own amendment of 2026-10-08,
  named on this spec's `Input` lines, and it is not this feature's.
