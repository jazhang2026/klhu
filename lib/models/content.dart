/// In-memory model of the content library (spec 008).
///
/// The on-disk shape is specified in
/// `specs/008-content-storage/contracts/storage-format.md`; this file is the
/// model those files round-trip through.
library;

import 'dart:convert';

/// Where an entry came from. A pre-set's text lives in the shipped asset; a
/// user entry's text lives in `contents/<id>.txt`.
enum ContentOrigin { preset, user }

/// Index schema version. A file with any other value is unsupported and takes
/// the repair path (contract § index.json).
const int kContentIndexVersion = 1;

/// Save guard: a longer text is refused, never truncated (research D10).
/// 100,000 characters is at most ~300 KB of UTF-8 CJK, inside the spec's 1 MB
/// assumption, and it bounds the platform undo stack's per-step snapshots.
const int kMaxContentChars = 100000;

/// Auto-generated names are the first line of the text, cut to this many
/// characters (research D7).
const int kMaxContentNameChars = 24;

/// One entry of the unified content list.
///
/// [damaged] is runtime state — an entry whose text file is missing or
/// unreadable — and is deliberately not persisted and not part of equality.
class SavedContent {
  final String id;
  final String name;

  /// Label language: `en`, `zh-Hans` or `es`. Reading still detects the
  /// language per paragraph (`lib/language.dart`).
  final String language;
  final ContentOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int charCount;
  final bool damaged;

  SavedContent({
    required this.id,
    required this.name,
    required this.language,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
    required this.charCount,
    this.damaged = false,
  });

  bool get isPreset => origin == ContentOrigin.preset;

  SavedContent copyWith({
    String? name,
    String? language,
    ContentOrigin? origin,
    DateTime? updatedAt,
    int? charCount,
    bool? damaged,
  }) =>
      SavedContent(
        id: id,
        name: name ?? this.name,
        language: language ?? this.language,
        origin: origin ?? this.origin,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        charCount: charCount ?? this.charCount,
        damaged: damaged ?? this.damaged,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'origin': origin.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'charCount': charCount,
      };

  /// Throws [FormatException] on a malformed entry, which sends the whole
  /// index down the repair path (contract § Error and repair states).
  factory SavedContent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final language = json['language'];
    final origin = json['origin'];
    final createdAt = _parseUtc(json['createdAt']);
    final updatedAt = _parseUtc(json['updatedAt']);
    final charCount = json['charCount'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('content id missing');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('content name missing');
    }
    if (language is! String || language.isEmpty) {
      throw const FormatException('content language missing');
    }
    if (origin is! String ||
        !ContentOrigin.values.any((o) => o.name == origin)) {
      throw const FormatException('unknown content origin');
    }
    if (charCount is! int || charCount < 1) {
      throw const FormatException('bad content charCount');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('updatedAt before createdAt');
    }
    return SavedContent(
      id: id,
      name: name,
      language: language,
      origin: ContentOrigin.values.firstWhere((o) => o.name == origin),
      createdAt: createdAt,
      updatedAt: updatedAt,
      charCount: charCount,
    );
  }

  /// Serialized shape equality: [damaged] is excluded on purpose.
  @override
  bool operator ==(Object other) =>
      other is SavedContent &&
      other.id == id &&
      other.name == name &&
      other.language == language &&
      other.origin == origin &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.charCount == charCount;

  @override
  int get hashCode =>
      Object.hash(id, name, language, origin, createdAt, updatedAt, charCount);

  @override
  String toString() =>
      'SavedContent($id, $name, $language, ${origin.name}, $charCount chars)';
}

DateTime _parseUtc(Object? raw) {
  if (raw is! String) throw const FormatException('missing timestamp');
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw const FormatException('bad timestamp');
  return parsed.toUtc();
}

/// The whole library's metadata: the only file the list screen reads.
class ContentIndex {
  final int version;
  final List<SavedContent> entries;

  /// Tombstones: pre-sets the user deleted are never seeded again in this
  /// install (research D4).
  final List<String> deletedPresetIds;

  /// Entry to open on the next launch (research D9).
  final String? lastOpenedId;

  ContentIndex({
    this.version = kContentIndexVersion,
    List<SavedContent>? entries,
    List<String>? deletedPresetIds,
    this.lastOpenedId,
  })  : entries = entries ?? <SavedContent>[],
        deletedPresetIds = deletedPresetIds ?? <String>[];

  ContentIndex copyWith({
    List<SavedContent>? entries,
    List<String>? deletedPresetIds,
    Object? lastOpenedId = _unset,
  }) =>
      ContentIndex(
        version: version,
        entries: entries ?? this.entries,
        deletedPresetIds: deletedPresetIds ?? this.deletedPresetIds,
        lastOpenedId:
            lastOpenedId == _unset ? this.lastOpenedId : lastOpenedId as String?,
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'entries': [for (final e in entries) e.toJson()],
        'deletedPresetIds': [...deletedPresetIds],
        'lastOpenedId': lastOpenedId,
      };

  String encode() => jsonEncode(toJson());

  /// Throws [FormatException] when the payload is unparsable, has a version
  /// this build does not know, or holds a malformed entry.
  factory ContentIndex.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != kContentIndexVersion) {
      throw FormatException('unsupported index version: $version');
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) throw const FormatException('entries missing');
    final rawDeleted = json['deletedPresetIds'];
    if (rawDeleted is! List) throw const FormatException('tombstones missing');
    final lastOpened = json['lastOpenedId'];
    if (lastOpened != null && lastOpened is! String) {
      throw const FormatException('bad lastOpenedId');
    }
    return ContentIndex(
      entries: [
        for (final raw in rawEntries)
          if (raw is Map<String, Object?>)
            SavedContent.fromJson(raw)
          else
            throw const FormatException('malformed entry'),
      ],
      deletedPresetIds: [for (final raw in rawDeleted) raw as String],
      lastOpenedId: lastOpened as String?,
    );
  }

  static ContentIndex decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('index is not JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('index root is not an object');
    }
    return ContentIndex.fromJson(decoded);
  }
}

const Object _unset = Object();

/// A shipped pre-set content, as it appears in `assets/content/presets.json`.
///
/// A pre-set carries no stored name: like a user entry, its title is generated
/// from its own text (`lib/content_naming.dart`), so it is never a translated
/// label that drifts from the content (spec 008).
class PresetContent {
  final String id;
  final String language;
  final String text;

  PresetContent({
    required this.id,
    required this.language,
    required this.text,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'language': language,
        'text': text,
      };

  factory PresetContent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final language = json['language'];
    final text = json['text'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('preset id missing');
    }
    if (language is! String || language.isEmpty) {
      throw const FormatException('preset language missing');
    }
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('preset text missing');
    }
    return PresetContent(id: id, language: language, text: text);
  }
}
