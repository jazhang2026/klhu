/// The boundary between two pictures' runs, and the switch across it (spec
/// 021): the sentence the reader reported as assignable twice, and the repair
/// that replaces refusing the reader outright.
///
/// The sentences are the video's own (`videoSentencesFrom` over the timeline's
/// fixture content), so the boundary is a real content offset rather than a
/// number this file invented.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/video_timeline.dart';

const _content = 'One. Two. Three.\n\nFour. Five. Six.';

/// A run over the sentences at [indices], stored the way the pass stores it:
/// the sentences' **own spans**.
PictureRun _run(List<VideoSentence> sentences, String name, List<int> indices) =>
    PictureRun(
      name: name,
      spans: [for (final i in indices) (sentences[i].start, sentences[i].end)],
    );

/// What [name]'s run comes to, read back through the same call the resolver
/// uses — so a span this file got wrong cannot pass unnoticed.
List<int> _held(List<VideoSentence> sentences, List<PictureRun> runs, String name) =>
    indicesOfSpans(runs.firstWhere((run) => run.name == name).spans, sentences);

void main() {
  late List<VideoSentence> sentences;

  setUp(() async {
    sentences = await _sentences(_content);
  });

  /// The reader's own report of 2026-10-15: white holds sentences 1-4, black
  /// 5-7, and tapping sentence 4 with black selected was accepted — the last
  /// sentence of one picture's run landing in the next picture's run as well.
  List<PictureRun> boundary() => [
        _run(sentences, 'white.png', [0, 1, 2, 3]),
        _run(sentences, 'black.png', [4, 5]),
      ];

  group('the boundary between two runs belongs to one picture', () {
    test('an earlier picture\'s last sentence is not the later picture\'s', () {
      expect(
        refusedAdd(sentences: sentences, runs: boundary(), picture: 1, index: 3),
        AssignmentRefusal.notInOrder,
        reason: 'sentence 4 is white\'s own; black taking it puts it in two runs',
      );
    });

    test('a later picture\'s first sentence is not the earlier picture\'s', () {
      expect(
        refusedAdd(sentences: sentences, runs: boundary(), picture: 0, index: 4),
        AssignmentRefusal.notInOrder,
        reason: 'the symmetric shape: sentence 5 is black\'s own',
      );
    });

    test('a sentence inside the neighbour\'s run is refused by the same rule', () {
      expect(
        refusedAdd(sentences: sentences, runs: boundary(), picture: 1, index: 1),
        AssignmentRefusal.notInOrder,
      );
    });
  });

  group('the switch across it', () {
    test('the holder of a sentence is read off the runs', () {
      expect(holderOf(sentences: sentences, runs: boundary(), index: 3), 0);
      expect(holderOf(sentences: sentences, runs: boundary(), index: 4), 1);
      expect(holderOf(sentences: sentences, runs: boundary(), index: 5), 1);
    });

    test('a sentence no run holds has no holder', () {
      final runs = [_run(sentences, 'white.png', [0, 1])];
      expect(holderOf(sentences: sentences, runs: runs, index: 3), isNull);
    });

    test('an end of the holder\'s run may be given to a target that stays in one run', () {
      expect(
        refusedSwitch(sentences: sentences, runs: boundary(), picture: 1, index: 3),
        isNull,
        reason: 'white would hold 1-3 and black 4-7: both continuous, in order',
      );
    });

    test('a middle sentence of the holder\'s run is refused', () {
      expect(
        refusedSwitch(sentences: sentences, runs: boundary(), picture: 1, index: 1),
        AssignmentRefusal.middleOfRun,
        reason: 'white would be left holding two runs',
      );
    });

    test('a switch that would leave the target gapped is refused as not continuous', () {
      final runs = [
        _run(sentences, 'white.png', [0, 1]),
        _run(sentences, 'black.png', [4, 5]),
      ];
      expect(
        refusedSwitch(sentences: sentences, runs: runs, picture: 0, index: 4),
        AssignmentRefusal.notContinuous,
        reason: 'white would hold 1, 2 and 5',
      );
    });

    test('the target\'s own sentence is not a switch at all', () {
      expect(
        refusedSwitch(sentences: sentences, runs: boundary(), picture: 0, index: 1),
        isNull,
        reason: 'white holds it: the same tap is the gesture that takes it back',
      );
    });

    test('applying it leaves one run shorter and the other longer, no sentence in two', () {
      final after = applySwitch(
        sentences: sentences,
        runs: boundary(),
        picture: 1,
        index: 3,
      );
      expect(_held(sentences, after, 'white.png'), [0, 1, 2]);
      expect(_held(sentences, after, 'black.png'), [3, 4, 5]);
      final spans = [for (final run in after) ...run.spans];
      expect(spans.toSet(), hasLength(spans.length),
          reason: 'no span is in two runs');
      expect(spans, hasLength(6), reason: 'every sentence is still somewhere');
    });
  });
}

/// The video's own sentence list over [content] — the same call the render
/// makes.
Future<List<VideoSentence>> _sentences(String content) async {
  final sentences = await videoSentencesFrom(
    content: content,
    position: 0,
    loadVoice: (language) async => null,
  );
  expect(sentences, hasLength(6), reason: 'fixture drift');
  return sentences;
}
