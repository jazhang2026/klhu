# Research: Comment Tag

**Feature**: `015-comment-tag` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Grounding corrections

Four statements were checked against this checkout before the plan was written; three are exact and the
fourth is a count that has drifted. Every one is recorded here rather than edited into the reviewed
`spec.md`, which is the record of what the reader approved (the corrected form is what the plan implements).

1. **A1's corpus count has drifted, and the amendment now carries the measured one.** The reviewed sentence said
   *"118,571 non-blank lines of `*.md`/`*.txt`, 44 lines begin with `[`"*. Re-measured on 2026-10-08 over the
   working tree
   (`find . -name '*.md' -o -name '*.txt' | grep -v '/.git/'`, then counting non-blank lines): **628
   files, 121,596 non-blank lines**, and lines beginning with `[`: **28**. The difference is the specs
   written since that measurement (014's and 015's own artifacts among them), not a different rule — the count was
   taken before they existed. **A1 itself was rewritten by the reader's amendment of 2026-10-08** (the tag's four
   spellings) and carries the numbers measured here — 123,236 non-blank lines, 28 lines beginning with `[` — so the
   reviewed figure and the amended one differ on the record rather than silently. What A1 *uses* the number for is
   unchanged and holds exactly:
   the only `[comment]`/`[注]` occurrences anywhere in the tree are in `text.txt` (the reader's wish-list, 3 lines)
   and in the files this feature wrote, and the amendment's two new spellings are **cleaner still**: `[nota]`,
   `[Nota]`, `[註]` and `[comentario]` occur **nowhere at all** (0 files). **No shipped content, asset, document or
   test uses any of the shapes**, so the tag costs no migration and collides with nothing — which is also why the
   spelling set could be extended without a corpus risk.
2. **A7 — "one block per slot, 012's slot arithmetic unchanged" — does not survive the case where a render
   starts after the comment's owner.** `videoSentencesFrom` resolves from `resolveSentence(content,
   position).start` to the content's end (`lib/video_timeline.dart:116-126`), so a render begun at a stored
   position that sits *after* the sentence a comment belongs to has that sentence in no slot — while the
   read from the same position still speaks the comment (its speech is in the range; see D1). A7 assumed
   the sentence is always in the file. The plan's correction: the comment rides the **last sentence before
   it in the file's own sentence list** — which for every render that reaches its owner is the owner, and
   for a render that starts past it is the file's own opening sentence — and when the file has no sentence
   before it at all (a range that begins at the comment itself), the comment is read as a slot of its own
   rather than dropped, because a file that went silent where the read speaks would break FR-009/SC-008.
   The spec keeps A7's wording; the case is stated in this file and in `data-model.md` §4 and the row that
   measures it.
3. **The checklist's ARB count is one short.** `checklists/requirements.md` says *"`app_en.arb` — the
   template, 116 keys — … 107 each"*. Measured (`json.load`, keys not starting with `@`): **107 message
   keys in each of the four ARBs**, the template carrying **117 keys in total** (107 messages + 10
   `@`-metadata entries) and each translation 108 (107 + `@@locale`). The plan's own count is quoted from
   this measurement, not from the checklist.
4. **A2, A3, A4 and A5's citations all resolve to the rules they name** — `lib/segmenter.dart:71`
   (`paragraphRanges`, the app's own paragraph unit, the ranges 014's turns are cut on), `lib/language.dart:96`
   (`detectLanguage`, the rule table), `lib/reading_view.dart:2241-2255` (the span tree, one `RichText`, the
   highlight as a middle span) with `:192` (`_highlight`) and `:968` (`_onTapText`) as the offsets' homes, and
   `lib/role_store.dart` (the per-content store, key `content_roles` at `:117`). No correction needed; the
   plan's design is built on exactly these.

## Verified environment facts

Everything a decision below rests on, checked against this checkout on 2026-10-08 (`file:line` is the
evidence; nothing here is from memory):

| Fact | Where it was verified |
|---|---|
| Dart `^3.13.3`, Flutter **3.47.5** stable | `pubspec.yaml:22`; `flutter --version` (2026-10-08) |
| Baseline of the tree this plan is written against: **559 tests green, 0 failing**, and `flutter analyze` → *No issues found!* | `flutter test --concurrency=2`, `flutter analyze` (2026-10-08, this host) — the figure `quickstart.md`'s Prerequisites carries |
| Dependencies: `flutter_tts ^4.2.3`, `shared_preferences ^2.5.5`, `intl ^0.20.3`, `path_provider ^2.1.6`, `file_selector ^1.1.0`; dev: `flutter_test`, `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4` | `pubspec.yaml:39-56`, `:58-73` |
| The read's units reach the engine as `List<ParagraphSpeech>`; the reader service cuts each into sentences itself | `lib/reading_view.dart:1072-1105` (`_readRange` → `speakParagraphs`) → `lib/reader_service.dart:374-415` (`_sentencesOf`) |
| `ParagraphSpeech` is `{text, language, voice, start, end, role}` — `role` is the one additive field 014 added, nullable by construction, and it exists for the log line | `lib/reader_service.dart:66-89` (`role` at `:79`), the line at `:522-527` |
| Offsets everywhere are **content** offsets: the highlight, the tap's answer, the Continue Read anchor and the stored position | `lib/reading_view.dart:192` (`_highlight`), `:998` (`resolve(_content, pos.offset)`), `:1005` (`_anchor = segment.start`), `:1018-1033` (`_persistAnchor` → `ReadingPosition.offset`) |
| The page paints the reader's text **verbatim** today: one `RichText`, one span tree (before / highlight / after), the highlighted middle span styled yellow | `lib/reading_view.dart:2241-2255`, the `RichText` at `:2399-2409` |
| The page's tap maps a touch point to a text offset through the `RenderParagraph` and resolves it with the segmenter | `lib/reading_view.dart:991-1010` (`_resolveAt`), the segmenter's own `resolveSentence`/`resolveParagraph` at `lib/segmenter.dart:148-152` |
| The tracking highlight and the follow-scroll measure the spoken span by a `TextSelection` over that same `RenderParagraph` | `lib/reading_view.dart:1181-1203` (`_measure`, the selection at `:1189`) |
| A sentence is a delimiter-terminated run — `. ! ? ; 。！？；` plus `...`/`……`, with trailing closing quotes/brackets absorbed (`]` is in the closers) and leading whitespace skipped | `lib/segmenter.dart:17-18` (the sets), `:33-69` (`sentenceRanges`), `:53-59` (the whitespace skip) |
| A paragraph is the app's own unit: blank-line separated (`\n[ \t]*\n+`), a single `\n` inside it does not break it | `lib/segmenter.dart:71-108` |
| Language detection is a rule table run on a paragraph's full text: CJK → `zh-Hans`, Spanish letters/one Spanish-only word/two function words → `es`, else `en` | `lib/language.dart:96-102` (the entry point), rule table `:29-93`, used per paragraph at `:119` |
| 标准's read IS one call to `resolveParagraphSpeeches(content, start, end, loadVoice)` | `lib/speech_resolver.dart:50-52`; the function at `lib/language.dart:110-133` |
| 014's tag grammar, in one place: ASCII braces, a name of at least one character that never spans a line, an optional separator (spaces, one optional `:`/`：`, spaces), read at a paragraph's **head only** | `lib/dialogue.dart:115-147` (`roleTagAt`), its doc at `:94-114`; the same table in prose at `:220-233` (`formatForDialogue`) and `:270-289` (`tagOffsets`, the scan *anywhere*) |
| A turn is a paragraph; a paragraph whose head carries no tag is one narration turn; a turn's content ends at its last non-whitespace character and excludes the prefix | `lib/dialogue.dart:160-195` (`turnsOf`), `:47-73` (`Turn`) |
| In dialogue mode the resolver builds one `ParagraphSpeech` per turn, each with its own detected language and the role's voice; a narration turn reads in the language's own pick | `lib/speech_resolver.dart:54-81`, the assignment at `lib/dialogue.dart:321-397` |
| 014's per-content store: one `shared_preferences` key `content_roles`, a JSON object keyed by the content's id, tolerant reads, written only on a change, the entry dropped when it says nothing, removed at the content's delete | `lib/role_store.dart:117` (the key), `:122-127` (load), `:186-202` (`_write`, the empty-entry drop at `:196-200`), `:207-227` (tolerant read), `:180-184` (`clearFor`); the delete site `lib/content_list_screen.dart:115` |
| `RoleSettings` is constructed **field by field** in four places (the store's own two `with*` helpers and the page's text-type switch), so a new field has four sites to keep in step; `isEmpty` is what decides whether an entry survives | `lib/role_store.dart:59-63` (ctor), `:68` (`isEmpty`), `:87-95` (`withRemoval`), `:100-108` (`withVoice`), `lib/reading_view.dart:1360-1368` (`_setDialogue`) |
| The page's settings sheet is 014's dialog, reached from the app bar (`textTypeButton`) and titled `textTypeTitle`; it holds the type chips and the role list; the app's shipped switch shape is a `SwitchListTile` | `lib/reading_view.dart:614-618` (the action), `:1383-1482` (`_openTextType`), `:1412-1414` (the dialog), `:1419-1434` (the chips), `:1449-1468` (the role list), `:1694-1700` (`SwitchListTile`, the video review's own) |
| The video's own unit: one `VideoSentence` per sentence of the resolved speeches, one slot per sentence whose duration is that sentence's own audio, a 400 ms gap between slots and a 2 s hold after the last | `lib/video_timeline.dart:70-93` (`videoSentencesOf`), `:131-178` (`VideoSlot`, the text at `:159`), `:226-297` (`buildVideoPlan`), `:202-203` (gap/hold) |
| The painter draws **`slot.text`** — one wrapped `TextPainter` per slot, reported as `paintedText` | `lib/video_painter.dart:576-603` (`_blockFor`, `paintedText: slot.text` at `:603`), the paint at `:452`, `VideoFrame.paintedText` at `:169` |
| The renderer synthesizes **one WAV per sentence** (`sentence_$i.wav`), reads its length from the header, and hands the muxer **one audio segment per slot** laid end to end | `lib/video_renderer.dart:226-259` (pass 1), `:245` (`wavDurationMsOf`), `:312-323` (the segments); `lib/platform/video_encoder.dart:20-21` (`VideoAudioSegment{path,durationUs}`) |
| The platform half reads **every segment's WAV, pads or cuts it to its `durationUs`, and takes the highest sample rate of the lot** — only a differing **channel count** is a failure | `android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:461-496` (`encodeAudio`, the channel check at `:474-479`, the rate choice at `:480`, the resample at `:490-496`, the pad/cut at `:526-527`) |
| A render whose sentences carry two different sample rates already ships: 014's row 29 renders one voice's `-local` (24 kHz) and `-network` (48 kHz) copies together and passes, with the conversion's own hiss probe | `specs/014-dialogue-reading/quickstart.md` rows 29 and 35; `lib/video_renderer.dart`'s note in the platform half above |
| The device rows' read evidence is the per-utterance line `klhu speak p<i> s<j>[ role=…][ voice=…] "text"`; the render's is `klhu render slot=… text=<painted length>` and `klhu render pictures=… sentences=N` | `lib/reader_service.dart:522-527`; `lib/video_renderer.dart:358-368`, `:277-279` |
| 014's driver parses the speak line with a regex that **ends in the quoted text** (`' "(.*)"'` after the optional `role=`/`voice=` groups) | `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py:161-166` |
| 012's driver parses the render's slot line with a regex that **ends in `text=(\d+)`** | `specs/012-reading-video/scripts/klhu_walk_video.py:486-492` |
| The four locale files carry 107 message keys each; `test/l10n_keys_test.dart` fails if the template gains a key any translation lacks, **and** if a translation keeps a key the template dropped | `lib/l10n/app_{en,zh,zh_Hans,es}.arb` (counted); `test/l10n_keys_test.dart:41-55`, `:57-68` |
| The app's four UI locales and their codes: `en`, `zh`, `zh_Hans`, `es`; the languages it *reads* are only three — `en`, `zh-Hans`, `es` | the four ARBs' own `@@locale` values (`lib/l10n/app_{en,zh,zh_Hans,es}.arb`); `lib/reading_view.dart:654-680` (the dropdown) and `lib/language.dart:15-22` (`languageLabelOf`) |
| The largest content the app accepts | `lib/models/content.dart:21` (`kMaxContentChars = 100000`) |
| 45 test files exist today (`ls test/*.dart`), 559 tests | `ls test/*.dart`; the suite run above |

## Decisions

Each decision is what was chosen, why, and what else was considered — the shape 012's and 014's research use,
so a reviewer can argue with one entry at a time.

### D1 — A comment is a **second `ParagraphSpeech` beside its sentence's own**, placed where its own text sits

**Decision**: `resolveSpeeches` (`lib/speech_resolver.dart:39`) gains one optional parameter —
`commentsRead` (default `true`, the shipped default of FR-006) — and, when a content holds comments, returns
them as **their own entry in the list it already returns**: a `ParagraphSpeech` whose `text` is the comment's
content, whose `language` is `detectLanguage` of that content alone (`lib/language.dart:96`), whose `voice` is
the language's own pick through the same `loadVoice` seam a paragraph uses, whose `start`/`end` are the
comment's content span, and which is marked `isComment: true` (the field `role` is the precedent for:
additive, nullable-by-default, and read by the read's evidence line — D9).

Its position in the list is its **text position**, and that is the whole of FR-007's ordering rule: the
comment's tag sits inside its own paragraph, and the sentence it belongs to (D4) is the last sentence of the
piece of text before that tag, so the comment's entry lands immediately after the entry that sentence belongs
to. Nothing has to be inserted anywhere; the list order *is* the read order.

In 标准 this means the speeches of one paragraph with an inline tag are two entries (the sentences' text up
to the tag, then the comment); in 多人对话 it means a turn's entry is followed by the comment's own. With
`commentsRead: false` the comment's entry is **not emitted at all** — the switch is a property of the
resolution, which is what keeps FR-009 (one resolution) true instead of the page, the service and the video
each filtering.

**Rationale**: `List<ParagraphSpeech>` is the one interface the page, the reader service and the video already
agree on (014's D1), and 015's own A8 says the comment is *"a second speech beside its sentence, not a new
unit"*. Making it an entry in that list costs the reader service nothing at all: it cuts each entry into
sentences (`lib/reader_service.dart:394-415`) and speaks them in order, so "the comment is read right after
its sentence, one utterance per sentence" is a property of the list order rather than a new code path. The
page's highlight is already expressed in content offsets, so a comment's own span highlights itself.

**Alternatives considered**:
- *The comment as a nested field on the sentence's own `ParagraphSpeech`* (`ParagraphSpeech.comment`). The
  second shape that works, and it pairs the two explicitly. Rejected: it makes the read's order a rule the
  reader service has to implement (append the comment's utterances after the *last* sentence of the speech
  that carries it), and it puts a second speech's language, voice and span inside a type whose contract is
  "one paragraph". The flat-list shape gets the order for free and keeps the type one-paragraph-per-entry.
- *A second reader path, or a filter in the reader service* ("skip comment utterances when the switch is
  off"). Rejected: three consumers would each have to know what a comment is, which is exactly the drift
  FR-009 exists to prevent; with the flag on the resolution, "the switch is off" and "there is no comment"
  are the same answer.
- *A comment as a paragraph of its own in the text handed to the segmenter* (i.e. resolve the comment by
  treating it as a paragraph). Rejected: a comment's content must be part of no sentence's span (FR-004), and
  a paragraph's text IS sentence spans — the split has to happen before segmentation, which is what D2's
  grammar and D3's span do.

### D2 — Each tag keeps its own implementation: `lib/comment.dart` writes the comment's rule, and 014's `roleTagAt` is not touched

**Decision** *(corrected 2026-10-08 at the plan gate — the reader's answer: 两个 tag 各留一份实现, each tag
keeps its own implementation; this entry first had one shared grammar)*: `lib/comment.dart` implements the
comment tag's rule **in full and on its own** — the delimiter pair `[` `]`, the spelling table, the name that
never spans a line, the optional separator of spaces and one optional `:`/`：` — and `commentTagAt` reads it
anywhere in a paragraph, the first well-formed occurrence opening the comment. `lib/dialogue.dart`'s
`roleTagAt` (`:115-147`) keeps 014's rule byte for byte: the braced pair, the head only. The two rules never
call each other, which is the shape the spec's A6 already asked for (*"the two tags do not see each other"*),
taken one step further than the plan first did.

**Rationale (the reader's)**: a tag rule is a feature's own rule. 014's lives with the dialogue rules it was
written for; the comment's lives with the comments. What the shared grammar would have bought is one table of
characters in one place; what it would have cost is that a change to *either* rule passes through the other
feature's module — and the two rules are not the same rule: the role tag is read at a paragraph's head and
names a speaker, the comment tag is read wherever it sits and marks an extent.

**What is kept as the guard**: the shape is written twice, so the two copies can drift — and the guard is each
rule's own test table, which is already there: `test/comment_test.dart` (this feature's, quickstart rows 1-3)
and 014's `test/dialogue_test.dart` (its prefix rule's own table, green unmodified in this feature's
checkpoints). A divergence between the two shapes is therefore a red test in whichever feature changed its
mind, not a silent one.

**Alternatives considered**: *one shared grammar in a new module, with `roleTagAt` rebuilt on it* (this entry's
first form, rejected by the reader on 2026-10-08: it re-cuts a shipped module's implementation for a table the
comment's own rule can hold); *a regex per tag* (the grammar has an ordering rule — the name ends at the first
closing delimiter and never spans a line — that is clearer as code, and each rule's implementation is its own
table's receipt); *reading `[注]` at a paragraph's head only, as the role tag is read* (the reader's own
example writes the tag inline — `the spanish sentence followed by a comment` — and FR-002 runs the comment to
the paragraph's end from wherever the tag sits, so the head-only rule would make the feature's common shape
unusable).

### D11 — The spelling table: one row per language the app's locales are written in, and all four are live everywhere

**Decision** *(the reader's own amendment of 2026-10-08, at the plan gate)*: the tag has **four spellings** —
`[comment]` (English), `[注]` (Simplified Chinese), `[註]` (Traditional Chinese) and `[nota]` (Spanish) — a table
with one row per language the app's own locales are written in (`en`, `zh`, `zh_Hans`, `es`: the four ARBs' own
`@@locale` values), and the ASCII rows (`comment`, `nota`) are matched case-insensitively like the item's own
English spelling. **Every row is live in every content, whatever language the app is showing.**

**Rationale (the reader's)**: *"when user use their own language keyboard, it's not easy for them to type words in
different locale"* — the spelling exists so that the reader can write the marker with the keyboard their language
gave them. That reason decides the second half of the rule as well: gating the table on the app's current UI locale
would make the same content read differently under two UI languages, which a text's own marker cannot do. The two
words are the reader's own answers to numbered options of the same day: `[nota]` (four letters, no accent, the same
"note" sense 注 carries) and `[註]` (the traditional character form of 注, one character, the shape of the
Simplified row); `[comentario]`, `[註解]` and `[註釋]` were the options not taken.

**Alternatives considered**: *only the current UI locale's spelling counts* (a content's meaning would depend on
the app's own language — rejected in the Clarifications entry); *one spelling per reading language*, which are only
three (`en`, `zh-Hans`, `es`) while the app ships four locales (Traditional Chinese would have no row of its own,
and the Traditional keyboard is exactly the case the reader named); *the literal word per language*
(`[comentario]`, `[註釋]`) — 10 and 2 characters against 4 and 1, and the reader's own item already picked the short
"note" word for Chinese rather than the literal 评论; *an English-only marker* (the reader's own reason says no).

### D3 — Where the tag's characters stop being painted, and where the comment's content is read from

**Decision**: the tag has **two ends**, and they are different ends:

- **`tagEnd`** — the first character after the tag and its separator, on the tag's own line. Everything from
  the tag's opening delimiter to here is the tag's own characters: **never painted** (FR-005), which is the
  elision the display makes (D7). It is `[`…`]` plus the spaces/colon that follow it **on that line**.
- **`contentStart`** — where the comment's **content** begins. When the tag is alone on its line, this is
  `014`'s own rule for a tag-only first line (`lib/dialogue.dart:138-145`): the line break and the following
  indentation belong to the tag's prefix, so the content begins on the paragraph's next line **and that line
  break is painted** — the reader's own layout is what FR-012 says the page shows, and only the marker's
  characters are removed from it.

A comment's content runs from `contentStart` to the paragraph's last non-whitespace character
(`contentEnd`) — FR-002, the paragraph being the app's own unit (`lib/segmenter.dart:71-108`) — including
any line breaks inside it, and including any further tag text (any of the four spellings), which is the comment's own
characters (the spec's own edge case: there is nothing to nest). Both ends are offsets into the content, and
neither is ever a sentence's span (FR-004).

**Rationale**: 014's grammar already distinguishes what a prefix *swallows* (the separator, and the line
break after a tag-only line — that is what makes `contentStart` correct for the spoken text) from what the
page *paints* (014 paints everything, because a role prefix is the reader's own script). 015 hides the
marker, so the two questions separate for the first time: the spoken text must not begin with a line break
(the video's block would gain a blank line, and the reader service would cut an empty first utterance), while
the display must not move the reader's sentence up a line. Keeping the line break painted and out of the
spoken span satisfies FR-005 (*"the tag's own characters, and the separator that belongs to it"* are the
things never painted) and FR-012 (*"a comment's content is visible where the reader wrote it, with its own
line breaks"*) at once.

**Alternatives considered**: *eliding the line break too* (the reader's text would visibly shift up by one
line — a repair of the reader's layout, which 014's A9 and this spec's FR-015 both refuse); *starting the
spoken text at `tagEnd`* (the utterance would begin with a line break; the sentence cutter skips it, so the
words would be the same, but the video's block would paint a leading blank line).

### D4 — The owner: the last sentence of the text **before the tag**, and a comment with none is never spoken

**Decision**: a comment **belongs to the last sentence that ends before its tag** (FR-003), and in this app's
own terms that is computed without a whole-content sentence scan: the sentences a read is made of are the
sentence ranges of the **speakable text preceding the tag** — the paragraph(s) up to the tag, with the
comment's own characters cut out (FR-004) — so the owner is **the last sentence of the speech immediately
before the comment's own entry** in D1's list. Operationally, the resolver emits a comment's entry only when
a preceding sentence exists; when the tag is at the very head of the content there is none, and the comment
is **not read, not highlighted and in no frame** (FR-003's own answer, *"displayed, and never spoken"*) —
while the page still paints its content, because the page paints the text, not the speeches (D7).

**Rationale**: a definition by the app's own units is the only one the video and the read can agree on. The
alternative — running the segmenter over the raw content and asking which range ends before the tag — gives
the *wrong* answer for the reader's own common shape: `Hola [注] Hi.` is **one** segmenter sentence
(`lib/segmenter.dart:33-69` sees no delimiter before the tag), so no raw range ends before the tag at all,
and the comment would belong to nothing even though a sentence plainly precedes it. Cutting the comment out
first (FR-004) is what makes "the last sentence before the tag" well-defined, and it is the same cut the read
makes anyway.

**Alternatives considered**: *"the previous paragraph is the owner"* — false across the inline shape (the tag
is mid-paragraph) and unnecessary for the honest shape (a paragraph between the owner's and the comment's
would have to hold a sentence, which would then be the last one before the tag); *the first sentence of the
content* — contradicts FR-003's *"across paragraph boundaries"* and its edge case; *the nearest sentence by
offset* (the app's tap fallback, `lib/segmenter.dart:120-146`) — that rule exists for whitespace, and using it
here would silently attach a top-of-content comment to the sentence below it, which FR-003 explicitly forbids.

### D5 — The setting's home is 014's store, one new field, absence = **read**

**Decision**: `RoleSettings` (`lib/role_store.dart:48`) gains one field — `commentsRead` (default `true`) —
and the page's switch writes it through a new `RoleStore.setComments(contentKey, {required bool read})` into
the **same** entry, as `"comments": false`. Absence, or any value that is not the boolean `false`, reads as
**read** — the shipped default the reader's own answer of 2026-10-08 settled (a content with nothing stored
reads its comments, FR-006). A content whose settings say the comments are read stores nothing at all, which
is also what keeps 014's receipts exact: the entry's shape for a dialogue content that never touched this
setting is byte-identical to today's. The store's other four sites follow: `RoleSettings.withRemoval` and
`.withVoice` (`:87`, `:100`) carry the field, `isEmpty` (`:68`) counts `commentsRead == false` as a decision
so an entry carrying only the switch is not dropped, and the page's `_setDialogue`
(`lib/reading_view.dart:1360-1368`) — which builds a `RoleSettings` by hand — carries it too, or switching
the text type would silently re-enable the comments.

**Rationale**: FR-015 asks for exactly this home (*"one store keyed by the content's own id, read tolerantly,
leaving 008's index, its schema and its repair path untouched, the content's own text unmodified, and
removed when the content is deleted"*) and A5 names it. The delete path already exists and already clears the
entry (`clearFor` at `lib/role_store.dart:180`, called from `lib/content_list_screen.dart:115`), so FR-015's
removal is one call the feature does **not** have to add. Storing *off* and defaulting the absence to *read*
is what makes the default one line to reverse (the spec's own note: *"reversing it back is a one-line change
of the store's absence rule plus a row's expectation"*) and what makes the switch cost nothing for every
content the reader never touches.

**Alternatives considered**: *`"comments": "read"` written explicitly* (writes a decision nobody made, and
014's store drops entries that say nothing); *a store of its own* (`content_comments`: a second key, a second
tolerant read, a second delete path, for one boolean that belongs to the same content); *a field in 008's
`index.json`* (a versioned schema with a repair path, for a view preference — 014's own D6 rejected this for
its settings and the reason has not changed).

### D6 — The switch joins 014's sheet, and the sheet keeps its name

**Decision**: the switch is a `SwitchListTile` — the app's shipped switch shape
(`lib/reading_view.dart:1694-1700`) — placed in 014's dialog (`_openTextType`, `lib/reading_view.dart:1383-1482`)
under the type chips and **above** the role list, offered in **both** text types (the tag works in 标准 too,
FR-010). Its label is a new key, and the dialog's title stays `textTypeTitle` (`:1414`). The page holds the
answer in `_roles` like every other setting of this content, applies it on the tap
(`_setComments` → the store → `setState`), and nothing else moves: not the text, not the undo stack, not the
reading position, not the roles or their voices (FR-016), and a read already playing keeps the speeches it
started with (014's own rule for the type switch, `:1355-1359`).

**Rationale**: FR-014 names this surface — *"the sheet where the text type and the role list already live"* —
and the reader reaches one place per content. The title is the sheet's own name for what the reader changes
about how the text is read; renaming it is a user-visible string that 014's own tests and the app bar's
tooltip both carry (`textTypeButton` at `:616`, `textTypeTitle` at `:1414`), and the switch's own label says
what the switch does. Nothing about the tag is a *text type*, so the honest alternative is not "rename the
sheet" but "the sheet's name is its own decision" — and it is not this feature's.

**Alternatives considered**: *a rename to a settings-wide title* (four ARB edits, the generated Dart, and the
`textTypeButton` tooltip re-cut for a word the reader did not ask about — and if the sheet ever grows a third
setting, the rename happens again); *a second surface of its own* (a route or a dialog for one boolean, and
a back-stack state to keep the reading page alive across); *a control in the app bar* (a per-content setting
shown as a page-level action, and 014's D8 rejected the shape for its own switch); *in the editor* (the
setting is not the text and must not be saved into it).

### D7 — The page paints the text **minus the tags**, and owes the mapping back to the content's offsets

**Decision**: the page derives, from `_content` alone, the **display string** — the reader's text with every
comment tag's own characters and its separator removed (`[tagStart, tagEnd)`, D3) and nothing else — and a
mapping between the two index spaces. `_buildSpans` (`lib/reading_view.dart:2244-2255`) builds its three
spans from that string, so the marker's characters are painted nowhere while the comment's content, its line
breaks and the rest of the text appear exactly where the reader wrote them (TWO spans' boundaries, the
highlight's, are the display offsets of the highlight's content offsets). The two paths that speak content
offsets and the one that answers them are mapped:

- `_resolveAt` (`:991-1010`): the offset `RenderParagraph` reports is a **display** offset; it is mapped back
  to a content offset before the segmenter sees it, and then the **comment rule** answers first: a tap whose
  content offset lies inside a comment's span (its tag included — the seam the elision creates) resolves to
  the **comment's own content span** when the comments are read, and to the comment's **owner sentence**
  (D4) when they are not (FR-012, SC-009), so a read from there speaks that sentence and never a marker.
- `_measure` (`:1181-1203`): the `TextSelection` it builds from the spoken span is built from the **display**
  offsets of that span, or the follow-scroll would measure the wrong box.
- Everything else already holds content offsets and needs nothing: `_highlight` (`:192`), the anchor
  (`:1005`), the stored `ReadingPosition` (`:1027-1031`), `_activeLanguage` (`:2284-2295`), and the edit mode,
  which shows `_content` itself (`:2380-2391`) — the editor is where the reader writes the tag, so it must
  keep showing it.

The display and the mapping are derived from `_content`, recomputed when it changes and never stored
(the same rule every other derived value in this tree follows), and for a text with no tag the display string
**is** `_content` — the mapping is the identity, which is what makes SC-004 true by construction rather than
by a careful edit.

**Rationale**: this is the shape the spec's own A4 names (*"the page hides the tag by eliding its
characters, not by rewriting the text"*) and the checklist's risk 1 asks the plan to pay for. Eliding inside
the span tree is the cheapest shape that is honest: the content the app stores, edits, saves and reads never
changes, and the page's offsets keep being the content's own, with one small map at the two seams where a
*display* offset is created or consumed.

**Alternatives considered**:
- *Rewriting the string the page paints* (store a tagless copy of the text and re-derive every offset from
  it). Rejected: every offset the app holds — the highlight, the anchor, the stored position, the spoken
  spans — would have to be translated, and the copy is a second version of the reader's text that can go
  stale against an edit.
- *Painting the tag's characters in the page's own background colour* (no mapping at all, since the string
  is unchanged). Rejected on four counts: FR-005 says they are never painted, not that they are painted
  invisibly; a glyph advance is not zero, so the reader's line would keep the marker's width as a gap; a
  text selection would copy characters the reader cannot see; and the appearance seam (011 FR-009,
  `_contentTextStyle` at `:2267-2280`) is the one place the reading text's style is built, so a per-tag
  style would be a second one.
- *A zero-width / transparent `TextStyle` on a span*: the same shape as the elision in effect, but it
  reaches the same shorter concatenation — the offsets still shift — while adding a style rule and keeping
  the characters in the string the `RichText` lays out. Eliding them from the string is the smaller claim.

### D8 — The video: the comment rides its sentence's slot — its content in the block, its audio in the slot's own

**Decision**: one slot per sentence stays the rule (012's own arithmetic), and a comment changes **what the
slot carries**, not how many slots there are:

- **The block**: the slot's `text` (what `lib/video_painter.dart:603` lays out and paints) is the sentence's
  own text followed, on its own line, by each comment that rides it — so a frame that paints the sentence
  paints its comment's content with it, and no frame ever paints a marker (FR-013, because a tag's
  characters are not in any slot's text at all). The block is simply taller where a comment is long (A7);
  012's scroll, its plate/tone rules and its `span=` field are untouched, and `span=` keeps naming the
  **sentence**, which is what 012's row 32 reads to decide which sentence is on a frame.
- **The audio**: the slot's audio is the read's own utterances for that slot, in order — the sentence's WAV,
  then the comment's WAVs (one per comment sentence, each synthesized with the comment's own language and
  voice through the same `_applyVoice` step every read uses) — laid end to end inside the slot's own frames.
  The platform half already takes exactly this: a flat list of `{path, durationUs}`, each padded or cut to its
  own `durationUs`, with the highest sample rate winning and only a differing channel count refused
  (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:461-496`).
- **The setting**: with the comments not read, the comment's utterances do not exist, so the slot's audio is
  the sentence's alone while its **block still paints the comment's content** — FR-013's scenario 2, and the
  reason the block's text is derived from the content's own comments rather than from the read's speeches.

**The case A7 did not consider** (see the corrections above): a render whose range begins *after* the
comment's owner. The comment rides the **last sentence before it in the file's own sentence list**; when
there is no sentence before it at all (a range beginning at the comment itself) it is read as a slot of its
own — its own words alone in the frame — rather than dropped, because the read from that same position speaks
it and the file may not say less than the read (FR-009, SC-008).

**Rationale**: FR-013 and SC-007 ask for the comment to be *painted with its sentence*, and A7 asks for
012's arithmetic to survive. Both are satisfied by keeping the slot the sentence's own and making the slot
carry more. The alternative — a slot per comment sentence — satisfies neither: the sentence's frames would
paint the sentence alone, and the file would gain slots.

**Alternatives considered**:
- *A slot of its own for each comment* (the comment read as its own timeline entry). Rejected: it is exactly
  what *"the comment content will be in the video with the sentence"* asks against, and it changes the slot
  arithmetic A7 protects.
- *Concatenating the sentence's and the comment's WAVs into one file in Dart* (one segment per slot, as
  today). Rejected: WAV concatenation in Dart is new code for a thing the platform half already does
  (`encodeAudio` reads each segment and pads/cuts it to its own slot), and the two files may carry different
  sample rates — which the platform already resolves and a hand-rolled concatenation would have to.
- *Filtering the tag out of the block text in the painter* (a string pass inside `lib/video_painter.dart`).
  Rejected for the reason 014's D9 gave for its own tag: the text a frame paints is what the plan put in the
  slot, and a filter in the painter is a second place that decides what the reader sees.
- *Skipping the comment entirely when its owner is outside the render's range*. Rejected: the file would go
  silent where the read speaks (FR-009), and the spec's own SC-008 measures exactly that agreement.

### D9 — The evidence: one new field on the read's line, none on the render's

**Decision**: the read's per-utterance line (`lib/reader_service.dart:522-527`) gains ` comment=1` **at the
end of the line, after the quoted utterance**, and only for an utterance that comes from a comment's speech
(a new `comment` flag carried from `ParagraphSpeech.isComment` through `_Utterance`). The renderer's own
lines are **not touched**: `klhu render slot=… span=a..b text=<painted length>` already carries what 015's
video rows need — `text=` is the painted block's own length, so a row can check it equals the sentence's
characters plus the comment's plus the line break between them — and `klhu render pictures=… sentences=N`
already carries the number of utterances the render synthesized, which is what tells the read's own unit
count from the render's.

**Rationale**: a voice, a role and the read's order are invisible to a UI dump (012's D9, 014's D10), and the
comment's own utterance is a thing a row must be able to *see* rather than infer from the text it happens to
hold. The position is chosen for one mechanical reason: 014's driver parses the speak line with a regex that
**requires the quoted text last** (`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py:161-166`), so a
field inserted before the text would make that driver read *zero* speak lines on a comment-bearing content.
Appending it after the quoted text keeps that regex matching and capturing the utterance correctly, and the
field's absence still means "not a comment" (the same additive shape 014's own `role=` field has). 012's
driver's render regex ends in `text=(\d+)`
(`specs/012-reading-video/scripts/klhu_walk_video.py:486-492`), which is the other reason no field is added
there.

**Alternatives considered**: *a second evidence line for comments* (a second regex per row, and the
utterance's own position in the read's order is lost); *marking the comment in the utterance's text* (the
device rows would have to parse text; and the text is the reader's own words, which the app must not
annotate); *re-cutting 014's regex to accept the new field anywhere* (a shipped sibling's driver changed for
a field nobody's row there reads).

### D10 — Verification is the tree's own shape: unit files first, then one device walk, then the receipts

**Decision**: four new test files written RED before their code (`test/comment_test.dart`,
`test/speech_resolver_comment_test.dart`, `test/reading_view_comment_test.dart`, `test/video_comment_test.dart`)
plus one new group in 014's own store test (`test/role_store_test.dart` — the store is the same class); a
device walk under `specs/015-comment-tag/scripts/klhu_walk_comment.py`, built on 014's and 012's helpers (one
string per `adb shell` command, row dispatch, `RESULT: PASS|FAIL`), with a fixture text that is the reader's
own example plus the shapes this feature's edge cases need; and the three structural rows that re-run the
receipts this feature can disturb (011's read, 012's video, 014's dialogue rows).

**Rationale**: it is the shape every spec in this tree used, and this feature's risk is precisely the shipped
behaviour it must not change (SC-004's *"a content with no tag at all reads exactly as the shipped app reads
it"*, and 014's device rows).

**Alternatives considered**: *unit tests only* (a voice and two WAVs muxed into one file cannot be seen
there); *a walk without the invariance rows* (the one failure mode this feature can cause and a unit test
cannot catch: a shipped read that changed for a text with no tag).

## Spikes

### S1 — does the engine write a comment's sentence and its owner's sentence in one muxable pair? — [device]

**Question**: SC-007/SC-008 put two different voices' audio inside one slot for the first time — a Spanish
sentence at one voice's rate and an English comment at another's — and the platform half takes one rate for
the whole stream (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:480`) and refuses two channel counts (`:474-479`). 014's row 29
proved the *rate* case (one voice's `-local` and `-network` copies); it did not prove two **languages** in one
render, which is what this feature's own example is.

**Method**: the device row that renders the fixture (`klhu_walk_comment.py`, the video row) renders a
two-language content with a comment and reports, beside its own checks, the file's measured rate and
duration and the render's own `sentences=` count; then `python3 specs/012-reading-video/scripts/klhu_probe_hiss.py`
on the pulled file, whose ceiling 014 already calibrated (its Spanish/English sentences sat at −45…−54 dB
above 10 kHz, the converted one at −49 dB with the fixed resampler).

**Why it cannot be assumed**: if the engine writes a comment's file in a different channel layout than the
sentence's, the render fails with the platform's own refusal and the feature's video half has no working
shape — the plan would have to fall back to one voice per slot, which contradicts FR-008. The row records
which it was; a failure here is a finding, not a test to hide.

**Measured (2026-10-09, `klhu_walk_comment.py 23`, AVD `emulator-5554`)**: the answer is **yes** — the two
languages mux into one file. With the comments read the renderer's own line reads `sentences=2` (the Spanish
sentence and the English comment: the read's own utterance count) and with them off `sentences=1`; both files
carry **one audio stream at 24000 Hz, 1 channel**, so the plugin's own refusal (`the sentences were written in
different audio layouts; they cannot be muxed`) was never reached. The read file is 100 frames / 3333 ms /
132635 B and the comments-off one 75 frames / 2500 ms / 96187 B: the comment's own audio is **833 ms /
25 frames**, and the two files' container durations differ by exactly that — 3.46125 s against 2.627958 s,
each running ~128 ms past the muxer's own accounting (a fixed tail, the same in both). The >10 kHz probe on the
two-language file exits 0 with its first 2 s at **−66.0 dB**, far under the −35 dB ceiling: muxing the two
languages' files introduces no interpolation hiss.

### S2 — how many lines does a comment's block add to a frame? — [device]

**Question**: SC-007 says every sampled frame of a sentence's slot paints that sentence **and** its comment.
The pixels can only answer `where the ink is`, so the row needs the number of lines a frame should carry,
which depends on the frame's column width and the reader's chosen size (012's own mapping,
`lib/video_painter.dart:311-332`).

**Method**: the video row renders the fixture twice — once with the comments read, once with them off — and
for the sentence's slot in each file reports the ink box the driver's own `scan_frame` measures
(`specs/012-reading-video/scripts/klhu_walk_video.py:801-830`), the render's own `text=` length for the slot,
and the two files' total frame counts. Expected: the same ink box in both files for that slot (the block does
not depend on the setting), strictly taller than the same sentence rendered with no comment, and `text=`
equal to `len(sentence) + 1 + len(comment)` in both.

**Why it cannot be assumed**: the block's own line count is a layout fact of the reader's chosen size, and
the frame's pixels are the only witness FR-013 has on a device. Stating the expected box here is what turns
"should look right" into a number the row can check. Not a spike in the *unproven* sense — the shape is
known (012's rows 32/49 already measure an ink box) — but its **numbers** are this feature's own, so the row
reports them rather than asserting from memory.

**Measured (2026-10-09, `klhu_walk_comment.py 22`, AVD `emulator-5554`)**: at 16:9 landscape 1080p the slot's
block is `Hola.` + one line break + `How are you?` — `text=18` — and its ink box at 1920x1080 is
**`(208, 864, 456, 964)`: 100 px tall in both files**, identical to the pixel. The same sentence with no
comment at all is `text=5` and `(208, 924, 298, 954)`: **30 px**. So the comment's line adds **70 px** of
block height at this size, and the singleton's line sits exactly where the block's *second* line sits
(y 924..954 inside 864..964) — the block grows **upward**. Frames: 100 with the comments read, 75 with them
off, 75 for the tagless twin; all 250 frames across the three files are free of the withdrawn band and of
anything outside the column.

## Open questions

- **Which of the two ends a tap at the elided seam answers** is decided by D3/D7 (the elided characters are
  painted nowhere, so the seam answers the first character after them — inside the comment; T007's own case), and the device row that taps inside a comment (quickstart row 19) is what confirms it on a
  real gesture; if the seam ever surprises the row, the fix is the mapping's rounding, not this rule.
- **Whether a future spec wants a fifth spelling or a second delimiter pair** (a full-width `［注］`, a `[note]`,
  another language's word) is deliberately open: the amendment closed the set at one row per language the app's
  locales are written in, A1 declines the full-width twin, and the comment tag's own spelling table makes either
  one row away.
