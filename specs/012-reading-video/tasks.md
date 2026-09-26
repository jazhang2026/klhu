# Tasks: Reading Video

**Feature**: `012-reading-video` | **Date**: 2026-09-25
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contracts**: [video-frame-protocol.md](./contracts/video-frame-protocol.md), [video-file-protocol.md](./contracts/video-file-protocol.md), [video-player-protocol.md](./contracts/video-player-protocol.md), [video-aspect-format.md](./contracts/video-aspect-format.md), [video-record-format.md](./contracts/video-record-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (the render, P1), `US2` (the video's own look, P2), `US3` (the
file's life cycle, P3).

## Status

**In progress.** T001–T003 are done — the ARB keys, the baseline receipt and spike S1. Implementation
proper starts at T004; nothing under `lib/`, `test/` or `android/` has been touched beyond
`lib/l10n/*.arb` (T001), and the specs themselves.

Baseline to protect: **301 tests green, `flutter analyze` clean**, re-taken 2026-09-25 16:53:58 on
`54ff4f3 "specs/011"` (T002) — these numbers, not 011's, are what every later task is measured against.

**Spike S1 answered (T003): the engine writes RIFF/WAVE, PCM 16-bit mono at 24 kHz, and the duration is in
the file's own header** (within a millisecond of `ffprobe`), so T014 keeps the shape the plan gave it — no
`MediaExtractor` fallback. S1 also proved a *chosen* voice is honoured by the file path (S1-e, the FR-003
case at the audio layer) and produced two traps for T011/T014, both recorded in the task and in
[breakpoint.md](./breakpoint.md). T032 (spike S2) still replaces SC-006's placeholder ≤ 5 minutes with a
measured number, and it cannot run before a render exists.

**One thing this list states plainly**: the Kotlin half has no unit tests and none can be added that run in
`flutter test` (research D9). Its entire coverage is the six `[device]` rows T017, T021, T030, T031 and the
two spikes — which is why the platform half is kept logic-free.

## Grounding notes (decisions these tasks implement)

1. **The video is rendered, never recorded** (D1, FR-006): no `MediaProjection`, no microphone. Frames are
   painted by the app; audio is the engine's own file synthesis.
2. **Dart paints the frames, Kotlin encodes them** (D2, FR-014/FR-020): one `TextPainter`, fed the page's
   own style seam (`reading_view.dart:927-928`), rasterises a frame into a `PictureRecorder`; the same
   `ui.Image` is shown to the reader as the render's progress and its bytes go to the encoder. A frame is
   produced only when the visual state changes and carries a repeat count (Σ repeats = `totalFrames`).
   There is no second text engine.
3. **The voice is the clock** (D3, A5, FR-016): pass 1 synthesises every sentence to its own file and reads
   the exact length out of it; pass 2 emits frames to that timeline. The picture can therefore never drift
   from the voice, and a slot's boundaries are exact — which is what makes the per-slot frame sampling in
   quickstart 32 meaningful.
4. **The platform half carries no app logic** (D4): `VideoEncoderPlugin.kt` gets frames as pictures and
   audio as files, and knows nothing about text, sentences, languages or voices. Every decision worth
   testing stays in Dart, behind the fakes (F3).
5. **The render owns the page** (D10, FR-019): RENDERING and REVIEW are states of `lib/reading_view.dart`,
   not new routes, and their ownership rule is 011's FR-025 sibling — whichever of a read, a render or a
   review owns the page keeps it until it ends or the reader confirms ending it.
6. **The file has a life cycle** (D11, FR-021/FR-022): a render produces a working copy in the app's cache;
   keeping promotes it into the device's library (and is the only thing that does); deleting takes it out
   again behind a warning (FR-024). The record is the only new persisted state besides the aspect.
7. **The share surface is the phone's** (D13, FR-023): `ACTION_SEND` with the file's URI; a working copy is
   exposed through AndroidX's `FileProvider`, which is already on the classpath transitively (F10), and a
   kept video needs none. No platform SDK, no appid, no upload, no network.
8. **Tests first** (constitution III): each story's tests are written and run RED before that story's
   implementation. A compile error counts as RED — say so when it is one.
9. **Report, do not sweep**: the pre-existing platform-floor gap (minSdk 24 vs the declared 29), the iOS
   half's absence (D8) and the emulator/engine findings are reported to the user and recorded in
   `breakpoint.md`; they are nobody's task to silently fix here.
10. **New copy lands in all four ARBs at once** (ripple note 3): `test/l10n_keys_test.dart` fails in both
    directions, so a partially translated addition cannot pass.

## Path conventions

- Source: `lib/` (the platform half under `lib/platform/`); widget/unit tests: `test/`
- Android platform half: `android/app/src/main/kotlin/com/example/klhu/`, manifest and Gradle under
  `android/app/src/main/AndroidManifest.xml` and `android/app/build.gradle.kts`
- This spec: `specs/012-reading-video/`; the walk driver: `specs/012-reading-video/scripts/klhu_walk_video.py`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2`
  (the emulator being up makes plain `flutter test` segfault on this 16 GB host)
- After any ARB edit: `flutter gen-l10n`, then `git status --short lib/l10n` to show the regenerated files
  are part of the diff (they are committed artifacts)
- Device commands target `emulator-5554` (AVD `klhu`, API 36), package `com.example.klhu`; assertions on the
  produced file use the host's `ffprobe`
- Task-format check: `python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_tasks_format.py specs/012-reading-video`

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the copy every state of this feature draws on. Nothing is installed — this feature adds no
dependency and no asset (plan § Technical Context).

- [x] T001 Add the new message keys to the template `lib/l10n/app_en.arb` and the three translations
      `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`, `lib/l10n/app_es.arb` — the aspect choice and its
      two options, the render's labels (rendering, the picture's label for TalkBack), Stop and its
      confirmation, the review's three actions (keep / throw away / share), the kept-video actions (play,
      share, delete), the delete warning and its "cannot be undone" message, the video-is-gone message, and
      the render's failure messages (~35 keys, ripple note 3) — then `flutter gen-l10n` and confirm the diff
      is exactly the four ARBs plus the regenerated `lib/l10n/app_localizations*.dart`. The template keys
      must exist before any widget task compiles against them.
      **DONE 2026-09-25 — 22 new keys, not ~35**: the estimate counted labels the app already ships, and
      `saveButton`, `stopButton`, `deleteButton`, `cancelButton`, `discardButton`, `deleteConfirmMessage`,
      `storageErrorMessage` and `nothingToReadMessage` are reused verbatim (the last two are FR-015's
      "existing message" and the storage failure's copy). `flutter gen-l10n` generated 22 `video*` getters
      including `videoProgressLabel(int index, int total)`; `test/l10n_keys_test.dart` green in both
      directions; `flutter analyze` clean. `app_zh.arb` and `app_zh_Hans.arb` carry identical strings
      (they differ only in `@@locale`, as shipped), and only the template carries the `@`-metadata block

**Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green (key parity in both
directions across the four ARBs).

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the receipt to protect, and the one measurement the audio design depends on.

- [x] T002 Record the baseline over the whole `test/` tree before touching anything: `flutter analyze`
      (clean) and `flutter test --concurrency=2` (expect 301 passing, 0 failing), then write both numbers
      into the Status section of `specs/012-reading-video/tasks.md` with the date and the command.
      **DONE 2026-09-25 16:53:58 — `54ff4f3 "specs/011"`, `flutter analyze` "No issues found!", `flutter
      test --concurrency=2` → 301 passing, 0 failing, "All tests passed!" at 16:54:22 (24 s; the emulator
      being up did not segfault the run at this concurrency)**
- [x] T003 Run spike S1 into `specs/012-reading-video/breakpoint.md` (quickstart 35): call the engine's file
      synthesis for one English and one Chinese sentence of the shipped pre-set and inspect what it wrote
      (header, sample rate, channels, length). If no usable file appears, stop and report before T014 — the
      audio path changes shape (`MediaExtractor` decode, or the platform
      `TextToSpeech.synthesizeToFile` API called from `VideoEncoderPlugin.kt` directly).
      **DONE 2026-09-25 — the engine says yes, and the length is in the header**: RIFF/WAVE, PCM 16-bit mono
      at 24 000 Hz, and the probe's own walk and the host's `ffprobe` on the pulled files agree to the
      millisecond (2789 / 2999 ms), so D3 keeps its shape and no fallback is needed. Three cases — the third
      added mid-spike because `getDefaultVoice` disagreed with `setLanguage`: an explicitly *picked* voice
      (`zh-TW-language@zh-TW`) is honoured by the file path too and gives the same sentence a different
      length (162 148 B / 3377 ms against 143 994 B / 2999 ms), which is FR-003 at the audio layer and the
      reason a slot's length must come from the file *that slot's voice* wrote. Two traps for T011/T014:
      `awaitSynthCompletion(true)` is mandatory (without it the future resolves before the file exists) and a
      second in-flight call is dropped silently (`FlutterTtsPlugin.kt:343-358`), so pass 1 is strictly
      sequential and awaited. Raw output, method and deviations: [breakpoint.md](./breakpoint.md) row 35;
      the probe stays at `specs/012-reading-video/scripts/probe_synthesize.dart`

**Checkpoint**: baseline receipt in hand, S1's answer recorded, and nothing under `lib/` touched except the
ARB files T001 added to (and nothing under `android/` at all).

---

## Phase 3: User Story 1 — A content becomes one video I can play anywhere (P1) 🎯 MVP

**Goal**: the pipeline. A content, its sentences, its voices, its highlight and its scrolling become one
mp4 on the device, with the reader watching the video's own picture while it is written, and one Stop to end
it. The video's *look* (US2) and the file's *life cycle* (US3) come after.

### Tests for US1 ⚠️ (write first, run RED)

- [x] T004 [P] [US1] Write `test/video_timeline_test.dart` from quickstart 1–6: the plan's start point
      following the page (highlighted sentence, else the first), its coverage of every sentence to the end,
      `frames == round(ms × fps / 1000)` per slot with a running `startFrame`, the padding and fixed slots
      inside their bounds, an empty content yielding nothing, and each slot's language/voice equal to the
      read's own resolution.
      **DONE 2026-09-25 — 14 tests, written RED then green.** RED was the shape TDD takes in a static
      language: `flutter test` reported `+0 -2` with both files failing to *load* (unresolved names), which
      is recorded here as the RED rather than dressed up as a failing assertion. Green after T009's sibling
      landed: the start point is a raw 011 position snapped to its sentence's own start, the six sentences
      of the mixed fixture tile the content with only whitespace between them, and the layout assertion walks
      the cursor title → sentence → gap → … → hold. One case was rewritten, not patched over: an
      `expect(prefs.getStringList(...), isNull)` in T005 asserted nothing and *threw* (this
      `shared_preferences` casts on a String value), so it was deleted — the round-trip and the raw record
      are the assertion that matters
- [x] T005 [P] [US1] Write `test/video_aspect_test.dart` from quickstart 18 and
      `contracts/video-aspect-format.md`: default `landscape`, `vertical` honoured, a junk value treated as
      the default without a rewrite, one write per confirmed choice, the value surviving a reload.
      **DONE 2026-09-25 — 10 tests, green.** The record carries the choice's *name* (`prefs.get(key) ==
      'vertical'`), a junk record reads as the default and is provably left alone, and the namespace
      assertion is against the app's real keys (`reading_appearance`, `voice_*`, `read_position_*`,
      `interface_language`), not a literal
- [x] T006 [P] [US1] Write `test/video_painter_test.dart` from quickstart 7 and 9: one frame per slot with
      the highlight covering exactly that slot's sentence span inside the column, the text inside the
      frame's margins, and no app chrome or device UI drawn in any frame.
      **DONE 2026-09-25 — 8 tests, written RED (`+0 -1`, failing to load) then green.** The assertions split
      by what they are about: *what the frame says and highlights* is asserted on the painter's own geometry
      (`paintedText`, `highlightRange`, `highlight`, `lineBoxes`), which does not care which font the test
      host has; *what the frame paints* is asserted on the frame's own bytes — the four bands around the
      column are the background to the frame's edges, and the highlight colour appears inside its band and
      nowhere outside the column. Sampling is on a stride and the reason string says so. One expectation was
      wrong and the painter was right: `清晨的阳光。` is six characters, so its sibling sentence's span starts
      at 6, not 5 — the test was corrected, not the code
- [x] T007 [P] [US1] Write `test/video_renderer_test.dart` from quickstart 13–17: one `synthesizeToFile` per
      sentence preceded by that slot's language and voice, the published picture being the frame whose bytes
      the encoder received, progress that never goes backwards, cancellation at four points leaving no file
      and an empty temp directory, and the three failure paths — plus the audio-length read's own cases,
      since T003 put a RIFF walk in this code: a synthetic file whose length is known exactly, a truncated
      one, and one in a container that is not RIFF (the renderer must report a failure rather than guess a
      duration).
      **DONE 2026-09-25 — 17 cases, and RED found two things, one of them a real product bug.** The first run
      failed to compile (the fakes' hang points are settable fields, not constructor parameters) and then
      failed on behaviour twice: (1) **the timeline let a whitespace-only paragraph through as a sentence**, so
      a content of three spaces rendered a "successful" video of a blank frame and silence instead of being
      refused as nothing to read — `videoSentencesOf` now drops a segment that is only whitespace, and
      `test/video_timeline_test.dart` gained the whitespace-only and blank-paragraph cases (the fix rests on
      FR-015's premise: nothing audible, nothing to see); (2) **the progress counter restarts at the pass
      boundary**, and my own monotonicity assertion compared across it — the counter is per pass (sentences,
      then frames) and the test now asserts monotonicity *within* a pass. The file also pins the contracts
      worth arguing about: the audio segment's length comes from the frames (µs, `× 1e6 ÷ fps`) and not from
      the file; a sentence's run of frames covers the gap that follows it; the hold reuses the last sentence's
      picture rather than painting it again (4 encoder frames for 5 slots, the last with a repeat of 68); the
      published picture's bytes ARE the encoder's bytes (recomputed from the public `pngBytesOf`, not from a
      probe); and the four cancellation points plus the three failure paths all leave an empty directory and a
      `VideoEncodeException`/`VideoRenderException` rather than a file that lies
- [ ] T008 [P] [US1] Write `test/reading_view_video_test.dart` from quickstart 25–27: the RENDERING state
      offering the picture and Stop and nothing else, the text inert to tap and long-press, Stop's
      confirmation continuing the render when dismissed and writing nothing when confirmed, and leaving
      asking the same way

### Implementation for US1

- [x] T009 [US1] Implement `lib/video_aspect.dart`: the choice (two values) with the store shaped like
      `ReadPositionStore`/`AppearanceStore` (a single `shared_preferences` key `video_aspect`, every failure
      swallowed and the default returned), plus the derived frame (1920×1080 or 1080×1920) and frame rate
      the renderer reads.
      **DONE 2026-09-25, and this task grew a second file — see Deviations 1.** `lib/video_timeline.dart`
      was extracted out of T014's job because T004's tests made the plan a *pure* module and the renderer an
      orchestrator: `VideoSentence` (a public twin of `ReaderService._sentencesOf`'s unit, so the video
      speaks the sentence the page speaks), `videoSentencesFrom` (a raw 011 position → its sentence to the
      end, through the same `resolveSentence` + `resolveParagraphSpeeches` calls a read makes), `VideoSlot` /
      `VideoPlan` and `buildVideoPlan` (frames = `round(ms × fps / 1000)` in one place, the cursor walking
      title → sentence → gap → … → hold, and an empty content returning an empty plan rather than throwing).
      `VideoAspectStore` is `AppearanceStore`'s shape exactly: one key, `decode` never throws and never
      rewrites, saves swallow their failure. 24 tests green in the two files; the whole suite is
      **325 passing** (301 + 24) with `flutter analyze` clean
- [x] T010 [US1] Implement `lib/video_painter.dart`: paint one frame into a `PictureRecorder` at the plan's
      frame size using the page's own style seam, with the column and its margins, the highlight over the
      slot's sentence, and the title card slot — returning the `ui.Image` and its encoded bytes.
      **DONE 2026-09-25.** `VideoFrame` carries the image plus the geometry (column, per-line boxes, the
      highlight band and the span it covers, the text actually painted) so both the renderer and the tests
      read one picture's facts; `pngOf` is the same frame's bytes for the encoder. Three decisions worth
      naming: the column is 84 % of the frame's width with 8 % margins, and the scale maps the reader's
      character size from 011's 360 dp reading width onto that column (FR-014/A3, asserted in US2's T018);
      `canvas.clipRect(column)` is what makes the margins *provably* pure background rather than probably;
      and a paragraph taller than the frame is windowed around the sentence being heard, which is the
      video's own self-scroll (FR-002) — the band is centred and the offset clamped so the text never runs
      past its own ends. The style is a constructor parameter, not an ambient `Theme`, so 011's seam stays
      the only place the reader's style is built and a frame can be painted without a `BuildContext`
- [x] T011 [US1] Add `synthesizeToFile(text, fileName)` to the engine seam in `lib/reader_service.dart`
      (the interface at `:116-153` and the `FlutterTts`-backed implementation), applying the slot's language
      and voice exactly as the read does before each call (D5) — the block at `:373-387`: the language is the
      picked voice's OWN locale when one is picked, then `setVoice` is tried and its failure ignored. Factor
      that into one private step both `speak` and `synthesizeToFile` call, so the read and the render cannot
      drift apart. Two constraints from T003 belong here or in T014, not in a comment: turn
      `awaitSynthCompletion(true)` on before the first call, and never have two writes in flight at once.
      **DONE 2026-09-25 — and NOT by adding a method to `Reader` (see Deviations 6).** The seam gained
      `TtsBackend.awaitSynthCompletion` and `TtsBackend.synthesizeToFile` (called with `isFullPath: true`,
      which is what the probe measured), and the renderer's capability is a separate
      `SentenceSynthesizer` interface that `ReaderService implements ... , SentenceSynthesizer` alongside
      `Reader`. The voice step is now one private `_applyVoice`, called by both `_run` (which passes its
      already-listed `_installed` voices, so the read's call sequence is unchanged) and
      `synthesizeToFile`. `awaitSynthCompletion(true)` is set before every file call — the S1 trap — and the
      result is checked: anything but success throws rather than leaving a caller to read a file that is not
      there
- [x] T012 [P] [US1] Give the three engine fakes the new method — `test/reader_service_test.dart`,
      `test/cantonese_dialect_test.dart`, `test/spanish_localization_test.dart` — plus one real case in the
      first (the call's arguments and the file it names).
      **DONE 2026-09-25.** The three fakes it named are the *backend* fakes, which is exactly where the two
      new `TtsBackend` methods landed (`FakeTtsBackend`, and one `_FakeTts` each in the Cantonese and Spanish
      suites). No `Reader` fake needed touching — that is the point of Deviations 6. The real case is three
      cases, and each asserts a contract rather than a snapshot: the voice step is applied BEFORE the file is
      asked for (`languages == ['zh-CN']` and the voice, then the file at the caller's own path), a picked
      voice the engine does not have falls back to the language with no `setVoice` at all, and an engine that
      refuses the file (answers 0) raises `ReaderException` instead of pretending. `synthAwaitSets` asserts
      the `awaitSynthCompletion(true)` trap is actually set. **Not done, and still T013's**: the channel
      client behind these interfaces
- [ ] T013 [US1] Implement `lib/platform/video_encoder.dart`: the interface the renderer depends on (start /
      frame / finish / cancel, plus `isAvailable` and the keep/share/delete/exists calls) and the channel
      client for `klhu/video_encoder` and `klhu/video_files`, per both contracts, including the mapping of
      platform failures to the five codes.
      **PART DONE 2026-09-25 — the interfaces (and only them).** `VideoEncoder`, `VideoFileStore`, and the
      value types they speak (`VideoAudioSegment`, `VideoFile`, `VideoEncodeException`) exist and are what
      T007's fakes and T014's renderer are written against; the audio segment's unit is microseconds derived
      from frames, per its own doc. **The channel client for `klhu/video_encoder` / `klhu/video_files` and the
      mapping of platform failures to the five codes are NOT written yet** — they cannot be tested without a
      device and belong with T015's Kotlin side, so this box stays open
- [x] T014 [US1] Implement `lib/video_renderer.dart`: take the plan from `lib/video_timeline.dart` (T009's
      second file — the renderer does not build it any more), run pass 1 (synthesise each sentence
      **strictly sequentially**, awaited, and read each duration out of the WAV header T003 measured —
      24 kHz mono 16-bit, so the length is the data chunk over the frame size), run pass 2 (paint each unique
      frame, publish it as the current picture, send it with its repeat count and its audio segment's exact
      length — the sentence's own frames plus, between sentences, `VideoPlan.gapFrames` of silence), report
      progress, and clean the working directory on finish, cancel and failure.
      **DONE 2026-09-25.** What the implementation decided, all of it asserted in T007: the **audio segment's
      length comes from the frames, not from the file** (`frames × 1e6 ÷ fps` microseconds) because the
      frames are the muxer's clock and a rounded frame count would otherwise drift from the audio by up to a
      frame; a sentence's run of frames **covers the gap that follows it**, so the highlight stays on the
      sentence just heard until the next one starts; the **hold reuses the last sentence's picture** and its
      frames are added to that run rather than painting an identical frame again (4 pictures for 5 slots, the
      last standing for 68 frames); the renderer deletes **exactly the files it wrote** and never the
      encoder's video; and every ending — cancel, engine failure, unreadable audio, encoder refusal — reports
      through `VideoRenderException`/`cancelled` and leaves no file behind. `wavDurationMsOf` is the whole of
      the RIFF reading and answers `null` rather than guessing when the file is short, not RIFF, or missing
      its `fmt `/`data` chunks
- [ ] T015 [US1] Implement the Android half: `android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt`
      (the channels, `MediaCodec` AVC fed by its input surface, AAC from the audio files, `MediaMuxer`, the
      working copy, cancellation that deletes it) and register it in
      `android/app/src/main/kotlin/com/example/klhu/MainActivity.kt`
- [ ] T016 [US1] Wire the RENDERING state into `lib/reading_view.dart`: the idle-only video action with the
      aspect prompt, the picture area fed by the renderer's current frame, Stop with its confirmation (the
      `_confirmDiscard` shape at `:517`), every other action unavailable, the text inert, and leaving asking
      the same way
- [ ] T017 [US1] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` rows
      31 and 34 (quickstart 31, 34): a real render asserted with `ffprobe` (one H.264 stream at the chosen
      frame, one AAC stream, constant rate, duration against the audio sum), and a confirmed Stop at ~50 %
      leaving no file, an empty cache and an untouched kept video

**Checkpoint**: US1 is complete and independently demonstrable — a content becomes a video, the reader
watches it being written, and Stop ends it cleanly. Nothing about the video's look or its life has been
polished yet, and that is fine.

---

## Phase 4: User Story 2 — The video is good enough to publish (P2)

**Goal**: the video's own layout, at both aspects and at the reader's own typeface and character size, with
a title card, a settled pace and a legible smallest size.

### Tests for US2 ⚠️ (write first, run RED)

- [ ] T018 [P] [US2] Extend `test/video_painter_test.dart` from quickstart 8 and 10–12: the title card
      naming the content, both aspects' frames measuring 1920×1080 and 1080×1920 with their own column and
      margins, the painted text's height following the reader's chosen size by its ratio (within 10 %) in
      the chosen typeface, and the smallest size staying above the legibility floor on the narrowest column

### Implementation for US2

- [ ] T019 [US2] Extend `lib/video_painter.dart`: derive the column's width, its margins and the scale that
      maps the reader's character size from the *frame* (not the phone's screen), paint the title card
      naming the content and its language, and keep the highlight the app's yellow over the reading
      background (FR-008, FR-014, A3)
- [ ] T020 [US2] Extend `lib/video_renderer.dart`: the pacing — the constant inter-sentence padding, the
      title card's lead-in and the end hold inside their bounds (the hold lasting at least one frame past
      the last sentence's audio), all in whole frames so the file keeps its constant rate
- [ ] T021 [US2] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` row
      32 (quickstart 32): a frame extracted at every slot's start, middle and end showing that slot's
      sentence highlighted inside the column with margins and no chrome anywhere, and the page's captured
      picture during the render matching the sentence the renderer reported writing

**Checkpoint**: the video is publishable-shaped — both aspects, the reader's own text, a titled opening and
a paced close — and US1 still passes unchanged.

---

## Phase 5: User Story 3 — The video is mine to watch, keep, share and delete (P3)

**Goal**: the file's life cycle. A finished render is played before anything is decided; keeping puts it in
the gallery; sharing hands it to the phone's own list; a kept video is reachable again and its deletion
warns first.

### Tests for US3 ⚠️ (write first, run RED)

- [ ] T022 [P] [US3] Write `test/video_record_test.dart` from quickstart 19–24 and 39, against the
      record contract: keep writing one entry and replacing the previous file (write-then-delete), throwing
      a render away touching nothing kept, sharing working before and after keeping without implying it, a
      record whose file is gone being reported and forgotten, deleting warning first (dismissing changes
      nothing, confirming removes file and entry), and the app's existing content delete still warning
- [ ] T023 [P] [US3] Extend `test/reading_view_video_test.dart` from quickstart 28–29: the video action
      offered only from idle and absent where the platform cannot render, and the review pointing the player
      at the working copy with keep / throw away / share all offered and nothing kept yet

### Implementation for US3

- [ ] T024 [US3] Implement `lib/video_record.dart`: the store keyed by content (`video_record`, a JSON map),
      tolerant of missing, malformed and stale entries, with one entry per content and the lookup rule that
      forgets a record whose file is gone (contract `video-record-format.md`)
- [ ] T025 [US3] Implement `lib/video_review.dart`: the working copy with its facts and the three decisions
      (keep promoting it through the store, throw away deleting it, share handing it over), and the cleanup
      rule that leaving undecided keeps nothing
- [ ] T026 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoFileStore.kt` and its manifest
      entries: keeping through `MediaStore` on API 29+ and the public Movies directory plus a media scan
      below (with `WRITE_EXTERNAL_STORAGE` capped at `maxSdkVersion="28"`), the `FileProvider` entry and
      paths resource for sharing a working copy, the share intent, deletion, existence, and availability
- [ ] T027 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoPlayerView.kt` and register it:
      the platform view over the framework's own player with its transport controls, per
      `contracts/video-player-protocol.md`, refusing anything that is not a local file
- [ ] T028 [US3] Implement `lib/platform/video_player.dart`: the Dart side of the playback view (the widget
      and its channel), used by the review and by a kept video's playback
- [ ] T029 [US3] Wire the file's life into `lib/reading_view.dart`: the REVIEW state (the player, keep,
      throw away, share), the kept-video actions on the page (play, share, delete-with-its-warning), the
      stale-video message, and the content offering to record again after a deletion
- [ ] T030 [US3] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` row
      33 (quickstart 33): play the review before keeping, throw one away and keep another, find it in the
      gallery under the content's name, share it through the phone's list, delete it behind the warning, and
      find it gone with the content offering to record again

**Checkpoint**: all three stories are independently demonstrable, and the file's whole life — working copy,
kept, shared, deleted — is exercised on the device.

---

## Phase 6: Polish & cross-cutting concerns

- [ ] T031 [P] Commit the walk driver `specs/012-reading-video/scripts/klhu_walk_video.py` (rows 31–36, one
      function per row, argv dispatch, `RESULT: PASS|FAIL`, importing 010's device helpers) and record every
      row with its evidence and divergences in `specs/012-reading-video/breakpoint.md`
- [ ] T032 [P] Run spike S2 per `specs/012-reading-video/quickstart.md` row 36 and replace the placeholder in
      `specs/012-reading-video/spec.md`: measure a one-minute render end to end on the reference device (wall
      time, frames per second, which side is the bottleneck) and put the measured number into SC-006 and into
      quickstart row 36 — the spec keeps ≤ 5 minutes only until this runs
- [ ] T033 [P] Update `README.md`: the 012 row in the spec index (drop any "spec only" wording) and the note
      that this is the repository's first feature with a platform-specific half
- [ ] T034 Tick the boxes in `specs/012-reading-video/tasks.md`, recording every deviation from this list
      inline beside the task it belongs to (a divergence found is written down where it was found)
- [ ] T035 Run the structural rows in `specs/012-reading-video/quickstart.md` (37–40) and write the final
      report: quickstart 37 (no dependency added), 38 (four ARBs), 39 (the content delete still warns) and 40
      (011's receipt still green, with its `android/`-is-empty row scoped to 011), then report what shipped,
      the receipt, the measured S2 number, and — restated, not buried — the iOS gap and the pre-existing
      platform-floor gap

---

## Dependencies & ordering

- **T001 → everything**: the ARB keys are what the widget tasks compile against.
- **T002 → all implementation** (the baseline), **T003 → T014** (S1 decides how the audio's length is read).
- **US1 → US2 and US3**: US2 refines the painter US1 introduces; US3's keep depends on a file existing.
  Within US1: T009/T010/T011 → T013 → T014 → T015 → T016, with T012 alongside T011.
- The six `[device]` rows (T017, T021, T030 and the driver they live in, T031/T032) come after the code
  they exercise, and are the only coverage the Kotlin half has (Status).
- **T034/T035 last**: the report quotes receipts, not intentions.

## Parallel opportunities

- The five US1 test files (T004–T008) are separate files with no dependency between them: one pass, all RED.
- T012 (the three fakes) and T013 (the channel client) touch different files and can go side by side.
- US2's tests (T018) can be written while US1's implementation is still in progress, as long as they are run
  RED before T019/T020 land.
- The two US3 test files (T022, T023) are independent of each other.
- T031–T033 are three different artifacts (the driver, the spec's number, the README).

## Implementation strategy

**MVP first**: T001–T017 give a working video of a content's reading with the reader watching it being made
— the whole of US1 and the reason the feature exists. Ship that, walk it on the device, then add US2's look
and US3's life cycle. Do **not** start US3's file store before US1's render is green end to end: the file's
life cycle is trivial once a file exists and unknowable before.

**Ordering rule inside each story**: write that story's tests, run them RED, then implement. A story's
device row is its acceptance test — a story is not done because its unit tests pass.

**What to do when the platform half misbehaves**: the Kotlin half is the part with no unit tests, so a bug
there is found by a device row, and the fix belongs in Kotlin (not as a workaround in Dart). If a workaround
in Dart seems necessary, that is a signal the split in D4 is wrong — report it rather than papering over it.

## Notes

- `[P]` is about files, not attention: `lib/reading_view.dart` is edited by T016 and T029 in that order,
  `lib/video_painter.dart` by T010 then T019, and `lib/video_renderer.dart` by T014 then T020.
- Never let the renderer hold a whole video in memory: frames are sent as they are painted, and the audio is
  files on disk. A ten-minute content must not need a ten-minute buffer.
- The working copy and the per-sentence audio live in the app's cache directory and must be gone after any
  ending — finish, cancel, failure, or a review that decides. quickstart 34 asserts exactly that.
- `flutter test` needs `--concurrency=2` while the emulator runs.
- Every RED claim in the transcript must quote the actual failure (assertion message or compile error); a
  test that was never seen failing is not evidence.
- The device rows must not depend on a fixed `sleep` for a moment that lasts seconds: poll
  `adb logcat -d | grep 'klhu render'` and act on the line (the 010 walk's mechanic). The render's own
  evidence line is `klhu render slot=<i>/<n> frame=<f>/<m>`, added in T014.
- Do not commit a `.mp4` into the repository: the device rows pull their artifacts into `$KLHU_OUT`, and the
  spec directory holds evidence (paths, `ffprobe` output, frame counts), never binaries.

---

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 the idle page offers a video action | T016, T023 |
| FR-002 the video shows the text, the moving highlight and the self-scroll | T010, T017 |
| FR-003 the voice is the app's own synthesis, per paragraph's language and chosen voice | T011, T014 |
| FR-004 start at the highlighted sentence, else the content's first; run to the last | T004, T009, T014 |
| FR-005 the highlight is the sentence being heard, inside the visible text | T006, T010, T021 |
| FR-006 the frame is the video's own — no chrome, no device UI, never a recording | T006, T010, T015, T021 |
| FR-007 the aspect/resolution chosen before the render, exactly as chosen | T005, T009, T017 |
| FR-008 a title card naming the content; a hold at the end | T018, T019, T020 |
| FR-009 progress and cancellation; nothing left behind | T007, T014, T017 |
| FR-010 the action is idle-only and a touch never interrupts | T008, T016, T023 |
| FR-011 a kept video lives where the galleries look, under the content's name | T026, T029, T030 |
| FR-012 keeping again leaves exactly one video for that content | T022, T024, T026 |
| FR-013 produced on the device — no account, no backend, no upload, no network | T015, T026, T035 |
| FR-014 the video's text is the reader's typeface and size, mapped to the frame | T018, T019, T020 |
| FR-015 an empty content is refused with the existing message and no file | T004, T014 |
| FR-016 pacing follows the voice, within the stated bounds | T004, T020 |
| FR-017 the audio is complete, in order, nothing dropped or repeated | T004, T007, T011 |
| FR-018 the reading page's shipped behaviour is untouched | T008, T016, T035 |
| FR-019 the render owns the page; Stop asks first | T008, T016, T029 |
| FR-020 the page shows the video's own picture as the render's progress | T007, T010, T014, T021 |
| FR-021 a finished render is played, then kept, thrown away or shared | T022, T023, T025, T029 |
| FR-022 a kept video is reachable again, and deleting it removes file and record | T022, T024, T029, T030 |
| FR-023 sharing through the platform's own list; no SDK, no account, no upload | T022, T026, T028, T030 |
| FR-024 deleting warns first, and never on a single tap | T022, T026, T029, T030 |
| SC-001 a reader makes a video in the app, no network, and is told the file's name and length | T017, T031 |
| SC-002 it plays start to end: one video stream, one audio stream, the duration within 2 s | T017, T031 |
| SC-003 every sentence's highlight is visible while its voice is heard (100 % of samples) | T006, T021 |
| SC-004 no frame carries the app's controls or the device's UI; margins on all sides | T006, T021 |
| SC-005 publishable-shaped, verified with a media analyser rather than by eye | T017, T031 |
| SC-006 the render's time on the reference device, with cancellation leaving nothing | T017, T032 |
| SC-007 a mixed-language content is voiced per paragraph exactly as the page voices it | T004, T007 |
| SC-008 two renders leave exactly one video for that content, and it is the second | T022, T030 |
| SC-009 the reading page behaves exactly as 011's receipt shows | T008, T035 |
| SC-010 with a highlight the video starts there; otherwise at the first sentence; always ends last | T004, T014 |
| SC-011 two renders at two sizes differ by their ratio, in the chosen typeface | T018, T019 |
| SC-012 each aspect measures as rendered (1920×1080 / 1080×1920) at the constant rate | T005, T017 |
| SC-013 while rendering only Stop is reachable; both Stop and leaving ask before acting | T008, T016 |
| SC-014 the picture shown during the render is the frame being written | T007, T014, T021 |
| SC-015 a review plays before anything is kept; keep, throw away and share each land as stated | T022, T025, T029, T030 |
| SC-016 a kept video is reachable, playable, shareable and deletable; a stale record is reported gone | T022, T024, T029 |
| SC-017 the share list is the device's own, and nothing is uploaded by the app | T026, T030 |
| SC-018 deleting warns: dismissing keeps the video, confirming removes it; the content delete still warns | T022, T026, T030 |
