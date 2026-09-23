# Feature Specification: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Feature Branch**: `007-reader-name-spanish-cantonese`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "header changes: KalaHoo -> KalaHoo Reading. 卡啦虎 -> 卡啦虎朗读. add Spanish as a language option - reading and i18n support. add 中文 方言 广东话 as Voice option. Spanish title: KalaHoo Lectura. 广东话 as option under 中文 voice picker, not separate Cantonese option. Use Latin American Spanish (es-MX) variant aligned with US high school curriculum."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enhanced App Titles with "KalaHoo Reading" (Priority: P1)

Users see the app title as "KalaHoo Reading" in English, "KalaHoo Lectura" in Spanish, and "卡啦虎朗读" in Chinese, providing more descriptive branding that clearly indicates the app's purpose as a reading application useful for language learning.

**Why this priority**: High priority - improves app discoverability and user understanding by making the purpose clear in the title itself, and aligns with the app's focus on language learning applications.

**Independent Test**: Users can see the updated app titles in both English and Chinese interfaces and in app metadata.

**Acceptance Scenarios**:

1. **Given** user is in English interface mode, **When** user views app title, **Then** title displays as "KalaHoo Reading"
2. **Given** user is in Chinese interface mode, **When** user views app title, **Then** title displays as "卡啦虎朗读"
3. **Given** user is in Spanish interface mode, **When** user views app title, **Then** title displays as "KalaHoo Lectura"
4. **Given** app is installed on device, **When** user views app launcher, **Then** app name shows updated title based on device locale
5. **Given** app is running, **When** user views app bar, **Then** title shows localized version (KalaHoo Reading, KalaHoo Lectura, or 卡啦虎朗读)

---

### User Story 2 - Latin American Spanish Language Support (Priority: P1)

Users can select Latin American Spanish (es-MX) as an interface language, with full i18n support for UI elements and reading functionality including the app title "KalaHoo Lectura". The app properly detects and handles Spanish locale preferences. The Latin American Spanish variant aligns with US high school curriculum and is most commonly taught in US schools.

**Why this priority**: High priority - expands user base to Spanish-speaking users and demonstrates multi-language extensibility beyond English/Chinese. Latin American Spanish (es-MX) aligns with US high school curriculum, making it ideal for language learning applications.

**Independent Test**: Users can switch to Spanish language and see all UI elements translated, and TTS reading works correctly with Spanish text.

**Acceptance Scenarios**:

1. **Given** user opens language dropdown, **When** user selects Latin American Spanish (Español), **Then** interface switches to Spanish translations
2. **Given** interface is in Latin American Spanish, **When** user views UI elements, **Then** all buttons, labels, and messages display in Spanish
3. **Given** text is in Spanish, **When** user initiates TTS reading, **Then** reading uses Latin American Spanish voice and proper pronunciation
4. **Given** Latin American Spanish voice is selected, **When** preview plays, **Then** audio output is in Spanish with correct Mexican/Latin American intonation
5. **Given** device locale is Spanish, **When** app first launches, **Then** interface defaults to Latin American Spanish

---

### User Story 3 - Cantonese Dialect Option (Priority: P2)

Users can select Cantonese (广东话) as a dialect option within the Chinese voice picker, providing support for a major Chinese dialect. Cantonese appears as an option under the Chinese (中文) voice selection, not as a separate language option.

**Why this priority**: Medium priority - important for Cantonese-speaking users, but secondary to core Spanish language support as it's a dialect within the existing Chinese support.

**Independent Test**: Users can select Cantonese from the Chinese voice picker and hear Chinese text read in Cantonese dialect.

**Acceptance Scenarios**:

1. **Given** user opens voice picker and selects Chinese (中文), **When** user views dialect options, **Then** Cantonese (广东话) appears as a dialect option
2. **Given** user selects Cantonese dialect, **When** reading Chinese text, **Then** TTS output uses Cantonese pronunciation
3. **Given** user previews Cantonese dialect, **When** sample text plays, **Then** audio is clearly Cantonese dialect
4. **Given** interface is in English, **When** user views Chinese voice options, **Then** Cantonese displays as "广东话" (Chinese characters only, not "Cantonese")

---

### Edge Cases

- What happens when Spanish locale is detected but Latin American Spanish ARB translations are incomplete? Fall back to English or show partial translations
- What happens when Cantonese dialect is not available on device? Hide Cantonese option or show as unavailable under Chinese voices
- What happens when user switches to Latin American Spanish but Spanish TTS voices are not available? Use Spanish-compatible voice or fall back to default
- What happens when app title change conflicts with existing shortcuts or bookmarks? Update gracefully
- What happens when Cantonese dialect mapping is incomplete? Display available characteristics only
- What happens when user selects Chinese voice but no dialect options are available? Show standard Chinese voice without dialect selection
- What happens when device locale is Spanish but not specifically Latin American? Default to Latin American Spanish (es-MX) as it's the standard US curriculum

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display app title as "KalaHoo Reading" in English
- **FR-002**: System MUST display app title as "卡啦虎朗读" in Chinese
- **FR-003**: System MUST display app title as "KalaHoo Lectura" in Spanish
- **FR-004**: System MUST support Latin American Spanish (es-MX) as a language option in language dropdown
- **FR-005**: System MUST provide Latin American Spanish translations for all UI elements (buttons, labels, messages)
- **FR-006**: System MUST support Latin American Spanish TTS reading with proper voice selection
- **FR-007**: System MUST detect Spanish device locale and default to Latin American Spanish interface
- **FR-008**: System MUST provide Cantonese (广东话) as a dialect option under Chinese (中文) voice selection
- **FR-009**: System MUST support Cantonese TTS reading for Chinese text when dialect is selected
- **FR-010**: System MUST display Cantonese dialect as "广东话" (Chinese characters only) in both English and Chinese interfaces
- **FR-011**: System MUST update app metadata (Android manifest, iOS Info.plist) with new titles for all three languages

### Key Entities

- **LanguageConfig**: Extended language configuration including Latin American Spanish (es-MX)
- **VoiceMapping**: Extended voice mapping including Cantonese dialect options under Chinese voices
- **LocalizedStrings**: Latin American Spanish ARB translations for all UI elements and app title
- **DialectConfig**: Dialect options within language-specific voice selections (e.g., Cantonese under Chinese)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: App title displays correctly as "KalaHoo Reading" in English, "KalaHoo Lectura" in Spanish, and "卡啦虎朗读" in Chinese
- **SC-002**: Latin American Spanish language option is available and fully functional with 100% UI translation coverage
- **SC-003**: Cantonese dialect option is available under Chinese voice selection and produces correct Cantonese pronunciation
- **SC-004**: Latin American Spanish TTS reading works with proper voice selection and Mexican/Latin American pronunciation
- **SC-005**: Language switching between English, Chinese, and Latin American Spanish works seamlessly
- **SC-006**: Cantonese dialect displays as "广东话" (Chinese characters only) in both English and Chinese interfaces

## Assumptions

- Latin American Spanish (es-MX) follows the same localization pattern as English/Chinese (ARB files, LocalizationService)
- Latin American Spanish (es-MX) is chosen because it aligns with US high school curriculum and is the most commonly taught Spanish variant in US schools
- Cantonese dialect is available through the flutter_tts plugin as a variant of Chinese voices
- App title changes are backward compatible with existing installations
- Latin American Spanish voice options are available in standard TTS engines (es-MX locale)
- Cantonese uses standard locale codes (zh-HK or similar) for dialect identification within Chinese voice selection
- Device locale detection works for Spanish and defaults to Latin American Spanish (es-MX) for any Spanish locale
- ARB file structure can accommodate a third language without breaking existing infrastructure
- The app's focus on language learning means proper pronunciation and dialect support are critical for user success
- Dialect options within language selections are supported by the voice picker architecture
- Latin American Spanish vocabulary and cultural references align with US educational standards