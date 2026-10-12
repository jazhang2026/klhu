# Storage Contract: Reading appearance (typeface and character size)

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Decisions**:
[research.md](../research.md) D4–D6

**Date**: 2026-09-24

The app is on-device only, so there is no HTTP/API contract; the persistent record is the contract.
Like the Continue Read position (`specs/010-continue-read/contracts/read-position-format.md`), this
record is deliberately **not** part of `specs/008-content-storage/contracts/storage-format.md`: the
library's `index.json` is version-locked (any other version takes the destructive repair path), and a
reading preference is per-device view state, not library metadata.

## Location

```text
Android: /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml
iOS:     NSUserDefaults, standard suite, for bundle id com.example.klhu
```

`shared_preferences` is already the app's store for per-device UI state (voice picks in
`lib/voice_store.dart`, interface language in `lib/models/language_preference.dart`), so this record needs no new
dependency and no new file format. *(The read-position store this sentence also named left the tree on
2026-10-12 — 016 decision 5.)*

## The record

One key for the whole appearance, in the two-field grammar the app's other per-device records already
use (`voice_*` = `<name>||<locale>`; its `read_position_*` twin retired with 010's FR-008 on 2026-10-12):

```text
key:   reading_appearance
value: <typeface>||<size>
```

| Field | Type | Domain | Default |
|---|---|---|---|
| `typeface` | `String` | `default`, `bold`, `serif`, `serif-bold`, `mono`, `mono-bold` | `default` |
| `size` | `String` | `small`, `medium`, `large`, `xlarge` | `medium` |

One key rather than one per field, so a confirmed choice is a **single** `setString`: there is no state
in which a new typeface sits beside a stale size because a write was cut short.

Examples:

```text
reading_appearance = serif||xlarge
reading_appearance = default||medium
```

The key is namespaced by its own name and shares no prefix with the keys already in use
(`voice_en`, `voice_zh_Hans`, `voice_es`, `interface_language`; `read_position_<contentKey>` retired
2026-10-12).

### What the keys mean when rendered

The stored value is the app-level name; the platform family and the point size are app constants, so a
later retune is a code change, not a data migration.

| `typeface` | Android family | iOS family |
|---|---|---|
| `default` | none — the theme's own family (today's look) | none |
| `bold` *(017, 2026-10-12)* | **none**, at `FontWeight.w700` — the theme's own family carries the weight, which on Android is the variable `Roboto` (its `wght` axis) | none, at `w700` |
| `serif` | `serif` (measured: `NotoSerif-Regular.ttf`, with the lang-tagged CJK family as fallback) | `Times New Roman` |
| `serif-bold` *(017, 2026-10-12)* | `serif`, at `FontWeight.w700` (measured: `NotoSerif-Bold.ttf` ships and the family registers a `weight="700"` entry; **no bold CJK face ships**, so a Chinese word is the fallback face with its weight synthesised) | `Times New Roman`, at `w700` |
| `mono` | `monospace` | `Courier New` |
| `mono-bold` *(017, 2026-10-12)* | `monospace`, at `FontWeight.w700` (measured: the family's only entry is `DroidSansMono.ttf` at `weight="400"`, so the weight is **synthesised** — 017's probe of 2026-10-12 and its decision 5, taken with the reader's eyes on the result) | `Courier New`, at `w700` |

The iOS column is **unverified on this host** (no macOS): it is the CoreText name for the same
intent, and research D5 records it as such. `default` never sets a family, so an unverified mapping
can never make the app's shipped look worse.

| `size` | Point size | Note |
|---|---|---|
| `small` | 12 | |
| `medium` | 14 | the size the app ships today (`bodyMedium`, Material 3) — the default is a no-op |
| `large` | 18 | |
| `xlarge` | 24 | the largest offered size, and the one FR-012's width guarantee is measured at |

## Read rules

`AppearanceStore.load()` returns a `ReadingAppearance` under **all** of these conditions, and never
throws:

1. the key exists and the value splits into exactly two non-empty parts;
2. part 1 is one of the **six** typeface names (017 added `bold`, `serif-bold`, `mono-bold` on 2026-10-12) —
   otherwise that field alone falls back to `default`;
3. part 2 is one of the four size names — otherwise that field alone falls back to `medium`.

Anything else — a missing key, a single-part value, a three-part value, a value from an older or
newer format — yields the defaults (`default`/`medium`), which is the app's shipped rendering. A
malformed record is **not** an error: nothing is shown to the user, nothing is repaired or rewritten,
and the next confirmed choice overwrites it.

## Write protocol

- Written **only** on a confirmed choice (the appearance screen's confirm) — never while the user is
  browsing the options, so an abandoned preview leaves the record untouched (FR-008, US2 scenario 4).
- One key, one `setString` per confirm: last confirm wins; a second confirm overwrites the value and
  never appends a second record.
- Deleted by nothing in this feature: there is no "reset to default" gesture in scope, and a confirm
  of `default||medium` is the same value the absent-record default produces.

## Error and repair states

| State | Detected by | Behaviour |
|---|---|---|
| Missing key (fresh install, cleared data) | read rule 1 | Defaults: `default`/`medium` — the shipped look; nothing is written until the user confirms one |
| Value unparsable (no `||`, empty part, extra part) | read rule 1 | Defaults; the stale value is left in place until the next confirm |
| Unknown typeface or size name (a value from a future build, a hand-edited file, a withdrawn face) | read rules 2–3 | That field falls back on its own; the other field still applies |
| `shared_preferences` unavailable or throwing | the store's own call | Caught and `debugPrint`-ed; the session renders with the defaults and reading works normally. Missing persistence must never block reading — the same rule `ReadPositionStore` follows |

## Invariants a test can assert

1. **Round-trip**: save `serif||xlarge`, load → `(serif, xlarge)`; and (017, 2026-10-12) each of
   `bold||xlarge`, `serif-bold||xlarge`, `mono-bold||xlarge` → itself, with the encoded value splitting into
   exactly two parts for every offered face (the mutation 2026-10-12 made the grammar's own assertion).
2. **Absent is default**: nothing stored → `(default, medium)`, and the applied style equals the
   theme's `bodyMedium` (size 14, no family).
3. **Per-field fallback**: `Helvetica||xlarge` → `(default, xlarge)`; `serif-bold||huge` →
   `(serif-bold, medium)` (017, 2026-10-12 — a bold name is a name like any other); `serif||huge` →
   `(serif, medium)`.
4. **Malformed values** (`''`, `serif`, `serif||`, `||xlarge`, `serif||xlarge||extra`) each return the
   defaults and never throw.
5. **Namespace**: the key this store writes collides with no existing key (`voice_*`,
   `interface_language` — `read_position_*` was the third, and left the tree on 2026-10-12, 016 decision 5).
6. **Last write wins**: after two saves, load returns the second.
7. **One write per confirm**: confirming once writes exactly one key (asserted on the mocked prefs
   map), and dismissing the screen writes none.
