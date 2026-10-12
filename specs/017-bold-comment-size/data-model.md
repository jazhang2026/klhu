# Data Model: A bold face, and a comment one size down

Nothing new is stored. One field's **value domain** grows, one relationship becomes a **computed function**, and
one in-memory value gains a boundary — that is the whole model, and the sections below say so entity by entity.

### ReadingTypeface

**Purpose**: one face the reader can choose for the reading text (011 US2's shipped value).
**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `name` | `String` | no | stored, in the `reading_appearance` record's first part (`default`, **`bold`**, `serif`, **`serif-bold`**, `mono`, **`mono-bold`**) |
| `weight` | `FontWeight` | no | **code only, never stored** — `w400` for `default`/`serif`/`mono`, `w700` for the three bold values |
| `familyFor(platform)` | `String?` | yes | computed; `null` for `default` **and for `bold`** (the theme's own family), `serif` for `serif`/`serif-bold`, `monospace` for `mono`/`mono-bold` (D5) |

**Relationships**: `ReadingAppearance` holds exactly one; `AppearanceScreen` offers `all` in order; the page's one
style seam and the preview both ask it for its family and weight.
**Validation rules**: the offered set is `all` — six values, three of them at weight 700 (FR-001); and the contract's field table is its source of truth (FR-001);
the value is stored **as a name** and read back through `byName`, so adding it changes no field (FR-004); the
three content languages must render without missing glyphs (FR-005).
**Worked example**: `bold` → `(name: 'bold', weight: w700, familyFor(android): null)`; `serif-bold` →
`(name: 'serif-bold', weight: w700, familyFor(android): 'serif')`; `mono-bold` → `(…, 'monospace')`. The records
they write are `bold||medium`, `serif-bold||xlarge`, `mono-bold||small`.

### ReadingSize

**Purpose**: one offered character size of the reading text (011 US2's shipped value) — **unchanged by this
feature**.
**Attributes**: `name` (`String`, stored, second part), `points` (`double`, code only: 12/14/18/24).
**Validation rules**: unchanged (the contract's four names, FR-004's read rules).
**Worked example**: `xlarge` → `(name: 'xlarge', points: 24)`.

### The comment's size (a derived relationship, not an entity)

**Purpose**: the size a comment's own characters are painted at, in both places they are painted.
**Attributes**: **none stored.** One function of the size in force:

| the text's size | the comment's points | where it comes from |
|---|---|---|
| `xlarge` (24) | 18 | the next offered size down |
| `large` (18) | 14 | the next offered size down |
| `medium` (14) | 12 | the next offered size down |
| `small` (12) | **10** | **derived** — no smaller size is offered, and the reader asked for a visible difference |

**Relationships**: called by the page's span builder (D3) and by the video painter's block (D4); it reads
`ReadingSize` and stores nothing.
**Validation rules**: the page paints a comment one offered size below the text (FR-007); the frame does the same
in its own relationship (FR-008); at the smallest text size the comment is still strictly smaller (FR-009); no
picker offers it (FR-012).
**Worked example**: a text at `small` with `[注] How are you?` after its first sentence paints the comment at 10
points while the sentence is 12.

### ReadingAppearance

**Purpose**: the appearance in force (011's shipped entity).
**Attributes**: `typeface` (`ReadingTypeface`), `size` (`ReadingSize`).
**Grammar**: `<typeface>||<size>` — **unchanged**. `encode()` joins two parts, `decode()` requires exactly two
non-empty parts, and a part naming something this build does not offer falls back **on its own**.
**Validation rules**: FR-004 — a record written before this feature loads in it, a record written after it loads
in the shipped app, and neither direction rewrites anything. Read rules 1 and 3 and the malformed-value case are
untouched (research D1's table is the evidence).
**Worked example**: `bold||xlarge` → `(bold, xlarge)`; `serif-bold||xlarge` → `(serif-bold, xlarge)`;
`Helvetica||xlarge` → `(default, xlarge)`;
`serif||xlarge||bold` → the defaults (three parts, 011's rule — which is exactly why the weight is not a field).

### VideoSlot

**Purpose**: one painted block of a rendered video: the sentence being spoken, plus the comments that ride it
(015's own model).
**Attributes**:

| name | type | nullable | source |
|---|---|---|---|
| `kind` | `VideoSlotKind` | no | built |
| `paragraph`, `sentence` | `int` | no | built |
| `start`, `end` | `int` | no | built — **content** offsets, not display offsets |
| `text` | `String` | no | built — what the frame paints (the sentence, then each riding comment on its own line) |
| `commentStart` | `int?` | **yes — new** | built — **the index inside `text` where the comment's own characters begin**; `null` when the slot carries none |

**Relationships**: built by `video_timeline.dart`'s two builders (`:331`, `:354`); consumed by
`video_painter.dart`'s `_blockFor`, which lays out one span when it is `null` and two when it is set.
**Validation rules**: FR-008 (two spans, the second smaller); FR-011 (no comment → one span, painted exactly as
before); and the reason it is a field rather than something the painter computes: `start`/`end` are content
offsets and the display elides the tag's characters, so the boundary is **not** recoverable from `text` plus
`start`/`end` (research D4).
**Worked example**: the fixture's first sentence with its comment → `text = "Hola.\nHow are you?"`,
`commentStart = 6` (the index of `H`), so the frame paints `Hola.` in the sentence's size and `How are you?` one
size below it.

### State and invariants

**No new mutable state.** 011's state machine for the record is unchanged (absent → defaults; a value read by the
read rules; a confirmed choice written once; a cut-short write repaired by the next confirm). `commentStart` is
set once at build time and never mutated. So there is no transition table to add — and that absence is itself the
feature's shape (constitution V).

Each invariant below is phrased so a test can assert it directly:

- **INV-1 — the grammar never grows.** For **every** face in `ReadingTypeface.all` — six, three of them bold — and
  every size in `ReadingSize.all`, `encode()` splits into exactly two non-empty parts. (FR-004; a test over
  `all`, not over a hand-listed set.)
- **INV-2 — every value round-trips.** `decode(encode())` returns the same face and size, for every offered pair,
  including `bold`. (FR-004.)
- **INV-3 — a comment is always strictly smaller.** For every offered size, the comment's points are **less than**
  the text's — including `small`, where they are 10 against 12. (FR-009; this is the reader's own "有区别" as an
  assertion.)
- **INV-4 — one step down, exactly.** Whenever a smaller offered size exists, the comment's points equal that
  size's points (24→18, 18→14, 14→12). (FR-007.)
- **INV-5 — no comment, no change.** A slot with no comment has `commentStart == null`, its block is one span, and
  the painted text is byte-for-byte the text it painted before. (FR-011.)
- **INV-6 — the boundary is inside the text.** A slot with a comment has `0 < commentStart < text.length`, and the
  block's second span begins exactly there. (FR-008.)
- **INV-7 — offsets are untouched.** For any text, the display mapping, the highlight boundaries, a tap's
  resolution and a step's range are the values they were before this feature: 015's mapping tests and 016's step
  tests are **re-run as they stand**, not re-cut. (FR-010.)
- **INV-8 — the comment is small, not bold.** A sentence's own characters carry the face's weight; a comment's
  characters carry the smaller size **and the weight they carry today** (the spec's own edge case).
- **INV-9 — a bold value keeps its family.** For each of the three pairs, the bold value's `familyFor` equals its
  regular counterpart's (`default`/`bold` both `null`, `serif`/`serif-bold` both `'serif'`, `mono`/`mono-bold`
  both `'monospace'`), and its weight is `w700` where the regular's is `w400`. (FR-002.)
