# Device validation: Comment Tag (015)

**Feature**: `015-comment-tag` | **Date**: 2026-10-09 — the walk began 2026-10-09 (rows 17, 18)
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Tasks**: [tasks.md](./tasks.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`), package `com.example.klhu` |
| Build | the row's own `flutter build apk --debug` + `adb install -r` (16.2 s) on `main` (HEAD `2639776` + this feature's uncommitted work), so the device ran the code the suite runs; `flutter analyze` clean; `flutter test --concurrency=2` → **630 passing, 0 failing** |
| Driver | `specs/015-comment-tag/scripts/klhu_walk_comment.py` — imports 014's `klhu_walk_dialogue.py`, which imports 012's `klhu_walk_video.py`, for the mechanics (one string per `adb shell`, `uiautomator dump` reads, `tap`, `check`); rows implemented as they are walked |
| Fixture | `specs/015-comment-tag/scripts/klhu_comment_fixture.txt` — nine named sections (`main`, `nota`, `traditional`, `inline`, `dialogue`, `standard_tags`, `head_comment`, `marker_only`, `full_width`), each pushed into the app's library by the driver |
| App locale | every row wipes the app's stored settings (`fresh_prefs`), so the chrome falls back to the **device's** locale — **English** on this AVD (`settings get system system_locales` empty). Every label the driver taps is matched in both languages (`app_zh_Hans.arb` / `app_en.arb`) |
| Engine | Google TTS (218 voices reported); `logcat` carries the app's own evidence lines — `klhu speak` (with 015's ` comment=1` after the quoted utterance), `klhu getVoices`, `klhu roles`, `klhu read range` |
| Interpreter | `/usr/bin/python3` (3.12) — the driver imports PIL (012's rows' frame reads); the default `python3` on this host has no PIL |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **PARTIAL** (walked, with the finding
written), **[unit]**, **[structural]**, or **NOT WALKED**.

**State of this file**: rows 15-26 are walked; rows 15-16 and 17-23 and 24-26 all pass (row 18's expectation was
corrected by the run, row 33 of the 26 group needed one re-run, and row 16's own key count was corrected —
§ Deviations 1, 4 and 5). No row is left unwalked.

## The rows at a glance

| Row | Scenario | State |
|---|---|---|
| 15-16 | the structural pair — no dependency and no platform change; the switch's key in all four locales | **WALKED — ALL GREEN** (a doc's key count corrected, § Deviations 5) |
| 17 | a comment read on the device: no marker painted, the sentence in the Spanish voice then the comment with `comment=1` in the English one, `[nota]`/`[註]` reading as `[注]` does | **WALKED — PASS (24/24)** |
| 18 | the inline tag's reach — one comment, its sentences in order, both `comment=1`; its own text detects Spanish, so it reads in the Spanish voice | **WALKED — PASS (7/7)** (the row's expectation corrected by the run, § Deviations 1) |
| 19 | a tap inside a comment answers — the comment's own span with them read, the owner sentence's with them off, and the highlight drawn in both | **WALKED — PASS (6/6)** |
| 20 | the switch off across a force-stop, per content, and gone with the content | **WALKED — PASS (9/9)** |
| 21 | a comment inside a dialogue turn (the turn keeps its words, language and voice; the role list unmoved) and in 标准, plus a comment before every sentence | **WALKED — PASS (9/9)** |
| 22 | a comment's video, the frames — the block paints the sentence and the comment in both switch states, the twin renders as 012 does | **WALKED — PASS (35/35)** |
| 23 | a comment's video, the audio — `sentences=` follows the read in both switch states, the files differ by the comment's audio, one rate, no hiss | **WALKED — PASS (25/25)** |
| 24-26 | the three receipts — 011's read, 012's video, 014's dialogue, each with its own unit group | **WALKED — ALL GREEN** (one transient, re-run) |

## Row 17 — a comment read on the device (24/24)

```
PASS 17: the device's own voice list came off the app (one line per voice) — 218 voices in this window
PASS 17: the reader's two picks were seeded in the app's own store — picks: {'voice_es': 'es-es-x-eea-local||es-ES', 'voice_en': 'en-au-x-aua-local||en-AU'}
PASS 17[main]: the page paints the comment's words (FR-012) — painted: 'Hola.\n\nHow are you?'
PASS 17[main]: no marker character reaches the page (FR-005) — painted: 'Hola.\n\nHow are you?'
PASS 17[main]: every sentence of the sentence's paragraph and the comment reached the engine, one utterance each (FR-007) — spoken: ['Hola.', 'How are you?']
PASS 17[main]: the comment's own utterance carries comment=1 (D9) — comment flags: [False, True]
PASS 17[main]: no marker in any spoken text (SC-001) — spoken: ['Hola.', 'How are you?']
PASS 17[main]: the sentence and the comment read in different voices (SC-003) — voices: ['es-es-x-eea-local', 'en-au-x-aua-local']
PASS 17[main]: the sentence reads in the Spanish voice, the comment in the English one (SC-003, FR-008) — locales ['es-ES', 'en-AU']
… the same nine checks for [nota] and for [traditional] …
PASS 17: [注], [nota] and [註] read exactly alike (FR-001, 2026-10-08)
```

the app's own lines for the three spellings (identical):

```
klhu speak p0 s0 voice=es-es-x-eea-local "Hola."
klhu speak p1 s0 voice=en-au-x-aua-local "How are you?" comment=1
```

**What it proves**: SC-001 (no marker in any utterance), SC-003 (two languages, two voices, per utterance),
SC-006's paint half (the page paints both languages and no marker), FR-001 (the four spellings are one tag on a
device), FR-005, FR-007, FR-008.

## Row 18 — the inline tag's reach (7/7)

```
PASS 18: the page shows the sentence and the comment, and no marker — painted: 'Hola. Hi. Adiós.'
PASS 18: exactly one comment is spoken, its sentences in order (FR-002) — spoken: ['Hola.', 'Hi.', 'Adiós.']
PASS 18: the comment's utterances carry comment=1 and the sentence's does not (D9) — comment flags: [False, True, True]
PASS 18: the comment's utterances read in the voice its own text detects (es here — the accent in Adiós.) (FR-008, A3) — voices ['es-es-x-eea-local', 'es-es-x-eea-local', 'es-es-x-eea-local'] → locales ['es-ES', 'es-ES', 'es-ES']
PASS 18: Adiós. is the comment's own text, not a sentence read in its own right (FR-002's boundary) — spoken/comment: [('Hola.', False), ('Hi.', True), ('Adiós.', True)]
```

the app's own lines:

```
klhu speak p0 s0 voice=es-es-x-eea-local "Hola."
klhu speak p0 s0 voice=es-es-x-eea-local "Hi." comment=1
klhu speak p0 s0 voice=es-es-x-eea-local "Adiós." comment=1
```

**What it proves**: the tag took the rest of its paragraph — the paragraph is ONE comment after `Hola.`, and
`Adiós.` is an utterance of that comment (with `comment=1`), not a sentence of the paragraph read in its own
right. The comment's voice is its **own** text's language (A3): `Hi. Adiós.` carries `Adiós.`'s accent, so the
detector reads Spanish and the comment is voiced by the Spanish pick — the same one `Hola.` gets, which is the
honest reading of this text and the reason the row's expectation was corrected (the two-language case is row
17's). The page shows `Hola. Hi. Adiós.` with no marker.

## Row 19 — a tap inside a comment (6/6)

```
PASS 19: with the comments read the read's range is the comment's own span (SC-009) — ranges [(11, 23)], the comment is (11, 23)
PASS 19: the comment itself was read (never a marker, never nothing) — spoken: [('How are you?', True)]
PASS 19: the highlight was drawn while the read ran (FR-012) — 1076 highlighted pixels in the still
PASS 19: with the comments off the same tap answers the owner sentence (SC-009, FR-012) — ranges [(0, 5)], the owner is (0, 5)
PASS 19: that sentence was read, and no comment's characters with it — spoken: ['Hola.']
PASS 19: the highlight was drawn in this state too (FR-012) — 410 highlighted pixels in the still
```

the driver's own taps, and the app's lines for the two states:

```
tap the comment's line @540,606 (block 228x158 at 540,551)   # the block is `Hola.`, a blank line, the comment
▶ Read → klhu read range: 11..23   klhu speak … "How are you?" comment=1   # the comment, comments read
the switch turned off on the page's own sheet (Text type → the switch → Done; the store kept `comments: false`)
▶ Read → klhu read range: 0..5     klhu speak … "Hola."                   # the owner sentence, no comment
```

**What it proves**: SC-009's tap half and FR-012, on a real gesture. The tap point is the comment's own painted
line, i.e. a **display** offset; the page maps it back to a content offset and answers with the comment rule
before the segmenter (research D7). With the comments read the answer is the comment's own span `11..23` and the
comment is spoken; with them off the same tap answers the owner sentence `0..5`, and only that sentence is read
— never a marker, never a gap, in either state. The highlight's **exact** span is the range line's own (the page
sets it from the same range) and the span tree is asserted by the unit file (T008); the stills prove the band is
drawn — 1076 pixels of `Colors.yellow` over the comment, 410 over `Hola.`.

## Row 20 — the switch off, across a restart, and with the content gone (9/9)

```
PASS 20: the switch is stored for this content, and it alone (FR-014) — content_roles[comment_main] = {'comments': False}
PASS 20: none of the comment's words reaches the engine (SC-002) — spoken: ['Hola.']
PASS 20: the page still paints the comment's words, and no marker (FR-005) — painted: 'Hola.\n\nHow are you?'
PASS 20: the app reopens on the same content — the page's own labels: ['KalaHoo Reading', 'English', 'Appearance', 'Contents', 'Text type', 'Voice']
PASS 20: after the restart the switch is still off for that content (SC-010, FR-014) — content_roles[comment_main] = {'comments': False}
PASS 20: the read after the restart is the read before it (SC-002) — spoken: ['Hola.']
PASS 20: a content whose switch was never touched still reads its comments (FR-016, SC-010) — spoken: [('Hola.', False), ('How are you?', True)]
PASS 20: the delete asks first (the shipped dialog shape) — labels: ['Delete this content?', 'This cannot be undone.', 'Cancel', 'Delete']
PASS 20: deleting the content takes its entry, the switch with it (SC-010, FR-015) — content_roles = None
```

**What it proves**: SC-002 (with the switch off none of the comment's words reaches the engine, while the page
still paints them — the setting changes what is heard, not what is seen), SC-006's switch half, SC-010 (the
choice survives a force-stop, is per content, and dies with the content), FR-014, FR-016. The store read back off
the device: `{'comments': False}` for the one content and nothing for the other, and the whole key gone once the
content was deleted through the shipped confirm dialog.

## Row 21 — a comment inside a dialogue turn, and in 标准 (9/9)

```
PASS 21: the comment's own voice (en) was seeded in the app's store — picks: {'voice_es': 'es-es-x-eea-local||es-ES', 'voice_en': 'en-au-x-aub-local||en-AU'}
PASS 21: the turn speaks its own words, with none of the comment's in them (FR-011, scenario 1) — spoken: ['今日个天气真系唔错啊。', 'How are you?']
PASS 21: the turn is 阿明's and the comment is nobody's (FR-011) — role/comment: [('阿明', False), (None, True)]
PASS 21: the comment reads in its own language's voice, never the role's (FR-008, scenario 1) — voices: ['cmn-cn-x-ccc-local', 'en-au-x-aub-local'] → locales ['zh-CN', 'en-AU']
PASS 21: the comment-only paragraph is no turn and no role (FR-011, scenario 3) — the list's roles: ['阿明']
PASS 21: 阿明's turn count is unmoved by the comment (SC-005) — 阿明's row: '阿明\n1 turn · 普通话 CCC (女)'
PASS 21: the 标准 content reads the shipped sentence and then the comment (FR-010, scenario 4) — spoken: ['{阿明} 今日个天气真系唔错啊。', 'How are you?']
PASS 21: a comment before every sentence is never spoken (FR-003) — spoken: [('Hola.', False)]
PASS 21: it is displayed all the same (FR-003) — painted: 'Hello.\n\nHola.'
```

the app's own lines:

```
klhu speak … role=阿明 voice=cmn-cn-x-ccc-local "今日个天气真系唔错啊。"   # 多人对话: the turn, its own voice
klhu speak … role=narration voice=en-au-x-aub-local "How are you?" comment=1  # the comment, in en
klhu speak … "{阿明} 今日个天气真系唔错啊。"                              # 标准: the shipped read, tag and all
klhu speak … voice=en-au-x-aub-local "How are you?" comment=1                # …plus the comment after it
klhu speak … "Hola."                                                        # the head-comment content: sentences only
```

**What it proves**: SC-005 (the turn's own speech and its role count, unmoved by the comment), FR-010, FR-011,
FR-003's own edge case, and FR-008 (the comment's own language decides its voice — en here, against 阿明's
zh-CN). Two details worth quoting rather than smoothing: in **标准** the first utterance is the paragraph **as
shipped**, `{阿明} 今日个天气真系唔错啊。` — the role tag is ordinary text there (014's rule), so it is spoken, and
`voice=` is absent because no zh-Hans pick was seeded (the OS default); and the role list's row reads
`阿明 / 1 turn · 普通话 CCC (女)` — **one** turn, the comment-only paragraph contributing nothing.

## Row 22 — a comment's video, the frames (35/35)

```
PASS 22: slot 0's block paints the sentence, a line break and the comment — the tag is in no frame (SC-007, FR-013) — text=18, the sum is 18
PASS 22: with the comments off the block paints exactly the same — the setting changes what is heard, not what is seen — text=18
PASS 22: the tagless twin's slot is the sentence alone, as 012 renders it today — text=5, the sentence is 5
PASS 22: the two files' boxes are the same for that slot (SC-007) — read (208, 864, 456, 964) vs off (208, 864, 456, 964)
PASS 22: the block covers the sentence's lines plus the comment's — strictly taller than the same sentence with no comment (FR-013) — the block's ink is 100px tall, the twin's 30px
PASS 22/comments-read: every one of the file's 100 frames is the app's own look — no band, no chrome
PASS 22/comments-off: every one of the file's 75 frames is the app's own look — no band, no chrome
PASS 22/no-comment: every one of the file's 75 frames is the app's own look — no band, no chrome
```

the renderer's own line, and the numbers the run measured (Spike S2's):

```
klhu render pictures=0 ranges= sentences=2
klhu render slot=0/2 frame=0/100 kind=sentence frames=100 scroll=0 picture=none tone=- role=narration span=0..5 text=18
   comments read  — 100 frames, 3333 ms, 132635 B — slot 0's ink box (208, 864, 456, 964) at 1920x1080, 100 px tall
   comments off   —  75 frames, 2500 ms,  96187 B — slot 0's ink box (208, 864, 456, 964)          — identical
   the twin, no comment — 75 frames, 2500 ms, 45516 B — slot 0's ink box (208, 924, 298, 954), 30 px
```

**What it proves**: SC-007 and FR-013, measured on the encoded frames rather than asserted. The block paints
the sentence and the comment in **both** switch states — the boxes are equal to the pixel — so the switch
changes what is heard, not what is seen. `text=18` is exactly the sentence's 5 characters + one line break +
the comment's 12, which is also how the row reads the marker's absence: a painted `[注]` would add four more.
The tagless twin's slot is `text=5` and its box 30 px, so a content with no comment renders exactly as 012
renders today. One detail worth keeping: the twin's single line sits where the block's **second** line sits
(y 924..954 inside 864..964), so the comment's line takes the place the single line had and the block grows
upward.

A driver fix on the way, not a device finding: 012's imported `render()` matched the app's told length to
Python's own `round(ms / 1000)` as an exact string, and a render landing exactly on .5 s — 2500 ms — is `3 s`
on the page (Dart rounds half away from zero) and `2` in this process (half to even); the check now reads the
number with the same one-second tolerance its own neighbour already had.

## Row 23 — a comment's video, the audio (25/25)

```
PASS 23: the read's own utterances are the sentence then the comment — spoken: ['Hola.', 'How are you?']
PASS 23/comments-read: the file says what the read says — `sentences=` is the read's own utterance count (SC-008) — the renderer's own line: {'synth_ms': 145, 'paint_ms': 16, 'send_ms': 2274, 'total_ms': 2292, 'finish_ms': 7, 'sentences': 2, 'pictures': 1, 'frames': 100}
PASS 23: the read with them off is the sentence alone — spoken: ['Hola.']
PASS 23/comments-off: `sentences=` is the sentences' alone (SC-008) — the renderer's own line: {'synth_ms': 59, 'paint_ms': 31, 'send_ms': 1766, 'total_ms': 1798, 'finish_ms': 3, 'sentences': 1, 'pictures': 1, 'frames': 75}
PASS 23: the whole track is one stream at one rate in each file, and the same rate in both (SC-008) — ['24000'] vs ['24000']
PASS 23: neither render fell to the platform's own refusal — the two languages muxed into one layout — channels [1, 1]
PASS 23: the read file is longer than the comments-off one by the comment's own audio (SC-008) — 833ms / 25 frames more; the files are 3.46125s and 2.627958s
PASS 23: each file's own duration is the render's length plus the platform's own fixed tail — files 3.46125s and 2.627958s, the renders 3333ms and 2500ms — a tail of 128 ms and 128 ms
PASS 23: the two-language file carries no hiss above 10 kHz — the probe's own ceiling (SC-008, 012's FR-017) — the probe exited 0, first 2 s -66.0 dB against the -35 dB ceiling
```

the renderer's own accounts, and the ffprobe/hiss readings (Spike S1's numbers):

```
comments read  — sentences=2 pictures=1 frames=100  100 frames 3333ms 132635B  audio 24000 Hz 1 ch
comments off   — sentences=1 pictures=1 frames=75    75 frames 2500ms  96187B  audio 24000 Hz 1 ch
the difference — 833 ms / 25 frames  =  the comment's own audio
containers     — 3.46125 s vs 2.627958 s (each ~128 ms past the muxer's own ms)
the >10 kHz probe on the read file — exit 0, first 2 s −66.0 dB (the ceiling is −35 dB)
```

**What it proves**: SC-008 and FR-009's video half. `sentences=` is read against the **read's own** utterance
count taken on the device in the same run (2 and 1, not a number written into the row), so the file says what
the read says in both switch states; the two files differ by exactly the comment's audio (833 ms / 25 frames,
matched by the container durations); the whole track is one stream at one rate in each file and the same rate
in both — the two languages muxed into one layout, so the plugin's own refusal (`the sentences were written in
different audio layouts; they cannot be muxed`) was not reached, which is the finding this row exists to catch;
and the two-language file carries no interpolation hiss above 10 kHz.

## Rows 15-16 — the structural pair (all green)

Row 15 — no dependency and no platform change ([structural], FR-018, SC-011)

```
git diff --stat pubspec.yaml pubspec.lock android/ ios/    → nothing (exit 0, no lines)
git status --short pubspec.yaml pubspec.lock android/ ios/ → nothing
```

The dependency block and the platform tree are untouched. The platform half the video uses is *read*, not
changed: its audio list already takes one file per utterance (research D8) — which is why the two-language
render muxed with no Kotlin edit at all (row 23).

Row 16 — every new key in all four locales ([structural], FR-014's string half)

```
message keys per ARB (keys not starting with '@'):
  app_en.arb 108    app_es.arb 108    app_zh.arb 108    app_zh_Hans.arb 108
against HEAD (107 message keys):  added ['commentsReadLabel']   removed []
each translation against the template:  missing [] extra []   (all three)
flutter test test/l10n_keys_test.dart → 3 tests, all passed
flutter gen-l10n → the generated Dart is byte-identical to what is already on disk (sha256 before == after)
git status --short lib/l10n → the four ARBs + the four generated files, modified by this feature (uncommitted)
```

**The one correction.** The row was written expecting **109** keys (107 + two new), but the feature adds
**one** — `commentsReadLabel` — for 107 → **108**, and every other authority in the feature says one: the
research's own decision (D6: "its label is a new key"), T001's receipt (2026-10-08: "one key,
`commentsReadLabel` … 107 → **108 message keys each**. No hint line was added") and the switch's own shape
(a single `SwitchListTile` title). `plan.md`'s l10n step carried the same slip, writing "Two new keys" in a
sentence that immediately says "the switch's label, and nothing else". **The app is right; both places were
corrected in place and dated** — the quickstart's row 16 and `plan.md`'s step 5 (§ Deviations 5). A hint line
under the switch would be a second key and a new decision, not a doc fix.

**What they prove**: FR-018 and SC-011 (no dependency, no platform edit — the video's platform half was read
only), and FR-014's string half (the switch's key exists in all four locales, the generated Dart on disk is the
generator's own output, and no translation keeps a key the template dropped).

## Rows 24-26 — the three receipts (all green)

Row 24 — 011's read ([structural])

```
011's driver takes one row per run (a bare run prints `usage: … 7|8|9|10|16|17|20|21` and exits 2):
  7 → RESULT: PASS    8 → RESULT: PASS    9 → RESULT: PASS    10 → RESULT: PASS
  16 → RESULT: PASS   17 → RESULT: PASS   20 → RESULT: PASS   21 → RESULT: PASS
014/012-style `  PASS `/`  FAIL ` lines: none — 011's driver prints ONE `RESULT:` line per row, not one
line per check, so its output has no per-check lines to count. Verified directly: each of the eight
files holds exactly one `RESULT: PASS` and no `FAIL`/`Traceback`/`Error` anywhere.
flutter test test/language_test.dart test/segmenter_test.dart test/reader_service_test.dart → 42 tests, all passed
```

Row 25 — 012's video ([structural])

```
python3 specs/012-reading-video/scripts/klhu_walk_video.py 32 → 42/42 checks passed
python3 specs/012-reading-video/scripts/klhu_walk_video.py 49 → 41/41 checks passed
flutter test test/video_timeline_test.dart test/video_painter_test.dart test/video_renderer_test.dart → 62 tests, all passed
```

Row 26 — 014's dialogue ([structural])

```
python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 23 → 10/10 checks passed
python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 25 → 19/19 checks passed
python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 33 → 5/9, then 9/9 on a re-run alone (below)
flutter test test/dialogue_test.dart test/speech_resolver_test.dart test/role_store_test.dart test/reading_view_dialogue_test.dart → 74 tests, all passed
```

**The one transient, and why it is not a regression.** 014's row 33 read the editor's field 1.2 s after the
**first** Format press and got the pre-press text (63 chars) where the app had already formatted it to 66; the
second press's read then showed 66, which broke the row's own "a second press changes nothing" as well. The
checks that read later — Undo's byte-for-byte restore, Done's save (66 chars) and the reopened page — all
passed, so the app's Format did its work on the first press. 015 leaves that path alone (`git diff
lib/reading_view.dart lib/dialogue.dart` carries no hunk at the editor's `formatForDialogue` call,
`reading_view.dart:753`, or at the button's enabled rule, `:2562`), 014's own receipt has the row at 9/9 with
the same driver, and a re-run alone three minutes later was **9/9** with no failure. It is recorded as a read
that raced the field, not as a claim about the app.

**What they prove**: SC-004 (nothing 015 changed has moved for a content with no comment), SC-005 and FR-015's
store shape (014's own rules and the shape of its stored entries), SC-008's invariance half, and plan ripple 6 —
014's driver reads its own speak lines unchanged beside the new `comment=1` field.

## Deviations

1. **Row 18's expectation was wrong, and was corrected — the fixture text is kept (the reader's answer,
   2026-10-09).** The comment's language is `detectLanguage` of its **own** content (FR-008/A3), and the
   detector's rule table treats an accented Spanish letter as Spanish: `Adiós.` carries `ó`, so `Hi. Adiós.`
   detects **es** and the comment is voiced by the Spanish pick (`es-es-x-eea-local`) — the same pick `Hola.`
   gets. The row had been written expecting "the English voice" and "`Adiós.` nowhere as a Spanish-voice
   utterance", both assuming the comment was English. **The app is right; the expectation was fixed in place**
   (`quickstart.md` row 18, and the same claim in `spec.md`'s inline edge case and the fixture note), and row 18
   re-walked **7/7** against the corrected form. Row 17 carries the two-language case (a plainly English comment
   in the English voice), so FR-008/SC-003 is proved by a text where the two languages really differ.
2. **The driver seeds the reader's two picks, rather than tapping two pickers.** A 标准 read names the voice the
   engine was given only when the reader has a pick (`loadVoice` answers null without one, and the app then omits
   `voice=`), so rows 17/18 write `voice_es`/`voice_en` into the app's own store — the two decisions the picker
   would write, in the format `VoiceStore` reads back (`<name>||<locale>`), with names taken from the device's own
   `klhu getVoices` list. The alternative — opening 语音 once per language and tapping a row — was not taken
   because the read rows' subject is the comment's voice, not the picker's (014's row 24 already drives the
   picker). Recorded as a deviation rather than presented as the reader's own gesture.
3. **A bare read prints no voice catalogue.** `ReaderService.voicesForAll` logs nothing; only the picker's
   `voicesFor` prints `klhu getVoices` (one line per engine entry). The driver therefore harvests the device's
   voice list by opening 语音 and pressing Back (014's row 28 does the same), not from the read.
4. **014's row 33 read one press stale on its first run (2026-10-09), and is green on a re-run.** Walked as part
   of row 26, the first run scored **5/9**: the field read 63 chars 1.2 s after the first Format press where the
   app had already made it 66, so that press's own checks failed, and the second press's read then showing 66
   broke the row's "a second press changes nothing" too — while Undo's byte-for-byte restore, Done's save of 66
   chars and the reopened page (the checks that read later) all passed, so the app did the work on the first
   press. 015 does not touch that path (`git diff lib/reading_view.dart lib/dialogue.dart` has no hunk at the
   editor's `formatForDialogue` call, `reading_view.dart:753`, or at the button's enabled rule, `:2562`), 014's
   own receipt has the row at 9/9 with the same driver, and a re-run alone three minutes later was **9/9** with
   no failure. Recorded because a receipt that failed once and passed on a re-run is a fact about the walk, not
   something to leave out of the record.
5. **Quickstart row 16's key count was 109, and `plan.md`'s l10n step said "Two new keys" — the feature ships
   one (2026-10-09).** Corrected in place, dated, in both places: the switch is a single `SwitchListTile` title,
   so `commentsReadLabel` is the feature's only message key and each of the four ARBs carries **108** message
   keys (107 before). That is what `research.md` § D6 decided ("its label is a new key") and what T001's
   2026-10-08 receipt recorded ("one key, `commentsReadLabel` … 107 → 108 message keys each. No hint line was
   added"). The docs were corrected rather than the implementation padded to match a count. A hint line under
   the switch would be a second key and a new decision — not part of this row.
