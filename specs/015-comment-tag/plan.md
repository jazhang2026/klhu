# Implementation Plan: Comment Tag

**Branch**: `015-comment-tag` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-comment-tag/spec.md`

**Grounding corrections**: four statements were checked against this checkout before the plan was written —
one count has drifted, one spec assumption (A7) does not survive a case the spec never considered, and the
rest hold. All four are in [research.md](./research.md) → **Grounding corrections**, with the evidence, and
the plan implements the corrected form:
1. A1's corpus count re-measured (628 files, 121,596 non-blank `*.md`/`*.txt` lines today; 3 occurrences of
   the shape, all in `text.txt`) — **the conclusion holds: no shipped content, asset, document or test uses
   the tag**.
2. **A7** (*"012's slot arithmetic unchanged"*) does not cover a render whose range begins **after** the
   comment's owner; the comment then rides the last sentence in the file before it, and with none it is a
   slot of its own (D8's own paragraph).
3. The checklist's ARB count is one short: **107 message keys in each of the four ARBs**, 117 keys in the
   template (10 of them `@`-metadata).
4. A2/A3/A4/A5's citations all resolve to the rules they name.

## Summary

A content's text may mark a **comment** — `[comment]`, `[注]`, `[註]` or `[nota]`, one spelling per language the
app's own locales are written in and all of them live in every content (the reader's amendment of 2026-10-08) — and
the reader's own example is the shape it exists for: a Spanish sentence followed by its English translation. The marker is **furniture**: it is
never spoken and never painted, on the page or in a frame. The comment's **content** is everything from the
marker to the end of its paragraph, and it belongs to the last sentence that ended before it. By default the
content **reads** its comments — the sentence in the Spanish voice, the translation in the English one, one
utterance per sentence, exactly as the words were written — and the page's own sheet carries one switch per
content that turns that off while leaving the words on the page where they are. The video renders the content
as it always has, one slot per sentence, with the comment's content painted in the sentence's own block and
its audio laid inside that slot, in the comment's own voice.

The technical approach is small and additive: **one new pure module** (`lib/comment.dart` — the marker
own grammar (a row per spelling), the comments of a text, and the display the page paints),
**one new entry in the list the app already speaks** (a comment resolves as a second `ParagraphSpeech`
beside its sentence's, which is what makes the read's order a property of the list rather than a new code
path), **one field in 014's own store** (the reader's choice, absent = read), **one switch** in the sheet 014
already opens, **the page's span tree mapped through the tagless display**, and **the video's slot carrying
one more block and one more WAV**. No new dependency, no platform code, no network — pure Dart over the text
the app already has.

## Technical Context

**Language/Version**: Dart `^3.13.3`, Flutter 3.47.5 stable (`pubspec.yaml:22`; `flutter --version` on this
host, 2026-10-08). No platform half: the Kotlin the video needs already exists and already takes what this
feature sends it (a flat list of audio files, research D8).

**Primary Dependencies**: none added. `flutter_tts ^4.2.3` (the engine, the per-utterance voice),
`shared_preferences ^2.5.5` (014's store), `intl ^0.20.3` + `flutter_localizations` (the four locales).
FR-018's assertion is *"no line changes in the dependency block"* (`pubspec.yaml:39-56`).

**Storage**: no new key. One new field inside 014's entry in `content_roles`
(`lib/role_store.dart:117`) — `"comments": false` — written only when the reader turns the switch off, read
tolerantly with everything else in that entry, and removed with the content by the path that already exists
(`clearFor`, called from `lib/content_list_screen.dart:115`). 008's `index.json`, its schema and its repair
path are untouched (FR-015).

**Testing**: `flutter test --concurrency=2` and `flutter analyze` on this host. New files follow the tree's
own placement: `test/comment_test.dart` (the grammar, the comment spans, the owner, the display and its two
mappings — the edge cases included), `test/speech_resolver_comment_test.dart` (the read: the comment's place,
its own language and voice, the switch off, and 标准's invariance for a text with no tag),
`test/reading_view_comment_test.dart` (the page: the marker not painted, the tap's answer in both settings,
the highlight, the switch in the sheet, the setting surviving a reopen), `test/video_comment_test.dart` (the
slot's block and its audio parts, the setting's two faces, no tag in any slot's text), and one new group in
`test/role_store_test.dart` (the store is the same class 014 already tests). The device rows live in
[quickstart.md](./quickstart.md) and are walked by hand on `emulator-5554`.

**Target Platform**: Android is where the rows are walked (the `klhu` AVD, API 36; the reader's own phone for
the ones they run themselves). The feature itself is platform-neutral Dart — and the one platform-facing half
it touches is already proven (the encoder's own audio path, research D8).

**Project Type**: mobile app — one Flutter project (`lib/` + `test/`), no new directory, no new package.

**Performance Goals**: the tag scan is one pass over the text per read and the comments are derived, never
stored; the display is one pass and a mapping, built from the same text. On 008's largest allowed content
(100,000 characters, `lib/models/content.dart:21`) the scan stays linear, the mappings are index arithmetic,
and the store is written only when the reader changes the setting — never on a read, never per comment.

**Constraints**: on-device only, no account/backend/network (constitution IV, FR-018); the reader's text is
never rewritten by this feature (its only write is 014's own store, and FR-015 says the text is untouched);
a content with no tag must read, paint and render exactly as today (SC-004), which is what the device rows
that re-run 011's, 012's and 014's receipts are for; the switch may not move the reading position, the roles
or the highlight (FR-016).

**Scale/Scope**: one new pure module (~180-220 lines: the marker's own grammar, `commentsOf`, the display and
its mapping), one optional parameter and one additive field on the resolution path, one optional field on
`ParagraphSpeech` and `_Utterance` (the evidence line), one field plus one method in 014's store, one switch
and three mapped seams in the reading page, one grouping step in the video's timeline plus the renderer's
per-utterance audio segments, **2 new ARB keys × 4 locales**, four new test files (~600 lines together), one
new group in 014's store test, and one device driver with its fixture. No new screen, no new state in the
page's state machine, no dependency.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 (below).*

- **I. Flutter single codebase** — PASS. Pure Dart: the feature is the reader's own text, the device's own
  voices and the app's own painter. The video's platform half is not changed — it is *used*, and the shape it
  already accepts (a flat audio list, each file padded or cut to its own length, research D8) is the shape
  this feature sends.
- **II. Spec-driven (NON-NEGOTIABLE)** — PASS. `specs/015-comment-tag/spec.md` is approved by the reader's
  three answers of 2026-10-08 (Clarifications); this plan and `tasks.md` follow it, and no requirement is
  minted here. The one correction to an assumption (A7) is recorded in `research.md` rather than edited into
  the reviewed spec.
- **III. Test-first (NON-NEGOTIABLE)** — PASS by construction: the four new test files are written RED before
  their code, and every story keeps an independent acceptance test — US1's the display and the tap (unit +
  device row 17), US2's the read's own utterance list (rows 1-2), US3's the setting across a restart (row 5),
  US4's a turn's own content beside a 标准 text (rows 9-10), US5's a rendered file's frames and audio (rows
  13-16).
- **IV. On-device first** — PASS. No network, no account, no analytics, nothing uploaded: the comments are the
  reader's own text and the voices are installed on the phone.
- **V. Simplicity (YAGNI)** — PASS, and this is where the plan's judgment calls live. The feature could have
  been a second reader path, a comment type of its own, a second store, a screen, or a filter in the painter;
  it is a **second entry in the list the app already speaks** (D1), **the grammar 014 already has** (D2),
  **a field in the store 014 already owns** (D5), **a switch in the sheet 014 already opens** (D6), and **one
  more block and WAV inside a slot that already exists** (D8). The complexity table below is empty on purpose.

**Post-design re-check (after Phase 1)**: the design settled on one resolution with the comment as an
optional second speech (D1), the owner computed in the app's own sentence units (D4), the setting stored as
the absence of a decision (D5), the page's display derived from the text with one map at two seams (D7), and
the video's slot carrying more rather than multiplying (D8). No principle is bent; the one place a second
code path was tempting — the switch — is a parameter of the resolution instead (D1's alternatives), which is
what keeps FR-009 true. The re-check therefore finds the same answers as the gate.

## Decisions the reader can see

Three of this plan's choices change what the reader watches, and they are stated here rather than left in
`research.md`, because the reader's own description of the result is their acceptance test:

1. **A frame carries the sentence and its comment as one block.** That is the reader's own words (*"the
   comment content will be in the video with the sentence"*), read as: the comment's content is painted in
   the same slot, on its own line under the sentence. The consequence to accept: a long comment makes the
   block taller, so a sentence that fitted still now scrolls, and 012's own scroll begins earlier for that
   slot. The alternative — a slot of its own for the comment — is what the reader asked against.
2. **The switch lives in the sheet 014 already opens, and that sheet keeps the name *Text type*.** The
   alternative (renaming it, e.g. to a settings-wide title) is four locale edits and the app bar's tooltip,
   for a word the reader did not ask about; the switch's own label says what the switch does.
3. **A render that begins *after* the sentence a comment belongs to shows that comment with the file's own
   opening sentence** (or, when the file starts at the comment itself, as a block of its own). The sentence a
   comment translates is not in that file at all — the render starts where the reader's stored position is —
   and the alternative is a file that goes silent where the read speaks (FR-009). This is the one case the
   spec's A7 did not consider, and it is named in the grounding corrections.

The two decisions that fix what the reader *hears and sees* most directly — the shipped default is **read**
(reversing the item's own example) and the marker is **invisible** while the comment's words stay where they
were written — are the reader's own answers of 2026-10-08 (`spec.md` → Clarifications), and the plan changes
neither. A third came with them at the plan gate: the tag's **four spellings** (`[comment]`, `[注]`, `[註]`,
`[nota]`), one per language the app's locales are written in and all of them live in every content, so the reader
types the one their own keyboard makes easy (research D11).

## Project Structure

### Documentation (this feature)

```text
specs/015-comment-tag/
├── spec.md                        # reviewed (specify + clarify), 2026-10-08
├── plan.md                        # this file
├── research.md                    # measured facts, grounding corrections, decisions D1–D10, spikes S1/S2
├── data-model.md                  # the tag, the comment, the display, the setting, the invariants
├── quickstart.md                  # validation scenarios, tagged [unit]/[device]/[structural]
├── checklists/
│   └── requirements.md            # the spec-quality gate (all items ticked)
├── scripts/                       # created at the implement stage
│   ├── klhu_walk_comment.py       # the device rows, one function per scenario, argv dispatch
│   └── klhu_comment_fixture.txt   # the reader's own example + this feature's edge shapes, pushed for the rows
└── tasks.md                       # created by the tasks stage
```

No `contracts/` for this feature: the interfaces it changes are in-process Dart types the app already
owns (`ParagraphSpeech`, `VideoSentence`, `VideoSlot`, `RoleSettings`), and the one external contract it
touches — the encoder's audio list — is unchanged (research D8). Inventing a directory here would be
ceremony; 012 needed one because it invented a channel protocol with Kotlin, and 014 skipped it for the same
reason this one does.

### Source Code (repository root)

```text
lib/
├── comment.dart                 # NEW — the marker's own grammar (a table of spellings), `commentsOf`, and
│                                #   the tagless display with its two mappings (pure)
├── dialogue.dart                # CHANGED at one function only — `turnsOf` gains an optional comment list, so
│                                #   a turn's own content stops at a comment's tag (`:160-195`). Its own tag
│                                #   rule (`roleTagAt`, `:115-147`) is NOT touched (D2)
├── speech_resolver.dart         # CHANGED — `commentsRead`, and a comment resolved as its own
│                                #   `ParagraphSpeech` placed after its owner's (`:39-81`)
├── reader_service.dart          # CHANGED — `ParagraphSpeech.isComment` + `_Utterance`'s flag (`:66-89`,
│                                #   `:213-243`), and the read's evidence line names a comment (`:522-527`).
│                                #   The sentence cut and the utterance loop are untouched.
├── role_store.dart              # CHANGED — `RoleSettings.commentsRead` (+ `with*`/`isEmpty`), the tolerant
│                                #   read of `"comments"`, `RoleStore.setComments` (`:48-109`, `:129-176`)
├── reading_view.dart            # CHANGED — the display in `_buildSpans` (`:2244-2255`), the tap's mapping
│                                #   and comment rule in `_resolveAt` (`:991-1010`), the display offsets in
│                                #   `_measure` (`:1181-1203`), the switch in 014's sheet (`:1383-1482`), and
│                                #   `_roles` carried through `_setDialogue` (`:1360-1368`)
├── video_timeline.dart          # CHANGED — `VideoSentence.isComment` (`:28-57`), a slot's block and its
│                                #   audio parts (`:131-178`), the grouping in `buildVideoPlan` (`:226-297`)
├── video_renderer.dart          # CHANGED — the muxer's segments walked per utterance inside each slot's
│                                #   frames (`:312-323`); pass 1 is untouched (`:226-259`)
└── l10n/app_{en,zh,zh_Hans,es}.arb  # CHANGED — the switch's own string, in all four (+ `gen-l10n`)

test/
├── comment_test.dart                 # NEW — the grammar, the spans, the owner, the display, the mappings
├── speech_resolver_comment_test.dart # NEW — the read: place, language, voice, the switch, 标准's invariance
├── reading_view_comment_test.dart    # NEW — the page: no painted marker, the tap, the highlight, the switch
├── video_comment_test.dart           # NEW — a slot's block and its audio, the setting's two faces
└── role_store_test.dart              # CHANGED — one new group for the comment setting (the store is 014's)
   (the shipped test files are NOT re-cut: the display of a text with no tag is the text itself, so every
    existing assertion on a tagged or untagged text reads exactly what it read before — plan ripple 1)

specs/015-comment-tag/
└── scripts/                      # the device rows' driver and its fixture (created at the implement stage)
```

### The tag rule, in one reference table (FR-001/FR-002 — the same table is in `lib/comment.dart`'s doc and in research D2/D3)

```text
tag            := '[' name ']'  — ASCII square brackets only
name           := 'comment' or 'nota' (ASCII, case-insensitive), or '注' or '註' — one row per language the
                  app's own locales are written in (en / zh_Hans / zh / es), every row live in every content
separator      := spaces, an optional single ':' or '：', spaces — part of the tag, on the tag's own line
where          := ANYWHERE in a paragraph (not only at its head, unlike 014's `{…}` tag); the FIRST
                  well-formed occurrence opens the comment; every later tag in that paragraph is content
tagEnd         := the first character after the separator — the tag's own characters stop here (never
                  painted, never spoken)
contentStart   := after tagEnd, except for a tag alone on its line: then the content begins on the
                  paragraph's next line (014's own prefix rule; the line break stays painted)
comment        := the paragraph's first tag + everything from contentStart to the paragraph's last
                  non-whitespace character, line breaks included
owner          := the last sentence of the speakable text before the tag; none at the content's head
```

Tags (a well-formed marker): `[comment] Hi.`, `[Comment] Hi.`, `[COMMENT]: Hi.`, `[注] Hi.`, `[注]: Hi.`,
`[注] ： Hi.`, `[nota] Hi.`, `[Nota]: Hi.`, `[註] Hi.`, and `Hola. [注] Hi. Adiós.` (one comment, `Hi. Adiós.`).
Not tags (ordinary text, displayed and read as written): `［注］` (full-width brackets), `[comentario]`,
`[註解]`, `[註釋]`, `[comments]`, `[note]`, `[注释]`, `[注` (no closing delimiter), `[]`, `[注]`-only text with
an empty content's marker — which is a tag with no content, so its characters are still not painted.
A role tag and a comment tag in one paragraph: `{阿明} 你好。[注] Hello.` is 阿明's turn whose own utterance is
`你好。`, with `Hello.` read after it in English (US4).

`lib/comment.dart` is this table's only implementation and `test/comment_test.dart` its only other reader;
quickstart rows 1-4 are the table's own receipt.

**Structure Decision**: the layout the fourteen earlier specs already use. Nothing new is invented at the top
level: a pure module beside `dialogue.dart`/`language.dart`/`segmenter.dart` (the three it is shaped after),
one optional parameter on the one resolution the page, the service and the video share, one field in the store
014 owns, and changes confined to the reading page, the video's timeline and its renderer. The one structural
claim a reviewer should check is the *second* implementation of a tag rule in this tree — `lib/comment.dart`
writes its own and `lib/dialogue.dart`'s is not touched (D2, the reader's answer at the plan gate:
两个 tag 各留一份实现). The price is that the shape is written twice; the guard is that each rule has its own
test table (`test/comment_test.dart` and 014's `test/dialogue_test.dart`), so a divergence is a red test rather
than a silent one.

### Ripple notes

1. **The page's own tests are not re-cut, and that is a property of the design rather than a hope.** The
   display a text with no tag paints **is** the text (`display == _content`, data-model I1), so
   `_buildSpans` returns the same three spans it returns today for every content that exists today. The greps
   that decide it, run on this tree: the tests that read the page's painted text do it through
   `find.textContaining(…, findRichText: true)` on texts with no tag
   (`test/reading_view_test.dart:106`, `test/reading_view_edit_test.dart:103`, `:379`,
   `test/reading_view_pause_test.dart:348`, `test/reading_view_dialogue_test.dart:253` — a 014 fixture, whose
   `{…}` tags 015 does not elide), and **no shipped test contains a `[注]`/`[comment]` literal at all**
   (`grep -rn '\[注\]\|\[comment\]' test/*.dart` → nothing), so no assertion in the tree can observe the
   elision. The tooltip/count assertions that do exist pin individual labels (`test/branding_test.dart:111-127`),
   not the page's set of actions, and this feature adds no entry. The new assertions live in
   `test/reading_view_comment_test.dart`. Re-check at implementation and report it if a shipped file moves for
   another reason.
2. **`lib/dialogue.dart` is touched by exactly one task, and its tag rule by none.** `roleTagAt` keeps 014's
   own implementation (D2: the reader's answer at the plan gate, 两个 tag 各留一份实现), so the module's only
   change is `turnsOf`'s optional comment list (ripple note 3). Its two call sites are inside the module
   (`:170`, `:239`) and no test calls it directly (`grep -rn roleTagAt lib test` → the module itself), so the
   rule's shape is frozen where it is; 014's `test/dialogue_test.dart` (the prefix rule's own table) is the
   guard that the file still behaves, and it must stay green, unmodified.
3. **`turnsOf` gains an optional parameter** (`comments`, default empty) so 014's own calls and tests keep
   today's behaviour exactly: `lib/reading_view.dart:1387`/`:1401` (the role list) and `lib/speech_resolver.dart:54`
   pass it; every shipped caller that does not gets today's turns. Two rules come with it: a paragraph that
   holds nothing but a comment is not a turn (FR-011), and a turn's content stops at a comment's tag (FR-011).
4. **`RoleSettings` is constructed field by field in five places** — `lib/role_store.dart:59-63` (the ctor),
   `:87-95` (`withRemoval`), `:100-108` (`withVoice`), `lib/reading_view.dart:1360-1368` (`_setDialogue`) and
   the new `setComments`' own read-back. A field added without all five is a setting that silently resets when
   the reader changes something else; the store's own test asserts each transition keeps the others.
5. **The l10n step is one atomic edit.** One new key (the switch's label, and nothing else) goes into all four
   ARBs in one pass, `flutter gen-l10n` regenerates the committed Dart, and `test/l10n_keys_test.dart` is the
   gate in both directions (a translation that keeps a dropped key fails too). Measured today: the template
   carries 107 message keys + 10 `@`-metadata entries; each translation 107 messages.
6. **The read's evidence line gains one field, appended after the quoted utterance** (`comment=1`), because
   014's driver's regex requires the utterance last (`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py:161-166`): inserted before the
   text it would make that driver read *zero* speak lines. 012's render line is **not** touched — its driver's
   regex ends in `text=(\d+)` (`specs/012-reading-video/scripts/klhu_walk_video.py:486-492`), and the two fields this feature's video rows
   need (`text=`, `sentences=`) already exist.
7. **The renderer's audio loop becomes one segment per utterance inside its slot's frames**
   (`lib/video_renderer.dart:312-323`), which is what the platform half already takes: a flat list whose
   entries are each padded or cut to their own `durationUs`, with the highest sample rate of the lot for the
   whole stream and only a differing **channel count** refused
   (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:461-496`). The invariant to keep in one place: the segments' frames sum to the
   plan's total frames, exactly, and the picture changes only where a sentence changes — which stays true
   because a slot is still one sentence.
8. **011's, 012's and 014's receipts are re-run, not assumed**: this feature changes the read's resolution
   (a text with a tag can now produce more speeches), the page's painting and the video's plan, so their
   device rows that touch those three land in this plan's quickstart as structural rows (SC-004, SC-007,
   SC-008) and are re-run against the changed code.
9. **There is nothing to migrate.** A1's re-measurement is the receipt: the only occurrences of the shape in
   this checkout are the reader's wish-list lines and this feature's own files. A content that carries no tag
   reads, paints, stores and renders as it does today, by construction rather than by conversion.
10. **The comment's span is never a sentence's span** (FR-004), which has one mechanical consequence worth
    naming where it bites: the segmenter, run on the raw text, will happily produce a "sentence" that begins
    with a tag or spans one (`lib/segmenter.dart:33-69` sees no delimiter in `[注]`). Nothing in this feature
    uses those ranges for a comment — the resolver cuts at the tag (D4), the page's tap asks the comment rule
    first (D7) and the block's text is the comment's own span (D8) — so the raw ranges remain what they are
    for every text shape that has no tag in it.
11. **A tap inside a comment is answered before the segmenter's nearest-sentence fallback**
    (`lib/reading_view.dart:991-1010`): with the comments read it resolves to the comment's own span, without
    them to the comment's owner sentence, and only a tap outside every comment reaches the segmenter's rule
    unchanged (FR-012, SC-009). The mapping is what decides whether the answer is even reachable: a tap on the
    seam of an elision reports the first character **after** the tag's own characters (D3) — inside the
    comment's own span, so the answer is the comment (corrected 2026-10-08 by the implementation, T007: the
    elided characters are painted nowhere, so the position they occupied is the next character's).

## Complexity Tracking

> No Constitution Check violations: the table is empty on purpose.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |
