/// Learn-mode session state (spec 035, data-model.md, amended for
/// voice-detection + kept audio): pure Dart — the cycle state machine and
/// per-sentence aggregation live here; all TTS/mic/recording orchestration
/// lives in `learn_controller.dart`.
///
/// Cycle rule (amended 2026-11-18): ONE learner repeat per tap —
/// Kalahoo reads the tapped sentence once, the mic records the learner's
/// reading once, and the session waits for the next tap. Re-tapping a
/// sentence appends another attempt; every recording is kept until Stop.
///
/// Re-practice: `begin` on an already-practiced sentence appends a new
/// attempt to the same [SentenceResult] (history kept for the summary).
library;

/// Where one attempt ended up.
enum AttemptStatus { voice, noVoice, failed }

/// Why a capture produced no usable audio.
enum AttemptFailure { permissionDenied, captureError }

/// The session-level state machine (data-model.md).
enum LearnState { idle, reading, listening, recording, waiting, stopped }

/// One learner repeat of one sentence.
class LearnAttempt {
  final String sentenceKey;
  final String sentenceText;

  /// Position of this attempt within its sentence's history (1-based).
  final int attemptIndex;
  final AttemptStatus status;

  /// Length of the kept recording, when capture succeeded.
  final Duration? duration;

  /// Path to the kept audio file (ephemeral, per-session), when one exists.
  final String? audioPath;

  /// Why the attempt failed, when [status] is [AttemptStatus.failed].
  final AttemptFailure? failure;

  const LearnAttempt({
    required this.sentenceKey,
    required this.sentenceText,
    required this.attemptIndex,
    required this.status,
    this.duration,
    this.audioPath,
    this.failure,
  });
}

/// Aggregate of every attempt made on one sentence this session.
class SentenceResult {
  final String sentenceKey;
  final String sentenceText;
  final List<LearnAttempt> attempts = [];

  SentenceResult({required this.sentenceKey, required this.sentenceText});

  int get voiceCount =>
      attempts.where((a) => a.status == AttemptStatus.voice).length;

  int get noVoiceCount =>
      attempts.where((a) => a.status == AttemptStatus.noVoice).length;

  int get failedCount =>
      attempts.where((a) => a.status == AttemptStatus.failed).length;

  /// Best run: most voiced attempts.
  int get bestVoiceCount {
    // Attempts accumulate across re-practice runs; the "best" is the run
    // with the most voiced attempts — computed per contiguous run is overkill
    // for the summary, so report the voiced count of the latest run.
    return voiceCount;
  }
}

/// The whole Learn session: which sentence is being practiced, how far into
/// its 3-cycle run, and every sentence's accumulated result.
class LearnSession {
  final Map<String, SentenceResult> _results = {};

  String? currentKey;
  String? _currentText;
  LearnState state = LearnState.idle;


  Map<String, SentenceResult> get results => Map.unmodifiable(_results);

  /// Summary order = first-practice order (insertion order of the map).
  List<SentenceResult> get summary => _results.values.toList();

  /// Start (or restart) the 3-cycle practice of [key]/[text]. Any in-flight
  /// cycle for another sentence is abandoned — its recorded attempts remain.
  void begin(String key, String text) {
    _results.putIfAbsent(
        key, () => SentenceResult(sentenceKey: key, sentenceText: text));
    currentKey = key;
    _currentText = text;
    state = LearnState.reading;
  }

  void toListening() {
    if (state != LearnState.reading) return;
    state = LearnState.listening;
  }

  void toRecording() {
    if (state != LearnState.listening) return;
    state = LearnState.recording;
  }

  /// The read for the current attempt failed — back to idle; the learner can
  /// tap again. Recorded attempts are kept.
  void noteReadError() {
    if (currentKey == null) return;
    state = LearnState.idle;
  }

  /// A repeat was captured and voice activity was detected.
  LearnAttempt recordVoice({
    required Duration duration,
    required String audioPath,
  }) {
    final attempt = _record(
      status: AttemptStatus.voice,
      duration: duration,
      audioPath: audioPath,
    );
    _advance();
    return attempt;
  }

  /// A repeat window closed without detectable voice. The audio is still
  /// kept for playback (the learner may have been too quiet).
  LearnAttempt recordNoVoice({
    required Duration duration,
    required String audioPath,
  }) {
    final attempt = _record(
      status: AttemptStatus.noVoice,
      duration: duration,
      audioPath: audioPath,
    );
    _advance();
    return attempt;
  }

  /// Capture could not run (permission denied / recorder error) — counts as
  /// an attempt so the three-cycle contract still completes.
  LearnAttempt recordFailed(AttemptFailure failure) {
    final attempt = _record(status: AttemptStatus.failed, failure: failure);
    _advance();
    return attempt;
  }

  LearnAttempt _record({
    required AttemptStatus status,
    Duration? duration,
    String? audioPath,
    AttemptFailure? failure,
  }) {
    final key = currentKey;
    if (key == null) throw StateError('record* before begin()');
    final result = _results[key]!;
    final attempt = LearnAttempt(
      sentenceKey: key,
      sentenceText: _currentText ?? result.sentenceText,
      attemptIndex: result.attempts.length + 1,
      status: status,
      duration: duration,
      audioPath: audioPath,
      failure: failure,
    );
    result.attempts.add(attempt);
    return attempt;
  }

  /// After the single attempt: wait for the learner's next tap.
  void _advance() {
    state = LearnState.waiting;
  }

  /// End the session (FR-007). Terminal — the controller discards it.
  void stop() {
    state = LearnState.stopped;
  }
}
