# Data Model: Read-Along Language Learning (035, amended)

All entities are in-memory only — Learn sessions are ephemeral per spec. No persistence, no schema changes to `SavedContent`.

**Amended 2026-11-18** (final, device-verified): speech-to-text was dropped — no transcript, no accuracy, no scorer. Each sentence tap runs ONE read+record attempt; a pure-Dart amplitude VAD decides "voice" vs "no voice"; every capture's `.m4a` is kept for playback until the session ends. The mic opens *paused* before the TTS read and resumes when it ends, so the read is never recorded and the repeat is never clipped.

## Entities

### `LearnAttempt` — one learner repeat of one sentence

| Field | Type | Notes |
|---|---|---|
| `sentenceKey` | `String` | stable identity of the practiced sentence (content offsets `start:end`) |
| `sentenceText` | `String` | display text (shown in the summary) |
| `attemptIndex` | `int` | 1-based position within the sentence's attempt history |
| `status` | `AttemptStatus` | `voice` / `noVoice` / `failed` |
| `duration` | `Duration?` | length of written audio (excludes the paused TTS window) |
| `audioPath` | `String?` | kept `.m4a` in the app cache `learn/` dir; ephemeral |
| `failure` | `AttemptFailure?` | `permissionDenied` / `captureError`; set only when `failed` |

### `SentenceResult` — aggregate for one practiced sentence

| Field | Type | Notes |
|---|---|---|
| `sentenceKey` | `String` | matches attempts |
| `sentenceText` | `String` | display text |
| `attempts` | `List<LearnAttempt>` | in order; grows on every tap of this sentence |
| `voiceCount` / `noVoiceCount` / `failedCount` | `int` | derived counts |

### `LearnSession` — the whole Learn-mode session

| Field | Type | Notes |
|---|---|---|
| `results` | `Map<String, SentenceResult>` | insertion-ordered by first practice |
| `currentKey` | `String?` | sentence mid-cycle, if any |
| `state` | `LearnState` | see state machine |
| `summary` | `List<SentenceResult>` | `results.values` in first-practice order |

## `LearnState` (state machine)

```text
idle ──tap──▶ reading ──TTS done──▶ listening ──▶ recording ──window closed──▶ waiting
  ▲            │                      │                                     │
  │            │ TTS error             │ (mic resumed)                      │ next tap → reading
  │            ▼                      ▼                                     │ Stop → stopped
  │         idle (noteReadError)   failed attempt ──────────────────────────┤
  │                                                                     ▼
  └────────────────────────────────────────────────────────────── stopped
```

- `reading`: mic session is open but **paused**; TTS plays.
- `listening`: TTS done, capture about to resume (transient).
- `recording`: capture resumed; amplitude samples feed the VAD window tracker.
- `waiting`: attempt recorded (voice / noVoice / failed); session idles until the next tap or Stop (FR-010).
- `stopped`: terminal; `summary()` feeds the result sheet. Recordings are deleted when the sheet is dismissed.
- A tap during `reading`/`listening`/`recording` is ignored by the view — one cycle at a time; no highlight is shown for ignored taps.

## Voice activity (`voice_activity.dart`)

Pure Dart over the recorder's amplitude stream (~200 ms samples, dB):

- `analyzeVoiceActivity(samples, {sampleIntervalMs, thresholdDb ≈ -45, minVoicedMs ≈ 250})` → `VoiceActivityResult { voiced, voicedDuration, peakDb }`.
- `VoiceWindowTracker` closes the capture window after ~2 s of trailing silence or the 20 s hard cap — whichever first.

## `VoiceCapture` seam (`voice_capture.dart`)

```dart
abstract class VoiceCapture {
  Future<void> prepare();          // warm recorder + permission/encoder probes
  Future<bool> start(String path); // open mic session (paused by caller next)
  Future<void> pause();            // suspend writing; mic stays open
  Future<void> resume();           // continue into the same file
  Stream<double> get amplitudes;   // dB samples while recording
  Future<CaptureResult?> stop();   // { path, duration } — duration excludes paused time
  Future<void> dispose();
}
```

`RecorderVoiceCapture` implements it on the `record` plugin (`AudioEncoder.aacLc`, 16 kHz mono, `echoCancel`/`noiseSuppress` on, `onAmplitudeChanged` 200 ms). Permission/encoder probes are cached per Learn session; `stop()` is a no-op when no capture is active. `pause()`/`resume()` map to `MediaRecorder.pause()/resume()` — paused audio is discarded, never written.

## `LearnController` (`learn_controller.dart`)

Orchestrates one cycle per `practice(sentence)` call; all platform access injected (`speak`, `capture`, `micPermission`, `recordingPath`) for tests.

Cycle order (final):

1. `session.begin(key, text)` → state `reading`.
2. Prefetch `recordingPath()` + `capture.prepare()` (concurrent, hidden under TTS).
3. Lazy mic permission (first attempt only) → `capture.stop()` (release leftovers) → `capture.start(path)` → `capture.pause()`.
4. `await speak(sentence)` — TTS; mic open but writing nothing.
5. Read failed → release mic, `noteReadError()`, no attempt.
6. `toListening()` → `capture.resume()` → `toRecording()`; collect amplitudes until the window tracker closes (or `stop()` force-closes it).
7. `capture.stop()` → `analyzeVoiceActivity` → `recordVoice` / `recordNoVoice` / `recordFailed` → state `waiting`.

`stop()`: if a capture is in-flight, force-close its window and await the attempt (≤5 s) so the last sentence keeps its recording; then `session.stop()`. `abandon()` (Learn exit/dispose) bumps the generation, stops and disposes the capture; completed recordings are deleted by the caller, in-flight ones are dropped.

Taps while `reading`/`listening`/`recording` are ignored at the view layer (`_learnTap` returns false → no highlight, no `practice()` call).

## What was removed (history)

- `speech_scorer.dart`, `speech_recognizer.dart`, `speech_to_text` dep — STT proved unreliable across devices (missing/broken language packs on ColorOS and GMS).
- 3-cycle repeat — replaced by one read+record per tap after on-device instability.
- `LearnAttempt` transcript/accuracy/missed/extra fields — gone with STT.
- `LearnState.scoring` — gone; states are `idle/reading/listening/recording/waiting/stopped`.
- `cycleIndex`/`_runStart` run-local attempt indexing — attempts are simply appended per sentence.
- `VoiceWindowTracker` 15 s cap → 20 s; trailing silence ~2 s (unchanged semantics).
- Mic-open timing: was "start after TTS completes" (clipped first syllables on device) → now "start paused before TTS, resume on completion".
- `Stop` used to drop an in-flight capture → now lets it finish (bounded) so the last sentence keeps its recording.
- `RecorderVoiceCapture` was created once per page → now fresh per Learn entry (disposed recorder was reused → "Recording failed").
- Summary playback used to delete recordings before the sheet opened → now deleted on sheet dismissal.
- Sentence taps during a cycle used to abandon it (0-attempt entries, overlapping TTS) → now ignored entirely.
- `record` amplitude/VAD analysis covers only post-resume samples — the paused TTS window writes nothing and emits no listened samples.

## Localization keys (×4 ARBs)

`learnToggle`, `learnMode`, `learnStatusReading`, `learnStatusListening`, `learnStatusRecording`, `learnStatusWaiting`, `learnTapSentence`, `learnStop`, `learnStopTitle`, `learnSummaryVoiced`, `learnSummaryNoVoice`, `learnSummaryFailed`, `learnNoVoiceLabel`, `learnVoiceCapturedLabel`, `learnRecordingFailedLabel`, `learnPlayRecording`, `learnStopRecording`, `learnMicDeniedMsg`, `learnMicDeniedTitle`, `learnRecordFailedMsg`.

STT-era keys (`learnStatusScoring`, accuracy/transcript/missed/extra labels) were removed.

## Test seams

- `FakeVoiceCapture` (both test files): scripted `start`/`pause`/`resume`/`stop`/`amplitudes`; `feedVoiceThenSilence`/`feedSilenceToCap` drive the window tracker.
- `FakeVoiceCapture.prepare()` no-op; `RecorderVoiceCapture` lazy `AudioRecorder` so widget tests never touch platform channels.
- `micPermission`/`recordingPath`/`speak` injected into `LearnController`; `voiceCapture`/`micPermission`/`recordingPath` injectable into `ReadingView`.
- `audioplayers` `AudioPlayer` created lazily in `_LearnPlayButton` so widget tests don't hit the platform channel.

## Device-verified behavior (OnePlus 9, `37e102a0`)

- Tap → highlight → KalaHoo reads → status "Recording — your turn" → speak → "Voice heard · Xs" + ▶.
- Re-tap any sentence appends attempts; all kept; ▶ plays each.
- Stop → summary (voiced/no-voice/failed counts + ▶ per recording) → dismiss deletes files.
- Exit/re-enter Learn → fresh recorder each session; no "Recording failed".
- Stop during an open capture → the attempt is still recorded.
- No clipped head: mic resumes instantly at read end (paused-open design).
- Works identically for en / zh-Hans / es — VAD is language-agnostic.
- Android shows the mic indicator during the read too (session open, paused) — accepted trade-off.
- `flutter analyze --no-pub` clean; `flutter test --concurrency=2` all green (1124 tests).
- Commits: `9a0aa10` (STT→VAD pivot), `b05ce23` (one attempt per tap), `38b94fc` (summary playback), `8c4a50a` (fresh recorder), `8faa71b` (busy-tap guard), `deed6dc` (no highlight on ignored tap), `a61c068` (graceful stop + prefetch), `fb30f45` (paused-mic pre-open).

## iOS notes

`record_darwin` implements the same `pause`/`resume` semantics (AVAudioRecorder); `RECORD_AUDIO` equivalent is `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`. Not device-tested — Android is the verified target.

## Known limits

- VAD is energy-based: very quiet speech or loud background noise can misclassify; the audio is always kept so the learner can judge by ear.
- `MediaRecorder.pause()` granularity may leave a few ms of audio at the boundary — inaudible in practice.
- A second `AudioRecorder` cannot run concurrently; the controller serializes captures (one Learn cycle at a time).
- Recordings live in `cache/` — the OS may purge them under storage pressure mid-session (rare; session is short-lived by design).
- The mic indicator stays lit during the TTS read (paused session) — inherent to the no-clip design.

## Related files

- `lib/learn/learn_controller.dart`, `lib/learn/learn_session.dart`, `lib/learn/voice_activity.dart`, `lib/learn/voice_capture.dart`
- `lib/reading_view.dart` — Learn toggle, `_learnTap`, `_learnSpeak`, `_learnControls`, `_showLearnSummary`, `_deleteLearnRecordings`
- `test/learn_controller_test.dart`, `test/learn_session_test.dart`, `test/voice_activity_test.dart`, `test/reading_view_learn_test.dart`
- `specs/035-read-along/{spec,plan,research,tasks,quickstart}.md`, `checklists/requirements.md`
- `pubspec.yaml`: `record: 7.2.0`, `audioplayers: 6.8.1`, `permission_handler` (+`permission_handler_android` pinned 13.0.1 via override)
- `android/app/src/main/AndroidManifest.xml`: `RECORD_AUDIO`; `ios/Runner/Info.plist`, `macos/Runner/Info.plist`: mic usage strings

## Removed files

- `lib/learn/speech_scorer.dart`, `lib/learn/speech_recognizer.dart` (STT design)
- `test/speech_scorer_test.dart`, `test/speech_recognizer_test.dart` (if present)

## Sources / references

- `record` plugin 7.2.0 (`AudioRecorder.pause/resume`, `onAmplitudeChanged`, `hasPermission`, `isEncoderSupported`)
- `record_android` 2.3.0 — `MediaCaptureEngine` maps pause/resume to `MediaRecorder.pause()/resume()`; paused frames are not written
- `audioplayers` 6.8.1 — `DeviceFileSource` playback
- `permission_handler` 13.x — `Permission.microphone`
- Constitution: `.specify/` (test-first, on-device-first, simplicity)

## Open questions

None — feature is implemented and device-verified. Remaining: merge `035-read-along` → `main` after user approval.

## Next steps

1. User device-walks `specs/035-read-along/quickstart.md` once more on the final build (optional — already verified).
2. Merge branch to `main` on approval.
3. Archive superseded spec docs if a newer convention requires it.

## Notes

- The three original research questions (STT plugin, on-device enforcement, mic permission) are moot — no STT remains. See `research.md` amendment for the pivot rationale (device fragmentation made platform speech recognition unusable for normal users).
- `tasks.md` retains its historical checklist; task text mentioning 3-cycle/STT predates the amendments — this file and `spec.md` are authoritative.
- Quickstart device-walk steps were updated for the single-attempt flow; see `quickstart.md`.
- Constitution check (plan.md) was PASS under the STT design; re-verified conceptually under VAD — still on-device, still test-first, still additive to ReadingView.

## Changelog

- 2026-11-18 — initial data model (STT design).
- 2026-11-18 — amended: voice detection + kept audio; single attempt per tap; paused-mic capture; graceful stop; fresh recorder per session; summary playback lifetime fix.

## See also

- `spec.md` — amended user stories, FRs, edge cases.
- `plan.md` — amended technical context.
- `research.md` — R1–R9 plus amendment notes.
- `tasks.md` — historical task list (checked); see amendment note.
- `quickstart.md` — device walk for the final flow.
- `checklists/requirements.md` — spec quality checklist (16/16).
- `AGENTS.md` — repo verification commands and crash-recovery notes.

## Implementation status

Complete on branch `035-read-along`; all automated checks green; device-verified on OnePlus 9. Awaiting merge approval.

## Review

- Spec: `specs/035-read-along/spec.md`
- Plan: `specs/035-read-along/plan.md`
- Tasks: `specs/035-read-along/tasks.md`
- Research: `specs/035-read-along/research.md`
- Data model: `specs/035-read-along/data-model.md`
- Quickstart: `specs/035-read-along/quickstart.md`
- Checklist: `specs/035-read-along/checklists/requirements.md`

## References

- Flutter/Dart
- `record` plugin
- `audioplayers` plugin
- `permission_handler` plugin
- Android `MediaRecorder` / `AudioRecord`
- iOS `AVAudioRecorder`
- macOS `AVAudioEngine` (via `record_darwin`)
- Pure-Dart DSP / VAD
- Local file I/O (`path_provider`)
- Widget testing (`flutter_test`)

## Appendix A — amended entity field summary

| Entity | Key fields | Lifecycle |
|---|---|---|
| `LearnAttempt` | sentenceKey, sentenceText, attemptIndex, status, duration, audioPath, failure | created per capture; lives in `SentenceResult.attempts` until session end |
| `SentenceResult` | sentenceKey, sentenceText, attempts[] | created on first tap of a sentence; accumulates attempts |
| `LearnSession` | results map, currentKey, state | created on Learn entry; stopped on Stop/exit |
| `VoiceActivityResult` | voiced, voicedDuration, peakDb | transient — computed per attempt, not stored |
| `CaptureResult` | path, duration | transient — returned by `VoiceCapture.stop()` |

## Appendix B — state transition table

| From | Event | To | Side effects |
|---|---|---|---|
| idle | tap sentence | reading | begin(); prepare(); permission; start+pause capture |
| reading | TTS completes | listening | notify |
| listening | resume() ok | recording | capture.resume(); attach amplitude listener |
| recording | window closes | waiting | capture.stop(); analyzeVoiceActivity; record* |
| recording | stop() pressed | waiting→stopped | force-close window; await attempt ≤5s; session.stop() |
| reading/listening/recording | tap another sentence | (ignored) | view returns false; no highlight |
| any | Stop | stopped | graceful stop; summary shown |
| any | exit Learn/dispose | (controller abandoned) | gen++; capture.stop()+dispose(); files deleted |

## Appendix C — file map

```
lib/learn/
  learn_controller.dart   orchestration + lifecycle
  learn_session.dart      state machine + aggregates (pure Dart)
  voice_activity.dart     VAD + window tracker (pure Dart)
  voice_capture.dart      VoiceCapture seam + RecorderVoiceCapture
lib/reading_view.dart     Learn toggle, tap routing, controls, summary, cleanup
test/
  learn_controller_test.dart
  learn_session_test.dart
  voice_activity_test.dart
  reading_view_learn_test.dart
specs/035-read-along/
  spec.md plan.md research.md data-model.md tasks.md quickstart.md
  checklists/requirements.md
```

## Appendix D — verification commands

```bash
flutter analyze --no-pub
flutter test --concurrency=2
flutter build apk --debug
adb -s 37e102a0 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 37e102a0 logcat -s flutter | grep learn
```

## Appendix E — device log markers

- `learn: speak <key>` / `learn: spoke <key> lang=<lang>` — TTS boundaries
- `learn capture: permission=<bool>` / `encoder=<bool>` — prepare probes
- `learn capture: started <path>` — mic session open
- `learn capture done: path=… dur=… samples=…` — window closed
- `learn voice: voiced=<bool> voicedMs=… peak=…` — VAD result
- `learn play: <path>` / `learn play: started` / `learn play failed: …` — playback
- `learn mic permission -> <bool>` — lazy permission result

## Appendix F — glossary

- **Learn mode**: the reading page's practice state, entered via the 🎓 toggle.
- **Attempt**: one read+record cycle for one sentence tap.
- **VAD**: voice-activity detection — energy threshold + min-duration + trailing-silence windowing.
- **Paused-open mic**: `MediaRecorder` session started before TTS but paused; resumed at read end. Nothing is written while paused.
- **Graceful stop**: `LearnController.stop()` lets an in-flight capture finish (bounded) so its attempt is kept.
- **Fresh recorder**: `RecorderVoiceCapture` is created per Learn entry because `abandon()` disposes it.

## Appendix G — risk register (final)

| Risk | Status | Mitigation |
|---|---|---|
| Platform STT unreliable | eliminated | STT removed entirely |
| Recorder disposed reuse | fixed | fresh capture per Learn entry |
| Summary playback ENOENT | fixed | recordings deleted on sheet dismissal |
| Head clipping | fixed | paused-open mic, instant resume |
| Stop drops last attempt | fixed | graceful stop awaits in-flight capture |
| Rapid taps corrupt state | fixed | taps ignored during in-flight cycle |
| Highlight without read | fixed | `_learnTap` returns bool; `_select` only on accept |
| VAD false positives/negatives | accepted | audio always kept for self-review |
| Mic indicator during TTS | accepted | inherent to no-clip design |
| Cache-dir purge mid-session | accepted | sessions are short; OS purge is rare |

## Appendix H — commit index

| Commit | Change |
|---|---|
| `9458748` | initial STT-based Learn implementation |
| `53d3955` | permission_handler_android pin for compileSdk |
| `9a0aa10` | replace STT with voice detection + kept audio |
| `b05ce23` | one read+record per tap; drop 3-cycle repeat |
| `38b94fc` | keep Learn recordings alive for summary playback |
| `8c4a50a` | fresh recorder per Learn session |
| `8faa71b` | ignore sentence taps during in-flight cycle |
| `deed6dc` | no Learn highlight on ignored taps |
| `a61c068` | graceful stop keeps in-flight attempt; faster mic open |
| `fb30f45` | open mic paused before TTS, resume on read end |

## Appendix I — spec traceability

| Spec item | Implementation |
|---|---|
| FR-001 Learn entry, no changes to existing | `_toggleLearn`, `_learnActive` gate; all existing paths untouched |
| FR-002 reuse sentence model/highlight; comments never read | `_learnTap` → `_learnSpeak` with `commentsRead: false` |
| FR-003 one cycle per tap; no audio written during read | `LearnController._practice`; paused-open mic |
| FR-004 local recording + on-device VAD; no cloud/AI/STT | `RecorderVoiceCapture` + `voice_activity.dart` |
| FR-005 per-attempt result visible | `_learnControls` status line + last-attempt label |
| FR-006 tap any sentence; re-tap appends | `session.begin` appends to `SentenceResult.attempts` |
| FR-007 Stop → summary | `_learnStop` → `_showLearnSummary` |
| FR-008 language-agnostic | VAD is energy-based; no locale dependency |
| FR-009 lazy mic permission, degrade gracefully | `_permissionAsked`/`_permissionGranted`; `permissionDenied` failure |
| FR-010 wait for next tap | `LearnState.waiting`; no auto-advance |
| FR-011 playable audio, kept for session, deleted at end | `audioPath` per attempt; `_deleteLearnRecordings` on dismiss/exit |
| FR-012 mode toggle beside controls | 🎓 toggle in idle control row |
| SC-001 usable without instruction | status line + localized prompts |
| SC-002 100% on-device | no network, no STT, no cloud |
| SC-003 result ~1s after window | VAD is pure Dart on 200ms samples |
| SC-004 regression-free | additive mode; 1124 tests green |
| SC-005 permission denial non-blocking | read still happens; attempt marked failed |

## Appendix J — open follow-ups (non-blocking)

- Optional: shorten trailing-silence window (~2s → ~1.2s) if users find the wait long — trade-off: may clip slow speakers' last phoneme.
- Optional: add a subtle "your turn" beep when `resume()` fires, to make the record window obvious — currently only the status text changes.
- Optional: show attempt count per sentence in the summary rows.
- Merge `035-read-along` → `main` on user approval.

## Appendix K — file:line quick reference

- `lib/learn/learn_controller.dart` — `_practice` (~line 96), `_recordAttempt` (~line 190), `stop` (~line 280), `abandon` (~line 300)
- `lib/learn/learn_session.dart` — `LearnSession.begin` (~96), `recordVoice/NoVoice/Failed` (~122–160), `_advance` (~181)
- `lib/learn/voice_activity.dart` — `analyzeVoiceActivity`, `VoiceWindowTracker`
- `lib/learn/voice_capture.dart` — `RecorderVoiceCapture.start/pause/resume/stop` (~90–180)
- `lib/reading_view.dart` — `_toggleLearn` (~2104), `_learnTap` (~2171), `_learnSpeak` (~2198), `_learnControls` (~2250), `_learnStop` (~2146), `_showLearnSummary`, `_deleteLearnRecordings`

## Appendix L — known-good log sequence (OnePlus 9)

```
learn: speak 93:128
learn capture: permission=true
learn capture: encoder=true
learn capture: started .../attempt_XXX.m4a
learn: spoke 93:128 lang=zh-Hans
learn capture done: path=... dur=0:00:09.5 samples=46
learn voice: voiced=true voicedMs=6400 peak=-12.75
```

(With the paused-open design, `started` now precedes `spoke`; `dur` excludes the paused TTS window.)

## Appendix M — spec amendment index

| Date | Change | Authority |
|---|---|---|
| 2026-11-18 | STT design → voice detection + kept audio | user decision after device testing |
| 2026-11-18 | 3-cycle repeat → one read+record per tap | user decision after instability |
| 2026-11-18 | recordings kept until summary dismiss | bug fix (ENOENT on play) |
| 2026-11-18 | fresh recorder per Learn entry | bug fix (disposed recorder reuse) |
| 2026-11-18 | busy-tap guard + no-highlight-on-ignore | bug fix (0-attempt entries, overlapping TTS) |
| 2026-11-18 | graceful stop keeps in-flight attempt | bug fix (last sentence lost recording) |
| 2026-11-18 | paused-open mic before TTS | fix (head clipping) |

## Appendix N — test inventory

| File | Tests | Covers |
|---|---|---|
| `test/voice_activity_test.dart` | ~6 | VAD thresholds, min duration, window tracker silence/cap |
| `test/learn_session_test.dart` | ~8 | state machine, attempt aggregation, re-practice, stop |
| `test/learn_controller_test.dart` | ~9 | orchestration, echo gate (paused), permission, capture error, stop-during-record, accumulation |
| `test/reading_view_learn_test.dart` | ~6 | toggle swap, tap flow, busy-tap ignore, summary playback, re-tap, exit cleanup |

## Appendix O — dependency diff vs main

```diff
+ record: 7.2.0
+ audioplayers: 6.8.1
+ permission_handler: ^13.0.2
+ permission_handler_android: 13.0.1 (override, compileSdk 35)
- speech_to_text: ^7.5.0 (added then removed during pivot)
```

## Appendix P — platform permissions

| Platform | Permission / usage string | Where |
|---|---|---|
| Android | `android.permission.RECORD_AUDIO` | `android/app/src/main/AndroidManifest.xml` |
| iOS | `NSMicrophoneUsageDescription` | `ios/Runner/Info.plist` |
| macOS | `NSMicrophoneUsageDescription` | `macos/Runner/Info.plist` |

## Appendix Q — ARB key diff vs main

Added (×4 locales): `learnToggle`, `learnMode`, `learnStatusReading`, `learnStatusListening`, `learnStatusRecording`, `learnStatusWaiting`, `learnTapSentence`, `learnStop`, `learnStopTitle`, `learnSummaryVoiced`, `learnSummaryNoVoice`, `learnSummaryFailed`, `learnNoVoiceLabel`, `learnVoiceCapturedLabel`, `learnRecordingFailedLabel`, `learnPlayRecording`, `learnStopRecording`, `learnMicDeniedMsg`, `learnMicDeniedTitle`, `learnRecordFailedMsg`.

Removed during pivot: `learnStatusScoring`, `learnAccuracyLabel`, `learnTranscriptLabel`, `learnMissedLabel`, `learnExtraLabel`, `learnNoSpeechMsg`, `learnUnsupportedMsg`, `learnNoSpeechDetectedLabel` (exact names per ARB history).

## Appendix R — performance notes

- VAD: O(n) over ≤100 samples per attempt — negligible.
- `analyzeVoiceActivity` runs once per attempt on the UI isolate — <1 ms.
- `recorder.start()` latency (~100–300 ms AudioRecord init) is fully hidden: it runs before/during TTS, not after.
- `pause()`/`resume()` are binder calls (~ms) — imperceptible.
- File I/O: one `.m4a` per attempt (~50–200 KB for a sentence) in `cache/`.
- No polling loops; amplitude stream is event-driven at 5 Hz.

## Appendix S — accessibility / UX notes

- Status line uses localized text; icons (▶/■) have semantic labels via l10n.
- Highlight follows the practiced sentence via `_revealRange` scroll-into-view.
- Ignored taps produce no visual change — intentional (prevents confusion vs. abandoned cycles).
- Summary sheet is scrollable for long sessions.

## Appendix T — merge checklist (when approved)

- [ ] `flutter analyze --no-pub` clean on merge commit
- [ ] `flutter test --concurrency=2` all green
- [ ] `git log main..035-read-along` reviewed
- [ ] spec artifacts consistent (this pass)
- [ ] no secrets/keys in diff
- [ ] `pubspec.yaml`/`pubspec.lock` consistent
- [ ] AndroidManifest + plist permissions present
- [ ] l10n ARBs ×4 regenerated
- [ ] device walk signed off (quickstart.md)

## Appendix U — post-merge cleanup ideas (optional)

- Remove `record_use`/`record_windows`/`record_linux`/`record_web` from pub cache if disk pressure (they're transitive deps of `record`, harmless).
- Consider `ffmpeg_kit` audio trim if leading-silence trimming ever needed (currently unnecessary — pause drops TTS).
- Consider persisting session results if users ask (spec says ephemeral — would be a new feature).

## Appendix V — contacts / ownership

- Feature owner: reader (product decisions via conversation)
- Implementation: Devin agent
- Verification device: OnePlus 9 `37e102a0` (primary), OnePlus 13 `38821a76` (secondary, China ROM — noted for future STT-free features)

## Appendix W — session summary (final)

Learn mode is implemented, tested (1124 tests), and device-verified on the OnePlus 9. The final architecture is deliberately minimal: one read+record per tap, paused-open mic for zero-clip capture, energy VAD for voice detection, kept `.m4a` files for playback, graceful stop, fresh recorder per session. No cloud, no AI, no speech recognition, no language packs. All spec artifacts are now consistent with the shipped behavior.

**Status**: ready for merge review.

## Appendix X — one-line summary

KalaHoo reads a sentence; the mic (already open but paused during the read) resumes instantly; the learner's repeat is recorded locally, voice-checked by amplitude VAD, kept for playback, and summarized on Stop — all on-device, all language-agnostic.

## Appendix Y — document control

| Field | Value |
|---|---|
| Feature | 035-read-along |
| Branch | `035-read-along` |
| Last updated | 2026-11-18 |
| Author | Devin (agent) |
| Reviewers | reader (product), pending merge approval |
| Classification | Internal — feature spec artifacts |

## Appendix Z — end of document

*This file is the authoritative data model for feature 035 as implemented. Where it conflicts with earlier drafts in `plan.md`/`research.md`/`tasks.md`, this file and `spec.md` win.*

---

*Generated as part of the spec-kit workflow; amended through device-driven iteration.*

## Final note

The Learn feature is done pending merge. If device testing reveals any regression, the fastest diagnostic is `adb -s 37e102a0 logcat -s flutter | grep learn` — all lifecycle events are logged with the `learn` prefix.

## Sign-off

- [x] Implementation complete
- [x] Tests green
- [x] Analyzer clean
- [x] Device-verified
- [x] Spec artifacts consistent
- [ ] Merge approved (pending user)

*End of data-model.md — amended 2026-11-18.*
