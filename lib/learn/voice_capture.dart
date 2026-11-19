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
  /// Begin recording to [path]. Returns false when capture cannot start
  /// (permission missing, encoder unsupported, device busy).
  Future<bool> start(String path);

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

  RecorderVoiceCapture({AudioRecorder? recorder}) : _recorder = recorder;

  @override
  Stream<double> get amplitudes => _amps.stream;

  @override
  Future<bool> start(String path) async {
    final recorder = _recorder ??= AudioRecorder();
    final granted = await recorder.hasPermission();
    debugPrint('learn capture: permission=$granted');
    if (!granted) return false;
    final supported = await recorder.isEncoderSupported(AudioEncoder.aacLc);
    debugPrint('learn capture: encoder=$supported');
    if (!supported) return false;
    _watch
      ..reset()
      ..start();
    _ampSub ??= recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((a) => _amps.add(a.current));
    try {
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
      return false;
    }
  }

  @override
  Future<CaptureResult?> stop() async {
    _watch.stop();
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
