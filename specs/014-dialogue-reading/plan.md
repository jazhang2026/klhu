# Implementation Plan: Multi-Role Dialogue Reading

**Branch**: `014-dialogue-reading` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-dialogue-reading/spec.md`

**Grounding corrections**: five statements were checked against this checkout before the plan was
written, and two of the spec's own assumptions were narrowed by what the check found (the rest held):

1. **The seam the roles must feed is `List<ParagraphSpeech>`** — not the page, not the reader service
   and not the video, each of which consumes that one list (`lib/reading_view.dart:910` →
   `lib/reader_service.dart:337`, `lib/video_timeline.dart:96-105`). The spec says "one shared
   resolution" (FR-019); what it is *shared through* is this type. Everything below follows from it.
2. **A turn must be a `ParagraphSpeech`, and in dialogue mode a turn replaces a paragraph** as the unit
   the rest of the app counts (indices, spans, highlight). The spec's A5 says the unit of *speech* does
   not change — one utterance per sentence — which is true and separate: the reader service cuts a
   `ParagraphSpeech` into sentences itself (`lib/reader_service.dart:357-377`), so a turn inherits that
   for free.
3. **The content key is the content's own id** — `preset.id` / `entry.id` (`lib/reading_view.dart:447,
   665`), the key `read_position` (`lib/read_position_store.dart:47`) and `video_record`
   (`lib/video_record.dart:88`) already use. The spec's FR-021 says "the content's own key"; this is it,
   and there is no second id space to invent.
4. **`SavedContent.updatedAt` exists and is bumped on every save** (`lib/models/content.dart:40`), which
   is what lets a removed role name be tied to the version of the text it was removed from — the rule
   the spec's US3 scenario 4 needs ("an edit is a change of the text, and the proposal follows the
   text") without a new field.
5. **The voice picker has no "use the default" row today** (`lib/voice_picker_screen.dart` — it lists
   voices and saves a pick; nothing clears one). The spec's US2 scenario 5 needs a pick to be clearable,
   so the role's picker gains one affordance at its head. That is a new string in four locales, and the
   one shipped surface this feature changes rather than reuses as-is.

**Amendment, 2026-10-03 — a turn is a paragraph, not a line.** The reader's correction while reviewing this
plan: a role turn does not end at the line's end; one turn may hold several lines and sentences, and the
reader separates turns with paragraphs — a paragraph with a role tag at its head is a turn, a paragraph
without one is narration. The line scan this plan first described (research D2's original form) becomes a
map over `paragraphRanges(content)` (`lib/segmenter.dart:71-108`) — the very unit
`resolveParagraphSpeeches` iterates today (`lib/language.dart:117`) — whose ranges a turn *is*. The tag is
read at the paragraph's head only, and a tag anywhere else is ordinary text — spoken, braces and all (the
reader's second answer of 2026-10-03, which replaced this plan's first "strip the inner tag" reading) — so
the app neither guesses nor repairs, and the reader gets exactly one press to put a misplaced tag right: the
editor's **Format** action (FR-024, D12). The tag's own form is unchanged (the table below); what changed is
*where it is read*, *what a turn spans*, and one button in the editor. Grounding correction 2 above is now
literal rather than approximate: in dialogue mode a turn IS the paragraph.

## Summary

A content's text may tag its speaker at the head of a paragraph — `{旁白} …`, `{阿明} …`, `{May} …` — and
the reader can set that content's **text type** to 多人对话: each role's paragraphs are then spoken as that
role's turns, in that role's own voice, and the role tags are never spoken. 标准 (the default, and the only
thing that changes nothing) keeps today's reading exactly. The role set is *proposed* by a mechanical scan and
confirmed by the reader once per content; a role's voice is the reader's own pick or, with none, a
deterministic assignment that prefers the turn's language, then the same dialect (read from the voices'
own locales — corrected 2026-10-03), then a gender that
differs from the roles already placed — so a dialogue sounds like a conversation rather than a text read
aloud. The reader's own writing needs no discipline it does not already have: one **Format** press in the
editor puts every tag at the head of its own paragraph and touches nothing else. The same resolution feeds
the video (012), so a dialogue's frames carry only the sentence being spoken and its audio is the read's own
per-role voices.

The technical approach is deliberately small: **one new pure module** (`lib/dialogue.dart` — the paragraph
scan, the prefix rule, the turn list, the auto-assignment and the Format transformation), **one new store**
(`lib/role_store.dart`, shaped after `lib/video_record.dart`), **one changed resolution layer** (a function
with two modes that the page, the reader service and the video all call, replacing today's
`resolveParagraphSpeeches`), the reading page's entry for the text type and the role list, the role's
picker reusing the shipped `VoicePickerScreen`, **one button** in the page's existing edit toolbar (a
transformation and one assignment to the controller the editor already has), and no new dependency, no
platform code and no network.

## Technical Context

**Language/Version**: Dart `^3.13.3`, Flutter 3.47.5 stable (`pubspec.yaml`, `flutter --version` on this
host, 2026-10-01). No platform half: this feature needs no Kotlin/Swift, unlike 012 — the roles are text,
the voices are the ones the engine already offers.

**Primary Dependencies**: none added. `flutter_tts ^4.2.3` (the engine, the per-utterance voice and
`getVoices`), `shared_preferences ^2.5.5` (the store), `intl ^0.20.3` + `flutter_localizations`
(the four locales), `path_provider ^2.1.6` (008's content files — untouched), `file_selector ^1.1.0`
(012's picker — untouched). The plan's FR-023 assertion is "no line changes in the dependency block".

**Storage**: one new `shared_preferences` key, `content_roles`, holding a JSON object keyed by the
content's own id — `{type, removed: [{name, at}], voices: {<role>: {name, locale}}}` — read tolerantly
(a malformed entry is ignored, never repaired) and written only when the type, a removal or a pick
changes. 008's `index.json` and its schema version stay exactly as they are (spec FR-021, A1): the roles
are not part of the content.

**Testing**: `flutter test --concurrency=2` (the emulator may be up; D9 of 012's research is why the
concurrency flag is in every command) and `flutter analyze` on this host. New unit/widget files follow
the tree's own placement: `test/dialogue_test.dart` (the paragraph scan, the prefix rule and the Format
transformation),
`test/speech_resolver_test.dart` (one function, two modes — including that standard is today's call),
`test/role_assignment_test.dart` (the ranking and its determinism), `test/role_store_test.dart` (the
store's tolerance), `test/reading_view_dialogue_test.dart` (the page's entry, the role list, the mode
switch, the editor's Format button), `test/video_dialogue_test.dart` (a dialogue's plan and its voices). The
device rows live in [quickstart.md](./quickstart.md) and are walked by hand on `emulator-5554`.

**Target Platform**: Android is where the rows are walked (the `klhu` AVD, API 36; the reader's own phone
for the ones they run themselves). The feature itself is platform-neutral Dart, so iOS/desktop/web are
expected to work — and are *not* claimed: nothing in this feature is platform-specific, which is the
difference between this plan and 012's.

**Project Type**: mobile app — one Flutter project (`lib/` + `test/`), no new directory, no new package.

**Performance Goals**: the scan is one pass over the text and the turn list is derived, never stored; a
read of a dialogue costs the same engine calls as today's read of the same text (one utterance per
sentence, one `setVoice` before each, which the app already does per paragraph). On 008's largest
allowed content (100,000 characters, `lib/models/content.dart:21`) the scan must stay linear and the
store must not be written per turn — the store is touched only on a change.

**Constraints**: on-device only, no account/backend/network (constitution IV, FR-023); the reading page's
shipped behaviour and 011's/012's receipts must be byte-identical for a content with no stored type
(SC-005); the app never rewrites the reader's text (FR-020, A9); no age property is modelled and no
dialect is detected from the text (FR-017, A2, A3).

**Scale/Scope**: one new pure module (~180-240 lines: the paragraph scan, the tag rule, the turns, the
assignment and the Format transformation), one new store (~120 lines), one extended resolution layer, one new
page entry (a chooser + a role list), one changed picker screen, one new button in the existing edit toolbar,
~18-25 new ARB keys across four locales, and six new test files. No new screen, no new state in the page's
state machine, no dependency.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 (below).*

- **I. Flutter single codebase** — PASS. Pure Dart, no platform code, no fork: the whole feature is one
  codebase's own text and the engine's own voices. (009/011/012 have platform halves; this one has none,
  and the plan says so rather than leaving the reader to wonder.)
- **II. Spec-driven (NON-NEGOTIABLE)** — PASS. `specs/014-dialogue-reading/spec.md` is approved by the
  reader's own answers of 2026-10-01 (Clarifications); this plan and `tasks.md` follow it, and no
  requirement is minted here.
- **III. Test-first (NON-NEGOTIABLE)** — PASS by construction, with the discipline the tree already
  uses: the six new test files are written RED before their code, and each user story keeps an
  independent acceptance test — US1's is the read's own utterance log, US2's the assignment in the same
  log, US3's a removal surviving a restart, US4's a rendered video's frames and voices
  (quickstart rows 3, 8, 12, 15).
- **IV. On-device first** — PASS. No network, no account, no analytics, nothing uploaded: the roles are
  the reader's text and the voices are installed on the phone.
- **V. Simplicity (YAGNI)** — PASS, and this is where the plan's main judgment call lives. The feature
  could be built as a second reader path for dialogues, a `Role` field on every speech/utterance, or a
  new screen; it is built as *one function with two modes* returning the type the app already passes
  around (D1/D2). The complexity table below is empty on purpose.

**Post-design re-check (after Phase 1)**: the design settled on one resolution (D1), a paragraph scan (the
app's own `paragraphRanges`, D2) whose only state is the reader's own removals (D4), a store with no schema
coupling to 008 (D6) and an assignment that is computed, not stored (D5). No principle is bent, no violation needs justifying, and
the one place a second code path would have been tempting — the video — is a call-site substitution
(D9). The re-check therefore finds the same answers as the gate.

## Project Structure

### Documentation (this feature)

```text
specs/014-dialogue-reading/
├── spec.md                        # reviewed (specify + clarify)
├── plan.md                        # this file
├── research.md                    # measured facts, decisions D1–D12, spike S1
├── data-model.md                  # TextType, Turn, Role (+its removal), the assignment, RoleSettings
├── quickstart.md                  # 33 validation scenarios, tagged [unit]/[device]/[structural]
├── checklists/
│   └── requirements.md            # the spec-quality gate (all items ticked)
├── scripts/                       # created at the implement stage
│   ├── klhu_walk_dialogue.py      # the device rows, one function per scenario, argv dispatch
│   └── klhu_dialogue_fixture.txt  # the reader's own four-role example, pushed for the device rows
├── tasks.md                       # created by the tasks stage
└── breakpoint.md                  # created at the implement stage (PASS/FAIL rows + divergences)
```

No `contracts/` for this feature: the interfaces it changes are in-process Dart types the app already
owns (`ParagraphSpeech`, `VoiceChoice`), and the only external contract it touches — the engine's
voice/locale handshake — is unchanged. 012 needed a `contracts/` directory because it invented a
channel protocol with Kotlin; inventing one here would be ceremony.

### Source Code (repository root)

```text
lib/
├── dialogue.dart            # NEW — the paragraph scan, the prefix rule, the turns, the auto-assignment, the Format transformation (pure)
├── role_store.dart          # NEW — the per-content settings store (prefs, keyed by the content's id)
├── speech_resolver.dart     # NEW — one resolution, two modes: standard → today's call, dialogue → turns
├── language.dart            # the rule table, per-utterance detection, resolveParagraphSpeeches (read; the
│                            #   standard mode IS this call — the new resolver delegates to it)
├── segmenter.dart           # sentences and paragraphs (read, unchanged)
├── reader_service.dart      # speakParagraphs: consumes the same List<ParagraphSpeech> (unchanged), and
│                            #   the per-utterance voice apply stays the app's only engine-voice mechanism;
│                            #   its per-read log line gains the role and the voice (the device rows, D10)
├── voice_store.dart         # the per-language pick (read; still the assignment's reference, FR-013)
├── voice_picker_screen.dart # CHANGED — an optional title and a "follow the assignment" first row
├── content_list_screen.dart # CHANGED — the content's delete also clears its role settings (ripple note 6)
├── reading_view.dart        # CHANGED — the text type entry, the role list, the mode switch, the editor's Format button (no new state)
├── video_timeline.dart      # CHANGED at one call site — the shared resolver instead of its own call
├── video_renderer.dart      # CHANGED — the slot log line gains the role (the video row's evidence)
├── models/voice_mapping.dart# read: gender, and deliberately no age and no dialect row (A2; the dialect
│                           # comes from the voice's own locale — corrected 2026-10-03)
└── l10n/app_{en,zh,zh_Hans,es}.arb  # CHANGED — every new string, in all four

test/
├── dialogue_test.dart            # NEW — the prefix rule, the turns, the spans, the edge cases, the Format transformation
├── speech_resolver_test.dart     # NEW — one function, two modes; standard returns today's call
├── role_assignment_test.dart     # NEW — the ranking, distinctness, determinism, the too-few-voices bound
├── role_store_test.dart          # NEW — the store's shape and its tolerance
├── reading_view_dialogue_test.dart # NEW — the entry, the role list, the removal, the mode switch, the Format button
├── video_dialogue_test.dart      # NEW — a dialogue's plan: voices per turn, no tag in any frame text
└── (the shipped test files are NOT re-cut: the page tests assert per label, never the toolbar's set —
   ripple note 1 carries the check — so every new assertion lives in the six files above)

specs/014-dialogue-reading/
└── scripts/                      # only if a device row needs a driver: `klhu_walk_dialogue.py`, built on
                                  #   012's helpers (adb_shell one string per command, row dispatch, PASS/FAIL)
```

### The tag rule, in one reference table (FR-004 — the same table is in research D3)

```text
paragraph head := the paragraph's first line, its leading spaces trimmed
tag            := '{' name '}'   — ASCII braces only
name           := the characters between the braces, trimmed of surrounding spaces; at least one, never
                  spanning a line, ended by the first '}'; spaces allowed, any length
separator      := spaces, an optional single ':' or '：', spaces — part of the prefix, not of the content
turn           := the paragraph whose first line carries the tag; a tag anywhere else is ordinary text
turn content   := everything after the separator on the first line, plus the paragraph's own remaining
                  lines, trailing whitespace trimmed
```

Turns (a tag at the head of a paragraph): `{May} : hello`, `{May}: hello`, `{May} hello`, `{May Anne} hello`,
`{阿明} 你好`.
Narration (a paragraph whose first line carries no tag): `12:30`, `https://example.com`, `他说：我来了`,
`May：系啊。`, `{May : hello` (no closing brace), `{} hello`, `｛May｝ hello` (full-width braces).
A tag inside a paragraph is ordinary text: `{阿明} 你好。` and `{阿芳} 我很好。` in one paragraph are 阿明's
single turn, spoken as `你好。{阿芳} 我很好。`, braces and all — the editor's Format action (FR-024) is how the
reader turns that into two paragraphs.

`lib/dialogue.dart` is this table's only implementation (`turnsOf`, plus D12's `formatForDialogue`, which
shares the one grammar) and `test/dialogue_test.dart` its only other reader — quickstart rows 1-4 are the
table's own receipt.

**Structure Decision**: the layout the thirteen earlier specs already use. Nothing new is invented at
the top level: a pure module beside `language.dart`/`segmenter.dart` (the two it is shaped after), a
store beside `video_record.dart`/`voice_store.dart`, and changes confined to the reading page, the
picker and two log lines. The one structural claim a reviewer should check is the *third* new file —
`speech_resolver.dart` is not 012's god-file pattern; it is the single place a mode is read, so that
"标准 is today's call" is a one-line statement rather than a claim about two code paths.

### Ripple notes

1. **The page's own tests do *not* enumerate the toolbar's items — this corrects the plan's earlier
   claim, checked before `tasks.md` was written.** The only offered/not-offered assertions in the tree are
   `test/reading_view_video_test.dart:321-339` (`offeredBy` / `expectOffered` / `expectNotOffered`), and
   each names ONE label; the four page tests 012's ripple note 2 listed iterate the labels they *tap*
   (`test/reading_view_test.dart:671` positions four controls against the system bar,
   `test/reading_view_pause_test.dart:411` taps a pause/resume sequence) and never the set of actions. No
   test counts `IconButton`s or reads `AppBar.actions` (`grep -rn "byType(IconButton)\|actions.length"
   test/` → only the picker's own check icon). So the new app-bar entry and the fourth editor button
   re-cut nothing and the shipped page tests stay green untouched — a stronger SC-005 than a re-cut, and
   the new assertions live in `test/reading_view_dialogue_test.dart`. One file could still move, and it is
   not a page test: `test/content_list_test.dart`, if the delete's new role-store clear turns out to need
   an injected store — `lib/content_list_screen.dart:108` reaches the one store it has as `widget.store`,
   so a `RoleStore()` clear needs no new construction. Re-check that at implementation and report it if it
   is otherwise.
2. **`resolveParagraphSpeeches` has two call sites today** (`lib/reading_view.dart:910`,
   `lib/video_timeline.dart:103`) — three test files also call it directly, which is why the function
   itself stays. Both call sites move to the shared resolver; `lib/language.dart`'s own function
   stays for its tests and for the standard path, so nothing about today's behaviour is re-typed.
3. **`test/language_test.dart`'s own `resolveParagraphSpeeches offsets` group (`:115-140`) asserts the
   standard resolver's offsets** — it stays green untouched, which is the spec's SC-005 expressed as a
   test rather than as a promise; the other two direct callers
   (`test/reading_view_mixed_test.dart:80-110`, `test/spanish_localization_test.dart:226-268`) are in the
   same position. The new resolver's own tests assert that standard mode returns exactly what that
   function returns (a relationship, not a snapshot).
4. **The video's slot log line and its `span=` field** are what 012's device row 32 reads to decide
   which sentence is on a frame. In dialogue mode the slot's `paragraph`/`sentence` now count *turns*;
   the row's checks are derived from the plan (`slot=i/n`, `text=n` read through `span=`), so they hold
   — and the row must be re-run on a dialogue content to prove it, which quickstart row 14 does.
5. **The role picker's "follow the assignment" row is a new affordance** in a shipped screen whose tests
   assert its rows (`test/voice_picker_test.dart`, `test/voice_picker_semantics_test.dart`). The row is
   added *only* when the picker is opened for a role (the language-level picker keeps exactly today's
   list), so those tests keep their meaning; the new one is exercised by
   `test/reading_view_dialogue_test.dart`.
6. **The content delete must clear the role settings** (`lib/content_list_screen.dart:108`, where a
   content is actually deleted). The shipped app forgets a kept video lazily
   (`lib/video_record.dart:93-95`); the role store keeps the same lazy tolerance as a belt, but the
   spec's FR-021 asks for removal, so the list screen does it at the delete.
7. **Two log lines gain a field** — the reader's (`klhu speak …`) and the renderer's (`klhu render slot=…`)
   — because they are the device rows' only witness of *which voice* spoke (a UI dump cannot show a
   voice; 012's research D9 recorded the same reasoning). Additive fields, so the existing rows' regexes
   keep working.
8. **011's and 012's receipts are re-run, not assumed**: their quickstart rows that touch the read and
   the video are in this plan's quickstart as structural rows (SC-005, SC-008), because the change lands
   in the two functions those features are built on.
9. **There is nothing to migrate.** The dialogue work has not started and no content in the reader's
   library carries either shape (the reader, 2026-10-02: *对话还没有开始。现有的库不是问题*), so the tag's
   form is a green-field choice: SC-005's invariance is proven by the tests, not by converting existing
   text — and a content that carries no tag reads the same in both types by construction.
10. **A paragraph is already the app's own unit** (`lib/segmenter.dart:71-108`; a single `\n` inside one
    does not break it), so the turn scan adds no segmentation of its own and `test/segmenter_test.dart`
    stays untouched: what changed on 2026-10-03 is that `turnsOf` maps those ranges instead of splitting
    lines. A turn therefore carries its own `\n`, which the sentence cutter already treats as whitespace
    (`lib/segmenter.dart:53-59`) — the reason a multi-line turn needs no new speech path and 011's
    highlight needs no new span rule.
11. **The editor's toolbar is three buttons today** (`lib/reading_view.dart:2064-2083`: Undo / Save / Done)
    and the Format button is the fourth. It assigns `_editController.value` once — one undo entry, the way
    `_enterEdit` makes the loaded text the stack's first state (`:614`) — and is disabled when
    `formatForDialogue(text) == text`, the pattern Undo already uses (`:2069`). It saves through 008's own
    path (Save or Done) and its refusals are 008's: a press that pushes a text past `kMaxContentChars`
    (`lib/models/content.dart:21`) fails exactly as an ordinary over-long edit fails. This is the feature's
    only write to the reader's text, so its test is the widget test that reads the controller back
    (quickstart rows 32-33).

## Complexity Tracking

> No Constitution Check violations: the table is empty on purpose.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |
