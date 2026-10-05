# Research: Multi-Role Dialogue Reading

**Feature**: `014-dialogue-reading` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Measured facts

Everything a decision below rests on, checked against this checkout on 2026-10-01 (`file:line` is the
evidence; nothing here is from memory):

| Fact | Where it was verified |
|---|---|
| Dart `^3.13.3`, Flutter 3.47.5 stable | `pubspec.yaml`; `flutter --version` (2026-10-01) |
| Dependencies: `flutter_tts ^4.2.3`, `shared_preferences ^2.5.5`, `intl ^0.20.3`, `path_provider ^2.1.6`, `file_selector ^1.1.0`; dev: `flutter_test`, `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4` | `pubspec.yaml` |
| The read's units reach the engine as `List<ParagraphSpeech>`; the reader service cuts each into sentences itself | `lib/reading_view.dart:910` → `lib/reader_service.dart:337`, `_sentencesOf` at `:357-377` |
| A `ParagraphSpeech` carries `{text, language, voice, start, end}` — offsets into the content | `lib/reader_service.dart:63-85` |
| The video resolves its sentences through the *same* function | `lib/video_timeline.dart:96-105` (`videoSentencesFrom`) → `videoSentencesOf` at `:64-86` |
| Language detection is a rule table: CJK → `zh-Hans`, Spanish letters/two function words → `es`, else `en`; per *paragraph*, on the paragraph's full text | `lib/language.dart:29-74`; the ranges themselves come from `lib/segmenter.dart:71-108` (blank lines) and `:33-69` (delimiters) |
| A **paragraph** is the app's own unit and already the unit `resolveParagraphSpeeches` iterates: blank-line-separated (`\n[ \t]*\n+`), a single `\n` inside one does not break it, and the sentence cutter treats a line break as whitespace between sentences | `lib/segmenter.dart:71-108` (`paragraphRanges`), `:33-69` (`sentenceRanges`, the whitespace skip at `:53-59`); `lib/language.dart:117` |
| One voice per language is persisted per device: keys `voice_en` / `voice_zh_Hans` / `voice_es` | `lib/voice_store.dart:21-45` |
| Cantonese is a *voice* under Chinese, not a language: the Chinese list's locales are `['zh','cmn','yue']` | `lib/reader_service.dart:275-285`; 007's own decision |
| The engine is told the *picked voice's own locale* before each utterance — which is what makes a voice win over the list's default | `lib/reader_service.dart:458-469` (`_applyVoice`), called once per utterance in `_run` at `:465` |
| Voice metadata the app holds: 96 rows; `gender` recorded from two independent measurements where both exist (one voice — `en-us-x-tpc` — has none); **`dialect` is declared but set by NO row — corrected 2026-10-03 by the implementation**, deliberately (a Cantonese voice is *named* by its dialect, so the field would only repeat the name — 007 FR-010), so the assignment reads the dialect from the voice's own LOCALE instead; **no `age` field at all, with the reason written down** | `lib/models/voice_mapping.dart:1-56`, and the counts by language: 14 Mandarin ids → 7 names (3 female, 4 male), 11 Cantonese ids → 6 names, 18 Spanish ids → 11 names, 51 English ids → 28 names |
| The voices actually installed are read back from the engine at read time | `lib/reader_service.dart:507-510` (`voicesForAll`) |
| Per-content stores key on the content's own id: `read_position_<id>` | `lib/read_position_store.dart:45-49` |
| `SharedPreferences` JSON-keyed-by-content precedent: one key `video_record`, tolerant reads, written only by keeping | `lib/video_record.dart:69-180` (`key` at `:78`, `_entries` at `:142`, `_remove` at `:174`, the gone-file case at `:93-95`) |
| The content key the page holds is `preset.id` / `entry.id` / `saved.id` | `lib/reading_view.dart:447`, `:665`, `:768` |
| `SavedContent` carries `updatedAt` (bumped on every save) and a versioned index with a repair path | `lib/models/content.dart:40`, `:16` |
| The largest content the app accepts | `lib/models/content.dart:21` (`kMaxContentChars = 100000`) |
| A content is deleted at one place | `lib/content_list_screen.dart:86-108` (`_confirmDelete` → `store.delete(entry)` at `:108`) |
| The shipped confirmation dialog shape (Cancel + filled confirm, ARB-keyed) | `lib/reading_view.dart:735-753` (`_confirmDiscard()`; the `AlertDialog` opens at `:738`) |
| The shipped small either/or chooser shape | `lib/reading_view.dart:1400` (the video aspect dialog, `videoAspectTitle`) |
| The per-language voice picker screen, reached from the page | `lib/voice_picker_screen.dart:18` (`VoicePickerScreen`), opened at `lib/reading_view.dart:1939` |
| The picker lists voices and saves a pick; **it has no row that clears one** | `lib/voice_picker_screen.dart:36-145` (`_onTap` saves; no default/clear row) |
| The l10n mechanism: `arb-dir: lib/l10n`, template `app_en.arb`, `output-localization-file: app_localizations.dart`; four ARBs (en, zh, zh_Hans, es) with generated Dart committed | `l10n.yaml`; `lib/l10n/` |
| The tests that will move: **none of the shipped files** — corrected 2026-10-03, see plan ripple note 1 | the page tests assert per label (`test/reading_view_video_test.dart:321-339`), never the toolbar's set; `test/language_test.dart:115-140` and the two other direct callers keep calling `resolveParagraphSpeeches` |
| 37 test files exist today, including 012's own five | `ls test/*.dart` |

## Decisions

Each decision is written as what was chosen, why, and what else was considered — the shape 012's
research uses, so a reader can argue with one entry at a time.

### D1 — Roles resolve *into* `List<ParagraphSpeech>`, the one interface all three consumers already share

**Decision**: a new module `lib/speech_resolver.dart` exposes one function —
`resolveSpeeches({content, start, end, mode, roles, loadVoice, loadRoleVoice, assignment})` — that
returns `List<ParagraphSpeech>`. In 标准 it returns exactly what `resolveParagraphSpeeches` returns
today (it calls it); in 多人对话 it returns one `ParagraphSpeech` per turn, whose `text` is the turn's
content, whose `language` is that content's detected language, whose `voice` is the role's pick or its
assigned voice, and whose `start`/`end` are the content's offsets (the prefix is outside them). The
page (`lib/reading_view.dart:910`), the reader service (unchanged: it already takes this list) and the
video (`lib/video_timeline.dart:103`) all call it.

**Rationale**: the type is the only thing the three consumers agree on, and it is already the app's
notion of "a thing to read". Nothing downstream learns that roles exist: the reader service still cuts
each speech into sentences (`_sentencesOf`), the page's highlight still works from `start`/`end`, 010's
resume offset is still a content offset, and 012's video still receives `{text, language, voice,
start, end}` per sentence. The spec's FR-019 ("one shared resolution") is then a property of the type
system, not a promise in prose.

**Alternatives considered**:
- *A second reader path for dialogues* (a `DialogueReaderService`, or a branch inside `speakParagraphs`).
  Rejected: two paths that must produce the same sentences, the same highlight and the same video — the
  exact drift 012's row-32 re-cut was spent fixing once.
- *A `role` field on `ParagraphSpeech`/`_Utterance`/`VideoSentence`*. Rejected: three types, every
  consumer and every test fake in the suite (`test/reading_view_*.dart` define their own `speakParagraphs`
  fakes) changes for a field the reader's eye never needs — the role is the *voice*, which the type
  already carries.
  **Partly reversed 2026-10-03 by the implementation, for D10's sake**: what makes that cost real is the
  field being *required*. It is optional instead — `ParagraphSpeech.role` is set by the resolver alone, null
  for narration and for every 标准 speech, and `_Utterance` passes it through for the log line — so the
  rejection's own reasoning (every consumer changes) does not apply and D10's evidence line is exact. The
  suite's fakes are untouched by it (513 tests green). `VideoSentence` is not touched here; whether the
  video's slot line needs the role is T020/T021's own call.
- *Roles resolved inside the reader service* (it has the sentences and the voices). Rejected: the video
  needs the same answer without a reader service, and the page's own highlight needs the spans before
  anything is spoken.

### D2 — A turn is a paragraph; the blank line is its boundary, and the scan is one pass
*(the form settled 2026-10-03, replacing this entry's own "a turn is a line")*

**Decision**: `lib/dialogue.dart` derives the turns from the paragraphs the app already computes —
`paragraphRanges(content)` (`lib/segmenter.dart:71-108`), the same ranges `resolveParagraphSpeeches`
iterates today (`lib/language.dart:117`) — one turn per paragraph, offsets preserved:

- A paragraph whose **first line's head** matches the prefix rule (D3) opens a **role turn**: `{role,
  contentStart, contentEnd}`, where `contentStart` is after the tag, its optional colon and the spaces that
  may follow, and `contentEnd` is the paragraph's end (trailing whitespace trimmed).
- A paragraph whose first line has no prefix is one **narration turn** (`role == null`): the spec's
  FR-009/A8 — it is never silently attributed to the speaker above it.
- A **blank line** is the only boundary: nothing else opens or closes a turn (the paragraph's own end and
  the content's end are the other two).
- A turn's content is the reader's own lines, so it contains `\n`; the sentence cutter already treats a
  line break as whitespace between sentences (`lib/segmenter.dart:53-59`), which is why a turn of several
  lines is read sentence by sentence with no new mechanism.
- A role's turns are the turns that name it; the role's *order* is first appearance.

**Rationale**: the reader's correction of 2026-10-03 — *one role turn read at least one sentence … I like
to use paragraph to separate the role turn … a paragraph should starts with a role tag, otherwise it's a
narration* — and it is also the app's own notion: `paragraphRanges` is the unit the read already resolves
and the video already counts, so a turn is now that unit instead of a second, finer division the reader
never wrote. The example in the spec's Input block puts a blank line between its turns, and a script is
written that way too; what changes is that a turn may hold the whole paragraph — a wrapped sentence, or
three sentences — instead of one line of it.

**Alternatives considered**:
- *One line = one turn* (this entry's form until 2026-10-03). Rejected by the reader: a paragraph written
  as three lines was three turns, so a role's own paragraph could not be one turn at all, and a sentence
  wrapped across two lines became two.
- *A tag inside a paragraph opening a new turn* (one of the options the reader was given). Rejected: it
  re-attributes lines the reader did not separate with a blank line. It would make a chat log pasted
  without blank lines work, at the price of a paragraph's own lines not belonging to the paragraph's own
  speaker. The reader's answer is D3's.
- *Continuation appending* (an unprefixed line belongs to the previous turn — the `>>` convention of
  screenplays). Still rejected as a *rule*: it would make an unprefixed line's fate depend on the line
  above it *across* a blank line. Inside one paragraph it is exactly what the reader asked for, and there
  the paragraph's own head decides the speaker, not the turn above.
- *Punctuation-based segmentation* (quotes as the delimiter): the spec's format is a braced tag; quotes
  are not part of it, and half the world's dialogue has no quotes.

### D3 — The prefix rule: a braced tag, and the reader's confirmation as the guard

**Decision** (FR-004, in one place, table-driven like the language rules; the tag's own form settled by the
reader on 2026-10-02, the **place the rule is read** on 2026-10-03):

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

so `{阿明} 你好`, `{阿明}: 你好`, `{阿明} : 你好` and `{May Anne} hello` are the heads of turns, and a
twenty-character name is a name. What is **not** a turn is a paragraph whose first line carries no braced
tag: `12:30`, `https://…`, `时间：8 点`, `他说：我来了`, a bare name with a colon, `{阿明` (no closing brace)
and `{}` at a paragraph's head are narration, and nothing is lost. A tag typed with full-width braces
(`｛阿明｝`, a Chinese IME's own default) is narration too: the reader chose the single ASCII pair.

**A tag anywhere else is ordinary text** (the reader's second answer of 2026-10-03, replacing this entry's
first one): `{阿明} 你好。` and `{阿芳} 我很好。` on two consecutive lines of one paragraph are **one** turn —
阿明's — spoken as `你好。{阿芳} 我很好。`, braces and all. Only the paragraph's head is a prefix; nothing else
in the reader's text is removed, hidden or repaired, so the format is a contract the reader keeps rather than
a shape the app fixes up. The consequence to accept is the reader's own choice: a missing blank line is heard
out loud rather than silently dropped, and the remedy is D12 — one Format press in the editor inserts the
blank lines and changes nothing else.

**Rationale**: the rule has to be mechanical (it runs on every paragraph of every dialogue read), and the
confirmation (D4) is where its mistakes are corrected. The first draft guessed the speaker from a colon
and bounded the name (≤8 characters, no whitespace) *because* a colon is also punctuation — the clock,
the URL, 他说：. The reader replaced that guess with an explicit tag, which bounds the name exactly, needs
neither a length bound nor a whitespace ban, and deleted the whole punctuation-collision class with it.
What braces cannot settle is what the reader *meant* by them (`{laughs} hello`), and that is the
confirmation's job, not the rule's; likewise, only the reader can know that two consecutive tagged lines
were meant to be two turns, and the blank line (or one Format press, D12) is how they say so.

**Alternatives considered**: a colon with a length bound (the first draft — every punctuation colon had to
be proposed and then removed by hand, and a long name or a name with a space in it was silently not a
speaker); `#name#`, `%name%`, `(name)`, `$name$` (measured over a 15,356-line prose corpus: 1,174 lines
start with `#` — Markdown headings — 384 with `(` — ordinary punctuation, and the reader's own phrasebook
carries "(informal)" — and 15 with `$`; braces start 6, all code samples; the reader's answer of
2026-10-02); requiring the name to be a known word (needs a dictionary, and refuses names like 阿明 or
May — the example's own); requiring two occurrences of the name (refuses a role with one turn, which the
spec's A4 says is still a role); requiring the name to be listed up front (the reader's text has no such
list); a second tag inside a paragraph starting a new turn (it decides a speaker the reader did not
separate, D2); stripping a tag out of the spoken content — this entry's own first form of 2026-10-03,
replaced the same day, because it makes the app the judge of which braces the reader did not mean
(2026-10-03 → D12's Format press is the reader's own answer instead).

### D4 — The roles are proposed; the removals are the only state, and they carry the text's version

**Decision**: the proposal is computed, never stored: `roles(content)` returns the distinct names a
paragraph's head names (D2/D3), in first-appearance order, each with its turn count (its paragraphs). The
reader's **removals** are stored per content as
`{name, at}` where `at` is the content's `updatedAt` at the time of the removal; a removal is honoured
only while the content's current `updatedAt` equals its own `at`. When the text is saved, `updatedAt`
moves (008), so every removal expires with the edit and the app proposes the name again — the spec's US3
scenario 4. Reading never requires the confirmation: with no stored settings at all, the detected set is
used (FR-008).

**A shipped pre-set is the exception, and it is what the page got wrong first (corrected 2026-10-03 by
the implementation)**: a pre-set has no text of its own that can change — editing one saves a *new* content
with its own id (`lib/services/content_store.dart::saveEdited`) — so its version is the epoch constant, not
the seeded entry's `updatedAt`. Two of the page's three opening paths agreed on that and one
(`_loadEntry`, the pick-from-the-list path) used the entry's `updatedAt` instead, so a removal made after
opening the content from the list was out of force in the next session, and vice versa. The removal test
found it; the fix is the one line that made all three paths agree (T017).

**Rationale**: derived state cannot go stale and cannot be edited into an inconsistent shape; the
reader's own decisions (a false name is not a role) are the only thing worth storing, and tying them to
the text's version is what makes "the proposal follows the text" true without a diff of the text. It
also means a content whose settings are unreadable still reads — the failure mode is "the app proposed a
name you had removed", never "the app cannot read this".

**Alternatives considered**: storing the confirmed role set (it duplicates what the text says; an edit
leaves a stale set); storing a diff or a content hash (more machinery for the same effect, and a hash of
100,000 characters is a cost the version already pays); never re-proposing a removed name (contradicts
an edit that genuinely makes it a speaker again).

### D5 — A role's voice: the reader's pick, else an assignment computed from the live voice list

**Decision**: the effective voice of a turn is, in order: (1) the role's own pick, if the reader made
one; (2) the role's **assigned** voice from the automatic assignment below; (3) the per-language pick
(002) — which (2) has already used as its reference; (4) nothing, i.e. the engine's own default. The
assignment is computed at read time from the voices the engine lists (`voicesForAll`) plus the app's own
metadata, ranked:

1. **same language** as the turn (always the first filter — a Chinese turn is never given an English
   voice),
2. **the same dialect** as the reader's own pick for that language, when that pick has one (so a reader
   who reads in 广东话 gets a Cantonese dialogue) — **corrected 2026-10-03 by the implementation**: read
   from the voices' own LOCALES (`yue-HK` against `zh-CN`/`cmn-CN`), because `VoiceMapping.dialect` is
   declared but set by no row, deliberately (a Cantonese voice is *named* by its dialect, so the field
   would only repeat the name — 007 FR-010); the locale is the signal the engine itself is given,
3. **the reader's own picked voice for that language, first** — it satisfies 1 and 2 perfectly and is the
   voice the reader already chose to hear this text in,
4. **a recorded gender that differs from the roles already placed in this read** (so the second and third
   roles do not sound like the first — see the honest limit below),
5. a stable tie-break on the voice's own name, so the ranking is total and the result is reproducible.

The assignment is **never stored**: only picks are. The same device, the same content and the same text
yield the same assignment twice (FR-014); a voice uninstalled changes the assignment, which is correct —
the app does not hold a reference to a voice that is gone.

**Honest limit, and the one thing here that the reader should argue with**: nothing in the text says
which role is meant to be male and which female, so the assignment cannot honour "同性别" literally — it
answers it with (4): roles of the same language are placed on voices whose *recorded* genders differ,
which is what the reader's own example wants (旁白/阿明 male-ish, May/阿芳 female-ish) without the app
claiming to know who is who. The identity of each role's voice is always visible in the list and always
the reader's to change (FR-012/FR-016).

**Rationale**: the reader's own sentence is 优先选择同语言，同性别，同方言 — "prefer the same language,
the same gender, the same dialect" — and "the same as what?" has exactly one honest answer: the same as
the voice the reader already chose for that language. Everything else (a gender per role, a dialect per
role) is not in the text and must not be invented (A2/A3).

**Alternatives considered**: assigning by the *engine's* order (the list's order is not documented and
changes between devices — not reproducible); storing the assignment (a stale reference to a voice that
may no longer exist, and a second thing to migrate); giving every role the same voice unless the reader
picks (the feature's whole point is a dialogue that sounds like one); a per-role gender claim (a guess
the repo's own voice data refuses to make — `lib/models/voice_mapping.dart:18-23`).

### D6 — The settings store: one prefs key, the content's id, tolerant reads (012's shape)

**Decision**: `lib/role_store.dart` owns one `shared_preferences` key `content_roles`, whose value is a
JSON object keyed by the content's own id:

```json
{ "<content id>": { "type": "dialogue",
                    "removed": [{"name": "他说", "at": "2026-10-01T09:12:44Z"}],
                    "voices": {"阿明": {"name": "yue-hk-x-yud-local", "locale": "yue-HK"}} } }
```

Reads are tolerant exactly as `VideoRecordStore`'s are (a malformed entry is ignored, never repaired, and
never takes the others down); the key is written only when the type, a removal or a pick changes; the
entry is removed when the content is deleted (`lib/content_list_screen.dart:108`) and, as a belt, when a
lookup finds no such content. `type: "standard"` is stored as *absence* of the key's `type` field, so a
content that was never touched costs nothing.

**Rationale**: 012 already established this shape for per-content state that is not part of the content
(`lib/video_record.dart`), and 008's index is a versioned schema whose repair path exists for *content*
problems — putting role settings in it would make a broken setting a broken library.

**Alternatives considered**: a field in `index.json` (schema version bump + migration + repair semantics
for data the content does not own); one prefs key per content (`content_roles_<id>`: more keys, no atomic
read of the whole map, contradicts the sibling store); a file beside the content text (008 owns that
directory; the roles are not content).

### D7 — The role picker reuses `VoicePickerScreen`, with four additions, and the language-level picker is untouched

**Decision**: `VoicePickerScreen` gains (a) an optional `title` and (b) a `clearable` flag which renders a
first row meaning *follow the automatic assignment* (this is how a pick is cleared, spec's US2 scenario 5).
When the page opens it for a role, it passes the title of that role and the language of the role's first
turn; when it opens it for the reader's per-language pick (today's path,
`lib/reading_view.dart:1939`), it passes neither and the screen is exactly what ships today.

**Two more parameters, added 2026-10-03 by the implementation** — (c) `initialSelection` and (d)
`onPick` — because the two things D7 assumed the screen could answer itself it cannot: a role's pick does
not live in the `VoiceStore` this screen holds (it lives in `lib/role_store.dart`), so the page must say
which row is chosen and must be told where a tap goes. Without (d) a role's voice would be written as the
**language's** voice, which is exactly what FR-013 forbids. Both are absent on the language path, which
still reads and writes through `store` — and the shipped picker tests stay green *unmodified*, which is the
guard that says so.

**Rationale**: the picker already lists the right voices (including 广东话 under 中文, 007), already
previews them, already highlights the current pick and already scrolls to it. The only things missing for a
role are a way to say "no pick", a way to know which role is being answered, and a sink that is not the
language store.

**Alternatives considered**: a second picker screen (a copy of ~300 lines and a second place to fix every
future picker bug); a dropdown in the role row (loses the preview, which is the only way to choose a voice);
clearing by re-tapping the selected voice (an invisible rule, and it makes an accidental second tap a
destructive action).

### D8 — The page: one entry, two surfaces, no new state

**Decision**: the reading page gains one entry beside its existing ones (language / appearance / contents /
voice / video) that opens the content's **text type** choice (标准 | 多人对话, the shipped either/or chooser
shape) and, when the type is 多人对话, the **role list** — each role's name, its turn count, its voice and a
remove action, with the role's voice row opening D7's picker. The page's state machine is not extended: the
role list is a dialog, not a mode, and reading, pausing, resuming and editing are untouched while it is
closed. In 标准 the entry exists and shows the type alone (a content with no dialogue in it must not be
cluttered with a role list that has nothing in it).

**Rationale**: the page already owns "settings for this content" as small dialogs; a second screen would
add a navigation path and a back-stack state for something the reader touches once per content.

**Alternatives considered**: a dedicated screen (a route, a back button, and the reader's position to keep
alive across it); putting the type in the edit mode (the text type is not the text — it must not be saved
into the content or undone by the undo stack); a switch in the toolbar (a mode switch is not reversible by
a stray tap — the spec's own edge case list has a reader switching type mid-read).

### D9 — The video: one call site, and the frame's text is the turn's content by construction

**Decision**: `lib/video_timeline.dart:103` calls the shared resolver instead of `resolveParagraphSpeeches`,
and nothing else about the video changes. The prefix is not painted because it is not in `slot.text` and
not inside any span (`lib/video_painter.dart` paints the slot's own text; 012's row 32 reads text through
the `span=` field) — for the same reason 012 could withdraw the title card by deleting code rather than
adding a filter.

**Rationale**: the video's voices must be the read's (FR-018/FR-019) and the cheapest way to guarantee
that is to make them the same call. The video's own unit (one sentence per slot) is untouched, so 012's
plan, painter and rows keep their meaning.

**Alternatives considered**: passing a `roles` map into the renderer and resolving there (a second
resolution — the drift FR-019 exists to prevent); stripping prefixes in the painter (a filter for text
that need never enter a span).

### D10 — The evidence: what the device rows must be able to see

**Decision**: the reader's own log line (`klhu speak …`, `lib/reader_service.dart:481-484`) gains the role
and the voice — `klhu speak p2 s0 role=阿明 voice=yue-hk-x-yud-local "今日个天气…"` — and one line per read
prints the assignment — `klhu roles 旁白→cmn-cn-x-ccd-local(male) 阿明→yue-hk-x-yud-local(male) …` — while
the renderer's slot line gains the role (it already carries the voice's effect through the audio).
Additive, so the existing rows' checks keep working. The Format action (D12) needs no line of its own: the
editor's own text is what its device row dumps (quickstart row 33).

**Rationale**: a voice is invisible to a UI dump (012's research D9 reached the same conclusion about
which voice spoke), and the assignment is the one thing a reviewer cannot otherwise check — it must be
printed by the app, not reconstructed from the voice list by hand.

**Alternatives considered**: asserting the voice from the audio itself (pitch analysis — the repo did it
once for 007's gender table; far too heavy for a read row); trusting the picker's UI state (it shows what
the reader chose, not which voice the engine was given).

### D11 — Verification is the tree's own shape: unit files first, then one device walk, then the two receipts

**Decision**: six new test files (listed in plan.md) written RED before their code; a device walk
(`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py`, built on 012's helpers — one string per
`adb shell` command, row dispatch, `RESULT: PASS|FAIL`) whose rows are in
[quickstart.md](./quickstart.md); and the two structural rows that make the invariance claim real (011's
read receipt and 012's video receipt re-run against the changed resolution).

**Rationale**: this is the shape every earlier spec in this tree used, and the feature's risk is exactly
the shipped behaviour it must not disturb (SC-005, SC-009).

**Alternatives considered**: unit tests only (a voice assignment and a video's frames cannot be seen
there); a walk without the invariance rows (the one failure this feature can cause and a unit test cannot
catch).

### D12 — The format is the reader's; the editor's Format action is the one press that helps produce it

**Decision**: `lib/dialogue.dart` gains a second pure function, `formatForDialogue(String text)`, and the
edit mode's toolbar (`lib/reading_view.dart:2064-2083` — today Undo / Save / Done) gains one button that
assigns the result to `_editController.value` in a single assignment (so it is one undo entry) and is
disabled when `formatForDialogue(text) == text`, the pattern the Undo button already uses (`:2069`). The
function inserts `\n\n` immediately before every tag occurrence (D3's grammar, found anywhere in the text)
that is not already the head of its own paragraph, and returns the text unchanged when there is none.
Nothing else is added, removed or reordered — not a character of the reader's words.

**One refinement, settled by the implementation 2026-10-03 (data-model.md §2.a is the record)**: a tag that
already *begins* a line needs one `\n`, not two — the tag ends up under exactly one blank line either way,
and this is the smallest edit that makes it a paragraph head. Inserting the letter's two would have left the
reader an extra blank line for the common shape of turns typed on their own lines. What the reader's rule
asks for is what holds: blank lines and nothing else, the same tag grammar, one press, one undo.

**Rationale**: the reader's own ask (*add a 'Format' button in editor, so user can start a pagagraph for
inline {rolename}*) follows from the consequence of the rule they chose in the same breath: with no stripping
(D3) and no guessing, a tag in the wrong place is read out loud, so the app owes the reader exactly one cheap
way to put it right. Keeping the transformation in the pure module means the unit tests and the device row
exercise the real text, that `turnsOf` and `formatForDialogue` share the one tag grammar, and that the widget
does nothing but apply the result.

**Alternatives considered**:
- *List the offending tags first, then insert on confirmation*: a second dialog and a second decision for an
  action that is one press and one undo away from being reversed; the reader chose the single press
  (2026-10-03).
- *Insert at the cursor only*: the reader has to find every tag by hand, and the button is then hard to tell
  apart from a newline key.
- *Check only, change nothing*: leaves the reader editing by hand for a rule the app already knows.
- *Normalise the text in the same press* (a bare `名字：` → `{名字} `): the reader's answer is *不改：只插空行，
  字形一个字不动*, and D3's own measurement is why — `12:30`, `https://…` and `他说：` are exactly the lines
  such a conversion would rewrite.
- *Reformat on open or on save, or repair the text while reading*: rejected outright — it is the
  behind-the-back rewrite A9 forbids, and it would make the file the reader sees differ from the file the app
  reads.

## Spikes

### S1 — how many distinct voices does the device actually list, per language and per gender? — [device]

**Question**: SC-003 claims four roles of the same language get four distinct voices "whenever the device
lists at least N matching voices". The app's own table has 7 Mandarin names and 6 Cantonese names, but the
*engine's* installed list is the truth, and a name can be listed in both a local and a network variant (the
same voice, per the table's own note) — so the count of *distinct voices* is not the count of ids.

**Method**: a probe that prints the installed voices grouped by language and recorded gender, using the
app's own `voicesForAll` (`lib/reader_service.dart:507-510`) and the mapping table, run on the `klhu` AVD.
The answer is a table (language × gender → distinct voices) written into this file, and quoted by the
assignment's own test as the bound it is asserting (`N roles are distinct when the list has N distinct
voices of that language`).

**Why it cannot be assumed**: the assignment's whole user-visible claim (a dialogue sounds like a dialogue)
depends on how many voices the device has. If the AVD turns out to list two Mandarin voices of the same
gender, the plan's own promise has to shrink to what the device can do, and the spec's SC-003 wording
("where the device lists a voice of the same dialect and gender") is what makes that honest.

### Not a spike, because it already ships

Switching the engine's voice between utterances is not new work: `_applyVoice` runs before every utterance
(`lib/reader_service.dart:458-469`) and 002/011's mixed-language contents already switch voices mid-read,
with their own device rows green. A per-role dialogue is the same mechanism with a different `loadVoice`.

## Carried forward from the spec (not re-decided here)

The six answers of 2026-10-01 (`spec.md` → Clarifications), each of which this research *uses* rather than
re-opens: no voice age is modelled (A2 → D5's honest limit); the dialect is not detected from the text
(A3 → D3/D5's language-only detection); the prefix is mechanical with the reader's confirmation as its
guard (→ D3/D4); a turn is read sentence by sentence (→ D2's note that the reader service still cuts the
speech it is handed); the settings live per content outside 008's index (→ D6); the prefix is never inside
a span (→ D9). Plus the three of 2026-10-03, which decide what a turn *is* and how the reader produces the
format: its boundary is a paragraph (→ D2), the tag is read only at a paragraph's head and is ordinary text
anywhere else (→ D3), and the editor's Format action is the one press that helps (→ D12). If a reviewer
reverses one of those, the decision that consumes it changes with it — the dependency is named in each entry
above.
