/// Unit tests for `lib/ai/post_processor.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/post_processor.dart';

void main() {
  group('postProcessAiText', () {
    test('strips header filler lines', () {
      const input = '''Sure! Here's your story about a tiger:

Once upon a time, a tiger lived in the jungle.
It was orange and black.''';
      const expected = '''Once upon a time, a tiger lived in the jungle.
It was orange and black.''';
      expect(postProcessAiText(input), expected);
    });

    test('strips footer filler lines', () {
      const input = '''A tiger is the largest living cat species.

Let me know if you need anything else!''';
      const expected = 'A tiger is the largest living cat species.';
      expect(postProcessAiText(input), expected);
    });

    test('strips both header and footer filler', () {
      const input = '''Of course! Here is a dialogue between Alice and Bob:

{Alice}：Hello Bob!
{Bob}：Hi Alice!

Hope this helps!''';
      const expected = '''{Alice}：Hello Bob!
{Bob}：Hi Alice!''';
      expect(postProcessAiText(input), expected);
    });

    test('returns original text when no filler is detected', () {
      const input = '''{Teacher}：Today we learn about photosynthesis.
{Student}：What is that?''';
      expect(postProcessAiText(input), input);
    });

    test('returns original text when entire text is filler', () {
      const input = '''Sure!
Here you go!
Let me know!''';
      expect(postProcessAiText(input), input);
    });

    test('handles single-line input', () {
      expect(postProcessAiText('Hello world'), 'Hello world');
    });

    test('handles empty input', () {
      expect(postProcessAiText(''), '');
    });

    test('strips blank lines at edges after filler removal', () {
      const input = '''Sure!

{Narrator}：The end.''';
      const expected = '{Narrator}：The end.';
      expect(postProcessAiText(input), expected);
    });

    test('preserves {role} tags in content', () {
      const input = '''Write a story:

{Hero}：I will save the day!
{Villain}：Never!''';
      expect(postProcessAiText(input), input);
    });

    test('preserves [comment] tags in content', () {
      const input = '''Spanish: Hola [comment]Hello[/comment]
Spanish: Adiós [comment]Goodbye[/comment]''';
      expect(postProcessAiText(input), input);
    });
  });
}
