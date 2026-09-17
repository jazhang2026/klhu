# Feature Specification: Voice Picker with Preview

**Feature Branch**: `002-voice-picker`

**Created**: 2026-09-14

**Status**: Approved (2026-09-14)

**Input**: User description: "voice picker with preview — voice list per language via getVoices, tap-to-preview speaking a sample line, persist the choice."

**Context**: 001-read-aloud speaks via `ReaderService` (flutter_tts), language set per content locale (`en-US` / `zh-Hans-CN`), always the OS default voice. Users with several voices installed (e.g. multiple English or Chinese voices) cannot choose.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Mixed-language page reads with the right voice per paragraph (Priority: P1)

User opens a page mixing English and Chinese paragraphs (EN paragraphs and zh-Hans paragraphs separated by blank lines) and taps Read (sentence, paragraph, or page). klhu detects each paragraph's language, speaks every EN paragraph with the picked English voice and every zh-Hans paragraph with the picked Chinese voice, in order, as one continuous reading. A sentence tap uses its enclosing paragraph's language. Content rule: one language per paragraph — a language switch must start a new paragraph. Future languages plug into the same per-paragraph detection.

**Why this priority**: The core ask — without per-paragraph language handling, a mixed page mispronounces half its paragraphs no matter which voice is picked.

**Independent Test**: Load a mixed EN/zh sample (paragraphs separated by blank lines) on Android emulator, tap Read page, hear EN paragraphs in the EN voice and zh paragraphs in the zh voice in order; Stop halts mid-page.

**Acceptance Scenarios**:

1. **Given** a page with alternating EN/zh-Hans paragraphs, **When** user taps Read page, **Then** each paragraph is spoken with the voice of its own language, in page order.
2. **Given** a single paragraph, **When** user reads a sentence or paragraph inside it, **Then** it speaks once in the paragraph's language with no mid-paragraph voice switch, repeat, or skip.
3. **Given** multi-paragraph speech is playing, **When** user taps Stop, **Then** all speech halts within 1 second.
4. **Given** a paragraph contains both scripts, **When** its language is resolved, **Then** CJK presence wins (zh-Hans), else English.

---

### User Story 2 - Pick a voice for my language (Priority: P1)

User opens the voice picker, sees the voices installed for the current reading language, taps one, and hears it speak a short sample line; the choice sticks — next Read uses that voice, including after app restart.

**Why this priority**: The whole feature. Without list + preview + persist, there is no product.

**Independent Test**: Open picker on Android emulator, confirm listed voices match the OS voice list for that language, tap a voice, hear the sample line in that voice, restart the app, tap Read and hear the same voice.

**Acceptance Scenarios**:

1. **Given** the picker is open for English, **When** the list loads, **Then** every listed voice belongs to an English locale and no Chinese-only voice appears (and vice versa).
2. **Given** a voice is tapped, **When** preview plays, **Then** the sample line is spoken in the tapped voice (not the previous one).
3. **Given** a voice was picked, **When** the app restarts and user taps Read, **Then** speech uses the picked voice.
4. **Given** the previously picked voice is no longer installed, **When** user taps Read, **Then** speech falls back to the OS default voice for that language (no crash, no silence).

---

### User Story 3 - Separate voices per language (Priority: P2)

Bilingual user picks one English voice and one different Chinese voice; each language keeps its own choice and each is previewed with a sample line in its own language.

**Why this priority**: klhu content is EN + zh-Hans by design; a single global voice would mispronounce one language.

**Independent Test**: Pick voice A for EN, switch sample to zh-Hans, pick voice B, restart, verify Read in EN uses A and Read in zh-Hans uses B.

**Acceptance Scenarios**:

1. **Given** an EN voice is picked, **When** user switches to a zh-Hans sample, **Then** the picker opens on the zh-Hans choice (not the EN one).
2. **Given** the picker is open, **When** user taps the EN/中文 switch, **Then** the list, preview line, and checkmark follow the switched language with its own persisted choice.
3. **Given** each language has its voice, **When** user taps Read in each language, **Then** each speaks with its own picked voice.

---

### Edge Cases

- Voice list empty for a language (no matching voice installed): picker shows an explanatory empty state; Read keeps working with the OS default.
- getVoices fails or returns malformed entries: picker shows an error state with retry; reading still works.
- Preview tapped rapidly on several voices: only the latest preview speaks (previous preview stopped first).
- Preview while 001 reading is in progress: preview stops the current reading first (one audio stream at a time).
- Picked voice persists per app install; uninstall clears it (platform default).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect each paragraph's language by script (CJK presence → zh-Hans, else English) through an extensible per-paragraph resolver (future languages added as rules, not branches). A sentence tap uses its enclosing paragraph's language.
- **FR-002**: Multi-paragraph reads (paragraph, page; sentence tap reads in its paragraph's voice) MUST speak paragraphs in order, each with its language's picked voice, stopping previous speech before switching.
- **FR-003**: Picker MUST list installed voices per language (via flutter_tts getVoices, filtered by locale), with an in-picker EN/中文 switch; it opens on the active reading language.
- **FR-004**: Tapping a voice MUST speak a short fixed sample line in that voice (EN line for English, zh-Hans line for Chinese).
- **FR-005**: The picked voice per language MUST persist across app restarts (shared_preferences).
- **FR-006**: Read (001) MUST use the picked voice for the content language when still installed, else OS default.
- **FR-007**: Picker MUST be reachable from the reading screen (AppBar action).
- **FR-008**: Picker MUST handle empty list / load failure with an explicit state (not a blank screen or crash).
- **FR-009**: Starting a preview MUST stop any in-progress speech first.

### Key Entities

- **VoiceChoice**: per-language voice selection — language (`en` / `zh-Hans`), voice identifier (name + locale as returned by getVoices), persisted.
- **VoiceEntry**: one row in the picker — display name, locale, whether it is the current choice.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A mixed EN/zh-Hans page (languages separated by paragraph) reads every paragraph in its own language's voice, in order, with no repeats or skips (Android emulator).
- **SC-002**: Picker lists exactly the OS-installed voices for the active language (verified against getVoices output on Android emulator, EN + zh-Hans).
- **SC-003**: Tapping a voice plays the sample line in that voice within 2 seconds.
- **SC-004**: After app restart, Read uses the previously picked voice (both languages), 100% of trials.
- **SC-005**: Missing picked voice, empty list, and load failure all degrade to OS-default speech or an explicit message — never a crash or silence.

## Assumptions

- flutter_tts getVoices returns name + locale per voice on Android and iOS (shape verified at plan time against flutter_tts 4.2.3).
- Voice identity (name + locale pair) is stable enough across restarts to match a persisted choice.
- One persisted choice per language is enough (no per-text or per-session voices).
- iPhone-simulator validation stays pending (no macOS); Android emulator is the validation path, as in 001.
- Picker is a full screen pushed from an AppBar voice button (decided 2026-09-14).
- Preview speaks a fixed short line per language (decided 2026-09-14).
- Content rule (decided 2026-09-15): one language per paragraph — a language switch must start a new paragraph; bundled EN/zh-Hans samples stay unchanged (already paragraph-separated).
