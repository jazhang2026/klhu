/// 024 US3 — the i-th picture takes the i-th scene, inside 020's own rules
/// (quickstart row 7).
///
/// The N×M grid is the reader's question in every direction: more pictures than
/// scenes, more scenes than pictures, none of either, and an empty scene in the
/// middle. Each cell is compared, run for run, with the assignment the reader
/// would have made by hand — and then read back through 020's own resolver, so a
/// run the rules would refuse cannot pass as the answer (FR-010, FR-011).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/scene_tag.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';

/// The quickstart's fixture: three scenes over five sentences, plus the preamble
/// no scene owns.
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

/// The reader's picks, in the order chosen: only the **names** matter to the
/// rule, so the paths are the picker's own shape and nothing more.
List<HeldPicture> _picks(int count) => [
      for (var i = 0; i < count; i++)
        HeldPicture(name: 'p$i.png', path: '/picks_1/pick_${i}_p$i.png'),
    ];

void main() {
  late List<VideoSentence> sentences;
  late List<Scene> scenes;

  setUp(() async {
    sentences = await videoSentencesFrom(
      content: _fixture,
      position: 0,
      loadVoice: (language) async => null,
    );
    scenes = scenesOf(_fixture);
    // The fixture is the test's own premise: seven of the app's sentences (the
    // `？」` split is the segmenter's, not this feature's), the preamble owned by
    // nobody, and three scenes over the five after it.
    expect(sentences, hasLength(7), reason: 'fixture drift');
    expect(scenes, hasLength(3), reason: 'fixture drift');
    expect([for (final scene in scenes) scene.sentenceCount], [2, 3, 1]);
  });

  group('the scene pairing', () {
    test('the N×M grid: min(N, M) runs written, each one the reader\'s own order', () {
      // What the scenes own, by sentence index — the hand-made answer every cell
      // is compared against.
      final owned = <List<int>>[
        for (final scene in scenes)
          [
            for (var i = 0; i < sentences.length; i++)
              if (scene.owns(sentences[i].start)) i,
          ],
      ];
      expect(owned, [
        [1, 2],
        [3, 4, 5],
        [6],
      ], reason: 'the preamble (0) is in no scene');

      for (final (pictures, sceneCount) in const [
        (0, 1),
        (1, 0),
        (1, 1),
        (2, 3),
        (3, 2),
        (5, 3),
        (3, 5),
      ]) {
        final picked = _picks(pictures);
        final answer = assignScenesToPictures(
          scenes: scenes.take(sceneCount).toList(),
          sentences: sentences,
          pictures: picked,
        );
        final expected = sceneCount == 0 || pictures == 0 || sceneCount == 0
            ? 0
            : (pictures < sceneCount ? pictures : sceneCount);
        final reason = '$pictures pictures, $sceneCount scenes';

        if (expected == 0) {
          expect(answer, isNull, reason: reason);
          continue;
        }
        expect(answer, isNotNull, reason: reason);
        expect(answer!, hasLength(pictures), reason: '$reason: one run per picture');

        // The i-th picture takes the i-th scene's sentences, in the scenes' own
        // order; the pictures past min(N, M) are written empty.
        for (var i = 0; i < pictures; i++) {
          expect(answer[i].name, 'p$i.png', reason: '$reason: run $i');
          expect(indicesOfSpans(answer[i].spans, sentences),
              i < expected ? owned[i] : <int>[],
              reason: '$reason: run $i');
        }

        // The runs ascend across the pictures, never repeat an index, and each
        // one is contiguous — 020's rules, read off the answer itself.
        var previous = -1;
        for (final run in answer) {
          final held = indicesOfSpans(run.spans, sentences);
          for (var k = 0; k < held.length; k++) {
            expect(held[k], greaterThan(previous), reason: reason);
            if (k > 0) {
              expect(held[k], held[k - 1] + 1,
                  reason: '$reason: a run holds contiguous sentences');
            }
            previous = held[k];
          }
        }

        // And 020's own resolver accepts it as an ordinary assignment: nothing
        // goes stale, and every sentence the answer gave a picture is still that
        // picture's. The resolver's own fallback (`assignmentsFor` rule 3) hands
        // the sentences nobody assigned — the preamble, the tail — to the
        // nearest picture, so the effective list is a superset of the run, never
        // a different one (FR-006, FR-011).
        final resolved = assignmentsFor(
          sentences: sentences,
          pictures: picked,
          runs: [for (final run in answer) if (!run.isEmpty) run],
        );
        expect(resolved.stale, isEmpty, reason: reason);
        for (var i = 0; i < pictures; i++) {
          expect(resolved.effective[i].name, 'p$i.png', reason: reason);
          expect(resolved.effective[i].sentences,
              containsAll(indicesOfSpans(answer[i].spans, sentences)),
              reason: '$reason: the resolver kept run $i as written');
        }
      }
    });

    test('an empty scene consumes no picture', () {
      const text = '[scene]\n[scene]\n他推门进来。\n\n[scene]\n屋里很暗。';
      final empty = scenesOf(text);
      expect([for (final scene in empty) scene.sentenceCount], [0, 1, 1]);
      final answer = assignScenesToPictures(
        scenes: empty,
        sentences: [
          for (var i = 0; i < 2; i++)
            VideoSentence(
              paragraph: 0,
              sentence: i,
              start: empty[i + 1].first,
              end: empty[i + 1].first + 1,
              text: i == 0 ? '他' : '屋',
              language: 'zh-Hans',
              voice: null,
            ),
        ],
        pictures: _picks(3),
      );
      expect(answer, isNotNull);
      // The first scene owns nothing, so it writes nothing: picture 0 takes the
      // second scene's sentence and picture 1 the third's.
      expect(indicesOfSpans(answer![0].spans, _sentencesOf(answer)), hasLength(1));
      expect(answer[2].isEmpty, isTrue);
    });

    test('null when nothing pairs: no pictures, no scenes, or no sentences', () {
      final picked = _picks(2);
      expect(
        assignScenesToPictures(
            scenes: scenes, sentences: sentences, pictures: const []),
        isNull,
      );
      expect(
        assignScenesToPictures(
            scenes: const [], sentences: sentences, pictures: picked),
        isNull,
      );
      // Scenes, pictures, and a sentence list that names nothing they own —
      // the preamble only.
      final preamble = sentences.where((s) => s.start < scenes.first.first).toList();
      expect(preamble, isNotEmpty);
      expect(
        assignScenesToPictures(
            scenes: scenes, sentences: preamble, pictures: picked),
        isNull,
      );
    });

    test('the preamble and the heading are in no run', () {
      final answer = assignScenesToPictures(
        scenes: scenes,
        sentences: sentences,
        pictures: _picks(3),
      )!;
      final all = <int>[
        for (final run in answer) ...indicesOfSpans(run.spans, sentences),
      ];
      expect(all, isNot(contains(0)), reason: 'the preamble is nobody\'s');
      for (final index in all) {
        expect(sentences[index].text.trim(), isNot(contains('青石观蚁')));
        expect(sentences[index].text.trim(), isNot(contains('1：')));
      }
    });
  });
}

/// The sentences [answer]'s runs are written against — rebuilt from the runs'
/// own spans, so the helper reads the answer rather than the fixture.
List<VideoSentence> _sentencesOf(List<PictureRun> answer) => [
      for (final run in answer)
        for (final span in run.spans)
          VideoSentence(
            paragraph: 0,
            sentence: 0,
            start: span.$1,
            end: span.$2,
            text: '',
            language: 'zh-Hans',
            voice: null,
          ),
    ];
