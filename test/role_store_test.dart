import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/role_store.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this feature persists, and how it behaves when what it finds is not what
/// it wrote (FR-001, FR-007, FR-008, FR-021 — quickstart rows 13-14).
///
/// The store is the real one over mocked `shared_preferences`; the cases that
/// matter are the tolerant reads, because a content whose settings cannot be read
/// must still read exactly as today.
void main() {
  final saved = DateTime.utc(2026, 10, 3, 12);
  final later = DateTime.utc(2026, 10, 4, 9);

  Future<String?> rawValue() async =>
      (await SharedPreferences.getInstance()).getString(RoleStore.key);

  Future<void> storeRaw(Object? value) async {
    SharedPreferences.setMockInitialValues({
      RoleStore.key: value is String ? value : jsonEncode(value),
    });
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a fresh store', () {
    test('answers "nothing decided", and written nothing', () async {
      final settings = await RoleStore().load('content-a');
      expect(settings.isDialogue, isFalse);
      expect(settings.removed, isEmpty);
      expect(settings.voices, isEmpty);
      expect(await rawValue(), isNull);
    });
  });

  group('the text type (FR-001)', () {
    test('dialogue is stored, 标准 is the absence of the field', () async {
      final store = RoleStore();
      await store.setDialogue('content-a', dialogue: true);
      expect((await store.load('content-a')).isDialogue, isTrue);
      expect(jsonDecode((await rawValue())!),
          {'content-a': {'type': 'dialogue'}});

      await store.setDialogue('content-a', dialogue: false);
      expect((await store.load('content-a')).isDialogue, isFalse);
      // Nothing left to say about this content: the entry is gone entirely.
      expect(await rawValue(), isNull);
    });
  });

  group('a removal (FR-007)', () {
    test('is stored with the text version it was made on', () async {
      final store = RoleStore();
      await store.removeRole('content-a', name: '阿芳', at: saved);
      expect((await store.load('content-a')).removed,
          [RoleRemoval(name: '阿芳', at: saved.toIso8601String())]);
    });

    test('holds for that version and expires when the text is saved', () async {
      final store = RoleStore();
      await store.removeRole('content-a', name: '阿芳', at: saved);
      final settings = await store.load('content-a');
      expect(settings.removedFor(saved), {'阿芳'});
      expect(settings.removedFor(later), isEmpty);
      // Expired, not deleted: it is still there, with its own version.
      expect(settings.removed, hasLength(1));
    });
  });

  group('a role\'s pick (FR-012, FR-013)', () {
    const pick = VoiceChoice(
      language: 'zh-Hans',
      name: 'yue-hk-x-jar-local',
      locale: 'yue-HK',
    );

    test('is stored as its name and locale, and read back as a pick',
        () async {
      final store = RoleStore();
      await store.setVoice('content-a', role: '阿明', voice: pick);
      final read = (await store.load('content-a')).pickFor('阿明');
      expect(read!.name, pick.name);
      expect(read.locale, pick.locale);
      // The language is the voice's own locale's list — the stored shape carries
      // no language field (data-model.md §5).
      expect(read.language, 'zh-Hans');
    });

    test('clearing it returns the role to the automatic assignment', () async {
      final store = RoleStore();
      await store.setVoice('content-a', role: '阿明', voice: pick);
      await store.setVoice('content-a', role: '阿明', voice: null);
      expect((await store.load('content-a')).pickFor('阿明'), isNull);
      expect(await rawValue(), isNull);
    });
  });

  group('per content (FR-008, FR-021)', () {
    test('each content keeps its own entry, and a delete removes one', () async {
      final store = RoleStore();
      await store.setDialogue('content-a', dialogue: true);
      await store.setDialogue('content-b', dialogue: true);
      await store.setVoice(
        'content-b',
        role: '阿明',
        voice: const VoiceChoice(
            language: 'en', name: 'en-us-x-sfg-local', locale: 'en-US'),
      );

      await store.clearFor('content-a');

      expect((await store.load('content-a')).isDialogue, isFalse);
      final b = await store.load('content-b');
      expect(b.isDialogue, isTrue);
      expect(b.pickFor('阿明'), isNotNull);
    });
  });

  group('tolerant reads (FR-021)', () {
    test('a store that is not JSON, or not an object, is "nothing decided"',
        () async {
      for (final raw in ['{ not json', '"a string"', '[]', '42']) {
        await storeRaw(raw);
        expect((await RoleStore().load('content-a')).isDialogue, isFalse,
            reason: raw);
      }
    });

    test('a malformed entry is ignored and the readable ones are kept',
        () async {
      await storeRaw({
        'bad': 'not an object',
        'good': {'type': 'dialogue'},
      });
      final store = RoleStore();
      expect((await store.load('bad')).isDialogue, isFalse);
      expect((await store.load('good')).isDialogue, isTrue);
    });

    test('a type that is not "dialogue" reads as 标准', () async {
      for (final type in [1, true, 'standard', 'Dialogue', null]) {
        await storeRaw({
          'content-a': {'type': type},
        });
        expect((await RoleStore().load('content-a')).isDialogue, isFalse,
            reason: '$type');
      }
    });

    test('malformed removals and picks are dropped, the rest survives',
        () async {
      await storeRaw({
        'content-a': {
          'type': 'dialogue',
          'removed': [
            {'name': '阿芳', 'at': saved.toIso8601String()},
            {'name': 'lone'},
            {'at': 'no name'},
            'not an object',
          ],
          'voices': {
            '阿明': {'name': 'yue-hk-x-jar-local', 'locale': 'yue-HK'},
            '阿芳': {'name': 'a voice', 'locale': 'fr-FR'},
            '阿空': 'not an object',
            '阿无': {'locale': 'en-US'},
          },
        },
      });
      final settings = await RoleStore().load('content-a');
      expect(settings.removed, hasLength(1));
      expect(settings.removed.single.name, '阿芳');
      expect(settings.voices.keys, ['阿明']);
    });

    test('an unreadable pick is no pick: the role follows the assignment',
        () async {
      await storeRaw({
        'content-a': {
          'voices': {
            '阿明': {'name': 'voix', 'locale': 'fr-FR'},
          },
        },
      });
      expect((await RoleStore().load('content-a')).pickFor('阿明'), isNull);
    });
  });
}
