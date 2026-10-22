# Breakpoint — 024 scene tags, walked on the emulator

**Feature**: `024-scene-tags` | **Build**: `flutter build apk --debug` installed over
`emulator-5554` (Android, `klhu` AVD) on 2026-10-22 | **Driver**:
`specs/024-scene-tags/scripts/klhu_walk_scene.py <row>` | **Fixture**:
`specs/024-scene-tags/scripts/klhu_scene_fixture.txt`

One writer, one build, one file: every device row appends here, and the number that
identifies a row is the driver's own key.

## What landed before the walk (unit side)

```
flutter analyze                                   → No issues found! (1.1 s)
flutter test --concurrency=2                      → +901: All tests passed!   (1:19)
grep -cE '^  "[\^@"]+"' lib/l10n/app_{en,zh,zh_Hans,es}.arb → 135 135 135 135   (was 131)
ls test/*.dart | wc -l                            → 65   (was 62: this feature's three new files)
ls lib/*.dart | wc -l                             → 32   (was 31: lib/scene_tag.dart)
flutter gen-l10n                                  → idempotent; test/l10n_keys_test.dart green
```

The feature's own rows are **44** of the 901 (26 in `test/scene_tag_test.dart`, 7 in
`test/reading_view_scene_test.dart`, 4 in `test/picture_assignment_scene_test.dart`, 7 in
`test/picture_assignment_screen_scene_test.dart`); the baseline 857 are untouched.

```
check_tasks_format.py   specs/024-scene-tags   → OK: format, sequencing and spec-id coverage check out
task_id_audit.py        specs/024-scene-tags   → 35 tasks, 0 done, 4 [P]      (before the ticks below)
check_row_coverage.py   specs/024-scene-tags   → quickstart 25 rows claim 25 of 25; no row claims: none
check_quickstart_coverage.py specs/024-scene-tags → 15 rows ([unit] 9, [device] 6); unclaimed: none
spec_consistency.py     specs/024-scene-tags   → no divergence
check_artifact_refs.py  specs/024-scene-tags   → checked 68 line references; no unresolved references
```

## Row 10 — the page shows nothing of the tag, and paints the twin

`ADB_SERIAL=emulator-5554 /usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 10`
→ **10/10 checks passed**.

- The fixture's three tag spans, by the rule's own scan: `[(8, 20), (33, 41), (56, 64)]`.
- The page's painted block, read off the dump, is **byte-equal to the deleted-line
  twin** — 43 characters, no `[`, no `场景`/`场景(sic)`, no `青石观蚁`, no `1：`, no `2：`:

```
她走进院子。

他推门进来。屋里很暗。

「有人吗？」她说。门开了。

脚步声远了。
```

- The pixel side: the fixture's page and the twin's page ink the **same scanlines**
  (**0** differ) — 136 inked scanlines in the text block, and the widest vertical gap
  inside that block is **71 px on both**. A tag line left painted would add rows of its
  own and a gap where a tag stood would be a band no line spacing explains; neither is
  there. Stills: `/tmp/klhu_out/scene_row10_fixture.png`, `scene_row10_twin.png`.

## Row 11 — the read runs through a boundary, silent on the tag

`… klhu_walk_scene.py 11` → **4/4 checks passed**.

- **Seven utterances on the fixture and seven on the twin**, identical texts in identical
  order, none blank, none carrying a tag: `她走进院子。` `他推门进来。` `屋里很暗。`
  `「有人吗？` `」她说。` `门开了。` `脚步声远了。`
- The app's own `klhu read range` lines show the tag lines being stepped over rather than
  spoken: the fixture reads `0..6, 8..14, 14..19, 21..26, 26..30, 30..34, 56..70` — the
  jump from `34` to `56` is the two tag lines and the blank lines between them, with no
  range and no utterance inside either.
- The eighth press is the text's end: nothing is in force, ▶ takes the first step again
  (`0..6`), and no utterance is logged for a boundary on the way.

## Row 12 — one press, one Undo, blank lines only

`… klhu_walk_scene.py 12` → **5/5 checks passed** (content `他推门进来。\n[场景] 1：青石观蚁\n屋里很暗。`).

- Before: the field holds the row's text byte for byte (24 chars).
- After one Format press: `他推门进来。\n\n[场景] 1：青石观蚁\n屋里很暗。` — **25 chars, one
  added, and it is a line break**; the tag line stands alone, no character of the reader's
  text changed.
- A second press changes nothing (**25 chars** still): the button is disabled, not a silent
  no-op.
- One Undo restores the input byte for byte (24 chars).

## Row 13 — the option takes the scenes, and a move still works

`… klhu_walk_scene.py 13` → **10/10 checks passed**.

- Five pictures chosen through the platform's own file dialog; the pass opens with every
  thumbnail at `0`.
- The option's label is on the page; one press and the counts are **`2, 3, 1, 0, 0`** — the
  three scenes over the first three pictures, the last two holding nothing, **6** sentences
  in the runs, and no question asked because nothing was assigned.
- Done carries the runs back to the prompt, whose picture cells read `2`, `3`, `1`.
- A picture the option left empty still moves: a hold on the fifth, `Move left`, and the
  strip reads `white, black, red, **green, blue**` — the pairing locked nothing.
- On a **tag-free** content the same page offers **no option at all** (`Auto assign scenes`
  absent), which is FR-008's other half.

## Row 14 — the render's frames carry no tag

`… klhu_walk_scene.py 14` → **5/5 checks passed**.

- The renderer's own line: `pictures=5 ranges=(0,154),(155,272),(273,373),None,None
  sentences=7` — three pictures carrying the three scenes, two left empty, and **one slot
  per sentence of the read**, the tag lines named by no range.
- The render's own report: `12466 ms, 545877 bytes, **374 frames**`, written to
  `…/cache/klhu_video.mp4`.
- 7 slot spans against the read's own 7 sentences: every span is one of them, and no span
  reaches a tag line's offsets (`[8,20)`, `[33,41)`, `[56,64)`).

## Row 15 — the five closed features' receipts, re-run on tag-free content

Each row's own command, unmodified, on the build this feature produces. A tag-free
content is what FR-016 is about, and these are the rows whose painted string, step
count, frame count and page layout 024's seam could have moved.

```
klhu_walk_comment.py 17     → 24/24 PASS   painted 'Hola.\n\nHow are you?', two utterances,
                                            comment=1 on the comment's own, [注]/[nota]/[註] alike
klhu_walk_head.py 10        → 14/14 PASS   ink per rung 10205 · 14245 · 20070 · 27210 · 33003
klhu_walk_step.py 5         → 13/13 PASS   three presses on the steps' own ranges, the fourth
                                            silent, the fifth back at 0..15
klhu_walk_assignment.py 6   → 14/15        sentences=10, pictures=3, ranges=(0,206),(207,351),
                                            (352,551), 776933 bytes, frame pixels as 020 recorded —
                                            **one FAIL, and it is 020's own stale precondition**
klhu_walk_pass.py 8         → 5/5 PASS     three cells, each with its own name and count 0
klhu_walk_video.py 32       → 41/41 PASS
```

The one failure is **not a 024 movement**: 020's `assign` asserts its clean-page
precondition against the chip *wording* `No sentences assigned`, which 021 replaced with
the bare count (021's own count-only cell, that spec's own decision); the row's own detail line shows the page painting
`['0', '0', '0']`. Every measured thing that row checks — the render's sentence count,
the pictures' count, the ranges, the file's bytes and three frames' own pixels — passes. A
row that reads a word an earlier spec removed is a finding about that row, and nothing
about this build moves a count (021's own driver carries the same note in `assign_own`).

**SC-001's identity holds on the device**: six closed features, six rows, every count
beside the number its own quickstart records, with no row re-cut.

## Findings — where the walk disagreed with the plan, and what is owed

1. **The fixture reads as 7 sentences and owns `2, 3, 1`, not the quickstart's 5 and
   `2, 2, 1`.** The shipped segmenter does not treat `」` as a sentence closer, so
   `「有人吗？」她说。` splits at `？` into `「有人吗？` and `」她说。` — pre-existing behaviour
   (the twin splits identically, which is why row 11's equality still holds), and 024 must
   not change it (FR-016). Every count above is the measured one; the quickstart's `five`
   counted the scenes' sentences, and its `2, 2, 1` counted the reader's sentences rather
   than the app's.
2. **Ownership is by the sentence's first spoken character, not its range start.** The
   content's first sentence in a tagged paragraph begins *inside* the tag line, so a raw
   start test gave `1, 2, 0` at the unit stage; `Scene.owns` now reads the position where
   the sentence begins to say something (data-model §2's wording, made precise).
3. **`T010` needed no edit at `lib/reader_service.dart:450`.** The speeches there are cut
   from the *display's* own words, which already elide the tag line (T008), so the mask
   reaches the read one seam earlier — at `turnsOf` in `lib/speech_resolver.dart`, where a
   role tag under a scene tag must still be its paragraph's head.
4. **One closed-feature row carries a precondition an earlier spec superseded** — 020's
   `assign` reads the chip wording `No sentences assigned`, which 021 replaced with the
   count. It fails on this build and would fail on the one before it; the row's own
   measured checks (sentences, pictures, ranges, bytes, pixels) all pass. Recorded here
   rather than edited into 020's driver, per this feature's own rule.
