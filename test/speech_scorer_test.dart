import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/speech_scorer.dart';

void main() {
  group('scoreTranscript', () {
    test('perfect English match scores 1.0', () {
      final r = scoreTranscript('The cat sat on the mat.',
          'The cat sat on the mat');
      expect(r.accuracy, 1.0);
      expect(r.missed, isEmpty);
      expect(r.extra, isEmpty);
    });

    test('case and punctuation are normalized', () {
      final r = scoreTranscript('Hello, World!', 'hello world');
      expect(r.accuracy, 1.0);
    });

    test('one missed word lowers accuracy and lists it', () {
      final r = scoreTranscript('the quick brown fox', 'the quick fox');
      expect(r.accuracy, closeTo(0.75, 0.001));
      expect(r.missed, contains('brown'));
    });

    test('extra words are reported but do not reduce accuracy', () {
      final r = scoreTranscript('the quick fox', 'the very quick fox');
      expect(r.extra, contains('very'));
      expect(r.accuracy, 1.0);
    });

    test('Spanish words diff correctly', () {
      final r = scoreTranscript('Voy al cine esta noche', 'Voy al cine');
      expect(r.accuracy, closeTo(0.6, 0.001));
      expect(r.missed, containsAll(['esta', 'noche']));
    });

    test('empty transcript scores 0 with all words missed', () {
      final r = scoreTranscript('one two three', '');
      expect(r.accuracy, 0.0);
      expect(r.missed, ['one', 'two', 'three']);
      expect(r.extra, isEmpty);
    });

    test('total mismatch scores 0', () {
      final r = scoreTranscript('one two', 'alpha beta');
      expect(r.accuracy, 0.0);
      expect(r.missed, ['one', 'two']);
      expect(r.extra, ['alpha', 'beta']);
    });

    test('Chinese compares by character', () {
      final r = scoreTranscript('你好世界', '你好');
      expect(r.accuracy, 0.5);
      expect(r.missed, ['世', '界']);
    });

    test('Chinese punctuation ignored', () {
      final r = scoreTranscript('你好，世界！', '你好世界');
      expect(r.accuracy, 1.0);
    });

    test('repeated words align by LCS not multiset', () {
      // "had had" vs "had" — one 'had' should match, not both collapse oddly.
      final r = scoreTranscript('he had had enough', 'he had enough');
      expect(r.accuracy, greaterThan(0.7));
      expect(r.missed.length, lessThanOrEqualTo(2));
    });

    test('empty target does not crash', () {
      final r = scoreTranscript('', 'hello');
      expect(r.accuracy, 0.0);
    });
  });
}
