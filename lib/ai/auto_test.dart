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
      final response = await _request(uri);
      return response.statusCode >= 200 && response.statusCode < 300
          ? TestResult.passed
          : TestResult.failed;
    } catch (_) {
      return TestResult.failed;
    }
  }

  Future<_HttpResponse> _request(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      return _HttpResponse(response.statusCode);
    } finally {
      client.close();
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
      final response = await _request(uri, headers: {
        'Authorization': 'Bearer $apiKey',
      });
      return response.statusCode >= 200 && response.statusCode < 300
          ? TestResult.passed
          : TestResult.failed;
    } catch (_) {
      return TestResult.failed;
    }
  }

  Future<_HttpResponse> _request(Uri uri,
      {Map<String, String>? headers}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (headers != null) {
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }
      final response = await request.close();
      return _HttpResponse(response.statusCode);
    } finally {
      client.close();
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
      final response = await _request(uri, headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }, body: body);
      return response.statusCode >= 200 && response.statusCode < 300
          ? TestResult.passed
          : TestResult.failed;
    } catch (_) {
      return TestResult.failed;
    }
  }

  Future<_HttpResponse> _request(Uri uri,
      {Map<String, String>? headers, String? body}) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      if (headers != null) {
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }
      if (body != null) {
        request.write(body);
      }
      final response = await request.close();
      return _HttpResponse(response.statusCode);
    } finally {
      client.close();
    }
  }
}

/// HTTP response wrapper to avoid exposing dart:io directly.
class _HttpResponse {
  final int statusCode;
  const _HttpResponse(this.statusCode);
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
