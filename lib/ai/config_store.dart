/// The AI provider list persistence layer — reads and writes the provider entries
/// (with their `active` and `selected` flags) and the last-picked generation
/// type over `shared_preferences` (data-model §1/§2).
///
/// Mirrors the shape of `lib/role_store.dart`: one `shared_preferences` key
/// holding a JSON object keyed by the provider's `name`, read tolerantly — a
/// malformed entry is ignored rather than repaired, and the other entries are
/// unaffected.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_list.dart';
import 'prompt.dart';
import 'prompt_history.dart';

/// Persists the AI provider list in `shared_preferences` (spec FR-002, FR-003).
///
/// The key for the provider list: one namespace so the per-entry keys do not
/// collide with any other record.
///
/// The key for the last-picked generation type: separate so the prompt dialog
/// remembers the reader's last choice across sessions.
class AIConfigStore {
  /// The single key this store addresses, namespaced so it collides with no
  /// other record. Exposed for tests.
  static const String providersKey = 'ai_providers';

  /// The key for the last-picked generation type (text / image / video).
  /// Exposed for tests.
  static const String lastTypeKey = 'ai_last_type';

  /// Injected `SharedPreferences.getInstance`; the real one is the app's; a
  /// test's own keeps the prefs out of the test.
  final Future<SharedPreferences> Function() _prefs;

  AIConfigStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// The provider list, seeded with the four presets and with the reader's own
  /// entries merged in. The first `active` provider is marked `selected` (Q10);
  /// if none is active yet the first preset is selected (the reader sees the
  /// dialog with a default).
  ///
  /// Missing presets from the seed are automatically merged in so that adding
  /// a new preset (e.g. a new provider) is visible to readers who already have
  /// stored data.
  Future<List<AIProvider>> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(providersKey);
      final entries = _parseEntries(raw);
      if (entries.isEmpty) return List.from(AIProvider.presets);
      var providers = <AIProvider>[];
      for (final json in entries) {
        providers.add(AIProvider.fromJson(json));
      }
      // Merge any presets that are missing from the stored list (e.g. a new
      // preset added in a later app version). Presets take priority over
      // user-added providers with the same name.
      final existingNames = providers.map((p) => p.name).toSet();
      for (final preset in AIProvider.presets) {
        if (!existingNames.contains(preset.name)) {
          providers.add(preset);
        }
      }
      // Invariant: only active providers can be selected. Clear any stale
      // selected flag on inactive providers (can happen after a migration).
      providers = providers
          .map((p) => (!p.active && p.selected)
              ? p.copyWith(selected: false)
              : p)
          .toList();
      // Invariant: exactly one provider must be selected. If multiple are
      // selected, keep only the first active one; if none is selected, pick
      // the first active or fall back to the first entry.
      final selectedProviders = providers.where((p) => p.selected).toList();
      if (selectedProviders.length > 1) {
        // Multiple selected — clear all and pick the first active.
        providers = providers
            .map((p) => p.copyWith(selected: false))
            .toList();
        var firstActiveIdx = providers.indexWhere((p) => p.active);
        if (firstActiveIdx < 0) firstActiveIdx = 0;
        if (firstActiveIdx >= 0 && firstActiveIdx < providers.length) {
          providers[firstActiveIdx] =
              providers[firstActiveIdx].copyWith(selected: true);
          await _save(prefs, providers);
        }
      } else if (selectedProviders.isEmpty) {
        // None selected — pick the first active or fall back to first entry.
        var firstActiveIdx = providers.indexWhere((p) => p.active);
        if (firstActiveIdx < 0) firstActiveIdx = 0;
        if (firstActiveIdx >= 0 && firstActiveIdx < providers.length) {
          providers[firstActiveIdx] =
              providers[firstActiveIdx].copyWith(selected: true);
          await _save(prefs, providers);
        }
      }
      return providers;
    } catch (e) {
      debugPrint('klhu AI config unreadable: $e');
      return List.from(AIProvider.presets);
    }
  }

  /// Persist the [providers] list. The list is stored as a JSON array keyed by
  /// `name`; an empty list clears the key (nothing to say).
  Future<void> save(List<AIProvider> providers) async {
    try {
      final prefs = await _prefs();
      await _save(prefs, providers);
    } catch (e) {
      debugPrint('klhu AI config not persisted: $e');
    }
  }

  /// The last-picked generation type, or `text` as the default (FR-005, Q8).
  Future<AIPromptType> loadLastType() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(lastTypeKey);
      if (raw == null) return AIPromptType.text;
      return AIPromptType.values.byName(raw);
    } catch (e) {
      debugPrint('klhu AI last type unreadable: $e');
      return AIPromptType.text;
    }
  }

  /// Persist the last-picked generation type.
  Future<void> saveLastType(AIPromptType type) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(lastTypeKey, type.name);
    } catch (e) {
      debugPrint('klhu AI last type not persisted: $e');
    }
  }

  /// Load the prompt history from SharedPreferences.
  /// Exposed for tests; delegates to [AIPromptHistory.load].
  Future<List<AIPromptEntry>> loadPromptHistory() async {
    final history = AIPromptHistory(prefs: _prefs);
    return history.load();
  }

  /// Add a prompt to the history.
  /// Exposed for tests; delegates to [AIPromptHistory.add].
  Future<void> addPromptHistory({
    required String text,
    required AIPromptType type,
    required bool includeReadingContent,
  }) async {
    final history = AIPromptHistory(prefs: _prefs);
    await history.add(text: text, type: type, includeReadingContent: includeReadingContent);
  }

  Future<void> _save(
    SharedPreferences prefs,
    List<AIProvider> providers,
  ) async {
    if (providers.isEmpty) {
      await prefs.remove(providersKey);
      return;
    }
    final jsonList = providers.map((p) => p.toJson()).toList();
    await prefs.setString(providersKey, jsonEncode(jsonList));
  }

  /// Parse a JSON-encoded list of provider entries. A missing, malformed, or
  /// non-list value yields an empty list — the caller seeds from the presets.
  List<Map<String, Object?>> _parseEntries(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            {
              for (final entry in item.entries)
                if (entry.key is String) entry.key as String: entry.value,
            },
      ];
    } on FormatException {
      return [];
    }
  }
}
