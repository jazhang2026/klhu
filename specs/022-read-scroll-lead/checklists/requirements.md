# Requirements checklist — 022 the page keeps something ahead of the read

## What the spec claims, and how it was checked

`python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/spec_consistency.py specs/022-read-scroll-lead`:

```
FRs             9  (spec.md)
SCs             7  (spec.md)
assumptions     0  (spec.md)
stories         2  (spec.md)
scenarios       7  (spec.md)
scenarios in "1 - The read always has something ahead of it (Priority:": 5
scenarios in "2 - The page does not lurch, and does not fight the read": 2
bullets in "User Scenarios & Testing *(mandatory)*": 6
bullets in "Requirements *(mandatory)*": 12
bullets in "Success Criteria *(mandatory)*": 7
bullets in "Assumptions": 7
bullets in "What this feature supersedes, and the pointers it owes": 4
fenced blocks kept in more than one artifact: no divergence
```

`python3 …/check_artifact_refs.py specs/022-read-scroll-lead` → `checked 9 line references`, `no unresolved
references` (the six source citations the spec rests on: `lib/reading_view.dart:1137`, `:1166`, `:1199`, `:1232`,
`:1272`, and `lib/reader_service.dart:37`).

**One finding on the checker's first run, this stage's own, corrected in the spec before this note was written** (a
checklist that hides its own red run is not a receipt): the spec cited 016's step rule as a bare id, and the checker's
own rule is that **every `FR-`/`SC-` id a stage's documents use must be defined in that stage's `spec.md`** — a sibling's
requirement is cited **in words**, never by id. It reads `016's own step rule` now. (021's record hit the same rule from
the other side, on the day a pointer row dragged 012's id into its own file.)

**The `assumptions` line reads `0` and is not usable**: the spec carries seven assumption bullets and the checker's
pattern wants a different shape than the prose uses. The section is what matters; the count is not claimed. (020's and
021's checklists say the same about the same line.)

## The measured basis this spec rests on (taken 2026-10-16, before the spec was written)

011's own walk row 7 was re-run on the tree as it stands — `emulator-5554`, Extra large, display 1080×1000, 011's
8-sentence preset — and it passed (`RESULT: PASS`), so what follows is the app's own evidence line on a **shipped,
receipted** behaviour:

```
klhu speak: 8 utterances | klhu follow: 8 reports | 5 frames | viewport=196 logical
klhu follow: p0 s0 visible=1 top=3   bottom=31  viewport=196
klhu follow: p0 s1 visible=1 top=37  bottom=65  viewport=196
klhu follow: p1 s0 visible=1 top=105 bottom=167 viewport=196
klhu follow: p1 s1 visible=1 top=134 bottom=196 viewport=196     ← box ends at the viewport's last pixel
klhu follow: p1 s2 visible=1 top=134 bottom=196 viewport=196     ←
klhu follow: p2 s0 visible=1 top=168 bottom=196 viewport=196     ←
klhu follow: p2 s1 visible=1 top=100 bottom=196 viewport=196     ←
klhu follow: p2 s2 visible=1 top=134 bottom=196 viewport=196     ← the content's last sentence (the exception)
```

- **Every report is `visible=1`**: 011's own rule (never scroll while the sentence being read is fully visible) is
  satisfied at every sentence — which is why this is a **new requirement**, not a defect report against 011: the
  shipped rule asks whether the spoken sentence is visible, the reader asks whether anything is visible **after** it.
- **Four of the seven non-final sentences** were spoken with their own box ending at `bottom=196` — the viewport's last
  pixel — i.e. the sentence being read was the bottom-most thing on screen. That is the complaint, in the app's numbers.
- **The number the rule needs is not in the line.** Today's six fields say where the spoken sentence is; they cannot
  say whether a sentence follows it on screen, which is what FR-009 adds and what SC-001 is measured on.
- **One measured difference to reconcile in the plan**: 011's own receipt for this row quotes `viewport=209` on the same
  fixture where today's run reads `196`. Neither number is inherited: the plan's first row re-takes the baseline.

## The four questions this stage put, and the reader's answer (2026-10-16)

**The reader answered `1A 2A 3A 4A` on 2026-10-16** — one token for the four questions, bound to this table's own
numbering — and then, **later the same day and after the plan stage, restated the requirement unchanged: "This is not
changed."** Question 1 is therefore **`1B`**: `1A` starts the move *with* the last-visible sentence's highlight, which
is not "before" it, and the window this checklist records below as the one hard thing is **refused as the design**.
Questions 2-4 stand as answered. The first row below is left as it was written (what was proposed and taken) with the
revision marked against it, and the spec's `## Clarifications` carries the same pair. The table below is left as the stage put it (what each
recommendation refused and what the alternatives cost); the row above it is what stands, and the spec's
`## Clarifications` carries the same binding.

| # | question | this stage's recommendation | what the recommendation refuses, and what the alternative costs |
|---|---|---|---|
| — | **the reader's own answer, 2026-10-16** | **`1A 2A 3A 4A`** — the recommendation, taken on all four | nothing beyond what the entries below already refuse; the entries stay as the argument that produced the answers |
| — | **the revision, 2026-10-16 (after the plan stage)** | **`1B` for question 1** — "This is not changed.", the requirement restated: the move fires one sentence earlier, and the 200 ms window is refused | question 1's own `1A` row below, and the plan's `D1`/`D3`/risk notes, all of which were rewritten to the literal reading |
| 1 | when the move starts | **`1A`** — at the last-visible sentence's own start, the same event that paints its highlight (one sentence of headroom) | refuses `1C` (today's trigger — the reported behaviour). `1B` (one sentence earlier) is the **literal** reading of the reader's own words and removes the reveal's own window, at the cost of the page moving under the sentence the reader is mid-way through; the spec's Clarifications 1 names both, because the window is the whole difference |
| 2 | how far the page moves | **`2A`** — just enough that the next sentence is visible (the reveal is handed the reading sentence's box **and** the next one's) | refuses `2C` (a page turn — the reading sentence to the top: fewest moves, largest lurches) and prices `2B` (a third-of-a-viewport cushion: fewer, larger moves, and the sentences above leave the screen sooner) |
| 3 | whether the ▶ step follows the same rule | **`3A`** — yes; the step reveals through the same code path, and a reader pressing ▶ at the bottom meets the same edge | refuses nothing outright; `3B` (steps unchanged) is cheaper and leaves 016's row and cases as written, at the cost of the reader meeting the same situation one press at a time and reporting it later |
| 4 | whether the move must finish before the voice starts | **`4A`** — no; the move starts before the voice and animates while the sentence begins, so the reading never pauses | refuses `4B` (hold the voice until the page settles) as the default: an audible gap before each triggering sentence is louder than a moving page. 4B remains recordable as a setting if the reader misses the trade |

## What a reviewer should argue with

**A defect the tree was found carrying while this stage was written (2026-10-16, the reader's own report)**: with the
page away from the top and nothing highlighted, ▶ Read read the first sentence **with the page where it was** — the
reveal arrived only after that sentence, when the highlight advanced to the next one — while ⏭ Continue Read revealed it
first. The tree confirms it: `_readSelection` set its unit with `_select` and then read it with `step: true`, which does
not track, so no sentence report ever reached `_followRead`, and 016's own rule that a step's sentence be brought into view
before the reader can press again was implemented only for the *next* press, in `_advanceStep`. It is fixed as a dated change
in `specs/016-sentence-reading`'s own record — its case, its RED and its device row — and this feature's `3A` builds on
that fix rather than duplicating it.

1. **FR-001/FR-002 are this stage's reading of three sentences of prose, and the load-bearing word is "before".** The
   spec reads "start the auto scroll before highlight/read last sentence on screen" as *the trigger moves earlier*, and
   its own invariant ("the reading sentence is not the last sentence on screen") as **positional and per-sentence** —
   not as "scroll by a page", not as "scroll whenever a sentence is within N pixels of the bottom". If the reader meant
   the second reading, FR-003's "no further than the rule needs" is the line to overturn, and Clarifications 2 is where
   its alternatives are already priced.
2. **[Settled 2026-10-16: the reader refused this window, `1B` stands — see the revision row above; the paragraph is left as the argument that raised it.]** **The window in Clarifications 1 is the one place where the recommendation is weaker than the reader's words.**
   `1A` leaves the reveal's own animation (a fraction of a second) during which the sentence being read is still at the
   bottom edge; `1B` is what "before highlight" literally asks for. This is put to them as a question rather than
   decided, because both readings are defensible and only the reader knows whether the page moving under a
   half-read sentence is worse than a brief bottom-edge window.
3. **FR-009 changes a line a closed feature parses.** The `klhu follow:` evidence line is read by 011's walk driver and
   by 011's own case in `test/reading_view_follow_test.dart`; the spec requires the new fact to be **appended** so both
   parsers keep matching. A reviewer who would rather not touch a closed feature's instrumentation is asking for the
   rule to be walked on something else — the honest alternative is screenshots, which cannot count sentences below the
   spoken one.
4. **The rule is unsatisfiable for a sentence taller than the viewport**, and the spec says so in Edge Cases rather
   than designing around it. The walk's fixture is far from that (sentences ~28 logical px against a 196 px viewport),
   so the limit is stated, not measured.
5. **SC-002's ordering claim is measurable but its exact line pair is the plan's to name.** "The move precedes the
   voice" is true by construction of the seam (`lib/reader_service.dart:37` fires immediately before `speak`), and the
   plan must say which two logcat lines are compared rather than leaving the check as an inference from timestamps.
6. **This feature re-measures part of 011's closing receipt without rewriting it.** Its device row 7 and two of its
   four follow cases describe the old trigger; the spec names them as re-cut-or-re-run and leaves 011's artifacts as
   written, with a dated pointer in its `tasks.md`. A reviewer who wants 011's record edited instead is reading the
   convention the other way.

## Notes added at the implement stage (2026-10-16)

The list closed at **14 of 22 rows**, with one deliberately half-done (T014) and named as such in its own row. The
checkers, on the finished artifacts:

```
check_tasks_format.py         → 22 tasks (14 done), 6 marked [P]; (setup/foundational/polish): 14, [US1]: 3, [US2]: 3,
                                [US3]: 2; OK: format, sequencing and spec-id coverage check out
task_id_audit.py              → 022-read-scroll-lead: 22 tasks, 14 done, 6 [P]
check_row_coverage.py         → spec.md: 16 ids defined · quickstart: 16 rows claim 16 · tasks.md: coverage table cites 16
check_quickstart_coverage.py  → 9 FR + 7 SC defined · 12 rows ([unit] 9, [device] 2, [structural] 1); unclaimed: none
spec_consistency.py           → no divergence
check_artifact_refs.py        → checked 23 line references; no unresolved references
```

**What the implement stage found, and what each finding changed** (all written into the artifacts rather than kept
here):

1. **The plan's own `D7` was wrong about one of the two parsers**: `FollowLine.parse`'s pattern is **anchored**
   (`…viewport=(\d+)$`), so the appended `below=` field did not "keep matching" — every case of 011's own follow suite
   would have thrown. The suite's own reader was re-cut (the field read when present, `below` null when not, both shapes
   asserted); 011's driver needed no change, because its pattern is unanchored. Recorded in T004's receipt.
2. **US2's bound needed no code** (T009): the framework's own `showOnScreen` on the union rect already keeps the
   sentence in force on screen and never above the viewport's top, and the measured move is well under a page. Recorded
   as green-on-first-run rather than padded with a guard nobody needs.
3. **011's own *long text* case needed no re-cut** (T007) — the sentence it fires is the read's last, so the rule asks
   nothing of it and its expectation still measures what it always did.
4. **Two failures were the tests' own, and both are recorded as such**: the US3 case's helper looked for the shipped
   fixture's first words and threw `reading content RichText not found` on a generated body (fixed by addressing the
   paragraph through the case's own text, and the honest RED taken after that), and the lead case first measured the
   second-next sentence *after* the move that makes it visible — a condition its own move could never satisfy.
5. **The walk found a driver bug this feature owned**: row 24 left the display at 1080×1000, so 016's row 15 (written
   for 1080×2400) tapped the wrong coordinates and failed for a reason with nothing to do with the app. Row 24 now calls
   `reset_viewport()`, and 016's row was re-run: 3/3.
6. **The device's own numbers, against the reader's complaint**: on 011's fixture, the *before* run has four of seven
   non-final reports ending at the viewport's own last pixel; the walked build reads `below >= 1` for every one of them
   and `below=0` only for the content's last sentence.

**What is owed, named**: T014's device half (a text that fits the reading area, moved by zero pixels) needs its own
fixture — a content shorter than the reading area opened on the device — and no row seeds one today; the unit half is
011's own unchanged case. **Closed 2026-10-16, later the same day**: 011's driver gained row **25** (the shipped preset
at the display's own size and the app's own appearance — `viewport=657` against the tallest sentence's `bottom=198`), and
it walks both halves: 8/8 sentences inside the area at once, and the highlight walking down the page
(`472 → 628 → 680 → 840` device px) while the page's offset stays put. `RESULT: PASS`. T014 is ticked; the paragraph
above is left as written.

## Notes added at the plan stage (2026-10-16)

The stage's own set is complete — `plan.md` (D1-D9), `research.md` (§1-§9), `data-model.md` (INV-1..INV-6) and
`quickstart.md` (**12 rows: [unit] 9, [device] 2, [structural] 1**) — and the checkers read:

```
check_quickstart_coverage.py  → 9 FR + 7 SC defined; 12 rows ([unit] 9, [device] 2, [structural] 1, untagged 0);
                                unclaimed: none; no 'Proves' line: none
spec_consistency.py           → FRs 9 · SCs 7 · stories 2 · scenarios 7; no divergence
check_artifact_refs.py        → checked 20 line references; no unresolved references
                                (lib/reading_view.dart:1128/:1147/:1176/:1209/:1242/:1264, lib/reader_service.dart:37,
                                 test/reading_view_follow_test.dart:677, …)
```

**What the plan stage found, and what it settled** (each is written into the artifacts rather than kept here):

1. **The rule already has its own once-per-sentence guard** — `_followRead`'s `gen`/`paragraph`/`sentence` comparison
   (research §3). So `FR-004` needs no new mechanism, and a resumed sentence cannot be dragged back by the lead
   either. This is the cheapest fact the stage found and it removes the one thing that looked like new state.
2. **"Before the voice" is a seam that exists**, not a hope: `onSentenceStart` fires immediately before the engine is
   asked to speak the sentence (research §5), so `FR-002` is implementable at the sentence's own start — and the
   reveal's own 200 ms window is what `1A` accepted — and what the reader **refused** on 2026-10-16, restating the
   requirement unchanged, so the trigger moved one sentence earlier (`1B`) and the window is gone.
3. **The next sentence's box is measurable off screen** because the whole text is one `RenderParagraph` (research §4).
   This is the plan's load-bearing assumption and it is **tested first** (checkpoint 1): if the page ever renders a
   paragraph per widget, the lead's measurement stops being available before a scroll.
4. **`3A` has one doorway and its prerequisite is already in the tree** — the ▶ press's own reveal, fixed the same day
   in `specs/016-sentence-reading`'s record (research §6). The plan therefore adds **one** helper, not three copies of
   the rule.
5. **The evidence line has two parsers and both are regex-shaped** (research §7), so the new field is **appended** and
   nothing is reordered — a reordered field would make a closed feature's parser read a wrong number silently.
6. **`viewport`'s own figure disagrees with 011's receipt** (209 against today's 196, research §2). The walk's first
   action re-takes the baseline; neither number is inherited.

**What the plan deliberately leaves to the implement stage**: the exact wording of the appended field's name (the plan
proposes `below`), the union rect's own inset (whether the next sentence's box is taken whole or to its first line —
the walk's `below` counts whole boxes, and the implementation follows the line), and the per-case cuts of 011's five
follow cases (which is which is decided at the first row of the implement stage, against the printed totals).

**The one hard thing this stage put to the reviewer, and its answer (settled 2026-10-16)**: `1A`'s own window — the
reader's words say "before highlight", and `1A` started the move *with* the highlight, leaving the reading sentence at
the bottom edge for the reveal's 200 ms. The reader refused it: **`1B` is in force**, the move fires one sentence
earlier, and the page therefore moves under the sentence **before** the triggered one — the cost this plan now carries
and names (plan D1/D3 and its risks).
