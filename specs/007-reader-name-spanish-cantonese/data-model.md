# Data Model: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-22

## Entities

### LanguageConfig

**Purpose**: Extended language configuration including Latin American Spanish support

**Attributes**:
- `languageCode` (String): Language code (e.g., "en", "zh", "es-MX")
- `languageName` (String): Native language name (e.g., "English", "中文", "Español")
- `localeCode` (String): Full locale code (e.g., "en-US", "zh-Hans", "es-MX")
- `isSupported` (bool): Whether this language is fully supported with translations
- `hasTTS` (bool): Whether TTS voices are available for this language

**Relationships**:
- Used by: LocalizationService for language selection
- Maps to: ARB files (app_en.arb, app_zh.arb, app_es_mx.arb)

**Validation Rules**:
- `languageCode` must be a valid ISO 639-1 code with regional variant for Spanish
- `localeCode` must match available system locales
- Latin American Spanish requires complete ARB translations before `isSupported` can be true

**Sample Data**:
```dart
LanguageConfig(
  languageCode: "es-MX",
  languageName: "Español",
  localeCode: "es-MX",
  isSupported: true,
  hasTTS: true,
)
```

### VoiceMapping

**Purpose**: Extended voice mapping including Cantonese dialect options under Chinese voices

**Attributes**:
- `systemVoiceId` (String): System voice identifier (e.g., "zh-hk-x-ioc-local" for Cantonese)
- `englishName` (String): User-friendly name in English (e.g., "Chinese Voice 1")
- `chineseName` (String): User-friendly name in Chinese (e.g., "中文声1")
- `languageCode` (String): Language code (e.g., "zh" for Chinese)
- `dialect` (String?): Dialect identifier (e.g., "cantonese", null for standard)
- `dialectDisplay` (String?): Display name for dialect (e.g., "广东话")
- `gender` (String?): Gender characteristic ("male", "female", or null)
- `age` (String?): Age characteristic ("young", "old", or null)

**Relationships**:
- Used by: VoiceMappingService for lookup
- Maps to: System voice IDs from flutter_tts
- Groups by: Language (dialects appear under parent language)

**Validation Rules**:
- `systemVoiceId` is required and unique
- Dialect entries must have parent language entry
- `dialectDisplay` uses Chinese characters only (as per requirement)

**Sample Data**:
```dart
VoiceMapping(
  systemVoiceId: "zh-hk-x-ioc-local",
  englishName: "Chinese Voice 1",
  chineseName: "中文声1",
  languageCode: "zh",
  dialect: "cantonese",
  dialectDisplay: "广东话",
  gender: "female",
  age: "young",
)
```

### DialectConfig

**Purpose**: Dialect options within language-specific voice selections

**Attributes**:
- `languageCode` (String): Parent language code (e.g., "zh" for Chinese)
- `dialectCode` (String): Dialect identifier (e.g., "cantonese")
- `dialectName` (String): Native dialect name (e.g., "广东话")
- `voiceIds` (List<String>): List of system voice IDs supporting this dialect
- `isAvailable` (bool): Whether this dialect is available on current device

**Relationships**:
- Used by: Voice picker to show dialect options under language selection
- Filters: VoiceMapping entries by dialect
- Depends on: flutter_tts voice availability

**Validation Rules**:
- `dialectCode` must be unique within `languageCode`
- `voiceIds` list cannot be empty when `isAvailable` is true
- `dialectName` uses native language characters (Chinese for Cantonese)

**Sample Data**:
```dart
DialectConfig(
  languageCode: "zh",
  dialectCode: "cantonese",
  dialectName: "广东话",
  voiceIds: ["zh-hk-x-ioc-local", "zh-hk-x-joh-local"],
  isAvailable: true,
)
```

### LocalizedStrings

**Purpose**: Latin American Spanish ARB translations for all UI elements and app title

**Attributes**:
- `locale` (String): Locale code (e.g., "es-MX")
- `appTitle` (String): App title translation (e.g., "KalaHoo Lectura")
- `languageLabel` (String): Language selector label
- `spanishLabel` (String): Spanish language name in native form
- All other UI translation keys (readButton, stopButton, etc.)

**Relationships**:
- Stored in: app_es_mx.arb file
- Loaded by: Flutter's localization system
- References: AppLocalizations class

**Validation Rules**:
- All English keys must have corresponding Latin American Spanish translations
- App title must match "KalaHoo Lectura" exactly
- Percent/placeholder syntax must match English ARB
- Vocabulary and cultural references align with US educational standards