# Quickstart: 002-voice-picker

1. `flutter pub add shared_preferences` (new dep), `flutter pub get`
2. Implement + unit-test `lib/language.dart` (CJK-wins resolver)
3. Extend `ReaderService`: getVoices/setVoice/`speakParagraphs()` + fake-tts tests
4. Implement + test `lib/voice_store.dart` (persist per-language choice)
5. Build `lib/voice_picker_screen.dart` + AppBar action in reading view
6. Verify on Android emulator: mixed page order (SC-001), list matches
   getVoices (SC-002), preview <2s (SC-003), restart persists both languages
   (SC-004), missing/empty/failure fallbacks (SC-005)
