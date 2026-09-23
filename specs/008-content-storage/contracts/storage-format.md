# Storage Format Contract: Content Library

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Decisions**: [research.md](../research.md) D1/D4/D8/D10/D11
**Date**: 2026-09-23

This is the one interface a future version (or a test) must agree with. The app
is on-device only, so there is no HTTP/API contract; the persistent format is the
contract.

## Location

```text
<getApplicationDocumentsDirectory()>/content/
├── index.json                  # metadata for every entry (the only file the list reads)
├── contents/
│   ├── c_1758609612000_1a2b.txt     # UTF-8 text, one file per user content
│   └── c_1758609612000_1a2b.txt     # (pre-set texts live in the asset, not here)
└── index.corrupt-<epochMillis>.json # a moved-aside index that failed to parse
```

## index.json

```json
{
  "version": 1,
  "entries": [
    {
      "id": "c_1758609612000_1a2b",
      "name": "The sun rose over the quiet town",
      "language": "en",
      "origin": "user",
      "createdAt": "2026-09-23T10:22:03.114Z",
      "updatedAt": "2026-09-23T10:31:47.902Z",
      "charCount": 412
    }
  ],
  "deletedPresetIds": ["preset_es_sample"],
  "lastOpenedId": "c_1758609612000_1a2b"
}
```

| Field | Type | Rules |
|---|---|---|
| `version` | int | `1`. Any other value ⇒ treat as unsupported (repair path) |
| `entries[].id` | string | `c_<epochMillis>_<4 hex>`; unique; also the text file name for `origin: user` |
| `entries[].name` | string | non-empty; auto-generated for user content, catalog-supplied for presets |
| `entries[].language` | string | `en` \| `zh-Hans` \| `es` |
| `entries[].origin` | string | `user` \| `preset` |
| `entries[].createdAt` / `updatedAt` | ISO-8601 UTC | `updatedAt >= createdAt` |
| `entries[].charCount` | int | ≥ 1, ≤ 100000; lets the list show size without reading text |
| `deletedPresetIds` | string[] | tombstones; a tombstoned preset is never seeded again in this install |
| `lastOpenedId` | string \| null | entry id, or null when nothing is loaded; cleared when it points at a deleted entry |

## Pre-set catalog (asset, read-only)

```json
{
  "version": 1,
  "presets": [
    {
      "id": "preset_en_sample",
      "language": "en",
      "name": { "en": "English sample", "zh": "英文示例", "es": "Muestra en inglés" },
      "text": "The sun rose over the quiet town. …"
    }
  ]
}
```

Presets are **not** copied into `contents/`: their text is read from the asset,
so an app update can correct or extend them (research D3). Deleting one only adds
its id to `deletedPresetIds` (research D4).

## Write protocol (crash safety)

1. Write the new/updated text to `contents/<id>.txt.tmp`, `flush`, then rename to
   `contents/<id>.txt` (rename is atomic on the same filesystem).
2. Only then write `index.json` the same way (`.tmp` + rename).
3. A `.tmp` file left by a crash is ignored on load and deleted on the next save;
   an entry in the index whose text file never landed is *damaged*, never fatal.

## Error and repair states

| State | Detection | Behaviour |
|---|---|---|
| Index unparsable / bad `version` | `jsonDecode`/schema check | move to `index.corrupt-<ts>.json`, re-seed presets, report a localized error (FR-010) |
| Text file missing for a user entry | read on load | entry listed as damaged; delete offered (spec edge case) |
| Text file unreadable (permissions/IO) | `FileSystemException` on read | same as above; the error text is not swallowed |
| Disk full / write refused | `FileSystemException` (incl. `ENOSPC`) on save | localized message, in-memory state unchanged, previous index intact (FR-010) |
| Empty / whitespace-only save | guard before write | localized message, nothing written |
| Text over 100,000 chars | guard before write | localized message, nothing written, nothing truncated |
| Catalog entry malformed | parse of the asset | entry skipped, other presets still seed; reported once |

## Invariants a test can assert

1. `list()` reads `index.json` and no `contents/*.txt`.
2. Save-then-restart yields an identical library (ids, names, timestamps, order
   by `updatedAt` descending).
3. Editing a pre-set and saving leaves the asset text untouched and produces a
   new `origin: user` entry (SC-010).
4. Deleting a pre-set adds exactly one tombstone and survives restart; deleting a
   user entry removes its index entry **and** its file.
5. Timestamps are UTC ISO-8601; `updatedAt >= createdAt` for every entry.
6. All integers/strings in the index round-trip through one JSON encode/decode.
