/// A content's kept videos as a list (spec 012 FR-033, the 2026-10-06
/// amendment): one screen, one row per video, reached from the content itself.
///
/// It is built the way the app's contents are listed (`content_list_screen.dart`):
/// a `ListTile` per row, a one-line name, a subtitle saying when the video was
/// kept, its own share and its own delete on the row, a tap playing **that**
/// video, and a state for a content with no videos rather than an empty list.
///
/// The rows are the record's own order — oldest first, the newest last, which is
/// the one the page's Play action opens (FR-022) — and every delete warns by the
/// name of the video it removes (FR-024), never by the content's.
///
/// Whoever pushed this screen reads the record again when it returns: a delete
/// here is what leaves a content with nothing to play.
library;

import 'package:flutter/material.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/video_playback_screen.dart';
import 'package:klhu/video_record.dart';

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({
    super.key,
    required this.contentKey,
    required this.records,
    required this.files,
    required this.player,
  });

  /// The content whose videos these are — the record's own key (FR-011).
  final String contentKey;

  /// The record and the platform's file channel: what the rows are read from,
  /// and what a row's share and delete act through.
  final VideoRecordStore records;
  final VideoFileStore files;

  /// The platform's player, handed to the screen a row opens (FR-022).
  final VideoPlayer player;

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  /// The videos that are there, once the record has been read.
  List<KeptVideo>? _videos;

  /// True when the record could not be read at all, so the screen says so
  /// instead of showing a list that is empty for the wrong reason.
  bool _failed = false;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    late final VideoLookup lookup;
    try {
      lookup = await widget.records.recordFor(widget.contentKey);
    } catch (e) {
      debugPrint('klhu reading the video list failed: $e');
      if (!mounted) return;
      setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _failed = false;
      _videos = lookup.videos;
    });
    // A video whose file has gone is reported as gone — each one by its own
    // name — and that read forgot it (FR-022), so the rows are what plays. The
    // messages queue rather than replacing one another.
    final l10n = AppLocalizations.of(context);
    for (final video in lookup.gone) {
      _showMessage(
        l10n?.videoGoneMessage(video.name) ?? '"${video.name}" is gone',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// FR-022: a row's own tap plays **that** video, whose own file the
  /// platform's player is pointed at.
  Future<void> _play(KeptVideo video) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlaybackScreen(player: widget.player, video: video),
      ),
    );
  }

  /// FR-023: a row's own share hands **that** file to the platform's own share
  /// surface. Sharing is not deleting: the row stays.
  Future<void> _share(KeptVideo video) async {
    try {
      await widget.files.share(source: video.uri);
    } catch (e) {
      debugPrint('klhu sharing the kept video failed: $e');
    }
  }

  /// FR-024: deleting a video warns first, **naming that video**, and only then
  /// removes its file and its entry. Dismissing the warning deletes nothing.
  Future<void> _confirmDelete(KeptVideo video) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.videoDeleteConfirmTitle ?? 'Delete this video?'),
        content: Text(
          l10n?.videoDeleteConfirmMessage(video.name) ??
              '"${video.name}" will be removed from your gallery. '
                  'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.deleteButton ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // The player is released first: what is about to be deleted must not still
    // be playing (player contract § Rules 4).
    await widget.player.stop();
    var gone = true;
    try {
      gone = await widget.records.delete(video.uri);
    } catch (e) {
      debugPrint('klhu deleting the video failed: $e');
      gone = false;
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (!gone) {
      // The entry is gone either way, so the row goes rather than offering a
      // video that is not there (contract § Write rules 2).
      _showMessage(
        l10n?.storageErrorMessage ??
            'Could not save. Check storage space and try again.',
      );
    }
  }

  /// When a video was kept, in the reader's own locale — the row's own date,
  /// because every video a content holds is named after that content.
  String _keptOn(BuildContext context, KeptVideo video) =>
      MaterialLocalizations.of(context).formatShortDate(
        DateTime.fromMillisecondsSinceEpoch(video.keptAtMs).toLocal(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.videoListTitle ?? 'Videos')),
      body: _body(context, l10n),
    );
  }

  Widget _body(BuildContext context, AppLocalizations? l10n) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.storageErrorMessage ??
                'Could not save. Check storage space and try again.',
          ),
        ),
      );
    }
    final videos = _videos;
    if (videos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (videos.isEmpty) {
      // A content with no videos says so rather than showing an empty list
      // (FR-033) — what deleting this screen's last row leaves.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.videoListEmptyMessage ?? 'This content has no videos yet',
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return ListTile(
          // One line always: a long name is cut with an ellipsis rather than
          // wrapping into the subtitle (FR-033).
          title: Text(
            video.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_keptOn(context, video)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n?.videoShareButton ?? 'Share',
                onPressed: () => _share(video),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n?.videoDeleteButton ?? 'Delete video',
                onPressed: () => _confirmDelete(video),
              ),
            ],
          ),
          // A tap anywhere else on the row plays that video (FR-033).
          onTap: () => _play(video),
        );
      },
    );
  }
}
