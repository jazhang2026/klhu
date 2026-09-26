# Research: Reading Video

**Feature**: `012-reading-video` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

This file records the decisions the plan rests on, the facts each decision was measured against, and
the two spikes that must run before the plan's numbers are trusted. Every fact below was read or run on
this checkout/host/device on 2026-09-25, at the revision named in the plan's Technical Context.

## Measured facts

| # | Fact | How it was established |
|---|---|---|
| F1 | `flutter_tts` 4.2.5 can synthesise text **to a file** without playing it: `synthesizeToFile(text, fileName, [isFullPath])` (Dart `flutter_tts.dart:376`, Android `FlutterTtsPlugin.kt:343` → `synthesizeToFile` at `:708`). With `awaitSpeakCompletion(true)` the call's Future resolves when the file is written; the utterance carries the engine's current bundle, i.e. the voice/language/rate last set | read the installed plugin's Dart and Kotlin sources |
| F2 | The sentence model the timeline needs already exists: `segmenter.dart` exposes `sentenceRanges`, `paragraphRanges`, `pageRange`; `reader_service.dart`'s `SpokenSentence` carries `paragraph`, `sentence` and the absolute span | read `lib/segmenter.dart`, `lib/reader_service.dart:79-200` |
| F3 | The engine is already behind a seam: `reader_service.dart:116-153` declares `getVoices / setLanguage / setVoice / speak / stop / awaitSpeakCompletion / setCompletionHandler` — the test fakes implement it, so a `synthesizeToFile` addition is testable with a fake | read `lib/reader_service.dart:110-160` and the fakes in `test/` |
| F4 | This device encodes H.264 1920×1080 into a playable MP4: `adb shell screenrecord --size 1920x1080 --time-limit 10` finished in 10.3 s and `ffprobe` read `codec_name=h264, 1920x1080` from the pulled file | ran on `emulator-5554`, 2026-09-25 |
| F5 | The emulator's TTS engine is `com.google.android.tts` (the only TTS package installed). It speaks — earlier walks proved which voice spoke via `GoogleTTSServiceImpl` logcat lines — but its **file** synthesis is not yet proven | `adb shell pm list packages`, prior walks |
| F6 | The host has `ffprobe`/`ffmpeg`, so a device row can assert stream shape, duration and per-slot frames mechanically instead of by eye | `which ffprobe` |
| F7 | No platform code exists yet: `MainActivity.kt` is a bare `FlutterActivity`, there is no channel, and `minSdk` resolves to the Flutter default (24) | read `android/app/src/main/kotlin/.../MainActivity.kt`, `android/app/build.gradle.kts` |
| F8 | The reading page's text style is already one seam (`reading_view.dart:927-928`: `fontFamily: _appearance.typeface.familyFor(platform)`, `fontSize: _appearance.size.points`), and the confirmation dialog shape exists (`reading_view.dart:517` `_confirmDiscard()`) | read `lib/reading_view.dart` |
| F9 | 301 tests were green at the 011 receipt; `flutter test` on this 16 GB box needs `--concurrency=2` with the emulator up | prior stage's receipt |
| F10 | `androidx.core` — the home of `FileProvider`, which sharing an app-private file needs — is already resolved for this app (`~/.gradle/caches/modules-2/files-2.1/androidx.core/core` present, pulled in through the Flutter embedding's `androidx.lifecycle` dependency) | listed the Gradle cache, read the embedding's pom |
| F11 | The app's existing destructive delete already warns the way FR-024 requires: `content_list_screen.dart:92` `_confirmDelete` shows a titled `AlertDialog` (`deleteConfirmTitle` "Delete this content?", `deleteConfirmMessage` "This cannot be undone.") with Cancel and a filled Delete | read `lib/content_list_screen.dart:85-115` and `lib/l10n/app_en.arb:40-45` |

## Decisions

### D1 — The video is rendered, not recorded

The frames are painted by the app itself into a video encoder; nothing photographs the screen. There is
no `MediaProjection`, no screen capture, no microphone.

*Why*: FR-006 forbids the app's chrome, the device's status bar and notifications from appearing in any
frame, and FR-003 forbids the audio being a recording of the speaker. Both are unachievable-by-accident
with a screen recorder, and SC-004 is a per-frame assertion that a recorder cannot satisfy reliably.

*Rejected*: `MediaProjection` screen recording — cheapest path to an mp4, and it films exactly what the
spec excludes (plus a per-session user grant dialog, and its audio path would have to capture playback,
breaking FR-003).

### D2 — The frames are Dart's, the encoding is Kotlin's

Each frame is painted in Dart: the same text engine the page uses (`TextPainter`, fed the same
`TextStyle` seam as F8) draws into a `PictureRecorder` canvas sized to the video's frame, the picture
becomes an image, and the image's bytes go to the platform channel as one frame. A frame is produced
**only when the visual state changes** (the highlight moves, the page scrolls) and carries a repeat
count; the encoder emits that frame's bytes `repeat` times so the file keeps a constant frame rate
(FR-007/SC-002). A 60 s reading at 30 fps is ~1800 frames but only a few dozen unique ones, which is
what makes this transport affordable.

*Why*: one text engine. Because the video's wrapping, highlight geometry and typeface come from the same
`TextPainter` the page uses, FR-005 (highlight on the spoken sentence) and FR-014 (the reader's own
typeface and size) hold by construction rather than by a second implementation agreeing with the first.

*Rejected*: Android `StaticLayout` in Kotlin — a second text engine whose line breaking, CJK metrics and
hyphenation would differ from the page's; the video would stop looking like the page and every fidelity
claim would need a cross-engine proof. *Rejected*: streaming full-resolution RGBA (1920×1080×4 ≈ 8 MB per
frame ≈ 249 MB/s at 30 fps) — no channel survives that.

*Fallback if PNG encoding is the bottleneck (spike S2)*: keep the pipeline, change the transport to raw
BGRA bytes over the channel. The encoder path is unaffected.

*The same frame is also the free preview* (FR-020): `Picture.toImage()` yields a `ui.Image`, which the
reading page shows directly while the render runs, and the same image's bytes are what the encoder
receives. One rasterisation serves both the reader's progress display and the file, so "the picture the
reader sees is the frame being written" (FR-020) is literally true rather than synchronised.

### D3 — The audio is the clock (spec A5), in two passes

**Pass 1**: every sentence from its start point to the content's end is synthesised to its own audio file
(FR-004's start rule, `sentenceRanges` from F2), and each file's exact duration is read out of its header.
**Pass 2**: the timeline is built from those durations — each sentence's slot = its audio length, the
title card and the end hold are fixed slots (FR-008/FR-016) — and frames are emitted to match, with the
same PCM encoded to AAC for the audio track.

*Why*: the picture can then never drift from the voice, and a slot's boundaries are exact, which is what
makes SC-003's per-slot frame sampling meaningful. It also makes progress reportable in a unit a user
understands (sentences done, then frames done — FR-009).

*Rejected*: emitting frames on a wall-clock estimate of speech length — drift is unavoidable and SC-003
would fail at the tail of a long content.

### D4 — The platform half knows nothing about text, TTS or the app

The Kotlin side is an encoder and a muxer: an AVC encoder fed by its input surface, an AAC encoder fed
the PCM the Dart side hands over (or the audio files' paths), and a `MediaMuxer` joining them at the
timeline's presentation timestamps. It also owns the two platform-only chores: writing the finished file
where the gallery finds videos (D7) and keeping the screen awake while the render runs (A4).

*Why*: platform code is the least testable part of this feature (it cannot run in `flutter test`), so it
must be as dumb as possible and carry no app logic. Every decision worth testing stays in Dart, behind
the fakes (F3).

*Rejected*: RGBA→YUV conversion in Kotlin to feed the encoder from raw buffers — pointless work when the
input-surface path exists, and it would put pixel handling in the untestable half.

### D5 — The per-sentence voice is the read's own resolution

Before each sentence is synthesised, the engine is set exactly as the read sets it (`setLanguage` +
`setVoice` from the same per-language choice the voice picker writes), then `synthesizeToFile` is called
(F1/F3). The fallback when a language has no chosen voice is the read's fallback, not a new one.

*Why*: FR-003/SC-007 require the video's voice per paragraph to be the page's voice. Sharing the
resolution makes "the video and the page never disagree about the voice" structural.

### D6 — The aspect/resolution is a remembered per-device choice

`shared_preferences` key (`video_aspect`), defaulting to 16:9 1920×1080, offered before a render starts
(FR-007), read by the plan the same way `ReadPositionStore`/`voice_store` are read today. 9:16 is
1080×1920. The frame size drives the layout: the reading column's width, the margins and the scale that
maps the reader's chosen type size onto the frame are derived from it (FR-014/A3) rather than hardcoded
for one aspect.

*Why*: A8, and because the two aspects need different column widths — a 16:9 frame wants a narrower
column than a 9:16 one, and the smallest offered size must still be legible on both (A3's consequence).

### D7 — Where the file lands, and how it is shared

`MediaStore` (`Video`, `Movies/Klhu/`) on API 29+; on 24–28, `getExternalStoragePublicDirectory(MOVIES)`
plus `MediaScannerConnection.scanFile`, with `WRITE_EXTERNAL_STORAGE` declared `maxSdkVersion="28"`. The
file name is the content's name (FR-011); re-rendering the same content deletes the previous file first
(FR-012). Sharing is an `ACTION_SEND` intent carrying the `MediaStore` content URI — no `FileProvider`,
no new dependency.

*Why*: `minSdk` is 24 today (F7) and the app must not silently drop devices by raising it; the two
branches are ~20 lines. The `MediaStore` URI is already shareable, so the share path needs no provider.

### D8 — iOS is a declared gap, not a silent one

The channel protocol and the Dart renderer are platform-neutral; the iOS half (an `AVAssetWriter` +
`AVSpeechSynthesizer` implementation of the same protocol) is **not written in this spec**. Where the
platform half is absent the capability reports itself unavailable and the reading page does not offer the
video action.

*Why*: there is no macOS on this host (the 009/011 precedent), and an unverifiable encoder shipped on
trust is worse than an honest gap. The interface is in place so the iOS implementation is a drop-in.

*Open question for the user*: accept the gap (recommended), or write the Swift half unvalidated.

### D9 — How this gets verified

- **Dart, on the host**: timeline arithmetic and slot mapping (`segmenter` ranges → slots), the frame
  painter's per-slot highlight, progress and cancellation, the RENDERING state's controls and the Stop
  confirmation, the aspect store — all against a fake engine (F3) and a fake encoder, with no device.
- **Device, on `emulator-5554`**: a new walker script drives a render and then the host asserts on the
  file with `ffprobe` (F6): stream count, codec, the exact frame size per aspect (SC-012), the constant
  frame rate, the duration against the audio sum (SC-002), a frame extracted at each slot boundary
  showing that sentence highlighted and inside the column (SC-003), no chrome in any sampled frame
  (SC-004), and the file present in the gallery under the content's name (SC-008/SC-011).
- **The Kotlin half has no unit tests** and is covered only by those rows. That is a stated limit of
  this feature, not an oversight: it is the price of a platform encoder, and it is why D4 keeps the
  platform half logic-free.

### D10 — The render is a state of the reading page, not a new screen

The page gains a RENDERING state beside READ / SPEAKING / PAUSED. Its toolbar is progress + Stop
(FR-019); leaving asks (FR-019) reusing the dialog shape at F8; the text is inert. Nothing else on the
page is reachable while it runs.

*Why*: FR-019's ownership rule is the read's rule; a second owner model would be a second set of bugs.

### D11 — The file has a life cycle: working copy → kept → gone (FR-021, FR-022)

A render produces a **working copy** in the app's own cache directory. The review plays that copy and
offers three independent decisions: keep it (which produces the library entry), throw it away (which
deletes the working copy), or share it. Keeping is the *only* thing that writes into the device's video
library, and it replaces any earlier kept video for that content (FR-012). A small persisted record — one
entry per content, keyed by the content's identity, holding the kept file's name and location — is what
makes a kept video reachable again for play, share or delete (FR-022); deleting removes both the file and
the record, and a record whose file has vanished is reported and forgotten rather than shown as playable.

*Why*: the reader asked to see the video before deciding (their item 2), and a file that appears in the
gallery the moment a render finishes cannot be "not saved". The working copy also makes the throw-away
path free: nothing ever entered the gallery to undo.

*Sharing before keeping* needs a URI the receiving app may read, so the working copy is exposed through
AndroidX's `FileProvider` — already on the classpath transitively (F10), no dependency line added. The
kept file needs none: a `MediaStore` URI is shareable as it is. **The reader offered to drop this if it
were hard; it is kept, because the cost is measured rather than assumed**: one `<provider>` entry in the
manifest, one `res/xml` paths file, and the `FLAG_GRANT_READ_URI_PERMISSION` on the intent — no
dependency, no permission prompt. If the implement stage finds `FileProvider` unavailable, the fallbacks in
order are `MediaStore`'s `IS_PENDING` flag on API 29+ (insert pending, share, then clear or delete) and,
last, keeping the video as part of sharing — which FR-023's wording would then
have to be amended to allow rather than quietly break.

### D12 — The video is watched on the platform's own player, hosted by the app

Playback (both at the review and later from the record) is an `AndroidView` over the framework's own
player, with the transport controls it already provides, driven by a small channel: open this file, play,
pause, position, stop. No new package is added (A7/A11 stand).

*Why*: the keep/throw-away/share decision has to sit on the same screen as the video (FR-021), and handing
the file to the device's player by an intent would move the decision out of the app. A platform view over
a framework player is the cheapest way to keep it in.

*Rejected*: a package such as `video_player` — a real new dependency for one screen's playback, and this
repository has shipped without adding one so far. *Rejected as the primary design*: the intent hand-off
(A11 names it as the alternative a reviewer may prefer; the FRs are written so swapping the player changes
nothing the reader can decide).

*Consequence to own*: the platform half gains a second, independent piece (a player view) whose iOS
counterpart is absent with the encoder's (D8), so on iOS the review's playback is missing too. That is
reported, not hidden: the capability reports itself unavailable there.

### D13 — The share surface is the phone's chooser, and its ceiling is honest (FR-023)

The app hands the file to the platform's share surface (`ACTION_SEND` with the file's URI) and stops there:
the platform lists the apps that accept a video, the reader picks one, that app receives the file and does
whatever it does with it. The app bundles no platform SDK, holds no appid and makes no network call.

*Why*: this is the reader's own description ("list the apps to share, select an app, then upload the video
in the selected app"), it is what the phone does for photos and videos everywhere else, and it keeps
FR-013's no-account/no-network rule intact.

*The ceiling, stated rather than discovered later*: the list contains only what the device registers. A
target like **WeChat Moments** is not exposed to the standard share surface — reaching it needs the WeChat
Open SDK, an appid and a third-party dependency, all of which the constitution's IV/A7 exclude here. So
"share to WeChat" works through WeChat's own share target, "share to Moments" does not, and the spec says
so in its Out of scope rather than letting the reader find out from a missing list entry (research F11
records the app's existing delete confirmation, which is the same "the app already does this" grounding).

## Spikes (must run before the plan's numbers are trusted)

- **S1 — does the emulator's engine write a usable audio file?** Call `synthesizeToFile` with a sentence
  of the shipped English pre-set on `emulator-5554` and inspect the result: does a file appear, is it
  RIFF/WAV, what sample rate and channel count, and does the length match the text? If the engine
  refuses or writes something unparsable, D3's "read the duration from the header" becomes "decode with
  `MediaExtractor`", and FR-003's feasibility needs a different answer (the fallback is the platform
  `TextToSpeech.synthesizeToFile` API called from Kotlin directly, which is what the plugin wraps).
  (F5 leaves this genuinely open.)
- **S2 — how fast is a real render on the reference device?** With D2/D3 in place, measure a one-minute
  reading end to end: total wall time, frames encoded per second, and whether PNG rasterisation in Dart
  or the encoder is the bottleneck. This number replaces SC-006's assumed ≤ 5 minutes and decides
  whether D2's fallback transport is needed.

## Carried forward from the spec (not re-decided here)

The spec's clarifications fix the start point (the highlighted sentence, else the first), the look (the
reader's typeface, size and voices), the format (a pre-render choice) and Stop's confirmation; A1–A10
remain the spec's. This file does not restate them.
