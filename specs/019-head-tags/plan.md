# Implementation Plan: Head tags (`#` a title, `##` a subtitle)

**Branch**: `019-head-tags` | **Date**: 2026-10-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/019-head-tags/spec.md`

**Grounding**: three things the spec's own wording cannot carry as written are corrected in
[`research.md`](./research.md) § Grounding corrections, each with its `file:line` — the ceiling clause of US1's
scenario 4 (before the reader's amendment of 2026-10-13 both marks clamped at the largest size *and* both were
bold, so at `large` and `xlarge` nothing distinguished them; **the amendment resolved it**, and what survives is a
narrower limit: a body already on the ladder's last rung), FR-002's trailing-`#`-sequence (one of its two readings,
named and taken), and the Out-of-scope bullet about a mark not changing a line's height (a bigger size *is* a
taller line box; no *spacing rule* is added). A fourth item is a contract step FR-004 forces on the resolution's
own type: a speech's text becomes the display's, and the speech carries the display so the read's offsets stay the
content's.


> This feature's own device walk — every row's command, evidence and state — is `breakpoint.md`, beside
> these artifacts; its driver and fixture are `scripts/klhu_walk_head.py` and `scripts/klhu_head_fixture.txt`.

## Summary

A line that starts with `# ` or `## ` is a **title** or a **subtitle**, and the marker itself is nowhere: the page
paints the line at a **rung of a ladder the app derives** from the reader's own choice — the four offered sizes in
their order, then the largest offered size at the **bold** and at the **black** weight (the reader's amendment of
2026-10-13, *"把加粗字体 计入 大一号，大二号"*: research's table) — and the voice never hears a `#`: the marker is a
second kind of **never-painted, never-spoken character**, inside the two seams 015 already owns (its display elides
it alongside every comment tag, and its resolution keeps both out of what the engine is handed). A title takes the
rung **two** steps above the reader's own and a subtitle **one**; the same ladder read **downwards** is 017's
comment, whose step down now takes the **weight first** (a bold body's comment is the same size at the regular
weight — FR-015, and 017's own records carry the dated report). The video rides the same rungs at the frame's own
scale (012/017's derived-size seam). Nothing is stored, nothing is configured, no locale string is added, no entry
is added to the reader's Appearance list, and the reader's own text — in the editor, in `008`'s index, in what is
stored — is byte-for-byte what they typed.

## Technical Context

- **Language / version**: Dart 3 / Flutter, the app's own toolchain — `pubspec.yaml` untouched.
- **Primary dependencies**: none added, no network call. The whole feature is pure Dart over the reader's text
  (constitution IV).
- **Storage**: **none.** No new key, no new field in any record, nothing migrated (FR-010; the spec's Key
  Entities is *"None"*).
- **Testing**: `flutter test --concurrency=2`; baseline measured **2026-10-13 09:05** — `flutter analyze` clean,
  **663 passing, 0 failing**, 110 message keys per ARB (the gate every row in [`quickstart.md`](./quickstart.md)
  is read against). Two new test files, seven re-read or extended.
- **Target platform**: Android — the walked device is the API 36 emulator. **iOS stays unverified on this
  host** (no macOS), exactly as 011's appearance contract and 017's plan already say; this plan does not remove
  that limit.
- **Project type**: one Flutter app, one codebase (constitution I).
- **Performance goals**: none new. The page's change is a style on spans it already builds (its cut set gains
  the marks' boundaries); the frame's is a split inside the per-frame layout the painter already performs, and
  no cache is added or invalidated.
- **Constraints**: a mark must move **no offset** (FR-011) — the display mapping, a tap's resolution, a step's
  range and 016's step list are the guard; the reader's text is never rewritten (FR-010); a malformed mark is
  the reader's characters (FR-014); a mark's look is the ladder's rung and nothing else (FR-006/FR-007), and a
  comment's step down is the same ladder read downwards (FR-015) — which moves 017's shipped rule and is
  reported in that feature's own records.
- **Scale / scope**: **9 source files, 1 of them new**; 9 test files (2 new); 0 ARB files; 0 dependencies; no
  `contracts/` (the interfaces it changes are in-process Dart types the app already owns); **two sibling
  records** (017's `tasks.md` + `breakpoint.md`) carry the dated report of the amended rule.

## Constitution Check

| Principle | Gate | How this feature passes |
|---|---|---|
| **I. Flutter Single Codebase** | one codebase, no platform split | No channel, no plugin, no native code: a mark is a rule over a Dart string, and the bold weight is the platform's own font handling, which 017 already measured on the device. |
| **II. Spec-Driven (NON-NEGOTIABLE)** | the artifacts come first | `spec.md` reviewed; this stage's four artifacts are written before any code. Where the spec cannot be implemented as written the correction is recorded in `research.md` **and** in the handback — the spec's own sentences are left alone, since they are the record of what was approved. |
| **III. Test-First (NON-NEGOTIABLE)** | tests before code | Every story's cases are written and run **RED** before its implementation in `tasks.md`. The RED is real: `headTagsOf` and `headSpans()` do not exist, the page's spans carry no heading style, and the invariant case in `test/speech_resolver_test.dart:106` fails the moment a speech's text is the display's — each named when it is one. |
| **IV. On-Device First** | the behaviours that matter are device-verified | The page's own painted text (`uiautomator dump`), the words the engine was handed (`klhu speak`), the highlight's walk (▶/⏭) and a rendered frame's ink box are **device rows**, with the reader's own content among the fixtures. |
| **V. Simplicity** | the smallest shape that satisfies the ask | No new dependency, no new stored setting, no new ARB key, no new screen, no new control **and no new entry in the reader's Appearance list**: one new source file (the rule), one **derived ladder** of six rungs both paints call, one elision inside an object that already elides, one nullable field on the resolution's own type, and one **amended shipped rule** (017's comment, reported dated). The cheaper shape for the read (substituting the marker with spaces) is refused with its reason in research D1; the shapes the reader refused for the ladder are recorded in research D4/D9. |

## Decisions the user can see

1. **A title and a subtitle are distinguishable at every reader size but the ladder's last rung** — and the ladder
   is the reader's own answer of 2026-10-13 (*"把加粗字体 计入 大一号，大二号"*, and their three choices recorded in
   `spec.md`'s Clarifications session). What it looks like, by the reader's own Appearance size:

   1. `small` → subtitle **14**, title **18**, both in the reader's own face and weight.
   2. `medium` → subtitle **18**, title **24**.
   3. `large` → subtitle **24**, title **24 bold** (subtitle regular).
   4. `xlarge` → subtitle **24 bold**, title **24 black** (the ladder's last rung).
   5. **a bold face at `xlarge`** → nothing sits above the reader's own rung: both marks paint at **24 black**.
      The case is named (SC-006), pictured by a row, and the remedies are the reader's own — a smaller size, or a
      regular face. **This is the one shape the amendment could not buy**, and it is what makes the ladder's top a
      limit rather than a promise.

   The alternatives were put to the reader with their costs and refused by them: the **interleaved** ladder (a step
   that is the same size, only bolder — *"有的档很微妙"*), and any rung **below** the reader's own for a mark (a
   subtitle lighter or smaller than the body). A third, the **weight floor** (a mark never lighter than the body),
   is refused in research D4 because it ties the title and the subtitle at `large` — and it is the one to revisit
   **if** row 5b shows a bold body's bigger-but-lighter marks reading as a demotion rather than as headings.
2. **A bold reader's comment stops being smaller and becomes lighter.** With a bold face in force, a comment's own
   characters are painted at the sentence's own size and the regular weight (FR-015, US4) — so the translation
   under a bold sentence is *quieter* instead of smaller. With a regular face nothing about a comment changes, and
   every figure 017's own device rows hold stands. This moves a shipped rule, so 017's `tasks.md` and
   `breakpoint.md` carry the dated report and `breakpoint.md` gains the row that proves the new case.
3. **The marker is not painted, not dimmed, not spaced.** The line moves left by the marker's two characters
   and nothing else about the paragraph changes; the alternative (painting the marker's characters as spaces)
   is refused because a frame paints the same string the read speaks, and the spaces would then be a visible
   indent in the video (research D1).
4. **Nothing becomes configurable, and nothing new is stored.** No heading picker, no heading face, no
   per-content switch, **no new entry in the Appearance list and no new size** (the reader's answer of
   2026-10-13): the relationship is derived from the choice they already made, and the ladder's two heavier
   rungs are values no control offers — 017's derived 10-point comment size is the precedent.
5. **A `#` the rule refuses stays exactly the reader's characters** — `#hashtag`, `#1 best`, `### note`, a lone
   `#`, `  # Title`, `# Title #` are painted *and read* as they are today, a voice saying "hash" included. The
   app never repairs a malformed mark and never drops a character silently (FR-014), and this is the direction
   every clause of the rule errs in.

## Project Structure

### Documentation (this feature)

```
specs/019-head-tags/
├── spec.md                  (reviewed; its US1 scenario 4 and FR-002's trailing clause are the two
│                             sentences research.md's corrections are about)
├── plan.md                  ← this file
├── research.md              (Grounding corrections, the verified facts, D1-D9, open questions)
├── data-model.md            (HeadTag, the display, ParagraphSpeech, VideoSlot, the ladder, INV-1..INV-11)
├── quickstart.md            (16 rows — [unit] 11, [device] 4, [structural] 1 — read against the 663 baseline)
├── checklists/requirements.md
└── scripts/                 (implement time: klhu_walk_head.py — the device rows' own driver, importing
                              015's and 016's drivers for the device mechanics, the content seeding and the
                              `RESULT: PASS|FAIL` dispatch)
```

### Source code (repository root)

```
lib/
├── head_tag.dart            NEW       the rule: `HeadTag` (level, the marker's span, the line it rules) and
│                                     `headTagsOf(content)`, derived on every read (FR-001/002/008/009)
├── comment.dart             MODIFIED  the display gains the second kind of elided span: `heads`,
│                                     `headSpans()`, and `toContent`/`toDisplay` over the merged spans (FR-003)
├── appearance_store.dart    MODIFIED  the one derived **ladder** both paints call — the four offered sizes, then
│                                     the top size at bold and at black — and the comment's step down read
│                                     downwards (FR-006/FR-007/FR-015, research D4)
├── speech_resolver.dart     MODIFIED  computes the display, hands every speech its own text from it, and sets
│                                     the speech's `display` (the standard, dialogue and comment paths)
├── reader_service.dart      MODIFIED  `ParagraphSpeech` gains `display` + the helper that turns a local
│                                     sentence range into words and content offsets; `_sentencesOf` uses it
├── reading_view.dart        MODIFIED  `_buildSpans()`'s cut set gains the marks' boundaries; `_spanPaint`
│                                     gives a marked run its derived size and `w700`
├── video_timeline.dart      MODIFIED  `videoSentencesOf` uses the speech's helper; `VideoSlot` gains
│                                     `headings`; `buildVideoPlan` is handed the display
├── video_painter.dart       MODIFIED  `_blockFor` splits the block at the mark's spans as well as at 017's
│                                     comment boundary (a comment's characters keep 017's size)
└── video_renderer.dart      MODIFIED  passes the content's display into the plan (one argument, `:267-275`)

test/
├── head_tag_test.dart              NEW   the recognition table, the line scope, the comment exclusion
├── reading_view_head_test.dart     NEW   the page's painted sizes and weights, the read's and the step's halves
├── comment_test.dart                     the display's elision of a marker + the mapping, beside 015's cases
├── speech_resolver_test.dart             the marked text's utterances and offsets; the invariant case re-cut
├── step_ranges_test.dart                 the reader's own content (unmodified) + the markers-as-spaces variant
├── reading_view_comment_test.dart        a comment riding a marked line; 015's and 017's cases re-read
├── video_timeline_test.dart              the slot's text and its `headings`
├── video_painter_test.dart               the frame's split runs and their sizes
└── appearance_store_test.dart            the four offered sizes' derived rows
```

**One new source file**, and no new artifact of any other kind: the walk's driver is the only other new file
this stage plans, and it lives under this feature's `scripts/`.

## Ripple notes

1. **The resolution's own type gains a field, and that is FR-004's price.** `ParagraphSpeech`'s
   `{text, language, voice, start, end, role, isComment}` (`lib/reader_service.dart:66-98`, documented for 015
   in `specs/015-comment-tag/data-model.md:174`) gains a nullable `display`. 015's own data-model row is
   **corrected in place with its date** by this feature's tasks, the way 016's rows were: a receipt that
   described the type as it stood is not rewritten, it is dated. The field is additive and nullable, so every
   existing construction, fake and test keeps compiling; a content with no tag and no mark sets it to `null`
   and is byte-for-byte what it was (INV-8).
2. **The display keeps its name** (`CommentDisplay`, `lib/comment.dart:291-349`) and grows a second elided
   kind. Renaming it to something neutral would touch 13 references in `lib/`, 12 in `test/` and 9 in `specs/`
   (015's and 017's reviewed records among them) — counted, and refused in research D7, which also records that
   the spec's own Assumption approves the extension in as many words (`spec.md:331-332`).
3. **`buildVideoPlan`'s comment list becomes the display** (`lib/video_timeline.dart:278-283`): the display
   carries the comments *and* the marks, so one object answers both. The parameter becomes optional and nullable
   (default `null` ≡ today's `const []`), so only the call sites that pass `comments:` are re-cut — **two**,
   found by grep: `lib/video_renderer.dart:274` and `test/video_comment_test.dart:45`. The other four call sites
   (`test/video_painter_test.dart:70`, `test/video_dialogue_test.dart:60`, `test/video_timeline_test.dart:41`,
   `:112`, plus `test/video_pictures_test.dart:56`) pass nothing and compile unchanged.
4. **The painter's one split becomes a cut set.** `_blockFor`'s `commentStart` (`lib/video_painter.dart:591-608`)
   is joined by the slot's `headings`; where a marked line also carries a comment, the comment's own characters
   keep 017's size and the face's weight and the rest of the line takes the derived size and `w700` (FR-012).
   The block's lines, height and scroll steps still come from that one layout call (`:616-640`), so 012's
   scrolling absorbs a taller line with no new mechanism — the row that measures it is `quickstart.md` 12.
5. **011's width guarantee is not extended.** A mark never paints larger than `xlarge` (FR-006 clamps at the
   largest offered size), which is the size 011 FR-012's guarantee was measured at and 017 re-measured for the
   bold faces (`specs/017-bold-comment-size/quickstart.md:114-125`) — so this feature adds no measurement to
   011's contract, and no row of 011's moves.
6. **016's own receipts hold.** The step list is computed over the **content** (`lib/comment.dart:205-215`,
   `lib/segmenter.dart:93-99`) and a mark is not a delimiter, so for a marked text the ranges are exactly those
   of the same text with the markers written as spaces (INV-7). The reader's own content carries no `#`
   (`test/step_ranges_test.dart:16-27`), so its seven steps and every number 016 recorded are unchanged; the
   marked variant is an addition beside them, not a re-cut.
7. **015's own receipts hold, and nothing of 015's moves.** The `text=<n>` line a frame reports keeps meaning
   *the painted characters* (`lib/video_renderer.dart:389`), and 015's fixture carries no mark, so
   `specs/015-comment-tag/quickstart.md:442-446`'s numbers stand untouched — this feature moves no sibling
   receipt, which is the claim `quickstart.md` 13 re-checks before the handback.
8. **The walk's own fixture format has a collision to avoid.** 015's and 016's drivers split their fixtures on a
   line that starts with `## ` (`specs/016-sentence-reading/scripts/klhu_walk_step.py:92-97`), which is exactly
   the shape of a **subtitle** — so 019's fixture cannot carry a bare `## Greetings` line as content, and its
   driver must recognise a section header by its own known keys rather than by the two characters. Named here
   because a fixture that silently loses its subtitle line is a device row that proves nothing.
9. **No ARB key is added** (110 → **110** for each of the four), no store is touched, no record is written, and
   the editor keeps painting the reader's text as written (`lib/reading_view.dart:2576-2589`) — the four ARBs'
   diff is part of `quickstart.md` 13's structural receipt.
10. **017's own records carry the amended rule, dated** — the feature is closed (32/32 done), so its
    `spec.md` is **reported, never rewritten**: its `tasks.md` gains a `## Superseded by later specs` note naming
    FR-015 as the rule that now owns a comment's size and weight, and its `breakpoint.md` gains a dated section
    recording which of its rows the change moves. **What moves**: its FR-007/FR-008/FR-009 (the comment is one
    offered size down) and its derived-size table (`data-model.md`). **What does not**: every device figure it
    holds — its rows and its fixture use a **regular** face, and FR-015 leaves a regular body's comment exactly
    what 017 shipped (row 12's own receipt says so, by rendering both). Its SC-003/SC-005's *"measure smaller"*
    becomes *"never larger, and never the same size **and** weight"* for the bold case — that is the one sentence
    of 017's the amendment makes false, and it is named in the supersession note rather than left standing.
11. **The comment's new case is proved here, not in 017's walk.** A closed feature's rows are re-run or
    re-cut only where they assert the moved behaviour; the new case (a bold body's comment) has no row of 017's
    to re-cut, so `quickstart.md` 8b walks it on this feature's build and 017's supersession note points at it.

## Complexity Tracking

Nothing to track: no dependency, no new stored state, no new setting, no new screen, no platform code, one new
source file. Stated thin rather than filled.

## Honest limits

1. **The ladder's top is a limit, not a promise.** A reader whose own face is **bold at `xlarge`** sits on the
   ladder's last rung: nothing is above them for the title, so their title and subtitle paint identically (both at
   24 black) — named by SC-006, pictured by `quickstart.md` 5's last row, and left to their own remedy (a smaller
   size, or a regular face). A second consequence of the reader's own chosen order: because the heavier rungs sit
   at the largest size alone, a **bold body at `small`/`medium`/`large`** takes its marks from the **regular** rungs
   above it — its headings are bigger and *lighter* than its body. `quickstart.md` 5b pictures it; the weight floor
   (a mark never lighter than the body) is the named alternative, refused here because it re-ties the title and the
   subtitle at `large`.
2. **The elision moves the line left by two characters**, and with it every later line of that paragraph (the
   marker's characters are simply not there). Every *offset* the app maintains is mapped exactly (INV-2), but
   the *look* of a paragraph whose first line carried a mark is a re-flow, and the walk's screenshots are what
   the reader judges it by (research's open question 1, whose fallback is a change to FR-003's own wording).
3. **iOS is unverified on this host** (no macOS). A mark is a rule over a string and a style on a span — both
   platform-neutral — and the weight rungs are 017's own cross-platform caveat, extended rather than closed: the
   `w900` rung is a **real** face for the default family on the walked device and a synthesised one elsewhere.
4. **Where the platform has no black (or, for `mono`, no bold) face, a weight rung is synthesised** — for every CJK
   word (the device's only CJK faces are two `Regular` files) and for `mono`, `serif-monospace`, `casual` and
   `sans-serif-smallcaps` (one `weight="400"` entry each). 017 measured that synthesis at **+51%** ink for Chinese
   at 30 pt against its own real Latin bold's +47% (`specs/017-bold-comment-size/research.md:33-35`), and the rows
   picture it. Nothing here can make a platform paint a face it does not ship.
5. **A `#` inside a comment's span is spoken as written** (FR-009 with FR-004's own limit): the marker rule
   stops at a comment's words, so a voice may say "hash" there — deliberately, since those characters are the
   reader's own text in a place the rule refuses to touch.
6. **017's shipped comment rule moves for a bold body only** (FR-015, US4): its own records carry the dated
   report, its SC-003/SC-005's *"measure smaller"* is the one sentence the amendment falsifies, and its own device
   rows stand because its fixture uses a regular face — the row that proves the new case is this feature's
   (`quickstart.md` 8b).
