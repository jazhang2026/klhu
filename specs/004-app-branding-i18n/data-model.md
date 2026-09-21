# Data Model: App Branding and Internationalization

**Feature**: 004-app-branding-i18n | **Date**: 2026-09-17

## Entities

### LanguagePreference

**Purpose**: Stores user's selected interface language preference across app sessions

**Fields**:
- `languageCode`: String - Language identifier ("en" for English, "zh-Hans" for Simplified Chinese)
- `lastUpdated`: DateTime - Timestamp of last preference change

**Validation Rules**:
- `languageCode` must be either "en" or "zh-Hans"
- Default value: "en" (English) if no preference exists
- Invalid values fall back to "en" with error logging

**Storage**:
- Key: `interface_language` in shared_preferences
- Format: String (language code only)
- Persistence: Survives app restarts and app updates

**State Transitions**:
```
[No Preference] → [English Selected] → [Chinese Selected] → [English Selected]
     ↓                    ↓                  ↓                  ↓
   Default          Persisted          Persisted          Persisted
```

### AppTitle

**Purpose**: Localized app title strings for display in UI and OS-level presentation

**Fields**:
- `englishTitle`: String - "KalaHoo"
- `chineseTitle`: String - "卡啦虎"

**Validation Rules**:
- Both titles must be non-empty strings
- Chinese title must use Simplified Chinese characters
- Titles must match spec requirements exactly

**Usage Contexts**:
- In-app AppBar titles (Flutter i18n)
- OS home screen display (platform-specific)
- App switcher/task manager (platform-specific)

**Retrieval Logic**:
```
IF interface_language == "en" THEN return englishTitle
ELSE IF interface_language == "zh-Hans" THEN return chineseTitle
ELSE return englishTitle (fallback)
```

### AppIcon

**Purpose**: Custom app icon resource reference

**Fields**:
- `iconPath`: String - "images/kalahu.jpeg"
- `fallbackAvailable`: Boolean - Always true (Flutter default icon)

**Validation Rules**:
- Icon file must be JPEG format
- File must exist at specified path for custom icon display
- Invalid/missing files trigger fallback to default Flutter icon

**Platform-Specific Paths**:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**Fallback Strategy**:
```
IF custom icon file exists AND is valid THEN use custom icon
ELSE use default Flutter icon (no crash, log warning)
```

### UITranslations

**Purpose**: Mapping of all UI text strings to language-specific values

**Structure**: Map of translation keys to language-specific values

**Translation Keys** (examples):
- `appTitle`: "KalaHoo" / "卡啦虎"
- `readButton`: "Read" / "朗读"
- `stopButton`: "Stop" / "停止"
- `editButton`: "Edit" / "编辑"
- `doneButton`: "Done" / "完成"
- `voiceButton`: "Voice" / "语音"
- `languageDropdown`: "Language" / "语言"
- `englishNative`: "English" / "English" (native name, same in both languages)
- `chineseNative`: "中文" / "中文" (native name, same in both languages)
- `hintText`: "Tap a sentence to read" / "点击句子开始朗读"

**Validation Rules**:
- Every translation key must have both English and Chinese values
- No empty string values allowed
- Missing translations fall back to English with error logging
- Translation files must be valid ARB JSON format

**File Structure**:
```
lib/l10n/
├── app_en.arb        # English translations
└── app_zh.arb        # Chinese translations
```

**Retrieval Logic**:
```
translations = AppLocalizations.of(context)
IF interface_language == "en" THEN use app_en.arb
ELSE IF interface_language == "zh-Hans" THEN use app_zh.arb
ELSE use app_en.arb (fallback)
```

## Entity Relationships

```
LanguagePreference
    ├── determines → AppTitle selection
    ├── determines → UITranslations selection
    └── persisted via → shared_preferences

AppTitle
    └── displayed in → UI (Flutter) + OS (platform-specific)

AppIcon
    └── displayed in → OS home screen + app switcher

UITranslations
    └── applied to → All UI widgets (buttons, labels, messages)
```

## Data Flow

### Language Switching Flow
```
User Action → LanguageSelector Widget
    ↓
LocalizationService.updateLanguage(newLanguage)
    ↓
shared_preferences.save("interface_language", newLanguage)
    ↓
MaterialApp.locale = Locale(newLanguage)
    ↓
AppLocalizations rebuild with new locale
    ↓
All UI widgets update with new translations
    ↓
ReaderService.stop() (if reading in progress)
```

### App Startup Flow
```
App Launch → LocalizationService.loadLanguage()
    ↓
shared_preferences.load("interface_language", default: "en")
    ↓
MaterialApp.locale = Locale(loadedLanguage)
    ↓
AppLocalizations initialized with loaded locale
    ↓
UI displays with correct language
```

## Persistence Strategy

### Storage Keys
- `interface_language`: User's selected interface language (String)

### Storage Format
- Simple string value: "en" or "zh-Hans"
- No complex serialization needed
- Direct compatibility with existing shared_preferences setup

### Migration Strategy
- No migration needed (new feature)
- Default to "en" if key doesn't exist
- Backward compatible with existing VoiceStore keys

## Error Handling

### Storage Failures
- Fallback to English ("en")
- Log error to console
- App remains functional
- Show user-friendly error message if possible

### Translation File Errors
- Fallback to English translations
- Log specific missing key errors
- UI remains functional with English text
- No crash on missing translations

### Icon File Errors
- Fallback to default Flutter icon
- Log file access errors
- App launches normally
- No impact on functionality

## Validation Requirements

### Unit Tests
- LanguagePreference storage/retrieval round-trip
- Invalid language code handling
- Missing preference default behavior
- Translation key lookup with fallbacks

### Widget Tests
- Language selector state changes
- UI updates on language switching
- Icon fallback behavior
- Title localization in different contexts

### Integration Tests
- End-to-end language switching flow
- App icon display on both platforms
- App title localization verification
- Preference persistence across restarts