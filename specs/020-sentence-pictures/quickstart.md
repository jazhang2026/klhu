# Quickstart: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · the rows that decide whether the feature is done, each with the evidence it
leaves behind. Kinds: **[unit]** a Dart test, **[device]** a row the driver walks on the emulator, **[structural]**
a property of the tree.

## The rows

### 1. **[unit]** the run's own shape — `test/picture_assignment_test.dart` (new)

A `PictureRun`'s spans are sentence spans of the content, ascending, and no two runs name a sentence; an empty
`runs` list is the no-assignment state and not an assignment of zero-length runs. A picture's identity is its held
path, and a run whose path is not held any more is not silently re-pointed.

**Proves**: FR-003, FR-005, FR-011, INV-1, INV-7, research D1/D2.

### 2. **[unit]** `assignmentsFor` — the six shapes in one table

The assigned run; a sentence between two runs (the previous picture); the tail with pictures after it (012's even
split); the tail with none (the last assigned picture); a picture between two runs left with nothing (skipped); and
the whole thing with `runs` empty (012's own split, frame for frame).

**Proves**: FR-006, FR-007, FR-009, INV-6, and the reader's refinement of 2026-10-13.

### 3. **[unit]** the schedule seam — `test/video_pictures_test.dart` (extended)

With an assignment the ranges follow the runs; with none, `buildPictureSchedule`'s own output is returned unchanged,
compared as ranges and frames (not as a shape).

**Proves**: FR-009, SC-003, INV-2, research D3.

### 4. **[unit]** a stale run — `test/picture_assignment_test.dart`

A content edit that leaves a run's spans matching no sentence yields that run as `stale` and drops it from the
effective runs; the runs that still match stand, and their order is checked against the new sentence list.

**Proves**: FR-014, SC-008's unit half.

### 5. **[unit]** who may be dragged — the predicate, alone

With the runs of row 2 in force: the pictures holding sentences (assigned or fallen back to) are not movable, the
ones holding none are, and moving one leaves every other picture's ranges identical.

**Proves**: FR-015, SC-009, SC-010, INV-5.

### 6. **[device]** the assignment line, the page, and the render's own ranges

Seed a ten-sentence content with three pictures, open the video dialog, assign 4/3/3 through the page, render: the
renderer's own `klhu render pictures=3 ranges=…` line names three ranges matching the reader's runs in order, and
every sentence's frame paints its own picture.

**Proves**: FR-001, FR-002, FR-006, SC-001.

### 7. **[device]** the two refusals

Try to add a sentence that is not adjacent to its picture's run; try to give a later picture a sentence that starts
before an earlier picture's last one: each is refused with its own reason and the assignment in force is unchanged
(compared against the render's own line before and after).

**Proves**: FR-003, FR-004, FR-012, SC-002.

### 8. **[device]** un-assigning, at the ends and in the middle

An end sentence of a run is removed and the run stays continuous; a middle one is refused with that reason; after
the ends are removed the picture holds nothing and becomes draggable.

**Proves**: FR-016, SC-010.

### 9. **[device]** the drag, and the order the render walks

Drag a picture with nothing assigned to the front: the render's `pictures=… ranges=…` line shows the new order and
no other range moved. Try to drag a picture holding sentences: refused, order unchanged.

**Proves**: FR-015, SC-009.

### 10. **[device]** the skip, and the tail's fallback

Leave the middle picture with nothing (between two assigned ones): no frame paints it and the render's own line
prints its range as `-`. Leave the tail unassigned with a picture after it: that picture takes the tail, split the
way 012 splits.

**Proves**: FR-006, FR-007, SC-004.

### 11. **[device]** the stale warning, before the render

Assign, then edit the content so a run no longer fits; start a render: the warning appears **before** the render's
own line, names the sentences involved, and tapping it opens the assignment page with that picture in view.

**Proves**: FR-014, SC-008.

### 12. **[device]** no assignment is 012's video, frame for frame

With pictures chosen and nothing assigned, render the same content 012's own device row renders, and compare: the
frame counts, the durations and the `pictures=… ranges=…` line agree with that row's recorded figures.

**Proves**: FR-009, SC-003.

### 13. **[device]** the audio does not move

The same content with and without an assignment: the same utterances (`klhu speak` lines), in the same order, and
the same total duration in the render's own report.

**Proves**: FR-008, SC-005.

### 14. **[structural]** the tree

`flutter analyze` clean; the suite count read against the pre-feature baseline; the four ARBs unchanged (`git diff
--stat lib/l10n/` empty); and `buildPictureSchedule`'s own body unchanged (`git diff lib/video_pictures.dart` shows
the new function beside it, never inside it).

**Proves**: FR-009's second half, SC-003, research D3.

## What the rows do not cover

- **The assignment page's own visual design** inside (A): the rows check behaviour (what is assigned, what is
  refused, what the render walks) and take one screenshot per state for a reader to look at, as 019's row 10 did.
- **The warning's wording**: the rows check *when* it comes and *what it names*, not its prose.
- **Where the assignment's record is stored**: the store is 015's own shape (`lib/role_store.dart`); the rows check
  that it survives a relaunch, not where the bytes sit.
