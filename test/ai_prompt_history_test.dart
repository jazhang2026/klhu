/// 029 — the AI prompt history persistence layer (data-model §2 extended).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/prompt.dart';
import 'package:klhu/ai/prompt_history.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final historyKey = AIPromptHistory.historyKey;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AIPromptEntry JSON round-trip', () {
    test('serializes and deserializes correctly', () {
      const entry = AIPromptEntry(
        text: 'Write a short story about a tiger.',
        type: AIPromptType.text,
        includeReadingContent: true,
        timestamp: 1700000000000,
      );
      final json = entry.toJson();
      expect(json['text'], 'Write a short story about a tiger.');
      expect(json['type'], 'text');
      expect(json['includeReadingContent'], isTrue);
      expect(json['timestamp'], 1700000000000);

      final loaded = AIPromptEntry.fromJson(json);
      expect(loaded, entry);
    });

    test('falls back gracefully for missing fields', () {
      final entry = AIPromptEntry.fromJson(<String, Object?>{});
      expect(entry.text, isEmpty);
      expect(entry.type, AIPromptType.text);
      expect(entry.includeReadingContent, isFalse);
      expect(entry.timestamp, 0);
    });

    test('handles all prompt types', () {
      for (final type in AIPromptType.values) {
        final entry = AIPromptEntry(
          text: 'test',
          type: type,
          includeReadingContent: false,
          timestamp: 0,
        );
        expect(AIPromptEntry.fromJson(entry.toJson()).type, type);
      }
    });
  });

  group('AIPromptHistory', () {
    test('returns empty list when nothing is stored', () async {
      final history = AIPromptHistory();
      expect(await history.load(), isEmpty);
    });

    test('stores and reads back a single prompt', () async {
      final history = AIPromptHistory();
      await history.add(
        text: 'Hello world',
        type: AIPromptType.text,
        includeReadingContent: false,
      );
      final entries = await history.load();
      expect(entries.length, 1);
      expect(entries[0].text, 'Hello world');
      expect(entries[0].type, AIPromptType.text);
      expect(entries[0].includeReadingContent, isFalse);
    });

    test('prepends new prompts and preserves order', () async {
      final history = AIPromptHistory();
      await history.add(text: 'first', type: AIPromptType.text, includeReadingContent: false);
      await history.add(text: 'second', type: AIPromptType.image, includeReadingContent: true);
      await history.add(text: 'third', type: AIPromptType.video, includeReadingContent: false);

      final entries = await history.load();
      expect(entries.length, 3);
      expect(entries[0].text, 'third');
      expect(entries[1].text, 'second');
      expect(entries[2].text, 'first');
    });

    test('caps at maxEntries (20)', () async {
      final history = AIPromptHistory();
      for (var i = 0; i < 25; i++) {
        await history.add(
          text: 'prompt_$i',
          type: AIPromptType.text,
          includeReadingContent: false,
        );
      }
      final entries = await history.load();
      expect(entries.length, AIPromptHistory.maxEntries);
      // Most recent first.
      expect(entries[0].text, 'prompt_24');
      expect(entries.last.text, 'prompt_5');
    });

    test('clears the history', () async {
      final history = AIPromptHistory();
      await history.add(text: 'keep me', type: AIPromptType.text, includeReadingContent: false);
      await history.clear();
      expect(await history.load(), isEmpty);
    });

    test('a malformed stored value is tolerated — returns empty', () async {
      await (await SharedPreferences.getInstance()).setString(historyKey, 'not-json');
      final history = AIPromptHistory();
      expect(await history.load(), isEmpty);
    });

    test('duplicate text is allowed (reader may retry same prompt)', () async {
      final history = AIPromptHistory();
      await history.add(text: 'same prompt', type: AIPromptType.text, includeReadingContent: false);
      await history.add(text: 'same prompt', type: AIPromptType.text, includeReadingContent: true);
      final entries = await history.load();
      expect(entries.length, 2);
      expect(entries[0].includeReadingContent, isTrue);
      expect(entries[1].includeReadingContent, isFalse);
    });
  });

  group('AIConfigStore prompt history integration', () {
    test('loadPromptHistory and addPromptHistory work through the store', () async {
      final store = AIConfigStore();
      expect(await store.loadPromptHistory(), isEmpty);

      await store.addPromptHistory(
        text: 'retry this',
        type: AIPromptType.image,
        includeReadingContent: true,
      );
      final entries = await store.loadPromptHistory();
      expect(entries.length, 1);
      expect(entries[0].text, 'retry this');
      expect(entries[0].type, AIPromptType.image);
      expect(entries[0].includeReadingContent, isTrue);
    });
  });
}
