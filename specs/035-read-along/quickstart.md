# Quickstart: Read-Along Language Learning (035, amended)

Validation guide — proves the feature end-to-end. Prerequisites: Flutter
stable, a connected Android device (**OnePlus 9 `37e102a0`** is the primary
target; OnePlus 13 `38821a76` secondary), `flutter pub get` run.

Amended scope: **no speech-to-text**. The mic records each repeat to a local
`.m4a`; a pure-Dart amplitude VAD reports "voice heard" / "no voice
detected"; every capture is kept and playable. No speech packs, no network,
no AI — works on any phone with a mic.

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
- `test/learn_session_test.dart` — 3-cycle state machine, voice/noVoice/
  failed attempts, sentence switching, Stop summary aggregation.
- `test/learn_controller_test.dart` — faked `VoiceCapture`: 3-cycle
  orchestration, echo gate, permission denial, capture errors, stop.
- `test/reading_view_learn_test.dart` — toggle swaps controls, tap starts
  cycle, comments never spoken, Stop shows summary with play buttons,
  re-tap restarts. No platform channels.

## Device walk (OnePlus 9)

Setup: build + install debug APK, launch, open any saved text with at
least 3 sentences (ideally one with a comment).

1. **Enter Learn**: tap the Learn toggle beside the reading controls →
   controls swap to Learn controls (status + Stop + exit). Normal
   read/continue/edit controls are gone; page looks otherwise identical.
2. **First cycle**: tap a sentence → it highlights → KalaHoo reads it
   aloud → *after* the read finishes the status shows "Recording — your
   turn" → speak the sentence → window closes ~2s after you stop →
   "Voice heard · Xs" appears with a small ▶ button.
3. **Playback**: tap ▶ → your recording plays; tap again (■) to stop.
   The recording is *your* voice, not KalaHoo's.
4. **Echo check**: during KalaHoo's read the mic must NOT be recording
   (no attempt completes during TTS).
5. **No-voice case**: stay silent during a repeat → after the ~15s cap the
   attempt shows "No voice detected" but the audio is still kept and
   playable.
6. **Wait state**: after 3 cycles the session waits — it does NOT
   auto-advance.
7. **Next sentence**: tap another sentence → fresh 3-cycle run; the first
   sentence keeps its results.
8. **Comments**: a text with comments — Learn never reads comment text.
9. **Stop**: tap Stop → summary lists every practiced sentence
   (voiced/no-voice/failed counts + attempts) with a ▶ per recording →
   dismiss → recordings deleted → back to normal controls; read/continue
   work exactly as before.
10. **Permission denial**: revoke mic permission in Android settings →
    enter Learn → cycles still read aloud, attempts show "Microphone
    permission needed"; re-grant restores recording.
11. **Regression spot-check**: exit Learn → tap-read a sentence,
    Continue Read, Text type dialog, edit — all behave as before.
12. **Languages**: repeat on English, 简体中文, Español sentences — voice
    detection is language-agnostic; all three should detect voice
    identically.

## Expected outcomes

- SC-001: full 3-cycle practice with voice detection, no instruction
  beyond on-screen prompts.
- SC-002: airplane-mode test — everything still works (fully on-device).
- SC-003: "Voice heard" appears within ~2s of finishing speaking.
- SC-004/SC-005: zero change to existing functions; mic denial never
  blocks reading.

## Known device caveats

- Very quiet speech or heavy background noise may read as "no voice" —
  the recording is still kept; the learner can replay it.
- The 15s cap means a silent window takes up to ~15s to close; speaking
  closes it ~2s after you stop.
- Recordings live in the temp dir and are deleted when the session ends —
  they are not persisted.

## Evidence to capture

- `flutter test` summary line.
- Screen recording or notes for steps 2 (mic gating), 3 (playback),
  8 (comments), 9 (summary), 10 (denial).
- `adb logcat` snippet if any attempt errors unexpectedly
  (debugPrint tags: `learn`).
