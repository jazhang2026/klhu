# Tasks: Reading Video

**Feature**: `012-reading-video` | **Date**: 2026-09-25
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contracts**: [video-frame-protocol.md](./contracts/video-frame-protocol.md), [video-file-protocol.md](./contracts/video-file-protocol.md), [video-player-protocol.md](./contracts/video-player-protocol.md), [video-aspect-format.md](./contracts/video-aspect-format.md), [video-record-format.md](./contracts/video-record-format.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no
incomplete dependency), `[Story]` = `US1` (the render, P1), `US2` (the video's own look, P2), `US3` (the
file's life cycle, P3).

## Status

**In progress — re-cut 2026-09-27 to the amended picture.** T001–T025, T028, T029, **T036** (the pictures'
keys), **T038** (spike S4), **T040/T043** (the schedule in the video's own frames and the picks' copies),
**T044** (the picker is flutter.dev's `file_selector`) and **T045** (the picker's seam over it) are done; T026,
T027 and T030 (the file store, the player view and US3's device row) are not.
→ **Closed 2026-10-01**: T026, T027 and T030 are done — row 33 walks the file's whole life with **both
playback steps enabled** (44/44; the run before it 45/45 — one check moves with whether a dump catches the
SnackBar, as row 32's note explains) — and with them T031–T035 (the driver, spike S2, the README, the boxes and the structural rows). All
57 tasks are ticked and the checker is OK. What the stage was genuinely waiting for, in its own words, was
"nothing has played" (T027) and the S2 placeholder; both are answered below and in the rows. The gaps that
remain are not tasks: **iOS** (the feature does not exist there — `isAvailable` false, `ENGINE_UNAVAILABLE`)
and the **API 29 floor** for keeping (written below 29, unexercisable on this API 36 emulator). The 2026-09-26 amendment replaced what a
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
→ **Superseded 2026-10-01: the checker reports `57 tasks (57 done), 15 [P]` and OK.** It was green again only
after T034's three fixes (the `Re-cut` notes off the first lines, T055 filled in, the paths added) — the stale
line above is the reason T034 says "what must not survive is a receipt claiming OK".

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
      **Re-cut 2026-09-29 (T057, D23): the opening title card is withdrawn — the painter has no card branch
      left** (no centred placement, no `titleLabelScale`, no language-label seam), so what it paints is each
      slot's own sentence and the end hold, and the video's first frame is the first sentence's.
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
      **Re-cut 2026-09-29 (T057, D23): the encoder itself is unchanged, but its segment list lost the card's
      silent segment** — a pre-set render is four segments and 743 frames now, where this task's own numbers
      below say five and 818.
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
      **DONE 2026-09-26 — row 31: 31/31 checks; row 34: 25/25.** **Re-run 2026-09-27 on a live emulator:
row 31 31/31, row 33 40/40 (its two playback steps skipped, see T030), row 34 25/25** — and the re-run is
what caught two driver faults the 2026-09-26 numbers had hidden. Both are the same shape, and it is the shape
worth remembering: **a row that leaves the review on screen leaves state the next row inherits, and then
`tap` finds the review's three decisions instead of the page's toolbar.** Row 31 read it as "the render
produced no file" (16/17) and row 34 as a render it could not start — and row 34 then exited through a bare
`return`, so the run printed **7/7 passed** for a row whose subject (stopping a render half way) had not run
at all. Green over a truncated row is worse than red: `return` on a failed tap is now an explicit `check(...,
False)` in that row, and each aspect or review is taken down before the next step. The other side of the same
coin: `dump()` kept a node only when it carried a `content-desc`, which is how Flutter's widgets reach the
tree — another app's window (the phone's share sheet) names its rows in `text`, so a chooser sitting on the
screen read as an empty screen and T030's share check failed twice for a feature that was there all along. The driver was written for these two rows
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
a settled pace and a legible smallest size. *(The title card stood here when this phase was cut; it was
withdrawn on 2026-09-29 — D23, T057.)*

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
      **Re-cut 2026-09-29 (T057, D23): the two card cases are gone from this file** — the case that replaces
      them paints every slot of the plan and asserts the content's name is in none of them.
      (The note sits at the end of this row, not at its head, because the row's first line must name the file
      it touches — `test/video_painter_test.dart` — for the tasks-format checker.)

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
      **Re-cut 2026-09-29 (T057, D23): the card and its language label are painted nowhere any more** —
      `languageLabelOf` has one caller left (the content list) — and the column, the margins and the scale this
      task fixed are unchanged.
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
      **Re-cut 2026-09-29 (T057, D23): the lead-in is gone with the card, so FR-016's lead-in bound is
      vacuous** and the bounds this task fixed are the gap's and the hold's alone.
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
- [x] T026 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoFileStore.kt` and its manifest
      entries: keeping through `MediaStore` on API 29+ and the public Movies directory plus a media scan
      below (with `WRITE_EXTERNAL_STORAGE` capped at `maxSdkVersion="28"`), the `FileProvider` entry and
      paths resource for sharing a working copy, the share intent, deletion, existence, and availability
      — **PART DONE 2026-09-27 (updated the same day, second pass)**. **`keep` has now run on the device**,
      through the app's own Save: the file appeared in `Movies/Klhu/` under the content's own name, the
      record holds `content://media/external_primary/video/media/39`, the bytes the host pulled are the
      render's own (1335708 B, byte-for-byte), and the kept file probes as H.264/AAC 1920×1080 30 fps with
      exactly the render's 818 frames. `isAvailable` also ran (the app offered the video action at all,
      which it does only when the channel answers true). **Still unexercised: `share`, `delete` and
      `exists`** — the walk that would have covered them died with the emulator (see T030). First pass:
      the file exists and the app **builds and installs with it**
      (`flutter build apk --debug` clean, the APK on `emulator-5554`, and `dumpsys package com.example.klhu`
      shows the provider at the authority `com.example.klhu.fileprovider`, which is the one the code asks
      for). Written: the whole channel (`isAvailable`/`keep`/`share`/`delete`/`exists`), `keep` through
      `MediaStore` on API 29+ (insert with `IS_PENDING`, cleared only once the bytes are complete, and the
      pending entry deleted if the bytes fail) and through the public `Movies/Klhu` directory below it,
      with the media scan's *own* uri taken as the record's uri so share/delete/exists speak one language
      across API levels; **write-then-delete** for a replacement (FR-012); `share` through a chooser with
      `FLAG_GRANT_READ_URI_PERMISSION`, a kept video by its library uri and a working copy through
      `FileProvider` (D11/D13); `delete` answering whether the file is gone rather than whether this call
      removed it; `exists` by opening the uri. **What is NOT proven**: no line of it has executed — the
      device walk (T030) is what proves it. Two known gaps, stated rather than hidden: (1) below API 29 the
      storage permission is *asked* on the first keep and that keep fails with the reason, so an old device
      needs a second tap (a request-and-wait flow was not built); (2) the legacy path cannot be exercised at
      all on this API 36 emulator, so `keepInMovies` is written from the contract and untested here
      **CLOSED 2026-10-01 — the three calls it could not reach ran on the device** (row 33, with the two
      player steps enabled): `share` handed the kept file to the phone's own chooser (`['Sharing 1 file',
      'Quick Share', 'Drive', 'Maps', 'Messages', 'Photos', …]`) and changed neither the album nor the library;
      `delete` answered behind its warning — Cancel deleted nothing, confirming removed the file from
      `Movies/Klhu/` **and** its MediaStore entry, which is what `exists` then reported; and the content offered
      to record again, with play and delete gone. `isAvailable` and `keep` were already green (same row). Still
      unexercised, and stated as such: the below-API-29 `keepInMovies` path, which this emulator cannot run.
- [x] T027 [US3] Implement `android/app/src/main/kotlin/com/example/klhu/VideoPlayerView.kt` and register it:
      the platform view over the framework's own player with its transport controls, per
      `contracts/video-player-protocol.md`, refusing anything that is not a local file
      — **PART DONE 2026-09-27 (updated the same day, second pass)**: the view is **on the screen** — the
      compositor lists a surface of the app's own for it while the review is up
      (`SurfaceView[com.example.klhu/com.example.klhu.MainActivity]`). **Playback itself is still unproven,
      and the walk found out why**: Flutter's accessibility tree stops at the platform view's edge, so
      `uiautomator` never shows the platform's own transport controls (the raw tree holds the page's three
      buttons and nothing of the player), and the driver's blind coordinate taps at the controller bar
      started no sound. Verifying the player wants either a harness that calls the channel directly
      (`position()`/`duration()` after a `play`) or a tap that the platform will answer — this is the open
      piece, not a closed one. First pass: `VideoPlayerView.kt` exists, the app builds and installs
      with it, and `MainActivity` registers both halves of it (the view factory under
      `klhu/video_player_view` and the channel under `klhu/video_player`). Written: a `VideoView` with the
      platform's own `MediaController` (the transport is not re-implemented, which is the point of D12), a
      source that is a local path or a local library uri and **nothing else** (FR-013), the contract's whole
      method table (`play`/`pause`/`stop`/`position`/`duration`), and disposal that stops and releases the
      player — rule 4, which is what keeps a deleted video from playing on. **One thing the build taught**:
      the page's channel is registered *once for the engine* and answered by whichever view is current,
      rather than per view — the four-argument `MethodChannel` constructor takes a `TaskQueue`, not a view
      id, so the per-view shape does not exist; a `stop` with nothing showing is a no-op and answers. **What
      is NOT proven**: nothing has played. The 15 page rows use a fake player, so the view appearing on a
      device at all is T030's and T048's to show
      **CLOSED 2026-10-01 — playback itself is proven on the device at last.** Row 33's two player steps ran with
      `KLHU_SKIP_PLAY` unset: the review's own picture played (`AudioPlaybackConfiguration … u/pid:10216/4565
      state:started … sampleRate=24000` — the render's own audio, and no `MediaPlayer`/`IllegalState` line in
      logcat) and the kept video played the same way from the gallery's own entry. The container is the
      **`TextureView`** T055 introduced. What is still not exercised, and said rather than glossed: pause and
      seek, and the tap that raises the transport bar is still driven blind — Flutter's accessibility tree stops
      at the platform view's edge, so the row reaches the control by where the layout says it is (see
      `play_in_view`).
- [x] T028 [US3] Implement `lib/platform/video_player.dart`: the Dart side of the playback view (the widget
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
      **CLOSED 2026-10-01**: the consumer this row was waiting for is the review T029 wired, and row 33 drove it
      end to end — the picture on screen during the review is the app's own surface, and tapping where the
      platform's transport bar sits starts a real player (both player steps pass in the closing run). The four transport methods
      stay out of Dart: the platform's own controls own the transport, which is the decision this row recorded.
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
- [x] T030 [US3] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` row
      33 (quickstart 33): play the review before keeping, throw one away and keep another, find it in the
      gallery under the content's name, share it through the phone's list, delete it behind the warning, and
      find it gone with the content offering to record again
      — **PART DONE 2026-09-27 — the row is written and its first half has run on the device; the emulator
      died part way through and the rest is open.** The row (`row_33` in the driver, dispatched as `33`)
      does all of it, and it earned its keep before it finished by finding **a real bug in shipped code**:
      the library entry was named after the *file the render wrote* (`klhu_video.mp4`, the same for every
      content) instead of after the content, which FR-011 asks for and which is the whole point of keeping a
      video where the gallery finds it. The page now names it from the content (`'$title.mp4'`), and the
      device confirms it: the record reads `The sun rose over the q….mp4` while the render wrote
      `klhu_video.mp4`. That is pinned by a new unit row (`a kept video is named for the content, not for the
      render`) and by the walk's own `the name is the content's, not the render's own file`. What the walk
      proved on the device before it stopped: the gallery starts empty, the aspect prompt opens with the
      pictures step in it, the render runs and reports itself, the review offers the three decisions and its
      picture is a surface of its own on screen, the kept file is in `Movies/Klhu/` under the content's name,
      its bytes are the render's own, and it probes as a real 1080p video with exactly the plan's frames.
      What it did not reach: `share`, the delete warning and its confirmation, `exists` after a delete, and
      playback (T027's open piece, above). Two driver bugs it found in itself, both fixed: the shell's
      `content query` takes a **colon**-separated projection (`_display_name:relative_path`; a comma is read as
      one column name and refused on stderr, which a stdout-only read sees as "the library has no entries"),
      and the name parse has to tolerate spaces and commas in a content's name; and `pm clear` empties the app
      but *not* the phone's gallery, so a row about the library has to clear the album and its MediaStore
      entries itself, or it can pass on an earlier run's leftovers. **Second run (2026-09-27, same day): 39 of
      40 checks pass, with the two playback steps skipped** — `KLHU_SKIP_PLAY=1` exists because playback is
      this box's memory peak and the emulator dies under it (it died three times: twice at a player step, once
      at the share step). What that run proved on the device, end to end: an empty gallery at the start; the
      aspect prompt opening; the render running twice and reporting itself; the review offering its three
      decisions with its picture as a **surface of its own**; the throw-away leaving the gallery untouched and
      the page saying "Video not saved"; the **keep** putting the file in `Movies/Klhu/` under the content's
      name (the app's record reads `The sun rose over the q….mp4` while the render wrote `klhu_video.mp4` —
      FR-011's fix, confirmed on hardware); the same file as a **MediaStore entry** the gallery finds; its
      bytes pulled back byte-for-byte and probing as H.264/AAC 1920×1080 30 fps with exactly the plan's 818
      frames; the delete warning with its own copy, **Cancel** deleting nothing, and the confirmation removing
      it from both the album and the library, with the content offering to record again and no longer offering
      play or delete. **Third run (2026-09-27): 40 of 40 checks pass** — the share
      "failure" was the driver lying about a screen that was there. `dump()` kept a node only when it had a
      **content-desc**, and that is how Flutter's own widgets reach the tree; another app's window — the
      phone's share sheet — names its rows in `text`, so a chooser sitting on screen read as an *empty*
      screen, and only an absent list could explain it. A label is now either channel, and the same run shows
      the sheet: `['Sharing 1 file', 'Quick Share', 'Drive', 'Maps', 'Messages', 'Photos', …]`. The lesson is
      worth more than the check: **a probe that reads one of two label channels reports present UI as absent,
      and the app gets blamed** — the finding was reported here as an app-side gap for two runs before the
      dump was read properly.
      The driver also grew a preflight: an AVD snapshot restored a **2026-09-14 build** of the app, and half a
      run went into "the app behaves oddly" before the installed package's `lastUpdateTime` explained it — it
      now refuses to walk when the device's app is older than the APK on disk. **To finish**: chase the share
      (with the raw-tree print), and run the two playback steps on a machine that can hold the emulator
      through them
      **CLOSED 2026-10-01 — 44/44 checks, with both player steps enabled** (no `KLHU_SKIP_PLAY`;
      `python3 specs/012-reading-video/scripts/klhu_walk_video.py 33`). The whole life in one run: the gallery
      starts empty; the prompt opens with its pictures step; the render runs and reports itself; the review
      offers its three decisions over a surface of its own; **the review's video plays**; the throw-away leaves
      the gallery untouched and the page saying `Video not saved`; a second render is **kept** — the record names
      it for the content (`The sun rose over the q….mp4` against the render's own `klhu_video.mp4`), the file is
      in `Movies/Klhu/`, its bytes are the render's own (1173771 B) and it probes as H.264/AAC 1920×1080 30 fps
      with exactly the plan's 743 frames; **it plays again from the gallery's own entry**; the share sheet is the
      phone's own and sharing adds and removes nothing; the delete warns, Cancel deletes nothing, and confirming
      empties album and library and leaves the content offering to record again. The emulator held through both
      player steps this time (the box was idle, and the T055 `TextureView` is the lighter container); the escape
      hatch stays for the runs where it does not. Receipt: [breakpoint.md](./breakpoint.md) rows 33 and 34.

**Checkpoint**: all three stories are independently demonstrable, and the file's whole life — working copy,
kept, shared, deleted — is exercised on the device.

---

## Phase 6: Polish & cross-cutting concerns

- [x] T031 [P] Commit the walk driver `specs/012-reading-video/scripts/klhu_walk_video.py` (rows 31–36, plus
      rows 41, 42 and 49 from the 2026-09-26 amendment, one function per row, argv dispatch,
      `RESULT: PASS|FAIL`, importing 010's device helpers) and record every row with its evidence and
      divergences in `specs/012-reading-video/breakpoint.md`
      **DONE 2026-10-01** — the driver is in the tree with eight rows (31, 32, 33, 34, 36, 49 plus hooks for the
      spikes 41 and 42), one function per row, `RESULT: PASS|FAIL`, importing 010's device helpers. The two
      spike rows never needed a function: their answers are measurements, and they live in `breakpoint.md` rows
      41–42, which is what this row's own text allows. Two defects in the driver were found by walking it and
      fixed: `adb shell` joins its arguments with spaces and adds no quotes, so a `cat > <path>` redirection ran
      in the **outer** shell and the first row-33 run silently measured the app's own pre-set text rather than
      the content it pushed (every device command is now one whole string); and the picture dialog does not open
      on a folder — it opens on Files' own `Images` root with no folder rows in it — so row 49 now walks
      roots → storage root → `Pictures/klhu_walk` → the file, the path the reader takes, instead of looking for
      the file in the dialog's "Recent" view.
- [x] T032 [P] Run spike S2 per `specs/012-reading-video/quickstart.md` row 36 and replace the placeholder in
      `specs/012-reading-video/spec.md`: measure a one-minute render end to end on the reference device (wall
      time, frames per second, which side is the bottleneck) and put the measured number into SC-006 and into
      quickstart row 36 — the spec keeps ≤ 5 minutes only until this runs. *The amendment changed the economy
      this number is measured on*: a frame is now produced per sentence (and per line step of a tall one)
      rather than per repaint of the page, and painting a picture under it adds one image decode per range —
      the measurement stands, the shape it measures does not
      **DONE 2026-10-01 — S2 ran on `emulator-5554` and the placeholder is gone.** A 17-sentence content rendered
      as a 1080p30 video of **69.3 s over 2078 frames** (one frame per sentence plus its hold) in **63 s of wall
      clock — 0.9× real time, 33 frames per second**. The bottleneck is the **encoder side**: `send` (the
      texture's frames into `MediaCodec`) 49.6 s of the 63, `synth` (the audio mix) 2.1 s, and Dart's painting of
      all 2078 pictures **0.18 s** — a fraction of a percent, which is the answer FR-021's shape needed. The
      renderer gained the evidence line that says so, once per render: `klhu render time synth=… paint=… send=…
      total=… finish=…`. `spec.md`'s SC-006 and quickstart row 36 carry the measured number; the ≤ 5 minutes the
      spec kept "only until this runs" is retired.
- [x] T033 [P] Update `README.md`: the 012 row in the spec index (drop any "spec only" wording) and the note
      that this is the repository's first feature with a platform-specific half
      **DONE 2026-10-01**: the spec index carries 012 with what it makes, the Features section has its `Video`
      entry, and `### Reading video (012)` is the developer's entry — the walk commands, the evidence to read
      (`klhu render`, `klhu render time`, `AudioPlaybackConfiguration`, `Movies/Klhu/`), the two traps
      (`--concurrency=2` with the emulator up; where the file dialog lands) and the sentence this row asked for:
      the frames are Dart, the encoder and the player are Kotlin, and that half is the first of its kind here.
      The walk-driver list now counts 012's script.
- [x] T034 Tick the boxes in `specs/012-reading-video/tasks.md`, recording every deviation from this list
      inline beside the task it belongs to (a divergence found is written down where it was found) — including
      the 2026-09-26 amendment's re-cut, whose tasks (T036–T048) are appended rather than renumbered — and with
      it **the task-format receipt**: the line at the head of this file's conventions says
      `check_tasks_format.py` reports **OK (48 tasks, 26 done, 15 `[P]`) as of 2026-09-27**, which is now false
      (56 tasks, 47 done), and the same checker reports two problems that pre-date that line — a gap in the id
      sequence (no T055) and the first lines of T049–T057 naming no file path. Either bring the file into the
      checker's shape or record why each stands; what must not survive is a receipt claiming OK. (Found
      2026-09-29 while re-cutting row 32; the checker's own output is quoted in the run below.)
      **DONE 2026-10-01 — the checker is OK and every box is ticked.** `check_tasks_format.py
      specs/012-reading-video` prints `57 tasks (57 done), 15 marked [P]` / `[US1]: 14  [US2]: 11  [US3]: 9
      [US4]: 15` / `OK: format, sequencing and spec-id coverage check out`. Three things had to change to get
      there, each recorded in the row it touched: the twelve `Re-cut` notes moved off their rows' first lines
      (a first line must name the file the task touches, and those rows now carry their path there); the missing
      id was **filled, not renumbered** — the 2026-09-28 `TextureView` work the coverage table's `FR-021` already
      called **T055** was split out of T056, which is now the frame's own look alone; and T049–T054 and T057
      gained the paths of the files they change. The head of this file's conventions carries the corrected
      receipt.
- [x] T035 Run the structural rows in `specs/012-reading-video/quickstart.md` (37–40) and write the final
      report: quickstart 37 (`file_selector` is the one dependency added, on the reader's file-picker decision),
      38 (four ARBs, the picture keys included), 39 (the content delete still warns) and 40 (011's receipt still
      green, with its `android/`-is-empty row scoped to 011), then report what shipped, the receipt, the
      measured S2 number, the measured scrim depth and contrast (S4), and — restated, not buried — the iOS gap
      and the pre-existing platform-floor gap
      **DONE 2026-10-01 — rows 37–40 all pass, and here is the report.**
      *Row 37 (one dependency)*: `pubspec.yaml` gained **`file_selector`** and nothing else; `pubspec.lock`
      gained its platform packages (`file_selector_android/ios/linux/macos/web/windows`, `cross_file`, `http`,
      `http_parser`); `android/app/build.gradle.kts` and `android/settings.gradle.kts` are untouched by this
      feature. No other new package, no network client of ours.
      *Row 38 (four ARBs)*: `flutter test test/l10n_keys_test.dart` green and `git status --short lib/l10n`
      empty — the four ARBs and the generated `l10n.dart` agree both ways.
      *Row 39 (the content delete still warns)*: `test/video_record_test.dart` green, and the walk's first steps
      show the dialog itself.
      *Row 40 (011's receipt still green)*: 011's rows 7, 8, 9, 10, 16 and 17 all PASS on the current build; its
      `android/`-is-empty row is 011's own and is not re-run here (this feature changes `android/` by design).
      *Receipt*: `flutter analyze` clean; `flutter test --concurrency=2` **439 passing, 0 failing**; rows 31
      (33/33), 32 (42/42), 33 (**44/44, playback included**), 34 (26/26), 36 (27/27), 49 (41/41) on
      `emulator-5554`; 011's receipt rows above.
      *What ships*: the reader picks pictures from the phone before a render; a render is a real H.264/AAC MP4
      written on the device, played in the review and playable after it is kept, found in the phone's gallery
      under the content's name, shareable and deletable; and the picture itself — words at the bottom over the
      picture with the tone's own scrim, no title card.
      *The S2 number*: 63 s of wall clock for 69.3 s / 2078 frames of 1080p30 — 0.9× real time — with 96 % of it
      in the encoder's own `send`, and Dart's painting at 0.18 s.
      *S4*: the scrim's depth and contrast are measured and carried in `research.md` (55 % of the picture's
      own background colour at D16) and asserted by the painter's own tests.
      *Not claimed — the two gaps, restated*: **(1) iOS.** `isAvailable` answers false and the entry points
      refuse with `ENGINE_UNAVAILABLE`; there is no encoder, no player view and no file store for iOS, so the
      feature does not exist there rather than existing badly. **(2) The platform floor.** This feature needs
      API 29+ for `MediaStore`-based keeping (the app declares 24, and the below-29 path is written but cannot
      be exercised on this API 36 emulator). Both are pre-existing shapes the spec inherited, not consequences
      of this work.
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

- [x] T037 [US4] Run spike S3 into `specs/012-reading-video/breakpoint.md` (quickstart 41): the driver pushes its
      own pictures into the device's `Pictures/` first — the app bundles none, since with a file dialog the
      reader's own files are the source — then, on
      `emulator-5554`, through the app's own file dialog, browse into that folder, pick two or three pictures and
      record what comes back — what a pick *is* here, whether its bytes can be read once right after choosing,
      how long copying a handful of full-resolution files takes, and what a cancel leaves behind. *Re-cut
      2026-09-27: the dialog is the FILE picker, not the photo one (D15, the reader's decision).* *Added 2026-09-26 with the amended picture*, and it
      gates T042/T045: if the URIs are not stable the copy into the working directory (D15) is mandatory
      rather than merely careful, and that verdict rewrites those two tasks' text instead of being absorbed.
      **This task belongs to Phase 2**, before the batches below
      (2026-09-27: **BLOCKED** — the emulator's `/sdcard/DCIM` and `/sdcard/Pictures` are both empty, so there
      is nothing to pick, and no channel yet opens a picker (T044/T045 are what S3 gates). Cheapest honest
      route: run S3 as T044's first cut instead of gating it — see breakpoint row 41)
      (DONE 2026-09-28 — **the spike's own two questions are answered, and its answer is row 49's walk** rather
      than a separate script: the dialog is the system's Files app in its Recent view, a **long press** opens its
      selection mode, its toolbar reads `N selected` and carries the button that confirms (`Select`), the app gets
      each file's own **name** and one read of its bytes while the grant is alive, and the cost is one file per
      pick on disk for exactly as long as the prompt and its render (measured `[]` → `[]` twice). Recorded in
      `breakpoint.md` under row 41, with the drive's own code in `scripts/klhu_walk_video.py` (`choose_pictures`).)
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

- [x] T039 [US2] Rewrite the rows of `test/video_painter_test.dart` from quickstart 7–12 and 44–46: the frame's
      text is the slot's sentence alone at the reader's own size (no band, no window, no other sentence's text),
      the wrapped-and-stepped-by-line case for a sentence taller than the text area, the picture filling the
      frame with the scrim between it and the text — the frame's own background colour at D16's measured 55 % —
      the plain background when nothing is scheduled, both
      aspects' frames and text areas, the reader's size honoured with no shrink, and no chrome — *added
      2026-09-26 with the amended picture*: T006's and T018's rows are **replaced**, not extended (ripple note
      7), and the contrast case uses T038's measured scrim depth. (DONE 2026-09-27 — 17 cases, and **RED was a
      compile error** naming exactly the new API: `lines`, `scrollLines`, `progress`, `scrimDepth`. The old
      file's 20 cases went with the band — the four "which span is highlighted" rows have no counterpart by
      design (FR-002). Three of the new cases are pixel claims the old file could not make: the scrim's own
      composite over a black picture computed here rather than read from the painter, a 2:1 four-quadrant picture
      in a 9:16 frame whose four corners prove cover-and-crop rather than letterbox, and the first line's own box
      holding ink over the scrim. The scroll case paints every position of a 278-character sentence and asserts
      the whole sentence is drawn at each, that every line is fully on screen at some step, and that a step moves
      the block by exactly one line — with the frames' images disposed as it goes, or the test would hold ~90
      full frames of memory)
- [x] T040 [P] [US4] Write `test/video_pictures_test.dart` from quickstart 43 and 48: the schedule the reader's
      rule allows — pictures sharing the plan's **sentences** equally, each range running from its first
      sentence's own first frame to the frame before the next picture's first sentence, so no boundary falls
      inside a sentence (inclusive ranges that partition the spoken part, the title card left plain, more
      pictures than sentences, an empty schedule) — the picks' copies into the render's working directory, and a
      picture that cannot be copied failing the copy and leaving nothing behind — *added 2026-09-26 with the
      amended picture* (D15), *re-cut 2026-09-27* to the reader's rule.
      (DONE 2026-09-27 — **13 cases, and this row's RED is the part worth reading**: the first cut — equal shares
      of the video's *frames* — was written RED as a compile error, `+0 -1` naming `PictureSchedule`,
      `buildPictureSchedule` and `copyPictures`, and went green after T043; the reader's rule then made those
      shares **wrong**, because a share boundary could fall mid-sentence. The cut was redone, and its RED was two
      real steps: the sentence-based signature failed to compile (`plan` at eight call sites), and then the *old*
      frame-sharing rule was adapted to that signature and run so the new assertions could be exercised — **5 of
      8 schedule cases failed**, naming `a.png starts mid-sentence (0)`, the title card carrying a picture, and
      shares of three sentences where the rule allows two. The sentence-based rule made all 13 green. **Two of this
      row's claims moved to T046**, where they belong: "their cleanup after a finish, a cancel and a failure" and
      "before any frame is written" are the *renderer's* behaviour — it owns the endings and the order of pass 2 —
      so this file asserts what a unit can: every copy is written inside the working directory and nowhere else,
      which is the only thing the renderer's own delete reaches. Written down here rather than left as a row that
      overclaims)
      **Re-cut 2026-09-29 (T057, D23): the schedule's own case now starts at the video's frame 0** — the first
      picture's range begins where the first sentence does, because there is no card's worth of plain
      background before it.
- [x] T041 [P] [US4] Extend `test/reading_view_video_test.dart` from quickstart 47: the page names how many
      pictures are chosen and lets the reader choose again, the render starts only on the reader's own confirm,
      and choosing none still renders the plain-background video — *added 2026-09-26 with the amended picture*.
      Run it RED before T047. (DONE 2026-09-27 — 4 rows, RED first as "No named parameter with the name
      'picturePicker'". Quickstart 47's own name is one of them. The rows: the step is up with nothing chosen
      and says so, offers to choose, then names the count and offers to choose *again* — and never renders
      without the reader's own confirm; the picks reach the frames, checked as a **real pixel** of the first
      sentence's frame (it is not the background, so the picture is behind the text); nothing chosen still
      renders the plain-background video, checked on *every* frame's corner pixel against the page's own
      scaffold colour, exactly; a picker that failed says so with the app's own message, renders nothing, and
      lets the reader try again. **Two traps this row's own red run found, and both would have looked like
      healthy tests.** (1) `pumpAndSettle` never returns on this page — the reader ticks, so the tree never goes
      quiet; the picker's answer lands in a microtask, which is a plain pump. (2) A `testWidgets` body runs on a
      fake clock, and an image decode started inside it never calls back: `await pngOf(...)` in a row's *setup*
      did not fail, it **hung** — the runner reported nothing at all for ten minutes. The fixtures now build
      their PNGs under `tester.runAsync`. 19 rows green in this file, suite **414 passing, 0 failing**,
      `flutter analyze` clean)

### Implementation (T042–T047)

- [x] T042 [US2] Rewrite `lib/video_painter.dart` to the amended picture: delete the highlight band, the page
      window and the column mapping (with one sentence in the frame there is nothing to highlight and nothing
      to scroll to), and paint instead the sentence alone at the reader's own size inside the frame's text
      area, wrapped over as many lines as it needs and stepped upward one line at a time by the elapsed
      fraction of the slot (D14) — with the scheduled picture drawn to fill the frame and the scrim over it:
      the frame's own background colour at D16's measured 55 % (T038), and the plain background where nothing is
      scheduled (FR-027/FR-028). The title
      card, the frame size and the style-as-a-parameter seam stay — *added 2026-09-26 with the amended picture*:
      this is the rewrite T010's row declared, not an extension of it. (DONE 2026-09-27: `paint(slot, progress,
      picture)`, `VideoFrame` carrying `lines` (the drawn boxes), `scrollLines`, `picture` and `scrimDepth`;
      `_TextBlock` lays the text out once for both the paint and the new `scrollSteps(slot)`, which T046 needs to
      know how many pictures a sentence's run holds; the cover-and-crop source rect is the one place the picture's
      shape meets the frame's; a title card that fits stays centred while a sentence sits at the text area's top.
      `content` is gone from `paint` (the slot carries its own text), `highlight` is gone from the painter **and
      from the renderer** — the yellow band was the only reason either had it — with the three call sites
      (`video_renderer.dart`, `reading_view.dart`, `video_renderer_test.dart`'s fixture) updated in the same
      change. 17 painter cases green, `flutter analyze` clean, suite **405 passing, 0 failing** (the old file's 20
      cases became these 17). **What this row does not yet deliver**: the renderer still paints one picture per
      slot, so a tall sentence's scroll does not appear in the rendered video until T046 splits a sentence's run
      into one picture per line step — `progress` is the seam and nothing passes it yet)
      **Re-cut 2026-09-29 (T057, D23): the card's centred branch went with the rest of the old picture** — the
      painter has one placement rule now (a fitting block at the bottom, a taller one stepping down from the
      top) and no frame of the video is centred.
- [x] T043 [US4] Implement `lib/video_pictures.dart`: the schedule builder (equal shares of the plan's
      **sentences** in the order chosen, each picture's **inclusive** start and end frame, no boundary inside a
      sentence — FR-026, *re-cut 2026-09-27 to the reader's rule*), the copies of the picks into the
      render's working directory before pass 2 reads them, and their cleanup with the working copy however the
      render ended — *added 2026-09-26 with the amended picture* (D15). It consumes the picker's own seam
      (T045) rather than declaring one. (DONE 2026-09-27: `ScheduledPicture` (path, inclusive start/end, `frames`,
      `isDrawn`), `PictureSchedule` with `at(frame)` and `none`, `buildPictureSchedule` (the extra **sentences**
      go to the earlier pictures; a picture holding no sentence is undrawn rather than dropping one; the last
      picture runs to the video's own last frame, because the end hold keeps the last sentence and its picture —
      FR-008) and `copyPictures` (one copy per pick, `picture_<i>_<name>`, every copy inside `workDir`, all-or-
      nothing on failure), plus the name rule that keeps a platform's own idea of a filename inside the working
      directory. Two traps are written into the code rather than left to be found: equal sentences are not equal
      frames (a share holding the end hold is the longest), and `VideoSlot.endFrame` is exclusive while a
      picture's range is inclusive, so every boundary is "the next sentence's start minus one". 13 cases green;
      `flutter analyze` clean; suite **408 passing, 0 failing**. The "cleanup however the render ended" is the
      renderer's existing `_delete` reaching a directory it owns — T046 wires the copies into it)
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
- [x] T046 [US2] Extend `lib/video_renderer.dart` to the amended picture: produce one `RenderedFrame` per
      visual state — the slot's sentence, its line step, and the picture covering it — so the scroll's line
      steps and each picture range's first frame are their own frames with their own repeats (Σ repeats still
      equals `totalFrames`), copy the chosen pictures before pass 2 reads anything (T043), paint **one picture per
      line step** for a sentence whose text is taller than the frame — asked of `painter.scrollSteps(run.slot)`,
      each step holding an equal share of that sentence's frames, since the picture shown is the picture written
      and T042's `progress` is the seam that makes it possible (without this the video would show a tall sentence's
      first line for its whole slot) — and carry 48's two
      render-level rows with them — the copies are gone after a finish, a cancel and a failure, because they are
      written into the working directory the render already deletes, and no frame is written before they exist
      (T040 could only assert the unit half: that every copy lands in that directory) — while the audio
      pass, the pacing and the cancellation stay exactly as they are — *added 2026-09-26 with the amended
      picture* (D14/D15). (DONE 2026-09-27 — 5 new rows in `test/video_renderer_test.dart`, RED first as a
      compile error ("No named parameter with the name 'pictures'"), then **the green runs found three real
      things**, which is what this row's tests were for. (1) **A rendering bug**: the painter's step came from
      `position / positions`, and binary floating point cannot represent that exactly — at 31/102 the product
      lands a hair below 31, so one step was painted twice while the next was skipped, and the video jumped.
      Caught by the row asserting the steps are strictly increasing; fixed with a documented epsilon in the
      painter. (2) **A trap for whoever keys by it**: `VideoSlot.sentence` is the sentence's index *within its
      paragraph*, so a content of two paragraphs has two slots with `sentence == 0` — the first version of the
      row's own bookkeeping collided on it. (3) The **end hold** is not a step: the last step absorbs it, so the
      block stops at its bottom and stays there (FR-008). What shipped: `pictures` on the renderer (copied into
      the working directory before pass 2 and recorded in `written`, so a finish, a cancel and a failure all take
      them with the rest); `_stepsOf` splitting each slot's run into one run per line step with equal shares —
      and a step that gets no frame of its own is not written, since it is a picture nobody could see, while the
      shares still add up to the timeline exactly; `_pictureFor` decoding one picture per copy and reusing it for
      the slot's whole run (the schedule changes a picture where a sentence changes, FR-026, so no picture
      boundary can land mid-run); the decoded images are kept for the frames' own lifetime because the reader's
      preview holds them. 22 renderer rows green, `flutter analyze` clean, suite **410 passing, 0 failing**.
      **The cost this row pays**: a 278-character sentence over a 40 s slot renders as 102 pictures instead of 1
      (measured in this fixture) — the frames are still the timeline's length, but the paints are not. T032's S2
      numbers are the thing to check against the device's real time before US4 is called done)
- [x] T047 [US4] Wire the pictures into `lib/reading_view.dart`: the choose-pictures step before a render starts
      (the picker, how many are chosen, choosing again, the picker's failure), the picks held for the render and
      not remembered after it, and **the picks** handed to the renderer beside the aspect prompt — the page's
      shipped behaviour untouched (FR-018) — *added 2026-09-26 with the amended picture*. (DONE 2026-09-27 —
      **the row's own wording was amended here**: it said "the schedule handed to the renderer", but the schedule
      cannot exist before the plan does, and the plan is what the render's own synth pass produces. So the page
      hands the *picks* beside the aspect and the renderer builds the schedule where the plan is (T046). Where
      the step lives is the same reading of this row: **beside the aspect prompt, in one dialog** — the format's
      chips, then the count, the failure line and the choose/choose-again button — so the shipped `Start` stays
      the reader's own confirm and FR-001's "the format is asked for first" still holds (it is the first thing in
      that dialog, and nothing renders until Start). Frozen behaviour of the step: a dialog the reader cancelled
      changes nothing, so "choose again" is always a repick and never a quiet reset; a picker that failed sets
      the app's own message and leaves the choice as it was; the picks belong to the render that reads them and
      nothing holds them afterwards. The page's seam is `picturePicker` (the real `FilePicturePicker` by default,
      a fake in tests); `ReadingView`'s other collaborators are untouched, so the existing 15 rows needed no
      change beyond the shared `pageWith` getting a quiet picker)

### Device row (T048)

- [x] T048 [US4] Device walk on `emulator-5554` per `specs/012-reading-video/scripts/klhu_walk_video.py` rows 32
      and 49 (quickstart 32, 49): re-walk row 32 against the amended picture — every sampled frame carrying its
      slot's sentence alone at the reader's own size, the long one scrolled and never shrunk or split — then
      choose three pictures through the app's file dialog — the driver pushes its own into the device's
      `Pictures/` first, so nothing is bundled and the row cleans them up — and render, checking each range's
      frames against each seam
      (the picture filling the frame behind the sentence, the scrim, 4.5:1 against what is behind the text), that
      no seam sits inside a sentence, and
      a no-picture render producing the plain-background video. The driver gains rows 41, 42 and 49 (T037/T038
      own 41 and 42), and every claim lands in `breakpoint.md` — *added 2026-09-26 with the amended picture*
      **State 2026-09-27**: this row is not re-cut yet, and today's run says exactly where it stands. Row 32
      still reads the renderer's *pre-amendment* line — it looks for `band=<label> range=<start>..<end>`, and
      `lib/video_renderer.dart` now writes `scroll=<lines> picture=<yes|no> span=<start>..<end>` — so its
      "the renderer reported the pictures it wrote" check found **0 runs against a file with 818 frames** and
      every check after it (the runs tiling the timeline, the band on each sentence's frame) was skipped by a
      `continue`. The remaining half of the row was faulted too and is fixed: a review left up from the
      landscape aspect hid the page's toolbar, so the vertical render never started ("the render produced no
      file", 6/8). The two are the same lesson T026's re-run recorded — **a row whose provider of truth has
      changed reports absence, not change** — and it is why the renderer's account has to be *rewritten* onto
      `scroll`/`picture`, with the pixel checks re-anchored to the span the file actually carries, rather than
      have its regex extended. Rows 41, 42 and 49 do not exist in the driver yet.
      **State 2026-09-29 — DONE: rows 31, 32, 33 and 34 re-walked on `emulator-5554`** (`flutter analyze` clean,
      `flutter test --concurrency=2` **440 passing**), and row 32 **re-cut onto the renderer's amended line**
      rather than extended, which is what this task asked for: `render_runs()`/`slot_groups()` now read
      `slot=i/n frame=start/total kind= frames= scroll= picture= tone= span=a..b text=n`, the row's checks were
      re-anchored on it — the band it used to *require* is the thing it now requires to be **absent** — and
      "which sentence is on this frame" is read from the content's own text through the slot's character
      `span=`, not from the app's word for it. **Row 32: 42/42 checks, both aspects** (818/818 frames clean at
      96×54 in each; a fitting sentence's own glyph box ending at the column's bottom, `(206, 924, 826, 964)`
      against 972 at 1920×1080 and `(44, 1686, 592, 1720)` against 1728 at 1080×1920); **row 31: 33/33**,
      **row 33: 42/42**, **row 34: 26/26**, and **row 49: 41/41** (re-walked too, unchanged: eight pictures for
      eight sentences, one range each, the plate's tone over the band the words cover, every glyph box at the
      bottom of the area). Row 33's two playback steps are **skipped and said to be skipped**
      (`KLHU_SKIP_PLAY=1`): the emulator died under them twice in this session (breakpoint deviation 10) —
      the playback itself was proven in the run before the device went.
      **The scroll has no case in this video, and the row says so in its own output**: the pre-set's longest
      sentence is 55 characters and the text area holds it on one line at both aspects, so `scroll` is 0 in
      every run of both files — FR-029's "later lines in later frames" is a **gap on the record** here, its
      branch written and unexercised. **A defect the re-run found, in the walk rather than in the app**:
      SC-001's message is a SnackBar, so reading it off the page is a race the row had been winning by luck
      (it missed in one aspect and caught it in the other, in both orders, across four runs). Measured with the
      probe beside the walk (`probe_snack_life.py`: readable at +2.2 s and +4.3 s after the render's own line,
      gone by +6.4 s), the app now prints the message it showed — `klhu render told: <the message>` — which is
      what the check reads (the file's name and the render's own seconds both required); the page is still read
      and the two must agree when a dump catches it, a run that never catches it prints the times it tried
      instead of failing, and a **still of the page at that moment** (`screencap()`, `$KLHU_OUT/*_told.png`) is
      kept for every render of every row. Receipts: [breakpoint.md](./breakpoint.md) rows 31, 32 and the rows
      33/34 section.
      **Advanced 2026-10-01 — the skipped half is now walked.** Row 33 ran **44/44 with both player steps
      enabled** (no `KLHU_SKIP_PLAY`): the review's video played and the kept video played from the gallery's own
      entry (the third point of this row's own list — "play it from the gallery" — had never actually run before
      today; the earlier session proved playback, then lost the emulator to it, and every run since skipped the
      steps). Row 49 ran **41/41** on top of the driver's corrected dialog walk (T031's receipt: the dialog opens
      on Files' `Images` root, not on a folder), and row 36's spike ran **27/27** for the first time. What this
      row still does not cover, unchanged and stated: the scroll case (no sentence of the pre-set is long enough
      to scroll at either aspect), pause and seek, and the below-29 keep path.

**Checkpoint**: US2's amended frame and US4 are complete and independently demonstrable — a reader picks
pictures from their own files (the file dialog browses folders; the app ships no images), the video carries
each one behind the sentence with the scrim over it, no picture lands or lifts inside a sentence,
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

## Phase 8 — the 2026-09-28 re-cut (the picture's own life, its bound, its order)

*The reader's own follow-ups after using the amended app on the phone: "(a) 保留已选并提示 (b) 底板会与背后区域撞色——
改为只统计文字所在条带； (c) use scrool. small show window, scroll to show others.", then "remove max 20 images
limit. keep all 30 images for now. user can delete images.", then "1. (2) 选图当下落盘到应用私有目录、页面与渲染从
文件读 2. 图多于句子时：show error message! force user to remove images. 3. OK." The new work takes the next
numbers (T049–T054); no earlier tick is renumbered, and the rows a re-cut changes are named in its receipt.*

- [x] T049 [US4] Store every pick at the pick — `lib/video_pictures.dart`, `lib/reading_view.dart` (FR-025, D18,
      SC-024): `HeldPicture` becomes **name + path** —
      the file the app wrote it into — and `storePicks` reads each pick once, while the picker's own read grant
      is alive, writing `pick_<i>_<safe name>` inside a directory of the app's own; the page's thumbnails are
      `Image.file` of those files (still bounded by `cacheWidth`) and the renderer **copies** them into its own
      working directory rather than being handed bytes. The prompt's directory is created before the dialog opens
      and removed in a `finally` around prompt-and-render, so finished, stopped, failed or cancelled all take the
      stored picks with them (FR-025's own "never remembered"). (DONE 2026-09-28 — `HeldPicture{name, path}`,
      `storePicks`, `discardPictures` in `lib/video_pictures.dart`; `copyPictures` copies from the stored file;
      `ChosenThumbnail` reads the file; `_openVideoPrompt` owns the directory. Rows: every pick is written in the
      order chosen, inside the one directory the page owns; a pick nothing can be read from throws **and writes
      nothing** (one file, then a delete of what it wrote — a choice with a hole is not half a choice); the
      directory is removed and removing it twice is not an error; the page's thumbnails are the stored files, by
      path, in order; and the directory is gone once the render is over. `flutter analyze` clean; suite **438
      passing, 0 failing**. **The trap this row paid for**: in the test the thumbnails' provider is a
      `ResizeImage` wrapping the `FileImage` (the decode bound), so an assertion that casts to `FileImage` fails
      on a *correct* implementation — the re-cut's rows unwrap it))
- [x] T050 [US4] Withdraw the cap — `lib/video_pictures.dart`, `lib/video_painter.dart` and the four
      `lib/l10n/app_*.arb` (FR-025, SC-022): delete `maxPictures`, the refusal branch and
      `refusedCount`, and let `mergePicks` be a pure append; delete the l10n key that named the cap from all four
      ARB files and re-run `gen-l10n`. Every picture chosen is kept, and the only way one leaves is FR-030's
      remove. (DONE 2026-09-28 — the reader's own words are the receipt: "remove max 20 images limit. keep all 30
      images for now. user can delete images." Rows: a second pick adds to the first; 12 + 12 = 24 pictures on
      the page, one cell each, in the order chosen, with the count the sum. Analysis clean; suite green.)
- [x] T051 [US4] `lib/reading_view.dart` and the four `lib/l10n/app_*.arb`: a choice larger than the video's
      sentences is silent and startable (FR-026, SC-022) — **re-cut 2026-09-28, by the reader's own phone
      test**: delete the count the prompt resolved
      (`videoSentencesFrom` and the `sentenceCount` it fed), the overshoot message and its l10n key from all four
      ARBs, and the disabled Start — the prompt opens on the remembered aspect and says nothing more. A picture
      that found no sentence is simply not drawn, which is what the schedule always did with one.
      (DONE 2026-09-28 — the reader watched the message on the phone and withdrew it: "超限提示、no need. not
      show." **All three parts of T051 are gone**: the count, the message, the blocked render. The row that used
      to assert the refusal now asserts the opposite — four pictures over three sentences is accepted, each with
      its own cell, Start offered, the render going ahead. The l10n key `videoPicturesOverSentences` is deleted
      rather than left unused, and the page no longer imports `video_timeline` for the count.
      `flutter analyze` clean; suite **439 passing, 0 failing**.) **Two real defects the green runs found**: (1) the prompt's own content grew
      with the message and pushed the Choose/Start buttons outside the dialog's tap area on a short screen — a
      test tap that *missed* found it, not an eye — fixed with `AlertDialog(scrollable: true)` so the content
      scrolls and the actions stay pinned (FR-025's own sentence about the prompt scrolling); (2) the page's own
      test harness drove the prompt's store reads with two `pump`s, which was never enough for a real store read:
      the file's own `letWorkRun` (real event loop) is now what opens the prompt and what lands the storing, with
      the wait written as "the pictures the picker handed over are the pictures on screen" rather than a count of
      pumps. Analysis clean; suite **438 passing, 0 failing**.)
- [x] T052 [US4] `lib/reading_view.dart`: show the chosen pictures in a window two rows tall that scrolls
      (FR-030, SC-023): the cells
      live in a `ConstrainedBox(maxHeight: 152)` around a `SingleChildScrollView` (keyed `video picture
      window`, so the page and its tests can measure and drive it), so thirty pictures are one scroll rather than
      a dialog taller than the screen, and the window's own l10n key says the pictures can be reordered. The
      button that adds pictures is named for what it does — **Choose more**, not "choose again" — because that is
      what it does (FR-031, the reader's own correction from the phone of 2026-09-28), **confirmed on the phone the
      same day**: "按钮改名 fixed". (DONE 2026-09-28 — the
      reader's own answer: "(c) use scrool. small show window, scroll to show others." **Confirmed on the
      reader's own phone the same day** ("小窗口滚动、works"), with the wording and the drag's reach changed as a
      result (T051, T054) Rows: 24 cells are on the page while the window measures its own height, and the window's scroll
      extent is **greater than** its height — the cells do not all fit, which is what the window is for.)
- [x] T053 [US2] `lib/video_painter.dart`: read the plate's tone over the band the words cover
      (FR-027, D16's second amendment): the
      painter lays the text out first, maps each painted line's box back onto the picture's pixels, and reads the
      tone **band by band** (a shared sample budget; the picture's pixels converted once) instead of over the
      whole picture — so a dark photograph whose sentence sits under a bright sky is plated for the strip behind
      the words. The cost is written into the code and the requirement: inside one sentence whose band crosses
      the floor, the plate and the ink may change between line steps. (DONE 2026-09-28 — the reviewer's own point:
      "底板会与背后区域撞色——改为只统计文字所在条带". `toneOfPixels` (pure, band-sampled) and `pictureTone(picture,
      {bands})`. Rows (44-c): a bright picture with a dark band under the text plates dark; a dark picture with a
      bright band plates light; the band's own pixels are the evidence, not the whole picture's average. One real
      defect found on the way: an out-of-range band indexed past the pixel array — fixed by checking the band's
      own width/height before its area.)
- [x] T054 [US4] `lib/reading_view.dart`: let the reader set the order (FR-032, D19, SC-025): holding a picture's own cell and dropping
      it on another picture's cell puts it where it was dropped, the others keeping their places; the cells' order
      is the order the video draws (FR-026), a drop on the picture's own cell changes nothing, and the copy tells
      the reader the order can be changed. (DONE 2026-09-28 — `MovableThumbnail` (`DragTarget` around
      `LongPressDraggable`) and `movePicture` (pure: out of range or in place answers the choice unchanged).
      **Re-cut the same day, by the reader's own phone test, to reach past the visible rows** (D21): the page owns
      the window's own `ScrollController` and a `GlobalKey` on the window, and a hold within 36 pixels of either
      end scrolls it 24 pixels every 80 ms — the first step immediately — until the hold leaves the band or ends;
      `onDragUpdate`/`onDragEnd` carry the finger's position down from `MovableThumbnail`, and the controller is
      disposed with the page. **The phone's receipt, in the reader's own words**: "长按换序, works. but only can
      move in displayed rows. need to able to move out of the disabled rows. use auto scroll." New row: with
      twenty-four pictures chosen, a hold taken past the window's bottom edge scrolls it (the offset read from the
      window's own `Scrollable`) and the picture is then dropped on a cell the scroll brought into view, still 24
      pictures on the page; and its other half — a hold past the window's **top** edge, after a plain drag down —
      scrolls it back and letting go stops it, the direction the reader's own phone confirmed the same day
      ("拖拽自动滚动 fixed up and down"). `flutter analyze` clean; suite **440 passing, 0 failing**.
      Rows: a drop onto another cell lands there; the same move the other way; a drop on itself and a drag from
      nowhere change nothing; the order the reader set is the order the render's copies are written in; and the
      page's own row drives a hold-and-drop through the real dialog. **Two real defects the green runs found**:
      (1) the hold never reached the cell **at all** — an `Image` answers no pointer by itself, so the cell now
      draws a transparent `ColoredBox` as its own hit surface; (2) the corner remove was an `IconButton` whose
      padded tap target is **48×48 on a 72-pixel cell**, so the middle of the cell was the remove and the hold
      landed on it: the remove's `tapTargetSize` is now `MaterialTapTargetSize.shrinkWrap`. **The cost, named**:
      the remove's own touch target is the cross itself (22×22) rather than 48 pixels — the trade that makes the
      whole cell draggable, and the reviewer's point to accept or reject. `flutter analyze` clean; suite **438
      passing, 0 failing**.)

- [x] T055 [US2] `android/app/src/main/kotlin/com/example/klhu/VideoPlayerView.kt`: the review's picture is a
      picture rather than a black surface — replace the `VideoView` with a `TextureView` whose surface is handed
      to the platform's own player (D20, FR-021), so the video the reader watches before keeping it draws. The
      view type, the channel, its five methods, rules 1–5 and the seam above them are unchanged: what changes is
      the container, and with it two things a `VideoView` did for itself — the video's own shape inside the box
      the page gives it (letterboxed, never stretched) and the transport bar appearing on a tap. (DONE
      2026-09-28 — a scratch probe first, because the cause had to be *seen* rather than argued: two temporary
      platform views side by side over one `ffmpeg` `testsrc` clip pushed into the app's own private directory,
      one screenshot read pixel by pixel. The shipped `VideoView` measured **0.98 of its picture area below luma
      30, saturation 0, 2 distinct colours** — the reader's black picture, reproduced on `emulator-5554` — while
      `TextureView` + `MediaPlayer` measured 10 % dark, saturation 255, 273 colours. The view was then rewritten
      (`MediaPlayer` prepared **after** its surface exists; `fitPicture` letterboxing on the texture;
      `MediaController` still driving play/pause/seek through `MediaController.MediaPlayerControl`, so D12's "no
      scrubber of ours" holds and no dependency is added) and measured again through the shipping Dart seam:
      **10 % dark, saturation 235, 189 colours**. The probe's two files (`ProbePlayerViews.kt`,
      `lib/probe_main.dart`) were deleted and `MainActivity` restored. `flutter analyze` clean; suite **438
      passing, 0 failing**; `breakpoint.md` row 54 holds the numbers — and the half this repo could not reach,
      the **reader's own phone**, reported the next thing to be said: the fixed APK on their **LE2115** — the
      device the black picture came from — plays, their own words "play button works on my LE2115 phone."
      **Closed on this repo's own device 2026-10-01**: row 33 walked the review end to end with its two player
      steps enabled — `MediaPlayer` started with no error logged and the kept video played from the gallery's own
      entry (44/44 checks). What is still not claimed: pause and seek were not exercised.)
- [x] T056 [US2] `lib/video_painter.dart`: the frame's own look, by the reader's two requests of 2026-09-28
      (FR-014, FR-029, D22, D6's amendment): **move the text block from the top to the bottom** of the text
      area, and **make a line 1.4×
      the reader's own reading column** so a sentence needs fewer of them. One constant decides the line
      (`lineLengthGain`): the column's height bound is that multiple of the frame's height and the letters divide
      by it, so the extra width is more words rather than bigger ones; where the column cannot grow (a 9:16
      frame, whose column is already 92% of its width) the legibility floor (`minimumEm`, A3) wins and the line
      grows less instead of the words shrinking. A sentence that **fits** is bottom-anchored; a sentence taller
      than the area keeps FR-029's own shape (its first line at the top, scrolling down a line at a time), which
      is why the branch is the block's own `steps` rather than the progress. (DONE 2026-09-28 — the reader's own
      words are the receipt: "1. move text block from top to bottom. 2. make the text line to be longer, will has
      less lines." **The numbers, from the app's own geometry and from a real render**: a 16:9 frame's column
      1080 → **1512** px (`min(0.92 × 1920, 1.4 × 1080)`), the letters unchanged there (42 px at the pre-set's
      size, and on a 9:16 frame **also unchanged** — the letters are measured against their own, unchanged
      fraction of the frame (`lettersColumnFraction`, 0.88) rather than against the wider column, which is the
      reader's own answer when the choice was put to them: "竖屏也保持原来的字大小". The line is where the gain
      lands: 16:9 goes from 1.000× to **1.400×** the letters' own column per line (the column 1080 → 1512 px),
      9:16 from 1.000× to **1.045×** (950 → 994 px) — a portrait frame has only the 4.5% of width it was not
      already using to give, and its sentences wrap much as they did. Both figures are the app's own constants'
      arithmetic, not a measurement. The pre-set's
      own eight sentences are one line each either way (their glyph boxes are 38–40 px tall before and after, with
      identical ink pixel counts), so on this pre-set the change shows as *where* the words are, not how many
      lines: the same frames' boxes moved from y 120–160 to y 924–964, against a text area ending at 972 — read
      off the file's pixels by row 49, which now checks that placement on every range. Six painter tests were
      re-cut to the new geometry (the column rule read from the constants, the fit case's bottom, the margins'
      floor, and the two D16 fixtures whose bands moved to where the words now are). `flutter analyze` clean;
      suite **440 passing, 0 failing**; row 49 **40/40, exit 0**.
      **Split 2026-10-01 (T034): this row used to carry the player view's rewrite as well** — the 2026-09-28
      TextureView work, which the tasks-format checker's own id sequence and the coverage table's `FR-021` already
      called **T055**. The two are separate artifacts (a Kotlin view and the painter) and are now separate rows;
      nothing was renumbered, the missing id was filled in.)

*The device half is still open for all six: no emulator or phone walk has driven the stored picks, the sentence
bound, the window's scroll or the hold-and-drop yet. `scripts/klhu_walk_video.py` needs the new steps before that
walk can be run.*

---

## Phase 9 — the 2026-09-29 amendment (the opening title frame is withdrawn)

- [x] T057 [US2] `lib/video_painter.dart`, `lib/video_timeline.dart`, `lib/video_renderer.dart`,
      `lib/reading_view.dart`: withdraw the opening title card (FR-008's amendment, D23) — the reader's own request, made
      while watching the two renders of 2026-09-28 — *"I want to remove the first title frame. and don't show
      the title in the top of 16:9 video."* The card is **deleted, not hidden**: the video opens on its first
      spoken sentence, and no frame of either aspect carries the content's name or its language.
      Surface removed, in the order the data flows: `VideoSlotKind.title`; `VideoPlan.title` and
      `VideoPlan.titleMs`; the painter's card branch — its centred placement, `titleLabelScale`, the two-span
      name-over-language layout — and its `languageLabel` seam; `VideoRenderer.title` and
      `VideoRenderer.languageLabel`; and `reading_view`'s two arguments to it. The end hold and every other
      2026-09-28 look (the bottom-anchored block, the 1.4× line, the plate over the band the words cover) are
      untouched. **This supersedes the parts of T010, T015, T018, T019, T020, T040 and T042 that describe the
      card as the design or test it as such, and Phase 4's goal line** — each of those now carries a dated
      `Re-cut 2026-09-29` prefix, and they stay as the record of what was built then; what the code holds now
      is this task's shape. (The list first named T036 and left out T015/T040: T036 is the ARB-keys task and
      never mentioned the card, while those two do. T021's two card sentences are that row's own historical
      evidence of the encoder bug and it is already marked superseded, so it stands as written.)
      The unit suite followed rather than being emptied around the change: the plan's own case asserts **no
      slot is a card** and that the video opens on sentence 0 at frame 0 (FR-016's lead-in bound is now
      vacuous); the painter's two card cases became one that paints **every** slot and finds the name in none;
      the renderer's segments lost the card's (`[1400000, 900000, 266666, 2000000]` µs — four runs, not five)
      and its painting pass counts 3 units; the schedule's partition case starts at frame 0 with its
      `[84, 84, 132]` share lengths unchanged (the shares are over sentences).
      (DONE 2026-09-29 — `flutter analyze` clean, `flutter test --concurrency=2` **439/439** (one fewer than
      440: two card assertions became one check). The device rows were re-cut rather than re-run blind:
      quickstart 32's three card checks became **the video opens on sentence 0 at frame 0**, **no run of the
      file is a card**, **one slot per sentence and nothing else — the name is painted nowhere**, the driver's
      slot arithmetic moved with the plan (`slot i` is `sentence i`), and the "words sit at the bottom" pixel
      check lost its card exemption. **The arithmetic the withdrawal is worth, measured on the device**: row 31
      **33/33** both aspects, 743 frames per file (818 − the card's 75) and ffprobe **24.89 s** against the
      render's own 24.77 s — the 2.5 s exactly, and the reader's own message now reads
      `Video made: klhu_video.mp4 (25 s)`. Row 32 **41/41** (both aspects, 8 slots for 8 sentences, every
      sentence's frame carrying its own text alone and every glyph box at the column's bottom), row 49
      **41/41**, rows 33 and 34 unchanged and green.)
      **The cover, settled the same day**: the reader asked whether what they had seen "at the top" was the
      video's cover and whether it carried the content's name — it was and it did, because the app writes no
      cover and the phone derives it from the file's first frame, which was the card. Their decision for now —
      *"use the first image as the video's cover image"* — is what this task already gives, and nothing was
      built for it: with pictures chosen, frame 0 is the first picture with the first sentence's words at its
      bottom (measured off the device's own file: `(253,253,253)` above the words, 438 dark samples in the
      words' band against 6283 white); with none chosen there is no image and the cover is the app's own
      background. A wordless cover slot was put to the reader with its cost and declined for now (D23's cover
      paragraph has the numbers and the reasoning).

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
| FR-014 the video's text is the reader's typeface and size — never shrunk, wrapped and scrolled when tall, on a line 1.4× the reader's own column | T039, T042, T046, T056 |
| FR-015 an empty content is refused with the existing message and no file | T004, T014 |
| FR-016 pacing follows the voice, within the stated bounds | T004, T020 |
| FR-017 the audio is complete, in order, nothing dropped or repeated | T004, T007, T011 |
| FR-018 the reading page's shipped behaviour is untouched | T008, T016, T047, T035 |
| FR-019 the render owns the page; Stop asks first | T008, T016, T029 |
| FR-020 the page shows the video's own picture — the amended frame — as the render's progress | T007, T014, T046, T048 |
| FR-021 a finished render is played — a picture, not a black surface — then kept, thrown away or shared | T022, T023, T025, T029, T055 |
| FR-022 a kept video is reachable again, and deleting it removes file and record | T022, T024, T029, T030 |
| FR-023 sharing through the platform's own list; no SDK, no account, no upload | T022, T026, T028, T030 |
| FR-024 deleting warns first, and never on a single tap | T022, T026, T029, T030 |
| FR-025 the reader chooses pictures from their own files before a render, chooses again to add, is never capped, sees the choice in a scrolling window, and nothing is remembered once the render ends | T036, T037, T041, T044, T045, T047, T049, T050, T052 |
| FR-026 each chosen picture occupies an inclusive run of the video's own frames, shared equally — and a choice larger than the video's sentences is startable and silent, its extras simply not drawn | T040, T043, T046, T048, T051, T052, T054 |
| FR-027 a picture fills the frame it is in with a plate behind each painted line, the plate and ink decided by the tone of the band the words cover — the picture's own colours untouched | T038, T039, T042, T048, T053 |
| FR-028 no pictures chosen — and any frame outside every range — is the app's plain background | T040, T042, T048 |
| FR-029 a sentence too tall for the frame is drawn whole at the reader's own size, wrapped and scrolled by line — and a sentence that fits sits at the bottom of the area | T039, T042, T046, T056 |
| FR-030 the chosen pictures are shown as thumbnails in a window that scrolls, each with its own remove | T047, T052, T049 |
| FR-031 every string is the app's own, and the reader's own actions are named in the reader's own terms (the button that adds pictures says *Choose more*) | T051, T052 |
| FR-032 holding a picture and dropping it on another cell puts it there, that order is the video's, and a hold at either end of the window scrolls it so any cell can be reached | T054 |
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
| SC-022 both picks are held (the count is the sum, nothing capped or trimmed) and a choice larger than the video's sentences is startable and silent, the extras left undrawn | T050, T051 |
| SC-023 one thumbnail per picture in the order chosen, each with its own remove, in a window two rows tall that scrolls | T047, T052 |
| SC-024 the picks exist as files in one directory of the app's own, shown by the page and copied by the render, and the directory is gone once the render is over | T049 |
| SC-025 a hold-and-drop leaves the picture where it was dropped, the others in place, the count unchanged, and a hold at the window's end scrolls it so any cell can be reached — and the render draws that order | T054 |
