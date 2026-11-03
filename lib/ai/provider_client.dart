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

  /// When [success] is false and the server indicated a different model
  /// should be used (e.g. the requested model was deprecated), this holds
  /// the suggested replacement model name. The caller may update the
  /// provider and retry without user intervention.
  final String? suggestedModel;

  /// The provider actually used for the call. May differ from the input
  /// provider when the client auto-resolved a deprecated model via the
  /// local [AIProviderClient.modelRegistry]. The caller should persist
  /// this provider back to the store on success.
  final AIProvider? resolvedProvider;

  const AIResult({
    required this.content,
    required this.success,
    this.errorMessage,
    this.suggestedModel,
    this.resolvedProvider,
  });

  factory AIResult.failed(String error) =>
      AIResult(content: '', success: false, errorMessage: error);

  factory AIResult.modelSuggested({
    required String error,
    required String model,
  }) =>
      AIResult(
        content: '',
        success: false,
        errorMessage: error,
        suggestedModel: model,
      );
}

/// The AI provider transport. Routes the prompt to the correct endpoint based
/// on the provider's url and the prompt's type.
class AIProviderClient {
  /// A static registry of known-deprecated Gemini model names mapped to their
  /// current replacements. Populated at startup from Google's deprecation notices
  /// and is extended whenever a new preview model is shut down.
  ///
  /// The registry is consulted **before** any network request, so a deprecated
  /// model is resolved without wasting a call.
  static final Map<String, String> modelRegistry = {
    // Gemini image models — deprecated previews and GA versions route to
    // the cheapest current model (gemini-3.1-flash-lite-image at ~$0.034/image).
    'gemini-2.5-flash-image-preview': 'gemini-3.1-flash-lite-image',
    'gemini-2.0-flash-preview-image-generation': 'gemini-3.1-flash-lite-image',
    'gemini-2.0-flash-exp-image-generation': 'gemini-3.1-flash-lite-image',
    // gemini-2.5-flash-image is deprecated (shut down March 15, 2027).
    'gemini-2.5-flash-image': 'gemini-3.1-flash-lite-image',
    // Gemini video — the preview was never public; Omni Flash is the current model.
    'gemini-2.5-flash-video-preview': 'gemini-omni-1.1-flash',
    // Gemini 3.1 image preview also deprecated in favour of lite.
    'gemini-3.1-flash-image-preview': 'gemini-3.1-flash-lite-image',
    'gemini-3-pro-image-preview': 'gemini-3.1-flash-lite-image',
  };

  /// Resolve a provider's model for [type] through the local [modelRegistry].
  /// Returns the provider unchanged when the model is already current.
  static AIProvider resolveProvider(AIProvider provider, AIPromptType type) {
    final current = _geminiModelForStatic(provider, type);
    final resolved = modelRegistry[current];
    if (resolved == null) return provider;
    debugPrint('klhu AI model resolved: $current → $resolved');
    if (type == AIPromptType.image) {
      return provider.copyWith(imageModel: resolved);
    }
    if (type == AIPromptType.video) {
      return provider.copyWith(videoModel: resolved);
    }
    return provider.copyWith(textModel: resolved);
  }

  /// Send [prompt] with the optional [readingContent] to [provider] and return
  /// the result. The call goes through the network; use a fake HTTP client in
  /// tests.
  ///
  /// Before routing, the provider's model is resolved through the local
  /// [modelRegistry]. If the original model was deprecated the resolved
  /// provider is returned in [AIResult.resolvedProvider] so the caller can
  /// persist the change automatically.
  Future<AIResult> generate({
    required AIProvider provider,
    required AIPrompt prompt,
    String? readingContent,
  }) async {
    try {
      final fullPrompt = buildPrompt(prompt, readingContent);
      // Resolve any deprecated model before making a network call.
      final resolved = resolveProvider(provider, prompt.type);
      // Route by provider url and prompt type.
      if (resolved.url.contains('generativelanguage.googleapis.com')) {
        return _callGemini(resolved, fullPrompt, prompt.type);
      }
      if (resolved.url.contains('openrouter.ai')) {
        return _callOpenRouter(resolved, fullPrompt, prompt.type);
      }
      if (resolved.url.contains('nvidia.com')) {
        return _callNvidiaNIM(resolved, fullPrompt, prompt.type);
      }
      if (resolved.url.contains('agnes-ai.com')) {
        return _callAgnesAI(resolved, fullPrompt, prompt.type);
      }

      return AIResult.failed('Unknown provider URL: ${resolved.url}');
    } catch (e) {
      debugPrint('klhu AI generate failed: $e');
      return AIResult.failed('Generate failed: $e');
    }
  }

  /// Return the Gemini model to use for [type] on [provider].
  /// The provider's override takes priority; otherwise the built-in default is
  /// used so that user-added providers without model overrides still work.
  static String _geminiModelForStatic(AIProvider provider, AIPromptType type) {
    if (type == AIPromptType.image) {
      return provider.imageModel ?? 'gemini-3.1-flash-lite-image';
    }
    if (type == AIPromptType.video) {
      return provider.videoModel ?? 'gemini-omni-1.1-flash';
    }
    return provider.textModel ?? 'gemini-3.5-flash-lite';
  }

  /// Call the Gemini API for text/image/video generation.
  Future<AIResult> _callGemini(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    // Use the provider's model override, falling back to the built-in default.
    final model = _geminiModelForStatic(provider, type);
    // provider.url is the base (e.g. https://generativelanguage.googleapis.com/v1beta),
    // so append /models/$model:generateContent.
    final uri = Uri.parse('${provider.url}/models/$model:generateContent')
        .replace(queryParameters: {'key': provider.apiKey});
    debugPrint('klhu Gemini generate: $uri');

    final body = jsonEncode({
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
    });
    debugPrint('klhu Gemini body: ${body.substring(0, body.length.clamp(0, 200))}');

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();
      debugPrint('klhu Gemini response: status=${response.statusCode} body=${responseBody.substring(0, responseBody.length.clamp(0, 500))}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          // Extract the generated content from the response.
          final candidates = decoded['candidates'] as List? ?? [];
          debugPrint('klhu Gemini candidates: ${candidates.length}');
          if (candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map? ?? {};
            final parts = content['parts'] as List? ?? [];
            debugPrint('klhu Gemini parts: ${parts.length}');
            if (parts.isNotEmpty) {
              final text = parts[0]['text'] as String? ?? '';
              debugPrint('klhu Gemini text: ${text.substring(0, text.length.clamp(0, 100))}');
              return AIResult(content: text, success: true, resolvedProvider: provider);
            }
          }
          return AIResult(content: responseBody, success: true, resolvedProvider: provider);
        } catch (e) {
          debugPrint('klhu Gemini parse error: $e');
          return AIResult(content: responseBody, success: true, resolvedProvider: provider);
        }
      }
      // On 404, consult the local registry as a fallback — the pre-flight
      // resolution in generate() covers the common cases, but this catches
      // models that Google deprecated after our registry was last updated.
      if (response.statusCode == 404) {
        final fallback = modelRegistry[model];
        if (fallback != null && fallback != model) {
          debugPrint('klhu Gemini 404 — retrying with registry fallback: $model → $fallback');
          final fallbackUri = Uri.parse('${provider.url}/models/$fallback:generateContent')
              .replace(queryParameters: {'key': provider.apiKey});
          final fallbackClient = HttpClient();
          try {
            final fallbackRequest = await fallbackClient.postUrl(fallbackUri);
            fallbackRequest.headers.set('Content-Type', 'application/json');
            fallbackRequest.add(utf8.encode(body));
            final fallbackResponse = await fallbackRequest.close();
            final fallbackBody = await fallbackResponse.transform(const Utf8Decoder()).join();
            if (fallbackResponse.statusCode >= 200 && fallbackResponse.statusCode < 300) {
              final decoded = jsonDecode(fallbackBody) as Map<String, dynamic>;
              final candidates = decoded['candidates'] as List? ?? [];
              if (candidates.isNotEmpty) {
                final content = candidates[0]['content'] as Map? ?? {};
                final parts = content['parts'] as List? ?? [];
                if (parts.isNotEmpty) {
                  final text = parts[0]['text'] as String? ?? '';
                  return AIResult(content: text, success: true, resolvedProvider: provider);
                }
              }
              return AIResult(content: fallbackBody, success: true, resolvedProvider: provider);
            }
          } finally {
            fallbackClient.close();
          }
        }
      }
      // Check whether the error response suggests a different model.
      final suggested = _extractGeminiSuggestedModel(responseBody, model);
      if (suggested != null) {
        return AIResult.modelSuggested(
          error: _cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video),
          model: suggested,
        );
      }
      return AIResult.failed(_cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video));
    } catch (e, st) {
      debugPrint('klhu Gemini exception: $e\n$st');
      return AIResult.failed('Generate failed: $e');
    } finally {
      client.close();
    }
  }

  /// Produce a clean, user-facing error message from an HTTP response.
  /// Strips URLs, technical details and quota info, and returns a short string
  /// suitable for display in the UI.
  /// When [isImageOrVideo] is true and the 429 carries `limit: 0`, the message
  /// tells the reader that a paid billing account is required for image/video.
  static String _cleanErrorMessage(
    int statusCode,
    String responseBody, {
    bool isImageOrVideo = false,
  }) {
    // Rate limit — give a friendly hint and stop right there.
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
      // OpenAI-compatible error shape.
      final message = (error['message'] ?? error['detail']) as String?;
      if (message != null) return _stripDetails(message);
      // Gemini error shape (already has a "message" field inside "error").
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

  /// Strip URLs and long trailing details from an error message.
  static String _stripDetails(String msg) {
    // Remove anything that looks like a URL.
    var cleaned = msg.replaceAll(
        RegExp(r'https?://[^\s]+'), '').trim();
    // Take only the first meaningful sentence (up to the first URL-like run
    // or a long dash).
    final parts = cleaned.split(RegExp(r'\s*[-–—]\s*'));
    return parts.isNotEmpty ? parts.first.trim() : cleaned;
  }

  /// Fallback: show status + first 80 chars of raw body.
  static String _truncRaw(int statusCode, String body) {
    final truncated =
        body.substring(0, body.length.clamp(0, 80)).replaceAll('\n', ' ');
    return 'HTTP $statusCode: $truncated';
  }

  /// Try to extract a suggested model name from a Gemini error response body.
  /// Gemini sometimes returns the correct model name in the error message when
  /// the requested model has been deprecated or is unavailable.
  String? _extractGeminiSuggestedModel(String responseBody, String requestedModel) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error == null) return null;
      final message = error['message'] as String?;
      if (message == null) return null;

      // Common Gemini patterns for model suggestions:
      // "Model <old> is not found for this operation." — no suggestion, skip.
      // "Model <old> is deprecated. Use <new> instead."
      // "Please use <new> instead."
      // "Did you mean <new>?"
      final patterns = [
        // "Use <model> instead." or "Use <model>:generateContent instead."
        RegExp(r'Use\s+(\S+)\s+instead'),
        // "Did you mean <model>?"
        RegExp(r'Did you mean\s+(\S+)'),
        // "<model> is not available. Use <model2> instead."
        RegExp(r'not available\.\s*Use\s+(\S+)\s+instead'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(message);
        if (match != null) {
          var candidate = match.group(1)!;
          // Strip trailing punctuation.
          candidate = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.:/]'), '');
          // Remove the operation suffix if present (e.g. ":generateContent").
          candidate = candidate.replaceAll(RegExp(r':\w+$'), '');
          if (candidate.isNotEmpty && candidate != requestedModel) {
            debugPrint('klhu Gemini model suggestion: $candidate');
            return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint('klhu Gemini suggest-model parse error: $e');
    }
    return null;
  }

  /// Call the OpenRouter API for text/image/video generation.
  Future<AIResult> _callOpenRouter(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    // OpenRouter uses the standard chat completions format.
    final model = _providerModelFor(provider, type, 'openai/gpt-oss-120b');
    final uri = Uri.parse('${provider.url}/chat/completions');
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
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = decoded['choices'] as List? ?? [];
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map? ?? {};
          final content = message['content'] as String? ?? '';
          return AIResult(content: content, success: true, resolvedProvider: provider);
        }
        return AIResult(content: responseBody, success: true, resolvedProvider: provider);
      }
      // Check whether the error response suggests a different model.
      final suggested = _extractOpenRouterSuggestedModel(responseBody, model);
      if (suggested != null) {
        return AIResult.modelSuggested(
          error: _cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video),
          model: suggested,
        );
      }
      return AIResult.failed(_cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video));
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
    final model = _providerModelFor(
      provider,
      type,
      type == AIPromptType.image
          ? 'nvidia/nemotron-4-340b'
          : 'google/gemma-4-31b-it',
    );
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
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = decoded['choices'] as List? ?? [];
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map? ?? {};
          final content = message['content'] as String? ?? '';
          return AIResult(content: content, success: true, resolvedProvider: provider);
        }
        return AIResult(content: responseBody, success: true, resolvedProvider: provider);
      }
      // Check whether the error response suggests a different model.
      final suggested = _extractNvidiaSuggestedModel(responseBody, model);
      if (suggested != null) {
        return AIResult.modelSuggested(
          error: _cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video),
          model: suggested,
        );
      }
      return AIResult.failed(_cleanErrorMessage(response.statusCode, responseBody, isImageOrVideo: type == AIPromptType.image || type == AIPromptType.video));
    } finally {
      client.close();
    }
  }

  /// Return the model to use for [type] on [provider].
  /// The provider's override takes priority; otherwise [defaultModel] is used.
  String _providerModelFor(
    AIProvider provider,
    AIPromptType type,
    String defaultModel,
  ) {
    if (type == AIPromptType.image) return provider.imageModel ?? defaultModel;
    if (type == AIPromptType.video) return provider.videoModel ?? defaultModel;
    return provider.textModel ?? defaultModel;
  }

  /// Call the Agnes AI API. Text uses chat completions; images use the
  /// dedicated image generation endpoint; video is not supported.
  Future<AIResult> _callAgnesAI(
    AIProvider provider,
    String prompt,
    AIPromptType type,
  ) async {
    // Text generation — same OpenAI-compatible chat completions format.
    if (type == AIPromptType.text) {
      return _callOpenRouter(provider, prompt, type);
    }

    // Video generation is not supported by Agnes AI.
    if (type == AIPromptType.video) {
      return AIResult.failed(
          'Agnes AI does not support video generation yet.');
    }

    // Image generation — uses /v1/images/generations.
    final model = provider.imageModel ?? 'agnes-image-2.5-flash';
    final uri = Uri.parse('${provider.url}/images/generations');
    final body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'size': '1024x1024',
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer ${provider.apiKey}');
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final data = decoded['data'] as List? ?? [];
        if (data.isNotEmpty) {
          final image = data[0] as Map? ?? {};
          final url = image['url'] as String? ?? '';
          if (url.isNotEmpty) {
            debugPrint('klhu Agnes AI image generated: $url');
            // Return the URL as the content so it lands in the editor
            // and can be saved as a reference.
            return AIResult(
              content: url,
              success: true,
              resolvedProvider: provider,
            );
          }
          final b64 = image['b64_json'] as String? ?? '';
          if (b64.isNotEmpty) {
            return AIResult(
              content: 'data:image/png;base64,$b64',
              success: true,
              resolvedProvider: provider,
            );
          }
        }
        return AIResult(
            content: responseBody, success: true, resolvedProvider: provider);
      }

      // Parse error response.
      try {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
        if (decoded != null) {
          final error = decoded['error'] as Map? ?? {};
          final message = error['message'] as String?;
          if (message != null) {
            debugPrint('klhu Agnes AI error: $message');
            return AIResult.failed(message);
          }
        }
      } catch (_) {}
      return AIResult.failed('Image generation failed (HTTP ${response.statusCode})');
    } catch (e, st) {
      debugPrint('klhu Agnes AI exception: $e\n$st');
      return AIResult.failed('Image generation failed: $e');
    } finally {
      client.close();
    }
  }

  /// Try to extract a suggested model name from an OpenRouter error response.
  /// OpenRouter sometimes returns the correct model name in the error when a
  /// model is unavailable or deprecated.
  String? _extractOpenRouterSuggestedModel(
      String responseBody, String requestedModel) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error == null) return null;
      final message = error['message'] as String?;
      if (message == null) return null;

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
            debugPrint('klhu OpenRouter model suggestion: $candidate');
            return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint('klhu OpenRouter suggest-model parse error: $e');
    }
    return null;
  }

  /// Try to extract a suggested model name from a NVIDIA NIM error response.
  /// NVIDIA NIM uses an OpenAI-compatible error format.
  String? _extractNvidiaSuggestedModel(
      String responseBody, String requestedModel) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>?;
      if (decoded == null) return null;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error == null) return null;
      final message = error['message'] as String?;
      if (message == null) return null;

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
            debugPrint('klhu NVIDIA model suggestion: $candidate');
            return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint('klhu NVIDIA suggest-model parse error: $e');
    }
    return null;
  }
}
