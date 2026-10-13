/// 016's step list, on the reader's own content (2026-10-12).
///
/// The reader's Spanish greetings are seven lines, each followed by a blank
/// line, and **no sentence delimiter before the tag** — the shape their phone
/// content has and every fixture in this suite did not. The step a read takes
/// must be the line the reader sees, comment included; only a comment's own
/// characters are no step (016 FR-004/005).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/segmenter.dart';

/// The reader's own content, verbatim, copied off their phone on 2026-10-12.
const readerContent = 'Basic Spanish 1\n'
    '\n'
    '[comment]Greetings\n'
    '\n'
    'Hola [comment] Hello\n'
    '\n'
    'Buenos días [comment] Good morning\n'
    '\n'
    'Buenas tardes [comment] Good afternoon\n'
    '\n'
    'Buenas noches [comment] Good evening / Good night\n'
    '\n'
    '¿Cómo estás? [comment] How are you?\n'
    '\n'
    '¿Qué tal? [comment] How\'s it going?';

/// Every step, as the reader sees it on the page.
List<String> steps(String text) => [
      for (final step in stepRanges(text))
        text.substring(step.start, step.end),
    ];

/// The step after [from], by the page's own rule: the first one that starts at
/// or after it (`reading_view.dart`, `_advanceStep`).
String? after(String text, int from) {
  for (final step in stepRanges(text)) {
    if (step.start >= from) return text.substring(step.start, step.end);
  }
  return null;
}

void main() {
  group('the reader\'s own content: a line with no delimiter before its tag',
      () {
    test('every line the reader sees is a step, in order', () {
      expect(steps(readerContent), [
        'Basic Spanish 1',
        'Hola [comment] Hello',
        'Buenos días [comment] Good morning',
        'Buenas tardes [comment] Good afternoon',
        'Buenas noches [comment] Good evening / Good night',
        '¿Cómo estás?',
        '¿Qué tal?',
      ]);
    });

    test('the step after the title is the very next line, not the sixth', () {
      final first = stepRanges(readerContent).first;
      expect(after(readerContent, stepEnd(readerContent, true, first)),
          'Hola [comment] Hello');
    });

    test('a step that carries a comment reaches to the comment\'s own end', () {
      final line = stepRanges(readerContent)[1];
      expect(line.start, readerContent.indexOf('Hola'));
      expect(stepEnd(readerContent, true, line),
          readerContent.indexOf('Hello') + 'Hello'.length);
    });

    test('a comment\'s own characters are never a step of their own', () {
      final own = steps(readerContent);
      expect(own.any((step) => step.startsWith('[comment]')), isFalse);
      expect(own.any((step) => step.startsWith(' How are you')), isFalse);
    });
  });

  group('the shapes the suite already had, unchanged', () {
    test('a delimiter before the tag: the sentence and its comment, two units',
        () {
      expect(steps('Hola. [注] Hi.'), ['Hola.']);
    });

    test('a comment whose content is two sentences is still not steps', () {
      expect(steps('Hola. [注] Hi. Bye.'), ['Hola.']);
    });

    test('a tag alone on a line is not a step', () {
      expect(steps('Hola.\n\n[注] Hi.'), ['Hola.']);
    });

    test('a tag before every sentence leaves nothing to step through', () {
      expect(steps('[注] Hi. Hola.'), isEmpty);
    });

    test('no comment at all: the sentence ranges themselves', () {
      expect(steps('Hola. Adiós.'), ['Hola.', 'Adiós.']);
      expect(
          stepRanges('Hola.')
              .map((s) => '${s.start}..${s.end}')
              .toList(),
          sentenceRanges('Hola.')
              .map((s) => '${s.start}..${s.end}')
              .toList());
    });
  });

  group('019: a mark is not a step of its own (the control)', () {
    // The reader's own content with the first line a title and the "Hola" line
    // a subtitle — and the control, the same text with the markers written as
    // spaces: two and three characters, exactly the markers' own lengths, so
    // every offset in the two texts coincides.
    String marked(String text) => text
        .replaceFirst('Basic Spanish 1', '# Basic Spanish 1')
        .replaceFirst('Hola [comment]', '## Hola [comment]');
    String spaced(String text) => text
        .replaceFirst('Basic Spanish 1', '  Basic Spanish 1')
        .replaceFirst('Hola [comment]', '   Hola [comment]');

    List<(int, int)> pairs(String text) =>
        [for (final step in stepRanges(text)) (step.start, step.end)];

    test('the markers written as spaces give the same steps, in the same order', () {
      expect(pairs(marked(readerContent)), pairs(spaced(readerContent)));
      expect(marked(readerContent).length, spaced(readerContent).length);
    });

    test('a marked line is the line the reader sees, marker included', () {
      expect(steps(marked(readerContent)).first, '# Basic Spanish 1');
      expect(steps(marked(readerContent)), contains('## Hola [comment] Hello'));
      expect(steps(marked(readerContent)).contains('# '), isFalse);
      expect(steps(marked(readerContent)).contains('## '), isFalse);
    });

    test("the reader's own content is untouched by 019", () {
      expect(steps(readerContent).first, 'Basic Spanish 1');
      expect(pairs(readerContent), hasLength(7));
    });
  });
}
