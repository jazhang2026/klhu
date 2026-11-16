# Quickstart: Read Language validation (034)

## Prerequisites

- Flutter stable; `flutter pub get` already run (no new deps).
- `flutter analyze --no-pub`, `flutter test --concurrency=2` clean.

## Automated verification

```bash
cd ~/Documents/GitHub/Projects/klhu
flutter analyze --no-pub
flutter test --concurrency=2
```

## Widget/unit scenarios (what the tests prove)

1. **Resolution unit tests** (`read_language_test.dart`):
   role override wins over main; main wins over detection; auto → detected;
   unknown role name → falls through to main/detection.
2. **Store round-trip**: `readLang`/`roleLangs` survive
   `SavedContent.toJson`/`fromJson` and `ContentStore` save/load; old index
   records without the fields load as auto.
3. **Dialog**: Text type dialog shows "Auto — detected: X" for main;
   picking Español persists `readLang='es'`; reopening shows Español
   selected. Preset content shows no language section.
4. **Read evidence**: a content with `readLang='es'` whose paragraphs
   detect as `en` produces `ParagraphSpeech.language == 'es'` on tap-read
   and Continue Read (fake reader records languages).
5. **Dialogue**: role with `roleLangs['阿明']='en'` reads English while
   other roles keep detection; role removed/re-added keeps override by
   name.
6. **Next-read**: change language while idle → next tap-read uses it; an
   in-flight read is untouched.

## Detector scenarios (US3)

7. **langid unit tests**: ≥30 held-out sentences/language — en/es ≥90%,
   zh-Hans ≥98% top-1; accent-less Spanish ("Voy al cine.", "Nos vemos
   manana.") → `es`; symbol-only/ambiguous → rule-table fallback.
8. **Device spot-check**: paste accent-less Spanish into a content →
   auto-detect reads it in Spanish voice without any override.

## Device walk

1. Import/save a Spanish text that detects as English → Text type →
   Reading language → Español → tap a sentence → `klhu speak`/voice is
   Spanish; force-stop + relaunch → still Español.
2. Dialogue content → Text type → role list → pin one role to English →
   Continue Read → that role's turns are English, others unchanged.
3. New content → dialog shows Auto + detected label; no setup needed.
