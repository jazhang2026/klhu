# Quickstart: how 024 is walked

**Feature**: `024-scene-tags` | **Plan**: [plan.md](./plan.md) | **Data model**: [data-model.md](./data-model.md)

Fifteen rows: nine unit, five device, one closing. Every row names the **one** thing it proves, the command that runs it,
and the numbers it is expected to land on. A row that cannot fail is not a row; a number nobody took is not evidence.

**The device rows' driver**: `specs/024-scene-tags/scripts/klhu_walk_scene.py` (new; 021's driver supplies the library
seeding, the file dialog and the dumps, and 023's supplies the frame reads). Its fixture is
`specs/024-scene-tags/scripts/klhu_scene_fixture.txt`:

```
她走进院子。

[场景] 1：青石观蚁
他推门进来。屋里很暗。

[scene]
「有人吗？」她说。门开了。

[场景] 2：
脚步声远了。
```

— two of the four spellings, a heading on each tag line, four scenes' worth of text across three tags plus a preamble, and five
sentences the app must read (the same five the deleted-line twin carries).

## Unit rows

### 1. The tag's grammar is the four spellings, at a line's head — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "the tag line's grammar"`
Steps: one table, one line per shape — `[scene]`, `[SCENE]`, `[Scene]`, `[场景]`, `[場景]`, `[escena]`, `[ESCENA]`,
`[场景] 1：青石观蚁`, `[escena] 3：夜`, ` [scene]` (leading spaces), `[scene]   ` (trailing), `[scene]\r` (CRLF),
`[scene] 第一场。他说。` (a heading with delimiters); and the refusals: `［场景］`, `［場景］` (full width), `[scenes]`,
`[escenas]`, `[scene]` mid-sentence, `text [scene]`, `# [scene]`, `[scene` (unclosed), `[]`, `[comment]`, `[注]`,
`[scene]` inside a comment's span. A second pass runs the **twin content** — the fixture with its three tags respelled
`[場景] 1：…`, `[ESCENA]`, `[escena] 2：…` — through `sceneTagsOf`/`scenesOf` and compares it with the fixture's own.
Expected: every accepted shape yields one `SceneTag` whose `lineStart`/`lineEnd` are **the whole line** (data-model §1)
and whose `headingStart` is past the `]`; every refused shape yields **none**, and the text it lives in is unchanged by
every other rule; the twin's three scenes own the fixture's three scenes' sentences, spelling for spelling, so each of
the four spellings is proved **inside a content** and not only as a bare line.
Evidence: the table itself, printed branch by branch; the count of accepted shapes.
Proves FR-001, FR-002, FR-007, SC-007.

### 2. What a scene owns: the sentences after its line, until the next tag — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "what a scene owns"`
Steps: on the fixture: the preamble's sentence, each scene's sentence range, the two empty cases (a tag as the last line;
two tags back to back), and the heading.
Expected: the preamble (`她走进院子。`) belongs to **no** scene; scene 1 owns `他推门进来。` and `屋里很暗。`; scene 2 owns
`「有人吗？」她说。` and `门开了。`; scene 3 owns `脚步声远了。`; a tag line's **heading is owned by nobody**; a scene with
no sentence between it and the next tag has `sentenceCount == 0` and consumes no picture.
Evidence: the ownership table, scene by scene, with the sentence texts printed.
Proves FR-003, FR-014, FR-017, SC-003.

### 3. The page paints the text as if the tag lines were deleted — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "the painted string"`
Steps: `displayOf(fixture).text`, and the same for a text mixing scenes, a 015 comment and a 019 mark; compare byte for
byte against the content with the tag-line spans removed.
Expected: **byte equality** (data-model I5); no `[`, `场景`, `場景`, `scene`, `escena`, `青石观蚁`, `1：` anywhere; no double blank line where a tag
stood; the comment's and the mark's own elision unchanged; a tag-free text's `displayOf` equal to the pre-feature build's
(the identity half).
Evidence: the two strings' lengths, a diff of zero, and the tag-free comparison.
Proves FR-004, FR-016, SC-001, SC-002.

### 4. Nothing is spoken, stepped, or slotted for a tag line — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "not a sentence, not a step, not a slot"`
Steps: `sentenceRanges(sceneMasked(fixture))`, `stepRanges(sceneMasked(fixture))`, `videoSentencesOf` over the speeches,
and `turnsOf(sceneMasked(fixture))` — each compared against the same content with the tag lines **deleted**; the hard
case is the heading `[场景] 1：青石观蚁` where a tag is followed by text on the line, plus the pathological
`[场景] 第一场。他说。` (a delimiter inside the heading).
Expected: same count, same texts (after trim), same order, both directions; the delimiter inside the heading starts no
sentence and swallows no text; the mask has the same length and no delimiter inside a tag line (I1/I2/I4).
Evidence: the four lists side by side with the deleted-line twin's; the `。` case printed on its own.
Proves FR-005, SC-003, SC-008.

### 5. A tag-free content's four counts are the ones the app has today — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "a content without a scene tag"`
Steps: a sample of the app's own fixtures and 012's pre-set text, through the four derivations, with and without the new
code path (the mask returns the text unchanged).
Expected: `sceneMasked(text) == text`; the display string, the step count, the slot count and the utterances equal the
pre-feature values the existing tests already pin; nothing to mask costs nothing extra.
Evidence: the equality of the masked string, and the four counts quoted against the skipped tests' own numbers.
Proves FR-016, SC-001.

### 6. Format gives a tag its own paragraph and nothing else — [unit]

Test: `flutter test test/reading_view_scene_test.dart --plain-name "the Format press and a scene tag"`
Steps: a text with a tag mid-paragraph, a tag that already heads its paragraph, two tags in a row, a tag inside a marked
line; press Format (the composed function), press it twice, undo once.
Expected: the diff is **blank lines only** (a line-by-line diff whose every changed line is empty), every tag's own
characters byte-identical, `formatForSceneTags(formatForSceneTags(t)) == formatForSceneTags(t)`, one Undo restores the
input, 014's own behaviour unchanged on a text with no scene tag.
Evidence: the diff, the idempotence equality, the undo's restored string.
Proves FR-006, SC-004.

### 7. The pairing: i-th picture with i-th scene, inside 020's rules — [unit]

Test: `flutter test test/picture_assignment_scene_test.dart --plain-name "the scene pairing"`
Steps: an N×M grid — (N, M) ∈ {(0,1), (1,0), (1,1), (2,3), (3,2), (5,3), (3,5)} on the fixture; for each, the runs the
function answers, then the same assignment made by hand through 020's own add/remove calls.
Expected: `min(N, M)` runs written; each run's spans contiguous and ascending; no index twice; runs in the scenes' order;
an empty scene consumes no picture; the preamble's sentence in no run; the result equals the hand-made assignment run
for run; `null` when nothing pairs.
Evidence: the grid's table, and the hand-made equality per cell.
Proves FR-009, FR-010, FR-013, FR-014, FR-017, SC-005.

### 8. The page's option: there when scenes exist, asking before it replaces — [unit]

Test: `flutter test test/picture_assignment_screen_scene_test.dart --plain-name "the option"`
Steps: open the page for (a) a content with scenes and no runs, (b) scenes with runs, (c) no scenes; choose the option in
(a) and (b); refuse the question in (b); open (c).
Expected: the action is **absent** in (c) and present in (a)/(b); in (a) it writes the pairing with no question; in (b) a
dialog naming how many runs go appears, and refusing leaves `_runs` **exactly** as it was (same spans, same order); the
option's label is read from the four ARBs (no hard-coded string), and the key audit stays green (131 → 135 keys each).
Evidence: the labels the page builds for each case, the runs before/after a refusal, the four ARBs' counts.
Proves FR-008, FR-011, FR-012, SC-005.

### 9. The three rules do not eat each other's text — [unit]

Test: `flutter test test/scene_tag_test.dart --plain-name "beside the comment and the mark"`
Steps: a tag inside a comment's span; a comment inside a tag line; a tag on a line carrying a 019 mark; a mark inside a
tag line; a comment and a scene in the same paragraph.
Expected: a tag inside a comment is **not** a scene (FR-015); a tag on a marked line is **not** a scene; the tag line,
where it wins, takes the comment's characters with it (pinned in research §4); no shape makes either rule re-scan the
other's text or produce two elisions of the same characters (I11's round trip holds).
Evidence: each shape's display string and scene count, printed.
Proves FR-015, SC-007.

## Device rows

### 10. The page on the device shows nothing of the tag — [device]

Test: `/usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 10`
Steps: seed the fixture, open it, dump the page; then screenshot and scan the text area for a gap (a horizontal band of
pure page background between two text lines).
Expected: the dump holds **no** `[场景]`, `[scene]`, `青石观蚁`, `1：` string; the painted text runs continuously across
where each tag stood (no band of background wider than a normal line gap); the same page with the tag lines deleted
looks the same in the screenshot's own pixel comparison.
Evidence: the dump's labels, the band scan's numbers, the two screenshots' comparison.
Proves FR-004, SC-002, SC-006.

### 11. The read runs through a boundary with no pause and no silence — [device]

Test: `/usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 11`
Steps: read the content from the first sentence to the last, counting the app's own utterance lines; then read the
deleted-line twin, same way.
Expected: **five** utterances in both, the same texts in the same order; no utterance whose text is blank or a tag; the
highlight crosses each boundary in one step (the step index after `屋里很暗。` is `「有人吗？」她说。`, not a skipped
step); the read's own elapsed time differs only within one utterance's worth.
Evidence: both logs' utterance lines side by side, the step list, the elapsed times.
Proves FR-005, SC-003, SC-006.

### 12. Format on the device: one press, one Undo — [device]

Test: `/usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 12`
Steps: open a content whose tag sits mid-paragraph, enter EDIT, press Format, dump; press Undo, dump.
Expected: after the press the tag line stands alone (a blank line before it) and no character of the text changed; after
one Undo the text is the input again; a second press on an already-formatted text leaves the button reporting nothing to
do.
Evidence: the two dumps' texts, the undo's restored text.
Proves FR-006, SC-004.

### 13. The option on the device: the pictures take the scenes — [device]

Test: `/usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 13`
Steps: pick five pictures, open Assign sentences, read the thumbnails' counts, choose the option, confirm if asked, dump
the page and the counts again; then move one picture right and dump.
Expected: the option's label is present (and absent for a no-scene content); after it, the first three thumbnails read
`2`, `2`, `1` sentences (scenes 1–3) and the last two read `0`; the sentence list shows each scene's rows under its
picture; a move still works and nothing is locked.
Evidence: the counts before and after, the option's label, the move's effect.
Proves FR-008, FR-009, FR-011, FR-012, SC-005, SC-006.

### 14. The render's frames carry no tag, and the slots are the sentences — [device]

Test: `/usr/bin/python3 -u specs/024-scene-tags/scripts/klhu_walk_scene.py 14`
Steps: render the fixture (16:9 and 9:16), pull the file, read its frame count and slot count from the renderer's own log
lines, extract a frame at each boundary, and OCR-free scan each frame's text area for the tag's glyph shapes (the same
pixel-scan 023's rows use).
Expected: the renderer's `klhu render` lines name **five** slots, the texts of the five sentences; **no frame** carries
the tag or the heading (zero matching pixel runs in the text area); the frame after a boundary opens the next sentence
with no blank slot between; the file's frame count equals the deleted-line twin's.
Evidence: the render lines, the frame count, the boundary frames, the pixel scans.
Proves FR-004, FR-005, SC-006, SC-008.

## The closing row

### 15. The five closed features' receipts re-run unchanged — [device]

Test: 015's, 019's, 016's, 020/021's and 012's own frame/step rows, on a **tag-free** content, unmodified:
`klhu_walk_comment.py`, `klhu_walk_head.py`, `klhu_walk_step.py`, `klhu_walk_assignment.py`, `klhu_walk_pass.py`,
`klhu_walk_video.py 32` — each its own command, each its own count.
Steps: run each row against the build this feature produces, and read its reported count.
Expected: each row's count is the number its own `quickstart.md` records, with **no re-cut**; where 021's rows dump the
assignment page, the new action's label may appear in a dump but the rows' own assertions do not read it — a row whose
count moves is a finding, and it is recorded in `breakpoint.md` rather than fixed by editing that row.
Evidence: each row's count, side by side with its own spec's number.
Proves FR-016, SC-001.
