/// Unit tests for `lib/ai/skill.dart` and `lib/ai/skill_store.dart`.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/prompt.dart';
import 'package:klhu/ai/skill.dart';
import 'package:klhu/ai/skill_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AISkillStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = AISkillStore();
  });

  group('AISkill', () {
    test('fromJson round-trips', () {
      const skill = AISkill(
        id: 'story',
        name: 'Story',
        description: 'A narrative',
        template: 'Write about {{topic}}',
        defaultType: AIPromptType.text,
        isBuiltIn: true,
      );
      final decoded = AISkill.fromJson(skill.toJson());
      expect(decoded.id, skill.id);
      expect(decoded.name, skill.name);
      expect(decoded.description, skill.description);
      expect(decoded.template, skill.template);
      expect(decoded.defaultType, AIPromptType.text);
      expect(decoded.isBuiltIn, true);
    });

    test('fromJson handles missing fields gracefully', () {
      final decoded = AISkill.fromJson({});
      expect(decoded.id, '');
      expect(decoded.name, '');
      expect(decoded.defaultType, AIPromptType.text);
      expect(decoded.isBuiltIn, true);
    });

    test('copyWith creates a new instance', () {
      const original = AISkill(
        id: 's',
        name: 'Story',
        description: 'd',
        template: 't',
      );
      final copy = original.copyWith(name: 'New Story');
      expect(copy.name, 'New Story');
      expect(original.name, 'Story'); // unchanged
    });

    test('equality is by id and name', () {
      const a = AISkill(id: 'x', name: 'X', description: 'd', template: 't');
      const b = AISkill(id: 'x', name: 'X', description: 'other', template: 'other');
      expect(a == b, isTrue);
    });
  });

  group('AISkillStore', () {
    test('load returns built-in skills when nothing stored', () async {
      final skills = await store.load();
      expect(skills.length, 3);
      expect(skills.every((s) => s.isBuiltIn), isTrue);
      final ids = skills.map((s) => s.id).toList();
      expect(ids, contains('story'));
      expect(ids, contains('dialogue'));
      expect(ids, contains('lesson'));
    });

    test('load merges custom skills with built-ins', () async {
      final custom = AISkill(
        id: 'my-custom',
        name: 'My Custom',
        description: 'desc',
        template: 'custom template',
        isBuiltIn: false,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_skills', '[${jsonEncode(custom.toJson())}]');

      final skills = await store.load();
      expect(skills.length, 4); // 3 built-in + 1 custom
      expect(skills.any((s) => s.id == 'my-custom'), isTrue);
      expect(skills.any((s) => s.isBuiltIn), isTrue);
    });

    test('upsert adds a new custom skill', () async {
      final custom = AISkill(
        id: 'unique-id',
        name: 'Unique',
        description: 'desc',
        template: 'template',
        isBuiltIn: false,
      );
      await store.upsert(custom);

      final skills = await store.load();
      expect(skills.any((s) => s.id == 'unique-id'), isTrue);
      expect(skills.any((s) => s.name == 'Unique'), isTrue);
    });

    test('upsert replaces an existing custom skill', () async {
      final first = AISkill(
        id: 'same-id',
        name: 'First',
        description: 'd1',
        template: 't1',
        isBuiltIn: false,
      );
      final second = first.copyWith(name: 'Second', template: 't2');
      await store.upsert(first);
      await store.upsert(second);

      final skills = await store.load();
      final updated = skills.firstWhere((s) => s.id == 'same-id');
      expect(updated.name, 'Second');
      expect(updated.template, 't2');
    });

    test('delete removes a custom skill', () async {
      final custom = AISkill(
        id: 'to-delete',
        name: 'Delete Me',
        description: 'd',
        template: 't',
        isBuiltIn: false,
      );
      await store.upsert(custom);
      final deleted = await store.delete('to-delete');
      expect(deleted, isTrue);

      final skills = await store.load();
      expect(skills.any((s) => s.id == 'to-delete'), isFalse);
    });

    test('delete returns false for non-existent id', () async {
      final deleted = await store.delete('nonexistent');
      expect(deleted, isFalse);
    });

    test('built-in skills cannot be deleted', () async {
      final deleted = await store.delete('story');
      expect(deleted, isFalse);

      final skills = await store.load();
      expect(skills.any((s) => s.id == 'story'), isTrue);
    });
  });
}
