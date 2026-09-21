import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:klhu/models/language_preference.dart';

class LocalizationService {
  final LanguagePreference _preference;

  LocalizationService(SharedPreferences prefs)
      : _preference = LanguagePreference(prefs);

  /// Load the current language preference
  String loadLanguage() {
    try {
      final languageCode = _preference.loadLanguage();
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