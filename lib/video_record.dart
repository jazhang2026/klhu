/// Which content owns which kept videos (spec 012 US3): the store a kept video is
/// found again through, and the rule that a video whose file has gone is
/// reported as gone rather than offered as playable (FR-011, FR-012, FR-022).
///
/// The format is `specs/012-reading-video/contracts/video-record-format.md`: one
/// `shared_preferences` key (`video_record`) holding a JSON object keyed by the
/// content's own key, each value an **array** of entries, oldest first, each
/// `{name, uri, keptAt}`. The last entry is the content's own video — what the
/// page's Play action opens (FR-022). A value in the shape 012 shipped with (a
/// single object rather than an array) is read as a one-entry list and is not
/// rewritten until that content is next written (contract § Read rules 5).
///
/// Reading never rewrites what it could not understand, and nothing but keeping
/// writes an entry into this store. A write touches **the contents it writes**,
/// so an old-shape value nobody has written yet stays exactly as it was found
/// (contract § Read rules 5): the migration is per content, on that content's own
/// next write, never a store-wide pass.
library;

import 'dart:convert';

import 'package:klhu/platform/video_encoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One kept video: what the device's library calls it and where it lives.
class KeptVideo {
  const KeptVideo({
    required this.name,
    required this.uri,
    required this.keptAtMs,
  });

  /// The library entry's name, derived from the content's name at keep time —
  /// a later rename of the content does not rewrite it (contract § Invariants).
  final String name;

  /// The library's own identity for the file; what play, share and delete take.
  final String uri;

  final int keptAtMs;

  Map<String, Object?> toJson() => {
    'name': name,
    'uri': uri,
    'keptAt': keptAtMs,
  };

  /// The entry [value] stands for, or null when it is not a well-formed one
  /// (`name` and `uri` are both required and both strings).
  static KeptVideo? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final uri = value['uri'];
    if (name is! String || name.isEmpty) return null;
    if (uri is! String || uri.isEmpty) return null;
    final keptAt = value['keptAt'];
    return KeptVideo(
      name: name,
      uri: uri,
      keptAtMs: keptAt is int ? keptAt : 0,
    );
  }
}

/// What a read of a content's record answers: the videos that are there, and the
/// entries that had to be forgotten on the way because their files no longer
/// resolve (FR-022).
class VideoLookup {
  const VideoLookup({
    this.videos = const <KeptVideo>[],
    this.gone = const <KeptVideo>[],
  });

  /// The content's videos that are still in the library, **oldest first**.
  final List<KeptVideo> videos;

  /// The entries this read reported as gone and forgot — each one is a video the
  /// reader kept whose file the app can no longer play.
  final List<KeptVideo> gone;

  /// The content's own video: the one kept most recently, which is what the
  /// page's Play action opens (FR-022).
  KeptVideo? get latest => videos.isEmpty ? null : videos.last;

  /// True when this read had to forget something: the app reports that video as
  /// gone and, when it was the content's last one, offers to record again.
  bool get wasStale => gone.isNotEmpty;
}

/// The record, over `shared_preferences`.
class VideoRecordStore {
  VideoRecordStore({
    required this.files,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  /// The `shared_preferences` key this store owns.
  static const String key = 'video_record';

  /// The platform's file channel: the one place a kept file's existence is
  /// asked about, and the only thing that touches the library.
  final VideoFileStore files;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  /// The videos kept for [contentKey], oldest first — and the entries this read
  /// has to forget because their files are gone (contract § Read rules 4), each
  /// one reported so the reader is told which video is missing rather than the
  /// whole content going quiet.
  Future<VideoLookup> recordFor(String contentKey) async {
    final prefs = await _prefs();
    final videos = _entries(prefs)[contentKey];
    if (videos == null || videos.isEmpty) return const VideoLookup();

    final present = <KeptVideo>[];
    final gone = <KeptVideo>[];
    for (final video in videos) {
      if (await files.exists(uri: video.uri)) {
        present.add(video);
      } else {
        gone.add(video);
      }
    }
    if (gone.isNotEmpty) {
      // Forgotten, so what is left is what can be played and the next read is
      // simply the videos that are there — the content's other videos keep
      // their order.
      await _write(prefs, {contentKey: present});
    }
    return VideoLookup(videos: present, gone: gone);
  }

  /// Keep [workingPath] for [contentKey] under [displayName], according to the
  /// reader's own answer in the review (FR-012).
  ///
  /// [replace] (the default) **rewrites the content's last entry**: the new file
  /// is put in place before the old one goes — the platform's own order, named
  /// as `previousUri` — so the content still has exactly one video. A keep the
  /// reader asked **not** to replace names no previous file and **appends**
  /// after the earlier entry: both files are in the library, and the content's
  /// own video is the one just kept (FR-022).
  Future<KeptVideo> keep(
    String contentKey, {
    required String workingPath,
    required String displayName,
    bool replace = true,
  }) async {
    final prefs = await _prefs();
    final videos = _entries(prefs)[contentKey] ?? const <KeptVideo>[];
    final previous = videos.isEmpty ? null : videos.last;
    final uri = await files.keep(
      workingPath: workingPath,
      displayName: displayName,
      previousUri: replace ? previous?.uri : null,
    );
    final kept = KeptVideo(
      name: displayName,
      uri: uri,
      keptAtMs: _now().millisecondsSinceEpoch,
    );
    // What the content holds after this keep: everything but the entry being
    // rewritten (when replacing), then the entry just written. The store never
    // holds two entries naming the same uri (contract § Invariants), so a
    // platform that handed back a uri already in the list has that entry
    // dropped rather than duplicated.
    final remaining = replace && videos.isNotEmpty
        ? videos.sublist(0, videos.length - 1)
        : [...videos];
    remaining.removeWhere((video) => video.uri == uri);
    await _write(prefs, {
      contentKey: [...remaining, kept],
    });
    return kept;
  }

  /// Delete **one** kept video: its file from the device's library and its entry
  /// from the store. Answers whether the file is gone — a removal that failed is
  /// reported rather than swallowed (contract § Write rules 2); the entry goes
  /// either way, so the next read finds that video gone and the content's other
  /// videos are untouched.
  ///
  /// The warning is the caller's (FR-024): this does what it is told.
  Future<bool> delete(String uri) async {
    final gone = await files.delete(uri: uri);
    await forget(uri);
    return gone;
  }

  /// Remove [uri]'s entry from the store without touching the library: what a
  /// read does with an entry whose file has gone (contract § Read rules 4).
  Future<void> forget(String uri) async {
    final prefs = await _prefs();
    final entries = _entries(prefs);
    final written = <String, List<KeptVideo>>{};
    for (final contentKey in entries.keys) {
      final videos = entries[contentKey]!;
      final left = [
        for (final video in videos)
          if (video.uri != uri) video,
      ];
      if (left.length != videos.length) written[contentKey] = left;
    }
    if (written.isNotEmpty) await _write(prefs, written);
  }

  /// Every well-formed entry in the store, in memory, keyed by content: a store
  /// whose value is missing, not JSON, or not an object answers with what it
  /// could read and is not rewritten (contract § Read rules 2).
  ///
  /// One content's value may be an **array** of entries (this feature's shape) or
  /// the **single object** 012 shipped with (contract § Read rules 5), which
  /// reads as a one-entry list: nothing the reader kept is lost and nothing is
  /// duplicated by the read.
  Map<String, List<KeptVideo>> _entries(SharedPreferences prefs) {
    final decoded = _decode(prefs);
    if (decoded is! Map) return <String, List<KeptVideo>>{};
    final entries = <String, List<KeptVideo>>{};
    decoded.forEach((Object? contentKey, Object? value) {
      if (contentKey is! String || contentKey.isEmpty) return;
      final videos = _videos(value);
      if (videos.isNotEmpty) entries[contentKey] = videos;
    });
    return entries;
  }

  /// What the store's own value decodes to, or null when it is missing or is
  /// not JSON at all (contract § Read rules 2).
  Object? _decode(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// The entries [value] holds: an array's well-formed entries in order, or —
  /// the shape this feature shipped with — one object's single entry.
  List<KeptVideo> _videos(Object? value) {
    final raw = value is List ? value : <Object?>[value];
    final videos = <KeptVideo>[];
    for (final entry in raw) {
      final video = KeptVideo.fromJson(entry);
      if (video != null) videos.add(video);
    }
    return videos;
  }

  /// Write [values] — one content's videos, in the current array shape — into
  /// the store, leaving every other content's value exactly as it was found. A
  /// content with nothing left is removed rather than stored empty: it offers to
  /// record again (contract § Read rules 3).
  Future<void> _write(
    SharedPreferences prefs,
    Map<String, List<KeptVideo>> values,
  ) async {
    final store = _store(prefs);
    for (final entry in values.entries) {
      if (entry.value.isEmpty) {
        store.remove(entry.key);
      } else {
        store[entry.key] = [for (final video in entry.value) video.toJson()];
      }
    }
    await prefs.setString(key, jsonEncode(store));
  }

  /// The store as it stands, keyed by content, with every value left in whatever
  /// shape it was found in — what [_write] merges into, so a write cannot
  /// migrate a content nobody wrote (contract § Read rules 5).
  Map<String, Object?> _store(SharedPreferences prefs) {
    final decoded = _decode(prefs);
    return decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
  }
}
