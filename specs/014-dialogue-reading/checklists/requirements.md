# Specification Quality Checklist: Multi-Role Dialogue Reading

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-01
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — the file names and line numbers appear only in
      the Clarifications, Assumptions and this checklist's Notes, where they are the evidence for a decision
      ("what the app already does"), never a design instruction; the Functional Requirements name observables
      (what is spoken, who speaks it, what a frame shows, what survives a restart)
- [x] Focused on user value and business needs — the reader's own four asks, in their own words in the Input
      block; every requirement traces to one of them or to the round of 2026-10-01
- [x] Written for non-technical stakeholders — 对话/朗读, the role list, the voices, the video; no store,
      schema or widget is named as a decision
- [x] All mandatory sections completed — header (Feature Branch / Created / Status / Input), Clarifications,
      User Scenarios & Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions,
      Out of scope

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c 'NEEDS CLARIFICATION' spec.md` → 0). Twelve
      decisions were put to the reader as numbered options: six answered 2026-10-01, three on the tag's own
      form the next day, and three on 2026-10-03 while the plan was being reviewed (the turn's boundary, what
      a tag inside a paragraph is, and the editor's Format action); each is recorded in the spec's
      Clarifications section and each names the wording it settles
- [x] Requirements are testable and unambiguous — each FR names an observable: what the engine is asked to say
      (FR-003/FR-005), what the scan accepts as a tag and what it refuses (FR-004), what a removal does and
      does not do (FR-007/FR-008), which voice a turn gets and in what order of preference (FR-012–FR-015),
      what a frame may contain (FR-018), what a type change may change (FR-020), where the settings live,
      what deletes them (FR-021) and what the editor's Format press adds and does not add (FR-024).
      24 FRs, 11 SCs, 12 assumptions, 5 stories, 23 acceptance scenarios,
      20 edge cases — counted mechanically, not by eye
- [x] Success criteria are measurable — the utterances' own text and voice read from the app's device line
      (SC-001/SC-002), the assignment's determinism and its bound when the device has too few voices
      (SC-003/SC-004), the shipped reading reproduced for a content with no stored type (SC-005), a removal's
      permanence (SC-006), settings surviving a restart and dying with the content (SC-007), a video's frames
      and audio (SC-008), the reading position (SC-009), the dependency and network receipt 012 already
      defines (SC-010), and the editor's Format press: every tag a paragraph head, blank lines the only
      difference, one Undo back (SC-011)
- [x] Success criteria are technology-agnostic — "the app's own per-utterance line", "the device's voices",
      "sampled frames"; no plugin, codec, store key or language is named as the criterion
- [x] All acceptance scenarios are defined — US1: 7, US2: 5, US3: 5, US4: 4, US5: 2 (23 in total), each
      Given/When/Then and independently demonstrable
- [x] Edge cases are identified — 20, including the five that decide the feature's feel: a bare `名字：` line
      that is narration and not a speaker (他说：/ 时间：/ 12:30 / a URL — the class the tag deleted), braces
      that are not a speaker (`{laughs}`, removed once), a paragraph with no tag in 多人对话 (one narration
      turn, never silently attributed to the previous speaker), a tag that is not at a paragraph's head (read
      as ordinary text, braces and all, 2026-10-03), and a turn whose two sentences must stay two utterances
      — plus the Format action's own two: a brace pair that is not a speaker is taken at face value, and a
      text with nothing to format leaves no trace
- [x] Scope is clearly bounded — the Out of scope list (voice age, dialect detection, per-role appearance,
      per-role audio export, screenplay tags beyond a braced tag, roles shared between contents or
      devices, guessing a speaker, rewriting a bare `名字：` into a tag, OCR and translation) and A8/A9 (the
      app never invents a speaker and never rewrites the reader's text — the one exception being the reader's
      own Format press, FR-024)
- [x] Dependencies and assumptions identified — A1–A12, each with its reason and, where the reason is a fact
      about this checkout, the file it comes from (A1's store precedent, A2's missing age evidence, A3's
      dialect-under-Chinese rule, A10's gender evidence)

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-003/005 → US1 scenarios 1–4, FR-001/002 →
      US1 scenarios 2 and 5, FR-011–FR-015 → US2 scenarios 1–5, FR-006–FR-008 → US3 scenarios 1–5,
      FR-018/FR-019 → US4 scenarios 1–4, FR-024 → US5 scenarios 1–2, FR-020/FR-021 → US1 scenarios 6–7 and
      SC-007/SC-009
- [x] User scenarios cover primary flows — read a dialogue as a dialogue (P1), give each role its own voice
      (P2), keep a false role out (P2), make the dialogue's video (P3), write the format with one press (P3)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — the platform mechanics the feature rests on
      (per-sentence synthesis, the voice lists, the per-content store) appear only as A1/A10/A11's declared
      constraints, which is the constitution's slot for them

## Notes

**The rounds of 2026-10-01, 2026-10-02 and 2026-10-03, and what each answer now binds.**

- The reader answered six questions with option letters; the entries live in `spec.md`'s Clarifications. What a
  reviewer should notice is not the answers but their consequences: **age is not modelled** (A2 — the reader's
  own example, 成熟男声/年轻男声, is explicitly *not* taken literally, and FR-017 says so in a requirement rather
  than in a footnote), **the dialect is not detected** (A3 — so 阿明's Cantonese line is `zh-Hans` and the reader
  hands 阿明 a 广东话 voice), and **the prefix rule is mechanical with a confirmation as its guard** (FR-004 +
  FR-006). Those three are the decisions a reviewer is most likely to want reversed; reversing any of them
  changes the story set, not just a sentence.
- **The tag's form (2026-10-02) is the newest decision and the easiest to reverse.** A braced tag with an
  optional colon, and the old `名字：` shape explicitly *not* a speaker: reversing it means going back to the
  first draft's colon heuristic with its bounds, and research D3 keeps the measurement (braces start 6 lines of
  a 15,356-line prose corpus, `#` 1,174, `(` 384) that argued against `#name#`, `(name)` and `%name%`.
- **The rounds of 2026-10-03 are the newest, and they are the ones the other requirements are now read
  against.** Three answers: a turn **is a paragraph** (FR-003), the tag is read **only at a paragraph's head**
  — a tag anywhere else is ordinary text, braces and all, because the reader wanted the rule *死一点，像一个剧本*
  (FR-004) — and the editor's **Format** press is the one thing that helps produce the format (FR-024). Two
  corrections inside the same round are recorded rather than hidden: the reader's first answer to the second
  question was "strip the inner tag", replaced on reading it written down; and the deletion is named in the
  amendment note. Reversing any of the three means going back to one line = one turn (research D2 keeps that
  form, with the reader's reason for rejecting it, in its own `Alternatives considered`) or to an app that
  edits the reader's text while reading it (A9, and the reason FR-024 is a press and not a pass over the
  text).
- **The story split is mine and should be argued with.** The reader listed four things (format, per-role voices,
  the text-type setting, the video); the spec has five stories whose order is P1 mode+roles, P2 per-role voices,
  P2 confirmation, P3 video, P3 the editor's Format press — i.e. their items 1 and 3 merged into US1 (a text
  type with no mode has nothing to switch), their item 2 kept as US2, and **US3 is new**: the confirmation the
  reader's own answer (option C) introduced, which their list did not mention. **US5 is the reader's own
  addition of 2026-10-03** (the Format button, asked for while correcting the rule that reads a tag *inside* a
  paragraph as ordinary text), and it is P3 because nothing about reading depends on it: it is not one of the
  four, and a dialogue written correctly by hand never needs the button. Nothing was dropped and nothing was
  re-ranked against their intent; if the reader wants "per-role voices" first, that is a two-line re-cut of the
  priorities.

**Precision added beyond the reader's wording — each one is a place the plan could otherwise decide silently.**

- The tag's own form: `{`, a name (trimmed of surrounding spaces, spaces allowed inside, any length, ended by
  the first `}`, at least one character), `}`, then an optional colon with spaces (FR-004). The alternatives:
  the first draft's colon-and-length-bound (a name that carries a space, or is 9 characters long, was silently
  not a speaker), "any colon is a speaker" (makes 12:30 a role), "only names that appear twice" (refuses a
  role that speaks once).
- A paragraph whose first line carries no tag is one narration turn in the language's own voice, not the
  previous speaker's (FR-009, A8); a tag inside a paragraph is ordinary text — spoken, braces and all, and
  naming no role (FR-004, 2026-10-03); and a name is matched as written, per content (A4) — so May and may
  are two roles, which the list shows and the reader can fix by editing their text (the app does not rewrite
  it, outside their own Format press).
- The **turn's boundary is the app's own paragraph** (`lib/segmenter.dart:71-108`, the ranges
  `resolveParagraphSpeeches` already iterates), so a turn holds several lines and sentences and the tag is
  read at the paragraph's head only (FR-003/FR-004, the reader's own corrections of 2026-10-03). The
  consequence to accept: a text whose turns are not separated by blank lines is one turn in the first
  speaker's voice, heard with its braces.
- The **Format action** is specified as *what it is allowed to add* rather than as an algorithm: blank lines
  before the tags that are not paragraph heads, and nothing else — not one character of the reader's words
  (FR-024, SC-011). Its premise is stated with it: a brace pair is taken to be a speaker, so a stage direction
  written as `{laughs}` becomes a paragraph head and is then proposed as a role, which the role list removes.
- The separator is the spaces and optional colon that follow the tag, so a second colon is content (edge case);
  an empty turn contributes no utterance and no frame
  (never a silent gap in a video); a tap inside a tag answers with the turn's first sentence (A6).
- FR-019's single resolution is the requirement that keeps the page and the video from drifting apart; 012's
  own history (the renderer's line changing under a row that still read the old one) is why it is written as a
  requirement instead of left to the plan.

**Reuse obligations the plan inherits (grepped, not remembered).**

- The confirmation is a yes/remove review of a short list, not an invention: the shipped dialog shape is
  `lib/reading_view.dart:695` and `:730` (`_confirmDiscard()` — `AlertDialog`, Cancel plus a filled confirm,
  ARB-keyed, the shape 012's Stop confirmation already reused).
- The text type is the small either/or choice: the shape is `lib/reading_view.dart:1400` (the video aspect's
  own chooser, `videoAspectTitle`), reached from the reading page's settings entries near `:1946`.
- The per-role voice picker extends `lib/voice_picker_screen.dart:18` (the per-language picker, reached at
  `lib/reading_view.dart:1935`), which already groups 广东话 under 中文 (007) and already previews a voice.
- Every new string goes into the app's four locale files (`lib/l10n/app_en.arb`, `app_zh.arb`,
  `app_zh_Hans.arb`, `app_es.arb`) — the constitution's rule, and the reason 012's checklist states it too.
- The per-content store copies 012's shape: `lib/video_record.dart:78` (`VideoRecordStore.key`, one
  `shared_preferences` key holding JSON keyed by the content's own key, tolerant reads, removal on delete).
- The rule table's shape is `lib/language.dart:29-74`; the sentence unit and its spans are
  `lib/segmenter.dart:33/120`; the paragraph a turn now is: `:71-108`; the engine is told a voice's own
  locale at `lib/reader_service.dart:458-469`, which is what makes FR-013 (a role's pick decides its
  pronunciation) true without a second mechanism. The editor's own surface is the page's edit mode
  (`lib/reading_view.dart:2008-2083`: one `TextField` with an `UndoHistoryController`, a three-button row) —
  the Format button joins that row and copies the Undo button's disabled pattern (`:2069`) rather than
  inventing one.

**Risks the plan must carry, in the order they are likely to bite.**

1. **标准 invariance (SC-005).** Every existing content, and 011's and 012's device receipts, are measured
   against today's read. One resolution with two modes (FR-019) is the only shape that keeps the two halves
   honest; a second code path for dialogues that "also works" for 标准 is how a shipped receipt quietly
   changes.
2. **The tag is exact; the reader's meaning is not (FR-004).** Braces are the reader's own text, so the rule
   no longer guesses the clock or the URL — but it cannot know what they meant by a pair of braces. The plan
   should expect the cases the edge cases name (`{laughs}`, a name they would rather hear) and prove the
   confirmation removes one — on the device, not in a unit test alone.
3. **The automatic assignment must be written down and visible (FR-014/FR-016).** A deterministic preference
   order that is not printed is a claim nobody can check; the device row needs the assignment in the app's own
   log alongside the voice each utterance used.
4. **Cost on 008's largest allowed content (100,000 characters).** The roles are derived, so nothing is stored
   per turn; the plan should confirm the scan is one pass over the text and that the store is written on a
   change of the type, a removal or a pick — not per turn, and not on every read.
5. **Format takes the reader's braces at face value.** It is the one action that can promote a brace pair the
   reader did not mean as a speaker (`{laughs}`, a code sample) into a paragraph head — i.e. into a role. The
   plan carries the premise rather than hiding it (FR-024, data-model 2.a), the role list is where the mistake
   is removed (US3), and one Undo reverses the whole press. The device row 33 is what proves the Undo step is
   real on the reader's own keyboard.

**Deliberately absent, so the plan does not add it.**

Voice age, dialect detection, per-role typeface/size/colour, per-role audio files or tracks, screenplay features
(parentheticals, emotion or speed markers, speaker lists declared up front), roles shared across contents or
devices, guessing a speaker for an untagged line, any automatic rewriting of the reader's text beyond the
Format press's blank lines, and any conversion of a bare `名字：` into a tag. OCR and translation
are separate wish-list items (15 and 16) and are not this feature.

**Naming.** The feature directory is `014-dialogue-reading` (the reader's own numbering, item 014 of `text.txt`).
`.specify/feature.json` was re-pinned at it by the repository's own `create-new-feature.sh --number 014` — the
number had to be given explicitly because the script counts directories on this checkout and `013-web-storage`
lives on a branch, so it would otherwise have re-used 013. The slug is a name, not a decision: say a word and it
is renamed in the four places a rename touches.
