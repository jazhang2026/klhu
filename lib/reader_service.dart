import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/voice_store.dart';

/// TTS capability consumed by the reading view. Extracted so widget
/// tests can substitute a fake (T008); production uses [ReaderService].
abstract class Reader {
  Future<void> speak(String text, String language);
  Future<void> stop();

  /// Stop the audio, keep the queued read, remember where it stopped.
  /// Nothing speaks until [resume].
  Future<void> pause();

  /// Continue the read [pause] interrupted. No-op when not paused.
  Future<void> resume();

  bool get isSpeaking;
  bool get isPaused;

  /// Installed voices for [language] (`'en'`, `'zh-Hans'` or `'es'`), filtered
  /// by locale prefix; malformed platform entries are skipped.
  Future<List<VoiceEntry>> voicesFor(String language);

  /// Speak [paragraphs] in order, each with its own language voice.
  /// Stop ([stop]) cancels the queue; nothing further speaks afterwards.
  /// Each paragraph reaches the engine as one utterance per SENTENCE (010
  /// FR-011), which is what makes a paused read resume at the sentence that
  /// was in progress rather than at the top of a possibly long paragraph.
  /// [onParagraphStart] fires once per paragraph, with the paragraph's index
  /// in [paragraphs], on its first sentence (read-page tracking); never for a
  /// stale generation.
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
  /// System voice identifier (the `name` field from flutter_tts getVoices).
  final String name;

  /// Locale code (e.g., "en-US", "zh-Hans-CN").
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
///
/// No `pause()` here on purpose: the engine's Android pause is a
/// stop-and-remember hack that corrupts on repeat (see [ReaderService.pause]),
/// and this app does not use it — exposing it would only invite a caller back
/// into that trap.
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

/// One utterance handed to the engine: a whole sentence of a paragraph, in
/// submission order, carrying the paragraph's own language, picked voice and
/// index. The sentence is the smallest unit that is still a whole utterance,
/// so it is also the smallest unit a [ReaderService.resume] can start from
/// (FR-011) — the engine's own mid-utterance pause corrupts on repeat.
class _Utterance {
  final String text;
  final String language;
  final VoiceChoice? voice;

  /// Index of the paragraph this sentence came from — what the tracking
  /// callback reports, so 003 stays paragraph-level.
  final int paragraph;

  /// Index of this sentence inside its paragraph (device-evidence only).
  final int sentence;

  const _Utterance({
    required this.text,
    required this.language,
    this.voice,
    required this.paragraph,
    required this.sentence,
  });
}

/// Thin wrapper over [TtsBackend]; production [Reader].
///
/// Language follows the reading content: `en-US` for English,
/// `zh-Hans-CN` for Simplified Chinese. No rate/pitch UI in v1 (API defaults).
class ReaderService implements Reader {
  final TtsBackend _tts;
  bool _speaking = false;
  bool _paused = false;

  /// Stale-generation guard: [stop], [pause] and [resume] each bump
  /// [_generation] so a loop that is already in flight aborts instead of
  /// speaking on — or, after a resume started a fresh loop, speaking twice.
  int _generation = 0;

  /// Queue state a paused read needs: what is being read — one entry per
  /// sentence — which one is in flight, the voices resolved for it, and the
  /// highlight callback. Kept across [pause]/[resume]; cleared by [stop].
  List<_Utterance> _queue = const [];
  List<VoiceEntry> _installed = const [];
  void Function(int index)? _onParagraphStart;
  int _cursor = 0;

  /// Resolves when the utterance in flight ends — or when [pause]/[stop] cut
  /// it short, so a cut-off paragraph releases the loop instead of parking it
  /// on a completion callback that a stopped utterance never delivers.
  Completer<void>? _utterance;

  ReaderService([TtsBackend? backend])
      : _tts = backend ?? FlutterTtsBackend();

  @override
  bool get isSpeaking => _speaking;

  @override
  bool get isPaused => _paused;

  /// Engine locale per reading language. Spanish has no `es-MX` voice on the
  /// engine (measured on emulator-5554: `es-ES` and `es-US` only), so Spanish
  /// reads in `es-US` — the Latin American variety this app targets. See
  /// `specs/007-reader-name-spanish-cantonese/research.md`.
  static const Map<String, String> _speechLocales = {
    'en': 'en-US',
    'zh-Hans': 'zh-Hans-CN',
    'es': 'es-US',
  };

  /// Voice-list membership per reading language. The Chinese list carries the
  /// Cantonese (`yue-HK`) voices too: Cantonese is a Chinese voice choice, not
  /// a separate language (spec 007 FR-008).
  static const Map<String, List<String>> _voiceLocalePrefixes = {
    'en': ['en'],
    'zh-Hans': ['zh', 'cmn', 'yue'],
    'es': ['es'],
  };

  static String localeFor(String language) =>
      _speechLocales[language] ?? 'en-US';

  static bool _matchesLanguage(String locale, String language) {
    final lower = locale.toLowerCase();
    return (_voiceLocalePrefixes[language] ?? const ['en'])
        .any(lower.startsWith);
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

  /// Speak [text] in [language] (`'en'`, `'zh-Hans'` or `'es'`).
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
    _generation++;
    _queue = _sentencesOf(paragraphs);
    _cursor = 0;
    _paused = false;
    _onParagraphStart = onParagraphStart;
    _speaking = _queue.isNotEmpty;
    await _run(_generation);
  }

  /// The queue a read is spoken from: every paragraph's speech cut into whole
  /// sentences, in order, each carrying its paragraph's language, picked voice
  /// and index (FR-011). A speech that starts mid-paragraph — what an anchored
  /// Continue Read hands over — yields its remainder as the first sentence.
  ///
  /// An empty [sentenceRanges] can only come from an empty speech, which the
  /// resolver never emits: a paragraph with text always has one sentence.
  static List<_Utterance> _sentencesOf(List<ParagraphSpeech> paragraphs) {
    final units = <_Utterance>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final ranges = sentenceRanges(paragraph.text);
      for (var j = 0; j < ranges.length; j++) {
        units.add(
          _Utterance(
            text: paragraph.text.substring(ranges[j].start, ranges[j].end),
            language: paragraph.language,
            voice: paragraph.voice,
            paragraph: i,
            sentence: j,
          ),
        );
      }
    }
    return units;
  }

  /// Continue the read [pause] interrupted.
  ///
  /// Sentence granularity: the interrupted SENTENCE is spoken again from its
  /// start, then the rest of the queue follows in order. Nothing is skipped
  /// and no sentence is read twice once the queue runs to its end. There is
  /// no safe mid-utterance position to resume from: the engine's own
  /// pause/resume bookkeeping corrupts on repeat (see [pause]).
  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _generation++;
    _speaking = _queue.isNotEmpty;
    await _run(_generation);
  }

  /// One read: the queue from [_cursor] to the end, at [gen]. Shared by
  /// [speakParagraphs] (from the top) and [resume] (from where it stopped).
  Future<void> _run(int gen) async {
    try {
      await _tts.awaitSpeakCompletion(true);
      _installed = await voicesForAll();
      var reported = -1;
      while (_cursor < _queue.length) {
        if (gen != _generation) return;
        final unit = _queue[_cursor];
        // Stop-first: the engine queues utterances, so anything still in
        // flight (a paused one included) must go before the next speak.
        await _tts.stop();
        // The picked voice decides the engine language when it differs from the
        // reading language's default: Cantonese (`yue-HK`) reads Chinese text,
        // and a picked `es-ES` voice differs from the Spanish default. Telling
        // the engine the voice's OWN locale is what makes it honor the voice
        // instead of the list's default.
        final voice = unit.voice;
        final picked = voice != null &&
                _installed.any(
                  (v) => v.name == voice.name && v.locale == voice.locale,
                )
            ? voice
            : null;
        await _tts.setLanguage(picked?.locale ?? localeFor(unit.language));
        if (picked != null) {
          try {
            await _tts.setVoice({'name': picked.name, 'locale': picked.locale});
          } catch (_) {
            // Fall through to the OS default voice.
          }
        }
        if (gen != _generation) return;
        // 003's tracking is paragraph-level: one callback per paragraph, on its
        // first sentence. A resume reports its paragraph again, as it always
        // has; nothing downstream counts the calls.
        if (unit.paragraph != reported) {
          reported = unit.paragraph;
          _onParagraphStart?.call(unit.paragraph);
        }
        debugPrint(
          'klhu speak p${unit.paragraph} s${unit.sentence} '
          '"${_logPrefix(unit.text)}"',
        );
        final done = Completer<void>();
        _utterance = done;
        _tts.setCompletionHandler(() {
          if (!done.isCompleted) done.complete();
        });
        await _tts.speak(unit.text);
        await done.future;
        // Stale generation means a pause/stop already took over: leave the
        // new run's utterance slot alone.
        if (gen != _generation) return;
        _utterance = null;
        _cursor++;
      }
    } catch (e) {
      if (e is ReaderException) rethrow;
      throw ReaderException('TTS error: $e');
    } finally {
      if (gen == _generation) _speaking = false;
    }
  }

  /// All installed voices, both languages (single getVoices round-trip).
  Future<List<VoiceEntry>> voicesForAll() async {
    final raw = await _tts.getVoices();
    return [for (final entry in raw) ?_parseVoice(entry)];
  }

  /// The first few characters of an utterance, one line, for the device walk
  /// (`adb logcat | grep 'klhu speak'` names which sentence went to the
  /// engine, which no UI dump can show).
  static String _logPrefix(String text) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ');
    return oneLine.length <= 24 ? oneLine : '${oneLine.substring(0, 24)}...';
  }

  /// Cut the utterance in flight short and wake the loop waiting on it.
  void _releaseUtterance() {
    final done = _utterance;
    _utterance = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Stop the audio and remember the sentence in flight, so [resume] can
  /// continue the queue from it.
  ///
  /// This deliberately does NOT call the engine's own `pause()`. On Android
  /// flutter_tts implements pause as "stop, then remember the remaining
  /// substring of the utterance", and every further pause re-truncates that
  /// remembered substring from an absolute progress index: the second call
  /// throws `StringIndexOutOfBoundsException` inside the plugin
  /// (`FlutterTtsPlugin.kt:363`, reproduced on emulator-5554 with
  /// `length=6; index=57`), the method call fails, and the engine never
  /// resumes. A pause/resume toggle is exactly that second call, so the app
  /// keeps its own position and stops the audio for real instead.
  @override
  Future<void> pause() async {
    if (_paused || !_speaking) return;
    _paused = true;
    _speaking = false;
    // Detach the in-flight loop: it wakes up below, sees a stale generation
    // and exits without touching the queue.
    _generation++;
    await _tts.stop();
    _releaseUtterance();
  }

  @override
  Future<void> stop() async {
    _generation++;
    _paused = false;
    _queue = const [];
    _cursor = 0;
    _onParagraphStart = null;
    _releaseUtterance();
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
