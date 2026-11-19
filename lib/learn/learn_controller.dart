import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:klhu/learn/learn_session.dart';
import 'package:klhu/learn/voice_activity.dart';
import 'package:klhu/learn/voice_capture.dart';

/// One sentence queued for practice.
class LearnSentence {
  /// Stable identity for the session map: content offsets `start:end`.
  final String key;

  /// Content offsets of the sentence — the reading page rebuilds its
  /// [TextSegment] from these for the TTS read.
  final int start;
  final int end;

  /// The sentence text as written — shown in the summary.
  final String text;

  /// The resolved read language, for diagnostics. Not used for recognition —
  /// voice detection is language-agnostic.
  final String? language;

  const LearnSentence({
    required this.key,
    required this.start,
    required this.end,
    required this.text,
    this.language,
  });
}

/// Reads [sentence] aloud; returns the language it was read in (resolved
/// language — role override → main override → detection) or null on read
/// failure. Implemented by the reading page, which owns TTS.
typedef LearnSpeaker = Future<String?> Function(LearnSentence sentence);

/// Provides a fresh file path for one attempt's recording (ephemeral temp
/// dir, `.m4a`). Implemented by the reading page via path_provider.
typedef RecordingPath = Future<String> Function();

/// Orchestrates one Learn session's three-cycle loop (spec 035 FR-003,
/// amended): Kalahoo reads → mic records the repeat → voice detected?
/// → repeat ×3 → wait.
///
/// No speech recognition: the mic only captures audio; a pure-Dart
/// amplitude VAD decides whether the learner's voice was present. Every
/// captured attempt keeps its audio file for playback.
///
/// All platform access is injected — [speak] (TTS), [capture] (mic),
/// [micPermission], [recordingPath] — so the whole state machine is
/// unit-testable with fakes. UI listens via [addListener]; [session]
/// exposes the data model.
class LearnController extends ChangeNotifier {
  final LearnSession session = LearnSession();
  final LearnSpeaker _speak;
  final VoiceCapture _capture;
  final MicPermission _micPermission;
  final RecordingPath _recordingPath;

  /// Bumped by [stop]/[abandon] and by each [practice] call so a stale async
  /// cycle can never record an attempt for a sentence the learner left.
  int _gen = 0;

  /// Whether mic permission was already asked this session — requested
  /// lazily at the FIRST repeat attempt only (FR-009).
  bool _permissionAsked = false;
  bool _permissionGranted = false;

  /// The most recent attempt, for the status line.
  LearnAttempt? lastAttempt;

  /// Amplitude sample spacing assumed for VAD bookkeeping (matches the
  /// recorder's 200 ms poll).
  static const double _sampleIntervalMs = 200;

  /// Hard bound on one capture window — a learner who never stops talking
  /// still releases the mic.
  static const Duration _maxCapture = Duration(seconds: 20);

  LearnController({
    required this._speak,
    required this._capture,
    required this._micPermission,
    required this._recordingPath,
  });

  /// Current UI-facing status for the Learn control row.
  LearnState get state => session.state;

  /// Practice [sentence]: runs its full 3-cycle loop, then waits. Safe to
  /// call while another sentence is mid-cycle — the old cycle is abandoned
  /// (its recorded attempts remain in the session).
  Future<void> practice(LearnSentence sentence) async {
    final gen = ++_gen;
    session.begin(sentence.key, sentence.text);
    _notify();
    await _runCycles(sentence, gen);
  }

  Future<void> _runCycles(LearnSentence sentence, int gen) async {
    while (_alive(gen) && session.state == LearnState.reading) {
      // 1. KalaHoo reads — the mic must never open during TTS (echo gate).
      debugPrint('learn cycle ${session.cycleIndex + 1}: speak');
      final language = await _speak(sentence);
      debugPrint('learn cycle ${session.cycleIndex + 1}: spoke lang=$language');
      if (!_alive(gen)) return;
      if (language == null) {
        session.noteReadError();
        _notify();
        return;
      }
      session.toListening();
      _notify();

      // 2. The learner's repeat — record, then check for voice.
      await _recordAttempt(sentence, gen);
      if (!_alive(gen)) return;
      // session.record* already advanced state: reading (next cycle) or
      // waiting (3 done).
      _notify();
    }
  }

  Future<void> _recordAttempt(LearnSentence sentence, int gen) async {
    session.toRecording();
    _notify();

    if (!_permissionAsked) {
      _permissionAsked = true;
      _permissionGranted = await _micPermission();
      debugPrint('learn mic permission -> $_permissionGranted');
      if (!_alive(gen)) return;
    }
    if (!_permissionGranted) {
      _record(AttemptFailure.permissionDenied, gen);
      return;
    }

    final path = await _recordingPath();
    if (!_alive(gen)) return;

    final started = await _capture.start(path);
    if (!_alive(gen)) {
      // Abandoned mid-start — make sure the mic is released.
      unawaited(_capture.stop());
      return;
    }
    if (!started) {
      _record(AttemptFailure.captureError, gen);
      return;
    }

    // Collect amplitude samples; the window closes on trailing silence or
    // the hard cap, whichever first — then stop the recorder once.
    final samples = <double>[];
    final tracker = VoiceWindowTracker(
      sampleIntervalMs: _sampleIntervalMs,
      maxWindowMs: _maxCapture.inMilliseconds.toDouble(),
    );
    final windowDone = Completer<void>();
    void closeWindow() {
      if (!windowDone.isCompleted) windowDone.complete();
    }

    final sub = _capture.amplitudes.listen((db) {
      samples.add(db);
      if (tracker.addSample(db)) closeWindow();
    });
    // Safety bound in case the amplitude stream stalls.
    final safety = Timer(_maxCapture + const Duration(seconds: 3), closeWindow);

    await windowDone.future;
    CaptureResult? result;
    try {
      result = await _capture.stop();
    } catch (_) {
      result = null;
    } finally {
      await sub.cancel();
      safety.cancel();
    }
    debugPrint(
        'learn capture done: path=${result?.path} '
        'dur=${result?.duration} samples=${samples.length}');
    if (!_alive(gen)) return;

    if (result == null) {
      _record(AttemptFailure.captureError, gen);
      return;
    }

    final activity = analyzeVoiceActivity(
      samples,
      sampleIntervalMs: _sampleIntervalMs,
    );
    debugPrint('learn voice: voiced=${activity.voiced} '
        'voicedMs=${activity.voicedDuration.inMilliseconds} '
        'peak=${activity.peakDb}');

    if (activity.voiced) {
      session.recordVoice(duration: result.duration, audioPath: result.path);
    } else {
      session.recordNoVoice(duration: result.duration, audioPath: result.path);
    }
    lastAttempt =
        session.results[sentence.key]?.attempts.last ?? lastAttempt;
    _notify();
  }

  void _record(AttemptFailure failure, int gen) {
    if (!_alive(gen)) return;
    session.recordFailed(failure);
    lastAttempt =
        session.results[session.currentKey!]?.attempts.last ?? lastAttempt;
    _notify();
  }

  bool _alive(int gen) =>
      gen == _gen && session.state != LearnState.stopped;

  /// End the session: close any open capture, mark stopped. The session's
  /// recorded results (and their audio paths) remain readable for the
  /// summary — the caller deletes the files afterwards.
  Future<void> stop() async {
    _gen++;
    await _capture.stop();
    session.stop();
    _notify();
  }

  /// Abandon without summary (leaving Learn mode entirely).
  Future<void> abandon() async {
    _gen++;
    await _capture.stop();
    await _capture.dispose();
  }

  /// All audio paths kept this session — for cleanup on exit.
  List<String> get recordingPaths => [
        for (final r in session.summary)
          for (final a in r.attempts)
            if (a.audioPath != null) a.audioPath!,
      ];

  void _notify() => notifyListeners();
}
