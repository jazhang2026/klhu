# Contract: the kept-video record

**Feature**: `012-reading-video` | **Store owner**: `lib/video_record.dart` | **Spec**: FR-011, FR-012, FR-022

Which content owns which kept videos. It exists so that every video the reader kept can be found again
(played, shared, deleted) and so that FR-012's rule about a re-render has something to be enforced against.

| Item | Value |
|---|---|
| Store | `shared_preferences`, key `video_record`, holding a JSON object |
| Key of the map | the content's own key — the same string the read position and the library use for that content |
| Value | an **array** of entries, oldest first: `{"name": <string>, "uri": <string>, "keptAt": <int, epoch ms>}` |
| The content's own video | the **last** entry: the one kept most recently, which is what the page's Play action opens (FR-022) |

## Read rules

1. A missing key returns an empty map.
2. Malformed JSON, a JSON value that is not an object, or an entry missing `name`/`uri` returns the entries
   that are well-formed and drops the rest — without an error and without rewriting the store. An array whose
   entries are all malformed is no entry.
3. Looking up a content with no entry — or whose array is empty — returns nothing (the content offers to record
   a video).
4. **A lookup whose `uri` no longer resolves** (the file was removed outside the app) reports **that** video as
   gone, forgets that entry, and leaves the content's other videos alone; when it was the content's last one,
   the content offers to record again (FR-022). It never returns a video that cannot be played.
5. **The shape this feature shipped with is migrated on read** (2026-10-06 amendment): a value that is a single
   object rather than an array — what 012 wrote from 2026-09-26 to 2026-10-06 — is read as a one-entry array.
   Nothing the reader kept is lost, and that content is rewritten in the new shape the next time anything is
   written for it.

## Write rules

1. **Keeping** a review writes for that content according to the reader's own answer (FR-012): **replace**
   rewrites the content's last entry, and the platform deletes the file that entry named; **keep both** appends
   a new entry after it. Either way the entry written is the last one — it is the content's own video (FR-022) —
   and the store never holds two entries naming the same `uri`.
2. **Deleting** a kept video removes **its** entry and its file from the device's video library. The content's
   other entries are untouched and keep their order. The entry is removed whether or not the file's removal
   succeeds; a failure to remove the file is reported, not swallowed silently, and the next lookup then finds
   that video gone (rule 4).
3. **Throwing a render away** writes nothing: the review's working copy never had an entry (FR-021).
4. No other path writes this store — not the reading page's idle state, not a content's deletion, not app
   start.

## Invariants

- Every entry names a `name` and a `uri`, and no two entries of one content name the same `uri`.
- Entries are ordered oldest first; the last entry is the video the content's own Play action opens.
- Every entry names a video the reader kept: the store never holds a video that was only rendered, played or
  shared from a review (FR-021).
- The `name` is derived from the content's name at keep time; a later rename of the content does not rewrite an
  entry's name in the library, and a later keep does not rewrite an earlier entry's name.
- Deleting a **content** (the app's existing delete) leaves its video entries and files alone: the spec does
  not couple the two, and this feature must not start to.
