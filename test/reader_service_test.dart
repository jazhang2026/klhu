import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_store.dart';

/// Fake at the platform-channel seam: canned getVoices, recorded calls,
/// completion either automatic (microtask) or manual via [completePending].
class FakeTtsBackend implements TtsBackend {
  final List<dynamic> voicesRaw;
  bool autoComplete;

  final List<String> spoken = [];
  final List<Map<String, String>> setVoices = [];
  final List<String> languages = [];
  int stops = 0;
  VoidCallback? _handler;
  Completer<void>? _pending;

  FakeTtsBackend({required this.voicesRaw, this.autoComplete = true});

  @override
  Future<List<dynamic>> getVoices() async => voicesRaw;

  @override
  Future<dynamic> setLanguage(String locale) async {
    languages.add(locale);
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    setVoices.add(voice);
  }

  @override
  Future<dynamic> speak(String text) async {
    spoken.add(text);
    if (autoComplete) {
      final h = _handler;
      if (h != null) scheduleMicrotask(h);
    } else {
      _pending = Completer<void>();
    }
  }

  @override
  Future<dynamic> stop() async {
    stops++;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool v) async {}

  @override
  void setCompletionHandler(VoidCallback cb) {
    _handler = cb;
    if (autoComplete) scheduleMicrotask(cb);
  }

  void completePending() {
    _handler?.call();
    _pending?.complete();
  }
}

List<dynamic> get cannedVoices => [
      {'name': 'en-a', 'locale': 'en-US'},
      {'name': 'en-b', 'locale': 'en-GB'},
      {'name': 'zh-a', 'locale': 'zh-Hans-CN'},
      {'name': 'bad-no-locale'},
      {'name': '', 'locale': 'en-US'},
      'not-a-map',
    ];

void main() {
  group('voicesFor', () {
    test('filters by locale prefix, skips malformed entries', () async {
      final svc = ReaderService(
        FakeTtsBackend(voicesRaw: cannedVoices),
      );
      final en = await svc.voicesFor('en');
      expect(en.map((v) => v.name), ['en-a', 'en-b']);
      final zh = await svc.voicesFor('zh-Hans');
      expect(zh.map((v) => v.name), ['zh-a']);
    });
  });

  group('speakParagraphs', () {
    test('speaks in order, stop-first, picked voice per paragraph',
        () async {
      final backend = FakeTtsBackend(voicesRaw: cannedVoices);
      final svc = ReaderService(backend);
      await svc.speakParagraphs([
        const ParagraphSpeech(
          text: 'Hello.',
          language: 'en',
          voice: VoiceChoice(language: 'en', name: 'en-b', locale: 'en-GB'),
          start: 0,
          end: 6,
        ),
        const ParagraphSpeech(
          text: '你好。',
          language: 'zh-Hans',
          voice: VoiceChoice(
            language: 'zh-Hans',
            name: 'zh-a',
            locale: 'zh-Hans-CN',
          ),
          start: 0,
          end: 3,
        ),
      ]);
      expect(backend.spoken, ['Hello.', '你好。']);
      // The picked voice decides the engine locale, not the reading language's
      // default: 'en-b' is en-GB, so the English paragraph tells the engine
      // en-GB. This is what makes a picked Cantonese (yue-HK) voice read
      // Chinese text (spec 007) and a picked es-ES voice read Castilian.
      expect(backend.languages, ['en-GB', 'zh-Hans-CN']);
      expect(backend.setVoices, [
        {'name': 'en-b', 'locale': 'en-GB'},
        {'name': 'zh-a', 'locale': 'zh-Hans-CN'},
      ]);
      // stop-first: one stop before each speak.
      expect(backend.stops, 2);
    });

    test('unknown persisted voice falls back to OS default (no setVoice)',
        () async {
      final backend = FakeTtsBackend(voicesRaw: cannedVoices);
      final svc = ReaderService(backend);
      await svc.speakParagraphs([
        const ParagraphSpeech(
          text: 'Hello.',
          language: 'en',
          voice: VoiceChoice(
            language: 'en',
            name: 'gone',
            locale: 'en-US',
          ),
          start: 0,
          end: 6,
        ),
      ]);
      expect(backend.spoken, ['Hello.']);
      expect(backend.setVoices, isEmpty);
      // No usable pick → the reading language's own default locale.
      expect(backend.languages, ['en-US']);
    });

    test('Stop cancels the queue: no further speaks', () async {
      final backend = FakeTtsBackend(
        voicesRaw: cannedVoices,
        autoComplete: false,
      );
      final svc = ReaderService(backend);
      final future = svc.speakParagraphs([
        const ParagraphSpeech(text: 'One.', language: 'en', start: 0, end: 4),
        const ParagraphSpeech(text: 'Two.', language: 'en', start: 0, end: 4),
        const ParagraphSpeech(
            text: 'Three.', language: 'en', start: 0, end: 6),
      ]);
      // Let the first speak land, then stop and release it.
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, ['One.']);
      await svc.stop();
      backend.completePending();
      await future;
      expect(backend.spoken, ['One.']);
    });

    test('onParagraphStart fires in order with matching index', () async {
      final backend = FakeTtsBackend(voicesRaw: cannedVoices);
      final svc = ReaderService(backend);
      final seen = <int>[];
      await svc.speakParagraphs(
        [
          const ParagraphSpeech(
              text: 'One.', language: 'en', start: 0, end: 4),
          const ParagraphSpeech(
              text: '二。', language: 'zh-Hans', start: 0, end: 2),
        ],
        onParagraphStart: seen.add,
      );
      expect(seen, [0, 1]);
    });

    test('omitted callback speaks exactly as before', () async {
      final backend = FakeTtsBackend(voicesRaw: cannedVoices);
      final svc = ReaderService(backend);
      await svc.speakParagraphs([
        const ParagraphSpeech(text: 'One.', language: 'en', start: 0, end: 4),
      ]);
      expect(backend.spoken, ['One.']);
    });

    test('Stop means no callback after the stop point', () async {
      final backend = FakeTtsBackend(
        voicesRaw: cannedVoices,
        autoComplete: false,
      );
      final svc = ReaderService(backend);
      final seen = <int>[];
      final future = svc.speakParagraphs(
        [
          const ParagraphSpeech(
              text: 'One.', language: 'en', start: 0, end: 4),
          const ParagraphSpeech(
              text: 'Two.', language: 'en', start: 0, end: 4),
        ],
        onParagraphStart: seen.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0]);
      await svc.stop();
      backend.completePending();
      await future;
      expect(seen, [0]);
      expect(backend.spoken, ['One.']);
    });
  });

  group('pause / resume (005)', () {
    List<ParagraphSpeech> queueOf(int n) => [
          for (var i = 0; i < n; i++)
            ParagraphSpeech(
              text: 'Paragraph $i.',
              language: 'en',
              start: 0,
              end: 12,
            ),
        ];

    test('pause keeps the queue; resume replays the paused paragraph, then '
        'the rest — nothing skipped', () async {
      final backend = FakeTtsBackend(
        voicesRaw: cannedVoices,
        autoComplete: false,
      );
      final svc = ReaderService(backend);
      final seen = <int>[];
      final future = svc.speakParagraphs(
        queueOf(3),
        onParagraphStart: seen.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, ['Paragraph 0.']);

      // Paragraph 0 ends by itself, paragraph 1 starts and stays in flight.
      backend.completePending();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0, 1]);
      expect(backend.spoken, ['Paragraph 0.', 'Paragraph 1.']);

      final stopsBeforePause = backend.stops;
      await svc.pause();
      expect(svc.isPaused, isTrue);
      expect(svc.isSpeaking, isFalse);
      // Pausing stops the audio for real (the engine's own pause() is what
      // crashes on a second call, so it is never used).
      expect(backend.stops, stopsBeforePause + 1);

      // The parked loop must not speak on by itself.
      backend.completePending();
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, ['Paragraph 0.', 'Paragraph 1.']);
      expect(seen, [0, 1]);

      final resumed = svc.resume();
      await Future<void>.delayed(Duration.zero);
      expect(svc.isPaused, isFalse);
      expect(svc.isSpeaking, isTrue);
      // Paragraph 1 is spoken again (it was interrupted mid-read)…
      expect(backend.spoken,
          ['Paragraph 0.', 'Paragraph 1.', 'Paragraph 1.']);
      expect(seen, [0, 1, 1]);

      // …then the read carries on in order and ends.
      backend.completePending();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0, 1, 1, 2]);
      backend.completePending();
      await resumed;
      await future;
      expect(backend.spoken, [
        'Paragraph 0.',
        'Paragraph 1.',
        'Paragraph 1.',
        'Paragraph 2.',
      ]);
      expect(svc.isSpeaking, isFalse);
      expect(svc.isPaused, isFalse);
    });

    test('Stop after a pause clears the queue; resume cannot revive it',
        () async {
      final backend = FakeTtsBackend(
        voicesRaw: cannedVoices,
        autoComplete: false,
      );
      final svc = ReaderService(backend);
      final future = svc.speakParagraphs(queueOf(2));
      await Future<void>.delayed(Duration.zero);
      await svc.pause();

      await svc.stop();
      expect(svc.isPaused, isFalse);
      await svc.resume();
      await Future<void>.delayed(Duration.zero);
      backend.completePending();
      await future;
      // Only the first paragraph ever spoke, and it does not speak again.
      expect(backend.spoken, ['Paragraph 0.']);
      expect(svc.isSpeaking, isFalse);
    });

    test('pause while idle and resume while speaking are no-ops', () async {
      final backend = FakeTtsBackend(voicesRaw: cannedVoices);
      final svc = ReaderService(backend);

      await svc.pause();
      expect(svc.isPaused, isFalse);
      await svc.resume();
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, isEmpty);

      await svc.speakParagraphs(queueOf(1));
      // Not paused: nothing to resume, and the finished read stays finished.
      await svc.resume();
      expect(svc.isPaused, isFalse);
      expect(svc.isSpeaking, isFalse);
    });
  });
}
