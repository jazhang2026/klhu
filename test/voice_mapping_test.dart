import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations_en.dart';
import 'package:klhu/l10n/app_localizations_es.dart';
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
        'es-es-x-eea',
        'es-es-x-eec',
        'es-es-x-eed',
        'es-us-x-esc',
        'es-us-x-esd',
        'es-us-x-esf',
        'es-us-x-sfb',
        'yue-hk-x-jar',
        'yue-hk-x-yuc',
        'yue-hk-x-yud',
        'yue-hk-x-yue',
        'yue-hk-x-yuf',
      ]) {
        final local = VoiceMappingTable.lookup('$base-local')!.gender;
        expect(local, isNotNull, reason: base);
        expect(local, VoiceMappingTable.lookup('$base-network')!.gender,
            reason: base);
      }
    });

    // Spec 007: the es-* and yue-HK rows come from the 2026-09-22 sweep
    // (specs/007-.../voice-gender-evidence.md), same method as the rows above:
    // rendered speech tracked for F0, cross-checked against the engine
    // manifest's gender bit.
    test('Spanish voices carry the measured gender', () {
      expect(VoiceMappingTable.lookup('es-ES-language')!.gender, 'female');
      expect(VoiceMappingTable.lookup('es-US-language')!.gender, 'female');
      expect(VoiceMappingTable.lookup('es-es-x-eea-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('es-es-x-eed-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('es-es-x-eef-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('es-us-x-esd-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('es-us-x-esf-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('es-us-x-sfb-local')!.gender, 'female');
    });

    // A Cantonese voice is named by its dialect instead of carrying a dialect
    // characteristic (spec FR-010), so gender is the only label it needs.
    test('Cantonese voices carry the measured gender', () {
      expect(VoiceMappingTable.lookup('yue-HK-language')!.gender, 'female');
      expect(VoiceMappingTable.lookup('yue-hk-x-jar-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('yue-hk-x-yuc-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('yue-hk-x-yue-local')!.gender, 'female');
      expect(VoiceMappingTable.lookup('yue-hk-x-yud-local')!.gender, 'male');
      expect(VoiceMappingTable.lookup('yue-hk-x-yuf-local')!.gender, 'male');
    });

    // Every voice the sweep measured for the Spanish and Cantonese lists has a
    // row, so no row in those lists falls back to a raw system id (T023).
    test('the measured es-* and yue-* voices all resolve', () {
      for (final measured in const [
        'es-ES-language',
        'es-US-language',
        'es-es-x-eea-local',
        'es-es-x-eea-network',
        'es-es-x-eec-local',
        'es-es-x-eec-network',
        'es-es-x-eed-local',
        'es-es-x-eed-network',
        'es-es-x-eee-local',
        'es-es-x-eef-local',
        'es-us-x-esc-local',
        'es-us-x-esc-network',
        'es-us-x-esd-local',
        'es-us-x-esd-network',
        'es-us-x-esf-local',
        'es-us-x-esf-network',
        'es-us-x-sfb-local',
        'es-us-x-sfb-network',
        'yue-HK-language',
        'yue-hk-x-jar-local',
        'yue-hk-x-jar-network',
        'yue-hk-x-yuc-local',
        'yue-hk-x-yuc-network',
        'yue-hk-x-yud-local',
        'yue-hk-x-yud-network',
        'yue-hk-x-yue-local',
        'yue-hk-x-yue-network',
        'yue-hk-x-yuf-local',
        'yue-hk-x-yuf-network',
      ]) {
        final mapping = VoiceMappingTable.lookup(measured);
        expect(mapping, isNotNull, reason: measured);
        expect(mapping!.englishName, isNot(measured), reason: measured);
        expect(mapping.chineseName, isNot(measured), reason: measured);
        expect(mapping.gender, isNotNull, reason: measured);
      }
    });

    // The one voice whose two cues disagree (F0 in the overlap band, manifest
    // saying person 1): no gender is claimed rather than a coin flip.
    test('the ambiguous voice carries no gender', () {
      expect(VoiceMappingTable.lookup('en-us-x-tpc-local')!.gender, isNull);
      expect(VoiceMappingTable.lookup('en-us-x-tpc-network')!.gender, isNull);
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

    // The Spanish list is labelled in Spanish: with only an en/zh split the
    // Spanish list fell through to the English labels, so a Spanish reading
    // session showed "US SFB (Female)" while app_es.arb already had "Femenina"
    // (found on emulator-5554, spec 007 SC-002).
    test('the Spanish list is labelled in Spanish', () {
      const female = VoiceEntry(name: 'es-us-x-sfb-local', locale: 'es-US');
      const male = VoiceEntry(name: 'es-us-x-esd-local', locale: 'es-US');

      final femaleName = service.displayName(female, AppLocalizationsEs(),
          voiceListLanguage: 'es');
      expect(femaleName, contains('Femenina'));
      expect(femaleName, isNot(contains('Female')));

      final maleName = service.displayName(male, AppLocalizationsEs(),
          voiceListLanguage: 'es');
      expect(maleName, contains('Masculina'));
      expect(maleName, isNot(contains('Male')));
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
