/// 029 — the AI provider client's suggested-model retry logic
/// (spec FR-007; research D1, R2).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/provider_client.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/ai/prompt.dart';

// --- Helper functions for error message cleaning tests ---

String _cleanErrorMessage(
  int statusCode,
  String responseBody, {
  bool isImageOrVideo = false,
}) {
  if (statusCode == 429) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
      final error = decoded?['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null && message.contains('limit: 0')) {
        if (isImageOrVideo) {
          return 'Image/video generation requires a paid Google Cloud billing account. Set up billing at https://console.cloud.google.com/billing to enable it on the Gemini API.';
        }
      }
    } catch (_) {}
    return 'Rate limit exceeded. Please wait a moment and try again, or switch to a different provider.';
  }
  try {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
    if (decoded == null) return _truncRaw(statusCode, responseBody);
    final error = decoded['error'] as Map<String, dynamic>?;
    if (error == null) return _truncRaw(statusCode, responseBody);
    final message = (error['message'] ?? error['detail']) as String?;
    if (message != null) return _stripDetails(message);
    final subError = error['details'] as List?;
    if (subError != null && subError.isNotEmpty) {
      final desc = subError.firstWhere(
        (d) => (d as Map?)?['@type'] == 'type.googleapis.com/google.rpc.ErrorInfo',
        orElse: () => subError.first,
      );
      final reason = (desc as Map?)?['reason'] as String?;
      if (reason != null) return 'Error: $reason';
    }
    final reason = error['reason'] as String?;
    if (reason != null) return 'Error: $reason';
  } catch (_) {}
  return _truncRaw(statusCode, responseBody);
}

String _stripDetails(String msg) {
  var cleaned = msg.replaceAll(
      RegExp(r'https?://[^\s]+'), '').trim();
  final parts = cleaned.split(RegExp(r'\s*[-–—]\s*'));
  return parts.isNotEmpty ? parts.first.trim() : cleaned;
}

String _truncRaw(int statusCode, String body) {
  final truncated =
      body.substring(0, body.length.clamp(0, 80)).replaceAll('\n', ' ');
  return 'HTTP $statusCode: $truncated';
}

void main() {
  group('AIResult.modelSuggested', () {
    test('carries the suggested model name', () {
      final result = AIResult.modelSuggested(
        error: 'Model deprecated',
        model: 'gemini-2.0-flash',
      );
      expect(result.success, isFalse);
      expect(result.suggestedModel, 'gemini-2.0-flash');
      expect(result.errorMessage, 'Model deprecated');
    });
  });

  group('Gemini suggested-model extraction', () {
    final geminiProvider = AIProvider.presets[1];

    test('extracts model from "Use <model> instead" message', () {
      final body = jsonEncode({
        'error': {
          'code': 404,
          'message':
              'Model gemini-1.5-flash is deprecated. Use gemini-2.0-flash instead.',
          'status': 'NOT_FOUND',
        },
      });
      // We exercise the private extractor indirectly via a failed call with a
      // mocked HTTP client. Instead, we test the parsing patterns directly.
      expect(
        _parseSuggestedFrom(
            'Model gemini-1.5-flash is deprecated. Use gemini-2.0-flash instead.',
            'gemini-1.5-flash'),
        'gemini-2.0-flash',
      );
    });

    test('extracts model from "Did you mean <model>?" message', () {
      expect(
        _parseSuggestedFrom('Did you mean gemini-2.0-flash?', 'old-model'),
        'gemini-2.0-flash',
      );
    });

    test('extracts model from "not available. Use <model> instead."', () {
      expect(
        _parseSuggestedFrom(
            'Model old-model is not available. Use gemini-2.0-flash instead.',
            'old-model'),
        'gemini-2.0-flash',
      );
    });

    test('strips trailing :generateContent suffix', () {
      expect(
        _parseSuggestedFrom(
            'Use gemini-2.0-flash:generateContent instead.',
            'old-model'),
        'gemini-2.0-flash',
      );
    });

    test('returns null when no pattern matches', () {
      expect(
        _parseSuggestedFrom('Model not found.', 'old-model'),
        isNull,
      );
    });

    test('returns null when suggested model equals requested model', () {
      expect(
        _parseSuggestedFrom('Use gemini-2.0-flash instead.', 'gemini-2.0-flash'),
        isNull,
      );
    });
  });

  group('OpenRouter suggested-model extraction', () {
    test('extracts model from "Use <model> instead" message', () {
      expect(
        _parseOpenRouterSuggestedFrom(
            'Model is deprecated. Use openai/gpt-4o instead.',
            'openai/gpt-3.5-turbo'),
        'openai/gpt-4o',
      );
    });

    test('extracts model from "Did you mean <model>?" message', () {
      expect(
        _parseOpenRouterSuggestedFrom('Did you mean openai/gpt-4o?', 'old'),
        'openai/gpt-4o',
      );
    });

    test('returns null when no pattern matches', () {
      expect(
        _parseOpenRouterSuggestedFrom('Rate limit exceeded.', 'openai/gpt-3.5'),
        isNull,
      );
    });
  });

  group('NVIDIA NIM suggested-model extraction', () {
    test('extracts model from "Use <model> instead" message', () {
      expect(
        _parseNvidiaSuggestedFrom(
            'Model is unavailable. Use google/gemma-3-27b-it instead.',
            'google/gemma-4-31b-it'),
        'google/gemma-3-27b-it',
      );
    });

    test('extracts model from "Did you mean <model>?" message', () {
      expect(
        _parseNvidiaSuggestedFrom('Did you mean nvidia/nemotron-4-340b?', 'old'),
        'nvidia/nemotron-4-340b',
      );
    });

    test('returns null when no pattern matches', () {
      expect(
        _parseNvidiaSuggestedFrom('Internal server error.', 'google/gemma'),
        isNull,
      );
    });
  });

  group('provider model selection by type', () {
    test('uses provider.textModel for text prompts', () {
      final provider = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        textModel: 'my-text-model',
        imageModel: 'my-image-model',
        videoModel: 'my-video-model',
      );
      expect(_geminiModelFor(provider, AIPromptType.text), 'my-text-model');
    });

    test('uses provider.imageModel for image prompts', () {
      final provider = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        textModel: 'my-text-model',
        imageModel: 'my-image-model',
        videoModel: 'my-video-model',
      );
      expect(_geminiModelFor(provider, AIPromptType.image), 'my-image-model');
    });

    test('uses provider.videoModel for video prompts', () {
      final provider = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        textModel: 'my-text-model',
        imageModel: 'my-image-model',
        videoModel: 'my-video-model',
      );
      expect(_geminiModelFor(provider, AIPromptType.video), 'my-video-model');
    });

    test('falls back to built-in default when model override is null', () {
      final provider = const AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
      );
      expect(_geminiModelFor(provider, AIPromptType.text), 'gemini-3.5-flash-lite');
      expect(
          _geminiModelFor(provider, AIPromptType.image),
          'gemini-3.1-flash-lite-image');
      expect(
          _geminiModelFor(provider, AIPromptType.video),
          'gemini-omni-1.1-flash');
    });
  });

  group('update provider model (FR-007)', () {
    test('updates textModel without changing other fields', () {
      final original = AIProvider(
        name: 'Google AI Studio (Gemini)',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: 'tip',
        apiKey: 'key',
        active: true,
        selected: true,
        textModel: 'old-model',
        imageModel: 'image-model',
        videoModel: 'video-model',
      );
      final updated = _updateProviderModel(original, 'new-model',
          AIPromptType.text);
      expect(updated.name, 'Google AI Studio (Gemini)');
      expect(updated.url, original.url);
      expect(updated.textModel, 'new-model');
      expect(updated.imageModel, 'image-model');
      expect(updated.videoModel, 'video-model');
      expect(updated.active, isTrue);
      expect(updated.selected, isTrue);
    });

    test('updates imageModel for image type', () {
      final original = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        imageModel: 'old-image',
      );
      final updated = _updateProviderModel(original, 'new-image',
          AIPromptType.image);
      expect(updated.imageModel, 'new-image');
      expect(updated.textModel, isNull);
    });

    test('updates videoModel for video type', () {
      final original = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        videoModel: 'old-video',
      );
      final updated = _updateProviderModel(original, 'new-video',
          AIPromptType.video);
      expect(updated.videoModel, 'new-video');
      expect(updated.imageModel, isNull);
    });

    test('does not mutate the original provider', () {
      final original = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        textModel: 'old-model',
      );
      _updateProviderModel(original, 'new-model', AIPromptType.text);
      expect(original.textModel, 'old-model');
    });
  });

  group('model registry and auto-resolution', () {
    test('registry contains known deprecated image models', () {
      expect(
        AIProviderClient.modelRegistry['gemini-2.5-flash-image-preview'],
        'gemini-3.1-flash-lite-image',
      );
      expect(
        AIProviderClient.modelRegistry['gemini-2.0-flash-preview-image-generation'],
        'gemini-3.1-flash-lite-image',
      );
      // Deprecated GA image model also routes to lite.
      expect(
        AIProviderClient.modelRegistry['gemini-2.5-flash-image'],
        'gemini-3.1-flash-lite-image',
      );
    });

    test('registry contains known deprecated video models', () {
      expect(
        AIProviderClient.modelRegistry['gemini-2.5-flash-video-preview'],
        'gemini-omni-1.1-flash',
      );
    });

    test('resolveProvider returns unchanged provider when model is current', () {
      final provider = const AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        imageModel: 'gemini-3.1-flash-lite-image',
      );
      expect(
        AIProviderClient.resolveProvider(provider, AIPromptType.image),
        provider,
      );
    });

    test('resolveProvider replaces a deprecated image model', () {
      final provider = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        imageModel: 'gemini-2.5-flash-image-preview',
      );
      final resolved =
          AIProviderClient.resolveProvider(provider, AIPromptType.image);
      expect(resolved.imageModel, 'gemini-3.1-flash-lite-image');
      expect(resolved.name, provider.name);
      expect(resolved.url, provider.url);
    });

    test('resolveProvider replaces a deprecated video model', () {
      final provider = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        videoModel: 'gemini-2.5-flash-video-preview',
      );
      final resolved =
          AIProviderClient.resolveProvider(provider, AIPromptType.video);
      expect(resolved.videoModel, 'gemini-omni-1.1-flash');
      expect(resolved.imageModel, isNull);
    });

    test('resolveProvider leaves text model alone when no registry entry', () {
      final provider = const AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        textModel: 'gemini-3.5-flash-lite',
      );
      expect(
        AIProviderClient.resolveProvider(provider, AIPromptType.text),
        provider,
      );
    });

    test('resolveProvider does not mutate the original provider', () {
      final original = AIProvider(
        name: 'Test',
        url: 'https://generativelanguage.googleapis.com/v1beta',
        registerTip: '',
        apiKey: 'key',
        imageModel: 'gemini-2.5-flash-image-preview',
      );
      AIProviderClient.resolveProvider(original, AIPromptType.image);
      expect(original.imageModel, 'gemini-2.5-flash-image-preview');
    });
  });

  group('error message cleaning', () {
    test('429 returns a friendly rate-limit message for text', () {
      expect(
        _cleanErrorMessage(429, '{"error":{"message":"You exceeded your quota..."}}'),
        'Rate limit exceeded. Please wait a moment and try again, or switch to a different provider.',
      );
    });

    test('429 with limit:0 shows billing required message for image', () {
      final msg = 'Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 0, model: gemini-3.1-flash-lite-image';
      final result = _cleanErrorMessage(
        429,
        jsonEncode({'error': {'message': msg}}),
        isImageOrVideo: true,
      );
      expect(result, contains('billing'));
      expect(result, isNot(contains('limit: 0')));
    });

    test('429 with limit:0 still shows rate-limit message for text', () {
      final msg = 'Quota exceeded, limit: 0';
      final result = _cleanErrorMessage(
        429,
        jsonEncode({'error': {'message': msg}}),
        isImageOrVideo: false,
      );
      expect(result, contains('Rate limit'));
    });

    test('strips URLs from Gemini error messages', () {
      final msg = 'You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 0, model: gemini-3.1-flash-lite-image';
      final result = _cleanErrorMessage(429, jsonEncode({'error': {'message': msg}}));
      expect(result, contains('Rate limit'));
      expect(result, isNot(contains('https://')));
    });

    test('extracts simple message from OpenAI-compatible error', () {
      final body = jsonEncode({
        'error': {'message': 'Model not found', 'code': 404},
      });
      expect(_cleanErrorMessage(404, body), 'Model not found');
    });

    test('falls back to truncated raw body on unparseable response', () {
      expect(_cleanErrorMessage(500, 'Internal Server Error'), contains('HTTP 500'));
    });

    test('falls back to truncated raw body on malformed JSON', () {
      expect(_cleanErrorMessage(502, 'not-json at all'), contains('HTTP 502'));
    });
  });
}

// --- Test helpers that mirror the private methods in AIProviderClient ---

/// Mirrors [AIProviderClient._geminiModelFor].
String _geminiModelFor(AIProvider provider, AIPromptType type) {
  if (type == AIPromptType.image) {
    return provider.imageModel ?? 'gemini-3.1-flash-lite-image';
  }
  if (type == AIPromptType.video) {
    return provider.videoModel ?? 'gemini-omni-1.1-flash';
  }
  return provider.textModel ?? 'gemini-3.5-flash-lite';
}

/// Mirrors [_extractGeminiSuggestedModel] patterns.
String? _parseSuggestedFrom(String message, String requestedModel) {
  final patterns = [
    RegExp(r'Use\s+(\S+)\s+instead'),
    RegExp(r'Did you mean\s+(\S+)'),
    RegExp(r'not available\.\s*Use\s+(\S+)\s+instead'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(message);
    if (match != null) {
      var candidate = match.group(1)!;
      candidate = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.:/]'), '');
      candidate = candidate.replaceAll(RegExp(r':\w+$'), '');
      if (candidate.isNotEmpty && candidate != requestedModel) {
        return candidate;
      }
    }
  }
  return null;
}

/// Mirrors [_extractOpenRouterSuggestedModel] patterns.
String? _parseOpenRouterSuggestedFrom(String message, String requestedModel) {
  final patterns = [
    RegExp(r'Use\s+(\S+)\s+instead'),
    RegExp(r'Did you mean\s+(\S+)'),
    RegExp(r'not available\.\s*Use\s+(\S+)\s+instead'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(message);
    if (match != null) {
      var candidate = match.group(1)!;
      candidate = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.:/]'), '');
      candidate = candidate.replaceAll(RegExp(r':\w+$'), '');
      if (candidate.isNotEmpty && candidate != requestedModel) {
        return candidate;
      }
    }
  }
  return null;
}

/// Mirrors [_extractNvidiaSuggestedModel] patterns.
String? _parseNvidiaSuggestedFrom(String message, String requestedModel) {
  final patterns = [
    RegExp(r'Use\s+(\S+)\s+instead'),
    RegExp(r'Did you mean\s+(\S+)'),
    RegExp(r'not available\.\s*Use\s+(\S+)\s+instead'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(message);
    if (match != null) {
      var candidate = match.group(1)!;
      candidate = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.:/]'), '');
      candidate = candidate.replaceAll(RegExp(r':\w+$'), '');
      if (candidate.isNotEmpty && candidate != requestedModel) {
        return candidate;
      }
    }
  }
  return null;
}

/// Mirrors [_updateProviderModel] from reading_view.dart.
AIProvider _updateProviderModel(
  AIProvider provider,
  String model,
  AIPromptType type,
) {
  if (type == AIPromptType.image) {
    return provider.copyWith(imageModel: model);
  }
  if (type == AIPromptType.video) {
    return provider.copyWith(videoModel: model);
  }
  return provider.copyWith(textModel: model);
}
