/// 029 — the AI provider transport (spec FR-006; research D1, R2).
///
/// Sends a composed prompt to a provider's endpoint and returns the model's
/// answer as reading content. Routes by provider url (Gemini, OpenRouter,
/// NVIDIA NIM) and generation type (text / image / video).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'provider_list.dart';
import 'prompt.dart';

/// The result of an AI generation call.
class AIResult {
  /// The generated content (may be a URL for image/video, or text).
  final String content;

  /// Whether the call succeeded.
  final bool success;

  /// An optional error message if [success] is false.
  final String? errorMessage;

  const AIResult({
    required this.content,
    required this.success,
    this.errorMessage,
  });

  factory AIResult.failed(String error) =>
      AIResult(content: '', success: false, errorMessage: error);
}

/// The AI provider transport. Routes the prompt to the correct endpoint based
/// on the provider's url and the prompt's type.
class AIProviderClient {
  /// Send [prompt] with the optional [readingContent] to [provider] and return
  /// the result. The call goes through the network; use a fake HTTP client in
  /// tests.
  Future<AIResult> generate({
    required AIProvider provider,
    required AIPrompt prompt,
    String? readingContent,
  }) async {
    try {
      final fullPrompt = buildPrompt(prompt, readingContent);
      // Route by provider url and prompt type.
      if (provider.url.contains('generativelanguage.googleapis.com')) {
        return _callGemini(provider, fullPrompt, prompt.type);
      }
      if (provider.url.contains('openrouter.ai')) {
        return _callOpenRouter(provider, fullPrompt, prompt.type);
      }
      if (provider.url.contains('nvidia.com')) {
        return _callNvidiaNIM(provider, fullPrompt, prompt.type);
      }

      return AIResult.failed('Unknown provider URL: ${provider.url}');
    } catch (e) {
      debugPrint('klhu AI generate failed: $e');
      return AIResult.failed('Generate failed: $e');
    }
  }

  /// Call the Gemini API for text/image/video generation.
  Future<AIResult> _callGemini(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    final model = type == AIPromptType.image
        ? 'gemini-2.5-flash-image-preview'
        : type == AIPromptType.video
            ? 'gemini-2.5-flash-video-preview'
            : 'gemini-2.5-flash-lite';
    final uri = Uri.parse('${provider.url}/v1beta/models/$model:generateContent?key=${provider.apiKey}');

    final body = jsonEncode({
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        // Extract the generated content from the response.
        final candidates = decoded['candidates'] as List? ?? [];
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map? ?? {};
          final parts = content['parts'] as List? ?? [];
          if (parts.isNotEmpty) {
            final text = parts[0]['text'] as String? ?? '';
            return AIResult(content: text, success: true);
          }
        }
        return AIResult(content: responseBody, success: true);
      }
      return AIResult.failed('Gemini error: $responseBody');
    } finally {
      client.close();
    }
  }

  /// Call the OpenRouter API for text/image/video generation.
  Future<AIResult> _callOpenRouter(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    // OpenRouter uses the standard chat completions format.
    final uri = Uri.parse('${provider.url}/chat/completions');
    final body = jsonEncode({
      'model': 'openai/gpt-oss-120b', // default free model
      'messages': [{'role': 'user', 'content': prompt}],
      'max_tokens': 4096,
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer ${provider.apiKey}');
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = decoded['choices'] as List? ?? [];
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map? ?? {};
          final content = message['content'] as String? ?? '';
          return AIResult(content: content, success: true);
        }
        return AIResult(content: responseBody, success: true);
      }
      return AIResult.failed('OpenRouter error: $responseBody');
    } finally {
      client.close();
    }
  }

  /// Call the NVIDIA NIM API for text/image/video generation.
  Future<AIResult> _callNvidiaNIM(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    // NVIDIA NIM uses the OpenAI-compatible format.
    final model = type == AIPromptType.image
        ? 'nvidia/nemotron-4-340b'
        : 'google/gemma-4-31b-it';
    final uri = Uri.parse('${provider.url}/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': [{'role': 'user', 'content': prompt}],
      'max_tokens': 4096,
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer ${provider.apiKey}');
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = decoded['choices'] as List? ?? [];
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map? ?? {};
          final content = message['content'] as String? ?? '';
          return AIResult(content: content, success: true);
        }
        return AIResult(content: responseBody, success: true);
      }
      return AIResult.failed('NVIDIA NIM error: $responseBody');
    } finally {
      client.close();
    }
  }
}
