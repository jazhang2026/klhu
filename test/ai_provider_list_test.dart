/// 029 — the AI provider entry and the preset seed (spec FR-002, FR-003;
/// data-model §1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/provider_list.dart';

void main() {
  group('the provider entry', () {
    test('has name, url, registerTip, apiKey, active and selected', () {
      final provider = AIProvider(
        name: 'Test Provider',
        url: 'https://api.test.com',
        registerTip: 'Go to test.com/apikey',
        apiKey: 'key-123',
        active: true,
        selected: false,
      );
      expect(provider.name, 'Test Provider');
      expect(provider.url, 'https://api.test.com');
      expect(provider.registerTip, 'Go to test.com/apikey');
      expect(provider.apiKey, 'key-123');
      expect(provider.active, isTrue);
      expect(provider.selected, isFalse);
    });

    test('copyWith replaces only the given fields', () {
      final original = AIProvider(
        name: 'Original',
        url: 'https://original.com',
        registerTip: 'tip',
        apiKey: 'old-key',
        active: false,
        selected: false,
      );
      final updated = original.copyWith(
        apiKey: 'new-key',
        active: true,
      );
      expect(updated.name, 'Original');
      expect(updated.url, 'https://original.com');
      expect(updated.registerTip, 'tip');
      expect(updated.apiKey, 'new-key');
      expect(updated.active, isTrue);
      expect(updated.selected, isFalse);
    });

    test('equality compares all fields', () {
      final a = AIProvider(
        name: 'Same',
        url: 'https://same.com',
        registerTip: 'tip',
        apiKey: 'key',
        active: true,
        selected: false,
      );
      final b = AIProvider(
        name: 'Same',
        url: 'https://same.com',
        registerTip: 'tip',
        apiKey: 'key',
        active: true,
        selected: false,
      );
      final c = a.copyWith(apiKey: 'different');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('the preset seed (FR-002)', () {
    test('ships with three presets in the right order', () {
      expect(AIProvider.presets.length, 3);
      expect(AIProvider.presets[0].name, 'Google AI Studio (Gemini)');
      expect(AIProvider.presets[1].name, 'OpenRouter (:free)');
      expect(AIProvider.presets[2].name, 'NVIDIA NIM');
    });

    test('each preset has a register tip and an empty API key', () {
      for (final preset in AIProvider.presets) {
        expect(preset.registerTip.isNotEmpty, isTrue);
        expect(preset.apiKey, isEmpty);
        expect(preset.active, isFalse);
      }
    });

    test('the first preset is selected by default', () {
      expect(AIProvider.presets[0].selected, isTrue);
      expect(AIProvider.presets[1].selected, isFalse);
      expect(AIProvider.presets[2].selected, isFalse);
    });

    test('each preset has its own url', () {
      expect(
        AIProvider.presets[0].url,
        contains('generativelanguage.googleapis.com'),
      );
      expect(AIProvider.presets[1].url, contains('openrouter.ai'));
      expect(AIProvider.presets[2].url, contains('nvidia.com'));
    });
  });

  group('JSON round-trip (data-model §1)', () {
    test('toJson then fromJson round-trips', () {
      final original = AIProvider(
        name: 'My Provider',
        url: 'https://my.provider.com',
        registerTip: 'Register at my.provider.com',
        apiKey: 'my-key',
        active: true,
        selected: true,
      );
      final json = original.toJson();
      final restored = AIProvider.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson tolerates a missing field', () {
      final json = <String, Object?>{'name': 'Incomplete'};
      final provider = AIProvider.fromJson(json);
      expect(provider.name, 'Incomplete');
      expect(provider.url, isEmpty);
      expect(provider.apiKey, isEmpty);
      expect(provider.active, isFalse);
      expect(provider.selected, isFalse);
    });
  });
}
