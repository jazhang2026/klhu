/// The reader's assignment as a rule (spec 020): quickstart rows 1, 2 and 4 —
/// a run names its picture by the picture's own file name, the six shapes one
/// resolver answers, and a run the content has moved out from under.
///
/// The sentences are the video's own: `videoSentencesFrom` over the timeline's
/// fixture content, so a run's spans are real content offsets rather than
/// numbers this file made up, and a content edit can move them for real.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';

/// Six sentences — the timeline's own fixture — which is what puts the spans
/// below in the content rather than in a table this file invented.
const _content = 'One. Two. Three.\n\nFour. Five. Six.';

/// The same content with one character more inside its **second** sentence:
/// every span after it moves, while the first sentence's own span stands. That
/// is what makes a run over the first paragraph survive and a run over the
/// second go stale, rather than a whole-content fixture that only ever fails.
const _edited = 'One. Twos. Three.\n\nFour. Five. Six.';

/// The reader's picks, in the order chosen: only the **names** matter to the
/// rule, so the paths are the prompt's own shape and nothing more.
List<HeldPicture> _picks(List<String> names) => [
      for (var i = 0; i < names.length; i++)
        HeldPicture(name: names[i], path: '/picks_1/pick_${i}_${names[i]}'),
    ];

/// A run over the sentences at [indices], stored the way the pass stores it:
/// the sentences' **own spans** (research D2's surviving half).
PictureRun _run(List<VideoSentence> sentences, String name, List<int> indices) =>
    PictureRun(
      name: name,
      spans: [for (final i in indices) (sentences[i].start, sentences[i].end)],
    );

/// The first picture of [answer] that carries [name], or null: what a caller
/// reads back by name without depending on the display order.
List<int>? _of(AssignmentAnswer answer, String name) {
  for (final run in answer.effective) {
    if (run.name == name) return run.sentences;
  }
  return null;
}

void main() {
  late List<VideoSentence> sentences;

  setUp(() async {
    sentences = await _sentences(_content);
  });

  group('a run names its picture by the picture\'s own file name', () {
    test('nothing assigned is the no-assignment state, not empty runs', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png']),
        runs: const [],
      );

      expect(answer.isInForce, isFalse);
      expect(answer.effective, isEmpty,
          reason: 'no runs at all is no assignment, not two empty ones');
      expect(answer.stale, isEmpty);
    });

    test('a run whose picture is not among the picks is stale, and nothing '
        'is re-pointed at its place', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png']),
        runs: [_run(sentences, 'gone.png', [0, 1])],
      );

      expect(answer.stale.map((r) => r.name), ['gone.png']);
      expect(answer.isInForce, isFalse,
          reason: 'the one picture here was never the one assigned');
      expect(_of(answer, 'a.png'), isNull);
    });

    test('the same file picked again brings its run back into force', () {
      final runs = [_run(sentences, 'a.png', [0, 1])];

      final away = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['b.png']),
        runs: runs,
      );
      expect(away.stale.map((r) => r.name), ['a.png']);

      final back = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['b.png', 'a.png', 'c.png']),
        runs: runs,
      );
      expect(back.stale, isEmpty);
      expect(_of(back, 'a.png'), [0, 1],
          reason: 'the reader\'s own run, back on the file it names');
      expect(_of(back, 'b.png'), isEmpty,
          reason: 'b is before the assigned picture: nothing precedes it');
      expect(_of(back, 'c.png'), [2, 3, 4, 5],
          reason: 'c is after it and holds nothing, so the tail is c\'s');
    });

    test('two picks with the same name: the first in the order takes the run',
        () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'a.png']),
        runs: [_run(sentences, 'a.png', [0, 1])],
      );

      expect(answer.effective, hasLength(2));
      expect(answer.effective[0].sentences, [0, 1]);
      expect(answer.effective[1].sentences, [2, 3, 4, 5],
          reason: 'the second is unassigned, so the tail falls to it');
      expect(answer.stale, isEmpty);
    });

    test('every run it answers with is ascending, and no sentence is held '
        'twice', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png', 'c.png']),
        runs: [
          _run(sentences, 'a.png', [0, 1]),
          _run(sentences, 'c.png', [4, 5]),
        ],
      );

      final seen = <int>{};
      for (final run in answer.effective) {
        expect(run.sentences, orderedEquals(List.of(run.sentences)..sort()));
        for (final index in run.sentences) {
          expect(seen.add(index), isTrue, reason: 'sentence $index twice');
        }
      }
      expect(seen, {0, 1, 2, 3, 4, 5},
          reason: 'every sentence is one picture\'s, and the gap went to a');
    });
  });

  group('the six shapes', () {
    test('the assigned run is the reader\'s own, in order', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png', 'c.png']),
        runs: [
          _run(sentences, 'a.png', [0, 1]),
          _run(sentences, 'b.png', [2, 3]),
          _run(sentences, 'c.png', [4, 5]),
        ],
      );

      expect(_of(answer, 'a.png'), [0, 1]);
      expect(_of(answer, 'b.png'), [2, 3]);
      expect(_of(answer, 'c.png'), [4, 5]);
      expect(answer.stale, isEmpty);
    });

    test('a sentence between two runs keeps the picture before it', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png']),
        runs: [
          _run(sentences, 'a.png', [0]),
          _run(sentences, 'b.png', [3]),
        ],
      );

      expect(_of(answer, 'a.png'), [0, 1, 2],
          reason: '1 and 2 are the gap: the picture before them stays');
      expect(_of(answer, 'b.png'), [3, 4, 5],
          reason: 'and the tail after the last assigned run is b\'s');
    });

    test('the tail falls to the pictures after it that hold nothing, split '
        'the way 012 splits', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png', 'c.png', 'd.png']),
        runs: [_run(sentences, 'a.png', [0])],
      );

      expect(_of(answer, 'a.png'), [0]);
      // Five sentences over three pictures: each 1, the remainder to the first.
      expect(_of(answer, 'b.png'), [1, 2]);
      expect(_of(answer, 'c.png'), [3, 4]);
      expect(_of(answer, 'd.png'), [5]);
    });

    test('with no picture after it, the tail stays on the last assigned one',
        () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png']),
        runs: [
          _run(sentences, 'a.png', [0, 1, 2]),
          _run(sentences, 'b.png', [3]),
        ],
      );

      expect(_of(answer, 'a.png'), [0, 1, 2]);
      expect(_of(answer, 'b.png'), [3, 4, 5]);
    });

    test('a picture between two runs, left with nothing, holds nothing', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png', 'c.png']),
        runs: [
          _run(sentences, 'a.png', [0, 1, 2]),
          _run(sentences, 'c.png', [4, 5]),
        ],
      );

      expect(_of(answer, 'a.png'), [0, 1, 2, 3],
          reason: 'sentence 3 is the gap, and a is the picture before it');
      expect(_of(answer, 'b.png'), isEmpty);
      expect(_of(answer, 'c.png'), [4, 5]);
      expect(answer.stale, isEmpty);
    });

    test('nothing precedes the first assigned run, so the first sentence '
        'paints it', () {
      final answer = assignmentsFor(
        sentences: sentences,
        pictures: _picks(['a.png', 'b.png', 'c.png']),
        runs: [
          _run(sentences, 'b.png', [0, 1]),
          _run(sentences, 'c.png', [2, 3]),
        ],
      );

      expect(_of(answer, 'a.png'), isEmpty,
          reason: 'a precedes the first assigned run, and no sentence is '
              'before that run');
      expect(_of(answer, 'b.png'), [0, 1]);
      expect(_of(answer, 'c.png'), [2, 3, 4, 5]);
    });
  });

  group('a stale run', () {
    test('a run whose spans match no sentence is stale, and its picture holds '
        'nothing of its own', () async {
      final moved = await _sentences(_edited);
      final answer = assignmentsFor(
        sentences: moved,
        pictures: _picks(['a.png', 'b.png']),
        runs: [
          _run(sentences, 'a.png', [0]),
          _run(sentences, 'b.png', [3, 4, 5]),
        ],
      );

      expect(answer.stale.map((r) => r.name), ['b.png'],
          reason: 'FR-014: what no longer fits is named');
      expect(_of(answer, 'a.png'), [0],
          reason: 'the run that still matches stands, at its own place');
      expect(_of(answer, 'b.png'), [1, 2, 3, 4, 5],
          reason: 'b holds nothing of its own, so the tail after a is b\'s');
    });

    test('a run one of whose spans still matches stands with that span',
        () async {
      final moved = await _sentences(_edited);
      final answer = assignmentsFor(
        sentences: moved,
        pictures: _picks(['a.png', 'b.png']),
        runs: [_run(sentences, 'a.png', [0, 1, 2])],
      );

      expect(answer.stale, isEmpty,
          reason: 'one span of it still matches, so the run is not stale');
      expect(_of(answer, 'a.png'), [0],
          reason: 'the run holds the span the text still answers with');
      expect(_of(answer, 'b.png'), [1, 2, 3, 4, 5],
          reason: 'the rest is the tail, and b is the picture after a that '
              'holds nothing');
    });

    test('every run stale is no assignment at all', () async {
      final moved = await _sentences(_edited);
      final answer = assignmentsFor(
        sentences: moved,
        pictures: _picks(['a.png', 'b.png']),
        runs: [
          _run(sentences, 'a.png', [3, 4, 5]),
          _run(sentences, 'b.png', [1, 2]),
        ],
      );

      expect(answer.stale.map((r) => r.name), ['a.png', 'b.png']);
      expect(answer.isInForce, isFalse,
          reason: 'nothing stands, so the render is 012\'s own (FR-009)');
      expect(answer.effective, isEmpty);
    });
  group('what is refused, and why (FR-003, FR-004, FR-012, FR-016)', () {
    late List<VideoSentence> s;
    late List<HeldPicture> picks;

    setUp(() async {
      s = await _sentences(_content);
      picks = _picks(['a.png', 'b.png', 'c.png']);
    });

    /// The reader's own runs, in the pictures' order — what the pass edits.
    List<PictureRun> runsOf(Map<String, List<int>> assigned) => [
      for (final pick in picks)
        _run(s, pick.name, assigned[pick.name] ?? const []),
    ];

    test('a sentence that is not next to the run it would join is refused', () {
      final runs = runsOf({'a.png': [0, 1]});

      expect(
        refusedAdd(sentences: s, runs: runs, picture: 0, index: 2),
        isNull,
        reason: 'right after the run: that is how a run grows (FR-003)',
      );
      expect(
        refusedAdd(sentences: s, runs: runs, picture: 0, index: 5),
        AssignmentRefusal.notContinuous,
        reason: 'a hole between 1 and 5 is not a continuous run',
      );
      expect(
        refusedAdd(sentences: s, runs: runs, picture: 0, index: 3),
        AssignmentRefusal.notContinuous,
      );
    });

    test('a sentence before an earlier picture\'s own is refused, and one '
        'after a later picture\'s own too', () {
      final runs = runsOf({
        'a.png': [0, 1],
        'b.png': [3],
      });

      expect(
        refusedAdd(sentences: s, runs: runs, picture: 1, index: 2),
        isNull,
        reason: 'it sits between a and b: in order either way',
      );
      expect(
        refusedAdd(sentences: s, runs: runs, picture: 1, index: 0),
        AssignmentRefusal.notInOrder,
        reason: 'a already holds sentence 0 (FR-004)',
      );
      expect(
        refusedAdd(sentences: s, runs: runs, picture: 0, index: 4),
        AssignmentRefusal.notInOrder,
        reason: 'and the rule read the other way: b already holds 3',
      );
    });

    test('taking back an end sentence is accepted; a middle one is refused',
        () {
      final runs = runsOf({
        'a.png': [0, 1, 2],
      });

      expect(refusedRemove(sentences: s, runs: runs, picture: 0, index: 0),
          isNull);
      expect(refusedRemove(sentences: s, runs: runs, picture: 0, index: 2),
          isNull);
      expect(
        refusedRemove(sentences: s, runs: runs, picture: 0, index: 1),
        AssignmentRefusal.middleOfRun,
        reason: 'removing 1 would leave two runs on one picture (FR-016)',
      );
    });

    test('a single sentence run takes its own sentence back', () {
      final runs = runsOf({
        'a.png': [2],
      });
      expect(refusedRemove(sentences: s, runs: runs, picture: 0, index: 2),
          isNull);
    });

    test('a picture the reader gave nothing may take another place, even when '
        'the render\'s fallback feeds it', () {
      // a holds sentence 1, and the tail falls back to b and c, so b and c
      // carry sentences although the reader assigned them none (FR-006). What
      // decides whether the reader may move a picture is **the reader's own
      // run** (spec 021 D3): the fallback is an outcome of the render, not a
      // decision of theirs — the reader's own report of 2026-10-15 was that a
      // picture they gave nothing to was refused a move because of it.
      final runs = [
        _run(s, 'a.png', [0]),
        _run(s, 'b.png', []),
        _run(s, 'c.png', []),
      ];
      final answer = assignmentsFor(sentences: s, pictures: picks, runs: runs);

      expect(answer.effective[1].sentences, isNotEmpty,
          reason: 'the tail fell to b');
      expect(answer.effective[2].sentences, isNotEmpty,
          reason: 'and to c');
      expect(mayMove(runs, 0), isFalse,
          reason: 'a holds a sentence of the reader\'s');
      expect(mayMove(runs, 1), isTrue,
          reason: 'b holds only what the render fed it');
      expect(mayMove(runs, 2), isTrue, reason: 'and c the same');
    });

    test('a picture the reader gave nothing and nothing reaches may be moved',
        () {
      // a holds 0..2, b holds 3..5: nothing is left for c, and neither a nor b
      // may move.
      final runs = [
        _run(s, 'a.png', [0, 1, 2]),
        _run(s, 'b.png', [3, 4, 5]),
        _run(s, 'c.png', []),
      ];
      final answer = assignmentsFor(sentences: s, pictures: picks, runs: runs);

      expect(answer.effective[2].sentences, isEmpty);
      expect(mayMove(runs, 2), isTrue);
      expect(mayMove(runs, 0), isFalse);
      expect(mayMove(runs, 1), isFalse);
    });
  });

  });
}

/// The video's own sentence list over [content] — the same call the render
/// makes, so a span in this file is a span the render would match.
Future<List<VideoSentence>> _sentences(String content) async {
  final sentences = await videoSentencesFrom(
    content: content,
    position: 0,
    loadVoice: (language) async => null,
  );
  expect(sentences, hasLength(6), reason: 'fixture drift');
  return sentences;
}
