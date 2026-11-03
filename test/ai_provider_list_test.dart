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

    test('has optional textModel, imageModel and videoModel', () {
      final provider = AIProvider(
        name: 'Gemini Provider',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: 'Register at aistudio',
        apiKey: 'key',
        textModel: 'gemini-3.5-flash-lite',
        imageModel: 'gemini-3.1-flash-lite-image',
        videoModel: 'gemini-omni-1.1-flash',
      );
      expect(provider.textModel, 'gemini-3.5-flash-lite');
      expect(provider.imageModel, 'gemini-3.1-flash-lite-image');
      expect(provider.videoModel, 'gemini-omni-1.1-flash');
    });

    test('model fields default to null for user-added providers', () {
      final provider = AIProvider(
        name: 'Custom',
        url: 'https://custom.example.com',
        registerTip: '',
        apiKey: 'key',
      );
      expect(provider.textModel, isNull);
      expect(provider.imageModel, isNull);
      expect(provider.videoModel, isNull);
    });

    test('copyWith replaces only the given fields', () {
      final original = AIProvider(
        name: 'Original',
        url: 'https://original.com',
        registerTip: 'tip',
        apiKey: 'old-key',
        active: false,
        selected: false,
        textModel: 'old-model',
        imageModel: 'old-image',
        videoModel: 'old-video',
      );
      final updated = original.copyWith(
        apiKey: 'new-key',
        active: true,
        textModel: 'new-text',
      );
      expect(updated.name, 'Original');
      expect(updated.url, 'https://original.com');
      expect(updated.registerTip, 'tip');
      expect(updated.apiKey, 'new-key');
      expect(updated.active, isTrue);
      expect(updated.selected, isFalse);
      expect(updated.textModel, 'new-text');
      expect(updated.imageModel, 'old-image');
      expect(updated.videoModel, 'old-video');
    });

    test('equality compares all fields including models', () {
      final a = AIProvider(
        name: 'Same',
        url: 'https://same.com',
        registerTip: 'tip',
        apiKey: 'key',
        active: true,
        selected: false,
        textModel: 'model-a',
        imageModel: 'img-a',
        videoModel: 'vid-a',
      );
      final b = AIProvider(
        name: 'Same',
        url: 'https://same.com',
        registerTip: 'tip',
        apiKey: 'key',
        active: true,
        selected: false,
        textModel: 'model-a',
        imageModel: 'img-a',
        videoModel: 'vid-a',
      );
      final c = a.copyWith(textModel: 'different');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('the preset seed (FR-002)', () {
    test('ships with four presets in the right order', () {
      expect(AIProvider.presets.length, 4);
      expect(AIProvider.presets[0].name, 'Agnes AI');
      expect(AIProvider.presets[1].name, 'Google AI Studio (Gemini)');
      expect(AIProvider.presets[2].name, 'OpenRouter (:free)');
      expect(AIProvider.presets[3].name, 'NVIDIA NIM');
    });

    test('each preset has a register tip and an empty API key', () {
      // Agnes AI ships active and selected; the rest do not.
      for (final preset in AIProvider.presets) {
        expect(preset.registerTip.isNotEmpty, isTrue);
        expect(preset.apiKey, isEmpty);
        if (preset.name == 'Agnes AI') {
          expect(preset.active, isTrue);
          expect(preset.selected, isTrue);
        } else {
          expect(preset.active, isFalse);
          expect(preset.selected, isFalse);
        }
      }
    });

    test('the first preset is selected by default', () {
      expect(AIProvider.presets[0].selected, isTrue);
      expect(AIProvider.presets[1].selected, isFalse);
      expect(AIProvider.presets[2].selected, isFalse);
      expect(AIProvider.presets[3].selected, isFalse);
    });

    test('each preset has its own url', () {
      expect(AIProvider.presets[0].url, contains('agnes-ai.com'));
      expect(
        AIProvider.presets[1].url,
        contains('generativelanguage.googleapis.com'),
      );
      expect(AIProvider.presets[2].url, contains('openrouter.ai'));
      expect(AIProvider.presets[3].url, contains('nvidia.com'));
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
        textModel: 'gemini-3.5-flash-lite',
        imageModel: 'gemini-3.1-flash-lite-image',
        videoModel: 'gemini-omni-1.1-flash',
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

    test('fromJson tolerates missing model fields', () {
      final json = <String, Object?>{
        'name': 'No Models',
        'url': 'https://no-models.com',
        'apiKey': 'key',
      };
      final provider = AIProvider.fromJson(json);
      expect(provider.name, 'No Models');
      expect(provider.textModel, isNull);
      expect(provider.imageModel, isNull);
      expect(provider.videoModel, isNull);
    });
  });
}
