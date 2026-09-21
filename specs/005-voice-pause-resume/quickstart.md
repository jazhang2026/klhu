# Quickstart: Voice List Improvements and Pause/Resume Functionality

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-21

## Prerequisites

- Flutter development environment setup
- Android emulator or physical device running
- flutter_tts plugin installed (version 4.2.3 or compatible)
- Existing klhu app with specs 001-004 implemented

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
flutter pub get
flutter gen-l10n
```

## Validation Scenarios

### Scenario 1: Voice Names in English Mode

**Goal**: Verify voice picker displays user-friendly names in English with characteristics

**Steps**:
1. Launch app in English interface mode
2. Tap Voice button to open voice picker
3. Observe voice list display

**Expected Outcome**:
- Voice names display in English (e.g., "Female Voice 1 (Young, Standard)")
- Characteristics shown: gender, age, dialect when available
- At least 90% of voices have user-friendly names
- Fallback to system name for unmapped voices

### Scenario 2: Voice Names in Chinese Mode

**Goal**: Verify voice picker displays user-friendly names in Chinese with characteristics

**Steps**:
1. Switch interface language to Chinese via dropdown
2. Tap Voice button to open voice picker
3. Observe voice list display

**Expected Outcome**:
- Voice names display in Chinese (e.g., "女声1 (年轻, 标准音)")
- Characteristics shown in Chinese: 性别, 年龄, 方言 when available
- Matches English mapping characteristics
- Immediate language switch for voice names

### Scenario 3: Pause Page Reading

**Goal**: Verify Pause button stops reading and changes to Resume

**Steps**:
1. Load sample text
2. Tap "Read page" button
3. Wait for reading to start
4. Tap Pause button

**Expected Outcome**:
- Reading stops at current position
- Button changes from Pause to Resume
- Reading state is paused (not idle)
- Current paragraph is tracked for resume

### Scenario 4: Resume Page Reading

**Goal**: Verify Resume continues from paused position

**Steps**:
1. Start page reading
2. Tap Pause button
3. Tap Resume button

**Expected Outcome**:
- Reading continues from paused paragraph
- Button changes back to Pause
- Resume position accuracy is 100%
- No duplicate or skipped paragraphs

### Scenario 5: Stop on Other Action While Paused

**Goal**: Verify reading stops completely when non-Resume action taken while paused

**Steps**:
1. Start page reading
2. Tap Pause button
3. Tap Read (sentence) button

**Expected Outcome**:
- Reading stops completely (does not resume)
- State resets to idle
- Button returns to Read page
- Stop completes within 500ms

### Scenario 6: Stop Button While Paused

**Goal**: Verify Stop button stops reading completely while paused

**Steps**:
1. Start page reading
2. Tap Pause button
3. Tap Stop button

**Expected Outcome**:
- Reading stops completely
- State resets to idle
- Button returns to Read page
- Resume position cleared

### Scenario 7: Language Switch While Paused

**Goal**: Verify reading stops completely when language switched while paused

**Steps**:
1. Start page reading
2. Tap Pause button
3. Switch interface language via dropdown

**Expected Outcome**:
- Reading stops completely (spec 004 requirement)
- State resets to idle
- Interface language changes
- No resume position preservation

### Scenario 8: Auto-Complete at End of Page

**Goal**: Verify button returns to Read page when reading completes

**Steps**:
1. Load short sample text (1-2 paragraphs)
2. Tap "Read page" button
3. Wait for reading to complete

**Expected Outcome**:
- Reading auto-stops at end
- Button returns to Read page (not Pause)
- State resets to idle
- No residual pause state

### Scenario 9: Rapid Pause/Resume Toggling

**Goal**: Verify latest action takes effect with rapid toggling

**Steps**:
1. Start page reading
2. Rapidly tap Pause and Resume multiple times
3. Observe final state

**Expected Outcome**:
- Only latest action takes effect
- No UI corruption or crashes
- App remains responsive
- Final state matches last button press

### Scenario 10: Voice Mapping Fallback

**Goal**: Verify unmapped voices fall back to system names

**Steps**:
1. Add a test voice not in mapping table (if possible)
2. Open voice picker
3. Observe display

**Expected Outcome**:
- Unmapped voice displays system voice name
- No crash or error
- Voice can still be selected and previewed
- Other voices still show mapped names

## Test Commands

### Unit Tests
```bash
# Run voice mapping tests
flutter test test/voice_mapping_test.dart

# Run pause/resume state tests
flutter test test/reading_view_pause_test.dart

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

## Troubleshooting

**Voice names not displaying in user-friendly format**:
- Check VoiceMapping static table includes the system voice ID
- Verify voice picker uses VoiceMappingService for lookup
- Check ARB files have characteristic translations

**Pause button not appearing during page reading**:
- Verify ReadingState enum and state management logic
- Check button state updates on reading start
- Ensure page reading triggers reading state (not idle)

**Resume not continuing from correct position**:
- Verify currentParagraphIndex is tracked correctly
- Check resume uses saved paragraph index
- Validate paragraph index bounds before resume

**Reading not stopping on other action while paused**:
- Verify state check logic for non-Resume actions
- Check all actions trigger full stop when paused
- Ensure guard prevents resume after other actions

**Chinese voice names not displaying**:
- Check app_zh.arb has voice characteristic translations
- Verify AppLocalizations loads correctly for Chinese locale
- Ensure Chinese voice names are in mapping tablesk-d31f69142a794215b0439a9186440ddf