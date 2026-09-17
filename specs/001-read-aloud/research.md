# Research: 001-read-aloud

## TTS: flutter_tts
- `setLanguage('en-US')` / `setLanguage('zh-Hans-CN')` per device locale; `speak(text)`, `stop()` returns int.
- Decision: wrap in `ReaderService` (speak/stop/isSpeaking) so widget tests can fake it; no rate/pitch UI in v1 (API defaults).
- Risk: missing voice on emulator → catch error, show message (FR edge case). Verify on both simulators during implement.

## Segmentation (tap-offset → ranges)
- Sentences: split on `. ! ? ;` + CJK `。！？；……`, keep delimiter with sentence; handle closing quotes/brackets after delimiter.
- Paragraphs: split on blank line / `\n`; single `\n` inside paragraph does not break it.
- Page: the full loaded text (v1 has no pagination; "page" = current reading page content top-to-bottom).
- Tap resolution: offset → containing sentence/paragraph via precomputed ranges; whitespace taps resolve to nearest sentence.
- Decision: pure-Dart `segmenter.dart`, no NLP package (YAGNI, offline).
- Test vectors: EN sample, zh-Hans sample, mixed sample, boundary taps.

## Input
- v1: paste field + bundled EN/zh-Hans samples (spec decision 2026-09-14). No file import, OCR, PDF.

## Environment note
- Flutter SDK NOT installed on this machine (checked 2026-09-14). Prerequisite before implement: install Flutter stable + iOS simulator / Android emulator, then `flutter create .` inside `klhu/` (spec files stay).
