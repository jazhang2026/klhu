# Data Model: Head tags (`#` a title, `##` a subtitle)

Nothing is stored. The spec's Key Entities says *"None"* (`spec.md:286-287`) and means it about **stored**
state: no new field in any record, no new `shared_preferences` key, no migration, no locale string. What this
file models is the four **derived, in-memory** shapes the feature is made of — a mark, the display that elides
it, a speech whose text is that display's, and a slot that carries a mark's spans into a frame — plus the one
computed relationship (a mark's size). Every one of them is recomputed from the reader's text on every read and
discarded with it, exactly as 014's turns and 015's comments already are.

### HeadTag (new — `lib/head_tag.dart`)

**Purpose**: one mark in the reader's text: which of the two marks it is, the characters that belong to it, and
the line it rules (FR-001, FR-005, FR-008).

**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `level` | `int` | no | derived — `1` for `#` (a title), `2` for `##` (a subtitle); no other value exists (FR-001, FR-006) |
| `start` | `int` | no | derived — the offset of the line's first `#` |
| `markEnd` | `int` | no | derived — just past **the marker and its one space**: the span `[start, markEnd)` is what the display elides (FR-003) |
| `lineStart` | `int` | no | derived — the offset of the first character the mark paints (`markEnd`), i.e. where the title's or subtitle's own text begins |
| `lineEnd` | `int` | no | derived — just past the line's last character: the `\n` that ends the line, or the paragraph's own last character (FR-008: the mark's scope is the line, never the paragraph) |

**Relationships**: derived from the content alone by `headTagsOf(content)`; consumed by 015's display (to know
what to elide and to hand the paints their spans) and, through the display, by the page and the frame. A mark
is **never** derived from, or stored on, the content itself (FR-010).

**Validation rules** (each one a shape SC-003 names, `spec.md:299-300`):

- `headTagsOf` returns a mark only when, at a line's first character: the `#`-run is exactly one or two
  characters (FR-002), the character after the run is exactly one ASCII space, the character after that space
  exists and is not a space or tab (FR-002), and the line's last non-space character is not `#` (FR-002's
  trailing-`#`-sequence refusal, research's grounding correction 2).
- `#hashtag`, `#1 best`, `### note`, `#### `, a lone `#`, a lone `##`, `# ` followed by whitespace alone,
  `  # Title` (a marker preceded by whitespace) and `# Title #` (a trailing `#` sequence) each yield **no**
  mark: painted and read as written (FR-002, FR-014).
- A line that lies inside a comment's span (`[tag.start, contentEnd)`, 015's own `Comment`) yields no mark: a
  comment's words are the comment's (FR-009).
- `lineStart <= lineEnd` always, and `markEnd == lineStart` unless the line is only the marker and whitespace —
  which is not a mark at all (above). `[start, markEnd)` never overlaps a comment's `[tag.start, tagEnd)`: a
  comment's tag begins with `[`, a mark's span is `#`s and one space (FR-009's disjointness, which is what lets
  the display merge the two kinds in one pass).

**Worked example**: the content `'# Basic Spanish 1\nHola.'` yields
`level: 1, start: 0, markEnd: 2, lineStart: 2, lineEnd: 17`; the content `'## Greetings'` yields
`level: 2, start: 0, markEnd: 3, lineStart: 3, lineEnd: 12` (so its painted span is the nine characters
`Greetings`); the content `'#1 best'` and the content
`'# Title #'` each yield **nothing**.

### The display (015's `CommentDisplay`, extended — `lib/comment.dart`)

**Purpose**: what the page **and the frame** paint, and the mapping between the two index spaces (015
FR-005/FR-012, extended by 019 FR-003).

**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `text` | `String` | no | derived — the content minus every comment tag's `[tag.start, tagEnd)` **and** every mark's `[start, markEnd)` (FR-003) |
| `comments` | `List<Comment>` | no | derived — 015's own, unchanged (one per paragraph at most) |
| `heads` | `List<HeadTag>` | no | **new** — derived, in text order; empty for a content with no mark |
| `toContent(displayOffset)` | `int` | no | derived — the content offset a painted offset belongs to, over the merged elided spans |
| `toDisplay(contentOffset)` | `int` | no | derived — where a content offset is painted, over the same spans |
| `commentSpans()` | `List<(int, int)>` | no | derived — 017's: where a comment's **own characters** are painted |
| `headSpans()` | `List<(int, int, int)>` | no | **new** — where a mark's **line** is painted, as `(start, end, level)` in display offsets, each span **cut where a comment's own characters begin** (a comment keeps 017's size inside a marked line, FR-012) |

**Relationships**: built by `displayOf(content)`; the page's span tree (`lib/reading_view.dart:2440-2390`) and
a slot's block (`lib/video_painter.dart:578-640`) both read it; every offset-bearing value in the app — a tap's
answer, a highlight's boundaries, a step's range, a speech's span, a slot's `start`/`end` — stays in **content**
offsets and is translated only at those two paint seams.

**Validation rules**: the marker's characters are painted **nowhere** (FR-003) and a mark's line is painted at
its derived size and weight and no other line is affected (FR-005, FR-008); a text with no mark or tag has
`text == content` and an identity mapping (FR-010's own shape, which is what makes SC-003 true by construction);
`toContent(toDisplay(o)) == o` for every content offset `o` that is not inside an elided span, and
`toDisplay(toContent(d)) == d` for every display offset `d` (INV-2).

**Worked example**: `'# Basic Spanish 1\n\nHola.'` → `text: 'Basic Spanish 1\n\nHola.'`,
`heads: [(0, 15, 1)]`, `toDisplay(2) == 0`, `toContent(0) == 2`; `'# Basic Spanish 1\n\n[注] Basic Spanish 1'` yields
`heads: [(0, 15, 1)]` and the same elided tag span as today (a `[`-run is never a marker, FR-009); a content
with no mark at all yields `heads: []` and `text == content`.

### ParagraphSpeech (extended — `lib/reader_service.dart:66-98`)

**Purpose**: one speech of a read: a paragraph's, a turn's, or a comment's own (010/014/015's shipped shape).

**Attributes**: `text`, `language`, `voice`, `start`, `end`, `role`, `isComment` — **all unchanged** — plus:

| name | type | nullable | source |
|---|---|---|---|
| `display` | `CommentDisplay?` | **yes — new** | set by the resolution: the content's own display when `text` is a slice of it; **null** when the content holds nothing elided, and for every speech a test builds by hand |

**Relationships**: the resolver (`lib/speech_resolver.dart:52-87`) sets it on the standard, dialogue and comment
paths; the two producers that cut a speech into sentences — `ReaderService._sentencesOf`
(`lib/reader_service.dart:408-435`) and `VideoTimeline.videoSentencesOf` (`lib/video_timeline.dart:76-100`) —
ask the speech for each local sentence range's words and offsets through it.

**Validation rules**: `text` is the **display's own characters** for the span `[start, end)` (FR-004: no `#`
that is a mark reaches the engine, and no tag's characters either — 015's rule, now by construction); with
`display == null`, `text == content.substring(start, end)` exactly as today (SC-003); the speech's `start`/`end`
are **content** offsets in both cases (FR-011: 016's units are unmoved).

**Worked example**: for `'# Basic Spanish 1\n\nHola.'` the first speech is
`(text: 'Basic Spanish 1', start: 0, end: 17, display: <the content's display>)` — where today the same span's
speech is `text: '# Basic Spanish 1'`.

### VideoSlot (extended — `lib/video_timeline.dart:144-207`)

**Purpose**: one painted block of a rendered video: the sentence being spoken, then each comment that rides it
(015's shipped shape).

**Attributes**: `kind`, `paragraph`, `sentence`, `start`, `end`, `text`, `language`, `voice`,
`durationMs`, `frames`, `startFrame`, `audio`, `role`, `commentStart` — **all unchanged** — plus:

| name | type | nullable | source |
|---|---|---|---|
| `headings` | `List<(int start, int end, int level)>` | no (empty = none) | **new** — built: where the marks' lines sit **inside this slot's own `text`**, in that text's index space, each span cut where the comment's own characters begin (D5, the same precedence as the page's `headSpans()`) |

**Relationships**: filled by `buildVideoPlan`, which is handed the content's **display** in place of the bare
comments list it takes today (`lib/video_timeline.dart:278-283`, call site `lib/video_renderer.dart:268-275`);
consumed by `_blockFor`, which splits the block at these spans as well as at 017's `commentStart`
(`lib/video_painter.dart:591-608`); the end hold repeats the last slot's, as it does for `text` and
`commentStart` (`lib/video_timeline.dart:361-378`).

**Validation rules**: a slot's `text` carries no marker's characters (FR-013: no `#` is painted in a frame —
the slot's text is the display's, D1/D3); every span satisfies `0 <= start < end <= text.length`; every span
lies on a line of its own text; a slot of a content with no mark has `headings` empty and a block painted
exactly as today (FR-013's second half).

**Worked example**: the sentence `'# Basic Spanish 1'` (its own paragraph) → `text: 'Basic Spanish 1'`,
`headings: [(0, 15, 1)]`, and the frame's `klhu render … text=15` line counts the title's own characters; the
paragraph `'# Title\nHola.'` (one sentence, no delimiter) → `text: 'Title\nHola.'`,
`headings: [(0, 5, 1)]`, so only the first line is painted as a title.

### The ladder (a derived relationship, not an entity)

**Purpose**: the ordered rungs a mark's and a comment's look is derived from, and the rungs themselves.
**Attributes**: **none stored.** The rungs, from 011's own offered sizes (`lib/appearance_store.dart:79-91`) and
017's own faces (`:31-39`):

```text
rung | size   | weight | how the app reaches it
0    | 12 pt  | w400   | offered: small, in the reader's own face
1    | 14 pt  | w400   | offered: medium
2    | 18 pt  | w400   | offered: large
3    | 24 pt  | w400   | offered: xlarge
4    | 24 pt  | w700   | derived: the largest offered size, bold (017's weight)
5    | 24 pt  | w900   | derived: the largest offered size, black (no control offers it)
```

**The reader's own rung** is the last rung not above the reader's own choice — their `ReadingSize` at their
`ReadingTypeface`'s weight (so a bold face at `medium` sits on rung 1, exactly where a regular `medium` does).

| the reader's own rung | `##` subtitle (rung + 1) | `#` title (rung + 2) | distinct? |
|---|---|---|---|
| 0 `small` 12 | 14 w400 | 18 w400 | yes — sizes |
| 1 `medium` 14 | 18 w400 | 24 w400 | yes — sizes |
| 2 `large` 18 | 24 w400 | 24 **w700** | yes — size, then weight |
| 3 `xlarge` 24 | 24 **w700** | 24 **w900** | yes — both weights |
| 4 a bold face at `xlarge` | 24 w900 | 24 w900 (clamped) | **no** — the exhausted top, named (FR-006's clamp, SC-006) |

| the body | the comment, one step **down** (FR-015) | 017's shipped behaviour |
|---|---|---|
| 12 w400 (`small`) | **10** — 017's derived floor | unchanged |
| 14 w400 (`medium`) | 12 w400 | unchanged |
| 18 w400 (`large`) | 14 w400 | unchanged |
| 24 w400 (`xlarge`) | 18 w400 | unchanged |
| any size, at **w700 or w900** | the **same size at w400** | **changed** — FR-015's new case |

**Relationships**: called by the page's `_spanPaint` and by the frame's block, which carries the rung onto the
frame's own scale the way 017's comment size already does (`lib/video_painter.dart:641-646`); it reads
`ReadingSize`/`ReadingTypeface` and stores nothing.
**Validation rules**: the ladder decides a mark's size **and** weight (FR-006, FR-007); the reader's own face is
the family every rung paints in, and no rung is a family the reader did not choose; a mark is never taken from a
rung below the reader's own; the only pair that can be equal is the exhausted top, which SC-006 names; and a
comment's step down takes the weight first (FR-015), which is what makes a bold body's comment *quieter* rather
than smaller.
**Worked example**: a content read at `medium` with a regular face paints `## Greetings` at 18 pt w400 and
`# Basic Spanish 1` at 24 pt w400; the same content at `large` paints the subtitle at 24 pt w400 and the title at
24 pt **w700**; with 017's `bold` in force at `xlarge`, a title and a subtitle both paint at 24 pt **w900** and
their comments at 24 pt w400.

### State and invariants

**No new mutable state, and nothing to migrate.** The reader's text, 008's index, 011's appearance record,
014's roles, 015's comments switch and 016's step are all untouched: a mark is a rule applied to text that is
already there. `HeadTag`, the display, the speech field and the slot field are set once, at derive/build time,
and never mutated.

Each invariant below is phrased so a test can assert it directly:

- **INV-1 — the marker is painted nowhere and spoken nowhere.** For every text, no painted span's text and no
  speech's `text` contains a `#` that `headTagsOf` recognises as a mark's, and a mark's own `[start, markEnd)`
  appears in neither (FR-003, FR-004).
- **INV-2 — the mapping is exact and free for a text with no mark.** `toContent(toDisplay(o)) == o` for every
  content offset outside an elided span, `toDisplay(toContent(d)) == d` for every display offset, and for a
  text with no tag and no mark `text == content` with both mappings the identity (FR-003, FR-010).
- **INV-3 — the marks' derivations are ordered and disjoint.** `headTagsOf` returns its marks in text order,
  `[start, markEnd)` of one never overlaps the next, and no mark's span overlaps any comment's
  `[tag.start, tagEnd)` (FR-009).
- **INV-4 — a mark's scope is its line.** `lineEnd` is at or before the paragraph's own end, and a text whose
  marked line is followed by more lines paints every other line as it does today (FR-005, FR-008).
- **INV-5 — the rung decides size and weight, and never below the reader's own.** For every rung the ladder
  derives, the painted size and weight are the rung's own two values, and every mark's rung is above the reader's
  own — the two clamped values being the ladder's last rung and nothing lower (FR-006, FR-007).
- **INV-10 — the three levels are strictly ordered.** For every offered size and every one of the six faces, the
  body, the subtitle and the title stand in the ladder's order with no equal pair; the one exception is a body on
  the ladder's last rung (a bold face at `xlarge`), where both marks are the last rung — named by SC-006 and
  pictured by a row. (FR-006, SC-006.)
- **INV-11 — a comment is never larger, and never the same size *and* weight.** From a regular body the comment
  is one offered size down at the same weight; from a bold or black body it is the same size at the regular
  weight; at the smallest size it is 017's derived 10. Every case 017's own device rows hold is unchanged.
  (FR-015, SC-007.)
- **INV-6 — a comment keeps its own treatment inside a marked line.** For a marked line that also carries a
  comment, the comment's painted span is the one FR-015 derives (its own step down the ladder — the weight first),
  the marked line's other characters carry the rung's size and weight, and 015's comment behaviour is otherwise
  unchanged (FR-012).
- **INV-7 — the read's units are 016's.** For a marked text and the same text with its markers written as
  spaces, `stepRanges` returns the same ranges in the same order, and the utterances' `start`/`end` are the
  same content offsets (FR-011).
- **INV-8 — a text with nothing elided is byte-identical to today.** For any content with no tag and no mark:
  the display is the content, every speech's `display` is null, `text` is the content's own slice, and the
  page's painted spans and the frame's block are what they were before this feature (FR-010, SC-003).
- **INV-9 — a malformed mark is the reader's characters.** Every refused shape is painted, read and rendered as
  written: no repair, no silent removal, no shift of any offset (FR-002, FR-014).
