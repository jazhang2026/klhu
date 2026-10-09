import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/segmenter.dart';

void main() {
  group('sentenceRanges EN', () {
    test('splits on . ! ? and keeps delimiter', () {
      final ranges = sentenceRanges('Hello world. How are you? Fine!');
      expect(ranges.length, 3);
      expect(ranges[0].unit, SegmentUnit.sentence);
      expect('Hello world.'.substring(0, 0), '');
      // Verify substrings round-trip the sentences (leading gaps trimmed).
      const text = 'Hello world. How are you? Fine!';
      expect(ranges.map((r) => text.substring(r.start, r.end)).toList(),
          ['Hello world.', 'How are you?', 'Fine!']);
    });

    test('handles closing quote after delimiter', () {
      const text = 'She said "hi." Then left.';
      final ranges = sentenceRanges(text);
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end), 'She said "hi."');
    });
  });

  group('sentenceRanges zh-Hans', () {
    test('splits on 。！？；', () {
      const text = '今天天气很好。我们去公园吧！你呢？好；就这么定了。';
      final ranges = sentenceRanges(text);
      expect(
          ranges.map((r) => text.substring(r.start, r.end)).toList(),
          ['今天天气很好。', '我们去公园吧！', '你呢？', '好；', '就这么定了。']);
    });
  });

  group('mixed text', () {
    test('EN + CJK punctuation in one string', () {
      const text = 'Hello。你好。Bye.';
      final ranges = sentenceRanges(text);
      expect(ranges.map((r) => text.substring(r.start, r.end)).toList(),
          ['Hello。', '你好。', 'Bye.']);
    });
  });

  group('paragraphRanges', () {
    test('blank line splits, single newline does not', () {
      const text = 'Para one line1\nline2.\n\nPara two.';
      final ranges = paragraphRanges(text);
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end),
          'Para one line1\nline2.');
      expect(text.substring(ranges[1].start, ranges[1].end), 'Para two.');
    });
  });

  group('tap resolution', () {
    const text = 'First sentence. Second sentence.';

    test('offset inside sentence resolves to it', () {
      final seg = resolveSentence(text, 2);
      expect(text.substring(seg.start, seg.end), 'First sentence.');
    });

    test('whitespace tap resolves to nearest sentence', () {
      // Offset 15 is the space right after "First sentence."
      final seg = resolveSentence(text, 15);
      expect(text.substring(seg.start, seg.end), 'First sentence.');
    });

    test('offsets stay within bounds', () {
      final seg = resolveSentence(text, 1000);
      expect(seg.end, lessThanOrEqualTo(text.length));
      final segNeg = resolveSentence(text, -5);
      expect(segNeg.start, greaterThanOrEqualTo(0));
    });

    test('paragraph resolution', () {
      const multi = 'Para one.\n\nPara two.';
      final seg = resolveParagraph(multi, 14);
      expect(multi.substring(seg.start, seg.end), 'Para two.');
    });

    test('page range covers full text', () {
      final seg = pageRange(text);
      expect(seg.start, 0);
      expect(seg.end, text.length);
      expect(seg.unit, SegmentUnit.page);
    });
  });

  group('a paragraph ends a sentence too', () {
    // 011's 2026-09-24 amendment: "the highlight, the spoken sentence and the
    // resume point always name the same unit". The read cuts sentences per
    // paragraph (`reader_service.dart:412`) and so does the video's slots
    // (`video_timeline.dart:80`), but the tap and the resume anchor ask the
    // WHOLE text (`reading_view.dart:975`, `:538`) — so the whole-text view has
    // to agree with them. A blank line ends a paragraph, and it ends a
    // sentence with it: nothing here may span one.
    final blankLine = RegExp(r'\n[ \t]*\n+');

    test('a title with no ender does not swallow the paragraph after it', () {
      const text = '我的旅行日记\n\n今天天气很好。';
      expect(sentenceRanges(text).map((r) => text.substring(r.start, r.end)).toList(),
          ['我的旅行日记', '今天天气很好。']);
    });

    test('two unpunctuated paragraphs are two sentences', () {
      const text = '今天天气很好\n\n适合出去走走';
      expect(sentenceRanges(text).map((r) => text.substring(r.start, r.end)).toList(),
          ['今天天气很好', '适合出去走走']);
    });

    test('no sentence range spans a blank line', () {
      const text = '我的旅行日记\n\n今天天气很好。\n\nY mañana, también.';
      for (final r in sentenceRanges(text)) {
        final span = text.substring(r.start, r.end);
        expect(blankLine.hasMatch(span), isFalse,
            reason: 'this sentence spans a blank line: "$span"');
      }
    });

    test('spaces inside the blank line belong to no sentence', () {
      const text = '标题\n  \n正文。';
      expect(sentenceRanges(text).map((r) => text.substring(r.start, r.end)).toList(),
          ['标题', '正文。']);
    });

    test('the tap answers one paragraph, the way the read does', () {
      const text = '我的旅行日记\n\n今天天气很好。';
      final title = resolveSentence(text, 2);
      expect(text.substring(title.start, title.end), '我的旅行日记');
      final body = resolveSentence(text, 10);
      expect(text.substring(body.start, body.end), '今天天气很好。');
    });

    test('a text with no blank line is untouched by the rule', () {
      const text = 'First sentence.\nstill the same sentence? Yes.';
      expect(sentenceRanges(text).map((r) => text.substring(r.start, r.end)).toList(),
          ['First sentence.', 'still the same sentence?', 'Yes.']);
    });
  });
}
