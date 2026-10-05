# Data Model: Multi-Role Dialogue Reading

**Feature**: `014-dialogue-reading` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Two kinds of thing live in this feature, and keeping them apart is the model's whole point:

- **Derived** — what the text says (the turns, the roles, the proposal, the voices a role gets when the
  reader has not chosen). Never stored. Recomputed from the text and the device on every read, so nothing
  can go stale (research D2/D4/D5).
- **Stored** — what the reader decided (the text type, the names that are *not* roles, the voice each role
  was given). Stored per content, outside the content, in one `shared_preferences` key (research D6).

Nothing in this feature changes 008's content, its index, its schema version or its files; nothing
changes 010's/011's reading position or 012's kept video. The existing types this feature *consumes*
(`ParagraphSpeech`, `VoiceEntry`, `VoiceChoice`, `SavedContent`) are read as they are — with one exception
noted in entity 3.b: `VoicePickerScreen` gains two optional constructor parameters. The one existing value
this feature *writes* is the content's own text, and only when the reader presses Format (entity 2.a).

---

## 1. TextType — **stored** (per content)

The reading mode of one content.

| Field | Type | Rules |
|---|---|---|
| `type` | enum `standard` \| `dialogue` | Absent means `standard`. |

**Where**: `{type: "dialogue"}` inside the content's entry in the `content_roles` key. `standard` is
stored as the *absence* of the field, so a content that was never switched costs nothing and an app
upgrade has nothing to migrate (research D6).

**Validation**: any value other than `"dialogue"` (including a missing field, a non-string, or a
corrupt entry) reads as `standard`. A content whose settings cannot be read is read exactly as today —
the failure mode of this feature is "the reader's dialogue settings are gone", never "the text will not
read".

**Lifecycle**: set by the reader's text-type chooser (research D8); removed with the content's entry when
the content is deleted (`lib/content_list_screen.dart:108`); irrelevant to — and never written into — the
content's text, its undo stack, or 008's index (spec FR-020).

**Why it is not a field on `SavedContent`**: 008's index is a versioned schema with a repair path for
content problems; a reading preference living there would make a bad preference a bad library (research
D6, spec A1).

---

## 2. Turn — **derived** (per read)

One paragraph of a content read in 多人对话 — the app's own paragraph (`paragraphRanges`,
`lib/segmenter.dart:71-108`), however many lines and sentences it holds — and the smallest unit that
belongs to one speaker *(the boundary settled 2026-10-03: a turn is a paragraph, not a line)*.

| Field | Type | Rules |
|---|---|---|
| `role` | `String?` | The role's name as written at the paragraph's head, or `null` for narration. |
| `contentStart` | `int` | Offset of the first character after the tag, the optional colon and the spaces that follow (on the paragraph's first line). |
| `contentEnd` | `int` | Offset just past the paragraph's last non-whitespace character. |
| `text` | `String` | `content.substring(contentStart, contentEnd)` — the paragraph's own line breaks are inside it. |

**Where**: `lib/dialogue.dart` — `List<Turn> turnsOf(String text)`, one pass over the app's own paragraph
ranges (`paragraphRanges`, `lib/segmenter.dart:71-108`) — the same ranges `resolveParagraphSpeeches`
iterates today (`lib/language.dart:117`) — with offsets preserved. No other module constructs a `Turn`, and
no second notion of a paragraph is introduced.

**Validation / rules** (each one is a spec line, quoted):

- A **paragraph whose first line's head** matches the prefix rule (entity 3) opens a **role turn** (FR-003):
  the turn is the paragraph, however many lines and sentences it holds.
- A paragraph whose first line has no prefix is one **narration turn**, `role == null` (FR-009) — it is
  never attributed to the paragraph above it (A8).
- A **blank line** is the only boundary: it produces no speech and no video frame, and nothing else opens
  or closes a turn (the paragraph's own end and the end of the content are the other two, and neither is a
  boundary rule of its own).
- A **tag anywhere else** — a later line's head inside a paragraph, or the middle of a line — is **ordinary
  text**: it names no role, it is not removed from `text`, and it is spoken, highlighted and painted like any
  other characters (FR-004, 2026-10-03). The consequence the reader chose: a text whose turns are not
  separated by blank lines is one turn in the first speaker's voice and its braces are heard — which is why
  entity 2.a exists.
- `contentStart` excludes the tag, its separator and the spaces that follow it; `contentEnd` excludes
  trailing whitespace. That head prefix is the only thing excluded: it is outside every span — never spoken,
  never highlighted, never painted (FR-005, FR-018, SC-008) — while a tag inside the paragraph is inside the
  span, because it is content.
- A turn whose content is empty (a paragraph that is only `{阿明}`, or whose every line is a tag) produces
  **no speech** (spec edge cases); an empty turn is dropped from the turn list before counting, so a role's
  count is its number of *readable* turns.
- **One paragraph is one turn**, so a turn's own lines are its speaker's sentences — the continuation the
  reader asked for (2026-10-03) — and a blank line is what starts the next turn.
- Turn order is the text's order; the turn list tiles the content with the prefixes and blank lines as
  gaps (the shape 012's `span=` field already reads).

**Ranges consumed**: the resolver is called with `[start, end)` (the page's selection, or the whole
content for the video), so `turnsOf` is called with the same range and returns only turns that overlap it;
a turn partially outside the range is clipped to it, exactly as `paragraphRanges` is today
(`lib/segmenter.dart:71-108`).

### 2.a. The Format action — **derived → written to the reader's text** (the feature's one write)

`formatForDialogue(String text) → String`, in the same module: the reader's own text with the blank line
every tag needs put immediately before it — `\n\n` before a tag with content earlier on its line, a single
`\n` before one that already begins a line, so the tag ends up under exactly one blank line and the edit is
the smallest one that makes it a paragraph head *(the two-form detail settled 2026-10-03 by the
implementation; the reader's own rule was "insert blank lines, change nothing else")*. Every tag occurrence
is found by the tag grammar above, searched anywhere in the text; a tag already at a paragraph's head is left
alone, and a text with nothing to format comes back byte-identical (FR-024, research D12).

| Rule | Detail |
|---|---|
| what it adds | blank lines, and nothing else: no character of the reader's words is altered, no tag added, none removed, no separator rewritten (the reader's own answer, 2026-10-03) |
| where it is applied | the editor's controller (`lib/reading_view.dart`), as one value assignment → one undo entry; disabled when the result equals the input (the Undo button's own disabled pattern, `:2069`) |
| where it is stored | nowhere of its own — the result *is* the content's text, saved by 008's existing path when the reader presses Save or Done |
| what it never does | it does not run on open, on save or while reading: there is no repair behind the reader's back (A9, FR-020) |
| the premise to accept | a brace pair is taken to be a speaker, so a `{laughs}`-style pair becomes a paragraph head and is then proposed as a role; the role list (entity 3) is where that is removed, and one undo reverses the whole press |

---

## 3. Role — **derived, plus two stored facts about it**

One speaker named in one content, as far as this content is concerned. Not an entity that exists
anywhere else (spec: a role is not shared between contents or devices).

| Field | Type | Rules |
|---|---|---|
| `name` | `String` | Verbatim from the text (so `May` ≠ `may`); non-empty. |
| `turns` | `List<Turn>` | The turns whose `role == name`, in text order. |
| `turnCount` | `int` | `turns.length` — the number the list shows (FR-006). |
| `voice` | `VoiceChoice?` | **Stored** (2.1 below): the reader's pick, or `null`. |
| `assigned` | `VoiceChoice?` | **Derived** (2.2 below): what the role reads with when `voice == null`. |

**Where**: `lib/dialogue.dart` — `List<Role> rolesOf(List<Turn> turns)` returns roles in
**first-appearance order** (the order the reader sees them in, which is the order the text introduces
them), and its `name`s are exactly the distinct non-null `role` values.

### 3.a. Removal — **stored** (per content)

A name the reader has said is not a role.

| Field | Type | Rules |
|---|---|---|
| `name` | `String` | The name as it appears in the text. |
| `at` | `String` (ISO-8601) | The version of the text the removal was made on (`lib/models/content.dart:40`): a saved content's `updatedAt`, or the epoch for a shipped pre-set, whose text cannot change. |

**Rules**:

- A removal is honoured **only while the content's current version equals its own `at`** — a saved
  content's `updatedAt`, or the epoch for a pre-set, which never changes (editing a pre-set saves a new
  content with a new id, so no removal can outlive its text). Saving a content moves `updatedAt` (008), which
  expires every removal and makes the proposal re-include the name (spec US3 scenario 4, FR-006). No text
  diff, no hash, no new field (research D4).
- Every opening path must compute that version the same way, or a removal made on one path is out of force
  on another: the page has three (the catalog fallback, `_loadEntry`, the save path) and the middle one
  disagreed until T017 fixed it (research D4's correction).
- A removal whose name no longer occurs in the text is kept (harmless) but has no effect; it expires on
  the next save like any other.
- A removed name is never a role in this content: its turns become narration turns (`role == null`,
  FR-007) and it is not offered in the list again until an edit.
- Removing a name changes what is **spoken**, not what is displayed: the page still shows the text as
  written (spec A9, the reader's own wording about display vs speech).

### 3.b. `VoicePickerScreen` — **existing type, four optional parameters**

| Parameter | Type | Rule |
|---|---|---|
| `title` | `String?` | When set, the screen shows it (the role's name). Default `null` = today's behaviour. |
| `clearable` | `bool` (default `false`) | When true, a first row meaning *follow the automatic assignment* is offered; tapping it clears the pick. |
| `initialSelection` | `VoiceChoice?` | What to show as chosen. Unset = read the pick from `store` (today's path). A role's pick is not in `store`, so the page hands it over. |
| `onPick` | `Future<void> Function(VoiceChoice?)`? | Where a pick (or a clear, as null) goes. Unset = save through `store`. Set = the role store, so a role's voice can never be written as the language's (FR-013). |

**Corrected 2026-10-03 by the implementation**: the shape was recorded as two parameters; it is four,
because the two things the screen cannot answer itself are which row is chosen (a role's pick is not in the
`VoiceStore` it holds) and where a tap goes. Both are absent on the language path.

The language-level picker (today's caller, `lib/reading_view.dart:1939`) passes none of them, so that screen is
byte-identical to what ships (research D7, ripple note 5): the shipped picker tests pass unmodified. This is
the feature's only change to an existing widget's public shape.

---

## 4. RoleVoice / assignment — **derived** (recomputed per read)

The answer to "which voice does this role read with, given what the reader has chosen and what the device
has installed".

| Input | Source | Notes |
|---|---|---|
| the turn's detected language | `lib/language.dart` per paragraph rule, applied to the turn's **content** | a role whose turns are in two languages gets two reads — the language rule is per turn (and a turn is one paragraph), not per role |
| the reader's pick for that role | entity 3 `voice` | wins outright, whatever the language and dialect (FR-013) |
| the reader's pick for that language | `lib/voice_store.dart:21-45` | the assignment's reference (research D5) |
| the installed voices + their metadata | `voicesForAll()` (`lib/reader_service.dart:507-510`) + `lib/models/voice_mapping.dart` | gender where recorded; the dialect from the voice's own **locale** — corrected 2026-10-03 by the implementation, see rule 2 |

**The ranking** (deterministic; ties broken on the voice's own name so the order is total):

1. same language as the turn (never overridden — an English turn is never given a Chinese voice),
2. the same dialect as the reader's pick for that language, when that pick has one — read from the voices'
   own **locale** (`yue-HK` against `zh-CN`/`cmn-CN`; those two Mandarin spellings are one family), never
   from `VoiceMapping.dialect`: **corrected 2026-10-03 by the implementation**, which found the field
   declared but set by no row — deliberately, since 007 FR-010's own reason is that a Cantonese voice is
   *named* by its dialect, so the field would only repeat the name. The locale is what the engine is told
   before each utterance and it does carry the split, so it is the signal rule 2 reads
   (`lib/dialogue.dart`'s `_dialectFamily`),
3. the reader's own pick for that language, first (it satisfies 1 and 2),
4. a **recorded gender that differs from the roles already placed in this read** (so the second role does
   not sound like the first),
5. the voice's own name, ascending.

**Rules**:

- **Never stored.** Only picks are (research D5): a voice uninstalled simply yields a different
  assignment, rather than a dangling reference.
- **Reproducible**: the same content, the same picks and the same installed list give the same assignment
  (FR-014) — this is what the unit test asserts, by running the ranking twice and comparing, not by
  comparing to a frozen table.
- **Distinctness is bounded by the device** (FR-015, SC-003): when fewer voices match than there are
  roles, a voice is reused and the list shows it — the app does not refuse to read, and does not silently
  invent a voice. The bound is what Spike S1 measures (research.md → Spikes).
- **A voice's gender is metadata, never a claim about the role**: the assignment uses gender only to
  *differ from what it already placed*; it never asserts that 阿明 is male (A2, research D5's honest
  limit). A voice with no recorded gender (one exists — `en-us-x-tpc`) ranks after the ones that have one,
  rather than being excluded.

---

## 5. RoleSettings — **stored** (per content; the store's value)

The whole of what this feature persists for one content. One JSON object per content inside the single
`content_roles` preference key (research D6).

```
content_roles = {
  "<content id>": {
    "type":    "dialogue" | absent                     // entity 1
    "removed": [ {"name": String, "at": ISO-8601} ]    // entity 3.a, may be absent
    "voices":  { "<role name>": {"name": String, "locale": String} }  // may be absent
  }
}
```

| Rule | Detail |
|---|---|
| key | `content_roles` — one key for the whole app, `SharedPreferences` (`lib/video_record.dart:78`'s shape) |
| content key | the content's own id (`preset.id` / `entry.id` — `lib/reading_view.dart:447`, `:665`), the same key `read_position` and `video_record` use |
| written when | the type changes, a role is removed, or a role's pick changes — never on a read, never per turn |
| read | tolerantly: a malformed entry (not an object, wrong types, unparseable JSON) is ignored and the content reads as `standard`; the other contents' entries are unaffected — the rule `VideoRecordStore` follows (`lib/video_record.dart:69-180`) |
| removed when | the content is deleted (`lib/content_list_screen.dart:108`), and lazily when a lookup finds no such content (the belt 012's record store also wears, `lib/video_record.dart:93-95`) |
| size | bounded by the number of roles (tens), not by the text: a 100,000-character content stores the same handful of names and picks as a three-line one |
| migration | none needed: absence is `standard`, and an unreadable entry is `standard` |

---

## 6. What this feature feeds the existing types (no change to them)

| Existing type | Where | How the roles reach it |
|---|---|---|
| `ParagraphSpeech {text, language, voice, start, end}` | `lib/reader_service.dart:63-85` | the resolver's return value: in dialogue mode one speech per turn (entity 2), in standard mode exactly what `resolveParagraphSpeeches` returns today. **One field added 2026-10-03**: an optional `role` (the turn's speaker, null for narration and for every 标准 speech), which nothing but the read's log line and the video read — D1's partial reversal, recorded there |
| `_Utterance {paragraph, sentence, text, language, voice, start, end}` | `lib/reader_service.dart` `_sentencesOf` (`:357-377`) | derived by the reader service from the speeches it is handed: a turn is cut into sentences by the same code that cuts a paragraph (FR-010) — so a turn is *read* sentence by sentence, as the reader asked |
| `VideoSentence` (012) | `lib/video_timeline.dart:64-86` | one per sentence of the resolver's output; `paragraph`/`sentence` now count turns in dialogue mode (ripple note 4) |
| `ReadingPosition {contentKey, offset, charCount}` | `lib/read_position_store.dart` | untouched: the offset is a content offset and the prefixes are characters in the content, so switching type does not move the reader's place (FR-020, SC-009) |
| `SavedContent {id, text, updatedAt, …}` | `lib/models/content.dart` | untouched and never written by this feature; `updatedAt` is *read* (entity 3.a) and `id` is the store's key |

---

## 7. State transitions

```
                 reader sets the text type = 多人对话
   standard  ─────────────────────────────────────────────▶  dialogue
      ▲                                                        │
      │  reader sets the text type = 标准                      │  (page display, position, text, undo: unchanged)
      └────────────────────────────────────────────────────────┘

   in dialogue:
     proposal (derived)  ──reader removes a name──▶  removal stored (with updatedAt)
     role's voice        ──reader picks / clears──▶  pick stored / cleared
     the text            ──the reader presses Format──▶  blank lines inserted; the same undo stack
     reading             ──the text is saved──────▶  updatedAt moves ⇒ removals expire ⇒ proposal re-asked
     reading             ──the content is deleted─▶  the whole entry is removed
```

Nothing else transitions: a read never writes, a pick never moves the position, a removal never edits the
text — the reader's own Format press (entity 2.a) is the one transition that writes it, and it is an ordinary
008 edit — and the engine's own state (which voice is applied) is not part of this model: it is applied per
utterance by `_applyVoice` (`lib/reader_service.dart:458-469`) exactly as it is today.
