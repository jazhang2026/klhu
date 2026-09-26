# Device validation: Reading Video (012)

**Feature**: `012-reading-video` | **Date**: 2026-09-25 (in progress)
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Tasks**: [tasks.md](./tasks.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400), package `com.example.klhu` |
| Build | `flutter analyze` clean; `flutter test --concurrency=2` → **372 passing, 0 failing** (2026-09-26, emulator up; 301 at T002's baseline on `54ff4f3 "specs/011"`, 360 after US1) |
| Driver | `specs/012-reading-video/scripts/klhu_walk_video.py` — rows 31, 32 and 34 walked below; rows 33/35/36 are T030–T032's |
| Spike S1 | `specs/012-reading-video/scripts/probe_synthesize.dart` — run on the device, read back with `adb shell run-as com.example.klhu cat /data/data/com.example.klhu/cache/s1_report.txt`, audio pulled with `adb exec-out run-as … cat …/s1_<case>.wav` and analysed with the host's `/usr/bin/ffprobe` |
| Engine | Google TTS (`com.google.android.tts`), 472 voices installed; `logcat` tag `GoogleTTSServiceImpl` says which voice actually spoke |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **[unit]** (the Dart test that
carries it), **[structural]**, **PENDING** (not yet runnable), or **UNVERIFIED WITH REASON**.

**State of this file**: US1 is implemented and its two device rows are closed — **31** (a real render at both
aspects, asserted with `ffprobe`), **32** (the video's own look, frame by frame) and **34** (a confirmed Stop
at about half way). Row **32** found and closed a real US1 bug — the encoder wrote the title card's picture
for the whole video (below). Row **33** (the file's life cycle) is **PENDING** because it is US3's work, and
row **36** (spike S2) is **PENDING** even though a render now exists to time — its by-product is noted under
row 31 and T032 owns the measurement. Rows **35** (S1) and **30** (the page's shipped behaviour, run as the
existing suite) are closed below and in the suite's own receipt.

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 31 | A real render produces a real video (landscape, then vertical, `ffprobe`) | **WALKED — PASS** | **31/31** checks, both files pulled and probed (below) |
| 32 | The video's own look, frame by frame: the band per slot, the column, no chrome (both aspects) | **WALKED — PASS** | **30/30** checks; 818/818 frames each aspect, 27/27 at full size (below) |
| 34 | A confirmed Stop at about half way cleans up and leaves the library alone | **WALKED — PASS** | **25/25** checks (below) |
| 35 | Spike S1: does the engine write a usable audio file, and does it carry its own length? | **WALKED — PASS** | Three cases, one engine, one run (below) |
| 36 | Spike S2: a one-minute render's wall time, which replaces SC-006's placeholder | **PENDING** | a render exists (row 31: 21 s for 27.27 s of video); T032 owns the measurement |
| 33, 37–40 | US3's life cycle | **PENDING** | that story is not implemented |
| 1–29 | The feature's `[unit]` rows | **[unit]** | `flutter test --concurrency=2` → **372 passing, 0 failing** (60 of them 012's own, 20 in `video_painter_test.dart`) |

### Row 31 — a real render produces a real video, in full

The render was run twice from `pm clear`'d state, choosing landscape and then vertical, and both files were
pulled off the device and read by the host's `ffprobe`. **31/31 checks passed.** The two interesting numbers
are the frame count (the file holds exactly the frames the plan asked for — 818 — for both aspects) and the
duration (ffprobe 27.39 s against the render's own 27.27 s, a 0.13 s difference against row 31's 2 s bound).

    $ python3 specs/012-reading-video/scripts/klhu_walk_video.py 31
    PASS  31: the page is idle with content and the video action
    PASS  31/landscape: the aspect prompt opened
    PASS  31/landscape: the render reported done — 21s wall
    PASS  31/landscape: the page showed progress while it ran
    PASS  31/landscape: the page reported the file's name and length — 'Video made: klhu_video.mp4 (27 s)'
    PASS  31/landscape: the reported length is the render's own — page said 27 s, render said 27266 ms
    PASS  31/landscape: the file came off the device and is not empty — 1236914B on the host, app said 1236914B
    PASS  31/landscape: exactly one video stream — ['h264']
    PASS  31/landscape: exactly one audio stream — ['aac']
    PASS  31/landscape: the frames are exactly 1920x1080 — 1920x1080
    PASS  31/landscape: the frame rate is constant — r=30/1 avg=30/1
    PASS  31/landscape: the file holds the frames the plan asked for — file 818 vs render 818
    PASS  31/landscape: frames / duration is that rate — 29.86 vs 30.00
    PASS  31/landscape: the duration is the render's own, within 2 s — ffprobe 27.39s vs render 27.27s
    PASS  31/vertical: the frames are exactly 1080x1920 — 1080x1920
    (the vertical pass repeats every landscape check at 1080x1920, same 818 frames, same duration)
    31/31 checks passed

`ffprobe` on the two pulled artifacts — the whole of row 31's "one H.264 stream at exactly WxH, one AAC
stream, a constant frame rate, and a duration equal to the sum of the sentences' audio plus the title card
and the hold, within 2 s":

    $ ffprobe -v error -print_format json -count_frames -show_entries stream=codec_type,codec_name,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,channels,sample_rate:format=duration,size landscape.mp4
        video: h264 1920x1080, r_frame_rate 30/1, avg_frame_rate 30/1, nb_read_frames 818
        audio: aac 24000 Hz, 1 channel, 642 frames  (= 27.4 s of sound)
        format: duration 27.393833, size 1236914
    $ ffprobe … vertical.mp4
        video: h264 1080x1920, r_frame_rate 30/1, avg_frame_rate 30/1, nb_read_frames 818
        audio: aac 24000 Hz, 1 channel, 642 frames
        format: duration 27.393833, size 1036800

Three things this row settles beyond the wording:

1. **The audio is padded to the frames, and it shows.** 642 AAC frames at 1024 samples / 24 kHz is 27.4 s of
   sound for 818 video frames at 30 fps (27.27 s): the two ends are within 0.13 s of each other, which is the
   padding in `encodeAudio` doing its job. A slot model that let the voices' own lengths drive the file would
   have drifted by however long the last sentence ran past its slot.
2. **Frame count equality is a stronger assertion than it looks.** `nb_read_frames` is ffprobe *decoding* the
   video: 818 is the plan's number, and the encoder's own `totalFrames` check refuses the render if the frames
   sent ever disagree with it. The two agreeing means nothing was dropped, coalesced or duplicated between
   Dart's painter and the muxer.
3. **By-product for spike S2 (row 36, T032, still PENDING):** a render of 8 sentences / 818 frames / 27.27 s of
   video took **21 s wall** on this emulator, both aspects — faster than real time. T032 owns the official
   number and the bottleneck attribution; this is a note, not its receipt.

### Row 32 — the video's own look, frame by frame, in full

The look cannot be asserted structurally: `ffprobe` knew the frame size, the rate and the count, and nothing
about what the pictures *contain*. So this row reads them — every frame of both files scaled to 96×54 so that
all of them can be looked at, and three frames of every slot (its start, its middle, its end) at the file's
own size for the colours and the column's edges. **30/30 checks passed.**

- **Every frame, both aspects — 818/818.** The app's background to the edges, nothing outside the column (so
  no chrome anywhere in any frame), and the app's own yellow band on exactly the sentences' frames and never
  on the title card.
- **Three frames per slot, at 1920×1080 and 1080×1920 — 27/27 clean in each aspect**, with the band the
  renderer reported (`band=1032x109` and the like) inside the column plus a line's trailing space.
- **The page and the renderer, on the same picture.** The page prints the frame it is showing, the renderer
  prints the frame it is writing, and they were sampled 4 times per aspect: the page's picture was always one
  the renderer had written, for the same slot, never ahead of it, and naming the sentence that slot stands
  for (`[2, 4, 5, 7]` landscape, `[2, 4, 6, 7]` vertical — FR-020 on the device).

**The bug this row found.** The first run's pixel pass failed: **no frame of any file held the highlight** —
0 of 818, both aspects, and row 31's older artifacts were the same. Every structural check had passed. The
chain that found it, in order:

1. the renderer's own per-run line said it *had* drawn a band (`band=1032x109` on a sentence's frame), and a
   screenshot of the page mid-render showed yellow in the app's own preview — so the painter was right;
2. the file's frames were the *same picture* 818 times over (identical colour histograms at frames 152, 160
   and 190), and the file was 1 133 960 B where ten distinct pictures cannot fit;
3. `android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt` kept
   `private var picture: Yuv?` — converted **once** per render and reused for every later `sendFrame`
   (`picture ?: rgbToYuv(bitmap).also { picture = it }`, reset only when a render ended). The first picture
   of a render is the title card, which has no band: hence a whole video of title cards. The frame contract
   in `contracts/video-frame-protocol.md` is explicit — the platform half "must not reorder, coalesce or
   drop frames" — and the local `val` already covers a call's own repeats, so the field was redundant as
   well as wrong.

**The fix and its receipt.** The cache is gone (`val yuv = rgbToYuv(bitmap)`); the same walk then passed
**30/30**, the landscape file grew from 1 133 960 B to **2 270 646 B** (ten pictures, not one), and 818/818
frames hold the band.

Row 31 cannot see this class of bug and does not claim to — that division is exactly why both rows exist. Nor
could the unit tests: the Kotlin half has no Dart test, so the device *is* its test, and the row that reads
pixels is the one that caught it. (The walker had a bug of its own, found by the same run: it derived the
column from the thumbnail's dimensions, which are not the frame's aspect, and so called a 9:16 frame's own ink
"outside the column". The column is now scaled from the file's own size.)

    $ python3 specs/012-reading-video/scripts/klhu_walk_video.py 32
    PASS  32/landscape: the aspect prompt opened
    PASS  32/landscape: the render reported done — 21s wall
    PASS  32/landscape: the page showed progress while it ran
    PASS  32/landscape: the page reported the file's name and length — 'Video made: klhu_video.mp4 (27 s)'
    PASS  32/landscape: the reported length is the render's own — page said 27 s, render said 27266 ms
    PASS  32/landscape: the file came off the device and is not empty — 2270646B
    PASS  32/landscape: the renderer reported the pictures it wrote — 9 runs, file has 818 frames
    PASS  32/landscape: the renderer's own band, on every sentence's frame — card none, sentences
         ['627x49', '1032x109', '835x49', '1007x109', '927x109', '505x49', '957x109', '1090x109']
    PASS  32/landscape: the runs tile the file frame for frame — last run ends at 818, file has 818
    PASS  32/landscape: the first picture is the card, the rest are sentences
    PASS  32/landscape: the page showed a picture the renderer had written — 4/4 pairings
    PASS  32/landscape: what the page showed moved forward with the render — [2, 4, 5, 7]
    PASS  32/landscape: every frame was read back — 818 frames read, render said 818
    PASS  32/landscape: every frame is the app's own look, and no chrome — 818/818 frames; first bad: []
    PASS  32/landscape: every sampled frame holds the app's own look — 27/27 frames clean
    PASS  32/vertical: the renderer's own band … — card none, sentences
         ['552x43', '909x96', '736x43', '888x96', '817x96', '445x43', '843x96', '807x96']
    PASS  32/vertical: what the page showed moved forward with the render — [2, 4, 6, 7]
    PASS  32/vertical: every frame is the app's own look, and no chrome — 818/818 frames; first bad: []
    PASS  32/vertical: every sampled frame holds the app's own look — 27/27 frames clean
    (the vertical aspect's other six checks repeat the landscape ones above, and pass)
    30/30 checks passed

### Row 34 — a cancel leaves nothing, in full

First a render to completion (the file row 34 calls "the earlier video"), then a second render stopped at
about half way and confirmed. **25/25 checks passed.** `pm clear` before the row, so the app's library holds
its 5 shipped files and nothing else; the walker snapshots their hashes before the cancel and compares after.

    $ python3 specs/012-reading-video/scripts/klhu_walk_video.py 34
    PASS  34/first: the render reported done — 21s wall
    PASS  34: the earlier file came off the device — 1236914B
    PASS  34: the render was under way when Stop was tapped — ['Rendering video…, Video preview', 'Rendering video…']
    PASS  34: stopping asks first — ['Stop making the video?', 'Stop']
    PASS  34: the page is idle again
    PASS  34: the render's chrome is gone from the page — ['KalaHoo Reading', 'English', 'Appearance', 'Contents', 'Voice', 'Video', …]
    PASS  34: the cache holds no working copy — []
    PASS  34: the cache holds no per-sentence audio and no render directory — []
    PASS  34: the earlier render's working copy is gone from the cache — 0B read back; ok=False
    PASS  34: the app's library was neither added to nor rewritten — 5 -> 5 files; changed: []
    (the earlier artifact's own streams: h264 1920x1080, aac, 818 frames, 27.39 s — as row 31)
    25/25 checks passed

**What this row can and cannot say in US1, stated rather than glossed.** Row 34 says "keep a video for a
content; render it again; … the kept video is still in the gallery and still playable". Keeping is US3's file
store (T026/T029/T030) — in US1 nothing is kept, so there is no kept video to be untouched and the walker
tests the two things that do exist: the app's library (5 files, hashes unchanged across the cancel) and the
cache (empty of `.mp4`, `.wav` and `render_*` afterwards). The earlier render's file was the cache's working
copy, and row 34 itself requires the cache to be free of it afterwards — which is what the `ok=False` line
shows. The "still in the gallery" half is T030's, on the kept file.

Two walker bugs this row found, both in the driver rather than the app: the page's toolbar is at the *bottom*
of the screen (1080×2400), so the app-bar `Stop` and the dialog's `Stop` are told apart by y, and a substring
match for `'Stop'` hit the dialog's *title* ("Stop making the video?") instead of its button — the tap went to
a label and nothing happened. The driver now takes `exact=True` for buttons. A third: `run-as cat` on a
deleted file prints `cat: …: No such file or directory` and exits non-zero, which read as an 83-byte file —
`pull()` answers `(data, ok)` now, and the cache claims are made from a recursive `find` on the device rather
than from a pull.

### Row 35 — spike S1, in full

The question the plan could not answer from source (F5): the plugin's file-synthesis call exists in Dart and
in Kotlin (F1), but whether *the engine* writes something usable — and whether the length can be read out of
it — was unverified. Answer: **yes, and the duration is in the header**, so research D3 needs no fallback
and T014 keeps its shape.

Raw report (`adb shell run-as com.example.klhu cat …/cache/s1_report.txt`), three cases:

    engine=com.google.android.tts
    voices=472
    zh voices=[zh-TW-language@zh-TW, cmn-cn-x-cce-local@zh-CN, cmn-cn-x-ssa-local@zh-CN, cmn-tw-x-ctd-network@zh-TW, cmn-cn-x-ccd-network@zh-CN, zh-CN-language@zh-CN, …]
    en        lang=en-US setLanguage=1 result=1 wall=75ms  file=133906B  magic=RIFF fmt={rate:24000 ch:1 bits:16} data=133862 frames=66931 ms=2789
    zh        lang=zh-CN setLanguage=1 result=1 wall=315ms file=143994B  magic=RIFF fmt={rate:24000 ch:1 bits:16} data=143950 frames=71975 ms=2999
    zh-picked lang=zh-CN setLanguage=1 setVoice=zh-TW-language|zh-TW -> 1 result=1 wall=422ms file=162148B magic=RIFF fmt={rate:24000 ch:1 bits:16} data=162104 frames=81052 ms=3377

The engine's own log for the same run (`adb logcat -d | grep 'Synthesis request for locale'`) — this is the
only evidence of *which* voice spoke:

    Synthesis request for locale eng-USA and name en-US-language
    Synthesis request for locale zho-CHN and name zh-CN-language
    Synthesis request for locale zho-TWN and name zh-TW-language

The host's `ffprobe` on the two pulled files, independently of the probe's own RIFF walk:

    s1_en.wav  pcm_s16le 24000 Hz mono 16-bit  duration=2.788792  size=133906
    s1_zh.wav  pcm_s16le 24000 Hz mono 16-bit  duration=2.998958  size=143994

| # | What S1 settles | Evidence |
|---|---|---|
| S1-a | The engine writes real audio files through the plugin's call | `result=1` and three files of 134–162 KB |
| S1-b | The container is RIFF/WAVE, PCM 16-bit mono at **24 000 Hz** | the probe's header walk and the host's `ffprobe` agree exactly |
| S1-c | The sentence's exact length is in the file's own header | the probe's `ms=2789 / 2999 / 3377` match `ffprobe`'s `2.788792 / 2.998958` s to the millisecond — **D3 holds, no `MediaExtractor` fallback is needed** |
| S1-d | A sentence's language is honoured by the file path, not just by speak | engine log: `locale zho-CHN and name zh-CN-language` for the `zh` case |
| S1-e | **A chosen voice is honoured too**, and changes the audio's length | `setVoice(zh-TW-language@zh-TW)` → engine log `locale zho-TWN and name zh-TW-language`, file **162 148 B / 3377 ms** against the zh-CN default's **143 994 B / 2999 ms** — the same sentence, 378 ms longer in another voice |
| S1-f | Synthesis is fast enough to be a pass of its own | 75 / 315 / 422 ms of wall time per sentence — a 20-sentence content is a few seconds of pass 1 |

**S1-e is the one that matters for the design**: the timeline is measured per sentence with that sentence's
own voice, so a slot's length must be read from the file the *slot's* voice wrote — which is exactly what
pass 1 does and why the durations cannot be pre-computed once per content. It is also the FR-003/SC-007
case (a mixed-language content voiced as the page voices it) proven at the audio layer.

Two pitfalls the spike produced, both recorded for T011/T014:

1. **`awaitSynthCompletion(true)` is mandatory before the first call.** The plugin only holds the Dart
   future until the engine reports completion when that flag is on; without it the call resolves *before*
   the file exists, and pass 1 would read a half-written file and compute a wrong duration.
2. **A second call while one is in flight is dropped silently** — the plugin `result.success(0)`s it
   (`FlutterTtsPlugin.kt:343-358`). Pass 1 is therefore strictly sequential and awaited, one sentence at a
   time, never a batch.
3. **`getDefaultVoice` is not evidence of which voice spoke**: it answered `en-US-language` while the engine
   was synthesising `zh-CN`. The evidence is the engine's own log line.

## Deviations

1. **T003's method changed twice, and both are worth knowing.** `dart:io`'s `stdout` is not forwarded from
   the Android embedder — the probe's first run produced *no* console output at all — so the probe writes a
   report file into the app's cache and it is read back with `adb shell run-as`. The log line for a live run
   is a convenience, not the receipt.
2. **T003 gained a third case** (a picked voice, `zh-picked`) beyond the two sentences the task named. The
   first run left `getDefaultVoice` disagreeing with `setLanguage`, and the only way to tell an engine quirk
   from a broken voice path was to synthesise with an explicitly chosen voice and read the engine's log.
   That case is the strongest result in the row (S1-e).
3. **The device's installed app is currently the probe** (`flutter run -t …probe_synthesize.dart` replaced
   the entrypoint). Any device row (T017 onward) must reinstall the real app first — `flutter run -d
   emulator-5554` with no `-t`, or `flutter build apk --debug && adb -s emulator-5554 install -r`.
4. **T009 grew a second file: `lib/video_timeline.dart`.** The plan's file list had the plan/timeline inside
   `video_renderer.dart`; T004's tests made it a module of its own (the timeline is pure — sentences and
   measured audio in, the layout out — while the renderer is synthesis, painting and encoding, which cannot
   be tested without a device). T014 now consumes the plan instead of building it. Nothing in the plan's
   *decisions* changed: D3's two-pass shape, the frames' arithmetic and the slot model are as planned.
5. **A T005 assertion was deleted rather than repaired.** `expect(prefs.getStringList(VideoAspectStore.key),
   isNull)` threw instead of passing — this `shared_preferences` casts the stored value — and it asserted
   nothing about the contract anyway; the raw record (`prefs.get(key) == 'landscape'`) and the round-trip
   are the assertion that matters.
6. **The render's engine capability is a new narrow interface, not a method on `Reader`.** T011 said "add
   `synthesizeToFile` to the engine seam"; the seam it named (`lib/reader_service.dart:116-153`) is
   `TtsBackend`, and that is where the method went — but the *renderer* does not talk to `Reader`, it talks to
   a new `SentenceSynthesizer` that `ReaderService` implements alongside it. Reason: `Reader` has thirteen
   implementations in the suite alone, and adding a method to it would force thirteen edits whose only purpose
   is to satisfy a capability none of them has. The narrower interface has the compiler enforce the same thing
   where it matters — the renderer can only call synthesis — while every 010/011 fake is untouched. `Reader`
   keeps its shape; the page still receives a `Reader`. What the render and the read DO share is the voice
   step: both go through one private `_applyVoice`, so a sentence cannot be voiced one way on screen and
7. **The Kotlin half writes the encoder's own input buffer, not a surface.** T015's text said "`MediaCodec`
   AVC fed by its input surface"; what shipped is `COLOR_FormatYUV420Flexible` with `getInputImage`, so the
   picture is converted once per distinct frame and written straight into the buffer the codec hands back
   (no EGL context, no GPU, no presentation-time juggling, and it works on the emulator's software encoder).
   The conversion is BT.601 limited-range, which is what an SDR player expects. The route is invisible to
   every other task — the channel's shape is the contracts' — and the trade is per-frame Kotlin arithmetic
   for a whole GL stack; row 31's 21 s wall for a 27 s video says the trade is fine at this size.
8. **`VideoFileStore.keep` returns the kept file's URI and not a `VideoFile`** (T013), because the file
   contract answers `{uri, name}` and has no duration or size to report. Nothing consumed the old shape, so
   this is a correction rather than a break: `share` / `delete` / `exists` take that uri, which is what the
   record (US3, T022) will store.
9. **Row 32 found a defect in the new Kotlin half, and US2 fixed it (a US1 file).** `VideoEncoderPlugin` kept
   `private var picture: Yuv?` — one picture converted per *render* and reused for every later `sendFrame` —
   so **every video row 31 produced was 818 copies of the title card, with no highlight anywhere in it**.
   Row 31's `ffprobe` checks are structural (size, rate, frame count, duration) and passed throughout; the
   pixel pass of row 32 is what caught it, and its section above has the chain and the receipt. The cache is
   removed. Consequence for the checkpoints: US1's *Dart* tests pass unchanged (372/372) and row 31's numbers
   still stand (a file of repeated pictures has the same frame count, rate, aspect and duration), but US1's
   **device evidence is only trustworthy from this fix onward** — the earlier artifacts at
   `/tmp/klhu_out/landscape.mp4` and `vertical.mp4` show the title card throughout and must not be cited as
   the look.

