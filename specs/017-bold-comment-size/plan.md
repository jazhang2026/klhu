# Implementation Plan: A bold face, and a comment one size down

**Branch**: `017-bold-comment-size` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-bold-comment-size/spec.md`

**Grounding**: nothing in the spec needed correcting — its four claims about today's code were checked site by
site and hold, and the two facts it could only assert (what the device's faces actually hold, what the suite's
baseline is) are measured in [`research.md`](./research.md) § Verified environment facts.

## Summary

Two paints change and nothing else moves. `bold`, `serif-bold` and `mono-bold` become **three more values of 011's own `typeface` field** (six faces in all) — no
new field, no new store, and the record's grammar `<typeface>||<size>` is untouched — with the weight carried by
the **face in code** (research D1), so an old record still loads, a new one still reads in the shipped shape, and
011's read rules keep their meaning. A comment's own characters are painted **one offered size below** the
reading text's — `xlarge`→18, `large`→14, `medium`→12, `small`→**10**, derived — on the page (research D3) and in
a video frame (research D4), computed at paint time from the size in force, never stored (research D2).

## Technical Context

- **Language / version**: Dart 3 / Flutter, the app's own toolchain — `pubspec.yaml` untouched (FR-013).
- **Primary dependencies**: none added, no network call (FR-013, SC-006).
- **Storage**: `shared_preferences`, the existing `reading_appearance` record. Its value domain gains `bold`;
  its grammar and 011's read rules do not change (research D1). Nothing is migrated and nothing is rewritten.
- **Testing**: `flutter test --concurrency=2`; baseline measured **2026-10-12 11:22** — `flutter analyze` clean,
  **643 passing, 0 failing** (the gate every row in [`quickstart.md`](./quickstart.md) is read against).
  `flutter gen-l10n` regenerates the four committed `app_localizations*.dart`.
- **Target platform**: Android — the walked device is the API 36 emulator, whose font set is what D1's evidence
  comes from. **iOS stays unverified on this host** (no macOS), exactly as 011's appearance contract already
  says; this plan does not remove that limit and does not pretend to.
- **Project type**: one Flutter app, one codebase (constitution I).
- **Performance goals**: none new. The page's change is a style on spans it already builds; the video's is one
  extra `TextSpan` **inside the per-frame layout the painter already performs** (the block is laid out per frame
  by design, because the ink colour is a paint-time fact — nothing is cached, so nothing new is invalidated).
- **Constraints**: 011 FR-012's width guarantee at the largest offered size is **measured again for each bold face** (FR-006);
  015's own row 22 holds numbers that move and must be re-taken (FR-008); the comment's smaller size must move
  **no offset** (FR-010) — the display mapping, the highlight's boundaries, a tap's resolution, a step's range.
- **Scale / scope**: 4 source files, 1 contract, 4 ARB files (+ 4 generated), 4 test files; **no new source file**.

## Constitution Check

| Principle | Gate | How this feature passes |
|---|---|---|
| **I. Flutter Single Codebase** | one codebase, no platform split | No platform channel, no plugin, no native code. Both changes are Flutter style values; the faces are the platform's own fonts, as 011 D5 already ruled. |
| **II. Spec-Driven (NON-NEGOTIABLE)** | the artifacts come first | `spec.md` reviewed and its two open decisions answered by the reader (A; the smallest-size case). This plan names the ripple into 011's and 015's own records, which are amended **dated, in their own files**, by `tasks.md`'s rows. |
| **III. Test-First (NON-NEGOTIABLE)** | tests before code | Each story's tests are written and run **RED** before its implementation in `tasks.md`. The RED is real, not formal: the store's round-trip for `bold||xlarge`, a widget test reading the painted weight and the comment's span size, and a painter test on a two-span block all fail on today's tree for a named reason. |
| **IV. On-Device First** | the behaviours that matter are device-verified | The look of the bold face, the width re-measure at `xlarge`, the comment's measured size at two offered sizes, the Chinese word in bold, and the video frame's own ink are **device rows**, with screenshots and the app's own lines as evidence. |
| **V. Simplicity** | the smallest shape that satisfies the ask | No new dependency, no new field in the record, no new stored setting, no new screen, no new control row: the derived size is computed, and the bold is one more value of a field that already exists. The reader's second answer — six names, all three faces — took the cheapest way to offer every bold, and refused the switch on its own cost (a third field in the record). |

## Decisions the user can see

1. **The font list grows from three entries to six.** The appearance control shows `default · Bold · serif ·
   Serif Bold · mono · Mono Bold`, in that order, previewed in the candidate size before it is applied. Nothing
   else about the control changes (two rows, same Save, same dismissal rule) — but the face row is now long
   enough to wrap, so **011's own layout case** (`16. the last option scrolls clear of the system bar`) is
   re-read and its numbers re-taken rather than assumed (ripple 10).
2. **A comment is visibly smaller than the text it belongs to**, on the page and in every rendered frame — at
   every offered size, including the smallest, where its size falls to 10 points.
3. **Nothing becomes configurable.** There is no comment-size picker, no bold switch, and no second size
   dimension: the relationship is derived, and the reader's own answer refused the shapes that would have added
   one.
4. **A Chinese word in the bold face is painted by the platform's synthetic weight** — the device ships no bold
   CJK face. That is visible the moment the reader picks Bold on Chinese text, and the walk carries a screenshot
   of exactly that rather than leaving it to be discovered.

## Project Structure

### Documentation (this feature)

```
specs/017-bold-comment-size/
├── spec.md                  (reviewed; decision 1 carries the device evidence)
├── plan.md                  ← this file
├── research.md              (D1-D6, the verified environment facts, open questions)
├── data-model.md            (ReadingTypeface + weight, the derived comment size, VideoSlot's boundary)
├── quickstart.md            (13 rows — [unit] 7, [device] 5, [structural] 1 — read against the 643 baseline)
├── checklists/requirements.md
└── scripts/                 (implement time: klhu_walk_bold.py — the device rows' own driver)
```

### Source code (repository root)

```
lib/
├── appearance_store.dart    MODIFIED  ReadingTypeface gains a weight + three consts; `all` gains the three bold values
├── appearance_screen.dart   MODIFIED  `_faceLabel`'s three new cases; `_previewStyle` gains the weight
├── reading_view.dart        MODIFIED  the ONE style seam gains the weight; `_buildSpans()` splits a comment
├── comment.dart             MODIFIED  the comment's own DISPLAY ranges (from the resolution 015 already does)
├── video_timeline.dart      MODIFIED  VideoSlot gains the comment's boundary inside its `text`; both builders fill it
├── video_painter.dart       MODIFIED  `_blockFor` lays out two spans when the slot carries a comment
└── l10n/app_{en,es,zh,zh_Hans}.arb  MODIFIED  107 → 110 keys (three labels); the four generated Dart files regenerated

test/
├── appearance_store_test.dart          the contract's own cases, + `bold||xlarge` and the fallbacks
├── reading_view_appearance_test.dart   the picker's offered set, the painted weight, xlarge's width re-measure
├── reading_view_comment_test.dart      the painted comment size at each offered size; no comment, no change
└── video_painter_test.dart             the two-span block, the smaller comment line, the no-comment slot

specs/011-reading-experience/contracts/appearance-format.md   MODIFIED (dated amendment)
specs/011-reading-experience/{spec.md,data-model.md}          MODIFIED (dated notes: the re-measure)
specs/015-comment-tag/{spec.md,quickstart.md,research.md,breakpoint.md}  MODIFIED (dated notes: FR-012/FR-013, row 22)
```

**No new source file.** The only new file this stage plans is the walk's own driver, and it lives under this
feature's `scripts/`.

## Ripple notes

1. **011's contract is where the value is declared** — `contracts/appearance-format.md`: the field table's
   domain (`:38`) gains `bold`, `serif-bold` and `mono-bold`; the family table (`:63-65`) gains three rows —
   `bold` (its families are **none**, the theme's own, at `FontWeight.w700`; D5's reason: naming a family would
   drop the theme's own and the CJK fallback chain with it), `serif-bold` (`serif`) and `mono-bold`
   (`monospace`); read rule 2 (`:83`) says "one of the three typeface names" and becomes six; the test list gains
   a round-trip for each of the three names and `serif-bold||huge` → `(serif-bold, medium)` (per-field fallback); the
   invariants list keeps its meaning. **Read rules 1 and 3 and the grammar do not move** — that is exactly what
   makes the six-name shape cheap, and it is the first thing a reviewer should check against the code
   (`ReadingAppearance.decode`'s comment says "exactly two non-empty parts").
2. **`lib/appearance_store.dart`**: the weight belongs to the **face in code**, not to the record (D1). So the
   three values' weights are `w700` and `familyFor` returns `null` only for `bold` (`serif` for `serif-bold`,
   `monospace` for `mono-bold`). An absent or
   hand-edited record is untouched by this change; `ReadingAppearance.byName` accepts the new name for free.
3. **`lib/reading_view.dart:2511-2439` is the ONE style seam** (its own comment says so, and 011 FR-009 rests on
   it): the weight is added there, and with it the bold reaches the rich text **and** the editor field, and
   neither reaches the chrome. `_loadAppearance`'s comparison (`:404-405`) already compares **names**, so a
   change to `bold` is noticed and a stored `bold` is adopted — no change needed, and none is made.
4. **The comment's split is a paint seam, not an offset change** (FR-010). `_buildSpans()` (`:2355-2372`) already
   builds three spans for a highlight from 015's display; the comment's own characters get their own span(s) from
   the **same display resolution** 015 already performs (D3) — the mapping that decides which content offset a
   display offset holds is not re-derived anywhere, and the tests that hold 015 FR-012 and 016's step ranges are
   the guard.
5. **The video's block** (`lib/video_painter.dart:577-595`) lays the slot's text out in one `TextSpan` and takes
   its lines, height and scroll steps **from that one layout**. It becomes two spans (D4), and the scroll maths
   follows from the same call — so the painter's own tests (`video_painter_test.dart`'s group "46. a tall
   sentence wraps and scrolls a line at a time") are the ones that must be re-read, not rewritten.
6. **A field another driver parses gets it where that regex still matches** — and here the answer is *no field
   moves*: the renderer's own line (`klhu render slot=… span=… text=…`) keeps its shape, and only its **values**
   change (`text=18` and the ink box for 015's own fixture). So no sibling driver's parser needs re-cutting; what
   needs re-taking is 015's row 22's **expected numbers** (`specs/015-comment-tag/quickstart.md:421-428`) and the
   ink box `specs/015-comment-tag/research.md:499-500` holds. That is the one receipt this feature knowingly moves.
7. **`lib/l10n/app_*.arb`**: **three** new keys (`fontBoldLabel`, `fontSerifBoldLabel`, `fontMonoBoldLabel`,
   beside the four that exist) → **107 → 110** in each of the four files, `flutter gen-l10n` re-run, the four
   generated Dart files committed with it, and `test/l10n_keys_test.dart` re-run. **The older records that quote
   107 as the current count — 016's Status, its T012/T031 receipts and its `breakpoint.md`, and 015's and 011's
   own counts where they quote it — are corrected with dates in the same pass that adds the labels**, because
   until then 107 is still the truth.
8. **015's and 011's own records carry the dated amendments**, in their own files, by this feature's tasks: 015
   FR-012/FR-013 (the comment's painted size) + row 22 + its research's numbers; 011 FR-012/SC-005 (the width
   measurement, re-taken for the bold face) + the contract. Neither spec's structure changes; each amendment
   names the date and the reader's own words.
9. **No `read_position_*`, no `reading_appearance` migration, no store file touched** — and no key added beyond
   the one label. The record 016 left behind (`reading_appearance` two-part values) is loadable in every
   direction: shipped app → this build, this build → shipped app (FR-004).

10. **Corrected 2026-10-12, at the tasks stage: the re-cuts this ripple first named were the wrong two.**
    Grepped before spending them as work, and the three cases in `test/reading_view_appearance_test.dart` do
    **not** pin the face set: `12.` asserts each label of a list `findsOneWidget` (a new entry beside them passes),
    `13.` taps two labels by name, and `16. the last option scrolls clear of the system bar` drags the list by a
    fixed `-2000` and measures the **last** option against the system bar — the control is a `ListView`, so a
    taller content still scrolls to its end. All three are **read and run unmodified**; if one moves, it is
    re-cut and the deviation reported. What actually moves, found by the same grep, is
    (a) `test/appearance_store_test.dart:114-119` — `expect(ReadingTypeface.all.map((face) => face.name),
    ['default', 'serif', 'mono'])` pins the offered list and **fails** on six values, so it is re-cut (with its
    own title); and (b) `test/video_painter_test.dart`'s `_layoutOf`/`_stepsOf` helpers, which recompute a
    block's layout as **one** span at the reading style — they must learn the two-span shape for a
    comment-carrying slot, while every no-comment case stays green unmodified (FR-011's receipt).
11. **The comment half of this feature is untouched by the widening** (US2, FR-007 to FR-011): the derived size,
    the page's span split, the frame's two-span block, and 015's re-measured row 22 all stand exactly as planned
    before the bold faces were widened.

## Complexity Tracking

Nothing to track: no complexity, no violation, no dependency, no new field, no new file. Stated thin rather than
filled.

## Honest limits

1. **iOS is unverified on this host** (no macOS). The bold face is "no family override + weight 700" on both
   platforms, and 011's contract already carries the same unverified-iOS caveat for its three faces; this
   feature extends that caveat rather than pretending to close it.
2. **The Chinese word under any bold face is the platform's synthetic weight** — and that is now **measured and
   accepted**, not assumed: the probe of 2026-10-12 put the synthesis at +51% ink at 30 pt (+64% at the app's own
   14 pt, against the shipped real bold's Latin +47%), pixel-identical across families (`mono-bold`'s Chinese =
   `bold`'s), and the reader answered with decision 5. FR-005 still guarantees the glyphs; nothing in this feature
   can make the platform paint a real bold CJK face it does not ship. The walk still owes the screenshots.
3. **FR-006 may not survive its own re-measure.** 011 FR-012 was measured on the regular faces. If any bold
   face at `xlarge` clips a line, the recovery is **named, not narrowed quietly**: 011 FR-012's wording gets a dated
   note saying which face and weight it holds for, and the options (a narrower top size for the bold face, or a
   fallback face) go back to the reader. The plan does not pre-decide it; it pre-declares it.
4. **The derived 10 points is this spec's own number**, chosen by the reader's sentence ("有区别") rather than by
   a measurement. If the walk shows it illegible next to 12-point text, that is a change to decision 2, not a bug
   in the code.
