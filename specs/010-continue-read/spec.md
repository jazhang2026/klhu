# Feature Specification: Continue Read Functionality

**Feature Branch**: `010-continue-read`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "change 'Read Page' to 'Continue Read' function. tap or tap and hold to set the start position. 'Continue Read' is same as Read Page, but it starts from the position where the user set."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Continue Read with Position Setting (Priority: P1)

Users can set a start position in the text and then continue reading from that position instead of always starting from the beginning. The "Read Page" button is replaced with "Continue Read" which allows users to tap or tap and hold to set the starting point.

**Why this priority**: High priority - essential for language learning use cases where users want to practice reading from specific positions or continue from where they left off.

**Independent Test**: User can set a start position, tap Continue Read, and reading begins from the selected position rather than the beginning.

**Acceptance Scenarios**:

1. **Given** user has text content, **When** user taps on text to set start position, **Then** start position is set at the tapped location
2. **Given** user has text content, **When** user taps and holds on text to set start position, **Then** start position is set at the held location with visual feedback
3. **Given** start position is set, **When** user taps Continue Read, **Then** reading begins from the set position
4. **Given** no start position is set, **When** user taps Continue Read, **Then** reading begins from the beginning (default behavior)
5. **Given** reading is in progress, **When** user sets new start position, **Then** reading stops and can continue from new position

---

### User Story 2 - Sentence-granular Pause/Resume (Priority: P2)

Pausing during a long paragraph and resuming repeats only the sentence that was being
read, not the whole paragraph from its top. A paragraph can hold many sentences, so
resuming at paragraph granularity makes the listener re-hear text they already heard;
the sentence is the unit they think in.

**Why this priority**: it refines the shipped pause/resume (005), which resumes at
paragraph granularity. Reading works without it, but long paragraphs are exactly where
pause is reached for.

**Independent Test**: start a page read in a paragraph with three or more sentences,
pause during its second sentence, resume: the interrupted sentence is heard again from
its start and the first sentence is not repeated.

**Acceptance Scenarios**:

1. **Given** a read is in progress inside a paragraph's second sentence, **When** user taps Pause then Resume, **Then** reading continues from the start of that sentence
2. **Given** a read is paused, **When** user taps Resume, **Then** no sentence that already completed is spoken again
3. **Given** a paused read in a paragraph's last sentence, **When** user taps Resume, **Then** the remaining sentences and the following paragraphs follow in order and the read ends normally
4. **Given** a sentence that takes longer than the listener expected, **When** user pauses inside it and resumes, **Then** that sentence starts again from its beginning, never from a mid-sentence point

---

### Edge Cases

- What happens when user sets start position at very end of text? Show feedback that no content remains to read
- What happens when user sets start position in middle of word? Start from word boundary or exact position
- What happens when user taps rapidly on different positions? Only latest position is used as start position
- What happens when start position is set but content is changed? Reset start position or keep if valid
- What happens when user taps Continue Read with start position beyond text length? Adjust to end of text
- What happens when a paragraph holds a single long sentence? Sentence and paragraph granularity coincide, so resume behaves the same either way
- What happens when Pause is tapped exactly on a sentence boundary? The next sentence is the one that resumes
- What happens when the paused sentence is the page's last one? Resume reads it, then the read ends and the buttons return to idle

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST replace "Read Page" button with "Continue Read" button
- **FR-002**: System MUST allow users to tap on text to set start position
- **FR-003**: System MUST allow users to tap and hold on text to set start position with visual feedback
- **FR-004**: System MUST continue reading from the set start position when Continue Read is tapped
- **FR-005**: System MUST start reading from beginning when no start position is set
- **FR-006**: System MUST provide visual feedback when start position is set
- **FR-007**: System MUST clear start position when content is changed or cleared
- **FR-008**: System MUST persist start position across app restarts
- **FR-009**: System MUST handle start position beyond text length gracefully
- **FR-010**: System MUST maintain reading progress tracking from set position
- **FR-011**: System MUST pause and resume at sentence granularity: after Resume, reading continues from the start of the sentence that was in progress when Pause was tapped, never from the start of its paragraph, and no already-completed sentence is spoken again

### Key Entities

- **ReadingPosition**: Tracks the start position for Continue Read functionality
- **ContinueReadState**: Manages the state of Continue Read functionality (position set, reading in progress)
- **PositionFeedback**: Visual feedback for start position setting
- **ResumePoint**: The sentence a paused read continues from — the smallest unit that is still a whole utterance

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Continue Read button replaces Read Page button in the UI
- **SC-002**: Users can set start position by tapping or tapping and holding on text
- **SC-003**: Reading begins from set start position when Continue Read is tapped
- **SC-004**: Start position persists across app restarts
- **SC-005**: Visual feedback clearly indicates when start position is set
- **SC-006**: In a paragraph of N sentences, pausing during sentence k and resuming repeats at most sentence k — the preceding k-1 sentences are not heard again

## Assumptions

- Continue Read function works for both sample texts and user-generated content
- Start position can be set at character, word, or paragraph level (implementation decision)
- Visual feedback for position setting is intuitive (highlight, cursor, etc.)
- Position setting works with both tap and tap-and-hold gestures
- Start position is stored as a character index or paragraph index
- Continue Read maintains all existing TTS functionality (pause/resume, voice selection, etc.)
- The same reading mechanism used for Read Page is used for Continue Read
- Sentence-granular resume changes the granularity of 005's shipped pause/resume, which resumes at the start of the paused paragraph; 005's pause/resume contract otherwise stands unchanged (Pause acts as Stop when any other action follows it, Read/Stop/Edit/language switch end the read)
- A resumed sentence is spoken again from its start: the engine's own mid-utterance pause is unusable (005 research), so the resume unit is the smallest unit that is still a whole utterance