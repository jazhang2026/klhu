# Feature Specification: Voice List Improvements and Pause/Resume Functionality with Icon Buttons

**Feature Branch**: `005-voice-pause-resume`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Voice list: change the voice name to a user-friendly name. has i18n form English and Chinese. have more characters of the voice if possible: man/woman, yang/old, 方言. use Approach: Static mapping table (recommended). change Stop to Puse/Resume functionality to stop and continue TTS reading(page reading). When Pused, next action is not Resume, Pause works as Stop."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - User-Friendly Voice Names with i18n (Priority: P1)

Users see voice names displayed in their native language (English or Chinese) with descriptive characteristics like gender, age, and dialect. A static mapping table maps system voice IDs to user-friendly display names.

**Why this priority**: High priority - improves user experience by making voice selection more intuitive and accessible to both English and Chinese users.

**Independent Test**: Users can open the voice picker and see voices displayed with user-friendly names in their selected interface language, with characteristics like "Female, Young, Standard" in English or "女声, 年轻, 标准音" in Chinese.

**Acceptance Scenarios**:

1. **Given** user is in English interface mode, **When** user opens voice picker, **Then** all voice names display in English with descriptive characteristics (gender, age, dialect)
2. **Given** user is in Chinese interface mode, **When** user opens voice picker, **Then** all voice names display in Chinese with descriptive characteristics (性别, 年龄, 方言)
3. **Given** user selects a voice, **When** preview plays, **Then** the selected voice shows as highlighted in the list with its user-friendly name
4. **Given** voice picker is opened, **When** system voice is not in the mapping table, **Then** display the original system voice name as fallback

---

### User Story 2 - Pause/Resume TTS Reading with Icon Buttons (Priority: P1)

Users can pause ongoing TTS page reading and resume from where they left off using icon buttons. If the user takes any other action while paused (not Resume), the reading stops completely. All primary action buttons use icons instead of text for better space efficiency and modern UI design.

**Why this priority**: High priority - essential user experience improvement for longer readings, allowing users to pause and resume without losing progress, while improving UI with icon buttons.

**Independent Test**: User starts page reading, taps Pause icon, reading stops. User taps Resume icon, reading continues from the paused position. User taps Pause then taps Read icon, reading stops completely (does not resume paused page read).

**Acceptance Scenarios**:

1. **Given** page reading is in progress, **When** user taps Pause icon, **Then** reading stops at current position and icon changes to Resume
2. **Given** reading is paused, **When** user taps Resume icon, **Then** reading continues from the paused position
3. **Given** reading is paused, **When** user taps Read (sentence) icon, **Then** reading stops completely (does not resume paused page read)
4. **Given** reading is paused, **When** user taps Stop icon, **Then** reading stops completely and state resets to idle
5. **Given** reading is paused, **When** user switches interface language, **Then** reading stops completely
6. **Given** reading is paused, **When** user taps Edit icon, **Then** reading stops completely and enters edit mode
7. **Given** reading reaches end of page, **When** auto-stops, **Then** icon returns to Read page (not Pause)
8. **Given** interface displays icon buttons, **When** user taps and holds on icon, **Then** tooltip shows button label (accessibility)
9. **Given** screen reader is active, **When** user navigates to icon button, **Then** semantic label is announced (VoiceOver/TalkBack)

---

### Edge Cases

- What happens when user rapidly toggles Pause/Resume multiple times? Only the latest action takes effect
- What happens when reading is paused and user switches language? Reading stops completely (spec 004 requirement)
- What happens when voice mapping table is incomplete or corrupted? Fall back to system voice names
- What happens when voice has unknown characteristics in mapping? Display available characteristics only
- What happens when user pauses at very end of page? Auto-completes reading and resets to idle
- What happens when icon buttons are tapped rapidly? Only latest action takes effect
- What happens when screen reader is used? Semantic labels announce button purpose

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display voice names using user-friendly names in English and Chinese via static mapping table
- **FR-002**: System MUST display voice characteristics (gender: man/woman, age: young/old, dialect: 方言) when available in the mapping
- **FR-003**: System MUST provide a static mapping table that maps system voice IDs to user-friendly display names with characteristics
- **FR-004**: System MUST fall back to system voice name when voice is not in the mapping table
- **FR-005**: System MUST support i18n for voice names and characteristics (English and Chinese)
- **FR-006**: System MUST provide Pause icon button during page reading TTS
- **FR-007**: System MUST change Pause icon to Resume icon when reading is paused
- **FR-008**: System MUST resume reading from paused position when Resume icon is tapped
- **FR-009**: System MUST stop reading completely when any action other than Resume is taken while paused (Read, Stop, Edit, language switch)
- **FR-010**: System MUST reset to idle state when reading stops completely after pause
- **FR-011**: System MUST use icon buttons for all primary actions (Read, Read page, Stop, Edit, Pause/Resume)
- **FR-012**: System MUST provide tooltip labels for icon buttons on long-press (accessibility)
- **FR-013**: System MUST provide semantic labels for icon buttons for screen readers (VoiceOver/TalkBack)
- **FR-014**: Icon buttons MUST maintain minimum 44pt touch target size (accessibility requirement)

### Key Entities

- **VoiceMapping**: Static mapping from system voice ID to user-friendly display name with characteristics (gender, age, dialect, locale-specific names)
- **ReadingState**: Tracks current reading state (reading, paused, idle) and resume position

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify voices by descriptive characteristics (gender, age, dialect) in their native language
- **SC-002**: Users can pause and resume page reading with 100% accuracy of resume position
- **SC-003**: Reading stops completely within 500ms when any non-Resume action is taken while paused
- **SC-004**: Voice picker displays user-friendly names for at least 90% of available system voices
- **SC-005**: Language switching displays voice names in the correct language (English/Chinese) immediately
- **SC-006**: Icon buttons are recognizable with tooltips and semantic labels for accessibility

## Assumptions

- System voice IDs are stable across device restarts and system updates
- Static mapping table can cover the most common TTS voices (Google TTS, Samsung TTS, etc.)
- Existing TTS system supports pause/resume functionality via the flutter_tts plugin
- Page reading maintains track of current paragraph index for resume functionality
- Voice characteristics (gender, age, dialect) are available from system voice metadata or can be manually mapped
- User-friendly voice names should be intuitive (e.g., "Female Voice 1 (Young, Standard)" in English, "女声1 (年轻, 标准音)" in Chinese)
- Pause state should be visually distinct from idle state (icon change)
- Resume functionality should work for paragraph-level tracking (resume from current paragraph)
- Icon buttons use standard Material Design icons for consistency
- Touch targets for icon buttons maintain 44pt minimum for accessibility