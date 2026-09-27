# Tasks: Reading Video

**Feature**: `012-reading-video` | **Date**: 2026-09-25
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contracts**: [video-frame-protocol.md](./contracts/video-frame-protocol.md), [video-file-protocol.md](./contracts/video-file-protocol.md), [video-player-protocol.md](./contracts/video-player-protocol.md), [video-aspect-format.md](./contracts/video-aspect-format.md), [video-record-format.md](./contracts/video-record-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (the render, P1), `US2` (the video's own look, P2), `US3` (the
file's life cycle, P3).

## Status

**In progress — re-cut 2026-09-27 to the amended picture.** T001–T025, T028, T029, **T036** (the pictures'
keys), **T038** (spike S4), **T044** (the picker is flutter.dev's `file_selector`) and **T045** (the picker's
seam over it) are done; T026, T027 and T030 (the file store, the player view and US3's device row) are not. The 2026-09-26 amendment replaced what a
frame *shows*: one sentence per frame at the reader's own size, over the reader's own pictures with the scrim
between them, with each picture's schedule counted in the video's own frames (FR-002, FR-014, FR-025–FR-029,
US4). The
rows written to the withdrawn picture — T006, T010, T018, T019 and T021 — are marked **superseded in place**
and their work is re-cut by T039–T048 rather than renumbered: their ticks are the record of what was built and
measured at the time, and the amendment's own rule is that the old picture's code is deleted, not extended
(plan ripple note 7).

**The scrim's direction and depth were settled by measurement, not by assumption (T038, 2026-09-27).** On the
reader's own four pictures at both aspects, the 40 % *black* layer the amendment assumed left **42–100 %** of the
glyph pixels under SC-004's 4.5:1, a 45 % layer left 2–42 %, and 50 % left up to 51 % — while a **55 % layer of
the frame's own background colour passes everywhere (min 4.90:1, 0 % under the floor)**, and passes *by
construction*: over a pure-black picture that layer is the background's own 4.90:1 against the reader's text. The
painter (T042) and its rows (T039), plus the numbers in `spec.md`, `quickstart.md` (row 42's) `data-model.md` and
`research.md` D16, were re-cut to it in the same pass; the stills harness is kept beside S1's probe.

Receipt to protect: **395 tests green, `flutter analyze` clean** (measured 2026-09-27 on `b76c452 "012 +"`,
`flutter test --concurrency=2`, emulator up) — 301 at T002's baseline, re-taken 2026-09-25 16:53:58 on
`54ff4f3 "specs/011"`, which is the number every earlier tick in this list was measured against. T002's
reordering still holds: the receipt predates every edit of this stage.

The requirement checker was red on exactly the amendment's seven new ids — `FR-026`, `FR-027`, `FR-028`,
`FR-029`, `SC-019`, `SC-020`, `SC-021` — which is what this re-cut exists to fix: the coverage table below names
them now, and `check_tasks_format.py` reports **OK** (48 tasks, 26 done, 15 `[P]`) as of 2026-09-27.

**Spike S1 answered (T003): the engine writes RIFF/WAVE, PCM 16-bit mono at 24 kHz, and the duration is in
the file's own header** (within a millisecond of `ffprobe`), so T014 keeps the shape the plan gave it — no
`MediaExtractor` fallback. S1 also proved a *chosen* voice is honoured by the file path (S1-e, the FR-003
case at the audio layer) and produced two traps for T011/T014, both recorded in the task and in
[breakpoint.md](./breakpoint.md). T032 (spike S2) still replaces SC-006's placeholder ≤ 5 minutes with a
measured number, and it cannot run before a render exists.

**Three spikes now gate work rather than being decided inside it**: S2 (T032) still replaces SC-006's
placeholder, S3 (T037) decides what the file dialog hands back and what converting it costs — which is what
T043/T045 wait on —
and S4 (T038) sets the scrim's number, which T039's contrast row and T042's painter wait on.

**One thing this list states plainly**: the Kotlin half has no unit tests and none can be added that run in
`flutter test` (research D9). Its entire coverage is the `[device]` rows T017, T021, T030 and T048 plus the
spikes — which is why the platform half is kept logic-free, and why the picker (T044) is flutter.dev's own
plugin handing back a name and bytes, rather than a screen.

## Grounding notes (decisions these tasks implement)

1. **The video is rendered, never recorded** (D1, FR-006): no `MediaProjection`, no microphone. Frames are
   painted by the app; audio is the engine's own file synthesis.
2. **Dart paints the frames, Kotlin encodes them** (D2, FR-014/FR-020): one `TextPainter`, fed the page's
   own style seam, rasterises a frame into a `PictureRecorder`; the same
   `ui.Image` is shown to the reader as the render's progress and its bytes go to the encoder. A frame is
   produced only when the visual state changes — the sentence, its line step, or the picture covering it
   (note 11) — and carries a repeat count (Σ repeats = `totalFrames`).
   There is no second text engine.
3. **The voice is the clock** (D3, A5, FR-016): pass 1 synthesises every sentence to its own file and reads
   the exact length out of it; pass 2 emits frames to that timeline. The picture can therefore never drift
   from the voice, and a slot's boundaries are exact — which is what makes the per-slot frame sampling in
   quickstart 32 meaningful.
4. **The platform half carries no app logic** (D4): `VideoEncoderPlugin.kt` gets frames as pictures and
   audio as files, and knows nothing about text, sentences, languages or voices. Every decision worth
   testing stays in Dart, behind the fakes (F3).
5. **The render owns the page** (D10, FR-019): RENDERING and REVIEW are states of `lib/reading_view.dart`,
   not new routes, and their ownership rule is the sibling of the rule 011 wrote as its own FR-025 (a different
   requirement from this feature's FR-025) — whichever of a read, a render or a
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
11. **The frame is one sentence (amended 2026-09-26)** (D14, FR-002/FR-005/FR-014): the painter draws the
    sentence being spoken, alone, at the reader's own character size — no highlight band, no window around a
    paragraph and no scrolling of the page, because with one sentence in the frame there is nothing left to
    highlight. A sentence taller than the frame's text area is drawn **whole** and scrolled upward inside its
    own frame, quantised to a **line** step (one paint per line, not per pixel — the cost S2 measures), with
    the position proportional to the elapsed fraction of the slot. The one estimate this feature admits, and
    the reader accepted it: the engine speaks a sentence as one utterance, so no finer timing exists.
12. **The pictures are the reader's own** (D15, FR-025–FR-028): chosen through the platform's own **file**
    dialog — flutter.dev's `file_selector`, the reader's decision of 2026-09-27, because the pictures are files
    made anywhere and the file dialog is the one selection UI every target has; no in-app gallery, no new
    permission, and no platform half of ours — then copied once into the render's working directory before pass 2
    reads them, and cleaned up with the working copy. Their schedule is each picture's **inclusive start and
    end frame in the video's own numbering** — equal shares in the order chosen for this cut — and an empty
    schedule is valid: the plain background, nothing refused and nothing delayed.
13. **The scrim is one layer at a measured depth** (D16, FR-027, SC-004): one full-frame layer **in the frame's
    own background colour** between the picture and the text, at **55 %** — the depth S4 (T038) measured, not the
    40 % *black* layer the amendment assumed: on the reader's own pictures the black layer left 42–100 % of the
    glyph pixels under 4.5:1, 45 % left 2–42 %, 50 % left up to 51 %, and 55 % of the background colour passes
    everywhere (min 4.90:1, 0 % under the floor) because that layer's floor *is* the background's own 4.90:1.
    The reversal is recorded in research D16 and `breakpoint.md` row 42 instead of being absorbed.
14. **The amended picture's rows are appended, never renumbered** (Tasks-stage rule): T004–T035 keep their
    numbers and their ticks, the tasks written to the withdrawn picture say so in place, and the amendment's
    own work takes the next numbers (T036–T048) even where it belongs physically to an earlier story.

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

*The amended picture also needs keys of its own — T036, which belongs to this phase and is cut in **Phase 7**:
the format checker requires the task ids to run sequentially through the file, and the reviewed rows may not be
renumbered, so every task added after 2026-09-26 carries the next number and is appended at the end.*

**Checkpoint**: `flutter analyze` clean; `flutter test test/l10n_keys_test.dart` green (key parity in both
directions across the four ARBs).

---

## Phase 2: Foundational (blocking prerequisite)

**Purpose**: the receipt to protect, and the three measurements the audio design and the amended picture
depend on (S1's is answered; S3 and S4 were added 2026-09-26).

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

*The amended picture also needs two measurements of its own — spikes S3 and S4, cut as **T037/T038** in
**Phase 7**: the format checker requires the task ids to run sequentially through the file, and the reviewed
rows keep their numbers, so every task added after 2026-09-26 is appended at the end. They gate the painter
(T042) and the picker (T044/T045), so in build order they run before Phase 7's test and implementation
batches, not after them.*

**Checkpoint**: baseline receipt in hand and S1's answer recorded — and, at the time this phase ran, nothing
under `lib/` touched except the ARB files T001 added to (and nothing under `android/` at all).

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
      at 6, not 5 — the test was corrected, not the code.
      **SUPERSEDED 2026-09-27 — this row's picture is withdrawn.** Its cases assert the highlight band inside
      the column, which the 2026-09-26 amendment removed (FR-002, plan ripple note 7). The file's rows are
      **replaced** by T039's, not extended; the tick above stands as the record of what the painter did before
      the amendment (8 tests, suite 372 at the time)
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
- [x] T008 [P] [US1] Write `test/reading_view_video_test.dart` from quickstart 25–27: the RENDERING state
      offering the picture and Stop and nothing else, the text inert to tap and long-press, Stop's
      confirmation continuing the render when dismissed and writing nothing when confirmed, and leaving
      asking the same way
      **DONE 2026-09-26.** 5 cases, all green, and the RED was the page's missing seam: the file was written
      first and the compiler named exactly what T016 had to add (`synthesizer` / `videoEncoder` /
      `videoWorkDir`) — plus one real correction the compiler caught: `RawImage` carries no
      `semanticLabel`, so the picture is announced through a `Semantics` wrapper instead (which is what the
      plan's accessibility row asked for anyway). Everything below the page is the REAL pipeline — the real
      `VideoRenderer`, painter and timeline, over a fake engine writing real RIFF/WAVE files and a fake
      encoder — so "the picture on screen is the frame written" is checked by decoding the encoder's own PNG
      and comparing it with the frame the page is showing (`encoder.frames` recorded 213 frames for the
      three-sentence content). Three test-side lessons worth keeping: `find.text` does NOT see the page's
      reading text (it paints a `RichText` directly — `renderedContent()` in the file is the finder that
      does); the idle page legitimately has its own `Stop` button, so "not rendering" is asserted on the
      progress line, not on the Stop tooltip; and a helper that lets real IO run must pump once AFTER its
      loop, or work landing in the last real turn is observed before the tree redraws

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
      the only place the reader's style is built and a frame can be painted without a `BuildContext`.
      **SUPERSEDED 2026-09-27 — the painter is rewritten, not extended.** The band, the page window and the
      column mapping come out (with one sentence in the frame there is nothing to highlight and nothing to
      scroll to); the sentence at the reader's own size, its wrapped-and-scrolled-by-line layout, the picture
      layer and the scrim go in — T042, per research D14/D15/D16. What survives untouched is the frame size,
      the style-as-a-parameter seam and `pngOf`
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
- [x] T013 [US1] Implement `lib/platform/video_encoder.dart`: the interface the renderer depends on (start /
      frame / finish / cancel, plus `isAvailable` and the keep/share/delete/exists calls) and the channel
      client for `klhu/video_encoder` and `klhu/video_files`, per both contracts, including the mapping of
      platform failures to the five codes.
      **DONE 2026-09-26.** `MethodChannelVideoEncoder` (`klhu/video_encoder`) and
      `MethodChannelVideoFileStore` (`klhu/video_files`), both contract-shaped: the encoder sends
      `startRender` (frame, fps, the constant bitrate, `totalFrames`, the working path under the app's cache,
      and the timeline's audio segments in order), `sendFrame`, `finishRender` (a map that MUST carry a path —
      a caller is never handed a path that is not there), `cancelRender`; the file store sends `keep` /
      `share` / `delete` / `exists` / `isAvailable`. A platform failure becomes a `VideoEncodeException`
      whose message carries the contract's own code (`CODEC_FAILED: …`), and a `MissingPluginException` —
      the iOS case, D8 — answers `false` from `isAvailable` and `ENGINE_UNAVAILABLE` from a call, never an
      error the reader sees. Two corrections to what the earlier part of this task left: (1)
      **`VideoFileStore.keep` now returns the kept file's URI, not a `VideoFile`** — the contract answers
      `{uri, name}` and has no duration or size to report, and nothing consumed the old shape yet (the
      renderer only speaks `VideoEncoder`); `share`/`delete`/`exists` therefore take a uri `source`, which is
      what the record stores. (2) **`isAvailable` is asked on `klhu/video_encoder` as well** — the interface
      the renderer was already written against carries it, and the frame contract's table did not list it;
      the file channel keeps its own per the file contract. **Not exercised yet, and stated rather than
      glossed:** the file-store client has no in-tree consumer until US3 (T026/T029), and neither client can
      be validated without the device — that is T015/T017's and T033's work, not a unit test's
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
- [x] T015 [US1] Implement the Android half: `android/app/src/main/kotlin/com/example/klhu/VideoEncoderPlugin.kt`
      (the channels, `MediaCodec` AVC fed by its input surface, AAC from the audio files, `MediaMuxer`, the
      working copy, cancellation that deletes it) and register it in
      `android/app/src/main/kotlin/com/example/klhu/MainActivity.kt`
      **DONE 2026-09-26, and the device proved it on the first try (row 31).** `VideoEncoderPlugin` handles
      `isAvailable` / `startRender` / `sendFrame` / `finishRender` / `cancelRender` on a single-thread
      executor and answers each call only when its work is done — Dart awaits every call, so that one thread
      is the whole concurrency story and the UI thread never converts a picture. The video is `MediaCodec`
      AVC at `COLOR_FormatYUV420Flexible` with **`getInputImage`** (not the input surface the task named —
      Deviations 7), the audio AAC-LC at the WAV's own rate, both muxed by `MediaMuxer`; the muxer starts when
      the video's own format arrives, which is the first moment both tracks can be added, and the audio
      encoded at the start is written into its track then. Four decisions worth naming: (1) **the audio is
      padded or cut to the durations Dart measured** (silence for the title card and the hold), so A/V cannot
      drift — row 31's 642 AAC frames (27.4 s) against 818 video frames (27.3 s) is that padding showing;
      (2) **one `totalFrames` check refuses the render** if the frames sent don't add up, because a file that
      is not the length the timeline promised is broken rather than short; (3) **a picture is converted once
      and written again for each of its frames** (the renderer sends 4 pictures for 5 slots, so this is the
      difference between 4 conversions and 213); (4) **every ending closes everything** — `releaseAll` stops
      and releases both codecs and the muxer and deletes the working file unless the render finished. Platform
      failures become the frame contract's five codes, and a `MissingPluginException` answers `isAvailable:
      false` (the iOS case, D8) rather than an error the reader sees. `MainActivity` gains only
      `configureFlutterEngine`. Verified by `flutter build apk --debug` (the Kotlin compiles) and quickstart
      row 31 — the only coverage this half has (Status)
- [x] T016 [US1] Wire the RENDERING state into `lib/reading_view.dart`: the idle-only video action with the
      aspect prompt, the picture area fed by the renderer's current frame, Stop with its confirmation (the
      `_confirmDiscard` shape at `:517`), every other action unavailable, the text inert, and leaving asking
      the same way
      **DONE 2026-09-26.** `_Mode.rendering` beside the page's four states; the video action is an app-bar
      `IconButton` offered only from READ (`FR-010`: absent, not greyed, in EDIT/SPEAKING/PAUSED); the
      prompt is an `AlertDialog` with the app's own `ChoiceChip` idiom (the appearance screen's) opening on
      the remembered `VideoAspectStore` choice and saving the confirmed one (A8); `_startRender` builds the
      real `VideoRenderer` from the page's own style seam (`_contentTextStyle`, the scaffold background,
      `Colors.yellow` — FR-014), feeds the picture area from `onFrame`, counts pass 1 in sentences and lets
      pass 2's picture be the progress (FR-009/FR-020), and reports the finished file's name and length
      (SC-001); Stop and leaving share one `_confirmStop` dialog, and `PopScope(canPop: !rendering)` is what
      makes leaving ask (FR-019); `dispose` cancels, so a page that goes away leaves no file (FR-009);
      `_renderGen` is the guard that keeps a stopped render's own report off the page.
      **Deviations, recorded where they were found:**
      1. **One more ARB key than T001's list.** `videoDoneMessage` ("Video made: {name} ({seconds} s)") in all
         four ARBs + regenerated `app_localizations*`: US1 is independently demonstrable at T017 and the spec
         asks the finished render to say WHERE the file is and how long it is (SC-001, US1 scenario 1), which
         no key in T001's set could say. US3's review (T029) decides whether it stays.
      2. **Each render gets its own working directory** (`<videoWorkDir>/render_<n>`, removed by the page
         when the render reports) rather than sharing one. A confirmed Stop takes the page back to idle at
         once while the render is still finishing the call in flight AND deleting the files it wrote — in one
         shared directory that cleanup would delete a *newer* render's per-sentence files (the renderer's
         `written` list names paths, and the second render's files have the same names). The renderer is
         unchanged: it still deletes exactly the files it wrote, in a directory that holds nothing else.
      3. **Leaving a render reuses the Stop dialog's keys** (`videoStopConfirmTitle/Message`) — FR-019's own
         wording is "leaving … asks in the same way", and `videoLeaveTitle`/`videoLeaveMessage` ("Nothing is
         saved until you tap Save") are the *review's* leave, which is US3's T029.
      4. **The app bar now carries five actions** plus the language dropdown when a localization service is
         set. It fits the 800×600 test surface; the device row (T017) is where a real phone's width decides
         it, and the fallback if it crowds is moving the action into the toolbar, not shrinking it.
      5. **`_reportRenderDone` also prints `klhu render done: <path> <ms>ms <bytes>B frames=<n>`** — the
         walker's evidence line, in the app's existing `klhu read range` / `klhu follow` / `klhu speak` style,
         so T017 can assert the file's own facts as well as the SnackBar's text.
      6. **`main.dart` needed no change**: the page's synthesizer defaults to the reader it is handed
         (`ReaderService` implements `SentenceSynthesizer`), so the read and the render share one engine (D5)
- [x] T017 [US1] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` rows
      31 and 34 (quickstart 31, 34): a real render asserted with `ffprobe` (one H.264 stream at the chosen
      frame, one AAC stream, constant rate, duration against the audio sum), and a confirmed Stop at ~50 %
      leaving no file, an empty cache and an untouched kept video
      **DONE 2026-09-26 — row 31: 31/31 checks; row 34: 25/25.** The driver was written for these two rows
      (`specs/012-reading-video/scripts/klhu_walk_video.py`); it polls the app's own `klhu render done:` line
      and the page's progress instead of sleeping, per the Notes. **Row 31**, from `pm clear`'d state at both
      aspects: one H.264 stream at exactly 1920×1080 then 1080×1920, one AAC stream (24 kHz mono),
      `r_frame_rate == avg_frame_rate == 30/1`, **`nb_read_frames` 818 — the plan's own number** — and a
      duration of 27.393833 s against the render's 27.266 s (0.13 s, inside the 2 s bound); the page said
      `Video made: klhu_video.mp4 (27 s)` and each pulled file's byte count equalled the app's
      (1236914 / 1036800). **Row 34**: a full render, then a second stopped mid-render and confirmed — the
      page went idle with its render chrome gone, the cache held **no** `.mp4`, `.wav` or `render_*`
      afterwards, and the app's library was unchanged (5 files, hashes identical before and after). Receipts
      and the three driver bugs this row found: [breakpoint.md](./breakpoint.md) rows 31 and 34.
      **Row 34's scope, stated rather than glossed:** "the kept video is still in the gallery and still
      playable" needs US3's keep (T026/T029) — in US1 nothing is kept, so the earlier render's file *is* the
      cache's working copy and row 34 itself requires the cache to be free of it afterwards. What stands in
      for "untouched" here is the app's library, hash-compared, plus the artifact's streams re-probed by
      `ffprobe`; T030 owns the kept file's half. **By-product for T032 (row 36, still PENDING):** 8 sentences,
      818 frames, 27.27 s of video rendered in **21 s wall** on this emulator at both aspects — faster than
      real time, so SC-006's ≤ 5 min placeholder is not at risk; T032 owns the official number and the
      bottleneck attribution

**Checkpoint**: US1 is complete and independently demonstrable — a content becomes a video, the reader
watches it being written, and Stop ends it cleanly. Nothing about the video's look or its life has been
polished yet, and that is fine.

---

## Phase 4: User Story 2 — The video is good enough to publish (P2)

**Goal**: the video's own layout, at both aspects and at the reader's own typeface and character size, with
a title card, a settled pace and a legible smallest size.

### Tests for US2 ⚠️ (write first, run RED)

- [x] T018 [P] [US2] Extend `test/video_painter_test.dart` from quickstart 8 and 10–12: the title card
      naming the content, both aspects' frames measuring 1920×1080 and 1080×1920 with their own column and
      margins, the painted text's height following the reader's chosen size by its ratio (within 10 %) in
      the chosen typeface, and the smallest size staying above the legibility floor on the narrowest column
      — RED as a compile error (the painter's new API: `languageLabel`, `titleLabelScale`, `minimumEm`,
      `maxColumnFraction`, `VideoFrame.style`), then 12 new tests, all green; 20 in the file, 372 in the suite.
      **SUPERSEDED 2026-09-27 — the geometry, not the whole row.** Its column, its margins and its "both
      aspects" cases measure the withdrawn picture (plan ripple note 7); what survives into T039 is the title
      card (FR-008), the size-ratio case (SC-011) and the legibility floor, now measured against the frame's
      text area. `languageLabelOf` (extracted here into `language.dart`) is untouched and still shared

### Implementation for US2

- [x] T019 [US2] Extend `lib/video_painter.dart`: derive the column's width, its margins and the scale that
      maps the reader's character size from the *frame* (not the phone's screen), paint the title card
      naming the content and its language, and keep the highlight the app's yellow over the reading
      background (FR-008, FR-014, A3)
      — the column is now `min(0.88 × width, height)` wide, centred, with a 10 % margin top and bottom (the
      old rule measured the screen: a 16:9 frame got the same 84 % column as a 9:16 one and a 40-character
      line). A 16:9 frame's column is 1080 px, a 9:16 one's is 950 px: the same rule, two shapes — D6.
      The card's language comes from the plan's first *sentence*, not the content's first paragraph: a video
      that opens at a highlighted sentence names that sentence's language (FR-004/A1). Label map extracted
      to `language.dart`'s `languageLabelOf` and shared with the content list's rows (one naming, two users).
      Legibility floor stated as `minimumEm = 30`; at the smallest size on the narrowest column the frame
      gets 31.7 px per em and 30 characters per line (measured in the test).
      **SUPERSEDED 2026-09-27 — the column rule is replaced by the text area.** The floor's *numbers* stand
      (they are the frame's own scale, which the amendment kept), but the geometry they were measured against
      — a column of `min(0.88 × width, height)` with a band and a window — is the withdrawn picture: T042
      re-derives the text area from the frame and re-measures the floor there
- [x] T020 [US2] Extend `lib/video_renderer.dart`: the pacing — the constant inter-sentence padding, the
      title card's lead-in and the end hold inside their bounds (the hold lasting at least one frame past
      the last sentence's audio), all in whole frames so the file keeps its constant rate
      — the pacing itself already landed with T014 (T007's tests forced the bounds: 400 ms padding, a
      2.5 s card, a 2 s hold, all in whole frames at 30 fps) and row 31 measured it on the device, so US2
      adds the renderer's per-run evidence line instead:
      `klhu render slot=<i>/<n> frame=<f>/<m> kind=<k> frames=<r>`, one per picture written, which is what
      row 32 needs to know where each picture starts. The hold is folded into the last sentence's run, so a
      run covers that sentence's frames *and* the hold — the file's last picture outlives the last audio by
      the hold's own 60 frames (row 31: 642 AAC frames over 27.4 s vs 818 video frames over 27.27 s).
- [x] T021 [US2] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` row
      32 (quickstart 32): a frame extracted at every slot's start, middle and end showing that slot's
      sentence highlighted inside the column with margins and no chrome anywhere, and the page's captured
      picture during the render matching the sentence the renderer reported writing
      — **30/30 checks, both aspects.** Every frame of both files (818/818 at 96×54, 100 % of frames) is the
      app's own look: the band on exactly the sentences' frames and never on the card, nothing at all
      outside the column, and 3 frames per slot at 1920×1080 / 1080×1920 (27/27 each) carrying the app's own
      yellow inside the column. The page's captured picture matched the renderer 4/4 times per aspect, in
      order (`[2, 4, 5, 7]` and `[2, 4, 6, 7]`), each naming the sentence the slot stands for.
      **This row found a US1 bug** — the encoder plugin cached the first picture across `sendFrame` calls,
      so all 818 frames were the title card and no frame in the file ever held the highlight. Row 31's
      `ffprobe` checks passed with it (they are structural); only pixels could see it. Fixed, re-run, clean.
      **SUPERSEDED 2026-09-27 as the row's *claims*, kept as its evidence.** Every check this row makes was
      written for the withdrawn picture (a band on the sentences' frames, nothing outside the column), so it is
      re-cut and re-run by T048 — row 32 as `quickstart.md` now states it. The tick above is what the
      pre-amendment video measured, and the encoder bug it found (deviation 9) stays a finding of that run

*The amendment's own US2 work — `T039` (the painter's rows), `T042` (the rewrite) and `T046` (the renderer's frames) — belongs to this phase and is cut in **Phase 7** by the ordering rule stated there.*

**Checkpoint**: the video is publishable-shaped — both aspects, the reader's own text, a titled opening and
a paced close — and US1 still passes unchanged. *What "unchanged" means here*: US1's Dart tests pass exactly
as they did (372/372, nothing edited), while US1's *device* output was defective until row 32 caught it (the
encoder wrote the title card for the whole video, deviation 9) — its structural numbers were right all along,
its look was not, and row 32 is now the row that reads it. *And "nothing edited" needs a date on it as of
2026-09-27*: the amended picture rewrites the **painter's** rows (T039/T042, the file T010/T018 built) and
re-cuts row 32 (T048). US1's own tests — the timeline, the renderer, the encoder — are still unedited, and the
painter's rewrite is the amendment's declared cost, not drift.

---

## Phase 5: User Story 3 — The video is mine to watch, keep, share and delete (P3)

**Goal**: the file's life cycle. A finished render is played before anything is decided; keeping puts it in
the gallery; sharing hands it to the phone's own list; a kept video is reachable again and its deletion
warns first.

### Tests for US3 ⚠️ (write first, run RED)

- [x] T022 [P] [US3] Write `test/video_record_test.dart` from quickstart 19–24 and 39, against the
      record contract: keep writing one entry and replacing the previous file (write-then-delete), throwing
      a render away touching nothing kept, sharing working before and after keeping without implying it, a
      record whose file is gone being reported and forgotten, deleting warning first (dismissing changes
      nothing, confirming removes file and entry), and the app's existing content delete still warning
      — **DONE 2026-09-26.** RED first as a compile error (8 errors naming `VideoRecordStore`,
      `VideoReview` and the page's missing seams), then **13/13 green**. The file defines the record's and
      the review's seam over the REAL file system and the REAL store; the platform is a fake that records
      what it was asked, so "keep was called with the first file's uri as `previousUri`" is a fact about
      this file. Two deviations from the task's own wording, both deliberate: (1) rows 20/22/23/24's
      *page-level* halves — the warning a delete raises, the content's offers, the "gone" message — are
      asserted in `reading_view_video_test.dart`, which owns the page's harness; duplicating that harness
      here (engine, encoder, reader, real-IO pumps) would have cost more than it proved. Row 39's case does
      live here, and it asserts the existing dialog through its own l10n strings rather than English
      literals. (2) Row 39's dialog needs the real-IO pump window (`loadPageContent`), not `pumpAndSettle`,
      which never settles behind the screen's spinner.
      The store's tolerance rules got three cases of their own (missing key, malformed entries dropped
      without a rewrite, a value that is not an object at all) — the contract's read rules, which no
      quickstart row names.
- [x] T023 [P] [US3] Extend `test/reading_view_video_test.dart` from quickstart 28–29: the video action
      offered only from idle and absent where the platform cannot render, and the review pointing the player
      at the working copy with keep / throw away / share all offered and nothing kept yet
      — **DONE 2026-09-26** (the tests; their page half is T029, so this file is RED until it lands, which
      is the order TDD asks for). Ten new cases: the review's player source and its three actions; keeping,
      which consumes the working copy and leaves the content with the video; throwing the render away;
      keeping again (the page half of row 19); a kept video's share; the delete that warns and only deletes
      when confirmed; a video removed outside the app (the page half of row 22); the action's idle-only
      rule across READ/SPEAKING/PAUSED/EDIT; the unavailable platform; and leaving an undecided review.
      **Two changes to the file's harness, both forced by the new seams**: `pageWith` now injects a
      `PageFileStore` and a `PagePlayer` (the page asks the platform whether it can render at all, so a
      test with no fake would see the real channel answer "no" and lose the action every existing case
      relies on), and `RecordingEncoder.finish` now WRITES the working copy it names, so "keeping consumed
      the working copy" is a fact about the file system rather than about a string. The file's existing
      eight cases keep their own expectations untouched, which is what T030's row 30 receipt re-checks.

### Implementation for US3

- [x] T024 [US3] Implement `lib/video_record.dart`: the store keyed by content (`video_record`, a JSON map),
      tolerant of missing, malformed and stale entries, with one entry per content and the lookup rule that
      forgets a record whose file is gone (contract `video-record-format.md`)
      — **DONE 2026-09-26.** `VideoRecordStore` (lookup / keep / delete) over `shared_preferences`, with
      `KeptVideo` as the entry and `VideoLookup` answering *what* it found and *whether an entry had to be
      forgotten as stale* — the second field is what lets the page say "this video is gone" instead of
      showing the same silence as "nothing was ever kept". Reading never rewrites what it could not parse
      (asserted by comparing the raw stored string before and after). `delete` answers whether the file is
      gone and forgets the entry either way, which is the contract's write rule 2: a failed removal is
      reported, and the next lookup finds the video gone.
- [x] T025 [US3] Implement `lib/video_review.dart`: the working copy with its facts and the three decisions
      (keep promoting it through the store, throw away deleting it, share handing it over), and the cleanup
      rule that leaving undecided keeps nothing
      — **DONE 2026-09-26.** `VideoReview` carries the working copy's path, the content it came from and the
      name its library entry will take, and its three decisions go through the record and the platform:
      `keep()` promotes through `VideoRecordStore.keep` and then lets the working copy go, `share()` hands
      the *working copy's* path over and writes nothing, `throwAway()` deletes it. The "leaving undecided"
      case is the absence of any write: the page calls `throwAway()` on the way out, and the review itself
      never writes the store outside `keep`.
- [ ] T026 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoFileStore.kt` and its manifest
      entries: keeping through `MediaStore` on API 29+ and the public Movies directory plus a media scan
      below (with `WRITE_EXTERNAL_STORAGE` capped at `maxSdkVersion="28"`), the `FileProvider` entry and
      paths resource for sharing a working copy, the share intent, deletion, existence, and availability
- [ ] T027 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoPlayerView.kt` and register it:
      the platform view over the framework's own player with its transport controls, per
      `contracts/video-player-protocol.md`, refusing anything that is not a local file
- [ ] T028 [US3] Implement `lib/platform/video_player.dart`: the Dart side of the playback view (the widget
      and its channel), used by the review and by a kept video's playback
      — **PART DONE 2026-09-26 — and only this**: the module exists and compiles — the `VideoPlayer` seam
      (`view(context, source)` + `stop()`), its `PlatformVideoPlayer` over `AndroidView`
      (`klhu/video_player_view`) and the `klhu/video_player` channel. What is NOT done is its consumer: the
      page does not inject or use it until T029 wires the review, so nothing proves the view appears
      anywhere yet.
      A decision to argue with: the contract's method table names play / pause / position / duration as well
      as stop, but the transport belongs to the platform view's own controls (the contract says so itself),
      so only `stop()` is exposed in Dart — the page's one decision about playback is to release it when the
      review is left. The other four would be surface with no consumer.
- [x] T029 [US3] Wire the file's life into `lib/reading_view.dart`: the REVIEW state (the player, keep,
      throw away, share), the kept-video actions on the page (play, share, delete-with-its-warning), the
      stale-video message, and the content offering to record again after a deletion
      — **DONE 2026-09-26, verified here 2026-09-27** (this session only read it; the tick was owed because the
      commit landed after the previous handback). The wiring is present and green: the review state and its
      player (`reading_view.dart:1220`), the three decisions (keep `:1145`, share `:1156`, the warned delete
      `:1172`), the stale-video message (`:1056`), the aspect prompt (`:1257`), and the kept-video actions
      (share `:1685`, delete `:1690`). Evidence: `flutter test --concurrency=2` → **395 passing, 0 failing**,
      which includes `reading_view_video_test.dart`'s ten review cases that T023 wrote RED; `flutter analyze`
      clean. What T029 does **not** cover and T030 still owns: nothing here is exercised on the device.
- [ ] T030 [US3] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` row
      33 (quickstart 33): play the review before keeping, throw one away and keep another, find it in the
      gallery under the content's name, share it through the phone's list, delete it behind the warning, and
      find it gone with the content offering to record again

**Checkpoint**: all three stories are independently demonstrable, and the file's whole life — working copy,
kept, shared, deleted — is exercised on the device.

---

## Phase 6: Polish & cross-cutting concerns

- [ ] T031 [P] Commit the walk driver `specs/012-reading-video/scripts/klhu_walk_video.py` (rows 31–36, plus
      rows 41, 42 and 49 from the 2026-09-26 amendment, one function per row, argv dispatch,
      `RESULT: PASS|FAIL`, importing 010's device helpers) and record every row with its evidence and
      divergences in `specs/012-reading-video/breakpoint.md`
- [ ] T032 [P] Run spike S2 per `specs/012-reading-video/quickstart.md` row 36 and replace the placeholder in
      `specs/012-reading-video/spec.md`: measure a one-minute render end to end on the reference device (wall
      time, frames per second, which side is the bottleneck) and put the measured number into SC-006 and into
      quickstart row 36 — the spec keeps ≤ 5 minutes only until this runs. *The amendment changed the economy
      this number is measured on*: a frame is now produced per sentence (and per line step of a tall one)
      rather than per repaint of the page, and painting a picture under it adds one image decode per range —
      the measurement stands, the shape it measures does not
- [ ] T033 [P] Update `README.md`: the 012 row in the spec index (drop any "spec only" wording) and the note
      that this is the repository's first feature with a platform-specific half
- [ ] T034 Tick the boxes in `specs/012-reading-video/tasks.md`, recording every deviation from this list
      inline beside the task it belongs to (a divergence found is written down where it was found) — including
      the 2026-09-26 amendment's re-cut, whose tasks (T036–T048) are appended rather than renumbered
- [ ] T035 Run the structural rows in `specs/012-reading-video/quickstart.md` (37–40) and write the final
      report: quickstart 37 (`file_selector` is the one dependency added, on the reader's file-picker decision),
      38 (four ARBs, the picture keys included), 39 (the content delete still warns) and 40 (011's receipt still
      green, with its `android/`-is-empty row scoped to 011), then report what shipped, the receipt, the
      measured S2 number, the measured scrim depth and contrast (S4), and — restated, not buried — the iOS gap
      and the pre-existing platform-floor gap
---

## Phase 7: The amended picture (2026-09-26) — US2's rewrite and US4's pictures

**Goal**: the reader picks pictures from the phone's own gallery before a render starts; the video draws
them behind the sentence, each filling the frame, with the scrim between the picture and the text — the frame's
own background colour at D16's measured 55 % — so the words still read; the schedule is each picture's
**inclusive start and end frame** in the video's own
numbering, equally shared for this cut, and no pictures is a valid schedule. Beside it, US2's frame is
rewritten: one sentence per frame at the reader's own size, wrapped and scrolled a line at a time when it
is taller than the text area (FR-002/FR-014/FR-025–FR-029).

**Why this phase is last in the file and not last in the build**: the format checker requires the task ids
to run `T001..T048` in file order, and the rows above keep their numbers because a tick is the record of
what was built and measured at the time — so every task the amendment adds takes the next number and is
appended here. **In build order it sits between Phase 4 and Phase 5**: the spikes first, then the amended
US2 work beside US4's, then Phase 6's close-out (`T034`/`T035`) last of all. The insertion point is stated
in `## Dependencies & ordering` so the numbering cannot be read as the build order.

### Setup (T036 — Phase 1's own work)

- [x] T036 [P] [US4] Add the pictures' message keys to the template `lib/l10n/app_en.arb` and the three
      translations `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hans.arb`, `lib/l10n/app_es.arb` — the "choose
      pictures" action, how many are chosen, choosing again, and the picker's own failure — then
      `flutter gen-l10n` and confirm the diff is exactly the four ARBs plus the regenerated
      `lib/l10n/app_localizations*.dart` (ripple note 3). *Added 2026-09-26 with the amended picture*: the
      pictures have no UI without these strings, and the template key must exist before T041's page cases
      compile against it. **This task belongs to Phase 1** and is cut here by this phase's ordering rule, above
      (DONE 2026-09-27: `videoPicturesButton`, `videoPicturesChosen` with an ICU plural on `{count}`,
      `videoPicturesChooseAgain`, `videoPicturesFailed` in all four ARBs (84 → 88 keys, parity both ways),
      `flutter gen-l10n`, and the diff is exactly the four ARBs plus the four regenerated
      `app_localizations*.dart`; `flutter analyze` clean, `l10n_keys_test.dart` green, the suite re-run
      **395 passing, 0 failing**)

### The two spikes, before anything is written (T037, T038)

- [ ] T037 [US4] Run spike S3 into `specs/012-reading-video/breakpoint.md` (quickstart 41): on
      `emulator-5554`, through the app's own file dialog, browse into a folder, pick two or three pictures and
      record what comes back — what a pick *is* here, whether its bytes can be read once right after choosing,
      how long copying a handful of full-resolution files takes, and what a cancel leaves behind. *Re-cut
      2026-09-27: the dialog is the FILE picker, not the photo one (D15, the reader's decision).* *Added 2026-09-26 with the amended picture*, and it
      gates T042/T045: if the URIs are not stable the copy into the working directory (D15) is mandatory
      rather than merely careful, and that verdict rewrites those two tasks' text instead of being absorbed.
      **This task belongs to Phase 2**, before the batches below
      (2026-09-27: **BLOCKED** — the emulator's `/sdcard/DCIM` and `/sdcard/Pictures` are both empty, so there
      is nothing to pick, and no channel yet opens a picker (T044/T045 are what S3 gates). Cheapest honest
      route: run S3 as T044's first cut instead of gating it — see breakpoint row 41)
- [x] T038 [US4] Run spike S4 into `specs/012-reading-video/breakpoint.md` (quickstart 42): composite a bright,
      a mid and a dark photo under a 40 % black scrim with both of the app's text colours and measure the
      text-to-background contrast each way. *Added 2026-09-26 with the amended picture*, and it gates T039's
      contrast case and T042's painter: every pairing must measure at least 4.5:1 (SC-004), and any pairing
      below it changes the design (a glyph shadow or a deeper scrim, research D16) rather than lowering the
      floor. **This task belongs to Phase 2**, beside T037 (sequential with it: one evidence file)
      (RAN 2026-09-27 → `breakpoint.md` row 42: **the 40 % black layer does not hold** — the app's own text
      colour `#161D1C` misses 4.5:1 for every photo tone below ~205 (200 → 3.88:1, mid grey → 2.03:1), because
      a black veil moves the picture toward a text that is nearly black; the app has **one** text colour, not
      two, so D16's "both of the app's text colours" is wrong too. The direction and depth are a design call:
      recorded in row 42 with the measured options, deliberately **not** absorbed into T039/T042 until chosen).
      Then measured on the reader's own four pictures at both aspects, through
      `specs/012-reading-video/scripts/probe_scrim_stills.dart` (kept beside S1's probe; outside `test/`): the
      40 % black layer leaves **42–100 %** of the glyph pixels under 4.5:1, 45 % **2–42 %**, 50 % **0.4–27.5 %**
      (51 % in one portrait crop) — and a **55 % veil of the frame's own background passes everywhere, 0 % under
      the floor, min 4.90:1**, because that veil's floor *is* the background's own 4.90:1, i.e. it passes by
      construction for any picture. 60 % reaches 5.77:1. Stills and `measurements.tsv`:
      `~/Documents/GitHub/Multi-Media/klhu_scrim/`)

### Tests ⚠️ (write first, run RED — T039–T041)

- [ ] T039 [US2] Rewrite the rows of `test/video_painter_test.dart` from quickstart 7–12 and 44–46: the frame's
      text is the slot's sentence alone at the reader's own size (no band, no window, no other sentence's text),
      the wrapped-and-stepped-by-line case for a sentence taller than the text area, the picture filling the
      frame with the scrim between it and the text — the frame's own background colour at D16's measured 55 % —
      the plain background when nothing is scheduled, both
      aspects' frames and text areas, the reader's size honoured with no shrink, and no chrome — *added
      2026-09-26 with the amended picture*: T006's and T018's rows are **replaced**, not extended (ripple note
      7), and the contrast case uses T038's measured scrim depth. Run it RED before T042
- [ ] T040 [P] [US4] Write `test/video_pictures_test.dart` from quickstart 43 and 48: the equal-share schedule
      in the video's own frames (inclusive ranges that partition the video, more pictures than frames, an empty
      schedule), the picks' copies into the render's working directory, their cleanup after a finish, a cancel
      and a failure, and a picture that cannot be copied failing the render before any frame is written —
      *added 2026-09-26 with the amended picture* (D15). Run it RED before T043
- [ ] T041 [P] [US4] Extend `test/reading_view_video_test.dart` from quickstart 47: the page names how many
      pictures are chosen and lets the reader choose again, the render starts only on the reader's own confirm,
      and choosing none still renders the plain-background video — *added 2026-09-26 with the amended picture*.
      Run it RED before T047

### Implementation (T042–T047)

- [ ] T042 [US2] Rewrite `lib/video_painter.dart` to the amended picture: delete the highlight band, the page
      window and the column mapping (with one sentence in the frame there is nothing to highlight and nothing
      to scroll to), and paint instead the sentence alone at the reader's own size inside the frame's text
      area, wrapped over as many lines as it needs and stepped upward one line at a time by the elapsed
      fraction of the slot (D14) — with the scheduled picture drawn to fill the frame and the scrim over it:
      the frame's own background colour at D16's measured 55 % (T038), and the plain background where nothing is
      scheduled (FR-027/FR-028). The title
      card, the frame size and the style-as-a-parameter seam stay — *added 2026-09-26 with the amended picture*:
      this is the rewrite T010's row declared, not an extension of it
- [ ] T043 [US4] Implement `lib/video_pictures.dart`: the schedule builder (equal shares of `totalFrames` in the
      order chosen, each picture's **inclusive** start and end frame — FR-026), the copies of the picks into the
      render's working directory before pass 2 reads them, and their cleanup with the working copy however the
      render ended — *added 2026-09-26 with the amended picture* (D15). It consumes the picker's own seam
      (T045) rather than declaring one
- [x] T044 [US4] `pubspec.yaml` gains `file_selector: ^1.1.0` with the comment that says why: the picker's
      platform half is **flutter.dev's own plugin**, not Kotlin of ours — no `PicturePickerPlugin.kt`, no
      channel, no activity result, no new permission, no gallery screen (D15). *Re-cut 2026-09-27 on the
      reader's decision*: the **file** dialog rather than the photo picker, because the reader's pictures are
      files made on the phone, on a PC or by an AI tool, and the file dialog is the one selection UI with
      folders that every target the app builds for has (Android, iOS, desktop, web). (DONE 2026-09-27:
      `flutter pub get` → 11 packages changed, the seven `file_selector*` ones and their transitive peers,
      `flutter analyze` clean, nothing added under `android/`) — *added 2026-09-26 with the amended picture*
- [x] T045 [US4] Implement `lib/platform/picture_picker.dart`: the picker seam's Dart half — the `PicturePicker`
      interface the page and the tests fake, plus `FilePicturePicker` over `file_selector`, whose per-platform
      `XTypeGroup` carries what each platform accepts (`uniformTypeIdentifiers` on iOS/macOS, `extensions` on
      Windows, extensions **and** `mimeTypes` on Android/Linux — the plugin throws on a filter a platform cannot
      honour) and whose pick is a `PickedPicture` of a name and a one-shot `read` of the bytes, so no uri, blob
      or path ever leaves the seam — *added 2026-09-26 with the amended picture*. (DONE 2026-09-27:
      `flutter analyze` clean; **not** device-verified — T037 answers what it actually returns, and the interface
      is what the tests fake until then)
- [ ] T046 [US2] Extend `lib/video_renderer.dart` to the amended picture: produce one `RenderedFrame` per
      visual state — the slot's sentence, its line step, and the picture covering it — so the scroll's line
      steps and each picture range's first frame are their own frames with their own repeats (Σ repeats still
      equals `totalFrames`), and copy the chosen pictures before pass 2 reads anything (T043), while the audio
      pass, the pacing and the cancellation stay exactly as they are — *added 2026-09-26 with the amended
      picture* (D14/D15)
- [ ] T047 [US4] Wire the pictures into `lib/reading_view.dart`: the choose-pictures step before a render starts
      (the picker, how many are chosen, choosing again, the picker's failure), the picks held for the render and
      not remembered after it, and the schedule handed to the renderer beside the aspect prompt — the page's
      shipped behaviour untouched (FR-018) — *added 2026-09-26 with the amended picture*

### Device row (T048)

- [ ] T048 [US4] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` rows 32
      and 49 (quickstart 32, 49): re-walk row 32 against the amended picture — every sampled frame carrying its
      slot's sentence alone at the reader's own size, the long one scrolled and never shrunk or split — then
      choose three pictures from the phone's gallery and render, checking each range's frames against each seam
      (the picture filling the frame behind the sentence, the scrim, 4.5:1 against what is behind the text) and
      a no-picture render producing the plain-background video. The driver gains rows 41, 42 and 49 (T037/T038
      own 41 and 42), and every claim lands in `breakpoint.md` — *added 2026-09-26 with the amended picture*

**Checkpoint**: US2's amended frame and US4 are complete and independently demonstrable — a reader picks
pictures from their own gallery, the video carries each one behind the sentence with the scrim over it,
a tall sentence is never shrunk and never split, and choosing none still produces the video the feature
would have made without them (SC-021).

---

## Dependencies & ordering

- **T001 → everything**: the ARB keys are what the widget tasks compile against.
- **T002 → all implementation** (the baseline), **T003 → T014** (S1 decides how the audio's length is read).
- **US1 → US2 and US3**: US2 refines the painter US1 introduces; US3's keep depends on a file existing.
  Within US1: T009/T010/T011 → T013 → T014 → T015 → T016, with T012 alongside T011.
- **The amended picture's chain (2026-09-26)**: T036 → T041/T047 (the picture keys are what those cases compile
  against); T037 → T044/T045 (S3 says whether the copy is mandatory and what a URI can be read for);
  T038 → T039's contrast case and T042's scrim depth; T039 → T042 (the file's rows are the RED for the rewrite);
  T040 → T043 → T046 (pass 2 reads the copies T043 makes); T041 → T047; T042/T046/T047 → T048, whose rows read
  what the painter, the renderer and the page produce. T043 consumes T045's seam, so those two are sequential;
  T044 is Kotlin and independent of both.
- The `[device]` rows (T017, T021, T030, T037, T038, T048 and the driver they live in, T031/T032) come after the
  code they exercise, and are the only coverage the Kotlin half has (Status).
- **Where Phase 7 runs**: between Phase 4 and Phase 5 in the build order — its spikes before its test and
  implementation batches, and before Phase 6's close-out. Its place at the end of the FILE is the id-sequencing
  rule (`T001..T048` in order), not its place in the work.
- **T034/T035 last of all**: the report quotes receipts, not intentions — including Phase 7's.

## Parallel opportunities

- The five US1 test files (T004–T008) are separate files with no dependency between them: one pass, all RED.
- T012 (the three fakes) and T013 (the channel client) touch different files and can go side by side.
- US2's tests (T018) can be written while US1's implementation is still in progress, as long as they are run
  RED before T019/T020 land.
- The two US3 test files (T022, T023) are independent of each other.
- T031–T033 are three different artifacts (the driver, the spec's number, the README).
- The amendment's test tasks are on separate files — T039 (`test/video_painter_test.dart`), T040
  (`test/video_pictures_test.dart`) and T041 (`test/reading_view_video_test.dart`) can go side by side, and all
  RED before the implementation batch. T044 (Kotlin) can go beside the Dart tasks; T043 waits on T045.
- T037 and T038 are **not** parallel with each other even though the spikes are independent: both append to
  `specs/012-reading-video/breakpoint.md`, and two writers to one evidence file are sequential by construction.

## Implementation strategy

**MVP first**: T001–T017 give a working video of a content's reading with the reader watching it being made
— the whole of US1 and the reason the feature exists. Ship that, walk it on the device, then add US2's look
and US3's life cycle. Do **not** start US3's file store before US1's render is green end to end: the file's
life cycle is trivial once a file exists and unknowable before.

**Ordering rule inside each story**: write that story's tests, run them RED, then implement. A story's
device row is its acceptance test — a story is not done because its unit tests pass.

**The amendment's increment (2026-09-26, Phase 7)**: T036–T048 walk the same ladder again on the new picture — the ARB
keys and the two spikes first (S3 and S4 decide the two things the code may not guess: what a pick from the
file dialog can be read for, and how deep the scrim must be), then the three test files RED (T039–T041), then the
painter (T042), the pictures and their copies (T043), the picker (T044/T045), the renderer's frames (T046) and the page (T047),
then the device rows (T048). US3's remaining work (T026/T027/T030) is independent of it in files except
`lib/reading_view.dart`, which T047 and T029 both edit — so the two land one after the other, never together.

**What to do when the platform half misbehaves**: the Kotlin half is the part with no unit tests, so a bug
there is found by a device row, and the fix belongs in Kotlin (not as a workaround in Dart). If a workaround
in Dart seems necessary, that is a signal the split in D4 is wrong — report it rather than papering over it.

## Notes

- `[P]` is about files, not attention: `lib/reading_view.dart` is edited by T016, T029 and T047 in that order,
  `lib/video_painter.dart` by T010 and then T042 (the rewrite), and `lib/video_renderer.dart` by T014, then
  T020, then T046. `test/reading_view_video_test.dart` is edited by T008, T023 and T041.
- **The amended picture's own note**: a frame is now painted once per sentence and once per **line step** of a
  tall one, and a picture range needs its image decoded once — so the economy is measured on a different shape
  of work than row 31's numbers were, and T032 re-measures it rather than inheriting them.
- **The picks are copies**: after T043 the render's working directory holds the pictures beside the per-sentence
  audio and the working copy, and all three must be gone after any ending — quickstart 48's cases assert the
  copy's own life, and T048 asserts the directory on the device (which is where row 34's check now reads it).
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
| FR-002 each frame carries the sentence being spoken, alone and whole at the reader's own size | T039, T042, T048 |
| FR-003 the voice is the app's own synthesis, per paragraph's language and chosen voice | T011, T014 |
| FR-004 start at the highlighted sentence, else the content's first; run to the last | T004, T009, T014 |
| FR-005 the text in the frame is the sentence whose voice is heard, and no other sentence's text | T039, T042, T048 |
| FR-006 the frame is the video's own — no chrome, no device UI, never a recording | T015, T039, T042, T048 |
| FR-007 the aspect/resolution chosen before the render, exactly as chosen | T005, T009, T017 |
| FR-008 a title card naming the content; a hold at the end | T020, T039, T042 |
| FR-009 progress and cancellation; nothing left behind | T007, T014, T017 |
| FR-010 the action is idle-only and a touch never interrupts | T008, T016, T023 |
| FR-011 a kept video lives where the galleries look, under the content's name | T026, T029, T030 |
| FR-012 keeping again leaves exactly one video for that content | T022, T024, T026 |
| FR-013 produced on the device — no account, no backend, no upload, no network | T015, T026, T035 |
| FR-014 the video's text is the reader's typeface and size — never shrunk, wrapped and scrolled when tall | T039, T042, T046 |
| FR-015 an empty content is refused with the existing message and no file | T004, T014 |
| FR-016 pacing follows the voice, within the stated bounds | T004, T020 |
| FR-017 the audio is complete, in order, nothing dropped or repeated | T004, T007, T011 |
| FR-018 the reading page's shipped behaviour is untouched | T008, T016, T047, T035 |
| FR-019 the render owns the page; Stop asks first | T008, T016, T029 |
| FR-020 the page shows the video's own picture — the amended frame — as the render's progress | T007, T014, T046, T048 |
| FR-021 a finished render is played, then kept, thrown away or shared | T022, T023, T025, T029 |
| FR-022 a kept video is reachable again, and deleting it removes file and record | T022, T024, T029, T030 |
| FR-023 sharing through the platform's own list; no SDK, no account, no upload | T022, T026, T028, T030 |
| FR-024 deleting warns first, and never on a single tap | T022, T026, T029, T030 |
| FR-025 the reader chooses pictures from the phone's own gallery before a render, and sees what is chosen | T036, T037, T041, T044, T045, T047 |
| FR-026 each chosen picture occupies an inclusive run of the video's own frames, shared equally | T040, T043, T046, T048 |
| FR-027 a picture fills the frame it is in, with the scrim between it and the text — the frame's own background colour at 55 %, which holds 4.90:1 over any picture | T038, T039, T042, T048 |
| FR-028 no pictures chosen — and any frame outside every range — is the app's plain background | T040, T042, T048 |
| FR-029 a sentence too tall for the frame is drawn whole at the reader's own size, wrapped and scrolled by line | T039, T042, T046 |
| SC-001 a reader makes a video in the app, no network, and is told the file's name and length | T017, T031 |
| SC-002 it plays start to end: one video stream, one audio stream, the duration within 2 s | T017, T031 |
| SC-003 the text in a frame is the sentence being spoken, in 100 % of samples, and no other sentence's | T039, T048 |
| SC-004 no frame carries the app's controls or the device's UI, margins on all sides, 4.5:1 over the scrim | T038, T039, T042, T048 |
| SC-005 publishable-shaped, verified with a media analyser rather than by eye | T017, T031 |
| SC-006 the render's time on the reference device, with cancellation leaving nothing | T017, T032 |
| SC-007 a mixed-language content is voiced per paragraph exactly as the page voices it | T004, T007 |
| SC-008 two renders leave exactly one video for that content, and it is the second | T022, T030 |
| SC-009 the reading page behaves exactly as 011's receipt shows | T008, T035 |
| SC-010 with a highlight the video starts there; otherwise at the first sentence; always ends last | T004, T014 |
| SC-011 two renders at two sizes differ by their ratio, in the chosen typeface, never below the reader's size | T039, T042 |
| SC-012 each aspect measures as rendered (1920×1080 / 1080×1920) at the constant rate | T005, T017 |
| SC-013 while rendering only Stop is reachable; both Stop and leaving ask before acting | T008, T016 |
| SC-014 the picture shown during the render is the frame being written, page and file agreeing | T007, T014, T046, T048 |
| SC-015 a review plays before anything is kept; keep, throw away and share each land as stated | T022, T025, T029, T030 |
| SC-016 a kept video is reachable, playable, shareable and deletable; a stale record is reported gone | T022, T024, T029 |
| SC-017 the share list is the device's own, and nothing is uploaded by the app | T026, T030 |
| SC-018 deleting warns: dismissing keeps the video, confirming removes it; the content delete still warns | T022, T026, T030 |
| SC-019 pictures cover the video as scheduled; no frame carries one outside its own range | T040, T042, T048 |
| SC-020 a long sentence is neither split nor shrunk; its whole text is inside its slot's frames | T039, T042, T048 |
| SC-021 a render with no pictures produces the video the feature would have made without them | T040, T042, T048 |
