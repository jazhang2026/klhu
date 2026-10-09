/// The video's timeline: what it shows, in what order, in whose voice, and for
/// exactly how long (spec 012, research D3 — the voice is the clock).
///
/// This module is pure: it is handed the sentences and their measured audio
/// lengths and returns the finished layout. The renderer (`video_renderer.dart`)
/// does the synthesis, the painting and the encoding around it.
library;

import 'package:klhu/comment.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/voice_store.dart';

/// What a slot of the video is: a sentence being heard, or the hold on the last
/// sentence at the end (FR-008).
///
/// A video opens on its first spoken sentence — the reader's own request of
/// 2026-09-29 ("remove the first title frame"), which withdrew the opening card
/// that used to name the content. Nothing in a frame carries the content's name
/// or its language any more; the frames are the sentences and the end hold.
enum VideoSlotKind { sentence, hold }

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
    this.role,
    this.isComment = false,
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

  /// The role whose turn this sentence is, or null for narration (014 FR-018):
  /// the read's own answer, carried through so the render's log line can name it
  /// (D10) — the frame itself never shows it.
  final String? role;

  /// Whether this unit is a comment's own speech (015 FR-007): it is never a
  /// slot of its own — it rides the sentence it belongs to (D8).
  final bool isComment;
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
          role: paragraph.role,
          isComment: paragraph.isComment,
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
/// rather than mid-way through one.
///
/// Language, voice and role resolution is [resolveSpeeches] — the same call the
/// page's read makes, with the same content type, removals and picks (014 D9),
/// so the video cannot read or voice something different from what a read would.
/// The dialogue parameters default to the standard read, which is what this call
/// was before 014: 012's own callers and tests pass none of them. 015's
/// [commentsRead] defaults to `true` (the shipped default of FR-006): with it
/// `false` no comment's characters reach the sentences at all, which is what
/// makes the file's audio the sentences' own (SC-008) while the block still
/// paints the comment (`buildVideoPlan`).
Future<List<VideoSentence>> videoSentencesFrom({
  required String content,
  required int position,
  required Future<VoiceChoice?> Function(String language) loadVoice,
  ReadingMode mode = ReadingMode.standard,
  Set<String> removed = const {},
  Map<String, VoiceChoice> picks = const {},
  bool commentsRead = true,
  Future<List<VoiceEntry>> Function()? loadInstalled,
}) async {
  final from = resolveSentence(content, position).start;
  final speeches = await resolveSpeeches(
    content: content,
    start: from,
    end: content.length,
    mode: mode,
    removed: removed,
    picks: picks,
    commentsRead: commentsRead,
    loadVoice: loadVoice,
    loadInstalled: loadInstalled,
  );
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
    this.audio = const [],
    this.role,
  });

  final VideoSlotKind kind;

  /// Indices into the content's paragraphs and sentences; `-1` on the end hold,
  /// which names no sentence.
  final int paragraph;
  final int sentence;

  /// Absolute offsets in the content; both `0` on the hold, which paints no
  /// content text.
  final int start;
  final int end;

  /// The sentence being spoken. The end hold repeats the last one's.
  final String text;
  final String language;
  final VoiceChoice? voice;

  /// The role whose turn this slot speaks, or null for narration (014 FR-018).
  /// The hold repeats the last sentence's, like its text and its voice.
  final String? role;

  /// The utterances this slot plays, in order, as indices into the list
  /// [buildVideoPlan] was handed — the sentence's own first, then each comment
  /// that rides it (015 D8). The renderer turns each index into its own audio
  /// file (`sentence_$i.wav`) and its own segment. Empty on the end hold, which
  /// plays the sentence's own tail as silence.
  final List<int> audio;

  /// How long this slot lasts, and how many frames that is at the plan's rate.
  final int durationMs;
  final int frames;

  /// Where this slot begins in the video's frame count.
  final int startFrame;

  bool get isSentence => kind == VideoSlotKind.sentence;

  int get endFrame => startFrame + frames;
}

/// The video's whole timeline: one slot per sentence lasting exactly as long as
/// its own audio, a constant gap between consecutive sentences, and the end hold
/// (FR-008, FR-016).
class VideoPlan {
  const VideoPlan({
    required this.slots,
    required this.fps,
    required this.width,
    required this.height,
  });

  /// In the order they are seen and heard: sentences, end hold. An empty list is
  /// a content with nothing to read (FR-015) — there is no video.
  final List<VideoSlot> slots;

  final int fps;
  final int width;
  final int height;

  /// FR-016's bounds are "no gap between consecutive sentences longer than
  /// 0.5 s and no end hold longer than 3 s"; these are the values inside them.
  /// Fixed, so the pace is the same every render.
  static const int gapMs = 400;
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

/// A slot while it is being built: the sentence that opens it ([own], an index
/// into the plan's sentences) and the comment units that ride it, in order.
class _SlotDraft {
  _SlotDraft(this.own);

  final int own;
  final List<int> riders = <int>[];
}

/// Builds the finished plan: [sentences] in order, each with the length of the
/// audio that was measured for it in [audioMs], laid out at [aspect]'s frame and
/// rate.
///
/// 015: a comment does not get a slot of its own — it **rides** the sentence it
/// belongs to (FR-013, D8). The slot's [VideoSlot.text] is that sentence
/// followed, on its own line, by each comment that rides it, and its
/// [VideoSlot.audio] names the utterances it plays, the sentence's own first.
/// The block is built from the content's own [comments], not from the read's
/// speeches, so it paints the comment in both switch states while the audio
/// carries it only when it was read (research D8). The pairing is its own rule: a
/// comment rides the last non-comment sentence that starts before its tag, and a
/// comment whose owner is not in the render (a range that begins past it) is a
/// slot of its own — its own words alone in the frame — rather than dropped
/// (research's grounding correction 2). A comment the read never speaks (no
/// sentence precedes it anywhere) is in no frame: a file may not paint what the
/// read does not say.
///
/// An empty [sentences] is an empty plan, not an error (FR-015). A length
/// mismatch is a programming error and throws — a plan whose slot count and
/// audio count disagree would silently misalign every highlight after the gap.
VideoPlan buildVideoPlan({
  required List<VideoSentence> sentences,
  required List<int> audioMs,
  required VideoAspect aspect,
  List<Comment> comments = const [],
}) {
  if (sentences.isEmpty) {
    return VideoPlan(
      slots: const [],
      fps: aspect.fps,
      width: aspect.width,
      height: aspect.height,
    );
  }
  if (audioMs.length != sentences.length) {
    throw ArgumentError(
      'audioMs has ${audioMs.length} entries for ${sentences.length} sentences',
    );
  }

  int framesOf(int ms) => (ms * aspect.fps / 1000).round();

  // One slot per non-comment sentence; a comment unit (already placed right
  // after its owner by the resolver) rides the slot it follows, and one with no
  // sentence before it opens a slot of its own.
  final drafts = <_SlotDraft>[];
  for (var i = 0; i < sentences.length; i++) {
    if (!sentences[i].isComment) {
      drafts.add(_SlotDraft(i));
    } else if (drafts.isEmpty || sentences[drafts.last.own].isComment) {
      drafts.add(_SlotDraft(i));
    } else {
      drafts.last.riders.add(i);
    }
  }

  // The block each slot paints: its own sentence, then each content comment that
  // rides it — the last non-comment sentence that starts before the comment's
  // tag. A comment nothing rides paints nothing (the read never speaks it).
  final riding = <int, List<String>>{
    for (var s = 0; s < drafts.length; s++) s: <String>[],
  };
  for (final comment in comments) {
    var target = -1;
    for (var s = 0; s < drafts.length; s++) {
      final own = sentences[drafts[s].own];
      if (!own.isComment && own.start < comment.tag.start) target = s;
    }
    if (target >= 0) riding[target]!.add(comment.text);
  }

  final slots = <VideoSlot>[];
  var cursor = 0;
  for (var s = 0; s < drafts.length; s++) {
    final draft = drafts[s];
    final own = sentences[draft.own];
    // The utterances this slot plays, and the frames they run for.
    final audio = <int>[draft.own, ...draft.riders];
    final durationMs = audio.fold<int>(0, (sum, i) => sum + audioMs[i]);
    final frames = framesOf(durationMs);
    slots.add(
      VideoSlot(
        kind: VideoSlotKind.sentence,
        paragraph: own.paragraph,
        sentence: own.sentence,
        start: own.start,
        end: own.end,
        text: <String>[own.text, ...riding[s]!].join('\n'),
        language: own.language,
        voice: own.voice,
        role: own.role,
        audio: audio,
        durationMs: durationMs,
        frames: frames,
        startFrame: cursor,
      ),
    );
    cursor += frames;
    // A gap separates consecutive sentences; the hold follows the last one.
    if (s < drafts.length - 1) cursor += framesOf(VideoPlan.gapMs);
  }

  final last = slots.last;
  slots.add(
    VideoSlot(
      kind: VideoSlotKind.hold,
      paragraph: -1,
      sentence: -1,
      start: 0,
      end: 0,
      text: last.text,
      language: last.language,
      voice: last.voice,
      role: last.role,
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
  );
}
