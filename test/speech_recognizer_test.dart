import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/speech_recognizer.dart';

/// Scriptable fake: tests drive results/errors without platform channels.
class FakeSpeechRecognizer implements SpeechRecognizer {
  bool initResult = true;
  final List<String> listenedLocales = [];
  int listenCalls = 0;
  int stopCalls = 0;
  bool isListening = false;
  bool _initialized = false;

  void Function(String transcript, bool isFinal)? _onResult;
  void Function()? _onDone;
  void Function(String reason)? _onError;

  @override
  Future<bool> initialize() async {
    _initialized = initResult;
    return initResult;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String reason)? onError,
  }) async {
    listenCalls++;
    isListening = true;
    listenedLocales.add(localeId);
    _onResult = onResult;
    _onDone = onDone;
    _onError = onError;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    isListening = false;
    // A real recognizer's stop ends the session — fire done so pending
    // listen windows resolve.
    _onDone?.call();
  }

  @override
  void dispose() {}

  bool get initialized => _initialized;

  /// Test hooks: emit a final transcript then done.
  void emitFinal(String text) {
    _onResult?.call(text, true);
    _onDone?.call();
    isListening = false;
  }

  void emitError(String reason) {
    _onError?.call(reason);
    isListening = false;
  }
}

void main() {
  group('localeIdFor', () {
    test('maps supported read languages', () {
      expect(localeIdFor('en'), 'en_US');
      expect(localeIdFor('zh-Hans'), 'zh_CN');
      expect(localeIdFor('es'), 'es_ES');
    });

    test('returns null for unsupported languages', () {
      expect(localeIdFor('yue'), isNull);
      expect(localeIdFor('auto'), isNull);
      expect(localeIdFor('fr'), isNull);
    });
  });

  group('FakeSpeechRecognizer', () {
    test('initialize reflects scripted result', () async {
      final f = FakeSpeechRecognizer()..initResult = false;
      expect(await f.initialize(), isFalse);
      expect(f.initialized, isFalse);
    });

    test('listen records locale and stop counts calls', () async {
      final f = FakeSpeechRecognizer();
      await f.initialize();
      await f.listen(
        localeId: 'en_US',
        onResult: (_, _) {},
      );
      expect(f.listenedLocales, ['en_US']);
      expect(f.listenCalls, 1);
      await f.stop();
      expect(f.stopCalls, 1);
    });

    test('emitFinal delivers transcript then done', () async {
      final f = FakeSpeechRecognizer();
      await f.initialize();
      String? got;
      var done = false;
      await f.listen(
        localeId: 'en_US',
        onResult: (t, isFinal) {
          if (isFinal) got = t;
        },
        onDone: () => done = true,
      );
      f.emitFinal('hello world');
      expect(got, 'hello world');
      expect(done, isTrue);
    });
  });
}
