/// The video's timeline (spec 012 US1): quickstart scenarios 1–6 — where the
/// video starts and how far it runs, which sentence each slot speaks, how long
/// a slot is against its own audio, and the pace and padding FR-016 bounds.
///
/// This file defines the API it tests: `lib/video_timeline.dart` does not exist
/// yet (T004 is written before T014 implements it), so the first run is a
/// compile error — the RED this story starts from.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_timeline.dart';
import 'package:klhu/voice_store.dart';

/// Two English paragraphs around one Chinese and one Spanish one — the
/// mixed-language content SC-007 is about.
const _content = 'One two. Three four.\n\n'
    '清晨的阳光。鸟儿歌唱。\n\n'
    'Sí, siete ocho. Nueve diez.';

/// The Spanish paragraph carries an accent on purpose: the app's detector needs
/// one, or two distinct function words, to call a paragraph Spanish.
const _zhPicked =
    VoiceChoice(language: 'zh-Hans', name: 'zh-CN-language', locale: 'zh-CN');

int _at(String text) {
  final index = _content.indexOf(text);
  expect(index, isNonNegative, reason: 'fixture drift: "$text" is not there');
  return index;
}

Future<List<VideoSentence>> _sentences(int position, {VoiceChoice? picked}) =>
    videoSentencesFrom(
      content: _content,
      position: position,
      loadVoice: (language) async =>
          picked != null && picked.language == language ? picked : null,
    );

VideoPlan _plan(List<VideoSentence> sentences, List<int> audioMs) =>
    buildVideoPlan(
      title: 'Mixed',
      sentences: sentences,
      audioMs: audioMs,
      aspect: VideoAspect.landscape,
    );

void main() {
  group('where the video starts and how far it runs (1, 2, 5)', () {
    test('1. with nothing highlighted it starts at the content\'s first sentence',
        () async {
      final sentences = await _sentences(0);
      expect(sentences.first.text, 'One two.');
      expect(sentences.first.start, 0);
      expect(sentences.first.paragraph, 0);
      expect(sentences.first.sentence, 0);
    });

    test('1. with a sentence highlighted it starts there, not at the top',
        () async {
      final sentences = await _sentences(_at('清晨的阳光。'));
      expect(sentences.first.text, '清晨的阳光。');
      expect(sentences.first.start, _at('清晨的阳光。'));
    });

    test('1. a position inside a sentence starts at that sentence\'s own start',
        () async {
      // 011's stored position is a raw offset, not a sentence boundary.
      final sentences = await _sentences(_at('Three four.') + 4);
      expect(sentences.first.text, 'Three four.');
      expect(sentences.first.start, _at('Three four.'));
    });

    test('1. a position at the content\'s end still resolves to its last sentence',
        () async {
      final sentences = await _sentences(_content.length);
      expect(sentences.map((s) => s.text), ['Nueve diez.']);
    });

    test('2. every sentence to the content\'s end is there, in order, once',
        () async {
      final sentences = await _sentences(_at('Three four.'));
      expect(sentences.map((s) => s.text).toList(), [
        'Three four.',
        '清晨的阳光。',
        '鸟儿歌唱。',
        'Sí, siete ocho.',
        'Nueve diez.',
      ]);
    });

    test('2. the spans tile the content from the start sentence to its end',
        () async {
      final sentences = await _sentences(_at('清晨的阳光。'));
      for (var i = 1; i < sentences.length; i++) {
        // Only whitespace between one sentence's end and the next one's start:
        // no sentence is dropped, duplicated or read short.
        final between =
            _content.substring(sentences[i - 1].end, sentences[i].start);
        expect(between.trim(), isEmpty, reason: 'gap between $i-1 and $i');
      }
      expect(sentences.last.end, _content.length);
    });

    test('5. an empty content yields no sentence and no plan', () async {
      final sentences = await videoSentencesFrom(
        content: '',
        position: 0,
        loadVoice: (_) async => null,
      );
      expect(sentences, isEmpty);
      expect(
        buildVideoPlan(
          title: 'Empty',
          sentences: sentences,
          audioMs: const [],
          aspect: VideoAspect.landscape,
        ).slots,
        isEmpty,
      );
    });

    test('5. a content that is only whitespace has nothing to read', () async {
      final sentences = await videoSentencesFrom(
        content: '   \n\n  \t ',
        position: 0,
        loadVoice: (_) async => null,
      );
      expect(sentences, isEmpty);
    });

    test('5. a blank paragraph inside real text is skipped, not spoken',
        () async {
      // Two paragraphs of text with a whitespace-only one between them: the
      // video speaks the two and holds no frame for the blank one.
      final sentences = await videoSentencesFrom(
        content: 'One two.\n\n   \n\nThree four.',
        position: 0,
        loadVoice: (_) async => null,
      );
      expect(sentences.map((s) => s.text).toList(), ['One two.', 'Three four.']);
    });
  });

  group('the slots (3, 4, 6)', () {
    test('3. each sentence\'s frames are exactly its own audio', () async {
      final sentences = await _sentences(0);
      const audioMs = [1000, 500, 2000, 250, 1500, 1000];
      final plan = _plan(sentences, audioMs);

      final spoken = plan.sentences;
      expect(spoken.length, sentences.length);
      for (var i = 0; i < spoken.length; i++) {
        expect(spoken[i].durationMs, audioMs[i]);
        expect(spoken[i].frames, plan.framesFor(audioMs[i]));
        expect(spoken[i].frames, (audioMs[i] * plan.fps / 1000).round());
      }
      // The frame size and rate come from the chosen format.
      expect(plan.width, VideoAspect.landscape.width);
      expect(plan.height, VideoAspect.landscape.height);
      expect(plan.fps, VideoAspect.landscape.fps);
    });

    test('3. startFrame runs from the title card, gap by gap, into the end hold',
        () async {
      final sentences = await _sentences(0);
      final plan = _plan(sentences, List.filled(sentences.length, 1000));

      expect(plan.slots.first.kind, VideoSlotKind.title);
      expect(plan.slots.last.kind, VideoSlotKind.hold);

      final title = plan.slots.first;
      expect(title.startFrame, 0);
      expect(title.frames, plan.framesFor(VideoPlan.titleMs));

      // A gap follows each sentence except the last, which the hold follows.
      var cursor = title.frames;
      for (final slot in plan.sentences) {
        expect(slot.startFrame, cursor);
        cursor += slot.frames;
        if (slot != plan.sentences.last) cursor += plan.gapFrames;
      }
      final hold = plan.slots.last;
      expect(hold.startFrame, cursor);
      expect(hold.durationMs, VideoPlan.holdMs);
      expect(plan.totalFrames, cursor + hold.frames);
    });

    test('4. the lead-in, the gap and the end hold are inside FR-016\'s bounds',
        () async {
      expect(VideoPlan.gapMs, greaterThan(0));
      expect(VideoPlan.gapMs, lessThanOrEqualTo(500));
      expect(VideoPlan.titleMs, greaterThan(0));
      expect(VideoPlan.titleMs, lessThanOrEqualTo(3000));
      expect(VideoPlan.holdMs, greaterThan(0));
      expect(VideoPlan.holdMs, lessThanOrEqualTo(3000));
    });

    test('4. a short video is still a valid one', () async {
      // One sentence, a quarter second of audio: the smallest real video is
      // lead-in + sentence + hold, and none of the three may vanish.
      final sentences = await _sentences(_at('Nueve diez.'));
      final plan = _plan(sentences, const [250]);
      expect(plan.sentences.single.durationMs, 250);
      expect(plan.totalFrames,
          greaterThan(plan.framesFor(VideoPlan.titleMs) + plan.framesFor(VideoPlan.holdMs)));
      expect(plan.sentences.single.startFrame, plan.framesFor(VideoPlan.titleMs));
    });

    test('6. each slot keeps its own paragraph\'s language and picked voice',
        () async {
      final sentences = await _sentences(0, picked: _zhPicked);
      final plan = _plan(sentences, List.filled(sentences.length, 1000));

      expect(plan.sentences.map((s) => s.language).toList(),
          ['en', 'en', 'zh-Hans', 'zh-Hans', 'es', 'es']);
      // The picked voice reaches exactly the paragraph whose language it is.
      expect(plan.sentences[2].voice, _zhPicked);
      expect(plan.sentences[3].voice, _zhPicked);
      expect(plan.sentences[0].voice, isNull);
      expect(plan.sentences[4].voice, isNull);
      // And the text each slot will speak is that sentence, not its paragraph.
      expect(plan.sentences[2].text, '清晨的阳光。');
      expect(plan.sentences[4].text, 'Sí, siete ocho.');
    });

    test('6. a slot\'s span is the sentence it speaks, inside the content',
        () async {
      final sentences = await _sentences(0);
      final plan = _plan(sentences, List.filled(sentences.length, 100));
      for (final slot in plan.sentences) {
        expect(slot.start, greaterThanOrEqualTo(0));
        expect(slot.end, greaterThan(slot.start));
        expect(slot.end, lessThanOrEqualTo(_content.length));
        expect(_content.substring(slot.start, slot.end), slot.text);
      }
    });
  });
}
