/// The AI prompt the reader submits, and the function that composes it into a
/// single string for the provider (data-model §2).
library;

/// One AI generation type: text, image or video (Q8).
enum AIPromptType {
  /// Text generation.
  text,

  /// Image generation.
  image,

  /// Video generation.
  video,
}

/// The AI prompt the reader submits. The `type` field routes the call to the
/// right model on the chosen provider (Q8, data-model §2).
class AIPrompt {
  /// The generation type: text, image or video.
  final AIPromptType type;

  /// The reader's own prompt string.
  final String text;

  /// Whether the current reading content is included in the prompt (spec A3).
  final bool includeReadingContent;

  /// An optional string of the reading content to include (carried in the UI
  /// and passed through to [buildPrompt]).
  final String? readingContent;

  const AIPrompt({
    required this.type,
    required this.text,
    this.includeReadingContent = false,
    this.readingContent,
  });

  /// A copy with the given fields replaced.
  AIPrompt copyWith({
    AIPromptType? type,
    String? text,
    bool? includeReadingContent,
    String? readingContent,
  }) =>
      AIPrompt(
        type: type ?? this.type,
        text: text ?? this.text,
        includeReadingContent: includeReadingContent ?? this.includeReadingContent,
        readingContent: readingContent ?? this.readingContent,
      );

  @override
  bool operator ==(Object other) =>
      other is AIPrompt &&
      type == other.type &&
      text == other.text &&
      includeReadingContent == other.includeReadingContent &&
      readingContent == other.readingContent;

  @override
  int get hashCode =>
      Object.hash(type, text, includeReadingContent, readingContent);
}

/// Compose the reader's [prompt] into a single string to send to the provider.
/// If [readingContent] is non-null and [prompt.includeReadingContent] is true,
/// the reading content is appended; otherwise only the prompt string is returned
/// (spec FR-006, A3).
String buildPrompt(AIPrompt prompt, String? readingContent) {
  if (!prompt.includeReadingContent || readingContent == null || readingContent.isEmpty) {
    return prompt.text;
  }
  return '${prompt.text}\n\n[Reading Content]\n$readingContent';
}
