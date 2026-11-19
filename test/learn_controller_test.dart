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
  bool isRecording = false;
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
  Future<bool> start(String path) async {
    startCalls++;
    paths.add(path);
    isRecording = startResult;
    return startResult;
  }

  @override
  Stream<double> get amplitudes => _amps.stream;

  @override
  Future<CaptureResult?> stop() async {
    stopCalls++;
    isRecording = false;
    return stopResult ??
        CaptureResult(path: paths.last, duration: const Duration(seconds: 3));
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

  /// Runs one full practice and feeds each capture window as it opens.
  /// [feed] chooses the amplitude script per attempt.
  Future<LearnController> runPractice(
    FakeVoiceCapture cap, {
    void Function(int attempt)? feed,
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
        (feed ?? (_) => cap.feedVoiceThenSilence())(
            ctl.session.cycleIndex + 1);
      }
      await pumpEventQueue();
    }
    await practice;
    ctl.dispose();
    return ctl;
  }

  test('three cycles: speak → record → voice detected', () async {
    final cap = FakeVoiceCapture();
    final spoken = <String>[];
    final ctl = await runPractice(
      cap,
      speak: (s) async {
        spoken.add(s.key);
        return s.language;
      },
    );
    expect(spoken, hasLength(3));
    expect(cap.startCalls, 3);
    expect(ctl.session.state, LearnState.waiting);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(r.attempts.every((a) => a.status == AttemptStatus.voice), isTrue);
    expect(r.attempts.every((a) => a.audioPath != null), isTrue);
    expect(ctl.recordingPaths, hasLength(3));
  });

  test('silence → noVoice attempts, audio still kept', () async {
    final cap = FakeVoiceCapture();
    final ctl = await runPractice(cap,
        feed: (_) => cap.feedSilenceToCap());
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(r.attempts.every((a) => a.status == AttemptStatus.noVoice),
        isTrue);
    expect(r.noVoiceCount, 3);
    // The audio is kept for playback even when no voice was detected.
    expect(r.attempts.every((a) => a.audioPath != null), isTrue);
  });

  test('mic never opens before speak resolves (echo gate)', () async {
    final cap = FakeVoiceCapture();
    final duringSpeak = <bool>[];
    final ctl = makeCtl(
      cap,
      speak: (s) async {
        duringSpeak.add(cap.isRecording);
        return s.language;
      },
    );
    final practice = ctl.practice(sent());
    await pumpEventQueue();
    expect(duringSpeak, [false]);
    while (cap.isRecording) {
      cap.feedVoiceThenSilence();
      await pumpEventQueue();
    }
    await ctl.stop();
    await practice;
    expect(duringSpeak.every((v) => !v), isTrue);
    ctl.dispose();
  });

  test('permission denied → read-only cycles, failed attempts', () async {
    final cap = FakeVoiceCapture();
    final ctl = await runPractice(cap, micPermission: () async => false);
    expect(cap.startCalls, 0);
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(
        r.attempts.every((a) =>
            a.status == AttemptStatus.failed &&
            a.failure == AttemptFailure.permissionDenied),
        isTrue);
  });

  test('capture start failure → failed(captureError) attempts', () async {
    final cap = FakeVoiceCapture()..startResult = false;
    final ctl = await runPractice(cap);
    // start() returns false → no window opens; the loop still completes
    // three cycles because each cycle re-attempts.
    final r = ctl.session.results['0:12']!;
    expect(r.attempts, hasLength(3));
    expect(
        r.attempts.every((a) =>
            a.status == AttemptStatus.failed &&
            a.failure == AttemptFailure.captureError),
        isTrue);
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

  test('speak failure → read error, no capture opened', () async {
    final cap = FakeVoiceCapture();
    final ctl = makeCtl(cap, speak: (s) async => null);
    await ctl.practice(sent());
    expect(cap.startCalls, 0);
    expect(ctl.session.state, LearnState.idle);
    ctl.dispose();
  });

  test('mixed results across attempts accumulate on the sentence',
      () async {
    final cap = FakeVoiceCapture();
    final ctl = await runPractice(
      cap,
      feed: (i) {
        if (i == 2) {
          cap.feedSilenceToCap();
        } else {
          cap.feedVoiceThenSilence();
        }
      },
    );
    final r = ctl.session.results['0:12']!;
    expect(r.voiceCount, 2);
    expect(r.noVoiceCount, 1);
    expect(r.attempts.map((a) => a.status), [
      AttemptStatus.voice,
      AttemptStatus.noVoice,
      AttemptStatus.voice,
    ]);
  });
}
