# Quickstart: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-22

## Prerequisites

- Flutter development environment setup
- Android emulator or physical device running
- flutter_tts plugin installed (version 4.2.3 or compatible)
- Existing klhu app with specs 001-004 implemented
- Spec 005 (icon buttons and pause/resume) completed

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
flutter pub get
flutter gen-l10n
```

## Validation Scenarios

### Scenario 1: App Title in English Mode

**Goal**: Verify app title displays as "KalaHoo Reading" in English interface

**Steps**:
1. Launch app in English interface mode
2. Observe app bar title
3. Check app launcher display

**Expected Outcome**:
- App bar shows "KalaHoo Reading"
- App launcher shows "KalaHoo Reading"
- All UI elements in English

### Scenario 2: App Title in Chinese Mode

**Goal**: Verify app title displays as "卡啦虎朗读" in Chinese interface

**Steps**:
1. Switch interface language to Chinese via dropdown
2. Observe app bar title
3. Check UI elements

**Expected Outcome**:
- App bar shows "卡啦虎朗读"
- All UI elements in Chinese
- Language dropdown shows current selection

### Scenario 3: App Title in Latin American Spanish Mode

**Goal**: Verify app title displays as "KalaHoo Lectura" in Latin American Spanish interface

**Steps**:
1. Switch interface language to Spanish via dropdown
2. Observe app bar title
3. Check UI elements

**Expected Outcome**:
- App bar shows "KalaHoo Lectura"
- All UI elements in Spanish
- Language dropdown shows "Español" as current selection

### Scenario 4: Spanish Language Switching

**Goal**: Verify Spanish language option is available and functional

**Steps**:
1. Open language dropdown
2. Select "Español"
3. Observe interface changes
4. Navigate through app screens

**Expected Outcome**:
- Language dropdown shows "Español" option
- Interface switches to Spanish translations
- All buttons, labels, messages in Spanish
- Language preference persisted across app restart

### Scenario 5: Spanish TTS Reading

**Goal**: Verify Spanish TTS reading works with proper voice selection

**Steps**:
1. Switch to Spanish interface
2. Load Spanish text sample
3. Tap Read button
4. Observe audio output

**Expected Outcome**:
- Reading uses Spanish voice
- Pronunciation is correct for Spanish text
- No fallback to English voice
- Audio quality acceptable for language learning

### Scenario 6: Spanish Voice Preview

**Goal**: Verify Spanish voice preview works correctly

**Steps**:
1. Switch to Spanish interface
2. Tap Voice button
3. Select Spanish voice
4. Tap preview button

**Expected Outcome**:
- Voice picker shows Spanish voices
- Preview plays Spanish sample text
- Audio output clearly Spanish with proper intonation
- Voice selection persists

### Scenario 7: Spanish Device Locale Detection

**Goal**: Verify app defaults to Spanish when device locale is Spanish

**Steps**:
1. Set device locale to Spanish (emulator settings)
2. Clear app data (fresh install simulation)
3. Launch app
4. Observe default interface language

**Expected Outcome**:
- App defaults to Spanish interface
- App title shows "KalaHoo Lectura"
- No manual language selection required
- User can still switch to other languages

### Scenario 8: Cantonese Dialect Under Chinese

**Goal**: Verify Cantonese appears as dialect option under Chinese voice selection

**Steps**:
1. Switch to Chinese interface
2. Tap Voice button
3. Select Chinese (中文) voice category
4. Observe dialect options

**Expected Outcome**:
- Chinese voice category shows dialect options
- Cantonese (广东话) appears as dialect option
- Dialect uses Chinese characters only
- Standard Chinese voices remain available

### Scenario 9: Cantonese Dialect Selection

**Goal**: Verify Cantonese dialect reading works correctly

**Steps**:
1. Select Chinese voice category
2. Choose Cantonese (广东话) dialect
3. Load Chinese text sample
4. Tap Read button
5. Observe audio output

**Expected Outcome**:
- Reading uses Cantonese pronunciation
- Audio clearly Cantonese dialect
- Chinese text read with Cantonese intonation
- Dialect selection persists for reading

### Scenario 10: Cantonese Display in English Interface

**Goal**: Verify Cantonese displays as "广东话" in English interface

**Steps**:
1. Switch to English interface
2. Tap Voice button
3. Select Chinese voice category
4. Observe Cantonese dialect display

**Expected Outcome**:
- Cantonese displays as "广东话" (Chinese characters)
- No English translation "Cantonese" shown
- Display consistent with requirement
- Other dialects follow same pattern

### Scenario 11: Language Switching Between All Three

**Goal**: Verify seamless switching between English, Chinese, and Spanish

**Steps**:
1. Start in English interface
2. Switch to Chinese
3. Switch to Spanish
4. Switch back to English
5. Observe app titles and UI elements

**Expected Outcome**:
- Each switch completes within 500ms
- App titles update correctly for each language
- UI elements translate completely
- No UI corruption or crashes
- Language preference persists correctly

### Scenario 12: Incomplete Spanish Translations Fallback

**Goal**: Verify graceful fallback when Spanish translations are incomplete

**Steps**:
1. Temporarily remove some Spanish ARB entries (simulated)
2. Switch to Spanish interface
3. Navigate through app

**Expected Outcome**:
- Incomplete translations fall back to English
- No crashes or errors
- Partial Spanish translations still show
- App remains functional

### Scenario 13: Cantonese Unavailable Fallback

**Goal**: Verify fallback when Cantonese dialect unavailable

**Steps**:
1. On device without Cantonese voice support
2. Select Chinese voice category
3. Check for Cantonese option

**Expected Outcome**:
- Cantonese option hidden or marked unavailable
- Standard Chinese voices still available
- No crashes or errors
- User can still use Chinese TTS

## Test Commands

### Unit Tests
```bash
# Run Spanish localization tests
flutter test test/spanish_localization_test.dart

# Run Cantonese dialect tests
flutter test test/cantonese_dialect_test.dart

# Run all tests
flutter test
```

### Build and Run
```bash
# Build APK
flutter build apk

# Run on Android emulator
flutter run -d emulator-5554

# Run on physical device
flutter run -d <device_id>
```

### Localization Generation
```bash
# Generate localization files
flutter gen-l10n

# Verify ARB files
ls lib/l10n/
```

## Troubleshooting

**Spanish app title not displaying**:
- Check app_es.arb contains appTitle key with "KalaHoo Lectura"
- Verify l10n.yaml includes Spanish in supported locales
- Ensure LocalizationService loads Spanish locale correctly

**Spanish language option not appearing**:
- Check LanguageConfig includes Spanish with isSupported: true
- Verify app_es.arb exists and is valid
- Ensure language dropdown includes Spanish option

**Cantonese not appearing under Chinese voices**:
- Check DialectConfig includes Cantonese under Chinese
- Verify VoiceMapping has Cantonese entries with dialect: "cantonese"
- Ensure flutter_tts returns Cantonese voices (zh-HK locale)

**Cantonese showing English text instead of Chinese characters**:
- Check dialectDisplay field uses "广东话" (Chinese characters)
- Verify voice picker displays dialectDisplay correctly
- Ensure no English translation logic for dialect names

**Spanish TTS not working**:
- Verify flutter_tts has Spanish voices available
- Check language code set to "es-ES" or "es-MX"
- Ensure voice selection filters by Spanish locale
- Test with standard Spanish voice fallback if needed

**App title not updating in launcher**:
- Check Android strings.xml in values-es/ has correct title
- Verify iOS InfoPlist.strings in es.lproj/ has correct title
- Ensure app is rebuilt after metadata changes
- Reinstall app to update launcher icon/title