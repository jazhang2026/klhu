# Quickstart: the assignment pass's pictures, and the controls on them

## Prerequisites

`export PATH=$HOME/development/flutter/bin:$PATH`, the emulator `emulator-5554` (AVD `klhu`, API 36) up, package
`com.example.klhu`, and the line's own measured baseline — **every row below is read against it**:

```
flutter analyze                      → No issues found! (ran in 1.2s)
flutter test --concurrency=2         → 01:17 +782: All tests passed!
message keys per ARB (four files)    → 120 each
test/*.dart files in the tree        → 55
```

Measured 2026-10-15 08:40–08:45 PDT on the tree of 2026-10-14, the same build the 020 walk drove. Re-take it with
the same two commands before reading any row: a row that fails while the baseline itself has moved is a row about
the baseline, not about this feature.

## Automated checks

```
flutter analyze                                   → clean
flutter test --concurrency=2                      → the baseline's count + this feature's own cases, 0 failing
flutter test test/picture_assignment_switch_test.dart      → the switch and the boundary
flutter test test/reading_view_picture_pass_test.dart      → the surface
flutter gen-l10n && flutter test test/l10n_keys_test.dart  → the regenerated Dart is the tree's, parity green
python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_artifact_refs.py specs/021-picture-pass
```

## Scenarios

### 1. **[unit]** a sentence is never in two runs — the reader's own report

The boundary the reader hit: white holds sentences 1-4, black 5-7, tap white's **last** sentence with black
selected. The rules must refuse it (order), and the record must be unchanged.

**Expected**: `refusedAdd` answers `notInOrder`; the two runs are what they were; a switch proposed for the same
sentence is legal only because it removes it from white first, and after it white holds 1-3 and black 4-7.
**Evidence**: `test/picture_assignment_switch_test.dart` — the case named for the reader's report.
Proves FR-013, SC-010.

### 2. **[unit]** the switch's own legality

An end of a holder's run may switch where the target ends continuous and in order; a **middle** sentence may not
(020's own middle-of-run words, no confirmation); a switch that would leave the target's run gapped or out of order
is refused with that rule's words and no confirmation.
**Evidence**: `test/picture_assignment_switch_test.dart`, one case per shape.
Proves FR-011, FR-015.

### 3. **[unit]** what decides the move and the delete

A picture the reader assigned nothing — **whether or not the render's fallback would feed it** — offers both
controls; a picture holding one of the reader's sentences offers neither.
**Evidence**: `test/reading_view_picture_pass_test.dart`, two cases around one fixture (three pictures, the first
assigned four sentences, so the tail would feed the other two).
Proves FR-005, SC-004.

### 4. **[unit]** the badge's number is the reader's own record

A picture's count is its own run's sentences resolved against this render's list: assigning a sentence changes it;
the fallback's sentences never appear in it; a stale span is not counted.
**Evidence**: `test/reading_view_picture_pass_test.dart` and `test/picture_assignment_store_test.dart` (020's own,
extended only if the store's shape moves — it does not).
Proves FR-001, FR-019, SC-002.

### 5. **[unit]** the cell's label and what is painted

A cell's semantic label is the picture's own file name; no painted string on the page is a file name; the app's own
count words appear under the large picture.
**Evidence**: `test/reading_view_picture_pass_test.dart` (semantics + the painted labels' own list).
Proves FR-002, FR-019.

### 6. **[unit]** a confirmation cancels to nothing

Cancelling the delete, and cancelling the switch, each leave the runs byte-identical and a render's own `ranges=`
line identical.
**Evidence**: `test/reading_view_picture_pass_test.dart`, the two confirmation groups.
Proves FR-008, FR-012, INV-5.

### 7. **[unit]** the shipped pass cases, re-cut

020's own cases for the pass (its chips' labels, its refusals, its drag) are re-cut where this feature moved the
surface — never deleted: the chip cases read the thumbnail and the badge, the refusal cases stay, and the drag's
cases become the buttons'.
**Evidence**: `test/reading_view_video_assignment_test.dart` (re-cut, its other groups untouched).
Proves FR-006, FR-015.

### 8. **[device]** the strip: the pictures and their numbers

Three pictures chosen, nothing assigned: each cell shows the picture itself with `0` at its top right; no painted
label carries a file name; the dump's cell labels carry the pictures' own names (the semantic label).
**Expected**: a still, plus the dump's own labels.
**Evidence**: `python3 specs/021-picture-pass/scripts/klhu_walk_pass.py 8`; still `/tmp/021_row8_strip.png`.
Proves FR-001, FR-002, SC-001.

### 9. **[device]** one tap: select, list, and the number changes on the same tap

Tap the middle picture: it is highlighted, the sentence list below is that picture's; tap one sentence: it is
given to that picture and the badge on that cell reads `1` — read off two dumps taken around the tap.
**Evidence**: `…klhu_walk_pass.py 9`; stills `_before.png`, `_after.png`.
Proves FR-003, FR-006, SC-002.

### 10. **[device]** a hold: the large picture, the list hidden, and `Close`

Hold the middle picture: the picture is large below the strip, the sentence list is gone, and the app's own count
words are under it; `Close` brings the list back with the same picture selected.
**Evidence**: `…klhu_walk_pass.py 10`; stills `_large.png`, `_closed.png`.
Proves FR-004, FR-019, SC-003.

### 11. **[device]** the controls' own gating, on the pictures the fallback would feed

With three pictures and only the first assigned four sentences: the two the reader gave nothing offer
`Move left` / `Move right` and `Delete this picture` in their large picture; the first offers neither (a still of
each).
**Evidence**: `…klhu_walk_pass.py 11`; stills `_free.png`, `_holding.png`.
Proves FR-005, SC-004.

### 12. **[device]** the move shows at once, and the render follows it

Move the last picture left: the strip's own order changes at once (a still), and a render started now prints the
reader's runs in the new order — the ranges differ exactly where the move put them, no other range moves.
**Evidence**: `…klhu_walk_pass.py 12`; the app's own `klhu render pictures=… ranges=…` line, and stills around the
move.
Proves FR-006, SC-005.

### 13. **[device]** the delete asks, and cancelling changes nothing

Delete a picture that holds nothing: the confirmation appears and names it **by the picture**; cancelling leaves a
render's own line identical to the one taken before (both lines quoted); confirming names one picture fewer.
**Evidence**: `…klhu_walk_pass.py 13`; stills `_confirm.png`, `_after.png`; the two render lines.
Proves FR-008, FR-009, SC-006.

### 14. **[device]** the selected cell sits in the middle of the bar

Select the first cell, then the last, then a middle one: the selected cell's own box centre is within the strip's
middle (read off the dump's own bounds, with the numbers quoted).
**Evidence**: `…klhu_walk_pass.py 14`; the bounds, and stills per selection.
Proves FR-007, SC-007.

### 15. **[device]** the dialog's own surface, and the switch's confirmation

The picture-chosen dialog's cells behave the same (hold → large picture, `Close`, the same controls under the same
rule); in the pass, tapping a sentence another picture holds shows a confirmation with **both pictures** — and
cancelling it leaves the record and the render's line identical, confirming it leaves the holder with one sentence
fewer and moves the render's own boundary by exactly that sentence.
**Evidence**: `…klhu_walk_pass.py 15`; stills `_dialog_large.png`, `_switch_confirm.png`; the render lines.
Proves FR-010, FR-011, FR-014, SC-008, SC-009.

### 16. **[structural]** the tree, and the shipped rules that did not move

`flutter analyze` clean; the suite's count against the baseline decomposed by file (the two new test files and the
re-cut one); the four ARBs at the new count with `flutter gen-l10n` reproducing the tree's Dart and
`test/l10n_keys_test.dart` green; `git diff lib/video_pictures.dart lib/video_timeline.dart` empty (the split, the
timeline and the painter are untouched); and 020's own walk rows 6-11 and 16 re-walked with their evidence re-taken
(the parser still matches, because the file name is the cell's semantic label).
**Evidence**: the commands' own output, quoted; the re-walked rows' PASS lines.
Proves FR-015, FR-017, FR-018, SC-011.

### 17. **[unit]** the draft holds the reader's own runs, and nothing else

With the reader's runs in force and the tail falling back to a picture nobody assigned, the pass's own answer
(`AssignmentDraft`) carries **only** the runs the reader made: no fallback sentence appears in any run, the order
is the reader's own, and a picture whose run is empty is simply empty.
**Evidence**: `test/reading_view_picture_pass_test.dart`, the draft's own case, read against the resolver's own
answer for the same fixture (`assignmentsFor` carries the fallback; the draft must not).
Proves FR-016, INV-8.

## Troubleshooting

- **A cell shows no picture**: the pick's copy lives inside the prompt's directory and only while the dialog holds
  it (012's own rule). A cell opened after the prompt closed cannot decode — the pass is only reachable from the
  dialog, and every row starts by opening it.
- **`uiautomator dump` refuses while a window animates**: 020's own finding and its driver's answer — delete the
  device's XML first (`fresh_dump`) and poll to a deadline (`dump_until`); a refused dump then reads as a missing
  file instead of the previous screen.
- **The centring row reads a stale box**: the dump's bounds are taken after the scroll settles; poll the cell's own
  box until two reads agree before measuring.
- **A still at the wrong moment**: `screencap` is the framebuffer, so take it after the state is asked for (the
  dump) rather than in the same breath.

### Row 18 — [device] the assignment line with nothing picked (the reader's own report, 2026-10-15) — driver key `19`

**Steps**: choose three pictures, open the pass, give one sentence to the first picture, `Done`, then `Cancel` the
prompt. Open it again (`Video`) without picking anything.

**Expected**: the prompt is open with nothing picked, and the assignment line reads the app's own "No sentences
assigned". **Correction 2026-10-15, the reader's own decision**: the cancelled visit takes the record **with it** —
picking the same three files again brings nothing back, and the pass's own cells all read 0. (The line's own half —
nothing is claimed while no picture is in force — was the first fix; the record's own half is the second.)

**Evidence**: `klhu_walk_pass.py 19` — the app's own labels either side of `Cancel`, and a still.

Proves FR-019, FR-001.

### Row 19 — [device] a picture the reader gave nothing, dropped on a picture that holds one (the reader's own report, 2026-10-16) — driver key `20`

**Steps**: choose three pictures, open the pass, give **one** sentence to the first picture, `Done` (back in the
prompt: the cells read `1`, `0`, `0`), then hold the second picture — the one holding nothing — and drop it on the
first picture's own cell.

**Expected**: the order of the cells follows the drop (the held picture takes the cell the sentence-holder stood in,
and the sentence-holder and everything after it shift by one), **and the sentence stays with its own picture** — the
first cell still reads `1` at its new place, and no count moves. A hold on the sentence-holder itself moves nothing
(021's FR-005: it is the destination, never the thing that travels).

**Evidence**: `klhu_walk_pass.py 20` — the cells' own labels before and after (`{'w020_white.png': '1', …}`), the
order read off the device's own bounds, and two stills. On the build of 2026-10-15 the same row read **8/9**: the drop
did nothing (`order: ['w020_white.png', 'w020_black.png', 'w020_red.png']`), which is the reader's own report; on the
fixed build, **9/9**.

Proves FR-005, FR-010. (The drop destination half is 012's own requirement — "another picture's cell" — and this
row is what re-proves it under the assignment rule.)
