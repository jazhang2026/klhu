# Quickstart: Reading Video

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-25

Validation guide. Every scenario names **how** it is proven: `[unit]` is a Dart test, `[device]` runs on the
emulator with the app installed, `[structural]` is a file/artifact check. No implementation code here.

The device rows are the only place the Kotlin half is exercised at all (research D9): the platform-half
coverage of this feature is rows 31–36, and nothing else.

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) — `flutter emulators --launch klhu`,
  wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- **`ffprobe` on the host** (`/usr/bin/ffprobe`, measured): the device rows assert on the produced file with
  it, rather than by eye.
- Desktop tests only need the checkout; the suite is **301 tests green on `main`** before this feature
  (measured 2026-09-25 with `flutter test --concurrency=2`).

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get
flutter gen-l10n                            # regenerates lib/l10n/app_localizations*.dart
flutter analyze
flutter test --concurrency=2                # full suite; the emulator being up can make plain
                                            # `flutter test` segfault on this 16 GB host
```

Device rows:

```bash
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am start -n com.example.klhu/.MainActivity
adb -s emulator-5554 logcat -s flutter        # the render's debugPrint evidence: plan, slots, frame counts
```

Reading the persisted state the rows below assert on (the same paths the app reads):

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep -E 'video_aspect|video_record'
# the video library: does the file exist, and what is it?
adb -s emulator-5554 shell content query --uri content://media/external/video/media \
  --projection _display_name:duration:_size | grep -i klhu
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`video_renderer.dart`, `video_painter.dart`, `video_aspect.dart`, `video_record.dart`, `video_review.dart`, `reading_view.dart`, `reader_service.dart`, `lib/platform/*`) |
| `flutter test --concurrency=2` | every `[unit]` scenario below, plus the 301-test baseline as a regression gate |
| `flutter test test/video_timeline_test.dart` | the plan: slots, start point, durations, gaps, bounds (rows 1–6) |
| `flutter test test/video_painter_test.dart` | the frames: highlight, title card, chrome, both aspects, the reader's appearance (rows 7–12) |
| `flutter test test/video_renderer_test.dart` | the render: per-sentence voice, the picture shown, progress, cancel, failure (rows 13–17) |
| `flutter test test/video_aspect_test.dart` | the remembered choice's read/write rules (row 18) |
| `flutter test test/video_record_test.dart` | the file's life cycle: keep/replace, throw away, share, stale, delete (rows 19–24) |
| `flutter test test/reading_view_video_test.dart` | the page's two new states, their confirmations, availability (rows 25–30) |
| `flutter test test/l10n_keys_test.dart` | every new key exists in all four ARBs (row 38) |
| `git diff --stat pubspec.yaml android/app/build.gradle.kts android/settings.gradle.kts` | no dependency and no Gradle change at all (row 37) |

## Re-run the device rows

The `[device]` rows are scripted — one command per row, each printing its evidence and ending with
`RESULT: PASS|FAIL`:

```bash
cd specs/012-reading-video/scripts
python3 klhu_walk_video.py 31     # a real render, asserted with ffprobe
python3 klhu_walk_video.py 32     # a frame per slot boundary; the on-screen picture matches the frame
python3 klhu_walk_video.py 33     # play → keep → gallery → share list → delete (warned)
python3 klhu_walk_video.py 34     # cancel at ~50%: no file, empty cache, an earlier video untouched
python3 klhu_walk_video.py 35     # spike S1: the engine's audio file, measured
python3 klhu_walk_video.py 36     # spike S2: a one-minute render's wall time
```

`ADB_SERIAL` (default `emulator-5554`), `KLHU_REPO` (default this repo) and `KLHU_OUT` (default
`/tmp`) override the defaults; the driver imports `specs/010-continue-read/scripts/klhu_walk_continue.py` for
the shared device mechanics and reads the pre-set text from `assets/content/presets.json`. Rows and
divergences: [breakpoint.md](./breakpoint.md).

## Validation scenarios

### 1. The plan starts where the page would — [unit]

Test: `test/video_timeline_test.dart`, "start point follows the page".
Steps: build the plan with nothing highlighted; then with a sentence highlighted; then with a paragraph
highlighted; and once with a highlight on the content's last sentence.
Expected: the first sentence slot is the content's first sentence / that sentence / the paragraph's first
sentence / the last sentence respectively, and every plan ends at the content's last sentence (never earlier).
Proves FR-004, SC-010.

### 2. The plan covers every sentence, in order — [unit]

Test: `test/video_timeline_test.dart`, "slots cover the remainder".
Steps: build the plan for a mixed English/Chinese pre-set and compare its sentence slots with
`sentenceRanges`/`paragraphRanges` for the same text.
Expected: one slot per sentence from the start point to the end, in reading order, with the same absolute
spans; no sentence is missing and none appears twice. Proves FR-017.

### 3. Each slot lasts exactly as long as its own audio — [unit]

Test: `test/video_timeline_test.dart`, "frames follow the audio".
Steps: feed pass 1 durations (including one long and one very short utterance, and one whose length is not a
whole number of frames) and read the slots' `frames`/`startFrame`.
Expected: `frames == round(ms × fps / 1000)` per slot, `startFrame` is the running total, and Σ frames is the
plan's `totalFrames` — so the picture cannot drift from the voice. Proves FR-016, A5.

### 4. The gaps, the title card and the end hold are within their bounds — [unit]

Test: `test/video_timeline_test.dart`, "the padding and the fixed slots".
Steps: build a plan and inspect consecutive sentence slots' boundaries, the lead-in and the closing slot.
Expected: each inter-sentence gap is ≤ 0.5 s, the title card ≤ 3 s, the end hold ≤ 3 s and lasts at least one
frame beyond the last sentence's audio; the hold is not a cut. Proves FR-008, FR-016.

### 5. An empty content produces no plan — [unit]

Test: `test/video_timeline_test.dart`, "empty and whitespace-only".
Steps: build a plan for `""`, `"   \n  "` and a text with one sentence.
Expected: the first two are refused with the app's existing message and yield no plan; the third yields a
plan with one sentence slot, the title card and the hold. Proves FR-015, US1 scenario 7.

### 6. Each slot carries its paragraph's own language and voice — [unit]

Test: `test/video_timeline_test.dart`, "mixed languages keep their voices".
Steps: build a plan for a text whose paragraphs are English, Cantonese and Spanish, with a chosen voice for
two of the three, and inspect the slots.
Expected: every slot names its paragraph's language and the voice the read would use — the chosen one where
there is one, the read's own fallback where there is not — so the video and the page cannot disagree.
Proves FR-003, SC-007.

### 7. A frame highlights its slot's sentence, inside the column — [unit]

Test: `test/video_painter_test.dart`, "the highlight is the slot's sentence".
Steps: paint one frame per slot for every slot of a multi-sentence plan.
Expected: each frame's painted highlight band covers exactly the slot's sentence span (measured from the
`TextPainter`'s boxes) and lies inside the column's width, with the sentence's text inside the frame's
margins. Proves FR-005, SC-003.

### 8. The video opens with a title card naming the content — [unit]

Test: `test/video_painter_test.dart`, "the title card".
Steps: paint the title card's frame and the first sentence slot's frame.
Expected: the card carries the content's name (and its language where the content has one) and no highlight;
the first sentence's frame carries the first sentence highlighted. Proves FR-008.

### 9. No frame carries the app or the device — [unit]

Test: `test/video_painter_test.dart`, "the frame is the video's own".
Steps: paint every slot's frame for both aspects and assert on what the painter was asked to draw.
Expected: no app bar, button, hint, dialog or keyboard is drawn; no status or navigation area is drawn; the
text block sits inside the frame with margins on all four sides — the frame is rendered, never a recording.
Proves FR-006, SC-004.

### 10. Each aspect's frames are that aspect's frame — [unit]

Test: `test/video_painter_test.dart`, "both aspects".
Steps: paint the same slot as `landscape` and as `vertical`.
Expected: the frames measure 1920×1080 and 1080×1920, the column and margins differ accordingly, and the
highlight and text are correct in both. Proves FR-007, SC-012.

### 11. The video's text is the reader's own typeface and size — [unit]

Test: `test/video_painter_test.dart`, "the appearance carries over".
Steps: paint the same slot at `small`, `medium`, `large` and `xlarge`, and at each of the three typefaces.
Expected: the painted text's height differs by the ratio of the sizes (within 10 %) and the family in the
style is the chosen one — the reader's choice reaches the video instead of being overridden. Proves FR-014,
SC-011.

### 12. The smallest size is still legible on the smallest column — [unit]

Test: `test/video_painter_test.dart`, "legibility floor".
Steps: paint at `small` in a `vertical` frame (the narrowest column) and measure the glyph height and the
column's characters per line.
Expected: the glyph height and the line length stay at or above the plan's stated floor for legibility at
100 % — A3's consequence needs to be proven on the smallest size, not the largest. Proves FR-014, A3.

### 13. Every sentence is synthesised, with the read's own voice, in order — [unit]

Test: `test/video_renderer_test.dart`, "pass 1 asks the engine once per sentence".
Steps: run a render against a fake engine that records every `setLanguage` / `setVoice` / `synthesizeToFile`
call, for a mixed-language content.
Expected: one synthesis per sentence, in slot order, each preceded by that slot's language and voice — the
same values the read uses — and the file's path is the render's own. Proves FR-003, FR-017.

### 14. The picture the reader sees is the frame being written — [unit]

Test: `test/video_renderer_test.dart`, "the preview is the encoded frame".
Steps: run a render against a fake encoder that records every `sendFrame`, and collect what the renderer
published as the current picture.
Expected: at every moment the published picture is the image whose bytes the encoder just received, and a
frame is only produced when the highlight or the scroll changes (Σ repeats = `totalFrames`). Proves FR-020,
SC-014.

### 15. Progress is the timeline's own position — [unit]

Test: `test/video_renderer_test.dart`, "progress".
Steps: run a render and record the reported progress.
Expected: progress never goes backwards, reaches 100 % exactly when `finishRender` is called, and reflects
sentences first (pass 1) then frames (pass 2). Proves FR-009.

### 16. Cancelling leaves no file behind — [unit]

Test: `test/video_renderer_test.dart`, "cancel at any point".
Steps: cancel at the start, mid-pass-1, mid-pass-2 and after the last frame but before `finishRender`.
Expected: every case ends with the working file gone, the temp directory empty, the content, the reading
position and the appearance unchanged, and a kept video for that content (if any) untouched. Proves FR-009,
SC-006, SC-013.

### 17. A failed render is reported and keeps nothing — [unit]

Test: `test/video_renderer_test.dart`, "failures".
Steps: make the fake engine fail on one sentence, the fake encoder fail on one frame, and the working
directory read-only, one case each.
Expected: the render stops with the failure reported, nothing is kept, no partial file remains, and the page
returns to idle. Proves FR-009.

### 18. The remembered aspect obeys its contract — [unit]

Test: `test/video_aspect_test.dart`.
Steps: read with no key, with `vertical`, with a junk value; write a choice; read again after a fresh load.
Expected: default `landscape`, `vertical` honoured, junk treated as `landscape` without rewriting, one write
per confirmed choice, the value survives a reload (contract `video-aspect-format.md`). Proves FR-007, A8.

### 19. Keeping writes one entry and replaces what was there — [unit]

Test: `test/video_record_test.dart`, "keep replaces".
Steps: keep a video for a content; keep a second one for the same content.
Expected: one entry afterwards, naming the second file, and the platform's `keep` was called with the first
file's URI as `previousUri` (write-then-delete). Proves FR-011, FR-012, SC-008, SC-015.

### 20. Throwing a render away touches nothing that was kept — [unit]

Test: `test/video_record_test.dart`, "throw away".
Steps: keep a video; render again; throw the second render away.
Expected: the working copy is deleted, `keep` was never called, the store still names the first video, and the
content still offers to play, share or delete it. Proves FR-021, SC-015.

### 21. Sharing works before keeping and after it — [unit]

Test: `test/video_record_test.dart`, "share".
Steps: share an undecided review's working copy; then share a kept video; then throw a shared render away.
Expected: the platform's `share` was called with the working copy's path in the first case and with the kept
video's URI in the second, `keep` was not called by sharing, and throwing the shared render away still keeps
nothing. Proves FR-023, SC-017, A12.

### 22. A record whose file is gone is reported, not played — [unit]

Test: `test/video_record_test.dart`, "stale".
Steps: seed an entry whose file the fake platform reports as absent, then open the content.
Expected: the app reports the video as gone, the entry is forgotten, and the content offers to record again —
never a play action that fails. Proves FR-022, SC-016.

### 23. Deleting warns, and dismissing keeps everything — [unit]

Test: `test/video_record_test.dart`, "delete warns".
Steps: delete a kept video and dismiss the warning; then confirm it.
Expected: on dismissal the platform's `delete` was never called, the entry and the file are untouched and the
video is still playable; on confirmation `delete` was called with that URI and the entry was removed.
Proves FR-024, SC-018.

### 24. Deleting removes the file and the record — [unit]

Test: `test/video_record_test.dart`, "delete removes".
Steps: delete a kept video (confirmed) and then open the content.
Expected: the file is gone from the platform's library, the store has no entry for that content, and the
content offers to record a video again. Proves FR-022, SC-016.

### 25. While rendering, only the picture and Stop exist — [unit]

Test: `test/reading_view_video_test.dart`, "the RENDERING state".
Steps: start a render and inspect the page: the app bar's actions, the text's gestures, the toolbar.
Expected: the pages's other actions (Read, Continue Read, Edit, Appearance, Contents, Voice, the video action
itself) are not offered; the picture area shows the renderer's current frame; the only control is Stop; a tap
and a long-press on the text change nothing. Proves FR-019, SC-013.

### 26. Stop asks first, and both answers do what they say — [unit]

Test: `test/reading_view_video_test.dart`, "Stop's confirmation".
Steps: tap Stop and dismiss; tap Stop and confirm — while checking the renderer's own progress between the
two.
Expected: dismissing leaves the render running (the progress moves on and the render still finishes); nothing
is paused while the box is up; confirming stops it with no file written for that content and the page back to
its idle controls. Proves FR-019, SC-013.

### 27. Leaving asks, and an undecided review keeps nothing — [unit]

Test: `test/reading_view_video_test.dart`, "leaving".
Steps: leave the page mid-render (confirmed and dismissed); leave a finished review without deciding.
Expected: leaving a render asks the same way Stop does and cancels only on confirmation; leaving an undecided
review keeps nothing, reports nothing kept, and cleans the working copy up. Proves FR-019, FR-021.

### 28. The action is idle-only, and absent where rendering is impossible — [unit]

Test: `test/reading_view_video_test.dart`, "availability".
Steps: pump the page in READ, in SPEAKING, in PAUSED and in EDIT; then pump it with the platform reporting
`isAvailable() == false` (the iOS case, D8).
Expected: the video action is offered only from idle; in the unavailable case no action is offered at all and
nothing about the page suggests a video can be made. Proves FR-001, FR-010, D8.

### 29. The review plays before anything is kept — [unit]

Test: `test/reading_view_video_test.dart`, "the review".
Steps: finish a render and inspect the review: the player's source, the three actions, the library's state.
Expected: the player is pointed at the working copy (not at a library file), the platform's `keep` has not
been called, and keep / throw away / share are all offered. Proves FR-021, SC-015.

### 30. The page's shipped behaviour is untouched — [unit]

Test: `test/reading_view_video_test.dart`, plus the existing suites unchanged.
Steps: run the reading page's own tests (follow, pause, continue, edit, mixed) with the new states present.
Expected: every one of them still passes without being rewritten; the new states are additional rows in the
page's state machine, not a change to the old ones. Proves FR-018, SC-009.

### 31. A real render produces a real video — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 31`.
Steps: record the shipped English pre-set from the first sentence, as `landscape`; then record it as
`vertical`; pull both files.
Expected: `ffprobe` reports one H.264 video stream at exactly 1920×1080 (then 1080×1920) and one AAC audio
stream, a constant frame rate, and a duration equal to the sum of the sentences' audio plus the title card and
the hold, within 2 s; the app reports the file's name and length when the render is done. Proves FR-002,
FR-007, SC-001, SC-002, SC-005, SC-012.

### 32. Every slot's frames carry its highlight, and the screen matched them — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 32`.
Steps: extract a frame at each slot's start, middle and end with `ffprobe`/`ffmpeg`; while the render ran,
capture the page and the reported current slot.
Expected: 100 % of sampled frames show that slot's sentence highlighted inside the column with margins and no
app chrome anywhere in any frame; and each capture of the page shows the same sentence that the renderer
reported writing at that moment. Proves FR-005, FR-006, FR-020, SC-003, SC-004, SC-014.

### 33. The file's life cycle on the device — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 33`.
Steps: render, play the review's video, throw one away, keep another, then play it from the gallery, share it,
and finally delete it.
Expected: the throw-away leaves the library without a video for that content; the kept one is listed in the
gallery under the content's name and plays from there; the share list appears with the device's apps; the
delete warns first, and after confirming, the gallery no longer lists the file and the content offers to
record again. Proves FR-011, FR-021, FR-022, FR-023, FR-024, SC-015, SC-016, SC-017, SC-018.

### 34. Cancelling on the device cleans up, and leaves the old video alone — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 34`.
Steps: keep a video for a content; render it again; confirm Stop at about 50 %.
Expected: no file for that content was added or rewritten, the app's cache directory holds no working copy or
per-sentence audio afterwards, and the kept video is still in the gallery and still playable. Proves FR-009,
FR-012, SC-006.

### 35. Spike S1 — does this engine write a usable audio file? — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 35`.
Steps: call the engine's file synthesis for one sentence of the shipped pre-set, then inspect the file it
wrote (header, sample rate, channels, length) and compare the length with the sentence's text.
Expected: a file exists, its header is one the platform half can read (RIFF/WAV), its length is proportional
to the text, and the same call works for an English and a Chinese sentence. A failure here is **not** a test
failure to hide: it changes D3's "read the duration from the header" to a decode step and must be reported.
Proves A6, FR-003.

### 36. Spike S2 — how long does a real render take? — [device]

Test: `python3 specs/012-reading-video/scripts/klhu_walk_video.py 36`.
Steps: time a one-minute reading from the tap to the finished review on the reference device, and count the
frames encoded per second.
Expected: a measured wall time, and a note of which side is the bottleneck (Dart's rasterisation or the
encoder). **This number replaces SC-006's ≤ 5 minutes**, which the spec carries as a placeholder until it is
measured. Proves SC-006.

### 37. No dependency was added — [structural]

Check: `git diff --stat pubspec.yaml android/app/build.gradle.kts android/settings.gradle.kts` is empty, and
`git diff pubspec.lock` shows no new package.
Expected: empty — the feature uses what is installed plus the framework itself (A7, constitution V). The one
third-party piece it leans on, AndroidX's `FileProvider`, arrives transitively and adds no line (F10). Nothing
in the diff names a network client, an account or a key: the video is produced on the device (FR-013).

### 38. Every new key exists in all four locales — [structural]

Check: `flutter test test/l10n_keys_test.dart`, plus `git status --short lib/l10n` after `flutter gen-l10n` is
empty.
Expected: every key added by this feature (the aspect choice and its prompts, the render's labels, the
review's keep/throw away/share, the delete warning and its message, the "video is gone" message, the errors)
exists in `app_en`, `app_es`, `app_zh` and `app_zh_Hans`, and the generated localizations are committed with
no drift.

### 39. The app's other delete still warns — [structural]

Check: `test/video_record_test.dart`'s "the content delete still warns" case, asserting the existing dialog
is still reached for a content (`content_list_screen.dart:92`).
Expected: deleting a content still shows its titled warning and its "cannot be undone" message with Cancel
and Delete — this feature adds a second warned delete rather than replacing the first (FR-024).

### 40. The 011 receipt still passes — [structural]

Check: `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py` for rows 7–10 and 16–17, and
`git status --short` for the files 011 owns.
Expected: the reading page's follow, its appearance and its new-content path behave exactly as 011's receipt
records; this feature changes none of them (FR-018, SC-009). Note: 011's row 18 asserts `git status --short
android/` is empty — true of 011 and **not** a repository invariant, since this feature adds platform code by
design (plan ripple note 4); that row is scoped to 011 and is not re-run against this feature.
