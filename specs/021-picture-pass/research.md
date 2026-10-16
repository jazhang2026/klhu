# Research: the assignment pass's pictures, and the controls on them

## Grounding corrections

Five claims, each read against the tree rather than remembered — the first two are the ones the reader's own
report rests on.

1. **"Un-assigned" is not what the tree tests.** The spec's FR-005 (and the reader's words, "If no sentences
   assigned to this picture") mean *the reader assigned it nothing*. The tree asks a different question:
   `mayDrag` (`lib/picture_assignment.dart:186-189`) reads `AssignmentAnswer.effective`, which **carries FR-006's
   tail fallback** — the sentences the render hands to a picture nobody assigned. So a reader who assigned
   nothing can be refused the move with *"This picture holds sentences; un-assign them before moving it."*, which
   is exactly the message they reported. The correction: the question the surface asks is the reader's own runs.
2. **The boundary is strict, and that is the reported defect.** `refusedAdd` tests its two order boundaries with
   `<` and `>` (`lib/picture_assignment.dart:149-151`). White holding sentences 1-4 and black holding 5-7: a tap
   on white's **last** sentence with black selected passes both (`4 < 4` is false; the continuity test measures
   against black's own first sentence, which the tapped one is adjacent to), so `_tap` writes the span into **both**
   runs (`lib/picture_assignment_screen.dart:112-149`). `assignmentsFor` then resolves the shared sentence to the
   **later** picture (`lib/picture_assignment.dart:291-296`), so the counts stop matching the runs — 020's own
   FR-005, broken silently, with no walked row covering the shape (row 7 refuses a far sentence and one before an
   earlier run; row 9's subject is the drag).
3. **020's own walk reads the pass through the file name.** `chip_line`
   (`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py`) matches a cell whose label is
   `<name>\n<count>`, and rows 6, 7, 8, 9, 10, 11 and 16 use it. FR-002 removes the **painted** name; the reader's
   answer keeps it as the cell's **semantic label**, so those rows keep matching and their evidence is re-taken
   rather than re-cut.
4. **012's reorder is unconditional.** The dialog's own chosen pictures can all be moved (its own reorder rule),
   with no notion of an assignment. FR-010 gives that surface the same gating as the pass, so 012's rule narrows
   to "a picture holding nothing" — a supersession to point at, not to edit.
5. **The holds-sentences refusal loses its surface on the pass.** `AssignmentRefusal.holdsSentences` is reachable
   today only through the pass's own hold (`lib/picture_assignment_screen.dart:250`); with the controls' visibility
   doing that work (FR-005), the string has no surface there. Where it remains reachable is the plan's to record —
   and this plan's answer is: **nowhere**, so the key stays (keys are never deleted) and the string is named in
   `spec.md`'s FR-015 as having no surface, rather than left as a string nobody can reach.

## Verified environment facts

| Fact | Value | Evidence |
|---|---|---|
| Analyzer | clean, `No issues found! (ran in 1.2s)` | `flutter analyze`, 2026-10-15 08:40 PDT |
| Suite | **782 cases, 0 failing**, 55 test files | `flutter test --concurrency=2` → `01:17 +782: All tests passed!` |
| Message keys | **120** in each of the four ARBs, parity both ways | measured 2026-10-15; `test/l10n_keys_test.dart` green |
| Toolchain | Flutter **3.47.5** stable, revision `6a19cca564` (2026-09-17) | `flutter --version` |
| Device | `emulator-5554`, package `com.example.klhu`, **API 36** | `adb -s emulator-5554 shell getprop ro.build.version.sdk` |
| The build the walk drives | APK built 2026-10-15 08:10:52, installed 08:10:54; no source file newer | `ls -l build/app/outputs/flutter-apk/app-debug.apk`, `dumpsys package` |
| The thumbnail decode bound this feature reuses | `Image.file(…, cacheWidth: 144)` in `ChosenThumbnail` | `lib/reading_view.dart:3027-3030` |
| The pass's own file today | 317 lines, one class, its chip built in `_chip` | `wc -l lib/picture_assignment_screen.dart`, `:220-256` |
| The rules' own file today | 347 lines: `refusedAdd` `:134-161`, `refusedRemove` `:168-180`, `mayDrag` `:186-189`, `assignmentsFor` `:259-347` | read on this tree |

## D1. The cell is the picture, with a number at its top right

- **Decision**: a cell is the picture's own thumbnail (bounded decode, D1 in `plan.md`) with a badge carrying
  **the number** at its top right; the file name is **the cell's semantic label**, never painted; the app's words
  for the count are painted under the large picture (FR-001, FR-002, FR-019).
- **Rationale**: the reader's own reason is "so I can better understand the picture and to match sentences" —
  a file name cannot be matched to a sentence. The semantic label is what keeps the name available to a screen
  reader and to 020's own walk (correction 3), so the change costs no receipt.
- **Alternatives considered**: the name painted beside the thumbnail (refused by the reader); no name anywhere
  (re-cuts 020's rows for no reader-visible gain — the reader's own answer was (a)); the words on the cell
  (refused: the text they asked to be rid of).

## D2. One tap selects; a hold opens the picture large below the strip

- **Decision**: a tap selects a cell (highlighted) and the sentence list below becomes that picture's; a **hold**
  shows the held picture large **below the strip** with the list hidden, a `Close` control, and the app's own
  count words under it; `Close` returns to the list with the same picture selected (FR-003, FR-004, FR-019).
- **Rationale**: the reader's own words ("one tap select the thumnail to assign sentences … sentence list is
  showing below"; "tap+hold show large picture below … use close button to close the large picture and show the
  sentences list"). Holding is the same gesture 020 taught for the drag, so nothing new is learned to open it.
- **Alternatives considered**: a full-screen route (off the strip the reader is watching); a modal overlay (covers
  the strip); one tap for both (the reader separated the two on purpose).

## D3. What the controls are, and what decides them

- **Decision**: in the large picture only, and only when **the reader's own run for that picture is empty**, the
  pass offers `Move left` / `Move right` and `Delete this picture` (FR-005). The drag is gone from the pass.
- **Rationale**: the reader's words are "If no sentences assigned to this picture, show move buttons and delete
  button", and their report is what the fallback-based refusal does to them. Buttons also remove the gesture
  question entirely (their two attempts: a refusal and a scroll).
- **Alternatives considered**: keep the drag (the platform's scroll axis wins it — their evidence); read the
  fallback (the shipped rule, and the thing their report falsifies); show the controls always and refuse on the
  tap (a control that refuses on tap is what the fourth refusal string is, and it now has no surface).

## D4. The switch, and the boundary the reader reported

- **Decision**: a tap on a sentence another picture holds proposes a **switch** where it is legal (an end of its
  holder's run, and the taking picture ends continuous and in order), the confirmation shows **both pictures**, and
  the switch applies as a repair — the sentence is removed from its holder before it is given to the target
  (FR-011, FR-012, FR-013). Independently, both order-boundary comparisons in `refusedAdd` become inclusive
  (`lib/picture_assignment.dart:149-151`), so no path can put one sentence in two runs.
- **Rationale**: the reader's own reversal of the disabled-checkbox answer, and their defect report is this exact
  tap. A repair-shaped edit keeps 020's FR-005 true *by construction* rather than by a guard that a later path can
  forget.
- **Alternatives considered**: refuse and require a take-back first (what ships, and what the reader reported);
  apply without confirming (that is the defect); let the switch bypass continuity and order (a run with a gap is
  not walkable — `spec.md`'s Clarifications 4).

## D5. The delete, and the two screens

- **Decision**: the delete asks first in the app's own destructive-confirm shape, and confirming drops the picture
  from the pass's answer — the dialog's own list, its order and its store entry follow, because the pass's answer
  **is** what the dialog applies (FR-008, FR-009). The dialog's own picture surface gets the same cells, the same
  large picture and the same controls (FR-010), narrowing its reorder.
- **Rationale**: one write path for one record (020's own `AssignmentDraft`), and one surface implementation for
  two screens. The reader's own words: "pass 内删除即时生效. stay in Assign page" and "the pictures chosen dialog
  page should have same UI and function".
- **Alternatives considered**: a delete callback into the dialog (a second write path); marking and applying on
  `Done` (not the reader's words, though the confirmation makes either safe); leaving the dialog's surface alone
  (the drift this feature removes).

## D6. The strip keeps the selected picture in the middle

- **Decision**: the selected cell is centred with `Scrollable.ensureVisible(alignment: 0.5)` over a per-cell
  `GlobalKey`, applied when the selection changes and after a move or a delete (FR-007).
- **Rationale**: the reader's own words ("the selected thumnail auto scroll to the middle of thumnail bar"), and
  the platform's own API is what knows where the child sits.
- **Alternatives considered**: hand-computed offsets (re-derives the layout, and the first spacing change moves
  the centre); no centring (a cell off screen is the state the reader asked to avoid).

## D7. The walk's own shape

- **Decision**: the device walk is one new driver, `specs/021-picture-pass/scripts/klhu_walk_pass.py`, importing
  020's own for the device mechanics and dispatching one row per device scenario; the rules' own rows are unit
  tests, and the shipped pass test file is **re-cut, never deleted**, where the surface moved.
- **Rationale**: 020's precedent (one driver per feature, rows as quickstart numbers), and the shipped cases are
  the record of the surface that was approved on 2026-10-13.
- **Alternatives considered**: extend 020's driver (its rows are receipts of that surface, and mixing two features'
  rows in one dispatch table is how a walk stops being readable); replace the shipped cases (they assert the
  refusals and the store, which this feature keeps).

## D8. What the label makes possible, and what the confirmations name

- **Decision**: every confirmation names the picture **by the picture itself** — the same thumbnail widget — since
  no name is painted anywhere (FR-014); a confirmation cancels to a byte-identical record (FR-008, FR-012).
- **Rationale**: the reader's own words ("switch happens on two closed pictured. not use file name is OK") and the
  requirement that a cancel changes nothing. A confirmation that named a file name would be the one place the
  reader saw a name they called useless.
- **Alternatives considered**: names in the confirmation (the reader's own answer); no confirmation for the switch
  (their words: "must confirm").

## D9. The count is the reader's own record

- **Decision**: the badge's number is the picture's own run resolved against **this render's** sentence list
  (`indicesOfSpans`), never the fallback's sentences — the same number the store holds and the same one the
  runner-up warning reads.
- **Rationale**: 020's own distinction (`runsThatFit`): the fallback is an outcome of the render, not a decision of
  the reader. A count that included it would tell the reader they assigned something they did not.
- **Alternatives considered**: count what the render will paint (the reader would see counts appear on pictures they
  never touched, and the badge would disagree with the store).

## D10. The one honest limit this plan carries

- **Decision**: the app cannot promise anything about the **drag** on this platform, so this feature does not use
  one: the move is a pair of buttons. The limit is named here rather than designed around — a `LongPressDraggable`
  inside a horizontal scroll view competes with the scroll axis, and the reader's own two attempts are the
  evidence.
- **Rationale**: an honest limit is cheaper than a promise the gesture arena may not keep.
- **Alternatives considered**: the probe this stage offered (offered, **not taken** — their report answered it);
  re-engineering the arena (unbounded, and not what the reader asked for).

## Open questions

- **How wide a cell is**: the plan fixes the surface's structure (thumbnail, badge, centring) but not the cell's
  exact width or the strip's spacing — implement time, with the stills as the record, and the reader's own eyes at
  the next gate. Fallback chosen: reuse the dialog's own thumbnail metrics so the two surfaces look like one app.
- **Whether the strip wraps or scrolls** when many pictures are chosen: the reader's own words ask for scrolling
  and centring (FR-007), so it scrolls; a wrap would contradict the centring requirement. Fallback: scroll.
- **Whether the count words stay anywhere else**: 020's prompt line (`N sentences chosen`) and the warning
  (`<name>: sentences 3`) are 020's own surfaces and are not touched; the badge's words live under the large
  picture (FR-019). Implement time confirms no third copy is needed.
