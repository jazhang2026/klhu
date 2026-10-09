/// 015 US2 — the read's own half of the comment tag (quickstart rows 6-8 and 10,
/// plus one dialogue-mode case): a comment resolves as its own speech, placed
/// after the sentence it belongs to, in the language its own content detects and
/// that language's own voice — and with the setting off none of its characters
/// reaches the engine at all.
///
/// The harness is `speech_resolver_test.dart`'s: the shared resolution layer over
/// a stub `loadVoice`, one distinct voice per language so a voice's identity is
/// assertable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/language.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/voice_store.dart';

void main() {
  const esVoice = VoiceChoice(language: 'es', name: 'es-us-x-sfb-local', locale: 'es-US');
  const enVoice = VoiceChoice(language: 'en', name: 'en-us-x-sfg-local', locale: 'en-US');

  /// The reader's picks: one voice per language, so "the comment reads in its own
  /// language's voice" is a comparison between two different values.
  Future<VoiceChoice?> picked(String language) async => switch (language) {
        'es' => esVoice,
        'en' => enVoice,
        _ => null,
      };

  Future<List<ParagraphSpeech>> read(
    String content, {
    bool commentsRead = true,
    ReadingMode mode = ReadingMode.standard,
    int? start,
    int? end,
    Map<String, VoiceChoice> picks = const {},
    Set<String> removed = const {},
    Future<VoiceChoice?> Function(String)? loadVoice,
  }) =>
      resolveSpeeches(
        content: content,
        start: start ?? 0,
        end: end ?? content.length,
        mode: mode,
        picks: picks,
        removed: removed,
        commentsRead: commentsRead,
        loadVoice: loadVoice ?? picked,
      );

  const bilingual = 'Hola.\n\n[注] How are you?';

  group("6. the comment is read after its sentence, in its own voice", () {
    test('it is its own speech, placed right after the sentence it belongs to',
        () async {
      final speeches = await read(bilingual);
      expect(speeches.map((s) => s.text).toList(), ['Hola.', 'How are you?']);
      expect(speeches.first.language, 'es');
      expect(speeches.first.start, 0);
      expect(speeches.first.end, 5);
      expect(speeches.last.language, 'en',
          reason: "the comment's own content decides its language (FR-008)");
      expect(speeches.last.start, bilingual.indexOf('How'));
      expect(speeches.last.end, bilingual.length);
      expect(speeches.last.isComment, isTrue);
      expect(speeches.first.isComment, isFalse);
      // FR-004/FR-005 from the read's own side: no marker character is any part
      // of what the engine is handed.
      for (final speech in speeches) {
        expect(speech.text.contains('['), isFalse, reason: speech.text);
        expect(speech.text.contains(']'), isFalse, reason: speech.text);
      }
    });

    test('the comment reads in its own language\'s pick, the sentence in its own',
        () async {
      final asked = <String>[];
      final speeches = await read(bilingual, loadVoice: (language) async {
        asked.add(language);
        return picked(language);
      });
      expect(asked.toSet(), {'es', 'en'});
      expect(speeches.first.voice?.name, esVoice.name);
      expect(speeches.last.voice?.name, enVoice.name,
          reason: "the comment's voice is the pick for ITS language (FR-008)");
    });

    test('a comment of two sentences is cut exactly as a paragraph is', () async {
      const content = 'Hola.\n\n[注] How are you? Fine.';
      final speeches = await read(content);
      final comment = speeches.last;
      expect(comment.text, 'How are you? Fine.');
      // One utterance per sentence, from the SAME cutter the reader service uses
      // (010 FR-011): the comment needs no second unit (FR-007), and the cut —
      // including where a sentence's own range ends — is a paragraph's own.
      expect(
          sentenceRanges(comment.text)
              .map((r) => comment.text.substring(r.start, r.end))
              .toList(),
          ['How are you?', 'Fine.']);
    });

    test('a comment whose language is the sentence\'s own is still a comment',
        () async {
      const content = 'Hola.\n\n[注] Buenos días.';
      final speeches = await read(content);
      expect(speeches, hasLength(2));
      expect(speeches.last.language, 'es');
      expect(speeches.last.isComment, isTrue);
    });

    test('a text with no tag is today\'s call, field for field', () async {
      for (final content in [
        'Hello world.\n\n你好世界。',
        'First sentence. Second sentence.',
        '{阿明} 你好。\n\n旁白一句。',
        '',
      ]) {
        final mine = await read(content);
        final theirs = await resolveParagraphSpeeches(
            content, 0, content.length, picked);
        expect(mine.length, theirs.length, reason: content);
        for (var i = 0; i < mine.length; i++) {
          expect(mine[i].text, theirs[i].text, reason: content);
          expect(mine[i].language, theirs[i].language, reason: content);
          expect(mine[i].voice?.name, theirs[i].voice?.name, reason: content);
          expect(mine[i].start, theirs[i].start, reason: content);
          expect(mine[i].end, theirs[i].end, reason: content);
          expect(mine[i].isComment, isFalse, reason: content);
        }
      }
    });
  });

  group('7. with the comments off, nothing of them reaches the engine', () {
    test('the comment\'s own paragraph contributes no speech at all', () async {
      final speeches = await read(bilingual, commentsRead: false);
      expect(speeches.map((s) => s.text).toList(), ['Hola.']);
      for (final speech in speeches) {
        expect(speech.text.contains('How'), isFalse);
      }
    });

    test('an inline tag takes the rest of its paragraph with it, switch or not',
        () async {
      const content = 'Hola. [注] Hi. Adiós.';
      final on = await read(content);
      final off = await read(content, commentsRead: false);
      expect(on.map((s) => s.text).toList(), ['Hola.', 'Hi. Adiós.']);
      expect(off.map((s) => s.text).toList(), ['Hola.'],
          reason: 'with the comments off the sentence after an inline tag is '
              'not read either — it is the comment\'s own text (FR-002)');
    });

    test('a comment at the very head of a content is never spoken', () async {
      const content = '[注] Hello.\n\nHola.';
      final on = await read(content);
      final off = await read(content, commentsRead: false);
      expect(on.map((s) => s.text).toList(), ['Hola.'],
          reason: 'it belongs to no sentence (FR-003)');
      expect(off.map((s) => s.text).toList(), ['Hola.']);
    });
  });

  group('8. a comment\'s content is no sentence\'s span', () {
    test('no non-comment speech overlaps a comment', () async {
      const content =
          'Hola. [注] Hi. Adiós.\n\nBuenos días.\n\n[註] Buenos días means good morning.';
      final speeches = await read(content);
      final comments = commentsOf(content);
      expect(comments, hasLength(2));
      // Nothing that is a sentence's own speech may touch a comment's span…
      for (final speech in speeches.where((s) => !s.isComment)) {
        for (final comment in comments) {
          final overlaps = speech.start < comment.contentEnd &&
              comment.contentStart < speech.end;
          expect(overlaps, isFalse,
              reason: '${speech.text} against ${comment.text}');
        }
      }
      // …and a comment's own speech is exactly one comment's own span.
      for (final speech in speeches.where((s) => s.isComment)) {
        expect(
            comments.where((c) =>
                c.contentStart == speech.start && c.contentEnd == speech.end),
            hasLength(1),
            reason: speech.text);
      }
    });
  });

  group('10. 标准 is unchanged but for the comments', () {
    test('the sentences keep their spans, languages and voices', () async {
      const content = 'Hola.\n\n[注] How are you?\n\nAdiós.';
      final on = await read(content);
      final off = await read(content, commentsRead: false);
      final onSentences = on.where((s) => !s.isComment).toList();
      expect(onSentences.length, off.length);
      for (var i = 0; i < off.length; i++) {
        expect(onSentences[i].text, off[i].text);
        expect(onSentences[i].language, off[i].language);
        expect(onSentences[i].voice?.name, off[i].voice?.name);
        expect(onSentences[i].start, off[i].start);
        expect(onSentences[i].end, off[i].end);
      }
      // The switch adds exactly one entry, at its own text position.
      expect(on.map((s) => s.text).toList(), ['Hola.', 'How are you?', 'Adiós.']);
      expect(off.map((s) => s.text).toList(), ['Hola.', 'Adiós.']);
    });
  });

  group('9. in 多人对话 the turn keeps its own words, language and voice', () {
    // The reader's own fixture (quickstart row 9): a Chinese turn and the
    // English comment under it. 阿明 has a pick, so "the comment reads in its
    // OWN language's voice, never the role's" compares two known values.
    const abby = VoiceChoice(language: 'zh-Hans', name: 'yue-hk-x-yud-local', locale: 'yue-HK');
    const dialogue = '{阿明} 今日个天气真系唔错啊。\n\n[注] How are you?';

    test("the turn's speech is the turn's own text, its own language", () async {
      final speeches =
          await read(dialogue, mode: ReadingMode.dialogue, picks: {'阿明': abby});
      expect(speeches.map((s) => s.text).toList(),
          ['今日个天气真系唔错啊。', 'How are you?']);
      final turn = speeches.first;
      expect(turn.role, '阿明');
      expect(turn.isComment, isFalse);
      expect(turn.language, 'zh-Hans',
          reason: "the turn keeps its own language: an English comment does not "
              'make a Chinese turn English');
      expect(turn.text.contains('['), isFalse,
          reason: "the comment's own characters are no part of the turn's text");
      final comment = speeches.last;
      expect(comment.isComment, isTrue);
      expect(comment.role, isNull,
          reason: "a comment is never the turn's own speech (FR-011)");
      expect(comment.language, 'en',
          reason: "the comment's own content decides its language (FR-008)");
    });

    test("the comment reads in its own language's voice, never the role's",
        () async {
      final speeches =
          await read(dialogue, mode: ReadingMode.dialogue, picks: {'阿明': abby});
      expect(speeches.first.voice?.name, abby.name);
      expect(speeches.last.voice?.name, enVoice.name);
      expect(speeches.first.voice?.name, isNot(speeches.last.voice?.name));
    });

    test('a paragraph that is nothing but a comment is no turn, no role, no count',
        () async {
      const text = '{阿明} 你好。\n\n[注] Hello.\n\n{May} Hi.';
      final roles = rolesOf(turnsOf(text, comments: commentsOf(text)));
      expect(roles.map((r) => r.name).toList(), ['阿明', 'May']);
      expect(roles.first.turnCount, 1);
      // Without the comment list the comment-only paragraph is a narration turn
      // — the difference the new rule makes (FR-011).
      final plain = turnsOf(text);
      expect(plain, hasLength(3));
      expect(plain[1].role, isNull);
      expect(plain[1].text, '[注] Hello.');
    });

    test('a role whose only paragraph is a comment is no role at all', () async {
      const text = '{阿明} [注] Hello.\n\n{May} Hi.';
      final roles = rolesOf(turnsOf(text, comments: commentsOf(text)));
      expect(roles.map((r) => r.name).toList(), ['May'],
          reason: "阿明's paragraph holds nothing but a comment (FR-011)");
    });

    test("a comment does not move the turn's own count or its own text", () async {
      const text = '{阿明} 你好。[注] Hello.\n\n{阿明} 再见。';
      final turns = turnsOf(text, comments: commentsOf(text));
      final roles = rolesOf(turns);
      expect(roles.single.name, '阿明');
      expect(roles.single.turnCount, 2, reason: 'unmoved by the comment (SC-005)');
      expect(turns.first.text, '你好。',
          reason: "the turn's content stops at the comment's tag (FR-011)");
      expect(turns.last.text, '再见。');
    });

    test('a comment before every sentence is never spoken, in dialogue too',
        () async {
      const content = '[注] Hello.\n\n{阿明} 你好。';
      final speeches = await read(content, mode: ReadingMode.dialogue);
      expect(speeches.map((s) => s.text).toList(), ['你好。'],
          reason: 'the comment belongs to no sentence (FR-003)');
      expect(speeches.every((s) => !s.isComment), isTrue);
    });
  });
}
