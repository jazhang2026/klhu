# Contract: the render channel (Dart → platform)

**Feature**: `012-reading-video` | **Dart side**: `lib/platform/video_encoder.dart` | **Kotlin side**:
`VideoEncoderPlugin.kt` | **Spec**: FR-007, FR-009, FR-020 | **Decisions**: D2, D3, D4

The Dart half owns every decision (which frames, which audio, in what order); the platform half owns only
encoding, muxing and the file. Nothing in this protocol carries text, a voice or a sentence identity — the
frames arrive as pictures and the audio as files.

Channel: `klhu/video_encoder` (a `MethodChannel`; the Dart side's interface is what the tests fake).

## `startRender(spec) → void`

Opens the encoders and the muxer and prepares the working file.

| Field | Type | Meaning |
|---|---|---|
| `frameWidth`, `frameHeight` | `int` | the chosen aspect's frame (FR-007) |
| `fps` | `int` | the constant frame rate (30) |
| `bitrateKbps` | `int` | the encoder's target (the plan's number, measured by spike S2) |
| `totalFrames` | `int` | Σ of `sendFrame`'s repeats — the muxer's expected video length |
| `workingPath` | `String` | where the app wants the working copy written (its own cache directory) |
| `audioSegments` | `List<{path: String?, durationUs: int}>` | in timeline order, covering the whole video: a sentence slot names its pass-1 file and its exact slot length (audio + padding); the title card and the end hold have `path: null` (silence) |

Fails with `RenderFailure` (below) before any frame is sent if the encoders cannot be opened or the working
file cannot be created — the page stays idle and reports it, and nothing is left behind.

## `sendFrame(bytes, repeat) → void`

Hands over one picture and how many frames it stands for (D2's transport: the picture is only re-sent when
the visual state changed).

| Field | Type | Meaning |
|---|---|---|
| `bytes` | `Uint8List` | one frame's pixels, encoded (PNG by default; raw BGRA if S2 forces it) |
| `repeat` | `int` | how many frames of the timeline this picture stands for (≥ 1) |

Ordering: frames are sent in timeline order and one call's `repeat` is exactly how long that picture lasts;
Σ `repeat` across a render = `totalFrames`. The platform half must not reorder, coalesce or drop frames.

## `finishRender() → {path, durationMs, sizeBytes}`

Closes the muxer and returns the working copy's final facts. After this call the file is complete and
playable; the encoders are released. Calling it twice is an error, not a silent no-op.

## `cancelRender() → void`

Stops encoding, releases the encoders, and **deletes the working file** (FR-009). Legal at any point after
`startRender`, including between two `sendFrame` calls; after it, the render is over and a new one must
`startRender` again. A cancel must leave no partial file anywhere (SC-006/SC-013).

## Failures

| Code | When | The reader sees |
|---|---|---|
| `ENGINE_UNAVAILABLE` | the platform cannot render at all (no encoder, or iOS) | the action is not offered; a render that was already started reports it and leaves nothing |
| `CODEC_FAILED` | an encoder or the muxer refuses a frame, a format or a file | the render stops, nothing is kept, the failure is reported (FR-009) |
| `IO_FAILED` | the working file or the audio files cannot be read/written | same |
| `NO_SPACE` | the device is out of space mid-render | same |
| `CANCELLED` | the reader confirmed Stop | the page returns to idle (FR-019) |

## Invariants

- No network use, no account, no SDK — the platform half only touches the device's own encoders and files
  (FR-013).
- A working file exists only between `startRender` and (`finishRender` or `cancelRender`); the app's cache
  directory holds nothing after a render ends, however it ended.
- The channel carries no app state: cancelling a render cannot disturb the content, the reading position,
  the appearance or an already-kept video (FR-009/FR-012).
