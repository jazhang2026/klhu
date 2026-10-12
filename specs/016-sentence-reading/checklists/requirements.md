# Specification Quality Checklist: Sentence-by-sentence reading

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-12 (the spec itself is dated 2026-10-09; this checklist is written at the review gate that
followed the tasks list, and every count below was taken then, not on the day of the spec)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — file names and line numbers appear only in the
      `Input` quotes, the decisions' cost lines and this checklist's Notes, where they are the evidence for a
      decision ("what the app already does today"), never a design instruction; every FR names an observable
      (what is spoken, what stays highlighted, what a relaunch shows, what a press does at the text's end)
- [x] Focused on user value and business needs — the reader's own item, quoted verbatim in the `Input` block, and
      the spoken correction underneath it (*"我需要的是读完一句停 再一键读第二句。"*); every requirement traces to
      one of the two
- [x] Written for non-technical stakeholders — the reading page, ▶ Read, ⏭ Continue Read, the highlight, the
      reader's own pace; no widget, store, key or function is named as a decision
- [x] All mandatory sections completed — header (Feature Branch / Created / Status / Input), User Scenarios &
      Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope, and the
      decisions section this spec carries in place of a `research.md`

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c 'NEEDS CLARIFICATION' spec.md` → 0). The two
      questions the design rested on were put to the reader as numbered options and answered in one turn (which
      sentence the waiting highlight points at; what a relaunch remembers), and the answer that came back was a
      **new requirement** rather than a pick — the text's end is silent (*"user can see it"*) — so the FR that
      carried the old reading was rewritten with it (FR-008)
- [x] Requirements are testable and unambiguous — each FR names an observable: what ▶ reads with nothing
      highlighted (FR-001), with a sentence (FR-002), with a paragraph (FR-003), where the highlight goes when a
      read ends by itself (FR-004), what one step covers (FR-005), which rule resolves the next sentence (FR-006),
      what is in force inside a session and what survives a relaunch (FR-007), what happens at the text's end
      (FR-008), what Stop and an edit still clear (FR-009), what Pause keeps (FR-010), what a step is in 多人对话
      (FR-011), that the step's sentence comes into view (FR-012), which message key leaves and what happens to
      the count (FR-013), and that nothing is installed (FR-014).
      **14 FRs, 5 SCs, 4 assumptions, 2 stories, 11 acceptance scenarios, 6 edge cases, 4 out-of-scope bullets,
      5 decisions** — counted mechanically (`grep`/script over `spec.md`), not by eye
- [x] Success criteria are measurable — the app's own device lines per press (SC-001), where the highlight sits
      after each press and what the page says at the end (SC-002), what ⏭ reads after a step (SC-003), one press
      carrying a sentence with its comment (SC-004), and the 010/011 rows that must still pass, with the ones the
      amendment changes named (SC-005)
- [x] Success criteria are technology-agnostic — "the app's own per-press line", "the highlight's rows", "a
      relaunch"; no store, key, type or function is named as a criterion
- [x] All acceptance scenarios are defined — US1: 6, US2: 5 (**11** in total), each Given/When/Then, each
      independently demonstrable
- [x] Edge cases are identified — 6, including the three that decide the feature's feel: a paragraph with **no
      sentence delimiter** is one step (the rule 011's 2026-10-09 amendment made true), a step that lands **off
      screen** is brought into view before the reader can press again, and the reader who presses ▶ **twice
      quickly** must not queue a second sentence
- [x] Scope is clearly bounded — the Out of scope list (auto-advance on a timer, changing ⏭'s meaning, the video
      and the editor beyond a position's normal life, and the sheet / picker / removed roles / 015's comment
      switch) plus the assumptions that keep a step a step (a press never reads twice, a tap is never a mode the
      reader is locked into)
- [x] Dependencies and assumptions identified — 4 assumptions, each with its reason and, where the reason is a
      fact about this checkout, the file it comes from

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001/FR-002/FR-003/FR-004/FR-008 → US1
      scenarios 1-3 and 4-6; FR-005/FR-006 → US1 scenarios 6 and the comment edge case; FR-007/FR-009/FR-010 →
      US2 scenarios 1-4; FR-011 → US2 scenario 5; FR-012 → US1's off-screen edge case; FR-013/FR-014 → the
      structural half
- [x] User scenarios cover primary flows — the stepper itself (P1) and the invariants that keep it from breaking
      010/011/015 (P2), in that order, because the second story exists to protect the first
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — the mechanics the feature rests on (sentence
      segmentation, the comment's own span, the position's record) appear only in the decisions' cost lines and
      in this checklist's Notes

## Notes

**The round of 2026-10-09, and what each answer binds.**

- The reader answered with the two of US1/US2's acceptance scenarios rewritten in their own words, then chose
  between two readings of "no previous highlighted position" and removed a message in one turn. What a reviewer
  should notice is that the answer **reversed a shipped feature**: today a tap's position survives a restart
  (010 FR-008), and **decision 5 retires that** — *"(B) 谁都别留,重启一律干净"*. It is recorded in `spec.md` three
  ways (the `Input` line's dated amendment, FR-007's own sentence, decision 5 with the reader's words), and the
  record work it forces on 010's and 011's own artifacts is the plan's §3.7 and tasks' Phase 5.
- **Decision 2's "say nothing" is the reader's own correction, not a quiet simplification**: the spec first read
  "clear the highlight and the position and say the text has ended", and *"user can see it"* removed the message
  with it. FR-008, decision 2 and FR-013's cost line were rewritten the same day; the plan's §2.3/§4 carried the
  old reading until 2026-10-12, when the tasks stage corrected them in place.
- **This spec records the round in its `Input` block and its decisions, not in a `## Clarifications` section**
  (015's shape). Every question and answer is there with its date, but a reader looking for that heading will not
  find it — a `## Clarifications` section is one edit away if the house form is wanted.

**The story split is mine and should be argued with.** The reader's item is **one** mechanism: a press reads one
sentence, stops, and the next press reads the next. US1 is that. US2 exists because narrowing 011 FR-022 (the
highlight no longer clears when a read ends by itself) is the load-bearing change in the whole feature, and the
things it could break — Stop's clearing, ⏭'s meaning, Pause's resume point, the follow, and what a relaunch
shows — are not the reader's ask but are what makes it safe to ship. A reviewer who thinks US2 is not a story
can fold it into US1's edge cases; the cost is that the invariants lose their own priority and their own
independent test.

**Precision added beyond the reader's wording — each one a place the plan could otherwise decide silently.**

- **The next sentence is resolved by `lib/segmenter.dart`'s `sentenceRanges`** (FR-006) — the same rule the read
  uses and the one 011's 2026-10-09 amendment re-cut to cut inside paragraphs. Nothing new divides the reader's
  text, and a step cannot cross a blank line.
- **One step is the sentence *plus its comment*** (FR-005) — 015's comment is part of its sentence's read, so a
  step that stopped at the sentence's own end would drop it. The plan found the mechanism (`lib/speech_resolver.dart:190`
  speaks a comment only when the range covers the comment's own span) and this is the feature's first test.
- **A paragraph press keeps its own meaning** (FR-003): FR-004's "do not clear" applies, the advance does not —
  the reader's own unit (011 FR-024) is never overruled by the stepping rule.
- **The existing empty-range message is not reused** (FR-008, FR-013): the text's end says nothing at all, and
  `nothingToReadMessage` stays where it is (`lib/reading_view.dart:1095`, `:2023`, `:2149` — an empty **range**).
- **The count that moves is named** (FR-013): 108 → 107, and the one receipt elsewhere in the repo that reads
  108 (015's row 16) is corrected with its date in 015's own record.

**Reuse obligations the plan inherits (grepped, not remembered).**

- The step's own read is ▶'s existing path: `lib/reading_view.dart:1048` (`_readSelection`) and `:1077`
  (`_readRange`), whose `track` flag stays `false` for ▶ — a step needs no callback, because its own range is
  the record of what was read.
- The advance lands in the read's own end: `:1243-1252` (`_runRead`'s `finally`, guarded by `gen == _readGen`).
- The reveal 011 FR-002 uses is `:1142` (`_followRead`); a step reveals by the same code or a highlighted
  sentence can sit off screen (FR-012).
- The gesture's own selection is `:992-1014` (`_resolveAt` → `_highlight` + `_anchor`), and the position it
  writes is the record decision 5 retires (`lib/read_position_store.dart`).
- The comment's rule and the comment's owner are `lib/comment.dart` (`commentsOf` at `:155`, the owner at `:204`);
  the comment's own span gate is `lib/speech_resolver.dart:190`.
- The sentences are `lib/segmenter.dart:93` (`sentenceRanges`), the paragraph ranges `:101`.
- Every string the app shows is one of four ARBs (`lib/l10n/app_en.arb` — 108 keys on `409ffe1` — plus `app_zh`,
  `app_zh_Hans`, `app_es`), and `test/l10n_keys_test.dart` is bidirectional.

**Risks the plan must carry, in the order they are likely to bite.**

1. **011 FR-022's narrowing (FR-004).** The highlight no longer clears when a read ends by itself, which is what
   FR-022 was written to prevent. The mitigation is that Stop, an edit, leaving the page and the text's end still
   clear it, and that a step survives only its session (FR-007). The risk that remains is a later reader finding
   the old rule quoted in a row and calling the highlight's persistence a bug.
2. **The comment's range (FR-005).** A step scoped to the sentence drops the comment **silently**, on exactly the
   texts that use comments. It is the first thing to write a test for.
3. **010's stored position retires (decision 5).** This is a deletion that reaches six shipped test files, two
   doc comments, a contract file and four other features' records — under-counted in the plan's first draft and
   corrected on 2026-10-12 (plan §3.7, tasks § The stage's corrections). The honest record is 010's own dated
   amendment beside the ask that reversed it.
4. **The reveal seam (FR-012).** If a step's next sentence is not brought into view, the reader presses a key
   aimed at something they cannot see.

**Deliberately absent, so the plan does not add it.**

Auto-advance on a timer, any change to ⏭'s meaning, a second read button, a visible stepping mode, a per-sentence
delay or speed control, the video beyond a position's normal life, and the sheet / the picker / removed roles /
015's comment switch.

**Two artifact deviations, both dated, neither silent.**

- **No `research.md` and no `data-model.md`**: the plan's §1 is the research (every site read on `409ffe1` with
  its line numbers) and §3 is the data model (the store's retirement, the step helper), because the spec's own
  decisions section carries the alternatives with their costs.
- **`quickstart.md` was written *after* `tasks.md`** (2026-10-12), at the review gate that followed the tasks
  list — 016's plan stage handed back `spec.md` + `plan.md` alone. Nothing in the tasks list was re-cut to fit
  it: its Phase 6 rows cite this file's rows 5-11, and its unit tasks mirror rows 1-4.
- **The spec's 4 assumptions are unnumbered** (015's shape is `A1`..`An`): nothing in this feature's artifacts
  cites them by an id, so no `A`-id dangles — but a reader looking for `A1` will not find one, and the
  specification-coverage script counts assumptions by that id form, which is why it reports **0** for a spec
  that has four.
- **`.specify/feature.json` was still pinned at `specs/015-comment-tag` on 2026-10-12** — observed, not assumed.
  Any repository script run before it is re-pinned (`setup-plan.sh`, `setup-tasks.sh`, `check-prerequisites.sh`)
  would operate on 015. Re-pin it at `specs/016-sentence-reading` before the implement stage runs one.

**Naming.** The feature directory is `016-sentence-reading` (the reader's own numbering, item 016). The slug is a
name, not a decision: say a word and it is renamed in the four places a rename touches.
