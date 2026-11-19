import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/learn_controller.dart';
import 'package:klhu/learn/learn_session.dart';
import 'package:klhu/learn/voice_capture.dart';

/// A scripted capture: tests feed amplitude samples while a window is open;
/// the controller's tracker closes the window on trailing silence or cap.
class FakeVoiceCapture implements VoiceCapture {
  final StreamController<double> _amps =
      StreamController<double>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  bool isRecording = false;
  bool isPaused = false;
  bool startResult = true;
  CaptureResult? stopResult;
  final List<String> paths = [];

  /// Feed amplitude samples (dB) into the open window.
  void feed(List<double> db) {
    for (final v in db) {
      _amps.add(v);
    }
  }

  /// A typical voiced window: speech-level samples then trailing silence —
  /// enough for the tracker to close the window.
  void feedVoiceThenSilence() {
    feed([...List.filled(8, -20.0), ...List.filled(12, -60.0)]);
  }

  /// Pure silence out to the 15s cap (75 samples @200ms).
  void feedSilenceToCap() {
    feed(List.filled(80, -60.0));
  }

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> start(String path) async {
    startCalls++;
    paths.add(path);
    isRecording = startResult;
    isPaused = false;
    return startResult;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    isPaused = isRecording;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    isPaused = false;
  }

  @override
  Stream<double> get amplitudes => _amps.stream;

  @override
  Future<CaptureResult?> stop() async {
    stopCalls++;
    isRecording = false;
    isPaused = false;
    return stopResult ??
        CaptureResult(path: paths.isEmpty ? '' : paths.last,
            duration: const Duration(seconds: 3));
  }

  @override
  Future<void> dispose() async {
    await _amps.close();
  }
}

void main() {
  LearnSentence sent({String text = 'Hello world.', String lang = 'en'}) =>
      LearnSentence(
          key: '0:12', start: 0, end: 12, text: text, language: lang);

  var pathSeq = 0;
  String nextPath() => '/tmp/learn/a${pathSeq++}.m4a';

  LearnController makeCtl(
    FakeVoiceCapture cap, {
    Future<String?> Function(LearnSentence)? speak,
    Future<bool> Function()? micPermission,
  }) =>
      LearnController(
        speak: speak ?? (s) async => s.language,
        capture: cap,
        micPermission: micPermission ?? () async => true,
        recordingPath: () async => nextPath(),
      );

  /// Runs one practice() and feeds the capture window as it opens.
  Future<LearnController> runOnce(
    FakeVoiceCapture cap, {
    void Function()? feed,
    Future<String?> Function(LearnSentence)? speak,
    Future<bool> Function()? micPermission,
    LearnSentence? sentence,
  }) async {
    final ctl = makeCtl(cap,
        speak: speak, micPermission: micPermission);
    final practice = ctl.practice(sentence ?? sent());
    for (var spins = 0; spins < 200; spins++) {
      if (ctl.session.state == LearnState.waiting ||
          ctl.session.state == LearnState.idle ||
          ctl.session.state == LearnState.stopped) {
        break;
      }
      if (cap.isRecording) {
        (feed ?? cap.feedVoiceThenSilence)();
      }
      await pumpEventQueue();
    }
    await practice;
    return ctl;
  }

  test('one tap: speak once, record once, voice detected', () async {
    final cap = FakeVoiceCapture();
    final spoken = <String>[];
    final ctl = await runOnce(
      cap,
      speak: (s) async {
        spoken.add(s.key);
        return s.language;
      },
    );
    expect(spoken, hasLength(1));
    expect(cap.startCalls, 1);
    expect(ctl.session.state, LearnState.waiting);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(1));
    expect(r.attempts.single.status, AttemptStatus.voice);
    expect(r.attempts.single.audioPath, isNotNull);
    expect(ctl.recordingPaths, hasLength(1));
    ctl.dispose();
  });

  test('stop during recording keeps the in-flight attempt', () async {
    final cap = FakeVoiceCapture();
    final ctl = makeCtl(cap);
    final practice = ctl.practice(sent());
    for (var i = 0; i < 200 && !cap.isRecording; i++) {
      await pumpEventQueue();
    }
    expect(cap.isRecording, isTrue);
    cap.feed(List.filled(6, -20.0));
    await ctl.stop();
    await practice;
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(1));
    expect(r.attempts.single.audioPath, isNotNull);
    expect(ctl.session.state, LearnState.stopped);
    ctl.dispose();
  });

  test('silence → noVoice attempt, audio still kept', () async {
    final cap = FakeVoiceCapture();
    final ctl = await runOnce(cap, feed: cap.feedSilenceToCap);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts.single.status, AttemptStatus.noVoice);
    expect(r.attempts.single.audioPath, isNotNull);
    ctl.dispose();
  });

  test('mic opens PAUSED during the read; resumes only after (echo gate)',
      () async {
    final cap = FakeVoiceCapture();
    final micStateDuringSpeak = <String>[];
    final ctl = makeCtl(
      cap,
      speak: (s) async {
        micStateDuringSpeak.add(!cap.isRecording
            ? 'closed'
            : cap.isPaused
                ? 'paused'
                : 'live');
        return s.language;
      },
    );
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    // The mic session is already open — but paused, so TTS is never
    // written to the file.
    expect(micStateDuringSpeak, ['paused']);
    while (cap.isRecording) {
      cap.feedVoiceThenSilence();
      await pumpEventQueue();
    }
    await practice;
    expect(cap.pauseCalls, greaterThanOrEqualTo(1));
    expect(cap.resumeCalls, greaterThanOrEqualTo(1));
    ctl.dispose();
  });

  test('permission denied → failed attempt, read still happened',
      () async {
    final cap = FakeVoiceCapture();
    var speaks = 0;
    final ctl = await runOnce(
      cap,
      micPermission: () async => false,
      speak: (s) async {
        speaks++;
        return s.language;
      },
    );
    expect(speaks, 1);
    expect(cap.startCalls, 0);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts.single.status, AttemptStatus.failed);
    expect(r.attempts.single.failure, AttemptFailure.permissionDenied);
    ctl.dispose();
  });

  test('capture start failure → failed(captureError)', () async {
    final cap = FakeVoiceCapture()..startResult = false;
    final ctl = await runOnce(cap);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts.single.status, AttemptStatus.failed);
    expect(r.attempts.single.failure, AttemptFailure.captureError);
    ctl.dispose();
  });

  test('stop mid-cycle halts without recording phantom attempts',
      () async {
    final cap = FakeVoiceCapture();
    final ctl = makeCtl(cap);
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    await ctl.stop();
    await practice;
    expect(ctl.session.state, LearnState.stopped);
    expect(cap.stopCalls, greaterThan(0));
    ctl.dispose();
  });

  test('speak failure → read error, paused mic released, no attempt',
      () async {
    final cap = FakeVoiceCapture();
    final ctl = makeCtl(cap, speak: (s) async => null);
    await ctl.practice(sent());
    // The mic opened paused before the read; the failed read releases it
    // without recording an attempt.
    expect(cap.startCalls, 1);
    expect(cap.isRecording, isFalse);
    expect(ctl.session.state, LearnState.idle);
    ctl.dispose();
  });

  test('each tap is one attempt; recordings accumulate', () async {
    final cap = FakeVoiceCapture();
    final ctl = makeCtl(cap);
    for (var i = 0; i < 3; i++) {
      final practice = ctl.practice(sent());
      for (var spins = 0; spins < 200; spins++) {
        if (ctl.session.state == LearnState.waiting) break;
        if (cap.isRecording) cap.feedVoiceThenSilence();
        await pumpEventQueue();
      }
      await practice;
    }
    expect(cap.startCalls, 3);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(r.voiceCount, 3);
    expect(ctl.recordingPaths, hasLength(3));
    ctl.dispose();
  });
}
