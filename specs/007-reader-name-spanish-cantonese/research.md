# Research: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Feature**: [spec.md](./spec.md)
**Date**: 2026-09-22

## Latin American Spanish Language Support

### Decision: Extend existing ARB infrastructure with Latin American Spanish (es-MX) translations

**Rationale**: The existing English/Chinese ARB infrastructure (app_en.arb, app_zh.arb) provides a proven pattern for adding additional languages. Adding app_es_mx.arb follows the same approach without requiring architectural changes. Latin American Spanish (es-MX) is chosen because it aligns with US high school curriculum and is the most commonly taught Spanish variant in US schools, making it ideal for language learning applications.

**Implementation Details**:
- Create app_es_mx.arb file with Latin American Spanish translations for all UI elements
- Add Spanish app title "KalaHoo Lectura" to app_es_mx.arb
- Update LocalizationService to include Latin American Spanish (es-MX) in supported languages
- Update l10n.yaml to include Latin American Spanish in supported locales
- Latin American Spanish language code: "es-MX" for Mexican Spanish
- Default any Spanish locale to es-MX for consistency with US curriculum

**UI Integration**:
- Language dropdown adds "Español" option for Latin American Spanish
- Language preference persistence uses shared_preferences with "es-MX" value
- Device locale detection adds Spanish fallback, defaulting to es-MX for any Spanish locale
- Latin American Spanish TTS voice selection uses flutter_tts language code matching es-MX
- Vocabulary and cultural references align with US educational standards

**Alternatives Considered**:
- General Spanish (es) without regional specification: Rejected - doesn't align with US curriculum
- Castilian Spanish (es-ES): Rejected - not commonly taught in US schools
- Multiple Spanish variants simultaneously: Rejected - adds complexity for v1, can extend later
- External translation service: Rejected - violates on-device-first principle

## Cantonese Dialect Support

### Decision: Implement dialect options under Chinese voice selection

**Rationale**: Cantonese is a dialect of Chinese, not a separate language. Placing it under Chinese (中文) voice selection follows linguistic conventions and maintains logical organization. flutter_tts supports Cantonese through specific voice IDs (zh-HK locale).

**Implementation Details**:
- Create DialectConfig model to handle dialect options within language selections
- Modify voice picker to show dialect options when Chinese is selected
- Use zh-HK locale code for Cantonese voice identification
- Display Cantonese as "广东话" (Chinese characters only) in both English and Chinese interfaces
- Fallback to standard Chinese voice if Cantonese unavailable

**Voice Mapping**:
- Extend VoiceMapping to include dialect-specific entries
- Map Cantonese voice IDs to "广东话" display name
- Dialect selection stored as part of voice preference (e.g., "zh-cantonese")
- Standard Chinese voices remain available without dialect selection

**Alternatives Considered**:
- Separate Cantonese language option: Rejected - Cantonese is a dialect, not a separate language
- English label "Cantonese": Rejected - user requirement specifies Chinese characters only
- Regional dialect variants: Rejected - start with Cantonese, can extend to other dialects later

## App Title Changes

### Decision: Update platform-specific app metadata for three languages

**Rationale**: App titles need to be updated in both Flutter UI and platform-specific metadata (Android manifest, iOS Info.plist) for proper display in app launchers and system UI.

**Implementation Details**:
- **Flutter UI**: Update app_title in ARB files for all three languages
- **Android**: Update strings.xml in values/, values-zh/, and create values-es/
- **iOS**: Update Info.plist base title and create es.lproj/InfoPlist.strings
- **Backward compatibility**: App title changes are cosmetic, no data migration needed

**Platform-Specific Details**:
- **Android**: Add <string name="app_name">KalaHoo Reading</string> to values/strings.xml
- **Android**: Add <string name="app_name">卡啦虎朗读</string> to values-zh/strings.xml
- **Android**: Add <string name="app_name">KalaHoo Lectura</string> to values-es/strings.xml
- **iOS**: Update CFBundleDisplayName in Info.plist and localized InfoPlist.strings

**Alternatives Considered**:
- Dynamic app title loading: Rejected - platform metadata is static at build time
- Single app title across languages: Rejected - violates localization requirement
- Runtime title override: Rejected - platform launchers don't support dynamic titles

## flutter_tts Latin American Spanish Voice Support

### Decision: Verify and utilize flutter_tts Latin American Spanish voice capabilities

**Rationale**: Need to confirm flutter_tts plugin supports Latin American Spanish voices and proper Mexican/Latin American pronunciation for language learning use cases aligned with US high school curriculum.

**Implementation Details**:
- Set language to "es-MX" for Latin American Spanish TTS
- Filter available voices by Latin American Spanish locale codes
- Provide Latin American Spanish voice preview with sample text
- Handle cases where Latin American Spanish voices are unavailable (fallback to Spanish-compatible voice or default)
- Ensure vocabulary and pronunciation align with US educational standards

**Alternatives Considered**:
- Custom Latin American Spanish TTS engine: Rejected - violates simplicity principle
- Network-based Latin American Spanish TTS: Rejected - violates on-device-first principle
- Assume Latin American Spanish voice availability: Rejected - need graceful fallback for missing voices

## Grounding corrections (verified on emulator-5554, 2026-09-22)

The plan above was written without the engine in front of it; two of its assumptions
are wrong and the implementation follows the corrected versions below.

### Correction 1: `es-MX` is a UI locale, not a TTS locale

A `getVoices()` sweep of the emulator's Google TTS (`klhu getVoices` logcat lines from
the app's own picker, 312 voices total) reports exactly two Spanish locales:

| locale | voices |
|---|---|
| `es-ES` | `es-es-x-eea-{local,network}`, `es-es-x-eec-network`, `es-es-x-eed-local`, `es-es-x-eee-local`, `es-es-x-eef-local` |
| `es-US` | `es-US-language`, `es-us-x-esc-{local,network}`, `es-us-x-esd-local`, `es-us-x-esf-local`, `es-us-x-sfb-network` |

There is **no `es-MX` voice**, so `setLanguage('es-MX')` cannot be what the reader
calls. Decision: the interface locale stays `es-MX` (the spec's Latin American Spanish,
ARB `app_es_MX.arb`) and speech uses `es-US` — US Spanish is the Latin American variety
the spec targets, and `es-US-language` exists as that locale's default voice. The voice
list accepts every `es*` locale, so a picked `es-ES` voice also works if the user wants
Castilian.

**Rejected**: `setLanguage('es-MX')` (no such voice — the read would fall back to the
engine default, i.e. English audio for Spanish text); silently picking `es-ES` (the
Castilian variety the spec explicitly rejected).

### Correction 2: Cantonese is already installed and the app hides it

The same sweep reports 7 `yue-HK` voices: `yue-HK-language`, `yue-hk-x-jar-local`,
`yue-hk-x-yuc-network`, `yue-hk-x-yud-local`, `yue-hk-x-yue-network`,
`yue-hk-x-yuf-{local,network}`. The engine needs nothing added.

The app, however, filters the Chinese list with
`ReaderService._matchesLanguage` → `locale.startsWith('zh')`, which `yue-HK` never
satisfies. So spec US3 is a *filter + naming* change, not an engine-capability change:
add a `yue*` arm to the Chinese list, and give each of the 7 voices a `广东话 <CODE>`
row so no row falls back to its raw system id.

**User decision** (2026-09-22): Cantonese is not a separate picker tab and not a second
saved choice — the 7 voices are mixed into the 中文 list, and picking one *is* the
Chinese voice pick, so Chinese text is then read in Cantonese.

### Corollary: the detection rule needs a Spanish arm

`detectLanguage()` today returns only `'zh-Hans'` or `'en'`, so Spanish content would be
read with the English voice. Spanish is added as a rule-table row (accented characters +
high-frequency Spanish stopwords), keeping the "a third language is a new rule row, not
new branches" shape of `lib/language.dart`.
