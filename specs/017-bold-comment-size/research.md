# Research: A bold face, and a comment one size down

## Grounding corrections

*None.* The spec's four claims about today's code were checked at the sites themselves and all hold; the two
facts it could only assert are now **measured** (below), and one of them turned out to be the load-bearing one.
What follows is the verification, with its `file:line` — recorded rather than corrected, because a claim that
survives a check is still worth the reviewer's ability to re-run it.

| The spec says | What the code says | Verdict |
|---|---|---|
| "`bold` is a fourth value of the existing `typeface` field" | `lib/appearance_store.dart:18-23` — the three faces are three `ReadingTypeface._(name)` consts, `all` is the offered order, and `byName` reads any name in it | **holds** — a new const is a value, not a field, and three more of them cost the grammar nothing (updated 2026-10-12) |
| "the record's grammar `<typeface>||<size>` is unchanged, and a record written before this feature still loads" | `lib/appearance_store.dart:100-119` — `encode()` joins two parts; `decode()` requires *exactly two non-empty parts* and puts **a name it does not offer** back to that field's default alone | **holds** — and this is why choice A is cheap: an unknown name is already a *tolerated value*, where a third field would have collided with the "three parts is malformed" rule (`:105`) |
| "the page paints the reading text in one place" | `lib/reading_view.dart:2426-2439` — the comment above it says "this method is the ONE place the reading text's style is built, and the rich text and the edit field both go through it" | **holds** — and the bold is therefore one `copyWith` |
| "the comment is already painted in a video frame with its sentence" | `lib/video_painter.dart:577-595` — one `TextSpan(text: slot.text, style: …)` per frame, laid out per frame | **holds** — and the same block is also the thing whose **one-span** assumption D4 breaks |
| "015's row 22 holds `text=18` and an ink box of `(208, 864, 456, 964)`" | `specs/015-comment-tag/research.md:499-500` (the numbers) and `specs/015-comment-tag/quickstart.md:421-428` (the row that asserts them) | **holds** — this row's expected numbers are what FR-008 moves |
| "`mono` has no bold face to offer" | `/system/fonts` + `/system/etc/fonts.xml` on the walked device (below) | **holds** — the evidence is what turned the shape question from taste into arithmetic |

## Verified environment facts

| Fact | Value | Evidence |
|---|---|---|
| The suite's baseline on the day this plan was written | analyzer clean; **643 passing, 0 failing** | `flutter analyze` → `No issues found! (ran in 1.1s)`; `flutter test --concurrency=2` → `00:56 +643: All tests passed!`, 2026-10-12 11:22 |
| The default face's family | **none — the theme's own** (not the literal string `sans-serif`) | `lib/appearance_store.dart:16-18, :32-36` ("No family is set, so the theme's own family renders — the app ships no font"), `lib/reading_view.dart:2433` |
| A real bold face for that default family | yes — `Roboto` is a **variable** font whose `wght` axis the family instances from 100 up; `DroidSans-Bold.ttf` also ships | `adb shell sed -n '38,48p' /system/etc/fonts.xml` (the `sans-serif` family lists `Roboto-Regular.ttf` per weight with `<axis tag="wght" …>`), `ls /system/fonts` |
| A real bold face for `serif` | **Latin only** — `NotoSerif-Bold.ttf` is a `weight="700"` entry and `serif-bold` is an alias; no bold CJK serif ships | `/system/etc/fonts.xml` (`<family name="serif">` lists 400/700 normal and italic), `ls /system/fonts | grep CJK` → `NotoSerifCJK-Regular.ttc` only |
| A real bold face for `monospace` | **none** — the family's only entry is `DroidSansMono.ttf` at `weight="400"` | `/system/etc/fonts.xml` (`<family name="monospace">`) |
| A real bold face for **any** CJK face | **none** — `NotoSansCJK-Regular.ttc` and `NotoSerifCJK-Regular.ttc` are the only CJK faces | `ls /system/fonts | grep -iE 'CJK'` |
| The walk device | AVD `klhu` = `emulator-5554`, API 36, package `com.example.klhu` | `adb devices` |
| The comment's own characters are inside the painted display text | 015's display elides the **tag** only; `_buildSpans()` splits from `display.text` | `lib/reading_view.dart:2355-2372`, 015 FR-005/FR-012 |
| A `VideoSlot` already carries the sentence's own content range but **not** the comment's boundary inside its painted `text` | `lib/video_timeline.dart:144-174` (`kind`, `paragraph`, `sentence`, `start`, `end`, `text`); the two builders are `:331` and `:354` | grep of the constructor and its call sites |
| The message keys before this feature | **107** per ARB, four ARBs — this feature takes it to **110** (three labels) | `python3 -c` count over `lib/l10n/app_*.arb` |
| What a synthesised bold does where no bold face ships (Chinese, the probe of 2026-10-12) | ink/area 0.245 → 0.369 at 30 pt (**+51%**), 0.222 → 0.365 at 14 pt (**+64%**); median stroke run 6 → 10 px; counters (enclosed white) −40% | measured per band on `/tmp/017_probe_bold_zh_{top,large}.png` with PIL; the probe app is throwaway (`~/.hermes/cache/scratch/klhu_bold_probe`, not in the tree) |
| The shipped **real** bold's thickening, for scale | Latin ink/area 0.185 → 0.271 at 30 pt (**+47%**), 0.169 → 0.245 at 14 pt (+45%) — Roboto's variable `wght` axis | same probe |
| Whether the family changes what Chinese looks like | **No**: `mono`·w400's Chinese is pixel-identical to `default`·w400's (ink 16667, ratio 0.245, stroke 6), and `mono-bold`'s to `bold`'s (26193, 0.369, 10) | same probe — every family's Chinese falls back to the same NotoSansCJK face |

## D1. The weight belongs to the face in code, not to the record

- **Decision**: the bold is carried by **three more `ReadingTypeface` values** whose weight is a property of the
  value in code (`w700`): `bold` (its family stays **null** — the theme's own), `serif-bold` (`serif`) and
  `mono-bold` (`monospace`). The record keeps `<typeface>||<size>`.
- **Rationale**: the record's grammar is what 011's contract, its read rules and its malformed-value case are all
  written around; a *value* rides through all of them unchanged (the table above), while a third field would
  change read rule 1's "exactly two non-empty parts" and the case that calls three parts malformed. The reader's
  own answer (*"选 A，不好的没必要做"*) picked the shape that is also the cheapest, and the evidence made that
  choice the honest one rather than merely the convenient one.
- **Alternatives considered**: a `boldWeight` **switch** in the record — refused by the reader on 2026-10-12 on
  the cost it was put to them with: it is the third field above, and it moves 011's read rule 1, its
  three-parts-are-malformed case and the control's own height, for a coverage the six names already give;
  separate *families* named `bold`/`serif bold`/… — declined: naming `sans-serif` for the default family drops
  the theme's own family and its CJK fallback chain (D5).

## D2. The comment's size is computed in one place, from the size in force

- **Decision**: a single helper on the size/appearance value returns a comment's points for a text size — the
  **next offered size down** (24→18, 18→14, 14→12), and **10** below the smallest. Both paints (page, frame) call
  it; neither stores it.
- **Rationale**: two call sites computing "one smaller" independently is how a page and a video come to disagree;
  and the reader asked for a *relationship*, not a setting, so there is nothing to persist or to keep in sync.
- **Alternatives considered**: a ratio (`×0.85` → 24 gives 20.4) — declined in the spec's decision 2: it makes
  the app's own offered numbers a fiction; a per-content or per-device comment size — declined: a second setting
  nobody asked for, stale the moment the text's size changes; a fifth offered size (`tiny` 10) — declined: the
  reader picks a *text* size, and adding a fifth chip changes what the control offers rather than what a comment
  is painted at.

## D3. The page's split comes from 015's own resolution, never from a re-derivation

- **Decision**: the comment's display ranges come from the same display/comment resolution the page already
  performs, and `_buildSpans()` uses them to give those characters their own span with D2's size.
- **Rationale**: FR-010 is the requirement that protects every offset in the app — the highlight's boundaries, a
  tap's resolution, a step's range, 015's mapping. Splitting the *painted* text must therefore not introduce a
  second opinion about where a comment begins: one resolution, used twice.
- **Alternatives considered**: re-deriving the comment's boundaries in the view from `commentsOf` plus the
  display's own elision arithmetic — declined: that is a second implementation of 015's mapping, and the tests
  that would catch it drifting are the ones FR-010 exists to keep green; splitting by searching the display text
  for the comment's first characters — declined outright: it breaks on a repetition ("Hola. Hola." ) and would
  fail silently.

## D4. The video's boundary is carried by `VideoSlot`, not re-found by the painter

- **Decision**: `VideoSlot` gains one nullable field naming where the comment's own characters begin inside its
  painted `text`; the two builders fill it; `_blockFor` lays out two spans when it is set.
- **Rationale**: the painter cannot recover that boundary honestly — `start`/`end` are **content** offsets and the
  display elides the tag's characters, so the relationship between content offsets and the painted string is not
  linear; and searching for the comment's text inside the painted string fails exactly where a comment repeats
  its sentence's words. The information exists at the builder, where the block is assembled, and one nullable
  field is the smallest way to carry it.
- **Alternatives considered**: the painter splits at the first `\n` — declined: it is a guess about the block's
  shape that today's code happens to obey and tomorrow's need not; the renderer passes the comment's text
  separately into the plan (two texts per slot) — declined: a bigger model change for the same result, touching
  every consumer of `VideoSlot` rather than the two builders and one painter.

## D5. A bold value is its family at weight 700; the default one names none

- **Decision**: each bold value asks for the family of the face it is the bold of, with `FontWeight.w700` —
  except `bold` itself, which asks for **no family override** at all.
- **Rationale**: `default` already means "the theme's own family" (`lib/appearance_store.dart:16-18`), which on
  Android is the variable `Roboto` — the one family on the device with a real bold for the Latin text the reader
  reads (`wght` instances up to 900; `DroidSans-Bold.ttf` ships as well). `serif-bold` lands on the shipped real
  `NotoSerif-Bold.ttf`; `mono-bold` lands on a family with **no** bold face, which is the case the probe measured
  and the reader accepted (the environment table above). Naming `sans-serif` explicitly for `bold` would look the
  same today and change the meaning of the chain for CJK fallback and for any future theme.
- **Alternatives considered**: naming `sans-serif` — declined (above); making bold a *family* with its own
  family string — declined: it is the same value with a second source of truth.

## D6. The width guarantee is re-measured, and its recovery is declared in advance

- **Decision**: 011 FR-012 (and its SC-005 measurement) is re-taken for the bold face at the largest offered size
  as a **device/test measurement before any wording changes**; if the measurement shows a clip, 011's FR-012 gets
  a dated note naming the face and weight it holds for, and the reader is offered the options.
- **Rationale**: bold is wider than regular; the guarantee was measured on the regular faces, and a plan that
  assumed it survived would be asserting a number nobody took. The alternative — quietly narrowing the rule, or
  silently dropping bold from `xlarge` — is a change the reader never sees.
- **Honest limit**: this plan **cannot** promise the guarantee holds for the bold face. It promises to measure it,
  and to report the figure either way. `quickstart.md`'s row for it states the expected evidence (the widest
  painted line against the page's own width) and not an assumed verdict.

## Open questions (implement time answers these; each has its fallback chosen)

1. **How much does the block's ink move in the video?** 015's row 22 asserts an ink box; a smaller comment line
   changes the block's own height. The row is re-taken, not re-argued: whatever it measures is written into
   015's own `specs/015-comment-tag/quickstart.md` row 22 and `specs/015-comment-tag/research.md:499-500` with the date. Fallback if the box's shape changes more
   than its height: the row's own Expected is rewritten to describe the new block, since the rule it asserts is
   "the comment's characters are painted, smaller than the sentence's" and not a pixel rectangle.
2. **Is the derived 10 points legible next to 12-point text, in Latin and in CJK?** The walk's screenshot decides.
   Fallback if it is not: the reader is given the two options (11 points, or a smaller floor for the text size
   itself) — a change to spec decision 2, made with the picture in hand.
3. **Does each `xlarge` + bold combination still fit?** D6 — now three measurements rather than one. Measured,
   then reported.
4. ~~**Does the picker's own layout survive six chips?**~~ **Answered 2026-10-12, at the tasks stage, by
   grepping the three cases instead of assuming:** they do not pin the set — `12.` asserts each label of a list
   `findsOneWidget`, `13.` taps labels by name, and `16.` drags the list `-2000` and measures the **last** option
   against the system bar, which a `ListView` satisfies at any content height. So they run **unmodified**, and
   the real re-cuts are the store's offered-list assertion (`test/appearance_store_test.dart:114-119`, which
   pins `['default', 'serif', 'mono']`) and the painter's `_layoutOf`/`_stepsOf` helpers (one span → two for a
   comment-carrying block). Recorded in `plan.md`'s ripple 10, which this question corrected.
