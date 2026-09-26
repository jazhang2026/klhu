# Implementation Plan: Reading Video

**Branch**: `012-reading-video` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-reading-video/spec.md`

**Grounding corrections**: four statements were checked against the checkout, the plugin sources and the
device before planning, and the plan is written to what they say rather than to what the first draft
assumed.

1. **The audio path exists.** `flutter_tts` 4.2.5 exposes `synthesizeToFile(text, fileName, isFullPath)`
   in Dart (`flutter_tts.dart:376`) and implements it on Android (`FlutterTtsPlugin.kt:343,708`), with a
   completion Future when `awaitSpeakCompletion(true)` is set, carrying the engine's current
   voice/language bundle. A6's "per-sentence audio without capturing playback" is therefore real — but
   the *engine's* ability to write that file is still unverified on this device (research S1).
2. **The app has no platform code today.** `MainActivity.kt` is a bare `FlutterActivity`; this is the
   first feature in the repository to add any (research D4). The spec's A6/A7 declared that in advance.
3. **`minSdk` resolves to 24, not the constitution's 29.** Pre-existing (011's plan reported the same
   gap) and this feature must work with it: the file lands in MediaStore on 29+ and in the public Movies
   directory below that (research D7). Raising the floor would silently drop devices and is *not* done.
4. **The sentence model the timeline needs already exists** (`segmenter.dart`'s `sentenceRanges`, and
   `reader_service.dart`'s `SpokenSentence` carrying paragraph/sentence/absolute span), so the render
   plan is assembled from shipped code rather than from a new splitter.

## Summary

One pipeline, three stories on top of it (FR-001–FR-019).

1. **A content becomes a video of its own reading** (P1, FR-001–FR-006, FR-008–FR-010, FR-013, FR-015–FR-017,
   FR-019): from the page's own start point — the highlighted sentence, else the first — every sentence is
   synthesised to an audio file (the reader's chosen voice per language, the read's own fallback), each
   file's exact length becomes that sentence's slot, the sentence's frames are painted by the same text
   engine the page uses with the highlight on the spoken sentence, and a Kotlin encoder+muxer turns those
   frames and that audio into one mp4. While it runs the page shows the video's own picture advancing —
   the highlight moving sentence by sentence, the text scrolling (FR-020) — beside a single Stop, with the
   text inert and leaving asking first (FR-019).
2. **The video is shaped for watching** (P2, FR-006–FR-008, FR-014, FR-016): the frame carries no app
   chrome and no device UI — it is rendered, never recorded — and its text is the reader's own typeface
   and size mapped onto the chosen frame, opening with a title card and closing on a hold, paced by the
   voice so the picture never drifts.
3. **The video is the reader's** (P3, FR-011, FR-012, FR-021–FR-024): a finished render plays in the app
   before anything is decided, and is then kept, thrown away, or shared through the phone's own share list.
   Keeping is the only thing that puts a file in the device's video library, where it lives under the
   content's name, stays reachable from that content for playing, sharing or deleting — deleting warns first
   and cannot be undone — and is replaced rather than duplicated when it is re-rendered.

## Technical Context

**Language/Version**: Dart `^3.13.3`, Flutter 3.47.5 stable. Platform half: Kotlin 2.4.0, JVM target 17
(measured from `android/settings.gradle.kts:23`, `android/app/build.gradle.kts:43`).

**Primary Dependencies**: none added. The feature uses what is installed — `flutter_tts ^4.2.3`
(`synthesizeToFile`, F1), `shared_preferences ^2.5.5` (the remembered aspect and the kept-video record,
D6/D11), `path_provider ^2.1.6` (the working copy's directory), and the Android framework's own
encoders/muxer/library and its own video player (research D12). Sharing a *not yet kept* video needs a
readable URI and uses AndroidX's `FileProvider`, which is already resolved transitively for this app (F10)
— **no dependency line is added**, no video package, no `share_plus`. **No ffmpeg on the device, no
network** (FR-013/FR-023, constitution IV).

**Storage**: two new `shared_preferences` keys (`video_aspect` for the remembered format, `video_record`
for which content owns which kept video), the working copy and the pass-1 per-sentence audio under the
app's cache directory, and kept files in the device's video library (research D7/D11). Every temporary
artefact is cleaned up on success, on cancellation, and after a review decides (FR-009/FR-021).

**Testing**: `flutter test --concurrency=2` (F9) and `flutter analyze` on the host against a fake engine
and a fake encoder (research D9), plus a new walker script
(`specs/012-reading-video/scripts/klhu_walk_video.py`) whose device rows assert on the produced file with
the host's `ffprobe` (F6) — stream shape, frame size per aspect, constant frame rate, duration against
the audio sum, and a frame extracted at each slot's boundaries. Per constitution III each story's tests
are written and seen failing before its implementation.

**Target Platform**: Android (validated on the `klhu` AVD, API 36) for the capability itself — the encoder,
the file store and the player view are all "this platform" work; iOS from the same Dart codebase once its
platform half exists (research D8/D12 — declared gap, not silent).

**Project Type**: mobile app — one Flutter project (`lib/` + `test/`, six platform directories), with the
first platform-specific half this repository has had.

**Performance Goals**: the render is offline and CPU-bound; the pass-2 loop must emit frames at least as
fast as the reference device can encode them. Its cost is measured before any budget is claimed (research
S2). The reading page itself gains nothing measurable until a render starts (SC-009).

**Constraints**: on-device only, no account/backend/analytics (constitution IV, FR-013/FR-023); no second
text engine (the frames come from the page's own `TextPainter` seam, research D2); platform code isolated
under `lib/platform/` and its Kotlin counterpart, carrying no app logic (research D4); **keeping is the
only thing that writes into the video library** (FR-021) and cancellation must leave no file and not
disturb a kept video (FR-009/FR-012); the Stop control and the review's three actions meet the 44 pt
target, and the player's picture is reachable by TalkBack as the video it is.

**Scale/Scope**: one new platform half (3 Kotlin files + a registration in `MainActivity` and a
`FileProvider` entry in the manifest), ~7 new Dart files, ~35 new localization keys across the four ARBs
(en/es/zh/zh_Hans) and their regenerated `app_localizations*`, one new aspect store and one new kept-video
record, two new states on an existing screen (rendering and review), ~6 new test files, one new walker
script. The shipped content set (three pre-sets) is the validation corpus.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle (as the constitution names it) | Gate | Verdict |
|---|---|---|
| **I. Flutter Single Codebase** | One codebase ships to both platforms; platform-specific forks only where a capability is unavailable in the shared plugin, and platform code isolated under `lib/platform/` | **PASS with a declared gap.** No shared plugin encodes video, so the capability is the constitution's own exception. The Dart side lives under `lib/platform/` (`video_encoder.dart`, the channel protocol) and the Kotlin side under `android/app/src/main/kotlin/...`, carrying no app logic (D4). The iOS half is **not written** (no macOS on this host) and the action reports itself unavailable there — reported to the user, per D8, not hidden |
| **II. Spec-Driven (NON-NEGOTIABLE)** | spec → plan → tasks under `specs/` before implementation | PASS: `specs/012-reading-video/` holds the reviewed spec (all clarifications answered), this plan, `research.md` (F1–F11, D1–D13, spikes S1/S2), `data-model.md`, five contracts and `quickstart.md` (40 rows); `tasks.md` is the next stage |
| **III. Test-First (NON-NEGOTIABLE)** | Tests written and seen failing, then implementation; every story has an independent acceptance test on the emulator | PASS by plan: each story's `[unit]` rows are written and run RED first against the fakes (F3), and each story has `[device]` rows in the walker, ending in host `ffprobe` assertions on the produced file (D9). The Kotlin half's coverage is those rows only — stated, not glossed |
| **IV. On-Device First** | On-device text and TTS; no account/backend/analytics; any network use declared | PASS: everything happens on the device — the audio is the installed engine's own file synthesis, the frames are painted locally, the encoder is the platform's. No network use at all (FR-013) |
| **V. Simplicity (YAGNI)** | No speculative machinery; the smallest thing that satisfies the spec | PASS: **no new dependency** (no ffmpeg build, no video or sharing package), no new route, no new screen, no queue, no format matrix beyond the two aspects the spec asks for, no second text engine. What the reader's four follow-ups added (the preview, the review, the record, the sheet) is requested behaviour, not speculation: the preview is the frame the renderer already produced (D2), the record is a `shared_preferences` map beside the two stores that already exist, and the player is a platform view over the framework's own player rather than a package (D11/D12) |
| **Constraints: TTS via `flutter_tts` (or equivalent declared in plan)** | Declare the TTS mechanism | PASS: `flutter_tts` stays the only TTS path, used in its file-synthesis mode (F1) — the same engine, the same per-language voice resolution as the read (D5) |
| **Constraints: iOS 16+ / Android 10+ (API 29+) — "confirm in plan"** | Confirm the project's floors | **GAP (pre-existing, plus one deliberate branch)**: the build resolves `minSdk` to 24 and iOS to 15.0, as 011's plan already reported. This feature does not raise either floor; it branches on API level so the file still lands in the gallery on 24–28 (D7). Reported to the user |
| **Constraints: accessibility, 44 pt targets, VoiceOver/TalkBack** | New controls meet the target and keep the semantics contract | PASS by design: Stop is an `IconButton` (48 pt) with a tooltip; the render's picture (FR-020) is announced as a progress picture with the sentence being written, not left as an unlabelled image; the review's keep/throw-away/share actions are labelled buttons with the 44 pt target; and every confirmation uses the same `AlertDialog` shape as the page's existing one (F8) so TalkBack reads it as the app's other dialogs |

**Post-design re-check (after Phase 1)**: the design settled on one pipeline (D1/D2/D3) and one platform
half with no logic in it (D4), which is what keeps principle V and the testability stance intact. Nothing
in the design moves a principle; the two items that need a human decision are the iOS gap (D8) and the
pre-existing floor gap — neither of which a design choice inside this feature can close.

## Project Structure

### Documentation (this feature)

```text
specs/012-reading-video/
├── spec.md                        # reviewed (specify + clarify)
├── plan.md                        # this file
├── research.md                    # facts F1–F9, decisions D1–D10, spikes S1/S2
├── data-model.md                  # VideoAspect, RenderPlan/Slot, RenderedFrame, KeptVideoRecord, VideoReview, the page's states
├── quickstart.md                  # 40 validation scenarios, tagged [unit]/[device]/[structural]
├── contracts/
│   ├── video-frame-protocol.md    # Dart → platform: start / frame / finish / cancel + the timeline's audio segments
│   ├── video-file-protocol.md     # Dart → platform: keep / share / delete / exists / availability
│   ├── video-player-protocol.md   # Dart → platform: the playback view (the review, and later plays)
│   ├── video-aspect-format.md     # the persisted aspect choice (the 011 appearance-format shape)
│   └── video-record-format.md     # the kept-video record: which content owns which file
├── checklists/
│   └── requirements.md            # the spec-quality gate (all items ticked)
├── scripts/                       # created at the implement stage
│   └── klhu_walk_video.py         # the device rows, one function per scenario, argv dispatch
├── tasks.md                       # created by the tasks stage
└── breakpoint.md                  # created at the implement stage (PASS/FAIL rows + divergences)
```

### Source Code (repository root)

```text
lib/
├── platform/                      # NEW directory — the constitution's home for platform halves
│   ├── video_encoder.dart         # NEW  the encoder interface + the channel client (protocol: contracts/)
│   ├── video_player.dart          # NEW  the playback view widget + its channel (the review, and later plays)
│   └── video_availability.dart    # NEW  whether this platform can render (D8: iOS reports no)
├── video_renderer.dart            # NEW  the orchestrator: timeline, pass 1 (audio), pass 2 (frames), cancel
├── video_painter.dart             # NEW  one frame: the column, the highlight, the title card — the page's own text engine
├── video_aspect.dart              # NEW  the aspect choice and its remembered store (D6)
├── video_record.dart              # NEW  which content owns which kept video, and its staleness rules (D11)
├── video_review.dart              # NEW  the working copy and its three decisions: keep, throw away, share (D11)
├── reader_service.dart            #      `synthesizeToFile` on the engine seam + the voice resolution reused (D5)
├── reading_view.dart              #      the RENDERING and REVIEW states, the aspect prompt, the confirmations (D10)
└── l10n/                          #      four ARBs (+~30 keys) and the 4 regenerated app_localizations*

android/app/src/main/kotlin/com/example/klhu/
├── MainActivity.kt                #      registers the channel and the player view (today: a bare FlutterActivity)
├── VideoEncoderPlugin.kt          # NEW  the channel + MediaCodec (AVC/AAC) + MediaMuxer, no app logic (D4)
├── VideoFileStore.kt              # NEW  the working copy, keeping it, replacing it, deleting it, sharing it (D7/D11)
└── VideoPlayerView.kt             # NEW  the platform view over the framework's player (D12)
android/app/src/main/AndroidManifest.xml   #  WRITE_EXTERNAL_STORAGE maxSdkVersion="28" + the FileProvider (D7/D11)

test/
├── video_timeline_test.dart       # NEW  quickstart 1–6: slots from the segmenter, durations, start point, the hold
├── video_painter_test.dart        # NEW  quickstart 7–11: a frame per slot, the highlight, both aspects, no chrome
├── video_renderer_test.dart       # NEW  quickstart 12–17: order, per-sentence voice, the picture shown, cancel leaves nothing
├── video_aspect_test.dart         # NEW  quickstart 18: the remembered choice's rules
├── video_record_test.dart         # NEW  quickstart 19–22: keep/throw away/share, replacement, staleness, delete
├── reading_view_video_test.dart   # NEW  quickstart 23–27: the RENDERING state, the review, the confirmations, unavailable platforms
├── reader_service_test.dart       #      the engine fake gains `synthesizeToFile` (signature + one case)
├── cantonese_dialect_test.dart, spanish_localization_test.dart #  same fake, signature only
└── (unchanged)                    #      the remaining 25 files; see the ripple notes

specs/011-reading-experience/quickstart.md #  row 18 asserts `git status --short android/` is empty — true for
                                           #  011 only; this feature's rows own that assertion from now on
```

**Structure Decision**: the layout the six earlier specs already use, plus the one directory the
constitution reserves for platform halves. `lib/` keeps one file per concern at its top level
(`<concern>_store.dart`, `<concern>_screen.dart` — now `<concern>.dart` for the pipeline pieces), and the
Dart half of the platform channel is the only thing under `lib/platform/`. The Kotlin half sits beside the
existing `MainActivity` in the Android app's own source set.

**Ripple note 1 — the engine seam**: adding `synthesizeToFile` to the interface at
`reader_service.dart:116-153` reaches the three fakes that implement it
(`test/reader_service_test.dart`, `test/cantonese_dialect_test.dart`,
`test/spanish_localization_test.dart`). By the 011 precedent these are signature additions, and one of
them gains a case; the implement stage settles which by reading each fake, not its name.

**Ripple note 2 — the page's state machine**: the reading page's tests enumerate what its toolbar offers
per state (`reading_view_test.dart`, `reading_view_pause_test.dart`, `reading_view_continue_test.dart`,
`reading_view_follow_test.dart`). A RENDERING state is a new row in those enumerations, so the existing
expectations are **extended**, never rewritten; if any of them turns out to pin "exactly three states",
that is a correction to report, not a quiet edit.

**Ripple note 3 — localization**: ~35 new keys land in all four ARBs (en/es/zh/zh_Hans) and the
`app_localizations*` files are regenerated, exactly as 011 did. A key added to fewer than four ARBs is a
test failure waiting to happen, not a shortcut.

**Ripple note 4 — the empty-`android/` assertion**: 011's quickstart row 18 asserts `git status --short
android/` stays empty. That row was about 011 adding no platform code and remains true of 011; it is not a
repository-wide invariant, and this feature's rows assert the opposite (`android/` **is** modified, by
design). No existing row is deleted; the new ones state their own scope.

**Ripple note 5 — the page's two new states and the new record (added 2026-09-25)**: the reader's four
follow-ups put a review beside the render (FR-021) and a record beside the aspect store (FR-022). Both
land on the reading page rather than a new route, so the state enumerations in ripple note 2 grow two more
rows and the tests' fakes grow a record and a player. `video_record.dart` mirrors the two stores the app
already ships (`ReadPositionStore`, `AppearanceStore`): a `shared_preferences`-backed map, tolerant of
missing and stale entries, unit-tested without a device. The working copy's cleanup rules (success,
cancellation, and after the review decides) are the one place a leak could hide, so the device rows assert
the cache directory is empty afterwards as well as that the library holds what it should.

**Ripple note 6 — every destructive action warns (added 2026-09-25)**: FR-024 is the reader's rule that the
delete of a video — and the app's other delete — must warn. The video's warning reuses the shape the app
already ships for deleting a content (F11: a titled dialog with the "cannot be undone" line, Cancel and a
filled Delete), so the implement stage adds ARB keys in that shape rather than a second dialog idiom, and
the validation rows assert both deletes warn (the video's, and the content's still doing so). The rule is
stated once, in the spec, so a later feature cannot quietly drop it.

## Complexity Tracking

Two things are introduced that the constitution makes a reviewer look at, and both are named rather than
absorbed:

1. **Platform-specific code, Android only.** Justified by constitution I's own exception (the shared
   plugin set cannot encode video) and by the spec's A6/A7. The Dart half is isolated under `lib/platform/`
   and the Kotlin half carries no app logic (D4), so the fork is in *mechanism* only: every decision the
   spec makes is taken in shared code and tested there. The same half also hosts the playback view (D12).
   The iOS half's absence is reported (D8), not hidden behind a silently missing control.
2. **The API-level branch for where the file lands (D7).** Justified by the pre-existing gap between the
   resolved `minSdk` (24) and the declared baseline (29): raising the floor would drop devices, and a
   single `MediaStore`-only path would fail on 24–28 with no way to notice on this emulator (API 36).
