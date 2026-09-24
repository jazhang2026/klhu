# Research: Continue Read

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

Phase 0 output. Every claim below was checked in this checkout before being written
down; the evidence column names the file and line it was read from.

## Verified environment facts (grounding)

| Fact | Evidence |
|---|---|
| Flutter 3.47.5 stable, Dart SDK `^3.13.3` | `flutter --version`; `pubspec.yaml` `environment:` |
| Baseline suite **234 tests, all green, ~6 s**; `flutter analyze` clean | `flutter test` on this checkout, 2026-09-24 |
| The button FR-001 replaces is an icon-only `IconButton`, `Icons.skip_next`, tooltip `readPageButton` | `lib/reading_view.dart:691-695` |
| The label key exists in the template ARB, all 3 translation ARBs and 4 generated classes | `lib/l10n/app_en.arb:8`, `app_zh.arb:8`, `app_zh_Hans.arb:8`, `app_es.arb:8`; `lib/l10n/app_localizations_en.dart:28`, `_es.dart:28`, `_zh.dart:28`, `_zh.dart:182` |
| The generated localization Dart files are tracked in git and `flutter gen-l10n` is idempotent (re-running with unchanged ARBs produces no diff) | `git ls-files lib/l10n`; `flutter gen-l10n && git status --short lib/l10n` → empty |
| An existing test already enforces ARB parity **in both directions** (a dropped template key may not survive in a translation file) | `test/l10n_keys_test.dart:34-60` |
| The 30 existing references to the literal `'Read page'` live in 5 test files (branding 1, edit 9, mixed 4, pause 9, reading_view 7) | `grep -rc "Read page" test/*.dart` |
| Tap already resolves a **sentence**, long-press a **paragraph**, then stops speech and paints the yellow highlight; nothing is spoken until a button is pressed | `lib/reading_view.dart:387-413`; `lib/segmenter.dart:148-152` |
| Segment resolution is a pure function of `(text, offset)` with a nearest-boundary fallback for whitespace taps | `lib/segmenter.dart:113-152` |
| "Page" is currently the **whole text**: `pageRange(text) = TextSegment(0, text.length, page)` | `lib/segmenter.dart:110-111` |
| The page read is `_readRange(0, content.length, track: true)`; the same range path serves sentence, paragraph and page | `lib/reading_view.dart:425-428`, `:415-423` |
| A read resolves **per-paragraph** speeches (language detected on the whole paragraph, text clipped to the requested range) | `lib/language.dart:63-87` |
| Tracking paints each spoken paragraph through `onParagraphStart`; a stale read generation is ignored | `lib/reading_view.dart:446-465` |
| The empty-range case today sets a **hardcoded English** hint `'Nothing to read.'` | `lib/reading_view.dart:442-445` |
| Persistent key/value state is `shared_preferences` 2.5.5, one key per setting, `'<a>\|\|<b>'` value grammar, malformed value ≡ absent | `lib/voice_store.dart:21-44`; `lib/models/language_preference.dart:6,31,41`; `pubspec.lock` |
| The app awaits `SharedPreferences.getInstance()` before `runApp`, so the store is available on the first frame | `lib/main.dart:12-14` |
| Widget tests already mock prefs globally | `test/reading_view_test.dart:96` (`SharedPreferences.setMockInitialValues({})`) |
| Widget tests drive real taps/long-presses on the RichText and record what was spoken through a fake `Reader` | `test/reading_view_test.dart:101-106,384,432`; fake at `:53-62` |
| The content library's index is versioned and **any other version takes the repair path** (file moved aside, library re-seeded from the catalog) | `lib/models/content.dart:16`, `:198-202`; `lib/services/content_store.dart:189-204` |
| Text mutations happen only in `ReadingView` (Edit→Done, Save); the list screen only deletes | `lib/reading_view.dart:234-262`, `:347-369`; `lib/content_list_screen.dart:143-146` |
| The first screen can be the catalog fallback with **no entry loaded** (`_loaded == null`), yet the text is a real preset with a stable id | `lib/reading_view.dart:132-149`; `assets/content/presets.json` → `preset_en_sample`, `preset_zh_sample`, `preset_es_sample` |
| Preset ids match `[a-z_]+` — safe as a prefs key suffix | `assets/content/presets.json` |
| `flutter_tts` 4.2.5 is the resolved version; its Android side **never logs the utterance text** (`private fun speak(text: String, …)` at `FlutterTtsPlugin.kt:664`, no `Log` call carries `text`) | `~/.pub-cache/hosted/pub.dev/flutter_tts-4.2.5/android/src/main/kotlin/com/eyedeadevelopment/fluttertts/FlutterTtsPlugin.kt` |
| No CI in this repository, so nothing regenerates or re-runs anything automatically | `.github/` contains only `skills/` |
| 005's shipped pause/resume resumes at **paragraph** granularity, and that was device-validated | `specs/005-voice-pause-resume/breakpoint.md:108` ("Resume is paragraph-granular: the interrupted paragraph is read again from its start"); assumption "paragraph-level tracking" at `specs/005-voice-pause-resume/spec.md:106` |
| The resume unit **is** the queue ("utterance") unit: `resume()` re-runs the queue from `_cursor` and holds no mid-utterance state | `lib/reader_service.dart:243-257` (`resume`), `:261-312` (`_run`) |
| A mid-utterance resume is not available: the engine's own pause corrupts on repeat | `lib/reader_service.dart:327-338` (doc: `StringIndexOutOfBoundsException` inside the plugin at `FlutterTtsPlugin.kt:363`, reproduced on emulator-5554) |
| The app has exactly one definition of "sentence", pure and dependency-free, already used by tap resolution | `lib/segmenter.dart:33-69` (`sentenceRanges`) |
| Where the paragraph granularity is encoded today: the **service** cases (one `ParagraphSpeech` per paragraph, each a single sentence, so they keep passing) — not the view-level test, whose fake `Reader` simulates its own paragraph queue | `test/reader_service_test.dart:234-293` (`backend.spoken == ['Paragraph 0.', 'Paragraph 1.', 'Paragraph 1.']`, `seen == [0,1,1]`); the view-level fake at `test/reading_view_pause_test.dart:62-122` (`_playFrom` over its own `_queue`) |
| Tracking stays paragraph-level because the callback is paragraph-indexed, and that callback is widely used | `lib/reading_view.dart:446-465`; 30 `onParagraphStart` occurrences in `lib/` + `test/` |
| Renaming the speech unit would be a 14-file mechanical change | `grep -rn ParagraphSpeech lib test` → 46 sites in 14 files; `speakParagraphs` → 26 sites in 12 files |
| Android floor is `minSdk 24`, target 36 (from `flutter.*`), iOS deployment target 15.0 — neither is touched by this feature | `android/app/build.gradle.kts:22-23`; measured in spec 009 `research.md` |

## Decisions

### D1 — The start position is the resolved segment's start; no new gesture and no character-level anchor

**Decision**: a tap sets the position to the **start of the sentence** it resolves to, a
long-press to the **start of the paragraph**. The gesture pair is the one 003 already
defines (`lib/reading_view.dart:387-393`); 010 adds the anchor as a second fact derived
from the same resolution, so a tap now means "read this sentence" **and** "continue from
here".

**Rationale**: it satisfies FR-002/FR-003 without inventing a gesture the user has to
learn, keeps the app's whole reading model segment-based (`segmenter.dart`), and makes
the anchor land on a boundary the speak path can start from cleanly. The spec's own edge
case ("start position in middle of word") then has a defined answer that never speaks a
mid-word fragment.

**Alternatives considered**: (a) the exact tapped character offset — reads "…ing over the
quiet town" to the end of the paragraph, which is not what a language learner wants and
contradicts the segmentation model; (b) a word-level anchor — would need a word segmenter
this codebase does not have (no word ranges anywhere in `lib/`), for no benefit over the
sentence a tap already lands in; (c) a drag-to-position handle — a new interaction with a
new hit-testing surface, unreviewable against FR-002/003's wording.

### D2 — Continue Read is the page read with a starting offset: `_readRange(anchor ?? 0, content.length, track: true)`

**Decision**: reuse `_readRange` unchanged; "Continue Read" differs from the old page
read by one argument. With no anchor it is byte-for-byte the previous behaviour
(FR-005), which is also why the 4 existing "read whole page" tests keep their
expectations and only change their tooltip literal.

**Rationale**: FR-004/FR-010 are already implemented by `resolveParagraphSpeeches` +
the tracking callback: starting at a non-zero offset clips only the first speech
(`lib/language.dart:73-75`), the rest is one speech per paragraph in order, and the
highlight follows. Nothing new ships in the read path.

**Alternatives considered**: (a) a separate `_readFrom(anchor)` method — a second copy of
the resolve/speak/guard sequence, i.e. a second place for the generation guard to drift;
(b) a new `Reader.speakFrom(offset)` API on the service — pushes a UI concern
(where the user pointed) into the TTS seam, whose queue model is paragraph-based.

### D3 — The "Read" (sentence) button stays; FR-001 replaces the page button only

**Decision**: keep `Read` (reads the highlighted segment) beside `Continue Read`. The tap
sets selection *and* anchor; the two buttons read the same anchor differently (segment vs
segment-to-end).

**Rationale**: FR-001 names exactly one button to replace, and removing `Read` would
delete a feature the spec never mentions (II/III territory: unrequested scope). The two
buttons are the two useful granularities of the same anchor: "this sentence" and "from
here on".

**Alternatives considered**: (a) drop `Read` and make Continue Read the only read action —
loses the 003 sentence/paragraph read that the existing suite drives through 16
tap/long-press calls in 3 test files and 13 taps on the `Read` button; (b) keep `Read` but have it also continue to the
end of the page — collapses two distinct actions into one and silently changes 003's
behaviour.

### D4 — The anchor is state of its own, not the painted highlight

**Decision**: a new `int? _anchor` (an offset into `_content`) holds the start position;
`_highlight` stays what it is today (the painted segment). The read's tracking callback
repaints `_highlight` without touching `_anchor`.

**Rationale**: the tracking highlight is per-paragraph and is cleared at the end of every
read and by every Stop (`lib/reading_view.dart:481-486`, `:490-499`). If the anchor *were*
`_highlight`, a finished read or a Stop would silently forget the position the user set —
and FR-008/SC-004 need it to survive. Two facts, two fields.

**Alternatives considered**: (a) treat `_highlight.start` as the anchor — no new field, but
the anchor then disappears the moment reading paints the first paragraph, making Continue
Read non-repeatable and the persistence meaningless; (b) recompute the anchor from
`_highlight` at read time and keep only the persisted value — the in-memory and persisted
states would diverge (a restored anchor would be invisible until it is re-persisted).

### D5 — Persist in `shared_preferences`, one key per content — **not** in `index.json`

**Decision**: a new `ReadPositionStore` (mirroring `VoiceStore`) writes
`read_position_<contentKey>` = `'<offset>||<charCount>'`. The content library's
`index.json` is left alone.

**Rationale**: `index.json` is versioned and *any* version other than
`kContentIndexVersion` is treated as corruption — moved aside and re-seeded from the
catalog, which drops the user's entries from the list
(`content.dart:16,198-202`; `content_store.dart:189-204`). Adding a field there means
either a version bump that repairs every existing install or a two-version reader inside
another spec's contract (`specs/008-content-storage/contracts/storage-format.md`), for a
value that is per-device view state, not library metadata. `shared_preferences` is
already the app's store for exactly that kind of per-device state (voice picks, UI
language) and is already injected/mocked in tests.

**Alternatives considered**: (a) an `index.json` field with a version bump — see above,
destructive on upgrade and outside 010's scope; (b) a `position.json` of our own next to
the index — a second file format to specify, validate and repair for one integer per
content, when `shared_preferences` already gives atomic per-key writes; (c) no
persistence at all — contradicts FR-008/SC-004.

### D6 — The stored position must prove it belongs to the text in hand

**Decision**: the stored value carries the length of the text it was computed on
(`charCount`). On load the anchor is accepted only when `charCount == text.length` and
`0 <= offset < text.length`; otherwise it is discarded silently and reading starts from
the beginning (FR-005/FR-009). An accepted offset is re-resolved to its enclosing
sentence start before it is used, so the anchor is always a segment boundary of the
current text.

**Rationale**: FR-009 ("position beyond text length") and the spec's "content changed"
edge case both land here. `charCount` is cheap, already part of the content model
(`models/content.dart:41`), and catches the case that matters most — a shipped pre-set
whose asset text changes between app versions while its id (and therefore our key)
survives. Re-resolving makes any residual mismatch degrade to a valid sentence start
instead of a mid-word read.

**Alternatives considered**: (a) a content hash — strictly stronger, but every in-app text
change already deletes the key (D7), so the only remaining exposure is an out-of-band
edit of an equal-length text; a hash buys little for a per-load pass over up to 100 000
characters; (b) trust the offset and clamp — clamping a stale offset still yields a
position that has nothing to do with the text on screen; (c) store the segment index
rather than the offset — a paragraph inserted earlier shifts every later segment.

### D7 — Any change to the visible text clears the position (in memory **and** on disk)

**Decision**: Done (committed edit), Save, loading/switching content and emptying the
text all clear `_anchor` and delete the stored key. The anchor changes only through a
tap, a long-press, or a content change.

**Rationale**: FR-007 with a single, testable rule. The audit that makes it sufficient:
text can only change in `ReadingView` — `_doneEdit` (`:254-262`) and `_save`
(`:347-369`); `ContentListScreen` deletes entries but never edits text
(`content_list_screen.dart:143-146`). Deleting the key (not just the field) is what makes
"cleared" survive a restart.

**Alternatives considered**: (a) keep the key after an unsaved edit and let it come back
when the app reopens the saved text — two different notions of "the position" for the
same screen, and it survives exactly the change the spec asks us to forget; (b) clear
only in memory — FR-007 would be false after a restart.

### D8 — A restored position is shown, not silent

**Decision**: when a stored anchor is restored on load, the view paints the anchor's
segment (the sentence containing it) as the highlight — the same feedback a tap gives —
and that paint disappears as soon as a read repaints it (tracking) or Stop clears it.

**Rationale**: FR-006/SC-005 say the set position is indicated visually; a restored
position *is* set, and Continue Read that starts from an invisible offset is a mystery
button. Reusing the existing highlight keeps one visual language and one span builder
(`_buildSpans`, `:525-536`) with no metric change — a real constraint here, since the
view deliberately renders plain and highlighted states through a single `RichText` so
layout cannot shift (`:522-524`).

**Alternatives considered**: (a) restore the value silently — the user cannot tell where
the next read starts, and cannot tell whether last session's position survived at all;
(b) a distinct anchor marker (underline/left border on the anchor character, or a
`WidgetSpan` caret) — a second highlight style for one concept, and a `WidgetSpan` inside
the measured paragraph risks the metric change the file warns about; noted for review if
the user wants the anchor to look different from a selection.

### D9 — Localization: rename the key, add the "nothing left" message

**Decision**: rename `readPageButton` → `continueReadButton` in the template ARB and the
three translations (en `Continue Read`, zh/zh_Hans `继续朗读`, es `Continuar leyendo`),
regenerate the Dart classes with `flutter gen-l10n`, and add `nothingToReadMessage` for
the empty-range case so `'Nothing to read.'` (`reading_view.dart:443`) stops being a
hardcoded English string in a 4-locale app.

**Rationale**: keeping the old key name with a new value leaves a key that lies about what
it labels, and the repo's own guard (`test/l10n_keys_test.dart:34-60`) fails if a
translation keeps a key the template dropped — so the rename must be complete in one
pass, which is the honest version. The generated files are tracked; regeneration is a
committed artifact, verified idempotent above.

**Alternatives considered**: (a) new key `continueReadButton`, old key left in place —
the parity guard fails, and dead keys accumulate; (b) reuse `readPageButton` with the new
string — cheapest, and the reason it is rejected is the drift 007 already suffered once.

### D10 — Device evidence: the app logs the resolved read range and every utterance

**Decision**: two `debugPrint` lines, debug builds only, matching the existing
`debugPrint('klhu getVoices: …')` seam (`lib/reader_service.dart:220`): the view logs the
resolved read range in `_readRange` (`klhu read range: <start>..<end>`), and the service
logs each utterance it hands the engine (`klhu speak p<paragraph> s<sentence> "<prefix>"`).

**Rationale**: without them, "reading started at the position the user set" and "resume
picked up the interrupted sentence" are unprovable on the emulator — `flutter_tts` 4.2.5
never logs the utterance text on Android (verified in the plugin source), the Google engine's
log line names the voice and locale but not the text, and a UI dump cannot show which
characters were spoken. The two lines make both claims checkable in `adb logcat` without
shipping anything to release builds.

**Alternatives considered**: (a) no app-side logging — the device walk would rest on
watching the tracking highlight and the persisted prefs file, i.e. on the anchor having
been *stored* rather than on what was *spoken*; (b) counting `Synthesis request …` lines
from the engine per read (a fair cross-check, kept in `quickstart.md`, but it is one log
line per utterance, not per range, and depends on the engine implementation).

### D11 — Non-goals (explicitly not built)

**Decision**: no auto-advancing bookmark (the anchor does not follow the read and is not
rewritten as paragraphs finish), no mid-utterance resume, no position indicator in the
content list, no pagination ("page" remains the whole text).

**Rationale**: FR-010 asks for tracking *from the set position*, which the existing
`track: true` highlight already does; the spec's own wording ("the position where the user
set") ties the anchor to a user gesture. Auto-bookmarking would make Continue Read mean
"resume" — a different feature with its own failure modes (a stale position the user never
chose) and its own spec. This is the one place where a reviewer could reasonably want the
opposite, so it is stated rather than left implicit.

**Alternatives considered**: (a) update the anchor at each `onParagraphStart` — turns every
tap-read into a silent bookmark, and the persisted value would drift on every read;
(b) a "resume last read" separate from Continue Read — a second button for the same
mechanism.

### D12 — Resume from the interrupted sentence: the utterance unit becomes the sentence, inside the TTS service

**Decision**: `ReaderService` splits each paragraph's speech into **sentence utterances**
(reusing `sentenceRanges` from `lib/segmenter.dart`, the app's single definition of a
sentence) and keeps those as its queue; each unit speaks with its paragraph's detected
language and picked voice. `ParagraphSpeech`, `Reader.speakParagraphs` and the
`onParagraphStart` callback keep their signatures and their meaning — the callback still
reports the **paragraph** a sentence belongs to, fired on that paragraph's first
sentence — so 003's paragraph-level tracking, the caller contract and every existing fake
reader stay exactly as they are.

**Rationale**: the resume unit *is* the utterance unit — `resume()` re-runs the queue from
`_cursor` with no mid-utterance state (`lib/reader_service.dart:243-257`), so queue
granularity *is* resume granularity. A whole utterance spoken from its start is the only
resume this engine survives (005's pause corruption, `:327-338`), and a sentence is the
smallest unit that is still a whole utterance — which is exactly FR-011. Keeping the
split inside the service means the caller keeps handing over paragraphs: the 46
`ParagraphSpeech`, 26 `speakParagraphs` and 30 `onParagraphStart` sites across 14 files
keep compiling and keep meaning what they say, and a speech that starts at an anchor
already yields the remainder as its first sentence.

**Alternatives considered**: (a) split in the resolver (`resolveParagraphSpeeches` emits
one speech per sentence) — identical behaviour with a smaller service diff, but then the
type named `ParagraphSpeech` carries sentences: ~100 mechanical edits across 14 files to
rename it, and a rename must not ride along with a feature change; (b) keep
paragraph-sized utterances and use the engine's word-level progress callback
(`setProgressHandler`) to remember which sentence the last word fell in — preserves
paragraph prosody, but introduces an engine API this app has never used, whose behaviour
cannot be verified here, plus a fallback path (no progress events → resume at the
paragraph start), i.e. two behaviours to test instead of one; (c) resume mid-sentence —
impossible, per the engine constraint above; (d) sentence utterances only for the
interrupted paragraph — needs (b)'s progress knowledge to know which sentence was
reached.

**Cost, accepted**: every read now reaches the engine as one utterance per sentence, so
the engine's own utterance gap also appears at sentence boundaries, not only at paragraph
boundaries. The mitigation is that nothing else changes per sentence — same language,
same picked voice — and `quickstart.md` scenario 17 is the device check that the result
still reads acceptably. A reviewer who values paragraph prosody over the finer resume can
reject this decision in favour of (b); that is the one place where this plan would look
different.

## Grounding corrections to the spec's assumptions

| Spec item | What the spec says | What the system says | Consequence |
|---|---|---|---|
| Key Entities | Three entities: `ReadingPosition`, `ContinueReadState`, `PositionFeedback` | Only one has independent existence: the position (an offset + the text it belongs to). "Continue Read state" is the existing `_Mode` plus one nullable int; "feedback" is the highlight that already exists | `data-model.md` defines one persisted value and one view field; the other two are *not* built as classes (V. Simplicity) |
| Assumptions: granularity | "character, word, or paragraph level (implementation decision)" | Nearest available segments are sentence (tap) and paragraph (long-press); there is no word segmenter in `lib/` | Decided: sentence/paragraph starts (D1); word/character rejected with reasons |
| FR-009 + edge case | "start position beyond text length … adjust to end of text" **and** "at very end … show feedback that no content remains" | Both bullets describe one outcome: a range of zero length. "Adjusting to the end" reads nothing; the read path already treats an empty range as a hint (`reading_view.dart:442-445`) | Position past the end (or belonging to different text) is **discarded**, and the empty-range case gets a localized message (D6/D9). No silent truncation to a shorter range |
| FR-007 edge case | "Reset start position **or keep if valid** when content changed" | "Valid" cannot be established without text identity we do not store | Decided: reset on any text change (D7), with the residual case (out-of-band edit of equal length) recorded in D6 |
| FR-002/FR-003 | Reads as if tap/tap-and-hold are new gestures | Both gestures already exist and already resolve to a segment; 003 shipped them and the suite drives them through 16 tap/long-press calls (13 of which press the `Read` button) | 010 extends the existing resolution rather than adding gestures; the tests that read the tapped sentence keep passing unchanged |
| FR-008 / SC-004 | "persist start position across app restarts" as if free | The app has no per-content view state store; its only per-content format (`index.json`) is version-locked and repairs destructively | Persistence is a new, small `shared_preferences` seam (D5) with its own contract file |
| FR-001 | "replace the Read Page **button**" | It is an icon-only `IconButton` whose visible label is a tooltip | The visible change is the tooltip string (and the existing tests that query it by literal); the icon (`Icons.skip_next`) is kept — see `plan.md` § Note for review |
| FR-011 (added in review, 2026-09-24) | Sentence-granular pause/resume | 005 shipped paragraph-granular resume and its own docs say so; the engine cannot resume mid-utterance | The utterance unit becomes the sentence *inside* `ReaderService` (D12); the paragraph callback and the caller contract stand, so 003's tracking and every other spec's behaviour are unchanged |

## Interfaces and contracts

The feature's only external interface is the on-disk record it persists, because the app
has no network or API surface: `specs/010-continue-read/contracts/read-position-format.md`
fixes the prefs key grammar, the value grammar, the validation rules, the write protocol
and the failure states. The content library's own format stays untouched and remains
specified by `specs/008-content-storage/contracts/storage-format.md`.
