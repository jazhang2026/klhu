# Specification Quality Checklist: Comment Tag

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-08
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — the file names and line numbers appear only in the
      Clarifications, Assumptions and this checklist's Notes, where they are the evidence for a decision ("what
      the app already does"), never a design instruction; the Functional Requirements name observables (what is
      spoken, what a page paints, what a frame carries, what survives a restart)
- [x] Focused on user value and business needs — the reader's own item, quoted verbatim in the `Input` block, with
      their three answers of 2026-10-08 beside it; every requirement traces to one of the two
- [x] Written for non-technical stakeholders — 注释/comment, the reading page, the video, the voice; no store,
      schema, widget or scanner is named as a decision
- [x] All mandatory sections completed — header (Feature Branch / Created / Status / Input), Clarifications, User
      Scenarios & Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c 'NEEDS CLARIFICATION' spec.md` → 0). The three
      decisions the tag's design rested on were put to the reader as numbered options the same day the research
      was done and answered in one turn (the comment's boundary, the switch's home and default, whether the marker
      is displayed); each is recorded in the spec's Clarifications section and each names the wording it settles
- [x] Requirements are testable and unambiguous — each FR names an observable: the tag's own grammar (FR-001),
      where a comment begins and ends (FR-002), which sentence it belongs to (FR-003), what never reaches the
      engine (FR-004/FR-005), what a content with nothing stored does (FR-006), what is spoken and in whose voice
      (FR-007/FR-008), what one resolution means (FR-009), what 标准 and 多人对话 each read (FR-010/FR-011), what
      the page paints and how a tap answers (FR-012), what a frame carries (FR-013), where the switch lives and
      where the setting is stored (FR-014/FR-015) and what changing it may not touch (FR-016/FR-017).
      **18 FRs, 11 SCs, 10 assumptions, 5 stories, 25 acceptance scenarios, 13 edge cases, 8 out-of-scope
      bullets** — counted mechanically, not by eye
- [x] Success criteria are measurable — the utterances' own text and voices read from the app's device line
      (SC-001/SC-003), the switch-off sequence (SC-002), the shipped read reproduced for a content with no tag
      (SC-004), a turn's own speech and its role count (SC-005), the page's pixels and its highlight (SC-006), a
      file's own frames and audio (SC-007/SC-008), the tap's answer (SC-009), the setting's life (SC-010), and the
      dependency/network receipt 012 already has (SC-011)
- [x] Success criteria are technology-agnostic — "the app's own per-utterance line", "sampled frames", "the
      device's voices"; no plugin, codec, store key or language is named as the criterion
- [x] All acceptance scenarios are defined — US1: 5, US2: 5, US3: 6, US4: 5, US5: 4 (25 in total), each
      Given/When/Then and independently demonstrable
- [x] Edge cases are identified — 13, including the four that decide the feature's feel: the **inline tag taking
      the rest of its paragraph** (the consequence FR-002's boundary carries, and the line the device row has to
      show), the **second marker** inside a comment (it is the comment's own text — there is nothing to nest), the
      **comment before any sentence** (displayed, never spoken, in no frame), and **a marker the rule refuses is
      not repaired** (heard rather than seen, since the page paints no markers)
- [x] Scope is clearly bounded — the Out of scope list (per-comment styling, any second marker shape, more than
      one comment per sentence, translating or generating a comment, per-comment audio or tracks, markup inside a
      comment, comments shared between contents or devices, and the 9:16 placement that is 014's own amendment)
      plus A6 (the two tags do not see each other) and A7 (a frame stays one block per slot)
- [x] Dependencies and assumptions identified — A1–A10, each with its reason and, where the reason is a fact about
      this checkout, the file or the measurement it comes from (A1's corpus count, A2's paragraph ranges, A5's
      store, A10's evidence lines)

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001/FR-002 → US1 scenarios 1–5 and the edge
      cases; FR-006 → US3 scenarios 1–6; FR-007–FR-009 → US2 scenarios 1–5; FR-010–FR-011/FR-017 → US4 scenarios
      1–5; FR-013 → US5 scenarios 1–4; FR-015/FR-016 → US3 scenarios 3–6 and SC-010
- [x] User scenarios cover primary flows — the comment and its invisible marker (P1), the comment read after its
      sentence (P1), a content whose comments are not read (P2), a comment inside a dialogue turn and in 标准 (P2),
      the comment in the video (P3)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — the mechanics the feature rests on (sentence
      segmentation, the language rule table, the per-content store) appear only as A2/A3/A5's declared
      constraints, which is the constitution's slot for them

## Notes

**The round of 2026-10-08, and what each answer now binds.**

- The reader answered three questions in one terse turn. What a reviewer should notice is **the reversal**: the
  item's own example (*"the english translation will not be read"*) is **not** the shipped default — a content
  with nothing stored reads its comments, and the switch turns them off (FR-006, SC-001). A plan that reads the
  `Input` block literally ships the opposite behaviour, which is why the reversal is stated on the `Input` lines
  themselves and not only in the Clarifications entry. Reversing it back is one rule (the store's absence) plus
  one row's expectation.
- **The boundary (paragraph, not line) is the answer with the visible cost.** It buys the app's own unit
  (`lib/segmenter.dart:71`, the ranges 014's turns are cut on — no new division of the reader's text) and the
  spelling that reads naturally; it costs the inline case its reach: `Hola. [注] Hi. Adiós.` makes *Adiós.* part
  of the comment, so a sentence written after an inline tag is never read by the sentence's voice. That is a
  **silent** loss rather than a loud one, so the plan owes it a device row (the sentence after the tag is absent
  from the app's own per-utterance lines) rather than a prose sentence alone. The line boundary was the
  alternative; it was not taken, and the reason is in the Clarifications entry.
- **Hiding the marker is the answer that moves work into the plan.** The page paints the reader's text today
  (`lib/reading_view.dart:2241-2255`, one span tree: before / highlight / after) and taps and highlights are
  expressed in content offsets (`:192 _highlight`, `:968 _onTapText`). Painting less than the text means the
  display and those offsets are no longer the same string, so the plan must state the mapping (A4) and the
  device rows must prove a tap inside a comment still answers (SC-009). An elision inside the span tree — the
  tag's characters painted as an empty span, no re-indexing of the text — is the shape that costs the least;
  the alternative (rewriting the string the page paints) re-derives every offset the app already has.

**The story split is mine and should be argued with.** The reader listed one mechanism, one example, one switch,
one mode note and one video note; the spec has five stories: US1 the tag and its display (P1), US2 the comment's
read (P1), US3 the switch (P2), US4 the two tags sharing a text and the two modes (P2), US5 the video (P3). US2
is P1 **beside** US1 because the reader's own answer of 2026-10-08 makes reading the default — the split is
separable either way (US1 alone is a display feature), and if the reader wants the video first, that is a
two-line re-cut of the priorities. US4 is new in the sense that the item's *"can also applied in standard mode"*
line is one clause and the dialogue half of it was not asked for at all: it is in the spec because 014 ships
`{角色}` tags, both tags can sit in one text, and that is the case the reader will actually write.

**Precision added beyond the reader's wording — each one is a place the plan could otherwise decide silently.**

- The tag's grammar: `[comment]`/`[注]`, ASCII brackets, the ASCII spelling case-insensitive, and an optional
  separator (spaces, one optional colon either width, spaces) that belongs to the tag (FR-001). *(Amended
  2026-10-08: the set is **four spellings** — `[comment]`, `[注]`, `[註]`, `[nota]`, one per language the app's own
  locales are written in, all live in every content. FR-001 and A1 were rewritten in place; see the plan-gate
  review below.)* The alternatives:
  a required colon (014 rejected that shape for its own tag: a forgotten character turns a tag into text), a
  second spelling set (`[note]`, `[译]`), and a full-width bracket twin (one table row away; not taken).
- A comment's own language is the comment's own content's, never the paragraph's (A3, FR-008) — which is what
  makes the reader's own example work: the Spanish sentence reads in Spanish and the English comment in English
  **from one text**.
- The selection's precedence is written down rather than left to the reader: `{阿明} 你好。[注] Hello.` is 阿明's
  turn with a comment, while a `[注]`-headed paragraph is a comment belonging to the sentence above it — the role
  rule reads a paragraph's head (014 FR-004) and the comment rule reads its own tag wherever it is (edge cases).
- The comment is a **second speech in the sentence's own unit family** (A8, FR-007), not a new unit: one utterance
  per sentence is what 011's highlight, 010's resume point and 012's one-slot-per-sentence timeline are all built
  on, so the plan's job is to place a comment's speech beside its sentence, not to invent a unit.
- FR-017 is the smallest requirement here and the easiest to forget: the Format action (014's own) moves `{…}`
  tags and knows nothing else, so it must leave a comment exactly where the reader wrote it.

**Reuse obligations the plan inherits (grepped, not remembered).**

- The tag scan's shape is 014's: `lib/dialogue.dart:115` (`roleTagAt`, the paragraph-head rule) and
  `lib/dialogue.dart:275` (`tagOffsets`, every occurrence anywhere — the scan a comment needs, since its tag is
  read wherever it sits).
- The paragraph and sentence units are `lib/segmenter.dart:71` and `:33`; the language table is
  `lib/language.dart:96`; the standard read path is `lib/language.dart:110`.
- The **one resolution** is `lib/speech_resolver.dart:39` (`resolveSpeeches`, with 标准 delegating at `:51` and
  the per-dialogue debug line at `:68`) — the comment's read rides here so the page, the engine and the video
  cannot disagree (FR-009).
- The speech type is `lib/reader_service.dart:66` (`ParagraphSpeech`; its `role` field is the precedent for one
  additive field, and it is nullable by construction), the sentence cut is `:394`, and the evidence line is
  `:523` (`klhu speak p<s> s<n> …`) — the line every SC above is read from.
- The store is `lib/role_store.dart` (key `content_roles` at `:117`, the settings object at `:48`, the write shape
  to copy at `:129`, the delete path at `:180` which `lib/content_list_screen.dart` already calls).
- The settings sheet is `lib/reading_view.dart:1414`'s dialog (the text type), the role list at `:1450`, and the
  shipped switch shape at `:1694` (`SwitchListTile`) — the new setting joins that dialog rather than opening a
  second surface.
- The video's own side is `lib/video_timeline.dart:70` (`videoSentencesOf`) and the slot's own text at `:159`,
  which `lib/video_painter.dart` paints — the frame's text is where FR-013 lands.
- Every new string goes into the app's four locale files (`lib/l10n/app_en.arb` — the template, 116 keys —
  `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb`, 107 each), and `test/l10n_keys_test.dart` fails the build if the
  template gains a key any translation lacks: the ARB edits and the generator run are one atomic step.

**Risks the plan must carry, in the order they are likely to bite.**

1. **The page's display and its offsets (A4, FR-012).** Every tap, highlight and stored position in this app is a
   content offset; hiding the tag makes what is painted shorter than the text. The plan must name the mapping and
   prove a tap inside a comment answers after the change (SC-009); the cheapest shape is an empty span in the
   existing span tree, and a rewritten string is the one that re-derives offsets the app already owns.
2. **The inline tag's reach (FR-002).** A sentence after an inline tag is silently not read. It is the answer the
   reader gave, so it is not a defect — but it needs a device row that shows it, and the page shows no marker
   (FR-005), so the reader's only clue is the utterance list.
3. **标准 invariance (SC-004).** Every existing content, and 011's and 012's device receipts, are measured against
   today's read. One resolution with the comment as an optional second speech (FR-009/A8) is the only shape that
   keeps both halves honest; a second code path that "also works" for a text with no tag is how a shipped receipt
   quietly changes.
4. **A frame's block grows (A7).** A long comment makes a taller block, so 012's own scroll rule starts
   earlier and the frame's look changes for a content that has comments. The plan states the cost and measures a
   frame with a full-length comment, not only the shortest one.
5. **The reversed default (FR-006).** A plan that follows the item's example rather than the reader's answer ships
   the switch off. SC-001 is worded so that the *stored-nothing* case is what it measures, which is the only
   sentence that can catch it.

**Deliberately absent, so the plan does not add it.**

Per-comment styling in the page or the video, a displayed marker, a marker with an argument or a named comment
type, nesting or a closing tag, more than one comment per sentence, markup inside a comment, per-comment audio
files or tracks, translating or generating a comment (wish-list item 16), comments shared between contents or
devices, and anything about where a portrait video frame rests its words (014's amendment of 2026-10-08).

**The plan-gate review of 2026-10-08 answered two things, and both are in the artifacts.** (1) **Each tag keeps
its own implementation** — the plan first had one grammar shared between 014's `roleTagAt` and the comment's new
rule; the reader's answer (两个 tag 各留一份实现) re-cut it, so `lib/comment.dart` writes its own rule and 014's
module keeps its own (`research.md` D2's correction; `tasks.md` T004/T005). (2) **The tag's spellings are one per
language the reader types in** — `[comment]`/`[注]` plus `[註]` (Traditional) and `[nota]` (Spanish), all four live
in every content whatever the app is showing, because *"when user use their own language keyboard, it's not easy
for them to type words in different locale"* (`spec.md`'s two new sessions of 2026-10-08, FR-001, A1, and
`research.md` D11). The two words are the reader's own picks from the numbered options of that day; this checklist's
counts still read 18 FRs / 11 SCs, because the spelling set rewrote FR-001's own sentence rather than minting a
second requirement for the same behaviour.

**Naming.** The feature directory is `015-comment-tag` (the reader's own numbering, item 015 of `text.txt`).
`.specify/feature.json` was re-pinned at it by the repository's own `create-new-feature.sh` — the dry run read
back `FEATURE_NUM` **015**, the reader's own number, so no explicit `--number` was needed. The slug is a name,
not a decision: say a word and it is renamed in the four places a rename touches.
