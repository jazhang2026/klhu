import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreference {
  final SharedPreferences _prefs;
  static const String _key = 'interface_language';
  static const String _defaultLanguage = 'en';

  LanguagePreference(this._prefs);

  /// Save the language preference
  Future<void> saveLanguage(String languageCode) async {
    try {
      await _prefs.setString(_key, languageCode);
    } catch (e) {
      // Log error but don't crash - fallback to default behavior
      debugPrint('Failed to save language preference: $e');
    }
  }

  /// Load the language preference with fallback to default
  String loadLanguage() {
    final saved = _prefs.getString(_key);
    
    // Validate and return valid language code
    if (saved == null || saved.isEmpty) {
      return _defaultLanguage;
    }
    
    // Only accept valid language codes
    if (saved == 'en' || saved == 'zh' || saved == 'zh-Hans') {
      return saved;
    }
    
    // Fallback to default for invalid values
    return _defaultLanguage;
  }
}