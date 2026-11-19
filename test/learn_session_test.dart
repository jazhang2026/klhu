import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/learn_session.dart';

void main() {
  group('LearnSession cycle', () {
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

    test('state walk: reading → listening → recording → reading', () {
      final s = LearnSession();
      s.begin('0:10', 'Hi.');
      s.toListening();
      expect(s.state, LearnState.listening);
      s.toRecording();
      expect(s.state, LearnState.recording);
    });

    test('three voiced attempts complete the cycle into waiting', () {
      final s = LearnSession();
      s.begin('0:10', 'Hello world.');
      for (var i = 1; i <= 3; i++) {
        s.toListening();
        s.toRecording();
        s.recordVoice(
            duration: const Duration(seconds: 2), audioPath: '/tmp/a$i.m4a');
        if (i < 3) {
          expect(s.state, LearnState.reading);
        }
      }
      expect(s.state, LearnState.waiting);
      final r = s.results['0:10']!;
      expect(r.attempts, hasLength(3));
      expect(r.attempts.map((a) => a.attemptIndex), [1, 2, 3]);
      expect(r.attempts.every((a) => a.status == AttemptStatus.voice), isTrue);
      expect(r.voiceCount, 3);
      expect(r.noVoiceCount, 0);
      expect(r.attempts.first.audioPath, '/tmp/a1.m4a');
    });

    test('no-voice and failed attempts count toward the three cycles', () {
      final s = LearnSession();
      s.begin('0:10', 'Hi.');
      s.toListening();
      s.toRecording();
      s.recordNoVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/n.m4a');
      s.toListening();
      s.toRecording();
      s.recordFailed(AttemptFailure.permissionDenied);
      s.toListening();
      s.toRecording();
      s.recordFailed(AttemptFailure.captureError);
      expect(s.state, LearnState.waiting);
      final r = s.results['0:10']!;
      expect(r.voiceCount, 0);
      expect(r.noVoiceCount, 1);
      expect(r.failedCount, 2);
      expect(r.attempts[1].failure, AttemptFailure.permissionDenied);
      expect(r.attempts[2].audioPath, isNull);
    });

    test('switching sentences mid-cycle keeps partial result', () {
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

    test('re-practicing a sentence appends a fresh run', () {
      final s = LearnSession();
      s.begin('0:5', 'Again.');
      for (var i = 0; i < 3; i++) {
        s.toListening();
        s.toRecording();
        s.recordVoice(
            duration: const Duration(seconds: 1), audioPath: '/tmp/r$i.m4a');
      }
      expect(s.state, LearnState.waiting);
      s.begin('0:5', 'Again.');
      expect(s.state, LearnState.reading);
      s.toListening();
      s.toRecording();
      s.recordVoice(
          duration: const Duration(seconds: 1), audioPath: '/tmp/r3.m4a');
      final r = s.results['0:5']!;
      expect(r.attempts, hasLength(4));
      expect(r.voiceCount, 4);
      expect(r.attempts.last.attemptIndex, 1); // run-local index restarts
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
