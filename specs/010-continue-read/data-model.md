# Data Model: Continue Read

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Only values that will actually exist are modelled here. The spec's
`ContinueReadState` and `PositionFeedback` are not separate types: the first is the
existing `_Mode` plus one nullable field, the second is the highlight span builder
that 003 already ships (see `research.md` § Grounding corrections).

## Entities

### ReadingPosition — the start position (FR-002/FR-003/FR-004, persisted per FR-008)

The one new value in the app. It is always derived from a user gesture, never invented,
and it is always a sentence or paragraph start of the text it belongs to.

| Attribute | Type | Meaning | Source |
|---|---|---|---|
| `contentKey` | `String` | Which text this position belongs to: the library entry id, or the shipped preset's id when the view is showing the catalog fallback | `SavedContent.id` / `PresetContent.id` |
| `offset` | `int` | Character index into that text, at a sentence or paragraph start | `TextSegment.start` from `resolveSentence` / `resolveParagraph` |
| `charCount` | `int` | Length of the text the offset was computed on — the identity guard | `text.length` |

Validation rules:

| Rule | Requirement | Behaviour when violated |
|---|---|---|
| `offset >= 0` | FR-009 | Discard the stored value, read from the beginning (FR-005) |
| `offset < charCount` and `charCount == text.length` | FR-009, "content changed" edge case | Discard; no message, no crash |
| `offset` re-resolves to a segment start in the current text | FR-002/FR-003 | Re-resolve to the enclosing sentence's start before use (never read from mid-word) |
| `contentKey` names the text currently on screen | FR-007 | A position for another text is never applied |
| `''` / whitespace-only text | "content cleared" edge case | No position exists (nothing to anchor), the key is deleted |

### ReadPositionStore — the persistence adapter (FR-008)

The reader/writer of the `shared_preferences` record specified in
`contracts/read-position-format.md`. Injectable so the view is testable without a
platform channel, exactly like `VoiceStore` (`lib/voice_store.dart`).

| Operation | Contract |
|---|---|
| `Future<void> save(String contentKey, ReadingPosition position)` | Writes `<offset>\|\|<charCount>` under `read_position_<contentKey>` |
| `Future<ReadingPosition?> load(String contentKey, int textLength)` | Returns a position only when the record parses **and** its `charCount` equals `textLength`; otherwise `null` |
| `Future<void> clear(String contentKey)` | Removes the key (FR-007) |

The `charCount` comparison lives in the store, not the view: it is a property of the
record, and a unit test can assert it without a widget.

### ReadingView anchor state — the in-memory position (FR-004/FR-005/FR-006/FR-010)

| Field | Type | Meaning | Cleared by |
|---|---|---|---|
| `_anchor` | `int?` | The start position currently in force; `null` means "read from the beginning" (FR-005) | tap/long-press (replaced), content load (replaced by the stored value), text change (D7) |
| `_anchorKey` | `String?` | `contentKey` of the text on screen — the library entry's id, or the preset id on the catalog-fallback path | every content load |
| `_highlight` | `TextSegment?` | **Existing** field, unchanged in meaning: the painted segment (tap/long-press feedback, per-paragraph read tracking) | read end, Stop, edit |
| `_readGen` | `int` | **Existing** generation guard: a stale read's cleanup must not win over a newer tap/Stop | tap/Stop |

Relationship to the existing model: `_anchor` is the parent fact; `_highlight` is one of
its renderings (the anchor's segment) and, while reading, the spoken paragraph. Neither
derives from the other — the tracking callback repaints `_highlight` and must never touch
`_anchor` (invariant I6).

### SpeechUnit — the utterance a read is queued in (FR-011)

Not a new public type: `ReaderService`'s existing queue entry (`ParagraphSpeech`) keeps its
name and its meaning — one paragraph's speech — while the service's **internal** queue
becomes one entry per sentence of that speech, derived with `sentenceRanges`
(`lib/segmenter.dart:33-69`). This is what makes the resume point a sentence.

| Attribute | Type | Meaning |
|---|---|---|
| text | `String` | One whole sentence, in submission order |
| language, voice | inherited | The enclosing paragraph's detected language and picked voice (a sentence never re-detects or re-picks) |
| paragraph index | `int` | Which speech it came from — what `onParagraphStart` reports |
| `_cursor` | `int` | The service's position in this queue; `pause()` keeps it, `resume()` re-runs from it |

Validation rules:

| Rule | Requirement | Behaviour |
|---|---|---|
| Every unit is a whole sentence | FR-011 | A split never produces a mid-sentence unit. The first unit of a speech starts where the caller asked (a paragraph start, a tapped sentence, or an anchor), which is always a sentence start (D1) |
| The queued order is the read order | FR-004/FR-011 | Units are spoken in queue order; no unit is skipped and none is spoken twice within one run |
| A resumed run starts at the interrupted unit | FR-011 | `resume()` re-runs from `_cursor`; units before it are not spoken again |
| The paragraph callback fires once per paragraph | FR-010 (003 tracking) | On that paragraph's **first** unit, so the highlight advances per paragraph, not per sentence |

## State transitions

```text
                 tap / long-press (resolve segment S)
   (no position) ─────────────────────────────────────► position = S.start
        ▲                                                   │
        │                                                   │ Continue Read
        │                                                   ▼
        │                                          SPEAKING from position,
        │                                          highlight = spoken paragraph
        │                                                   │
        │                                     end of text / Stop
        │                                                   ▼
        └──────────── text changed (Done, Save, ◄──── position RETAINED
                      load, emptied)                    (highlight cleared)
```

- A second tap or long-press **overwrites** the position (last gesture wins) and rewrites
  the stored record.
- Reading never moves the position (FR-010 is the tracking highlight, not a bookmark —
  `research.md` D11).
- A read started from a position ends with the position still in force, so Continue Read
  is repeatable and SC-004 has something to restore.
- Persistence is written on the gesture that sets the position, not on read start: a
  position the user set and never read is still remembered.

## Invariants a test can assert

- **I1 (FR-005, regression)** With no position, Continue Read speaks exactly the
  paragraphs the previous page read spoke, from offset 0 to the end.
- **I2 (FR-002/004)** After a tap that resolves segment `S`, the first speech of
  Continue Read starts at `S.start`; the last speech ends at `text.length`. The union of
  the spoken ranges is contiguous and covers `[S.start, text.length)`.
- **I3 (FR-003)** After a long-press the position is the enclosing paragraph's start, so
  the first speech starts at that paragraph, not at the sentence inside it.
- **I4 (FR-010)** Stop, and the natural end of a read, leave the position unchanged
  (`_anchor` identical before and after), while the tracking highlight follows the spoken
  paragraph and clears at the end.
- **I5 (FR-006)** Setting a position paints its segment; a restored position paints its
  segment; a read repaints the spoken paragraph.
- **I6** The tracking callback never mutates the position (a read that advances
  paragraphs does not move the anchor).
- **I7 (FR-007)** Changing the text (Done, Save, load another content, empty text) leaves
  no position: neither in memory (Continue Read reads from 0) nor on disk (the key is
  gone).
- **I8 (FR-008)** A position set in one view instance is in force in a fresh instance for
  the same text (the restart case), and only for that text.
- **I9 (FR-009)** A stored record whose `charCount` differs from the text length, a
  non-numeric or malformed record, and an offset at/past the end are all discarded
  silently — reading starts at 0, nothing throws.
- **I10 (spec edge case: rapid taps)** Successive taps leave the **last** position in
  force in memory and on disk (a slower earlier write may not overwrite a later one).
- **I11 (FR-001/SC-001)** The idle toolbar shows Continue Read and no longer offers the
  old label, in all four shipped locales.
- **I12 (FR-011/SC-006)** Pausing during a paragraph's k-th sentence and resuming speaks
  that sentence again from its start and never re-speaks sentences 1…k-1; the run still
  ends at the last unit of the queue.
- **I13 (FR-011)** Every queued unit is a whole sentence: after a split, no unit begins
  mid-sentence, whatever range the caller asked for.
- **I14 (FR-010)** The paragraph callback fires exactly once per paragraph — on its first
  sentence — so a sentence-granular queue leaves 003's paragraph-level tracking unchanged.

## Requirement coverage

| Requirement | Where it lives |
|---|---|
| FR-001 replace the page button | `_buildToolbar` idle branch; `continueReadButton` in the 4 ARBs (D9) |
| FR-002 tap sets the position | `_resolveAt` (sentence branch) → `_anchor`, `_anchorKey`, store save |
| FR-003 long-press sets the position | `_resolveAt` (paragraph branch) → same |
| FR-004 read from the position | `_readContinue` → `_readRange(anchor ?? 0, length, track: true)` |
| FR-005 no position → from the beginning | `_anchor == null` branch; I1 |
| FR-006 visual feedback | `_highlight` span builder (existing), set by the gesture and by restore (D8) |
| FR-007 clear on content change | D7 clear points; `ReadPositionStore.clear`; I7 |
| FR-008 persist across restarts | `ReadPositionStore` + `contracts/read-position-format.md`; I8 |
| FR-009 position beyond text length | `ReadPositionStore.load` validation + re-resolve to sentence start; I9 |
| FR-010 tracking from the position | existing `onParagraphStart` tracking, unchanged, exercised from a non-zero offset; I2/I4 |
| FR-011 resume at sentence granularity | the service's sentence queue (`SpeechUnit`); `resume()` from `_cursor`; I12/I13/I14; `quickstart.md` scenarios 12 (unit) and 16 (device) |
| SC-001 button replaced | I11, plus `quickstart.md` scenario 1 |
| SC-002 set by tap or tap-and-hold | I2/I3 |
| SC-003 reading begins at the position | I2, `quickstart.md` scenarios 2–3 |
| SC-004 position survives restart | I8, `quickstart.md` scenario 8 |
| SC-005 feedback indicates the position | I5, `quickstart.md` scenario 6 |
| SC-006 at most the interrupted sentence repeats | I12, `quickstart.md` scenarios 12 (unit) and 16 (device) |
