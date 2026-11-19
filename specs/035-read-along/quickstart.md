# Quickstart: Read-Along Language Learning (035, amended)

Validation guide — proves the feature end-to-end. Prerequisites: Flutter
stable, a connected Android device (**OnePlus 9 `37e102a0`** is the primary
target; OnePlus 13 `38821a76` secondary), `flutter pub get` run.

Amended scope: **no speech-to-text, no 3-cycle repeat**. Each sentence tap
runs ONE read → record → voice-check cycle, then waits. The mic records to
a local `.m4a`; a pure-Dart amplitude VAD reports "voice heard" / "no
voice detected"; every capture is kept and playable until Stop. No speech
packs, no network, no AI — works on any phone with a mic.

## Automated checks

```bash
cd ~/Documents/GitHub/Projects/klhu
flutter analyze --no-pub
flutter test --concurrency=2        # all suites incl. new learn tests
```

Expected: analyze clean (pre-existing warnings only); all tests pass
including:

- `test/voice_activity_test.dart` — VAD thresholds, min-voiced-time,
  window tracker trailing-silence/cap.
- `test/learn_session_test.dart` — one-attempt-per-tap state machine,
  voice/noVoice/failed attempts, re-practice appends, Stop summary.
- `test/learn_controller_test.dart` — faked `VoiceCapture`: paused-mic
  echo gate (mic opens paused before TTS, resumes after), permission
  denial, capture errors, graceful stop, attempt accumulation.
- `test/reading_view_learn_test.dart` — toggle swaps controls, tap starts
  cycle, comments never spoken, Stop shows summary with play buttons,
  re-tap restarts. No platform channels.

## Device walk (OnePlus 9)

Setup: build + install debug APK, launch, open any saved text with at
least 3 sentences (ideally one with a comment).

1. **Enter Learn**: tap the Learn toggle beside the reading controls →
   controls swap to Learn controls (status + Stop + exit). Normal
   read/continue/edit controls are gone; page looks otherwise identical.
2. **First tap**: tap a sentence → it highlights → KalaHoo reads it
   aloud → *after* the read finishes the status shows "Recording — your
   turn" → speak the sentence → window closes ~2s after you stop →
   "Voice heard · Xs" appears with a small ▶ button.
3. **Playback**: tap ▶ → your recording plays; tap again (■) to stop.
   The recording is *your* voice, not KalaHoo's.
4. **Echo check**: during KalaHoo's read the mic session is open but
   PAUSED — the recording contains only your voice, never KalaHoo's.
   (Android shows the mic indicator during the read — expected.)
5. **No-voice case**: stay silent during a repeat → after the ~20s cap
   the attempt shows "No voice detected" but the audio is still kept and
   playable.
6. **Next sentence**: tap another sentence → same single read+record;
   the first sentence keeps its result. Re-tap any sentence to append
   another attempt — recordings accumulate.
7. **Comments**: a text with comments — Learn never reads comment text.
8. **Stop**: tap Stop → summary lists every practiced sentence
   (voiced/no-voice/failed counts + attempts) with a ▶ per recording →
   dismiss → recordings deleted → back to normal controls;
   read/continue work exactly as before.
9. **Permission denial**: revoke mic permission in Android settings →
   enter Learn → reads still happen, attempts show "Microphone
   permission needed"; re-grant restores recording.
10. **Regression spot-check**: exit Learn → tap-read a sentence,
    Continue Read, Text type dialog, edit — all behave as before.
11. **Languages**: repeat on English, 简体中文, Español sentences —
    voice detection is language-agnostic; all three should detect voice
    identically.

## Expected outcomes

- SC-001: tap-to-record practice with voice detection, no instruction
  beyond on-screen prompts.
- SC-002: airplane-mode test — everything still works (fully on-device).
- SC-003: "Voice heard" appears within ~2s of finishing speaking.
- SC-004/SC-005: zero change to existing functions; mic denial never
  blocks reading.

## Known device caveats

- Very quiet speech or heavy background noise may read as "no voice" —
  the recording is still kept; the learner can replay it.
- The 20s cap means a silent window takes up to ~20s to close; speaking
  closes it ~2s after you stop.
- Recordings live in the temp dir and are deleted when the session ends —
  they are not persisted.

## Evidence to capture

- `flutter test` summary line.
- Screen recording or notes for steps 2 (mic gating), 3 (playback),
  7 (comments), 8 (summary), 9 (denial).
- `adb logcat` snippet if any attempt errors unexpectedly
  (debugPrint tags: `learn`).
