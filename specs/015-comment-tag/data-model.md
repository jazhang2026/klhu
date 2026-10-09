# Data Model: Comment Tag

**Feature**: `015-comment-tag` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

The same two kinds of thing 014's model has, and the split is again the point:

- **Derived** — what the text says (its comment tags, the comments themselves, their content spans, the
  sentence each belongs to, and what the page paints). Never stored, recomputed on every read, so nothing can
  go stale (research D1–D4, D7).
- **Stored** — what the reader decided (whether this content's comments are read). One boolean, per content,
  in the store 014 already owns (research D5).

Nothing here changes 008's content, its index or its files; nothing changes 010's/011's reading position or
012's kept video; nothing 014 derives (the turns, the roles, their voices) changes except that a turn's own
content stops at a comment's tag (research D2). The existing types this feature *consumes*
(`ParagraphSpeech`, `VideoSentence`, `VideoSlot`, `RoleSettings`, `ReadingPosition`) are read as they are,
with the additive fields named in §6.

---

## 1. Comment tag — **derived** (per text, every read)

One marker occurrence in the reader's text: the thing the rule recognises.

| Field | Type | Rules |
|---|---|---|
| `start` | `int` | Offset of the tag's opening `[`. |
| `name` | `String` | One of the four spellings — `comment`, `注`, `註`, `nota` (2026-10-08) — the characters between the delimiters, trimmed; the ASCII ones matched case-insensitively. |
| `tagEnd` | `int` | Offset just past the tag and the separator that belongs to it — the spaces and the one optional `:`/`：` that follow it **on its own line** (research D3). Everything in `[start, tagEnd)` is the tag's own characters: never spoken, never painted. |
| `contentStart` | `int` | Where the comment's **content** begins. After `tagEnd`, except when the tag is alone on its line: then the line break and the following indentation belong to the prefix, and the content begins at the next line's first non-space character (014's own rule for a tag-only first line, `lib/dialogue.dart:138-145`). |
| `contentEnd` | `int` | Offset just past the paragraph's last non-whitespace character — the comment's content runs to the end of its own paragraph (FR-002). |

**Where**: `lib/comment.dart` — `CommentTag? commentTagAt(String text, int paragraphStart, int paragraphEnd)`
reads the **first** well-formed occurrence anywhere in the paragraph, by the comment tag's own implementation
(research D2): the rule is written here and 014's `roleTagAt` is not touched — its pair is read at a
paragraph's head only, in its own module, and the two rules never call each other (A6).

**Rules** (each is a spec line):

- The pair is ASCII `[` `]` only (FR-001). `［注］` — a Chinese IME's own brackets — is **not** a tag: it is
  ordinary text, displayed and read as written, and nothing is repaired (the spec's edge case, 014's A9).
- The name is one of the four rows — `comment` or `nota` in any ASCII case, `注`, `註` exactly — and **all four
  are live in every content, whatever language the app is showing** (FR-001, the reader's amendment of 2026-10-08
  and research D11: the reader types with their own keyboard, and a text must not change meaning with the UI
  language). A near miss in any language is ordinary text: `[comments]`, `[comentario]`, `[註解]`, `[註釋]`,
  `[注释]`, `[note]` (FR-001: *"No other text is a comment"*).
- The separator is a run of spaces, at most one `:`/`：` inside it, and a run of spaces — it belongs to the
  tag (FR-001). A **second** colon is the content's (`[注]: note: read this` reads `note: read this`).
- A tag with nothing after it, or a paragraph that holds only a tag, is a comment with an empty content: no
  utterance, no frame, nothing to switch off (the spec's edge case).
- **At most one comment per paragraph**: the first occurrence opens it, and every later tag in that paragraph
  is the comment's own characters — displayed and read with it (the spec's edge case; nothing nests).
- A tag whose characters lie inside another comment's content is **not** a tag (it is that comment's text).
- A paragraph whose tag is mid-line (`Hola. [注] Hi. Adiós.`) makes one comment that runs to the paragraph's
  end; the sentences after the tag are not read by the sentence's voice (the spec's own edge case).
- The rule is mechanical and never guards against the reader's mistakes: a tag in the wrong place is heard
  rather than seen (the page paints no marker), and the remedy is the reader's own edit.

---

## 2. Comment — **derived** (per text, every read)

One comment: its tag, the text it carries, and the sentence it belongs to.

| Field | Type | Rules |
|---|---|---|
| `tag` | `CommentTag` | §1 — the offsets above. |
| `text` | `String` | `content.substring(contentStart, contentEnd)` — the comment's own characters, its line breaks inside them. |
| `language` | `String` | `detectLanguage(text)` (`lib/language.dart:96`) — the comment's **own** content decides it, never the paragraph it sits in (A3, FR-008). |
| `ownerStart` / `ownerEnd` | `int?` | The span of the sentence this comment belongs to, or `null`/`null` when there is none. Both are the app's own sentence **range** in the text (`lib/segmenter.dart:65-67` — a run with no delimiter is one range, its trailing space included), so a tap answered with it is the same span the page's own sentence resolution would answer. |

**Where**: `lib/comment.dart` — `List<Comment> commentsOf(String text)`, one pass over the app's own paragraph
ranges (`paragraphRanges`, `lib/segmenter.dart:71-108`) with §1's scan inside each paragraph.

**Validation / rules**:

- **The owner is the last sentence ending before the tag** (FR-003), computed in the app's own units: the
  sentence ranges of the speakable text that precedes the tag — i.e. the text up to the tag, with every
  comment's own characters cut out (FR-004) — so the owner is the last sentence of the piece of text before
  the comment, **across paragraph boundaries**. When the tag sits at the very head of the content there is no
  such piece, both are `null`, and the comment is displayed, never spoken and in no frame (FR-003). The
  video pairs a comment with its owner by the same rule, over its own sentence list (research D8).
  *(Corrected 2026-10-08 by the implementation, T004: the owner is the range of the text **as the reader wrote
  it** — a 014 role prefix inside it included, since in 标准 those characters are ordinary text and that is the
  span the page's own sentence resolution answers for an offset there (SC-009) — while the **read** keeps using
  the turn's own prefix-less span, which is `turnsOf`'s business and unchanged. Naming the fields as a span
  rather than a single end offset is what the page's tap rule needed.)*
- A comment's content is **part of no sentence's span** (FR-004): it is never highlighted as part of a
  sentence, never part of the reading position and never handed to the engine except as its own speech (§6).
  In this app's terms the sentence structure of the text is unchanged everywhere except that a sentence's
  text stops at a comment's tag.
- A comment is **never a shape of its own in the content**: it is recomputed from the text on every read, and
  an edit that removes the tag removes the comment with it (FR-015, the spec's edge case about editing).
- Comments are not shared between contents or devices and are never written anywhere (out of scope): a comment
  belongs to the text that wrote it.

---

## 3. The display — **derived** (per text, what the reading page paints)

The reader's text with the tags' own characters elided, and the mapping between the two index spaces
(research D7, A4, FR-012).

| Part | Rule |
|---|---|
| `display` | `text` with every `[tagStart, tagEnd)` removed and **nothing else changed** — the comment's content, its line breaks, the comment's owner's text and every role tag (014's `{…}`, which the page does show) all stay exactly where they are. |
| `toContent(displayOffset)` | The content offset the reader's finger is on. Across an elision the answer is the first content character **after** the elided span — those characters are not painted, so the character at the display position they occupied is the one that follows them, and for a comment's tag that character is inside the comment's own span (so a tap at the seam still answers the comment; corrected 2026-10-08 by the implementation, T007). |
| `toDisplay(contentOffset)` | Where a content offset is painted. An offset inside an elided span answers the span's display start, so a highlight whose end lands inside a tag paints no marker and covers the comment's content. |

**Where**: `lib/comment.dart`, derived from `_content` alone and recomputed when it changes; the reading page
uses it in `_buildSpans`, `_resolveAt` and `_measure` (research D7 lists the three seams).

**Invariants** (each is assertable):

- **I1** — for a text with no tag, `display == text` and both mappings are the identity; the page is
  byte-for-byte what ships (SC-004's own sentence, as a property of the function).
- **I2** — the display contains no character of `[`…`]` of any tag, and no character of its separator.
- **I3** — `toContent(toDisplay(o)) == o` for every content offset `o` that is not inside an elided span, and
  `toDisplay(toContent(d)) == d` for every display offset `d`.
- **I4** — the display's length is the content's minus the sum of the elided spans' lengths; the two mappings
  are monotonic and never move an offset backwards past itself.

---

## 4. The comment setting — **stored** (per content, one boolean)

Whether this content's comments are read aloud (FR-006).

| Field | Type | Rules |
|---|---|---|
| `comments` | `bool` | `false` = the comments are **not** read. Absent, or any value that is not the boolean `false`, = **read** — the shipped default (the reader's answer of 2026-10-08, which reverses the item's own example). |

**Where**: inside the content's entry in 014's one `shared_preferences` key `content_roles`
(`lib/role_store.dart:117`), beside `type`, `removed` and `voices`. The page writes it through
`RoleStore.setComments(contentKey, {required bool read})`; `RoleSettings.commentsRead` carries it in memory.

**Validation**: a malformed entry is ignored, never repaired, and the other contents' entries are unaffected —
the tolerant read 014's store already implements (`lib/role_store.dart:207-227`), which this field simply
joins. A content with nothing stored reads its comments.

**Lifecycle**: set by the reading page's sheet (research D6); remembered per content and per device; **removed
with the content** (`RoleStore.clearFor` at `lib/role_store.dart:180`, already called from
`lib/content_list_screen.dart:115`) — the feature adds no second path here; written **only** when the reader
changes it, so a content that never touched the switch stores nothing and 014's own entries keep the shape
their rows assert.

**What changing it may not touch** (FR-016): the content's text, 008's `updatedAt`, the stored reading
position, the roles and their voices, the highlight in force and 014's `type`/`removed`/`voices` fields — all
of which live in other fields of the same entry and are carried through untouched.

---

## 5. State transitions

```
   reader turns the switch off            reader turns it back on
   read ───────────────────────▶ not read ───────────────────────▶ read
     │  (the entry gains "comments": false)     (the field is removed;
     │                                           an entry that says nothing is dropped)
     │
     └─ the content is deleted ─▶ the whole entry is removed (014's own clearFor path)
```

Nothing else transitions. A read never writes (§4), a comment is never stored (§2), and the display is
recomputed from the text (§3) — so an edit that changes the tags changes every derived thing at once, and
one Undo takes it back (the spec's edge case about a text still being edited).

---

## 6. What this feature feeds the existing types (four additive fields, no new interface)

| Existing type | Where | What 015 adds |
|---|---|---|
| `ParagraphSpeech {text, language, voice, start, end, role}` | `lib/reader_service.dart:66-89` | one optional `isComment` (`bool`, default `false`): the speech is a comment's own, placed in the list immediately after the speech its sentence belongs to (research D1). Null-able-by-default like `role` was in 014, so every existing construction and every test fake is untouched. |
| `_Utterance` (private) | `lib/reader_service.dart:213-243` | the same flag, passed through from the speech so the read's evidence line can name the comment (research D9). The reader service needs nothing else: it cuts each entry into sentences and speaks them in order (`:394-415`). |
| `VideoSentence` | `lib/video_timeline.dart:28-57` | one optional `isComment` — set on a sentence that came from a comment's speech — and the slot it rides is the one its owner sentence built (research D8). |
| `VideoSlot` | `lib/video_timeline.dart:131-178` | the slot's `text` now carries the block (its sentence **and** the comments riding it, D8); its `audio` names the WAVs it plays, in order (its own sentence first, then each comment's sentences), so the renderer can hand the muxer one segment per utterance inside the slot's frames. `span=` is unchanged — still the **sentence's** own offsets, which is what 012's row 32 reads. |
| `RoleSettings` | `lib/role_store.dart:48-109` | one field (`commentsRead`, default `true`) plus its two callers kept in step (`withRemoval`, `withVoice`) and `isEmpty`; the page's own `RoleSettings(...)` construction follows (`lib/reading_view.dart:1360-1368`). |
| `VideoPlan` / `buildVideoPlan` | `lib/video_timeline.dart:183-297` | the plan's own arithmetic is unchanged for a content with no comment; a slot whose audio has several parts sums its own `durationMs` from them, and `audio` (above) is what the renderer walks for the muxer's segments. |
| `ReadingPosition`, `SavedContent`, `TextSegment`, `VoiceChoice`, `VoiceEntry` | `lib/read_position_store.dart`, `lib/models/content.dart`, `lib/segmenter.dart`, `lib/voice_store.dart` | **nothing** — every offset this feature produces is a content offset, and every stored position stays one. |

---

## 7. Invariants (each phrased so a test can assert it)

- **INV-1** — A content with no tag (none of the four spellings) resolves, reads, paints, stores and renders
  exactly as the shipped app does: the same speeches field for field, the same display string, the same slots
  (SC-004).
- **INV-2** — With nothing stored, a content's comments are read: each comment's content reaches the engine as
  its own utterances, immediately after its owner sentence's, and no utterance anywhere contains a `[` or a
  `]` of a tag (SC-001).
- **INV-3** — With the setting off, no comment's characters reach the engine at all, and the utterance
  sequence is the sentences' own, in order (SC-002).
- **INV-4** — A comment's utterances carry the language the comment's own content detects, and the utterance
  sequence alternates voices exactly where the texts' languages alternate (SC-003).
- **INV-5** — In 多人对话 a turn's utterances contain none of its comment's characters, and a paragraph that
  holds only a comment produces no utterance, no role and no turn count (FR-011, SC-005).
- **INV-6** — The page's display contains no character of any tag and every comment's content; a tap inside a
  comment answers the comment's own span while the comments are read and the owner sentence while they are
  not; the highlight covers a comment exactly while it is read (FR-012, SC-006, SC-009).
- **INV-7** — Every slot of a comment-bearing content paints its sentence **and** each comment riding it, and
  no slot's text contains a tag; a comment's audio is in the slot exactly when the setting reads it, and
  `sentences=N` agrees with the read's own utterance count either way (FR-013, SC-007, SC-008).
- **INV-8** — The setting survives a restart, is per content, and is gone when the content is deleted
  (SC-010); the feature adds no dependency and makes no network call (FR-018, SC-011).
