/// What this feature persists: the reader's assignment, per content (spec 020
/// FR-010, FR-013, `data-model.md` §2).
///
/// The shape is 015's `RoleStore`'s (`lib/role_store.dart:132`): one
/// `shared_preferences` key holding a JSON object keyed by the content's own id,
/// read **tolerantly** — a malformed entry is ignored rather than repaired, and
/// the other contents' entries are unaffected. The failure mode is therefore
/// always "this content's assignment is gone", never "the video will not
/// render".
///
/// It is deliberately not 012's picks' store: the picks themselves are never
/// remembered (that is 012's own rule, and it stays), and what is remembered
/// here is the reader's decision **about** them — which is why a run is keyed by
/// the picture's own file name and why this record outlives the prompt that made
/// it (research D7).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'picture_assignment.dart';

/// Reads and writes the reader's runs over `shared_preferences`.
class PictureAssignmentStore {
  PictureAssignmentStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// The `shared_preferences` key this store owns: one for the whole app, as
  /// 015's is — 015's own key is untouched by this one.
  static const String key = 'content_picture_assignments';

  final Future<SharedPreferences> Function() _prefs;

  /// This content's runs, or an empty list: a content the reader assigned
  /// nothing on stores nothing, and one whose record cannot be read answers the
  /// same way rather than failing the page.
  Future<List<PictureRun>> load(String contentKey) async {
    final prefs = await _prefs();
    final entry = _entries(prefs)[contentKey];
    if (entry == null) return const <PictureRun>[];
    return _runsFrom(entry);
  }

  /// Record [runs] as this content's assignment (FR-010).
  ///
  /// An empty list is the **absence** of the entry rather than an empty one:
  /// nothing assigned is what the reader had before they assigned anything, and
  /// a content they cleared must cost nothing.
  Future<void> save(String contentKey, {required List<PictureRun> runs}) async {
    final prefs = await _prefs();
    final entries = _entries(prefs);
    if (runs.isEmpty) {
      entries.remove(contentKey);
    } else {
      entries[contentKey] = <String, Object?>{
        'runs': <Object?>[
          for (final run in runs)
            <String, Object?>{
              'name': run.name,
              'spans': <Object?>[
                for (final span in run.spans) <int>[span.$1, span.$2],
              ],
            },
        ],
      };
    }
    await _save(prefs, entries);
  }

  /// Forget what this content's assignment held — the content is gone (012's
  /// `lib/content_list_screen.dart` deletes, 015's `clearFor` has the same job).
  Future<void> clearFor(String contentKey) async {
    final prefs = await _prefs();
    final entries = _entries(prefs)..remove(contentKey);
    await _save(prefs, entries);
  }

  /// Every well-formed entry, in memory. A store that is missing, not JSON, not
  /// an object, or holds entries of the wrong shape answers with what it could
  /// read, and is **not** rewritten on the way out.
  Map<String, Map<String, Object?>> _entries(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};
    final entries = <String, Map<String, Object?>>{};
    decoded.forEach((Object? contentKey, Object? value) {
      if (contentKey is String && contentKey.isNotEmpty && value is Map) {
        entries[contentKey] = {
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        };
      }
    });
    return entries;
  }

  /// One entry's runs: a run needs a name, and keeps the spans that are pairs of
  /// non-negative integers in ascending order of position (`data-model.md` §1).
  List<PictureRun> _runsFrom(Map<String, Object?> entry) {
    final raw = entry['runs'];
    if (raw is! List) return const <PictureRun>[];
    final runs = <PictureRun>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name'];
      if (name is! String || name.isEmpty) continue;
      final spans = <(int, int)>[];
      final written = item['spans'];
      if (written is List) {
        for (final span in written) {
          if (span is! List || span.length != 2) continue;
          final start = span[0];
          final end = span[1];
          if (start is! int || end is! int || start < 0 || end <= start) continue;
          spans.add((start, end));
        }
      }
      runs.add(PictureRun(name: name, spans: spans));
    }
    return runs;
  }

  Future<void> _save(
    SharedPreferences prefs,
    Map<String, Map<String, Object?>> entries,
  ) async {
    if (entries.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(entries));
  }
}
