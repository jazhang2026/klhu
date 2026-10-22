# Feature Specification: Scene tags (`[scene]`, `[场景]`)

**Feature Branch**: `024-scene-tags`

**Created**: 2026-10-20

**Status**: Draft

**Input**: The reader's wish list (`text.txt`), item 024, quoted verbatim **as it now stands** — substring-checked line
by line against the file (six lines, none reflowed, none dropped). The reader added the example on its first line on
2026-10-20, **after** this stage's five questions had been answered with `take recommendations`; that example reopens
two of the five, and it is carried here rather than papered over:

> 024. add [scene] or [场景] tag support. example: [场景] 1：青石观蚁
>     same as role tag, format button will start a new paragraph if not yet. for scene tag.
>     scene tag will not be read and showing in the reading page and video.
>     on Assign sentences page, add option(if found scene tags): auto assign scene sentences to pictures.
>     scene sentences are the sentences after this [scene] or [场景] tag line and before next [scene] or [场景] tag.
>     use the same order of pictures and scenes.

The example is `[场景] 1：青石观蚁` — a tag **followed by a heading on the same line**, a scene number and a name. It
contradicts two readings this spec had already written down (the tag alone on its line; scenes as bare ordinals with no
name), and the item's own fifth line is what makes the contradiction sharp: the scene's sentences begin **after** the
tag line, so nothing on that line is a scene sentence — but the heading is still the reader's own text, and the app's
rule everywhere else is that a reader's text is never silently dropped. Clarifications item 3 carries the re-cut and
item 10 carries the three readings, one taken and two refused, and the reader **confirmed the taken one on the same day**
with the token `keep 1`.

**Amendment note (2026-10-20, after this stage's plan was written)**: the reader asked for two more spellings in a
message of their own — `please include: 場景、escena` — so the set is **four**, one per shipped UI locale
(`scene`/`场景`/`場景`/`escena`), all live in every content. Clarifications item 1, FR-001 and A1 carry the new form; the
`Input` quote above stands exactly as the reader wrote it, and the plan's D2, which recorded `場景`/`escena` as *not
taken now*, is superseded.

**What the tree already carries, and the gap the item names.** The app has three rules of this shape and every one of
them is derived from the reader's text on every open, never stored:

- **014's role tag** — a `{name}` prefix at a paragraph's head (`lib/dialogue.dart:116`), and the edit toolbar's
  Format press is one pure function whose only difference from the reader's text is blank lines
  (`lib/dialogue.dart:249`).
- **015's comment tag** — `[comment]`, `[注]`, `[註]`, `[nota]`, ASCII brackets only (`lib/comment.dart:14`, the
  spelling list at `:25`), matched anywhere inside a paragraph (`:126`), and its characters are neither painted nor
  spoken.
- **019's head tag** — `#` a title, `##` a subtitle, at a line's head, elided from the page and the voice by the same
  mapping (`lib/head_tag.dart:58`).

The page's **one** elision site is `displayOf` (`lib/comment.dart:386`), and the video paints that same display
(`lib/video_renderer.dart:314`). Sentences are the segmenter's (`lib/segmenter.dart:93`); the ▶ steps
(`lib/comment.dart:206`) and the video's slots (`lib/video_timeline.dart:80`) are cut from that same list, and a
paragraph with no delimiter is **one** sentence. So today `[scene]` on a line of its own is an ordinary narration
sentence: **spoken, painted, one row on the Assign sentences page, one slot in the video.** That is exactly what the
item's second and third lines ask it not to be, and it is what makes scene-owned pictures (the fourth line) impossible
until the tag is recognised.

## Clarifications

### Session 2026-10-20 — what the tree settles, with no question put to the reader

1. **The spellings are four — one per shipped UI locale, all live in every content**: `scene` and `escena` in any
   ASCII case, `场景` (Simplified), `場景` (Traditional). They join no other list — 015's four comment spellings
   (`comment`/`注`/`註`/`nota`) are the precedent and a different rule with a different owner (`lib/comment.dart:25`) —
   so a text carrying both kinds of tag reads as both, and neither rule imports the other (014/015's separation, kept).
   None of the four is gated on the UI language the app is showing: the reader's keyboard decides what the text
   carries. **Re-cut 2026-10-20**, after this stage's plan was written: the reader asked for the two the plan had
   recorded as *not taken now* (`please include: 場景、escena`), so the shipped-locale rule's own four are in force.
2. **The brackets are ASCII `[` `]` only.** `［场景］` — a Chinese IME's own default — is the reader's text, painted
   and read as written, never repaired. This is 015's rule (`lib/comment.dart:14`) and 019's near-miss rule read the
   same way.
3. **Where a tag is recognised — the first reading, then the reader's own example re-cut it.** First written: a scene
   tag is recognised at a line's head **and alone on that line** (the item's *tag line*; wider than 014's paragraph
   head, narrower than 015's anywhere-in-a-paragraph). **Re-cut 2026-10-20**, when the reader appended
   `example: [场景] 1：青石观蚁` to the item: the tag must now **open a line, and the rest of that line is the tag
   line's own text** — a heading. What replaces "alone" is item 10 below, which decides what happens to that text; the
   narrow half survives untouched — a `[scene]` with any character **before** it on the line is the reader's ordinary
   text, and so is a `[scene]` in the middle of a sentence.
4. **A scene owns a range of the text, not a set of paragraphs**: every sentence that begins after that tag line's end
   and before the next scene tag's start (the item's fifth line, read against `lib/segmenter.dart:93`). Because the
   ownership is by offset, a text the reader never pressed Format on still has its scenes — the press only puts each
   tag at a paragraph head.
5. **The Format press gains the scene tag's own head rule** in `formatForDialogue` (`lib/dialogue.dart:249`): a scene
   tag that does not already start a paragraph gains a blank line before it, and nothing else in the text moves — the
   same contract 014's press keeps (the diff is blank lines only, one Undo takes it back, pressing twice is pressing
   once).
6. **The tag rides the one elision.** Its characters are a third kind of never-painted span in `displayOf`
   (`lib/comment.dart:386`), beside 015's tags and 019's marks, so the page and each frame keep one mapping (015's D3).
7. **The tag's line goes with its characters.** 019 elides only the marker because a mark's line carries the reader's
   own text; **since the re-cut the scene tag's line may carry a heading** (`[场景] 1：青石观蚁`), and under item 10's
   taken reading the **whole line** goes — its characters, the heading after them, and the break that ends it. What
   that costs is stated plainly there: it is the app's first rule that hides characters the reader typed.
8. **Nothing else moves**: a tag line contributes no sentence (whatever heading it carries), so the read, ▶'s steps,
   the assignment rows and the video's slots see exactly what the same text would see with the tag lines **deleted** —
   same count, same text, same order (FR-005, SC-003).
9. **Auto-assign is a pairing by index** — the i-th picked picture with the i-th scene in text order — expressed in
   020's own run model (contiguous runs, in order: 020's FR-003/FR-004) rather than as a second model beside it.
10. **The heading on the tag line — the one question the reader's example opened, and the reading this spec takes.**
    Three readings were possible; the first is taken and flagged, because it is the first rule in this app that hides
    characters the reader typed:
    - **taken — the whole tag line is the marker.** The tag and the heading after it are painted nowhere on the page,
      spoken nowhere, painted in no frame, and owned by no scene. It is consistent with the item's third line ("not
      showing"), with its fifth line (the scene's sentences begin **after** the line), and with Q1's "no visible break".
    - **refused — the tag is elided and the heading is painted as a heading** on the page (unspoken, and in no frame,
      because a heading is no sentence). It preserves the reader's own text; it makes the scene break visible, which
      Q1 refused, and it needs a heading treatment this app has no rule for (019's mark is the nearest, and it would be
      a second one).
    - **refused — the tag is elided and the rest of the line is the scene's first sentence** (014's role-tag shape,
      where `{阿明}: 我来了` elides only the prefix and reads the rest). It contradicts the item's fifth line: the
      scene's sentences would begin **on** the tag line.
    **This was the one decision that needed the reader's explicit yes** — hiding `1：青石观蚁` is hiding their own
    words, and no shipped rule in this app does that. It was put to them as Q6, with the other two readings drawn
    beside it, and **they answered `keep 1` on 2026-10-20**: the whole tag line is the marker, settled, and it is
    reversible only by their own later word — not by a later stage's preference.

### The questions this stage put to the reader, and the answers they gave

**Asked and settled 2026-10-20**: the reader's answer was the single token **`take recommendations`** — bound here,
one by one, to the five questions and to the recommended option each named, because the token alone would be ambiguous
out of context. A bare token is how this reader answers a form, and this is the binding written down.

The token settles **all five**: Q1's "no", Q2's min(N, M), Q3's "no scene", Q4's "ask first", Q5's "not in this
feature". Nothing in the table below was declined or re-token'd; each row's recommended option is now the requirement,
and each row's third column keeps the alternative it refuses so a later stage does not re-propose it.

| # | the question as put | the reader's answer (the recommended option, token-bound) | the alternative it refuses |
|---|---|---|---|
| **Q1** | Is a scene break visible in the page at all? | **No.** The item says the tag is not shown; the blank line that carried it disappears with it, so the page reads as if the scenes were ordinary paragraphs | a hairline separator, a scene number, or an indent — a surface the reader never asked for, and a second thing to keep out of every frame |
| **Q2** | When pictures and scenes differ in number? | **The first min(N, M) of each pair up**, in order; leftovers keep 020's own meanings — a picture with no sentences is a skipped picture, sentences with no picture are drawn on the plain background | stretching the last picture over the remaining scenes, or repeating the first scene's picture: both break 020's "one picture, one continuous run" model |
| **Q3** | The sentences **before the first** scene tag? | They belong to **no scene**, and auto-assign leaves them unassigned | folding them into scene 1 — invents an owner the reader did not write |
| **Q4** | Auto-assign over an assignment that already exists? | The option is offered whenever the content has scenes; **when anything is already assigned it asks first**, naming how many runs would be replaced, and refusing changes nothing | offering it only when empty (it hides exactly when the reader wants to redo it), or replacing silently |
| **Q5** | Scene **names** (`[scene 教室]`)? | **Not in this feature** *as data*: no name is parsed, stored or compared — the tag carries nothing but the boundary. The reader's example puts a **heading** on the tag line (`[场景] 1：青石观蚁`), which is Q6's question, not a name grammar | a name form now: a second grammar to keep in step, for a distinction the item never writes |
| **Q6** | The heading on the tag line: hidden with the tag, painted as a heading, or read as the scene's first sentence? | **Hidden with the tag** — the whole tag line is the marker (Clarifications item 10) | painted as a heading (keeps the reader's text; makes the break visible, which Q1 refused, and needs a second heading treatment); read as the first sentence (contradicts the item's fifth line) |

**Q6 was asked on its own, and answered on its own — `keep 1` (2026-10-20).** The token `take recommendations` bound
Q1–Q5 to the recommendations as they stood when it was sent; the reader's example arrived **after** that and opened a
shape none of the five named, and the reading taken hides characters the reader typed. So it was put as a form of three,
and the answer was `1` — the first of the three, the one the spec had taken: **the whole tag line is the marker**. Two
tokens, two dates, both bound in this table; nothing here is left standing.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A scene tag is a boundary, never a word (Priority: P1)

A reader whose content is written in scenes marks each scene's start with `[scene]` (their Chinese content with
`[场景]`). Reading the content, they never see a bracket and never hear one spoken: the scenes are simply paragraphs
one after another, and the read moves from the last sentence of one scene to the first of the next in the same voice.
A video renders the same way — no frame carries the tag, and the sentence after a boundary has its own slot.

**Why this priority**: it is the item's second and third lines, and nothing else in the item works until the tag is
recognised and withheld from every surface.

**Independent Test**: one content with three scene tags; compare the page's painted string, the read's utterance list,
▶'s step list, the Assign sentences rows and the video's slot count against the **same content with the tag lines
deleted**. All five are equal — that is the whole story.

**Acceptance Scenarios**:

1. **Given** a text whose scenes are marked, **When** the reading page paints it, **Then** no `[scene]`/`[场景]`
   characters and no blank line where a tag stood appear anywhere in the painted string.
2. **Given** the same text, **When** the read reaches a boundary, **Then** no utterance is spoken for the tag and the
   next sentence follows the previous one with no pause the boundary invented.
3. **Given** the same text, **When** a video is rendered, **Then** the tag appears in no frame, and the first sentence
   after the boundary opens its own slot.
4. **Given** a tag line carrying a heading (`[场景] 1：青石观蚁`, the item's own example), **When** the page paints it
   and the video renders it, **Then** neither the tag nor the heading appears anywhere, and no utterance is spoken for
   either — the scene's first sentence is the first thing read after the previous scene's last.

---

### User Story 2 - Format gives a scene tag its own paragraph (Priority: P1)

The reader's text has `[scene]` in the middle of a paragraph — a shape a keyboard produces easily. One press of the
edit toolbar's Format button puts a blank line before the tag line and changes nothing else; one Undo takes the whole
press back.

**Why this priority**: the item's second line asks for it explicitly ("same as role tag"), and it is what makes the
scene a paragraph of its own for the reader who cares about layout.

**Independent Test**: Format a text with one mid-paragraph tag; the diff is blank lines only, the tag's characters are
byte-identical, Undo restores the input, and a second press is a no-op (014's own contract, re-read for this tag).

**Acceptance Scenarios**:

1. **Given** a paragraph holding `[scene]` after other text, **When** Format is pressed, **Then** a blank line stands
   before the tag line and no other character of the text changed.
2. **Given** the formatted text, **When** the reader presses Undo once, **Then** the text is the input again.
3. **Given** a text whose scene tags already start their own paragraphs, **When** Format is pressed, **Then** the text
   comes back byte-identical and the button reports nothing to do.

---

### User Story 3 - One picture per scene, in order (Priority: P2)

On the Assign sentences page, a content with scene tags offers one extra option. Choosing it gives each picked picture
the sentences of one scene, in the order the reader wrote the scenes and the order they picked the pictures. The result
is an ordinary assignment: the reader can still move a picture, add a sentence by hand, or delete a run.

**Why this priority**: the item's fourth, fifth and sixth lines. It is a shortcut over 020's model, so it can land after
the tag itself works.

**Independent Test**: eight pictures, three scenes — the first three pictures hold the three scenes' sentences (each
contiguous, in order), the other five hold none; and the result is identical to the same assignment made by hand.

**Acceptance Scenarios**:

1. **Given** a content with three scenes and eight picked pictures, **When** the option is chosen, **Then** pictures 1–3
   hold scenes 1–3's sentences in order and pictures 4–8 hold none.
2. **Given** the assignment the option just made, **When** the reader moves picture 2 right, **Then** the page's own
   rules apply and nothing is locked.
3. **Given** a content with no scene tag, **When** the Assign sentences page opens, **Then** no such option appears.

---

### User Story 4 - A near miss stays the reader's text (Priority: P3)

A reader types `［场景］` with a Chinese IME, or `[scenes]` or `[escenas]`, or writes `[scene] and then the dialogue`
on one line.
Each is painted, read, assigned and drawn like any other characters — never repaired, never silently dropped.

**Why this priority**: 014's own assumption that a shape failing the tag grammar is the reader's text, and 019's
FR-002/FR-014 (same content, its own file), set this rule for every tag in the app; it is what keeps the
new rule from eating the reader's own words.

**Independent Test**: a content of near misses renders and reads byte-identically to the same text with the feature
absent (a frame and an utterance comparison against today).

**Acceptance Scenarios**:

1. **Given** `［场景］` on its own line, **When** the page paints it and the read speaks it, **Then** the characters are
   the reader's own, unchanged.
2. **Given** `[scene]` with text after it on the same line, **Then** the line is ordinary text and starts no scene.

### Edge Cases

- **Two scene tags in a row** — the first scene is empty: it owns no sentence, and auto-assign consumes no picture for
  it (Q2's rule, applied to an empty scene).
- **A tag as the last line** — the last scene is empty; nothing follows it to own.
- **A tag inside a comment's span** (015) — not a scene: 019's `inside` seam (`lib/head_tag.dart:58`), read in the
  other direction, keeps the two rules from eating each other's text.
- **A tag on a `#` title line** (`# [scene]`) — not a scene: a character precedes the tag on the line, so the title is
  painted and the brackets are the reader's.
- **A tag line carrying a heading** (`[场景] 1：青石观蚁`, the item's own example) — the whole line is the marker under
  item 10's taken reading: hidden on the page, in no frame, and no scene owns it. Its **own delimiters start no
  sentence**: a heading like `[场景] 第一场。` loses that `。` with the line.
- **A tag line whose heading is the only text between two tags** — the scene is still empty (FR-003), because the
  heading is no sentence: an empty scene consumes no picture (Q2).
- **A tag line inside a paragraph the reader never formatted** — still a boundary and still hidden, heading and all;
  the Format press only makes it a paragraph head.
- **CRLF content** (the reader's own phone-typed text) — a `\r` before the line's break is trailing whitespace and does
  not defeat the tag; the same for trailing spaces and tabs.
- **Indentation before the tag** — allowed: the app's own prefix rule already trims leading spaces at a line head
  (`lib/dialogue.dart:120-122`).
- **A tag inside a paragraph the reader never formatted** — still a boundary; the Format press only makes it a
  paragraph head.
- **A content of nothing but tag lines** — no scene owns a sentence, so the page, the read and the video are what an
  empty content is today.
- **Many scenes** — the scan is one pass, no cap (A6); a text with no `[` at a line head costs what it costs today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST recognise **four spellings** of the scene tag — `scene` and `escena` in any ASCII case,
  `场景` (Simplified) and `場景` (Traditional) — with ASCII `[` `]` brackets and nothing else. All four MUST be live in
  every content whatever UI language the app is showing. No other spelling (including 015's four comment spellings)
  opens a scene.
- **FR-002**: A scene tag MUST be recognised **only at a line's head**: leading spaces/tabs are tolerated, nothing but
  the tag may precede it on the line, and **whatever follows it on that line is the tag line's own heading**
  (`[场景] 1：青石观蚁` — the item's own example), tolerated with trailing spaces/tabs/`\r`. A tag with any character
  **before** it on the line, or in the middle of a sentence, is the reader's ordinary text.
- **FR-003**: A scene MUST own **every sentence that begins after its tag line's end and before the next scene tag's
  start**, in text order; sentences before the first tag belong to no scene, and a scene with no sentence between it
  and the next tag is empty.
- **FR-004**: The tag's characters, **the heading that follows them on the same line, and the break that ends that
  line** MUST be painted nowhere: in the reading page and in every frame of a video the text MUST read as if each tag
  line had been deleted. No blank line, indentation, heading or gap may mark where a tag stood. (Clarifications item 10:
  this is the app's first rule that hides characters the reader typed, and the reader settled it themselves —
  `keep 1`, 2026-10-20.)
- **FR-005**: A scene tag and its line MUST be **silent and invisible to every derived list**: never spoken, never a
  ▶ step, never a row on the Assign sentences page, never a video slot — a heading on that line is no sentence, so no
  delimiter in it starts one. The read's utterance list, the step list, the assignment rows and the slot list MUST equal
  the same text's with the tag lines **deleted** — same count, same text, same order. This MUST hold whether or not the
  content's pictures were assigned by hand or by FR-008's option.
- **FR-006**: The edit toolbar's **Format press MUST give each scene tag its own paragraph** when it does not already
  start one — a blank line before the tag line, nothing else — and MUST keep 014's contract: the difference from the
  input is blank lines and only blank lines, one Undo takes the whole press back, a text with nothing to format comes
  back byte-identical, and pressing twice is pressing once.
- **FR-007**: A shape that fails FR-001 or FR-002 MUST be the reader's own text: painted, read, stepped, assigned and
  drawn as written, never repaired, never removed.
- **FR-008**: The Assign sentences page MUST offer **one option to auto-assign scene sentences to pictures** whenever
  the content holds at least one scene, and MUST NOT offer it when the content holds none.
- **FR-009**: That option MUST pair the **i-th picture with the i-th scene**, scenes in text order and pictures in the
  page's own order (021's move controls decide it, not the pick order the OS returned).
- **FR-010**: The assignment the option produces MUST be one 020's rules already allow: each picture's sentences
  **contiguous** and the whole assignment **in order**; no sentence may land in two places.
- **FR-011**: The result MUST be an ordinary assignment — the page's own controls MUST be able to edit, move, extend or
  delete any run it made, nothing is marked as automatic, and nothing new is stored.
- **FR-012**: When anything is already assigned, the option MUST **ask first**, naming how many runs would be replaced;
  the reader's refusal MUST leave the assignment exactly as it was (Q4).
- **FR-013**: When pictures and scenes differ in number, the option MUST pair the **first min(N, M) of each** and leave
  the leftovers to 020's own meanings: a picture with no sentences is a skipped picture, and sentences with no picture
  are drawn on the plain background (Q2).
- **FR-014**: Sentences **before the first** scene tag MUST belong to no scene and MUST NOT be assigned by the option
  (Q3).
- **FR-015**: A scene tag written **inside a comment's span** (015) or on a line that carries a **head mark** (019) is
  not a scene (the shared `inside` seam, `lib/head_tag.dart:58`).
- **FR-016**: A content with **no** scene tag MUST be unchanged on every surface: the painted string, the steps, the
  slots and the rendered frames identical to today's (the identity criterion 015 and 019 both keep).
- **FR-017**: The heading on a tag line MUST belong to **no scene** and MUST be assigned to **no picture**: it is not a
  sentence, so auto-assign (FR-008) never consumes a picture for it, and no run may include it.

### Key Entities *(include if this feature involves data)*

- **SceneTag**: the spelling as written, the offset of its `[`, the end of its own characters, the end of its **line**
  (the heading included), and the line it stands on. Derived on every open, never stored.
- **Scene**: its tag, its own ordinal in text order, and the range of sentences it owns (empty allowed). Derived, never
  stored.
- **AssignmentRun** (020's, unchanged): one picture and the contiguous, ordered sentences it holds. This feature adds
  no field to it — an auto-assigned run is indistinguishable from a hand-made one.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: (measured, identity) A content with no scene tag produces **byte-identical** results to today's build:
  the painted display string, the ▶ step list, the assignment rows and the video's slot list. *Measured 2026-10-22*:
  the 857-test baseline passed untouched (901 with this feature's own rows), and six closed-feature device rows were
  re-run on tag-free content — `klhu_walk_comment.py 17` 24/24, `klhu_walk_head.py 10` 14/14, `klhu_walk_step.py 5`
  13/13, `klhu_walk_assignment.py 6` 14/15, `klhu_walk_pass.py 8` 5/5, `klhu_walk_video.py 32` 41/41. The one failure
  is 020's own predicate reading the chip wording 021 replaced (`No sentences assigned`); every count that row measures
  is its own (breakpoint.md, row 15).
- **SC-002**: (measured, elision) In a content mixing scenes, comments and head marks, the painted string holds **zero**
  characters of any scene tag (and no double blank line where a tag line was), and equals — byte for byte — the same
  content with the tag lines deleted. *Measured 2026-10-22 on the fixture*: **43 characters, equal to the twin**; the
  two pages ink the same **136** scanlines with **0** differing, and the widest gap inside the text block is **71 px on
  both** — a tag line left painted would add rows a line's own spacing cannot explain.
- **SC-003**: (measured, silence) The utterance list, the step count, the assignment row count and the video's slot
  count equal the deleted-line content's **exactly**: same count, same text, same order — the same equality measured
  with the pictures assigned by hand and by the option. *Measured 2026-10-22*: **seven utterances on the fixture and
  seven on the twin**, identical texts and order, none blank, none carrying a tag; the app's own ranges read
  `0..6, 8..14, 14..19, 21..26, 26..30, 30..34, 56..70`, the jump `34 → 56` being both tag lines and the blank lines
  between them.
- **SC-004**: (measured, Format) For a text with a mid-paragraph tag: the press's diff is **blank lines only**, one Undo
  restores the input byte for byte, and a second press changes nothing.
- **SC-005**: (measured, pairing) Across the N×M cases measured (N pictures × M scenes, including 0, 1, equal and
  N<M / N>M): the option creates **min(N, M)** runs, each scene's sentences are contiguous and in order, no sentence is
  in two runs, and the result equals **the same assignment made by hand** run for run. *Measured 2026-10-22*: the
  seven-cell grid on the unit side, and on the device five pictures going `0,0,0,0,0 → **2, 3, 1, 0, 0**` with
  **six** sentences in the runs — the third scene owns one sentence — and the fifth picture still movable afterwards.
- **SC-006**: (device) On the device: a real read and a real render of a content with scenes show **no** tag characters
  in any frame and **no** pause or slot at a boundary; the page's dump holds no tag string. *Measured 2026-10-22*
  (emulator-5554): the page's dump carries the twin's own block and no tag string; the render reports
  `pictures=5 ranges=(0,154),(155,272),(273,373),None,None sentences=7` and **374 frames** (545877 bytes), with no
  slot span reaching a tag line's offsets.
- **SC-007**: (measured, near misses) Each near-miss shape (`［场景］`, `［場景］`, `[scenes]`, `[escenas]`,
  `text [scene]`, `# [scene]`, `[scene]` inside a comment) stays painted and spoken exactly as today, frame for frame and utterance for utterance.
- **SC-008**: (measured, the item's own example) For a content carrying `[场景] 1：青石观蚁`, the painted string and
  every rendered frame hold **none** of those characters (tag or heading), the read speaks **no** utterance for them,
  the slot count equals the same content with that whole line deleted, and auto-assign creates one run for that scene's
  sentences with the heading in none of them. *Measured 2026-10-22*: the fixture's first tag line **is** that shape —
  the page paints neither `[场景]` nor `青石观蚁`, the read's seven utterances hold neither, and the pairing gives its
  scene the run `2` sentences wide with no heading in any of them.

## Assumptions

- **A1**: The tag is the reader's own typing, with ASCII brackets on whatever keyboard they use; the full-width form is
  not a spelling this app teaches, repairs or accepts (015's A1, 019's near-miss rule). The four spellings are one per
  **shipped UI locale** (en, zh-Hans, zh-Hant, es), following 015's own four, and none of them is gated on the UI
  language showing.
- **A2**: Scenes are **ordinals** ("the third scene"): no name is parsed, stored or compared. The reader's own example
  puts a heading on the tag line (`[场景] 1：青石观蚁`), and under Q6's taken reading that heading is part of the marker
  — text, not data.
- **A3**: A text's scenes are derived on every open and never stored — the same shape as 014's roles, 015's comments
  and 019's marks.
- **A4**: The Format press stays the **only** thing that changes the reader's text; nothing formats behind their back.
- **A5**: 020's and 021's assignment rules are the ones in force; this feature adds a shortcut into them, never a second
  model beside them.
- **A6**: No cap on the number of scenes; the scan is linear in the text's length.
- **A7**: The reader validates on their own device with their own content, which carries Chinese tags (`[场景]`); the
two spellings that content does not carry (`場景`, `escena`) are proved by row 1's table and its twin content instead.
- **A8**: The option's own label and the three strings of its replace question are new strings in all four ARBs (023
  added the 131st this way); the count grows by four to 135 and the key audit (`test/l10n_keys_test.dart`) must stay
  green.

## Out of scope

- **Scene names, subtitles or descriptions** (`[scene 教室]`, a scene heading painted anywhere) — Q5.
- **Any scene-aware surface besides the one option**: no scene list, no jump-by-scene, no scene picking for voices, no
  per-scene aspect, no per-scene framing beyond what 020 already does with a picture.
- **A visible scene break** — no separator, number, indent or blank line (Q1).
- **A pause in the audio** at a scene boundary.
- **Nested or hierarchical scenes**, and a scene tag inside 015's comment span (it is the comment's text).
- **Full-width brackets** `［场景］` and any near miss — these stay the reader's text.
- **Exporting or re-importing scene metadata**, and any storage of scenes.
- **Markdown**: 019's own decision stands; a scene tag is not a markdown heading.

## What this feature supersedes, and the receipts it re-measures

**It supersedes nothing.** It adds a third kind of derived tag beside 014's `{name}` and 015's `[comment]`/`[注]`/
`[註]`/`[nota]`, and a shortcut over 020's assignment model. No earlier rule is withdrawn or re-worded.

**The receipts it re-measures, because one seam serves them all** — `displayOf` (`lib/comment.dart:386`) and the
sentence list (`lib/segmenter.dart:93`, stepped by `lib/comment.dart:206` and slotted by `lib/video_timeline.dart:80`):

| whose receipt | what it reads | why this feature can move it |
|---|---|---|
| 015's painted-string and step rows | the display string, `stepRanges` | a third elided kind and a tag-only line that no longer yields a sentence |
| 019's line/display rows | `displayOf`, its mark spans | the same elision list, one more kind in it |
| 016's ▶ step rows | `stepRanges` | a tag-only line stops being a step |
| 020's and 021's assignment rows | the sentence list | one row fewer per tag line, and the new option's runs |
| 012's slot and frame rows | `lib/video_timeline.dart:80`, `lib/video_renderer.dart:314` | one slot fewer per tag line, and no tag in any frame |

Each is named as a re-run in the plan's own quickstart, with the two identity criteria (FR-016, SC-001) as the guard
that a content without tags is untouched.
