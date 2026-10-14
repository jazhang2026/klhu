# Requirements checklist — 020 sentences assigned to pictures

## What the spec claims, and how it was checked

`python3 …/spec_consistency.py specs/020-sentence-pictures`, on the spec as written:

    FRs            12  (spec.md)
    SCs             6  (spec.md)
    stories         4  (spec.md)
    scenarios      12  (spec.md)    3 / 3 / 3 / 3, one run per story
    bullets in "User Scenarios & Testing *(mandatory)*": 6      (the edge cases)
    bullets in "Requirements *(mandatory)*": 14                (12 FRs + 2 key entities)
    bullets in "Success Criteria *(mandatory)*": 6
    fenced blocks kept in more than one artifact: no divergence

`python3 …/check_artifact_refs.py specs/020-sentence-pictures` → `checked 0 line references`, `no unresolved
references`. The spec cites no file of the tree by line, which is why that count is zero: every claim in it is
about behaviour, and the two things it does name (`text.txt`, 012's own video) are named by their own names.

**Every count above is the checker's, not a recollection.** One number it reports is **not** usable and is not
quoted here: its `assumptions` line reads `0` although the spec carries four assumption bullets — the checker's
pattern wants a different shape than the prose uses. The section is what matters; the count is not claimed.

## The answers this spec rests on (recorded 2026-10-13)

The reader's own words (`text.txt`, quoted verbatim in the spec's Input) fix four things and leave three open. The
open three were put at this gate and answered in the spec's `## Clarifications` section, so no plan invents them:

| question the reader's words leave open | the answer taken, and what it costs |
|---|---|
| what "0 sentences on a picture" shows on screen | the picture is displayed as a still (FR-007) — the plan fixes its duration |
| what a sentence with no picture shows | the picture before it stays (FR-006) — the read is never truncated |
| where the assignment is made | on the video screen, beside the pick (FR-001) |

## What a reviewer should argue with

1. **FR-007 gives a picture the reader assigned nothing a place in the video.** The reader's words do allow 0
   sentences; they do not say the picture is *shown*. The other reading — skip it — is cheaper and makes "0" mean
   "chosen but unused". If a still moment is not what the reader wants, this is the row to overturn, and it is the
   only decision in this spec that changes what the video looks like for an untouched picture.
2. **"Sentences assigned must be in order" is read as an order *across* pictures** (FR-004: no picture may hold a
   sentence that starts before an earlier picture's last). The weaker reading — each picture's own run is ascending
   — would let picture two carry sentences 1 and 2 while picture one carries 8, which is not a video anybody can
   play. If the reader meant the weaker one, FR-004 is where to say so.
3. **The picture order is left to the plan** ("display selected pictures from first to last" does not say whether
   that order is the picking order or one the reader sets). The spec requires only that the order be **visible to
   the reader before they assign** (the edge cases). A reviewer who wants the reader to reorder pictures is asking
   for a second feature.
4. **What happens when the content's sentences change under an assignment** is stated as a requirement on the
   *outcome* (a run that no longer fits is dropped, the reader told, the rest stands) and leaves the telling to the
   plan. The opposite reading — keep the assignment and let it slide over new sentences — is what the spec refuses.
5. **SC-003 is the one criterion that can be checked without the new control being touched at all**: 012's own
   device row, re-run with pictures chosen and no assignment, must agree frame for frame. If it does not, this
   feature broke a shipped one, whatever the new tests say.

## Notes added at the plan stage

_(none yet)_

## Amendment, 2026-10-13 — the reader's answers at the gate

The gate asked; the reader answered; the spec was amended in place with the date on it. The counts above were true
when they were written and are left as they were — this is what moved:

    1. "0 sentences on a picture"       -> SKIPPED, not a still  (the reader overturned this spec's first answer:
                                           "「0 句」图干脆跳过吧，理解成用户不想用")
    2. a sentence with no picture       -> the picture before it stays (unchanged)
    3. where the assignment is made     -> the video screen, beside the pick (unchanged)
    4. can a made video be changed?     -> the assignment is a STORED SETTING, not part of a video: every render is
       the reader's own question           a fresh render and a written file is never edited. When the sentences
                                           changed under an assignment it is re-read against them, what no longer
                                           fits is dropped with the reader told, the rest stands.

    counts after the amendment    FRs 14 (was 12) · SCs 7 (was 6) · stories 4 · scenarios 12 · edge cases 6
    what was added                FR-013 (the assignment is a setting, never a part of a file) ·
                                  FR-014 (re-read against changed sentences, nothing assigned the reader did not) ·
                                  SC-007 (survives a render and a relaunch; a second render differs exactly where
                                  the assignment differs) · Out of scope: editing a video already written

    review point 1 above is CLOSED (the still was overturned). Points 2, 3 and 4 stand as written. In point 3's
    place there is a new open shape, and it is the plan's to settle **with the reader**: which of the three layouts
    in `ui-sketch.html` the pass takes — (A) a line in the dialog opening a full-screen page, (B) the runs expanded
    inside the dialog, (C) assigning after a render. FR-001 fixes only where the pass lives, not its shape, and the
    sketch was asked for by the reader before the plan.

## Amendment 2, 2026-10-13 — the layout, and the stale assignment

The reader's second answer at the gate, in their own words: *"选 A"* and *"句子变了，渲染前提示，可以点击进入改分配"*.

    the layout                 (A) one line in the dialog, opening a full-screen assignment page — decided, and the
                               sketch beside this checklist marks it. (B) expanded runs inside the dialog and
                               (C) assigning after a render are the recorded alternatives.
    the stale assignment       the warning now comes BEFORE the render's own line and is TAPPABLE: it opens the
                               assignment page on the offending picture (FR-014, rewritten), with User Story 5 and
                               SC-008 as its checks. What was FR-014 before — a telling after the fact, with the
                               edges left to the plan — is what the reader's refinement replaced; the alternative
                               (warn in the render's own result) is recorded in the decisions table.

    counts after this amendment  FRs 14 · SCs 8 · stories 5 · scenarios 15 · edge cases 6 · decisions 8
    review points               1 CLOSED (the still was overturned) · 2 and 3 stand · 4 stands, now with a shape
                                (a pre-render warning that leads somewhere, not a message)

**The plan's own open shapes are now smaller, not gone**: the assignment page's own layout inside (A) (how a
picture's run is shown and edited), the warning's own wording, and the picture display order ("first to last" is
still the plan's to pin, per review point 3).

## Amendment 3, 2026-10-13 — the unassigned tail, and the pass's own gestures

The reader's refinement of their own two rules, quoted: *"not assigned sentences default assigned to the previous
picture … 当后面的句子都没有分配图，而且后面还有图没有分配句子，沿用现在的方法：平均分配句子给没有句子的图"* and
*"当前选中的图可以用拖改顺序。没有分配句子的图可以拖，图上已分配的句子可以解除分配"*.

    the unassigned tail   FR-006: when the sentences after the last assigned one are unassigned AND pictures with
                          nothing assigned remain after it, those pictures take them by 012's own even split
                          (`buildPictureSchedule`) — so a tail is not one long hold on the last assigned picture.
                          FR-007 gains its "unless": a picture with nothing assigned is skipped **unless** the
                          fallback feeds it.
    the pass's gestures   FR-015 (drag a picture to change the walk's order; an unassigned picture is draggable
                          like any other) and FR-016 (un-assign: always at either end of a run, refused in the
                          middle with the reason, because a split run is what the reader's own contiguity rule
                          forbids).

    counts after this amendment  FRs 16 · SCs 8 · stories 5 · scenarios 17 · edge cases 6 · decisions 12
                                  (the checker's own numbers after the repair below, not a hand count)
    review points               1 CLOSED · 2, 3 stand (`movePicture` exists, but the pass owns the drag now, so the
                                order is decided where the assignment is made) · 4 stands, with its shape

**One reading of the reader's words to confirm with them**: "没有分配句子的图可以拖" is taken as *draggable like any
other picture* (so the pass keeps it visible and reorderable, and only the render skips it). If it means "drag it off
the list to drop the picture", that is a removal the pass does not have yet and the spec does not ask for.

**A defect in the amendment above, caught and repaired the same minute**: two of the replacements that wrote this
section's spec edits used a `\1` backreference inside a lambda, which Python takes literally — so FR-014's whole text
and the stale-assignment decision row were each replaced by the two characters `\1`. The checker's FR count (15
where 16 was intended) is what surfaced it; both were restored from the text as written, and the counts above are the
checker's own run after the repair. This is the second time this pass has made the same mistake in the same way.

## Amendment 4, 2026-10-13 — the drag is for pictures that hold nothing

The reader's own correction of the amendment above, quoted: *"应该是 只有没分配到句子的图能改顺序。分配了句子图的不能改顺序。
必须等分配的句子解除后才可以改顺序"*. Amendment 3 had it as "any picture can be dragged".

    FR-015 now reads  only a picture with **nothing assigned** may be reordered; a picture carrying sentences
                     refuses the drag with the reason until its sentences are un-assigned (FR-016) — and so does a
                     picture the unassigned tail falls back to (FR-006), because moving it would change which
                     pictures the tail falls to.
    SC-009 / SC-010  the new criteria for it: a drag changes the walk's order and nothing else's range; a picture
                     holding sentences refuses and the order stands.

    counts after this amendment  FRs 16 · SCs 10 · stories 5 · scenarios 17 · edge cases 6 · decisions 12

**Why the rule is the right shape, not just the reader's preference**: the pictures' order and the sentences' order are
the same order. A picture that holds sentences therefore has a *place fixed by its sentences*, and letting it move
would either re-order the reader's sentences or leave the run where it was — both of which are things this spec
forbids elsewhere. An unassigned picture holds nothing, so it can go anywhere without touching a sentence; the rule
falls out of FR-003/FR-004 rather than sitting beside them.
