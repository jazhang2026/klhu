/// The video's timeline: what it shows, in what order, in whose voice, and for
/// exactly how long (spec 012, research D3 — the voice is the clock).
///
/// This module is pure: it is handed the sentences and their measured audio
/// lengths and returns the finished layout. The renderer (`video_renderer.dart`)
/// does the synthesis, the painting and the encoding around it.
library;

import 'package:klhu/language.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/voice_store.dart';

/// What a slot of the video is: the opening card, a sentence being heard, or the
/// hold on the last sentence at the end (FR-008).
enum VideoSlotKind { title, sentence, hold }

/// One sentence as the video will speak it: the same unit the engine gets for a
/// read — one utterance per sentence (010 FR-011), in its paragraph's language
/// and picked voice (002/FR-003) — so the video hears exactly what the page
/// would speak.
class VideoSentence {
  const VideoSentence({
    required this.paragraph,
    required this.sentence,
    required this.start,
    required this.end,
    required this.text,
    required this.language,
    required this.voice,
  });

  /// Indices into the sentences' own paragraphs and their sentences, as the
  /// read reports them (011 FR-020).
  final int paragraph;
  final int sentence;

  /// Absolute offsets in the content — the span the video's highlight covers.
  final int start;
  final int end;

  final String text;
  final String language;
  final VoiceChoice? voice;
}

/// Splits per-paragraph speeches into the sentences the video will speak.
///
/// The split mirrors `ReaderService._sentencesOf` deliberately: a paragraph
/// reaches the engine as one utterance per sentence, and the video must speak
/// the same units the page does — 011's highlight, 010's resume point and this
/// video all name the same sentence.
///
/// A segment that is nothing but whitespace is dropped: it is not a sentence
/// anyone can hear or see, and a video built on it would hold a blank frame for
/// its duration. Content that is only whitespace therefore has nothing to read
/// (FR-015), which is what a render refuses on.
List<VideoSentence> videoSentencesOf(List<ParagraphSpeech> speeches) {
  final units = <VideoSentence>[];
  for (var i = 0; i < speeches.length; i++) {
    final paragraph = speeches[i];
    final ranges = sentenceRanges(paragraph.text);
    for (var j = 0; j < ranges.length; j++) {
      final text = paragraph.text.substring(ranges[j].start, ranges[j].end);
      if (text.trim().isEmpty) continue;
      units.add(
        VideoSentence(
          paragraph: i,
          sentence: j,
          start: paragraph.start + ranges[j].start,
          end: paragraph.start + ranges[j].end,
          text: text,
          language: paragraph.language,
          voice: paragraph.voice,
        ),
      );
    }
  }
  return units;
}

/// The video's sentences from a raw reading position: the sentence that position
/// is in, to the content's last (FR-004, SC-010).
///
/// The position is 011's stored offset, which is not a sentence boundary — it is
/// resolved to its sentence's own start first, so the video opens at a sentence
/// rather than mid-way through one. Language and voice resolution is
/// `resolveParagraphSpeeches`, the same call the page's read makes, so the
/// video cannot read something different from what a read would.
Future<List<VideoSentence>> videoSentencesFrom({
  required String content,
  required int position,
  required Future<VoiceChoice?> Function(String language) loadVoice,
}) async {
  final from = resolveSentence(content, position).start;
  final speeches =
      await resolveParagraphSpeeches(content, from, content.length, loadVoice);
  return videoSentencesOf(speeches);
}

/// One stretch of the finished timeline.
class VideoSlot {
  const VideoSlot({
    required this.kind,
    required this.paragraph,
    required this.sentence,
    required this.start,
    required this.end,
    required this.text,
    required this.language,
    required this.voice,
    required this.durationMs,
    required this.frames,
    required this.startFrame,
  });

  final VideoSlotKind kind;

  /// Indices into the content's paragraphs and sentences; `-1` on the title card
  /// and the end hold, which name no sentence.
  final int paragraph;
  final int sentence;

  /// Absolute offsets in the content; both `0` on the title card and the hold,
  /// which paint no content text.
  final int start;
  final int end;

  /// The sentence being spoken, or the content's name on the title card.
  final String text;
  final String language;
  final VoiceChoice? voice;

  /// How long this slot lasts, and how many frames that is at the plan's rate.
  final int durationMs;
  final int frames;

  /// Where this slot begins in the video's frame count.
  final int startFrame;

  bool get isSentence => kind == VideoSlotKind.sentence;

  int get endFrame => startFrame + frames;
}

/// The video's whole timeline: the title card, one slot per sentence lasting
/// exactly as long as its own audio, a constant gap between consecutive
/// sentences, and the end hold (FR-008, FR-016).
class VideoPlan {
  const VideoPlan({
    required this.slots,
    required this.fps,
    required this.width,
    required this.height,
    required this.title,
  });

  /// In the order they are seen and heard: title card, sentences, end hold. An
  /// empty list is a content with nothing to read (FR-015) — there is no video.
  final List<VideoSlot> slots;

  final int fps;
  final int width;
  final int height;

  /// The content's name, as the title card shows it.
  final String title;

  /// FR-016's bounds are "no gap between consecutive sentences longer than
  /// 0.5 s, no lead-in longer than 3 s and no end hold longer than 3 s"; these
  /// are the values inside them. Fixed, so the pace is the same every render.
  static const int gapMs = 400;
  static const int titleMs = 2500;
  static const int holdMs = 2000;

  /// The sentences, in the order they are heard.
  List<VideoSlot> get sentences =>
      [for (final slot in slots) if (slot.isSentence) slot];

  /// The gap between two consecutive sentences, in frames.
  int get gapFrames => framesFor(gapMs);

  /// The video's whole length. Zero for an empty plan.
  int get totalFrames => slots.isEmpty ? 0 : slots.last.endFrame;

  /// The rounding rule, in one place: a duration in frames at this plan's rate.
  int framesFor(int ms) => (ms * fps / 1000).round();
}

/// Builds the finished plan: [sentences] in order, each with the length of the
/// audio that was measured for it in [audioMs], laid out at [aspect]'s frame and
/// rate.
///
/// An empty [sentences] is an empty plan, not an error (FR-015). A length
/// mismatch is a programming error and throws — a plan whose slot count and
/// audio count disagree would silently misalign every highlight after the gap.
VideoPlan buildVideoPlan({
  required String title,
  required List<VideoSentence> sentences,
  required List<int> audioMs,
  required VideoAspect aspect,
}) {
  if (sentences.isEmpty) {
    return VideoPlan(
      slots: const [],
      fps: aspect.fps,
      width: aspect.width,
      height: aspect.height,
      title: title,
    );
  }
  if (audioMs.length != sentences.length) {
    throw ArgumentError(
      'audioMs has ${audioMs.length} entries for ${sentences.length} sentences',
    );
  }

  int framesOf(int ms) => (ms * aspect.fps / 1000).round();

  final slots = <VideoSlot>[];
  var cursor = framesOf(VideoPlan.titleMs);
  slots.add(
    VideoSlot(
      kind: VideoSlotKind.title,
      paragraph: -1,
      sentence: -1,
      start: 0,
      end: 0,
      text: title,
      language: '',
      voice: null,
      durationMs: VideoPlan.titleMs,
      frames: cursor,
      startFrame: 0,
    ),
  );

  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    final frames = framesOf(audioMs[i]);
    slots.add(
      VideoSlot(
        kind: VideoSlotKind.sentence,
        paragraph: sentence.paragraph,
        sentence: sentence.sentence,
        start: sentence.start,
        end: sentence.end,
        text: sentence.text,
        language: sentence.language,
        voice: sentence.voice,
        durationMs: audioMs[i],
        frames: frames,
        startFrame: cursor,
      ),
    );
    cursor += frames;
    // A gap separates consecutive sentences; the hold follows the last one.
    if (i < sentences.length - 1) cursor += framesOf(VideoPlan.gapMs);
  }

  slots.add(
    VideoSlot(
      kind: VideoSlotKind.hold,
      paragraph: -1,
      sentence: -1,
      start: 0,
      end: 0,
      text: sentences.last.text,
      language: sentences.last.language,
      voice: sentences.last.voice,
      durationMs: VideoPlan.holdMs,
      frames: framesOf(VideoPlan.holdMs),
      startFrame: cursor,
    ),
  );

  return VideoPlan(
    slots: slots,
    fps: aspect.fps,
    width: aspect.width,
    height: aspect.height,
    title: title,
  );
}
