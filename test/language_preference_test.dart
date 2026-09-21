import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klhu/models/language_preference.dart';

void main() {
  group('LanguagePreference', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('load/save round-trip: saves and retrieves correct language code', () async {
      final preference = LanguagePreference(prefs);
      
      // Save English preference
      await preference.saveLanguage('en');
      final loaded = preference.loadLanguage();
      expect(loaded, equals('en'));
      
      // Save Chinese preference
      await preference.saveLanguage('zh');
      final loadedChinese = preference.loadLanguage();
      expect(loadedChinese, equals('zh'));
    });

    test('invalid value handling: falls back to English for unknown language codes', () async {
      final preference = LanguagePreference(prefs);
      
      // Save invalid language code
      await preference.saveLanguage('fr');
      final loaded = preference.loadLanguage();
      expect(loaded, equals('en')); // Fallback to default
    });

    test('default fallback: returns English when no preference is set', () async {
      final preference = LanguagePreference(prefs);
      
      // Don't save anything, just load
      final loaded = preference.loadLanguage();
      expect(loaded, equals('en')); // Default fallback
    });

    test('empty string handling: falls back to English for empty saved value', () async {
      final preference = LanguagePreference(prefs);
      
      // Save empty string
      await preference.saveLanguage('');
      final loaded = preference.loadLanguage();
      expect(loaded, equals('en')); // Fallback to default
    });
  });
}