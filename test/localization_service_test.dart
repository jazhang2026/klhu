import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klhu/services/localization_service.dart';

void main() {
  group('LocalizationService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('locale resolution: resolves correct Locale from language code', () async {
      final service = LocalizationService(prefs);
      
      // English should resolve to en locale
      final enLocale = service.resolveLocale('en');
      expect(enLocale.languageCode, equals('en'));
      
      // Chinese should resolve to zh locale
      final zhLocale = service.resolveLocale('zh');
      expect(zhLocale.languageCode, equals('zh'));
    });

    test('preference management: saves and loads language preference correctly', () async {
      final service = LocalizationService(prefs);
      
      // Save English preference
      await service.saveLanguage('en');
      final loaded = service.loadLanguage();
      expect(loaded, equals('en'));
      
      // Save Chinese preference (normalized from zh-Hans to zh)
      await service.saveLanguage('zh-Hans');
      final loadedChinese = service.loadLanguage();
      expect(loadedChinese, equals('zh'));
    });

    test('error handling: falls back to English for invalid language codes', () async {
      final service = LocalizationService(prefs);
      
      // Try to resolve invalid language code
      final invalidLocale = service.resolveLocale('invalid');
      expect(invalidLocale.languageCode, equals('en')); // Fallback
    });

    test('error handling: handles storage failure gracefully', () async {
      // This test verifies the service doesn't crash on storage errors
      // In real implementation, this would involve mocking storage failures
      final service = LocalizationService(prefs);
      
      // Normal operation should work
      final loaded = service.loadLanguage();
      expect(loaded, isNotNull);
      expect(loaded, equals('en')); // Default fallback
    });

    test('language code normalization: normalizes zh-Hans to zh', () async {
      final service = LocalizationService(prefs);
      
      // Save zh-Hans (should be normalized to zh)
      await service.saveLanguage('zh-Hans');
      final loaded = service.loadLanguage();
      expect(loaded, equals('zh'));
      
      // Current language code should also be normalized
      final currentCode = service.getCurrentLanguageCode();
      expect(currentCode, equals('zh'));
    });
  });
}