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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_renderer.dart';
import 'package:klhu/voice_store.dart';

/// Two paragraphs, three sentences, two languages.
const _content = 'One two. Three four.\n\nSí, cinco.';

/// One sentence, far taller than any frame's text area: the scroll's own case
/// (quickstart 46). Built rather than spelled out — it only has to be long.
final String _tallText =
    List.filled(60, 'the quiet river runs beneath the old stone bridge').join(' ');
final String _tallContent = _tallText;

/// A real PNG of one solid colour: the picks the reader makes are files, so the
/// renderer is handed bytes and decodes them rather than being given a picture.
Future<Uint8List> _pngOf(Color colour, {int side = 8}) async {
  final bytes = Uint8List(side * side * 4);
  final r = (colour.r * 255).round();
  final g = (colour.g * 255).round();
  final b = (colour.b * 255).round();
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = r;
    bytes[i + 1] = g;
    bytes[i + 2] = b;
    bytes[i + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      bytes, side, side, ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Where [_picked] stores its pictures: one directory for the whole file.
Directory? _storedPicks;

/// A picture the reader chose and the page stored at the pick (FR-025, D18): the
/// render is handed the app's own file, never the picker's handle to read again.
HeldPicture _picked(String name, Uint8List png) {
  final dir = _storedPicks ??=
      Directory.systemTemp.createTempSync('klhu_stored_picks');
  final path = '${dir.path}${Platform.pathSeparator}$name';
  File(path).writeAsBytesSync(png);
  return HeldPicture(name: name, path: path);
}

/// Whether every published frame's scroll step is at or below the one before it:
/// a block never goes back up inside its own slot (D14).
bool scrollsAreOrdered(List<VideoFrame> published) {
  var previous = -1;
  for (final frame in published) {
    if (frame.scrollLines < previous) return false;
    previous = frame.scrollLines;
  }
  return true;
}

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
    List<HeldPicture> pictures = const [],
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
      pictures: pictures,
    );
  }

  /// The picks' copies still in the working directory: what the render wrote
  /// there for the pictures, and what has to be gone however it ended.
  Set<String> copiesIn() => {
        for (final entry in work.listSync())
          if (entry.path.contains('picture_')) entry.path,
      };

  Future<VideoRenderResult> run(
    FakeSynthEngine engine,
    FakeEncoder encoder, {
    int position = 0,
    String content = _content,
    List<HeldPicture> pictures = const [],
    List<VideoRenderProgress>? progress,
    List<VideoFrame>? published,
  }) =>
      rendererFor(engine, encoder, pictures: pictures).render(
        content: content,
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

  group('46-48. the amended picture reaches the video', () {
    test('a tall sentence is painted once per line step, and the repeats still '
        'add up', () async {
      // 40 s of audio for one sentence: 1200 frames at 30 fps, which is far more
      // than the block needs to reach its bottom, so every step is its own
      // picture (FR-029, D14).
      final engine = FakeSynthEngine(msPerCall: const [40000]);
      final encoder = FakeEncoder();
      final published = <VideoFrame>[];
      final result =
          await run(engine, encoder, content: _tallContent, published: published);

      expect(published.first.picture, isNull,
          reason: 'the title card is the app\'s own card (FR-008)');
      // The sentence's own pictures, in order: one step further down each time,
      // never back up, starting at the top of the block and ending at its last
      // step (the card's own frame is not a step of it).
      final scrolls = [
        for (final frame in published.where((frame) => frame.slot.isSentence))
          frame.scrollLines,
      ];
      expect(scrolls.first, 0, reason: 'the block starts at the top');
      expect(scrolls.length, greaterThan(3), reason: 'the sentence must scroll');
      for (var i = 1; i < scrolls.length; i++) {
        expect(scrolls[i], greaterThan(scrolls[i - 1]),
            reason: 'each picture is one step further down, never back up');
      }

      // The repeats are the video's frames: one picture per visual state, and
      // nothing gained or lost against the timeline (FR-016/SC-014).
      expect(encoder.frames, hasLength(published.length));
      expect(
        encoder.frames.fold<int>(0, (sum, frame) => sum + frame.repeat),
        result.totalFrames,
      );
    });

    test('a slot with fewer frames than line steps shows the steps it has room '
        'for', () async {
      // One second of audio is 30 frames at 30 fps — fewer than the steps this
      // sentence needs. A step with no frame of its own is a picture nobody
      // could see, so it is not written: the video is the timeline's length
      // either way (a real sentence of this many lines is minutes of speech, so
      // this arm is the degenerate case, not the normal one).
      final engine = FakeSynthEngine(msPerCall: const [1000]);
      final encoder = FakeEncoder();
      final published = <VideoFrame>[];
      final result =
          await run(engine, encoder, content: _tallContent, published: published);

      expect(published.length, lessThan(result.totalFrames));
      expect(scrollsAreOrdered(published), isTrue);
      expect(
        encoder.frames.fold<int>(0, (sum, frame) => sum + frame.repeat),
        result.totalFrames,
      );
      // It did scroll — the steps it had room for, not one still picture.
      final sentenceFrames =
          published.where((frame) => frame.slot.isSentence).toList();
      expect(sentenceFrames.length, greaterThan(3));
    });

    test('each frame carries the picture the schedule puts there', () async {
      final red = await _pngOf(const Color(0xFFFF0000));
      final green = await _pngOf(const Color(0xFF00FF00));
      final pictures = [_picked('first.png', red), _picked('second.png', green)];
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      final published = <VideoFrame>[];
      await run(engine, encoder, pictures: pictures, published: published);

      expect(published.first.picture, isNull,
          reason: 'the title card keeps the plain background');
      // Three sentences and two pictures: the first covers sentences 1 and 2,
      // the second takes sentence 3 and the end hold (FR-026 — pictures change
      // where sentences change).
      // Keyed by the slot itself: `slot.sentence` is the sentence's index *in
      // its paragraph*, and this content has two paragraphs, so two slots would
      // share a key.
      final bySlot = <int, ui.Image>{};
      for (final frame in published.where((frame) => frame.slot.isSentence)) {
        final picture = frame.picture;
        expect(picture, isNotNull,
            reason: 'the sentence at frame ${frame.slot.startFrame} was painted '
                'without its picture');
        final earlier = bySlot[frame.slot.startFrame];
        if (earlier != null) {
          expect(identical(earlier, picture), isTrue,
              reason: 'one decoded picture per sentence, not one per frame');
        }
        bySlot[frame.slot.startFrame] = picture!;
      }
      final starts = bySlot.keys.toList()..sort();
      expect(starts, hasLength(3), reason: 'three sentences');
      // Two pictures over three sentences: the extra sentence goes to the
      // earlier picture (FR-026), so sentences 1 and 2 share a picture and
      // sentence 3 has the other.
      expect(identical(bySlot[starts[0]], bySlot[starts[1]]), isTrue);
      expect(identical(bySlot[starts[1]], bySlot[starts[2]]), isFalse);
      expect(bySlot[starts[0]]!.width, 8,
          reason: 'the pictures are the files the reader picked, decoded');
    });

    test('no frame is written before the copies exist', () async {
      final red = await _pngOf(const Color(0xFFFF0000));
      final pictures = [_picked('first.png', red)];
      final engine = FakeSynthEngine();
      final encoder = FakeEncoder();
      final renderer = rendererFor(engine, encoder, pictures: pictures);

      final seenAtEachFrame = <int>[];
      await renderer.render(
        content: _content,
        position: 0,
        loadVoice: (language) async => language == 'zh-Hans' ? _zhVoice : null,
        onFrame: (frame) {
          // Every frame is published after the copies exist — the title card's
          // picture is the plain background, so only the sentences are checked
          // for one, but the copies are checked on *every* frame.
          seenAtEachFrame.add(copiesIn().length);
          if (frame.slot.isSentence) {
            expect(frame.picture, isNotNull,
                reason: 'sentence ${frame.slot.sentence} was painted without '
                    'its picture');
          }
        },
      );

      expect(seenAtEachFrame, isNotEmpty);
      expect(seenAtEachFrame.every((count) => count == 1), isTrue,
          reason: 'the copy has to exist before the frame that draws it');
    });

    test('the copies are gone however the render ended', () async {
      final red = await _pngOf(const Color(0xFFFF0000));
      final pictures = [_picked('first.png', red)];

      // Finished.
      await run(FakeSynthEngine(), FakeEncoder(), pictures: pictures);
      expect(copiesIn(), isEmpty, reason: 'after a finish');

      // Cancelled: the reader stops it part-way through pass 2.
      final cancelled = FakeEncoder();
      final renderer =
          rendererFor(FakeSynthEngine(), cancelled, pictures: pictures);
      var frames = 0;
      final result = await renderer.render(
        content: _content,
        position: 0,
        loadVoice: (language) async => language == 'zh-Hans' ? _zhVoice : null,
        onFrame: (frame) {
          if (++frames == 2) renderer.cancel();
        },
      );
      expect(result.cancelled, isTrue);
      expect(copiesIn(), isEmpty, reason: 'after a cancel');

      // Refused by the encoder: the render fails where no video can exist.
      final refused = FakeEncoder()..failFrame = 1;
      await expectLater(
        run(FakeSynthEngine(), refused, pictures: pictures),
        throwsA(isA<VideoRenderException>()),
      );
      expect(copiesIn(), isEmpty, reason: 'after a failure');
    });
  });
}
