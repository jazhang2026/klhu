/// 019 US1 — the mark's own rule (`#` a title, `##` a subtitle), read off the
/// reader's text alone (quickstart rows 1 and 2).
///
/// What is a mark, what it rules, and every shape the rule refuses so the
/// reader's own lines stay theirs. The cases are `spec.md`'s FR-001/FR-002 and
/// its edge cases (`#hashtag`, `#1 best`, `### `, a lone `#`, `  # Title`,
/// `# Title #`), never values read off the implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/head_tag.dart';

void main() {
  group('the marks the rule recognises', () {
    test('a line that starts with "# " is a title, and the marker is the hash and its one space', () {
      final marks = headTagsOf('# Basic Spanish 1');
      expect(marks, hasLength(1));
      final mark = marks.single;
      expect(mark.level, 1);
      expect(mark.start, 0);
      expect(mark.markEnd, 2);
      expect(mark.lineStart, 2);
      expect(mark.lineEnd, 17);
    });

    test('a line that starts with "## " is a subtitle', () {
      final mark = headTagsOf('## Greetings').single;
      expect(mark.level, 2);
      expect(mark.markEnd, 3);
      expect(mark.lineStart, 3);
      expect(mark.lineEnd, 12);
    });

    test('a mark rules the line it starts, and only that line', () {
      const text = 'text\n# Title\nmore';
      final mark = headTagsOf(text).single;
      expect(text.substring(mark.start, mark.markEnd), '# ');
      expect(text.substring(mark.lineStart, mark.lineEnd), 'Title');
    });

    test('two marks in one paragraph are found in text order, at their own levels', () {
      final marks = headTagsOf('# Title\n## Sub\nbody');
      expect([for (final mark in marks) mark.level], [1, 2]);
      expect(marks[0].lineEnd, 7);
      expect(marks[1].lineStart, 11);
      expect(marks[1].lineEnd, 14);
    });
  });

  group("the shapes the rule refuses — the reader's own text (FR-002)", () {
    test('#hashtag is text: a marker needs its one space', () {
      expect(headTagsOf('#hashtag'), isEmpty);
    });

    test('#1 best is text', () {
      expect(headTagsOf('#1 best'), isEmpty);
    });

    test('### note and #### are text: only one or two markers are a mark', () {
      expect(headTagsOf('### note'), isEmpty);
      expect(headTagsOf('#### '), isEmpty);
    });

    test('a lone # or ## is text', () {
      expect(headTagsOf('#'), isEmpty);
      expect(headTagsOf('##'), isEmpty);
    });

    test('a marker followed by whitespace alone is text', () {
      expect(headTagsOf('# '), isEmpty);
      expect(headTagsOf('##  '), isEmpty);
      expect(headTagsOf('#\n'), isEmpty);
    });

    test('a marker after leading whitespace is text', () {
      expect(headTagsOf('  # Title'), isEmpty);
    });

    test('a marker followed by a tab is text', () {
      expect(headTagsOf('#\tTitle'), isEmpty);
    });

    test('a trailing #-sequence refuses the whole line', () {
      expect(headTagsOf('# Title #'), isEmpty);
      expect(headTagsOf('# Title ##'), isEmpty);
    });

    test('a mid-line # does not refuse the line, and stays painted', () {
      const text = '# C# notes';
      expect(headTagsOf(text).single.lineEnd, text.length);
      expect(headTagsOf('# Title # more'), hasLength(1));
    });

    test('an empty text holds no mark', () {
      expect(headTagsOf(''), isEmpty);
    });
  });

  group("a mark is not read inside a comment (FR-009)", () {
    test("a #-line inside a comment's span is the comment's own characters", () {
      const text = 'Hola.\n\n[注] Hi.\n# not a mark';
      final spans = [
        for (final comment in commentsOf(text))
          (comment.tag.start, comment.contentEnd),
      ];
      expect(headTagsOf(text, inside: spans), isEmpty);
      // Without the exclusion the same line is a mark: the exclusion is what
      // makes the comment's words the comment's, not a second rule.
      expect(headTagsOf(text), hasLength(1));
    });

    test('a mark on a line that also carries a comment is still a mark', () {
      const text = '# Title [注] Hola';
      final spans = [
        for (final comment in commentsOf(text))
          (comment.tag.start, comment.contentEnd),
      ];
      expect(headTagsOf(text, inside: spans), hasLength(1));
    });

    test('the display is what the page paints: no marker, the words and the rule', () {
      final display = displayOf('# Basic Spanish 1\n\n## Greetings');
      expect(display.text, 'Basic Spanish 1\n\nGreetings');
      expect(display.heads, hasLength(2));
    });
  });
}
