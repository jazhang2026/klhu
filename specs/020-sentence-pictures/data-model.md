# Data Model: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · **Ground**: `research.md` (the four grounding corrections and D1-D6)

---

## 1. `PictureRun` — what the reader decided, per picture

| name | type | nullable | source |
|---|---|---|---|
| `name` | `String` | no | the picture's own file name as the reader picked it (`HeldPicture.name`) — research D7 (2026-10-14), and **not** its index, nor the path of the prompt's own copy |
| `spans` | `List<(int, int)>` | no (empty = nothing assigned) | the sentences this picture carries, as **content spans**, in order |

**The key, and why it moved (2026-10-14)**: a run names its picture by the picture's own file name. This table's
first version keyed it by `HeldPicture.path` (research D2), which the app deletes with the prompt that made it
(`discardPictures`), so the assignment could not outlive a visit; the finding and the reader's answer are D7, and
FR-010 was rewritten in place for it.

**Purpose**: one picture's own sentences. A run's `spans` are contiguous **in the video's sentence list** (FR-003) and
ordered across runs (FR-004); a run with no spans is the reader's "0" and is a legal value, not an absence.

**Why spans and not sentence indices**: the video's sentences are derived from the content every render
(`videoSentencesFrom(content, position:)`), and their `start`/`end` are **content** offsets (the same pair 019's
walk read as `span=2..17`). A content edit therefore *changes the list*, and an index-keyed assignment would silently
re-point to whatever now sits at that index — exactly what FR-014 forbids. A span-keyed run is **stale** when no
sentence of the current render has that span, and that is the whole of FR-014's detection: no new bookkeeping.

## 2. `PictureAssignment` — the whole of it

| name | type | nullable | source |
|---|---|---|---|
| `contentId` | `String` | no | the content the assignment belongs to (015's `RoleSettings` precedent, `lib/role_store.dart:48`) |
| `runs` | `List<PictureRun>` | no (empty = no assignment) | the reader's runs, in the pictures' display order |

**Persistence**: one record per content beside 015's role settings — the shape FR-010 asks for (survives leaving the
screen and a relaunch), not a new mechanism. **The store's own shape lives here** (this feature has no `contracts/`):
one `shared_preferences` key, `content_picture_assignments`, holding a JSON object keyed by the content's own id —
015's `RoleStore`'s shape (`lib/role_store.dart:132-145`) — whose value is the run list, `{name, spans}` per run in
the pictures' display order, read **tolerantly**: a malformed entry is ignored while its siblings stand, and a content
the reader assigned nothing carries no entry. **An empty `runs` is not an assignment**: it is the no-assignment state,
and the render must then be 012's own (FR-009).

## 3. The resolution — `assignmentsFor`, one answer read twice

```
assignmentsFor(sentences, runs) -> (List<PictureRun> effective, List<PictureRun> stale)
```

| rule | what it does | which requirement |
|---|---|---|
| **match** | a run's spans are matched to this render's `sentences` by span; a run with no match is `stale` | FR-014 |
| **the picture in force** | a run is matched to a picture of the prompt **by the picture's own file name** (`HeldPicture.name`); a run whose file name is in no pick is `stale` — the same answer, and research D7 | FR-010, FR-014 |
| **assigned sentences** | a sentence a matching run names belongs to that picture | FR-006 |
| **the unassigned run between** | a sentence no run names, with an assigned sentence after it, keeps the **previous** picture | FR-006 |
| **the tail fallback** | the sentences after the last assigned one go to the pictures **after** it that have nothing assigned, by 012's own even split (`each = n ~/ paths.length`, remainder to the first) — and with no such picture they stay on the last assigned picture | FR-006 (the reader's refinement, 2026-10-13) |
| **skip** | a picture with nothing after all of that keeps 012's own **undrawn** entry — present, `isDrawn == false`, `frames == 0`, which is what the renderer's own log prints as `-` (D5 as corrected 2026-10-14: the first version said "emits no `ScheduledPicture`", and then the token this row names would have had nothing to print it) | FR-007, D5 |
| **draggable** | a picture holding any sentence — assigned or fallen back to — is not draggable | FR-015 |
| **the read** | nothing here touches the timeline, the utterances or the durations | FR-008, SC-005, D6 |

**Added 2026-10-14 (the implement pass of US5): the page's own claim is *not* `assignmentsFor`'s answer.**
`AssignmentAnswer.effective` carries FR-006's **fallback** as well — the sentences no run names, handed to pictures
by the render's own rule — so it is the answer of the **render**, not a record of what the reader decided. Two things
follow, and both were paid for in the pass that first needed them:

- what the assignment page opens on, and what it writes back when the reader confirms, is `runsThatFit(answer,
  runs)`: the reader's own runs minus the resolver's `stale` ones. Handing the page `effective` showed the reader
  sentences they had never assigned (a picture's chip reading "2 sentences" where "No sentences assigned" was true),
  and confirming it would have stored the fallback as a decision — INV-8 and FR-011 are exactly that.
- the same runs are what the render is handed after a warning (`FR-014`'s "the runs that still fit stand"), for the
  same reason: the fallback belongs to the render, which applies it itself, and a page that passes it along is
  asserting something the reader never said.

## 4. The schedule — 012's own shape, one function deeper

`PictureSchedule` and `ScheduledPicture{path, startFrame, endFrame}` (`lib/video_pictures.dart:126-160`) are unchanged.
The new function replaces only **the split**: `buildPictureSchedule` stays as the no-assignment branch (`:200`), and
the assignment's own function is its sibling — so the painter, the frame maths and `klhu render pictures=… ranges=…`
(`lib/video_renderer.dart:286`) all keep their shape, and SC-003 is a *diff*, not a claim.

## 5. The seam in the reading page (read 2026-10-13)

| what | where | what this feature changes |
|---|---|---|
| the video dialog | `_askVideoFormat` (`lib/reading_view.dart:1880`), returning `({VideoAspect aspect, List<HeldPicture> pictures})?` | its answer gains the assignment (`runs`) |
| the pick's own state | `var held = const <HeldPicture>[];` (`:1891`) with `_pickPictures(held:, onChosen:)` (`:2037`) | untouched; the **new page** is the picker's sibling, and returns its `List<PictureRun>` the same way the picker returns pictures |
| the render entry | `_startRender(aspect, pictures: answer.pictures)` (`:1857`, `:2063`) | gains `runs:` |
| the renderer | `VideoRenderer(... pictures: pictures ...)` (`:2092-2105`) | gains the runs, and hands the schedule builder the choice |

## 6. Invariants

- **INV-1** — a run's `spans` are sentence spans of the content it was made on, in ascending order, and no two runs
  name the same sentence (FR-003/FR-005).
- **INV-2** — with `runs` empty the render's picture ranges equal `buildPictureSchedule`'s, frame for frame (FR-009,
  SC-003).
- **INV-3** — every utterance of the render is unchanged by the assignment, in order and in total duration (SC-005).
- **INV-4** — a picture with no effective sentences has `isDrawn == false` and no frame paints it (FR-007).
- **INV-5** — a picture holding any sentence cannot be dragged; a picture holding none can be dragged anywhere
  without changing another picture's ranges (FR-015, SC-009/SC-010).
- **INV-6** — the fallback only ever feeds pictures **after** the last assigned run (FR-006); a picture between two
  assigned runs is never fed.
- **INV-7** — an assignment is never created by the app: every run with spans in it came from the reader (FR-011).
- **INV-8** — a run never re-points at a picture the reader did not name: a run whose file name is not among the picks
  in force is stale and dropped (with FR-014's warning), and a run whose name is picked again comes back into force
  (FR-010). Two picks with the same name: the **first in the pick order** takes the run (research D7).
