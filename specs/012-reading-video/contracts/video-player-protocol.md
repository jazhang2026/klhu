# Contract: the playback view (Dart → platform)

**Feature**: `012-reading-video` | **Dart side**: `lib/platform/video_player.dart` | **Kotlin side**:
`VideoPlayerView.kt` | **Spec**: FR-021, FR-022 | **Decisions**: D12

The video is watched inside the app — at the review, and later from the content's kept-video actions — so the
keep / throw-away / share decision stays on one screen (FR-021).

## The view

A platform view registered as `klhu/video_player_view`, created with:

| Parameter | Type | Meaning |
|---|---|---|
| `source` | `String` | the video's path (a working copy) or its library URI (a kept video) |

The view hosts the platform's own player with its own transport controls (play/pause/seek), so the app does
not re-implement a scrubber; the Dart side lays out where the picture goes and puts the reader's decisions
beside it.

## Methods (`klhu/video_player`)

| Method | Returns | Notes |
|---|---|---|
| `play()` | `void` | starts or resumes |
| `pause()` | `void` | |
| `stop()` | `void` | also releases the player; called when the view goes away |
| `position()` | `int` (ms) | for showing where playback is; the view's own controls also seek |
| `duration()` | `int` (ms) | the file's length |

## Rules

1. **No network**: the source is always a local file or a local library URI. Anything else is refused rather
   than handed to the player (FR-013).
2. **A vanished file is reported, not played**: if the source no longer resolves, the view reports it and the
   page says the video is gone, forgetting the record (FR-022). No spinner-then-silence.
3. **Playback never changes the file**: watching a video does not keep it, does not write the record, and
   does not touch the content or the reading position.
4. **Leaving stops playback**: disposing the view (leaving the review or the page, or deleting the video while
   it plays) stops the player and releases it.
5. **Availability**: where `isAvailable()` is `false` (D8), the view is not built at all and no action offers
   it.
