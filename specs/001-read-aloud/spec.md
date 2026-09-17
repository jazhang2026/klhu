# Feature Specification: Touch-Select Text and Read Aloud

**Feature Branch**: `001-read-aloud`

**Created**: 2026-09-14

**Status**: Approved (2026-09-14)

**Input**: User description: "as a klhu user, I want to touch and select (lines, block, page) of text and ask app to read it to me."

**Refinement (2026-09-14)**: one line = one sentence, one block = one paragraph.
Selection is tap-based: the user touches a point and klhu resolves the
enclosing sentence / paragraph / page (finds its start and end) instead of
requiring a manual drag range.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tap a sentence, hear it read (Priority: P1)

User opens a text in klhu, taps a point in a sentence, klhu resolves the
enclosing sentence (finds its start and end) and highlights it; user taps
"Read" and hears that sentence; Stop halts playback.

**Why this priority**: Core value of the app. Without tap-sentence + read, there is no product.

**Independent Test**: Load a sample text on iPhone simulator and Android emulator, tap inside a sentence, confirm the full sentence (start to end) highlights, tap Read, hear exactly that sentence; Stop halts audio.

**Acceptance Scenarios**:

1. **Given** a text is open, **When** user taps inside a sentence, **Then** klhu resolves and highlights the enclosing sentence from its start to its end.
2. **Given** a sentence is resolved, **When** user taps Read, **Then** TTS speaks only that sentence.
3. **Given** TTS is speaking, **When** user taps Stop, **Then** speech halts within 1 second.

---

### User Story 2 - Tap a paragraph, hear it read (Priority: P2)

User taps a point in a paragraph, klhu resolves the enclosing paragraph
(finds its start and end) and highlights it; user taps Read and hears the
full paragraph in order.

**Why this priority**: Natural extension of P1 for longer passages; still independently testable.

**Independent Test**: Tap inside a paragraph, confirm full-paragraph highlight, tap Read, hear the full paragraph in order.

**Acceptance Scenarios**:

1. **Given** a text is open, **When** user taps inside a paragraph (block mode or paragraph tap), **Then** klhu resolves and highlights the enclosing paragraph start-to-end.
2. **Given** a paragraph is resolved, **When** user taps Read, **Then** TTS speaks the whole paragraph in reading order.

---

### User Story 3 - Read a whole page (Priority: P3)

User taps "Read page" (touch point resolves to the enclosing page: find its
start and end); klhu highlights the page and reads it top-to-bottom.

**Why this priority**: Convenience shortcut; builds on the same TTS pipeline.

**Independent Test**: Tap Read page, confirm page highlight, hear the full page top-to-bottom.

**Acceptance Scenarios**:

1. **Given** a page is open, **When** user taps Read page, **Then** klhu resolves the page start-to-end and TTS speaks it top-to-bottom.

---

### Edge Cases

- Tap on whitespace between sentences: resolve to nearest sentence, or show hint if ambiguous.
- Tap changed mid-speech: current speech stops, new resolution highlights but does not auto-start (user taps Read again).
- Sentence segmentation must handle English + Simplified Chinese punctuation (。！？；…… as well as . ! ? ;).
- Very long page (P3): speech can be stopped; app stays responsive.
- TTS voice missing on device: show intelligible error, no crash.
- VoiceOver/TalkBack running: klhu controls remain operable, no double-speaking trap.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST resolve a tap point to its enclosing sentence — one line = one sentence — finding its start and end, and highlight it.
- **FR-002**: App MUST resolve a tap point to its enclosing paragraph — one block = one paragraph — finding its start and end, and highlight it.
- **FR-003**: App MUST provide a "Read page" action resolving the enclosing page start-to-end and reading it top-to-bottom.
- **FR-004**: App MUST speak the resolved sentence/paragraph/page via on-device TTS and provide Stop (pause is nice-to-have).
- **FR-005**: Sentence/paragraph segmentation MUST handle English and Simplified Chinese punctuation.
- **FR-006**: v1 text source: user paste + bundled sample text.
- **FR-007**: v1 TTS follows device locale and MUST support English + Simplified Chinese; no rate/pitch controls in v1.
- **FR-008**: App MUST work offline for selection + reading with bundled/sample text and on-device voices.

### Key Entities

- **ReadingText**: the text loaded in klhu (source, length, language).
- **Selection**: tap point resolved to enclosing unit — sentence (line) / paragraph (block) / page — with exact start/end offsets and highlighted range.
- **Utterance**: the queued TTS job (text, language: English / Simplified Chinese per device locale, state: speaking/stopped).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User selects lines and hears them within 2 seconds of tapping Read on either platform.
- **SC-002**: Line, block, and page reads each speak exactly the resolved text — verified on iPhone simulator and Android emulator.
- **SC-003**: Stop halts speech within 1 second, 100% of trials.
- **SC-004**: No crash on empty selection, missing voice, or VoiceOver/TalkBack active.

## Assumptions

- v1 ships one reading view; no library, accounts, backend, or analytics.
- Sample/bundled text suffices for v1 testing; import formats decided in clarify.
- On-device TTS voices exist on test devices; network fallback out of scope.
- iOS 16+, Android 10+ baseline (confirm in plan).
