/// The renderer (spec 012 US1): quickstart scenarios 13–17 — a synthesis call
/// per sentence in that sentence's own voice, the picture published being the
/// picture encoded, progress that follows the timeline, cancellation that
/// leaves nothing behind, and the failure paths.
///
/// This file defines the API it tests: `lib/video_renderer.dart` and
/// `lib/platform/video_encoder.dart` do not exist yet (T007 is written before
/// T011/T013/T014 implement them). The fake engine writes REAL RIFF/WAVE files
/// of a chosen length, so the renderer's own length read (T003's parser) is
/// exercised rather than mocked away.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_renderer.dart';
import 'package:klhu/voice_store.dart';

/// Two paragraphs, three sentences, two languages.
const _content = 'One two. Three four.\n\nSí, cinco.';

const _zhVoice =
    VoiceChoice(language: 'zh-Hans', name: 'zh-CN-language', locale: 'zh-CN');

/// A RIFF/WAVE PCM 16-bit mono file of exactly [ms] milliseconds.
Uint8List wavOf(int ms, {int rate = 24000}) {
  final frames = (ms * rate / 1000).round();
  final data = frames * 2;
  final bytes = BytesBuilder();
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) =>
      bytes.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  void u16(int v) => bytes.add([v & 0xff, (v >> 8) & 0xff]);

  ascii('RIFF');
  u32(36 + data);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  ascii('data');
  u32(data);
  bytes.add(Uint8List(data));
  return bytes.toBytes();
}

/// A file that is not RIFF at all (what another engine might hand over).
Uint8List notRiff() => Uint8List.fromList('ID3\u0004\u0000\u0000\u0000'.codeUnits);

/// A RIFF header that claims more audio than the file carries.
Uint8List truncatedWav() => wavOf(1000).sublist(0, 60);

/// The engine, writing files of chosen length (or chosen bytes, to break them).
///
/// Implements only the render's own interface ([SentenceSynthesizer]); the
/// engine log's own failures surface as [ReaderException] because that is what
/// the real implementation raises.
class FakeSynthEngine implements SentenceSynthesizer {
  FakeSynthEngine({this.msPerCall = const [1000, 500, 250], this.bytesOf});

  final List<int> msPerCall;
  Uint8List Function(int index)? bytesOf;

  /// Every call in the order the renderer made it.
  final calls = <({String text, String file, String language, VoiceChoice? voice})>[];

  /// Which call to fail on, 0-based; null never fails.
  int? failOn;
  int? hangOn;
  Completer<void>? _parked;
  bool hang = false;

  void release() {
    hang = false;
    _parked?.complete();
    _parked = null;
  }

  @override
  Future<void> synthesizeToFile({
    required String text,
    required String filePath,
    required String language,
    VoiceChoice? voice,
  }) async {
    final index = calls.length;
    calls.add((text: text, file: filePath, language: language, voice: voice));
    if (hang || hangOn == index) {
      hang = true;
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
      if (failOn == index) throw ReaderException('engine gave up');
    } else if (failOn == index) {
      throw ReaderException('engine gave up');
    }
    await File(filePath).writeAsBytes(
        bytesOf?.call(index) ?? wavOf(msPerCall[index % msPerCall.length]));
  }
}

/// The encoder, recording everything it is handed.
class FakeEncoder implements VideoEncoder {
  final startCalls = <({
    int width,
    int height,
    int fps,
    int totalFrames,
    List<VideoAudioSegment> audio,
  })>[];

  final frames = <({Uint8List png, int repeat})>[];
  int finishes = 0;
  int cancels = 0;

  /// Which `start` or `addFrame` call to park on, 0-based.
  int? hangOnStart;
  int? hangOnFrame;
  Completer<void>? _parked;
  bool _hanging = false;

  /// Which `start` or `addFrame` call to fail on.
  int? failStart;
  int? failFrame;

  void release() {
    _hanging = false;
    _parked?.complete();
    _parked = null;
  }

  Future<void> _maybePark(int index, bool isStart) async {
    final hang = isStart ? hangOnStart == index : hangOnFrame == index;
    final fail = isStart ? failStart == index : failFrame == index;
    if (hang || _hanging) {
      _hanging = true;
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
    }
    if (fail) throw const VideoEncodeException('codec refused');
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int totalFrames,
    required List<VideoAudioSegment> audio,
  }) async {
    startCalls.add((
      width: width,
      height: height,
      fps: fps,
      totalFrames: totalFrames,
      audio: audio,
    ));
    await _maybePark(startCalls.length - 1, true);
  }

  @override
  Future<void> addFrame(Uint8List png, {required int repeat}) async {
    await _maybePark(frames.length, false);
    frames.add((png: png, repeat: repeat));
  }

  @override
  Future<VideoFile> finish() async {
    finishes++;
    final path = '${(workDir ?? Directory.systemTemp).path}/klhu_video_render.mp4';
    // A real file, so a caller can check the render produced one.
    await File(path).writeAsBytes(List<int>.filled(sizeBytes, 0));
    return VideoFile(path: path, durationMs: durationMs, sizeBytes: sizeBytes);
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  /// Where `finish` says its file is; the test points this at its own temp dir.
  Directory? workDir;
  int sizeBytes = 1024;
  int durationMs = 7066;
}

void main() {
  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('klhu_video_test');
  });
  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  VideoRenderer rendererFor(
    FakeSynthEngine engine,
    FakeEncoder encoder, {
    VideoAspect aspect = VideoAspect.landscape,
  }) {
    encoder.workDir = work;
    return VideoRenderer(
      synthesizer: engine,
      encoder: encoder,
      workDir: work,
      aspect: aspect,
      title: 'Mixed',
      readingStyle: const TextStyle(fontSize: 14, color: Color(0xFFF2F2F2)),
      background: const Color(0xFF101014),
      highlight: const Color(0xFFFFFF00),
    );
  }

  Future<VideoRenderResult> run(
    FakeSynthEngine engine,
    FakeEncoder encoder, {
    int position = 0,
    List<VideoRenderProgress>? progress,
    List<VideoFrame>? published,
  }) =>
      rendererFor(engine, encoder).render(
        content: _content,
        position: position,
        loadVoice: (language) async =>
            language == 'zh-Hans' ? _zhVoice : null,
        onProgress: progress?.add,
        onFrame: published?.add,
      );

  group('13. one synthesis call per sentence, in its own voice', () {
    test('every sentence of the plan is written to its own file', () async {
      final engine = FakeSynthEngine();
      await run(engine, FakeEncoder());

      expect(engine.calls.map((c) => c.text).toList(),
          ['One two.', 'Three four.', 'Sí, cinco.']);
      expect(engine.calls.map((c) => c.language).toList(), ['en', 'en', 'es']);
      expect(engine.calls.map((c) => c.voice).toList(), [null, null, null]);
      // One file per sentence, all inside the working directory, all distinct.
      expect(engine.calls.map((c) => c.file).toSet().length, 3);
      for (final call in engine.calls) {
        expect(call.file, startsWith(work.path));
      }
    });

    test('the picked voice reaches the sentences of its own language', () async {
      const content = 'One two.\n\n清晨的阳光。鸟儿歌唱。';
      final engine = FakeSynthEngine();
      await rendererFor(engine, FakeEncoder()).render(
        content: content,
        position: 0,
        loadVoice: (language) async => language == 'zh-Hans' ? _zhVoice : null,
      );
      expect(engine.calls.map((c) => c.language).toList(),
          ['en', 'zh-Hans', 'zh-Hans']);
      expect(engine.calls.map((c) => c.voice).toList(),
          [null, _zhVoice, _zhVoice]);
    });

    test('a read of two sentences only writes those two', () async {
      final engine = FakeSynthEngine();
      await run(engine, FakeEncoder(), position: _content.indexOf('Three four.'));

      expect(engine.calls.map((c) => c.text).toList(),
          ['Three four.', 'Sí, cinco.']);
      expect(engine.calls.length, 2);
    });
  });

  group('14. the picture shown is the frame written (SC-014)', () {
    test('the encoder gets the bytes of the frame that was published',
        () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      final published = <VideoFrame>[];
      await run(engine, encoder, published: published);

      expect(published, isNotEmpty);
      expect(encoder.frames.length, published.length);

      for (var i = 0; i < published.length; i++) {
        // Recomputed from the published picture's own image: if the encoder was
        // handed anything else, it was not the picture the reader saw.
        expect(encoder.frames[i].png, await pngBytesOf(published[i].image),
            reason: 'frame $i was not the picture the encoder received');
      }
    });

    test('the plan the encoder was given is the timeline that was measured',
        () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      await run(engine, encoder);

      final start = encoder.startCalls.single;
      expect(start.width, VideoAspect.landscape.width);
      expect(start.height, VideoAspect.landscape.height);
      expect(start.fps, VideoAspect.landscape.fps);

      // One audio segment per slot, in the plan's order: the title card and the
      // end hold are silence, and every sentence's segment is its own audio plus
      // the gap that follows it — in microseconds, because the frames are the
      // muxer's clock.
      expect(start.audio.map((a) => a.path == null).toList(),
          [true, false, false, false, true]);
      expect(start.audio.map((a) => a.durationUs).toList(),
          [2500000, 1400000, 900000, 266666, 2000000]);

      // The frame repeats add up to exactly the plan's length.
      expect(encoder.frames.fold<int>(0, (sum, f) => sum + f.repeat),
          start.totalFrames);
      expect(start.totalFrames, greaterThan(0));
    });

    test('a frame is not painted twice for the same picture', () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      final published = <VideoFrame>[];
      await run(engine, encoder, published: published);

      // Title card, three sentences, and the hold — which is the last
      // sentence's picture held, not a new one (FR-008).
      expect(published.length, 4);
      expect(encoder.frames.length, 4);
      expect(encoder.frames.last.repeat, 68); // 8 frames of sentence + the hold
    });
  });

  group('15. progress follows the timeline, and pass 1 comes first', () {
    test('every synthesis is reported before the first frame is painted',
        () async {
      final engine = FakeSynthEngine();
      final progress = <VideoRenderProgress>[];
      await run(engine, FakeEncoder(), progress: progress);

      final passes = progress.map((p) => p.pass).toList();
      final firstPaint = passes.indexOf(VideoRenderPass.painting);
      expect(firstPaint, greaterThan(0));
      expect(passes.sublist(firstPaint).toSet(), {VideoRenderPass.painting});
      expect(passes.sublist(0, firstPaint).toSet(), {VideoRenderPass.synthesising});

      final synth = progress.sublist(0, firstPaint);
      expect(synth.map((p) => p.done).toList(), [1, 2, 3]);
      expect(synth.map((p) => p.total).toSet(), {3});

      final paint = progress.sublist(firstPaint);
      expect(paint.map((p) => p.done).toList(), [1, 2, 3, 4]);
      expect(paint.map((p) => p.total).toSet(), {4});
      // Within a pass the count only ever moves forward; each pass counts its
      // own units (sentences, then frames), so the two do not compare.
      for (var i = 1; i < progress.length; i++) {
        if (progress[i].pass == progress[i - 1].pass) {
          expect(progress[i].done, greaterThanOrEqualTo(progress[i - 1].done));
        }
      }
    });
  });

  group('16. cancelling leaves nothing', () {
    test('cancelling before the render starts writes nothing', () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      final renderer = rendererFor(engine, encoder);
      renderer.cancel();
      final result = await renderer.render(content: _content, position: 0,
          loadVoice: (_) async => null);

      expect(result.cancelled, isTrue);
      expect(engine.calls, isEmpty);
      expect(encoder.startCalls, isEmpty);
      expect(work.listSync(), isEmpty);
    });

    test('cancelling during the first synthesis leaves an empty directory',
        () async {
      final engine = FakeSynthEngine()..hangOn = 0;
      final encoder = FakeEncoder();
      final renderer = rendererFor(engine, encoder);
      final future = renderer.render(content: _content, position: 0,
          loadVoice: (_) async => null);
      await Future<void>.delayed(Duration.zero);
      renderer.cancel();
      engine.release();
      final result = await future;

      expect(result.cancelled, isTrue);
      expect(encoder.startCalls, isEmpty);
      expect(work.listSync(), isEmpty);
    });

    test('cancelling during painting stops the encoder and cleans up', () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder()..hangOnFrame = 0;
      final renderer = rendererFor(engine, encoder);
      final future = renderer.render(content: _content, position: 0,
          loadVoice: (_) async => null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      renderer.cancel();
      encoder.release();
      final result = await future;

      expect(result.cancelled, isTrue);
      expect(encoder.cancels, greaterThan(0));
      expect(encoder.finishes, 0);
      expect(work.listSync(), isEmpty);
      expect(File(result.path).existsSync(), isFalse);
    });

    test('cancelling during the encoder\'s start stops it too', () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder()..hangOnStart = 0;
      final renderer = rendererFor(engine, encoder);
      final future = renderer.render(content: _content, position: 0,
          loadVoice: (_) async => null);
      await Future<void>.delayed(Duration.zero);
      renderer.cancel();
      encoder.release();
      final result = await future;

      expect(result.cancelled, isTrue);
      expect(encoder.cancels, greaterThan(0));
      expect(work.listSync(), isEmpty);
    });
  });

  group('17. failures are reported, not guessed at', () {
    test('an engine that throws fails the render and cleans up', () async {
      final engine = FakeSynthEngine()..failOn = 1;
      final encoder = FakeEncoder();
      await expectLater(
        run(engine, encoder),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.engine)),
      );
      expect(encoder.finishes, 0);
      expect(work.listSync(), isEmpty);
    });

    test('audio that is not RIFF fails rather than guessing a length', () async {
      final engine = FakeSynthEngine()..bytesOf = (_) => notRiff();
      await expectLater(
        run(engine, FakeEncoder()),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.unreadableAudio)),
      );
      expect(work.listSync(), isEmpty);
    });

    test('a header that promises more audio than the file holds fails too',
        () async {
      final engine = FakeSynthEngine()..bytesOf = (_) => truncatedWav();
      await expectLater(
        run(engine, FakeEncoder()),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.unreadableAudio)),
      );
    });

    test('an encoder that refuses to start fails the render', () async {
      final encoder = FakeEncoder()..failStart = 0;
      await expectLater(
        run(FakeSynthEngine(), encoder),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.encoder)),
      );
      expect(encoder.finishes, 0);
      expect(work.listSync(), isEmpty);
    });

    test('an encoder that fails mid-painting fails the render', () async {
      final encoder = FakeEncoder()..failFrame = 1;
      await expectLater(
        run(FakeSynthEngine(), encoder),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.encoder)),
      );
      expect(encoder.finishes, 0);
      expect(work.listSync(), isEmpty);
    });

    test('a content with nothing to read never reaches the encoder', () async {
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      await expectLater(
        rendererFor(engine, encoder).render(content: '   \n\n  ', position: 0,
            loadVoice: (_) async => null),
        throwsA(isA<VideoRenderException>()
            .having((e) => e.kind, 'kind', VideoFailureKind.nothingToRead)),
      );
      expect(engine.calls, isEmpty);
      expect(encoder.startCalls, isEmpty);
    });
  });
}
