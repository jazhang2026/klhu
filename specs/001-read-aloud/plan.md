# Implementation Plan: Tap-to-Resolve Read Aloud

**Branch**: `001-read-aloud` | **Date**: 2026-09-14 | **Spec**: `spec.md`

**Input**: Feature specification from `/specs/001-read-aloud/spec.md` (tap point resolves enclosing sentence / paragraph / page; TTS English + Simplified Chinese; paste + bundled sample)

## Summary

Flutter app with one reading view. A tap resolves to the enclosing text unit
(sentence = line, paragraph = block, page) via a pure-Dart segmenter handling
English + Simplified Chinese punctuation; the resolved range highlights and
`flutter_tts` speaks it. Stop halts within 1s. Paste + bundled bilingual sample
text covers v1 input. On-device, offline, no backend.

## Technical Context

**Language/Version**: Dart (Flutter stable, 3.x)

**Primary Dependencies**: `flutter_tts` (TTS + Stop, en + zh-Hans voices)

**Storage**: N/A (in-memory text; bundled sample asset + paste field)

**Testing**: `flutter_test` (unit: segmenter; widget: tap-resolve-highlight-read-stop)

**Target Platform**: iOS 16+, Android 10+ (API 29+), single codebase

**Project Type**: mobile-app (Flutter, no API backend)

**Performance Goals**: Read starts <2s after tap; Stop halts <1s; segmenter <16ms on 10k chars

**Constraints**: Offline-capable; on-device TTS only; 44pt touch targets; operable with VoiceOver/TalkBack

**Scale/Scope**: 1 reading view, ~5 Dart files, bundled EN + zh-Hans samples

## Constitution Check

- Flutter single codebase: PASS (one codebase, `lib/platform/` only if needed)
- Spec-driven: PASS (spec approved 2026-09-14 before this plan)
- Test-first: PASS (segmenter + widget tests per story before implement)
- On-device first: PASS (no backend/accounts/analytics)
- Simplicity: PASS (no OCR/PDF/sync/controls in v1)

## Project Structure

### Documentation (this feature)

```text
specs/001-read-aloud/
├── spec.md              # approved 2026-09-14
├── plan.md              # this file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (next step)
```

### Source Code (repository root)

```text
klhu/
├── lib/
│   ├── main.dart                 # app entry, reading view wiring
│   ├── segmenter.dart            # tap-offset → sentence/paragraph/page ranges (EN + zh-Hans)
│   ├── reader_service.dart       # flutter_tts wrapper: speak/stop, locale en/zh-Hans
│   └── reading_view.dart         # text display, tap handling, highlight, Read/Stop/Read-page
├── assets/
│   └── sample_texts.dart         # bundled EN + Simplified Chinese samples
└── test/
    ├── segmenter_test.dart       # unit: boundaries, CJK punctuation, offsets
    └── reading_view_test.dart    # widget: tap→highlight→speak→stop per story
```

## Phases

- Phase 0: research (flutter_tts API, segmentation rules) → `research.md` (done, in this plan step)
- Phase 1: data model + quickstart (done, in this plan step)
- Phase 2: `tasks.md` via setup-tasks.sh (NEXT STEP, needs your approval of this plan)
- Phase 3: implement P1 → P2 → P3 with tests, verify on simulators
