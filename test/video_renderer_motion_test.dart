/// The renderer's two paths (spec 023 US1/US4): quickstart scenario 6 — with the
/// motion on, every frame is its own painted image (`repeat: 1`) and the render
/// says so in one `klhu render motion` line per picture; with it off, the runs
/// are the shipped ones and no such line exists.
///
/// One picture over two sentences is the fixture on purpose: a picture spanning
/// sentences must print **one** motion line whose own frame range covers both,
/// which is the wiring that proves the clock is the picture's and not a slot's.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_renderer.dart';
import 'package:klhu/voice_store.dart';

const _content = 'One two. Three four.';

/// A RIFF/WAVE PCM 16-bit mono file of exactly [ms] milliseconds.
Uint8List _wavOf(int ms, {int rate = 24000}) {
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

class _Engine implements SentenceSynthesizer {
  @override
  Future<void> synthesizeToFile({
    required String text,
    required String filePath,
    required String language,
    VoiceChoice? voice,
  }) async {
    await File(filePath).writeAsBytes(_wavOf(1000));
  }
}

class _Encoder implements VideoEncoder {
  _Encoder(this.workDir);

  final Directory workDir;
  final frames = <({Uint8List png, int repeat})>[];
  final starts = <({
    int width,
    int height,
    int fps,
    int totalFrames,
    List<VideoAudioSegment> audio,
  })>[];

  int get totalFrames => starts.single.totalFrames;

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
    starts.add((
      width: width,
      height: height,
      fps: fps,
      totalFrames: totalFrames,
      audio: audio,
    ));
  }

  @override
  Future<void> addFrame(Uint8List png, {required int repeat}) async {
    frames.add((png: png, repeat: repeat));
  }

  @override
  Future<VideoFile> finish() async {
    final path = '${workDir.path}/klhu_render.mp4';
    await File(path).writeAsBytes(const [0, 1, 2, 3]);
    return VideoFile(path: path, durationMs: 1000, sizeBytes: 4);
  }

  @override
  Future<void> cancel() async {}
}

/// A real PNG at a 4:3 shape, so the motion has room on both axes once the
/// framing is inset.
Future<Uint8List> _png() async {
  const width = 160;
  const height = 120;
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = 40;
    bytes[i + 1] = 90;
    bytes[i + 2] = 160;
    bytes[i + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      bytes, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Directory work;
  late Directory picks;
  late HeldPicture picture;

  setUp(() async {
    work = Directory.systemTemp.createTempSync('klhu_motion_render');
    picks = Directory.systemTemp.createTempSync('klhu_motion_picks');
    final path = '${picks.path}${Platform.pathSeparator}quadrants.png';
    File(path).writeAsBytesSync(await _png());
    picture = HeldPicture(name: 'quadrants.png', path: path);
  });

  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
    if (picks.existsSync()) picks.deleteSync(recursive: true);
  });

  Future<({_Encoder encoder, List<String> logs})> render({
    required bool motion,
  }) async {
    final encoder = _Encoder(work);
    final renderer = VideoRenderer(
      synthesizer: _Engine(),
      encoder: encoder,
      workDir: work,
      aspect: VideoAspect.landscape,
      readingStyle: const TextStyle(fontSize: 14, color: Color(0xFFF2F2F2)),
      background: const Color(0xFF101014),
      pictures: [picture],
      motion: motion,
    );
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final result = await renderer.render(
        content: _content,
        position: 0,
        loadVoice: (_) async => null,
        loadInstalled: () async => const [],
      );
      expect(result.cancelled, isFalse);
      expect(result.path, isNotNull);
    } finally {
      debugPrint = original;
    }
    return (encoder: encoder, logs: logs);
  }

  group('6. the renderer\'s two paths, and the evidence each prints', () {
    test('off: one image per visual state, and no motion line at all', () async {
      final run = await render(motion: false);
      final encoder = run.encoder;
      expect(encoder.frames.any((f) => f.repeat > 1), isTrue,
          reason: 'the shipped path replays an image across its frames');
      expect(
        encoder.frames.fold<int>(0, (sum, f) => sum + f.repeat),
        encoder.totalFrames,
        reason: 'the repeats add up to the timeline',
      );
      expect(encoder.frames.length, lessThan(encoder.totalFrames));
      expect(run.logs.where((l) => l.startsWith('klhu render motion')), isEmpty);
      // One slot line per run, as it has always been.
      expect(
        run.logs.where((l) => l.startsWith('klhu render slot=')).length,
        encoder.frames.length,
      );
    });

    test('on: one painted image per quantum, and one line names every cycle',
        () async {
      final run = await render(motion: true);
      final encoder = run.encoder;
      // D9's ladder, rung (a): one painted image per `motionQuantum` frames —
      // never one per frame, and never more than the quantum.
      expect(encoder.frames.every((f) => f.repeat <= VideoRenderer.motionQuantum),
          isTrue);
      expect(encoder.frames.every((f) => f.repeat >= 1), isTrue);
      expect(
        encoder.frames.fold<int>(0, (sum, f) => sum + f.repeat),
        encoder.totalFrames,
        reason: 'the repeats still add up to the timeline',
      );
      expect(encoder.frames.length,
          (encoder.totalFrames / VideoRenderer.motionQuantum).ceil());

      final motionLines =
          run.logs.where((l) => l.startsWith('klhu render motion')).toList();
      expect(motionLines, hasLength(1),
          reason: 'one line per picture, and the picture spans both sentences');
      final line = motionLines.single;
      expect(line, contains('picture=1'));
      expect(line, contains('frames=0..'), reason: 'its own range, not a slot\'s');
      expect(
        RegExp(r'dirs=[a-zA-Z]+:-?\d+(,[a-zA-Z]+:-?\d+)*$').hasMatch(line),
        isTrue,
        reason: 'every cycle names its direction and its amplitude in pixels: $line',
      );
      // The slot line keeps its fields; with the motion on it is printed once
      // per slot rather than once per painted frame.
      final slotLines =
          run.logs.where((l) => l.startsWith('klhu render slot=')).toList();
      expect(slotLines, hasLength(2),
          reason: 'two sentences, two slot lines — not one per frame');
      expect(slotLines.every((l) => l.contains('tone=') && l.contains('span=')),
          isTrue);
    });

    test('the two paths render one timeline: the same frames, rate and audio',
        () async {
      final off = await render(motion: false);
      final on = await render(motion: true);
      expect(on.encoder.starts.single.totalFrames,
          off.encoder.starts.single.totalFrames);
      expect(on.encoder.starts.single.fps, off.encoder.starts.single.fps);
      expect(on.encoder.starts.single.audio.length,
          off.encoder.starts.single.audio.length);
      expect(
        on.encoder.starts.single.audio.map((s) => s.durationUs).toList(),
        off.encoder.starts.single.audio.map((s) => s.durationUs).toList(),
      );
    });
  });
}
