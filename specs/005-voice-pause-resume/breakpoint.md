# Breakpoint: 005-voice-pause-resume (saved 2026-09-22, ~14:45 PDT)

Resume from here. Repo root is `/home/weihongzhang/Documents/GitHub/Projects/klhu`
(NOT `~/Projects/klhu`). Flutter SDK: `export PATH="$HOME/development/flutter/bin:$PATH"`
(v3.47.4). Validation device: `emulator-5554` (1080x2400).

## Status: all 24 tasks done and validated

`flutter analyze` clean, `flutter test` **119/119 green** (was 110 at the last
checkpoint). All ten quickstart scenarios have a PASS, each backed by either a device run
or a named test (details below). Tasks ticked in `tasks.md`, including the deviations.

## What was done in this session (2026-09-22)

1. **Scenario 7 verified on device** (the one open live bug from the previous session):
   read page → Pause → switch language via the app-bar dropdown lands in *idle* in the new
   language (`卡啦虎 | 朗读 朗读全文 停止 编辑`), instead of the stuck `继续/停止/编辑`.
   Fix was already in the tree (`_buildLanguageDropdown` calls the view's own `_stop()`,
   commit e46ca46); it is now proven, not just applied.
2. **`test/reading_view_pause_test.dart` written** (T012 was still missing — the file
   named in the task list did not exist): 7 widget tests covering pause → Resume swap,
   one engine toggle per tap, Resume not re-issuing the read, Stop-while-paused, sentence
   tap while paused, language switch while paused, natural end, rapid toggling.
   - The fake reader mirrors the engine contract that made the old bug possible: pausing
     parks the utterance's completion callback and **stopping a paused utterance never
     delivers it**, so a parked `speakParagraphs` await never returns and its cleanup
     never runs. A fake whose `stop()` completes that future masks the bug — proven by
     reverting `_stop()` → `widget.reader.stop()` and watching the test stay green until
     the fake was fixed, then go red on exactly that one test.
3. **Real i18n bug found and fixed**: the app-bar Voice action had a hardcoded
   `tooltip: 'Voice'`, so the Chinese UI still announced "Voice" (visible in the
   emulator dump). Now `AppLocalizations.of(context)?.voiceButton` → `语音` in ZH.
   Regression test added in `test/branding_test.dart` (proven red on the old code).
4. **Device runs** for scenario 8 (page read ends naturally in ~6 s on a short page →
   button row returns to idle `Read/Read page/Stop/Edit`, no residual pause state) and
   scenario 9 (7 rapid Pause/Resume toggles: no crash, same PID, no ANR/exception in
   logcat, final state matches the last tap).
5. Speech itself was confirmed to be real, not a state-machine no-op: during a read,
   `dumpsys audio` shows a Google TTS `AudioTrack` in `state:started`
   (usage=USAGE_MEDIA, content=CONTENT_TYPE_SPEECH).

## Validated scenarios (005 quickstart)

| # | Scenario | Evidence |
|---|---|---|
| 1 | Voice names in EN | device sweep (prior session) + `test/voice_mapping_test.dart` |
| 2 | Voice names in ZH | device sweep (prior session); labels follow the voice-list language, not the app locale |
| 3 | Pause page read | device + pause test |
| 4 | Resume page read | device + pause test |
| 5 | Stop on other action while paused | sentence tap is the reachable "other action" (Read/Read page are hidden while speaking/paused by design) — device + pause test |
| 6 | Stop button while paused | device (prior session) + pause test |
| 7 | Language switch while paused | device (this session) + pause test (red on pre-fix code) |
| 8 | Auto-complete at end of page | device (this session) + pause test |
| 9 | Rapid pause/resume toggling | device (this session) + pause test |
| 10 | Voice-mapping fallback | `test/voice_mapping_test.dart` (unmapped → raw system id, no crash); not reachable on this emulator since coverage is now complete |

## Validation tooling (reusable)

`~/.hermes/cache/scratch/klhu_ui.py` drives the app over uiautomator by content-desc
instead of hardcoded coordinates:

```bash
python3 ~/.hermes/cache/scratch/klhu_ui.py labels        # what is on screen
python3 ~/.hermes/cache/scratch/klhu_ui.py tap "Read page"
python3 ~/.hermes/cache/scratch/klhu_ui.py wait Pause 15
```

Build/install path that works here:
`flutter build apk --debug` then
`adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`,
launch with `am start -n com.example.klhu/.MainActivity` (avoid `flutter run`, it holds
the terminal).

## Resume after pause: rewritten (second pass, 2026-09-22)

User report: "resume reading is not working after paused." Correct — and the cause was
in the engine, not the UI wiring.

**Root cause (logcat evidence, emulator-5554):**

```
E MethodChannel#flutter_tts: Failed to handle method call
  java.lang.StringIndexOutOfBoundsException: length=6; index=57
      at com.eyedeadevelopment.fluttertts.FlutterTtsPlugin.onMethodCall(FlutterTtsPlugin.kt:363)
  #2 FlutterTts.pause  (flutter_tts.dart:366)
  #3 ReaderService.pause (reader_service.dart:249)
  #4 _ReadingViewState._pauseResume (reading_view.dart:276)
```

`flutter_tts` has no Android pause: `pause()` stops the utterance and remembers the
remaining substring (`pauseText = pauseText.substring(lastProgress)`), and it expects the
app to resume by calling `speak()` again with the same text. Every *further* `pause()`
re-truncates that already-truncated string from an absolute progress index, so the second
call throws inside the plugin: the method call fails and the audio never comes back. The
old code treated `pause()` as a toggle (called it again to resume) — i.e. it always made
exactly the call that crashes.

**Fix (`lib/reader_service.dart`, `lib/reading_view.dart`):**

- `ReaderService` now owns pause/resume instead of delegating to the engine: `pause()`
  stops the audio for real and keeps the queue + the paragraph in flight; the new
  `resume()` re-enters the same queue from that paragraph. `TtsBackend.pause()` was
  deleted, so the crashing call cannot be reached from anywhere in the tree.
- A paused read releases its parked utterance (`_releaseUtterance`) so the loop can
  return instead of parking forever on a completion callback that a stopped utterance
  never delivers; `pause`/`stop`/`resume` each bump the generation, so a released loop
  cannot speak on and a resumed one cannot be clobbered by it.
- **Resume is paragraph-granular**: the interrupted paragraph is read again from its
  start, then the read continues in order (nothing skipped, nothing read twice once the
  queue ends). Mid-utterance positions are unavailable safely, for the reason above.
- The view had a matching bug this exposed: the read's `finally` cleanup ran on a
  *paused* return too, dropping the paused state straight back to idle (Resume vanished
  as soon as the reader stopped). `_runRead` now cleans up only when the view still owns
  a SPEAKING read, and the resume path reuses the read generation so the continuation
  keeps updating the highlight.

**Verified on emulator-5554 (device, not only tests):** read page → Pause → audio tracks
`state:started` 0 and 继续 shown → Resume → audio started again, 暂停 shown → the read ran
on to the end by itself and returned to idle. Google TTS utterance log for that run:
paragraph 1 stopped (`Interrupted: true`) on pause, then two more utterances started
(paragraph 1 re-read, paragraph 2), then the app idled. Zero
`StringIndexOutOfBounds`/`Failed to handle` entries in logcat. Scenario 7 (language
switch while paused) and scenario 9 (rapid toggling, then a real resume) re-checked after
the refactor: both still pass, same PID, no exceptions.

**Tests:** 122 green (`flutter analyze` clean). New: `test/reader_service_test.dart`
"pause / resume (005)" — pause keeps the queue and does not speak on; resume replays the
paused paragraph then finishes the queue (exact utterance and callback-index sequences);
Stop after pause cannot be revived; pause-while-idle / resume-while-speaking are no-ops.
`test/reading_view_pause_test.dart`'s fake now models this contract, and its resume test
asserts the paragraph sequence `[0, 1, 1, 2]` — the interruption is repeated, nothing
skipped.

## Known, deliberately untouched

- `test/branding_test.dart` still carries two `expect(true, isTrue)` placeholder stubs
  from 004 (icon existence / icon fallback). They assert nothing; the file now holds real
  i18n tests next to them. Replace the stubs with a real asset/fallback check when icons
  move.
- The `EN sample` / `中文示例` buttons are hardcoded bilingual labels by design (they name
  the sample's language, not the UI language).
- iPhone/iOS validation is still impossible on this machine (no macOS) — Android
  emulator is the only path.
- `pubspec.lock` has an uncommitted transitive bump (`meta` 1.18.3→1.19.0,
  `vector_math` 2.4.0→2.4.3) from `flutter pub get`; commit it with the next change or
  revert it, but do not leave it dangling.

## Next

Nothing outstanding in 004 or 005. Natural next steps: package the 005 work for the user
to eyeball the new voice-list labels (the one item explicitly deferred on 2026-09-21), or
start the next spec (006) — run the spec-kit `/specify` flow in the repo.
