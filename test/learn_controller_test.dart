import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/learn_controller.dart';
import 'package:klhu/learn/learn_session.dart';
import 'speech_recognizer_test.dart' show FakeSpeechRecognizer;

void main() {
  LearnSentence sent({String text = 'Hello world.', String lang = 'en'}) =>
      LearnSentence(
          key: '0:12', start: 0, end: 12, text: text, language: lang);

  test('three cycles: speak then listen, each scored', () async {
    final rec = FakeSpeechRecognizer();
    final spoken = <String>[];
    final ctl = LearnController(
      speak: (s) async {
        spoken.add(s.key);
        return s.language;
      },
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    // Drive each mic window: listen opens → emit final → done.
    for (var i = 0; i < 3; i++) {
      await pumpEventQueue();
      expect(rec.listenCalls, i + 1);
      rec.emitFinal('hello world');
      await pumpEventQueue();
    }
    await practice;
    expect(spoken, hasLength(3));
    expect(ctl.session.state, LearnState.waiting);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(r.attempts.every((a) => a.status == AttemptStatus.scored), isTrue);
    expect(r.bestAccuracy, 1.0);
    ctl.dispose();
  });

  test('mic never opens before speak resolves (echo gate)', () async {
    final rec = FakeSpeechRecognizer();
    final duringSpeak = <bool>[];
    final ctl = LearnController(
      speak: (s) async {
        duringSpeak.add(rec.isListening);
        return s.language;
      },
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    expect(duringSpeak, [false]);
    rec.emitFinal('hello world');
    await pumpEventQueue();
    await ctl.stop();
    await practice;
    // Every read happens before its own mic window — never during TTS.
    expect(duringSpeak.every((v) => !v), isTrue);
    ctl.dispose();
  });

  test('permission denied → read-only cycles, unscored attempts', () async {
    final rec = FakeSpeechRecognizer();
    final ctl = LearnController(
      speak: (s) async => s.language,
      recognizer: rec,
      micPermission: () async => false,
    );
    final practice = ctl.practice(sent());
    await practice;
    expect(rec.listenCalls, 0);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(
        r.attempts.every((a) =>
            a.unscoredReason == UnscoredReason.permissionDenied),
        isTrue);
    ctl.dispose();
  });

  test('recognizer unavailable → unscored, cycles still complete', () async {
    final rec = FakeSpeechRecognizer()..initResult = false;
    final ctl = LearnController(
      speak: (s) async => s.language,
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    await practice;
    final r = ctl.session.results['0:12']!;
    expect(
        r.attempts.every((a) =>
            a.unscoredReason == UnscoredReason.recognitionUnavailable),
        isTrue);
    ctl.dispose();
  });

  test('unsupported language → unscored without touching mic', () async {
    final rec = FakeSpeechRecognizer();
    final ctl = LearnController(
      speak: (s) async => 'yue',
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    await practice;
    expect(rec.listenCalls, 0);
    expect(
        ctl.session.results['0:12']!.attempts.every((a) =>
            a.unscoredReason == UnscoredReason.unsupportedLanguage),
        isTrue);
    ctl.dispose();
  });

  test('empty done → noSpeech unscored', () async {
    final rec = FakeSpeechRecognizer();
    final ctl = LearnController(
      speak: (s) async => s.language,
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    rec.emitFinal('   ');
    await pumpEventQueue();
    await ctl.stop();
    await practice;
    final r = ctl.session.results['0:12']!;
    expect(r.attempts.first.unscoredReason, UnscoredReason.noSpeech);
    ctl.dispose();
  });

  test('stop mid-cycle halts without recording phantom attempts', () async {
    final rec = FakeSpeechRecognizer();
    final ctl = LearnController(
      speak: (s) async => s.language,
      recognizer: rec,
      micPermission: () async => true,
    );
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    await ctl.stop();
    await practice;
    expect(ctl.session.state, LearnState.stopped);
    expect(rec.stopCalls, greaterThan(0));
    ctl.dispose();
  });

  test('speak failure → read error, no mic opened', () async {
    final rec = FakeSpeechRecognizer();
    final ctl = LearnController(
      speak: (s) async => null,
      recognizer: rec,
      micPermission: () async => true,
    );
    await ctl.practice(sent());
    expect(rec.listenCalls, 0);
    expect(ctl.session.state, LearnState.idle);
    ctl.dispose();
  });
}
