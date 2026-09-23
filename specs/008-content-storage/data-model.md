# Data Model: Content Storage and Content Management

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Date**: 2026-09-23

On-disk shape is specified in [contracts/storage-format.md](./contracts/storage-format.md);
this file is the in-memory model, its invariants and its transitions.

## Entities

### SavedContent

**Purpose**: one entry in the unified content list — a pre-set or a user-saved page.

**Attributes**:
- `id` (String): stable identity, `c_<epochMillis>_<4 hex>` (research D8); the file name is `<id>.txt`
- `name` (String): display name. Auto-generated for user content (research D7), supplied by the preset catalog for pre-set content
- `language` (String): `en` | `zh-Hans` | `es` — the *label* language of the entry (used in the list and to seed naming); **reading language stays per-paragraph detection** (`lib/language.dart`), unchanged
- `origin` (ContentOrigin): `preset` | `user`
- `createdAt` (DateTime): creation time (preset: first seed into the index)
- `updatedAt` (DateTime): last save time; equal to `createdAt` until edited
- `charCount` (int): character count kept in the index so the list can show a size hint without reading the text

**Not stored in the index**: the text itself (it lives in `contents/<id>.txt`),
and no `EditHistory` — undo is the widget-level platform stack (research D6),
so no history field exists to persist.

**Relationships**:
- Managed by: `ContentStore`
- Listed by: `ContentListScreen`
- Loaded into: `ReadingView._content`
- Pre-set entries reference: `PresetCatalog` by `id`

**Validation Rules**:
- `id` unique across the index; a collision re-rolls the random suffix at creation (FR-007)
- `name` non-empty; uniqueness enforced by the ` (n)` suffix rule (spec edge case)
- text length 1 … 100,000 characters at save time (research D10); whitespace-only is rejected
- `origin == preset` ⇒ the entry exists in the seeded catalog; `deletedPresetIds` wins over the catalog on load
- an entry whose `contents/<id>.txt` is missing is *damaged*, not deleted

### ContentIndex

**Purpose**: the whole library's metadata; the only file read to draw the list.

**Attributes**:
- `version` (int): schema version, currently `1`
- `entries` (List<SavedContent>): all live entries, pre-set included
- `deletedPresetIds` (List<String>): presets the user deleted; they stay out of the list and out of future seeds (research D4)
- `lastOpenedId` (String?): the entry the app should open next launch (research D9)

**Relationships**: written by `ContentStore`; the source of truth for the list.

**Validation Rules**:
- unparsable / unknown `version` ⇒ the file is moved to `index.corrupt-<ts>.json`, the store re-seeds from the catalog and reports a localized error (research D11)
- entries referencing a missing text file are kept but flagged damaged; entries whose file the user deleted are dropped
- `lastOpenedId` pointing at a deleted entry is cleared on load

### PresetCatalog

**Purpose**: the shipped pre-set contents as data (FR-017, FR-020 — research D3).

**Attributes** (per entry in `assets/content/presets.json`):
- `id` (String): stable id, e.g. `preset_en_sample`
- `language` (String): `en` | `zh-Hans` | `es`
- `name` (Map<String, String>): localized display name keyed by interface language (`en`/`zh`/`es`), `en` as fallback
- `text` (String): the content itself

**Relationships**: read once at startup through `rootBundle`; seeds the index on
first launch or after a repair; supersedes `lib/sample_texts.dart`.

**Validation Rules**:
- `id` unique within the file; must not change once shipped (a changed id re-appears as a new entry)
- `language` must be one of the three reading languages; text non-empty
- names must be present for all three interface languages (fallback `en`)
- a malformed catalog entry must not break startup: it is skipped and reported (research D11)

### ContentStore (service seam)

**Purpose**: the only writer/reader of the library; injectable directory so every
rule is unit-testable without a device.

**API (shape, not final signatures)**:
- `Future<List<SavedContent>> list()` — index-only, no text reads
- `Future<String> read(SavedContent)` — the text for one entry
- `Future<SavedContent> saveNew(String text, {String language})` — auto-name, id, timestamps
- `Future<SavedContent> update(String id, String text)` — user entries only; name kept
- `Future<SavedContent> saveEdited(SavedContent loaded, String text)` — preset ⇒ `saveNew`, user ⇒ `update` (FR-019 / research D5)
- `Future<void> delete(String id)` — preset ⇒ tombstone, user ⇒ drop entry + file (research D4)
- `Future<SavedContent?> lastOpened()` / `Future<void> markOpened(String id)` (research D9)
- `Future<List<SavedContent>> repair()` — the index repair path of D11

**Validation Rules**: every mutating call applies the empty/size guards *before*
touching the file system; a failed write leaves both the in-memory state and the
previous index untouched (no half-saved entry).

## State transitions

```text
list ──load──> reading (READ)
reading ──Edit──> EDIT
EDIT ──Undo──> EDIT                (platform undo stack; disabled at the oldest state,
                                    SnackBar when history is exhausted — research D6)
EDIT ──Done──> READ                (commits the edit into the page buffer; not persisted)
EDIT ──Save──> EDIT                loaded user content  ⇒ entry updated (name kept)
                                   loaded pre-set       ⇒ NEW user entry created,
                                                          original preset untouched
EDIT ──switch content with unsaved edits──> confirm dialog
                                   Discard ⇒ load the chosen content
                                   Cancel  ⇒ stay in EDIT
list ──delete──> confirm dialog ──Cancel──> list (entry unchanged)
                                ──Delete──> list (entry gone; preset tombstoned)
```

Invariants that tests assert:
1. A pre-set's text is byte-identical before and after it is edited+saved (SC-010).
2. Nothing is written when the guards reject a save (empty / oversized).
3. `list()` never reads a content file (list latency independent of text size).
4. After a restart the library equals the library before it, including the
   deletion of a pre-set and the last opened entry (SC-004).
