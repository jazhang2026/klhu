/// Voice-activity detection over a stream of amplitude samples (spec 035,
/// amended): pure Dart, language-agnostic — it only answers "did the
/// learner's voice reach the mic", never what was said.
///
/// Samples are dB values (typically from the recorder's amplitude stream)
/// taken at a roughly fixed interval. A sample counts as voiced when its
/// level exceeds [thresholdDb]; voiced audio is "detected" once the total
/// voiced time reaches [minVoicedMs] — this filters taps, bumps and short
/// breaths while accepting a normal repeat of any language.
library;

class VoiceActivityResult {
  /// True when enough voiced audio was captured to count as a repeat.
  final bool voiced;

  /// Total time spent above the threshold.
  final Duration voicedDuration;

  /// Loudest sample seen (dB), useful for diagnostics.
  final double peakDb;

  const VoiceActivityResult({
    required this.voiced,
    required this.voicedDuration,
    required this.peakDb,
  });
}

/// Analyze amplitude samples. [sampleIntervalMs] is the spacing between
/// samples (the recorder emits ~every 200 ms). Defaults: threshold -45 dB
/// (speech sits well above room noise on phones) and 250 ms minimum voiced
/// time (a single amplitude tick can be a click).
VoiceActivityResult analyzeVoiceActivity(
  List<double> samplesDb, {
  required double sampleIntervalMs,
  double thresholdDb = -45,
  double minVoicedMs = 250,
}) {
  if (samplesDb.isEmpty || sampleIntervalMs <= 0) {
    return const VoiceActivityResult(
        voiced: false, voicedDuration: Duration.zero, peakDb: -160);
  }
  var voicedMs = 0.0;
  var peak = -160.0;
  for (final db in samplesDb) {
    if (db > peak) peak = db;
    if (db >= thresholdDb) voicedMs += sampleIntervalMs;
  }
  return VoiceActivityResult(
    voiced: voicedMs >= minVoicedMs,
    voicedDuration: Duration(milliseconds: voicedMs.round()),
    peakDb: peak,
  );
}

/// Stateful online detector used while a capture window is open: tracks
/// trailing silence so the controller can stop recording shortly after the
/// learner finishes speaking instead of waiting out the full window.
class VoiceWindowTracker {
  VoiceWindowTracker({
    this.thresholdDb = -45,
    this.trailingSilenceMs = 2000,
    this.maxWindowMs = 15000,
    this.sampleIntervalMs = 200,
  });

  final double thresholdDb;
  final double trailingSilenceMs;
  final double maxWindowMs;
  final double sampleIntervalMs;

  double _elapsedMs = 0;
  double _silenceMs = 0;
  bool _sawVoice = false;

  /// Feed one amplitude sample; returns true when the window should close:
  /// either [trailingSilenceMs] of quiet after voice was heard, or the
  /// [maxWindowMs] cap elapsed.
  bool addSample(double db) {
    _elapsedMs += sampleIntervalMs;
    if (db >= thresholdDb) {
      _sawVoice = true;
      _silenceMs = 0;
    } else {
      _silenceMs += sampleIntervalMs;
    }
    if (_elapsedMs >= maxWindowMs) return true;
    return _sawVoice && _silenceMs >= trailingSilenceMs;
  }

  /// Whether any voiced sample was seen so far.
  bool get sawVoice => _sawVoice;
}
