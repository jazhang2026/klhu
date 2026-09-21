# Feature Specification: App Branding and Internationalization

**Feature Branch**: `004-app-branding-i18n`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "change App title to 'KalaHoo' in English and '卡啦虎' in Chinese. Use images/kalahu.jpeg as the app icon. i18n support for English and Chinese. User can switch between English and Chinese."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - App branding with localized titles and custom icon (Priority: P1)

User opens the app and sees the app title displayed as "KalaHoo" when using English interface and "卡啦虎" when using Chinese interface. The app icon is the custom image at images/kalahu.jpeg instead of the default Flutter icon.

**Why this priority**: Core branding identity - without proper app titles and icon, the app lacks professional presentation and user recognition.

**Independent Test**: Launch the app on Android emulator and iPhone simulator, verify app shows "KalaHoo" title in English mode and "卡啦虎" title in Chinese mode, and displays the custom icon from images/kalahu.jpeg.

**Acceptance Scenarios**:

1. **Given** the app is launched in English mode, **When** the user views the app title, **Then** it displays "KalaHoo".
2. **Given** the app is launched in Chinese mode, **When** the user views the app title, **Then** it displays "卡啦虎".
3. **Given** the app is installed, **When** the user views the app icon on the home screen, **Then** it shows the custom image from images/kalahu.jpeg.
4. **Given** the custom icon file is missing, **When** the app launches, **Then** it falls back to the default Flutter icon without crashing.

---

### User Story 2 - Language switching dropdown (Priority: P1)

User can switch between English and Chinese languages through a dropdown language selector in the app interface. The dropdown displays the current language (device locale or selected language) using native language names ("English", "中文"). Tapping the dropdown opens a list of available languages with native names, allowing selection. The language selection persists across app restarts and all UI elements (buttons, labels, messages) update to reflect the selected language. The design supports future expansion to 2+ languages.

**Why this priority**: Core internationalization requirement - without language switching, Chinese users cannot use the app effectively.

**Independent Test**: Launch the app, tap language dropdown, verify it shows current language in native name, select Chinese ("中文"), verify all UI text updates to Chinese, restart the app, verify language preference persists, switch back to English ("English"), verify UI returns to English.

**Acceptance Scenarios**:

1. **Given** the app is in English mode, **When** the user views the language dropdown, **Then** it displays "English" (native name) as the current selection.
2. **Given** the app is in Chinese mode, **When** the user views the language dropdown, **Then** it displays "中文" (native name) as the current selection.
3. **Given** the language dropdown is tapped, **When** the list opens, **Then** it shows available languages with their native names ("English", "中文").
4. **Given** the app is in English mode, **When** the user selects "中文" from the dropdown, **Then** all UI elements update to Chinese within 1 second.
5. **Given** the app is in Chinese mode, **When** the user selects "English" from the dropdown, **Then** all UI elements update to English within 1 second.
6. **Given** a language is selected, **When** the app is restarted, **Then** the previously selected language remains active and the dropdown shows the correct native name.
7. **Given** the language is switched, **When** the user performs reading operations, **Then** the reading voice selection and text content language handling remain consistent with the selected interface language.

---

### Edge Cases

- Language switching while TTS is reading: current reading stops, language preference updates, but reading content language detection remains paragraph-based.
- Missing translation for a specific UI element: falls back to English text with a warning logged, no crash.
- App icon file corrupted or invalid format: falls back to default Flutter icon, logs error, no crash.
- Rapid language switching: only the latest selection takes effect, previous switches are discarded.
- Language preference storage failure: defaults to English, shows error message, app remains functional.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST display "KalaHoo" as the title when English interface language is selected.
- **FR-002**: App MUST display "卡啦虎" as the title when Chinese interface language is selected.
- **FR-003**: App MUST use the custom icon located at images/kalahu.jpeg as the app icon.
- **FR-004**: App MUST provide a dropdown language selector that displays the current language using native names ("English", "中文") and allows users to switch between available languages.
- **FR-005**: App MUST persist the selected language preference across app restarts.
- **FR-006**: App MUST update all UI elements (buttons, labels, messages, titles) to reflect the selected language within 1 second of language change.
- **FR-007**: App MUST handle missing custom icon file by falling back to default Flutter icon without crashing.
- **FR-008**: App MUST handle missing translations by falling back to English text with appropriate error logging.
- **FR-009**: Language switching MUST stop any in-progress TTS reading before applying the language change.

### Key Entities

- **AppTitle**: Localized app title string - English: "KalaHoo", Chinese: "卡啦虎"
- **AppIcon**: Custom app icon file path - images/kalahu.jpeg
- **LanguagePreference**: User's selected interface language - "en" or "zh-Hans", persisted across sessions
- **UITranslations**: Mapping of UI text strings to language-specific values for all interface elements, including native language names for the dropdown ("English", "中文")

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: App displays correct localized title ("KalaHoo" or "卡啦虎") based on selected language 100% of the time on both Android and iOS platforms.
- **SC-002**: Custom app icon from images/kalahu.jpeg displays correctly on device home screens 100% of the time when file is present.
- **SC-003**: Language switching completes and updates all UI elements within 1 second on both platforms.
- **SC-004**: Language preference persists correctly across app restarts 100% of the time.
- **SC-005**: Graceful fallback (default icon, English text) works 100% of the time when custom resources are missing or corrupted.

## Assumptions

- images/kalahu.jpeg file will be provided by the user and is a valid image format supported by mobile platforms.
- Flutter's internationalization (flutter_localizations and intl packages) will be used for i18n implementation.
- Language preference will be stored using shared_preferences (already in use from spec 002).
- The app's existing TTS functionality (specs 001-003) will continue to work with the new interface language selection.
- Android and iOS platforms both support dynamic app icon changes through their respective configuration systems.
- Chinese translations will use Simplified Chinese (zh-Hans) as in previous specs.
- The language selector dropdown will be accessible from the main reading interface for easy access, displaying native language names ("English", "中文") and supporting future expansion to 2+ languages.
