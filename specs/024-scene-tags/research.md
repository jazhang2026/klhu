# Research: scene tags — what the tree carries, and the readings this plan takes

**Feature**: `024-scene-tags` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

## Baseline, measured on the checkout this plan starts from (`0ef44e7` + 023's implement tree)

```
flutter analyze                                   → No issues found! (1.3 s)
flutter test --concurrency=2                      → +857: All tests passed!   (1:18)
grep -cE '^  "[^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 131 131 131 131
ls test/*.dart | wc -l                            → 62
ls lib/*.dart | wc -l                             → 31
```

The tree is 023's implement tree, uncommitted (the reader commits their own work); nothing in this feature's plan depends
on 023's uncommitted files, and the one shared surface — `displayOf` — is untouched by them.

## §1 What the tree already carries (the evidence the requirements rest on)

| rule | where | what it answers |
|---|---|---|
| 014 role tag | `lib/dialogue.dart:116` (`roleTagAt`), `:167` (`turnsOf`), `:249` (`formatForDialogue`) | `{name}` at a **paragraph head**, the rest of the line is the turn's text; Format's only difference is blank lines |
| 015 comment tag | `lib/comment.dart:14` (ASCII brackets), `:25` (four spellings), `:126` (`commentTagAt`), `:156` (`commentsOf`), `:206` (`stepRanges`) | `[comment\|注\|註\|nota]` **anywhere** in a paragraph, owns the rest of it; its characters are never painted or spoken |
| 019 head tag | `lib/head_tag.dart:58` (`headTagsOf`) | `#`/`##` at a **line head**; the marker is elided, the line's text is painted and read |
| the one elision | `lib/comment.dart:386` (`displayOf`), `:298` (`CommentDisplay`) | comments' tags + marks in one span list, with `toDisplay`/`toContent` between content and painted offsets |
| the sentences | `lib/segmenter.dart:93` (`sentenceRanges`), `:63` (paragraphs) | delimiters per paragraph; a paragraph with no delimiter is one sentence |
| the speeches | `lib/reader_service.dart:450` (`_sentencesOf`), `lib/video_timeline.dart:80` (`videoSentencesOf`) | paragraphs → sentences, cut into `ParagraphSpeech`/`VideoSentence` with **content offsets** |
| the assignment | `lib/picture_assignment.dart` (`PictureRun`, `holderOf`, `refusedAdd/Remove`, `movePicture`), `lib/picture_assignment_screen.dart:478` (AppBar's `Done`), `:137` (`holderOf` use) | runs of **contiguous sentence indices**, in order; one page for the reader's own assignment |
| new strings | `lib/l10n/app_{en,zh,zh_Hans,es}.arb`, `test/l10n_keys_test.dart` | 131 keys each; 023 added the 131st this way |

So today `[场景] 1：青石观蚁` on its own line is **one narration sentence**: spoken, painted, a row on the assignment page
(the page shows it), and one slot in a video — because a paragraph with no delimiter is one sentence
(`lib/segmenter.dart:93`) and nothing elides those characters.

## §2 Decisions

### D1 — The rule lives in its own module: `lib/scene_tag.dart`

A tag whose grammar looks like 015's and whose position looks like 014's, written in 024's own file with its own test
table. **Alternatives refused**: a shared "tag grammar" table with 014/015/019 rebuilt on it (003's shape, and 015's own
decision D2 refused the same thing); importing `comment.dart`'s scanner (the two rules answer different questions and a
shared table routes a change to either through the other's file). **The deliberate cost**: a second copy of the shape;
**the guard**: each rule keeps its own table, so a divergence is a red test in whichever feature changed its mind.

### D2 — Four spellings, one per shipped UI locale, all live in every content

`scene` and `escena` in any ASCII case, `场景` (Simplified), `場景` (Traditional) — the shipped-locale rule
(`references/rule-scope-and-marker-spellings.md`: one spelling per shipped UI locale, all live in every content),
following 015's own four comment spellings (`comment`/`注`/`註`/`nota`). **Re-cut 2026-10-20, after this stage was
written**: D2 first kept the reader's two and recorded the other two as *not taken now*; the reader then asked for them
in a message of their own (`please include: 場景、escena`), so all four are taken, and none is gated on the UI language
the app is showing.

| candidate | corpus: files under `lib/ test/ assets/` | verdict |
|---|---|---|
| `scene` | **1** (`test/video_pictures_test.dart:381`, a picture's name) | taken |
| `场景` | **0** | taken — the reader's own `[场景]` |
| `場景` | **0** | taken — the reader's own ask, 2026-10-20 |
| `escena` | **0** | taken — Spanish is a shipped UI locale |

The corpus check is the receipt that no accepted spelling collides with shipped prose: `scene`'s single hit is a
fixture's picture **name**, and a `[scene]` there would have to stand at a line head to matter (R1's table covers it);
the other three occur in no shipped file at all, and the only tree-wide hits are this feature's own artifacts and the
reader's `text.txt`. Measured 2026-10-20 with `grep -rIl <spelling> lib test assets`.

**Alternatives refused**: the reader's original two (`scene`, `场景`) only — refused by the reader themselves on
2026-10-20, and it is the shape that leaves 015's own precedent (four, one per shipped locale) unapplied; a sixth
spelling for a language the app does not ship (French `scène`, and similarly a Japanese `シーン`) — refused because the
set's rule is the **shipped** locales: extending it is a locale decision, not a table row.

### D3 — Recognition: a line's head, the rest of the line is its heading

`[` at a line's head after leading spaces/tabs; the closing `]` on the same line; the name is one of FR-001's four
(`scene`/`escena` any ASCII case, `场景`, `場景`); anything after the `]` on that line is the tag line's **heading** (the reader's own example
`[场景] 1：青石观蚁`). A `[` with any character before it on the line is the reader's text, and so is a tag-shaped run
mid-sentence. Trailing spaces/tabs and a `\r` belong to the line's end. Full-width `［场景］` is the reader's text.

**Alternatives refused**: alone-on-the-line (the spec's first reading; refused by the reader's own example, `keep 1`);
anywhere-in-the-paragraph (015's shape — it would make `他说 [场景] 我们走` a boundary the reader never wrote).

### D4 — The whole tag line is the marker

Painting: the elision span is `[lineStart, lineEnd + 1)` — the tag, the heading and the break. Speech: the same span
contributes no sentence at all, and no delimiter inside it starts one.

**Why the break goes too**: 019 elides only its marker because a mark's line carries the reader's own text; here the
line is the marker, and keeping its break would leave a blank line — a visible scene break, which the spec refuses (Q1)
and the item forbids.

**The cost, stated where a reviewer will see it**: this is the first rule in the app that hides characters the reader
typed (`1：青石观蚁`). The reader was asked as its own form and answered `keep 1`.

### D5 — The speech seam is a same-length mask, applied where the sentences are cut

`sentenceRanges` is the tree's single sentence rule and stays pure. A tag line is instead **masked**: every character
of `[lineStart, lineEnd + 1)` becomes a space, so the string keeps its **length and every offset**, and:

- no delimiter survives inside the heading, so nothing starts or ends a sentence there (the spec's FR-005's hard case:
  `[场景] 第一场。他说。` must not yield a sentence for `第一场。`, and must not swallow `他说。`);
- a tag line's own paragraph becomes a run of spaces, which the speech builders already drop
  (`video_timeline.dart`: whitespace-only segments are skipped; `turnsOf` drops empty turns — **verified by a unit row,
  see §4 R4**);
- every consumer keeps using content offsets, so highlights, assignment rows and slot spans need no remapping.

The mask is derived once per open (`sceneMasked(text)`) and handed to the four places that cut sentences or turns:
`lib/reader_service.dart:450` (the speeches every other surface reads), `lib/comment.dart:206`'s callers in
`lib/reading_view.dart:1029/:1337` (▶'s steps), `lib/reading_view.dart:1224/:1242` (the page's own sentence list and
taps), and `lib/dialogue.dart:167`'s three callers (`lib/reading_view.dart:1576/:1592/:1706`).

**Alternatives refused**:
- **split first, drop the sentence that starts in the tag line** — leaks the heading's delimiters: the sentence before
  them ends early and the text after them starts a new sentence, which is not "as if the line were deleted";
- **a stripped copy of the text** (real deletion) — every offset moves, and every consumer would need a mapping back;
- **teaching `sentenceRanges` about tags** — couples the pure delimiter rule to a feature's grammar (015 refused the
  same move for comments and filters outside instead).

### D6 — Painting rides the one elision

`displayOf` (`lib/comment.dart:386`) gains a third kind of span, exactly as 019's marks did: it calls `sceneTagsOf`,
adds `[lineStart, lineEnd + 1)` to the elided list, and `toDisplay`/`toContent` keep answering with one arithmetic. The
page and the video painter both consume `displayOf` already (`lib/reading_view.dart:2861`,
`lib/video_renderer.dart:314`), so neither knows a third kind exists.

**Grounding note**: `comment.dart` importing `scene_tag.dart` is the same shape as its existing `head_tag.dart` import
(`lib/head_tag.dart:58` is called from `displayOf`'s own derivation) — the display is one seam by design, and the *grammar*
stays in the feature's own file. FR-015's seam (a tag inside a comment, or on a marked line) is honoured by passing
comments' and marks' spans into `sceneTagsOf` the way `headTagsOf` takes `inside`.

### D7 — Format: 024's own function, composed in the press

`formatForSceneTags(text)` is 024's pure function (blank line before a scene tag that does not already start a
paragraph, nothing else). The edit toolbar's press calls `formatForSceneTags(formatForDialogue(text))` in one assignment
— still one Undo, still blank lines only, still "twice is once" (the composition is idempotent because neither function
moves a character). **Alternative refused**: teaching `formatForDialogue` the scene tag's rule (014's module would then
own 024's grammar, and 014's own tests would read as changed when nothing of 014 moved).

### D8 — Pairing: a pure function over 020's model, in 020's file

`assignScenesToPictures({scenes, sentences, pictureCount})` in `lib/picture_assignment.dart`, taking the scenes' own
**sentence-index ranges** (computed by the caller from `scene_tag.dart`'s offsets + the page's `VideoSentence`s). It
answers `List<PictureRun>` — contiguous spans of sentence indices, in order — or null when nothing pairs.

- `scene_tag.dart` never imports 020's types; 020's file never imports 024's grammar: the coupling is one integer range
  list each way.
- **Alternatives refused**: the pairing in the screen (a widget would own a rule the unit rows must test without a
  widget build); the pairing in `scene_tag.dart` (it would have to know `PictureRun` and 020's invariants).

### D9 — The option's surface: a second AppBar action, beside `Done`

`lib/picture_assignment_screen.dart:478`'s AppBar carries one action (`Done`). The option goes **beside it**, labelled
by a new string, and is **absent** when the content holds no scene (FR-008). When any run is non-empty, choosing it opens
the page's own two-button dialog shape (the `_askSwitch` pattern at `:184`) naming how many runs go; refusing changes
nothing (FR-012). Four new strings: the option's label, the dialog's title, its body (with the count), its confirm —
131 → 135 keys in each of the four ARBs.

**Alternatives refused**: a button above the sentence list (it would push the list down on every content, tagged or not);
a menu (an extra tap for the page's one new action, and 021's rows read labels off a dump where a menu's items are
invisible until opened).

### D10 — Nothing is stored, everything is derived

Scenes are recomputed on every open, like 014's roles, 015's comments and 019's marks; the assignment the option writes
is 020's own record, so nothing new is persisted and nothing has to be migrated.

## §3 The seams this feature touches, and the size of each change

| file | change | why |
|---|---|---|
| `lib/scene_tag.dart` | **new** — the grammar, `sceneTagsOf`, `sceneMasked`, `scenesOf` | D1, D3, D5 |
| `lib/comment.dart:386` | `displayOf` derives scene spans and elides them (a third kind) | D6 |
| `lib/reader_service.dart:450` | the speeches are cut from the masked text | D5 |
| `lib/reading_view.dart:1029/:1337` | ▶'s steps from the masked text | D5 |
| `lib/reading_view.dart:1224/:1242` | the page's sentence list/taps from the masked text | D5 |
| `lib/reading_view.dart:1576/:1592/:1706` | `turnsOf` from the masked text | D5 |
| `lib/reading_view.dart:736` | the Format press composes 024's function with 014's | D7 |
| `lib/picture_assignment.dart` | **new** pure `assignScenesToPictures` | D8 |
| `lib/picture_assignment_screen.dart:478` | the option's action + its dialog | D9 |
| `lib/l10n/app_*.arb` (4) + generated files | four new strings | D9 |
| `test/scene_tag_test.dart` etc. | **new** test files (one per unit row's subject) | — |

No new dependency, no network, no storage key, no platform channel.

## §4 Risks and the measurements that settle them

- **R4's hard case — a masked tag line must produce no turn, step or slot.** The speech builders drop whitespace-only
  segments (`lib/video_timeline.dart`'s `if (cut.text.trim().isEmpty) continue;`) but `turnsOf`'s own emptiness test is
  a **start/end** comparison, not a trim (`lib/dialogue.dart:156`'s comment says "a paragraph that is only a tag is
  dropped" — that was written for `{name}`). A masked paragraph is spaces, not an empty range: the first unit row must
  prove the turn is dropped, and if it is not, the implement stage trims in `turnsOf`'s own emptiness test (014's file,
  one condition) rather than masking differently.
- **A comment inside a tag line** (`[scene] 1：[注] x`): the mask destroys the comment's characters before `commentsOf`
  sees them, so its tag would stop being a comment. FR-015 says a tag inside a comment is not a scene; the reverse
  direction is not specified. The plan takes the narrower reading — **the tag line wins** (its text is the marker) —
  and R1's table records it as a pinned case.
- **A tag line with no blank line after it** (the reader never pressed Format): still one paragraph with the next line,
  and the mask merges them for speech exactly as deletion would. R4's table covers it.
- **Two tags in a row / a trailing tag**: empty scenes, no picture consumed (R2, R7).
- **The device's dump**: a hidden tag means the page's `uiautomator dump` must contain no `[场景]`/`[scene]`/`青石观蚁` string — the
  device rows read the dump rather than a screenshot for that half, and read pixels for the band/no-gap half.
- **The read's own log lines**: the app prints one `klhu render`/read line per utterance; the device rows count them
  against the deleted-line content's count (SC-003, SC-006).
- **021's rows that read the assignment page's labels** (a new AppBar action on a page their drivers dump): their own
  counts may grow by the new label's presence. They are re-run (R15) and their receipts re-taken rather than assumed.

## §5 What this feature deliberately does not research

The motion/plate/picture work 023 added, 019's size/weight ladder, and 015's speech language rules are independent of a
tag whose only effect is at a line's head and in the sentence list. No measurement of theirs is taken here beyond the
identity rows (R15).
