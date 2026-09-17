# Data Model: 002-voice-picker

## VoiceChoice (persisted, one per language)

- `language`: `en` | `zh-Hans`
- `name`, `locale`: raw strings from getVoices (identity = pair)
- Key: `voice_en` / `voice_zh_Hans`; value `"<name>||<locale>"`
- Invariant: missing/unparseable value ≡ no choice → OS default

## VoiceEntry (picker row, derived)

- `name`, `locale`, `isSelected` (== stored choice for active language)
- Derived by filtering getVoices on locale prefix (`en*` / `zh*`,
  case-insensitive); malformed entries skipped

## ResolvedParagraph (transient, mixed read)

- `text`, `language` (`language.dart` resolver), `voice` (picked or default)
- Invariant: order == segmenter order; Stop clears the queue

## PickerState

- `status`: loading | ready | empty | error; `voices`: List<VoiceEntry>;
  `activeLanguage`: en | zh-Hans (from current reading content)
- Preview: tap → stop current speech → setVoice → speak fixed sample line
  (EN: "Hello, this is my reading voice." / zh-Hans: "你好，这是我的朗读声音。")
