import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreference {
  final SharedPreferences _prefs;
  static const String _key = 'interface_language';
  static const String _defaultLanguage = 'en';

  /// Interface languages this app ships translations for. `zh-Hans` is kept
  /// because earlier builds persisted it; `LocalizationService` normalizes it
  /// to `zh` (spec 004).
  static const List<String> supportedLanguages = ['en', 'zh', 'zh-Hans', 'es'];

  LanguagePreference(this._prefs);

  /// The interface language to use before the user has chosen one, from the
  /// device locale: any Chinese locale → `zh`, any Spanish locale → `es` (the
  /// shipped Spanish is the Latin American variety, spec 007 FR-007), anything
  /// else → English. An absent locale is English, never a crash.
  static String resolveDefaultLanguage(Locale? deviceLocale) {
    final code = deviceLocale?.languageCode.toLowerCase();
    if (code == 'zh') return 'zh';
    if (code == 'es') return 'es';
    return _defaultLanguage;
  }

  /// Save the language preference
  Future<void> saveLanguage(String languageCode) async {
    try {
      await _prefs.setString(_key, languageCode);
    } catch (e) {
      // Log error but don't crash - fallback to default behavior
      debugPrint('Failed to save language preference: $e');
    }
  }

  /// Load the language preference, falling back to [resolveDefaultLanguage]
  /// when nothing has been saved and to English for an unusable stored value.
  String loadLanguage({Locale? deviceLocale}) {
    final saved = _prefs.getString(_key);

    if (saved == null || saved.isEmpty) {
      return resolveDefaultLanguage(deviceLocale);
    }

    if (supportedLanguages.contains(saved)) {
      return saved;
    }

    // Fallback to default for invalid values
    return _defaultLanguage;
  }
}
