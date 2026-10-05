import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_store.dart';

/// The automatic voice assignment (FR-012–FR-015): which voice a role reads with
/// when the reader has not picked one.
///
/// Every case builds the installed list by hand, so the ranking is observable
/// without a device. The voices named are the app's own table's rows
/// (`lib/models/voice_mapping.dart`), so a case that passes here is a case the
/// device can produce.
void main() {
  const cccFemale = VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN');
  const ccdMale = VoiceEntry(name: 'cmn-cn-x-ccd-local', locale: 'zh-CN');
  const yucCantonese = VoiceEntry(name: 'yue-hk-x-yuc-local', locale: 'yue-HK');
  const sfbSpanish = VoiceEntry(name: 'es-us-x-sfb-local', locale: 'es-US');
  const sfgEnglish = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');

  VoiceChoice of(VoiceEntry voice, String language) =>
      VoiceChoice(language: language, name: voice.name, locale: voice.locale);

  List<VoiceChoice?> assign(
    String text, {
    List<VoiceEntry> installed = const [],
    Map<String, VoiceChoice> picks = const {},
    VoiceChoice? Function(String)? languagePick,
  }) =>
      assignTurnVoices(
        turns: turnsOf(text),
        picks: picks,
        installed: installed,
        languagePick: languagePick,
      );

  group('the pick (FR-013)', () {
    test('a role\'s own pick wins, whatever the turn\'s language is', () {
      final pick = of(sfbSpanish, 'es');
      final voices = assign(
        '{阿明} 你好。',
        installed: const [cccFemale, ccdMale],
        picks: {'阿明': pick},
      );
      expect(voices.single!.name, pick.name);
      expect(voices.single!.locale, pick.locale);
    });
  });

  group('the ranking', () {
    test('only voices of the turn\'s language are candidates', () {
      // English voices installed, a Chinese turn: the OS default reads it,
      // rather than a voice that would pronounce it wrong.
      final voices = assign(
        '{阿明} 你好。',
        installed: const [sfgEnglish, sfbSpanish],
      );
      expect(voices.single, isNull);
    });

    test('the reader\'s pick for that language ranks first', () {
      final voices = assign(
        '{阿明} 你好。',
        installed: const [cccFemale, ccdMale],
        languagePick: (_) => of(ccdMale, 'zh-Hans'),
      );
      expect(voices.single!.name, ccdMale.name);
    });

    test('the dialect of that pick comes next', () {
      // The pick is not installed any more (a voice was removed), so the second
      // rank is what decides: another Cantonese voice, not the Mandarin one that
      // would win on the name alone.
      final voices = assign(
        '{阿明} 你好。',
        installed: const [cccFemale, yucCantonese],
        languagePick: (_) => VoiceChoice(
          language: 'zh-Hans',
          name: 'yue-hk-x-jar-local',
          locale: 'yue-HK',
        ),
      );
      expect(voices.single!.name, yucCantonese.name);
    });

    test('the second role does not sound like the first', () {
      final voices = assign(
        '{阿明} 你好。\n\n{阿芳} 我很好。',
        installed: const [cccFemale, ccdMale],
      );
      expect(voices[0]!.name, isNot(voices[1]!.name));
      // The two candidates differ by recorded gender, which is the only reason
      // the ranking can tell them apart (research D5).
      expect(
        {voices[0]!.name, voices[1]!.name},
        {cccFemale.name, ccdMale.name},
      );
    });

    test('the order the engine reports voices in changes nothing', () {
      const text = '{阿明} 你好。\n\n{阿芳} 我很好。\n\n{阿明} 再见。';
      final forwards = assign(
        text,
        installed: const [cccFemale, ccdMale, yucCantonese],
      );
      final backwards = assign(
        text,
        installed: const [yucCantonese, ccdMale, cccFemale],
      );
      expect(
        forwards.map((v) => v?.name).toList(),
        backwards.map((v) => v?.name).toList(),
      );
    });
  });

  group('what the device offers (FR-015)', () {
    test('fewer voices than roles: a voice is reused, no role is left silent',
        () {
      final voices = assign(
        '{阿明} 你好。\n\n{阿芳} 我很好。\n\n{阿明} 再见。',
        installed: const [cccFemale],
      );
      expect(voices.every((v) => v != null), isTrue);
      expect(voices.map((v) => v!.name).toSet(), {cccFemale.name});
    });

    test('the local and network twins of one voice are one voice', () {
      const network = VoiceEntry(name: 'cmn-cn-x-ccc-network', locale: 'zh-CN');
      // One installed voice, listed twice by the engine: the second role reuses
      // it rather than being given a "different" voice that sounds identical.
      expect(
        assign('{阿明} 你好。\n\n{阿芳} 我很好。', installed: const [cccFemale, network])
            .map((v) => v!.name)
            .toSet(),
        {cccFemale.name},
      );
      // …and with a genuinely different voice available, that one is used.
      expect(
        assign('{阿明} 你好。\n\n{阿芳} 我很好。',
                installed: const [cccFemale, network, ccdMale])
            .map((v) => v!.name)
            .toSet(),
        {cccFemale.name, ccdMale.name},
      );
    });
  });

  group('a role across its turns', () {
    test('one voice in one language, however many turns it reads', () {
      final voices = assign(
        '{阿明} 你好。\n\n{阿芳} 我很好。\n\n{阿明} 再见。\n\n{阿明} 晚安。',
        installed: const [cccFemale, ccdMale],
      );
      expect(voices[0]!.name, voices[2]!.name);
      expect(voices[0]!.name, voices[3]!.name);
    });

    test('a role whose turns are in two languages reads in two voices', () {
      final voices = assign(
        '{阿明} 你好。\n\n{阿明} hello there.',
        installed: const [cccFemale, sfgEnglish],
      );
      expect(voices[0]!.name, cccFemale.name);
      expect(voices[1]!.name, sfgEnglish.name);
    });
  });

  group('narration (FR-002, FR-009)', () {
    test('narration reads in the reader\'s pick for its language', () {
      final voices = assign(
        '旁白一句。\n\n{阿明} 你好。',
        installed: const [cccFemale, sfbSpanish],
        languagePick: (language) =>
            language == 'zh-Hans' ? of(cccFemale, 'zh-Hans') : null,
      );
      expect(voices[0]!.name, cccFemale.name);
    });
  });
}
