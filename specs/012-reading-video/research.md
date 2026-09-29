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
**only when the visual state changes** and carries a repeat count; the encoder emits that frame's bytes
`repeat` times so the file keeps a constant frame rate (FR-007/SC-002). A sentence that fits the frame is
one visual state and one unique frame; a sentence whose wrapped text is taller than the frame scrolls
(D14), and its scroll is quantised to the text's own line height — a step per line, not per pixel — so a
tall sentence is two to five unique frames instead of one paint per frame. A 60 s reading at 30 fps is
~1800 frames but only a few dozen unique ones, which is what makes this transport affordable.

*Why*: one text engine. Because the video's wrapping, typeface and character size come from the same
`TextPainter` the page uses, FR-002/FR-005 (the frame carries the spoken sentence and no other) and FR-014 (the
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
**Pass 2**: the timeline is built from those durations — each sentence's slot = its audio length, and
the end hold is a fixed slot (FR-008/FR-016; the opening card that used to be the other one was withdrawn on
2026-09-29 — D23) — and frames are emitted to match, with the
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
1080×1920. The frame size drives the layout: the text area's width, the margins and the scale that
maps the reader's chosen type size onto the frame's text area are derived from it (FR-014/A3) rather than
hardcoded for one aspect. The amended picture (D14) changes what is *in* that area — one sentence, wrapped
and scrolled a line at a time — not the rule that derives the area from the frame.

*Why*: A8, and because the two aspects need different text-area widths — a 16:9 frame wants a narrower
text area than a 9:16 one, and the smallest offered size must still be legible on both (A3's consequence).

**Amended 2026-09-28, by the reader's own request — the line is longer than the reader's own column.** Watching
renders, the reader asked for exactly this: *"make the text line to be longer, will has less lines."* So the
column may now be a **multiple** (`lineLengthGain`, 1.4) of the frame's height rather than at most its height,
and the **letters** are measured against their own, unchanged fraction (`lettersColumnFraction`, 0.88 — the rule
the text area itself had before) — which is what makes the extra width a longer *line* rather than bigger
letters: the line carries 1.4× the reader's own reading column of characters. The reader then settled the one
thing that has a price: shown that a portrait frame, whose column already uses 92% of its width, could only pay
for a longer line with smaller letters, they kept the letters — *"竖屏也保持原来的字大小"* (keep the original
character size on the portrait frame too). What the two frames get, then, from the app's own constants:

| frame | column, before → after | letters | a line, as a share of the letters' own column |
|---|---|---|---|
| 16:9 (1920×1080) | 1080 → **1512** px (`min(0.92 × 1920, 1.4 × 1080)`) | 3.000 — **unchanged** | 1.000 → **1.400** |
| 9:16 (1080×1920) | 950 → **994** px (`min(0.92 × 1080, 1.4 × 1920)`) | 2.640 — **unchanged** | 1.000 → **1.045** |

So the landscape — where the old rule was at its tightest, a column 56% of the frame's width — is where the line
grows; the portrait frame can only give the 4.5% of width it had left unused, and its sentences therefore wrap
much as they did. The video's lines are now **wider than the app's own reading column**, which is what D6's
original sentence about the eye was protecting: that sentence is the reader's own to overrule, and they did.

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
  painter's per-slot sentence, its wrap and scroll, progress and cancellation, the RENDERING state's
  controls and the Stop
  confirmation, the aspect store — all against a fake engine (F3) and a fake encoder, with no device.
- **Device, on `emulator-5554`**: a new walker script drives a render and then the host asserts on the
  file with `ffprobe` (F6): stream count, codec, the exact frame size per aspect (SC-012), the constant
  frame rate, the duration against the audio sum (SC-002), a frame extracted at each slot boundary
  showing that sentence's own text as the frame's text (SC-003), no chrome in any sampled frame
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

### D14 — The frame is one sentence, and a tall sentence scrolls a line at a time

The picture is the sentence being spoken, alone, in the reader's own typeface and size, over the scheduled
picture. The painter no longer draws the reading page: no highlight band and no page window, because with
one sentence in the frame there is nothing to highlight and nothing to scroll to (2026-09-26, FR-002).
A sentence whose wrapped text is taller than the frame's text area (FR-029) is drawn **whole** and scrolled
upward inside its own frame; the position is the elapsed fraction of the slot applied to the block's own
height, **quantised to the text's line height**, so the block moves a line at a time. *Why the
quantisation*: a pixel-smooth scroll would need a paint per frame on a 1920×1080 canvas — exactly the cost
S2 measures and the one thing that could push this transport over. *The estimate*: the position is
proportional to the slot, not read from the voice, because the engine speaks a sentence as one utterance
and exposes no word timings; the reader chose scrolling over splitting knowing that (FR-029, 2026-09-26).
*Rejected*: splitting the sentence across frames (the first cut, withdrawn by the reader); shrinking the
text to fit ("no smaller char"); a horizontal slide (never what the page does, and the sentence is never
all on screen at once).

### D15 — The pictures are the reader's own, chosen before the render and copied into its working directory

The picker is the platform's own **file** dialog, through flutter.dev's `file_selector` — the reader's own
decision on 2026-09-27, and their reason: the pictures are *files*, made on the phone, on a PC or by an AI
tool, so the dialog that browses files is the one that finds them, and it is the one selection UI with folders
that every target the app builds for has (Android, iOS, Linux, macOS, web, Windows). No in-app gallery, no new
permission, and no platform half of ours — the plugin *is* the platform half (S3 checks what it hands back on
the reference device). What it hands back is each platform's own idea of a chosen file — a content uri on
Android, a blob on web, a path on desktop — which is why the next sentence carries the design: chosen pictures
are copied once into the render's working directory before pass 2 starts, so the render reads them at its own
pace instead of depending on a file handle whose read grant may end with the activity that produced it, and the
copies are deleted with the working copy under D11's rules. The schedule is a list of (picture, inclusive start frame, inclusive end frame) in the video's own
frame numbers, equal shares **of the sentences** in the order chosen for the first cut (FR-026) — a picture's
run begins at a sentence's own first frame and ends immediately before the next picture's first sentence,
never inside a sentence. That is the reader's own rule, set 2026-09-27: the sentence is the unit on screen, and
the picture behind it changes with the sentence. It costs nothing in coverage, because a sentence's run
already carries the gap that follows it and the video's last sentence carries the end hold (D14, FR-008) — so
the pictures cover the whole spoken part with no plain flash between them, and — since the card was withdrawn
(2026-09-29, D23) — from the video's own first frame: the first picture starts at frame 0. Moving a start or end frame is the reader's later
good-to-have and it re-renders rather than editing the file — expressed as *which sentence* a picture starts
at, since frames would let the move land inside a sentence. No pictures is a valid schedule: the plain
background (FR-028).

**Multi-select, and no cap (2026-09-28).** The dialog may hand back several pictures at once, and a second
pick **adds** to the first rather than replacing it. The choice is **not capped**: the cap of 20 this
paragraph first carried (and, before it, the trim to the first 20) is withdrawn — the reader's own words of
2026-09-28, "remove max 20 images limit. keep all 30 images for now. user can delete images." What bounds a
render is the video, not a count (D18). One consequence worth knowing: the
multi-select is the plugin's own Android half (`EXTRA_ALLOW_MULTIPLE` on its `openFiles` intent —
`file_selector_android-0.5.2+11/…/FileSelectorApiImpl.java:148`, read back from `ClipData` at `:176`), so no
platform code of ours is added for it — and that the rule that matters lives with the pictures' module, where
its rows can drive it, rather than in the dialog. Before this each pick replaced the last, which is what the
reader reported from the phone ("only can select one image and re-select image").

*Rejected*: an in-app gallery (a screen to build for a phone that
already has one); keeping the picked file live through the render (that turns "the reader moved a photo" into
a failed render); the OS **photo** picker (2026-09-27 — it selects pictures, not files: on the reference
emulator its Albums view listed only Favorites/Camera/Videos and never the reader's own folders, and it exists
on Android and iOS only while the app builds for desktop and web too).

### D16 — The plate behind each painted line (the veil is withdrawn), and its tone decides the ink

**Decision (2026-09-28, the reader's own).** Between the picture and the text sits one **white plate behind
each painted line** — the line's own box, drawn from the picture up to the text (FR-027). There is no
full-frame layer: outside those lines the picture's own colours are untouched. The plate is white (`#FFFFFF`),
not the app's reading background (`#F4FBF8`), because white is the strongest floor the reader's own text colour
can sit on: `#161D1C` against white measures **17.1:1**. The plate is drawn only where a picture is behind the
text; with no pictures the frame is the plain background and the text sits on it exactly as before (FR-028).

**The tone rule (2026-09-28, the reader's own).** The plate is **the opposite of the picture's own tone**: a
light picture gets black text on white, a dark one white text on black — the reader's own words, *"black text
on white background if background image has light color. white text on black background if background image has
dark color"*. Light and dark are read from the picture itself: its average perceptual luminance (`0.299R +
0.587G + 0.114B`), at a floor of half, sampled on a stride (about 20 000 samples whatever the picture's size)
and **measured once per picture and kept**, since the renderer decodes a picture once and paints it across many
frames. Two consequences worth knowing: the pair is **21:1** by construction either way, so SC-004's floor no
longer depends on any picture's colours; and the plate sits *with* the picture instead of over it — a light
photo keeps its light and a dark one its dark, and the words read either way. The reader's own text colour
still governs the plain-background video (FR-028), where there is no picture to read a tone from — the one
place the app's single text colour is still what the reader sees.

**Rationale.** The scrim's purpose was always legibility over arbitrary pictures, and it bought that by veiling
the picture the reader had chosen to look at. The plate buys the same legibility *and* leaves the picture alone:
the contrast becomes a constant instead of a mixture with a photo (no picture can make the plate fail, where S4
had to measure four pictures at both aspects to show the veil held), and SC-004's 4.5:1 floor is met with 17.1:1
of headroom.

**What is withdrawn.** The 55 % full-frame layer of the frame's own background colour that S4 measured on
2026-09-27 — on the reader's own judgement after watching a render on the phone: *"like to have white background
to the sentence characters. Don't do any change to the background images's color."* S4's measured table stays in
breakpoint row 42 as the record of the design it replaced, and the stills harness stays beside S1's probe.

*Alternatives considered*: one plate over the whole text area (it hides the middle of the picture — offered and
not chosen); a light veil to soften the plate's edge against the photo (a second layer, and it re-opens the depth
question S4 answered — not chosen); a dark plate with light text (needs a second text colour, which this app does
not have: it paints one, `#161D1C`); a plate the width of the text area rather than of each line (rejected with
the first alternative — the reader's pick was "each wrapped line's own box").

**The tone is read over the band the words cover (2026-09-28, second amendment).** The reviewer's own point
about D16's first cut: "底板会与背后区域撞色——改为只统计文字所在条带" — a picture's *average* is not what is
behind the words, so a dark photograph whose sentence sits under a bright sky was plated in black against a
bright strip. The tone is therefore read over **the band each painted line covers**, mapped back from the
line's own box onto the picture's pixels (`toneOfPixels` over the bands, the picture's pixels converted once
and reused), and the plate and the ink follow that band. The cost is named rather than hidden: inside one
sentence whose band crosses the light/dark floor, the plate can change between line steps — the band actually
behind the words is what decides, and a step's frames carry that step's own band. Bands are read with a shared
sample budget, so the measurement stays bounded however long the sentence is.

### D17 — The chosen pictures are shown, and each can be taken back

**Decision (2026-09-28, the reader's own):** "now we have add more images. let's have thumbnail review and
image remove function." The prompt shows **one thumbnail per chosen picture**, in the order chosen, each
carrying its own **remove** (FR-030). Taking one back is part of the choice, not a cancel: the rest of the
choice stands, the count follows, and the render is still the reader's own confirm.

**Rationale.** Choosing several pictures at once made the count useless on its own: twelve `sunset.png`s and
twelve of somebody else's screenshots read the same as a line of text. A thumbnail is the picture the reader
chose, so "which ones did I pick" is answered by looking rather than by remembering — and the remove is what
makes a wrong pick cost one tap instead of a restart.

**What it costs, and the shape it took.** The bytes have to be in hand when the prompt draws, so a pick is
read **once, at the pick** (D15's own rule: the read grant is alive then and may not be later) and handed on
as `HeldPicture` — name + bytes — to the page and then to the render, which writes exactly what the reader
saw. The thumbnail decode is bounded (`cacheWidth`), since a phone photo is many megapixels and this is a
72-pixel square; and a file that turns out not to be decodable shows as a broken-picture tile rather than
throwing the reader out of the prompt.

*Alternatives considered*: the names as a list (cheap, and it answers nothing the reader asked about — which
picture is which); a full-screen review with swipe-to-remove (a screen to build and a gesture to teach for
what one tap on a cross does). A reorder was **not** part of this decision and is now its own: the reader
asked for it on 2026-09-28 and it is D19 (FR-032).

### D18 — The picks are stored on disk at the pick, and the video's own sentences are the only bound

**Decision (2026-09-28, the reader's own):** "1. (2) 选图当下落盘到应用私有目录、页面与渲染从文件读 2. 图多于句子
时：show error message! force user to remove images." Two connected decisions, taken together because the second
is only sayable once the first is true:

1. **Every pick is stored as it is chosen.** The picker's read grant is alive at the pick and may not be later
   (D15's own rule), so the read is spent then — but what it produces is written into a file inside a directory
   of the app's own (the app's private cache), one directory per video prompt, one file per picture, named for
   the picture with any directory part stripped. `HeldPicture` carries **name + path**, never bytes. The page's
   thumbnails (`Image.file`, still bounded by `cacheWidth`) and the render's copies both come from those files.
2. **The choice is not capped.** The reader's own words: "remove max 20 images limit. keep all 30 images for
   now. user can delete images." Every picture chosen is kept, in the order chosen; the only way one leaves is
   FR-030's remove.
3. ~~**The video's own sentences are the bound.**~~ **Withdrawn the same day (2026-09-28), by the reader's own
   phone test**: "超限提示、no need. not show." The prompt resolves nothing and says nothing; a choice larger than
   the video's sentences is started as it stands, and the pictures past the last sentence are simply not drawn —
   which is what the schedule already did with a picture that found no sentence (FR-026, SC-022). The
   `videoSentencesFrom` call the prompt made for the count goes with it, and the prompt is back to opening on the
   remembered aspect and nothing else.

**What the reader's own phone settled (2026-09-28).** Two of the three parts above came back confirmed and one
came back wrong. Confirmed: the picker, the stored files, the thumbnails, the small scrolling window (part 1 and
FR-030). Wrong: part 3 — the count with a message and a blocked Start. The reader's words: "超限提示、no need. not
show." The lesson worth keeping is in *why* it was wrong: the bound was a rule about the **video's** capacity,
enforced as an error the **reader** had to fix; watching a real render showed that a picture with no sentence is
not a problem anyone has to fix, it is a picture that does not appear — the schedule's own long-standing answer.
The same phone test asked for two things that are now D19's and D21's: the reorder's reach (the window scrolls
while a hold is at its end) and the button's wording ("Choose more").

**Rationale.** (1) Thirty phone photographs held as bytes is a few hundred megabytes in a low-end phone's
heap, and the window (FR-030) only fixed what is *shown*, not what is *held* — while the file dialog's grant
makes the bytes-at-the-pick read the one moment the data is certainly reachable. Storing the read means the
page and the render read a file the app owns, and the lifetime is one directory the page can delete.
(2)+(3) A cap is a number the app invented; the video's sentences are a number the video actually has. A choice
larger than the video's sentences is not a pick to refuse — every picture in it is one the reader chose, and the
ones over the count are pictures the video has nowhere to draw (FR-026) — so the reader is told the two numbers
and fixes it themselves.

**What it costs, and the shape it took.** A directory per prompt, created before the dialog opens and removed
in a `finally` around the whole prompt-and-render: finished, stopped, failed, or cancelled, the stored picks go
(FR-025, SC-024). `storePicks` deletes what it wrote if a read fails part-way, so a choice is never half-stored;
`discardPictures` treats an absent directory as already done. The prompt's own content scrolls
(`AlertDialog.scrollable`), because the message it can now carry is several lines tall and on a short screen the
Choose/Start buttons were pushed out of the dialog's own tap area — found by a test whose tap missed, not by eye.

*Alternatives considered*: holding bytes and hoping (the risk the reader's own report was about); storing picks
in the render's working directory (it does not exist yet when the reader is choosing); keeping the picks between
prompts so a second render reuses them (FR-025 forbids it: the picks belong to the prompt that chose them); capping
by a number again (the number the reader just withdrew); trimming a too-large choice to the first N sentences'
worth (drops pictures silently, which is the one thing every amendment here has refused).

### D19 — The order the reader sets is the order the video draws

**Decision (2026-09-28, the reader's own request):** the review step may not only remove a picture but **move**
it: hold a picture's own cell and drop it on another picture's cell, and the choice is reordered so that the
picture lands where it was dropped and the others keep their own places (FR-032). The cells' order **is** the
order the video draws the pictures in (FR-026), so this is a different video rather than a different view of
one, and a drop on the picture's own cell changes nothing (`movePicture` hands the choice back as it was).

**Rationale.** The pictures share the sentences in the order chosen, so "the third picture is behind the
sentence I wanted the sunset for" was a reason to start over: remove, re-pick, and hope the dialog hands the
files back in the order the reader wants. A move is the direct fix, and it costs one gesture on a cell the
reader is already looking at.

**The reader's own phone test (2026-09-28).** The hold worked — and stopped at the window's own edge: "only can
move in displayed rows. need to able to move out of the disabled rows. use auto scroll." So the window follows
the hold (D21), and the button that adds pictures was renamed in the same breath: `"Choose again" to "Choose
more"` — the reader's own words, and the copy in all four languages changed with it (FR-031).

**What it costs, and the shape it took.** `MovableThumbnail` is a `DragTarget` around a `LongPressDraggable`
carrying the cell's index; the feedback is the picture alone (a remove is not what is being moved) and the cell
being dragged stays in place, dimmed. The hold must start **anywhere on the cell**, and that is where the real
defect was: an `Image` answers no pointer by itself, and the corner remove was an `IconButton` whose padded tap
target is 48×48 — two thirds of a 72-pixel cell — so the hold landed on the remove instead. The cell therefore
draws a transparent `ColoredBox` as its own hit surface, and the remove's `tapTargetSize` is
`MaterialTapTargetSize.shrinkWrap`, so it is the size it looks (22×22) and the rest of the cell is the reader's.
**The cost is named**: the remove's own touch target is now the cross itself rather than 48 pixels, which is the
trade that makes the whole cell draggable.

*Alternatives considered*: a long-press menu on a picture ("move left / move right" — two taps per move and a
menu to teach); arrows on each cell (a second control per cell in a window two rows tall); a separate reorder
screen (a screen to build for a gesture that fits on the cell); living with remove-and-re-pick (a lost choice
and a dialog to re-walk for a mis-ordered picture).

### D20 — The picture is a `TextureView`, because a `SurfaceView` inside a Flutter platform view never reaches the screen

**The defect (reported from the phone 2026-09-28, fixed the same day).** The reader: "video player is not working in
phone. only show a black view. click play button, not playing." The review's picture was black with the sound
playing, while the same file played from the device's Files app — so the file and the keep path were sound.

**What it was.** The view was a `VideoView`, which is a `SurfaceView` inside. Flutter composites an `AndroidView`
through its own layer; a `SurfaceView` sends its picture to a *separate* surface that the compositor has to punch
into the window, and inside a platform view that hole is where the picture does not arrive. D12's own choice —
"the platform's own player, hosted by the app", with the platform's transport controls so no scrubber of ours —
is right; the *container* was wrong.

**The measurement (both views, one screen, one file, `emulator-5554`).** A scratch probe mounted both ways side by
side over the same local `testsrc` clip and one screenshot was read pixel by pixel (`breakpoint.md` row 54):

| the view | pixels below luma 30 | max saturation | distinct colours | mean luma |
|---|---|---|---|---|
| `VideoView` (what shipped) | **0.98** | **0** | **2** | 0.8 |
| `TextureView` + `MediaPlayer` (candidate) | 0.10 | 255 | 273 | 123.6 |

So the defect reproduces on the emulator, with the file the candidate draws: the shipped view's whole picture area
is black, and a `TextureView` — composited like any other view — draws it.

**On the reader's own phone (2026-09-28).** The fixed APK was installed on the LE2115 — the device the black
picture was reported from — and the reader's own report is: "play button works on my LE2115 phone." So the fix holds where the
defect was found, not only where it was measured.

**Decision.** The shipping view is a `TextureView` whose `Surface` is handed to a `MediaPlayer`, prepared **after**
the surface exists (a player prepared before its surface is the classic half-black picture), with the platform's
own `MediaController` still driving play/pause/seek through `MediaController.MediaPlayerControl` — so D12's
"no scrubber of ours" holds and no dependency is added. Two things a `VideoView` did for itself that the view now
does: the video's own shape inside whatever box the page gives it (a `fitPicture` transform on the texture, so the
picture is letterboxed rather than stretched), and the transport bar appearing on a tap of the picture.

*Alternatives considered*: `androidx.media3` (`ExoPlayer` + `PlayerView`, whose own `surface_type="texture_view"`
exists for exactly this) — the modern, supported route, and the one to take the day `MediaController`'s
deprecation bites; it costs a dependency and a bigger rewrite for a view that has no other problem. Handing the
file to the device's player app (`ACTION_VIEW`) — considered and **declined by the reader on 2026-09-28**: it would
delete this view and its whole defect class, but it moves the watch out of the app, and FR-021's review is one
screen where the reader decides. A Dart-drawn control bar over a `TextureView` — puts the scrubber in our code,
which D12 exists to avoid.

### D21 — A hold at the window's end scrolls the window

**Decision (2026-09-28, the reader's own):** "only can move in displayed rows. need to able to move out of the
disabled rows. use auto scroll." While a picture is held and the finger is within a band of either end of the
picture window, the window scrolls a step at a time, and keeps scrolling while the finger stays there, so a
picture can be dropped on a cell that was not on screen when the hold began. Leaving the band — or ending the
hold — stops it.

**Rationale.** The window is two rows tall by FR-030's own shape, and the choice can be thirty pictures: without
this, the reorder could only shuffle what happened to be in sight, which on a real phone is exactly what the
reader found. Auto-scroll is also the gesture every list in every phone already teaches, so nothing new has to
be learned.

**Confirmed on the reader's own phone (2026-09-28)**, after the first fix — and in both directions, which the
repo's own rows did not yet cover: "拖拽自动滚动 fixed up and down" (a row for the upward half was added with it).

**What it costs, and the shape it took.** The page owns the window's `ScrollController` and a `GlobalKey` on the
window (so it can be measured against the finger's own position), and a `Timer.periodic` that repeats a fixed
24-pixel step every 80 ms while the finger sits in a 36-pixel band at either end — with the first step taken
immediately, so a hold at the end moves the window rather than seeming stuck. A step per *pointer move* would
have been simpler and worse: holding still at the end is precisely how a reader asks for more. The step is in
pixels rather than in cells on purpose — it is the window that moves, and the cell under the finger is whatever
is there when the reader lets go, which is the drop the `DragTarget` already handles. Nothing scrolls when the
hold ends or leaves the band, and the controller is disposed with the page.

*Alternatives considered*: a per-pointer-move step (stops the moment the reader stops moving, which is the
opposite of what a held finger means); paging the window a whole row at a time (jumpy, and it would drop cells
out from under the finger); a drag handle that raises the window out of the way (a control to teach for a
gesture that already means "move this"); no auto-scroll, with the reader reordering in several passes (the
reader's own answer: they asked for auto scroll).

### D22 — A sentence that fits sits at the bottom of the frame

**Decision (2026-09-28, the reader's own):** "move text block from top to bottom." A sentence whose block fits
the text area is placed so its **last line's box ends where the text area ends** — the bottom of the frame — so
everything above the words is the picture (or the background). A sentence **taller** than the text area keeps
FR-029's own shape unchanged: its first line starts at the top of the text area and the slot scrolls down through
the block a line at a time, which is what that requirement says in so many words ("from its first line at the top
of the text area to its last line at the bottom"). The end hold repeats the last sentence's placement — it is
that sentence's frame, held, not a frame of its own — and since 2026-09-29 nothing in the video is centred:
the card that was is gone (D23).

**Rationale.** The frame is watched on a phone, at a picture the reader chose: with the words at the bottom, the
picture owns the frame's middle and top, which is where a photograph's subject usually is, and the eye has one
place to look for the words rather than a place that moves with the sentence's length. It is also what the
reader's own reading view does not do — there the column fills the page — so it is a video-only look, deliberately.

**What it costs, and the shape it took.** One branch in the painter (`geometry.steps == 0` decides it, the
block's own answer rather than the progress, because a too-tall block's *first* frame is not a block that fits).
The cost is a visible jump between a sentence that fits and one that does not: the fitting one sits at the bottom,
the too-tall one starts at the top and travels down. The alternative — bottom-anchoring the too-tall case too —
would put a long sentence's *first* lines off the bottom of the frame, which FR-029 forbids; the other
alternative — centring both — is what D22 replaces.

*Alternatives considered*: the block vertically centred (a taller text area's worth of empty frame above and below
the words); the block at the top, as it was (the reader's own answer: no); the anchor following the *picture's*
subject (unknowable for a photograph, and it would make the words move from sentence to sentence).

### D23 — The video opens on its first sentence: the opening title card is withdrawn

**Decision (2026-09-29, the reader's own, from watching the two renders of 2026-09-28):** *"I want to remove the
first title frame. and don't show the title in the top of 16:9 video."* The opening card — the content's name,
over its language, held before the reading — is **deleted, not hidden**: the first frame of the video is the
first sentence's own, and no frame of either aspect carries the content's name or its language.

**What it costs.** SC-002's duration loses the card's 2.5 s (a pre-set render is now the sentences' audio plus
the 2 s hold instead of ~27.4 s), and FR-016's lead-in bound is vacuous rather than binding. The withdrawn
surface is real code and not a flag: `VideoSlotKind.title`, the plan's `title` field and `titleMs`, the
painter's card branch (its centred placement, `titleLabelScale`, and the language-label seam the page fed with
`languageLabelOf`), the renderer's `title`/`languageLabel` parameters, and the slot-index shift that follows
from it everywhere (`slot i` is now `sentence i`, not `sentence i-1`). The device row that read the card loses
three checks and gains three that say the same thing from the other side: **the video opens on sentence 0 at
frame 0**, **no run of the file is a card**, and **the file holds exactly one slot per sentence** — the name is
painted nowhere.

**Why "the top" is not a place in the file.** The card was centred in the text area (measured: ink box
`(206, 506, 670, 582)` in a 1920×1080 frame), never at the top. What reads as "the title at the top" is the
**review screen**: the video preview sits at the top of that page, so the card's own frames were the first thing
the reader saw there, above the three decisions. This reading — no title anywhere, file or screen — is what the
change took; if the reader meant *move* the card rather than remove it, the revert is exactly the list above and
nothing else moved with it.

**Alternatives considered**: keeping the card and moving it (bottom, or down out of the preview's first
impression); keeping the name as a caption on the review screen rather than in the file; a fade from the card
into the first sentence (per-frame alpha in the painter — a cost the reader did not ask for).

- **S1 — does the emulator's engine write a usable audio file?** Call `synthesizeToFile` with a sentence
  of the shipped English pre-set on `emulator-5554` and inspect the result: does a file appear, is it
  RIFF/WAV, what sample rate and channel count, and does the length match the text? If the engine
  refuses or writes something unparsable, D3's "read the duration from the header" becomes "decode with
  `MediaExtractor`", and FR-003's feasibility needs a different answer (the fallback is the platform
  `TextToSpeech.synthesizeToFile` API called from Kotlin directly, which is what the plugin wraps).
  (F5 leaves this genuinely open.)
- **S2 — how fast is a real render on the reference device?** With D2/D3 in place, measure a one-minute
  reading end to end (including at least one long sentence that scrolls, D14): total wall time, frames
  encoded per second, and whether PNG rasterisation in Dart or the encoder is the bottleneck. This number
  replaces SC-006's assumed ≤ 5 minutes and decides whether D2's fallback transport is needed.
- **S3 — what does the file dialog give back, and what does converting it cost (D15)? — PARTLY ANSWERED
  2026-09-27.** The dialog itself: on `emulator-5554` it is DocumentsUI, whose folder tree exists and lists
  the reader's own folders (breakpoint row 41), and it needs no permission. Still unproven, and it is what
  T045's shape rests on: what `file_selector` returns on Android for a picked picture, whether its bytes can
  be read once right after choosing (the render copies them immediately — D15) and how long copying a handful
  of full-resolution files takes. Run through the app, with the page wired (T047).
- **S4 — which scrim holds SC-004's contrast (D16)? — ANSWERED 2026-09-27.** The stills harness
  (`specs/012-reading-video/scripts/probe_scrim_stills.dart`) composited the reader's own four pictures under
  each candidate layer with the app's real geometry and text style, at both aspects, and measured the WCAG ratio
  at the glyph pixels themselves: the dark layer fails (42–100 % of glyph pixels under 4.5:1), the light layer at
  55 % passes everywhere by construction (min 4.90:1). D16 carries the numbers; the device half — sampling a
  finished render's frames — is row 49's.

## Carried forward from the spec (not re-decided here)

The spec's clarifications fix the start point (the highlighted sentence, else the first), the look (the
reader's typeface, size and voices), the format (a pre-render choice) and Stop's confirmation; A1–A10
remain the spec's. This file does not restate them.
