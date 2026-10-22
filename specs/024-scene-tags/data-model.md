# Data model: scene tags

**Feature**: `024-scene-tags` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

Everything here is **derived** from the reader's text on every open. No field in this file is stored, and no preference
key is added (D10).

## §1 `SceneTag` — one tag in the reader's text

| field | meaning |
|---|---|
| `spelling` | as written: one of FR-001's four — `scene`/`escena` in whatever case, `场景`, `場景`; the set is closed to the shipped UI locales and is not gated on the UI language |
| `start` | offset of the line's first `[` (after the line's leading spaces/tabs) |
| `markEnd` | just past the closing `]` |
| `lineStart` | the line's first character (**including** its leading spaces/tabs — the span that is masked and elided starts here) |
| `headingStart` | `markEnd`, skipping the spaces/tabs that follow the `]` |
| `lineEnd` | just past the line's last character, the `\n` that ends the line **excluded**, trailing spaces/tabs/`\r` excluded |

The **line span** every surface uses is `[lineStart, lineEnd + 1)` — the line and its break (spec FR-004; plan D4).
When the line is the text's last and carries no break, the span is `[lineStart, text.length)`.

## §2 `Scene` — what a tag owns

| field | meaning |
|---|---|
| `tag` | the `SceneTag` |
| `ordinal` | 0-based position among the text's scenes, in text order |
| `first` / `last` | the content offsets bounding the sentences it owns: from `tag.lineEnd + 1` to the next tag's `lineStart`, or the text's end |
| `sentenceCount` | how many sentences fall in that range (0 for an empty scene) |

**Ownership rule** (spec FR-003): a scene owns every sentence whose **start** lies in `[first, last)`. The heading on the
tag line is not a sentence and is owned by nobody (FR-017), and sentences before the first tag are owned by nobody
(FR-014).

## §3 `SceneMask` — the same-length text speech is cut from

`sceneMasked(text)` is the content with every `[lineStart, lineEnd + 1)` replaced by **spaces of the same length**. It is
the string handed to the sentence/turn builders (plan D5).

**Worked example** (fixture `scene_sample`, 51 characters):

```
offset  0..5   她走进院子。
offset  6      \n
offset  7      (blank line)
offset  8..18  [场景] 1：青石观蚁        ← a tag line, span [8, 20)
offset 20..30  他推门进来。屋里很暗。
offset 32      (blank line)
offset 33..40  [scene]                   ← a tag line, span [33, 41)
offset 41..49  「有人吗？」她说。
```

```
masked:  "她走进院子。\n\n            他推门进来。屋里很暗。\n\n       「有人吗？」她说。\n"
length:  51 characters — unchanged
```

- The tag's own break became a space, so the line merges with the paragraph that follows it — exactly "as if the line
  had been deleted" (the blank line **before** the tag still ends the previous paragraph).
- The heading's `：` and any `。` inside it are spaces: no delimiter survives, so no sentence starts or ends in a tag
  line (spec FR-005's hard case).
- The second tag's line is masked whether or not anything follows it.

## §4 `SceneElision` — the same span, for painting

`displayOf(content).text` removes exactly `[lineStart, lineEnd + 1)` for every tag (spec FR-004, plan D6). The span list
gains a third kind beside 015's comment tags and 019's marks; the three are disjoint by construction because
`sceneTagsOf` takes comments' and marks' spans as `inside` (spec FR-015).

**Worked example, same fixture**: the painted text is

```
"她走进院子。\n\n他推门进来。屋里很暗。\n\n「有人吗？」她说。\n"
```

— the content with the two tag lines (and their breaks) deleted, 39 characters. No blank line, no gap, no heading.

## §5 The pairing — `assignScenesToPictures`

| input | meaning |
|---|---|
| `scenes` | the scenes' sentence-index ranges, derived by the caller: scene `k` owns `VideoSentence`s whose `start` lies in its `first..last` |
| `sentences` | the page's own `VideoSentence` list, in the render's order (012's) |
| `pictureCount` | how many pictures the page holds, in **the page's order** (021's moves decide it) |

| output | meaning |
|---|---|
| `List<PictureRun>?` | one run per picture, `spans` = **contiguous sentence indices** in order; `null` when the pairing is empty (no scene owns a sentence, or no pictures) |

**Rule** (spec FR-009/FR-013): picture `i` takes scene `i`'s range, for `i < min(pictureCount, scenes.length)`; a scene
that owns no sentence is **skipped** (it consumes no picture); scenes beyond `pictureCount` and pictures beyond the
scene count are left exactly as they were.

**Worked example**: 5 pictures, 3 scenes owning sentences `[0..2)`, `[2..5)` and `[5..5)` (the last empty) → runs
`PictureRun(0, spans=[(0,2)]), PictureRun(1, spans=[(2,5)]), PictureRun(2, spans=[]), PictureRun(3, spans=[]),
PictureRun(4, spans=[])` — two runs written, one empty scene consuming nothing, two pictures left empty.

**What is never included**: a sentence before the first tag (FR-014), and the heading (FR-017) — because neither is a
sentence at all, the second by §3.

## Invariants

- **I1** — `sceneMasked(text)` has the **same length** as `text`; every offset outside a tag line is unchanged; every
  character inside one is `' '`.
- **I2** — the masked text holds **no delimiter** that stood inside a tag line: `。！？；.!?;` and the ellipses are
  spaces there.
- **I3** — every sentence's `start`/`end` is a **content** offset (no remapping anywhere).
- **I4** — `sentenceRanges(sceneMasked(text))` equals, sentence for sentence and after trimming, `sentenceRanges` of the
  content with the tag lines **deleted** (spec SC-003's equality).
- **I5** — `displayOf(text).text` equals the content with the tag-line spans **removed, byte for byte** (spec SC-002).
- **I6** — a text with no scene tag: `sceneMasked(text) == text` and `displayOf` is what it was before this feature, so
  every closed feature's receipt is untouched (spec FR-016/SC-001).
- **I7** — ownership: `scene.owns(sentence) == sentence.start ∈ [tag.lineEnd + 1, nextTag.lineStart)`, with the last
  scene's bound the text's end; an empty scene owns nothing; the heading and the preamble are owned by nobody.
- **I8** — the elision span and the mask span are **the same numbers** (`[lineStart, lineEnd + 1)`): one derivation,
  two uses, so a painting row and a speech row cannot disagree about which characters the tag line is.
- **I9** — pairing: runs are `min(pictureCount, scenesWithSentences)`; each run's spans are contiguous and ascending;
  no sentence index appears twice; the runs' order equals the scenes' order; empty scenes consume no picture.
- **I10** — `formatForSceneTags` is idempotent and its diff is **blank lines only**; composed with 014's
  `formatForDialogue` the press keeps 014's contract (one Undo, twice = once).
- **I11** — for any offset `o` outside every elided span, `toContent(toDisplay(o)) == o`.
- **I12** — no new stored key: the app's prefs hold nothing this feature writes (the assignment it produces is 020's
  own record shape).

## Why no `contracts/` file

A contract is owed when an interface outlives the code that writes it (a stored key, a file format, a platform channel).
This feature has none: `sceneMasked` and `assignScenesToPictures` are functions inside one binary, and their contract is
§3/§5 plus the invariants above, each witnessed by a unit row. A `contracts/` file here would restate the data model in
a second place and drift from it.
