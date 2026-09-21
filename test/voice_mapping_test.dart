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
      final mapping = VoiceMappingTable.lookup('en-us-x-sfg-local');
      expect(mapping, isNotNull);
      expect(mapping!.englishName, contains('US'));
      expect(mapping.chineseName, contains('美式'));
    });

    test('lookup returns null for unknown voice', () {
      final mapping = VoiceMappingTable.lookup('unknown-voice-id');
      expect(mapping, isNull);
    });

    test('all returns non-empty list', () {
      final all = VoiceMappingTable.all();
      expect(all.isNotEmpty, isTrue);
    });

    // Regression: the picker labelled the Chinese voices with the wrong gender
    // (the voice named CCC was shown as a man while it speaks as a woman).
    // Values below come from measuring the rendered speech on the device.
    test('Chinese voices carry the measured gender', () {
      expect(VoiceMappingTable.lookup('cmn-cn-x-ccc-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('cmn-cn-x-ccc-network')!.gender, 'female');
      expect(VoiceMappingTable.lookup('cmn-cn-x-ssa-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('cmn-cn-x-ccd-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('cmn-cn-x-cce-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('cmn-tw-x-ctc-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('cmn-tw-x-ctd-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('cmn-tw-x-cte-local')!.gender, 'male');
    });

    // Same bug class on the English list: en-us-x-iob was labelled male, it
    // measures as a female voice.
    test('English voices carry the measured gender', () {
      expect(VoiceMappingTable.lookup('en-us-x-iob-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('en-gb-x-gbc-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('en-gb-x-gbd-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('en-au-x-aua-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('en-us-x-sfg-local')!.gender, 'female');
    });

    // The engine exposes no age and the region already sits in the name, so a
    // row may carry a gender and nothing else. Nothing is guessed.
    test('no row claims an age or a dialect', () {
      for (final mapping in VoiceMappingTable.all()) {
        expect(mapping.age, isNull, reason: mapping.systemVoiceId);
        expect(mapping.dialect, isNull, reason: mapping.systemVoiceId);
      }
    });

    // Local and network variants of a code are the same measured voice, and
    // the suffix only repeated the system name.
    test('display names drop the Local/Network suffix', () {
      for (final mapping in VoiceMappingTable.all()) {
        expect(mapping.englishName, isNot(contains('Local')));
        expect(mapping.englishName, isNot(contains('Network')));
        expect(mapping.chineseName, isNot(contains('本地')));
        expect(mapping.chineseName, isNot(contains('网络')));
      }
    });

    test('local and network variants of a code agree on gender', () {
      for (final base in const [
        'cmn-cn-x-ccc',
        'cmn-cn-x-ccd',
        'cmn-cn-x-cce',
        'cmn-cn-x-ssa',
        'cmn-tw-x-ctc',
        'cmn-tw-x-ctd',
        'cmn-tw-x-cte',
        'en-us-x-sfg',
        'en-gb-x-rjs',
        'en-au-x-aub',
      ]) {
        final local = VoiceMappingTable.lookup('$base-local')!.gender;
        expect(local, isNotNull, reason: base);
        expect(local, VoiceMappingTable.lookup('$base-network')!.gender,
            reason: base);
      }
    });
  });

  group('VoiceMappingService', () {
    late VoiceMappingService service;

    setUp(() {
      service = VoiceMappingService();
    });

    test('displays English name for mapped voice', () {
      const voice = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');
      final name = service.displayName(voice, AppLocalizationsEn());
      expect(name, contains('US'));
      expect(name, contains('Female'));
    });

    test('displays Chinese name for mapped voice', () {
      const voice = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');
      final name = service.displayName(voice, AppLocalizationsZh());
      expect(name, contains('美式'));
    });

    test('falls back to system voice name for unmapped voice', () {
      const voice = VoiceEntry(name: 'unknown-voice', locale: 'en-US');
      final name = service.displayName(voice, AppLocalizationsEn());
      expect(name, 'unknown-voice');
    });

    test('shows the gender as the only characteristic', () {
      const voice = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');
      final name = service.displayName(voice, AppLocalizationsEn());
      expect(name, contains('Female'));
      expect(name, isNot(contains('Young')));
      expect(name, isNot(contains('Standard')));
    });

    // The reported bug: a Chinese voice labelled 男声 while the installed
    // voice speaks as a woman (and the reverse for the CCD/CCE voices).
    test('Chinese list shows the measured gender for a Chinese voice', () {
      const female = VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN');
      expect(
        service.displayName(female, AppLocalizationsZh(),
            voiceListLanguage: 'zh-Hans'),
        contains('女'),
      );
      const male = VoiceEntry(name: 'cmn-cn-x-cce-local', locale: 'zh-CN');
      expect(
        service.displayName(male, AppLocalizationsZh(),
            voiceListLanguage: 'zh-Hans'),
        contains('男'),
      );
    });

    // The picker renders the other language's voice list while the app locale
    // stays put: labels must follow the LIST language.
    test('labels follow the voice list language, not the app locale', () {
      const voice = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');

      final zhListInEnApp = service.displayName(voice, AppLocalizationsEn(),
          voiceListLanguage: 'zh-Hans');
      expect(zhListInEnApp, contains('美式'));
      expect(zhListInEnApp, contains('女'));
      expect(zhListInEnApp, isNot(contains('Female')));

      final enListInZhApp = service.displayName(voice, AppLocalizationsZh(),
          voiceListLanguage: 'en');
      expect(enListInZhApp, contains('US'));
      expect(enListInZhApp, contains('Female'));
      expect(enListInZhApp, isNot(contains('美式')));
    });
  });
}
