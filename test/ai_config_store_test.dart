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
    test('returns the four presets, with the first selected', () async {
      final store = AIConfigStore();
      final providers = await store.load();
      expect(providers.length, 4);
      expect(providers[0].name, 'Agnes AI');
      expect(providers[1].name, 'Google AI Studio (Gemini)');
      expect(providers[2].name, 'OpenRouter (:free)');
      expect(providers[3].name, 'NVIDIA NIM');
      expect(providers[0].selected, isTrue);
      expect(providers[1].selected, isFalse);
      expect(providers[2].selected, isFalse);
      expect(providers[3].selected, isFalse);
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
      expect(loaded.length, 5);
      expect(loaded.last.name, 'Custom Provider');
      expect(loaded.last.url, 'https://custom.example.com');
      expect(loaded.last.apiKey, 'custom-key');
      // The first preset is still selected.
      expect(loaded[0].selected, isTrue);
    });

    test('stores and reloads provider model overrides', () async {
      final store = AIConfigStore();
      var providers = await store.load();
      // Update the Gemini preset with explicit models.
      providers = providers.map((p) {
        if (p.name == 'Google AI Studio (Gemini)') {
          return p.copyWith(
            textModel: 'gemini-3.5-flash-lite',
            imageModel: 'gemini-3.1-flash-lite-image',
            videoModel: 'gemini-omni-1.1-flash',
          );
        }
        return p;
      }).toList();
      await store.save(providers);

      final loaded = await store.load();
      final gemini = loaded.firstWhere(
        (p) => p.name == 'Google AI Studio (Gemini)',
        orElse: () => throw Exception('not found'),
      );
      expect(gemini.textModel, 'gemini-3.5-flash-lite');
      expect(gemini.imageModel, 'gemini-3.1-flash-lite-image');
      expect(gemini.videoModel, 'gemini-omni-1.1-flash');
    });

    test('a malformed stored value is tolerated — returns presets', () async {
      await (await SharedPreferences.getInstance())
          .setString(storeKey, 'not-json');
      final store = AIConfigStore();
      final providers = await store.load();
      expect(providers.length, 4);
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
      // The partial entry is preserved and missing presets are merged in.
      expect(providers.length, greaterThan(1));
      expect(providers.any((p) => p.name == 'Partial'), isTrue);
    });

    test('missing presets are merged into stored data (migration)', () async {
      // Simulate old stored data with only 3 presets (no Agnes AI).
      final oldProviders = AIProvider.presets
          .where((p) => p.name != 'Agnes AI')
          .map((p) => p.toJson())
          .toList();
      await (await SharedPreferences.getInstance()).setString(
        storeKey,
        jsonEncode(oldProviders),
      );
      final store = AIConfigStore();
      final providers = await store.load();
      // Agnes AI should now be present even though it wasn't stored.
      expect(providers.length, 4);
      expect(providers.any((p) => p.name == 'Agnes AI'), isTrue);
      // The existing stored entries are preserved.
      expect(providers.any((p) => p.name == 'Google AI Studio (Gemini)'), isTrue);
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
      // Agnes AI (index 0) is active, so it gets auto-selected.
      expect(loaded[0].selected, isTrue);
      expect(loaded[0].name, 'Agnes AI');
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

    test(
        'when multiple providers are selected, only the first active one'
        ' remains selected (Q10)', () async {
      final store = AIConfigStore();
      var providers = await store.load();
      // Mark multiple providers as selected.
      providers = providers
          .map((p) => p.copyWith(selected: true, active: true))
          .toList();
      await store.save(providers);

      final loaded = await store.load();
      // Only the first active provider should be selected.
      expect(loaded.where((p) => p.selected).length, 1);
      expect(loaded[0].selected, isTrue);
      expect(loaded[0].name, 'Agnes AI');
      // Others should not be selected.
      expect(loaded[1].selected, isFalse);
      expect(loaded[2].selected, isFalse);
      expect(loaded[3].selected, isFalse);
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
