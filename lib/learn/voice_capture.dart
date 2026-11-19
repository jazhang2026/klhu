import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// One finished voice capture.
class CaptureResult {
  /// Path to the recorded audio file (AAC in an .m4a container).
  final String path;

  /// Wall-clock duration of the capture window.
  final Duration duration;

  const CaptureResult({required this.path, required this.duration});
}

/// Microphone capture seam for Learn mode (spec 035, amended): records the
/// learner's repeat to a local file and streams amplitude samples so the
/// controller can run voice-activity detection. No speech recognition —
/// nothing leaves the device.
///
/// All methods are safe to call from tests via fakes; the platform
/// implementation is [RecorderVoiceCapture].
abstract class VoiceCapture {
  /// Warm platform resources (recorder instance, permission and encoder
  /// probes) so [start] opens the mic with minimal latency. Safe to call
  /// while TTS is still playing — it touches no audio.
  Future<void> prepare() async {}

  /// Begin recording to [path]. Returns false when capture cannot start
  /// (permission missing, encoder unsupported, device busy).
  Future<bool> start(String path);

  /// Suspend writing to the file while keeping the mic session open —
  /// audio captured while paused is discarded, not recorded. Lets Learn
  /// open the mic BEFORE the TTS read and resume the instant it ends, so
  /// the learner's first syllables are never clipped.
  Future<void> pause() async {}

  /// Resume a [pause]d capture; recording continues into the same file.
  Future<void> resume() async {}

  /// Amplitude samples (dB, `current`) while recording — roughly one per
  /// 200 ms. Broadcast; safe to listen before or after [start].
  Stream<double> get amplitudes;

  /// Stop recording and return the finished capture, or null when nothing
  /// usable was written.
  Future<CaptureResult?> stop();

  /// Release platform resources.
  Future<void> dispose();
}

/// [VoiceCapture] on the `record` plugin: AAC-LC into `.m4a`, mono 16 kHz —
/// small files, plays everywhere, amplitude polling every 200 ms.
class RecorderVoiceCapture implements VoiceCapture {
  // Created lazily on first start(): AudioRecorder's constructor touches a
  // platform channel, so it must not run when the page merely builds.
  AudioRecorder? _recorder;
  final Stopwatch _watch = Stopwatch();
  StreamSubscription<Amplitude>? _ampSub;
  final StreamController<double> _amps = StreamController<double>.broadcast();

  /// Permission/encoder probe results — cached by [prepare] so [start]
  /// doesn't pay two platform round-trips after every TTS read.
  bool? _permOk;
  bool? _encoderOk;
  Future<void>? _prepareF;

  /// Whether a capture session is open (started, maybe paused) — lets
  /// [stop] skip a platform call when idle.
  bool _active = false;
  bool _paused = false;

  RecorderVoiceCapture({AudioRecorder? recorder}) : _recorder = recorder;

  @override
  Stream<double> get amplitudes => _amps.stream;

  @override
  Future<void> prepare() {
    return _prepareF ??= _doPrepare();
  }

  Future<void> _doPrepare() async {
    final recorder = _recorder ??= AudioRecorder();
    _permOk ??= await recorder.hasPermission();
    debugPrint('learn capture: permission=$_permOk');
    if (_permOk == true) {
      _encoderOk ??= await recorder.isEncoderSupported(AudioEncoder.aacLc);
      debugPrint('learn capture: encoder=$_encoderOk');
    }
  }

  @override
  Future<bool> start(String path) async {
    final recorder = _recorder ??= AudioRecorder();
    await prepare();
    if (_permOk != true) return false;
    if (_encoderOk != true) return false;
    _watch
      ..reset()
      ..start();
    _ampSub ??= recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((a) => _amps.add(a.current));
    try {
      _active = true;
      _paused = false;
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      debugPrint('learn capture: started $path');
      return true;
    } catch (e) {
      debugPrint('learn capture: start failed: $e');
      _active = false;
      return false;
    }
  }

  @override
  Future<void> pause() async {
    if (!_active || _paused) return;
    try {
      await _recorder?.pause();
      _paused = true;
      // The watch only measures written audio — paused time (the whole
      // TTS read) must not count toward the attempt's duration.
      _watch.stop();
    } catch (e) {
      debugPrint('learn capture: pause failed: $e');
    }
  }

  @override
  Future<void> resume() async {
    if (!_active || !_paused) return;
    try {
      await _recorder?.resume();
      _paused = false;
      _watch.start();
    } catch (e) {
      debugPrint('learn capture: resume failed: $e');
    }
  }

  @override
  Future<CaptureResult?> stop() async {
    _watch.stop();
    if (!_active) return null;
    _active = false;
    _paused = false;
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (e) {
      debugPrint('learn capture: stop failed: $e');
      path = null;
    }
    if (path == null || path.isEmpty) return null;
    return CaptureResult(path: path, duration: _watch.elapsed);
  }

  @override
  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _amps.close();
    await _recorder?.dispose();
  }
}

/// Mic permission check used by the controller's lazy request (FR-009).
/// Returns true when recording permission is granted.
typedef MicPermission = Future<bool> Function();

/// Default [MicPermission]: asks the OS (first call shows the prompt).
Future<bool> requestMicPermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}
