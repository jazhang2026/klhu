# Tasks: Comment Tag

**Feature**: `015-comment-tag` | **Date**: 2026-10-08
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (the translation is a comment and its marker is invisible, P1),
`US2` (the comment is read after its sentence, in its own language's voice, P1), `US3` (a content whose
comments I do not want to hear, P2), `US4` (a comment inside a role's turn, and in 标准, P2), `US5` (the
comment in the video, P3). Tasks with no story label are shared infrastructure, the walk, or the receipts.

## Status

**Phases 1-7 are done (T001-T021, 2026-10-09): the module, its tests, the page's own display and tap rule, the
read's own resolution, the switch that turns one content's comments off, the two tags sharing one text (a
turn excludes its comment, a comment-only paragraph is no turn, and the page's role list scans the same way),
and the video (a comment rides its sentence's slot — its block paints it in both switch states while only the
read's own utterances reach the audio). Phase 8 (the device walk) **began 2026-10-09 and is finished**: rows 17
(PASS 24/24), 18 (PASS 7/7, its expectation corrected by the run — `breakpoint.md` § Deviations 1), 19 (PASS
6/6), 20 (PASS 9/9), 21 (PASS 9/9), 22 (PASS 35/35), 23 (PASS 25/25) and 24-26 (the three receipts, all green —
011's eight rows and 42 unit tests, 012's 42/42 and 41/41 with 62 unit tests, 014's 10/10 and 19/19 with 74
unit tests, and 014's row 33 green on a re-run after a stale first read — § Deviations 4). Phase 9 is open and
nearly done: **T030 (rows 15/16 — no dependency, the four locales' keys) is done**, and T034 closes the list —
with T034 ticked, every task in this file is done.** The working tree
also carries the unrelated in-flight edits that were already there (014's 2026-10-08 portrait-frame amendment —
`lib/video_painter.dart`, `test/video_painter_test.dart` and its artifacts, uncommitted). The suite now reads
**630 passing, 0 failing** — re-taken **2026-10-09 by T034** on the finished tree (`flutter test
--concurrency=2` → `00:55 +630: All tests passed!`; `flutter analyze` → **No issues found!** in 1.2 s) and read
against T002's baseline of **559 passing on 2026-10-08** at HEAD `2639776` (measured: that 559 + 32 cases in `test/comment_test.dart` + 11 in
`test/reading_view_comment_test.dart` + 16 in `test/speech_resolver_comment_test.dart` + 4 in
`test/video_comment_test.dart` + 8 new cases in the comment group of 014's `test/role_store_test.dart`, which
now holds 20), with
`flutter analyze` clean, and **no shipped test file's own cases touched** (only new groups appended; git lists
no shipped test modified by this feature's passes — `test/video_painter_test.dart` was already dirty before
this work began, part of the unrelated 014 revision the tree carries). What the app does now, end to end in the
tests: the page paints the tagless display, a tap answers the comment, a read speaks it after its sentence in
the comment's own language and voice, the switch in the text-type sheet turns one content's comments off and
remembers it, a comment inside a role's turn is read in its own language's voice while the turn keeps its own
words and count, and a video's slot paints the sentence **with** its comment while its audio is the read's own.
What is not done: the device rows (which voice the engine was given for a comment, whether a tap inside a
comment answers, whether the setting survives a restart, whether two languages' audio really mux) and the
Phase 9 receipts.

The baseline this list is read against: **559 tests green** and `flutter analyze` clean — *No issues found!* —
measured 2026-10-08 with `flutter test --concurrency=2` and `flutter analyze` on this working tree. That is
also `quickstart.md`'s Prerequisites figure, and it is the count every tick below is read against. T002
records it before the first edit; T034 re-takes it on the finished tree.

**Format checker**: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/015-comment-tag`,
re-run **2026-10-09 by T034** after this file's last edit (the closing tick itself), quoted verbatim:

```
tasks.md: 34 tasks (34 done), 5 marked [P]
  (setup/foundational/polish): 18
  [US1]: 4
  [US2]: 3
  [US3]: 4
  [US4]: 2
  [US5]: 3

OK: format, sequencing and spec-id coverage check out
```

`task_id_audit.py specs/015-comment-tag` → `015-comment-tag: 34 tasks, 34 done, 5 [P]`, no duplicate, gap or
out-of-order id. (This file's first write had US3's rows out of order — T015 before T014 — which both scripts
caught; the two rows' ids were swapped with every citation moved in the same pass. This receipt is re-quoted by
every pass that moves the count: `0 done` before Phase 1/2 closed, `16 done` on 2026-10-08 after US1, `34 done`
here — T034's tick was the last edit it covers.) Re-run both after every structural edit, and
quote both: a later edit that breaks the id sequence, pushes a path off a task's first line, or drops an id
from the coverage table is what this receipt stops being true about.

**Suite**: the feature's own tests are the four new files plus one new group in 014's store test (T003,
T006, T008, T010, T013, T015, T017, T019); every checkpoint re-runs the shipped files the change could reach
(014's dialogue and resolver tests, 012's video tests, the reading page's own), and T034 records the count.

**Device rows**: rows **17-23**, walked by `specs/015-comment-tag/scripts/klhu_walk_comment.py` into
`specs/015-comment-tag/breakpoint.md`, plus rows **24-26** which re-run 011's, 012's and 014's own receipts on
a build of the changed code. None is walked yet.

## Grounding notes (decisions these tasks implement)

1. **A comment is a second `ParagraphSpeech` beside its sentence's own** (D1, FR-007/FR-009): `resolveSpeeches`
   (`lib/speech_resolver.dart:39`) returns it in the list it already returns, at its own text position — so the
   reader service's order is the list's order and no consumer grows a second path.
2. **Each tag keeps its own implementation** (D2, FR-001; corrected 2026-10-08 at the plan gate — the
   reader's answer: 两个 tag 各留一份实现): `lib/comment.dart` writes the comment tag's rule in full, and
   `lib/dialogue.dart`'s `roleTagAt` is **not touched**. Two rules, two modules, each with its own test table —
   and the only change in 014's module is T018's `turnsOf`. The rule this feature writes has **four spellings**
   (`[comment]`, `[注]`, `[註]`, `[nota]` — D11, the reader's amendment of the same day), all of them live in
   every content whatever the app is showing, and the ASCII two case-insensitive.
3. **The tag has two ends** (D3, FR-002/FR-005): `tagEnd` is where its own characters stop (never painted,
   never spoken); `contentStart` is where the spoken content begins — for a tag alone on its line, on the
   paragraph's next line (014's own prefix rule), with that line break still painted.
4. **The owner is computed in the app's own sentence units** (D4, FR-003): the comment is cut out of the text
   before the sentences are read (FR-004), so its owner is the last sentence of the text before its tag, and a
   tag at the content's head belongs to nothing — displayed, never spoken, in no frame.
5. **The setting lives in 014's own store, and its absence means *read*** (D5, FR-006/FR-015): one field
   (`"comments": false`) inside the `content_roles` entry, written only when the reader changes it, removed by
   the delete path that already exists.
6. **The switch joins 014's sheet, and the sheet keeps its name** (D6, FR-014): a `SwitchListTile` in
   `_openTextType`'s dialog, offered in both text types — the same shape the video review's own switch uses.
7. **The page paints the text minus the tags, and owes the mapping back** (D7, FR-005/FR-012): the display is
   derived from `_content`, `_buildSpans` builds its three spans from it, `_resolveAt` maps a display offset
   back and asks the comment rule first, and `_measure` maps the other way.
8. **The video's slot carries more rather than multiplying** (D8, FR-013): the slot's `text` is the sentence
   plus each comment riding it, its audio is the read's own utterances inside its frames, and the platform half
   already takes a flat file list — nothing there changes.
9. **The read's evidence line gains one field, after the quoted utterance** (D9): ` comment=1` for a comment's
   utterance only, so 014's driver's regex keeps reading and capturing every line, and no render line changes.
10. **Verification is the tree's own shape** (D10, constitution III): each story's `[unit]` file is written and
    run RED before that story's code, then one device walk covers the rows a unit test cannot hear (which voice
    the engine was given for a comment, whether a tap inside a comment answers, whether the setting survives a
    restart, whether two languages' audio really mux), then 011's, 012's and 014's receipts are re-run as
    structural rows. A compile error counts as RED — say so when it is one (the note `test/*.dart` files need
    the new `lib/comment.dart` to load, which is where most of this feature's REDs come from).
11. **No shipped test pins the page's painted text for a tagged content** (the grep plan ripple 1 records,
    re-run 2026-10-08): every assertion that reads the page's text does it with
    `find.textContaining(…, findRichText: true)` on a text with no tag (`test/reading_view_test.dart:106`,
    `test/reading_view_edit_test.dart:103`, `:379`, `test/reading_view_pause_test.dart:348`,
    `test/reading_view_dialogue_test.dart:253`), and **no `test/*.dart` file contains a `[注]`/`[comment]`
    literal** (`grep -rn '\[注\]\|\[comment\]' test/*.dart` → nothing) — so T008/T009 re-cut nothing, and
    their claim is the stronger one: the shipped files stay green **unmodified**. The tooltip assertions that do
    exist (`test/branding_test.dart:111-127`) name individual labels, not the page's action set, and this
    feature adds no app-bar entry.

12. **The plan-gate review's two answers are in the artifacts** (2026-10-08): each tag keeps its own
    implementation (D2 rewritten; T004/T005 re-cut so `roleTagAt` is not touched and T005 is only `turnsOf`'s
    optional parameter), and the tag has four spellings, one per language the app's locales are written in,
    all live in every content (D11; FR-001 and A1 rewritten in place in `spec.md`, since the spelling set *is*
    the tag's recognition rule — no new `FR-` id minted, and the checklist's own counts stay at 18 FRs / 11 SCs).
    The two words are the reader's: `[nota]` and `[註]`.

## Path conventions

- Source: `lib/`; widget/unit tests: `test/`; this feature's own files: `specs/015-comment-tag/`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2` (the emulator being up can
  make plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated files are
  part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; the walk driver
  lives at `specs/015-comment-tag/scripts/klhu_walk_comment.py` and the fixture it pushes beside it at
  `specs/015-comment-tag/scripts/klhu_comment_fixture.txt`
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/015-comment-tag`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the copy every state of this feature draws on. Nothing is installed — this feature adds no
dependency, no asset and no platform file (plan § Technical Context).

- [x] T001 Add this feature's message keys to the template `lib/l10n/app_en.arb` and the three translations
      `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`, `lib/l10n/app_es.arb`: the comment switch's label (a
      `String`, no placeholder) — and, if the sheet's own wording needs one, a one-line hint under the switch
      saying what it does to the reading. Then `flutter gen-l10n`, and confirm the diff is exactly the four
      ARBs plus the regenerated `lib/l10n/app_localizations*.dart`. The template carries 107 message keys today
      (plan ripple 5, re-measured), so this lands 108 — write the real count into the tick.
      `test/l10n_keys_test.dart` is bidirectional: a key in three ARBs fails exactly as loudly as a key in
      five (FR-014).
      **Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green.

      **DONE 2026-10-08** — one key, `commentsReadLabel` ("Read the comments" / 朗读注释 / 朗读注释 / Leer los
      comentarios), added to all four ARBs and to nothing else: 107 → **108 message keys each**. No hint line was
      needed — the switch's own label says what it does (the plan left that to the implementation). `flutter
      gen-l10n` regenerated `lib/l10n/app_localizations.dart` + `_en` + `_es` + `_zh` (the last covering both
      Chinese files, so the diff is four ARBs plus four generated files), `flutter test test/l10n_keys_test.dart`
      → **3 passing**, `flutter analyze` → No issues found.

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the baseline receipt and the pure module every story's layer sits on — the marker's grammar and
the comments of a text (T003/T004), plus the one change 014's own scan needs (T005) so a comment-only
paragraph is never a turn and a turn's own content stops at a comment's tag. Device-free by construction, which is why this is the only
genuinely shared work.

- [x] T002 Record the baseline over the whole `test/` tree before touching anything: `flutter analyze` (expect
      clean) and `flutter test --concurrency=2` (expect **559 passing, 0 failing** — this file's Status figure
      and `quickstart.md`'s Prerequisites), then write both numbers into the Status section of
      `specs/015-comment-tag/tasks.md` with the date and the command, and say which revision they were taken on
      (`git rev-parse --short HEAD`). If the count differs, that difference is the first thing the handback
      reports: a drifted baseline is the reason every later tick would be measured against the wrong number.

      **DONE 2026-10-08, before T001** (the baseline has to be taken before the first edit, so this task ran first
      even though the list numbers it second): `flutter analyze` → **No issues found!**, `flutter test
      --concurrency=2` → **559 passing, 0 failing** on `2639776`. The count matches this file's Status figure and
      `quickstart.md`'s Prerequisites exactly — no drift, which is the one thing this task exists to catch.
- [x] T003 [P] Write `test/comment_test.dart` from quickstart rows 1-4 and 8: the marker's grammar (every
      accepted spelling — `[comment]`, `[Comment]`, `[COMMENT]:`, `[注]`, `[注]:`, `[注] ： `, `[nota]`,
      `[Nota]:`, `[註]` — against every refused shape: full-width `［注］`, `[comentario]`, `[註解]`, `[註釋]`,
      `[comments]`, `[note]`, `[注释]`, `[注` with no closing delimiter, `[]`, the same characters inside a
      sentence), a comment's content (to the paragraph's last non-whitespace
      character, line breaks included, the tag and its separator outside it, `tagEnd` vs `contentStart` for a
      tag alone on its line), where the tag is read (mid-line, inside another comment's content, at a
      paragraph's head, in a paragraph with a role tag, a marker-only paragraph, an empty comment), the owner
      (the last sentence before the tag, across paragraph boundaries; none at the content's head; two comment
      paragraphs in a row), and that no comment's characters are part of a sentence's span. Run it and keep the
      RED output.
      **RED expected as a compile error**: the file imports `lib/comment.dart`, which T004 creates — say so
      when the RED is one.

      **DONE 2026-10-08** — `test/comment_test.dart`, **23 tests**, 6 groups (the marker's grammar, a comment's
      content, where the tag is read, the owner, no-sentence-claims, the turn scan T005 makes comment-aware). RED
      receipt: a **compile error**, not an assertion failure — `test/comment_test.dart:274:35: Error: No named
      parameter with the name 'comments'` beside the missing `lib/comment.dart`, which is what a RED for a new
      module is here. Four cases then failed on the first green run and each was corrected against the artifact
      that settles it, not against the code: `name` is the spelling **as written** (`[Nota]` → `Nota`; the
      data-model §1 says "the characters between the delimiters", and 014's own `RoleTag.name` is verbatim);
      `[note]`/`[註解]` are refused, so a paragraph led by one starts its comment at the *next* marker; the
      owner's span is the app's own sentence range of the text before the tag, role prefix included, which is the
      span the page's own sentence resolution answers for an offset there (SC-009); and the segmenter's tail
      range keeps its trailing space (`Hola [注] Hi.` → the owner is `Hola `, `lib/segmenter.dart:65-67`).
      Two cases were added while writing it, for a rule the artifacts state and the first draft of the file did
      not cover: a name that spans a line (`[com\nment]`, `[\n注]`) is not a marker.
- [x] T004 Write `lib/comment.dart`: the comment tag's **own** rule — an ASCII delimiter pair, a name of at
      least one character that never spans a line, an optional separator of spaces and one optional `:`/`：`,
      with the spelling table this feature owns — `[comment]`, `注`, `註`, `nota`, the ASCII two matched
      case-insensitively, every row live in every content (D2: 014's `roleTagAt` is not touched and the two rules
      never call each other; D11: one row per language the app's locales are written in) — `commentTagAt` reading
      it **anywhere** in a paragraph, and `commentsOf(text)` returning
      every comment with its tag offsets, its content span and its owner (D3, D4). Green against T003.

      **DONE 2026-10-08** — `lib/comment.dart` (**259 lines**, pure): the spelling table (`commentSpellings` = the
      four rows; `isCommentSpelling` folds case for the ASCII rows only), `commentTagAt` (the first well-formed
      marker anywhere in a paragraph; the two ends `tagEnd`/`contentStart`; the tag-only-first-line rule), and
      `commentsOf` (one comment per paragraph, its content span, its own `detectLanguage`, and its owner computed
      in the app's own sentence units over the text a read would speak). **23/23 green.**
      **One correction the implementation found, recorded in `data-model.md` §2 in the same pass**: the owner's
      span is the **raw** sentence range of the text before the tag (a role prefix included), not the turn's own
      prefix-less span — which is what makes SC-009 true (a tap inside a comment, with the comments off, answers
      exactly the sentence the page's own resolution would have answered) while the *read* keeps using 014's own
      turn span.
- [x] T005 Give `lib/dialogue.dart`'s `turnsOf` an optional comment list, so a paragraph that holds nothing but
      a comment is not a turn and a turn's own content stops at a comment's tag (FR-011; plan ripple 3).
      `roleTagAt` is **not touched** (D2), the parameter defaults to empty, and every shipped caller keeps
      today's turns.
      **Checkpoint**: `flutter test test/dialogue_test.dart test/speech_resolver_test.dart` green
      **unmodified** — 014's own rules are the guard that `turnsOf`'s optional parameter changed nothing
      observable.

      **DONE 2026-10-08** — `lib/dialogue.dart`: `turnsOf` gains the optional `comments` list (default empty), one
      private `_commentTagIn` seam, and one import; `roleTagAt` is untouched, as the reader's answer requires.
      014's own guards green **unmodified** — `flutter test test/dialogue_test.dart test/speech_resolver_test.dart
      test/reading_view_dialogue_test.dart` → **54 passing** — and the three new turn-scan cases green
      (a turn's content stops at the tag; a comment-only paragraph is no turn; a text with no comment is today's
      scan, field for field).

---

## Phase 3: User Story 1 — The translation is a comment, and its marker is invisible (P1) 🎯 MVP

**Goal**: the page shows both languages and no marker, while every offset the app holds stays a content
offset: a tap answers through the mapping and the comment rule, a highlight covers the comment's own span, and
a text with no tag paints exactly what it painted before. Editing is unchanged — the editor shows the tag,
because that is where the reader writes it.

**Independent Test**: open a content with one Spanish sentence and one `[注]` comment — the page paints both
languages and no marker, a tap inside the comment answers the comment (with the comments read) and the owner
sentence (with them off), and the highlight covers exactly what is read.

### Tests for US1 ⚠️ (write first, run RED)

- [x] T006 [US1] Write the display's own group into `test/comment_test.dart` from quickstart row 5: the display
      string of a content with a tag alone on its line, an inline tag and two comments (no tag character, no
      separator, nothing else moved, its length the content's minus the elided spans), both mappings
      round-tripping outside an elided span, an offset inside a tag answering the span's own start, and a text
      with no tag where the display **is** the content and both mappings are the identity (data-model §3, I1-I4).
      Run it and keep the RED output.

      **DONE 2026-10-08** — five cases added to `test/comment_test.dart` (the display group): the tag's characters
      are painted nowhere and nothing else moves; a tag alone on its line leaves the line break painted; every
      offset outside an elided span round-trips both ways; an offset inside a tag answers the character after it
      (see the correction below); and a text with no tag paints itself with both mappings the identity. RED
      receipt: **six compile errors** — `Method not found: 'displayOf'` — which is what a RED for a new function
      is here. Green after T007: `flutter test test/comment_test.dart` → **28 passing**.
- [x] T007 [US1] Implement the display in `lib/comment.dart`: the tagless string and `toContent`/`toDisplay` as
      index arithmetic over the comments' spans (D7, A4). Green against T006.

      **DONE 2026-10-08** — `CommentDisplay` + `displayOf` in `lib/comment.dart` (+85 lines): the tagless string
      as one pass over the comments, `toDisplay` as a prefix sum of the elided spans, `toContent` its inverse.
      **28/28 green.** One lint the first draft hit and how it was fixed: `prefer_initializing_formals` on the
      private `_tags` field (Dart forbids `this._x` in a named parameter, so the lint's own suggestion is
      impossible) — the field was **dropped** and the tags are read off `comments`, which is one source of truth
      instead of two, rather than made public for the lint's sake.
      **Correction recorded in the same pass** (`data-model.md` §3, `plan.md` ripple 11, `research.md`'s open
      question, `quickstart.md`'s troubleshooting): the seam of an elision answers the first character **after**
      the tag's own characters, not the tag's own start. The elided characters are painted nowhere, so the
      display position they occupied belongs to the character that follows them — which is inside the comment, so
      a tap at the seam still answers the comment (SC-009), which is the behaviour every artifact already
      promised. T006's own case asserts the corrected value.
- [x] T008 [P] [US1] Write the page's own group into `test/reading_view_comment_test.dart` from quickstart rows 5 and
      13's display/tap half: the `RichText`'s text contains no marker character for a content with a comment; a
      tap inside the comment answers the comment's own span with the comments read and the owner sentence with
      them off; the highlight covers the comment exactly while the comment's utterance is reported; and the
      reading position's own path (a stored offset, the anchor) still speaks content offsets. Run it and keep
      the RED output.

      **DONE 2026-10-08** — `test/reading_view_comment_test.dart`, **5 cases** in the harness 014's page test
      uses (a recording fake reader, the real page over a temp store, a clean mock `shared_preferences`), with a
      tap helper that measures the point from the `RenderParagraph`'s own boxes for a **display** offset — the
      same render object the page's tap path measures. RED receipt: a **behavioural** failure, not a compile
      error — four of the five cases failed with `Expected: 'Hola.\n\nHow are yo…' / Actual:
      'Hola.\n\n[注] How ar…'` (the page painted the tag), while the editor case passed, which is the split
      the story predicts. One fixture fix on the way (not a RED): `PresetContent` is not a const constructor.
      Green after T009: **5 passing**.

### Implementation for US1

- [x] T009 [US1] Wire the display into `lib/reading_view.dart`: `_buildSpans` builds its three spans from the tagless
      text with the highlight's boundaries mapped, `_resolveAt` maps the reported display offset back before
      the segmenter sees it and asks the comment rule first (the comment's own span when the comments are read,
      its owner sentence when they are not), and `_measure` builds its `TextSelection` from the display offsets
      of the spoken span (D7, FR-012; plan ripple 11). The display is derived from `_content` and recomputed
      when it changes; the editor keeps showing `_content` itself. Green against T008.

      **DONE 2026-10-08** — `lib/reading_view.dart` at three seams (plan ripple 11) plus the store's field:
      `_buildSpans` builds its three spans from `displayOf(_content)` with the highlight's boundaries mapped;
      `_resolveAt` maps the paragraph's own (display) offset back and asks `_segmentAt` first — a comment's own
      span when the comments are read, the owner sentence when they are not, and the segmenter's rule unchanged
      outside every comment; `_measure` builds its `TextSelection` from the display offsets of the spoken span.
      The display is memoized on `_content` (`identical`) so a read's per-sentence repaints cost one scan per
      content. **`RoleSettings.commentsRead`** (default `true`) was added here, with `_setDialogue` carrying it —
      the page's tap rule needs its answer on the very next tap, so T015/T016 are re-cut to own the setting's
      *life* (the tolerant read, `setComments`, the `with*`/`isEmpty` carry) rather than the field.
      **5/5 page cases green; the whole suite 592 passing, 0 failing; `flutter analyze` clean.**
      **The checkpoint's claim, measured rather than hoped**: every shipped page, dialogue and video test file is
      green **unmodified** — the greps T003's pass recorded (no test asserts a marker, every painted-text
      assertion is on a text with no tag) held, so US1 re-cut nothing.

**Checkpoint**: rows 1-5, 8, 13 (display/tap half) green; the shipped reading-page tests green **unmodified**
(the display of a text with no tag is the text, so nothing they assert can move — if one does, that is the
finding, and it is reported rather than edited away).

---

## Phase 4: User Story 2 — The comment is read after its sentence, in its own language's voice (P1)

**Goal**: the read. A comment is its own speech, placed after the speech whose last sentence it belongs to, in
the language its own content detects — so the Spanish sentence comes out in the Spanish voice and the English
comment in the English one, one utterance per sentence, and with the switch off none of the comment's
characters reaches the engine.

**Independent Test**: read a mixed content on the device and read the app's own per-utterance lines: the
sentence's utterance names the sentence's voice, the comment's own utterances carry `comment=1` and name the
voice the app has for the comment's own detected language, and no utterance's text contains a bracket of a tag.

### Tests for US2 ⚠️ (write first, run RED)

- [x] T010 [P] [US2] Write `test/speech_resolver_comment_test.dart` from quickstart rows 6-8 and 10: the comment is
      its own `ParagraphSpeech` placed after its owner's speech, with its own text, its own detected language
      and the language's own pick as its voice; two sentences of one comment cut into two utterances; with the
      comments off no speech carries the comment's characters and the sequence is the sentences' own; a content
      with no tag resolves field-for-field as `resolveParagraphSpeeches` does (a relationship between the two
      calls, not a frozen sample); and a 标准 read is today's read with the comment's speech added. Run it and
      keep the RED output.

      **DONE 2026-10-08** — `test/speech_resolver_comment_test.dart`, **11 cases in 5 groups** (the fifth is one
      dialogue-mode shape; US4's own cases are T017's). RED receipt: **compile errors** naming exactly what the
      pass had to add — `No named parameter with the name 'commentsRead'`, `The getter 'isComment' isn't defined
      for the type 'ParagraphSpeech'` (four sites), `Method not found: 'commentsOf'` — and once the code landed,
      **two of my own expectations were wrong and were fixed rather than the code**: (a) `sentenceRanges` ends a
      sentence at its own last character, so the fixture's comment cuts to `['How are you?', 'Fine.']`, not with
      the space ('the space after a sentence' is the cutter's own choice, shared with paragraphs — 014's rule,
      not 015's); (b) "no speech overlaps a comment" is false for a comment's OWN speech — rewritten as "no
      non-comment speech overlaps any comment" plus "a comment's own speech is exactly one comment's span".
      **11/11 green.**

### Implementation for US2

- [x] T011 [US2] Add the comments to `lib/speech_resolver.dart`: an optional `commentsRead` parameter (default
      `true`), the split of a paragraph's own text at its comment's tag so no sentence's span covers a comment
      (FR-004), the comment's own speech built from its content span with `detectLanguage` and the language's
      pick, placed at its text position (D1, D4), and the same for the turn path. Green against T010.

      **DONE 2026-10-08** — `lib/speech_resolver.dart`: an optional `commentsRead` (default `true`); the standard
      path is now this file's own `_paragraphSpeeches` — 014's per-paragraph resolution with the one split (a
      paragraph's speakable text stops at its tag, its whitespace trimmed, and `detectLanguage` runs on what is
      left, so a comment is no sentence's span and no sentence's language), byte-identical to
      `resolveParagraphSpeeches` for a text with no comment and asserted so against the real function; 014's turn
      path is extracted into `_turnSpeeches` unchanged (including its empty-turns early return, so an empty
      dialogue prints no roles line); and `_withComments` places each comment's own speech just before the first
      speech that starts at or after its tag — which is immediately after the piece of text its owner ends in,
      with no second ordering rule anywhere (research D4).
      **11/11 green; the shipped language, dialogue and reader-service tests green unmodified** — that is the
      checkpoint's own claim, and it is the reason `_paragraphSpeeches` exists here rather than a rewrite of
      `resolveParagraphSpeeches`.
      **Two artifact rows corrected in the same pass** (both were mine, both wrong as written):
      quickstart row 7's expected sequence said the switch-off read equals what the marker-stripped text would
      resolve to — it does not, and must not: that text would hand the comment's words to the engine as a
      paragraph of their own, which is the thing the switch forbids. Row 7 now says what the tests show (the
      comment's piece contributes no speech at all, and an inline tag's tail goes with it either way).
      Row 8's "the content is never rewritten" was written as a byte-identity assertion in this file; that is
      vacuous here — measured with a throwaway probe: this harness's catalog is in memory, so the temp tree is
      **empty** and there is no file to compare. The row now cites the guarantee where it actually lives (a
      pre-set's text is not writable: `lib/services/content_store.dart:355`; 015 adds no write path) and points
      at the page test's cross-check, instead of shipping an assertion that cannot fail.
- [x] T012 [US2] Carry the flag through `lib/reader_service.dart`: `ParagraphSpeech.isComment` (optional, default
      `false`, the precedent `role` set in 014), `_Utterance`'s own copy of it, and the read's evidence line
      gaining ` comment=1` **after** the quoted utterance, for a comment's utterance only (D9; plan ripple 6).
      Nothing else in the file changes — the sentence cut and the utterance loop already speak the list in
      order.

      **DONE 2026-10-08** — `lib/reader_service.dart`, four small edits and nothing else: `ParagraphSpeech`
      gains `isComment` (optional, default `false`, the precedent 014's `role` set); `_Utterance` gains its own
      copy; `_sentencesOf` carries it from the speech it cuts; and the read's evidence line gains
      ` comment=1` — **after** the quoted utterance, for a comment's utterance only. The position is not
      cosmetic: the device drivers' own pattern is `klhu speak p<i> s<j>( role=…)?( voice=…)? "…"`
      (`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py:161-164`), so a field placed between `s<j>` and
      the quotes would break every walk 010 and 014 wrote. Grep-verified, and the field is only emitted for a
      comment's utterance, so those walks read the line they always did.
      No unit test here by design — this row's own witness is the device row (17-23), where the flag is what says
      which utterance was the comment's; the sentence cut and the utterance loop needed no change because the
      resolver hands them one list in read order.

**Checkpoint**: rows 6-8, 10 green; the suite's shipped reader-service and language tests green unmodified
(FR-009's own point: the comment rides the one resolution, so nothing else learns it exists).

---

## Phase 5: User Story 3 — A content whose comments I do not want to hear (P2)

**Goal**: the switch. One setting per content, on the sheet the text type and the role list already live on,
defaulting to **read**, remembered across restarts, and touching nothing else: not the text, not the reading
position, not the roles or their voices, not the highlight in force.

**Independent Test**: turn one content's comments off, read it and read the app's own lines — none of the
comment's words appears among the utterances while the page still shows them — then reopen it after a restart
and the choice is still in force, while a second content's comments still read.

### Tests for US3 ⚠️ (write first, run RED)

- [x] T013 [P] [US3] Write the comment setting's own group into `test/role_store_test.dart` from quickstart row 12:
      nothing stored reads **true** (the shipped default, FR-006); the off state round-trips as
      `"comments": false` and an entry that says only that survives; each corruption of the entry (not JSON, a
      non-object, `comments` a string, `comments` the number `0`) is ignored for that content only, with no
      repair and the other contents untouched; two contents' settings are independent; and the delete removes
      the setting with the entry. Run it and keep the RED output.

      **DONE 2026-10-08** — **8 cases appended as a new group** ("the comment setting") in
      `test/role_store_test.dart`, 014's own groups untouched: the default; the off state round-tripping as
      `{"comments": false}` and surviving on its own (`isEmpty` false for it); turning them back on writing
      nothing; the corruption set (`not JSON`, a non-object entry, `comments` a string, `comments` the number
      `0`) each ignored for that content only and unrepaired (the raw stored string is compared before and
      after the read); the switch leaving the other three decisions and the raw entry's other fields alone; the
      `with*` copies carrying the field; and a delete taking it with the entry. RED receipt: **six compile
      errors**, `The method 'setComments' isn't defined for the type 'RoleStore'`. Then **one of my own
      expectations was wrong**: the "not JSON" store cannot have a good sibling content — it has no entries at
      all — so that case now asserts the whole-store answer alone and the per-entry cases each carry a healthy
      `content-b` beside the broken `content-a`. **20/20 in the file** (014's 12 + these 8).
- [x] T014 [US3] Write the sheet's and the switch's group into `test/reading_view_comment_test.dart` from quickstart
      row 13's switch half: 014's own sheet also carries the switch, in both text types; toggling it stores the
      choice and the next read honours it; nothing else on the page moves (the text, the undo stack, the
      highlight in force, the roles); and a reopen reads the stored choice back. Run it and keep the RED output.

      **DONE 2026-10-08** — **5 cases appended** to `test/reading_view_comment_test.dart` as the sheet's own
      group; the harness gained 014's page-test idioms (`settle`, `inSheet`, `openSheet`, `switchInSheet`,
      `storedRoles`). Cases: the sheet carries the switch in both text types; toggling stores exactly
      `{"comments": {"comments": false}}`; the next read honours it (the comment is an utterance, then it is
      not); nothing else moves (the painted text, the highlight in force) and choosing the text type afterwards
      keeps the switch off (the trap plan ripple 4 named); and a reopen reads the stored choice back — where a
      tap inside the comment answers the owner sentence instead (FR-012's off half, quickstart row 13's own
      tap half). RED receipt: **behavioural** — `Found 0 widgets with text "Read the comments" descending from
      AlertDialog`, and the toggle/tap cases failing the same way. **One harness fix of mine on the way**: the
      read that covers a comment is 010's ⏭ Continue Read (`Icons.skip_next`); my first draft tapped
      `Icons.play_arrow`, which reads the *highlighted selection* and therefore read nothing
      (`Actual: []`). **5/5 green.**
      Said plainly: SC-006's paint half — the comment's own span highlighted exactly while it is spoken — is
      **not** asserted here, because this harness's fake reader never calls `onSentenceStart`, so no
      page-level test can see the highlight move. That half is the device row's witness (row 20), as 014's own
      equivalent was.

### Implementation for US3

- [x] T015 [US3] Add the setting to `lib/role_store.dart`: `RoleSettings.commentsRead` (default `true`), the field
      carried by `withRemoval`/`withVoice` and counted by `isEmpty`, the tolerant read of `"comments"` in the
      content's entry, and `RoleStore.setComments(contentKey, {required bool read})` writing it absent when the
      answer is *read* (D5, FR-006/FR-015; plan ripple 4). Green against T013.
      **Re-cut 2026-10-08 (T009, US1):** the FIELD itself already exists — the page's tap rule needs its answer
      on the very next tap (FR-012), so T009 added `RoleSettings.commentsRead` with its default and carried it
      through `_setDialogue`'s hand-built settings. What is left here, and what this row's own test covers, is
      the setting's **life**: the tolerant read of `"comments"`, `setComments`, and the `with*`/`isEmpty` carry.
      Nothing writes or reads a stored value yet, which is why `test/role_store_test.dart` is still 014's own and
      green unmodified.

      **DONE 2026-10-08** — `lib/role_store.dart`, five edits: `isEmpty` counts the switch (a content whose
      comments are off is not "nothing decided"); `withRemoval` and `withVoice` carry it (the ripple-4 trap);
      `_settingsFrom` reads **only an explicit `false`** as off, so a string, a number or anything else reads
      as the shipped default; and `setComments(contentKey, {required bool read})` writes `"comments": false` or
      **removes the field**, which is what makes *read* the absence — exactly as 标准 is the absence of
      `"type"` (FR-006). **20/20 green**, 014's own store tests among them and unmodified.
- [x] T016 [US3] Add the switch to `lib/reading_view.dart`: a `SwitchListTile` in `_openTextType`'s dialog, above the
      role list and offered in both text types, applied through a `_setComments` that writes the store and
      updates the page's own `_roles` (D6, FR-014/FR-016; plan ripple 4). Green against T014.
      **Re-cut 2026-10-08 (T009, US1):** this row also carried "`_setDialogue`'s hand-built `RoleSettings` carries
      the field, or switching the text type would silently re-enable the comments" — T009 did that (the tap rule
      needed the field to exist), so what is left is the switch itself and its own store write.

      **DONE 2026-10-08** — `lib/reading_view.dart`, three edits: `_setComments` sets the page's own copy and
      writes the store (the same shape as `_setDialogue`, including the `_anchorKey` guard and the same
      one-line failure log); a `SwitchListTile` sits **above the role list** in `_openTextType`'s dialog —
      outside the `if (_roles.isDialogue)` block, so both text types are offered it (FR-014) — with
      `setDialog(() {})` rebuilding the sheet; and the read passes `commentsRead: _roles.commentsRead` into
      `resolveSpeeches` (the resolver already defaults to `true`, so every other caller is unchanged).
      **5/5 sheet cases green; the whole suite 616 passing, 0 failing; `flutter analyze` clean** — 014's page
      tests green **unmodified**, which is the checkpoint's own claim: a dialogue content that never touched
      this switch still stores exactly `{type, removed, voices}` and its sheet still reads as it did, with one
      row added above the roles.

**Checkpoint**: rows 12, 13 and 20's unit half green; 014's `test/role_store_test.dart` groups green
**unmodified** — a dialogue content that never touched this switch still stores exactly
`{type, removed, voices}` (FR-015).

---

## Phase 6: User Story 4 — A comment inside a role's turn, and in 标准 (P2)

**Goal**: the two tags in one text. A turn's spoken content excludes its comment, its detected language is its
own, the comment is read in its own language's voice rather than the role's, a paragraph that is nothing but a
comment is not a turn, and the editor's Format action knows no tag but `{}`.

**Independent Test**: in 多人对话, read a role's turn that carries a comment and read the app's own lines: the
turn's utterances are the turn's own text in that role's voice, the comment's utterances follow with
`comment=1` in the comment's language's voice, the role list's turn count is unmoved — while the same text set
to 标准 reads the sentence in its language's voice and the comment after it.

### Tests for US4 ⚠️ (write first, run RED)

- [x] T017 [US4] Write the dialogue's own group into `test/speech_resolver_comment_test.dart` and
      `test/comment_test.dart` from quickstart rows 9-11: `{阿明} 你好。[注] Hello.` is one turn whose own text
      is `你好。` with the English comment read after it in English; the turn's detected language is its own
      text's; a paragraph that holds nothing but a comment yields no turn, no role and no count; a 标准 content
      with a comment reads its sentences exactly as today plus the comment; and `formatForDialogue` on a
      comment-bearing dialogue text leaves every `[comment]`/`[注]` byte-identical (FR-017). Run it and keep the
      RED output.

      **DONE 2026-10-08** — the dialogue's own group is now group 9 of
      `test/speech_resolver_comment_test.dart` (6 cases replacing the one placeholder case): the turn's speech is
      its own text with its own language (`{阿明} 今日个天气真系唔错啊。` with an English comment under it → the turn
      stays `zh-Hans`), the comment reads in the English pick while 阿明 reads in its own pick, a comment-only
      paragraph is no turn/no role/no count (and without the comment list the same text is today's 3-turn scan),
      a role whose only paragraph is a comment is no role at all, a comment in a turn's own paragraph leaves the
      role's turn count at 2 with the turn's text ending at the tag, and a comment before every sentence is never
      spoken in dialogue mode either. `test/comment_test.dart` gains the group "Format knows {}, and nothing else
      (FR-017)" (4 cases): against an inline tag+comment, a head comment, and a comment whose content holds a
      `{…}` pair, every `[...]` marker is byte-identical and in order while the only characters Format adds are
      line breaks; a comment with nothing to format comes back identical. **RED receipt: none — these cases were
      green on the first run**, because T005 had already landed the turn scan they exercise (T018's own body);
      the two files go **39 → 48 cases** (`comment_test.dart` 28 → 32, `speech_resolver_comment_test.dart`
      11 → 16).

### Implementation for US4

- [x] T018 [US4] Make `lib/dialogue.dart`'s `turnsOf` comment-aware: a paragraph whose whole content is a comment is
      skipped, and a turn's content ends at a comment's tag in its own paragraph (and, for a comment taking the
      rest of the paragraph, at that tag) — FR-011, D2. The parameter is optional and defaults to empty, so
      every shipped caller keeps today's turns untouched. Green against T017.
      **Note**: `formatForDialogue` (`lib/dialogue.dart:236`) is **not changed** — "Format knows no other tag"
      is a property of its `{}`-only scan, and T017's case is what keeps it true (FR-017).

      **DONE 2026-10-08** — `turnsOf` itself was already comment-aware from T005 (its optional `comments` list,
      `_commentTagIn`, and the three turn-scan cases in `test/comment_test.dart`), so `lib/dialogue.dart` is
      untouched by this pass. What T018 still owed was **ripple 3's wiring**: the page's role-list scan —
      `lib/reading_view.dart` `_openTextType`'s two calls and `_openRoleVoice`'s one — now passes
      `comments: _commentDisplay.comments` (the display's own comments, so there is one source of truth), and a
      comment-only paragraph is no turn in the role list exactly as on the read's own path. `roleTagAt` is
      untouched, and `formatForDialogue` is untouched (T017's FR-017 group is what keeps that true). **RED
      receipt**: the new page case `21. the role list is comment-aware` failed before the wiring — the 阿明 row
      was still listed (`Expected: no matching candidates` at `reading_view_comment_test.dart:410`) — and is
      green after it. **The whole suite 616 → 626 passing, 0 failing; `flutter analyze` clean**; 014's
      `test/dialogue_test.dart` and `test/reading_view_dialogue_test.dart` green **unmodified**.

**Checkpoint**: rows 9-11 green; 014's `test/dialogue_test.dart` and `test/reading_view_dialogue_test.dart`
green **unmodified**.

---

## Phase 7: User Story 5 — The comment in the video (P3)

**Goal**: the render. One slot per sentence still, whose block paints the sentence **and** its comment's
content and whose audio is the read's own utterances inside that slot's frames — so the file shows what the
reader asked for (*"the comment content will be in the video with the sentence"*) and sounds exactly like the
read, in both switch states.

**Independent Test**: render a content with one comment, sample its frames and read the app's own render
lines: every frame of the sentence's slot carries the comment's content and none carries a marker, and the
file's own audio carries the comment exactly when the read does.

### Tests for US5 ⚠️ (write first, run RED)

- [x] T019 [P] [US5] Write `test/video_comment_test.dart` from quickstart row 14: no slot's text contains a tag
      character; the slot an owner sentence built carries that sentence's text followed by its comment's
      content on its own line, with `span=` still the sentence's own offsets; the slot's audio names its own
      WAV first and the comment's sentences' after it, in the read's own order and voices; with the comments off
      the block is unchanged while the audio names its own WAV alone; and a tagless content's plan is what
      012's own tests assert for that text. Run it and keep the RED output.

      **DONE 2026-10-09** — `test/video_comment_test.dart`, group "the slot's block and its audio (14)" (4
      cases): the comment's unit carries `isComment`; the plan gives the sentence ONE slot whose block is
      `Hola.\nHow are you?` with `span=` still the sentence's own `0..5`, and no slot's text holds a bracket; the
      slot's `audio` is `[0, 1]` (the sentence first, its comment after) and those two utterances carry the
      Spanish and the English pick; with the comments off the block is byte-identical while `audio` is `[0]` and
      the slot is shorter by exactly the comment's audio; and the tagless control's plan is 012's own shape
      (two sentences, two slots, `audio` `[0]`/`[1]`, each block exactly its sentence). **RED receipt: a compile
      error** — the file run against HEAD's `lib/video_timeline.dart` fails with `No named parameter with the
      name 'commentsRead'`, `… 'comments'`, `The getter 'isComment' isn't defined for the type 'VideoSentence'`
      and `… 'audio' isn't defined for the type 'VideoSlot'` (8 errors). **4/4 green.**

### Implementation for US5

- [x] T020 [US5] Group the comment into its sentence's slot in `lib/video_timeline.dart`: `VideoSentence.isComment`
      (optional, default `false`), the slot's `text` carrying its own sentence plus each comment riding it, and
      the slot's `audio` naming the utterances it plays, in order (D8). The pairing is its own rule: a comment
      rides the last non-comment sentence before it in the file's own sentence list, and when the file has no
      such sentence the comment is a slot of its own rather than dropped (research's grounding correction 2).
      The setting's two faces: the block always paints the comment's content, the audio carries it only when the
      comments were read. Green against T019.

      **DONE 2026-10-09** — `lib/video_timeline.dart`: `VideoSentence.isComment` (default `false`, set from
      `ParagraphSpeech.isComment` in `videoSentencesOf`); `VideoSlot.audio` (indices into the plan's own
      sentences, in play order); and `buildVideoPlan` regrouped — one slot per non-comment sentence, each
      comment unit riding the slot it follows, and a comment with no sentence before it (a range that begins
      past its owner) a slot of its own. The slot's `text` is its sentence, then each riding comment on its own
      line; the block is built from the content's own `comments` (a new optional parameter), so it paints a
      comment whether or not it was read (D8); `durationMs`/`frames` are the sum of the slot's utterances; and
      the hold repeats the last slot's block. A tagless content is unchanged, slot for slot.
- [x] T021 [US5] Hand the muxer one segment per utterance in `lib/video_renderer.dart`: the audio loop walks each
      slot's own `audio` list inside the slot's frames, so a comment's WAV is a segment of its own with its own
      `durationUs`, additive to the flat list the platform half already takes
      (`android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt:461-496`). Pass 1 is untouched — it
      still synthesizes one WAV per sentence, comment sentences included (D8; plan ripple 7).

      **DONE 2026-10-09** — `lib/video_renderer.dart`: `render` gains `commentsRead` (default `true`, passed to
      `videoSentencesFrom`) and hands `buildVideoPlan` the content's own `commentsOf(content)`; the audio loop
      walks each slot's `audio` list instead of one file per slot — one `VideoAudioSegment` per utterance, its
      path `sentence_$i.wav`, each given its own `durationUs` with the slot's **last** utterance absorbing the
      gap, so the flat list the platform half takes keeps its shape and its total still equals the plan's frames
      exactly. The end hold still writes one null segment of its own span. Pass 1 is untouched. The page's
      render call (`lib/reading_view.dart`) now passes `commentsRead: _roles.commentsRead`, so the file sounds
      exactly like the read — the one wiring the device rows (22/23) need, rippled but not named in this row.

**Checkpoint**: row 14 green; 012's `test/video_timeline_test.dart`, `test/video_painter_test.dart` and
`test/video_renderer_test.dart` green **unmodified** (a slot with one utterance is today's slot).

**DONE 2026-10-09 (checkpoint)** — the whole suite is **630 passing, 0 failing** and `flutter analyze` clean;
012's `test/video_timeline_test.dart`, `test/video_painter_test.dart`, `test/video_renderer_test.dart` and
014's `test/video_dialogue_test.dart` are green **unmodified** (a slot with one utterance is today's slot, and
a tagless plan is today's plan slot for slot). US5's device half (rows 22/23, S1/S2) is Phase 8.

---

## Phase 8: The device walk

**Purpose**: the rows a unit test cannot hear or see. Every row appends its evidence to
`specs/015-comment-tag/breakpoint.md`, and every row is dispatched by the driver T022 creates.

- [x] T022 Write the device driver `specs/015-comment-tag/scripts/klhu_walk_comment.py` and its fixture
      `specs/015-comment-tag/scripts/klhu_comment_fixture.txt`: the fixture holds the reader's own example (a
      Spanish sentence, a blank line, `[注] How are you?`) plus the shapes the rows need (the inline
      `Hola. [注] Hi. Adiós.` paragraph, **one content per spelling** — the same sentence with `[nota]` and with
      `[註]`, so row 17 can prove a spelling from another keyboard reads as `[注]` does — a dialogue content with
      a comment under a turn, the same tags in a 标准 content, a comment before any sentence, a marker-only
      paragraph, a full-width `［注］`), and the
      driver imports 014's (`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py`, which itself sits on
      012's) for the device mechanics, dispatch and `RESULT: PASS|FAIL`, extending 014's speak-line regex with
      `(?: comment=1)?` after the quoted utterance.

      **DONE 2026-10-09** — `klhu_comment_fixture.txt` (nine named sections) and `klhu_walk_comment.py`, with rows
      17 and 18 implemented (a row is implemented in the pass that walks it — 014's own convention; `main` names
      19-23 as still to come). Two mechanics the driver had to add, both in `breakpoint.md` § Deviations: the voice
      catalogue is harvested by opening 语音 and pressing Back (`voicesForAll` logs nothing; the picker's
      `voicesFor` logs every entry), and the two voice picks are seeded into the app's own store rather than tapped
      through two pickers. Load build: `flutter build apk --debug` (16.2 s) + `adb install -r` on `emulator-5554`.
      **Finished 2026-10-09**: the driver now implements every row it was written for — 17, 18, 19, 20, 21, 22
      and 23 (one row per run, 014's convention) — and `main` dispatches them all.
- [x] T023 Walk quickstart row 17 into `specs/015-comment-tag/breakpoint.md`: a comment read on the device —
      the page's dump has no marker, the `klhu speak` lines are the sentence's utterances in the device's
      Spanish voice then the comment's with `comment=1` in the English one, the highlight moves onto the comment
      while it is spoken, and the fixture's `[nota]` and `[註]` contents read exactly as the `[注]` one did.
      Proves SC-001, SC-003, SC-006, FR-001, FR-005, FR-007.

      **DONE 2026-10-09 — WALKED, PASS (24/24)**, quoted in `breakpoint.md` § Row 17. 218 voices off the device;
      the picks `es-es-x-eea-local||es-ES` / `en-au-x-aua-local||en-AU`; and for each of `main`/`nota`/`traditional`
      the page painted `Hola.\n\nHow are you?` (no bracket) while the app's own lines read, in order,
      `klhu speak p0 s0 voice=es-es-x-eea-local "Hola."` then
      `klhu speak p1 s0 voice=en-au-x-aua-local "How are you?" comment=1` — the two spellings' contents reading
      exactly as the `[注]` one did.
- [x] T024 Walk quickstart row 18 into `specs/015-comment-tag/breakpoint.md`: the inline tag's reach — exactly
      one comment, its utterances `Hi.` and `Adiós.` in that order with `comment=1`, in the voice the **comment's
      own** text detects (`es` for this text — the accent; corrected 2026-10-09), and `Adiós.` never a sentence
      of the paragraph read in its own right. Proves FR-002's consequence.

      **DONE 2026-10-09 — WALKED, PASS (7/7)**, quoted in `breakpoint.md` § Row 18. The row was written expecting
      the comment in the **English** voice; the run showed why that cannot hold: a comment's language is
      `detectLanguage` of its own content (FR-008/A3), and the rule table reads `Adiós.`'s accent as Spanish, so
      `Hi. Adiós.` detects **es** and the comment is voiced by the Spanish pick — the app is right. The reader
      kept the fixture text and the expectation was corrected in place (`quickstart.md` row 18, `spec.md`'s inline
      edge case and its fixture note); re-walked **7/7**: one comment, `Hola.`→`Hi.`→`Adiós.` in order, both
      `comment=1`, no marker on the page, and the comment in the voice its own text detects. Row 17 carries the
      two-language case.
- [x] T025 Walk quickstart row 19 into `specs/015-comment-tag/breakpoint.md`: a tap inside a comment, with the
      comments read and with them off — the read's range is the comment's own span in the first case and the
      owner sentence's in the second, with the highlight covering what was read. Proves SC-009, FR-012.

      **DONE 2026-10-09 — WALKED, PASS (6/6)**, quoted in `breakpoint.md` § Row 19. The tap lands on the comment's
      own painted line (`@540,606`; the block is `Hola.`, a blank line, the comment). With the comments read:
      `klhu read range: 11..23` — the comment's own span — and the utterance is `How are you?` with `comment=1`,
      the highlight drawn (1076 pixels). With them off (the sheet's switch, one tap): the same point answers
      `klhu read range: 0..5` — the owner sentence — and only `Hola.` is read, highlight drawn (410 pixels). Never
      a marker, never a gap, in either state. One driver fix on the way (not a device finding): 014's
      `tap_any`/`shows` read 014's own label table, which has no `comments` key, so this row's switch lookup is
      the 015 module's own.
- [x] T026 Walk quickstart row 20 into `specs/015-comment-tag/breakpoint.md`: the switch off, and across a
      restart — no comment utterance, the page's words unmoved, the setting still off for that content, a
      second content unaffected, and the setting gone after the content is deleted. Proves SC-002, SC-006,
      SC-010, FR-014, FR-016.

      **DONE 2026-10-09 — WALKED, PASS (9/9)**, quoted in `breakpoint.md` § Row 20. The store read back off the
      device is `content_roles[comment_main] = {'comments': False}` after one tap on the sheet's switch; the read
      from the top is `['Hola.']` alone while the page still paints `Hola.\n\nHow are you?` with no marker; a
      force-stop + start reopens the same content with the switch still off and the same read; a second content
      whose switch was never touched still reads its comments (`Hola.` then `How are you? comment=1`); and
      deleting the first through the shipped confirm dialog takes the entry — `content_roles = None`.
- [x] T027 Walk quickstart row 21 into `specs/015-comment-tag/breakpoint.md`: a comment inside a dialogue turn
      and in 标准 — the turn's own utterances in its role's voice, the comment's with `comment=1` in its own
      language's voice, the role's turn count unmoved, the comment-only paragraph no turn at all, and a comment
      before every sentence never spoken. Proves SC-005, FR-010, FR-011, FR-003.

      **DONE 2026-10-09 — WALKED, PASS (9/9)**, quoted in `breakpoint.md` § Row 21. In 多人对话 the turn's line is
      `role=阿明 voice=cmn-cn-x-ccc-local "今日个天气真系唔错啊。"` then `role=narration voice=en-au-x-aub-local
      "How are you?" comment=1` — the two voices differ, and 阿明's is Chinese. The role list reads one row,
      `阿明 / 1 turn · 普通话 CCC (女)` — the comment-only paragraph adds no role and no turn. The same text in
      标准 speaks the shipped paragraph **tag and all** (`{阿明} 今日个天气真系唔错啊。`, no `voice=` — no zh-Hans
      pick) and then the comment with `comment=1`. The head-comment content speaks `Hola.` alone while the page
      paints `Hello.\n\nHola.` with no marker.
- [x] T028 Walk quickstart row 22 into `specs/015-comment-tag/breakpoint.md`: a comment's video, the frames —
      two renders (comments read / off) with the slot's ink box measured by the driver's own `scan_frame`, its
      `text=` length and the aspect's own expected numbers, and the block taller than the same sentence with no
      comment in both files. Proves SC-007, FR-013; its measured numbers go into `research.md` → Spike S2.

      **DONE 2026-10-09 — WALKED, PASS (35/35)**, quoted in `breakpoint.md` § Row 22, numbers in `research.md`
      (Spike S2). Three renders at 16:9 landscape 1080p: the comments read (`text=18`, 100 frames, 3333 ms,
      132635 B), the comments off (`text=18`, 75 frames, 2500 ms, 96187 B) and a tagless twin of the same
      sentence (`text=5`, 75 frames, 45516 B). Slot 0's ink box is `(208, 864, 456, 964)` — 100 px tall — in
      **both** comment files, identical to the pixel, against `(208, 924, 298, 954)` — 30 px — for the twin; the
      block's second line sits where the twin's only line sits, so the block grows upward. No frame of the three
      files carries the withdrawn band or anything outside the column. One driver fix on the way (not a device
      finding): 012's imported `render()` compared the told length to Python's `round(ms / 1000)` as an exact
      string, which bites a render landing exactly on .5 s (2500 ms → `3 s` on the page, `2` in Python); it now
      reads the number with the one-second tolerance its own neighbour already had.
- [x] T029 Walk quickstart row 23 into `specs/015-comment-tag/breakpoint.md`: a comment's video, the audio —
      `sentences=N` against the read's own utterance count in both switch states, the file's duration
      difference, one rate for the whole stream, and the hiss probe on the two-language file. Proves SC-008,
      FR-009; its measured numbers go into `research.md` → Spike S1, and a failure here is recorded as the
      finding the row exists to catch.

      **DONE 2026-10-09 — WALKED, PASS (25/25)**, quoted in `breakpoint.md` § Row 23, numbers in `research.md`
      (Spike S1). Each render's `sentences=` was read against the utterance count the **read** produced on the
      device in the same run: 2 with the comments read (the sentence then the comment), 1 with them off. The
      two files differ by exactly the comment's audio — 833 ms / 25 frames, matched by the container durations
      3.46125 s vs 2.627958 s — and each carries one audio stream at 24000 Hz, 1 channel, so the plugin's own
      refusal (`the sentences were written in different audio layouts; they cannot be muxed`) was not reached:
      the two languages muxed into one layout. The >10 kHz probe on the two-language file exits 0, first 2 s at
      −66.0 dB against its −35 dB ceiling. One check of the row's own was corrected by the run (not a device
      finding): the container's duration runs ~128 ms past the muxer's own `ms` in **both** files, so the
      assertion is that the tail is the same constant either way, which is what keeps "the difference is the
      comment's audio" the whole difference.

**Checkpoint**: every row above has a PASS or a written reason in `breakpoint.md`; no row cites a driver
command that does not implement it (extend T022's dispatch in the same pass, or record the row as hand-run).

---

## Phase 9: Polish & cross-cutting concerns

- [x] T030 Run the two structural rows into `specs/015-comment-tag/breakpoint.md`: row 15 (`git diff --stat
      pubspec.yaml pubspec.lock android/ ios/` → nothing) and row 16 (`flutter test test/l10n_keys_test.dart`,
      `flutter gen-l10n`, `git status --short lib/l10n`). Proves FR-018, SC-011, FR-014's string half.

      **DONE 2026-10-09 — GREEN, with one doc count corrected**, quoted in `breakpoint.md` § Rows 15-16. Row 15:
      `git diff --stat pubspec.yaml pubspec.lock android/ ios/` and `git status --short` on the same paths are
      both **empty** — no dependency and no platform edit (the video's platform half was *read*; row 23's
      two-language render muxed with no Kotlin change). Row 16: each of the four ARBs carries **108** message
      keys, `added ['commentsReadLabel'] removed []` against HEAD's 107; every translation matches the template
      with `missing [] extra []`; `flutter test test/l10n_keys_test.dart` → **3 tests, all passed**; after
      `flutter gen-l10n` the generated Dart is **sha256-identical** to what was already on disk (the files on
      disk are the generator's own output, and their `git status` modification is this feature's uncommitted
      work). The row had been written expecting **109** keys, but the feature ships **one** — corrected in place
      in `quickstart.md` row 16 and in `plan.md`'s l10n step ("Two new keys" → "One new key"), both dated, since
      `research.md` § D6 and T001's own receipt both say one key (§ Deviations 5).
- [x] T031 Run quickstart row 24 into `specs/015-comment-tag/breakpoint.md`:
      `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py` plus
      `flutter test test/language_test.dart test/segmenter_test.dart test/reader_service_test.dart` — green,
      unmodified. Proves SC-004 for the read.

      **DONE 2026-10-09 — GREEN**, quoted in `breakpoint.md` § Rows 24-26. 011's driver takes **one row per
      run** (its own usage line: `7|8|9|10|16|17|20|21`; a bare run prints that and exits 2), so all eight were
      walked one at a time — 7, 8, 9, 10, 16, 17, 20, 21 → **RESULT: PASS** each. Its driver prints one `RESULT:`
      line per row rather than per check, so its output carries no `  PASS ` lines to count; the eight files hold
      one `RESULT: PASS` each, with no `FAIL`/`Traceback`/`Error` anywhere. The unit group is **42 tests, all
      passed**.
- [x] T032 Run quickstart row 25 into `specs/015-comment-tag/breakpoint.md` — **one row per run**:
      `python3 specs/012-reading-video/scripts/klhu_walk_video.py 32`, then `... 49`, plus
      `flutter test test/video_timeline_test.dart test/video_painter_test.dart test/video_renderer_test.dart`.
      Proves SC-004 and SC-008's invariance half for the video.

      **DONE 2026-10-09 — GREEN**, quoted in `breakpoint.md` § Rows 24-26. One row per run: `32` →
      **42/42 checks passed**, `49` → **41/41 checks passed**. The unit group is **62 tests, all passed**.
- [x] T033 Run quickstart row 26 into `specs/015-comment-tag/breakpoint.md` — one row per run:
      `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 23`, then `... 25`, then `... 33`, plus
      `flutter test test/dialogue_test.dart test/speech_resolver_test.dart test/role_store_test.dart
      test/reading_view_dialogue_test.dart`. Proves SC-004, SC-005 and FR-015's store shape, and re-checks plan
      ripple 6 (014's driver reads its own speak lines unchanged by the new field).

      **DONE 2026-10-09 — GREEN, with one transient re-run**, quoted in `breakpoint.md` § Rows 24-26. One row
      per run: `23` → **10/10**, `25` → **19/19**, `33` → first run **5/9**, then **9/9** on a re-run alone
      three minutes later. The first run's four failures were one stale read after the **first** Format press
      (the field read 63 chars where the app had already formatted it to 66; the second press's read then showed
      66, which also broke the row's own "a second press changes nothing" — while Undo's byte-for-byte restore,
      Done's save of 66 chars and the reopened page all passed, so the app did the work on the first press).
      015 leaves that path alone: `git diff lib/reading_view.dart lib/dialogue.dart` carries no hunk at the
      editor's `formatForDialogue` call (`reading_view.dart:753`) or at the button's enabled rule (`:2562`), and
      014's own receipt has this row at 9/9 with the same driver. Recorded as a read that raced the field, not a
      regression. The unit group is **74 tests, all passed** — and 014's driver reading its own speak lines
      unchanged is plan ripple 6, re-checked.
- [x] T034 Close the list in `specs/015-comment-tag/tasks.md`: re-run `flutter analyze` and
      `flutter test --concurrency=2` on the finished tree, write both numbers into the Status section beside
      T002's baseline and the count of new tests, re-run `check_tasks_format.py` and `task_id_audit.py` and
      quote both outputs, tick the rows that are done and record beside each tick the command, the counts and
      the date. A receipt that has gone false (a checker line quoting an older count, a row whose numbers moved
      with no reason recorded) is fixed in this task rather than left standing.

      **DONE 2026-10-09 — the list is closed, 34/34.** Re-taken on the finished tree: `flutter analyze` → **No
      issues found!** (1.2 s) and `flutter test --concurrency=2` → **630 tests, all passed** (55 s, `00:55 +630:
      All tests passed!`). Read against T002's baseline — **559 passing on 2026-10-08** at HEAD `2639776` — that
      is the feature's own **71** new cases: 32 in `test/comment_test.dart`, 11 in
      `test/reading_view_comment_test.dart`, 16 in `test/speech_resolver_comment_test.dart`, 4 in
      `test/video_comment_test.dart`, and 8 in the comment group appended to 014's `test/role_store_test.dart`
      (which now holds 20). Both checkers were re-run after this file's last edit and are quoted verbatim in the
      Status section above. Two receipts that had gone false are fixed **here** rather than left standing: the
      Format checker's quote read `16 done` (it now quotes this pass's own output), and quickstart row 16's key
      count said 109 where the feature ships one key, `commentsReadLabel` (`breakpoint.md` § Deviations 5).

---

## Dependencies & ordering

- **Phase 1 (T001)** blocks everything that compiles against the new key — i.e. T016 (and T014's assertion on
  the switch's label).
- **Phase 2 (T002-T005)** blocks all five stories: `lib/comment.dart` is what the read, the page and the video
  all consume, and T005's `turnsOf` is what the dialogue path needs. T002 is the first thing to run, and
  T003/T004 and T006/T007/T008 are RED before green.
- **US1 (Phase 3)** blocks US3's page half and US5's frame half, which build on the display and on what a slot
  carries. US2 (Phase 4) blocks US4 (a comment inside a turn is US2's resolution in dialogue mode) and US5
  (the slot's audio is the read's own utterances).
- **US3 (Phase 5)** depends on US2: the setting's whole meaning is what the resolution does with it.
- **The walk (Phase 8)** depends on its story's code: rows 17-18 on US1+US2, 19 on US1+US3, 20 on US3, 21 on
  US4, 22-23 on US5. T022 (the driver) depends on nothing but is written before its rows.
- **Phase 9** last: T030-T033 need the finished tree, and T034 needs everything.

## Parallel opportunities

- T003, T010, T013 and T019 are four different new test files whose modules already exist (or are T004's, in
  T003's case) — no shared state, and each is RED on its own.
- T006 and T008 are two files (the display's own tests and the page's); they are not `[P]` against each other's
  *green*, which needs T007 and T009 respectively.
- **Nothing in Phase 8 is parallel**: every row installs, drives and reads the same device, and they all append
  to one `breakpoint.md`. Two rows run one after the other even when their stories are independent.

## Implementation strategy

The MVP is **Phases 2-4**: a comment is recognised, hidden on the page and read after its sentence in its own
voice — demonstrable on the device with rows 17 and 18 alone. US3 then gives the reader the switch, US4 makes
the two tags share a text, US5 carries the comment into the video. Each story is independently demonstrable:
rows 17/18 (US1+US2), 19/20 (US3), 21 (US4), 22/23 (US5).

## Notes

- The device rows are walked by hand first and scripted afterwards; the driver's dispatch list is the authority
  on which rows are scripted, so a row added later extends it in the same pass.
- `test/l10n_keys_test.dart` is bidirectional: a key in three ARBs fails exactly as loudly as a key in five.
- No `contracts/` directory for this feature: the interfaces it changes are in-process Dart types the app
  already owns (`ParagraphSpeech`, `VideoSentence`, `VideoSlot`, `RoleSettings`), and the encoder's audio list
  is taken as it is (plan § Project Structure).
- The read's new `comment=1` field is device evidence only — no shipped test asserts either log line
  (`grep -rn 'klhu speak\|klhu render' test/` → nothing), so a row that rests on it says so.

## Requirement coverage

| Requirement | Tasks that satisfy it |
|---|---|
| FR-001 (the tag's grammar: four spellings, one bracket pair, all live everywhere) | T001, T003, T004, T009, T023 |
| FR-002 (a comment's content runs to its paragraph's end) | T003, T004, T011, T024 |
| FR-003 (the comment belongs to the last sentence before its tag) | T003, T004, T011, T027 |
| FR-004 (a comment's content is no sentence's span) | T003, T011, T018 |
| FR-005 (the tag's characters never reach the engine, never painted) | T003, T006, T007, T009, T023 |
| FR-006 (one setting per content; nothing stored reads them) | T010, T011, T013, T015 |
| FR-007 (read as its own speech after its sentence, one utterance per sentence) | T010, T011, T012, T023 |
| FR-008 (a comment's language is its own content's) | T010, T011, T023 |
| FR-009 (one resolution for page, service and video) | T010, T011, T020, T023, T029 |
| FR-010 (标准 reads as today but for the comments) | T010, T011, T027, T031 |
| FR-011 (a turn excludes its comment; a comment-only paragraph is no turn) | T005, T017, T018, T027 |
| FR-012 (the page paints no marker; tap and highlight still answer) | T006, T007, T008, T009, T025 |
| FR-013 (a frame paints the sentence with its comment, and no tag) | T019, T020, T028 |
| FR-014 (the switch on the page's own sheet; four locales) | T001, T014, T016, T026, T030 |
| FR-015 (stored per content, tolerated, removed with the content) | T013, T015, T026, T033 |
| FR-016 (changing the setting touches nothing else) | T014, T016, T026 |
| FR-017 (Format leaves every comment where it is) | T017 |
| FR-018 (no dependency, no network) | T030 |
| SC-001 (with nothing stored, the comments are read; no marker in any utterance) | T010, T011, T023 |
| SC-002 (with the setting off, none of the comments' words reach the engine) | T010, T011, T026 |
| SC-003 (two languages, two voices, per utterance) | T010, T011, T012, T023 |
| SC-004 (a content with no tag reads, paints and renders as today) | T002, T005, T008, T009, T010, T031, T032, T033 |
| SC-005 (a turn's own speech and its role count, unmoved by a comment) | T017, T018, T027, T033 |
| SC-006 (the page's pixels and its highlight) | T006, T007, T008, T009, T023, T025, T026 |
| SC-007 (a frame carries the comment with its sentence, and no marker) | T019, T020, T028 |
| SC-008 (the file's audio is the read's, in both switch states) | T019, T020, T021, T029, T032 |
| SC-009 (a tap inside a comment answers, never a marker, never a gap) | T008, T009, T025 |
| SC-010 (the setting survives a restart, is per content, dies with it) | T013, T015, T026 |
| SC-011 (no dependency and no network call) | T030 |
