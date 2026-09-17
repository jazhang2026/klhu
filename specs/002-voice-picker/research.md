# Research: 002-voice-picker

## flutter_tts voices (v4.2.3, verified against API used in 001)

- `getVoices` → `List<dynamic>`, each entry a Map with at least `name` and
  `locale` (e.g. `{name: "en-us-x-sfg#male_1-local", locale: "en-US"}`).
  Shape varies by OEM — code MUST defensively parse (missing keys → skip entry).
- `setVoice({"name": ..., "locale": ...})` selects the voice; call AFTER
  `setLanguage(locale)` and BEFORE `speak()` per sentence when switching
  languages. Verify on Android emulator at implement time (log raw getVoices).
- Filtering: match locale prefix case-insensitively — `en*` → English list,
  `zh*` (incl. `zh-Hans-CN`, `cmn-CN`, `yue-HK` variants) → Chinese list.
  Decision: prefix filter, not exact match (OEM locale strings vary).
- Risk: emulator with zero matching voices → picker empty state; Read falls
  back to OS default (setLanguage only, no setVoice).

## Sequential multi-paragraph speak

- flutter_tts has one audio stream: `await stop()` before each `speak()`,
  await completion handler (or per-paragraph `speak()` with completion future)
  to keep page order with no repeats/skips. Stop button → `stop()` + cancel
  queue flag (<1s). Decision: `speakParagraphs([(text, lang)])` loop in
  ReaderService with a generation counter; stale generations abort silently.

## Persistence

- `shared_preferences` (new dep): keys `voice_en`, `voice_zh_Hans`, value
  `"<name>||<locale>"`. On Read: look up persisted pair in current getVoices;
  exact match → setVoice, else OS default (no crash/silence).
- Decision: name+locale pair, not name alone (OEMs reuse display names).

## Language resolver

- Rule table `List<bool Function(String)>`: rule 1 = contains CJK
  (`\u4e00-\u9fff`, `\u3400-\u4dbf`, `\uf900-\ufaff`) → `zh-Hans`;
  fallback → `en`. Future language = new rule row, not new branches (spec FR-001).
- Input paragraphs come from 001 `segmenter.dart` paragraph ranges — resolver is pure
  `String → 'en' | 'zh-Hans'`, unit-tested with mixed/punctuation-only/empty.
