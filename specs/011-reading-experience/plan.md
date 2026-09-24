# Implementation Plan: Reading Experience

**Branch**: `011-reading-experience` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-reading-experience/spec.md`

**Grounding corrections**: two spec statements were corrected against the checkout before planning —
the app ships no font, so the faces are platform-guaranteed, and FR-012's guarantee is a *width*
guarantee because text wraps. The same section records the other change this feature carries: the
2026-09-24 amendment makes the read-tracking highlight the spoken **sentence** (it was the spoken
paragraph, 003), so the spec's "highlighted sentence" wording becomes literal, and the section names
the 003/005/010 artifacts that still state the old granularity. See
[research.md](./research.md) § Grounding corrections.

## Summary

Three behaviours, each independent, each with its own slice.

1. **The read is followed on screen, sentence by sentence** (P1, FR-001–FR-005, FR-020/FR-021): the
   yellow highlight now marks the **sentence** being spoken — it marked the whole paragraph (003) — so
   the highlight, the spoken utterance and 010's resume point name the same unit. While a read plays,
   the reading page scrolls by itself so that sentence is visible. The paragraph that renders the text
   is asked for that sentence's box (`RenderParagraph.getBoxesForSelection`) and, when the box is not
   fully visible, the framework's own minimal reveal moves the page (`showOnScreen(rect: …)`,
   animated). A text that fits never moves, a manual scroll is never undone, and the end of a read
   leaves the page where it stopped.
2. **The text's typeface and character size, remembered** (P2, FR-006–FR-014): a new screen previews
   the text on screen in the candidate style and offers three platform-guaranteed typefaces
   (Default / Serif / Mono) and four named sizes (Small 12 / Medium 14 / Large 18 / X-Large 24, where
   Medium is what the app ships today). Confirming writes one `shared_preferences` record; dismissing
   writes nothing. One style seam (`_contentTextStyle`) applies it to the reading text and the editor,
   and to nothing else.
3. **"+" adds a content from the contents list** (P3, FR-015–FR-019): the list gains an app-bar add
   action that pops a typed `NewContentRequest`; the reading page resets to a blank, unnamed page in
   EDIT (reusing `_enterEdit`), and Save creates an auto-named entry through 008's existing path. An
   empty Save is refused with the existing message; leaving writes nothing.

## Technical Context

**Language/Version**: Dart, SDK `^3.13.3`; Flutter 3.47.5 stable (measured: `flutter --version`).

**Primary Dependencies**: `shared_preferences ^2.5.5` (the appearance record), `flutter_tts ^4.2.3`
(the read, unchanged), `intl ^0.20.3`, `path_provider ^2.1.6` (the library). **No new dependency, no
new asset, no runtime network** — the typefaces are the platform's own (research D5).

**Storage**: one `shared_preferences` key, `reading_appearance = <typeface>||<size>`, per device —
the same store the app already uses for voice picks, interface language and read positions. The
record's read/write protocol is `contracts/appearance-format.md`.

**Testing**: `flutter test` (widget + unit), `flutter analyze`, plus scripted device rows on
`emulator-5554` (`specs/011-reading-experience/scripts/klhu_walk_experience.py`, run by hand). Per
constitution III, each story's tests are written and seen failing before the implementation.

**Target Platform**: Android (validated on the `klhu` AVD, API 36) and iOS from the same codebase. The
build resolves `minSdk` to the Flutter default (24) and iOS to 15.0, against the constitution's stated
Android 10+/iOS 16+; that gap is pre-existing, this feature adds no platform code, and it is reported
rather than changed (research.md § Grounding corrections).

**Project Type**: mobile app — a single Flutter project (`lib/` + `test/`, six platform directories).

**Performance Goals**: the follow reveal is one animated scroll per sentence (≈200 ms) started at the
utterance boundary, with the engine speaking seconds per sentence — the page is never the bottleneck.
No measurable cost added to a read.

**Constraints**: on-device only (no account, no backend, no analytics — constitution IV); the
appearance is applied through one style method so the plain and highlighted text states keep identical
metrics (the 003/010 invariant); every new interactive control meets the 44 pt touch target the
constitution requires (`IconButton` defaults to 48).

**Scale/Scope**: two new source files, one new store, two new test files, one new screen, ~13 new
localization keys across four ARBs; one existing screen gains an action and one existing screen's
route result becomes a typed value. The shipped content set (three pre-sets) is the validation corpus.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle (as the constitution names it) | Gate | Verdict |
|---|---|---|
| **I. Flutter Single Codebase** | No platform-specific fork. The appearance uses platform *font family names* through a small table in one Dart file — no `lib/platform/` code, no `ios/`/`android/` edits | PASS (`git status --short android/ ios/` must stay empty — quickstart 18) |
| **II. Spec-Driven (NON-NEGOTIABLE)** | spec → plan → tasks under `specs/` before implementation | PASS: `specs/011-reading-experience/` holds the reviewed spec and this plan; tasks come next |
| **III. Test-First (NON-NEGOTIABLE)** | Tests written and seen failing, then implementation; every user story has an independent acceptance test on the emulator | PASS by plan: each story's `[unit]` rows are written and run RED first (quickstart 1–6, 11–15), each story has `[device]` rows (7–10, 16, 17), and the tracking tests **rewritten** to sentence granularity (Ripple note 1) are seen failing against the old paragraph-level code before the change |
| **IV. On-Device First** | On-device text and TTS by default; no account/backend/analytics; any network use declared | PASS: no network use at all — the record is local prefs and the faces are the platform's. No font download, no asset fetch |
| **V. Simplicity (YAGNI)** | No speculative machinery; the smallest thing that satisfies the spec | PASS: no `ScrollController`, no offset math (framework reveal), no bundled fonts, no new dependency, no new file format — one key in an existing store. The one new abstraction (a typed route result) replaces an inferred one rather than adding a layer |
| **Constraints: Flutter stable, Dart** | Toolchain as declared | PASS: Flutter 3.47.5 stable, Dart `^3.13.3` |
| **Constraints: iOS 16+ / Android 10+ (API 29+) — "confirm in plan"** | Confirm the project's floors | **GAP (pre-existing, not introduced here)**: the build resolves `minSdk` to Flutter's default 24 and iOS to `IPHONEOS_DEPLOYMENT_TARGET = 15.0`. This feature adds no platform code and does not change either floor; reported to the user (research.md § Grounding corrections) |
| **Constraints: accessibility, 44 pt targets, VoiceOver/TalkBack** | New controls meet the target and keep the semantics contract | PASS by design: the add action and the appearance action are `IconButton`s (48 pt) with tooltips (their `content-desc`, which is how TalkBack and the device walk both find them); the appearance screen's rows are `ListTile`/`Radio`-shaped, and the reading page's gesture semantics are untouched |

**Post-design re-check (after Phase 1)**: unchanged. The design added one persisted key and one new
screen, and replaced one callback (the tracking callback, now sentence-level per the amendment); no
principle moved. The only item that needs a human decision is the
pre-existing platform-floor gap, which no design choice here can fix.

## Project Structure

### Documentation (this feature)

```text
specs/011-reading-experience/
├── spec.md                        # reviewed (specify)
├── plan.md                        # this file
├── research.md                    # decisions D1–D12, the fact table, the grounding corrections
├── data-model.md                  # ReadingAppearance, AppearanceDraft, FollowTarget, DraftContent
├── quickstart.md                  # 18 validation scenarios, tagged [unit]/[device]/[structural]
├── contracts/
│   └── appearance-format.md       # the persisted record: key, domains, read/write rules, invariants
├── checklists/
│   └── requirements.md            # the spec-quality gate (all items ticked)
├── scripts/                       # created at the implement stage
│   └── klhu_walk_experience.py    # the device rows, one function per scenario, argv dispatch
├── tasks.md                       # created by the tasks stage
└── breakpoint.md                  # created at the implement stage (PASS/FAIL rows + divergences)
```

### Source Code (repository root)

```text
lib/
├── appearance_store.dart          # NEW  the persisted choice + its defaults (D4, contract)
├── appearance_screen.dart         # NEW  typeface/size picker with a live preview (D8)
├── reading_view.dart              #      follow routine, appearance seam, new-content path (D1/D6/D7)
├── reader_service.dart            #      the sentence tracking callback replaces onParagraphStart (D2)
├── content_list_screen.dart       #      the add action + the route's result type (D7)
├── read_position_store.dart       #      unchanged — the shape D4 mirrors
├── voice_picker_screen.dart       #      unchanged — the shape D8 mirrors
├── main.dart                      #      unchanged (no new wiring: the store is a view-level field)
└── l10n/                          #      four ARBs (+~13 keys) and 4 regenerated app_localizations*

test/
├── appearance_store_test.dart     # NEW  the contract's read rules and write protocol
├── reading_view_follow_test.dart  # NEW  quickstart 2–6 (the follow behaviour + the sentence paint)
├── reading_view_appearance_test.dart # NEW  quickstart 11–15 (the screen and the page's style seam)
├── reading_view_new_content_test.dart # NEW  quickstart 19 (the draft: save, refusal, discard)
├── reader_service_test.dart       #      the sentence callback's cases (its 6 old callback sites)
├── reading_view_continue_test.dart #     tracking expectations per paragraph → per sentence (286, 289)
├── reading_view_mixed_test.dart   #      same (213)
├── reading_view_test.dart         #      same, plus its fake's signature
├── reading_view_pause_test.dart   #      its fake forwards tracking: signature + the resume expectation
├── reading_view_edit_test.dart    #      fakes only — its tap/long-press selection tests are unchanged
├── branding_test.dart, spanish_localization_test.dart, voice_picker_test.dart,
│   voice_picker_semantics_test.dart #    fake signatures only (no granularity assertions)
└── (unchanged)                    #      the remaining test files; see the ripple notes below

specs/010-continue-read/scripts/
└── klhu_walk_continue.py          #      unchanged — the 011 driver imports its device helpers (D10)
```

**Structure Decision**: single Flutter project, the layout the six earlier specs already use —
`lib/` for source (one file per screen/store/concern, no directories added), `test/` mirroring the
source at file granularity, and per-spec artifacts under `specs/<NNN>-<name>/`. The two new source
files follow the existing naming (`<concern>_store.dart`, `<concern>_screen.dart`).

**Ripple note 1 — the tracking callback (the amendment)**: replacing `onParagraphStart` with the
sentence-level callback (D2) reaches every fake that implements `Reader.speakParagraphs`. Measured:
12 test files reference the old callback, 9 carry the fake signature, and the tests that assert
paragraph-level painting (`reading_view_continue_test.dart:286,289`,
`reading_view_mixed_test.dart:213`, and the drive inside `reading_view_test.dart`) have their
expectations **rewritten** to sentence level, never deleted. The selection tests in
`reading_view_edit_test.dart:168,226` (tap → sentence, long-press → paragraph) are unaffected (D11).
The implement stage settles which files are signature-only by reading each fake, not its name.

**Ripple note 2 — the appearance read**: the appearance is readable from `initState`, and four
`reading_view_*` test files (`reading_view_test`, `_edit_test`, `_mixed_test`, `_pause_test`) never call
`SharedPreferences.setMockInitialValues`, so an unmocked `getInstance()` must stay harmless — the
store catches every failure and returns the defaults, exactly as `ReadPositionStore` does today. Only
the files that assert the appearance need the mock, and the store writes **only** on a confirm, so no
existing test file's expectations change from it. If the implement stage finds otherwise, that is a
correction to report, not a quiet edit.

## Complexity Tracking

None — no constitutional violation is introduced or justified by this feature. The one gap the
Constitution Check records (the platform floors) predates this feature, is not affected by it, and is
reported to the user rather than absorbed here.
