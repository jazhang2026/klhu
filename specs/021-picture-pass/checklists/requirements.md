# Requirements checklist — 021 the assignment pass's pictures, and the controls on them

## What the spec claims, and how it was checked

`python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/spec_consistency.py specs/021-picture-pass`,
on the spec as written:

    FRs            16  (spec.md)
    SCs             8  (spec.md)
    assumptions     0  (spec.md)
    stories         3  (spec.md)
    scenarios      14  (spec.md)     3 / 6 / 5, one run per story
    bullets in "User Scenarios & Testing *(mandatory)*": 7      (the edge cases)
    bullets in "Requirements *(mandatory)*": 19                (16 FRs + 3 key entities)
    bullets in "Success Criteria *(mandatory)*": 8
    bullets in "Assumptions": 6
    bullets in "What this feature supersedes, and the pointers it owes": 3
    fenced blocks kept in more than one artifact: no divergence

`python3 …/check_artifact_refs.py specs/021-picture-pass` → `test/*.dart files in the tree 55`, `checked 5 line
references`, `no unresolved references`.

**Two findings on that checker's first run, both this stage's own, both corrected in the spec before this note
was written** (they are quoted because a checklist that hides its own red run is not a receipt):

- a citation written against `reading_view.dart` **without its `lib/` prefix** (the lines the spec means are 3003 to
  3030) — the tree's own paths carry their `lib/`, and the checker
  resolves references literally, so it read the path as one that does not exist;
- a rule of **012's** cited as a bare id (the one its picture-remove carries). It is not this spec's to number, and
  020's own rule stands: a sibling feature's rule is cited **in words** — the same finding 020's own record hit,
  twice in one day, which is why it is written down here rather than fixed quietly.

**The `assumptions` line reads `0` and is not usable**: the spec carries six assumption bullets, and the
checker's pattern wants a different shape than the prose uses. The section is what matters; the count is not
claimed. (020's checklist says the same about the same line.)

## The answers this spec rests on (recorded 2026-10-15)

The reader's own message and their answers are quoted verbatim in the spec's `Input`, and each answer is bound
there to the question it answers — this reader answers a form in one token, and the token alone is ambiguous once
the handback that asked it is out of context. What each settles, and what it costs:

| question | the answer taken, and what it costs |
|---|---|
| the shape of a picture on the pass | **`1B` as first read** — the picture with its count and the name de-emphasised, preview on tap: **overturned the same day by Amendment 1 below**, which is what stands (no name painted; hold opens the picture large) |
| moving a picture the reader gave nothing | **not an option — an observation**: the hold refuses with *"This picture holds sentences; un-assign them before moving it."* and a plain drag scrolls. This spec's recommendation **2a + 2b** (the reader's own runs decide; an explicit control instead of the gesture), reversible up to the plan gate |
| deleting a picture the reader gave nothing | **`3.`**: inside the pass, immediate, the reader stays, and **every** delete asks first — the dialog's own `Remove this picture` included (FR-006–FR-009). Cost: 012's shipped immediacy is re-cut, with a pointer rather than an edit |
| a sentence another picture holds | **`4.` — a reversal** of the answer this stage first offered (the disabled checkbox): the sentence stays selectable and the tap proposes a confirmed **switch** (FR-010–FR-013). Cost: it rewrites 020's own tap path, and it is the same code path its defect lives on |
| the defect under *Issues* | **not a question**: `lib/picture_assignment.dart:149-151` tests both order boundaries with a strict comparison, so a neighbour's **last** sentence is accepted and lands in two runs — 020's own FR-005, broken by 020's own implementation, with no walked row covering the shape. The fix is 020's, carried by this feature's switch |

**The one thing the reader declined**: the probe this stage first offered for the move (two gesture variants on
the emulator, a still each). It is recorded as **not taken**, not as pending — their own report answered it more
directly than the probe would have.

## Amendment 1, 2026-10-15 — the reader settled the surface, and this stage's first reading is overturned

The reader's second message (quoted verbatim in the spec's `Input` as the `text.txt` item plus the conversation)
answers what the sketch left open **and** overrules this checklist's own first table in three places. The first
version is left above as written — it is the record of what this stage proposed — and this is what stands:

    spec_consistency.py, on the spec as it now reads:
      FRs            18   (was 16)
      SCs            11    (was 8)
      stories         3
      scenarios      15   (4 / 6 / 5)
    check_artifact_refs.py: checked 5 line references | no unresolved references

| question | what the reader settled, and what it costs |
|---|---|
| what a picture on the pass is | **a thumbnail of the picture, with its sentences' count at its top right, no file name painted anywhere** (FR-001, FR-002). Cost, named: 020's walk driver reads the pass's chips **by parsing the file name** (`chip_line`), so rows 6-11 and 16 of 020's own walk stop matching as written — the two ways out are in the spec's pointers and the plan picks one |
| what one tap does | **selects** the picture (highlighted, its sentence list below), not a preview (FR-003) |
| what a hold does | shows the picture **large below the bar**, the list hidden, with `Close` (FR-004) |
| the move and the delete | **buttons in the large picture**, offered **only when the reader has assigned that picture nothing** (FR-005) — the reader's own words, and the same reading of the fallback 020's rule got wrong; the drag is retired from the design |
| the selected picture's place | the bar **auto-centres** on it (FR-007) |
| the dialog's own surface | **the same surface and functions** (FR-010) — which narrows 012's own reorder (a picture carrying sentences offers no move), a second pointer owed |
| how a confirmation names a picture | **by the picture** (FR-014): the switch's box shows both thumbnails, since no name is painted anywhere |

**What that leaves the reviewer, in this order:** (1) FR-002's own cost is the one thing that reaches backwards
into a **closed** feature's receipts — 020's rows 6-11 and 16 read chips by name, and FR-002 removes the name from
the page; the recommendation (the name survives as the **semantic label**, invisible and still parsed) is the cheap
way out and the alternative is a re-cut parser plus re-walked rows, and this is the item to argue with first.
(2) FR-005 re-cuts 020's `FR-015` (the fallback no longer decides what the reader may do) — the reader's own words
say "un-assigned", so this is their reading and not this stage's invention. (3) FR-015 leaves the
holds-sentences refusal with **no surface** on this page: the plan must say where, if anywhere, that string is
still reachable rather than leaving a string nobody can reach. (4) FR-011's confirmation is about taking the
sentence away, not about waiving continuity and order — the reading it refuses is recorded in Clarifications 4.
(5) SC-005/SC-006/SC-009 re-walk 020's own rows 8/9-shaped subjects, so 020's closing receipt covers 020's tree and
not this one.

## What a reviewer should argue with

1. **FR-003 is the load-bearing re-cut, and it is this stage's reading of the reader's own words.** 020's rule
   (our own refinement of 2026-10-13) counts the render's **fallback** as holding, which is why the reader's hold
   was refused on a picture they had given nothing; FR-003 says the **reader's runs** decide. If the reader meant
   "keep the fallback out of the move's reach", FR-003 is the one line to overturn — and the cost of overturning
   it is the report that opened this feature.
2. **FR-005 replaces "the drag must work" with an explicit control, and that is a choice, not a fix.** I cannot
   promise the long-press drag inside a horizontally scrolling row; the alternatives were a probe (not taken) and
   re-engineering the gesture arena (unbounded). A reviewer who wants the drag itself repaired is asking for a
   different spec whose first row is that probe.
3. **FR-010's confirmation is about *taking the sentence away*, not about waiving the rules.** A switch is offered
   only where the sentence is an end of its holder's run and the taking picture ends up continuous and in order.
   The reading it refuses — any assigned sentence may be moved to any picture — would retire 020's FR-003 and
   FR-004 together and leave a schedule no render can walk.
4. **FR-012 restates another spec's requirement.** 020's FR-005, verbatim in meaning, appears here because 020's
   own implementation violates it. Whether that restatement belongs in 021 or only in 020's own fix is arguable;
   what is not arguable is that one of them must carry it, or the boundary case has two behaviours.
5. **FR-009 re-cuts 012's shipped remove** (immediate → asking). 012's artifacts stay as written, with a dated
   pointer in its `tasks.md`; a reviewer who wants that change kept out of 012's own record is reading the
   convention the same way this stage does.
6. **This feature invalidates part of 020's closing receipt.** Rows 8 and 9 of 020's walk were judged on the
   fallback-counts rule (SC-003/SC-004/SC-006 here restate their subjects), so "020 is closed" holds for its own
   tree and not for this one. Nothing in 020's `breakpoint.md` is rewritten; the re-walk is named in the
   pointer.

## Notes added at the plan stage

The stage's own set is complete — `plan.md`, `research.md` (5 grounding corrections, D1-D10), `data-model.md`
(INV-1..9) and `quickstart.md` (**17 rows ([unit] 8, [device] 8, [structural] 1, untagged 0)**), beside the spec, the
checklist and the sketch — and the checkers read:

    check_quickstart_coverage.py  → 19 FR + 11 SC defined; 17 rows ([unit] 8, [device] 8, [structural] 1);
                                    unclaimed: none; no 'Proves' line: none
    spec_consistency.py           → FRs 19 · SCs 11 · stories 3 · scenarios 15; no divergence
    check_artifact_refs.py        → every existing citation resolves (`lib/picture_assignment.dart:149`,
                                    `:186`, `lib/reading_view.dart:3003`, …), and **three references do not
                                    resolve, by design**: `test/picture_assignment_switch_test.dart`,
                                    `test/reading_view_picture_pass_test.dart` and
                                    `specs/021-picture-pass/scripts/klhu_walk_pass.py` are the files **this
                                    feature creates** (the plan's own Project Structure marks them `new`). They
                                    are the only unresolved entries, and none of them is a citation of a file
                                    that exists and moved.

**What the plan stage found false, or newly true** (each is written into the artifacts rather than kept here):

1. **"Un-assigned" is not what the tree tests** — `mayDrag` reads the resolver's `effective` answer, which carries
   FR-006's fallback (`lib/picture_assignment.dart:186-189`); the reader's own report is that rule's effect.
   research §1, and D4 in `plan.md`.
2. **The reported defect is a strict comparison** (`lib/picture_assignment.dart:149-151`), and the switch is what
   replaces its silent acceptance with a confirmed, repair-shaped edit (research §2, plan D8).
3. **020's own walk reads the pass by file name** — the reader's answer (a: the name as the **semantic label**) is
   what keeps those rows valid, so the plan promises no parser change and 020's receipts stand (research §3).
4. **012's reorder is unconditional** and narrows under FR-010 (research §4) — a second supersession pointer owed.
5. **The holds-sentences refusal has no surface left on the pass** (research §5): the plan records that it is
   reachable nowhere, rather than leaving a string nobody can reach — `spec.md`'s FR-015 says so in words.

**What the plan stage deliberately did not settle**, so the implement pass does: the cell's exact width and the
strip's spacing (the structure is fixed, the metrics are the reader's own eyes at the next gate, with the fallback
being the dialog's own thumbnail metrics), and the confirmations' final wording (the sketch proposes; the plan gate
adopts).

## Notes added at the tasks stage

_(the tasks stage fills this)_
