/// 029 — the connectivity test for AI providers (spec FR-004, Q7; research D5).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/auto_test.dart';

void main() {
  group('testFor — URL dispatch', () {
    test('maps a Gemini URL to the Gemini test', () {
      expect(
        testFor('https://generativelanguage.googleapis.com/v1beta'),
        isA<GeminiConnectivityTest>(),
      );
    });

    test('maps an OpenRouter URL to the OpenRouter test', () {
      expect(
        testFor('https://openrouter.ai/api/v1'),
        isA<OpenRouterConnectivityTest>(),
      );
    });

    test('maps an NVIDIA NIM URL to the NIM test', () {
      expect(
        testFor('https://integrate.api.nvidia.com/v1'),
        isA<NVIDIANIMConnectivityTest>(),
      );
    });

    test('returns null for an unknown URL', () {
      expect(testFor('https://unknown.example.com'), isNull);
    });
  });

  group('GeminiConnectivityTest', () {
    test('returns failed for an empty key', () async {
      final test_ = const GeminiConnectivityTest();
      expect(await test_.test('https://generativelanguage.googleapis.com/v1beta', ''),
          TestResult.failed);
    });

    test('returns failed for an unreachable host', () async {
      final test_ = const GeminiConnectivityTest();
      expect(
          await test_.test('https://nonexistent.invalid.test.example', 'some-key'),
          TestResult.failed);
    });
  });

  group('OpenRouterConnectivityTest', () {
    test('returns failed for an empty key', () async {
      final test_ = const OpenRouterConnectivityTest();
      expect(
          await test_.test('https://openrouter.ai/api/v1', ''),
          TestResult.failed);
    });
  });

  group('NVIDIANIMConnectivityTest', () {
    test('returns failed for an empty key', () async {
      final test_ = const NVIDIANIMConnectivityTest();
      expect(
          await test_.test('https://integrate.api.nvidia.com/v1', ''),
          TestResult.failed);
    });
  });
}
