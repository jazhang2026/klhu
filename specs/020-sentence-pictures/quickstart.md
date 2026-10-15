# Quickstart: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · the rows that decide whether the feature is done, each with the evidence it
leaves behind. Kinds: **[unit]** a Dart test, **[device]** a row the driver walks on the emulator, **[structural]**
a property of the tree.

## The rows

### 1. **[unit]** the run's own shape — `test/picture_assignment_test.dart` (new)

A `PictureRun`'s spans are sentence spans of the content, ascending, and no two runs name a sentence; an empty
`runs` list is the no-assignment state and not an assignment of zero-length runs. A picture's identity is its own
file name (`HeldPicture.name`, research D7, 2026-10-14): a run whose name is not among the picks in force is stale
and never silently re-pointed, and it comes back into force when that name is picked again.

Proves FR-003, FR-005, FR-011, INV-1, INV-7, INV-8, research D1/D2/D7.

### 2. **[unit]** `assignmentsFor` — the six shapes in one table

The assigned run; a sentence between two runs (the previous picture); the tail with pictures after it (012's even
split); the tail with none (the last assigned picture); a picture between two runs left with nothing (skipped); and
the whole thing with `runs` empty (012's own split, frame for frame).

Proves FR-006, FR-007, FR-009, INV-6, and the reader's refinement of 2026-10-13.

### 3. **[unit]** the schedule seam — `test/video_pictures_test.dart` (extended)

With an assignment the ranges follow the runs; with none, `buildPictureSchedule`'s own output is returned unchanged,
compared as ranges and frames (not as a shape).

Proves FR-009, SC-003, INV-2, research D3.

### 4. **[unit]** a stale run — `test/picture_assignment_test.dart`

A content edit that leaves a run's spans matching no sentence yields that run as `stale` and drops it from the
effective runs; the runs that still match stand, and their order is checked against the new sentence list.

Proves FR-014, SC-008's unit half.

### 5. **[unit]** who may be dragged — the predicate, alone

With the runs of row 2 in force: the pictures holding sentences (assigned or fallen back to) are not movable, the
ones holding none are, and moving one leaves every other picture's ranges identical.

Proves FR-015, SC-009, SC-010, INV-5.

### 6. **[device]** the assignment line, the page, and the render's own ranges

Seed a ten-sentence content with three pictures, open the video dialog, assign 4/3/3 through the page, render: the
renderer's own `klhu render pictures=3 ranges=…` line names three ranges matching the reader's runs in order, and
every sentence's frame paints its own picture.

Proves FR-001, FR-002, FR-006, SC-001.

### 7. **[device]** the two refusals

Try to add a sentence that is not adjacent to its picture's run; try to give a later picture a sentence that starts
before an earlier picture's last one: each is refused with its own reason and the assignment in force is unchanged
(compared against the render's own line before and after).

Proves FR-003, FR-004, FR-012, SC-002.

### 8. **[device]** un-assigning, at the ends and in the middle

An end sentence of a run is removed and the run stays continuous; a middle one is refused with that reason; after
the ends are removed the picture holds nothing and becomes draggable.

Proves FR-016, SC-010.

### 9. **[device]** the drag, and the order the render walks

Drag a picture with nothing assigned to the front: the render's `pictures=… ranges=…` line shows the new order and
no other range moved. Try to drag a picture holding sentences: refused, order unchanged.

Proves FR-015, SC-009.

### 10. **[device]** the skip, and the tail's fallback

Leave the middle picture with nothing (between two assigned ones): no frame paints it and the render's own line
prints its range as `-`. Leave the tail unassigned with a picture after it: that picture takes the tail, split the
way 012 splits.

Proves FR-006, FR-007, SC-004.

### 11. **[device]** the stale warning, before the render

Assign, then edit the content so a run no longer fits; start a render: the warning appears **before** the render's
own line, names the sentences involved, and tapping it opens the assignment page with that picture in view.

Proves FR-014, SC-008.

### 12. **[device]** no assignment is 012's video, frame for frame

With pictures chosen and nothing assigned, render what 012's own row 49 renders — the shipped pre-set, each picture
drawn over its own sentence — and compare against **that row's own figures, named here so this row cannot quote a
number nobody wrote** (corrected 2026-10-14: it said "that row's recorded figures" and no such figures exist for
the pictures case in one place): 012's row **31** (the same pre-set, no pictures chosen) records **818 frames** and
an ffprobe **27.39 s**; its row **49** (nine pictures, eight sentences) records **eight ranges, one per sentence,
each carrying a different one of the eight, with the ninth chosen picture in no range at all**. This row's render
agrees with those figures where it can be compared (the ranges' shape, the frames and the duration — pictures do not
add frames) and needs no `lib/` change to do it.

Proves FR-009, SC-003, research D3.

### 13. **[device]** the audio does not move

The same content with and without an assignment: the same utterances (`klhu speak` lines), in the same order, and
the same total duration in the render's own report.

Proves FR-008, SC-005.

### 14. **[structural]** the tree

`flutter analyze` clean; the suite count read against the pre-feature baseline; **the four ARBs carry this feature's
own keys** — 110 → **120** (corrected 2026-10-14 as the pass implemented it: ten keys, because the reader's
`Done` is 015's own word and is reused rather than minted again; T010's tick carries the measured per-file
counts), in each of the four files, with `flutter gen-l10n` re-run,
`test/l10n_keys_test.dart` green and the regenerated Dart files in the diff (corrected 2026-10-14: this row read
"the four ARBs unchanged", which was left over from a draft that added no interface text, while the plan's own
structural rule has this feature's pass, its two refusals and its warning as new text); and
`buildPictureSchedule`'s own body unchanged (`git diff lib/video_pictures.dart` shows the new function beside it,
never inside it).

Proves FR-009's second half, SC-003, research D3.

### 15. **[unit]** the assignment's own record — `test/picture_assignment_store_test.dart` (new)

One key per content: the store answers the runs the reader made for **this** content and nothing of another's; a
malformed entry is ignored while its siblings stand, so one bad byte never costs the reader a second content's
assignment; a content nothing was assigned on carries no entry, and clearing the runs leaves none behind.

Proves FR-010's store half, FR-013's "a stored setting", SC-006, `data-model.md` §2.

### 16. **[device]** the assignment outlives the prompt, and re-attaches by name

Assign runs, render, leave the screen and relaunch, then pick **the same files** again: the pass shows those runs
back in force on the pictures carrying those names, with nothing re-assigned by hand. Then change one run and render
again: the second render's `pictures=… ranges=…` line differs exactly where the assignment differs, and the **first
file's own hash is unchanged** (012's own `library_state`).

Proves FR-010, FR-013, SC-006, SC-007, research D7.

### 17. **[unit]** a highlighted sentence does not cut the video — `test/reading_view_video_assignment_test.dart`

Tap the content's **last** sentence on the page (the reader's own gesture: the page's position is in force and the
sentence is painted), open the video dialog and render: the renderer's own line holds **every** sentence of the
content and its first slot opens on the content's own first sentence.

Proves FR-017, SC-011, `plan.md`'s Amendment 2.

### 18. **[device]** the same on the emulator, off the app's own line

With a sentence highlighted on the device, render and read the app's own `klhu render pictures=… ranges=…
sentences=…` line and its `klhu render slot=0/N … span=…` line: `sentences=` is the content's own count and slot
0's `span=` is the content's first sentence — and with the same content and nothing highlighted, the two renders'
lines are identical.

Proves FR-017, SC-011.

## What the rows do not cover

- **The assignment page's own visual design** inside (A): the rows check behaviour (what is assigned, what is
  refused, what the render walks) and take one screenshot per state for a reader to look at, as 019's row 10 did.
- **The warning's wording**: the rows check *when* it comes and *what it names*, not its prose.
- **Where the assignment's record is stored**: the store is 015's own shape (`lib/role_store.dart`) and row 15
  checks its contract; which file the platform puts those bytes in is not a row.
