/// The AI prompt history — a persistently stored list of the reader's recent
/// prompts, each with its type, includeReadingContent flag, and a timestamp.
///
/// Mirrors the shape of `lib/ai/config_store.dart`: one `shared_preferences`
/// key holding a JSON array of prompt entries, read tolerantly.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'prompt.dart';

/// One entry in the prompt history.
class AIPromptEntry {
  /// The prompt string the reader typed.
  final String text;

  /// The generation type that was selected (text / image / video).
  final AIPromptType type;

  /// Whether reading content was included in the prompt.
  final bool includeReadingContent;

  /// Unix timestamp in milliseconds when the prompt was submitted.
  final int timestamp;

  const AIPromptEntry({
    required this.text,
    required this.type,
    required this.includeReadingContent,
    required this.timestamp,
  });

  factory AIPromptEntry.fromJson(Map<String, Object?> json) {
    return AIPromptEntry(
      text: json['text'] as String? ?? '',
      type: AIPromptType.values.byName(json['type'] as String? ?? 'text'),
      includeReadingContent: json['includeReadingContent'] == true,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
        'text': text,
        'type': type.name,
        'includeReadingContent': includeReadingContent,
        'timestamp': timestamp,
      };

  @override
  bool operator ==(Object other) =>
      other is AIPromptEntry &&
      text == other.text &&
      type == other.type &&
      includeReadingContent == other.includeReadingContent &&
      timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(text, type, includeReadingContent, timestamp);
}

/// Persists the AI prompt history in `shared_preferences`.
///
/// The history is a FIFO list of the most recent prompts, capped at
/// [maxEntries]. New prompts are prepended; older ones are dropped when the
/// cap is exceeded.
class AIPromptHistory {
  /// Maximum number of prompts to keep in history.
  static const int maxEntries = 20;

  /// The SharedPreferences key for the prompt history.
  static const String historyKey = 'ai_prompt_history';

  /// Injected `SharedPreferences.getInstance`; the real one is the app's; a
  /// test's own keeps the prefs out of the test.
  final Future<SharedPreferences> Function() _prefs;

  AIPromptHistory({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Load the prompt history from SharedPreferences.
  /// Returns an empty list if nothing is stored or the data is malformed.
  Future<List<AIPromptEntry>> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(historyKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map) AIPromptEntry.fromJson(item as Map<String, Object?>),
      ];
    } catch (e) {
      debugPrint('klhu AI prompt history unreadable: $e');
      return [];
    }
  }

  /// Add a new prompt to the history.
  ///
  /// The new entry is prepended; entries beyond [maxEntries] are dropped
  /// from the end. The updated list is persisted immediately.
  Future<void> add({
    required String text,
    required AIPromptType type,
    required bool includeReadingContent,
  }) async {
    try {
      final prefs = await _prefs();
      var entries = await load();
      entries = [
        AIPromptEntry(
          text: text,
          type: type,
          includeReadingContent: includeReadingContent,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        ...entries,
      ];
      if (entries.length > maxEntries) {
        entries = entries.take(maxEntries).toList();
      }
      final jsonList = entries.map((e) => e.toJson()).toList();
      await prefs.setString(historyKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('klhu AI prompt history not persisted: $e');
    }
  }

  /// Clear the entire prompt history.
  Future<void> clear() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(historyKey);
    } catch (e) {
      debugPrint('klhu AI prompt history not cleared: $e');
    }
  }
}
