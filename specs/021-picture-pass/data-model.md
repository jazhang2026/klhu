# Data model: the assignment pass's pictures, and the controls on them

Nothing is stored that was not stored before: the record is 020's own `PictureRun` list, and this feature changes
which edits may produce one — plus one screen's own view state, which is never written.

## The picture in force

**Purpose**: one picture the reader chose for this render, as the pass shows it and as the record names it.

**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `name` | `String` | no | `HeldPicture.name` — the reader's own file name; **the record's key** (020's `FR-010`) and, since this feature, the cell's **semantic label** (never painted) |
| `path` | `String` | no | the pick's own copy inside the prompt's directory (`lib/video_pictures.dart`); valid only while the dialog holds it — the reason a thumbnail lives no longer than the visit |
| `thumbnail` | widget | no | the picture at the cell's size, decoded bounded (`cacheWidth`) |
| `count` | `int` | no | the number of sentences **the reader assigned** this picture, resolved against this render's sentence list |

**Relationships**: one picture holds 0..n of the reader's runs' sentences (FR-003's own "0 or multiple"); its
place in the strip is its place in the render's order.

**Validation rules**: the picture is in force iff it is among the picks the dialog holds (FR-003, FR-016);
`name` is unique among the pictures in force as far as the record is concerned (two picks can share one name, and
020's own rule — the first pick carrying a name owns its run — stands).

**Sample / worked example**: three pictures — `w020_white.png` (4), `w020_black.png` (0), `w020_red.png` (0).

## The reader's runs

**Purpose**: what the reader decided, one entry per picture, exactly as 020 defined it. Unchanged in shape here.

**Attributes**: `PictureRun.name` (the picture's own file name), `PictureRun.spans` (the sentences as content
spans, ascending). Both unchanged; see 020's `data-model.md` §1-§3 — this feature does not re-open them.

**Validation rules**: a span belongs to at most one run (FR-013); the pass shows a picture's count as the number
of its spans that this render's sentence list answers (`indicesOfSpans`), so a stale span is not counted;
`runsThatFit` still decides what a pass opened later shows.

## The pass's own view state (never written)

**Purpose**: what the reader is looking at on this page. It is state of the page, not of the content.

**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `pictures` | `List<HeldPicture>` | no | the pictures in force, in the reader's order (020's own field) |
| `runs` | `List<PictureRun>` | no | one per picture, in the same order (020's own field) |
| `selected` | `int` | no | the picture a tap selected; the strip's highlight and the sentence list follow it |
| `held` | `int?` | **yes** | the picture a hold opened large; `null` means the list is showing (FR-004) |
| `confirming` | `AssignmentRefusal?` / delete-or-switch | yes | which confirmation is up, if any (FR-008, FR-011) |

**State machine** (per reader gesture):

| state | event | next state | guard |
|---|---|---|---|
| list showing | tap a cell | list showing, that picture selected | always |
| list showing | hold a cell | large picture showing | always (FR-004) |
| large picture showing | `Close` | list showing, same picture selected | always (FR-004) |
| large picture showing | `Move left` / `Move right` | large picture showing; the strip's order changed, and re-centred | the picture's own run is empty (FR-005, FR-006) |
| large picture showing | `Delete this picture` | a confirmation is up | the picture's own run is empty (FR-005, FR-008) |
| confirming a delete | `Delete` | list showing; the picture and its run are gone | — |
| confirming a delete | `Cancel` | large picture showing; nothing changed | — |
| list showing | tap a sentence the selected picture holds | list showing; that sentence is taken back | the sentence is an end of that picture's run, else the middle-of-run refusal (020's `FR-016`) |
| list showing | tap a sentence no picture holds | list showing; the sentence is given to the selected picture | 020's continuity and order rules |
| list showing | tap a sentence **another** picture holds | a switch confirmation is up | the sentence is an end of its holder's run **and** the selected picture ends continuous and in order (FR-011) |
| confirming a switch | `Move it` | list showing; the sentence left its holder and is the selected picture's | — |
| confirming a switch | `Cancel` | list showing; nothing changed | — |

## The assignment answer

**Purpose**: what the pass answers with when the reader is done — unchanged from 020: `AssignmentDraft(pictures,
runs)`, the pictures in the reader's order and one run per picture. **The fallback is never written into it**
(FR-016): the sentences the render hands to a picture nobody assigned are an outcome of the render.

## Invariants

Each is phrased so a test can assert it directly.

- **INV-1**: every sentence of the content appears in **at most one** run's spans' resolved indices — for the
  record, for the badge's counts, and for the render's `ranges=` (FR-013).
- **INV-2**: a picture's badge number equals the number of **its own run's** spans that this render's sentence list
  answers — never anything the fallback feeds (FR-001, FR-019, D9).
- **INV-3**: the cell's semantic label is the picture's own `name`, and no painted label on the page carries a file
  name (FR-002).
- **INV-4**: the move and the delete are offered **iff** the selected picture's own run is empty (FR-005).
- **INV-5**: cancelling **any** confirmation leaves the record byte-identical — the same runs, in the same order,
  and a render started afterwards produces the same `ranges=` line (FR-008, FR-012).
- **INV-6**: a switch moves **exactly one** sentence: the holder's run loses it and the target's gains it, in one
  edit, and the counts sum to the content's sentence count before and after (FR-011, FR-013).
- **INV-7**: every legal edit leaves each run's sentences continuous and in the pictures' order (020's `FR-003`,
  `FR-004`, kept by FR-015).
- **INV-8**: the draft the pass answers with holds the **reader's** runs only — no fallback sentence, ever
  (FR-016).
- **INV-9**: the whole content is still covered by the render: every sentence paints a picture (020's own
  invariant, untouched — this feature changes no split and no frame).
