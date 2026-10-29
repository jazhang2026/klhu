/// The connectivity test the reader's API key is validated against. When the
/// reader adds or edits a provider's `apiKey`, the endpoint is pinged with that
/// key; the provider's `active` flag is set true iff the test returned a valid
/// response (spec FR-004, Q7).
///
/// Each provider has its own shape — the test is a lightweight probe specific
/// to the provider's endpoint, not a full completion call (research R2).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// The result of a connectivity test.
enum TestResult {
  /// The test call returned a valid response — the key works.
  passed,

  /// The test call failed (missing key, invalid key, model error, network) —
  /// the key is not usable.
  failed,
}

/// The connectivity test contract each provider implements.
abstract class ProviderConnectivityTest {
  /// Run the connectivity test for [provider] with [apiKey].
  /// Returns [TestResult.passed] if the key is valid, [TestResult.failed]
  /// otherwise (including network errors).
  Future<TestResult> test(String url, String apiKey);
}

/// Google AI Studio (Gemini) connectivity test. Probes the `/v1beta/models`
/// endpoint with the API key; a 200 response means the key works.
class GeminiConnectivityTest implements ProviderConnectivityTest {
  const GeminiConnectivityTest();

  @override
  Future<TestResult> test(String url, String apiKey) async {
    if (apiKey.isEmpty) return TestResult.failed;
    try {
      final uri = Uri.parse('$url/v1beta/models').replace(
        queryParameters: {'key': apiKey},
      );
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        return response.statusCode >= 200 && response.statusCode < 300
            ? TestResult.passed
            : TestResult.failed;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('klhu Gemini connectivity test failed: $e');
      return TestResult.failed;
    }
  }
}

/// OpenRouter connectivity test. Probes the `/api/v1/models` endpoint with the
/// Authorization header; a 200 response means the key works.
class OpenRouterConnectivityTest implements ProviderConnectivityTest {
  const OpenRouterConnectivityTest();

  @override
  Future<TestResult> test(String url, String apiKey) async {
    if (apiKey.isEmpty) return TestResult.failed;
    try {
      final uri = Uri.parse('$url/api/v1/models');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        request.headers.set('Authorization', 'Bearer $apiKey');
        final response = await request.close();
        return response.statusCode >= 200 && response.statusCode < 300
            ? TestResult.passed
            : TestResult.failed;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('klhu OpenRouter connectivity test failed: $e');
      return TestResult.failed;
    }
  }
}

/// NVIDIA NIM connectivity test. Probes the `/chat/completions` endpoint with
/// the Authorization header; a 200 response means the key works.
class NVIDIANIMConnectivityTest implements ProviderConnectivityTest {
  const NVIDIANIMConnectivityTest();

  @override
  Future<TestResult> test(String url, String apiKey) async {
    if (apiKey.isEmpty) return TestResult.failed;
    try {
      final uri = Uri.parse('$url/v1/chat/completions');
      final body = const JsonEncoder().convert({
        'model': 'google/gemma-4-31b-it',
        'messages': [{'role': 'user', 'content': 'hi'}],
        'max_tokens': 1,
      });
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(uri);
        request.headers.set('Authorization', 'Bearer $apiKey');
        request.headers.set('Content-Type', 'application/json');
        request.write(body);
        final response = await request.close();
        return response.statusCode >= 200 && response.statusCode < 300
            ? TestResult.passed
            : TestResult.failed;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('klhu NVIDIA NIM connectivity test failed: $e');
      return TestResult.failed;
    }
  }
}

/// The connectivity test for [url], or null if the URL is not recognised.
/// The caller maps the provider's url to the right test (spec FR-004, research D1).
ProviderConnectivityTest? testFor(String url) {
  if (url.contains('generativelanguage.googleapis.com')) {
    return const GeminiConnectivityTest();
  }
  if (url.contains('openrouter.ai')) {
    return const OpenRouterConnectivityTest();
  }
  if (url.contains('nvidia.com')) {
    return const NVIDIANIMConnectivityTest();
  }
  return null;
}
