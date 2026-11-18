/// Learn-mode session state (spec 035, data-model.md). Pure Dart: the cycle
/// state machine and per-sentence aggregation live here; all TTS/mic/permission
/// orchestration lives in `learn_controller.dart`.
///
/// Cycle rule (FR-003, clarified): exactly three learner repeats per sentence —
/// each is Kalahoo-read → user-repeat. Attempts are recorded whether scored or
/// not; unscored attempts still count toward the three.
///
/// Re-practice (US4): `begin` on an already-practiced sentence starts a fresh
/// run — new attempts append to the same [SentenceResult] (history kept for
/// the summary) and the run-local index restarts at 1.
library;

/// Where one attempt ended up.
enum AttemptStatus { scored, unscored, failed }

/// Why an attempt produced no score.
enum UnscoredReason {
  noSpeech,
  recognitionUnavailable,
  unsupportedLanguage,
  permissionDenied,
  error,
}

/// The session-level state machine (data-model.md).
enum LearnState { idle, reading, listening, scoring, waiting, stopped }

/// One learner repeat of one sentence.
class LearnAttempt {
  final String sentenceKey;
  final String sentenceText;

  /// Position within the current 3-attempt run (1–3), not the lifetime count.
  final int attemptIndex;
  final AttemptStatus status;
  final String? transcript;
  final double? accuracy;
  final List<String> missedWords;
  final List<String> extraWords;
  final UnscoredReason? unscoredReason;

  const LearnAttempt({
    required this.sentenceKey,
    required this.sentenceText,
    required this.attemptIndex,
    required this.status,
    this.transcript,
    this.accuracy,
    this.missedWords = const [],
    this.extraWords = const [],
    this.unscoredReason,
  });
}

/// Aggregate of every attempt made on one sentence this session.
class SentenceResult {
  final String sentenceKey;
  final String sentenceText;
  final List<LearnAttempt> attempts = [];

  SentenceResult({required this.sentenceKey, required this.sentenceText});

  double? get bestAccuracy {
    double? best;
    for (final a in attempts) {
      final acc = a.accuracy;
      if (acc != null && (best == null || acc > best)) best = acc;
    }
    return best;
  }

  double? get lastAccuracy {
    for (var i = attempts.length - 1; i >= 0; i--) {
      final acc = attempts[i].accuracy;
      if (acc != null) return acc;
    }
    return null;
  }

  int get scoredCount =>
      attempts.where((a) => a.status == AttemptStatus.scored).length;

  int get unscoredCount =>
      attempts.where((a) => a.status == AttemptStatus.unscored).length;
}

/// The whole Learn session: which sentence is being practiced, how far into
/// its 3-cycle run, and every sentence's accumulated result.
class LearnSession {
  final Map<String, SentenceResult> _results = {};

  /// Attempts recorded before the current run began — the run-local index is
  /// `result.attempts.length - _runStart`.
  int _runStart = 0;

  String? currentKey;
  String? _currentText;
  LearnState state = LearnState.idle;

  /// Attempts made on the sentence currently being practiced.
  int get cycleIndex =>
      currentKey == null ? 0 : (_results[currentKey]!.attempts.length - _runStart);

  Map<String, SentenceResult> get results => Map.unmodifiable(_results);

  /// Summary order = first-practice order (insertion order of the map).
  List<SentenceResult> get summary => _results.values.toList();

  /// Start (or restart) the 3-cycle practice of [key]/[text]. Any in-flight
  /// cycle for another sentence is abandoned — its recorded attempts remain.
  void begin(String key, String text) {
    final result = _results.putIfAbsent(
        key, () => SentenceResult(sentenceKey: key, sentenceText: text));
    _runStart = result.attempts.length;
    currentKey = key;
    _currentText = text;
    state = LearnState.reading;
  }

  void toListening() {
    if (state != LearnState.reading) return;
    state = LearnState.listening;
  }

  void toScoring() {
    if (state != LearnState.listening) return;
    state = LearnState.scoring;
  }

  /// The read for the current attempt failed — back to idle; the learner can
  /// tap again. Recorded attempts are kept.
  void noteReadError() {
    if (currentKey == null) return;
    state = LearnState.idle;
  }

  /// A repeat produced a scored transcript.
  LearnAttempt recordScored({
    required String transcript,
    required double accuracy,
    List<String> missed = const [],
    List<String> extra = const [],
  }) {
    final attempt = _record(
      status: AttemptStatus.scored,
      transcript: transcript,
      accuracy: accuracy,
      missedWords: missed,
      extraWords: extra,
    );
    _advance();
    return attempt;
  }

  /// A repeat window closed without a usable transcript.
  LearnAttempt recordUnscored(UnscoredReason reason, {String? transcript}) {
    final attempt = _record(
      status: AttemptStatus.unscored,
      transcript: transcript,
      unscoredReason: reason,
    );
    _advance();
    return attempt;
  }

  /// The recognizer itself failed — counts as an unscored attempt so the
  /// three-cycle contract still completes.
  LearnAttempt recordFailed(UnscoredReason reason) =>
      recordUnscored(reason);

  LearnAttempt _record({
    required AttemptStatus status,
    String? transcript,
    double? accuracy,
    List<String> missedWords = const [],
    List<String> extraWords = const [],
    UnscoredReason? unscoredReason,
  }) {
    final key = currentKey;
    if (key == null) throw StateError('record* before begin()');
    final result = _results[key]!;
    final attempt = LearnAttempt(
      sentenceKey: key,
      sentenceText: _currentText ?? result.sentenceText,
      attemptIndex: result.attempts.length - _runStart + 1,
      status: status,
      transcript: transcript,
      accuracy: accuracy,
      missedWords: missedWords,
      extraWords: extraWords,
      unscoredReason: unscoredReason,
    );
    result.attempts.add(attempt);
    return attempt;
  }

  /// After an attempt: 3 done → waiting for the learner's next tap, else the
  /// next read begins.
  void _advance() {
    state = cycleIndex >= 3 ? LearnState.waiting : LearnState.reading;
  }

  /// End the current sentence's run early — used when the failure is
  /// deterministic (no STT for this language, recognizer absent): retrying
  /// the remaining cycles would just re-read aloud with no mic window.
  /// The learner sees the unscored reason and taps again to retry.
  void endRun() {
    if (currentKey == null) return;
    state = LearnState.waiting;
  }

  /// End the session (FR-007). Terminal — the controller discards it.
  void stop() {
    state = LearnState.stopped;
  }
}
