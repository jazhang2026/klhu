/// Spec 034: read-language resolution — the precedence seam, the persisted
/// fields on `SavedContent`, the store round-trip, and `resolveSpeeches`
/// honoring content/role overrides.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/read_language.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/voice_store.dart';

void main() {
  group('resolveReadLanguage precedence (US1/US2)', () {
    test('role override wins over main and detection', () {
      expect(
        resolveReadLanguage(
            detected: 'en', main: 'es', role: '阿明', roleLangs: const {'阿明': 'zh-Hans'}),
        'zh-Hans',
      );
    });

    test('role auto falls through to main', () {
      expect(
        resolveReadLanguage(
            detected: 'en', main: 'es', role: '阿明', roleLangs: const {'阿明': 'auto'}),
        'es',
      );
    });

    test('main wins over detection when set', () {
      expect(resolveReadLanguage(detected: 'en', main: 'es'), 'es');
    });

    test('auto everywhere returns the detector answer', () {
      expect(resolveReadLanguage(detected: 'es'), 'es');
      expect(
        resolveReadLanguage(
            detected: 'es', main: 'auto', role: 'x', roleLangs: const {}),
        'es',
      );
    });

    test('unknown role name falls back to main/detection', () {
      expect(
        resolveReadLanguage(
            detected: 'en', role: '旁白', roleLangs: const {'阿明': 'es'}),
        'en',
      );
    });
  });

  group('SavedContent read-language fields', () {
    test('json round-trip preserves readLang and roleLangs', () {
      final entry = SavedContent(
        id: 'a',
        name: 'n',
        language: 'en',
        origin: ContentOrigin.user,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        charCount: 3,
        readLang: 'es',
        roleLangs: const {'阿明': 'en'},
        commentLang: 'zh-Hans',
      );
      final back = SavedContent.fromJson(entry.toJson());
      expect(back.readLang, 'es');
      expect(back.roleLangs, {'阿明': 'en'});
      expect(back.commentLang, 'zh-Hans');
      expect(back, entry);
    });

    test('legacy record without the fields reads as auto', () {
      final json = SavedContent(
        id: 'a',
        name: 'n',
        language: 'en',
        origin: ContentOrigin.user,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        charCount: 3,
      ).toJson()
        ..remove('readLang')
        ..remove('roleLangs')
        ..remove('commentLang');
      final back = SavedContent.fromJson(json);
      expect(back.readLang, 'auto');
      expect(back.roleLangs, isEmpty);
      expect(back.commentLang, 'auto');
    });
  });

  group('ContentStore.setReadLanguage', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('klhu-readlang-test');
    });
    tearDown(() => root.deleteSync(recursive: true));

    ContentStore store() => ContentStore(
          directory: root,
          loadCatalog: () async => const [],
          now: () => DateTime.utc(2026, 1, 1),
        );

    test('persists readLang and roleLangs, survives reload', () async {
      final s = store();
      final entry = await s.saveNew('Hello world.');
      final updated = await s.setReadLanguage(
        entry,
        readLang: 'es',
        roleLangs: const {'阿明': 'zh-Hans'},
        commentLang: 'en',
      );
      expect(updated.readLang, 'es');
      expect(updated.roleLangs, {'阿明': 'zh-Hans'});
      expect(updated.commentLang, 'en');
      // updatedAt untouched: a settings change is not content activity.
      expect(updated.updatedAt, entry.updatedAt);

      final reloaded = await store().list();
      final found = reloaded.firstWhere((e) => e.id == entry.id);
      expect(found.readLang, 'es');
      expect(found.roleLangs, {'阿明': 'zh-Hans'});
      expect(found.commentLang, 'en');
    });

    test('refuses presets', () async {
      final s = ContentStore(
        directory: root,
        loadCatalog: () async => [
          PresetContent(id: 'p1', language: 'en', text: 'Hi.'),
        ],
        now: () => DateTime.utc(2026, 1, 1),
      );
      final preset = (await s.list()).first;
      expect(preset.isPreset, isTrue);
      expect(() => s.setReadLanguage(preset, readLang: 'es'),
          throwsArgumentError);
    });
  });

  group('resolveSpeeches honors overrides (US1/US2 evidence)', () {
    Future<VoiceChoice?> noVoice(String language) async => null;

    test('readLang pins every standard paragraph language', () async {
      const content = 'Hello there.\n\nThis is fine English.';
      final speeches = await resolveSpeeches(
        content: content,
        readLang: 'es',
        loadVoice: noVoice,
      );
      expect(speeches, isNotEmpty);
      expect(speeches.every((s) => s.language == 'es'), isTrue);
    });

    test('roleLangs pins only that role\'s turns', () async {
      const content = '{阿明} 你好。\n\n{Bob} 你好。\n\n旁白一句。';
      final speeches = await resolveSpeeches(
        content: content,
        mode: ReadingMode.dialogue,
        roleLangs: const {'阿明': 'en'},
        loadVoice: noVoice,
        loadInstalled: () async => const [],
      );
      final byRole = {for (final s in speeches) s.role: s.language};
      expect(byRole['阿明'], 'en');
      expect(byRole['Bob'], 'zh-Hans');
    });

    test('main readLang reaches dialogue turns without role picks', () async {
      const content = '{阿明} 你好。\n\n{Bob} Hello there.';
      final speeches = await resolveSpeeches(
        content: content,
        mode: ReadingMode.dialogue,
        readLang: 'es',
        loadVoice: noVoice,
        loadInstalled: () async => const [],
      );
      expect(speeches.every((s) => s.language == 'es'), isTrue);
    });

    // 034 amendment FR-015: the comment setting is its own — 'auto' keeps
    // each comment's detection, an explicit pick applies to all of them,
    // and the main readLang never reaches a comment.
    test('commentLang auto keeps each comment\'s own detection', () async {
      const content = 'Hello there.\n\n[注] How are you?\n\n[注] Como estas?';
      final speeches = await resolveSpeeches(
        content: content,
        readLang: 'es', // the main pick must NOT reach comments
        loadVoice: noVoice,
      );
      final comments = speeches.where((s) => s.isComment).toList();
      expect(comments.length, 2);
      expect(comments[0].language, 'en');
      expect(comments[1].language, 'es');
    });

    test('commentLang explicit pins every comment', () async {
      const content = 'Hello there.\n\n[注] How are you?\n\n[注] Como estas?';
      final speeches = await resolveSpeeches(
        content: content,
        commentLang: 'zh-Hans',
        loadVoice: noVoice,
      );
      final comments = speeches.where((s) => s.isComment).toList();
      expect(comments.length, 2);
      expect(comments.every((s) => s.language == 'zh-Hans'), isTrue);
    });
  });
}
