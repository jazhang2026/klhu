/// Which content owns which kept video (spec 012 US3): the store a kept video is
/// found again through, and the rule that a video whose file has gone is
/// reported as gone rather than offered as playable (FR-011, FR-012, FR-022).
///
/// The format is `specs/012-reading-video/contracts/video-record-format.md`: one
/// `shared_preferences` key (`video_record`) holding a JSON object keyed by the
/// content's own key, each value `{name, uri, keptAt}`. Reading never rewrites
/// what it could not understand, and nothing but keeping writes this store.
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

/// What a lookup answers: the video, or nothing — and whether an entry had to be
/// forgotten on the way because its file no longer resolves (FR-022).
class VideoLookup {
  const VideoLookup({this.video, this.wasStale = false});

  final KeptVideo? video;

  /// True when an entry existed and its file was gone: the app reports the video
  /// as gone and the content offers to record again.
  final bool wasStale;
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

  /// The video kept for [contentKey], or nothing — and whether one had to be
  /// forgotten as stale (FR-022).
  Future<VideoLookup> lookup(String contentKey) async {
    final prefs = await _prefs();
    final entry = _entries(prefs)[contentKey];
    if (entry == null) return const VideoLookup();
    if (await files.exists(uri: entry.uri)) return VideoLookup(video: entry);
    // Gone from the library outside the app: report it and forget it, so the
    // next look is simply "nothing kept" (contract § Read rules 4).
    await _remove(prefs, contentKey);
    return const VideoLookup(wasStale: true);
  }

  /// Keep [workingPath] for [contentKey] under [displayName], replacing whatever
  /// was kept there before — the new file is in place before the old one goes,
  /// which is the platform's own order (FR-012).
  Future<KeptVideo> keep(
    String contentKey, {
    required String workingPath,
    required String displayName,
  }) async {
    final prefs = await _prefs();
    final previous = _entries(prefs)[contentKey];
    final uri = await files.keep(
      workingPath: workingPath,
      displayName: displayName,
      previousUri: previous?.uri,
    );
    final kept = KeptVideo(
      name: displayName,
      uri: uri,
      keptAtMs: _now().millisecondsSinceEpoch,
    );
    await _save(prefs, _entries(prefs)..[contentKey] = kept);
    return kept;
  }

  /// Delete the kept video for [contentKey]: the file from the library and the
  /// entry from the store. Answers whether the file is gone — a removal that
  /// failed is reported rather than swallowed (contract § Write rules 2); the
  /// entry goes either way, so the next lookup finds the video gone and the
  /// content offers to record again.
  ///
  /// The warning is the caller's (FR-024): this does what it is told.
  Future<bool> delete(String contentKey) async {
    final prefs = await _prefs();
    final entry = _entries(prefs)[contentKey];
    if (entry == null) return true;
    final gone = await files.delete(uri: entry.uri);
    await _remove(prefs, contentKey);
    return gone;
  }

  /// Every well-formed entry in the store, in memory. A store whose value is
  /// missing, not JSON, not an object, or holds entries of the wrong shape
  /// answers with what it could read and is not rewritten (contract § Read 2).
  Map<String, KeptVideo> _entries(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return <String, KeptVideo>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <String, KeptVideo>{};
    }
    if (decoded is! Map) return <String, KeptVideo>{};
    final entries = <String, KeptVideo>{};
    decoded.forEach((Object? contentKey, Object? value) {
      final kept = KeptVideo.fromJson(value);
      if (contentKey is String && contentKey.isNotEmpty && kept != null) {
        entries[contentKey] = kept;
      }
    });
    return entries;
  }

  Future<void> _save(
    SharedPreferences prefs,
    Map<String, KeptVideo> entries,
  ) async {
    await prefs.setString(
      key,
      jsonEncode({
        for (final entry in entries.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  Future<void> _remove(SharedPreferences prefs, String contentKey) async {
    final entries = _entries(prefs)..remove(contentKey);
    await _save(prefs, entries);
  }
}
