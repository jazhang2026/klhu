/// The one thing this feature STORES: what the reader decided about a content's
/// dialogue (data-model.md §1, §3.a, §5).
///
/// Everything the text itself says — the turns, the roles it proposes, the
/// voices they read with when nobody chose — is derived on every read
/// (`lib/dialogue.dart`) and never written here. What lives here is small and
/// bounded by the number of roles, not by the length of the text: the text type,
/// the names the reader has said are *not* roles, and the voice each role was
/// given.
///
/// The shape is 012's `VideoRecordStore`'s (`lib/video_record.dart:69-180`): one
/// `shared_preferences` key holding a JSON object keyed by the content's own id,
/// read **tolerantly** — a malformed entry is ignored rather than repaired, and
/// the other contents' entries are unaffected. The failure mode is therefore
/// always "the reader's dialogue settings are gone", never "the text will not
/// read" (FR-021).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dialogue.dart';
import 'voice_store.dart';

/// A name the reader has said is not a role in this content (FR-006).
///
/// [at] is the content's `updatedAt` when the removal was made
/// (`lib/models/content.dart:40`), as ISO-8601. It is the whole of the versioning
/// this feature needs: saving the text moves `updatedAt`, which expires every
/// removal, so the name is proposed again — no text hash, no diff, no new field
/// on the content (research D4).
class RoleRemoval {
  final String name;
  final String at;

  const RoleRemoval({required this.name, required this.at});

  @override
  bool operator ==(Object other) =>
      other is RoleRemoval && other.name == name && other.at == at;

  @override
  int get hashCode => Object.hash(name, at);
}

/// Everything this feature persists for one content (data-model.md §5).
class RoleSettings {
  /// True when the reader chose 多人对话 for this content. Absence is 标准, so a
  /// content that was never switched stores nothing (FR-001).
  final bool isDialogue;

  /// The names the reader removed, with the text version they were removed on.
  final List<RoleRemoval> removed;

  /// The reader's pick per role name.
  final Map<String, VoiceChoice> voices;

  /// 015: whether this content's comments are read aloud. The shipped default is
  /// **read** — the reader's own answer of 2026-10-08, which reverses the item's
  /// own example — and the store's own read, write and tolerance of the field
  /// are US3's work (T015); the page needs its answer here for the tap rule
  /// alone (FR-006, FR-012).
  final bool commentsRead;

  const RoleSettings({
    this.isDialogue = false,
    this.removed = const [],
    this.voices = const {},
    this.commentsRead = true,
  });

  /// A content nothing was ever decided about — read as today, exactly (FR-002).
  static const RoleSettings none = RoleSettings();

  /// Nothing decided about this content. 015's switch is a decision like the
  /// others: a content whose comments the reader turned off is not "nothing
  /// decided", or its own entry would not survive its own write.
  bool get isEmpty =>
      !isDialogue && removed.isEmpty && voices.isEmpty && commentsRead;

  /// The names still removed for a text whose `updatedAt` is [updatedAt].
  ///
  /// A removal made on a different version is expired, not deleted: it is kept
  /// (it costs a few bytes) and simply has no effect (research D4).
  Set<String> removedFor(DateTime updatedAt) {
    final now = updatedAt.toIso8601String();
    return {
      for (final removal in removed)
        if (removal.at == now) removal.name,
    };
  }

  VoiceChoice? pickFor(String role) => voices[role];

  /// The settings with [name] removed as a role, against the text version [at]
  /// (FR-006, FR-007). One removal per name: removing a name twice keeps the
  /// later version, which is the one in force.
  RoleSettings withRemoval(String name, DateTime at) => RoleSettings(
        isDialogue: isDialogue,
        removed: [
          for (final removal in removed)
            if (removal.name != name) removal,
          RoleRemoval(name: name, at: at.toIso8601String()),
        ],
        voices: voices,
        // 015: every hand-built copy carries the switch, or changing a role
        // would silently turn the comments back on (plan ripple 4).
        commentsRead: commentsRead,
      );

  /// The settings with [role]'s pick replaced — or cleared, when [voice] is null
  /// (FR-012). The page's own copy of the settings follows the store's shape, so
  /// the list it redraws is what the next read will use.
  RoleSettings withVoice(String role, VoiceChoice? voice) {
    final next = {...voices};
    if (voice == null) {
      next.remove(role);
    } else {
      next[role] = voice;
    }
    return RoleSettings(
      isDialogue: isDialogue,
      removed: removed,
      voices: next,
      commentsRead: commentsRead,
    );
  }
}

/// Reads and writes [RoleSettings] over `shared_preferences`.
class RoleStore {
  RoleStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// The `shared_preferences` key this store owns: one for the whole app.
  static const String key = 'content_roles';

  final Future<SharedPreferences> Function() _prefs;

  /// The settings for [contentKey], or [RoleSettings.none].
  Future<RoleSettings> load(String contentKey) async {
    final prefs = await _prefs();
    final entry = _entries(prefs)[contentKey];
    if (entry == null) return RoleSettings.none;
    return _settingsFrom(entry);
  }

  /// Record the text type (FR-001, FR-020).
  Future<void> setDialogue(String contentKey, {required bool dialogue}) =>
      _write(contentKey, (entry) {
        if (dialogue) {
          entry['type'] = 'dialogue';
        } else {
          entry.remove('type');
        }
      });

  /// Record that [name] is not a role in the text whose `updatedAt` is [at]
  /// (FR-006, FR-007).
  Future<void> removeRole(
    String contentKey, {
    required String name,
    required DateTime at,
  }) =>
      _write(contentKey, (entry) {
        final removed = _list(entry['removed'])
          ..removeWhere((item) => item['name'] == name)
          ..add({'name': name, 'at': at.toIso8601String()});
        entry['removed'] = removed;
      });

  /// Give [role] a voice, or clear its pick when [voice] is null so it follows
  /// the automatic assignment again (FR-012, FR-013).
  Future<void> setVoice(
    String contentKey, {
    required String role,
    VoiceChoice? voice,
  }) =>
      _write(contentKey, (entry) {
        final voices = _map(entry['voices']);
        if (voice == null) {
          voices.remove(role);
        } else {
          // {name, locale} is the whole pick: the language is the voice's own
          // locale's list, which `languageOfVoice` reads back (data-model.md §5).
          voices[role] = {'name': voice.name, 'locale': voice.locale};
        }
        // Written back either way: an emptied map must not leave the previous
        // one in place, or clearing the last pick would clear nothing.
        if (voices.isEmpty) {
          entry.remove('voices');
        } else {
          entry['voices'] = voices;
        }
      });

  /// Record whether this content's comments are read (015 FR-006, FR-015).
  ///
  /// *Read* is the absence of the field, exactly as 标准 is the absence of
  /// `"type"`: a content the reader never turned the comments off for stores
  /// nothing about them, and turning them back on takes the field away again.
  Future<void> setComments(String contentKey, {required bool read}) =>
      _write(contentKey, (entry) {
        if (read) {
          entry.remove('comments');
        } else {
          entry['comments'] = false;
        }
      });

  /// Forget everything stored for [contentKey] — the content is gone
  /// (FR-021, `lib/content_list_screen.dart`'s delete).
  Future<void> clearFor(String contentKey) async {
    final prefs = await _prefs();
    final entries = _entries(prefs)..remove(contentKey);
    await _save(prefs, entries);
  }

  Future<void> _write(
    String contentKey,
    void Function(Map<String, Object?> entry) change,
  ) async {
    final prefs = await _prefs();
    final entries = _entries(prefs);
    final entry = entries[contentKey] ?? <String, Object?>{};
    change(entry);
    // An entry that says nothing is dropped: the store holds decisions, and a
    // content the reader undid every decision about costs nothing.
    if (entry.isEmpty) {
      entries.remove(contentKey);
    } else {
      entries[contentKey] = entry;
    }
    await _save(prefs, entries);
  }

  /// Every well-formed entry, in memory. A store that is missing, not JSON, not
  /// an object, or holds entries of the wrong shape answers with what it could
  /// read and is not rewritten (FR-021).
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

  RoleSettings _settingsFrom(Map<String, Object?> entry) {
    final removed = <RoleRemoval>[
      for (final item in _list(entry['removed']))
        if (item['name'] is String &&
            (item['name']! as String).isNotEmpty &&
            item['at'] is String)
          RoleRemoval(
            name: item['name']! as String,
            at: item['at']! as String,
          ),
    ];
    final voices = <String, VoiceChoice>{};
    _map(entry['voices']).forEach((role, value) {
      if (role.isEmpty || value is! Map) return;
      final name = value['name'];
      final locale = value['locale'];
      if (name is! String || locale is! String) return;
      final language = languageOfVoice(locale);
      // A pick whose locale is no language this app reads is not a pick: the
      // role follows the assignment instead (tolerant read, FR-021).
      if (language == null || name.isEmpty || locale.isEmpty) return;
      voices[role] =
          VoiceChoice(language: language, name: name, locale: locale);
    });
    return RoleSettings(
      isDialogue: entry['type'] == 'dialogue',
      removed: removed,
      voices: voices,
      // Tolerant like every other field: only an explicit `false` turns the
      // comments off, so a string, a number or anything else reads as the
      // shipped default (FR-006, FR-021).
      commentsRead: entry['comments'] != false,
    );
  }

  List<Map<String, Object?>> _list(Object? value) => [
        if (value is List)
          for (final item in value)
            if (item is Map)
              {
                for (final entry in item.entries)
                  if (entry.key is String) entry.key as String: entry.value,
              },
      ];

  Map<String, Object?> _map(Object? value) => {
        if (value is Map)
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
      };

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
