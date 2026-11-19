import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/voice_activity.dart';

void main() {
  group('analyzeVoiceActivity', () {
    test('empty samples → not voiced', () {
      final r = analyzeVoiceActivity(const [], sampleIntervalMs: 200);
      expect(r.voiced, isFalse);
      expect(r.voicedDuration, Duration.zero);
      expect(r.peakDb, -160);
    });

    test('silence only → not voiced', () {
      final r = analyzeVoiceActivity(
        List.filled(50, -60.0),
        sampleIntervalMs: 200,
      );
      expect(r.voiced, isFalse);
      expect(r.voicedDuration, Duration.zero);
      expect(r.peakDb, -60);
    });

    test('a loud burst → voiced', () {
      // 10 samples @200ms = 2s of speech-level audio.
      final r = analyzeVoiceActivity(
        [...List.filled(10, -20.0), ...List.filled(20, -60.0)],
        sampleIntervalMs: 200,
      );
      expect(r.voiced, isTrue);
      expect(r.voicedDuration, const Duration(milliseconds: 2000));
      expect(r.peakDb, -20);
    });

    test('brief click below minVoicedMs → not voiced', () {
      // One loud sample = 200ms < 250ms minimum.
      final r = analyzeVoiceActivity(
        [-20.0, ...List.filled(20, -60.0)],
        sampleIntervalMs: 200,
      );
      expect(r.voiced, isFalse);
    });

    test('threshold boundary: exactly at threshold counts', () {
      final r = analyzeVoiceActivity(
        List.filled(5, -45.0),
        sampleIntervalMs: 200,
        minVoicedMs: 500,
      );
      expect(r.voiced, isTrue);
    });

    test('custom threshold rejects moderate noise', () {
      final r = analyzeVoiceActivity(
        List.filled(20, -40.0),
        sampleIntervalMs: 200,
        thresholdDb: -30,
      );
      expect(r.voiced, isFalse);
    });
  });

  group('VoiceWindowTracker', () {
    test('closes after trailing silence once voice was heard', () {
      final t = VoiceWindowTracker(
          trailingSilenceMs: 1000, sampleIntervalMs: 200);
      for (var i = 0; i < 5; i++) {
        expect(t.addSample(-20), isFalse);
      }
      // 5 quiet samples = 1000ms trailing silence → close.
      for (var i = 0; i < 4; i++) {
        expect(t.addSample(-60), isFalse);
      }
      expect(t.addSample(-60), isTrue);
      expect(t.sawVoice, isTrue);
    });

    test('never closes early on silence alone — waits for the cap', () {
      final t = VoiceWindowTracker(
          trailingSilenceMs: 1000,
          maxWindowMs: 2000,
          sampleIntervalMs: 200);
      for (var i = 0; i < 9; i++) {
        expect(t.addSample(-60), isFalse);
      }
      expect(t.addSample(-60), isTrue); // 2000ms cap
      expect(t.sawVoice, isFalse);
    });

    test('voice resets the silence clock', () {
      final t = VoiceWindowTracker(
          trailingSilenceMs: 1000, sampleIntervalMs: 200);
      t.addSample(-20);
      for (var i = 0; i < 4; i++) {
        t.addSample(-60); // 800ms quiet — not yet
      }
      t.addSample(-20); // voice again
      for (var i = 0; i < 4; i++) {
        expect(t.addSample(-60), isFalse);
      }
      expect(t.addSample(-60), isTrue);
    });
  });
}
