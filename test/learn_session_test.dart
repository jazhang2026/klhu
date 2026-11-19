import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/learn_session.dart';

void main() {
  group('LearnSession single-cycle', () {
    test('starts idle', () {
      final s = LearnSession();
      expect(s.state, LearnState.idle);
      expect(s.summary, isEmpty);
    });

    test('begin sentence enters reading state', () {
      final s = LearnSession();
      s.begin('0:10', 'Hello world.');
      expect(s.state, LearnState.reading);
      expect(s.currentKey, '0:10');
    });

    test('state walk: reading → listening → recording → waiting', () {
      final s = LearnSession();
      s.begin('0:10', 'Hi.');
      s.toListening();
      expect(s.state, LearnState.listening);
      s.toRecording();
      expect(s.state, LearnState.recording);
      s.recordVoice(
          duration: const Duration(seconds: 2), audioPath: '/tmp/a.m4a');
      expect(s.state, LearnState.waiting);
    });

    test('one voiced attempt per tap, then waits', () {
      final s = LearnSession();
      s.begin('0:10', 'Hello world.');
      s.toListening();
      s.toRecording();
      s.recordVoice(
          duration: const Duration(seconds: 2), audioPath: '/tmp/a.m4a');
      expect(s.state, LearnState.waiting);
      final r = s.results['0:10']!;
      expect(r.attempts, hasLength(1));
      expect(r.attempts.single.status, AttemptStatus.voice);
      expect(r.attempts.single.attemptIndex, 1);
      expect(r.attempts.single.audioPath, '/tmp/a.m4a');
      expect(r.voiceCount, 1);
    });

    test('no-voice and failed attempts are recorded too', () {
      final s = LearnSession();
      s.begin('0:10', 'Hi.');
      s.toListening();
      s.toRecording();
      s.recordNoVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/n.m4a');
      expect(s.state, LearnState.waiting);
      s.begin('0:10', 'Hi.');
      s.toListening();
      s.toRecording();
      s.recordFailed(AttemptFailure.permissionDenied);
      final r = s.results['0:10']!;
      expect(r.noVoiceCount, 1);
      expect(r.failedCount, 1);
      expect(r.attempts[1].failure, AttemptFailure.permissionDenied);
      expect(r.attempts[1].attemptIndex, 2);
      expect(r.attempts[1].audioPath, isNull);
    });

    test('switching sentences keeps each result', () {
      final s = LearnSession();
      s.begin('0:5', 'First.');
      s.toListening();
      s.toRecording();
      s.recordVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/f.m4a');
      s.begin('5:9', 'Second sentence.');
      expect(s.currentKey, '5:9');
      expect(s.state, LearnState.reading);
      expect(s.results['0:5']!.attempts, hasLength(1));
    });

    test('re-tapping a sentence appends attempts, all kept', () {
      final s = LearnSession();
      for (var i = 0; i < 3; i++) {
        s.begin('0:5', 'Again.');
        s.toListening();
        s.toRecording();
        s.recordVoice(
            duration: const Duration(seconds: 1),
            audioPath: '/tmp/r$i.m4a');
      }
      final r = s.results['0:5']!;
      expect(r.attempts, hasLength(3));
      expect(r.voiceCount, 3);
      expect(r.attempts.map((a) => a.attemptIndex), [1, 2, 3]);
      expect(r.attempts.map((a) => a.audioPath),
          ['/tmp/r0.m4a', '/tmp/r1.m4a', '/tmp/r2.m4a']);
    });

    test('stop ends session and summary covers all sentences', () {
      final s = LearnSession();
      s.begin('0:5', 'One.');
      s.toListening();
      s.toRecording();
      s.recordVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/1.m4a');
      s.begin('5:8', 'Two.');
      s.toListening();
      s.toRecording();
      s.recordNoVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/2.m4a');
      s.stop();
      expect(s.state, LearnState.stopped);
      final summary = s.summary;
      expect(summary, hasLength(2));
      expect(summary[0].sentenceKey, '0:5');
      expect(summary[1].sentenceKey, '5:8');
    });

    test('recordVoice without begin throws StateError', () {
      final s = LearnSession();
      expect(
        () => s.recordVoice(
            duration: Duration.zero, audioPath: '/tmp/x.m4a'),
        throwsStateError,
      );
    });
  });
}
