# Quickstart: Comment Tag

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-08

Validation guide. Every scenario names **how** it is proven: `[unit]` is a Dart test, `[device]` runs on the
emulator with the app installed, `[structural]` is a file/artifact check. No implementation code here.

This feature has no platform half (unlike 012): everything is Dart, so the device rows exist for the things a
unit test cannot hear or see — which voice the engine was given for a comment, whether a tap inside a comment
answers, whether the setting survives a restart, whether a rendered frame really carries the comment beside
its sentence and whether two languages' audio really mux into one file.

The fixture the device rows use is the reader's own example (spec.md → `Input`) plus the shapes this feature's
edge cases need: a Spanish sentence followed by a blank line and `[注] How are you?`, the same tag written
inline (`Hola. [注] Hi. Adiós.` — one comment, and *Adiós.* is never a sentence read in its own right: its voice
is the comment's own detected language's, `es` here by the accent, corrected 2026-10-09), a
dialogue content that carries `{阿明} 今日个天气真系唔错啊。` with an English comment under it, a 标准 content
with the same two tags, a comment at the very top of a content (belonging to no sentence), a paragraph whose
only text is the marker, a `［注］` full-width pair that must stay ordinary text, and **one content per spelling**
(the same Spanish sentence with `[nota]` and with `[註]`), so a device row proves that a spelling from another
keyboard reads exactly as `[注]` does (the reader's amendment of 2026-10-08).

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) — `flutter emulators --launch klhu`,
  wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- **`ffprobe`/`ffmpeg` on the host** (`/usr/bin/ffprobe`, measured): the video rows assert on the produced
  file with them rather than by eye.
- The suite's baseline before this feature: **559 tests green on this working tree** and `flutter analyze`
  clean — *No issues found!* (measured 2026-10-08 with `flutter test --concurrency=2` and `flutter analyze`
  on this host). This is the regression gate every row below is read against. The tree also carries the
  unrelated in-flight edits 014's 2026-10-08 amendment left in `lib/video_painter.dart` and its artifacts;
  the count is what those edits leave, and it is the count this feature must not lower.
- The device's own voice list matters to rows 17 and 23: the rows print what the engine has rather than
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

Reading the persisted state the rows assert on (the switch lives in 014's own key):

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep -E 'content_roles|read_position'
```

Reading what the page paints (the ground truth for Flutter text on this host):

```bash
adb -s emulator-5554 shell uiautomator dump /sdcard/window.xml && \
  adb -s emulator-5554 shell cat /sdcard/window.xml | grep -o 'text="[^"]*"'
```

Pushing the fixture text:

```bash
adb -s emulator-5554 push specs/015-comment-tag/scripts/klhu_comment_fixture.txt /sdcard/Download/
# then: the app's add-a-text/import path, or the walk driver does it through the UI
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`comment.dart`, `dialogue.dart`, `speech_resolver.dart`, `reader_service.dart`, `role_store.dart`, `reading_view.dart`, `video_timeline.dart`, `video_renderer.dart`) |
| `flutter test --concurrency=2` | every `[unit]` scenario below, plus the pre-feature baseline as a regression gate |
| `flutter test test/comment_test.dart` | the marker's grammar, a comment's span and owner, the display and its two mappings, the edge shapes (rows 1-5, 8, 11) |
| `flutter test test/speech_resolver_comment_test.dart` | the read: the comment's place, language and voice, the switch off, 标准's invariance, the dialogue rules (rows 6, 7, 9, 10) |
| `flutter test test/reading_view_comment_test.dart` | the page: no painted marker, the tap's answer in both settings, the highlight, the switch in the sheet (row 13) |
| `flutter test test/video_comment_test.dart` | a slot's block and its audio parts, the setting's two faces, no tag in any slot's text (row 14) |
| `flutter test test/role_store_test.dart` | the setting's shape, its default, its tolerance and its life (row 12) |
| `flutter test test/l10n_keys_test.dart` | every new key exists in all four ARBs, and no dropped key survives (row 16) |
| `flutter test test/dialogue_test.dart test/speech_resolver_test.dart` | 014's own rules are unmodified: the prefix rule, the turns, the Format transformation, 标准's exact call (row 25) |
| `git diff --stat pubspec.yaml pubspec.lock android/ ios/` | no dependency and no platform change at all (row 15) |

## Re-run the device rows

The `[device]` rows are scripted — one command per row, each printing its evidence and ending with
`RESULT: PASS|FAIL` (the convention 012's and 014's drivers use):

```bash
cd specs/015-comment-tag/scripts
python3 klhu_walk_comment.py 17    # a comment read on the device: the read's own lines, in two voices
python3 klhu_walk_comment.py 18    # the inline tag's reach: the sentence after the tag is never read
python3 klhu_walk_comment.py 19    # a tap inside a comment, with the comments read and with them off
python3 klhu_walk_comment.py 20    # the switch off, across a restart, and the content's own delete
python3 klhu_walk_comment.py 21    # a comment inside a dialogue turn, and a 标准 content with one
python3 klhu_walk_comment.py 22    # a comment's video, the frames (spike S2's numbers)
python3 klhu_walk_comment.py 23    # a comment's video, the audio (spike S1: two languages, one render)
```

`ADB_SERIAL` (default `emulator-5554`), `KLHU_REPO` (default this repo) and `KLHU_OUT` (default `/tmp`)
override the defaults; the driver imports `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` for the
shared device mechanics (one string per `adb shell` command, row dispatch, PASS/FAIL) and, beneath it,
`specs/012-reading-video/scripts/klhu_walk_video.py` (the frame and audio machinery). Its own speak-line
regex is 014's with `(?: comment=1)?` appended after the quoted utterance (plan ripple 6). Rows and
divergences go in `specs/015-comment-tag/breakpoint.md`, created by the walk as 011's, 012's and 014's were.

The driver and the fixture text are written during implementation, the way 014's were: the rows below are the
contract it has to satisfy, and until it exists each `[device]` row is walked by hand with the same commands
in the same order.

## Validation scenarios

Rows are numbered append-only: the `[device]` rows 17-23 are the numbers the walk driver dispatches on, so a
row added later takes the next free number rather than shifting them.

### 1. The marker's grammar accepts the reader's four spellings and refuses everything else — [unit]

Test: `test/comment_test.dart`, "the marker's grammar".
Steps: feed the rule the tags the reader writes (`[comment] How are you?`, `[Comment] How are you?`,
`[COMMENT]: How are you?`, `[注] How are you?`, `[注]: How are you?`, `[注] ： How are you?`, `[nota] How are
you?`, `[Nota]: How are you?`, `[註] How are you?`) and, beside them, the pairs that must not be tags:
`［注］` (full-width brackets), `[comentario]`, `[註解]`, `[註釋]`, `[comments]`, `[note]`, `[注释]`, `[注` (no
closing delimiter), `[]`, `[ 注 ]` with an inner space trimmed to `注` (a tag) versus `[co mment]` (not one),
and the same characters appearing inside a sentence.
Expected: every listed spelling is one tag — the same offsets and the same content whichever of the four was
used — and each refused shape is not a tag at all: the rule answers `null` and the characters stay the
reader's own text, displayed and read as written. The four are one set: a content that uses `[nota]` is read
the same way while the app shows English, Chinese or Spanish (the reader's amendment of 2026-10-08).
Proves FR-001, A1.

### 2. A comment's content runs to its paragraph's end and excludes the tag — [unit]

Test: `test/comment_test.dart`, "a comment's content".
Steps: for each shape — a tag with its content on the same line, a tag with a colon, a tag alone on the
first line with the content on the next, a tag whose paragraph holds several lines — compare the comment's
`contentStart`/`contentEnd` and its `text` with the paragraph's own characters, and check `tagEnd`.
Expected: `content.substring(contentStart, contentEnd)` is the comment's content exactly, ending at the
paragraph's last non-whitespace character and including the line breaks inside it; the tag and its separator
are outside that span but **inside** `[start, tagEnd)` — the characters that are never painted (row 5); and
for a tag alone on its line the content begins on the paragraph's next line (014's own prefix rule), with the
line break itself outside the content span and inside the display.
Proves FR-002, A2, research D3.

### 3. The tag is read wherever it sits, and one paragraph holds at most one comment — [unit]

Test: `test/comment_test.dart`, "where the tag is read".
Steps: a paragraph with the tag mid-line (`Hola. [注] Hi. Adiós.`); a paragraph whose tag is inside another
comment's content (`[注] Hi. [注] more.`); a paragraph headed by the tag; a paragraph with a role tag and then
a comment tag (`{阿明} 你好。[注] Hello.`); a paragraph whose only text is the marker; a paragraph whose tag has
nothing after it.
Expected: the mid-line tag makes one comment covering `Hi. Adiós.`; the second marker in the first shape is
**inside** the comment's content (displayed and read with it — nothing nests); the role-tag paragraph yields
one comment whose content is `Hello.` and a turn whose own text is `你好。` (row 9); the marker-only paragraph
and the contentless tag are comments with empty content — no utterance, no frame, and their characters are
still not painted.
Proves FR-001, FR-002, the spec's edge cases.

### 4. A comment belongs to the last sentence that ended before it — [unit]

Test: `test/comment_test.dart`, "the owner".
Steps: a comment under a one-sentence paragraph; a comment under a multi-sentence paragraph (its owner is the
last sentence, not the first); a comment whose tag is inline after a sentence; a comment at the very top of a
content, before any sentence exists; two comment paragraphs in a row.
Expected: each comment's `owner` is the last sentence ending before its tag, **across paragraph boundaries**;
the comments at the head of a content have `owner == null` (displayed, never spoken, in no frame — row 21);
and both of the two consecutive comments belong to the same sentence, which is the last one before the first
of them.
Proves FR-003, research D4.

### 5. The page paints everything except the markers — [unit]

Test: `test/comment_test.dart`, "the display and its mappings".
Steps: build the display for a content that carries a tag alone on its line, an inline tag, two comments, and
a text with no tag at all; then map offsets both ways across and inside each elided span.
Expected: the display has no character of any tag and no separator, its length is the content's minus the
elided spans, and every other character — the comment's content, its line breaks, the sentence's text, a
`{…}` role tag — is exactly where the reader wrote it; `toContent`/`toDisplay` round-trip for every offset
outside an elided span (data-model I3, I4); an offset inside a tag answers the span's own start/display
position, so a highlight whose end lands in a tag paints no marker; and for a text with no tag the display
**is** the content and both mappings are the identity (data-model I1).
Proves FR-005, FR-012's display half, SC-006's unit half, A4.

### 6. The comment is read after its sentence, in its own language's voice — [unit]

Test: `test/speech_resolver_comment_test.dart`, group "6. the comment is read after its sentence, in its
own voice".
Steps: resolve the fixture (a Spanish sentence, a blank line, an English `[注]` comment) with the comments
read, and read the returned speeches; then resolve a content with no tag at all and compare it with
`resolveParagraphSpeeches`'s own output.
Expected: the comment is its own `ParagraphSpeech` (`isComment` true), placed immediately after the speech
whose last sentence is its owner; its `text` is its content, its `language` is what `detectLanguage` gives
that content alone (so the English comment is `en` beside a Spanish sentence — A3), its `voice` is the
language's own pick through the same `loadVoice` seam, its span is the comment's own, and no speech's text
contains a `[` or `]` of a tag; a comment of two sentences is cut into two utterances by the reader service's
own sentence cut, one per sentence (FR-007, 010 FR-011); for the tagless content the resolver's output is
`resolveParagraphSpeeches`'s, field for field — a relationship between the two functions, not a frozen
sample.
Proves FR-007, FR-008, FR-009, FR-010, SC-001, SC-003, SC-004.

### 7. With the comments off, nothing of the comment reaches the engine — [unit]

Test: `test/speech_resolver_comment_test.dart`, group "7. with the comments off, nothing of them reaches
the engine".
Steps: resolve the same fixture with the comments off; read the speeches; count the utterances the reader
service would cut from them.
Expected: no speech carries the comment's characters anywhere, in either text type; the speech sequence is
the sentences' own, in order, and the piece of text that was a comment contributes **no speech at all** — not
even a paragraph of its own. (This is deliberately NOT what the marker-stripped text would resolve to: that
text would hand the comment's words to the engine as a paragraph, which is exactly what the switch must not do.
Corrected 2026-10-08 by the implementation, T010/T011.) An inline tag takes the rest of its paragraph out of
the read with it whether the switch is on or off — those characters are the comment's, so with the comments
read they are the comment's own speech and with them off they are nothing (FR-002, the edge case's third
spelling). The page's display and the video's plan are unaffected by the setting (rows 13-14).
Proves FR-006's resolution half, SC-002.

### 8. A comment's content is no sentence's span, and a read never modifies the text — [unit]

Test: `test/comment_test.dart` (the span and owner groups) / `test/speech_resolver_comment_test.dart`,
group "8. a comment's content is no sentence's span".
Steps: for the fixture's speeches, check each speech's span against the comments' spans; then resolve, read
and re-resolve a content that carries an inline tag, and compare the content string before and after.
Expected: no speech's span overlaps a comment's content (FR-004): in 标准 the piece before a tag ends at the
sentence's own last character, and in 多人对话 the turn's span ends at the tag (`Comment.contentEnd`'s own
trimming, `lib/dialogue.dart`), while the tag's own characters are in no span at all; and a comment's own
speech is exactly one comment's span. The tags and the comments are gaps *inside* paragraphs rather than tiles
of the text — the paragraphs' own blank lines and the prefixes are not spoken either, so this row does not
claim a strict partition.
The "the content is never rewritten" half is the store's own contract and is cited rather than tested here: a
pre-set's text is not writable at all (`lib/services/content_store.dart:355` returns early for one), 015 adds
no write path, and the page's own test shows the editor still holding the tag and the store's text for the
fixture still carrying it while the page paints it away (`test/reading_view_comment_test.dart`, rows 5 and 13's
group) — a byte-identity assertion here would be vacuous, since this harness's catalog lives in memory
(corrected 2026-10-08 by the implementation, T010/T011).
Proves FR-004, FR-015's "the content's own text unmodified" (with row 12).

### 9. In 多人对话 the turn keeps its own words, language and voice — [unit]

Test: `test/speech_resolver_comment_test.dart` / `test/comment_test.dart`, "a comment inside a turn".
Steps: resolve the dialogue fixture (`{阿明} 今日个天气真系唔错啊。` with an English comment under it) in
dialogue mode; read the turn's speech and the comment's; then resolve a text whose paragraph holds nothing
but a comment; then ask the turn scan for the roles and their counts.
Expected: the turn's speech is the turn's own text alone (`今日个天气真系唔错啊。`, no comment characters), its
detected language is the turn's own (a Chinese turn with an English comment is still `zh-Hans`), its voice is
阿明's own pick or assignment; the comment is spoken by its **own** language's voice, never by 阿明's; the
comment-only paragraph produces no turn at all — no speech, no role, no turn count (FR-011); and 阿明's count
is what the text's own turns give, unmoved by the comment.
Proves FR-011, SC-005.

### 10. 标准 is unchanged but for the comments, and the switch touches nothing else — [unit]

Test: `test/speech_resolver_comment_test.dart`, "标准 and the switch's blast radius".
Steps: resolve a 标准 content that carries a comment; compare its sentence speeches with the same text
resolved with no comment in it; then turn the switch off and back on and compare the stored settings, the
roles, the text type and the text itself.
Expected: the sentences keep their own spans, languages and voices — the 标准 read is today's read with the
comment's speech added when the setting is on (FR-010); and the switch changes exactly one field of the
content's stored entry and nothing else: not the text, not the type, not the roles or their voices, not the
reading position (FR-016).
Proves FR-010, FR-016.

### 11. The editor's Format action leaves every comment where it is — [unit]

Test: `test/comment_test.dart`, "Format knows `{}`, and nothing else".
Steps: feed `formatForDialogue` a dialogue text with an inline role tag and an inline comment tag, a comment
at a paragraph's head, a comment whose content holds a `{…}` pair, and a text with a comment and no role tag.
Expected: the result puts every `{…}` tag at the head of its own paragraph and leaves every `[comment]`/`[注]`
byte-identical — character for character in the same place, including a bracket pair's own spacing; the
difference from the input is blank lines and nothing else (014's own rule); and a text with nothing to format
comes back identical.
Proves FR-017.

### 12. The setting's own shape and life — [unit]

Test: `test/role_store_test.dart`, "the comment setting" (a new group in 014's own file).
Steps: read a content's settings with nothing stored; turn the comments off and read back; corrupt the entry
(not JSON, a value that is not an object, `comments` a string, `comments` the number 0) and read again; set
the switch on two contents independently; delete one content and read.
Expected: nothing stored reads **true** for the comments (the shipped default — the reversal the reader
answered, FR-006); the off state round-trips as `"comments": false` and an entry that says only that survives
(`isEmpty` counts it); each corruption is ignored for **that** content only, without repair and without
affecting the others; the two contents' settings are independent; and the deleted content's entry — switch
included — is gone, through the delete path that already exists.
Proves FR-006, FR-015, SC-010.

### 13. The switch in the sheet, and what a tap inside a comment answers — [unit]

Test: `test/reading_view_comment_test.dart`, "the sheet and the tap".
Steps: open the page for a content with a comment; open 014's own sheet and read it; toggle the switch and
read the page's state; tap inside the comment with the comments read and with them off; read the highlight;
reopen the page.
Expected: the sheet the text type already opens also carries the switch, in **both** text types; toggling it
stores the choice and re-resolves the next read (nothing else on the page moves: not the text, not the undo
stack, not the highlight in force, not the roles); with the comments read, a tap inside the comment highlights
the comment's own span; with them off, it highlights the owner sentence; a re-read paints the comment's own
span exactly while the comment is being spoken (SC-006, SC-009); and the marker's characters are painted
nowhere in any state (the `RichText`'s text has none of them).
Proves FR-012, FR-014, SC-006, SC-009.

### 14. The video's slot carries its sentence and its comment — [unit]

Test: `test/video_comment_test.dart`, "the slot's block and its audio".
Steps: build a plan for the fixture (with a tagless content beside it as the control); read each slot's
`text`, its `audio` and its `span`; then build the same plan with the comments off.
Expected: no slot's text contains any `[comment]`/`[注]` character of any tag, and the slot an owner sentence
built carries that sentence's text followed by its comment's content on its own line — its block taller by
the comment's own lines; `span=` is still the **sentence's** own offsets; the slot's `audio` names its own
wav first and the comment's sentences' after it, in the read's own order and voices; with the comments off
the slot's block is **unchanged** while its audio names its own wav alone; and the tagless content's plan is
what 012's own tests assert for that text (same slots, same frames, same spans).
Proves FR-013, FR-009's video half, SC-007's unit half, SC-008's unit half.

### 15. No dependency and no platform change — [structural]

Check: `git diff --stat pubspec.yaml pubspec.lock android/ ios/` after the feature's commits.
Expected: nothing — the dependency block and the platform tree are untouched (FR-018). The platform half the
video uses is *read*, not changed: its audio list already takes one file per utterance (research D8).
Proves FR-018, SC-011.

### 16. Every new key exists in all four locales — [structural]

Check: `test/l10n_keys_test.dart` plus `flutter gen-l10n` and `git status --short lib/l10n` (the generated
files are committed and up to date).
Expected: the switch's new key(s) are present in `app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb` and
`app_es.arb` (107 message keys each before this feature, **108** after — one key, `commentsReadLabel`, with no
hint line; **corrected 2026-10-09**: the row had said 109, but the switch is one `SwitchListTile` title, which
is what T001 shipped and what [research.md](./research.md) § D6 decided), the generated Dart is regenerated and
committed, and no translation keeps a key the template dropped.
Proves FR-014's string half.

### 17. A comment read on the device, in two voices and with no marker painted — [device]

Test: `python3 specs/015-comment-tag/scripts/klhu_walk_comment.py 17`.
Steps: push the fixture, open the Spanish-sentence content with the comments read (the shipped default), dump
the page with `uiautomator dump`, then read it from the top with `logcat -s flutter` running and only the
app's own lines kept — and repeat that read on the fixture's `[nota]` content and on its `[註]` content.
Expected: the dump's text contains the comment's English words and **no** marker characters of any spelling
anywhere; the `klhu speak` lines are, in order, the Spanish sentence's utterances with `voice=` naming the
device's Spanish voice and then the comment's utterances carrying `comment=1` with `voice=` naming the
device's **English** voice — the two differ, and no line's quoted text contains a bracket of a tag; the
utterance sequence contains every sentence of the sentence's paragraph and every sentence of the comment, one
utterance per sentence; the page's own highlight moves onto the comment's line while the comment is spoken;
and the `[nota]` and `[註]` contents read **exactly as the `[注]` one did** (same words hidden, same voice,
same order), which is the amendment's own claim on a device (FR-001, 2026-10-08).
Proves SC-001, SC-003, SC-006, FR-005, FR-007.

### 18. The inline tag's reach, heard rather than seen — [device]

Test: `klhu_walk_comment.py 18`.
Steps: open the fixture's `Hola. [注] Hi. Adiós.` content (one paragraph, one inline tag) with the comments
read, read it from the top, and read the utterances.
Expected: exactly one comment is spoken — its utterances are `Hi.` and `Adiós.`, in that order, both carrying
`comment=1`, and both in the **comment's own** detected language's voice. For this text that language is `es`
(the detector reads `Adiós.`'s accent, A3), so the comment reads in the same Spanish voice `Hola.` does — the
point being that `Adiós.` is the comment's own text, **not** a sentence of the paragraph read in its own right
(FR-002's boundary, the consequence the reader accepted). The two-language case (a plainly English comment in
the English voice) is row 17's. The page shows `Hola. Hi. Adiós.` and no marker. Rows 1 and 3 hold the same rule
in the unit layer; this row is where the reader hears it.

*Corrected 2026-10-09 by the device run:* the row was written expecting the comment in the **English** voice,
which assumed `Hi. Adiós.` detected English — it does not (the accent), and the app is right (FR-008/A3). The
reader's own answer was to keep the fixture text and fix this expectation (option (b)); the device run and the
app's own lines are in [breakpoint.md](./breakpoint.md) § Row 18.
Proves FR-002's consequence, the spec's inline-tag edge case.

### 19. A tap inside a comment answers, in both settings — [device]

Test: `klhu_walk_comment.py 19`.
Steps: with the comments read, tap inside the comment's own line and press ▶ Read; then switch the comments
off, tap the same place and press ▶ Read; read the highlight and the `klhu read range:` line each time.
Expected: with the comments read the range is the comment's own span and the comment is spoken; with them off
the range is the **owner sentence's** span and that sentence is spoken — in both cases a sentence or a
comment, never a marker and never nothing (the tap never lands on an elided tag and answers with a gap), and
the highlight covers exactly what was read.
Proves SC-009, FR-012's tap half.

### 20. The switch off, across a restart, and with the content gone — [device]

Test: `klhu_walk_comment.py 20`.
Steps: turn the content's comments off in the sheet; read it from the top; dump the page; force-stop the app
and start it again and reopen the same content; read a second content whose switch was never touched; then
delete the first content and read the app's stored prefs.
Expected: none of the comment's words appears among the utterances (read from the app's own `klhu speak`
lines — 100 % of them are the sentences' own text) while the page's dump still shows the comment's words and
no marker; after the restart the switch is still off for that content; the second content still reads its
comments (the setting is per content); and after the delete the content's `content_roles` entry — the switch
with it — is gone.
Proves SC-002, SC-006, SC-010, FR-014, FR-016.

### 21. A comment inside a dialogue turn, and in 标准 — [device]

Test: `klhu_walk_comment.py 21`.
Steps: open the dialogue fixture (`{阿明} 今日个天气真系唔错啊。` with an English comment under it), set its
type to 多人对话, read it; read the app's `klhu speak` and `klhu roles` lines and the role list; then open the
标准 content that carries the same two tags and the content whose first paragraph is a comment before any
sentence, and read each.
Expected: the turn's utterances are the turn's own text in 阿明's voice with `role=阿明`, the comment's
utterances follow with `comment=1` and the **English** voice (阿明's voice never speaks the comment), 阿明's
turn count in the role list is unchanged by the comment, and the comment-only paragraph appears as no turn at
all; the 标准 content reads the sentence in its own voice and the comment after it, exactly as a 标准 read of
the same text without the tag would; and the content whose comment precedes every sentence reads its
sentences only — the comment is displayed and never spoken.
Proves SC-005, FR-010, FR-011, FR-003's own edge case.

### 22. A comment's video, the frames — [device] (spike S2's numbers are this row's)

Test: `klhu_walk_comment.py 22`, then `ffprobe`/`ffmpeg` on the pulled file.
Steps: render the Spanish/English content twice — once with the comments read, once with them off — and for
the sentence's own slot in each file extract a frame at the slot's start, report the render's own
`klhu render slot=… span=… text=<n>` line for it, and measure the ink box with the driver's own
`scan_frame` (the machinery 012's rows 32/49 already use).
Expected: in **both** files that slot's block paints the sentence **and** the comment — the ink box covers
the sentence's own lines plus the comment's, strictly taller than the same sentence rendered with no comment,
and the two files' boxes are the same for that slot (the setting changes what is heard, not what is seen);
`text=` equals the sentence's characters plus one line break plus the comment's characters in both files;
**no** sampled frame anywhere in either file contains a tag — which the row reads as `text=` matching that
sum exactly (a painted `[注]` would add its own characters) — and every frame of the content that carries no
comment is what 012 produces today. The measured numbers are written into this row and into
[research.md](./research.md) → Spike S2 rather than asserted from memory.
Proves SC-007, FR-013.

### 23. A comment's video, the audio — [device] (spike S1)

Test: `klhu_walk_comment.py 23`, then
`python3 specs/012-reading-video/scripts/klhu_probe_hiss.py <pulled video> --max-first-db -35`.
Steps: render the same content with the comments read and with them off; report the render's own
`klhu render pictures=… sentences=N` line and the file's measured duration and rate; listen-read the audio's
segments through `ffprobe`; run the hiss probe on the two-language file.
Expected: with the comments read `sentences=N` is the read's own utterance count (the sentence's sentences
plus the comment's), with them off it is the sentences' alone — the file says exactly what the read says, in
the same order and voices (SC-008); the file's duration differs from the comments-off file by the comment's
own audio; and the whole track is one stream at one rate with the comment's audio inside the sentence's slot:
if the engine writes the two languages' files in different channel counts the render fails with the
platform's own refusal (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:474-479`) rather than producing a broken file — which is the
finding this row exists to catch, not a test to hide. The measured rate, duration and `sentences=` values are
written into research.md → Spike S1.
Proves SC-008, FR-009's video half.

### 24. The 011 read receipt still passes — [structural]

Check: `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py` (its own rows, unchanged) plus
`flutter test test/language_test.dart test/segmenter_test.dart test/reader_service_test.dart`.
Expected: green, unmodified — the read of a content with no tag is byte-identical (SC-004), and
`test/language_test.dart`'s `resolveParagraphSpeeches offsets` group is untouched.
Proves SC-004.

### 25. The 012 video receipt still passes — [structural]

Check: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 32`, then `... 49` — **one row per run**:
012's script takes a single row and ignores the rest. Plus
`flutter test test/video_timeline_test.dart test/video_painter_test.dart test/video_renderer_test.dart`.
Expected: green, unmodified for a content with no comment — the video's sentences, frames, chrome, log line
and segments are what 012's own rows assert. This plan's video changes (a slot's block and its audio list) are
inert for such a content by construction, and that is the claim this row re-runs.
Proves SC-004, SC-008's invariance half.

### 26. The 014 dialogue receipt still passes — [structural]

Check: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 23`, then `... 25`, then `... 33` —
one row per run — plus
`flutter test test/dialogue_test.dart test/speech_resolver_test.dart test/role_store_test.dart test/reading_view_dialogue_test.dart`.
Expected: green, unmodified — 014's rules (the prefix rule, the turns, the role list, the picker, the Format
press, the stored entries' own shape for a content that never touched the comment switch) are what its rows
assert. 014's fixture carries no `[comment]`/`[注]` tag, so its driver's speak-line regex is untouched by the
new `comment=1` field (plan ripple 6).
Proves SC-004, SC-005, FR-015's store shape.

## Troubleshooting

- **The read speaks the comment's words with the sentence's voice.** The comment's `ParagraphSpeech` is
  carrying the wrong `language` or its voice is being assigned like a role's; the resolution sets the
  comment's language from its **own** content (A3, FR-008) and its voice from the language's own pick — the
  `klhu speak` line's `voice=` is the witness (row 17).
- **A marker appears on the page.** Every marker character must be inside an elided span: check
  `commentTagAt`'s `tagEnd` against the row-5 unit case for that shape before suspecting the span tree. A
  full-width `［注］` is **expected** to be painted — it is not a tag — so a reader who types one sees it.
- **A tap inside a comment answers the wrong thing.** The tap path maps the display offset back to a content
  offset first, then asks the comment rule (plan ripple 11). A tap on the elided seam reports the first
  character after the tag's own characters, which is inside the comment — never the tag itself.
  start, which belongs to the comment.
- **`sentences=N` disagrees with the read's own utterance count.** The video's resolution is not the read's:
  check that the render's call passes the same `commentsRead` the page did (FR-009's whole point).
- **A row reads zero `klhu speak` lines.** The evidence line changed shape: 015 appends ` comment=1` **after**
  the quoted utterance, and 014's driver's regex requires the utterance last. A driver that inserted the field
  before the text is the cause, not the app.
- **The render fails with "the sentences were written in different audio layouts".** The two languages' WAVs
  differ in **channel count**, which the platform half refuses by design
  (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:474-479`). Record it: it is what row 23 exists to catch.
