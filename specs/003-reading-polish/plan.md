# Implementation Plan: 003 Reading Polish

**Branch**: `003-reading-polish` | **Date**: 2026-09-16 | **Spec**: `spec.md` (goal + US1/US2/US3, out-of-scope: iPhone, TalkBack ear-check)

**Input**: Feature specification from `/specs/003-reading-polish/spec.md` (picker highlight without marker + autoscroll + count; direct-edit reading area; read-page paragraph tracking)

## Summary

Three independent polish stories on top of 002 (55/55 green, analyze clean).
(1) Picker rows drop the ✓ icon: selection shows via `ListTile.selected` +
`selectedTileColor` (keeps the "selected" TalkBack announcement, no visual
marker), list auto-centers the selected row on open and on select
(`Scrollable.ensureVisible`, alignment 0.5, post-frame), always-visible
scrollbar, and a "N voices" count. (2) The reading area becomes a multiline
`TextField`: paste/type directly, no paste box or Load button; single tap
resolves the enclosing sentence and selects its range so Read speaks it;
typing clears the selection; caret handles/long-press stay native. (3) Read
page tracks progress: `speakParagraphs` gains an `onParagraphStart(index)`
callback, `ParagraphSpeech` gains `start`/`end` content offsets, and the view
moves the highlight paragraph-by-paragraph, clearing at end/Stop.

## Technical Context

**Language/Version**: Dart (Flutter stable, 3.x, as in 001/002)

**Primary Dependencies**: none new (`flutter_tts`, `shared_preferences` already in)

**Storage**: unchanged (`voice_en`, `voice_zh_Hans`)

**Testing**: `flutter_test` (widget: picker highlight/scroll/count, edit-type/tap-select/sample-load, tracking advance + clear; unit/fake-tts: callback order + generation-cancel)

**Target Platform**: iOS 16+, Android 10+ (API 29+), single codebase; validation on Android emulator (iPhone pending, no macOS — as in 001/002)

**Project Type**: mobile-app (Flutter, no API backend)

**Performance Goals**: tracking highlight moves with utterance start (no lag perceptible); Stop clears highlight <1s (existing stop-first path); picker auto-scroll post-frame, no jank on ~40-row lists

**Constraints**: Offline-capable; on-device TTS only; 44pt touch targets; one audio stream (unchanged); TalkBack "selected" announcement preserved (extends T019 guarantee)

**Scale/Scope**: +0 Dart files (picker + reading view + reader service extended, 1 test file extended, 1 new test file for edit/tracking widget cases)

## Constitution Check

- Flutter single codebase: PASS (no platform channels; TtsBackend seam unchanged)
- Spec-driven: PASS (spec written before this plan; plan approval gates tasks.md)
- Test-first: PASS (widget + fake-tts tests per story before implement)
- On-device first: PASS (no backend/accounts/analytics)
- Simplicity: PASS (no new deps, no new storage keys; ParagraphSpeech +2 int fields is the only model change)

## Project Structure

### Documentation (this feature)

```text
specs/003-reading-polish/
├── spec.md              # goal + US1/US2/US3
├── plan.md              # this file
├── research.md          # Phase 0 output (no new APIs; decisions + rejected alternatives)
├── data-model.md        # Phase 1 output (ParagraphSpeech +start/end, PickerRow, ReadingEditState)
├── quickstart.md        # Phase 1 output (implement + emulator checklist)
└── tasks.md             # Phase 2 output (NEXT STEP, needs your approval of this plan)
```

### Source Code (repository root)

```text
klhu/
├── lib/
│   ├── voice_picker_screen.dart  # EXTEND (US1): selected-row highlight, autoscroll, scrollbar, count
│   ├── reading_view.dart         # EXTEND (US2): TextField editing area; (US3): tracking highlight
│   ├── reader_service.dart       # EXTEND (US3): onParagraphStart callback on speakParagraphs (+ Reader iface + fake)
│   └── language.dart             # EXTEND (US3): resolveParagraphSpeeches fills start/end offsets
└── test/
    ├── voice_picker_test.dart            # EXTEND (US1 widget cases; existing semantics tests must stay green)
    ├── voice_picker_semantics_test.dart  # MUST STAY GREEN (TalkBack "selected" without icon)
    ├── reading_view_test.dart            # EXTEND (US2 edit/tap cases; paste-field/Load expectations updated)
    ├── reading_view_mixed_test.dart      # EXTEND (US3 tracking cases)
    └── reader_service_test.dart          # EXTEND (US3 callback order, stop-cancels-callback)
```

## Research (Phase 0 — done inline, no new APIs)

- Picker (US1): `ListTile(selected: true)` merges "selected" into semantics —
  the T019 announcement survives the icon removal; existing
  `voice_picker_semantics_test.dart` proves it (must stay green, plus a
  no-✓-anywhere assertion). `Scrollable.ensureVisible(keyContext, alignment:
  0.5)` post-frame centers the row; needs one `GlobalKey` per row or a key on
  the selected tile only. `Scrollbar(thumbVisibility: true)` around the list.
  ListView becomes `ListView.builder` (same entries, indexed for keys).
- Editing (US2): `TextField` multiline (`maxLines: null`, `expands` inside the
  existing `Expanded`) with a `_contentController`. Tap-to-sentence mirrors the
  current `_resolveAt` path: wrap the field in `GestureDetector(onTapDown)`,
  map the point via the field's `RenderEditable.getPositionForOffset` (verify
  exact API at implement time — RenderEditable, not RenderParagraph), resolve
  the sentence, set `controller.selection` to its range. `onChanged` clears the
  pending sentence (typing replaces content). Read uses the pending sentence
  range; none pending → existing 'Tap a sentence first' hint. Sample buttons
  set controller text (guarded so programmatic sets don't clear state).
- Tracking (US3): `speakParagraphs` already awaits per-paragraph completion
  sequentially — invoke `onParagraphStart(i)` right before each `speak()`
  (utterance-start equivalent, no new platform handler needed). Generation
  guard: callback fires only for the live generation; `stop()` bumps the
  generation so stale callbacks never `setState`. View holds the speeches list;
  highlight range = `speeches[i].start/end`. Highlight clears in `finally`
  (natural end) and in `_stop`.

## Decisions (resolved 2026-09-16)

READ/EDIT/SPEAKING are explicit modes (see spec US2): tap keeps one meaning
per state, Edit is idle-only, Read buttons hidden in EDIT. Typing-during-read
and Read-with-unsaved-edits are impossible by construction.

Tracking highlight shows in the theme selection color, not the 001 yellow
`RichText` band — selection IS the highlight mechanism shared by tap-select,
tracking, and caret. No mode churn for one color; states keep its meaning
unambiguous.

## Phases

- Phase 0: research → `research.md` (done, in this plan step; RenderEditable API verified at implement time)
- Phase 1: data model + quickstart (done, in this plan step)
- Phase 2: `tasks.md` (done, in this plan step — needs your approval of the plan to start Phase 3)
- Phase 3: implement US1 (picker) → US2 (direct-edit) → US3 (tracking) with tests, verify on Android emulator EN + zh-Hans
