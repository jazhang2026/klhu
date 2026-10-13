# Requirements checklist — 019 head tags

## What the spec claims, and how it was checked

- **Input, verbatim.** Item 018 of `text.txt` is quoted with the dated withdrawal note under it, the four chat
  lines are quoted as given, and every quoted line was **substring-checked against the spec file**, not read by
  eye. The first pass quoted the item's number as `018.` — the reader had already marked it `（old）` themselves;
  the stale quote was corrected in place on 2026-10-12 and all five list lines and four chat lines were
  substring-checked again. The quote of item 018 is the *withdrawn* item: the spec says so in the same paragraph,
  names which half of it is **not** this feature's input, and repeats the exclusion under Out of scope.
- **The number.** `create-new-feature.sh --dry-run --json` proposed **018** (it counts directories, and 018's
  directory was withdrawn on 2026-10-12); the reader named **019** in chat, so `--number 019` was passed. The
  spec's Input block says the same, and says **018 stays free**.
- **Counts.** 14 FRs (FR-001..FR-014), 5 SCs (SC-001..SC-005), 3 stories (US1/US2 P1, US3 P2), 12 acceptance
  scenarios (US1 6, US2 4, US3 2), 9 edge cases, 5 assumptions, 5 out-of-scope bullets, 8 decisions — counted by
  `spec_consistency.py` over the file, not by eye. **(Corrected 2026-10-13, after the reader's own amendment: the
  spec now carries 15 FRs, 7 SCs, 4 stories, 17 scenarios — US1 8, US2 4, US3 2, US4 3 — 12 edge cases, 5
  assumptions, 6 out-of-scope bullets and 11 decisions. The figures above are what this checklist read at the
  specify gate and are kept as that record; the current counts are the amendment's, below.)**
- **No `[NEEDS CLARIFICATION]`** anywhere: the reader's answers of 2026-10-12 and the two measured device facts
  (their content carries no `#`; 015's `displayOf` elides a tag's characters) settled what was open.
- **Every FR is testable without naming a UI**: FR-003/FR-004 are the two seams (elision and resolution) that
  already exist; FR-006 references `ReadingSize` because 011's contract owns the ladder and the spec must not
  invent a second one; FR-011 pins behaviour to 016's own unit rather than describing a new one.

## The answers this spec rests on (recorded 2026-10-12)

- **The reader's own scope answer**: `continue to 019（#/## 标题）` — the token `/continue` with the feature
  named. It answers the handback's question *"要不要顺带把行内强调 `**粗**`/`*斜*` 一起放进去"* with **no**: this
  feature is the two line marks only, and emphasis stays the item the withdrawal note in `text.txt` already
  reserved at roughly a third of the whole. The spec's Out of scope says so in those words.
- **Their earlier answer, carried**: `head 标签（#/##）我建议直接开 019 -- OK.` — the go for opening this feature at
  the number they named.
- **`The title of the content: Basic Spanish 1.`** — the sentence that made the two marks cheap: their title is
  *already* a line of its own, so a mark needs no block layer, only a rule for a line's first characters.
- **The line-scope question they asked and I answered** (`#`/`##` 只影响一行 —— 对，但有三条要钉死) is decision 2,
  and the three things that had to be nailed are FR-001 (the required space), FR-002 (`###`+ is text) and FR-008
  (the line, not the paragraph).

## What a reviewer should argue with

1. **The derived ladder is the feature's one hard limit.** Title two offered steps up, subtitle one, clamped at
   xlarge: at the ceiling the title cannot grow and the title/subtitle difference is weight alone (decision 3,
   SC-002). If the reader would rather have a title that is always bigger than the body, that requires breaking
   011's contract that the reader's chosen size is the size that renders — a different feature, priced as one.
2. **Both halves are P1 on purpose.** US2 (never spoken) could be argued down to P2 as "the read can follow"; the
   spec refuses that on the grounds that the app's primary surface is the read, so shipping US1 alone ships a
   voice saying "hash". A reviewer who disagrees is disagreeing with decision 8.
3. **The space requirement is load-bearing and cheap to lose by accident.** FR-001's one space is what keeps
   `#1 best`, `#hashtag` and `C#` as the reader's own text; an implementation that accepts `#Title` still passes
   US1's scenarios 1–5 and fails SC-003. Read SC-003 as the test that guards it.
4. **The feature's value is prospective, and that is honest.** The reader's own content carries no `#` today
   (verified off their phone on 2026-10-12), so nothing they already read changes; the feature exists for the
   documents they will write. The reviewer's fair question — *which of their texts will carry marks?* — is not
   answered by the spec and cannot be answered from the tree.
5. **Its interaction with the 2026-10-12 fix is the thing most likely to be got wrong.** The marker characters sit
   *inside* the heading line's sentence, so they must not be added to the step list (FR-011), must not become a
   comment's owner, and must not disturb the step count the reader's own content now has. The fixture from that
   fix (`test/step_ranges_test.dart`'s `readerContent`) is the regression set this feature must not move.
6. **Where the two seams are, and only there.** 015's display (`lib/comment.dart`, `displayOf`) elides a tag's
   characters today; the page's one style seam (`lib/reading_view.dart`, `_spanPaint`) is where 017 hooked the
   comment's size; the resolution (`lib/speech_resolver.dart`) is where a tag is kept from the engine. This feature
   adds a second kind of never-painted, never-spoken character inside those three, not a fourth pipeline.

## Notes added at the plan stage (2026-10-13)

**The reader's own amendment came at this gate, and it is the biggest thing this stage did.** Their ask —
*"可否把加粗字体 计入 大一号，大二号。及计算小一号等。扩充可用字体数"* — is answered in `spec.md`'s new
`## Clarifications` session and rewritten in FR-006/FR-007 (the **ladder**: the four offered sizes, then the
largest offered size at **bold** and at **black**), a new FR-015 with a new US4 (a comment's step down takes the
**weight first**), two new SCs (SC-006/SC-007) and three new edge cases. The plan's four artifacts were re-cut
with it, and the amendment's blast radius reaches **017**, a closed feature: its `tasks.md` gains a
`## Superseded by later specs` note and its `breakpoint.md` a dated section — its own rows stand, because its
fixture uses a regular face, and the new case is walked by this feature's row 8b. What did **not** move: the two
marks' spelling, the required space, the elision, the resolution, the video's rule, and 011's Appearance list
(the reader's own answer: *只扩派生用的档位（阶梯），不动 Appearance 列表*).

The four artifacts of the plan stage are written beside this file, and the checks below were re-run on them after
the amendment. `spec_consistency.py` → **15 FR · 7 SC · 4 stories · 17 scenarios · no divergent fence** (the
ladder's table is a fenced block kept byte-identical in `research.md` and `data-model.md`, which the checker
reports `IDENTICAL`); `check_quickstart_coverage.py` → **16 rows ([unit] 11, [device] 4, [structural] 1),
`unclaimed: none`, `no 'Proves' line: none`**; `check_artifact_refs.py` → **95 line references checked, 9
unresolved** *on this stage's four artifacts, before the tasks file landed* (its own run over the whole directory
now reports 97 and 13, the four extra citations being the files the tasks stage names as about to be created),
and every unresolved one is a citation of a file this stage is about to create (`lib/head_tag.dart`
×2, `test/head_tag_test.dart` ×2, `test/reading_view_head_test.dart` ×2) or of `lib/display.dart`, which exists
only as the **refused** alternative of `research.md`'s D7. `check-prerequisites.sh --json` lists this stage's whole
file set (`AVAILABLE_DOCS` = `research.md`, `data-model.md`, `quickstart.md`). **Every `spec.md:NN` citation the
four artifacts carry was re-anchored after the amendment moved the spec's lines** — the checker prints each
citation's real line, and each one now lands on the sentence it names.

**One sentence of this spec cannot be implemented as written; the other was resolved by the reader's own
amendment.** US1's scenario 4 (*"the title is distinguished by weight alone"*) was false under the rule as first
reviewed — FR-006 clamped **both** marks at the largest offered size and FR-007 made **both** bold, so at `large`
and at `xlarge` they were identical — and the reader's amendment of 2026-10-13 rebuilt the rule as the **ladder**,
which makes the amended scenario true (at `xlarge`: the subtitle at 24 **bold**, the title at 24 **black**) and
leaves one narrower limit, a body already on the ladder's last rung (a bold face at `xlarge`), named by SC-006 and
pictured by a row. `research.md` § Grounding corrections records both the old failure and the resolution. **What
still cannot be implemented as written is FR-002's trailing-`#`-sequence** (`# Title #`), which admits two readings;
the one implemented — the whole line is the reader's text — is the only one that satisfies SC-003's
"byte-identical today" for that very shape. Both are recorded with their `file:line`, and the spec's own sentences
for them are amended rather than left to be discovered.

**Reuse obligations the plan inherits (grepped, not remembered).**

- `lib/comment.dart:291-349` — the display's elision and its two mappings are **one** object; a mark is a second
  elided kind inside it, not a second elider (D1), and the type keeps its name for the 13 + 12 + 9 references a
  rename would touch (D7).
- `lib/reading_view.dart:2355-2390` (the cut set) and `:2396-2410` (the one style seam) — the page's paint is
  additive there, and the editor reaches the same style method (`:2461-2476`), so the reader's own text is
  untouched by construction (FR-010).
- `lib/video_painter.dart:591-608` — 017's single `commentStart` split becomes a cut set with the slot's own
  `headings`; a comment's characters keep 017's size where a marked line carries one (FR-012).
- `specs/015-comment-tag/data-model.md:174` — `ParagraphSpeech`'s field list is documented in **015's** record, so
  the new nullable `display` gets a dated correction there, in 015's own file (plan `ripple 1`).
- `lib/video_renderer.dart:274` and `test/video_comment_test.dart:45` — the **only two** call sites that pass
  `comments:` to `buildVideoPlan`; the parameter becomes the display and those two are re-cut (plan `ripple 3`).
- `specs/016-sentence-reading/scripts/klhu_walk_step.py:92-97` — the device drivers split their fixtures on a line
  starting with `## `, which is exactly a subtitle's own shape: this feature's fixture and driver must recognise a
  section header by its known keys, or the subtitle line is silently lost (plan `ripple 8`).
- `specs/017-bold-comment-size/quickstart.md:114-125` — 011 FR-012's width guarantee was re-measured there for the
  bold faces at `xlarge`; a mark never paints above `xlarge`, so this feature adds no measurement to it (plan
  `ripple 5`).
- `lib/l10n/app_*.arb` — **110** keys each, measured on 2026-10-13; this feature adds **none**, so no record's
  quoted count goes stale.

**The risks the plan carries**, each named where it lands (`plan.md` § Honest limits): the ceiling's identical
marks; the two-character re-flow of a marked line; iOS unverified on this host; a Chinese title's synthetic bold;
and a `#` inside a comment's span read aloud as written. The spike list is empty on purpose — the two facts this
feature would otherwise have had to prove (that a synthesised bold exists where no bold CJK face ships, and that
the frame's own derived size carries) are 017's measured facts, and the walk re-pictures rather than re-learns
them.
