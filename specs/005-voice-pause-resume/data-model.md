# Data Model: Voice List Improvements and Pause/Resume Functionality

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-21

## Entities

### VoiceMapping

**Purpose**: Static mapping from system voice IDs to user-friendly display names with characteristics

**Attributes**:
- `systemVoiceId` (String): System voice identifier (e.g., "en-us-x-sfg#female_1-local")
- `englishName` (String): User-friendly name in English (e.g., "Female Voice 1")
- `chineseName` (String): User-friendly name in Chinese (e.g., "女声1")
- `gender` (String?): Gender characteristic ("male", "female", or null)
- `age` (String?): Age characteristic ("young", "old", or null)
- `dialect` (String?): Dialect characteristic ("standard", "mandarin", "cantonese", etc., or null)

**Relationships**:
- Used by: VoiceMappingService for lookup
- Maps to: System voice IDs from flutter_tts

**Validation Rules**:
- `systemVoiceId` is required and unique
- At least one of `englishName` or `chineseName` is required
- Characteristics are optional (null if unknown)

**Sample Data**:
```dart
VoiceMapping(
  systemVoiceId: "en-us-x-sfg#female_1-local",
  englishName: "Female Voice 1",
  chineseName: "女声1",
  gender: "female",
  age: "young",
  dialect: "standard",
)
```

### ReadingState

**Purpose**: Tracks current reading state and resume position for pause/resume functionality

**Attributes**:
- `state` (ReadingStateEnum): Current state (idle, reading, paused)
- `currentParagraphIndex` (int): Index of current paragraph being read (0-based)
- `totalParagraphs` (int): Total number of paragraphs in current reading session

**Relationships**:
- Managed by: ReadingView widget
- Used by: ReaderService for resume position

**Validation Rules**:
- `currentParagraphIndex` must be between 0 and `totalParagraphs - 1` when state is reading or paused
- `state` must be one of: idle, reading, paused

**State Transitions**:
- idle → reading: when Read page is tapped
- reading → paused: when Pause is tapped
- paused → reading: when Resume is tapped
- paused → idle: when any other action is taken (Read, Stop, Edit, language switch)
- reading → idle: when Stop is tapped or reading completes
- idle → idle: no change

## Enums

### ReadingStateEnum

**Purpose**: Represents the possible states of TTS reading

**Values**:
- `idle`: Not reading, no active reading session
- `reading`: Currently reading text
- `paused`: Reading paused, can be resumed