# Quickstart Validation: App Branding and Internationalization

**Feature**: 004-app-branding-i18n | **Date**: 2026-09-17

## Prerequisites

- Flutter SDK 3.47.4+ installed
- Android emulator with API 29+ (Android 10+) configured
- iPhone simulator with iOS 16+ (if macOS available)
- Custom app icon file: `images/kalahu.jpeg` (user-provided)
- Git branch: `004-app-branding-i18n`
- Previous specs (001-003) completed and tested

## Setup Commands

```bash
# Navigate to project directory
cd /home/weihongzhang/Documents/GitHub/Projects/klhu

# Ensure correct branch
git checkout 004-app-branding-i18n

# Add i18n dependencies
flutter pub add flutter_localizations intl
flutter pub get

# Place custom app icon (user-provided)
# Copy kalahu.jpeg to images/kalahu.jpeg
# Ensure file exists before proceeding

# Verify dependencies
flutter doctor
flutter analyze
```

## App Icon Setup

### Android Icon Setup
```bash
# Generate multiple icon sizes from kalahu.jpeg
# Place in android/app/src/main/res/mipmap-*/ directories:
# - mipmap-mdpi/ic_launcher.png (48x48)
# - mipmap-hdpi/ic_launcher.png (72x72)
# - mipmap-xhdpi/ic_launcher.png (96x96)
# - mipmap-xxhdpi/ic_launcher.png (144x144)
# - mipmap-xxxhdpi/ic_launcher.png (192x192)

# Update AndroidManifest.xml
# android:icon="@mipmap/ic_launcher"
```

### iOS Icon Setup
```bash
# Add icon to iOS project
# Place kalahu.jpeg in ios/Runner/Assets.xcassets/AppIcon.appiconset/
# Ensure proper sizes for iOS icon requirements
```

## Validation Scenarios

### Scenario 1: App Icon Display

**Goal**: Verify custom app icon displays correctly on device home screen

**Steps**:
1. Build and install app on Android emulator:
   ```bash
   flutter run -d emulator-5554
   ```
2. Navigate to device home screen
3. Locate klhu app icon
4. Verify custom icon from kalahu.jpeg is displayed

**Expected Outcome**:
- App icon matches kalahu.jpeg image
- Icon displays correctly on home screen
- No default Flutter icon visible

**Fallback Test**:
1. Remove kalahu.jpeg temporarily
2. Rebuild and install app
3. Verify default Flutter icon displays without crash

### Scenario 2: App Title Localization - English

**Goal**: Verify app displays "KalaHoo" title in English mode

**Steps**:
1. Launch app on Android emulator
2. Ensure device language is set to English
3. Observe app title in AppBar
4. Check app title in home screen/app switcher

**Expected Outcome**:
- AppBar displays "KalaHoo"
- Home screen shows "KalaHoo"
- App switcher displays "KalaHoo"

### Scenario 3: App Title Localization - Chinese

**Goal**: Verify app displays "卡啦虎" title in Chinese mode

**Steps**:
1. Change device language to Chinese (Simplified)
2. Launch app on Android emulator
3. Observe app title in AppBar
4. Check app title in home screen/app switcher

**Expected Outcome**:
- AppBar displays "卡啦虎"
- Home screen shows "卡啦虎"
- App switcher displays "卡啦虎"

### Scenario 4: Language Switching - English to Chinese

**Goal**: Verify user can switch from English to Chinese interface via dropdown

**Steps**:
1. Launch app in English mode
2. Verify language dropdown shows "English" (current language in native name)
3. Tap language dropdown in AppBar
4. Verify dropdown list shows "English" and "中文" (native names)
5. Select "中文" from the dropdown
6. Observe UI updates

**Expected Outcome**:
- Language dropdown displays "English" before selection
- Dropdown list shows both languages with native names
- All UI elements update to Chinese within 1 second
- Buttons show Chinese labels: "朗读", "停止", "编辑", "完成"
- Language dropdown now shows "中文" as current selection
- App title updates to "卡啦虎"

### Scenario 5: Language Switching - Chinese to English

**Goal**: Verify user can switch from Chinese to English interface via dropdown

**Steps**:
1. Launch app in Chinese mode
2. Verify language dropdown shows "中文" (current language in native name)
3. Tap language dropdown in AppBar
4. Verify dropdown list shows "English" and "中文" (native names)
5. Select "English" from the dropdown
6. Observe UI updates

**Expected Outcome**:
- Language dropdown displays "中文" before selection
- Dropdown list shows both languages with native names
- All UI elements update to English within 1 second
- Buttons show English labels: "Read", "Stop", "Edit", "Done"
- Language dropdown now shows "English" as current selection
- App title updates to "KalaHoo"

### Scenario 6: Language Preference Persistence

**Goal**: Verify language preference persists across app restarts

**Steps**:
1. Launch app in English mode
2. Switch to Chinese interface
3. Close app completely (swipe away from recent apps)
4. Relaunch app
5. Verify interface remains in Chinese

**Expected Outcome**:
- App launches in Chinese mode
- All UI elements display Chinese text
- No automatic reversion to English

### Scenario 7: Language Switching During Reading

**Goal**: Verify language switching stops TTS reading

**Steps**:
1. Load sample text
2. Start reading (tap Read or Read page)
3. While reading, tap language dropdown
4. Select different language from dropdown
5. Verify reading stops

**Expected Outcome**:
- TTS reading stops immediately when language changes
- UI updates to new language
- No audio overlap or conflicts
- Can start new reading in new language

### Scenario 8: Missing Translation Fallback

**Goal**: Verify app handles missing translations gracefully

**Steps**:
1. Temporarily remove a translation key from app_zh.arb
2. Launch app in Chinese mode
3. Navigate to screen with missing translation
4. Observe behavior

**Expected Outcome**:
- Missing translation shows English text
- App does not crash
- Error logged to console
- Other translations work normally

### Scenario 9: Rapid Language Switching

**Goal**: Verify app handles rapid language switching correctly

**Steps**:
1. Launch app in English mode
2. Rapidly tap language dropdown multiple times
3. Switch between English and Chinese quickly via dropdown
4. Observe final state

**Expected Outcome**:
- Only latest language selection takes effect
- No UI corruption or crashes
- App remains responsive
- Final language is correctly applied
- Dropdown shows correct native name for final selection

### Scenario 10: Accessibility with Screen Readers

**Goal**: Verify language dropdown works with screen readers

**Steps**:
1. Enable TalkBack on Android emulator
2. Launch app
3. Navigate to language dropdown
4. Expand dropdown
5. Switch language
6. Verify announcements

**Expected Outcome**:
- Language dropdown has proper semantic labels
- Current language announced in native name
- Language changes are announced to screen reader
- Touch targets meet 44pt minimum
- Navigation remains logical

## Test Commands

### Unit Tests
```bash
# Run language preference tests
flutter test test/language_preference_test.dart

# Run localization service tests
flutter test test/localization_service_test.dart

# Run translation file tests
flutter test test/l10n_test.dart
```

### Widget Tests
```bash
# Run language dropdown widget tests
flutter test test/reading_view_test.dart

# Run branding widget tests
flutter test test/branding_widget_test.dart

# Run all widget tests
flutter test
```

### Integration Tests
```bash
# Run on Android emulator
flutter drive --target=test_driver/app.dart -d emulator-5554

# Run on iPhone simulator (if available)
flutter drive --target=test_driver/app.dart -d iphone-simulator
```

## Verification Checklist

- [ ] Custom app icon displays on Android home screen
- [ ] Custom app icon displays on iOS home screen (if tested)
- [ ] App title shows "KalaHoo" in English mode
- [ ] App title shows "卡啦虎" in Chinese mode
- [ ] Language dropdown accessible from main interface
- [ ] Language dropdown shows current language in native name ("English"/"中文")
- [ ] Dropdown list shows available languages with native names
- [ ] Language switching completes within 1 second
- [ ] All UI elements update on language change
- [ ] Language preference persists across restarts
- [ ] Language switching stops TTS reading
- [ ] Missing translations fall back to English
- [ ] Rapid switching handled correctly
- [ ] Screen reader announcements work correctly
- [ ] App doesn't crash on missing icon file
- [ ] App doesn't crash on missing translations
- [ ] Touch targets meet accessibility requirements

## Success Criteria Validation

**SC-001**: App displays correct localized title 100% of the time
- Test: Scenarios 2, 3, 4, 5

**SC-002**: Custom app icon displays correctly 100% of the time when file present
- Test: Scenario 1

**SC-003**: Language switching completes within 1 second
- Test: Scenarios 4, 5

**SC-004**: Language preference persists 100% of the time
- Test: Scenario 6

**SC-005**: Graceful fallback works 100% of the time
- Test: Scenarios 1 (fallback), 8 (translation fallback)

## Troubleshooting

**Icon not displaying**:
- Verify kalahu.jpeg exists in correct location
- Check file format is valid JPEG
- Ensure proper icon sizes for platform requirements
- Verify AndroidManifest.xml and Info.plist configurations

**Language not switching**:
- Check shared_preferences storage
- Verify MaterialApp locale configuration
- Ensure AppLocalizations is properly initialized
- Check ARB file syntax and format
- Verify dropdown state management and native name display

**Translations not updating**:
- Verify ARB files are in lib/l10n/ directory
- Check MaterialApp localizationsDelegates configuration
- Ensure context has access to AppLocalizations
- Verify translation keys match between languages

**Crashes on missing resources**:
- Implement proper fallback logic
- Add null checks for resource loading
- Ensure error handling doesn't propagate to UI
- Log errors for debugging