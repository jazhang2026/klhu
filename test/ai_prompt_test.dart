/// 029 — the AI prompt composition (spec FR-006, A3; data-model §2, Q8).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/prompt.dart';

void main() {
  group('AIPromptType', () {
    test('has text, image and video values', () {
      expect(AIPromptType.values, [AIPromptType.text, AIPromptType.image, AIPromptType.video]);
    });
  });

  group('buildPrompt (FR-006, A3)', () {
    test('returns the prompt text alone when includeReadingContent is false',
        () {
      final prompt = AIPrompt(
        type: AIPromptType.text,
        text: 'Write a story about a tiger.',
        includeReadingContent: false,
      );
      expect(
        buildPrompt(prompt, 'The old text content.'),
        'Write a story about a tiger.',
      );
    });

    test(
        'returns the prompt text alone when readingContent is null'
        ' even if includeReadingContent is true', () {
      final prompt = AIPrompt(
        type: AIPromptType.text,
        text: 'Write a story about a tiger.',
        includeReadingContent: true,
      );
      expect(buildPrompt(prompt, null), 'Write a story about a tiger.');
    });

    test(
        'returns the prompt text alone when readingContent is empty'
        ' even if includeReadingContent is true', () {
      final prompt = AIPrompt(
        type: AIPromptType.image,
        text: 'A tiger in the jungle.',
        includeReadingContent: true,
      );
      expect(buildPrompt(prompt, ''), 'A tiger in the jungle.');
    });

    test(
        'appends the reading content when includeReadingContent is true'
        ' and readingContent is non-empty', () {
      final prompt = AIPrompt(
        type: AIPromptType.text,
        text: 'Translate this.',
        includeReadingContent: true,
        readingContent: 'Hoy es un buen día.',
      );
      final result = buildPrompt(prompt, 'Hoy es un buen día.');
      expect(result, contains('Translate this.'));
      expect(result, contains('[Reading Content]'));
      expect(result, contains('Hoy es un buen día.'));
    });

    test('image type does not change the composition logic', () {
      final prompt = AIPrompt(
        type: AIPromptType.image,
        text: 'A tiger in the jungle at sunset.',
        includeReadingContent: true,
        readingContent: 'A scene of a tiger.',
      );
      final result = buildPrompt(prompt, 'A scene of a tiger.');
      expect(result, contains('A tiger in the jungle at sunset.'));
      expect(result, contains('A scene of a tiger.'));
    });

    test('video type does not change the composition logic', () {
      final prompt = AIPrompt(
        type: AIPromptType.video,
        text: 'A short video of a tiger.',
        includeReadingContent: false,
      );
      expect(
        buildPrompt(prompt, 'A scene of a tiger.'),
        'A short video of a tiger.',
      );
    });
  });

  group('AIPrompt copyWith', () {
    test('replaces only the given fields', () {
      final original = AIPrompt(
        type: AIPromptType.text,
        text: 'Original',
        includeReadingContent: false,
        readingContent: 'old content',
      );
      final updated = original.copyWith(
        type: AIPromptType.image,
        includeReadingContent: true,
      );
      expect(updated.type, AIPromptType.image);
      expect(updated.text, 'Original');
      expect(updated.includeReadingContent, isTrue);
      expect(updated.readingContent, 'old content');
    });
  });
}
