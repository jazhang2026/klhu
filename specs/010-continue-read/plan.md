# Implementation Plan: Continue Read

**Branch**: `010-continue-read` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-continue-read/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

> **Grounding notes (2026-09-24, verified in this checkout):** the spec's three Key
> Entities are one value in practice — a persisted start position; "Continue Read state"
> is the existing mode plus a nullable offset, and "position feedback" is the highlight
> 003 already paints (see `research.md` § Grounding corrections). FR-002/FR-003 describe
> tap/tap-and-hold as if they were new: both gestures ship today, resolving a sentence and
> a paragraph respectively, so 010 derives the anchor from that existing resolution
> instead of adding an interaction. FR-009's "adjust to end of text" and the edge case's
> "no content remains to read" are the same empty range; the position is discarded and the
> message is localized, rather than silently truncated to a shorter read. FR-008 is not
> free: the only per-content format the app has (`index.json`) is version-locked and
> repairs destructively, so persistence is a new small `shared_preferences` record
> (`contracts/read-position-format.md`), and the app has no per-content view state today.
> This feature adds **no dependency** and **no platform code** — `shared_preferences`
> already ships on both platforms.
>
> FR-011 (sentence-granular pause/resume) was added at spec review (2026-09-24). It changes
> the granularity 005 shipped: `resume()` re-runs the queue from `_cursor`, so the queue's
> unit *is* the resume unit, and the split belongs inside `ReaderService` — the caller
> contract and therefore 003's paragraph-level tracking stand unchanged
> (`research.md` D12).

## Summary

Replace the "Read page" action with **Continue Read**: the user taps (sentence) or
long-presses (paragraph) in the text to set a start position, and Continue Read speaks
from there to the end of the text instead of always from the beginning. The read
mechanism is unchanged — `_readRange(anchor ?? 0, content.length, track: true)` — so
per-paragraph language detection, picked voices, pause/resume and tracking all apply
exactly as before, and with no position set the text read is exactly what the previous page
read read (FR-005) — though it now reaches the engine as one utterance per sentence
(FR-011). What is new: an `int?` anchor on the view, a small
`shared_preferences` record so the position survives a restart (FR-008), clearing rules
tied to every text change (FR-007), a localized "nothing left to read" message, and a
renamed label key so the button stops calling itself "Read page" in four locales.
Correctness is checked by widget/unit tests over the anchor's life cycle plus a device
walk that reads the resolved range out of `logcat` and the persisted record out of the
app's prefs file.

FR-011 (added at review) moves the **resume** unit from the paragraph to the sentence:
the TTS service queues one utterance per sentence (each inheriting its paragraph's
language and picked voice), so Pause/Resume repeats at most the sentence that was in
progress instead of a possibly very long paragraph. The caller contract does not move —
`ParagraphSpeech`, `speakParagraphs` and the paragraph-indexed tracking callback keep
their signatures and meaning — so 003's reading experience is untouched apart from the
finer resume.

## Technical Context

**Language/Version**: Dart `^3.13.3` on Flutter 3.47.5 (stable) — unchanged

**Primary Dependencies**: **none added**. Uses `shared_preferences 2.5.5` (already a
dependency, already the app's per-device state store) and the existing `flutter_tts
4.2.5` read path unchanged. No new package, no `pubspec.yaml` change, no `pubspec.lock`
churn

**Storage**: one new `shared_preferences` record per content —
`read_position_<contentId>` = `'<offset>||<charCount>'` (contract:
`contracts/read-position-format.md`). The content library's `index.json` and
`contents/<id>.txt` are **not** touched and keep spec 008's contract

**Testing**: `test/read_position_store_test.dart` (new, the record contract) and
`test/reading_view_continue_test.dart` (new, the anchor's life cycle and the button), plus
updates to the 30 existing references to the old label literal across 5 test files and
the existing `test/l10n_keys_test.dart` parity guard; device walk per `quickstart.md`;
`flutter analyze` clean. Baseline: 234 tests green on `main`. FR-011's evidence is new
cases in `test/reader_service_test.dart` (the real `ReaderService` against the file's
existing `FakeTtsBackend`): with a multi-sentence paragraph it must speak one utterance per
sentence and resume at the interrupted one. The 005 cases in that file and the view-level
`test/reading_view_pause_test.dart` keep their expectations — their paragraphs are single
sentences, and the view-level fake carries its own granularity

**Target Platform**: Android (floor `minSdk 24`, target 36) and iOS 16+ per the
constitution — both unchanged. No platform file, no manifest, no asset changes; the
feature is Dart + ARB only

**Project Type**: Mobile app, single Flutter codebase (`lib/` widgets + services, no
`lib/platform/` code)

**Performance Goals**: no new goal. One `shared_preferences` write per setting gesture
(sub-millisecond, off the frame path) and one prefs read per content load; the read path
does the same per-paragraph resolution over a shorter range, so Continue Read is never
slower than the page read

**Constraints**: Constitution IV (On-Device First) — nothing leaves the device, no
network, no account, no telemetry; the position is device-local view state. Constitution
V (Simplicity) — one integer, one store, no new dependency. Accessibility — the button
stays a 48 dp Material `IconButton` (≥ the 44 pt requirement) with a localized tooltip.
The view must keep rendering plain and highlighted states through the single `RichText`
span builder, so the highlight can never change text metrics
(`lib/reading_view.dart:522-536`). A resume point is always a whole utterance — the
engine's own mid-utterance pause is unusable (005) — so the queue is split at sentence
boundaries and a read is never resumed from inside a sentence (FR-011)

**Scale/Scope**: 1 new source file (~60 lines: `lib/read_position_store.dart`), 2 changed
source files (`lib/reading_view.dart`, ~50 lines: anchor state, set/clear/restore,
`_readContinue`, the localized empty-range message, one `debugPrint`; and
`lib/reader_service.dart`, ~25 lines: the sentence-split queue, the paragraph callback and
the resume doc comment), 4 ARB edits (1 key renamed, 1 key added) + 4 regenerated
localization files, 2 new test files, 1 existing test file that gains cases
(`reader_service_test.dart`; `reading_view_pause_test.dart` changes only its label literal),
~30 label literals updated in 5 further test files, 0 dependencies, 0 platform files, 0
assets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **I. Flutter Single Codebase** — the feature is Dart plus ARB strings, identical on
  both platforms; `ReadPositionStore` uses `shared_preferences`, which already ships for
  iOS and Android. No `lib/platform/` code, no per-platform branch, no plugin added.
- ✅ **II. Spec-Driven (NON-NEGOTIABLE)** — spec reviewed 2026-09-24; this plan, its
  `research.md`, `data-model.md`, `contracts/` and `quickstart.md` precede `tasks.md` and
  any code. Every requirement maps to a scenario or an invariant
  (`data-model.md` § Requirement coverage).
- ✅ **III. Test-First (NON-NEGOTIABLE)** — every requirement is testable without a
  device: the record contract (`test/read_position_store_test.dart`) and the anchor's life
  cycle through real taps/long-presses on the widget with a fake `Reader` (the pattern
  already used in `test/reading_view_test.dart`). Tests are written and seen failing before
  the implementation; FR-011's RED is a new case in `test/reader_service_test.dart` over a
  multi-sentence paragraph — today the whole paragraph goes to the engine as one utterance.
  The user story's independent acceptance test is the emulator walk in `quickstart.md`
  13–16. The rename is additionally guarded by the existing ARB parity test.
- ✅ **IV. On-Device First** — no network, no account, no analytics; the position never
  leaves the device. The one log line the device walk relies on is a `debugPrint`
  (debug builds only) over already-on-device text.
- ✅ **V. Simplicity** — no new dependency, no new file format, one nullable field and one
  ~50-line store; the page/paragraph/sentence machinery, the highlight and the read path
  are reused as they are. Rejected as YAGNI: a content hash for position identity, a
  custom anchor marker style, auto-advancing bookmarks, a position column in the content
  list, pagination, and the engine's word-progress callback for resume
  (`research.md` D6/D8/D11/D12).
- ✅ **Constraints** — Android floor and iOS baseline untouched (no platform work);
  TalkBack/VoiceOver: the action keeps an `IconButton` with a localized tooltip, and the
  new message is announced as ordinary text; TTS stays `flutter_tts`.

**Post-Design Re-check**: ✅ PASS — Phase 1 added no dependency, no entity beyond
`ReadingPosition`, and no interface beyond the prefs record already specified. No
`NEEDS CLARIFICATION` survives (`research.md` D1–D12 answer each).

**Note for review (four judgment calls, deliberately visible):**
1. **D8** — a *restored* position paints its sentence, reusing the selection highlight.
   Rejected: a visually distinct anchor marker (a second highlight style, and a metric
   risk inside the one `RichText`). If the anchor should look different from a selection,
   that is a UI decision worth arguing now, not after `tasks.md`.
2. **D11** — the anchor does **not** follow the read. FR-010 is satisfied by the existing
   tracking highlight, but a reviewer could read FR-008 as "resume where I stopped
   listening", which would make every read update the stored position. That is a different
   feature (implicit bookmarks) and is not built.
3. **D3/FR-001** — the "Read" (sentence) button stays and the `Icons.skip_next` glyph is
   kept, so the only *visible* change to the toolbar is the label. A distinct glyph for
   Continue Read is a one-line follow-up if the user wants it.
4. **D12/FR-011** — making the resume unit a sentence also makes the **queue** unit a
   sentence, so every read reaches the engine as one utterance per sentence and the
   engine's own gap now appears at sentence boundaries too. The alternative that keeps
   paragraph prosody (word-progress callbacks + a fallback path) adds an engine API this
   app has never used. If `quickstart.md` scenario 17 — listening to a full page read —
   says the result sounds choppier than before, that is the decision to revisit before
   `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/010-continue-read/
├── plan.md                          # This file (/speckit-plan command output)
├── research.md                      # Phase 0 output (/speckit-plan command)
├── data-model.md                    # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── read-position-format.md      # Phase 1 output: the persistent record contract
├── quickstart.md                    # Phase 1 output (/speckit-plan command)
└── tasks.md                         # Phase 2 output (/speckit-tasks command — NOT created here)
```

### Source Code (repository root)

```text
lib/
├── read_position_store.dart         # NEW: ReadingPosition + ReadPositionStore (the contract)
├── reading_view.dart                # CHANGED: _anchor/_anchorKey, set/clear/restore,
│                                    #   _readContinue, localized messages, debugPrint range
├── reader_service.dart              # CHANGED: the queue is split per sentence (FR-011);
│                                    #   onParagraphStart still fires once per paragraph
└── l10n/
    ├── app_en.arb                   # CHANGED: readPageButton → continueReadButton,
    │                                #   + nothingToReadMessage            (template)
    ├── app_zh.arb                   # CHANGED: same two keys
    ├── app_zh_Hans.arb              # CHANGED: same two keys
    ├── app_es.arb                   # CHANGED: same two keys
    └── app_localizations*.dart      # REGENERATED (flutter gen-l10n; committed artifacts)

test/
├── read_position_store_test.dart        # NEW: the record contract (save/load/clear/parse)
├── reading_view_continue_test.dart      # NEW: FR-001…FR-010 through the widget
├── reading_view_test.dart               # CHANGED: label literal + test names (US3 readings)
├── reading_view_edit_test.dart          # CHANGED: label literal + test names
├── reading_view_mixed_test.dart         # CHANGED: label literal
├── reading_view_pause_test.dart         # CHANGED: label literal only — its fake Reader
│                                        #   carries its own granularity, so the 005
│                                        #   pause/resume expectations stand
├── reader_service_test.dart             # CHANGED: FR-011's new cases (one utterance per
│                                        #   sentence, resume at the interrupted one)
├── branding_test.dart                   # CHANGED: label literal
└── l10n_keys_test.dart                  # UNCHANGED — guards the rename (ARB parity)

# Untouched by design: pubspec.yaml / pubspec.lock, models/content.dart,
# services/content_store.dart, segmenter.dart (reused, not changed), language.dart,
# android/**, ios/**, assets/**
```

**Structure Decision**: the feature is a behaviour change to one existing screen plus one
new value type, so it lands in the existing single-project layout: one new `lib/` file
owning the persisted record (data + IO together, the way `voice_store.dart` already
does), edits inside `lib/reading_view.dart`, ARB strings and their generated Dart, and
tests beside the existing per-topic reading-view test files. Nothing is extracted into a
new layer: the anchor is view state and the record is a value, and a repository/service
abstraction over one prefs key would be surface without a consumer.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The one addition beyond the spec's literal wording — the persisted record's
`charCount` identity guard (D6) — is a field on a value the feature was going to store
anyway, justified by a pre-set's text changing between app versions; it is recorded in
`research.md` D6 with the alternatives (a hash, clamping, nothing at all).
