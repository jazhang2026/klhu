# Data Model: Read Language (034)

## SavedContent (extended, `lib/models/content.dart`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `readLang` | `String` | `'auto'` | main-text language: `'auto'` \| `'en'` \| `'zh-Hans'` \| `'es'` |
| `roleLangs` | `Map<String,String>` | `{}` | role name → `'auto'` \| language; absent role = auto |

- `toJson`/`fromJson`: fields optional; missing → defaults (no migration).
- `copyWith` gains both; equality includes them (settings are content
  state — two contents differing only in language are different records).
- `PresetContent` untouched; presets expose no settings UI.

## Resolution (`lib/read_language.dart`)

```dart
const supportedReadLanguages = ['en', 'zh-Hans', 'es'];
const autoLanguage = 'auto';

String resolveReadLanguage({
  required String detected,          // detectLanguage() answer for the unit
  String main = autoLanguage,        // content.readLang
  String? role,                      // role name when resolving a turn
  Map<String, String> roleLangs = const {},
}) {
  if (role != null) {
    final pick = roleLangs[role];
    if (pick != null && pick != autoLanguage) return pick;
  }
  if (main != autoLanguage) return main;
  return detected;
}
```

Precedence: **role override → main override → detection** (FR-004).

## Effective-language display (dialog)

| Row | Auto shows | Explicit shows |
|-----|-----------|----------------|
| Main text | `detectLanguage(firstParagraph)` | chosen language |
| Role `R` | `detectLanguage(R.firstTurn)` (today's per-turn answer) | chosen language |

UI copy distinguishes auto: e.g. `Auto — detected: Español`.

## Language detector (US3, `lib/langid/`)

```dart
class LangIdResult {
  final String language;   // 'en' | 'zh-Hans' | 'es'
  final double confidence; // 0..1 margin over runner-up
}

LangIdResult detectWithModel(String text);  // pure Dart, bundled profiles
```

- Profiles: `assets/langid/profiles.json` — per-language char n-gram
  (1–4) log-frequencies, generated offline by `tool/gen_langid_profiles.dart`
  from `tool/langid_corpus/{en,es,zh-Hans}.txt` (Tatoeba, CC-BY).
- `detectLanguage(text)` in `lib/language.dart` becomes:
  `detectWithModel` → if `confidence >= threshold` return its language,
  else run the existing rule table. Signature unchanged — all callers
  unaffected; `detectWithModel` is directly unit-testable.
- Threshold tuned on the held-out SC-005 set; stored as a const.

## State flow

```
ContentStore.index.json ──load──▶ SavedContent{readLang, roleLangs}
        ▲                                    │
        └──save (copyWith)◀── Text type dialog picks ◀── ReadingView state
                                                          │
resolveParagraphSpeeches(languageFor:) ◀── resolveReadLanguage ◀── per read
speech_resolver role turns           ◀── same seam (role = turn.role)
```

- No caching of resolved languages — computed per read (FR-005 free).
- Comment path (`comment.dart`) never calls the seam — unchanged.
