import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:klhu/voice_store.dart';

/// TTS capability consumed by the reading view. Extracted so widget
/// tests can substitute a fake (T008); production uses [ReaderService].
abstract class Reader {
  Future<void> speak(String text, String language);
  Future<void> stop();
  bool get isSpeaking;

  /// Installed voices for [language] (`'en'` or `'zh-Hans'`), filtered by
  /// locale prefix; malformed platform entries are skipped.
  Future<List<VoiceEntry>> voicesFor(String language);

  /// Speak [paragraphs] in order, each with its own language voice.
  /// Stop ([stop]) cancels the queue; nothing further speaks afterwards.
  /// [onParagraphStart] fires with the paragraph index immediately before
  /// each utterance (read-page tracking); never for a stale generation.
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  });

  /// Preview [voice] with [sampleText]: stops current speech first, then
  /// speaks the sample in that voice (picker tap-to-preview).
  Future<void> previewVoice(VoiceEntry voice, String sampleText);
}

/// One installed voice: display name + locale as returned by getVoices.
class VoiceEntry {
  final String name;
  final String locale;

  const VoiceEntry({required this.name, required this.locale});
}

/// One paragraph to speak: text, detected language, optional picked voice.
/// A null [voice] (or one no longer installed) reads in the OS default.
/// [start]/[end] are offsets into the reading content (the overlap with the
/// requested range); tracking highlights read ONLY these, never recomputed.
class ParagraphSpeech {
  final String text;
  final String language;
  final VoiceChoice? voice;
  final int start;
  final int end;

  const ParagraphSpeech({
    required this.text,
    required this.language,
    this.voice,
    required this.start,
    required this.end,
  });
}

/// Platform-channel seam: production delegates to [FlutterTts], tests
/// substitute a fake. Keeps [ReaderService] unit-testable without a device.
abstract class TtsBackend {
  Future<List<dynamic>> getVoices();
  Future<dynamic> setLanguage(String locale);
  Future<dynamic> setVoice(Map<String, String> voice);
  Future<dynamic> speak(String text);
  Future<dynamic> stop();
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  void setCompletionHandler(VoidCallback callback);
}

class FlutterTtsBackend implements TtsBackend {
  final FlutterTts _tts;

  FlutterTtsBackend([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  @override
  Future<List<dynamic>> getVoices() async {
    final voices = await _tts.getVoices;
    return voices is List ? voices : [];
  }

  @override
  Future<dynamic> setLanguage(String locale) => _tts.setLanguage(locale);

  @override
  Future<dynamic> setVoice(Map<String, String> voice) => _tts.setVoice(voice);

  @override
  Future<dynamic> speak(String text) => _tts.speak(text);

  @override
  Future<dynamic> stop() => _tts.stop();

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _tts.awaitSpeakCompletion(awaitCompletion);

  @override
  void setCompletionHandler(VoidCallback callback) =>
      _tts.setCompletionHandler(callback);
}

/// Thin wrapper over [TtsBackend]; production [Reader].
///
/// Language follows the reading content: `en-US` for English,
/// `zh-Hans-CN` for Simplified Chinese. No rate/pitch UI in v1 (API defaults).
class ReaderService implements Reader {
  final TtsBackend _tts;
  bool _speaking = false;

  /// Stale-generation guard: every [stop] bumps [_generation] so an
  /// in-flight [speakParagraphs] loop aborts instead of speaking on.
  int _generation = 0;

  ReaderService([TtsBackend? backend])
      : _tts = backend ?? FlutterTtsBackend();

  @override
  bool get isSpeaking => _speaking;

  static String localeFor(String language) =>
      language == 'zh-Hans' ? 'zh-Hans-CN' : 'en-US';

  static bool _matchesLanguage(String locale, String language) {
    final lower = locale.toLowerCase();
    return language == 'zh-Hans'
        ? lower.startsWith('zh')
        : lower.startsWith('en');
  }

  static VoiceEntry? _parseVoice(dynamic entry) {
    if (entry is! Map) return null;
    final name = entry['name'];
    final locale = entry['locale'];
    if (name is! String ||
        locale is! String ||
        name.isEmpty ||
        locale.isEmpty) {
      return null;
    }
    return VoiceEntry(name: name, locale: locale);
  }

  /// Speak [text] in [language] (`'en'` or `'zh-Hans'`).
  /// Throws [ReaderException] when no voice is available (e.g. emulator).
  @override
  Future<void> speak(String text, String language) async {
    final locale = localeFor(language);
    try {
      final ok = await _tts.setLanguage(locale);
      if (ok != 1 && ok != true) {
        throw ReaderException('Voice not available for $locale');
      }
      await _tts.speak(text);
      _speaking = true;
    } catch (e) {
      if (e is ReaderException) rethrow;
      throw ReaderException('TTS error: $e');
    }
  }

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async {
    final raw = await _tts.getVoices();
    for (final entry in raw) {
      debugPrint('klhu getVoices: $entry');
    }
    return [
      for (final entry in raw)
        if (_parseVoice(entry) case final voice?)
          if (_matchesLanguage(voice.locale, language)) voice,
    ];
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    final generation = ++_generation;
    _speaking = paragraphs.isNotEmpty;
    try {
      await _tts.awaitSpeakCompletion(true);
      final installed = await voicesForAll();
      for (var i = 0; i < paragraphs.length; i++) {
        final paragraph = paragraphs[i];
        if (generation != _generation) break;
        await _tts.stop();
        await _tts.setLanguage(localeFor(paragraph.language));
        final voice = paragraph.voice;
        if (voice != null &&
            installed.any(
              (v) => v.name == voice.name && v.locale == voice.locale,
            )) {
          try {
            await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
          } catch (_) {
            // Fall through to the OS default voice.
          }
        }
        if (generation != _generation) break;
        onParagraphStart?.call(i);
        final done = Completer<void>();
        _tts.setCompletionHandler(() {
          if (!done.isCompleted) done.complete();
        });
        await _tts.speak(paragraph.text);
        await done.future;
      }
    } catch (e) {
      if (e is ReaderException) rethrow;
      throw ReaderException('TTS error: $e');
    } finally {
      if (generation == _generation) _speaking = false;
    }
  }

  /// All installed voices, both languages (single getVoices round-trip).
  Future<List<VoiceEntry>> voicesForAll() async {
    final raw = await _tts.getVoices();
    return [for (final entry in raw) ?_parseVoice(entry)];
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _tts.stop();
    _speaking = false;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {
    try {
      // Stop-first (spec FR-009): preview interrupts any in-progress read
      // and invalidates a queued multi-paragraph loop via the generation.
      await stop();
      await _tts.setLanguage(voice.locale);
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      await _tts.speak(sampleText);
      _speaking = true;
    } catch (e) {
      if (e is ReaderException) rethrow;
      throw ReaderException('Preview failed: $e');
    }
  }
}

class ReaderException implements Exception {
  final String message;
  ReaderException(this.message);

  @override
  String toString() => 'ReaderException: $message';
}
