# Device validation: Reading Video (012)

**Feature**: `012-reading-video` | **Date**: 2026-09-25 (in progress)
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Tasks**: [tasks.md](./tasks.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400), package `com.example.klhu` |
| Build | `flutter analyze` clean; `flutter test --concurrency=2` → **301 passing, 0 failing** (T002's receipt, 2026-09-25 16:53:58 on `54ff4f3 "specs/011"`, 24 s with the emulator up) |
| Driver | `specs/012-reading-video/scripts/klhu_walk_video.py` (rows 31–36; not written yet — T031) |
| Spike S1 | `specs/012-reading-video/scripts/probe_synthesize.dart` — run on the device, read back with `adb shell run-as com.example.klhu cat /data/data/com.example.klhu/cache/s1_report.txt`, audio pulled with `adb exec-out run-as … cat …/s1_<case>.wav` and analysed with the host's `/usr/bin/ffprobe` |
| Engine | Google TTS (`com.google.android.tts`), 472 voices installed; `logcat` tag `GoogleTTSServiceImpl` says which voice actually spoke |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **[unit]** (the Dart test that
carries it), **[structural]**, **PENDING** (not yet runnable), or **UNVERIFIED WITH REASON**.

**State of this file**: the feature rows (quickstart 1–34, 37–40) are **PENDING — implementation has not
started** (they are the tasks' own acceptance rows), and row 36 (spike S2) is **PENDING** because a render
has to exist before its time can be measured. Rows 35 (S1) is closed below.

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 35 | Spike S1: does the engine write a usable audio file, and does it carry its own length? | **WALKED — PASS** | Three cases, one engine, one run (below) |
| 36 | Spike S2: a one-minute render's wall time, which replaces SC-006's placeholder | **PENDING** | needs T014–T015 (a render that completes) |
| 1–34, 37–40 | The feature's own rows | **PENDING** | implementation not started; each row's task is named in [tasks.md](./tasks.md) § Requirement coverage |

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
   another in the video (FR-003).
