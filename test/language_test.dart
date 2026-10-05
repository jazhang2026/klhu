import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/language.dart';

void main() {
  group('detectLanguage (per-paragraph, CJK-wins)', () {
    test('pure English paragraph resolves to en', () {
      expect(
        detectLanguage('The sun rose over the quiet town. Birds sang.'),
        'en',
      );
    });

    test('pure Chinese paragraph resolves to zh-Hans', () {
      expect(detectLanguage('清晨的阳光洒在安静的小镇上。鸟儿在歌唱。'), 'zh-Hans');
    });

    test('mixed-script paragraph resolves to zh-Hans (CJK wins)', () {
      expect(
        detectLanguage('Flutter 让构建精美应用变得简单 with one codebase.'),
        'zh-Hans',
      );
    });

    test('single CJK character flips paragraph to zh-Hans', () {
      expect(detectLanguage('Hello 世界'), 'zh-Hans');
    });

    test('empty paragraph resolves to en (fallback)', () {
      expect(detectLanguage(''), 'en');
    });

    test('punctuation-only paragraph resolves to en (fallback)', () {
      expect(detectLanguage('... !!! 。？'), 'en');
    });

    test('extended CJK ranges count (Extension A, compatibility)', () {
      // U+3400 CJK Extension A, U+FA0E compatibility ideograph.
      final s =
          'a${String.fromCharCode(0x3400)} b${String.fromCharCode(0xFA0E)}';
      expect(detectLanguage(s), 'zh-Hans');
    });

    test('hiragana/katakana alone do not count as zh-Hans', () {
      expect(detectLanguage('こんにちは'), 'en');
    });
  });

  // 2026-10-02, on the OnePlus 13: a Spanish/English phrasebook ("Buenas
  // tardes." beside "Good afternoon.") read its Spanish lines in the English
  // voice — a phone keyboard drops the accents, and an accent-less greeting hit
  // no rule at all, so the paragraph fell through to English.
  group('detectLanguage: Spanish the keyboard left unaccented', () {
    test('a line with no accent at all is still Spanish', () {
      for (final line in const [
        'Buenas tardes.',
        'Buenas noches.',
        'Hola.',
        'Gracias.',
        'Por favor.',
        'Hasta luego.',
        'A mi me gusta.',
        'Como estas?',
        // The reader's own phrasebook, the lines the old table missed.
        'Muy bien, gracias.',
        'De nada.',
        'Mucho gusto.',
        'Nos vemos.',
        'No entiendo.',
        'Ayuda.',
      ]) {
        expect(detectLanguage(line), 'es', reason: line);
      }
    });

    test('a Spanish line and an English line with the same word stay apart',
        () {
      // "No." is Spanish and "No." is English: the only case a rule table
      // cannot decide, and the reason the tag exists (014).
      expect(detectLanguage('No.'), 'en');
    });

    test('English made of words Spanish shares stays English', () {
      for (final line in const [
        'No son of mine.',
        'The son is here.',
        'I have a son and a daughter.',
        'La la land.',
        'It is a son.',
        'No, no, no.',
        'Do me a favor.',
        'A dime is ten cents.',
      ]) {
        expect(detectLanguage(line), 'en', reason: line);
      }
    });

    test('a phrasebook page resolves each line to its own language', () async {
      const page = 'Buenos días.\n\nGood morning.\n\nBuenas tardes.\n\n'
          'Good afternoon.\n\nBuenas noches.\n\nGood evening / Good night.';
      final speeches =
          await resolveParagraphSpeeches(page, 0, page.length, (_) async => null);
      expect(speeches.map((s) => s.language).toList(),
          ['es', 'en', 'es', 'en', 'es', 'en']);
      expect(speeches.map((s) => s.text.trim()).toList(), const [
        'Buenos días.',
        'Good morning.',
        'Buenas tardes.',
        'Good afternoon.',
        'Buenas noches.',
        'Good evening / Good night.',
      ]);
    });
  });

  group('resolveParagraphSpeeches offsets', () {
    test('start/end tile the requested range in order', () async {
      const content = 'Hello world.\n\n你好世界。';
      final speeches = await resolveParagraphSpeeches(
        content,
        0,
        content.length,
        (_) async => null,
      );
      expect(speeches.length, 2);
      expect(content.substring(speeches[0].start, speeches[0].end),
          'Hello world.');
      expect(content.substring(speeches[1].start, speeches[1].end), '你好世界。');
      expect(speeches[0].language, 'en');
      expect(speeches[1].language, 'zh-Hans');
    });

    test('sentence sub-range keeps enclosing paragraph offsets', () async {
      const content = 'First sentence. Second sentence.';
      final speeches = await resolveParagraphSpeeches(
        content,
        'First sentence. '.length,
        content.length,
        (_) async => null,
      );
      expect(speeches.length, 1);
      expect(
          content.substring(speeches[0].start, speeches[0].end),
          'Second sentence.');
    });
  });
}
