# Specification Quality Checklist: A bold face, and a comment one size down

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-12, at the review gate that follows the spec, with every count below taken from the file as
it stands (`spec_consistency.py`'s own run is quoted in the Notes)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — file names, enum values and line numbers appear
      only in the `Input` quotes, the "what this changes in the features already shipped" block and this
      checklist's Notes, where they are the evidence for a decision ("what the app already does"), never a design
      instruction; every FR names an observable (what the picker lists, what the page paints, what a restart
      restores, what a tap selects)
- [x] Focused on user value and business needs — the reader's own two wish-list lines, quoted verbatim in `Input`,
      plus the two chat sentences that settle the shape of the bold option and the smallest-size case
- [x] Written for non-technical stakeholders — the appearance control, the font list, the preview, the reading
      text, a comment, a video frame; no widget, store, key or function is named as a decision
- [x] All mandatory sections completed — header (Feature Branch / Created / Status / Input), the
      what-this-changes block, User Scenarios & Testing, Edge Cases, Requirements + Key Entities, Success
      Criteria, Assumptions, Out of scope, and the decisions section this spec carries in place of a `research.md`

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c 'NEEDS CLARIFICATION' spec.md` → 0). The two
      questions the shape rested on were answered by the reader before this file was written: the bold option is
      an entry in the **font list** ("在 Appearance 选字体时 有一个加粗字体的选项"), and the comment's smaller size
      must be a **visible difference** ("有区别"), which is what makes the smallest-size case a derived value
      rather than a no-op
- [x] Requirements are testable and unambiguous — each FR names an observable: what the list offers (FR-001),
      what is painted on the page and in the frame (FR-002), what the preview shows (FR-003), what a restart
      restores and that the grammar does not move (FR-004), the three content languages (FR-005), the width
      guarantee re-measured (FR-006), the page's comment size (FR-007), the frame's (FR-008), the smallest-size
      case (FR-009), the offsets that must not move (FR-010), the no-comment no-regression (FR-011), the picker
      that must not appear (FR-012), and that nothing is installed (FR-013).
      **13 FRs, 6 SCs, 2 stories, 10 acceptance scenarios (US1 5, US2 5), 8 edge cases, 6 out-of-scope bullets,
      5 decisions, 5 assumptions** — the FR/SC/story/scenario counts are `spec_consistency.py`'s own run; the
      edge-case, out-of-scope, decision and assumption counts are counted by script over the file, because the
      checker's `assumptions` pattern counts its own `A<number>`-bullet shape, which these specs do not use (it reads **0** for
      this file's five plain bullets and for 016's four, so the number beside the claim is the hand count)
- [x] Success criteria are measurable — the preview before applying and no restart needed (SC-001), the face after
      a restart with no line clipped at the largest size (SC-002), a **measured** comparison of a comment's
      characters against the text's at each of the four sizes (SC-003), the same tap selecting the same sentence
      (SC-004), the frame's own measurement (SC-005), and the structural half (SC-006)
- [x] Success criteria are technology-agnostic — "a reader can see it before applying it", "measures smaller",
      "the same sentence is selected"; no store, key, type or function is named as a criterion
- [x] All acceptance scenarios are defined — US1: 5, US2: 5 (10 in total), each Given/When/Then, each
      independently demonstrable
- [x] Edge cases are identified — 8, including the four that decide the feature's feel: the smallest offered size
      (where "one smaller" has to be derived and must still be visible), the comment's own legibility floor, the
      video block whose measurements 015 already holds, and a **Chinese word under the bold face** (the device
      ships no bold CJK face, so the platform's synthetic weight is what paints it — FR-005's glyph coverage
      holds, the look is the walk's receipt)
- [x] Scope is clearly bounded — the Out of scope list (markdown, a weight toggle, a comment-size picker, 015's
      and 016's own settings, the content's characters) plus the assumptions that keep both changes contained
- [x] Dependencies and assumptions identified — 5 assumptions, each with its reason, and the two that rest on
      another feature's shipped rule naming that rule's id (011 FR-012/FR-013/SC-004/SC-005, 015 FR-012/FR-013/
      its no-dependency rule and its frame receipt)

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001/FR-003 → US1 scenario 1; FR-002 → US1
      scenario 2; FR-004 → US1 scenarios 3-4; FR-005/FR-006 → US1 scenario 5 and SC-002; FR-007/FR-009 → US2
      scenarios 1-2; FR-008 → US2 scenario 3; FR-010 → US2 scenario 4; FR-011 → US2 scenario 5; FR-012/FR-013 →
      the structural half
- [x] User scenarios cover primary flows — the bold face (P1) and the comment's size (P2), in the reader's own
      order, because the second is the one that moves a measurement another feature holds
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — the mechanics both changes rest on (the face enum, the
      record's grammar, the page's span tree, the frame's block layout) appear only in the cost lines, the
      what-this-changes block and this checklist's Notes

## Notes

**The reader's own words, and what each one binds.** "*add bold font option in Appearance selection.*" → FR-001,
and the chat sentence that followed fixes its **shape**: an entry in the font list, not a switch beside the
picker (decision 1). "*make comment is always one smaller size than the text if possible.*" → FR-007/FR-008, and
"**有区别**" fixes the case the wish list's own "*if possible*" left open: at the smallest offered size the
comment must still be **visibly** smaller, so the size is derived rather than absent (decision 2). The two lines
were quoted mechanically — every line substring-checked against `text.txt`, not compared by eye.

**The number, and the line the wish list put these two lines on — settled by the reader, 2026-10-12.** At the
review gate the two lines sat at the **tail of item 016** and the list's own item 017 was **markdown**. The reader
then edited `text.txt` themselves, after committing 016 (`3db8df5`): the two lines became item **017**'s two
numbered lines and markdown moved to **018**. This directory was already numbered 017, so the two now agree and
**nothing is owed** — the earlier version of this note (which offered a rename, and reserved 018 for markdown) is
what that edit answered. The Input block carries the list's new text verbatim, dated, and names the markdown item
as not this feature's input.

**The bold option's shape, settled by the reader on 2026-10-12 — and the evidence it rests on.** The reader's
answer was *"选 A，不好的没必要做"*: one more entry in the font list (the default family in bold), and the
combination schemes refused rather than postponed. That answer was taken **after** the device's own faces were
read out of `/system/fonts` and `/system/etc/fonts.xml`: `sans-serif` holds a variable `Roboto` whose `wght` axis
instances up to 900; `serif` holds `NotoSerif-Bold.ttf` (Latin only — the CJK face that ships is a `Regular`);
`monospace` holds `DroidSansMono.ttf` at `weight="400"` and nothing else; and **no CJK face on the device is
bold** (`NotoSansCJK-Regular.ttc` / `NotoSerifCJK-Regular.ttc`). So a toggle or a six-name list would sell a bold
that is *synthesised* for two of the three faces and for every Chinese word. Decision 1 in `spec.md` carries the
full table; the edge case above it (a Chinese word under the bold face) states what remains true anyway: FR-005
guarantees the glyphs, not the weight the platform chooses to fake. **Cost accepted with the answer**: no
`serif`-bold, no `mono`-bold, and this spec's own walk owes a screenshot of a Chinese word in the bold face so the
reader sees what the platform does rather than reading about it.

**The bold shape, settled a second time the same day — and by evidence, not by taste.** The first answer
(*"选 A，不好的没必要做"*, above) was given before anything had been seen; the reader then asked to see the
platform's synthetic Chinese bold, and the probe of 2026-10-12 answered with numbers: the synthesis thickens the
Chinese by **+51%** ink at 30 pt (**+64%** at the app's own reading size of 14 pt), against the shipped **real**
bold's Latin **+47%** — the same order of magnitude rather than a nominal effect — and it is the same paint
whatever family is asked for (`mono-bold`'s Chinese is **pixel-identical** to `bold`'s, because every family's
Chinese falls back to the one NotoSansCJK face). On that, the reader's second answer (quoted in `spec.md`'s
Input block as **"形状 1。就这样。"**) widened the bold to **every** face: six values, ordered by family, and the
**switch** was refused for its own cost (the record's third field, 011's "exactly two parts" read rule and its
three-parts-are-malformed case, and a third control row) — the same coverage the six names give with the grammar
untouched. What this second answer **overrules** is the first one's face list, not its shape; both answers and
their reasons are recorded in `spec.md` (decisions 1 and 5). The accepted cost is written where it lands:
three labels move the app's key count to 110, and the offered list grows from three names to six — **where the
tests that move were found by grepping them, not by trusting this note** (`plan.md`'s ripple 10, corrected at
the tasks stage: 011's own three cases in `test/reading_view_appearance_test.dart` run unmodified; the store's
offered-list assertion and the painter's `_layoutOf`/`_stepsOf` helper are the two that are re-cut).

**The story split is mine and should be argued with.** The two asks are independent: a reader can have the bold
face and never touch the comment's size, and the reverse. P1 is the bold face because it edits nothing another
feature measures; P2 is the comment's size because it edits a **paint rule 015 owns** and moves a **measurement
015 recorded** (its row 22's ink box), so it carries the re-measurement obligation. A reviewer who thinks the
comment's size is the headline ask should say so — the split is a ranking, not a dependency.

**Precision added beyond the reader's wording — each one a place the plan could otherwise decide silently.**

1. The comment's size is **the next offered size down** and not a ratio (decision 2): `xlarge`→18, `large`→14,
   `medium`→12, and `small`→**10**, derived. The four offered sizes are 12/14/18/24 points and their steps are
   uneven, so a ratio would make the app's own offered numbers a fiction.
2. The comment is **not** made bold by the bold face (edge case): the face is the text's own weight, and today's
   comment weight is unchanged.
3. The relationship is stated for the **video as well as the page** (FR-008): 015 already paints the comment in
   the frame, so a page-only rule would ship a page and a video that disagree about the same text.
4. The picker **must not** gain a third row (FR-012): "derived, never stored" is a rule, not an omission.

**Reuse obligations the plan inherits (grepped, not remembered).**

- `lib/appearance_store.dart` — `ReadingTypeface` (`default`/`serif`/`mono`, `familyFor(platform)`),
  `ReadingSize` (12/14/18/24), and the record's grammar `<typeface>||<size>`; the new value is one enum member
  plus a weight, and the record's shape does not move.
- `specs/011-reading-experience/contracts/appearance-format.md` — the value table (line ~38), the family table
  (lines ~60-64) and **read rule 2** ("one of the three typeface names") are each enumerated, so all three are
  amended with a date, plus a round-trip/fallback case **for each of the three bold names** in the contract's own
  test list.
- `lib/reading_view.dart:404-405` — the appearance comparison the page makes before adopting a stored value
  compares `typeface.name` and `size.name`; a new **value** passes through it, but the plan must not assume a new
  **field** would.
- `lib/reading_view.dart:2355-2372` — `_buildSpans()` builds one span (three when a highlight is in force) from
  015's display, so a smaller comment means splitting at the comment's own boundaries **in paint only**: the
  display mapping is what FR-010 protects.
- `lib/video_painter.dart:577-595` — `_blockFor` lays the slot's text out as **one** span and derives its lines,
  height and scroll steps from that layout, so FR-008's smaller comment is a two-span block and its numbers move.
- `specs/015-comment-tag/research.md:499-500` — 015's row 22 holds `text=18` and an ink box of
  `(208, 864, 456, 964)`, 100 px tall, for its own fixture; those numbers are this feature's to re-take.
- `lib/l10n/app_*.arb` — 107 message keys each (after 016's retirement); **three** labels are this feature's own
  (`fontBoldLabel`, `fontSerifBoldLabel`, `fontMonoBoldLabel` → **110**), and `flutter gen-l10n`'s committed
  artifacts are part of the receipt. **The records that quote 107 as the current count** — 016's Status, its
  T012/T031 receipts and its `breakpoint.md`, plus 015's/011's own files where they quote it — are corrected,
  dated, in the same pass that adds the labels: until then 107 is still the truth, and after it, a standing 107
  is a stale quote.

**Risks the plan must carry, in the order they are likely to bite.**

1. **Bold is wider** → 011 FR-012's width guarantee and its SC-005 measurement are taken at the largest offered
   size; **each** bold face at `xlarge` may clip a line where its regular counterpart did not, so the measurement
   is taken three times. FR-006 makes this a measurement
   to retake, and the honest outcome may be a narrower allowance or a fallback face — the plan must not assume
   the guarantee survives untouched.
2. **The video's block numbers move** → 015's row 22 and the frames 012's rows measure. The plan owes those rows a
   re-walk, and the re-walk is the evidence that FR-008 is true rather than merely coded.
3. **"One smaller" at the smallest size** → the derived 10 pt is this spec's own decision. If the reader would
   rather the comment stop at 12 (no smaller), that is a change to decision 2 and to FR-009, and it should be made
   before the plan, not after the walk.
4. **The glyph fallback at the derived size** → `[注]` inside a Spanish sentence asks the fallback family for a
   size it has always been asked for; if a family renders the derived size badly, the fix belongs to the family
   choice, not to a per-language size.

**Deliberately absent, so the plan does not add it.** No new store, no new field in the record's grammar, no
comment-size picker, no weight toggle, no per-content or per-device comment size, no markdown, no change to the
content's own characters or to the editor, and no new dependency of any kind.

**Naming.** The feature directory is `017-bold-comment-size` (the reader's own number of 2026-10-12, against the
wish list's own item 017 — see above). The slug names both changes in the order they are prioritised.
