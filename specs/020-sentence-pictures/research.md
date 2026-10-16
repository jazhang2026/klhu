# Research: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · **Read against**: the tree at `8c8de2f` (019's implement pass committed)

This file records what the shipped code actually does, where the spec's own words do not survive contact with it,
the decisions the plan takes on that ground, and what is still unknown. Every claim below is from the source, with
its file and symbol named; nothing here is inferred from the spec's prose.

---

## 1. Grounding corrections — four things the spec's framing does not survive

| the spec's framing | what the tree says | what the plan does about it |
|---|---|---|
| "This feature **adds** the reader's own assignment" (`spec.md`, *What already exists*) | **The app already assigns sentences to pictures — evenly and automatically.** `buildPictureSchedule` (`lib/video_pictures.dart:200`) partitions the plan's sentences across the picked pictures: `each = sentences.length ~/ paths.length` and the remainder goes to the first `extra` pictures (`:208-210`), producing `ScheduledPicture{path, startFrame, endFrame}` (`:126-139`) and `PictureSchedule` (`:152`), with `PictureSchedule.none` for no pictures (`:457`). | This feature is **an override of a split that already exists**, not the introduction of one. `buildPictureSchedule` stays as the no-assignment path *verbatim* — which is exactly what SC-003 measures. The new code decides the runs *before* frames exist, and the frames come from the schedule as they do today. |
| "'display selected pictures from first to last' leaves the order open" (review point 3) | **The reader's order already exists in shipped code**: `movePicture` (`lib/video_pictures.dart:115`) moves a picture within the list, and `mergePicks` (`:104`) appends. The order the renderer walks is the reader's own arranged order. | The question is answered by 012, not by this plan: the assignment shows the pictures **in the reader's arranged order** and offers no reordering of its own. Review point 3 closes itself. |
| "the reader is warned, and told" — as if a message were enough | **The renderer already writes the assignment's own shape into its log**: `klhu render pictures=<n> ranges=<start..end,…>` (`lib/video_renderer.dart:286-287`), one range per drawn picture, `-` for a picture that is not drawn. | SC-001 and SC-005 do not need new instrumentation: the device row reads the app's **own** line and compares it with the reader's assignment. The warning of FR-014 is a *separate* surface (before the render), and the row checks both. |
| "a picture is displayed" (the spec's whole vocabulary) | **The schedule is frame-based, not sentence-based**: `ScheduledPicture.startFrame/endFrame` (`:138-139`), and the painter reads `isDrawn`/the frame range. A picture's *duration* is a consequence of the sentences over it, not a setting of its own. | The assignment's unit is the **sentence** (the reader's words), and the plan translates it into frame ranges at render time — the seam `buildPictureSchedule` already is. FR-007's "skipped" then means: the picture's `ScheduledPicture` stays in the schedule **undrawn** — `isDrawn == false`, `frames == 0`, an empty range at the seam where its place begins — which is exactly the `-` the log already prints for a picture that found no sentence. *(Corrected 2026-10-14 at the implement stage: this row first said "is not emitted at all", and then the `-` it names would have had nothing to print it.)* |

---

## 2. The facts the plan stands on

- **The pictures** are `HeldPicture{name, path}` (`lib/video_pictures.dart:29-36`): picked by the reader, copied into
  the app's own directory by `storePicks` (`:51`), discarded by `discardPictures` (`:85`), and **copied again** into
  each render's working directory by `copyPictures` (`:255`) — the renderer never reads the reader's originals.
- **The renderer's input** is `VideoRenderer(... pictures: List<HeldPicture> ...)` (`lib/video_renderer.dart:151-171`),
  "read once at the pick and held for this render" (`:167`) — so a render in flight cannot be changed by an edit
  during it, which the spec assumes.
- **The sentences** the schedule partitions are the plan's own `plan.sentences` (`:204`), i.e. the video's existing
  sentence list (`VideoSentence`, `lib/video_timeline.dart`) — the same units 016's stepper and 019's rows use.
  Nothing in this feature creates or renumbers a sentence.
- **Per-content storage precedent**: the dialogue feature's `RoleSettings` (`lib/role_store.dart:48`) — per-content,
  keyed by the content's own id, read back on
  open) is the shape the assignment's store should copy — the spec's FR-010 (survives leaving/reopening/relaunch)
  is that shape, not a new mechanism.
- **Where the dialog the sketch draws actually lives (read 2026-10-13, and it corrected this file's first guess)**:
  **`lib/reading_view.dart`** — the three strings the device showed in row 12's log (`Choose pictures`,
  `Video format`, `No pictures chosen`) are in that file, and so is the video action that opens it
  (`grep -rln` over `lib/` answers with `reading_view.dart` and the l10n sources alone). `video_record.dart` holds
  `VideoRecordStore`/`KeptVideo`/`VideoLookup` (the library of *made* videos), and `video_list_screen.dart` /
  `video_playback_screen.dart` are the list and the player — none of them owns the pick. So the assignment pass
  attaches to the reading page's own video dialog: the same place the aspect choice and the pick already are.

---

## 3. Decisions

- **D1 — the assignment is a list of runs, not a set of lists.** `List<PictureRun>{picture: String (the held
  picture's own name), sentences: IntRange?}` in the pictures' own order. The reader's words ("continuous", "in
  order", "0 or more") are exactly a *partition of the sentence list into ordered, contiguous-at-most runs*.
- **D2 — a picture is identified by its held **path**, never by its index.** `movePicture` lets the reader reorder
  after assigning; an index-keyed assignment would silently re-point every run. `storePicks` writes each held picture
  as `pick_<i>_<name>` (`lib/video_pictures.dart:60-63`), so the path is unique inside one pick pass and survives
  reordering. **What this verification corrected**: the first version of this decision keyed on `HeldPicture.name`
  and claimed `_safeName` de-duplicated it — `_safeName` only sanitises `[/\\]` for a filename (`:285-292`) and two
  picks with the same basename would carry the same name. The correlary the plan must carry: **a picture that is no
  longer held** (removed, or the pick re-done) **has its runs dropped by the same rule as a stale run** (D4), with
  the same warning — never silently re-pointed to whatever now sits at that position.
  **[Superseded in one respect on 2026-10-14, at the tasks gate: the key is the picture's own file name, not its
  path — D7. The reasons for rejecting the index, and the rule about a picture that is no longer held, stand as
  written.]**
- **D3 — one derivation, read twice.** The reader's runs become the *same* `PictureSchedule` shape
  `buildPictureSchedule` produces, so the painter, the frame maths and the renderer's log line are untouched: the
  new function replaces only the *split*, and `buildPictureSchedule` remains the no-assignment branch (SC-003).
- **D4 — a stale run is dropped, and the warning is a first-class surface.** FR-014 needs the offending sentences
  *named* before the render: the resolver answers `(schedule, stale runs)` so both the warning and the render read
  one answer, and the assignment page can be opened on the picture it names (the reader's own refinement).
- **D5 — "skipped" is the absence of a range**, not a zero-length frame range: a picture with no sentences emits no
  `ScheduledPicture`, which is the state the renderer's own log already prints as `-`.
- **D6 — the assignment does not touch the read.** The video's audio, its sentence order and its total duration come
  from the timeline (`lib/video_timeline.dart`), which this feature does not hand anything new (SC-005).
- **D7 — the run's key is the picture's own file name (2026-10-14; it replaces D2's key and nothing else of D2).**
  D2 keyed a run by the held picture's **path**, and the tree disproves that key: a path is `_pictureDirSeq`-scoped
  (`<tmp>/picks_<n>/pick_<i>_<name>`, `storePicks`, `lib/video_pictures.dart`) and the whole directory is deleted
  when the prompt ends (`discardPictures`, `lib/reading_view.dart:1947`), so a stored run could not match a later
  prompt's pictures at all — while a **relaunch** re-created `picks_0` and matched them again by the accident of
  that sequence number. The value that does survive is `HeldPicture.name` — the reader's own basename, which
  `storePicks` keeps beside the sanitised copy's name — and the reader chose it at the tasks gate (option A,
  2026-10-14). What D2 was protecting stays protected: a picture that is not among the picks in force leaves its
  runs **stale** (D4), never re-pointed; and the collision D2 named (two files with the same basename) now has a
  rule instead of an avoidance — **the first pick carrying that name takes the run**, and the pass shows which
  picture each run is attached to, so a mis-attachment is visible and un-assignable.

---

## 4. Open questions, and who answers them

1. **How the assignment page's own list is edited** (tap a sentence to add it to a run? a range slider per picture?
   drag?) — the plan's, with the reader's pick between the cheap shapes; the sketch fixes only that the page exists
   behind one line in the dialog.
2. **The warning's own wording** — the plan's; it must name the sentences, per FR-014's check.
3. **How the dialog holds its state today, and therefore where the assignment's `List<PictureRun>` lives between
   the dialog and the renderer.** Answered in part by the reading above (the dialog is `reading_view.dart`'s, and
   the pick is that page's own state); what the plan must still read is *that* dialog's state field and the call
   that builds the `VideoRenderer` (the one that already passes `pictures:`) — a smaller read than this file first
   thought, and it must happen before the file tree is written.
4. **What the reader sees for an unassigned *sentence* on the assignment page** (it is drawn as belonging to the
   picture before it, FR-006) — a presentation question the plan settles with the page's shape.
