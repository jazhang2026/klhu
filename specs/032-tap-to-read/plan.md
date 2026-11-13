# Implementation Plan: Tap-to-read — remove the Read button

**Branch**: `032-tap-to-read` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/032-tap-to-read/spec.md`

## Summary

Remove the Read button and make the text gesture itself the read command: `_resolveAt` selects the segment
and immediately runs the existing step-read path (`_readSelection` → `_readRange(step: true)`). A finished
step read keeps its highlight and advances only the Continue Read anchor (`_advanceAnchor`, replacing
`_advanceStep`). ⏭ Continue Read gains a wrap loop (`_continueReading` + `_readCompleted`) that restarts at
the first sentence at end-of-content until Pause/Stop, including after a resume. The paged-read unit loop
gains Pause/Stop guards (FR-010) and a parked remainder (`_pausedReadFrom`) so resume continues where it
stopped.

## Technical Context

**Language/Version**: Dart / Flutter stable (existing app)

**Primary Dependencies**: none new — `flutter_tts` via `Reader`, existing segmenter/comment/role pipeline

**Storage**: none new — the position stays in-memory only (016 decision 5)

**Testing**: `flutter test --concurrency=2` (widget tests with `RecordingReader`/`FakeReader` fakes);
`flutter analyze --no-pub`

**Target Platform**: Android / iOS (unchanged)

**Project Type**: mobile-app

**Performance Goals**: unchanged — one tap = one `resolveSpeeches` + one `speakParagraphs`, same cost as a
Read-button press today

**Constraints**: per-conversation prompt caching n/a; constitution III (test-first) and II (spec-driven)
apply; memory-tight machine → run tests with `--concurrency=2`, clear `build/test_cache` after any IDE crash

**Scale/Scope**: one file's read path (`lib/reading_view.dart`), four ARB files + generated localizations,
~10 test files, 2 walk scripts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Flutter single codebase**: PASS — pure Dart/UI change in the shared layer.
- **II. Spec-driven**: PASS — this spec/plan/tasks set is the approval artifact.
- **III. Test-first**: PASS — tasks.md writes failing widget tests before the implementation lands.
- **IV. On-device first**: PASS — no network, no account, no backend.
- **V. Simplicity**: PASS — reuses `_readSelection`/`_readRange`/`stepRanges`; the only new state is three
  private flags on the page. No new files under `lib/`.

No violations; Complexity Tracking not required.

## Project Structure

### Documentation (this feature)

```text
specs/032-tap-to-read/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # spec-quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── reading_view.dart    # CHANGED: tap-to-read, _advanceAnchor, wrap loop,
│                        #   inter-unit guards, Read button removal
└── l10n/
    ├── app_en.arb       # CHANGED: drop readButton
    ├── app_zh.arb       # CHANGED: drop readButton
    ├── app_zh_Hans.arb  # CHANGED: drop readButton
    ├── app_es.arb       # CHANGED: drop readButton
    └── app_localizations*.dart  # regenerated via flutter gen-l10n

test/
├── reading_view_step_test.dart      # CHANGED: tap-driven steps, no auto-advance
├── reading_view_test.dart           # CHANGED: tap speaks; Read tooltip gone
├── reading_view_continue_test.dart  # CHANGED: wrap + anchor-from-next-step
├── reading_view_follow_test.dart    # CHANGED: Read tooltip references
├── reading_view_comment_test.dart   # CHANGED: Read tooltip references
├── reading_view_edit_test.dart      # CHANGED: Read tooltip references
├── reading_view_video_test.dart     # CHANGED: Read tooltip references
├── reading_view_video_assignment_test.dart  # CHANGED: Read tooltip references
└── picture_assignment_switch_test.dart      # CHANGED: Read tooltip references

specs/
├── 014-dialogue-reading/scripts/klhu_walk_dialogue.py   # CHANGED: readButton refs
└── 025-document-input/scripts/klhu_walk_document.py     # CHANGED: readButton refs
```

**Structure Decision**: single-project Flutter app; all behaviour lives in `lib/reading_view.dart`, tests
mirror it under `test/`, walk scripts under the owning specs' `scripts/`.

## Phase 0 / Phase 1 artifacts

- `research.md` — the gesture/read/wrap design decisions and the offset-space verification.
- `data-model.md` — the page's read state (highlight, anchor, wrap flags) and its transitions.
- `quickstart.md` — device + widget-test validation scenarios.
- `contracts/` — skipped: internal app behaviour, no external interface.
