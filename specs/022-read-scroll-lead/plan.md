# Implementation plan: The page keeps something ahead of the read

**Feature**: `022-read-scroll-lead` | **Spec**: [spec.md](./spec.md) | **Date**: 2026-10-16
**Research**: [research.md](./research.md) | **Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**The reader's own answers are this plan's inputs**: `1B 2A 3A 4A` (2026-10-16) — **the trigger one sentence before** the
last-visible one (the first answer, `1A`, was revised the same day when the reader restated the requirement unchanged:
"This is not changed."), the move minimal, the ▶ step under the same rule, and the voice is not held. The spec's `## Clarifications` carries the binding; this plan says what each one costs in
the tree.

## What this plan decides, in one paragraph

011's follow asks one question at a time — *is the sentence being read visible?* — and moves the page only when the
answer is no. This feature asks a second one at the same moment and at the same seam: **is a sentence after the one
being read visible?** If it is not, the page moves **once, minimally, before that sentence's own voice**, by handing
the framework's existing reveal a rect that covers the sentence being read **and** the one after it. There is no new
scroll machinery, no new state and no new string: a second measurement on the same `RenderParagraph`, one more branch
in the branch that already exists, one more field on the line the walk already reads, and the same reveal.

## The code as it stands (the seams this plan uses)

| seam | where | what it gives |
|---|---|---|
| the sentence's own start | `lib/reader_service.dart:37` — `onSentenceStart` fires **immediately before** that sentence is spoken (the call at `:570`, the `speak` at `:594`) | the moment the rule may act at, and the reason "before the voice" is reachable at all |
| the page's own entry | `_onSpokenSentence` (`lib/reading_view.dart:1128`) | the highlight is painted and the follow runs, in that order |
| the follow, and its once-per-sentence dedupe | `_followRead` (`:1147`) — `gen`/`paragraph`/`sentence` are compared before anything else | the rule fires **once per sentence**, which is what keeps a manual scroll standing (011's `FR-005`) |
| the measurement | `_measureSpan` (`:1209`) → `_SentenceGeometry{paragraph, rect, top, bottom, viewport, visible}` | **any** sentence's box, on screen or off it: the whole text is one `RenderParagraph` (`_textKey`) |
| the move | `_scrollIntoView` (`:1176`) — `RenderParagraph.showOnScreen(rect:, duration: _revealDuration, curve:)`, `_revealDuration` (`:1137`) | the framework's own reveal, per rect; "just enough" is a property of the **rect**, not of a new API |
| the step's own doorway | `_readSelection` (`:1021`, reveals its unit before reading it — 016's amendment of 2026-10-16) and `_advanceStep` (`:1264`, reveals the next highlight) | `3A` has one place to land, and 016's fix is its prerequisite |
| the evidence line | `_logFollow` (`:1242`) — `klhu follow: p<i> s<j> visible=<0\|1> top=<t> bottom=<b> viewport=<h>` | what a walked row reads; `FR-009` appends one field to it |

## Decisions

**D1 — The rule is a position, not a distance (`1B`).** The trigger is a sentence's **own start** (the callback the app
already fires before the voice), and the test is positional: **is the sentence after the one in force the last one
visible?** If it is, the page moves now — so the sentence that would be the last visible one is never highlighted at the
bottom edge, and the reading sentence always has a successor on screen. **Never** "is the sentence within N pixels of
the bottom". **Refused**: a distance threshold (it needs a
constant nobody can justify, and it fails on a sentence taller than the viewport); a check on every frame (it would
fight the reader's own scroll, and `FR-004` forbids undoing it inside the same sentence).

**D2 — How the page answers "is the sentence after this one the last visible?" (`1B`, `2A`).** The page resolves the
**next two** sentences from the same list the read itself was resolved from (`sentenceRanges`/`stepRanges`, the rules
016 and 020 already share), and measures both with `_measureSpan` — off screen included, because the text is one
paragraph. **Refused**: counting
sentences (it needs the whole list's boxes every time and answers a question nobody asked); reading the layout's own
paint (the page would have to know what the viewport clipped).

**D3 — The move is the union rect, and it is where "just enough" lives (`2A`).** When the sentence after the one in
force is the last visible one, the reveal is handed one rect spanning the sentence in force's `top` to the **box of the
sentence two places after it** — the smallest rect that makes the *next* sentence's own read satisfy INV-1 — through
the existing `_scrollIntoView`. So the page moves once, during the sentence being read, and the sentence that follows it
is highlighted with something already visible below it. **Refused** (spec
Clarifications 2, kept refused): a cushion of a third of a viewport (`2B`), and a page turn that brings the reading
sentence to the top (`2C`).

**D4 — The cases where the page must not move (`FR-005`).** The content's last sentence (nothing follows it); a text
that fits the viewport (nothing to scroll, and 011's own scenario 3 stands); the next sentence already wholly inside
the viewport; and a sentence **taller than the viewport**, which cannot have anything below it on screen — the spec's
own declared limit, asserted as "no move rather than a guess".

**D5 — One doorway for all three surfaces (`3A`).** A single private helper, `_revealLead(unit)`, holds the rule; the
follow calls it at a sentence's start, `_readSelection` calls it for the unit a press is about to read (016's fix of
today, unchanged in shape), and `_advanceStep` calls it for the highlight a step leaves behind. **Refused**: three
copies of the rule (the two-and-a-half-behaviours shape this repo has re-cut twice already); a lead only for the
continuous read (`3B`, refused in the spec).

**D6 — The manual scroll and the pause keep their own rules (`FR-004`).** 011's `FR-005` is untouched: the dedupe in
`_followRead` already fires the rule once per sentence, and a resumed sentence re-reporting itself is already ignored
(`_followedGen`/`_followedParagraph`/`_followedSentence`). **Refused**: re-running the rule on every report (it would
drag the page back after a hand scroll — the report that opened 011's own `FR-005`).

**D7 — The evidence line carries the fact the rule is about (`FR-009`).** `klhu follow:` gains **one appended field**,
`below=<n>` — how many sentences' boxes are inside the viewport **below** the reported one — with every existing
field's name and order kept, so both parsers that read the line keep matching: `FollowLine.parse`
(`test/reading_view_follow_test.dart:677`) and 011's own driver regex. The device rows read `below`.
**Refused**: a second line (`klhu lead:`) — one sentence, one line, one place to look; and recomputing the field in
the driver from the dump, which cannot see the boxes at all.

**D8 — The tests.** 011's five follow cases are re-cut per case, not deleted: *long text: the spoken sentence comes
into view* becomes the **lead** case (the sentence being read is never the bottom-most box, and the next one is
inside); *offsets are in range and never go backwards* keeps its shape; *short text: no scroll* and *manual scroll is
not undone* are **unchanged requirements** and must stay green as written. New cases: the content's last sentence does
not move the page; a sentence whose successor is already visible does not move it; the ▶ step's advance leaves a
sentence ahead of the new highlight (`test/reading_view_step_test.dart`); the extended line's own field.

**D9 — What does not move.** No new message key (the four ARBs are untouched), no new stored state, no platform file,
no dependency, the video and its timeline untouched, the read's own order and voices untouched, and the app's own
comment rule (a step is a sentence plus its comment) untouched.

## The ripple, file by file

| file | what changes |
|---|---|
| `lib/reading_view.dart` | `_revealLead` (new, private); `_followRead`'s branch and its doc comment; `_readSelection`'s and `_advanceStep`'s reveal calls; `_logFollow`'s appended field; `_SentenceGeometry` unchanged |
| `test/reading_view_follow_test.dart` | 011's five cases re-cut per case (D8); `FollowLine`'s parser carries the new field |
| `test/reading_view_step_test.dart` | one new case: a step's advance leaves a sentence ahead |
| `specs/011-reading-experience/spec.md` | `FR-003`'s letter narrowed, dated; the note that the lead is 022's |
| `specs/011-reading-experience/tasks.md` | the dated pointer in `## Superseded by later specs` |
| `specs/011-reading-experience/scripts/klhu_walk_experience.py` | the new row (key `24`) reads `below`; 011's row 7 re-walked |
| `specs/022-read-scroll-lead/quickstart.md` | the rows below |

## What this re-measures (receipts this feature invalidates, named)

- **011's device row 7** (the follow, sentence by sentence): its own receipt quotes `8 reports` with the geometry of
  2026-10-16's re-run, and the reports' own figures move with this rule. The row is **re-walked**, and its receipt is
  superseded by a dated one beside it rather than rewritten.
- **011's unit cases 231 and 303** (the spoken sentence comes into view; offsets in range and never backwards): the
  first *is* the old rule and is re-cut; the second's fixture moves, so its numbers move with it.
- **011's `SC-001`** ("no sentence is spoken out of sight"): still true, and no longer sufficient — the stricter
  criterion is this feature's `SC-001` (`below >= 1`). Recorded in 011's spec, dated.
- **016's row 15** (today's own): re-run after this lands, because the reveal it proves is the reveal this feature
  extends.
- **`viewport`'s own number**: 011's receipt for row 7 says `209` where today's run reads `196` on the same fixture.
  The row's first action is to re-take it; neither number is inherited (research §2).

## Checkpoints

1. **After the rule**: `flutter analyze` clean; 011's follow suite green with its re-cut cases; the new cases green;
   the full suite's count recorded against this tree's closing number and decomposed by file.
2. **After the line**: `klhu follow:` carrying `below=`, both its parsers still matching, and the suite's own parser
   case updated with it.
3. **After the walk**: 011's row 7 re-walked and the new row `24` walked on `emulator-5554` at Extra large /
   display 1080×1000, every report for a non-final sentence reading `below >= 1` and the content's last sentence
   reading `below=0` with no move; evidence in `specs/022-read-scroll-lead/breakpoint.md`.
4. **Structural**: the four ARBs' key counts unchanged (no string added), `git status --short android/ ios/` empty,
   and the video's own files untouched.

## Risks, and what this plan does about them

- **The page moves more often than today.** That is the trade the reader asked for; it is bounded by D3 (the smallest
  rect that satisfies the rule) and by D6 (once per sentence, never against a hand scroll). The walk's own row prints
  each report, so the extra movement is a number in the record rather than a feeling.
- **A sentence taller than the viewport** cannot satisfy the rule (D4's limit). Asserted as a limit, not designed
  around; the walk's fixture is far from it (research §1).
- **The reveal's own 200 ms** now runs while the sentence **before** the triggered one is being read (`1B`, `4A`), so the
  window Clarifications 1 first accepted at the last-visible sentence is gone; its cost is the page moving under a
  sentence the reader is mid-way through, which is the trade the reader's own restatement chose.
- **A closed feature's parsers.** Two read the line this feature extends; the plan keeps the field appended and
  re-runs both (D7, checkpoint 2).
