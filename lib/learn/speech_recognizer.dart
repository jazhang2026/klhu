import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech-recognition seam for Learn mode (spec 035, research R1/R2/R8).
///
/// The controller only ever sees this interface — tests inject a fake and the
/// platform implementation wraps `speech_to_text` with on-device recognition
/// preferred. Where the platform cannot honor on-device or lacks the locale's
/// language pack, attempts degrade to unscored (spec edge cases).
abstract class SpeechRecognizer {
  /// One-time per app session; false → recognition unavailable.
  Future<bool> initialize();

  /// Open a capture window for [localeId]. [onResult] receives partial and
  /// final transcripts; [onDone] fires when the window closes (endpointing,
  /// timeout, or stop); [onError] reports a recognizer failure.
  Future<void> listen({
    required String localeId,
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String reason)? onError,
  });

  /// Close the capture window early (e.g. session Stop mid-attempt).
  Future<void> stop();

  void dispose();
}

/// BCP-47-ish locale for a resolved read language; null → unsupported → the
/// attempt is marked `unsupportedLanguage` rather than guessed (FR-008).
String? localeIdFor(String language) => switch (language) {
      'en' => 'en_US',
      'zh-Hans' => 'zh_CN',
      'es' => 'es_ES',
      _ => null,
    };

/// `speech_to_text` backed recognizer: on-device preferred, bounded window.
class PlatformSpeechRecognizer implements SpeechRecognizer {
  final stt.SpeechToText _stt;
  bool _ready = false;

  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  PlatformSpeechRecognizer([stt.SpeechToText? sttInstance])
      : _stt = sttInstance ?? stt.SpeechToText();

  @override
  Future<bool> initialize() async {
    if (_ready) return true;
    _ready = await _stt.initialize(
      onStatus: (s) {
        debugPrint('learn-stt status: $s');
        _onStatus?.call(s);
      },
      onError: (e) {
        debugPrint('learn-stt init error: ${e.errorMsg}');
        _onError?.call(e.errorMsg);
      },
    );
    debugPrint('learn-stt initialize -> $_ready');
    if (_ready) {
      try {
        final locales = await _stt.locales();
        debugPrint('learn-stt locales: '
            '${locales.map((l) => l.localeId).join(',')}');
      } catch (_) {}
    }
    return _ready;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String reason)? onError,
  }) async {
    _onStatus = (status) {
      debugPrint('learn-stt status: $status');
      if (status == 'done' || status == 'notListening') onDone?.call();
    };
    _onError = (reason) {
      debugPrint('learn-stt listen error: $reason');
      onError?.call(reason);
    };
    debugPrint('learn-stt listen locale=$localeId');
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: stt.SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 15),
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  void dispose() => _stt.stop();
}
