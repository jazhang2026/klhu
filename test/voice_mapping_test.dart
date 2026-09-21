import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations_en.dart';
import 'package:klhu/l10n/app_localizations_zh.dart';
import 'package:klhu/models/voice_mapping.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/services/voice_mapping_service.dart';

void main() {
  group('VoiceMapping', () {
    test('creates mapping with all fields', () {
      const mapping = VoiceMapping(
        systemVoiceId: 'test-voice',
        englishName: 'Test Voice',
        chineseName: '测试语音',
        gender: 'female',
        age: 'young',
        dialect: 'standard',
      );
      expect(mapping.systemVoiceId, 'test-voice');
      expect(mapping.englishName, 'Test Voice');
      expect(mapping.chineseName, '测试语音');
      expect(mapping.gender, 'female');
      expect(mapping.age, 'young');
      expect(mapping.dialect, 'standard');
    });

    test('creates mapping with optional fields null', () {
      const mapping = VoiceMapping(
        systemVoiceId: 'test-voice-2',
        englishName: 'Basic Voice',
        chineseName: '基本语音',
      );
      expect(mapping.gender, isNull);
      expect(mapping.age, isNull);
      expect(mapping.dialect, isNull);
    });
  });

  group('VoiceMappingTable', () {
    test('lookup returns mapping for known voice', () {
      const voiceId = 'com.google.android.tts:en-US-x-sfg';
      final mapping = VoiceMappingTable.lookup(voiceId);
      expect(mapping, isNotNull);
      expect(mapping!.englishName, contains('Google'));
      expect(mapping.chineseName, contains('谷歌'));
    });

    test('lookup returns null for unknown voice', () {
      final mapping = VoiceMappingTable.lookup('unknown-voice-id');
      expect(mapping, isNull);
    });

    test('all returns non-empty list', () {
      final all = VoiceMappingTable.all();
      expect(all.isNotEmpty, isTrue);
    });
  });

  group('VoiceMappingService', () {
    late VoiceMappingService service;

    setUp(() {
      service = VoiceMappingService();
    });

    test('displays English name for mapped voice', () {
      const voice = VoiceEntry(
        name: 'com.google.android.tts:en-US-x-sfg',
        locale: 'en-US',
      );
      final l10n = AppLocalizationsEn();
      final name = service.displayName(voice, l10n);
      expect(name, contains('Google'));
      expect(name, contains('Female'));
    });

    test('displays Chinese name for mapped voice', () {
      const voice = VoiceEntry(
        name: 'com.google.android.tts:en-US-x-sfg',
        locale: 'en-US',
      );
      final l10n = AppLocalizationsZh();
      final name = service.displayName(voice, l10n);
      expect(name, contains('谷歌'));
    });

    test('falls back to system voice name for unmapped voice', () {
      const voice = VoiceEntry(
        name: 'unknown-voice',
        locale: 'en-US',
      );
      final l10n = AppLocalizationsEn();
      final name = service.displayName(voice, l10n);
      expect(name, 'unknown-voice');
    });

    test('includes characteristics in display name', () {
      const voice = VoiceEntry(
        name: 'com.google.android.tts:en-US-x-sfg',
        locale: 'en-US',
      );
      final l10n = AppLocalizationsEn();
      final name = service.displayName(voice, l10n);
      expect(name, contains('Female'));
      expect(name, contains('Young'));
      expect(name, contains('Standard'));
    });
  });
}
