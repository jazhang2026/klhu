# Research: Voice List Improvements and Pause/Resume Functionality

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-21

## Voice Mapping Implementation

### Decision: Static mapping table for voice name display

**Rationale**: Static mapping provides immediate lookup without network calls, aligns with on-device-first principle, and allows for curated user-friendly names with characteristics. Flutter TTS voices have stable IDs across restarts, making static mapping feasible.

**Implementation Details**:
- Create `VoiceMapping` model with system voice ID as key
- Map includes: gender (man/woman), age (young/old), dialect (方言)
- Provide locale-specific display names (English/Chinese)
- Fallback to system voice name when not in mapping
- Hardcode common voices (Google TTS, Samsung TTS, etc.)

**UI Integration**:
- Voice picker lists use mapped names with characteristics
- Format: "Gender, Age, Dialect" or "性别, 年龄, 方言"
- Example: "Female, Young, Standard" / "女声, 年轻, 标准音"
- Characteristics displayed as tags or comma-separated text

**Alternatives Considered**:
- Dynamic voice metadata extraction: Rejected - unreliable across TTS engines
- Cloud-based voice directory: Rejected - violates on-device-first principle
- User-customizable nicknames: Rejected - adds complexity for v1

## Pause/Resume Implementation

### Decision: Flutter TTS pause/resume with state management

**Rationale**: flutter_tts plugin supports pause/resume functionality. State management needed to track reading position and handle "stop on other action" requirement.

**Implementation Details**:
- Add reading state enum: `reading`, `paused`, `idle`
- Track current paragraph index for resume functionality
- Pause button changes to Resume when paused
- Resume continues from current paragraph index
- Any other action while paused (Read, Stop, Edit, language switch) triggers full stop
- Stop button always available and resets to idle

**UI Integration**:
- Replace Stop button with Pause during page reading
- Change Pause to Resume when paused
- Resume reading from saved paragraph index
- Visual feedback for paused state (button label change)

**Alternatives Considered**:
- Custom pause implementation with queue management: Rejected - flutter_tts has built-in support
- Bookmark-based resume: Rejected - paragraph-level tracking sufficient for v1
- Continue after any action: Rejected - spec requires stop on non-Resume actions

## I18n for Voice Characteristics

### Decision: ARB translations for voice characteristics

**Rationale**: Existing i18n infrastructure from spec 004 can be extended. Voice characteristics need locale-specific labels.

**Implementation Details**:
- Add keys to `app_en.arb`: `genderMale`, `genderFemale`, `ageYoung`, `ageOld`, `dialectStandard`, etc.
- Add keys to `app_zh.arb`: corresponding Chinese translations
- Use in voice picker when displaying characteristics
- Missing characteristics fall back to not displaying that attribute

**Alternatives Considered**:
- Hardcoded strings in code: Rejected - violates i18n principle
- External translation file: Rejected - ARB files already used in project

## Icon Button Implementation

### Decision: Convert text buttons to Material Design icons with accessibility features

**Rationale**: Icon buttons are more space-efficient, provide modern UI appearance, and display consistently across languages (important for English/Chinese). Accessibility is maintained through tooltips and semantic labels for screen readers.

**Implementation Details**:
- Replace ElevatedButton text with IconButton for all primary actions
- Use standard Material Design icons: play_arrow, stop, pause, edit, format_list_bulleted
- Add tooltip property for long-press accessibility guidance
- Use Semantics widget for screen reader announcements
- Maintain minimum 44pt touch target size (increase icon button padding if needed)
- Icon changes: Play arrow for Resume, Pause icon when paused

**UI Integration**:
- Read (sentence): Icons.play_arrow
- Read page: Icons.format_list_bulleted or Icons.menu_book
- Stop: Icons.stop or Icons.square
- Edit: Icons.edit
- Pause: Icons.pause
- Resume: Icons.play_arrow
- Voice: Icons.record_voice_over (existing)

**Accessibility**:
- Tooltip text: "Read", "Read page", "Stop", "Edit", "Pause", "Resume"
- Semantic labels: Semantics(label: 'Read', button: true)
- 44pt minimum touch target (icon button padding)
- High contrast for visibility

**Alternatives Considered**:
- Text buttons with reduced text length: Rejected - still space-inefficient compared to icons
- Custom SVG icons: Rejected - Material Design icons provide consistency
- Icon font library: Rejected - Material Icons included in Flutter

## flutter_tts Pause/Resume Support

### Decision: Verify flutter_tts pause/resume capabilities

**Rationale**: Need to confirm plugin supports pause/resume before implementation. If not, implement queue-based pause by skipping remaining paragraphs.

**Implementation Details**:
- Check flutter_tts documentation for pause/resume methods
- If supported: use built-in pause/resume
- If not supported: implement "stop and continue from index" approach
- Track paragraph index in ReadingState for resume

**Alternatives Considered**:
- Assume support without verification: Rejected - risk of implementation dead-end
- Implement custom TTS engine: Rejected - outside scope and violates simplicity

## Voice mapping correction (2026-09-21): measured gender replaces guesses

The first table derived gender from the letters of the system voice id, and emulator
validation showed the Chinese list labelling men as women and the reverse (CCC sounded
female but was shown as 男声). Re-derived under the rule **write nothing that cannot be
evidenced**:

- Probe: `TtsProbe.java`, run through `app_process` (no app install needed), calls
  `TextToSpeech.synthesizeToFile` once per voice; the WAVs are pulled and F0-tracked on the
  host (autocorrelation, 40 ms frames) — male voices 110-150 Hz, female 200-260 Hz.
- Cross-check: the gender field of the engine's own voice manifest
  (`assets/voices-list-dsig.pb` in GoogleTTS.apk 20241125.02). Audio and manifest agree on
  all 67 voices; the two voices Google's older published voice list documents
  (en-us-x-sfg female, en-gb-x-rjs male) match the measurement too.
- Table: `lib/models/voice_mapping.dart` now holds exactly the 67 `en`/`zh` voices the engine
  reports on emulator-5554 (verified against the app's own `getVoices` output), each with its
  measured gender.
- Names: region + id code ("普通话 CCC", "US SFG"); gender is the only characteristic shown.
- Removed on purpose: age (the engine exposes none — its own "Install voice data" screen lists
  voices as "Voice I..IV"), dialect (repeated the region already in the name), the
  Local/Network suffixes (the two variants of a code are the same measured voice), and the
  words "English"/"Standard" in the English names.
- `en-us-x-tpc` is left without a gender: F0 ~160 Hz sits in the overlap, its spectral centroid
  sits in the male range, while the manifest marks it as person 1 (female) — conflicting
  evidence, so no claim is written.

Per-voice numbers: `voice-gender-evidence.md`.
