/// Contract tests for the content library (spec 008 T005).
///
/// The behaviour asserted here is the persistent contract in
/// `specs/008-content-storage/contracts/storage-format.md`. Everything runs
/// against a temp directory — no device, no plugin, no asset bundle.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('klhu-content-test');
  });

  tearDown(() {
    if (!root.existsSync()) return;
    // A test may have left the contents directory read-only.
    final contents = Directory('${root.path}/contents');
    if (contents.existsSync()) Process.runSync('chmod', ['700', contents.path]);
    root.deleteSync(recursive: true);
  });

  var clockTicks = 0;

  PresetContent preset(String id, String language, String text) =>
      PresetContent(id: id, language: language, text: text);

  ContentStore store({List<PresetContent> catalog = const []}) => ContentStore(
        directory: root,
        loadCatalog: () async => catalog,
        // A ticking clock: deterministic, yet distinct per operation so
        // `updatedAt > createdAt` is observable.
        now: () => DateTime.utc(2026, 9, 23, 10, 22, 3, 114)
            .add(Duration(seconds: clockTicks++)),
      );

  // A plain function, not a getter: local getters are not a thing in Dart.
  File indexFile() => File('${root.path}/index.json');

  List<File> txtFiles() => Directory(root.path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  group('first launch', () {
    test('seeds the index from the catalog and writes no content files',
        () async {
      final s = store(catalog: [
        preset('preset_en_sample', 'en', 'Hello there.'),
        preset('preset_zh_sample', 'zh-Hans', '你好。'),
      ]);

      final entries = await s.list();

      expect(entries, hasLength(2));
      expect(entries.every((e) => e.isPreset), isTrue);
      expect(entries.map((e) => e.id),
          containsAll(['preset_en_sample', 'preset_zh_sample']));
      // A pre-set's text comes from the catalog, never from contents/.
      expect(await s.read(entries.first), 'Hello there.');
      expect(indexFile().existsSync(), isTrue);
      expect(txtFiles(), isEmpty, reason: 'pre-sets are not copied to disk');
    });

    test('seeds an empty library when the catalog is empty', () async {
      expect(await store().list(), isEmpty);
      final written = ContentIndex.decode(indexFile().readAsStringSync());
      expect(written.entries, isEmpty);
      expect(written.version, kContentIndexVersion);
    });

    test('entry timestamps are UTC and monotonic', () async {
      final entries =
          await store(catalog: [preset('preset_en_sample', 'en', 'Hi.')]).list();
      final entry = entries.single;
      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.updatedAt.isUtc, isTrue);
      expect(entry.updatedAt.isBefore(entry.createdAt), isFalse);
      // ISO-8601 UTC on disk, i.e. the repair path never sees a local time.
      final raw = indexFile().readAsStringSync();
      expect(raw, contains(entry.createdAt.toIso8601String()));
      expect(raw, contains('Z"'));
    });
  });

  group('round trip (contract invariants 5 and 6)', () {
    test('an index survives one encode/decode unchanged', () {
      final index = ContentIndex(
        entries: [
          SavedContent(
            id: 'c_1758609612000_1a2b',
            name: 'The sun rose over the quiet town',
            language: 'en',
            origin: ContentOrigin.user,
            createdAt: DateTime.utc(2026, 9, 23, 10, 22, 3, 114),
            updatedAt: DateTime.utc(2026, 9, 23, 10, 31, 47, 902),
            charCount: 412,
          ),
          SavedContent(
            id: 'preset_es_sample',
            name: 'El sol salió sobre el pueblo',
            language: 'es',
            origin: ContentOrigin.preset,
            createdAt: DateTime.utc(2026, 9, 23, 10, 0),
            updatedAt: DateTime.utc(2026, 9, 23, 10, 0),
            charCount: 240,
          ),
        ],
        deletedPresetIds: ['preset_zh_sample'],
        lastOpenedId: 'c_1758609612000_1a2b',
      );

      final restored = ContentIndex.decode(index.encode());

      expect(restored.entries, index.entries);
      expect(restored.deletedPresetIds, index.deletedPresetIds);
      expect(restored.lastOpenedId, index.lastOpenedId);
      expect(restored.entries.first.origin, ContentOrigin.user);
      expect(restored.entries.last.origin, ContentOrigin.preset);
    });

    test('an unknown version is unsupported, not silently migrated', () {
      expect(
        () => ContentIndex.decode('{"version":99,"entries":[],'
            '"deletedPresetIds":[],"lastOpenedId":null}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a malformed entry makes the payload unparsable', () {
      expect(
        () => ContentIndex.decode('{"version":1,"entries":[{"id":"c_1"}],'
            '"deletedPresetIds":[],"lastOpenedId":null}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('an entry whose updatedAt precedes createdAt is malformed', () {
      expect(
        () => ContentIndex.decode('{"version":1,"entries":[{"id":"c_1",'
            '"name":"x","language":"en","origin":"user",'
            '"createdAt":"2026-09-23T10:00:00.000Z",'
            '"updatedAt":"2026-09-23T09:00:00.000Z","charCount":5}],'
            '"deletedPresetIds":[],"lastOpenedId":null}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('repair path (contract error states)', () {
    test('an unparsable index is moved aside, re-seeded and reported',
        () async {
      indexFile().writeAsStringSync('{not json at all');

      final s = store(catalog: [preset('preset_en_sample', 'en', 'Hi.')]);
      final entries = await s.list();

      expect(entries.single.id, 'preset_en_sample');
      expect(s.lastError, ContentError.indexRepaired);
      final movedAside = Directory(root.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('index.corrupt-'))
          .toList();
      expect(movedAside, hasLength(1));
      expect(movedAside.single.readAsStringSync(), '{not json at all');
      // The repaired index is usable: a second read does not report again.
      expect(await store(catalog: []).list(), hasLength(1));
    });

    test('an unsupported version takes the same repair path', () async {
      indexFile().writeAsStringSync(
          '{"version":99,"entries":[],"deletedPresetIds":[],"lastOpenedId":null}');

      final s = store(catalog: [preset('preset_en_sample', 'en', 'Hi.')]);

      expect(await s.list(), hasLength(1));
      expect(s.lastError, ContentError.indexRepaired);
    });
  });

  group('damaged entries (contract error states)', () {
    test('an entry whose text file is gone is listed damaged, never fatal',
        () async {
      final index = ContentIndex(entries: [
        SavedContent(
          id: 'c_1758609612000_1a2b',
          name: 'Gone',
          language: 'en',
          origin: ContentOrigin.user,
          createdAt: DateTime.utc(2026, 9, 23, 10, 0),
          updatedAt: DateTime.utc(2026, 9, 23, 10, 0),
          charCount: 12,
        ),
      ]);
      indexFile().writeAsStringSync(index.encode());

      final s = store();
      final entries = await s.list();

      expect(entries.single.damaged, isTrue);
      expect(() => s.read(entries.single),
          throwsA(isA<ContentStoreException>()));
    });
  });

  group('crash leftovers (contract write protocol)', () {
    test('a .tmp left by a crash is ignored on load', () async {
      Directory('${root.path}/contents').createSync(recursive: true);
      File('${root.path}/contents/c_1758609612000_1a2b.txt.tmp')
          .writeAsStringSync('half written');

      final entries = await store().list();

      expect(entries, isEmpty);
    });
  });

  group('saving user content (US1)', () {
    test('saveNew writes the text file and an auto-named index entry',
        () async {
      final s = store();

      final saved = await s.saveNew('Morning notes\nsecond line.');

      expect(saved.origin, ContentOrigin.user);
      expect(saved.name, 'Morning notes');
      expect(saved.language, 'en');
      expect(RegExp(r'^c_\d+_[0-9a-f]{4}$').hasMatch(saved.id), isTrue,
          reason: 'ids are time-ordered and collision-resistant (D8)');
      expect(saved.charCount, 'Morning notes\nsecond line.'.length);
      expect(saved.updatedAt.isBefore(saved.createdAt), isFalse);
      expect(File('${root.path}/contents/${saved.id}.txt').readAsStringSync(),
          'Morning notes\nsecond line.');
      expect((await s.list()).single.id, saved.id);
      expect(await s.read(saved), 'Morning notes\nsecond line.');
    });

    test('two saves of the same text get distinct names and ids', () async {
      final s = store();

      final first = await s.saveNew('Notes');
      final second = await s.saveNew('Notes');

      expect(second.id, isNot(first.id));
      expect(second.name, 'Notes (2)');
    });

    test('saveNew prefers the caller\'s language over detection', () async {
      final s = store();

      final saved = await s.saveNew('中文内容', language: 'zh-Hans');

      expect(saved.language, 'zh-Hans');
    });

    test('saveNew refuses whitespace-only text and writes nothing', () async {
      final s = store();

      await expectLater(
        s.saveNew('   \n\t '),
        throwsA(isA<ContentStoreException>()
            .having((e) => e.kind, 'kind', ContentError.emptyText)),
      );

      expect(await s.list(), isEmpty);
      expect(txtFiles(), isEmpty);
    });

    test('saveNew refuses more than 100,000 characters and truncates nothing',
        () async {
      final s = store();
      final oversized = 'a' * (kMaxContentChars + 1);

      await expectLater(
        s.saveNew(oversized),
        throwsA(isA<ContentStoreException>()
            .having((e) => e.kind, 'kind', ContentError.tooLarge)),
      );

      expect(await s.list(), isEmpty);
      expect(txtFiles(), isEmpty);
    });

    test('exactly 100,000 characters is accepted', () async {
      final s = store();

      final saved = await s.saveNew('b' * kMaxContentChars);

      expect(saved.charCount, kMaxContentChars);
      expect((await s.read(saved)).length, kMaxContentChars);
    });

    test('update keeps id, name and createdAt and bumps updatedAt', () async {
      final s = store();
      final saved = await s.saveNew('Keep the name.');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final updated = await s.update(saved, 'Keep the name.\nMore text.');

      expect(updated.id, saved.id);
      expect(updated.name, saved.name);
      expect(updated.createdAt, saved.createdAt);
      expect(updated.updatedAt.isAfter(saved.updatedAt), isTrue);
      expect(updated.charCount, 'Keep the name.\nMore text.'.length);
      expect(await s.read(updated), 'Keep the name.\nMore text.');
      expect((await s.list()).single.id, saved.id);
    });

    test('update refuses a pre-set: pre-sets are saved as new content',
        () async {
      final s = store(catalog: [preset('preset_en_sample', 'en', 'Sample.')]);
      final preSet = (await s.list()).single;

      await expectLater(
        s.update(preSet, 'Edited sample.'),
        throwsArgumentError,
      );

      expect(await s.read(preSet), 'Sample.');
    });

    test('delete removes a user entry and its file', () async {
      final s = store();
      final saved = await s.saveNew('Doomed.');
      final file = File('${root.path}/contents/${saved.id}.txt');
      expect(file.existsSync(), isTrue);

      await s.delete(saved);

      expect(await s.list(), isEmpty);
      expect(file.existsSync(), isFalse);
      expect(txtFiles(), isEmpty);
    });

    test('a failed write leaves the index and the library untouched',
        () async {
      final s = store();
      final first = await s.saveNew('Keep me safe.');
      final indexBefore = indexFile().readAsStringSync();
      final contents = Directory('${root.path}/contents');
      // A read-only directory refuses the new file exactly like a full disk.
      Process.runSync('chmod', ['500', contents.path]);
      addTearDown(() => Process.runSync('chmod', ['700', contents.path]));

      await expectLater(
        s.saveNew('Never written.'),
        throwsA(isA<ContentStoreException>()
            .having((e) => e.kind, 'kind', ContentError.ioError)),
      );

      expect(indexFile().readAsStringSync(), indexBefore);
      final entries = await s.list();
      expect(entries.map((e) => e.id), [first.id]);
      expect(await s.read(entries.single), 'Keep me safe.');
      expect(s.lastError, ContentError.ioError);
    });

    test('a .tmp left by a crash is deleted on the next save', () async {
      Directory('${root.path}/contents').createSync(recursive: true);
      final stale = File('${root.path}/contents/c_1_dead.txt.tmp')
        ..writeAsStringSync('half written');
      final s = store();

      await s.saveNew('Fresh.');

      expect(stale.existsSync(), isFalse);
    });

    test('list() orders entries by updatedAt descending', () async {
      final s = store();
      final older = await s.saveNew('Older.');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final newer = await s.saveNew('Newer.');

      final entries = await s.list();

      expect(entries.map((e) => e.id), [newer.id, older.id]);
    });

    test('markOpened and lastOpened survive a restart', () async {
      final s = store();
      final saved = await s.saveNew('Remember me.');
      await s.markOpened(saved.id);

      final reopened = store();

      final last = await reopened.lastOpened();
      expect(last?.id, saved.id);
      expect(await reopened.read(last!), 'Remember me.');
    });

    test('lastOpened is cleared when it points at a deleted entry', () async {
      final s = store();
      final saved = await s.saveNew('Temporary.');
      await s.markOpened(saved.id);
      await s.delete(saved);

      final reopened = store();

      expect(await reopened.lastOpened(), isNull);
    });
  });

  group('pre-set management (US2, T017)', () {
    test('a deleted pre-set stays gone across a restart (tombstone)',
        () async {
      final catalog = [
        preset('preset_en_sample', 'en', 'Hello there.'),
        preset('preset_zh_sample', 'zh-Hans', '你好。'),
      ];
      final s = store(catalog: catalog);
      final zh = (await s.list()).firstWhere((e) => e.id == 'preset_zh_sample');

      await s.delete(zh);

      // The same catalog ships again on the next launch: the tombstone wins.
      final reopened = store(catalog: catalog);
      final after = await reopened.list();
      expect(after.map((e) => e.id), ['preset_en_sample']);
      expect(await reopened.read(after.single), 'Hello there.');
    });

    test('editing a pre-set creates new content and leaves the original intact',
        () async {
      final s = store(catalog: [preset('preset_en_sample', 'en', 'Sample.')]);
      final preSet = (await s.list()).single;

      final edited = await s.saveEdited(preSet, 'Edited sample.');

      expect(edited.origin, ContentOrigin.user);
      expect(edited.id, isNot(preSet.id));
      expect(await s.read(edited), 'Edited sample.');
      // The original is untouched and still served from the catalog — never
      // copied into contents/ (FR-019, SC-010).
      expect(await s.read(preSet), 'Sample.');
      expect((await s.catalog()).single.text, 'Sample.');
      expect(File('${root.path}/contents/${preSet.id}.txt').existsSync(), isFalse);
      expect(txtFiles().map((f) => f.path.split('/').last), ['${edited.id}.txt']);
    });

    test('saveEdited updates a user entry in place, with no duplicate',
        () async {
      final s = store();
      final mine = await s.saveNew('Mine.');

      final again = await s.saveEdited(mine, 'Mine, revised.');

      expect(again.id, mine.id);
      expect(await s.read(again), 'Mine, revised.');
      expect(await s.list(), hasLength(1));
    });
  });

  group('many entries (T025, SC-005)', () {
    test('the list path returns index metadata and reads no text', () async {
      // 50 entries whose texts are bulky: if listing touched content, the
      // reads would show up here AND the metadata would have to be derived
      // from the files rather than the index.
      const count = 50;
      final s = _CountingStore(root, now: () => DateTime.utc(2026, 9, 23));
      final saved = <SavedContent>[];
      for (var i = 0; i < count; i++) {
        saved.add(await s.saveNew('entry $i\n${'x' * 4000}'));
      }
      s.textReads = 0;

      final entries = await s.list();

      expect(entries, hasLength(count));
      expect(s.textReads, 0);
      // Names and sizes come from the index, unchanged by the listing.
      final byId = {for (final e in entries) e.id: e};
      for (final entry in saved) {
        expect(byId[entry.id]!.name, entry.name);
        expect(byId[entry.id]!.charCount, entry.charCount);
      }
      // A fresh store (nothing in memory) lists the same library off disk.
      final reopened = _CountingStore(root, now: () => DateTime.utc(2026, 9, 23));
      final again = await reopened.list();
      expect(again, hasLength(count));
      expect(reopened.textReads, 0);
      expect(again.map((e) => e.id).toSet(), byId.keys.toSet());
    });
  });
}

/// Counts every text read the store does through its own [ContentStore.read]
/// seam — the listing path must never reach for content (contract invariant 1).
class _CountingStore extends ContentStore {
  _CountingStore(Directory directory, {required DateTime Function() now})
      : super(directory: directory, loadCatalog: () async => const [], now: now);

  int textReads = 0;

  @override
  Future<String> read(SavedContent entry) {
    textReads++;
    return super.read(entry);
  }
}
