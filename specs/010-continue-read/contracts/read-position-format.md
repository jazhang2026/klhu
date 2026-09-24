# Storage Contract: Continue Read start position

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Decisions**: [research.md](../research.md) D4–D7
**Date**: 2026-09-24

The app is on-device only, so there is no HTTP/API contract; the persistent record is
the contract. This one is deliberately **not** part of
`specs/008-content-storage/contracts/storage-format.md`: the content library's
`index.json` is version-locked (any other version takes the destructive repair path), and
a start position is per-device view state, not library metadata.

## Location

```text
Android: /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml
iOS:     NSUserDefaults, standard suite, for bundle id com.example.klhu
```

`shared_preferences` is already the app's store for per-device UI state (voice picks in
`lib/voice_store.dart`, interface language in `lib/models/language_preference.dart`), so
this record needs no new dependency and no new file format.

## The record

One key per content, namespaced so it can never collide with the existing keys
(`voice_en`/`voice_zh_Hans`/`voice_es`, the language preference key):

```text
key:   read_position_<contentKey>
value: <offset>||<charCount>
```

| Field | Type | Rules |
|---|---|---|
| `contentKey` | `String` | A library entry id (`c_<epochMillis>_<4 hex>`, `[0-9a-z_]`) or a shipped preset id (`[a-z_]`). Never empty; the view only writes a key for content it can name |
| `offset` | decimal `int` | `0 <= offset < charCount`. Always a sentence or paragraph start of the text it was computed on (D1) |
| `charCount` | decimal `int` | `> 0`; the length of the text the offset was computed on — the identity guard (D6) |

Examples (the shipped English pre-set, position set on its third paragraph):

```text
read_position_preset_en_sample = 214||334
```

```text
read_position_c_1758609612000_1a2b = 96||412
```

The existing `voice_*` keys keep their own `'<name>||<locale>'` grammar; the separator is
shared, the fields are not.

## Read rules

`ReadPositionStore.load(contentKey, textLength)` returns a position only when **all** of
these hold:

1. the key exists and the value splits into exactly two non-empty parts;
2. both parts parse as non-negative decimal integers (no sign, no whitespace, no float);
3. `charCount` equals the `textLength` of the text currently in hand (D6);
4. `offset < textLength`.

Anything else — a missing key, a value from an older/newer format, a value whose text
changed underneath it — is **not an error**: the store returns `null`, the view reads
from the beginning (FR-005), and nothing is shown to the user. The record is *not*
repaired or rewritten by a failed read; the next gesture that sets a position overwrites
it.

Given an accepted position, the view re-resolves `offset` to its enclosing sentence start
before use, so a position is only ever a segment boundary of the current text (FR-009's
"middle of word" case cannot arise from stored data either).

## Write protocol

- Written on the gesture that sets the position (tap, long-press) — not at read start, so
  a position the user set and never played is still remembered (FR-008).
- Last gesture wins. The view serialises writes per content: a write that is no longer
  the current position is dropped rather than applied late (a slow earlier write must not
  resurrect a superseded position — invariant I10).
- One key per content: a new position for the same content overwrites the value, never
  appends a second record.
- Deleted by `clear(contentKey)` when the visible text changes: Done (committed edit),
  Save, loading or switching content, emptied text (FR-007, D7).
- Each write is a single `setString`, so there is no partial-write state to repair.

## Error and repair states

| State | Detected by | Behaviour |
|---|---|---|
| Value unparsable (wrong separator count, non-numeric, negative) | read rule 1–2 | Treated as no position; the stale value is left in place until the next position is set |
| Position belongs to different text of the same length | read rule 4 cannot see it; the re-resolve keeps it on a sentence start | Documented residual risk, accepted in D6 (no hash); a position can only point at the same length of text |
| Position from a pre-set whose text changed between app versions | read rule 3 (length differs) | Discarded; reading starts at the beginning |
| `shared_preferences` unavailable / throws | the store's own call | Caught; the position stays in memory for the session and reading works normally. A missing persistence layer must never block reading (the view already treats storage as optional — `reading_view.dart:103-106`) |
| Orphan key for a deleted content | never read | Invisible: reading a position requires naming the content, and nothing enumerates these keys. Growth is one short key per content the user ever positioned (`charCount` caps contents at 100 000 chars) |

## Invariants a test can assert

1. **Round-trip**: `save(k, position)` then `load(k, charCount)` returns an equal position.
2. **Length mismatch**: `load(k, charCount + 1)` returns `null`, and the stored value is
   untouched.
3. **Malformed values** (`'214'`, `'214||'`, `'||334'`, `'a||b'`, `'-1||334'`,
   `'214||334||5'`) each return `null` and never throw.
4. **Cleared is cleared**: after `clear(k)`, `load(k, …)` is `null`.
5. **Namespace**: no key this store writes collides with the `voice_*` keys or the
   language preference key.
6. **Last write wins**: after two `save` calls for the same key, `load` returns the second.
