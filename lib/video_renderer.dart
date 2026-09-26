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

import 'package:flutter/material.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
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
    required this.title,
    required this.readingStyle,
    required this.background,
    required this.highlight,
  });

  final SentenceSynthesizer synthesizer;
  final VideoEncoder encoder;

  /// Where the per-sentence audio and the encoder's working file live. The
  /// renderer deletes every file it wrote here and nothing else.
  final Directory workDir;

  final VideoAspect aspect;

  /// The content's name, as the title card shows it.
  final String title;

  /// The reader's own reading style (011's seam) and the frame's colours.
  final TextStyle readingStyle;
  final Color background;
  final Color highlight;

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
    void Function(VideoRenderProgress)? onProgress,
    void Function(VideoFrame)? onFrame,
  }) async {
    // What a read from this position would speak, resolved exactly as the read
    // resolves it: the same sentence split, the same language per paragraph,
    // the same picked voice (FR-004, A5).
    final sentences = await videoSentencesFrom(
      content: content,
      position: position,
      loadVoice: loadVoice,
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

      final plan = buildVideoPlan(
        title: title,
        sentences: sentences,
        audioMs: audioMs,
        aspect: aspect,
      );

      // ---- pass 2: the picture follows the clock --------------------------
      // One picture per distinct visual state: the title card, each sentence,
      // and the end hold — which holds the LAST SENTENCE's picture instead of
      // painting an identical frame again (FR-008). A sentence's run of frames
      // also covers the gap that follows it, so the highlight stays on the
      // sentence just heard until the next one starts.
      final runs = <({VideoSlot slot, int frames})>[];
      for (var i = 0; i < plan.slots.length; i++) {
        final slot = plan.slots[i];
        final span = _spanFrames(plan, i);
        if (slot.kind == VideoSlotKind.hold && runs.isNotEmpty) {
          final last = runs.removeLast();
          runs.add((slot: last.slot, frames: last.frames + span));
        } else {
          runs.add((slot: slot, frames: span));
        }
      }

      // One audio segment per slot, in order, each exactly as long as the
      // frames it occupies — the frames are the muxer's clock, so a segment's
      // length comes from the timeline, not from the file (FR-016).
      final segments = <VideoAudioSegment>[];
      var sentenceIndex = 0;
      for (var i = 0; i < plan.slots.length; i++) {
        final slot = plan.slots[i];
        segments.add(VideoAudioSegment(
          path: slot.isSentence ? written[sentenceIndex++] : null,
          durationUs: _spanFrames(plan, i) * 1000000 ~/ plan.fps,
        ));
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

      final painter = VideoPainter(
        plan: plan,
        readingStyle: readingStyle,
        background: background,
        highlight: highlight,
      );

      for (var i = 0; i < runs.length; i++) {
        if (_cancelled) return await _abandon(written);
        final run = runs[i];
        final frame = await painter.paint(content: content, slot: run.slot);
        // Shown and written from the same picture, in that order (FR-020).
        onFrame?.call(frame);
        try {
          await encoder.addFrame(await pngBytesOf(frame.image),
              repeat: run.frames);
        } on VideoEncodeException catch (e) {
          throw VideoRenderException(VideoFailureKind.encoder, e.message);
        }
        onProgress?.call(VideoRenderProgress(
          pass: VideoRenderPass.painting,
          done: i + 1,
          total: runs.length,
        ));
      }
      if (_cancelled) return await _abandon(written);

      try {
        final file = await encoder.finish();
        // The audio has been muxed into the video; the files it came from are
        // no longer anyone's (the video itself is the encoder's, and stays).
        await _delete(written);
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
