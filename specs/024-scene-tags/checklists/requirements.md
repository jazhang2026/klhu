# Specification Quality Checklist: Scene tags (`[scene]`, `[场景]`)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-20
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details as *decisions* — file names and line numbers appear only as **evidence for what the app
      already does** (`lib/dialogue.dart:116` the role tag, `:249` the Format press; `lib/comment.dart:14`/`:25` the
      comment tag's brackets and spellings, `:126` its grammar, `:386` the one elision; `lib/head_tag.dart:58` the
      head tag; `lib/segmenter.dart:93` the sentences; `lib/video_timeline.dart:80` the slots), never as a design
      instruction. The requirements name observables: what the page paints, what the voice says, what the step list and
      the slot list hold, what the assignment rows are, what the reader chooses
- [x] Focused on user value — the item's own six lines are the spine, quoted verbatim in `Input` (substring-checked
      line by line against `text.txt`, six lines, none reflowed)
- [x] Written for non-technical stakeholders — "the tag is a boundary, never a word", "one picture per scene, in order",
      "a near miss stays the reader's text"; the mechanism (elision spans, offset ownership, contiguous runs) is
      confined to the Clarifications' grounding
- [x] All mandatory sections completed — header, `Input`, the tree-today paragraph, Clarifications (what the tree
      settles + the five open questions with their refused alternatives), User Scenarios & Testing, Edge Cases,
      Requirements + Key Entities, Success Criteria, Assumptions, Out of scope, and the receipts section

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c` → 0). The five genuinely open points (Q1–Q5) are
      each written as this spec's answer **with the alternative it refuses**, because the reader's list is written and
      this stage is expected whole; each is reversible up to the plan gate and each sits in the answers table below.
      **Q6** (the heading on a tag line) is the same shape, one degree later: it was opened by the reader's own later
      example, its answer is written in Clarifications item 10, and the reader settled it on its own form — `keep 1`,
      2026-10-20
- [x] Requirements are testable and unambiguous — every FR names an observable: the four spellings, their locale-independence and the brackets
      (FR-001), where a tag may stand (FR-002), what it owns (FR-003), what the page and frames show (FR-004), what the
      read/step/row/slot lists hold (FR-005), what the Format press changes (FR-006), what a near miss is (FR-007), the
      option's presence (FR-008), the pairing (FR-009), the run rules it must obey (FR-010), that the result is
      ordinary (FR-011), the replace question (FR-012), the count mismatch (FR-013), the preamble (FR-014), the shared
      seams (FR-015), the identity of a tag-free content (FR-016), and the heading on a tag line (FR-017).
      **17 FRs, 8 SCs, 8 assumptions, 4 stories, 12 acceptance scenarios, 12 edge cases** — counted mechanically
      (`grep -c`), not by eye; the count moved on 2026-10-20 when the reader's own example was taken (FR-002 re-cut,
      FR-017 and SC-008 new, three edge cases, one scenario)
- [x] Success criteria are measurable — identity read as byte equality of the display/step/slot/row lists (SC-001,
      SC-003), elision read as zero tag characters and byte equality with the deleted-line text (SC-002), the Format
      diff read as blank lines only plus one Undo (SC-004), the pairing read across an N×M grid against a hand-made
      assignment (SC-005), the device read/render witnesses (SC-006), and the near misses read frame-for-frame and
      utterance-for-utterance against today (SC-007)
- [x] All acceptance scenarios are independently testable — US1 needs one tagged content and its deleted-line twin; US2
      needs one mid-paragraph tag; US3 needs eight pictures and three scenes; US4 needs one content of near misses
- [x] Edge cases are named rather than left to the plan — nine, including the three that decide the design: **two tags
      in a row** (an empty scene that consumes no picture), **CRLF content** (the reader's own phone-typed text, where a
      `\r` must not defeat the tag), and **a tag inside a comment's span or on a marked line** (015's and 019's own
      seam, which the plan must reuse rather than re-derive)
- [x] Scope is bounded — `## Out of scope` refuses scene names, any scene-aware surface besides the one option, a
      visible break, an audio pause, nesting, full-width brackets, stored metadata, and a markdown reading of the tag
- [x] Dependencies and integrations stated — no new dependency, no network call; the integrations are the one elision
      site (`lib/comment.dart:386`), the sentence list (`lib/segmenter.dart:93`) with its two consumers
      (`lib/comment.dart:206`, `lib/video_timeline.dart:80`), the Format press (`lib/dialogue.dart:249`), the Assign
      sentences page, and the four ARBs (four new strings, 131 → 135 keys)

## The reader's answers — asked at this stage, settled by the token `take recommendations` (2026-10-20)

| # | the question as put | the answer in force | state |
|---|---|---|---|
| Q1 | Is a scene break visible in the page at all? | No — the blank line goes with the tag | **answered** — `take recommendations`, bound to Q1 (2026-10-20) |
| Q2 | When pictures and scenes differ in number? | first min(N, M) of each, leftovers keep 020's meanings | **answered** — the same token, bound to Q2 |
| Q3 | The sentences before the first scene tag? | belong to no scene, not auto-assigned | **answered** — the same token, bound to Q3 |
| Q4 | Auto-assign over an existing assignment? | asks first, naming how many runs go | **answered** — the same token, bound to Q4 |
| Q5 | Scene names (`[scene 教室]`)? | not in this feature as data — no name parsed, stored or compared | **answered** — the same token, bound to Q5; the reader's later example puts a *heading* on the tag line, which is Q6 |
| Q6 | The heading on the tag line (`[场景] 1：青石观蚁`): hidden with the tag, painted as a heading, or read as the scene's first sentence? | **hidden with the tag** — the whole tag line is the marker (spec Clarifications item 10) | **answered — `keep 1` (2026-10-20)**: the reader was asked this one on its own, because the example arrived after `take recommendations` and this is the app's first rule that hides characters they typed |

The token was one message (`take recommendations`), and it is bound to each question **in the spec's Clarifications
section**, one row at a time, because a token alone is ambiguous out of context. No question was declined and no
question was answered differently from its recommendation; the spec's table keeps each row's refused alternative so a
later stage cannot re-propose one.

## Notes

**The judgment calls a reviewer should argue with, in the order they cost something.**

1. **The tag is wider than a role tag and narrower than a comment tag, and both differences are deliberate.** 014's
   `{name}` must head a **paragraph**; 015's `[comment]` may sit **anywhere** in one and owns the rest of it; this tag
   must head a **line** and be alone on it. The item's own words ("after this … tag line") are the reason, and the
   consequence is a rule the reader may not expect: `[scene] Hello` is ordinary text, painted and spoken. A reviewer
   who wants the tag to accept a trailing sentence is asking for a different reading of line five — say so and the
   spec is amended, not the code.
2. **The tag-only line is elided *with* its break, which 019 does not do.** 019 keeps the line break because a mark's
   line carries the reader's own text; a scene tag's line carries nothing, so keeping the break would leave a blank
   line — a visible scene break, which Q1 refuses and the item's third line forbids. This is the single most
   consequential elision decision in the file: it is what makes the page read as if scenes were paragraphs.
3. **Auto-assign is by index, and the index is the page's order, not the OS picker's.** 021 already lets the reader
   move a picture; pairing by pick order would make the same word mean two things. The cost is a reader who picks five
   pictures and expects the fifth pick to carry the fifth scene — the spec says the page's order decides, which is what
   the "same order of pictures and scenes" line has to mean once pictures can be moved.
4. **The option replaces only with a confirmation, and it is offered even when runs exist.** Both halves are judgment:
   hiding it when the assignment is non-empty would hide it exactly when a reader wants to redo the pairing; replacing
   silently would lose work 021's switch flow never loses.
5. **Scene names are refused, and the refusal is what keeps the grammar small.** A name form is a second grammar with a
   separator rule, a display question (`[scene 教室]` paints nothing — so where does the name go?) and a UI the item
   never mentions. If the reader wants scenes to be *labelled*, that is a different item with its own spec.
6. **`min(N, M)` is stated numerically because the alternative is an invention.** Stretching the last picture over the
   remaining scenes would break 020's "one picture, one continuous run" model; the spec instead leans on meanings 020
   already ships (a skipped picture, a plain background) so nothing new has to be defined to cover the remainder.
7. **The identity criterion (FR-016/SC-001) is the safety net for every receipt in the last section.** Five closed
   features read the same two seams; without a byte-equality guard on a tag-free content, "nothing else moved" would be
   an inspection rather than a measurement.

**What this stage does not answer, on purpose.** How the tag is scanned (one pass or a regex), where the scene list
lives in the code, how the assignment's runs are produced from the ranges, what the option is called in each of the four
locales, and how the confirmation reads — those are the plan's and the tasks'. The spec fixes what a reader can see and
what a row can measure.

**Owed before this stage can be called done.** Nothing. Q1–Q5 are settled by `take recommendations` (2026-10-20) and
**Q6 by `keep 1`** the same day; both bindings are written in the spec's Clarifications and in the answers table above.
The stage is whole, and the next one is the plan — including the re-runs named in the receipts table (015, 019, 016,
020/021, 012), each with its own row in the plan's quickstart.

## Notes added at the plan stage (2026-10-20)

- **What the plan decides, in ten lines**: **D1** the rule lives in its own module (`lib/scene_tag.dart`), a deliberate
  second copy of the shape; **D2** four spellings (`scene`/`escena` any case, `场景`, `場景`), one per shipped UI locale,
  corpus-checked; **D3** recognised at a line's head, the rest of the line is the heading; **D4** the whole line is the
  marker, its break included; **D5** speech is cut from a **same-length space mask**, one call site changed per consumer;
  **D6** painting rides `displayOf`'s one span list as 019's marks do; **D7** `formatForSceneTags` is 024's own function,
  composed with 014's in the press; **D8** the pairing is a pure function in 020's own file, taking scene sentence
  ranges; **D9** the option is a second AppBar action beside `Done`, four new strings (131 → 135); **D10** nothing is
  stored. `research.md` §2 argues each with the alternatives it refuses.
- **Three references are unresolved, and all three are files this feature will create**: `lib/scene_tag.dart`,
  `test/scene_tag_test.dart` and `specs/024-scene-tags/scripts/klhu_walk_scene.py` do not exist until the implement stage
  writes them, which is what `check_artifact_refs.py` reports — the same shape 023's plan stage had (its 8 unresolved
  refs cleared when the files landed). No reference to an **existing** file is unresolved.
- **What a reviewer should weigh, in the order it costs**: D5's mask (a sentence's `text` can carry internal spaces where
  a tag line stood; they are painted nowhere, because the display elides them — the alternative costs a mapping at every
  consumer), D9's placement (an AppBar action on a page whose layout 021's rows measured), D2's spelling set (the shipped-locale four, on the
  reader's ask of 2026-10-20), and row 15's **five re-runs** — the real price of a change to `displayOf`.
- **What the plan does not decide**: the strings' wording in each locale, the walk driver's mechanics, and the implement
  order inside a phase — the tasks stage's.

## Notes added the same day, after the reader's own example (2026-10-20)

- **What arrived, and when.** The item's first line in `text.txt` was edited by the reader to
  `024. add [scene] or [场景] tag support. example: [场景] 1：青石观蚁` — **after** the token `take recommendations` had
  settled Q1–Q5. The wish list is the reader's own file; this stage's job was to notice the edit, not to interpret it
  away.
- **What it reopened.** Two readings this spec had already written down: that a tag is **alone on its line**
  (Clarifications item 3), and that scenes carry **no name** (Q5). The example puts a heading on the tag line, so both
  had to move — item 3 now keeps the first reading beside the re-cut, and Q5 survives only in its "no name *as data*"
  half.
- **What it did not reopen.** Q1 (no visible break), Q2 (min(N, M)), Q3 (preamble), Q4 (ask before replacing), and the
  identity criterion: none of them reads differently under any of the three readings the example opened.
- **What was taken, and why the reader's own answer closed it.** The whole tag line is the marker — hidden and unspoken,
  owned by no scene (item 10). It follows the item's third and fifth lines, and it is the reading that leaves Q1 intact.
  Its cost is exact and stated in the spec: **it hides characters the reader typed**, which no shipped rule in this app
  does — so it was put as its own form of three, and the reader answered **`keep 1`** on 2026-10-20. The two refused
  readings are still in item 10, marked refused, with their reasons.
- **What it cost in artifacts** (all edited together, this stage): `Input` re-quoted and substring-checked again;
  Clarifications item 3 re-cut, items 7–8 re-worded, item 10 added; FR-002 re-cut, FR-004/FR-005 extended, **FR-017** and
  **SC-008** new; A2 and the `SceneTag` entity re-worded; three edge cases and one acceptance scenario added; every count
  re-taken mechanically (17 FRs, 8 SCs, 8 assumptions, 4 stories, 12 scenarios, 12 edge cases).

## Amendment, same day, after the plan stage was written (2026-10-20)

- **What arrived.** One message: `please include: 場景、escena`. It answers the exact gap D2 had recorded — the plan kept
  the reader's two spellings and named the other two as *not taken now* — so this is the reader taking them, not a new
  question.
- **What changed, and what did not.** FR-001 now names **four** spellings (`scene`/`escena` in any ASCII case, `场景`,
  `場景`), all live in every content whatever UI language is showing; 015's own four comment spellings are the
  precedent. No new `FR` id — this is the requirement's own vocabulary moving, so the counts stay **17 FRs, 8 SCs,
  8 assumptions, 4 stories, 12 scenarios, 12 edge cases**. The near-miss list gained `[escenas]` and `［場景］`
  (SC-007, US4), and `research.md` §2 D2's corpus table was re-measured over `lib/ test/ assets/`.
- **What a reviewer should check.** The corpus receipt (three of the four spellings occur in no shipped file; `scene`'s
  one hit is a fixture's picture name), that quickstart row 1's **twin content** proves the two new spellings inside a
  real content and not only as bare lines, and that the set stays **closed** — a sixth spelling needs a new shipped UI
  locale first.
- **A stale count found and fixed in the same pass.** Two lines still read D9's four strings as one (`131 → 132`: spec
  A8 and this file's own dependencies line); both now read **131 → 135**, which is what the plan's D9 and `research.md`
  §2 D9 already said. It was a leftover from the pass before D9 settled on four strings, not a change made here.

## Notes added at the tasks stage (2026-10-20)

- **The list is 35 rows, and its shape is the plan's ten decisions read as work**: the grammar (T001–T006), US1's two
  ends (T007–T015, the painted string then the four spoken lists), Format (T016–T018), the pairing and its page
  (T019–T023), the near-miss case (T024), one build for the five device rows (T025–T031), the closing pass (T032–T035).
  The split is 17 shared/close, 9 US1, 3 US2, 5 US3, 1 US4 — read off the rows' own labels, not by eye.
- **Two orderings a reviewer should check, because both are counter-intuitive and both are deliberate**:
  **T021** (the four ARB strings) sits *before* **T022** (the option's test), because that test pumps a page whose label
  is a generated getter — a missing getter is the wrong RED, and 023's own rows were ordered this way for the same
  reason. **T013** is a *conditional* row on `lib/dialogue.dart`: research §4's R4 says a masked tag line may still
  yield a turn (the emptiness test compares offsets, not whitespace), so the row is either a one-condition fix or a
  receipt saying the file was not touched — never an edit made because the plan guessed.
- **What the rows deliberately do not do**: no row writes a store (D10), no row re-derives 020's run model (the pairing
  calls 020's own add/remove in its test), and no row edits a closed feature's tests — row 15 re-runs them and records a
  moved count in `breakpoint.md` rather than fixing it there.
- **Owed before the walk**: `specs/024-scene-tags/breakpoint.md` and `specs/024-scene-tags/scripts/` do not exist yet;
  T025 writes the driver and its fixture, and the first walk row creates `breakpoint.md`. `tasks.md` itself is written,
  and its three checkers are green (35 tasks, 0 done, 4 `[P]`; 25 ids claimed by 25 rows).

## Notes added at the implement stage (2026-10-22)

**What landed**: all 32 of the rows the walk could reach, and every one of them with its own receipt in
[breakpoint.md](../breakpoint.md). The feature reads as the item asked: the tag line is painted nowhere
(the page's block is byte-equal to the deleted-line twin, 43 characters, 0 of 136 scanlines differing),
spoken nowhere (seven utterances on the fixture and on its twin, the same texts in the same order, with the
app's own ranges stepping `34 → 56` across both tag lines), given its own paragraph by one Format press
(24 → 25 characters, the added one a line break, one Undo back), and paired one scene per picture
(`0,0,0,0,0 → 2,3,1,0,0`, six sentences, the fifth picture still movable afterwards, the option **absent**
on a tag-free content). The render names `pictures=5 ranges=(0,154),(155,272),(273,373),None,None
sentences=7` and writes 374 frames.

**Each requirement, against the row that claimed it** — every FR below is green at the level the row
proves (unit rows in the shipped suite; device rows on `emulator-5554`):

| requirement | row(s) | what the receipt is |
|---|---|---|
| FR-001 four spellings, all live | T001, T002 | the grammar table's seven accepted lines, and the twin content's three respellings owning the fixture's own sentences |
| FR-002 a line's head, the rest is the heading | T001, T002 | `headingStart` past the `]`, the heading read off each accepted shape |
| FR-003 a scene owns the sentences after its line | T003, T004 | the fixture's `2, 3, 1` over the read's own sentences |
| FR-004 tag, heading and break painted nowhere | T007, T008, T026, T030 | the twin's byte-equality on the page (43 chars) and in the render (no slot span reaches a tag) |
| FR-005 silent to every derived list | T005, T009–T013, T027, T030 | seven utterances, both directions; the ranges' `34 → 56` jump |
| FR-006 Format, blank lines only | T016–T018, T028 | 24 → 25, one Undo, a second press disabled |
| FR-007 a near miss stays the reader's text | T001, T024 | the refusal corpus paints, masks and counts as written |
| FR-008 the option's presence | T021–T023, T029 | present with scenes, absent on the tag-free content (device) |
| FR-009 i-th picture with i-th scene | T019, T020, T029 | the N×M grid, and `2,3,1,0,0` on the device |
| FR-010 the result obeys 020's rules | T019, T020 | each cell read back through `assignmentsFor`, `stale` empty |
| FR-011 an ordinary assignment | T020, T022, T029 | a held sentence taken back on the page after the pairing |
| FR-012 ask first when replacing | T021–T023, T029 | the dialog naming three runs; Cancel leaves the runs untouched |
| FR-013 min(N, M) | T019, T020 | the grid's seven cells |
| FR-014 the preamble belongs to nobody | T003, T004, T019 | owner of index 0 in no run |
| FR-015 comments and marks win their spans | T002, T015 | a tag inside a comment's span is no scene; a comment inside a tag line goes with the line |
| FR-016 a tag-free content is unchanged | T006, T014, T024, T031, T032 | 901 tests with the 857 baseline untouched; six closed-feature device rows re-run |
| FR-017 the heading is nobody's | T003, T004, T019 | no owned sentence carries `青石观蚁` or `1：` |
| SC-001 identity | T014, T031, T032 | the six re-runs above, counts beside their own quickstarts |
| SC-002 elision, measured | T007, T026 | 0 scanlines differ; 71 px widest line gap on both pages |
| SC-003 silence, measured | T003, T009, T027 | 7 = 7 utterances, same order, none blank or tagged |
| SC-004 Format, measured | T016, T018, T028 | +1 character, undone in one press |
| SC-005 pairing, measured | T019, T020, T029 | the grid; `2,3,1,0,0` and the move |
| SC-006 device | T026, T027, T029, T030 | rows 10, 11, 13, 14 |
| SC-007 near misses | T001, T015, T024 | the refusal corpus, unchanged frame for frame |
| SC-008 the item's example | T030, T035 | no characters of `[场景] 1：青石观蚁` in any slot; one run per scene |

**Owed, not implied**: `T034` was the writing of this section (now landed); **`T035`** — the measured
figures folded back into SC-002/SC-003/SC-005/SC-006/SC-008's own sentences in `spec.md` — is the one
row still open. And one **finding** stands above the feature: the fixture reads as **7 sentences** and the
scenes own **2, 3, 1**, not the quickstart's five and `2, 2, 1`, because the shipped segmenter splits
`「有人吗？」她说。` at the `？` (`」` is not one of its closers). 024 must not change that (FR-016), the
twin splits identically so SC-003 still holds, and the numbers are recorded in `breakpoint.md` rather
than the row being re-cut.
