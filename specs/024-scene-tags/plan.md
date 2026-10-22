# Implementation Plan: scene tags

**Feature**: `024-scene-tags` | **Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Input**: the reader's wish-list item 024 (quoted verbatim in the spec's `Input`, its example `[场景] 1：青石观蚁`
included), settled by two tokens — `take recommendations` (Q1–Q5) and `keep 1` (Q6 — the whole tag line is the
marker) — and extended on the same day by a third message, `please include: 場景、escena` (the spelling set goes from
two to four).

## What this plan builds, in one paragraph

A third kind of derived tag, in its own file: `[scene]`/`[场景]`/`[場景]`/`[escena]` at a line's head, with the rest of
the line as a heading. The whole line — tag, heading and the break that ends it — is **painted nowhere** (the one elision in
`displayOf` gains a third span kind) and **heard nowhere** (the text is masked to spaces, so no sentence, step, turn or
slot exists for it). The edit toolbar's Format press gains one composed pure function that gives a tag its own
paragraph. The Assign sentences page gains one AppBar action that pairs the i-th picture with the i-th scene, in order,
inside 020's own run rules, asking first when anything would be replaced. Four new strings, no new dependency, nothing
stored.

## Decisions, and where each is argued

| # | decision | argued in |
|---|---|---|
| D1 | The rule is its own module (`lib/scene_tag.dart`), a deliberate second copy of the shape | research §2 D1 |
| D2 | Four spellings (`scene`/`escena` any case, `场景`, `場景`), one per shipped UI locale, live in every content | research §2 D2 |
| D3 | Recognised at a line's head; the rest of the line is the heading | research §2 D3 |
| D4 | The whole line is the marker, its break included — the app's first rule that hides typed characters, reader-answered | research §2 D4, spec Q6 |
| D5 | Speech is cut from a **same-length mask** (spaces), handed to the speech/step/turn call sites | research §2 D5 |
| D6 | Painting rides `displayOf`'s one span list, as 019's marks do | research §2 D6 |
| D7 | `formatForSceneTags` is 024's own pure function, composed with 014's in the press | research §2 D7 |
| D8 | The pairing is a pure function in 020's file, taking scene sentence ranges | research §2 D8 |
| D9 | The option is a second AppBar action beside `Done`; four strings | research §2 D9 |
| D10 | Nothing is stored; everything is derived on every open | research §2 D10 |

## Structure

```
lib/scene_tag.dart                     NEW  the grammar, sceneTagsOf, scenesOf, sceneMasked
lib/comment.dart                       +    displayOf derives the third span kind (one seam)
lib/reading_view.dart                  ~    masked text at 5 call sites; the press composes two functions
lib/reader_service.dart                ~    the speeches are cut from the masked text
lib/dialogue.dart                      ~    only if R4 proves turnsOf's emptiness test needs a trim
lib/picture_assignment.dart            +    assignScenesToPictures (pure)
lib/picture_assignment_screen.dart     +    the AppBar action + its confirm dialog
lib/l10n/app_{en,zh,zh_Hans,es}.arb    +    4 strings each (131 → 135), generated files regenerated
test/scene_tag_test.dart               NEW  the grammar table, ownership, masking, identity
test/picture_assignment_scene_test.dart NEW the pairing grid (N×M), the hand-made equality
test/reading_view_scene_test.dart      NEW  the page: paint, sentences, steps, turns, the press
test/picture_assignment_screen_scene_test.dart NEW the option's presence, the dialog, the refusal
```

No `contracts/` directory: this feature adds no interface another component implements — its two seams are functions
inside the app (`sceneMasked`, `assignScenesToPictures`), and their contract is the data model's invariants plus the
unit rows. (023 needed `contracts/` because a **store key** outlives the code that writes it; nothing here outlives an
open.)

## Phases

1. **The rule, alone** — `lib/scene_tag.dart` (grammar, ownership, mask) and its table. No caller yet. `flutter analyze`
   clean, the new file's tests green, every existing test untouched.
2. **The painting seam** — `displayOf`'s third kind + the page/video consumers' own tests. The identity row
   (tag-free content byte-identical) lands here.
3. **The speech seams** — masked text at the speeches, the steps, the page's sentence list and the three `turnsOf`
   call sites; R4/R5's rows decide whether `turnsOf`'s emptiness test needs a trim (research §4).
4. **The press** — `formatForSceneTags` + the composition in `_formatDialogue`; R6.
5. **The pairing** — `assignScenesToPictures` + its grid; R7.
6. **The page** — the AppBar action, its dialog, the four strings, the keys audit; R8.
7. **The device walk** — the driver and its five rows (R10–R14), then R15's re-runs of the five closed features'
   receipts on a tag-free content, with their own counts recorded.
8. **The closing pass** — `## Status` in `tasks.md`, the checklist's stage notes, the five counts re-taken, every
   artifact's FR count (17) and SC count (8) checked.

## Gates, and the order they run

```
flutter analyze                                   clean, at every phase
flutter test --concurrency=2                      +857 → +857+024's own, never a red
scripts/run_tests?                                (this repo runs flutter test directly)
spec_consistency.py <dir>                         no divergence (FR 17 · SC 8 · A 8 · stories 4 · scenarios 12)
check_artifact_refs.py <dir>                      no unresolved references
check_quickstart_coverage.py <dir>                every FR and SC claimed by a row
check_row_coverage.py / check_tasks_format.py     at the tasks stage
```

## Risks this plan carries, and what answers each

1. **`turnsOf`'s emptiness test is not a trim** (research §4 R4). If a masked paragraph becomes a turn of spaces, the read
   would speak a silent turn and 016's step count would move. Answered by R4's first case, and if red, by one condition
   in `lib/dialogue.dart`'s own emptiness test — 014's file, one line, no rule change.
2. **A comment inside a tag line** loses its characters to the mask. Pinned as "the tag line wins" in R1's table; a
   reviewer who disagrees is changing FR-015's scope, not this plan.
3. **The identity criterion** (FR-016/SC-001) is the guard for five closed features: a tag-free content must be
   byte-identical on the page, the steps, the slots and the frames. R15 measures it against their own rows.
4. **The device walk's dump versus pixels**: the tag's absence is read off the dump (a string search), the gap's absence
   off a screenshot's pixels (a band scan like 023's rows). Two readings, two kinds of failure, so neither hides the
   other.
5. **Cost, stated plainly**: this stage's own work is small; the **re-runs** are the expensive part (five features'
   rows), and a change to `displayOf` can move any of their painted-string receipts. They are re-taken, not assumed.

## What this plan explicitly does not decide

The user-visible shape of the option's label in each locale (the strings' wording is the implement stage's, in the
reader's own register — "Auto assign scenes" / 「按场景自动分配」), the driver's own mechanics (021's driver already
dumps the page), and whether `scenesOf` returns a list or an iterable. Those are the tasks stage's.

## What a reviewer should argue with, in the order they cost something

1. **D5's mask.** It is the one design choice a reviewer could reasonably reject: a same-length space mask makes the
   tag line vanish from speech *without* touching offsets, but it also means every sentence's `text` can carry internal
   runs of spaces where a tag line stood (they are painted nowhere, because the display elides them). The alternative —
   a stripped copy with a mapping — is cleaner to read and touches every consumer. If a reviewer rejects the mask, the
   spec's FR-005 does not change; only the seams in §3 do.
2. **D9's surface.** One AppBar action beside `Done`, absent when there are no scenes. A reviewer may prefer the option
   in the sentence list's own header, where the reader's eyes already are; the cost is a permanent row on a page whose
   layout 021's rows measured.
3. **D2's spelling set.** Four — the shipped-locale rule's own set, taken on the reader's ask of 2026-10-20
   (`please include: 場景、escena`). What a reviewer can weigh is the **closed** set: a sixth spelling needs a new
   shipped UI locale first, and the corpus receipt (`research.md` §2 D2) shows all four collide with nothing in
   shipped prose.
4. **D4's cost.** Hiding the reader's own heading text is a rule no earlier feature has. The reader settled it
   (`keep 1`), and the plan does not soften it — a reviewer who thinks the app should paint the heading is arguing with
   the reader's answer, not with this plan.
