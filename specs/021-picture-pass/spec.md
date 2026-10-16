# Feature Specification: The assignment pass's pictures, and the controls on them

**Feature Branch**: `021-picture-pass`

**Created**: 2026-10-15

**Status**: Draft

**Input**: The reader's wish list (`text.txt`), the item written there on their own instruction this stage, quoted
verbatim:

> 021. Assign sentences page: show the picture itself, and the controls on it.
>     1. On Assign sentences page, I like to see the picture not the file name, so I can better understand the picture and to match sentences.
>     2. On Assign sentences page, I like to be able to move the position of  an un-assigned picture.
>     3. On Assign sentences page, I like to be able to delete an un-assigned picture.
>     4. On Assign sentences page, an already assigned sentence should have the selection check box disabled for other pictures.
>
>     filename is useless on the UI, don't show it. Only show sentences number on top right of thumnail. the number change in real time.
>     one tap select the thumnail to assign sentences(the thumnail is highlighted). sentence list is showing below.
>     tap+hold show large picture below. the thumnail is highlighted. the sentence list is hidden. If no sentences assigned to this picture, show move buttons and delete button. when move or delete is heppen, show the real change on the thumnails.
>     use close button to close the large picture and show the sentences list.
>     the pictures chosen dialog page should have same UI and function on the large picture, move and delete button.
>     Since the move and delete only happen to the selected large picture, file name is not needed. switch happens on two closed pictured. not use file name is OK.
>     the selected thumnail auto scroll to the middle of thumnail bar.
>
>     (2026-10-15 修订，读者本人：第 4 条已推翻 —— 不用「勾选框禁用」，改成别的图持有的句子仍可点、
>      弹警告并确认后换手（switch）。本条的原文保留如上，撤销只在此处注明；规格里的记录见
>      specs/021-picture-pass/spec.md 的 Clarifications 第 4 条。)
>
>     Issues:
>     1. last sentence already assigned to previous picture still able to assign to following picture.
>         (2026-10-15 定：这是 020 自己的实现缺陷，不是新需求 —— lib/picture_assignment.dart:149-151
>          两处次序边界用了严格比较，邻居的最后一句因此被静默接受、落进两条 run，违反 020 自己的 FR-005。
>          修法归 020，与 021 的 switch 同一段代码路径。)

and the conversation that produced it, also quoted verbatim:

> changes:
> 1. On Assign sentences page, I like to see the picture not the file name, so I can better understand the picture and to match sentences.
> 2. On Assign sentences page, I like to be able to move the position of  an un-assigned picture.
> 3. On Assign sentences page, I like to be able to delete an un-assigned picture.
> 4. On Assign sentences page, an already assigned sentence should have the selection check box disabled for other pictures.
>
> Issues:
> 1. last sentence already assigned to previous picture still able to assign to following picture.

> 1B + 点 chip 弹大图预览(also add for chosen picture).
> 2. "长按 1.6s 再移动" get error msg: "This picture holds pictures ...". "直接拖动" is scroll.
> 3. pass 内删除即时生效. stay in "Assign" page. all delete should have worning/confirm msg box.
> 4. I changed my mind. I like to allow user select the assigned sentence(switch). The user will see a worning msg and must confirm the switch. the switch is completed after user's confirm.

**The number, and where this ask comes from.** `create-new-feature.sh` numbers by counting directories; its dry run
read **021** in `FEATURE_NUM`, which is the reader's own number in this conversation ("start specs/021!") — the two
agree, and the directory is `specs/021-picture-pass`. The wish list is the source of every earlier feature's
`Input`; it carried **no** 021 item when this stage began (its last entry was 020), the ask arrived in chat, and the
item above was written into `text.txt` on the reader's own instruction — so the list's own numbering is intact and
`Input` is the item, with the conversation quoted beside it.

**The revision of 2026-10-15, and what it overrules.** The reader's second message settles the surface this stage's
sketch had left open, and it overrules this stage's own first reading of `1B` in three places — recorded here
rather than edited away, because the first reading was argued in the handback and drawn in the sketch:

| this stage's first reading | what the reader settled | the neighbour it retires |
|---|---|---|
| the file name **de-emphasised** on the chip, 020's `FR-010` cited as the reason | **no file name painted at all**; the picture carries only its sentences' count, at the thumbnail's top right | the "name de-emphasised" chip and its cost line |
| **one tap** opens the picture full size | one tap **selects** the picture (its list appears below); **tap+hold** opens the large picture, below the bar | the full-size *overlay* on one tap |
| the move is a **control beside a drag**, and the drag's failure was to be designed around | the move and delete are **buttons in the large picture**, offered only when nothing is assigned; the drag is not part of the design at all | 020's own drag, and its `holdsSentences` refusal **on this page** |

**What already exists, and what this feature adds.** The pass and its rules are shipped and walked (020: the pass,
its two refusals, the split, the store, the render that walks the runs). This feature changes **what the pass looks
like and what the reader does to a picture**: the picture itself with a live count, a tap that selects, a hold that
opens the picture large with the two controls that act on it, and a **confirmed switch** of a sentence that belongs
to another picture — and it re-cuts two of 020's rules (its `FR-015` fallback half and, in effect, its drag) and two
of 012's (its immediate `Remove this picture`, and its reorder of a picture that carries sentences).

**The interface sketch.** `ui-sketch.html` beside this spec draws the surface **as the reader specified it** — the
thumbnail bar with the count at each thumbnail's top right, the selected one highlighted and centred, the sentence
list below it, the large picture with `Close` and (when nothing is assigned) the move and delete buttons, the
confirmation boxes, and the dialog's own surface — with the alternatives that were refused beside them, each with
its own cost line. The sketch is the record of that choice, not a second spec.

## Clarifications

### Session 2026-10-15 — the four changes, the answers, and the revision that settled the surface

1. **What a picture on the pass is.** **Decided by the reader, twice, and the second answer is the one in force
   (2026-10-15)**: a **thumbnail of the picture itself**, with **the count of the sentences it holds at its top
   right**, changing **as it changes**; **no file name painted** anywhere on the pass or on the dialog's own
   picture surface (FR-001, FR-002). **The alternatives recorded**: the reader's own earlier token `1B` as this
   stage first read it — the name de-emphasised on the chip — retired by their own revision the same day; (A) the
   name at full weight beside the thumbnail (refused: "filename is useless on the UI"); (C) keep the words and
   preview on tap (the preview survives, but as a **hold**, and the words do not). **What this costs, said
   plainly**: 020's stored record matches pictures **by file name**, and 020's own walk driver reads the pass's
   chips **by parsing that name** (`chip_line` in
   `specs/020-sentence-pictures/scripts/klhu_walk_assignment.py`), so removing the name from the page removes it
   from those rows' parser too — see the pointers below, where both ways out are named.
2. **Moving and deleting a picture the reader gave nothing — and the gesture's own end.** The reader's report of
   what the shipped gesture does ("the hold refuses with *This picture holds sentences…*; a plain drag is scroll")
   and their revision settle this between them: **the drag is not part of the design**. The pass offers **move
   buttons and a delete button inside the large picture**, and only when **the reader has assigned that picture
   nothing** — which is the reader's own words ("If no sentences assigned to this picture, show move buttons and
   delete button"), and it is also the honest reading of 020's rule: the fallback is an outcome of the render, not
   a decision of the reader, so it must not decide what the reader may do (FR-005, which re-cuts 020's `FR-015`).
   **The alternatives recorded**: keeping a drag as the only way (refused — the reader's two attempts are the
   evidence, and a gesture the platform's scroll axis wins is not a mechanism to build a rule on); the probe this
   stage offered for the gesture (offered, **not taken**: their own report answered it more directly than the probe
   would have); and designing around the fallback refusal (retired, because the buttons' own visibility now
   answers it — the fourth refusal's words have no surface left on this page, which the plan must record rather
   than leave as a string nobody can reach).
3. **Deleting.** **Decided by the reader (`3.`)**: it happens **inside the pass**, the reader **stays on the
   pass**, and **every** delete asks first — the dialog's own `Remove this picture` included, which today removes
   immediately. **The alternatives recorded**: (A) the delete only in the dialog (refused: "stay in Assign page");
   (B) mark it and apply on `Done` (not refused, but "即时生效" is what they said, and the confirmation is what
   makes immediate safe); (C) no confirmation (refused: "all delete should have worning/confirm msg box").
4. **A sentence another picture holds — the switch.** **Decided by the reader (`4.`, a reversal of the answer
   this stage first offered)**: the sentence stays selectable; the tap proposes a **switch**, the reader is warned
   which picture holds it now and which would hold it, and the switch completes only on confirmation. **The
   alternative recorded and refused**: option A of the question this stage put (the checkbox disabled for other
   pictures) — retired by the reader's own reversal; it answered the *defect* by preventing the edit, where they
   want the edit **confirmed** instead. **What the confirmation is about**: taking the sentence **away from the
   picture that holds it**. **What it is not**: a waiver of the two rules that keep a render walkable — a switch is
   offered only when the sentence is an **end** of its holder's run (020's own `FR-016`: a middle one would leave
   that picture's sentences in two) and when the picture taking it ends **continuous and in order** (FR-015).
   **How the confirmation names the pictures, now that names are gone**: by **the pictures themselves** (FR-014) —
   the reader's own "switch happens on two closed pictures. not use file name is OK" is the instruction, and the
   box shows both thumbnails.
5. **The defect under *Issues* — what it is, where its fix lands.** The reader's report is exact and the tree
   confirms it: **a sentence another picture holds can be taken by a later picture**. `refusedAdd` tests its two
   order boundaries with a strict comparison (`lib/picture_assignment.dart:149-151`): with white holding sentences
   1-4 and black holding 5-7, a tap on white's **last** sentence while black is selected passes both tests
   (`index < held.last` is false at equality, and the continuity test measures against black's own first sentence,
   which the tapped one is adjacent to), so the sentence is written into **both** runs — 020's own `FR-005` ("a
   sentence MUST belong to at most one picture") broken by 020's own implementation, and broken **silently**:
   `assignmentsFor` resolves the shared sentence to the **later** picture, so the earlier picture's count no longer
   matches what its run holds. No walked row covers the shape — row 7 refuses a non-adjacent sentence and one
   before an earlier run, row 9's subject is the drag — which is why a shipped, receipted feature carries it.
   **Where the fix lands, this spec's recommendation**: the **boundary fix is 020's** (its implementation
   contradicts its own `FR-005`; no requirement of 020's moves), fixed **with** this feature's switch because the
   switch is the same code path — the boundary case becomes the **confirmed** move this spec specifies, and every
   non-confirmable variant is refused by the rule. **The fallback, if they want the defect closed first**: fix it
   alone, on 020's tree, with its own RED case and a re-walked row, before this stage's artifacts exist.
6. **The selected picture's own place.** **Decided by the reader**: the selected thumbnail **auto-scrolls to the
   middle of the thumbnail bar** (FR-007) — the bar is longer than the screen once a few pictures are chosen, and
   the reader's own reason is that the picture they are working on must be the one they are looking at.
7. **Where the app's own count words live.** **Decided by the reader (2026-10-15: "N sentences / No sentences
   assigned -- can be under large picture")**: the thumbnail's top right carries **the number alone**, and the
   app's existing words sit **under the large picture**, where the reader is looking at the picture the number
   belongs to (FR-019). **The alternative recorded**: keep the words on the thumbnail as well (refused — it is the
   text the reader asked to be rid of), and drop them entirely (refused: 020's own strings would then have no
   surface anywhere, and a number with no words is what the reader asked for only *on the thumbnail*).
8. **The dialog's own surface.** **Decided by the reader**: the picture-chosen dialog gets **the same surface and
   the same functions** — hold → large picture, `Close`, and the same move and delete buttons under the same
   "nothing assigned" rule (FR-010). **What it re-cuts, said plainly**: 012's own reorder lets **any** chosen
   picture be moved (its own reorder rule); under this rule a picture the reader has given sentences to offers no
   move, so that half of 012's rule is superseded for the assigned case — recorded as a pointer, with 012's
   artifacts left as written.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The reader sees the picture and gives it sentences (Priority: P1)

The pass shows the reader's pictures as pictures, each carrying the count of the sentences it holds; one tap
selects one and its sentences appear below, ready to be given to it and taken back.

**Why this priority**: it is every visit to the pass — the reader's own reason is "so I can better understand the
picture and to match sentences" — and the count at the top right is what tells them what they have done.

**Independent Test**: on the device, open the pass with three pictures: each thumbnail carries the picture and its
own count at its top right; tapping one highlights it, shows its sentences below, and assigns a sentence whose
count appears on the thumbnail on the same tap.

**Acceptance Scenarios**:

1. **Given** the pass open with three pictures and nothing assigned, **When** the reader looks at the bar, **Then**
   each thumbnail shows the picture itself and `0` at its top right, and **no file name is painted** anywhere.
2. **Given** that bar, **When** the reader taps a thumbnail, **Then** it is highlighted and the sentence list below
   is that picture's own — every sentence of the render's list, in order, with the ones it holds marked.
3. **Given** a selected picture, **When** the reader taps a sentence, **Then** the sentence is given to it (or
   taken back) and the count on that thumbnail changes **on the same tap**.
4. **Given** a picture holding sentences, **When** the reader selects it, **Then** the list shows exactly those and
   the sentences another picture holds are marked with **which** picture holds them (by the picture, not a name).

---

### User Story 2 - Looking at one picture closely, and changing the set (Priority: P1)

A thumbnail is too small to tell two pictures apart, and a picture the reader has decided against has to leave (or
move) — both without walking back to the dialog.

**Why this priority**: the two things the reader asked for after seeing the picture (move, delete) can only be
done where they can see it, and the reader's own answer is "stay in Assign page".

**Independent Test**: hold a thumbnail: the large picture appears below with the list hidden and `Close`; a picture
holding nothing offers move and delete there; moving swaps them on the bar at once; deleting asks, and cancel
leaves the renderer's own line identical.

**Acceptance Scenarios**:

1. **Given** the bar, **When** the reader holds a thumbnail, **Then** that picture is shown **large below the
   bar**, the held picture highlighted, the sentence list hidden, and a `Close` control offered.
2. **Given** that large picture and **nothing assigned to it**, **When** the reader looks below it, **Then** the
   move controls and the delete control are offered.
3. **Given** a large picture with a sentence assigned to it, **Then** no move and no delete control is offered.
4. **Given** the large picture, **When** the reader moves the picture, **Then** the bar shows the new order at
   once; **When** the reader deletes it and confirms, **Then** the bar shows one picture fewer at once and the
   reader is still on the pass.
5. **Given** the delete's confirmation, **When** the reader cancels, **Then** the pictures, the order, the counts
   and a render's own line are exactly as they were.
6. **Given** any of the above, **When** the reader taps `Close`, **Then** the large picture goes and the sentence
   list is back, with the same picture selected.

---

### User Story 3 - A sentence that is on the wrong picture (Priority: P2)

A sentence already belongs to a picture and the reader wants it on the picture after it. Today that tap is either
refused or — at the boundary the reader reported — silently accepted into **both** pictures.

**Why this priority**: it is the reader's own reversal of the answer they first gave, and the shape their report is
about; P2 rather than P1 because the pass is usable without it (take the sentence back first, then assign it), and
because it changes a rule 020 settled.

**Independent Test**: with white holding sentences 1-4 and black 5-7, tap sentence 4 with black selected: the
warning shows **both pictures**, cancel leaves both runs and the renderer's line identical, confirm leaves white
1-3 and black 4-7.

**Acceptance Scenarios**:

1. **Given** a sentence at the **end** of another picture's run and a picture selected that can take it
   continuously and in order, **When** the reader taps it, **Then** a confirmation appears showing **both
   pictures** — which holds it now and which would hold it.
2. **Given** that confirmation, **When** the reader cancels, **Then** nothing moved.
3. **Given** that confirmation, **When** the reader confirms, **Then** the sentence is the selected picture's, the
   picture it left no longer holds it, and the page's counts sum to the content's sentence count.
4. **Given** a sentence in the **middle** of another picture's run, **When** the reader taps it, **Then** it is
   refused with the middle-of-run words, and no confirmation appears.
5. **Given** a sentence whose switch would leave the taking picture's run not continuous or its order wrong,
   **When** the reader taps it, **Then** it is refused with that rule's own words, and no confirmation appears.

---

### Edge Cases

- **A sentence is never in two runs**, after any sequence of taps, confirms and cancels: the counts sum to the
  content's sentence count and a render's `ranges=` meet without overlap (FR-013).
- **Two picks with one file name**: nothing on the page distinguishes them by name any more, so the pass's own
  order and the pictures themselves are what the reader works with; the record still matches by name (020's
  `FR-010`), and a name that never comes back is a `stale` run and 020's own warning, not this page's.
- **A picture whose last sentence left it** holds nothing, so its large picture offers move and delete in the same
  visit.
- **The selected picture moves out from under the reader**: after a move the bar re-centres on it (FR-007).
- **Deleting down to no picture**: the dialog then holds no pictures and no runs; the no-picture render is 012's
  own case and is not changed here.
- **A picture deleted, then the same file chosen again**: its stored run is gone (the delete writes the record).
- **The count of a picture the render's fallback would feed**: the count shows **what the reader assigned**, never
  the fallback — the fallback is an outcome of the render (020's own distinction), and the count is the reader's
  own record of their work.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pass MUST show each picture in force as a **thumbnail of the picture itself**, carrying **the
  number of sentences it holds at the thumbnail's top right**, and that number MUST change **as the reader
  changes it** — the tap that gives or takes back a sentence is visible on the thumbnail immediately.
- **FR-002**: No **file name** MUST be painted on the pass or on the dialog's own picture surface: the picture and
  its count are what the surface carries.
  **Decided by the reader (2026-10-15, "FR-002 不画文件名 -- a")**: the name stays as each picture's own
  **semantic label** — not painted, and therefore what keeps a screen reader, and 020's own walk driver, able to
  name the picture (that row parser is named in the pointers). The alternative — carrying no name at all — is
  recorded as refused: it re-cuts 020's rows 6-11 and 16 for no reader-visible gain.
- **FR-003**: One **tap** MUST select a picture: the thumbnail is highlighted and the sentence list below shows
  **that picture's** sentences — the render's own list, in order, with the ones this picture holds marked and the
  ones another picture holds marked with **which** picture.
- **FR-004**: A **hold** MUST open the held picture **large, below the thumbnail bar**, with the sentence list
  hidden while it is open and a **`Close`** control that returns to the list with the same picture selected.
- **FR-005**: The **move** controls and the **delete** control MUST be offered **only in the large picture** and
  **only when the reader has assigned that picture nothing** — the render's own fallback MUST NOT decide it (this
  re-cuts 020's `FR-015`, whose refinement of 2026-10-13 counted the fallback).
- **FR-006**: A move or a delete MUST be reflected **on the thumbnails at once** — the new order, or the picture's
  absence — and every count MUST stay truthful to the record.
- **FR-007**: The **selected** picture MUST be scrolled to the **middle of the thumbnail bar** when it becomes
  selected, and again when a move or a delete changes the bar under it.
- **FR-008**: Every delete MUST ask first, in a confirmation that names the picture **as the picture** (FR-014),
  and cancelling MUST leave the pictures, their order, the counts and the stored record exactly as they were.
- **FR-009**: Confirming a delete MUST take the picture out of the pictures in force, out of the pass's order, and
  out of the stored assignment for that content.
- **FR-010**: The dialog's own chosen pictures MUST offer **the same surface and the same functions**: hold →
  large picture, `Close`, and the same move and delete controls under the same rule (FR-005).
- **FR-011**: A tap on a sentence another picture holds MUST NOT be refused silently: where the switch is legal it
  MUST be proposed for confirmation, and the confirmation MUST show **both pictures** — which holds the sentence
  now and which would hold it.
- **FR-012**: A switch MUST complete **only** on confirmation; cancelling MUST leave the stored runs and a render's
  own `ranges=` line identical.
- **FR-013**: A sentence MUST belong to **at most one** picture at every moment — in the stored runs, on the
  page's counts, and in the render's ranges. (020's `FR-005`, restated because 020's implementation breaks it at
  the boundary: `lib/picture_assignment.dart:149-151` refuses only strictly inside another picture's run, so the
  boundary case is accepted. The boundary MUST be refused.)
- **FR-014**: Every confirmation this page shows MUST name what it is about **by the picture itself** (the same
  thumbnail), never by a file name.
- **FR-015**: Every other rule 020 shipped MUST keep its behaviour and its own words **where it still has a
  surface**: continuity within a picture, order across pictures, and the middle of a run. **The holds-sentences
  refusal has no surface left on this page** (the controls are simply not offered) — the plan MUST record where, if
  anywhere, that string is still reachable, rather than leave a string nobody can reach.
  **Where the holds-sentences refusal is still reachable (recorded 2026-10-15, this feature's own decision)**: the
  pass answers "this picture holds sentences" by **not offering** the controls at all (FR-005), so
  `AssignmentRefusal.holdsSentences` — 020's own reason, and the string `assignmentRefusedHoldsSentences` that names
  it in four languages — is returned by **no rule this page calls** any more: `refusedAdd`, `refusedRemove` and
  `refusedSwitch` between them answer a tap, and none of them says this. The value stays because the enum is the
  rules' own vocabulary and the page's reason mapping is exhaustive over it, and the key stays in the four ARBs
  because removing a key moves the counts four structural receipts quote (this feature's own row 16 among them).
  What it would cost to make it reachable again: showing it on a hold of a picture that holds sentences (a
  `SnackBar`, as the pass did before the controls existed) plus a device row to read it — not this feature's, and
  named here rather than left as a string nobody can reach.
- **FR-016**: What the pass answers MUST remain the draft the dialog applies — the pictures in the reader's own
  order and the runs that go with them — and the render's fallback MUST still never be written into the record.
- **FR-017**: Every new string MUST exist in all four ARBs, be generated, and pass the key check in both
  directions.
- **FR-018**: This feature MUST add no dependency, no new stored key, and no network call.

- **FR-019**: The count on a thumbnail MUST be **the number alone** (the reader's own words: "Only show sentences
  number on top right of thumnail"), and the app's own words for it — `N sentences` / `No sentences assigned` —
  MUST live **under the large picture** (decided by the reader, 2026-10-15: "can be under large picture").

### Key Entities

  **What a count counts, settled by the reader's own report of 2026-10-15**: a number beside the pictures — on a
  thumbnail's badge and on the prompt's own assignment line alike — counts the reader's sentences **in force**, i.e.
  for the pictures in front of them, and never the stored record's own total. Their steps: pick three pictures,
  assign, `Cancel`, open the prompt again — no pictures, and the line claimed the record's sentences. The record
  itself is **taken away by the cancel** (the reader's own decision of the same day, in answer to the first fix:
  "Cancel 之后记录本身就清掉（包括再选同样文件也不恢复）"), so picking the same files again brings nothing back; 020's own
  rule (the assignment outliving the prompt) narrows to a visit that ends in Start.
- **A picture on the pass**: the picture in force (its name and its copy's path), its thumbnail, its own count,
  and its place in the order the render walks.
- **The reader's runs**: `PictureRun`'s record, one per picture, unchanged in shape (020's `data-model.md` §1-§3).
  This feature changes which edits may produce one, not what one is.
- **The large picture**: the held picture at full size, with the two controls that act on it; it carries no state
  of its own.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the device, each thumbnail carries the picture's **own pixels** and its count **at the top
  right**; no painted label on the page carries a file name (a dump's labels are read for it).
- **SC-002**: One tap on a thumbnail highlights it, shows its sentences below, and the count on that thumbnail
  changes on the same tap that assigns a sentence — read off two dumps taken around one tap.
- **SC-003**: A hold shows the picture large below the bar with the sentence list hidden, and `Close` brings the
  list back with the same picture selected — two stills and the dump's own labels.
- **SC-004**: A picture with nothing assigned offers the move and delete controls in its large picture; a picture
  with a sentence assigned offers neither — a still of each.
- **SC-005**: Moving a picture changes the bar's own order at once and the renderer's own `ranges=` follows it with
  no other range moving — 020's row 9's shape, re-walked on the buttons.
- **SC-006**: Deleting asks; cancelling leaves the renderer's own line **identical** and the app's library
  untouched; confirming names one picture fewer in that same line.
- **SC-007**: The selected thumbnail's own box sits at the **middle** of the bar (measured off the dump's own
  bounds), after selecting the first picture, the last, and one in between.
- **SC-008**: The dialog's own surface offers the same hold, large picture, `Close`, move and delete — a still, and
  the same "nothing assigned" gating.
- **SC-009**: The switch's confirmation shows **both pictures**; cancelling leaves the runs and the renderer's line
  identical; confirming moves **exactly** that sentence (the ranges against the renderer's own per-sentence
  frames) and leaves the counts summing to the content's sentence count.
- **SC-010**: No sentence is in two runs after any sequence of taps: the counts sum, the ranges meet without
  overlap, and the boundary case the reader reported is refused — measured on the device and asserted in the
  suite.
- **SC-011**: `flutter analyze` clean; the suite's count against 020's closing **782** with the difference
  decomposed by file; the four ARBs' key parity green.

## Assumptions

- **The file name stays as the chip's own semantic label** (FR-002, decided 2026-10-15): it is not painted, and it
  is what keeps a screen reader, and 020's own walk, able to name the picture. The alternative — no name anywhere —
  is recorded as refused at the pointers below.
- **The reader's own report came from their phone; the walk runs on `emulator-5554`.** Both observations (the
  hold's refusal, the plain drag scrolling) are explained by the tree, so the rows can be walked here.
- **The thumbnail's decode stays bounded**: a phone photo is many megapixels and the dialog's own thumbnails
  already bound theirs (`lib/reading_view.dart:3003-3030`, `cacheWidth: 144`); the large picture is the only place
  a picture is decoded large.
- **The count shows the reader's own record**, never the render's fallback (which is an outcome of the render), and
  it is the same number the record's own runs hold.
- **One story per visit is not required**: a picture may be moved, then deleted, then its file chosen again, in one
  visit; the record is written when the pass is accepted (020's `FR-010`).
- **The evidence-first stills must be re-taken**: the 020 walk's own stills are gone from `/tmp`, so the first row
  of this feature's walk takes them again, on the same fixture, **before** any code changes.
- **Nothing is owed to `text.txt`'s numbering**: the `021.` item is written, dated, and the reversal inside it is
  marked there rather than left for a reader to re-derive.

## What this feature supersedes, and the pointers it owes

- **020's `FR-015`, its fallback half.** 020's refinement of 2026-10-13 made a tail-fed picture count as holding a
  sentence, so it refused the move; the reader's own report is what that rule does to them, and FR-005 re-cuts it.
  The pointer is one bullet in `specs/020-sentence-pictures/tasks.md`'s `## Superseded by later specs`, naming
  FR-005 and the sentence of 020's spec it falsifies.
- **020's own walk, whose parser reads the pass by file name.** `chip_line` in
  `specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` reads a chip as `<name>\n<count>`, and rows 6, 7, 8,
  9, 10, 11 and 16 read chips that way; FR-002 removes the painted name. **The reader picked (a) on
  2026-10-15**: the name is kept as the chip's **semantic label** — invisible on the page, and 020's own parser
  keeps reading chips by name, so those rows' receipts stand and their evidence is re-taken on this tree. **(b)**
  — the parser re-cut to read the count off the badge, with every receipt re-taken — is recorded as refused. 020's
  `breakpoint.md` is left as written either way.
- **020's `FR-005`, and the implementation that broke it.** FR-013 restates it; the fix is 020's own
  (Clarifications item 5), carried by this feature's switch so the boundary case has one behaviour rather than two.
- **012's `Remove this picture`, its immediacy** (FR-008 makes it ask), **and its reorder of a picture that carries
  sentences** (its own reorder rule allows moving any chosen picture; FR-005/FR-010 offer the move only when the
  reader has assigned it nothing). The pointers go in `specs/012-reading-video/tasks.md`'s `## Superseded by later
  specs`, and 012's artifacts are left as written.
