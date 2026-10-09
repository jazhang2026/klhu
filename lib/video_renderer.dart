/// The renderer: one content's reading becomes one mp4 (spec 012 US1).
///
/// Two passes, in this order, and the order is the whole design (research D3):
///
///  1. **synthesise** — every sentence is written to its own audio file, in the
///     language and voice that sentence's paragraph resolves to, and each file's
///     exact length is read out of its own header. The durations are MEASURED,
///     never estimated: the same sentence in another voice is a different
///     length (T003/breakpoint S1-e).
///  2. **paint and encode** — the timeline is laid out from those lengths and
///     each distinct frame is painted, published to the reader as the render's
///     progress, and handed to the encoder with the number of frames it stands
///     for. The picture the reader sees is the picture being written (FR-020).
///
/// The renderer owns no UI and no platform code: it is handed a
/// [SentenceSynthesizer], a [VideoEncoder] and a working directory, all three of
/// which a test can fake, and a `BuildContext` is needed nowhere.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:klhu/comment.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';
import 'package:klhu/voice_store.dart';

/// Which half of the render is running.
enum VideoRenderPass { synthesising, painting }

/// How far the render has come, in the pass that is running.
class VideoRenderProgress {
  const VideoRenderProgress({
    required this.pass,
    required this.done,
    required this.total,
  });

  final VideoRenderPass pass;

  /// Sentences written (pass 1) or frames painted (pass 2).
  final int done;
  final int total;
}

/// Why a render could not finish. Every one of these means NO video exists.
enum VideoFailureKind {
  /// The content has nothing to read from the start point (FR-015).
  nothingToRead,

  /// The speech engine failed to write a sentence, or refused (FR-003).
  engine,

  /// The engine wrote something whose length cannot be read, so the timeline
  /// cannot be trusted. Guessing a length is not an option: the picture would
  /// drift from the voice.
  unreadableAudio,

  /// The encoder refused, ran out of space, or stopped mid-way.
  encoder,
}

class VideoRenderException implements Exception {
  const VideoRenderException(this.kind, this.message);

  final VideoFailureKind kind;
  final String message;

  @override
  String toString() => 'VideoRenderException(${kind.name}): $message';
}

/// What a render produced. [cancelled] is the only field that means "no file".
class VideoRenderResult {
  const VideoRenderResult({
    this.path = '',
    this.durationMs = 0,
    this.sizeBytes = 0,
    this.totalFrames = 0,
    this.cancelled = false,
  });

  final String path;
  final int durationMs;
  final int sizeBytes;
  final int totalFrames;
  final bool cancelled;
}

/// The length of a RIFF/WAVE file's audio in milliseconds, or null when the
/// bytes are not a whole RIFF/WAVE file.
///
/// What the engine writes was measured, not assumed (T003, breakpoint row 35):
/// PCM 16-bit mono at 24 kHz, with the length in the file's own header — and
/// `ffprobe` on the device's own output agrees with this walk to the
/// millisecond. A file whose header promises more audio than it holds is NOT
/// repaired or guessed at: it answers null, and the render fails.
int? wavDurationMsOf(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
  if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;

  final view = ByteData.sublistView(bytes);
  int? rate;
  int? channels;
  int? bits;
  int? dataLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final length = view.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ' && offset + 24 <= bytes.length) {
      channels = view.getUint16(offset + 10, Endian.little);
      rate = view.getUint32(offset + 12, Endian.little);
      bits = view.getUint16(offset + 22, Endian.little);
    } else if (id == 'data') {
      dataLength = length;
      // The payload follows this chunk's own header, so the file has to be at
      // least that long; if it is not, the audio is not all there.
      if (bytes.length < offset + 8 + length) return null;
      break;
    }
    offset += 8 + length + (length.isOdd ? 1 : 0);
  }

  if (rate == null || channels == null || bits == null || dataLength == null) {
    return null;
  }
  if (rate <= 0 || channels <= 0 || bits <= 0) return null;

  final frames = dataLength / (bits / 8) / channels;
  return (frames * 1000 / rate).round();
}

/// Renders one content's reading to a video file.
class VideoRenderer {
  VideoRenderer({
    required this.synthesizer,
    required this.encoder,
    required this.workDir,
    required this.aspect,
    required this.readingStyle,
    required this.background,
    this.pictures = const [],
  });

  final SentenceSynthesizer synthesizer;
  final VideoEncoder encoder;

  /// Where the per-sentence audio and the encoder's working file live. The
  /// renderer deletes every file it wrote here and nothing else.
  final Directory workDir;

  final VideoAspect aspect;

  /// The reader's own reading style (011's seam) and the frame's colours.
  final TextStyle readingStyle;
  final Color background;

  /// The reader's picked pictures, read once at the pick and held for this
  /// render only (FR-025). They are written into [workDir] before the first
  /// frame is painted and deleted with everything else this render wrote (D15) —
  /// the picks themselves are never remembered.
  final List<HeldPicture> pictures;

  bool _cancelled = false;

  /// Stop the render. Whatever is in flight finishes, then nothing further is
  /// synthesised or painted, no file is kept, and everything this render wrote
  /// is deleted.
  void cancel() => _cancelled = true;

  /// Renders [content] from [position] — 011's stored offset, which need not be
  /// a sentence boundary — to the content's end.
  ///
  /// Throws [VideoRenderException] for every failure; a cancelled render
  /// returns a [VideoRenderResult] with `cancelled == true` rather than
  /// throwing, because the reader asked for it.
  Future<VideoRenderResult> render({
    required String content,
    required int position,
    required Future<VoiceChoice?> Function(String language) loadVoice,
    ReadingMode mode = ReadingMode.standard,
    Set<String> removed = const {},
    Map<String, VoiceChoice> picks = const {},
    bool commentsRead = true,
    Future<List<VoiceEntry>> Function()? loadInstalled,
    void Function(VideoRenderProgress)? onProgress,
    void Function(VideoFrame)? onFrame,
  }) async {
    // What a read from this position would speak, resolved exactly as the read
    // resolves it: the same sentence split, the same language per paragraph,
    // the same picked voice (FR-004, A5) — and, since 014, the same roles and
    // the same per-role voices (FR-018). 015's switch decides whether a
    // comment's utterances exist at all (SC-008); the block paints the comment
    // either way (the plan's own `comments` below).
    final sentences = await videoSentencesFrom(
      content: content,
      position: position,
      loadVoice: loadVoice,
      mode: mode,
      removed: removed,
      picks: picks,
      commentsRead: commentsRead,
      loadInstalled: loadInstalled,
    );
    if (sentences.isEmpty) {
      throw const VideoRenderException(
        VideoFailureKind.nothingToRead,
        'Nothing to read from here',
      );
    }

    // The only files this render may delete: what it wrote itself.
    final written = <String>[];

    try {
      // ---- pass 1: the voice is the clock --------------------------------
      // Timed for the walk's own spike S2 (quickstart 36): SC-006 asks how long
      // a render takes *and* which side is the bottleneck, and the app is the
      // only thing that knows where its own time went.
      final synthWatch = Stopwatch()..start();
      final audioMs = <int>[];
      for (var i = 0; i < sentences.length; i++) {
        if (_cancelled) return await _abandon(written);
        final sentence = sentences[i];
        final path = '${workDir.path}/sentence_$i.wav';
        written.add(path);
        try {
          await synthesizer.synthesizeToFile(
            text: sentence.text,
            filePath: path,
            language: sentence.language,
            voice: sentence.voice,
          );
        } catch (e) {
          throw VideoRenderException(
            VideoFailureKind.engine,
            'sentence ${i + 1} of ${sentences.length}: $e',
          );
        }
        if (_cancelled) return await _abandon(written);
        final ms = wavDurationMsOf(await File(path).readAsBytes());
        if (ms == null) {
          throw VideoRenderException(
            VideoFailureKind.unreadableAudio,
            'sentence ${i + 1}: the engine wrote a file whose length cannot be '
                'read, so the timeline cannot be trusted',
          );
        }
        audioMs.add(ms);
        onProgress?.call(VideoRenderProgress(
          pass: VideoRenderPass.synthesising,
          done: i + 1,
          total: sentences.length,
        ));
      }

      synthWatch.stop();
      final plan = buildVideoPlan(
        sentences: sentences,
        audioMs: audioMs,
        aspect: aspect,
        // 015: the block is built from the content's own comments, not from the
        // read's speeches, so it paints a comment whether or not it was read
        // (research D8).
        comments: commentsOf(content),
      );

      // ---- pass 2: the picture follows the clock --------------------------
      // The reader's pictures are copied in first, so the frames that draw them
      // are painted after the copies exist and the copies go with everything
      // else this render deletes however it ends (D15).
      final schedule = await _preparePictures(plan, written);
      // The schedule in the video's own frames: the device row (quickstart 49)
      // samples a frame inside each picture's range and at every seam between
      // two, and the ranges exist nowhere else it can read them (FR-026). A
      // picture the video is too short to reach is listed as `-`.
      debugPrint('klhu render pictures=${schedule.pictures.length}'
          ' ranges=${schedule.pictures.map((p) => p.isDrawn ? '${p.startFrame}..${p.endFrame}' : '-').join(',')}'
          ' sentences=${sentences.length}');
      // One decoded picture per copy, kept for the whole pass: the frames handed
      // to the reader's preview hold them, so their lifetime is the frames' own
      // — a handful of pictures, not one image per frame.
      final decoded = <String, ui.Image>{};
      final painter = VideoPainter(
        plan: plan,
        readingStyle: readingStyle,
        background: background,
      );

      // One picture per **visual state**: each sentence at each line step its
      // text needs (D14) — and the end hold, which extends the last sentence's
      // last step rather than painting an identical frame again (FR-008). A sentence's run of frames also covers the gap that follows
      // it, so the picture behind it stays put until the next sentence starts;
      // and since the schedule shares the *sentences* (FR-026), that is exactly
      // where the picture changes — no picture boundary lands mid-run.
      final runs = <({VideoSlot slot, int frames, double progress})>[];
      for (var i = 0; i < plan.slots.length; i++) {
        final slot = plan.slots[i];
        final span = _spanFrames(plan, i);
        if (slot.kind == VideoSlotKind.hold && runs.isNotEmpty) {
          final last = runs.removeLast();
          runs.add((
            slot: last.slot,
            frames: last.frames + span,
            progress: last.progress,
          ));
        } else {
          runs.addAll(_stepsOf(painter, slot, span));
        }
      }

      // One audio segment per **utterance** inside its slot's frames, in order
      // (015 D8/T021): a comment rides its sentence's slot, so the flat list the
      // platform half already takes gains a segment per comment. A segment's
      // length comes from the timeline, not from the file — the frames are the
      // muxer's clock, and a slot's last utterance absorbs the gap after it
      // (FR-016).
      final segments = <VideoAudioSegment>[];
      for (var i = 0; i < plan.slots.length; i++) {
        final slot = plan.slots[i];
        final spanUs = _spanFrames(plan, i) * 1000000 ~/ plan.fps;
        if (slot.audio.isEmpty) {
          // The end hold: the plan's own silence, as before 015.
          segments.add(VideoAudioSegment(path: null, durationUs: spanUs));
          continue;
        }
        var usedUs = 0;
        for (var u = 0; u < slot.audio.length; u++) {
          final index = slot.audio[u];
          final isLast = u == slot.audio.length - 1;
          final us = isLast ? spanUs - usedUs : audioMs[index] * 1000;
          segments.add(VideoAudioSegment(path: written[index], durationUs: us));
          usedUs += us;
        }
      }

      try {
        await encoder.start(
          width: plan.width,
          height: plan.height,
          fps: plan.fps,
          totalFrames: plan.totalFrames,
          audio: segments,
        );
      } on VideoEncodeException catch (e) {
        throw VideoRenderException(VideoFailureKind.encoder, e.message);
      }
      if (_cancelled) return await _abandon(written);

      final paintWatch = Stopwatch()..start();
      // The two costs inside pass 2, kept apart so S2 can name the bottleneck
      // rather than guess at it: `paint` is Dart rasterising the frame, `send`
      // is the PNG encode plus the encoder's own conversion of it.
      var paintMs = 0;
      var sendMs = 0;
      for (var i = 0; i < runs.length; i++) {
        if (_cancelled) return await _abandon(written);
        final run = runs[i];
        final paintStep = Stopwatch()..start();
        final frame = await painter.paint(
          slot: run.slot,
          progress: run.progress,
          picture: await _pictureFor(run.slot, schedule, decoded),
        );
        paintStep.stop();
        paintMs += paintStep.elapsedMilliseconds;
        // Which slot this picture is for, in the frames' own terms: the device
        // row (quickstart 32) samples the file at these starts and pairs them
        // with the page, and it has nothing else to go on.
        debugPrint('klhu render slot=${plan.slots.indexOf(run.slot)}'
            '/${plan.slots.length} frame=${run.slot.startFrame}'
            '/${plan.totalFrames} kind=${run.slot.kind.name} frames=${run.frames}'
            ' scroll=${frame.scrollLines}'
            ' picture=${frame.picture == null ? "none" : "yes"}'
            ' tone=${frame.tone?.name ?? "-"}'
            // 014 D10: beside the fields 012's own walk reads, so every
            // existing check keeps matching. The device row has nothing else
            // to go on to say which voice read a turn.
            ' role=${run.slot.role ?? "narration"}'
            ' span=${run.slot.start}..${run.slot.end} text=${frame.paintedText.length}');
        // Shown and written from the same picture, in that order (FR-020).
        onFrame?.call(frame);
        final sendStep = Stopwatch()..start();
        try {
          await encoder.addFrame(await pngBytesOf(frame.image),
              repeat: run.frames);
        } on VideoEncodeException catch (e) {
          throw VideoRenderException(VideoFailureKind.encoder, e.message);
        }
        sendStep.stop();
        sendMs += sendStep.elapsedMilliseconds;
        onProgress?.call(VideoRenderProgress(
          pass: VideoRenderPass.painting,
          done: i + 1,
          total: runs.length,
        ));
      }
      if (_cancelled) return await _abandon(written);
      paintWatch.stop();

      final finishWatch = Stopwatch()..start();
      try {
        final file = await encoder.finish();
        // The audio has been muxed into the video; the files it came from are
        // no longer anyone's (the video itself is the encoder's, and stays).
        await _delete(written);
        finishWatch.stop();
        // Spike S2's own evidence (quickstart 36): SC-006 asks for the render's
        // time *and* which side of it is the bottleneck, and only the app knows
        // where its own time went. One line, so the walk's regex stays one line.
        debugPrint('klhu render time synth=${synthWatch.elapsedMilliseconds}ms'
            ' paint=${paintMs}ms send=${sendMs}ms'
            ' total=${paintWatch.elapsedMilliseconds}ms'
            ' finish=${finishWatch.elapsedMilliseconds}ms'
            ' sentences=${sentences.length} pictures=${runs.length}'
            ' frames=${plan.totalFrames}');
        return VideoRenderResult(
          path: file.path,
          durationMs: file.durationMs,
          sizeBytes: file.sizeBytes,
          totalFrames: plan.totalFrames,
        );
      } on VideoEncodeException catch (e) {
        throw VideoRenderException(VideoFailureKind.encoder, e.message);
      }
    } on VideoRenderException {
      await _abandon(written);
      rethrow;
    }
  }

  /// How many frames slot [index] occupies: its own, plus the gap that follows
  /// it, which the timeline already folded into the next slot's start.
  int _spanFrames(VideoPlan plan, int index) =>
      index + 1 < plan.slots.length
          ? plan.slots[index + 1].startFrame - plan.slots[index].startFrame
          : plan.slots[index].frames;

  /// Copies the reader's pictures into this render's working directory and lays
  /// out the schedule over the plan's sentences (FR-026, D15).
  ///
  /// The copies are recorded in [written] the moment they exist, so every ending
  /// — a finish, a cancel, a failure — takes them with the render's own files.
  Future<PictureSchedule> _preparePictures(
    VideoPlan plan,
    List<String> written,
  ) async {
    if (pictures.isEmpty) return PictureSchedule.none;
    final copies = await copyPictures(pictures: pictures, workDir: workDir);
    written.addAll(copies);
    return buildPictureSchedule(plan: plan, paths: copies);
  }

  /// One run per line step of [slot]'s text: the block's own positions, each
  /// holding an equal share of the slot's frames (D14).
  ///
  /// A step that gets no frame at all is not written — it is a picture nobody
  /// could see — and the shares always add up to [frames], so the video is the
  /// timeline's length whether the block had room for every step or not.
  List<({VideoSlot slot, int frames, double progress})> _stepsOf(
    VideoPainter painter,
    VideoSlot slot,
    int frames,
  ) {
    final positions = painter.scrollSteps(slot) + 1;
    final each = frames ~/ positions;
    final extra = frames % positions;
    return [
      for (var position = 0; position < positions; position++)
        if (each + (position < extra ? 1 : 0) > 0)
          (
            slot: slot,
            frames: each + (position < extra ? 1 : 0),
            progress: position / positions,
          ),
    ];
  }

  /// The picture covering [slot]'s frames, decoded once and reused: the schedule
  /// changes a picture only where a sentence changes (FR-026), so a slot's whole
  /// run reads the same file — and one decode per picture, not per frame.
  Future<ui.Image?> _pictureFor(
    VideoSlot slot,
    PictureSchedule schedule,
    Map<String, ui.Image> decoded,
  ) async {
    final scheduled = schedule.at(slot.startFrame);
    if (scheduled == null) return null;
    final already = decoded[scheduled.path];
    if (already != null) return already;
    final codec = await ui.instantiateImageCodec(
      await File(scheduled.path).readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    decoded[scheduled.path] = frame.image;
    return frame.image;
  }

  /// Stop the encoder, delete everything this render wrote, and report a
  /// cancelled render — which is not a failure: the reader asked for it.
  Future<VideoRenderResult> _abandon(List<String> written) async {
    try {
      await encoder.cancel();
    } catch (_) {
      // A cancelled render has no video to protect; the partial file is the
      // encoder's own to remove (contract video-frame-protocol.md).
    }
    await _delete(written);
    return const VideoRenderResult(cancelled: true);
  }

  Future<void> _delete(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // The cache directory's own sweep is the backstop.
        }
      }
    }
  }
}
