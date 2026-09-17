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
