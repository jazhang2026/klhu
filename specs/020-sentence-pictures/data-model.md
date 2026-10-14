# Data Model: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · **Ground**: `research.md` (the four grounding corrections and D1-D6)

---

## 1. `PictureRun` — what the reader decided, per picture

| name | type | nullable | source |
|---|---|---|---|
| `path` | `String` | no | the held picture's own path (`HeldPicture.path`, `pick_<i>_<name>`) — research D2, and **not** its index |
| `spans` | `List<(int, int)>` | no (empty = nothing assigned) | the sentences this picture carries, as **content spans**, in order |

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
screen and a relaunch), not a new mechanism. **An empty `runs` is not an assignment**: it is the no-assignment state,
and the render must then be 012's own (FR-009).

## 3. The resolution — `assignmentsFor`, one answer read twice

```
assignmentsFor(sentences, runs) -> (List<PictureRun> effective, List<PictureRun> stale)
```

| rule | what it does | which requirement |
|---|---|---|
| **match** | a run's spans are matched to this render's `sentences` by span; a run with no match is `stale` | FR-014 |
| **assigned sentences** | a sentence a matching run names belongs to that picture | FR-006 |
| **the unassigned run between** | a sentence no run names, with an assigned sentence after it, keeps the **previous** picture | FR-006 |
| **the tail fallback** | the sentences after the last assigned one go to the pictures **after** it that have nothing assigned, by 012's own even split (`each = n ~/ paths.length`, remainder to the first) — and with no such picture they stay on the last assigned picture | FR-006 (the reader's refinement, 2026-10-13) |
| **skip** | a picture with nothing after all of that emits no `ScheduledPicture` — the renderer's own log already prints it as `-` | FR-007, D5 |
| **draggable** | a picture holding any sentence — assigned or fallen back to — is not draggable | FR-015 |
| **the read** | nothing here touches the timeline, the utterances or the durations | FR-008, SC-005, D6 |

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
