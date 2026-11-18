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

    test('three scored attempts complete the cycle into waiting', () {
      final s = LearnSession();
      s.begin('0:10', 'Hello world.');
      for (var i = 1; i <= 3; i++) {
        s.toListening();
        expect(s.state, LearnState.listening);
        s.recordScored(
            transcript: 'hello world', accuracy: 0.9, missed: const [], extra: const []);
        if (i < 3) {
          expect(s.state, LearnState.reading);
        }
      }
      expect(s.state, LearnState.waiting);
      final r = s.results['0:10']!;
      expect(r.attempts, hasLength(3));
      expect(r.attempts.map((a) => a.attemptIndex), [1, 2, 3]);
      expect(r.bestAccuracy, 0.9);
      expect(r.lastAccuracy, 0.9);
    });

    test('unscored attempts count toward the three cycles', () {
      final s = LearnSession();
      s.begin('0:10', 'Hi.');
      s.toListening();
      s.recordUnscored(UnscoredReason.noSpeech);
      s.toListening();
      s.recordUnscored(UnscoredReason.permissionDenied);
      s.toListening();
      s.recordUnscored(UnscoredReason.recognitionUnavailable);
      expect(s.state, LearnState.waiting);
      final r = s.results['0:10']!;
      expect(r.unscoredCount, 3);
      expect(r.scoredCount, 0);
      expect(r.bestAccuracy, isNull);
    });

    test('switching sentences mid-cycle keeps partial result', () {
      final s = LearnSession();
      s.begin('0:5', 'First.');
      s.toListening();
      s.recordScored(
          transcript: 'first', accuracy: 1.0, missed: const [], extra: const []);
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
        s.recordScored(
            transcript: 'again', accuracy: 0.8, missed: const [], extra: const []);
      }
      expect(s.state, LearnState.waiting);
      s.begin('0:5', 'Again.');
      expect(s.state, LearnState.reading);
      s.toListening();
      s.recordScored(
          transcript: 'again', accuracy: 1.0, missed: const [], extra: const []);
      final r = s.results['0:5']!;
      expect(r.attempts, hasLength(4));
      expect(r.bestAccuracy, 1.0);
    });

    test('stop ends session and summary covers all sentences', () {
      final s = LearnSession();
      s.begin('0:5', 'One.');
      s.toListening();
      s.recordScored(
          transcript: 'one', accuracy: 0.5, missed: const ['x'], extra: const []);
      s.begin('5:8', 'Two.');
      s.toListening();
      s.recordUnscored(UnscoredReason.noSpeech);
      s.stop();
      expect(s.state, LearnState.stopped);
      final summary = s.summary;
      expect(summary, hasLength(2));
      expect(summary[0].sentenceKey, '0:5');
      expect(summary[1].sentenceKey, '5:8');
    });

    test('recordScored without begin throws StateError', () {
      final s = LearnSession();
      expect(
        () => s.recordScored(
            transcript: 'x', accuracy: 1, missed: const [], extra: const []),
        throwsStateError,
      );
    });
  });
}
