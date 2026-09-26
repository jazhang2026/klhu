/// The playback view's Dart side (spec 012 US3, decision D12): the platform's
/// own player hosted by the app, and the two things the app asks of it.
///
/// The contract is `specs/012-reading-video/contracts/video-player-protocol.md`.
/// The transport controls (play, pause, seek) belong to the platform view —
/// this app does not re-implement a scrubber — so the Dart side carries only
/// what the page itself decides with: where the picture goes, and stopping the
/// player when the review is left.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where a video is watched: the view, and a way to stop it.
abstract class VideoPlayer {
  /// The picture, over [source] — a working copy's path or a kept video's
  /// library uri. The view's own controls play it.
  Widget view(BuildContext context, {required String source});

  /// Stops playback and releases the player. Called when the review is left,
  /// or when the video being played is deleted (contract § Rules 4).
  Future<void> stop();
}

/// The platform's own view (`klhu/video_player_view`) and its channel
/// (`klhu/video_player`).
class PlatformVideoPlayer implements VideoPlayer {
  PlatformVideoPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String viewType = 'klhu/video_player_view';
  static const String channelName = 'klhu/video_player';

  final MethodChannel _channel;

  @override
  Widget view(BuildContext context, {required String source}) => AndroidView(
    viewType: viewType,
    // The view refuses anything that is not a local file or a local library
    // uri, so nothing else is ever handed over (FR-013).
    creationParams: <String, Object?>{'source': source},
    creationParamsCodec: const StandardMessageCodec(),
  );

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No platform half on this build (D8): there is nothing playing to stop.
    } on PlatformException {
      // Same: a player that cannot answer has nothing to stop either.
    }
  }
}
