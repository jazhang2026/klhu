/// A kept video, watched (FR-022): the content's own file, played by the
/// platform's own player, with a way back.
///
/// Leaving releases the player: what is no longer on screen must not still be
/// playing (player contract § Rules 4).
///
/// It is its own file rather than a private class of the page because two
/// screens open a video this way — the page's own Play action (which the list's
/// last row carries) and every row of the list (FR-033) — and a second copy of
/// the same screen is how the two come to differ.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/video_record.dart';

class VideoPlaybackScreen extends StatefulWidget {
  const VideoPlaybackScreen({
    super.key,
    required this.player,
    required this.video,
  });

  final VideoPlayer player;
  final KeptVideo video;

  @override
  State<VideoPlaybackScreen> createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  @override
  void dispose() {
    unawaited(widget.player.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.video.name)),
    body: Center(
      child: widget.player.view(context, source: widget.video.uri),
    ),
  );
}
