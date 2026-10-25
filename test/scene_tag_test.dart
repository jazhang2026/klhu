/// 024 — the scene tag's own rule, read off the reader's text alone
/// (quickstart rows 1, 2, 4, 5 and 9, and the near-miss row).
///
/// What a tag is, what each scene owns, what the text looks like with the tag
/// lines masked or elided, and every shape the rule refuses so the reader's own
/// lines stay theirs. The cases are `spec.md`'s FR-001–FR-007, FR-014–FR-017 and
/// the quickstart's own fixture, never values read off the implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/scene_tag.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/video_timeline.dart';

import 'content_fixtures.dart';

/// The quickstart's own six-line fixture — the driver's
/// `klhu_scene_fixture.txt`, three tags, two spellings, a heading on two of
/// them, a preamble, and the five sentences the scenes own.
const _fixture = '她走进院子。\n'
    '\n'
    '[场景] 1：青石观蚁\n'
    '他推门进来。屋里很暗。\n'
    '\n'
    '[scene]\n'
    '「有人吗？」她说。门开了。\n'
    '\n'
    '[场景] 2：\n'
    '脚步声远了。\n';

/// The same content with every tag's line **deleted** — the twin every elision
/// and every silence is measured against (FR-004, FR-005).
String _deleted(String text) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final tag in sceneTagsOf(text)) {
    buffer.write(text.substring(cursor, tag.lineStart));
    cursor = tag.lineEnd < text.length ? tag.lineEnd + 1 : text.length;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// The texts of [ranges], trimmed — what a read or a step list actually says.
List<String> _texts(List<TextSegment> ranges, String text) =>
    [for (final range in ranges) text.substring(range.start, range.end).trim()];

/// Where [sentence] begins to say something in [masked]: its own first
/// character, the leading whitespace of a paragraph's first sentence skipped —
/// the offset the scene's own rule reads.
int _textStart(String masked, TextSegment sentence) {
  var at = sentence.start;
  while (at < sentence.end && ' \t\n\r'.contains(masked[at])) {
    at++;
  }
  return at;
}

/// The sentence texts [scene] owns, read through the scene's own rule over the
/// text the read speaks (the masked one, so a tag line is no sentence).
List<String> _owned(String text, Scene scene) {
  final masked = sceneMasked(text);
  return _texts(
    [
      for (final sentence in sentenceRanges(masked))
        if (scene.owns(_textStart(masked, sentence))) sentence,
    ],
    masked,
  );
}

void main() {
  group("the tag line's grammar", () {
    test('the four spellings, at a line\'s head, in whatever case', () {
      for (final line in const [
        '[scene]',
        '[SCENE]',
        '[Scene]',
        '[场景]',
        '[場景]',
        '[escena]',
        '[ESCENA]',
      ]) {
        final tags = sceneTagsOf(line);
        expect(tags, hasLength(1), reason: line);
        final tag = tags.single;
        expect(line.substring(tag.start, tag.markEnd), line, reason: line);
        expect(tag.lineStart, 0, reason: line);
        expect(tag.headingStart, line.length, reason: line);
        expect(tag.lineEnd, line.length, reason: line);
      }
    });

    test('the rest of the line is the heading', () {
      const scene = '[场景] 1：青石观蚁';
      final tag = sceneTagsOf(scene).single;
      expect(scene.substring(tag.start, tag.markEnd), '[场景]');
      expect(tag.headingStart, 5);
      expect(scene.substring(tag.headingStart, tag.lineEnd), '1：青石观蚁');

      const es = '[escena] 3：夜';
      final other = sceneTagsOf(es).single;
      expect(es.substring(other.headingStart, other.lineEnd), '3：夜');
    });

    test('a heading may carry delimiters — the line still ends where it does', () {
      const text = '[scene] 第一场。他说。\nmore';
      final tag = sceneTagsOf(text).single;
      expect(text.substring(tag.headingStart, tag.lineEnd), '第一场。他说。');
    });

    test('leading spaces belong to the line, the tag starts after them', () {
      const text = '  \t[scene] 标题';
      final tag = sceneTagsOf(text).single;
      expect(tag.start, 3);
      expect(tag.lineStart, 0);
      expect(text.substring(tag.lineStart, tag.lineEnd), '  \t[scene] 标题');
      expect(text.substring(tag.start, tag.markEnd), '[scene]');
      expect(text.substring(tag.headingStart, tag.lineEnd), '标题');
    });

    test('trailing spaces, tabs and the CR of a CRLF line are not the line', () {
      expect(sceneTagsOf('[scene]  \t  \nmore').single.lineEnd, 7);
      expect(sceneTagsOf('[scene]\r\nmore').single.lineEnd, 7);
      // And the span every surface uses still takes the break with it.
      expect(sceneTagsOf('[scene]\r\nmore').single.spanIn('[scene]\r\nmore'), (0, 8));
    });

    test('every shape the rule refuses is the reader\'s own text', () {
      for (final text in const [
        '［场景］',
        '［場景］',
        '[scenes]',
        '[escenas]',
        '他推门进来。[scene]',
        'text [scene]',
        '# [scene]',
        '[scene',
        '[]',
        '[comment]',
        '[注]',
        '[nota]',
      ]) {
        expect(sceneTagsOf(text), isEmpty, reason: text);
      }
      // A tag one line down does not close the line above it.
      expect(sceneTagsOf('[escena\n标题]'), isEmpty);
    });

    test('the twin content respells the fixture\'s three tags and owns the same sentences', () {
      final twin = _fixture
          .replaceFirst('[场景] 1：青石观蚁', '[場景] 1：青石观蚁')
          .replaceFirst('[scene]', '[ESCENA]')
          .replaceFirst('[场景] 2：', '[escena] 2：');
      expect(twin, isNot(_fixture));

      final scenes = scenesOf(_fixture);
      final twinScenes = scenesOf(twin);
      expect(twinScenes, hasLength(scenes.length));
      for (var i = 0; i < scenes.length; i++) {
        expect(twinScenes[i].sentenceCount, scenes[i].sentenceCount,
            reason: 'scene ${i + 1}');
        expect(_owned(twin, twinScenes[i]), _owned(_fixture, scenes[i]),
            reason: 'scene ${i + 1}');
      }
      // Each spelling is proved INSIDE a content, not only as a bare line.
      expect([for (final scene in twinScenes) scene.tag.spelling],
          ['場景', 'ESCENA', 'escena']);
    });
  });

  group('what a scene owns', () {
    test('the preamble belongs to no scene, and each scene owns the sentences after its line', () {
      final scenes = scenesOf(_fixture);
      expect(scenes, hasLength(3));
      expect([for (final scene in scenes) scene.ordinal], [0, 1, 2]);
      expect([for (final scene in scenes) scene.sentenceCount], [2, 3, 1]);
      expect(_owned(_fixture, scenes[0]), ['他推门进来。', '屋里很暗。']);
      // The segmenter's own split of the corner-quote line: `？` ends the
      // sentence and `」` is not one of its closers, so the second scene owns
      // three of the app's sentences for its two sentences of the reader's.
      expect(_owned(_fixture, scenes[1]), ['「有人吗？', '」她说。', '门开了。']);
      expect(_owned(_fixture, scenes[2]), ['脚步声远了。']);

      final masked = sceneMasked(_fixture);
      final sentences = sentenceRanges(masked);
      expect(_texts(sentences, masked).first, '她走进院子。');
      expect(sentences.any((s) => scenes.any((scene) => scene.owns(_textStart(masked, s)))),
          isTrue);
      expect(scenes.any((scene) => scene.owns(_textStart(masked, sentences.first))),
          isFalse);
    });

    test('a tag line\'s heading is owned by nobody, and is in no sentence', () {
      final masked = sceneMasked(_fixture);
      final sentences = _texts(sentenceRanges(masked), masked);
      expect(sentences, hasLength(7));
      for (final heading in const ['青石观蚁', '1：', '2：']) {
        expect(sentences.any((sentence) => sentence.contains(heading)), isFalse,
            reason: heading);
      }
    });

    test('an empty scene owns nothing: a tag last in the text, two tags back to back', () {
      final lastTag = scenesOf('[scene]\n他推门进来。\n\n[场景] 2：');
      expect([for (final scene in lastTag) scene.sentenceCount], [1, 0]);

      final backToBack = scenesOf('[scene]\n[scene]\n他推门进来。');
      expect([for (final scene in backToBack) scene.sentenceCount], [0, 1]);
      expect(_owned('[scene]\n[scene]\n他推门进来。', backToBack[0]), isEmpty);
    });
  });

  group('the mask keeps every offset', () {
    test('the masked text is as long as the text and holds only spaces where a tag stood', () {
      final masked = sceneMasked(_fixture);
      expect(masked.length, _fixture.length);
      final spans = [for (final tag in sceneTagsOf(_fixture)) tag.spanIn(_fixture)];
      for (final (from, to) in spans) {
        expect(masked.substring(from, to).trim(), isEmpty, reason: '$from..$to');
      }
      // Outside every tag's span the two strings are the same character, one
      // offset at a time — data-model I1, which is what lets every sentence keep
      // the content's own span.
      bool inSpan(int offset) =>
          spans.any((span) => offset >= span.$1 && offset < span.$2);
      for (var offset = 0; offset < _fixture.length; offset++) {
        if (inSpan(offset)) continue;
        expect(masked[offset], _fixture[offset], reason: 'offset $offset');
      }
    });

    test('a tag line masks to spaces but keeps the break that ends it', () {
      // A scene tag standing as its own paragraph — the shape the reader's own
      // Format press makes. Masking the break with it would swallow the blank
      // line under the tag, and 014's turns are paragraphs: the `{旁白}：` line
      // under the tag would stop being a paragraph's head and be read and
      // painted as text. The mask may silence the tag's line, not the boundary.
      const text = '[场景] 1：青石观蚁\n\n{旁白}：今天天气很好。\n\n{阿明}：你好。';
      final masked = sceneMasked(text);
      expect(masked.length, text.length);
      final tag = sceneTagsOf(text).single;
      final (from, to) = tag.spanIn(text);
      expect(masked.substring(from, to - 1).trim(), isEmpty,
          reason: "the tag's own characters and its heading are silent");
      expect(masked[to - 1], '\n', reason: 'the break is not the tag line');
      // The paragraphs the read speaks are the deleted twin's own — one turn per
      // reader's paragraph, the tags' lines producing none.
      final deleted = _deleted(text);
      expect([for (final para in paragraphRanges(masked)) _texts([para], masked).single],
          [for (final para in paragraphRanges(deleted)) _texts([para], deleted).single]);
    });

    test('no delimiter survives inside a tag line', () {
      const text = '[event] 第一场。他说。\n';
      // A near miss for the rule (so the mask is the text) and the real case.
      expect(sceneMasked(text), text);
      const scene = '[scene] 第一场。他说。\n他走了。';
      final masked = sceneMasked(scene);
      final tag = sceneTagsOf(scene).single;
      final (from, to) = tag.spanIn(scene);
      for (final delimiter in const ['。', '：', '.', '！', '？']) {
        expect(masked.substring(from, to).contains(delimiter), isFalse,
            reason: delimiter);
      }
      expect(_texts(sentenceRanges(masked), masked), ['他走了。']);
    });

    test('a tag-free text\'s mask is the text itself', () {
      for (final text in [kSampleEnText, kSampleZhText, kSampleEsText]) {
        expect(identical(sceneMasked(text), text), isTrue);
      }
    });
  });

  group('the painted string', () {
    test('the page paints the content with the tag lines deleted, byte for byte', () {
      final shown = displayOf(_fixture).text;
      expect(shown, _deleted(_fixture));
      expect(shown, '她走进院子。\n\n他推门进来。屋里很暗。\n\n「有人吗？」她说。门开了。\n\n脚步声远了。\n');
      for (final gone in const ['[', '场景', '場景', 'scene', 'escena', '青石观蚁', '1：', '2：']) {
        expect(shown.contains(gone), isFalse, reason: gone);
      }
      expect(shown.contains('\n\n\n'), isFalse);
    });

    test('a comment and a mark keep their own elisions beside the scene\'s', () {
      const text = '# 标题\n[scene] 1：第一场\n他推门进来。[注] 这是注释。\n';
      final display = displayOf(text);
      expect(display.heads, hasLength(1));
      expect(display.comments, hasLength(1));
      expect(display.text, '标题\n他推门进来。这是注释。\n');
      expect(display.sceneTags, hasLength(1));
    });

    test('a comment inside a tag line is the tag line\'s own text', () {
      const text = '[scene] 1：第一场 [注] 注释\n他推门进来。\n';
      final display = displayOf(text);
      // The tag line wins (research R1's pinned reading): the comment's own
      // marker goes with the line it stands in, and nothing is elided twice.
      expect(display.text, '他推门进来。\n');
      expect(display.comments, hasLength(1));
      expect(display.sceneTags, hasLength(1));
    });

    test('a tag-free content\'s display is the content itself', () {
      for (final text in [kSampleEnText, kSampleZhText, kSampleEsText]) {
        expect(displayOf(text).text, text);
        expect(displayOf(text).sceneTags, isEmpty);
        expect(displayOf(text).scenes, isEmpty);
      }
    });
  });

  group('not a sentence, not a step, not a slot', () {
    test('the sentences, the steps, the turns and the video slots are the deleted twin\'s', () async {
      final masked = sceneMasked(_fixture);
      final deleted = _deleted(_fixture);

      expect(_texts(sentenceRanges(masked), masked),
          _texts(sentenceRanges(deleted), deleted));
      expect(_texts(stepRanges(masked), masked), _texts(stepRanges(deleted), deleted));
      expect(sentenceRanges(masked), hasLength(7));

      expect([for (final turn in turnsOf(masked)) turn.text.trim()],
          [for (final turn in turnsOf(deleted)) turn.text.trim()]);

      final spoken = await videoSentencesFrom(
          content: masked, position: 0, loadVoice: (_) async => null);
      final twin = await videoSentencesFrom(
          content: deleted, position: 0, loadVoice: (_) async => null);
      expect([for (final sentence in spoken) sentence.text.trim()],
          [for (final sentence in twin) sentence.text.trim()]);
      expect(spoken, hasLength(7));
      // Both directions: the twin is not merely longer than a silent list.
      expect([for (final sentence in twin) sentence.text.trim()],
          [for (final sentence in spoken) sentence.text.trim()]);
    });

    test('the heading\'s own delimiter starts no sentence and swallows no text', () {
      const text = '[场景] 第一场。他说。\n屋里很暗。';
      final masked = sceneMasked(text);
      final deleted = _deleted(text);
      expect(masked.length, text.length);
      expect(_texts(sentenceRanges(masked), masked), ['屋里很暗。']);
      expect(_texts(sentenceRanges(deleted), deleted), ['屋里很暗。']);
      expect(_texts(stepRanges(masked), masked), ['屋里很暗。']);
    });
  });

  group('a content without a scene tag', () {
    test('the mask and the display are the text itself, and no scene is found', () {
      for (final text in [kSampleEnText, kSampleZhText, kSampleEsText, 'One. Two.\n\nThree.']) {
        expect(sceneTagsOf(text), isEmpty);
        expect(scenesOf(text), isEmpty);
        expect(sceneMasked(text), text);
        expect(displayOf(text).text, text);
      }
    });

    test('the four counts are the ones the app has today', () {
      const text = kSampleEnText;
      expect(_texts(sentenceRanges(text), text), hasLength(8));
      expect(_texts(stepRanges(text), text), hasLength(8));
      expect(_texts(sentenceRanges(sceneMasked(text)), sceneMasked(text)),
          hasLength(8));
      // The display is the content, so every display offset IS a content offset
      // — the identity mapping the page relies on for a tag-free text.
      final display = displayOf(text);
      for (var offset = 0; offset <= text.length; offset++) {
        expect(display.toDisplay(offset), offset);
        expect(display.toContent(offset), offset);
      }
    });
  });

  group('beside the comment and the mark', () {
    test('a tag inside a comment\'s span is not a scene', () {
      const text = '[注] 这段话里写着 [scene] 1：青石观蚁\n他推门进来。\n';
      final comments = commentsOf(text);
      expect(comments, hasLength(1));
      final inside = [for (final comment in comments) (comment.tag.start, comment.contentEnd)];
      expect(sceneTagsOf(text, inside: inside), isEmpty);
      expect(scenesOf(text, inside: inside), isEmpty);
      // The page agrees: the reader's own characters stay painted.
      expect(displayOf(text).text, contains('[scene] 1：青石观蚁'));
    });

    test('a marked line opens no scene, and both elisions ride one list', () {
      const text = '## [scene] hi\n他推门进来。\n';
      final inside = [for (final head in displayOf(text).heads) (head.start, head.lineEnd)];
      expect(sceneTagsOf(text, inside: inside), isEmpty);
      final display = displayOf(text);
      expect(display.scenes, isEmpty);
      expect(display.text, '[scene] hi\n他推门进来。\n');
    });

    test('a comment and a scene in the same paragraph keep to their own spans', () {
      const text = '[scene] 1：第一场 [注] 注释\n他推门进来。[注] 又一条\n';
      final display = displayOf(text);
      expect(display.sceneTags, hasLength(1));
      // 015's rule is one comment per paragraph, and the paragraph's first
      // marker is the one inside the tag line.
      expect(display.comments, hasLength(1));
      expect(display.text, isNot(contains('[scene]')));
      // The paragraph's one comment starts inside the tag line, so its marker
      // goes with the line and the second marker is that comment's own text.
      expect(display.text, '他推门进来。[注] 又一条\n');
    });

    test('the round trip holds for every offset outside an elided span', () {
      for (final text in const [
        _fixture,
        '# 标题\n[scene] 1：第一场\n他推门进来。[注] 这是注释。\n',
        '[scene] 1：第一场 [注] 注释\n他推门进来。\n',
      ]) {
        final display = displayOf(text);
        // The spans this display removes, derived here so the test knows which
        // offsets have no painted position of their own (data-model I11).
        final elided = <int>{
          for (final comment in display.comments)
            for (var i = comment.tag.start; i < comment.tag.tagEnd; i++) i,
          for (final head in display.heads)
            for (var i = head.start; i < head.markEnd; i++) i,
          for (final tag in display.sceneTags)
            for (var i = tag.spanIn(text).$1; i < tag.spanIn(text).$2; i++) i,
        };
        for (var offset = 0; offset <= text.length; offset++) {
          if (elided.contains(offset)) continue;
          expect(display.toContent(display.toDisplay(offset)), offset,
              reason: 'offset $offset of ${text.length}');
        }
      }
    });
  });

  group('a near miss stays the reader\'s text', () {
    test('every refused shape paints, reads and counts as it is today', () {
      const text = '［场景］ 1：青石观蚁\n［場景］\n[scenes]\n[escenas]\n'
          '他推门进来。[scene] 标题\n';
      expect(sceneTagsOf(text), isEmpty);
      expect(scenesOf(text), isEmpty);
      expect(sceneMasked(text), text);
      expect(displayOf(text).text, text);
      expect(_texts(sentenceRanges(text), text),
          ['［场景］ 1：青石观蚁\n［場景］\n[scenes]\n[escenas]\n他推门进来。', '[scene] 标题']);
      expect(_texts(stepRanges(text), text), _texts(sentenceRanges(text), text));
    });
  });
}
