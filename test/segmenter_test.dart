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
}
