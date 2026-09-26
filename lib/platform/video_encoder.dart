/// The render's platform half: the encoder and the file store, as the app sees
/// them (spec 012 contracts `video-frame-protocol.md`, `video-file-protocol.md`).
///
/// Two interfaces, both narrow on purpose (research D4): the Kotlin side gets
/// frames as pictures and audio as files and knows nothing about text,
/// sentences, languages or voices, so every decision worth testing stays in
/// Dart. Nothing here needs a device to be tested — the renderer is tested
/// against fakes of these.
library;

import 'dart:typed_data';

/// One stretch of the video's audio, in the order it is heard.
///
/// [path] is a file the engine wrote (null means silence: the title card and the
/// end hold). [durationUs] is how long this stretch occupies in the video —
/// derived from the timeline's FRAMES, not from the audio file: the frames are
/// the muxer's clock, and the encoder pads the decoded audio to match.
class VideoAudioSegment {
  const VideoAudioSegment({required this.path, required this.durationUs});

  final String? path;
  final int durationUs;
}

/// The file the encoder produced.
class VideoFile {
  const VideoFile({
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
  });

  final String path;
  final int durationMs;
  final int sizeBytes;
}

/// The encoder refused, or could not finish, what it was asked for.
class VideoEncodeException implements Exception {
  const VideoEncodeException(this.message);

  final String message;

  @override
  String toString() => 'VideoEncodeException: $message';
}

/// The render's encoder. Sink, not filter: it is handed pictures and files and
/// returns one file.
abstract class VideoEncoder {
  /// Whether this device can encode at all — iOS and a device without the
  /// platform half answer false, and the video action is not offered (D8).
  Future<bool> isAvailable();

  /// Prepares the muxer for a video of [totalFrames] frames at [fps], with
  /// [audio] in order. Must be called before any frame.
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int totalFrames,
    required List<VideoAudioSegment> audio,
  });

  /// One encoded frame's bytes, standing for [repeat] frames of the timeline.
  Future<void> addFrame(Uint8List png, {required int repeat});

  /// Closes the file and returns it. Only a call that returns a [VideoFile]
  /// means a whole video exists.
  Future<VideoFile> finish();

  /// Abandons the render and deletes whatever partial file exists. Safe to call
  /// at any point, including before [start].
  Future<void> cancel();
}

/// The render's file store: the one place a video's life is decided (FR-011,
/// FR-021, FR-022, FR-023, FR-024).
abstract class VideoFileStore {
  /// Whether keeping and deleting videos is possible on this device.
  Future<bool> isAvailable();

  /// Promote [workingPath] into the device's own library under [displayName],
  /// replacing [previousPath] if there is one. Returns the file's new identity.
  Future<VideoFile> keep({
    required String workingPath,
    required String displayName,
    String? previousPath,
  });

  /// Hand the file to the platform's own share sheet: the list of apps is the
  /// device's, and the app uploads nothing (FR-023).
  Future<void> share({required String path});

  /// Remove the file from the library. The warning is the caller's (FR-024):
  /// this does what it is told.
  Future<void> delete({required String path});

  /// Whether the file is still there — the question a kept record is checked
  /// against before it is offered (FR-022).
  Future<bool> exists({required String path});
}
