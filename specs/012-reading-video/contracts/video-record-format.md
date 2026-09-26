# Contract: the kept-video record

**Feature**: `012-reading-video` | **Store owner**: `lib/video_record.dart` | **Spec**: FR-011, FR-012, FR-022

Which content owns which kept video. It exists so that a kept video can be found again (played, shared,
deleted) and so that "exactly one video per content" has something to be enforced against.

| Item | Value |
|---|---|
| Store | `shared_preferences`, key `video_record`, holding a JSON object |
| Key of the map | the content's own key — the same string the read position and the library use for that content |
| Value | an object: `{"name": <string>, "uri": <string>, "keptAt": <int, epoch ms>}` |

## Read rules

1. A missing key returns an empty map.
2. Malformed JSON, a JSON value that is not an object, or an entry missing `name`/`uri` returns the entries
   that are well-formed and drops the rest — without an error and without rewriting the store.
3. Looking up a content with no entry returns nothing (the content offers to record a video).
4. **A lookup whose `uri` no longer resolves** (the file was removed outside the app) reports the video as
   gone, forgets that entry, and leaves the content offering to record again (FR-022). It never returns a
   video that cannot be played.

## Write rules

1. **Keeping** a review writes exactly one entry for that content, replacing any earlier entry — the store
   never holds two entries for one content (FR-012), and the replaced file is deleted from the library as
   part of the same action.
2. **Deleting** a kept video removes its entry and the file from the device's video library. The entry is
   removed whether or not the file's removal succeeds; a failure to remove the file is reported, not
   swallowed silently, and the next lookup then finds the video gone (rule 4).
3. **Throwing a render away** writes nothing: the review's working copy never had an entry (FR-021).
4. No other path writes this store — not the reading page's idle state, not a content's deletion, not app
   start.

## Invariants

- At most one entry per content, and every entry names a `name` and a `uri`.
- The `name` is derived from the content's name at keep time; a later rename of the content does not rewrite
  the video's name in the library (the file the reader kept keeps its name).
- Deleting a **content** (the app's existing delete) leaves its video entry and file alone: the spec does
  not couple the two, and this feature must not start to.
- The store never holds a video the reader did not keep.
