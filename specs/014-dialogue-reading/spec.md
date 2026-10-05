# Feature Specification: Multi-Role Dialogue Reading

**Feature Branch**: `014-dialogue-reading`

**Created**: 2026-10-01

**Status**: Draft

**Input**: the reader's own text, item **014** of `text.txt`, quoted verbatim:

> 014. 多人对话(朗读):
>      文本格式依照角色分配，每个角色分配不同的句子。旁白也是一个角色。
>
>     1.文本格式示例：角色前缀 + 冒号 + 内容
>
>      旁白：今天天气很好，适合出去走走。
>
>      阿明：今日个天气真系唔错啊，行下公园好舒服。
>
>      May：系啊，太阳晒住，风又凉爽，真系适合周末。
>
>      阿芳：我好少黎呢个公园，原来呢度风景咁靓。
>
>     2.用户为每个角色选择不同的语音。语言由文本内容决定。
>
>      旁白：男声。
>
>      阿明：男声。
>
>      May：女声。
>
>      阿芳：女声。
>
>      如无设定，系统自动分配， 优先选择同语言，同性别，同方言。
>
>     3.设定文本类型：可选择 (标准，多人对话)
>      标准: 一个旁白角色. 读所有内容。（默认）
>      多人对话: 多个角色分别读各自的内容。不读角色前缀 （即：不读"旁白："，"阿明："等），是对话不是读书。
>
>     4.生成视频时，语音与对话(朗读)相同，只显示当前句子，文字不显示 角色前缀 + 冒号，只显示内容。

> **Amendment, 2026-10-02 — the format is a braced tag.** The reader moved the prefix's form from
> "角色前缀 + 冒号" to a **braced tag**: `{名字} 内容`, the colon now optional. A colon is punctuation a
> dialogue also contains — 他说：我来了, 时间：8 点, a clock's 12:30, a URL's https:// — so "a name and a
> colon" had to be guessed at with a length bound and a whitespace ban, and a long name or a name with a
> space in it was silently not a speaker. Braces are the reader's own, bound the name exactly, and give
> the name any length and spaces it needs. The quoted text above is the reader's own, kept as written;
> FR-004 carries the rule that now applies, and the Clarifications session of 2026-10-02 records the
> choice.

> **Amendment, 2026-10-03 — a turn is a paragraph, not a line.** The reader's own correction while
> reviewing the plan: *"I see the role turn ends on the line end. that's wrong. one role turn read at
> least one sentence. one sentence can be in multiple line. one role turn can read more than one
> sentence. I like to use paragraph to separate the role turn. Means the role turn ends on paragraph.
> a paragraph should starts with a role tag. otherwise it's a narration."* So a turn's boundary is the
> **blank line** — the app's own paragraph (`lib/segmenter.dart:71-108`, already the unit
> `resolveParagraphSpeeches` iterates) — and a turn holds as many lines and sentences as its paragraph
> does. The tag is read at the **paragraph's head only**. The quoted text above is the reader's own, kept as
> written; FR-003/FR-004/FR-009 carry the rule that now applies, and the Clarifications session of
> 2026-10-03 records the choices. The tag's own form (2026-10-02) is unchanged.

> **Amendment, 2026-10-03, same round — a tag inside a paragraph is ordinary text, and the editor gets a
> Format button.** The reader's second correction, on reading the first one written down: *"段内（非首行）行首的
> 标签：不要从朗读文本里剥掉。按正常文本读。规则我想写的死一点。像一个剧本。add a 'Format' button in editor, so user
> can start a pagagraph for inline {rolename}."* What the app removes is the paragraph head's own prefix and
> nothing else: every other `{…}` in the reader's text is characters, spoken, highlighted and painted as
> written. That makes the format **the reader's own contract**, not something the app repairs — and the
> remedy for a tag that is not a paragraph head is the editor's **Format** action (FR-024), which inserts the
> blank lines and changes nothing else. Deleted by this correction: the "stripped inner tag" clause of the
> first version of this amendment, and with it the last place this feature rewrote the reader's text behind
> their back.

**Input (the reader's own example, 2026-10-01)**: the same four turns, with the voice each role
should get — 旁白：成熟男声, 阿明：年轻男声, May：年轻女声, 阿芳：年轻女声 — and the sentence
"如无设定，系统自动分配". *The age words are the one part of this example the specification does not
take literally, and the reader's own answer of 2026-10-01 chose that outcome; see FR-017 and the
Clarifications entry that records it.*

## Clarifications

### Session 2026-10-01

Six decisions were put to the reader as numbered options and answered the same day. Each entry names
the wording it settles, so a later reader sees the choice was deliberate rather than a drift.

- **Q**: The voice data this repository holds has no age: `lib/models/voice_mapping.dart:18-23` records
  that the engine exposes none and that "any value would be a guess". How do 成熟男声 and 年轻男声
  become real? **A**: *C* — no age is modelled at all. A role's voice is chosen from the voices the app
  already offers, on the properties it already has evidence for (language, dialect, gender), and the
  role's own pick is always the reader's to make. The consequence to accept: the reader's example names
  a property the app will not guess, so a role's card shows the engine's own voice name (普通话 CCD,
  广东话 YUD) instead of 年轻/成熟. Settles the example's voice column (FR-012, FR-017, A2).
- **Q**: Is the turn's language detected from the text, including a *dialect* (a Cantonese line written
  in Chinese characters)? **A**: *C* — the dialect is not detected from the text. Cantonese is a voice
  under 中文 in this app (007's decision; `lib/reader_service.dart:279` lists `['zh','cmn','yue']` for
  the Chinese list), so the role's picked voice carries the dialect and the text only carries the
  language. The consequence to accept: 阿明's Cantonese line is detected as 中文 like every other Chinese
  line, so the reader gives 阿明 a 广东话 voice by hand; nothing about it is guessed from 唔/系/咁.
  Settles "语言由文本内容决定" for dialects (FR-011, FR-013, A3).
- **Q**: How strictly is a role prefix recognised? The reader's own text contains 他说：我来了-shaped
  ambiguity (a colon is not proof of a speaker). **A**: *C* — the app **proposes** the roles it found and
  the reader confirms: the confirmed set is per content and remembered. Settles the prefix rule's
  escape hatch (FR-004, FR-006, FR-007). *(The prefix's own form was settled the next day — see the
  2026-10-02 session: a braced tag, not a name and a colon.)*
- **Q**: Does a role's turn read as one utterance, or sentence by sentence? **A**: *sentence by sentence*,
  as the app reads today — one utterance per sentence, which is what 011's highlight and 010's resume
  point are built on. The role decides the voice and which text is spoken; it does not change the unit
  of speech. Settles the turn's speech unit (FR-010).
- **Q**: Where do the text type, the confirmed roles and the picks live? **A**: *as 012 stores a content's
  video* — one store keyed by the content's own key, outside 008's index, so the index schema and every
  existing content are untouched. Settles the storage question (FR-021, A1).
- **Q**: Is a role prefix ever part of what is spoken, highlighted or shown in the video? **A**: *no* —
  the prefix is not inside any sentence's span, so it cannot be spoken, highlighted or painted by
  construction rather than by filtering. Settles FR-005 and the video's own text (FR-018).

### Session 2026-10-02

Three decisions on the **tag's own form**, put to the reader as numbered options and answered the same
day, after the format was measured against text that is not this feature's.

- **Q**: Which delimiter pair marks a role's name — `{May}`, `#May#`, `%May%`, `(May)` or `$May$`?
  **A**: *`{ }`* — braces, and one pair only. Measured over a 15,356-line prose corpus, lines starting
  with `#` are Markdown headings (1,174 of them) and lines starting with `(` are ordinary punctuation
  (384, with 5,052 lines containing one — the reader's own phrasebook carries "(informal)"); `$` carries
  money and math (15 line-starts), `%` carries percent and printf. Braces mean "a placeholder" already,
  and 6 lines of 15,356 were code samples. The pair is ASCII `{` `}`; full-width `｛｝` and the CJK
  brackets are deliberately **not** accepted (the reader chose the single pair), so a tag typed with a
  Chinese IME's full-width braces is narration. Settles the tag's form (FR-004).
- **Q**: With the name bounded by braces, is the colon after it still required? **A**: *no, optional* —
  `{May} : hello`, `{May}: hello` and `{May} hello` are the same turn. A required colon only adds a way
  to fail silently (a forgotten colon turns a whole turn into narration). Settles the separator
  (FR-004).
- **Q**: What becomes of the colon prefix `名字：` the first draft accepted? **A**: *replaced* — only a
  braced tag is a role prefix; `名字：` is now plain text and reads as narration. This deletes a whole
  class of edge cases (the clock, the URL, 时间：8 点, a two-colon line, a nine-character name) at once:
  the rule stops guessing. Settles FR-004 and the edge cases it used to carry.

Nothing in the reader's library uses either shape yet — the dialogue work has not started (the reader,
2026-10-02: *对话还没有开始。现有的库不是问题*), so the replacement costs no migration and SC-005's
invariance stays a test obligation rather than a data one.

### Session 2026-10-03

Three decisions, all the reader's own corrections while reviewing the plan — two on the **turn's boundary** and
one on the remedy the format needs. They are recorded here because they change what every other requirement is
read against.

- **Q**: Where does a role turn end — at the line's end, or at the paragraph's? **A**: *the paragraph (a
  blank line)*. A turn is one paragraph: it holds as many lines and sentences as the reader wrote in it,
  and the app speaks it sentence by sentence exactly as it speaks a paragraph today (FR-003, FR-010). The
  consequence to accept: a text whose turns are written without blank lines between them is one turn, so
  consecutive speaker lines pasted without a blank line are read in one voice. Settles FR-003, and the
  unit A8 and FR-009 are read against.
- **Q**: A second tag inside the same paragraph (no blank line between them) — a new turn, part of the
  one turn, or something else? **A**: *ordinary text*. The reader first answered "stripped from the spoken
  text", and on reading that written down replaced it: *不要从朗读文本里剥掉。按正常文本读。规则我想写的死一点。
  像一个剧本。* Only the **paragraph's head** names a role; any other `{…}` is characters like any other, so
  `{阿明} 你好。` and `{阿芳} 我很好。` on two consecutive lines of one paragraph are 阿明's single turn, spoken
  as `你好。{阿芳} 我很好。` — braces and all. The consequence to accept: the format is the reader's own
  contract and the app does not repair it, so a missing blank line is read out loud rather than silently
  dropped. Settles FR-004's second half; the remedy is the next entry.
- **Q**: The reader's text is theirs and the app never rewrites it (A9) — so how is a tag that is *not* at a
  paragraph head turned into one? **A**: *the editor's Format action*, which the reader asked for in the
  same breath: *add a 'Format' button in editor, so user can start a pagagraph for inline {rolename}*. One
  press inserts a blank line before every tag that is not already the head of its own paragraph — the only
  characters it adds are blank lines (the reader's answer: *不改：只插空行，字形一个字不动*), it is one undo
  step, and it is disabled when it would change nothing, as Undo is with nothing to undo. The consequence to
  accept: the action takes the reader's braces at face value, so a `{…}` that is not a speaker becomes a
  paragraph head and is then proposed as a role — the role list is where that is removed (US3), and one Undo
  reverses the whole press (US5). Settles FR-024.

### Session 2026-10-05

One decision, made while walking the device rows: row 25 raised what the app actually *does* with a removed
name's paragraphs, and the reader settled it rather than leaving it to be re-discovered.

- **Q**: A name is removed from the role list. Its paragraphs are narration (FR-009) — read in *whose*
  voice? **A**: *the narration's own* — the reader's pick for that language, and with no such pick the OS
  default. That is what ships for every paragraph of a 标准 content (FR-002), and the device read of row 25
  shows it whole: `narration(zh-Hans)→os-default`, with the removed turn's lines carrying no role and no
  voice at all (`klhu speak p2 s0 "系啊，太阳晒住，风又凉爽。"`). The reader was shown the alternative —
  giving a removed name's paragraphs a voice out of the dialogue's own pool, at the cost of re-writing
  FR-009's *today's behaviour, exactly* and rows 23-25's expectations — and chose to keep this
  (*保持现状*, 2026-10-05). So: **removing a role does not hand its paragraphs to another role, and does not
  put them into any dialogue voice**; a reader who wants a different sound for those lines picks the
  *language's* voice in 语音 (row 24's own path, `voice_<language>`), which narration reads with. Settles
  FR-009's remaining half and closes the one question row 25 left open.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A dialogue reads as a dialogue (Priority: P1)

The reader opens a content whose paragraphs tag their speaker — {旁白} …, {阿明} …, {May} …, {阿芳} … —
and sets its text type to 多人对话. From then on the app speaks each paragraph as that role's turn —
however many lines and sentences it holds — in that role's own voice, and the tags are never spoken:
what the reader hears is the conversation, not the script. The same content in 标准 (the default) is read
exactly as it has always been read, tags included.

**Why this priority**: this is the feature. Without it there is nothing to voice per role, no video to
render differently and nothing to confirm. It is also the only story that changes what the engine is
asked to say, so it is the one that must not regress 标准 — every existing content and every 011/012
receipt depends on 标准 being untouched.

**Independent Test**: open the four-role content above (its paragraphs tagged `{旁白} …` and so on), set
多人对话, read from the top on the device and read the app's own per-utterance line: four turns, in
order, each its own content with no role name and no braces in it; then set the same content back to
标准 and read again — every utterance is the raw stored text, tags included.

**Acceptance Scenarios**:

1. **Given** a content in 多人对话 with four roles, **When** the reader reads from the top, **Then** the
   utterances are the turns' own contents in order, and no utterance contains a role name or a brace of
   a tag.
2. **Given** the same content, **When** its text type is 标准, **Then** the read is the stored text
   itself — the tags are spoken — and nothing about the read differs from the shipped app.
3. **Given** a turn whose content is longer than one sentence — including one the reader wrote across
   several lines — **When** it is read, **Then** it is spoken sentence by sentence, and the highlight
   follows the sentence being spoken (011's own behaviour).
4. **Given** a content in 多人对话, **When** the reader taps inside a role tag, **Then** the turn's
   first sentence is spoken — the tag is not a place with no answer.
5. **Given** a content whose text carries no role tag at all, **When** it is set to 多人对话, **Then** it
   reads exactly as it does in 标准, and the app says that no role was found rather than failing.
6. **Given** a content already being read (or paused mid-sentence) in 标准, **When** the type is switched
   to 多人对话, **Then** the stored reading position and the highlight are where they were, and the read
   continues from there.
7. **Given** the reader deletes a content, **When** it is gone, **Then** its text type, roles and picks
   are gone with it (nothing is left behind for a content that no longer exists).

---

### User Story 2 - Every role has its own voice (Priority: P2)

The reader gives 旁白 a male Chinese voice, 阿明 a 广东话 male voice, May and 阿芳 female voices — or
leaves some unset and lets the app assign one. The dialogue sounds like four people; no two roles
share a voice when the device has enough voices of the kind each turn needs.

**Why this priority**: this is what makes 多人对话 worth using — a dialogue read in one voice is a text
read aloud with names in it. It is P2 rather than P1 because US1 alone already changes *what* is
spoken, and this story only changes *whose* voice says it; the two are separately demonstrable.

**Independent Test**: on the four-role content, assign two roles by hand and leave two unset, read it,
and read the app's own lines: each hand-picked role's utterances name its voice, and each unset role
has been given a voice of its turn's language, of the same dialect where one applies and of the same
gender where the device has one — different from the other roles' where the device allows it.

**Acceptance Scenarios**:

1. **Given** four roles with no picks, **When** the content is read, **Then** each role's utterances use
   a voice of that turn's language, and the app's own list shows which voice each role got.
2. **Given** the same content, **When** the reader gives 阿明 a 广东话 voice, **Then** 阿明's utterances
   are spoken in that voice (its own locale), even though the line's text is detected as 中文.
3. **Given** the same content read twice, **When** nothing was changed, **Then** the same roles get the
   same voices (the assignment is deterministic).
4. **Given** a device where fewer voices of the needed kind exist than there are roles, **When** the
   content is read, **Then** every role still has a voice and the sharing is visible in the role list.
5. **Given** a role whose pick the reader clears, **When** the content is next read, **Then** the role is
   assigned again rather than left silent or refused.

---

### User Story 3 - The roles I confirmed are the roles in the text (Priority: P2)

The reader opens a text that uses braces for something a voice should not own — `{laughs} hello`, a
stage direction, or a name they would rather hear read aloud — and the app has proposed it as a role.
The reader removes it once; from then on that content reads it as narration, and the removal is
remembered.

**Why this priority**: the braces are the reader's own text, so the rule no longer guesses what a
speaker is — but it cannot know what the reader *meant* by a pair of braces, and the removal is how a
text is corrected without editing it (008's editor is the other path, and a tag deleted from the text is
gone for good). It is P2 because a text whose tags are all real never needs it — US1 and US2 work
without it.

**Independent Test**: on a content with one real role and one brace pair that is not a speaker, remove
the false name from the list, read, and read the app's own lines: the false name is never a speaker and
the paragraph it heads is narration; close and reopen the content and the removal is still in force.

**Acceptance Scenarios**:

1. **Given** a 多人对话 content, **When** it is opened, **Then** the roles found are listed in order of
   first appearance with the number of turns each has, and the list is a proposal the reader can edit.
2. **Given** a proposed name that is not a role, **When** the reader removes it, **Then** the paragraphs
   it heads are narration and the name is never treated as a speaker in that content again.
3. **Given** a removal, **When** the app is restarted, **Then** the removal is still in force.
4. **Given** a content whose text the reader then edits so that a removed name is genuinely a speaker
   again, **When** the content is reopened, **Then** the app proposes it once more (an edit is a change
   of the text, and the proposal follows the text).
5. **Given** a content where every proposed name was correct, **When** the reader changes nothing,
   **Then** the read uses the proposed set without any further step.

---

### User Story 4 - The dialogue's video is the dialogue (Priority: P3)

The reader renders a 多人对话 content as a video: the voices are the ones the read uses, role for role,
and every frame shows only the sentence being spoken — never {阿明} in front of it.

**Why this priority**: it is the fourth thing the reader asked for and it rides on the resolution the
first three stories establish. P3 rather than P2 because 012 already ships the render pipeline: this
story changes which voice a frame's audio uses and which characters a frame paints, not how a video is
made.

**Independent Test**: render the four-role content, sample the frames and the audio: no frame contains
a role tag, and each spoken turn's audio is that role's voice, as the read's own lines name them.

**Acceptance Scenarios**:

1. **Given** a 多人对话 content with per-role voices, **When** it is rendered, **Then** each turn's audio
   is the voice the read uses for that turn and the frames show the sentence's content alone.
2. **Given** the same content in 标准, **When** it is rendered, **Then** the video is what 012 produces
   today, unchanged.
3. **Given** a turn whose content is two sentences, **When** the video is rendered, **Then** each sentence
   has its own frame(s) — the video's own unit is unchanged by roles.
4. **Given** a content whose roles were auto-assigned, **When** it is rendered, **Then** the video's
   voices are exactly the read's (one resolution, not two).

---

### User Story 5 - Writing the format: one press puts every tag at the head of its own paragraph (Priority: P3)

The reader types or pastes a dialogue with its tags inline — `{阿明} 你好。{阿芳} 我很好。` — and presses
**Format** in the editor. The app inserts a blank line before every tag that is not already at the head of
its own paragraph, so the text becomes the format the reader's own rule expects. Nothing else about the text
changes: not a character of the reader's words, no tag added, no tag removed, no separator rewritten — and
one Undo puts the text back exactly as it was.

**Why this priority**: it is the writing half of the format. The format is the reader's own contract and the
app deliberately neither guesses nor repairs (FR-004), which is exactly why the reader needs a way to
produce it. It is P3 because nothing about reading, voices or the video depends on it: a dialogue written
correctly by hand never needs the button, and without it a misplaced tag is simply read — braces and all — the
way FR-004 says.

**Independent Test**: in the editor, put a text whose second tag is inline on one line, press Format and
read the editor's own text — a blank line stands before every tag and every other character is the reader's
own; then one Undo restores the earlier text byte for byte.

**Acceptance Scenarios**:

1. **Given** a text whose tags are not all at the heads of their own paragraphs, **When** the reader presses
   Format, **Then** every tag is the first non-space characters of its own paragraph, the only characters
   added are the blank lines, and one Undo restores the text exactly as it was.
2. **Given** a text in which every tag already heads its own paragraph, or a text with no tag at all,
   **When** the editor is open, **Then** Format is disabled — it is not a no-op that costs an undo step —
   and the text is untouched (SC-011).

### Edge Cases

- **A colon is not a speaker any more.** 他说：我来了, 时间：8 点, 备注：(略), a URL's `https://`, a clock's
  `12:30` — all plain text, narration, nothing proposed. Replacing the colon prefix with the braced tag
  deleted this whole class in one move (2026-10-02).
- **Braces that are not a speaker.** `{laughs} hello`, a stage direction, a name the reader would rather
  hear read aloud. The scan proposes the name it finds; the reader removes it once (US3). Digits inside a
  name are the reader's own choice now rather than something the rule refuses: `{12} hello` is a role
  named 12.
- **The separator is optional.** `{May} : hello`, `{May}: hello` and `{May} hello` are the same turn: the
  tag is `{May}`, and the spaces and single colon that may follow it belong to the prefix, not to the
  content — so a second colon is content (`{May} : he said: go` speaks "he said: go").
- **Spaces and length in a name.** `{May Anne} hello` and a twenty-character name are ordinary turns: the
  closing brace is what ends the name, so neither a space nor a length needs a rule (the first draft's
  8-character, no-whitespace bound is gone).
- **An unclosed tag, an empty name, an empty turn.** `{May : hello` and `{} hello` are narration — no
  closing brace, nothing between the braces; `{May}` with nothing after it is a turn with no content,
  contributing no utterance and no frame — never a silent gap in the video.
- **A brace inside a name** (`{a{b}c} x`): the first `}` ends the name, so the name is `a{b` — mechanical,
  and a name that carries a brace cannot be written at all.
- **Only the ASCII braces are a tag.** `｛May｝` typed with a Chinese IME's full-width braces is narration,
  braces and all (the reader chose the single pair, 2026-10-02; a twin is one table row away if it
  bites).
- **The same role twice in a row** (two consecutive paragraphs headed `{阿明}`, or two turns of it with a
  blank line between them): two turns of one role, same voice, no merging, no name spoken either time.
- **The same name in two spellings** (`{May}` / `{may}`, `{阿明}` / `{阿 明}`): different roles — the name is
  the text's own (trimmed of surrounding spaces), and a role is per content, never shared.
- **A paragraph whose first line has no prefix inside 多人对话**: one narration turn for the whole
  paragraph, in the per-language voice (the same one a 标准 read of that paragraph would use). It is never
  attributed to the previous speaker silently.
- **A tag that is not at a paragraph's head.** `{阿明} 你好。` and `{阿芳} 我很好。` on consecutive lines
  with no blank line between them: one turn, 阿明's, spoken as `你好。{阿芳} 我很好。` — the braces, the name
  and the colon are characters like any other, and 阿芳 is not a role (2026-10-03). The mistake is heard out
  loud; the editor's Format action (US5) is what turns it into two paragraphs.
- **Format on braces that are not speakers.** A text with `{laughs} hello` (a stage direction, a code
  sample) inline: Format takes the braces at face value, so that pair becomes a paragraph head and is then
  proposed as a role — the format's premise is that a brace pair is a speaker. Removing it in the role list
  (US3) or one Undo are the two ways back (2026-10-03).
- **Format when there is nothing to format.** A text with no tag at all, or one whose tags already head
  their own paragraphs: the action would change no character, so it is offered disabled (the way Undo is
  with nothing to undo), and the reader's text and undo history are untouched (SC-011).
- **Ten roles, two voices**: every role is assigned; the list shows which roles share.
- **A role whose lines are in two languages** (one Chinese turn, one English turn): each turn's own
  language decides its default voice; the role's pick, when it has one, is used for both (the engine is
  told the voice's own locale, as it is today).
- **A content with a single role and no other** (`{旁白} …` throughout): a valid dialogue of one speaker —
  the read of it and the read of the same text in 标准 differ only in the tag being spoken.
- **A very large dialogue** (thousands of turns): the read, the highlight and the video behave as they do
  for a long 标准 content — the roles add no per-turn file, no per-turn store write and no per-turn
  synthesis beyond what a read already does.
- **The stored reading position lands inside a tag** (after switching modes): the existing
  nearest-sentence rule answers it; the read never starts on a name.
- **A content that is nothing but tags** (`{阿明}` / `{阿芳}` with no content): there is nothing to read,
  which is 012's existing "nothing to read" case — the video refuses to render rather than producing a
  blank video.
- **Roles in a text the reader is still editing** (008's edit mode with its undo history): the text is
  what is read; the roles follow it. Undo restores the previous text and the previous roles with it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A content MUST carry a text type — 标准 or 多人对话 — remembered per content; a content
  with no stored type is 标准. The type is stored outside the content library's own index (FR-021).
- **FR-002**: 标准 MUST be the reading the app ships today: the whole stored text is spoken, a braced tag
  included, the language is detected per paragraph and the voice is the one picked for that language
  (002). No existing content's reading changes.
- **FR-003**: In 多人对话, a **paragraph** whose first line's start matches the role-prefix rule (FR-004)
  MUST be that role's turn — the paragraph's whole text after the prefix, however many lines and sentences
  it spans — and the turn MUST be spoken as its own content alone. A turn ends at the blank line that ends
  its paragraph; nothing else ends it (2026-10-03).
- **FR-004**: The role-prefix rule MUST be a table-driven scan (the shape `lib/language.dart` already
  uses for languages), and the prefix MUST be a **braced tag**: line start (leading spaces allowed), `{`,
  a name, `}`, then an optional single colon (ASCII or full-width) with spaces around it — the separator
  belongs to the prefix. The name is the characters between the braces, trimmed of surrounding spaces, at
  least one, never spanning a line, ended by the first `}`; it MAY contain spaces and MAY be any length
  (the first draft's 8-character, no-whitespace bound is gone, 2026-10-02). ASCII braces only. The rule is
  applied to the **first line of each paragraph**, which is the only line that can name a turn's role
  (FR-003): a paragraph whose first line is not such a tag is narration, not a turn — including one that
  starts with a bare `名字：`, which the first draft would have read as a speaker. A tag **anywhere else** —
  a later line's head inside a paragraph, or the middle of a line — is **ordinary text**: it names no turn,
  it is not removed from the turn, and it is spoken, highlighted and painted like any other characters
  (2026-10-03). The app never repairs the reader's text; the editor's Format action (FR-024) is how a tag is
  made into a paragraph head.
- **FR-005**: A role prefix MUST NOT be part of any sentence's span: it is never sent to the engine,
  never highlighted, never painted in a video frame, and never part of a stored reading position.
- **FR-006**: The app MUST propose the roles it found in a content — distinct names, in order of first
  appearance, with each one's turn count — and the reader MUST be able to remove a proposed name.
- **FR-007**: A removed name MUST be remembered for that content and MUST NOT be treated as a role there
  again; the paragraphs it heads are narration (FR-009) until the content's text changes (FR-006's
  proposal follows the text).
- **FR-008**: The confirmed set MUST survive restarts, and a content whose roles were never edited MUST
  read with the proposed set — the list is a proposal, never a gate in front of reading.
- **FR-009**: A paragraph whose first line has no prefix in 多人对话 MUST be one narration turn, spoken in
  the voice the per-language pick gives it (002), and MUST NOT be silently attributed to another role —
  including when a later line inside it carries a tag (FR-004, 2026-10-03).
- **FR-010**: A turn MUST be spoken sentence by sentence, one utterance per sentence, exactly as a
  paragraph is read today (010 FR-011); a turn that spans several lines is cut the same way a several-line
  paragraph is, so the line breaks between its sentences are never spoken. The role decides the voice and
  the text, not the unit of speech. The page's tap, highlight and resume behaviour (011) MUST be
  unchanged.
- **FR-011**: A turn's language MUST be detected from the turn's own content, by the rule table the app
  already uses, with the same outcomes (`zh-Hans`, `es`, `en`). A dialect is not detected.
- **FR-012**: The reader MUST be able to give each role its own voice, chosen from the voices the app
  already offers — the same lists as 002, with 广东话 under 中文 as 007 shipped it — and the app MUST NOT
  offer an age property it has no evidence for.
- **FR-013**: A role's own pick MUST decide that role's voice and pronunciation, including when the
  turn's detected language differs from the voice's own (阿明's Chinese line in a 广东话 voice); the
  turn's language decides the voice only when the role has no pick.
- **FR-014**: With no pick, a role MUST be assigned a voice deterministically, preferring the turn's
  language first, then the same dialect where the language offers one, then the same gender as the app
  records it — and the same content MUST be assigned the same voices on a second open.
- **FR-015**: The assignment MUST prefer voices not already given to another role of the same content,
  and where fewer suitable voices exist than roles, reuse MUST be allowed rather than a role left
  unvoiced.
- **FR-016**: The role list MUST show each role's voice by its own name (and the gender the app records
  where it has one), so the automatic choice is visible and changeable.
- **FR-017**: The app MUST NOT model or claim voice age; the reader's own example's 成熟男声/年轻男声 is
  answered by the reader picking the voice (2026-10-01 Clarifications).
- **FR-018**: A video of a 多人对话 content MUST use the same per-role voices as the read and MUST show
  only the current sentence's content — no role prefix in any frame; a video of a 标准 content MUST be
  exactly what 012 produces today.
- **FR-019**: The read and the video MUST resolve roles, languages and voices through one shared
  resolution, so the same turn cannot be voiced one way on the page and another way in the video.
- **FR-020**: Changing the text type MUST NOT modify the content (008's text and its undo history are
  untouched), MUST NOT move the stored reading position, and MUST NOT require re-reading the content.
- **FR-021**: The text type, the confirmed roles and the picks MUST be stored per content and per device
  the way 012 stores a content's video record — one store keyed by the content's own key, leaving 008's
  index schema and its repair path untouched — and MUST be removed when the content is deleted.
- **FR-022**: The text type and the role list MUST be reachable from the reading page (the surface the
  reader already uses for a content's language, appearance, voice and video), and every new string MUST
  exist in the app's four locale files.
- **FR-023**: The feature MUST NOT add a dependency or use the network: the roles are the reader's own
  text and the voices are the device's own (constitution IV).
- **FR-024**: The editor MUST offer one **Format** action that puts the reader's text into the format:
  before every occurrence of a role tag (FR-004's tag grammar) that is not already at the head of its own
  paragraph, it inserts a blank line — and it changes nothing else (no character of the reader's own words
  is altered, no tag is added, none is removed, no separator rewritten). It MUST be one ordinary edit (008's
  save path, one undo step), MUST be disabled when it would change nothing, and MUST NOT be a second way to
  change the text beyond those blank lines (2026-10-03).

### Key Entities *(include if feature involves data)*

- **Text type** — per content: 标准 or 多人对话; absent means 标准.
- **Turn** — one role's paragraph in 多人对话: the role, the paragraph's content span (everything after
  the prefix) and the sentences that span holds. Turns are derived from the text, never stored as text of
  their own.
- **Formatted text** — the reader's own text with blank lines inserted so that every tag heads its own
  paragraph (FR-024). Produced by the editor's Format action, stored as the content's own text (008), never
  as a shape of its own.
- **Role** — a name within one content, with the number of turns it has and (once decided) its voice.
- **Role voice** — a role's own pick (the same voice a language pick is: name + locale) or nothing;
  nothing means the assignment of FR-014 applies.
- **Role settings** — per content: the type, the removed names, the picks. What FR-021 stores.
- **Utterance** — the existing unit of speech (a sentence) with its language and voice; a turn does not
  change it, it only decides which of two voices it gets.
- **Content** (008, unchanged) — the text, its name and its language label; the roles are not part of it.
- **Voice** (002/007, unchanged) — a voice's name, its locale, its recorded gender and its dialect.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 多人对话, a read of a four-role content sends the engine exactly the turns' contents in
  order: 100 % of the utterances, read from the app's own per-utterance line, contain no role name and
  no brace of a tag.
- **SC-002**: A four-role content read with four different picks produces four distinct voices, each
  utterance naming its role's own voice.
- **SC-003**: With no picks, every role is given a voice of its turn's language; where the device lists a
  voice of the same dialect and gender, that voice is chosen; and the same content assigns the same
  voices on a second open (identical assignment, read twice).
- **SC-004**: Where the device lists fewer suitable voices than the content has roles, every role still
  has a voice and the sharing is visible in the list — no role is silent, no read fails.
- **SC-005**: A content with no stored type reads exactly as the shipped app reads it: the same utterance
  sequence, tag text included, and 011's and 012's device rows still pass.
- **SC-006**: A name removed in the confirmation list is not a speaker afterwards and is still not one
  after a restart; the paragraphs it heads are spoken as narration.
- **SC-007**: The text type, the roles and the picks survive a restart, and deleting a content removes
  them.
- **SC-008**: No frame of a 多人对话 content's video contains a role tag (sampled frames read as
  pixels/characters), and every turn's audio in the file is the voice the read used for that turn.
- **SC-009**: Switching between 标准 and 多人对话 leaves the stored reading position and the highlight
  where they were, and 010's resume row still passes.
- **SC-010**: The feature adds no dependency and makes no network call (the structural receipt 012
  already has: the manifest diff and the app's own offline behaviour).
- **SC-011**: After Format is pressed in the editor, every role tag in the text stands at the head of its own
  paragraph, the difference from the text before the press is blank lines and nothing else (character for
  character), and one Undo restores the earlier text exactly.

## Assumptions

- **A1 — the settings are per content, per device, outside the index (clarified 2026-10-01).** 012's
  `VideoRecordStore` (`lib/video_record.dart:78`, one `shared_preferences` key holding JSON keyed by the
  content's own key) is the precedent: the text type, the removed names and the picks live the same way.
  The reason is that 008's index is a versioned schema with a repair path
  (`lib/models/content.dart:16`), and the roles do not need to be in it: nothing but this feature reads
  them, and a content whose settings are unreadable still reads — as 标准.
- **A2 — no voice age (clarified 2026-10-01).** `lib/models/voice_mapping.dart:18-23` states the engine
  exposes no age and that a value would be a guess. The consequence to accept: the reader's example's
  成熟/年轻 is not a property of any role; the reader picks the voice itself, and the app shows the
  voice's own name.
- **A3 — the dialect is a property of the voice, not of the text (clarified 2026-10-01).** Since 007,
  Cantonese is a voice under 中文 (`lib/reader_service.dart:279`), so the text decides the language and
  the role's pick decides the dialect. The consequence to accept: 阿明's Cantonese line is detected as
  `zh-Hans` like any Chinese line, and the reader gives 阿明 a 广东话 voice by hand.
- **A4 — the role is a name in one content.** Roles are not shared between contents, are not declared
  anywhere but the text, and are matched as written (trimmed). A name that appears once is still a role:
  the confirmation list is the guard against a false one, not a frequency threshold.
- **A5 — the unit of speech does not change.** One utterance per sentence (010 FR-011); the roles add a
  voice per turn, not a new unit. This is what keeps 011's highlight, 010's resume point and 012's
  video's one-sentence-per-frame picture working unchanged (FR-010, FR-019).
- **A6 — the prefix is outside every span.** The role's content span starts after the tag, its optional
  colon and its spaces, so "not spoken, not highlighted, not painted" needs no filtering anywhere (FR-005);
  that head prefix is the *only* thing this feature removes from the reader's text. A tag inside a paragraph
  is inside the span like any other characters (FR-004, 2026-10-03). A tap in the head tag resolves to the
  turn's first sentence by the app's existing nearest-segment rule (`lib/segmenter.dart:120`).
- **A7 — detection is a proposal, not a verdict.** The rule table (FR-004) is deliberately mechanical —
  the same shape as the language rules — and the confirmation (FR-006) is where a wrong proposal is
  corrected. The reader never has to accept a role to read a content.
- **A8 — the app never invents a speaker.** A paragraph whose first line has no prefix is narration
  (FR-009). The *paragraph* is the unit of attribution: its lines belong to the speaker its own head names,
  and a tag inside it never moves a line to another speaker (2026-10-03). The app does not guess who is
  speaking, and no line is ever given a speaker that is not named at its own paragraph's head.
- **A9 — the reader's own text is the source of truth.** The feature does not write to the content, does not
  add tags, and does not reflow it: 008's edit surface and its undo history are untouched (FR-020) — with
  exactly one exception, the reader's own **Format** action (FR-024, 2026-10-03), which adds blank lines and
  nothing else, inside the editor that already exists, as one undoable edit saved by 008's own path.
- **A10 — the voices are the device's own.** The lists the picker offers are the ones the app already
  shows (002's per-language pick, 007's 广东话 under 中文), narrowed by nothing but the reader's choice;
  the app records a voice's gender where the engine's evidence allowed it
  (`lib/models/voice_mapping.dart`, 96 rows at the time of writing, 7 Mandarin and 6 Cantonese names
  among them) and claims nothing where it did not (`en-us-x-tpc` has no gender).
- **A11 — no account, no network, no new dependency** (constitution IV, FR-023), and the platform stays
  the app's own: no platform-specific code is expected for this feature (unlike 012).
- **A12 — the reference device** for the device rows is the AVD `emulator-5554` (API 36) and the reader's
  own phone (OnePlus LE2115) where the reader runs it, with the debug build's own evidence lines
  (`klhu speak …` extended with the role and the voice, FR-016's list, and the video's own lines).

## Out of scope

- **Voice age** (成熟/年轻) and any other property the app has no evidence for: it is the reader's own
  answer of 2026-10-01 that no age is modelled (A2).
- **Detecting a dialect from the text** (a 粤语 rule over 唔/系/咁/嘅): declined in the same round (A3).
  A role's dialect is picked, never inferred.
- **Per-role appearance** — a role's own typeface, character size or colour, in the page or in the
  video. The video still paints the reader's own reading appearance (012 FR-014).
- **Per-role audio files, per-role export, or a separate track per speaker** — the video stays one file
  with one mixed audio track (012 owns the file).
- **Screenplay features beyond a braced tag**: parenthetical stage directions, emotion or speed tags,
  nested speakers, a speaker list declared before the text, `>>` continuations. The tag is a speaker's
  name and nothing else — an emotion marker written as a tag is proposed as a role like any other, and
  the reader removes it once (US3).
- **Roles shared between contents, or synced between devices** (no account, constitution IV): a role
  belongs to the content whose text named it.
- **Guessing a speaker for an unprefixed line or paragraph** — and any automatic rewriting of the reader's
  text (A8, A9). The one edit this feature can make is the reader's own Format press (FR-024), which adds
  blank lines and nothing else: rewriting a bare `名字：` into `{名字} `, or any other normalisation of the
  reader's characters, is out of scope (2026-10-03).
- **Wish-list items 15 and 16** (OCR, translation) — separate features of their own.
