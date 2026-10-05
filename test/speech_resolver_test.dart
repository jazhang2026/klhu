import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/language.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/voice_store.dart';

/// The shared resolution layer (FR-002, FR-010, FR-011, FR-019 — quickstart rows
/// 6-8): 标准 mode is today's reading, character for character, and 多人对话 mode
/// is one `ParagraphSpeech` per turn, cut into sentences downstream exactly as a
/// paragraph is today.
void main() {
  const cccFemale = VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN');
  const ccdMale = VoiceEntry(name: 'cmn-cn-x-ccd-local', locale: 'zh-CN');
  const sfgEnglish = VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US');

  Future<VoiceChoice?> noVoice(String language) async => null;

  Future<List<ParagraphSpeech>> standard(
    String content, {
    int start = 0,
    int? end,
    Future<VoiceChoice?> Function(String)? loadVoice,
    Future<List<VoiceEntry>> Function()? loadInstalled,
  }) =>
      resolveSpeeches(
        content: content,
        start: start,
        end: end ?? content.length,
        loadVoice: loadVoice ?? noVoice,
        loadInstalled: loadInstalled,
      );

  Future<List<ParagraphSpeech>> dialogue(
    String content, {
    int start = 0,
    int? end,
    Set<String> removed = const {},
    Map<String, VoiceChoice> picks = const {},
    Future<VoiceChoice?> Function(String)? loadVoice,
    Future<List<VoiceEntry>> Function()? loadInstalled,
  }) =>
      resolveSpeeches(
        content: content,
        start: start,
        end: end ?? content.length,
        mode: ReadingMode.dialogue,
        removed: removed,
        picks: picks,
        loadVoice: loadVoice ?? noVoice,
        loadInstalled: loadInstalled ?? () async => const [cccFemale, ccdMale],
      );

  group('标准 is today\'s reading, exactly (FR-002, SC-005)', () {
    test('it returns what resolveParagraphSpeeches returns, for every shape',
        () async {
      for (final content in [
        'Hello world.\n\n你好世界。',
        'First sentence. Second sentence.',
        '{阿明} 你好。\n\n旁白一句。',
        '',
      ]) {
        final today = await resolveParagraphSpeeches(content, 0, content.length,
            (language) async => null);
        final shared = await standard(content);
        expect(
          shared.map((s) => [s.text, s.language, s.start, s.end]).toList(),
          today.map((s) => [s.text, s.language, s.start, s.end]).toList(),
          reason: content,
        );
      }
    });

    test('it never asks the engine for the installed voices', () async {
      // The voice list is what 多人对话 needs; 标准 must not pay for it — and on
      // a device with no voices the read is exactly today's.
      var asked = false;
      await standard('{阿明} 你好。', loadInstalled: () async {
        asked = true;
        return const [];
      });
      expect(asked, isFalse);
    });

    test('the language pick still decides a paragraph\'s voice', () async {
      final speeches = await standard(
        '你好。\n\nHello.',
        loadVoice: (language) async => language == 'zh-Hans'
            ? const VoiceChoice(
                language: 'zh-Hans', name: 'yue-hk-x-jar-local', locale: 'yue-HK')
            : null,
      );
      expect(speeches.first.voice!.name, 'yue-hk-x-jar-local');
      expect(speeches.last.voice, isNull);
    });
  });

  group('多人对话: one speech per turn (FR-003, FR-010)', () {
    test('the text is the turn\'s content and the spans are the content\'s',
        () async {
      const content = '{阿明} 你好。\n我很好。\n\n{May} Hello there.';
      final speeches = await dialogue(content);
      expect(speeches.map((s) => s.text).toList(),
          ['你好。\n我很好。', 'Hello there.']);
      // The prefix is outside every span: never spoken, never highlighted.
      for (final speech in speeches) {
        expect(content.substring(speech.start, speech.end), speech.text);
        expect(speech.text.contains('{'), isFalse);
      }
      expect(speeches.first.start, content.indexOf('你好'));
    });

    test('each turn carries its own language, not the content\'s', () async {
      final speeches = await dialogue('{JM} 你好。\n\n{May} Hello there.');
      expect(speeches.map((s) => s.language).toList(), ['zh-Hans', 'en']);
    });

    test('a paragraph with no tag is read as narration, in the language pick',
        () async {
      final speeches = await dialogue(
        '旁白一句。\n\n{阿明} 你好。',
        loadInstalled: () async => const [ccdMale],
        loadVoice: (language) async => language == 'zh-Hans'
            ? const VoiceChoice(
                language: 'zh-Hans', name: 'cmn-cn-x-ccc-local', locale: 'zh-CN')
            : null,
      );
      expect(speeches, hasLength(2));
      expect(speeches.first.text, '旁白一句。');
      expect(speeches.first.voice!.name, 'cmn-cn-x-ccc-local');
    });

    test('a range returns the turns it overlaps, still offset into the content',
        () async {
      const content = '{阿明} 你好。\n\n{May} Hello there.';
      final secondStart = content.indexOf('{May}');
      final speeches =
          await dialogue(content, start: secondStart, end: content.length);
      expect(speeches, hasLength(1));
      expect(speeches.single.text, 'Hello there.');
      expect(content.substring(speeches.single.start, speeches.single.end),
          'Hello there.');
    });

    test('a removed name reads as narration, in its language', () async {
      final speeches = await dialogue(
        '{阿芳} 我很好。\n\n{阿明} 你好。',
        removed: {'阿芳'},
      );
      expect(speeches, hasLength(2));
      expect(speeches.first.voice, isNull, reason: 'narration, no pick');
      expect(speeches.last.voice, isNotNull, reason: 'a role gets a voice');
    });

    test('a tag-only paragraph produces no speech', () async {
      final speeches = await dialogue('{阿明}\n\n你好。');
      expect(speeches, hasLength(1));
      expect(speeches.single.text, '你好。');
    });
  });

  group('a role\'s voice (FR-012, FR-013)', () {
    test('the pick wins, whatever the turn\'s language is', () async {
      const pick = VoiceChoice(
          language: 'es', name: 'es-us-x-sfb-local', locale: 'es-US');
      final speeches = await dialogue(
        '{阿明} 你好。',
        picks: const {'阿明': pick},
        loadInstalled: () async => const [cccFemale, ccdMale],
      );
      expect(speeches.single.voice!.name, pick.name);
      expect(speeches.single.voice!.locale, pick.locale);
    });

    test('with no pick, the turn\'s own language decides the voice', () async {
      final speeches = await dialogue(
        '{阿明} 你好。\n\n{May} Hello there.',
        loadInstalled: () async => const [cccFemale, sfgEnglish],
      );
      expect(speeches.first.voice!.name, cccFemale.name);
      expect(speeches.last.voice!.name, sfgEnglish.name);
    });

    test('no installed voices: the roles read in the OS default', () async {
      final speeches =
          await dialogue('{阿明} 你好。', loadInstalled: () async => const []);
      expect(speeches.single.voice, isNull);
    });
  });
}
