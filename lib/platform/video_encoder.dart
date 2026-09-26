/// The render's platform half: the encoder and the file store, as the app sees
/// them (spec 012 contracts `video-frame-protocol.md`, `video-file-protocol.md`).
///
/// Two interfaces, both narrow on purpose (research D4): the Kotlin side gets
/// frames as pictures and audio as files and knows nothing about text,
/// sentences, languages or voices, so every decision worth testing stays in
/// Dart. Nothing here needs a device to be tested — the renderer is tested
/// against fakes of these.
library;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
  /// replacing the file behind [previousUri] if there is one — the new file is
  /// in place BEFORE the old one goes (FR-012). Returns the kept file's own
  /// identity, which is what the record stores.
  ///
  /// A uri rather than a [VideoFile]: the platform knows where the file landed
  /// and what it is called, and the renderer — which owns the duration and the
  /// size — is not the one promoting it (contract
  /// `specs/012-reading-video/contracts/video-file-protocol.md`).
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  });

  /// Hand the file to the platform's own share sheet: the list of apps is the
  /// device's, and the app uploads nothing (FR-023). [source] is a kept video's
  /// uri or a working copy's path.
  Future<void> share({required String source});

  /// Remove the file from the library. The warning is the caller's (FR-024):
  /// this does what it is told. Answers whether the file is gone afterwards —
  /// true also when it was already gone, so a stale record cleans up quietly.
  Future<bool> delete({required String uri});

  /// Whether the file is still there — the question a kept record is checked
  /// against before it is offered (FR-022).
  Future<bool> exists({required String uri});
}

/// The platform's own render channel (`klhu/video_encoder`), speaking the frame
/// protocol in `specs/012-reading-video/contracts/video-frame-protocol.md`.
///
/// Nothing here needs a device to be exercised except the channel itself: the
/// renderer is tested against fakes of [VideoEncoder], and the protocol's own
/// behaviour is what the device rows assert against a real file.
class MethodChannelVideoEncoder implements VideoEncoder {
  MethodChannelVideoEncoder({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'klhu/video_encoder';

  /// The encoder's target, in kbps, for the 1080p frames and 24 kHz mono audio
  /// this feature produces. A constant rather than a per-render knob: no
  /// quality tiers are offered (A8), and spike S2's measurement is what would
  /// retune this number, not a caller.
  static const int bitrateKbps = 8000;

  final MethodChannel _channel;

  /// Where the platform writes the render's own file. The app's cache, never
  /// the device's library: keeping is the only call that writes there
  /// (FR-021), and a cancelled or failed render's file is the platform's to
  /// delete (contract § cancelRender).
  Future<String> _workingPath() async =>
      '${(await getTemporaryDirectory()).path}/klhu_video.mp4';

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      // No platform half on this build (iOS today, D8): not available, and
      // never an error the reader has to see.
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int totalFrames,
    required List<VideoAudioSegment> audio,
  }) async {
    try {
      await _channel.invokeMethod<void>('startRender', <String, Object?>{
        'frameWidth': width,
        'frameHeight': height,
        'fps': fps,
        'bitrateKbps': bitrateKbps,
        'totalFrames': totalFrames,
        'workingPath': await _workingPath(),
        'audioSegments': [
          for (final segment in audio)
            <String, Object?>{
              'path': segment.path,
              'durationUs': segment.durationUs,
            },
        ],
      });
    } on PlatformException catch (e) {
      throw VideoEncodeException(_describe(e));
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no encoder');
    }
  }

  @override
  Future<void> addFrame(Uint8List png, {required int repeat}) async {
    try {
      await _channel.invokeMethod<void>('sendFrame', <String, Object?>{
        'bytes': png,
        'repeat': repeat,
      });
    } on PlatformException catch (e) {
      throw VideoEncodeException(_describe(e));
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no encoder');
    }
  }

  @override
  Future<VideoFile> finish() async {
    final Map<String, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<String, Object?>('finishRender');
    } on PlatformException catch (e) {
      throw VideoEncodeException(_describe(e));
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no encoder');
    }
    final path = result?['path'];
    if (path is! String || path.isEmpty) {
      // No file means no video: a caller must never be handed a path that is
      // not there (contract § finishRender).
      throw const VideoEncodeException(
        'IO_FAILED: the encoder reported no file',
      );
    }
    return VideoFile(
      path: path,
      durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (result?['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> cancel() async {
    // Legal at any point, including before `start`: the platform answers a
    // cancel with nothing open as the no-op it is.
    try {
      await _channel.invokeMethod<void>('cancelRender');
    } on MissingPluginException {
      // Nothing was ever started on this platform.
    } on PlatformException catch (e) {
      // The render is over either way, and the partial file is the platform's
      // own to remove; the renderer treats a failed cancel as abandoned.
      throw VideoEncodeException(_describe(e));
    }
  }

  /// The platform's failure, named by the frame contract's own code
  /// (`CODEC_FAILED`, `IO_FAILED`, `NO_SPACE`, `ENGINE_UNAVAILABLE`,
  /// `CANCELLED`) so a failure in the field says which one it was.
  String _describe(PlatformException e) =>
      '${e.code}: ${e.message ?? 'the encoder refused'}';
}

/// The platform's file channel (`klhu/video_files`), speaking the file protocol
/// in `specs/012-reading-video/contracts/video-file-protocol.md`.
///
/// Used by US3's review and by a kept video's actions; nothing in US1 calls it.
class MethodChannelVideoFileStore implements VideoFileStore {
  MethodChannelVideoFileStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'klhu/video_files';

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  }) async {
    final Map<String, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<String, Object?>(
        'keep',
        <String, Object?>{
          'workingPath': workingPath,
          'displayName': displayName,
          'previousUri': previousUri,
        },
      );
    } on PlatformException catch (e) {
      // The file cannot be written where the phone's players look: nothing is
      // kept, and the reader is told (contract § keep).
      throw VideoEncodeException('${e.code}: ${e.message ?? 'keep failed'}');
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no file store');
    }
    final uri = result?['uri'];
    if (uri is! String || uri.isEmpty) {
      throw const VideoEncodeException('IO_FAILED: kept file has no uri');
    }
    return uri;
  }

  @override
  Future<void> share({required String source}) async {
    try {
      await _channel.invokeMethod<void>('share', <String, Object?>{
        'source': source,
      });
    } on PlatformException catch (e) {
      throw VideoEncodeException('${e.code}: ${e.message ?? 'share failed'}');
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no share surface');
    }
  }

  @override
  Future<bool> delete({required String uri}) async {
    try {
      return await _channel.invokeMethod<bool>('delete', <String, Object?>{
            'uri': uri,
          }) ??
          false;
    } on PlatformException catch (e) {
      throw VideoEncodeException('${e.code}: ${e.message ?? 'delete failed'}');
    } on MissingPluginException {
      throw const VideoEncodeException('ENGINE_UNAVAILABLE: no file store');
    }
  }

  @override
  Future<bool> exists({required String uri}) async {
    try {
      return await _channel.invokeMethod<bool>('exists', <String, Object?>{
            'uri': uri,
          }) ??
          false;
    } on PlatformException {
      // A library that cannot answer reads as "not there": the record is
      // forgotten and the content offers to record again (FR-022), which is
      // the same thing the reader sees for a file deleted outside the app.
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
