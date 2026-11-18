# Quickstart: Read-Along Language Learning (035)

Validation guide — proves the feature end-to-end. Prerequisites: Flutter stable, a connected Android device (OnePlus 13 `38821a76` or emulator), `flutter pub get` run.

## Automated checks

```bash
cd ~/Documents/GitHub/Projects/klhu
flutter analyze --no-pub
flutter test --concurrency=2        # all suites incl. new learn tests
```

Expected: analyze clean (pre-existing warnings only); all tests pass including:

- `test/speech_scorer_test.dart` — normalization, en/es word diffs, zh char diffs, empty/mismatch cases.
- `test/learn_session_test.dart` — 3-cycle state machine, unscored attempts, sentence switching, Stop summary aggregation.
- `test/speech_recognizer_test.dart` — fake recognizer: initialize/listen/stop/error paths, no platform channels.
- `test/reading_view_learn_test.dart` — toggle swaps controls, tap starts cycle, comments never spoken, Stop shows summary, permission-denied degrades gracefully.

## Device walk (OnePlus 13)

Setup: build + install debug APK, launch, open any saved text with at least 3 sentences (ideally one with a comment).

1. **Enter Learn**: tap the Learn toggle beside the reading controls → controls swap to Learn controls (mic state + Stop + exit). Normal read/continue/edit controls are gone; page looks otherwise identical.
2. **First cycle**: tap a sentence → it highlights → KalaHoo reads it aloud → *after* the read finishes, the mic window opens (visual indicator) → say the sentence → attempt scores (accuracy % + transcript + missed words) appear. Repeat for attempts 2 and 3 — each is read-then-repeat.
3. **Echo check**: during KalaHoo's read the mic must NOT be capturing (no attempt completes during TTS).
4. **Wait state**: after 3 cycles the sentence shows its result and the session waits — it does NOT auto-advance.
5. **Next sentence**: tap another sentence → fresh 3-cycle run; the first sentence keeps its score.
6. **Comments**: a text with comments — Learn never reads comment text aloud.
7. **Stop**: tap Stop → summary lists every practiced sentence (score, attempts, unscored count) → dismiss → back to normal controls; read/continue work exactly as before.
8. **Permission denial**: revoke mic permission in Android settings → enter Learn → cycles still read aloud but attempts are unscored with explanation; re-grant restores scoring.
9. **Regression spot-check**: exit Learn → tap-read a sentence, Continue Read, Text type dialog, edit — all behave as before.
10. **Language check**: on a Spanish or Chinese sentence the recognizer locale matches the read language (auto-detected or overridden per 034 settings).

## Expected outcomes

- SC-001: full 3-cycle practice + scores with no instruction beyond on-screen prompts.
- SC-002: airplane-mode test — everything still works (fully on-device).
- SC-003: score appears within ~3s of finishing speaking.
- SC-004/SC-005: zero change to existing functions; mic denial never blocks reading.

## Known device caveats

- If the device lacks a speech service or the locale's offline pack, attempts show "recognition unavailable" — that's the designed degradation, not a bug.
- Loud speaker + close mic may transcribe KalaHoo's own audio if the user waits too long; the mic opens only after TTS completes.

## Evidence to capture

- `flutter test` summary line.
- Screen recording or notes for steps 2 (mic gating), 6 (comments), 7 (summary), 8 (denial).
- `adb logcat` snippet if any attempt errors unexpectedly (tag: learn/speech_to_text).
