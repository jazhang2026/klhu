# Quickstart: 001-read-aloud

1. Install Flutter stable; verify `flutter --version`.
2. `cd klhu && flutter create .` (keeps `specs/`, adds Flutter scaffold).
3. `flutter pub add flutter_tts`.
4. Implement in story order with tests:
   - P1: `segmenter.dart` sentence resolution + tap→highlight→Read→Stop; `flutter test`
   - P2: paragraph resolution; `flutter test`
   - P3: Read page; `flutter test`
5. Verify: `flutter run` on iPhone simulator (EN + zh-Hans) and Android emulator; acceptance per spec SC-001..SC-004.
