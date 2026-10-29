/// 029 — the AI config store persistence layer (spec FR-002, FR-003; data-model
/// §1/§2).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:klhu/ai/prompt.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final storeKey = AIConfigStore.providersKey;
  final typeKey = AIConfigStore.lastTypeKey;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a fresh store', () {
    test('returns the three presets, with the first selected', () async {
      final store = AIConfigStore();
      final providers = await store.load();
      expect(providers.length, 3);
      expect(providers[0].name, 'Google AI Studio (Gemini)');
      expect(providers[1].name, 'OpenRouter (:free)');
      expect(providers[2].name, 'NVIDIA NIM');
      expect(providers[0].selected, isTrue);
      expect(providers[1].selected, isFalse);
      expect(providers[2].selected, isFalse);
      // Nothing written yet — the store returned the in-memory default.
      expect((await SharedPreferences.getInstance()).getString(storeKey),
          isNull);
    });
  });

  group('save and reload (FR-002, FR-003)', () {
    test('stores a user-added provider and reads it back', () async {
      final store = AIConfigStore();
      // Start from the seed.
      var providers = await store.load();
      // Add a user provider.
      final userProvider = AIProvider(
        name: 'Custom Provider',
        url: 'https://custom.example.com',
        registerTip: 'Go to custom.example.com',
        apiKey: 'custom-key',
        active: false,
        selected: false,
      );
      providers = [...providers, userProvider];
      await store.save(providers);

      final loaded = await store.load();
      expect(loaded.length, 4);
      expect(loaded.last.name, 'Custom Provider');
      expect(loaded.last.url, 'https://custom.example.com');
      expect(loaded.last.apiKey, 'custom-key');
      // The first preset is still selected.
      expect(loaded[0].selected, isTrue);
    });

    test('a malformed stored value is tolerated — returns presets', () async {
      await (await SharedPreferences.getInstance())
          .setString(storeKey, 'not-json');
      final store = AIConfigStore();
      final providers = await store.load();
      expect(providers.length, 3);
    });

    test('a stored entry with missing fields falls back gracefully', () async {
      final partial = <Map<String, Object?>>[
        {'name': 'Partial'},
      ];
      await (await SharedPreferences.getInstance()).setString(
        storeKey,
        jsonEncode(partial),
      );
      final store = AIConfigStore();
      final providers = await store.load();
      expect(providers.length, 1);
      expect(providers[0].name, 'Partial');
      expect(providers[0].url, isEmpty);
      expect(providers[0].apiKey, isEmpty);
    });
  });

  group('active and selected flags', () {
    test('active is persisted and read back', () async {
      final store = AIConfigStore();
      var providers = await store.load();
      providers = providers
          .map((p) =>
              p.name == 'OpenRouter (:free)' ? p.copyWith(active: true) : p)
          .toList();
      await store.save(providers);

      final loaded = await store.load();
      final openrouter = loaded.singleWhere(
          (p) => p.name == 'OpenRouter (:free)',
          orElse: () => throw Exception('not found'));
      expect(openrouter.active, isTrue);
    });

    test(
        'when no provider is selected, the first active one is auto-selected'
        ' (Q10)', () async {
      final store = AIConfigStore();
      var providers = await store.load();
      // Make the second preset active but not selected; clear selection on all.
      providers = providers.map((p) => p.copyWith(selected: false)).toList();
      providers[1] = providers[1].copyWith(active: true);
      await store.save(providers);

      final loaded = await store.load();
      expect(loaded[0].selected, isFalse);
      expect(loaded[1].selected, isTrue);
      expect(loaded[2].selected, isFalse);
    });

    test(
        'when no provider is active, the first entry is selected as fallback'
        ' (Q10)', () async {
      final store = AIConfigStore();
      var providers = await store.load();
      providers = providers.map((p) => p.copyWith(selected: false)).toList();
      await store.save(providers);

      final loaded = await store.load();
      expect(loaded[0].selected, isTrue);
    });
  });

  group('last-picked generation type (FR-005, Q8)', () {
    test('defaults to text when nothing is stored', () async {
      final store = AIConfigStore();
      expect(await store.loadLastType(), AIPromptType.text);
    });

    test('stores and reads back image', () async {
      final store = AIConfigStore();
      await store.saveLastType(AIPromptType.image);
      expect(await store.loadLastType(), AIPromptType.image);
    });

    test('stores and reads back video', () async {
      final store = AIConfigStore();
      await store.saveLastType(AIPromptType.video);
      expect(await store.loadLastType(), AIPromptType.video);
    });

    test('a malformed stored type falls back to text', () async {
      await (await SharedPreferences.getInstance())
          .setString(typeKey, 'not-a-type');
      final store = AIConfigStore();
      expect(await store.loadLastType(), AIPromptType.text);
    });
  });
}
