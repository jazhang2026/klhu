import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:klhu/models/language_preference.dart';

class LocalizationService {
  final LanguagePreference _preference;

  /// Device locale, used only to pick the language on a fresh install
  /// (spec 007 FR-007). Null in tests means "no device locale" → English.
  final Locale? deviceLocale;

  LocalizationService(SharedPreferences prefs, {this.deviceLocale})
      : _preference = LanguagePreference(prefs);

  /// Load the current language preference (saved choice, else device default)
  String loadLanguage() {
    try {
      final languageCode = _preference.loadLanguage(deviceLocale: deviceLocale);
      // Normalize zh-Hans to zh for consistency with ARB files
      return languageCode == 'zh-Hans' ? 'zh' : languageCode;
    } catch (e) {
      // Fallback to English on any error
      return 'en';
    }
  }

  /// Save a new language preference
  Future<void> saveLanguage(String languageCode) async {
    try {
      // Normalize zh-Hans to zh for consistency with ARB files
      final normalizedCode = languageCode == 'zh-Hans' ? 'zh' : languageCode;
      await _preference.saveLanguage(normalizedCode);
    } catch (e) {
      // Log error but don't crash - fallback to default behavior
      // In production, this would use a proper logging framework
      debugPrint('Failed to save language preference: $e');
    }
  }

  /// Resolve a Locale from a language code
  Locale resolveLocale(String languageCode) {
    switch (languageCode) {
      case 'zh':
        return const Locale('zh');
      case 'es':
        // One Spanish translation set ships: Latin American Spanish. Any
        // Spanish device locale resolves to it (spec 007 research.md).
        return const Locale('es');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  /// Get the current Locale based on saved preference
  Locale getCurrentLocale() {
    final languageCode = loadLanguage();
    return resolveLocale(languageCode);
  }

  /// Get the current language code (normalized)
  String getCurrentLanguageCode() {
    return loadLanguage();
  }
}