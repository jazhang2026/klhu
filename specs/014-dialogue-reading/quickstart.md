# Quickstart: Multi-Role Dialogue Reading

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-01

Validation guide. Every scenario names **how** it is proven: `[unit]` is a Dart test, `[device]` runs on the
emulator with the app installed, `[structural]` is a file/artifact check. No implementation code here.

This feature has no platform half (unlike 012): everything is Dart, so the device rows exist for the
things a unit test cannot hear — which voice the engine was given, whether a removal survives a restart,
whether a dialogue's video sounds like the read.

The fixture the device rows use is the reader's own example (spec.md → Input): 旁白 / 阿明 / May / 阿芳,
four roles, two languages by content (旁白 and May in Mandarin, 阿明 in Cantonese, 阿芳 in Mandarin). Its
paragraphs carry the braced tag — `{旁白} 今天天气很好，适合出去走走。` — one turn to a paragraph, with a
blank line between the turns; one of them (May's) is written across two lines, because a turn holds as many
lines and sentences as its paragraph does (2026-10-03) and the device row has to hear that too.

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) — `flutter emulators --launch klhu`,
  wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- The suite's baseline before this feature: **439 tests green on `main`** and `flutter analyze` clean
  (measured 2026-10-01, `flutter test --concurrency=2`) — the regression gate for every row below.
- The device's own voice list matters to rows 9-11 and 24: the rows print what the device has rather than
  assuming the app's table.

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get
flutter gen-l10n                            # regenerates lib/l10n/app_localizations*.dart
flutter analyze
flutter test --concurrency=2                # full suite; the emulator being up can make plain
                                            # `flutter test` segfault on this 16 GB host
```

Device rows:

```bash
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am start -n com.example.klhu/.MainActivity
adb -s emulator-5554 logcat -s flutter        # the read's and the render's debugPrint evidence
```

Reading the persisted state the rows assert on:

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep -E 'content_roles|read_position'
```

Pushing the fixture text (so the row's text is the reader's own example, not a hand-typed one):

```bash
adb -s emulator-5554 push specs/014-dialogue-reading/scripts/klhu_dialogue_fixture.txt /sdcard/Download/
# then: the app's add-a-text/import path, or the walk driver does it through the UI
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`dialogue.dart`, `speech_resolver.dart`, `role_store.dart`, `voice_picker_screen.dart`, `reading_view.dart`, `reader_service.dart`, `video_timeline.dart`, `video_renderer.dart`) |
| `flutter test --concurrency=2` | every `[unit]` scenario below, plus the pre-feature baseline as a regression gate |
| `flutter test test/dialogue_test.dart` | the prefix rule, the turns, the spans, the roles, the edge cases, the Format transformation (rows 1-5, 12, 32) |
| `flutter test test/speech_resolver_test.dart` | one function, two modes: standard is today's call, dialogue is the turns (rows 6-8) |
| `flutter test test/role_assignment_test.dart` | the ranking, its determinism, the too-few-voices bound, gender-spreading (rows 9-11) |
| `flutter test test/role_store_test.dart` | the store's shape, its tolerance, the removal's expiry, the delete (rows 13, 14) |
| `flutter test test/reading_view_dialogue_test.dart` | the entry, the type switch, the role list, the picker's new row, the Format button (rows 15-18, 32) |
| `flutter test test/video_dialogue_test.dart` | a dialogue's plan, its voices, no tag in any frame's text (rows 20-22) |
| `flutter test test/l10n_keys_test.dart` | every new key exists in all four ARBs (row 19) |
| `git diff --stat pubspec.yaml pubspec.lock android/` | no dependency and no platform change at all (row 29) |

## Re-run the device rows

The `[device]` rows are scripted — one command per row, each printing its evidence and ending with
`RESULT: PASS|FAIL` (the convention 012's driver uses):

```bash
cd specs/014-dialogue-reading/scripts
python3 klhu_walk_dialogue.py 23    # the four-role read: contents only, each in its role's voice
python3 klhu_walk_dialogue.py 24    # the printed assignment, against the device's own voice list
python3 klhu_walk_dialogue.py 25    # the role list and the picker: a removal and a pick survive a restart
python3 klhu_walk_dialogue.py 26    # the type switch keeps the reader's place (offset + highlight)
python3 klhu_walk_dialogue.py 27    # a dialogue's video: no tag in any frame, the read's own voices
python3 klhu_walk_dialogue.py 28    # spike S1: the device's installed voices per language and gender
python3 klhu_walk_dialogue.py 33    # the editor's Format press: the tags become paragraph heads, one Undo
                                    #   restores the text; then Done saves it
```

`ADB_SERIAL` (default `emulator-5554`), `KLHU_REPO` (default this repo) and `KLHU_OUT` (default
`/tmp`) override the defaults; the driver imports `specs/012-reading-video/scripts/klhu_walk_video.py`
for the shared device mechanics (one string per `adb shell` command, row dispatch, PASS/FAIL) and
`specs/010-continue-read/scripts/klhu_walk_continue.py` beneath it. Rows and divergences:
[breakpoint.md](./breakpoint.md) (created by the walk, as 011's and 012's were).

The driver and the fixture text (`scripts/klhu_dialogue_fixture.txt`, the reader's own four-role example)
are written during implementation, the way 012's driver was: the rows above are the contract it has to
satisfy, and until it exists each `[device]` row is walked by hand with the same commands in the same
order.

## Validation scenarios

Rows are numbered append-only: the `[device]` rows 23-28 are the numbers the walk driver dispatches on, so a
row added later (32-33) takes the next free number rather than shifting them.

### 1. The prefix rule accepts what the reader writes and refuses everything else — [unit]

Test: `test/dialogue_test.dart`, "the prefix rule".
Steps: feed the rule the reader's own tagged paragraph heads (`{旁白} 今天天气很好，适合出去走走。`, `{阿明}: 今日个天气真系唔错啊。`,
`{May} ： 系啊。`, `{May Anne} hello`) and, beside them, the lines that must not be read as speakers:
`12:30`, `https://example.com`, `他说：我来了`, `May：系啊。` (a name and a colon with no braces),
`{May : hello` (no closing brace), `{} hello`, `｛May｝ hello` (full-width braces), a line of punctuation.
Expected: the reader's lines are turn heads with the right name and content (the name trimmed of spaces, the
separator not part of the content); the others are not — they name no role, so a paragraph headed by one of
them is narration. Proves FR-004, A6.

### 2. A turn's span excludes the tag and covers the whole paragraph — [unit]

Test: `test/dialogue_test.dart`, "turn spans".
Steps: take the fixture text; for every turn, compare `contentStart`/`contentEnd` with the paragraph's own
characters.
Expected: `content.substring(contentStart, contentEnd)` is the spoken content exactly (`今天天气很好，适合出去走走。`),
with no tag, no braces, no colon, no leading or trailing whitespace; for the two-line turn the span covers
both lines, so the line break between its sentences is inside it (the sentence cutter treats it as
whitespace); and the spans are inside the paragraph's own span — so a tag like `{阿明}` is a gap no span
covers. Proves FR-005, SC-001.

### 3. A paragraph with no tag is narration and is never attributed — [unit]

Test: `test/dialogue_test.dart`, "narration paragraphs".
Steps: a text with a role paragraph, then a paragraph with no tag anywhere (written across two lines), then
another role paragraph.
Expected: three turns; the middle one's `role` is `null` and it is ONE turn holding both of its lines; it is
neither the previous role's nor the next's. Proves FR-009, A8.

### 4. The blank line is the only boundary; a tag inside a paragraph is read as text — [unit]

Test: `test/dialogue_test.dart`, "the boundary, a tag inside a paragraph and empty turns".
Steps: the reader's example (a blank line between every turn) plus `{阿芳}` with nothing after it, plus
`{阿芳}   ` (spaces only), plus one paragraph holding `{阿明} 你好。` and `{阿芳} 我很好。` on two consecutive
lines with no blank line between them.
Expected: the blank-line-separated text yields four turns and no empty one; the two empty turns are not in
the list at all, so 阿芳's count is its readable turns only; and the last paragraph is ONE turn — 阿明's —
whose text is `你好。{阿芳} 我很好。`, braces included, with 阿芳 absent from the role list (only a paragraph's
head names a role). Proves the spec's edge cases; the reading itself proves it too in row 23.

### 5. Roles are in first-appearance order, with their turn counts — [unit]

Test: `test/dialogue_test.dart`, "roles".
Steps: a text where 旁白 speaks first, then 阿明, then May twice, then 阿明 again.
Expected: `roles` is `[旁白, 阿明, May]` in that order, with counts `1, 2, 2` — the order the text introduces them
(what the list shows), not alphabetical and not by count. Proves FR-006.

### 6. Standard mode returns exactly today's resolution — [unit]

Test: `test/speech_resolver_test.dart`, "standard is the shipped call".
Steps: for several contents (single-language, mixed-language, one with a colon in it, one whose lines all
look like `名：字` — the shape the first draft would have read as speakers and this feature reads as
narration), compare the resolver's standard output with `resolveParagraphSpeeches`'s own output.
Expected: equal, field by field (`text`, `language`, `voice`, `start`, `end`) — a relationship between the
two functions, not a frozen sample. Proves FR-002, SC-005.

### 7. Dialogue mode: one speech per turn, in the turn's own language — [unit]

Test: `test/speech_resolver_test.dart`, "dialogue is the turns".
Steps: resolve the fixture with `type = dialogue`; read the returned speeches.
Expected: one speech per turn in text order — a turn written across two lines is still one speech, with its
own line break inside it; each speech's `text` is the turn's content; a turn's
`language` is the same value `detectLanguage` gives its content (so 阿明's Cantonese-written line is
`zh-Hans` — the language rule sees Chinese, the *voice* is what makes it Cantonese, D5); spans are the
turn's. Proves FR-003, FR-005, FR-010, FR-011.

### 8. A role's pick wins, whatever the language — [unit]

Test: `test/speech_resolver_test.dart`, "the pick wins".
Steps: give 阿明 a Cantonese voice and May an English one; resolve.
Expected: 阿明's turns carry the Cantonese voice, May's the English one, and nobody's language detection
overrode a pick (FR-013); a role with no pick carries its assigned voice (row 9). Proves FR-012, FR-013.

### 9. No picks: the assignment follows the ranking — [unit]

Test: `test/role_assignment_test.dart`, "the ranking".
Steps: with a stub voice list that makes every rank distinguishable (two dialects of one language — the
locales are the dialect signal, corrected 2026-10-03 — both genders, several names), assign four roles:
three whose turns are in the reference's language and one whose turn is in another.
Expected: the first role of the reference's language gets the reader's own pick; the next gets a voice of
the same language *and* the same dialect where one exists; the third, when none is left, a voice of the
same language whose recorded gender differs from the ones already placed; the other-language role gets a
voice of the turn's own language. No role is left without a voice while its language has one. Proves
FR-014, FR-015.

### 10. The assignment is deterministic — [unit]

Test: `test/role_assignment_test.dart`, "determinism".
Steps: run the assignment twice on the same content, the same picks and the same voice list; then once with
the list's own order shuffled.
Expected: the same role → voice map every time (the ranking is total, so the list's order cannot leak into
the result). Proves FR-014's "the same assignment twice".

### 11. Too few voices: reuse, and the read still happens — [unit]

Test: `test/role_assignment_test.dart`, "the bound".
Steps: a voice list with two voices of the reference's language and four roles; then a list with none.
Expected: the third and fourth roles reuse a voice (which the list shows, so the reader can see it); with
no matching voice the role still gets a voice from what the engine offers or none at all — never a refusal,
never a crash, never an invented voice. The *distinctness* claim is bounded by the device, and the test
asserts the bound rather than the coincidence. Proves the spec's FR-015, SC-003, SC-004.

### 12. The language rule runs per turn, not per role — [unit]

Test: `test/dialogue_test.dart` / `test/speech_resolver_test.dart`, "one role, two languages".
Steps: a role whose two turns are in different languages (one Chinese-written, one English-written).
Expected: the same *role*, two speeches, two languages, and (with no pick) two assigned voices — the role
is a person, the voice belongs to the turn. Proves FR-011's own wording. *The reviewer should argue with
this one*: it is the reading that makes the language rule the turn's, not the role's.

### 13. A removal holds only against the text it was made on — [unit]

Test: `test/role_store_test.dart`, "removal expiry".
Steps: remove a name (recording `at` = the content's `updatedAt`); resolve; then save the text (008 bumps
`updatedAt`) and resolve again.
Expected: the name is not a role while the version matches (its lines read as narration, with the
narration's voice); after the save it is proposed and is a role again. Proves FR-006/FR-007 and the spec's
US3 scenario 4.

### 14. The store's shape and its tolerance — [unit]

Test: `test/role_store_test.dart`, "shape and tolerance".
Steps: write a type, a removal and two picks; read them back; then corrupt the key (not JSON, a value that
is not an object, a `removed` entry without `at`, a pick whose `locale` is a number) and read again; then
delete a content and read.
Expected: the good case round-trips; each corruption is ignored for *that* content only (it reads as
standard) while the other contents' entries stay intact; no repair is attempted (nothing is rewritten);
the deleted content's entry is gone. Proves FR-021, SC-007.

### 15. The entry, and what switching the type does not touch — [unit]

Test: `test/reading_view_dialogue_test.dart`, "the entry and the switch".
Steps: open the page for a content; open the type chooser; switch to 多人对话 and back.
Expected: the entry is offered in 标准 too (showing the type alone); switching never edits the text (the
edit controller's value and 008's `updatedAt` are unchanged), never clears the highlight, and never writes
a reading position; only the `content_roles` entry changes. Proves FR-020, FR-022, SC-009.

### 16. The role list: names, counts, voices, remove — [unit]

Test: `test/reading_view_dialogue_test.dart`, "the role list".
Steps: open a dialogue content's role list; read its rows; remove a role; read again.
Expected: one row per proposed role, in first-appearance order, each with its turn count and its voice's
name (the pick's, or the assignment's), plus the remove action; after the remove the row is gone, the
removal is stored with the text's version, and the content's reading is re-resolved (the removed name's
lines are narration). Proves FR-006, FR-012, FR-016.

### 17. The role's picker: a title, and a first row that clears the pick — [unit]

Test: `test/reading_view_dialogue_test.dart`, "the picker for a role".
Steps: open a role's picker; check its title; tap the first row; then open the language-level picker.
Expected: the role's picker is titled with the role's name and its first row means *follow the automatic
assignment* — tapping it clears that role's pick (and the list then shows the assignment again); the
language-level picker is exactly today's screen (no title, no extra row). Proves FR-012's clear path,
ripple note 5.

### 18. In 标准 the page is what ships — [unit]

Test: `test/reading_view_dialogue_test.dart`, "standard is untouched" — and the shipped page tests stay
green *unmodified*: nothing in the tree enumerates the app bar's actions or counts the editor toolbar's
buttons (plan ripple note 1 has the check), so this row's own claim is that no shipped test changes, not
that one is re-cut.
Expected: for a content with no stored settings, every behaviour the shipped page's tests assert still
holds — the reading, the highlight, the edit mode, the undo, the voice entry, the video entry — with the one
added entry, and no role list anywhere. Proves FR-002's "nothing changes", SC-005.

### 19. Every new key exists in all four locales — [structural]

Check: `test/l10n_keys_test.dart` (the shipped drift check) plus `flutter gen-l10n` and
`git status --short lib/l10n` (the generated files are committed and up to date).
Expected: every new key (the entry, the two types, the role list's labels, the remove confirmation, the
picker's rows) is present in `app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb` and `app_es.arb`, and the
generated Dart is regenerated and committed. Proves FR-022.

### 20. A dialogue's video plan uses the read's own voices — [unit]

Test: `test/video_dialogue_test.dart`, "the plan's voices".
Steps: build a plan for the fixture with `type = dialogue`; compare each slot's voice with the read's own
resolution of the same sentences.
Expected: equal, slot by slot — the video cannot voice a turn differently from the read (one call, D9) —
while the slot count, the frame counts and the spans stay what 012's own tests assert for the same text.
Proves FR-018, FR-019, SC-008.

### 21. No frame's text carries a tag — [unit]

Test: `test/video_dialogue_test.dart`, "no tag in a frame".
Steps: for every slot of a dialogue plan, take `slot.text` and the content's span it names.
Expected: no slot's text starts with a role tag, no slot's text contains the fixture's role
names at all, and each slot's `span=` is the turn's content span — the tag is a gap the painter never
sees. Proves FR-005's video half, SC-008.

### 22. The render's slot line names the role — [unit]

Test: `test/video_dialogue_test.dart` / `test/video_renderer_test.dart` (the existing log assertion, extended).
Steps: render (with a stub engine) a dialogue and read the emitted `klhu render slot=…` lines.
Expected: each line carries the slot's role beside the fields it already carries, additively — 012's own
assertions on the line keep passing. Proves D10's evidence requirement (the device row 27 has nothing to
read without it).

### 23. A four-role dialogue read on the device: contents only, each in its role's voice — [device]

Test: `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 23`.
Steps: push the fixture, set its type to 多人对话, start the read from the top with `logcat -s flutter` running
(and only the app's own lines kept), let it finish.
Expected: the log's `klhu speak` lines are the turns' contents in order — no role name, no brace of a tag,
no blank line — one line per sentence (the reader's "回合内部仍按句子朗读"), the fixture's two-line turn
coming out as its two sentences one after the other in the same role's voice; and every
line carries `role=<name> voice=<voice id>` (the shape the implementation settled on, 2026-10-03), with the
read's own `klhu roles <role>→<voice>(<gender>) …` line naming the whole assignment — the reason the role is
on the speech at all is this line, not the reader's eye (D1's partial reversal). The four roles' voices are
the four the list showed.
Proves FR-003, FR-005, FR-010, FR-018, SC-001, SC-002.

### 24. The assignment as the app made it, against the device's own voices — [device]

Test: `klhu_walk_dialogue.py 24`.
Steps: open the dialogue content with no picks; read the page's own printed assignment line; list the
device's installed voices independently (`adb shell` on the engine's own settings page, or the app's own
`voicesForAll` probe) — the same evidence 012's spike S1 collected.
Expected: every role reads in a voice of its turn's own language; 旁白 (the first role) reads in the voice the
reader picked for that language; the roles that follow differ in recorded gender where the device offers
both; and where it does not, the rows say so (the bound, not a failure). Proves FR-014, FR-015, SC-003.

### 25. A removal and a pick survive a restart — [device]

Test: `klhu_walk_dialogue.py 25`.
Steps: open the fixture's role list; remove a name that is not a role; give one role a voice; force-stop the
app and start it again; open the same content.
Expected: the removal is still in force (the name is not listed, its lines read as narration with the
narration's voice) and the picked voice is still on its role — the persisted `content_roles` entry, read
back from the device's prefs, shows exactly `{type, removed, voices}` and nothing else. Proves FR-007,
FR-008, FR-012, SC-006, SC-007.

### 26. Switching the type mid-read keeps the reader's place — [device]

Test: `klhu_walk_dialogue.py 26`.
Steps: read a few sentences into the content (letting 010's position be saved); note the highlight and the
stored `read_position`; open the entry and switch to 多人对话; then switch back.
Expected: the highlight is where it was, the stored offset's value is unchanged (a content offset is a
content offset), the text is untouched (008's `updatedAt` unmoved) and reading resumes from the same
sentence. Proves FR-020, SC-009.

### 27. A dialogue's video on the device: no tag in a frame, the read's own voices — [device]

Test: `klhu_walk_dialogue.py 27`.
Steps: render the fixture as a video (012's path) with `logcat -s flutter` running; pull the file; with
`ffprobe` take its duration and audio; extract a frame inside each slot's range and one at each turn
boundary.
Expected: every sampled frame carries only the sentence being spoken — no role name, no braces of its tag,
no second speaker's turn — and the frames' text matches the turn's content span; the audio's segments are the read's
own per-role voices (the same assignment row 24 printed); a frame at a turn boundary belongs to one turn
only. Proves FR-018, SC-008.

### 28. Spike S1 — how many distinct voices does this device list, per language and gender? — [device]

Test: `klhu_walk_dialogue.py 28` (the probe; its answer goes into research.md → Spikes).
Steps: print the installed voices grouped by language and recorded gender, using the app's own
`voicesForAll` (`lib/reader_service.dart:507-510`) and the metadata table
(`lib/models/voice_mapping.dart`); count distinct voices, not ids (the table itself warns that one voice can
appear in two id variants).
Expected: a table (language × gender → count) — the number rows 9-11 and SC-003's distinctness claim are
bounded by. If the device lists only one Mandarin voice of each gender, the row records that as the bound
rather than failing.

### 29. No dependency and no platform change — [structural]

Check: `git diff --stat pubspec.yaml pubspec.lock android/ ios/` after the feature's commits.
Expected: nothing — the dependency block and the platform tree are untouched (FR-023), which is also the
proof that this feature has no half outside Dart.

### 30. The 011 read receipt still passes — [structural]

Check: `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py` (its own rows, unchanged) plus
`flutter test test/language_test.dart test/segmenter_test.dart test/reader_service_test.dart`.
Expected: green, unmodified — the read of a content with no dialogue settings is byte-identical (SC-005), and
`test/language_test.dart`'s `resolveParagraphSpeeches offsets` group (`:115-140`) is untouched.

### 31. The 012 video receipt still passes — [structural]

Check: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 31 32 33` and
`flutter test test/video_timeline_test.dart test/video_painter_test.dart test/video_renderer_test.dart`.
Expected: green, unmodified for a standard content — the video's sentences, frames, chrome and log line are
what 012's own rows assert, with the additive `role=` field ignored by their checks. Proves FR-019's
"nothing else changed" side.

### 32. Format puts every tag at the head of its own paragraph, and adds nothing else — [unit]

Test: `test/dialogue_test.dart`, "the Format transformation", plus `test/reading_view_dialogue_test.dart`,
"the Format button".
Steps: feed the transformation every text shape the rows above name — a tag already at a paragraph's head,
two tags on one line, a tag on a paragraph's second line, a tag in the middle of a line, no tag at all, an
unclosed brace, `{}`, full-width braces — and, beside them, the editor: open a content with an inline tag in
edit mode, read the button's enabled state, press it, read the controller's text back, press Undo.
Expected: after the press every tag is the first non-space characters of its own paragraph; the difference
from the input is blank lines and nothing else — no other character added, removed or reordered, so an
unclosed brace or a full-width pair stays exactly where it was, because neither is a tag; the button is
disabled when the result would equal the input; and the press is one undo step. Proves FR-024, SC-011.

### 33. Format in the editor on the device, with the reader's own hands — [device]

Test: `klhu_walk_dialogue.py 33`.
Steps: into the editor, type or paste a dialogue with two tags on one line; dump the editor's text with
`uiautomator dump` (the ground truth for Flutter text on this host) before and after pressing Format; press
Undo; then press Done and reopen the content.
**Wait > 500 ms between every press, and after entering the editor.** The platform undo stack throttles
pushes to one per 500 ms (`widgets/undo_history.dart`, `_kThrottleDuration`), and an Undo inside that window
*cancels the pending push* instead of undoing it; a change made in the same window as EDIT's own mount push
coalesces with it, leaving a single state and nothing to undo. The unit case hits this too — its probes
showed the toolbar's Undo disabled until the pushes landed (`test/reading_view_dialogue_test.dart`, 008's
`test/reading_view_edit_test.dart:513-519` waits the same way). A driver that presses quickly will read this
row as a failure of the app.
Expected: the after-Format dump has each tag at its own paragraph's onset and no other change; the dump after
Undo is byte-for-byte the one from before the press; Done saves, and the reopened content shows the formatted
text (the save path is 008's own, not a second one). Proves FR-024, SC-011 where the editor's own text is the
only witness.
