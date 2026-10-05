/// The dialogue's video (spec 014 US4, quickstart rows 20-22): a dialogue's plan
/// speaks the turns in the read's own voices and no frame carries a tag.
///
/// This file defines what `lib/video_timeline.dart` must accept — the content's
/// type, its removals and its picks — so the first run is a compile error: the
/// RED this story starts from. 012's own `test/video_timeline_test.dart` is not
/// re-cut: its calls pass none of the new parameters and keep their meaning.
///
/// The video does not resolve voices itself any more (D9): it calls the same
/// `resolveSpeeches` the read calls, so "the video sounds like the read" is a
/// property of there being one call, and this file is what holds the two answers
/// side by side.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_timeline.dart';
import 'package:klhu/voice_store.dart';

/// Two turns and a line that belongs to nobody: 阿明's turn holds two sentences
/// (so one turn is more than one slot), 阿芳's holds one, and the last paragraph
/// is narration — read by the reading voice, whatever the roles were given.
const _content = '{阿明} 你好。我很好。\n\n{阿芳} 我不好。\n\n他说：我来了。';

const _ccc = VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN');
const _ccd = VoiceEntry(name: 'cmn-cn-x-ccd-local', locale: 'zh-CN');

Future<List<VoiceEntry>> _installed() async => const [_ccc, _ccd];

/// Today's per-language pick loader: nothing picked, so the assignment is what
/// decides — the case where roles and narration differ.
Future<VoiceChoice?> _noPick(String language) async => null;

/// The read's own resolution of the same content — the answer the video's slots
/// must equal, slot by slot (D9).
Future<List<ParagraphSpeech>> _read() => resolveSpeeches(
      content: _content,
      start: 0,
      end: _content.length,
      mode: ReadingMode.dialogue,
      removed: const {},
      picks: const {},
      loadVoice: _noPick,
      loadInstalled: _installed,
    );

/// The video's sentences for the same content, over the same device.
Future<List<VideoSentence>> _sentences() => videoSentencesFrom(
      content: _content,
      position: 0,
      loadVoice: _noPick,
      mode: ReadingMode.dialogue,
      loadInstalled: _installed,
    );

/// One second of audio per sentence: the plan's arithmetic is 012's and this
/// file only reads it back.
VideoPlan _plan(List<VideoSentence> sentences) => buildVideoPlan(
      sentences: sentences,
      audioMs: List<int>.filled(sentences.length, 1000),
      aspect: VideoAspect.landscape,
    );

void main() {
  group("20. the plan's voices are the read's own (FR-018, FR-019, SC-008)", () {
    test('every slot speaks the voice the read gave its turn', () async {
      final read = await _read();
      final sentences = await _sentences();

      expect(read, hasLength(3),
          reason: 'one speech per turn, narration included (FR-005)');
      for (final sentence in sentences) {
        // Field by field: `VoiceChoice` is a plain value object without `==`
        // (lib/voice_store.dart), and the pick is what matters.
        final fromRead = read[sentence.paragraph].voice;
        expect(sentence.voice?.name, fromRead?.name,
            reason: 'slot ${sentence.sentence} of turn ${sentence.paragraph}: '
                'the video cannot voice a turn differently from the read');
        expect(sentence.voice?.locale, fromRead?.locale);
        expect(sentence.voice?.language, fromRead?.language);
        expect(sentence.role, read[sentence.paragraph].role,
            reason: 'nor attribute a turn differently (FR-018)');
      }
    });

    test('and that answer is the assignment: one voice per role, none for '
        'narration', () async {
      final sentences = await _sentences();

      expect(sentences.map((sentence) => sentence.text).toList(),
          ['你好。', '我很好。', '我不好。', '他说：我来了。'],
          reason: 'one slot per sentence, across the turns (010 FR-011)');
      final voices = sentences.map((s) => s.voice?.name).toList();
      expect(voices[0], _ccc.name, reason: '阿明 reads with the first voice');
      expect(voices[1], voices[0],
          reason: 'a role keeps one voice across its own turns');
      expect(voices[2], _ccd.name,
          reason: 'the second role does not sound like the first (FR-015)');
      expect(voices[3], isNull,
          reason: 'narration reads in the reading voice — the OS default while '
              'no language pick exists (FR-002)');
    });

    test('the counts and spans are what 012 builds for the same sentences',
        () async {
      final sentences = await _sentences();
      final plan = _plan(sentences);

      expect(plan.slots, hasLength(sentences.length + 1),
          reason: 'one slot per sentence, plus the end hold (FR-008)');
      for (var i = 0; i < sentences.length; i++) {
        final slot = plan.slots[i];
        expect(slot.kind, VideoSlotKind.sentence);
        expect(slot.text, sentences[i].text);
        expect(slot.start, sentences[i].start);
        expect(slot.end, sentences[i].end);
        expect(slot.frames, 1000 * plan.fps ~/ 1000);
      }
      expect(plan.slots.last.kind, VideoSlotKind.hold);
      expect(plan.slots.last.text, sentences.last.text);
      expect(
          plan.totalFrames,
          plan.slots.fold<int>(0, (sum, slot) => sum + slot.frames) +
              plan.gapFrames * (sentences.length - 1),
          reason: 'the plan still accounts for every frame it will paint — the '
              'gaps between sentences included (012 FR-016)');
    });
  });

  group('21. no frame carries a tag (FR-005, SC-008)', () {
    test('no slot text holds a brace, a role name, or anything but the turn',
        () async {
      final sentences = await _sentences();

      for (final sentence in sentences) {
        expect(sentence.text.contains('{'), isFalse);
        expect(sentence.text.contains('}'), isFalse);
        for (final name in const ['阿明', '阿芳']) {
          expect(sentence.text.contains(name), isFalse,
              reason: 'the tag is a gap the painter never sees');
        }
      }
    });

    test('each slot names exactly the span of the text it speaks', () async {
      final sentences = await _sentences();

      for (final sentence in sentences) {
        expect(_content.substring(sentence.start, sentence.end), sentence.text,
            reason: 'the span is the turn content, prefix excluded');
        expect(sentence.text.trim(), sentence.text,
            reason: 'and it carries no stray whitespace from the prefix');
      }
    });
  });

  group('22. the slot line has a role to name (D10, row 27)', () {
    test('every slot carries its turn\'s role, the hold included', () async {
      final sentences = await _sentences();
      final plan = _plan(sentences);

      expect(plan.slots.map((slot) => slot.role).toList(),
          ['阿明', '阿明', '阿芳', null, null],
          reason: 'the video\'s per-slot log line prints this (T021), and the '
              'device row samples the file with nothing else to go on: the '
              'narration slot has no role, and the hold repeats the last '
              'sentence it paints');
    });
  });
}
