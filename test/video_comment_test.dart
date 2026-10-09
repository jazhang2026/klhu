/// 015 US5 — the video's slot carries its sentence and its comment (quickstart
/// row 14): the block a frame paints is the sentence plus each comment that
/// rides it, and the audio is the read's own utterances in order — so the file
/// shows and sounds exactly what the reader asked for, in both switch states.
///
/// FR-013, FR-009's video half, SC-007's unit half, SC-008's unit half.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_timeline.dart';
import 'package:klhu/voice_store.dart';

void main() {
  const esVoice = VoiceChoice(language: 'es', name: 'es-us-x-sfb-local', locale: 'es-US');
  const enVoice = VoiceChoice(language: 'en', name: 'en-us-x-sfg-local', locale: 'en-US');

  /// One distinct voice per language, so "the comment reads in its own
  /// language's voice" is a comparison between two known values.
  Future<VoiceChoice?> picked(String language) async => switch (language) {
        'es' => esVoice,
        'en' => enVoice,
        _ => null,
      };

  /// The reader's own example — a Spanish sentence with an English comment under
  /// it — and the same text with the comment gone, as the control.
  const withComment = 'Hola.\n\n[注] How are you?';
  const withoutComment = 'Hola.\n\nHow are you?';

  Future<List<VideoSentence>> units(String content, {bool commentsRead = true}) =>
      videoSentencesFrom(
        content: content,
        position: 0,
        commentsRead: commentsRead,
        loadVoice: picked,
      );

  VideoPlan planOf(List<VideoSentence> sentences, List<int> audioMs, String content) =>
      buildVideoPlan(
        sentences: sentences,
        audioMs: audioMs,
        aspect: VideoAspect.landscape,
        comments: commentsOf(content),
      );

  group("the slot's block and its audio (14)", () {
    test('the comment rides its sentence: one slot, the block taller by a line',
        () async {
      final sentences = await units(withComment);
      expect(sentences.map((s) => s.isComment).toList(), [false, true]);
      final plan = planOf(sentences, const [1000, 500], withComment);

      // One sentence slot (the comment rides it) plus the end hold.
      expect(plan.sentences, hasLength(1));
      final slot = plan.sentences.single;
      expect(slot.text, 'Hola.\nHow are you?',
          reason: "the sentence's own text, then its comment on its own line (FR-013)");
      // No marker character is painted anywhere in the file.
      for (final s in plan.slots) {
        expect(s.text.contains('['), isFalse, reason: s.text);
        expect(s.text.contains(']'), isFalse, reason: s.text);
      }
      // `span=` is still the SENTENCE's own offsets, not the comment's.
      expect(slot.start, 0);
      expect(slot.end, 'Hola.'.length);
      // The slot lasts its own audio plus the comment's.
      expect(slot.durationMs, 1500);
      expect(slot.frames, plan.framesFor(1500));
    });

    test("the slot's audio names its own wav first, the comment's after it",
        () async {
      final sentences = await units(withComment);
      final plan = planOf(sentences, const [1000, 500], withComment);
      final slot = plan.sentences.single;
      expect(slot.audio, [0, 1],
          reason: "the sentence is index 0, the comment index 1, in the read's order");
      // …and those two utterances carry the two languages' own voices.
      expect(sentences[slot.audio.first].language, 'es');
      expect(sentences[slot.audio.last].isComment, isTrue);
      expect(sentences[slot.audio.last].language, 'en');
      expect(sentences[slot.audio.first].voice?.name, esVoice.name);
      expect(sentences[slot.audio.last].voice?.name, enVoice.name);
    });

    test('with the comments off the block is unchanged, the audio its own alone',
        () async {
      final on = planOf(await units(withComment), const [1000, 500], withComment);
      final off = planOf(
          await units(withComment, commentsRead: false), const [1000], withComment);

      // The block does not depend on the setting: the comment is painted either
      // way (the setting changes what is heard, not what is seen — FR-013).
      expect(on.sentences.single.text, off.sentences.single.text);
      expect(off.sentences.single.text, 'Hola.\nHow are you?');
      // The audio does: off, the slot plays the sentence alone.
      expect(on.sentences.single.audio, [0, 1]);
      expect(off.sentences.single.audio, [0]);
      // So the file is shorter by exactly the comment's own audio.
      expect(on.sentences.single.durationMs, 1500);
      expect(off.sentences.single.durationMs, 1000);
    });

    test("a tagless content's plan is 012's own shape", () async {
      final sentences = await units(withoutComment);
      expect(sentences.map((s) => s.isComment).toList(), [false, false]);
      final plan = planOf(sentences, const [1000, 500], withoutComment);
      // Two sentences, two slots; each block is exactly its sentence, and each
      // plays its own utterance alone — today's plan, slot for slot.
      expect(plan.sentences.map((s) => s.text).toList(), ['Hola.', 'How are you?']);
      expect(plan.sentences.map((s) => s.audio).toList(), [
        [0],
        [1]
      ]);
      expect(plan.sentences.map((s) => s.durationMs).toList(), [1000, 500]);
      for (var i = 0; i < plan.sentences.length; i++) {
        expect(plan.sentences[i].start, sentences[i].start);
        expect(plan.sentences[i].end, sentences[i].end);
      }
    });
  });
}
