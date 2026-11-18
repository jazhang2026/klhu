import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:klhu/learn/learn_session.dart';
import 'package:klhu/learn/speech_recognizer.dart';
import 'package:klhu/learn/speech_scorer.dart';

/// One sentence queued for practice.
class LearnSentence {
  /// Stable identity for the session map: content offsets `start:end`.
  final String key;

  /// Content offsets of the sentence — the reading page rebuilds its
  /// [TextSegment] from these for the TTS read.
  final int start;
  final int end;

  /// The target text scoring compares against — the sentence as written.
  final String text;

  /// The resolved read language for STT locale selection (what KalaHoo
  /// actually spoke), or null when the read failed.
  final String? language;

  const LearnSentence({
    required this.key,
    required this.start,
    required this.end,
    required this.text,
    this.language,
  });
}

/// Reads [sentence] aloud and returns the language it was read in — the
/// resolved language (role override → main override → detection), so
/// recognition matches what was spoken (FR-008). Returns null on read
/// failure. Implemented by the reading page, which owns TTS.
typedef LearnSpeaker = Future<String?> Function(LearnSentence sentence);

/// Ensures microphone permission; true → capture may proceed (FR-009).
typedef MicPermission = Future<bool> Function();

/// Orchestrates one Learn session's three-cycle loop (spec 035 FR-003):
/// Kalahoo reads → mic captures the repeat → score → repeat ×3 → wait.
///
/// All platform access is injected — [speak] (TTS), [recognizer] (STT),
/// [micPermission] — so the whole state machine is unit-testable with fakes.
/// UI listens via [addListener]; [session] exposes the data model.
class LearnController extends ChangeNotifier {
  final LearnSession session = LearnSession();
  final LearnSpeaker _speak;
  final SpeechRecognizer _recognizer;
  final MicPermission _micPermission;

  /// Bumped by [stop]/[abandon] and by each [practice] call so a stale async
  /// cycle can never record an attempt for a sentence the learner left.
  int _gen = 0;

  /// Whether the recognizer initialized successfully this session.
  bool _recognizerReady = false;

  /// Whether mic permission was already asked this session — requested
  /// lazily at the FIRST repeat attempt only (FR-009).
  bool _permissionAsked = false;
  bool _permissionGranted = false;

  /// The most recent attempt, for the status line (score or unscored reason).
  LearnAttempt? lastAttempt;

  LearnController({
    required this._speak,
    required this._recognizer,
    required this._micPermission,
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

      // 2. The learner's repeat — capture, then score.
      await _capture(sentence, language, gen);
      if (!_alive(gen)) return;
      // session.record* already advanced state: reading (next cycle) or
      // waiting (3 done).
      _notify();
    }
  }

  Future<void> _capture(
      LearnSentence sentence, String language, int gen) async {
    session.toScoring();
    _notify();

    final localeId = localeIdFor(language);
    debugPrint('learn capture locale=$localeId');
    if (localeId == null) {
      _record(UnscoredReason.unsupportedLanguage, gen);
      session.endRun();
      return;
    }

    if (!_recognizerReady) {
      _recognizerReady = await _recognizer.initialize();
      if (!_alive(gen)) return;
      if (!_recognizerReady) {
        _record(UnscoredReason.recognitionUnavailable, gen);
        session.endRun();
        return;
      }
    }

    if (!_permissionAsked) {
      _permissionAsked = true;
      _permissionGranted = await _micPermission();
      debugPrint('learn mic permission -> $_permissionGranted');
      if (!_alive(gen)) return;
    }
    if (!_permissionGranted) {
      _record(UnscoredReason.permissionDenied, gen);
      return;
    }

    // Open the mic window; resolve on the first final transcript, done,
    // error, or a bounded timeout — whichever lands first.
    debugPrint('learn listen open');
    final outcome = await _listen(localeId);
    debugPrint('learn listen closed: ${outcome.runtimeType}');
    if (!_alive(gen)) return;

    switch (outcome) {
      case _Transcript():
        final score = scoreTranscript(sentence.text, outcome.text);
        session.recordScored(
          transcript: score.transcript,
          accuracy: score.accuracy,
          missed: score.missed,
          extra: score.extra,
        );
      case _Empty():
        _record(UnscoredReason.noSpeech, gen);
      case _ListenError():
        // error_language_unavailable means this device has no speech pack
        // for the locale — deterministic, so end the run rather than
        // re-reading twice more with no mic window.
        if (outcome.reason.contains('language_unavailable')) {
          _record(UnscoredReason.unsupportedLanguage, gen,
              transcript: outcome.text);
          session.endRun();
        } else {
          _record(UnscoredReason.error, gen, transcript: outcome.text);
        }
    }
    lastAttempt =
        session.results[sentence.key]?.attempts.last ?? lastAttempt;
    _notify();
  }

  void _record(UnscoredReason reason, int gen, {String? transcript}) {
    if (!_alive(gen)) return;
    session.recordUnscored(reason, transcript: transcript);
    lastAttempt =
        session.results[session.currentKey!]?.attempts.last ?? lastAttempt;
  }

  /// One mic window. The completer resolves exactly once.
  Future<_ListenOutcome> _listen(String localeId) async {
    final completer = Completer<_ListenOutcome>();
    String latest = '';
    var sawFinal = false;

    void finish(_ListenOutcome o) {
      if (!completer.isCompleted) completer.complete(o);
    }

    // The platform reports 'done' and the real error in the same frame —
    // done wins the completer before the error lands, which would mislabel
    // error_language_unavailable as noSpeech. Hold the done briefly so a
    // trailing error can still take precedence.
    Timer? doneTimer;
    void done() {
      doneTimer?.cancel();
      doneTimer = Timer(const Duration(milliseconds: 300), () {
        finish(sawFinal && latest.trim().isNotEmpty
            ? _Transcript(latest)
            : const _Empty());
      });
    }

    await _recognizer.listen(
      localeId: localeId,
      onResult: (text, isFinal) {
        if (isFinal) {
          latest = text;
          sawFinal = true;
        }
      },
      onDone: done,
      onError: (reason) {
        doneTimer?.cancel();
        finish(_ListenError(latest, reason));
      },
    );

    // Hard bound: a recognizer that never reports must not hang the cycle.
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => sawFinal && latest.trim().isNotEmpty
          ? _Transcript(latest)
          : const _Empty(),
    );
  }

  bool _alive(int gen) =>
      gen == _gen && session.state != LearnState.stopped;

  /// End the session: close any open mic window, mark stopped. The session's
  /// recorded results remain readable for the summary.
  Future<void> stop() async {
    _gen++;
    await _recognizer.stop();
    session.stop();
    _notify();
  }

  /// Abandon without summary (leaving Learn mode entirely).
  Future<void> abandon() async {
    _gen++;
    await _recognizer.stop();
    _recognizer.dispose();
  }

  void _notify() => notifyListeners();
}

sealed class _ListenOutcome {
  const _ListenOutcome();
}

class _Transcript extends _ListenOutcome {
  final String text;
  const _Transcript(this.text);
}

class _Empty extends _ListenOutcome {
  const _Empty();
}

class _ListenError extends _ListenOutcome {
  final String text;
  final String reason;
  const _ListenError(this.text, this.reason);
}
