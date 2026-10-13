/// 015 — the comment tag's own rule (quickstart rows 1-4 and 8, plus the turn
/// scan T005 makes comment-aware).
///
/// The cases are the spec's own examples (`spec.md` → Clarifications, the edge
/// cases and the tag's reference table in `plan.md`), never values read off the
/// implementation: each spelling the reader writes, each shape the rule refuses,
/// where a comment's content begins and ends, where the tag is read, and which
/// sentence it belongs to.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/segmenter.dart';

/// One paragraph, whole: the shapes below are single paragraphs unless the case
/// says otherwise.
CommentTag? head(String text) => commentTagAt(text, 0, text.length);

void main() {
  group("the marker's grammar", () {
    test('every spelling the reader types is one tag', () {
      // The English spelling, in any ASCII case (FR-001).
      for (final text in ['[comment] How are you?', '[Comment] How are you?', '[COMMENT] How are you?']) {
        final tag = head(text);
        expect(tag, isNotNull, reason: text);
        expect(tag!.name.toLowerCase(), 'comment');
        expect(tag.start, 0);
        expect(text.substring(tag.contentStart), 'How are you?');
      }
      // Simplified Chinese, Traditional Chinese and Spanish — the reader's
      // amendment of 2026-10-08: one row per language the app's locales are
      // written in, all live in every content.
      for (final pair in [
        ('[注] How are you?', '注'),
        ('[註] How are you?', '註'),
        ('[nota] How are you?', 'nota'),
        ('[Nota] How are you?', 'Nota'), // as written; being one of the four is the rule's answer
      ]) {
        final tag = head(pair.$1);
        expect(tag, isNotNull, reason: pair.$1);
        expect(tag!.name, pair.$2);
        expect(isCommentSpelling(tag.name), isTrue, reason: pair.$1);
        expect(pair.$1.substring(tag.contentStart), 'How are you?');
      }
      expect(commentSpellings, hasLength(4));
    });

    test('the separator belongs to the tag', () {
      // Spaces, one optional colon either width, spaces (FR-001).
      for (final text in ['[注]: How are you?', '[注] : How are you?', '[注] ： How are you?', '[注]  How are you?']) {
        final tag = head(text)!;
        expect(text.substring(tag.contentStart), 'How are you?', reason: text);
        expect(tag.tagEnd <= tag.contentStart, isTrue, reason: text);
        expect(text.substring(tag.start, tag.tagEnd).trim(), anyOf('[注]', '[注]:', '[注]：', '[注] :', '[注] ：'),
            reason: text);
      }
      // A inner space is trimmed off the name, and that is still the tag.
      final spaced = head('[ 注 ] How are you?')!;
      expect(spaced.name, '注');
      expect('[ 注 ] How are you?'.substring(spaced.contentStart), 'How are you?');
    });

    test('the shapes the rule refuses stay the reader\'s own text', () {
      const refused = [
        '[comments] How are you?', // not a spelling
        '[comentario] How are you?', // the Spanish option not taken
        '[註解] How are you?', // the Traditional options not taken
        '[註釋] How are you?',
        '[note] How are you?',
        '[注释] How are you?',
        '[co mment] How are you?', // a space inside the name
        '[注 How are you?', // no closing delimiter
        '[] How are you?', // an empty name
        '［注］ How are you?', // full-width brackets (a Chinese IME's default)
        '[注］ How are you?', // mixed widths
        '[com\nment] How are you?', // a name that spans a line
        '[\n注] How are you?',
      ];
      for (final text in refused) {
        expect(head(text), isNull, reason: text);
        expect(commentsOf(text), isEmpty, reason: text);
      }
    });

    test('the four spellings are one set, recognised in every content', () {
      // Nothing in the rule reads the app's own language: the same text with
      // each spelling yields the same comment (FR-001, 2026-10-08).
      final contents = {
        for (final spelling in ['comment', '注', '註', 'nota'])
          spelling: 'Hola.\n\n[$spelling] How are you?',
      };
      final names = <String>{};
      for (final entry in contents.entries) {
        final comments = commentsOf(entry.value);
        expect(comments, hasLength(1), reason: entry.key);
        expect(comments.single.text, 'How are you?', reason: entry.key);
        expect(comments.single.ownerStart, 0, reason: entry.key);
        expect(comments.single.ownerEnd, 5, reason: entry.key);
        names.add(comments.single.tag.name);
      }
      expect(names, hasLength(4));
    });
  });

  group("a comment's content", () {
    test('runs from the tag to the paragraph\'s last non-whitespace character', () {
      const text = '[注] How are you?\nFine, thanks.   ';
      final comment = commentsOf(text).single;
      expect(comment.text, 'How are you?\nFine, thanks.');
      expect(comment.contentStart, text.indexOf('How'));
      expect(comment.contentEnd, text.indexOf('.') + 1);
      expect(comment.contentEnd, text.trimRight().length);
      expect(text.substring(comment.tag.start, comment.tag.tagEnd), '[注] ');
    });

    test('a tag alone on its line puts the content on the next line, and the line break stays painted', () {
      const text = '[注]\nHow are you?';
      final tag = head(text)!;
      expect(tag.tagEnd, 3, reason: 'the tag\'s own characters stop right after "]"');
      expect(tag.contentStart, 4, reason: 'the content begins on the paragraph\'s next line');
      final comment = commentsOf(text).single;
      expect(comment.text, 'How are you?');
      // The ellipsis is the tag's own characters plus the separator; the line
      // break after it is NOT part of it (research D3, data-model §3).
      expect(text.substring(tag.start, tag.tagEnd), '[注]');
      expect(text[tag.tagEnd], '\n');
    });

    test('a second colon is the comment\'s own', () {
      final comment = commentsOf('[注]: note: read this').single;
      expect(comment.text, 'note: read this');
    });

    test('an empty comment has no content', () {
      for (final text in ['[注]', '[注]   ', 'Hola.\n\n[註]']) {
        final comments = commentsOf(text);
        expect(comments, hasLength(1), reason: text);
        expect(comments.single.text, isEmpty, reason: text);
        expect(comments.single.contentStart, comments.single.contentEnd, reason: text);
      }
    });

    test('the tag\'s own characters are the only thing outside the content', () {
      const text = 'Hola.\n\n[注] Hi. [註] more.';
      final comment = commentsOf(text).single;
      // The first marker opens the comment; the second is the comment's own
      // text — the spec's own edge case: there is nothing to nest, and the four
      // spellings are one set.
      expect(comment.text, 'Hi. [註] more.');
      expect(comment.tag.name, '注');
      expect(comment.ownerEnd, text.indexOf('Hola.') + 'Hola.'.length);
    });
  });

  group('where the tag is read', () {
    test('mid-line: one comment, from the tag to the paragraph\'s end', () {
      const text = 'Hola. [注] Hi. Adiós.';
      final comments = commentsOf(text);
      expect(comments, hasLength(1));
      expect(comments.single.text, 'Hi. Adiós.');
      expect(comments.single.ownerStart, 0);
      expect(comments.single.ownerEnd, 5, reason: '"Hola." is the sentence the comment belongs to');
    });

    test('a marker-only paragraph is one comment with no content', () {
      final comments = commentsOf('[注]\n\nHola.');
      expect(comments, hasLength(1));
      expect(comments.single.text, isEmpty);
      expect(comments.single.ownerStart, isNull);
    });

    test('inside a role-tagged paragraph the comment is still its own span', () {
      const text = '{阿明} 你好。[注] Hello.';
      final comments = commentsOf(text);
      expect(comments, hasLength(1));
      expect(comments.single.text, 'Hello.');
      // The owner is the app's own sentence range of the text before the tag —
      // the same span the page's own sentence resolution answers for an offset
      // there, role prefix and all (SC-009). The turn's own, prefix-less span
      // is 014's business (`turnsOf`) and is what the read speaks.
      expect(comments.single.ownerEnd, text.indexOf('。') + 1);
      expect(text.substring(comments.single.ownerStart!, comments.single.ownerEnd!), '{阿明} 你好。');
    });

    test('every paragraph is scanned, in text order', () {
      const text = 'A. [注] one.\n\nB. [註] two.\n\nC.';
      final comments = commentsOf(text);
      expect(comments.map((c) => c.text), ['one.', 'two.']);
      expect(comments.first.tag.start < comments.last.tag.start, isTrue);
    });

    test('the text of a comment is never one of the sentences the read speaks', () {
      // FR-004 from the module's own side: no sentence range of the speakable
      // text overlaps a comment's span, and every owner ends at or before its
      // tag (the resolver's half is quickstart row 8's own test file).
      const text = 'Hola. [注] Hi. Adiós.\n\nBuenos días.\n\n[註] Buenos días means good morning.';
      final comments = commentsOf(text);
      expect(comments, hasLength(2));
      for (final comment in comments) {
        expect(comment.ownerEnd! <= comment.tag.start, isTrue, reason: comment.text);
        // The paragraph the comment sits in: nothing after its tag is a
        // sentence of that paragraph's speakable text.
        final paragraph = paragraphRanges(text).firstWhere((p) => p.start <= comment.tag.start && comment.tag.start < p.end);
        final spoken = text.substring(paragraph.start, comment.tag.start);
        for (final sentence in sentenceRanges(spoken)) {
          expect(sentence.end <= comment.tag.start, isTrue);
        }
      }
    });
  });

  group('the owner', () {
    test('is the last sentence that ended before the tag', () {
      const text = 'Hola. Adiós.\n\n[注] Bye.';
      final comment = commentsOf(text).single;
      expect(text.substring(comment.ownerStart!, comment.ownerEnd!), 'Adiós.');
      expect(comment.ownerEnd, text.indexOf('Adiós.') + 'Adiós.'.length);
    });

    test('is null when no sentence precedes it anywhere', () {
      final comment = commentsOf('[注] Hello.\n\nHola.').single;
      expect(comment.ownerStart, isNull);
      expect(comment.ownerEnd, isNull);
    });

    test('crosses paragraph boundaries', () {
      const text = 'Hola.\n\n[注] one.\n\nBuenos días.\n\n[註] two.';
      final comments = commentsOf(text);
      expect(comments, hasLength(2));
      expect(text.substring(comments[0].ownerStart!, comments[0].ownerEnd!), 'Hola.');
      expect(text.substring(comments[1].ownerStart!, comments[1].ownerEnd!), 'Buenos días.');
    });

    test('two comments in a row belong to the same sentence', () {
      const text = 'Hola.\n\n[注] one.\n\n[註] two.';
      final comments = commentsOf(text);
      expect(comments, hasLength(2));
      for (final comment in comments) {
        expect(text.substring(comment.ownerStart!, comment.ownerEnd!), 'Hola.');
      }
    });

    test('an unterminated run before the tag is the sentence (the app has no other unit)', () {
      const text = 'Hola [注] Hi.';
      final comment = commentsOf(text).single;
      // The segmenter's own tail range: a run with no delimiter is one range,
      // trailing space included (`lib/segmenter.dart:65-67`), which is what a
      // read of that text speaks today too.
      expect(text.substring(comment.ownerStart!, comment.ownerEnd!), 'Hola ');
    });

    test('a paragraph with no tag at all yields no comment', () {
      for (final text in ['Hola. Adiós.', '{阿明} 你好。', 'A [ bracket and no tag.', '']) {
        expect(commentsOf(text), isEmpty, reason: text);
      }
    });
  });

  group('the display and its mappings', () {
    test('the tag\'s own characters are not painted, and nothing else moves', () {
      const content = 'Hola.\n\n[注] How are you?';
      final display = displayOf(content);
      expect(display.text, 'Hola.\n\nHow are you?');
      expect(display.text.length, content.length - '[注] '.length);
      // FR-005 as a property of the painted string: no bracket, no spelling, no
      // separator character survives it.
      for (final spelling in commentSpellings) {
        expect(display.text.contains(spelling), isFalse, reason: spelling);
      }
      expect(display.text.contains('['), isFalse);
      expect(display.text.contains(']'), isFalse);
      // The reader's own layout is untouched: the comment's words are where
      // they were written, its line breaks included.
      expect(display.text.endsWith('How are you?'), isTrue);
    });

    test('a tag alone on its line leaves the line break painted', () {
      const content = '[注]\nHow are you?';
      final display = displayOf(content);
      // The line break after the tag is NOT one of the tag's characters
      // (research D3): the display keeps it, so the content does not move up.
      expect(display.text, '\nHow are you?');
    });

    test('every offset outside an elided span round-trips', () {
      const content = 'Hola. [注] Hi. [註] more.\n\nBuenos días.';
      final display = displayOf(content);
      final tags = displayOf(content).comments.map((c) => c.tag).toList();
      bool elided(int offset) => tags.any((t) => offset >= t.start && offset < t.tagEnd);
      for (var offset = 0; offset <= content.length; offset++) {
        if (elided(offset)) continue;
        expect(display.toContent(display.toDisplay(offset)), offset,
            reason: 'content offset $offset');
      }
      for (var offset = 0; offset <= display.text.length; offset++) {
        expect(display.toDisplay(display.toContent(offset)), offset,
            reason: 'display offset $offset');
      }
    });

    test('an offset inside a tag answers the character after it', () {
      const content = 'Hola.\n\n[注] How are you?';
      final display = displayOf(content);
      final tag = display.comments.single.tag;
      // The elided characters are not painted, so the display position they
      // occupied is the position of the character that follows them — which is
      // inside the comment's own span, so a tap at that seam answers the
      // comment (data-model §3, plan ripple 11).
      expect(display.toDisplay(tag.start + 1), display.toDisplay(tag.start));
      expect(display.toContent(display.toDisplay(tag.start)), tag.tagEnd);
      expect(display.toContent(display.toDisplay(tag.start)),
          display.comments.single.contentStart);
    });

    test('a text with no tag paints itself, and both mappings are the identity', () {
      for (final content in ['Hola. Adiós.', '{阿明} 你好。', '［注］ full width', '']) {
        final display = displayOf(content);
        expect(display.text, content, reason: content);
        expect(display.comments, isEmpty, reason: content);
        for (var offset = 0; offset <= content.length; offset++) {
          expect(display.toContent(offset), offset, reason: content);
          expect(display.toDisplay(offset), offset, reason: content);
        }
      }
    });
  });

  group('the turn scan with comments', () {
    test('a turn\'s own content stops at a comment\'s tag', () {
      const text = '{阿明} 你好。[注] Hello.';
      final turns = turnsOf(text, comments: commentsOf(text));
      expect(turns, hasLength(1));
      expect(turns.single.role, '阿明');
      expect(turns.single.text, '你好。');
      // The comment's own characters are NOT part of the turn's span.
      expect(turns.single.contentEnd, text.indexOf('['));
    });

    test('a paragraph that is nothing but a comment is not a turn', () {
      const text = '{阿明} 你好。\n\n[注] Hello.';
      final withComments = turnsOf(text, comments: commentsOf(text));
      expect(withComments, hasLength(1));
      expect(withComments.single.role, '阿明');
      // Without the comment list the same text is today's scan: the comment's
      // own paragraph is a narration turn (FR-011 is the new rule).
      final without = turnsOf(text);
      expect(without, hasLength(2));
      expect(without.last.role, isNull);
      expect(without.last.text, '[注] Hello.');
    });

    test('a text with no comment is today\'s scan', () {
      const text = '{阿明} 你好。\n\n旁白一句。';
      final turns = turnsOf(text, comments: commentsOf(text));
      final plain = turnsOf(text);
      expect(turns.length, plain.length);
      for (var i = 0; i < turns.length; i++) {
        expect(turns[i].role, plain[i].role);
        expect(turns[i].contentStart, plain[i].contentStart);
        expect(turns[i].contentEnd, plain[i].contentEnd);
        expect(turns[i].text, plain[i].text);
      }
    });
  });

  group('Format knows {}, and nothing else (FR-017)', () {
    void sameComments(String text) {
      final out = formatForDialogue(text);
      final marker = RegExp(r'\[[^\]]*\]');
      expect(marker.allMatches(out).map((m) => m.group(0)).toList(),
          marker.allMatches(text).map((m) => m.group(0)).toList(),
          reason: 'every comment marker survives, byte for byte, in order: $text');
      // The only character Format adds is a line break (014's own rule), so the
      // non-newline characters are identical — no comment character moves.
      expect(out.replaceAll('\n', ''), text.replaceAll('\n', ''), reason: text);
    }

    test('an inline comment beside an inline role tag is left where it is', () {
      sameComments('A. [注] Hi. {May} Hello.');
    });

    test('a comment at a paragraph head stays a comment', () {
      sameComments('[注] Hello.\n\n{May} Hi.');
    });

    test('a comment whose content holds a brace pair keeps its own markers', () {
      // Format is for `{}`: the pair inside the comment gains a blank line, and
      // the comment's own `[注]` is not so much as reordered.
      sameComments('[注] the {laughs} is inside the comment.');
    });

    test('a text with a comment and nothing to format comes back identical', () {
      for (final text in ['[注] Hello.', 'Hola. [註] Bye.', '[comment] x', '[nota]: y']) {
        expect(formatForDialogue(text), text, reason: text);
      }
    });
  });

  group("a step's own end (016)", () {
    // 016 FR-005: one step is one sentence **plus that sentence's comment**
    // when the comments are being read. A comment's characters begin after its
    // sentence's last one (015), and a read speaks a comment only when its own
    // range covers the comment's span (`lib/speech_resolver.dart:190`), so a
    // step scoped to the sentence alone would drop the comment — silently, and
    // on exactly the texts that carry one.
    TextSegment at(String text, String sentence) {
      final index = text.indexOf(sentence);
      return TextSegment(index, index + sentence.length, SegmentUnit.sentence);
    }

    test('a sentence with no comment is its own step, either way', () {
      const text = 'Hola. Adiós.';
      final first = at(text, 'Hola.');
      expect(stepEnd(text, false, first), 5);
      expect(stepEnd(text, true, first), 5);
    });

    test('an inline comment extends its owner, and only while it is read', () {
      const text = 'Hola. [注] Hi.';
      final first = at(text, 'Hola.');
      // Read: the step covers the comment's own span, so the resolution speaks
      // it after its sentence.
      expect(stepEnd(text, true, first), text.length);
      // Not read: the comment's words are not read at all, and the step is the
      // sentence.
      expect(stepEnd(text, false, first), 5);
    });

    test('a comment in its own paragraph still belongs to the sentence above', () {
      const text = 'Hola.\n\n[注] How are you?';
      final first = at(text, 'Hola.');
      expect(stepEnd(text, true, first), text.length);
      expect(stepEnd(text, false, first), 5);
    });

    test('a comment after a later sentence of the same paragraph leaves the earlier step alone', () {
      const text = 'Hola. Adiós. [注] Hi.';
      expect(stepEnd(text, true, at(text, 'Hola.')), 5);
      expect(stepEnd(text, true, at(text, 'Adiós.')), text.length);
    });

    test('a sentence in a later paragraph is itself', () {
      const text = 'Hola. [注] Hi.\n\nAdiós.';
      expect(stepEnd(text, true, at(text, 'Adiós.')), text.length);
    });

    test('every sentence of a text with no comment answers its own end', () {
      const text = 'Hola. Adiós.\n\nBuenos días.';
      for (final range in sentenceRanges(text)) {
        expect(stepEnd(text, true, range), range.end, reason: '$range');
      }
    });

    // The step CANDIDATES (FR-001/FR-006) are the app's own sentence ranges
    // minus the ones a comment's characters occupy: a comment's span is no
    // sentence's span (015 FR-004), and its words are never read as a sentence
    // of their own — whether or not the comments are being read.
    test('a text with no comment has today\'s sentences as its steps', () {
      const text = 'Hola. Adiós.\n\nBuenos días.';
      expect(
        stepRanges(text).map((r) => text.substring(r.start, r.end)).toList(),
        ['Hola.', 'Adiós.', 'Buenos días.'],
      );
    });

    test('an inline comment is no step of its own', () {
      const text = 'Hola. [注] Hi. Adiós.';
      final steps = stepRanges(text);
      expect(steps.length, 1);
      expect(text.substring(steps.first.start, steps.first.end), 'Hola.');
    });

    test('a comment at the text head is no step, so the first step is the sentence after it', () {
      const text = '[注] Hello.\n\nReal sentence.';
      final steps = stepRanges(text);
      expect(steps.length, 1);
      expect(text.substring(steps.first.start, steps.first.end), 'Real sentence.');
    });

    test("the next step starts after the step's own end, never inside the comment", () {
      const text = 'Hola.\n\n[注] How are you?\n\nAdiós.';
      final steps = stepRanges(text);
      expect(steps.length, 2);
      expect(text.substring(steps[1].start, steps[1].end), 'Adiós.');
      expect(steps[1].start, greaterThanOrEqualTo(stepEnd(text, true, steps.first)));
      expect(steps[1].start, greaterThanOrEqualTo(stepEnd(text, false, steps.first)));
    });
  });

  group('019 — the display elides a mark as it elides a tag (FR-003)', () {
    test('the marker is painted nowhere and the words after it are', () {
      final display = displayOf('# Basic Spanish 1\n\nHola.');
      expect(display.text, 'Basic Spanish 1\n\nHola.');
      expect(display.heads, hasLength(1));
      expect(display.headSpans(), [(0, 15, 1)]);
    });

    test('each mark is its own span, at its own level', () {
      final display = displayOf('## Greetings\n\n# Basic Spanish 1');
      expect(display.text, 'Greetings\n\nBasic Spanish 1');
      expect(display.headSpans(), [(0, 9, 2), (11, 26, 1)]);
    });

    test('a text with no tag and no mark is its own display, mapping included', () {
      final display = displayOf('Hola. Adiós.');
      expect(display.text, 'Hola. Adiós.');
      expect(display.heads, isEmpty);
      expect(display.headSpans(), isEmpty);
      expect(display.toContent(3), 3);
      expect(display.toDisplay(3), 3);
    });

    test('every offset outside an elided span maps back to itself (INV-2)', () {
      const text = '# Title\n\n[注] Hola.\n\n## Sub';
      final display = displayOf(text);
      expect(display.text, 'Title\n\nHola.\n\nSub');
      final elided = <int>{
        for (final head in display.heads)
          for (var i = head.start; i < head.markEnd; i++) i,
        for (final comment in display.comments)
          for (var i = comment.tag.start; i < comment.tag.tagEnd; i++) i,
      };
      for (var offset = 0; offset < text.length; offset++) {
        if (elided.contains(offset)) continue;
        expect(display.toContent(display.toDisplay(offset)), offset,
            reason: 'offset $offset');
      }
    });

    test('a comment on a later line does not cut the marked line', () {
      const text = '# Title\n[注] Hola.';
      final display = displayOf(text);
      expect(display.text, 'Title\nHola.');
      expect(display.headSpans(), [(0, 5, 1)]);
    });

    test("a marked line stops where the comment's own characters begin", () {
      const text = '# Title [注] Hola';
      final display = displayOf(text);
      expect(display.text, 'Title Hola');
      expect(display.headSpans(), [(0, 6, 1)]);
    });
  });
}
