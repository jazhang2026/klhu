/// The content library: the only reader/writer of `index.json` and
/// `contents/<id>.txt` (spec 008, contract:
/// `specs/008-content-storage/contracts/storage-format.md`).
///
/// The directory and the catalog loader are injectable so every rule below is
/// unit-testable without a device, a plugin channel or the asset bundle.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:klhu/content_naming.dart';
import 'package:klhu/language.dart';
import 'package:klhu/models/content.dart';
import 'package:path_provider/path_provider.dart';

/// Conditions the store reports instead of throwing: the app keeps running and
/// the UI shows a localized message.
enum ContentError {
  /// The index was unparsable or of an unknown version and has been re-seeded.
  indexRepaired,

  /// An entry's text could not be read (missing file, permissions, IO).
  damaged,

  /// A write or an asset read failed (disk full, missing catalog).
  ioError,

  /// A save was refused because the text was empty or whitespace-only.
  emptyText,

  /// A save was refused because the text exceeded [kMaxContentChars].
  tooLarge,
}

/// Raised by the mutating API and by [ContentStore.read]: the guards reject a
/// save before anything is written (contract § Error and repair states).
class ContentStoreException implements Exception {
  final ContentError kind;
  final String? detail;

  ContentStoreException(this.kind, [this.detail]);

  @override
  String toString() =>
      'ContentStoreException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Supplies the shipped pre-set catalog. Injected in tests; defaults to the
/// asset bundle.
typedef CatalogLoader = Future<List<PresetContent>> Function();

/// Parses `assets/content/presets.json`. A malformed entry is skipped so one
/// bad pre-set can never break startup (contract § Pre-set catalog).
List<PresetContent> parsePresetCatalog(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    // Not JSON at all: no pre-sets, and the app runs on user content alone.
    return const <PresetContent>[];
  }
  if (decoded is! Map<String, Object?>) return const <PresetContent>[];
  final rawPresets = decoded['presets'];
  if (rawPresets is! List) return const <PresetContent>[];
  final out = <PresetContent>[];
  final seen = <String>{};
  for (final rawPreset in rawPresets) {
    if (rawPreset is! Map<String, Object?>) continue;
    try {
      final preset = PresetContent.fromJson(rawPreset);
      if (seen.add(preset.id)) out.add(preset);
    } on FormatException {
      continue;
    }
  }
  return out;
}

/// The shipped catalog, read once per process.
Future<List<PresetContent>> loadAssetCatalog() async =>
    parsePresetCatalog(await rootBundle.loadString('assets/content/presets.json'));

class ContentStore {
  ContentStore({
    Directory? directory,
    CatalogLoader? loadCatalog,
    DateTime Function()? now,
  })  // The injected directory is a public named parameter while the field is
      // private: an initializing formal cannot express that pair.
      // ignore: prefer_initializing_formals
      : _directory = directory,
        _loadCatalog = loadCatalog ?? loadAssetCatalog,
        _now = now ?? DateTime.now;

  final Directory? _directory;
  final CatalogLoader _loadCatalog;
  final DateTime Function() _now;

  ContentIndex? _index;
  List<PresetContent>? _catalog;
  ContentError? _lastError;

  /// Set by the last operation that had something to report; cleared by
  /// [clearError] once the UI has shown it.
  ContentError? get lastError => _lastError;

  void clearError() => _lastError = null;

  /// The library directory. Resolving it needs the platform channel, which is
  /// absent in plain unit tests — that failure is reported as an IO error
  /// instead of escaping as a plugin exception.
  Future<Directory> _dir() async {
    final injected = _directory;
    if (injected != null) return injected;
    try {
      return Directory('${(await getApplicationDocumentsDirectory()).path}/content');
    } on Object catch (e) {
      _lastError = ContentError.ioError;
      throw ContentStoreException(ContentError.ioError, '$e');
    }
  }

  /// The shipped pre-sets, loaded once. A failed catalog read leaves the app
  /// usable with user content only.
  Future<List<PresetContent>> catalog() async {
    if (_catalog != null) return _catalog!;
    try {
      return _catalog = await _loadCatalog();
    } on Object {
      _catalog = const <PresetContent>[];
      _lastError = ContentError.ioError;
      return _catalog!;
    }
  }

  Future<PresetContent?> presetFor(String id) async {
    for (final preset in await catalog()) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// Every entry, newest save first. Reads `index.json` and stats the text
  /// files — never reads their content, so list latency is independent of text
  /// size (contract invariant 1).
  Future<List<SavedContent>> list() async {
    final index = await _loadIndex();
    final dir = await _dir();
    return [
      for (final entry in index.entries)
        if (entry.isPreset || File(_textPath(dir, entry)).existsSync())
          entry
        else
          entry.copyWith(damaged: true),
    ];
  }

  /// The text of one entry: the asset for a pre-set, `contents/<id>.txt` for a
  /// user entry. Throws [ContentStoreException] with [ContentError.damaged]
  /// when that text cannot be read.
  Future<String> read(SavedContent entry) async {
    if (entry.isPreset) {
      final preset = await presetFor(entry.id);
      if (preset == null) {
        throw ContentStoreException(ContentError.damaged, entry.id);
      }
      return preset.text;
    }
    final file = File(_textPath(await _dir(), entry));
    try {
      return await file.readAsString();
    } on FileSystemException catch (e) {
      throw ContentStoreException(ContentError.damaged, e.message);
    }
  }

  String _textPath(Directory dir, SavedContent entry) =>
      '${dir.path}/contents/${entry.id}.txt';

  Future<ContentIndex> _loadIndex() async {
    final cached = _index;
    if (cached != null) return cached;
    return _index = await _readOrRepairIndex();
  }

  Future<ContentIndex> _readOrRepairIndex() async {
    final dir = await _dir();
    final file = File('${dir.path}/index.json');
    if (!file.existsSync()) return _seed(ContentIndex());
    try {
      return ContentIndex.decode(await file.readAsString());
    } on Object {
      // Move the unreadable file aside so nothing the user wrote is destroyed,
      // then start over from the catalog (contract § Error and repair states).
      await dir.create(recursive: true);
      final stamp = _now().toUtc().millisecondsSinceEpoch;
      await file.rename('${dir.path}/index.corrupt-$stamp.json');
      _lastError = ContentError.indexRepaired;
      return _seed(ContentIndex());
    }
  }

  /// Adds catalog pre-sets the install has never seen. Tombstoned ids stay out
  /// (research D4) and existing entries are never overwritten.
  Future<ContentIndex> _seed(ContentIndex index) async {
    final known = {for (final entry in index.entries) entry.id};
    final tombstones = index.deletedPresetIds.toSet();
    final now = _now().toUtc();
    final entries = [...index.entries];
    for (final preset in await catalog()) {
      if (known.contains(preset.id) || tombstones.contains(preset.id)) continue;
      entries.add(
        SavedContent(
          id: preset.id,
          // A pre-set's title comes from its own text, never from a translated
          // label (spec 008); the list regenerates it the same way.
          name: contentNameFrom(preset.text),
          language: preset.language,
          origin: ContentOrigin.preset,
          createdAt: now,
          updatedAt: now,
          charCount: preset.text.length,
        ),
      );
    }
    final seeded = index.copyWith(entries: _sorted(entries));
    await _writeIndex(seeded);
    return seeded;
  }

  List<SavedContent> _sorted(List<SavedContent> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// `.tmp` + rename: a crash mid-write leaves the previous file intact
  /// (contract § Write protocol).
  Future<void> _writeAtomically(File target, String contents) async {
    final tmp = File('${target.path}.tmp');
    final handle = tmp.openSync(mode: FileMode.write);
    try {
      handle.writeStringSync(contents);
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    await tmp.rename(target.path);
  }

  Future<void> _writeIndex(ContentIndex index) async {
    try {
      final dir = await _dir();
      await dir.create(recursive: true);
      await _writeAtomically(File('${dir.path}/index.json'), index.encode());
    } on FileSystemException catch (e) {
      _lastError = ContentError.ioError;
      throw ContentStoreException(ContentError.ioError, e.message);
    }
  }

  /// Commits [next] to disk and only then to memory: a refused or failed write
  /// leaves the library the user sees exactly as it was.
  Future<void> _commit(ContentIndex next) async {
    await _writeIndex(next);
    _index = next;
  }

  // ---------------------------------------------------------------------
  // Mutating API (spec 008 US1)
  // ---------------------------------------------------------------------

  /// Saves [text] as a new user entry: name from its first line, id from the
  /// clock, text file first, index second.
  Future<SavedContent> saveNew(String text, {String? language}) async {
    _checkGuards(text);
    final index = await _loadIndex();
    final now = _now().toUtc();
    final label = language ?? detectLanguage(text);
    final entry = SavedContent(
      id: _newId(now, {for (final e in index.entries) e.id}),
      name: uniqueContentName(
        contentNameFrom(text),
        index.entries.where((e) => e.language == label).map((e) => e.name),
      ),
      language: label,
      origin: ContentOrigin.user,
      createdAt: now,
      updatedAt: now,
      charCount: text.length,
    );
    await _writeText(entry, text);
    await _commit(index.copyWith(
      entries: _sorted([...index.entries, entry]),
      lastOpenedId: entry.id,
    ));
    return entry;
  }

  /// Rewrites a user entry in place: id, name and `createdAt` survive.
  ///
  /// A pre-set is not updatable — editing one produces new content (FR-019),
  /// which is what [saveEdited] routes to; calling this with a pre-set is a
  /// programming error.
  Future<SavedContent> update(SavedContent entry, String text) async {
    if (entry.isPreset) {
      throw ArgumentError.value(
          entry, 'entry', 'update() applies to user content only');
    }
    _checkGuards(text);
    final index = await _loadIndex();
    final now = _now().toUtc();
    final updated = entry.copyWith(
      updatedAt: now.isBefore(entry.createdAt) ? entry.createdAt : now,
      charCount: text.length,
      damaged: false,
    );
    await _writeText(updated, text);
    await _commit(index.copyWith(
      entries: _sorted(
          [...index.entries.where((e) => e.id != entry.id), updated]),
      lastOpenedId: updated.id,
    ));
    return updated;
  }

  /// The one save entry point the UI uses: a pre-set becomes new content, a
  /// user entry is updated in place (FR-013/FR-019, SC-010).
  Future<SavedContent> saveEdited(SavedContent? loaded, String text,
      {String? language}) async {
    if (loaded == null || loaded.isPreset) {
      return saveNew(text, language: language);
    }
    return update(loaded, text);
  }

  /// Removes an entry. A pre-set leaves a tombstone so the catalog cannot
  /// resurrect it in this install; a user entry also loses its text file.
  Future<void> delete(SavedContent entry) async {
    final index = await _loadIndex();
    await _commit(index.copyWith(
      entries: [...index.entries.where((e) => e.id != entry.id)],
      deletedPresetIds: entry.isPreset
          ? [...{...index.deletedPresetIds, entry.id}]
          : index.deletedPresetIds,
      lastOpenedId:
          index.lastOpenedId == entry.id ? null : index.lastOpenedId,
    ));
    if (entry.isPreset) return;
    try {
      final file = File(_textPath(await _dir(), entry));
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // The entry is already gone from the library; an orphan file is
      // invisible (nothing lists it) and this is reported, not thrown.
      _lastError = ContentError.ioError;
    }
  }

  /// Remembers which entry to open next launch (research D9).
  Future<void> markOpened(String id) async {
    final index = await _loadIndex();
    if (index.lastOpenedId == id) return;
    await _commit(index.copyWith(lastOpenedId: id));
  }

  /// The entry to open on launch, or null when there is nothing to open.
  Future<SavedContent?> lastOpened() async {
    final index = await _loadIndex();
    final id = index.lastOpenedId;
    if (id == null) return null;
    for (final entry in index.entries) {
      if (entry.id == id) return entry;
    }
    // Points at something that is gone: clear it so later reads are clean.
    await _commit(index.copyWith(lastOpenedId: null));
    return null;
  }

  /// Guards run before the file system is touched: nothing is written and
  /// nothing is truncated (contract § Error and repair states).
  void _checkGuards(String text) {
    if (text.trim().isEmpty) {
      _lastError = ContentError.emptyText;
      throw ContentStoreException(ContentError.emptyText);
    }
    if (text.length > kMaxContentChars) {
      _lastError = ContentError.tooLarge;
      throw ContentStoreException(ContentError.tooLarge, '${text.length}');
    }
  }

  String _newId(DateTime now, Set<String> taken) {
    final millis = now.millisecondsSinceEpoch;
    for (var attempt = 0; attempt < 64; attempt++) {
      final suffix =
          Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
      final id = 'c_${millis}_$suffix';
      if (!taken.contains(id)) return id;
    }
    throw StateError('could not allocate a unique content id');
  }

  Future<void> _writeText(SavedContent entry, String text) async {
    try {
      final dir = await _dir();
      final contents = Directory('${dir.path}/contents');
      await contents.create(recursive: true);
      _sweepCrashedWrites(contents);
      await _writeAtomically(File(_textPath(dir, entry)), text);
    } on FileSystemException catch (e) {
      _lastError = ContentError.ioError;
      throw ContentStoreException(ContentError.ioError, e.message);
    }
  }

  /// A `.tmp` left by a crash is dead weight: the rename never happened, so
  /// the entry it belonged to was never committed (contract § Write protocol).
  void _sweepCrashedWrites(Directory contents) {
    for (final file in contents.listSync()) {
      if (file is! File || !file.path.endsWith('.tmp')) continue;
      try {
        file.deleteSync();
      } on FileSystemException {
        // Still stale and still harmless; the next save tries again.
      }
    }
  }
}
