# Plan: the assignment pass's pictures, and the controls on them

**Feature**: `021-picture-pass` · **Ground**: `spec.md` (19 FRs, 11 SCs, 3 stories, 15 scenarios), `research.md`
(5 grounding corrections, D1-D10), `data-model.md` (INV-1..9) · **Rows**: `quickstart.md` (17)

## Summary

020's pass asks the reader to give sentences to pictures and shows the pictures as **file names**
(`w020_white.png\n4 sentences`), moves a picture only by a gesture that the platform's scroll axis wins
(`LongPressDraggable` inside a horizontal `SingleChildScrollView`), refuses that move for a picture the reader gave
nothing whenever the render's fallback would feed it, and has no way to take a picture out at all. This feature
gives the pass **the pictures themselves** — a thumbnail strip with each picture's own sentence count at its top
right, a tap that selects and shows that picture's sentences below, a hold that shows the picture large with
`Close` — and the two controls that act on a picture (**move**, **delete**), offered only when the reader has
assigned it nothing. A sentence another picture holds stays tappable and, where the two rules allow it, becomes a
**confirmed switch**. The reader's own defect (a neighbour's last sentence silently accepted into two runs) is
fixed at the boundary, in the same code path. Nothing about the render, the split or the store's shape moves.

## Project rules this plan must satisfy

- **`flutter analyze` clean**, and every row read against the line's own measured baseline: **782 cases, 0 failing**
  (`flutter test --concurrency=2`, 2026-10-15 08:40 PDT, `01:17`) and **55** test files; the four ARBs at **120**
  keys each. The baseline line is quoted in `quickstart.md`'s Prerequisites and beside every row.
- **New user-visible text needs ARB keys in all four files** (`app_en`, `app_es`, `app_zh`, `app_zh_Hans`), with
  `flutter gen-l10n` and `test/l10n_keys_test.dart` green in both directions (014's and 019's own rule).
- **Constitution III (test-first)**: each rule's cases are written and run RED before its code; a compile error
  counts as RED and is quoted as one.
- **Constitution IV (on-device first)**: every claim about what the reader sees (the thumbnail, the badge, the
  large picture, `Close`, the centring, the two confirmations) is walked on `emulator-5554` with the app's own
  evidence or a still — never asserted from a unit test alone.
- **One rule, one file**: the assignment's rules stay in `lib/picture_assignment.dart`; the surfaces call them and
  never re-implement them. The pass and the dialog's own picture surface share one widget, so the two cannot drift.
- **No new dependency, no new stored key, no network** (FR-018).
- **A line another driver parses keeps working**: the chip's own file name survives as its **semantic label**
  (FR-002, decided 2026-10-15), so 020's `chip_line` parser (`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py`)
  and the rows that use it stay valid; this plan promises no change to that parser.

## Decisions

One decision set, `research.md`'s D1-D10 — this plan carries **no second numbering**, so a later stage quoting
"D4" finds one thing. Each row is what this plan does with that decision, and what the alternative would have cost.

| # | decision | what this plan does with it, and why not otherwise |
|---|---|---|
| D1 | the cell is the picture, the number at its top right | the cell reuses the dialog's own bounded decode (`ChosenThumbnail`, `lib/reading_view.dart:3067`) and keeps the file name as its **semantic label** (the reader's answer, `2` above); a new image widget, or a painted name, would each be a second thing to keep in step |
| D2 | one tap selects; a hold opens the picture large **below** the strip | the large picture lives in the page's own body — not a route, not an overlay: the reader's own words are "show large picture below", the list is hidden while it is open, and the strip has to stay visible for the "real change" they asked to see |
| D3 | the move and delete buttons, and **what decides them** | what decides is the pass's own `_runs`, not the resolver's `effective` answer; the drag is retired (D10). Reading the fallback is the shipped rule and is exactly what the reader's report falsifies (`lib/picture_assignment.dart:325-326`) |
| D4 | the switch, and the boundary that let a sentence into two runs | the switch applies as a **repair** — the sentence leaves its holder before it is given — and `refusedAdd`'s two comparisons become inclusive (`lib/picture_assignment.dart:162-165`), so no path can duplicate. Applying the switch without confirming is the defect itself; refusing the tap outright is what the reader's report asked to change |
| D5 | the delete, and the two screens | the delete writes through the draft the pass already answers with (020's `AssignmentDraft`), and the dialog's own surface shares the same widget. A second write path, or a second surface, is where the two screens start to differ |
| D6 | the strip centres the selected cell | the platform's own `Scrollable.ensureVisible(alignment: 0.5)` over a per-cell `GlobalKey`; hand-computed offsets re-derive a layout the framework already knows |
| D7 | the walk's own shape | one new driver, one row per device scenario, the shipped pass test file **re-cut and never deleted**; extending 020's driver would mix two surfaces' receipts in one dispatch table |
| D8 | the confirmations name the picture, not a file name | both boxes carry the same cell widget, and a cancel leaves the record byte-identical (FR-008, FR-012); a name in a box is the one place the reader called useless |
| D9 | the count is the reader's own record | the badge reads the picture's **own run** against this render's sentence list, never the fallback's sentences (020's own distinction in `runsThatFit`) |
| D10 | the honest limit: no drag on this platform | the move is two buttons, and this plan promises nothing about a gesture the scroll axis wins; the probe the spec stage offered was offered and **not taken** |

## Project Structure

Documentation (this feature):

    specs/021-picture-pass/
    ├── spec.md                    (19 FRs, 11 SCs, 3 stories, 15 scenarios, 8 clarifications)
    ├── checklists/requirements.md (the answers, and Amendment 1)
    ├── ui-sketch.html             (the surface the reader settled, and the refused neighbours)
    ├── plan.md · research.md · data-model.md        (this stage)
    ├── quickstart.md              (16 rows, this stage)
    └── tasks.md                   (next stage)

Source and tests — **new files are marked**; the rest is edited in place:

    lib/picture_assignment_screen.dart     the pass: the strip, the badge, the large picture, the controls, the
                                           confirmations, the switch (largely rewritten; 317 lines today)
    lib/picture_assignment.dart            the rules: the boundary becomes inclusive (D8); no other rule moves
    lib/reading_view.dart                  the dialog's own picture surface (D9), the pass's own call site, and the
                                           chip's semantic label (FR-002)
    lib/l10n/app_{en,es,zh,zh_Hans}.arb    the new strings (FR-017) + the regenerated Dart
    test/picture_assignment_switch_test.dart        **new**: the switch's legality, its two halves, the boundary
    test/reading_view_picture_pass_test.dart        **new**: the surface — strip, badge, tap, hold, Close, centring,
                                                    the controls' gating, the confirmations
    test/reading_view_video_assignment_test.dart    the shipped pass cases, re-cut where the surface moved (NOT
                                                    deleted): its chips' own labels are the thing that changed
    specs/021-picture-pass/scripts/klhu_walk_pass.py **new**: the device walk, one row per device scenario

## Complexity Tracking

None: no new dependency, no new stored key, no second rule engine, and the pass keeps its own file.

## Amendment 1, 2026-10-15 — what the reader settled after this plan was first drafted

The reader's two answers (quoted in `spec.md`'s Clarifications 1 and 7) settle two things this plan first left
open, and both are already written into the decisions above rather than patched on:

- **FR-002 (a)**: the file name stays as each cell's **semantic label** — not painted, and still what 020's own
  walk parser reads. This **retires the risk this plan's first draft named** (a re-cut parser and re-walked
  receipts for rows 6-11 and 16 of 020's walk); nothing in 020's own record needs re-cutting, and its rows'
  evidence is simply re-taken on this tree.
- **FR-019**: the badge carries the number alone and the app's words move **under the large picture** — one more
  string position, no new key (both words already exist).

## Citations corrected after the implement stage (2026-10-15)

Three `file:line` citations in the decisions above were written against the tree of the **plan** stage and the
implementation moved what they name. `check_artifact_refs.py` — the structural row's own checker — found them:

| decision | cited | now | what moved |
|---|---|---|---|
| D1 | `lib/reading_view.dart:3003` | `:3067` | this feature's own helpers (`_countOf`, `_confirmRemovePicture`) were inserted above `ChosenThumbnail` |
| D3 | `lib/picture_assignment.dart:186-189` | `:325-326` | `mayDrag` became `mayMove` and four rules (`holderOf`, `withoutSentence`, `refusedSwitch`, `applySwitch`) were added above it |
| D4 | `lib/picture_assignment.dart:149-151` | `:162-165` | the reason written beside the two comparisons pushed them down; the comparisons themselves are now inclusive |

A citation is a claim about a tree, and every one of these was true of the tree it was written on.
