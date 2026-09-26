/// The reading page during a render (spec 012 US1): quickstart scenarios 25–27
/// — while a render runs the page offers the render's own picture and Stop and
/// nothing else, Stop asks before it acts (and dismissing it does not pause the
/// render), and leaving asks the same way.
///
/// This file defines the page's render seam: `ReadingView` takes the renderer's
/// own collaborators (`synthesizer`, `videoEncoder`, `videoWorkDir`), which is
/// what lets the page's states be driven here. Everything below the page is the
/// REAL pipeline — the real `VideoRenderer`, the real painter and the real
/// timeline — over a fake engine and a fake encoder, so the picture the test
/// finds on screen is the picture the renderer wrote (FR-020).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/video_record.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// Three sentences, two paragraphs — short enough to render in a test, long
/// enough for a render to be observable while it runs.
const _text = 'One two. Three four.\n\nFive six.';

const _presetId = 'preset_short';

/// A RIFF/WAVE PCM 16-bit mono file of exactly [ms] milliseconds (the shape
/// spike S1 measured the engine to write).
Uint8List _wavOf(int ms, {int rate = 24000}) {
  final frames = (ms * rate / 1000).round();
  final data = frames * 2;
  final bytes = BytesBuilder();
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add([
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ]);
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

/// The speech engine: REAL files of a chosen length, and a park the test uses
/// to hold the render at a chosen sentence.
class ShortEngine implements SentenceSynthesizer {
  ShortEngine({this.msPerCall = const [800, 600, 400]});

  final List<int> msPerCall;

  /// The text of every call, in order.
  final calls = <String>[];

  /// The call index to park on (0-based); null parks nowhere.
  int? hangOn;
  bool _hanging = false;
  Completer<void>? _parked;

  /// True while the engine is parked: the render is waiting on a sentence.
  bool get isParked => _parked != null;

  /// Let the parked call finish (and stop parking the ones after it).
  void release() {
    _hanging = false;
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
    calls.add(text);
    if (hangOn == index || _hanging) {
      _hanging = true;
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
    }
    await File(filePath)
        .writeAsBytes(_wavOf(msPerCall[index % msPerCall.length]));
  }
}

/// The encoder: records what it was handed, and can park on a frame so the
/// page can be inspected mid-render.
class RecordingEncoder implements VideoEncoder {
  RecordingEncoder(this.workDir);

  /// Where `finish` says its file is — the test's own temp directory.
  final Directory workDir;

  final startCalls = <({int width, int height, int fps, int totalFrames})>[];
  final frames = <({Uint8List png, int repeat})>[];
  int finishes = 0;
  int cancels = 0;

  /// The `addFrame` call to park on (0-based); null parks nowhere.
  int? hangOnFrame;
  bool _hanging = false;
  Completer<void>? _parked;

  void release() {
    _hanging = false;
    _parked?.complete();
    _parked = null;
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
    ));
  }

  @override
  Future<void> addFrame(Uint8List png, {required int repeat}) async {
    if (hangOnFrame == frames.length || _hanging) {
      _hanging = true;
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
    }
    frames.add((png: png, repeat: repeat));
  }

  @override
  Future<VideoFile> finish() async {
    finishes++;
    // The working copy the review plays: a real file, so "keep promoted it and
    // the working copy went" is a fact about the file system.
    final file = File('${workDir.path}/Klhu reading.mp4')
      ..writeAsBytesSync([0, 0, 0, 1]);
    return VideoFile(
      path: file.path,
      durationMs: 3200,
      sizeBytes: file.lengthSync(),
    );
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

/// The reading engine: this suite drives the render, not a read, so it speaks
/// nothing and only answers the page's stops.
class QuietReader implements Reader {
  @override
  Future<void> speak(String text, String language) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  bool get isSpeaking => false;
  @override
  bool get isPaused => false;
  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => const [];
  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {}
  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

/// A read that never finishes, so the page can be inspected while it speaks and
/// while it is paused (FR-010's two states that are not idle).
class ParkedReader extends QuietReader {
  final _parked = Completer<void>();
  bool started = false;
  bool _paused = false;

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    started = true;
    await _parked.future;
  }

  @override
  bool get isSpeaking => started && !_paused;

  @override
  bool get isPaused => _paused;

  @override
  Future<void> pause() async => _paused = true;

  @override
  Future<void> resume() async => _paused = false;

  @override
  Future<void> stop() async {
    if (!_parked.isCompleted) _parked.complete();
  }
}

/// The platform's file store, in memory (spec 012 US3): it records every call
/// and answers from what the library holds, so a test can say what was kept,
/// shared or deleted, and can remove a file from outside the app.
class PageFileStore implements VideoFileStore {
  /// uri → the name it is in the library under.
  final kept = <String, String>{};
  final keeps =
      <({String workingPath, String displayName, String? previousUri})>[];
  final shares = <String>[];
  final deletes = <String>[];
  bool available = true;

  int _next = 1;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  }) async {
    keeps.add((
      workingPath: workingPath,
      displayName: displayName,
      previousUri: previousUri,
    ));
    final uri = 'content://media/external/video/media/${_next++}';
    kept[uri] = displayName;
    if (previousUri != null) kept.remove(previousUri);
    return uri;
  }

  @override
  Future<void> share({required String source}) async => shares.add(source);

  @override
  Future<bool> delete({required String uri}) async {
    deletes.add(uri);
    kept.remove(uri);
    return true;
  }

  @override
  Future<bool> exists({required String uri}) async => kept.containsKey(uri);
}

/// The playback view's seam (D12): the real one is the platform's own view, and
/// this one records what it was pointed at and when it was stopped.
class PagePlayer implements VideoPlayer {
  final sources = <String>[];
  int stops = 0;

  @override
  Widget view(BuildContext context, {required String source}) {
    sources.add(source);
    return const SizedBox(key: ValueKey('video player'), width: 20, height: 20);
  }

  @override
  Future<void> stop() async => stops++;
}

/// The control [label] names, however the page presents it: an icon action
/// carries the label as its tooltip, a button as its text. The requirement is
/// that the decision is offered, not which widget shape carries it.
Finder offeredBy(String label) {
  final byTooltip = find.byTooltip(label);
  return byTooltip.evaluate().isNotEmpty ? byTooltip : find.text(label);
}

/// Asserts the page offers a control the reader can act on.
void expectOffered(String label, {String? reason}) => expect(
  offeredBy(label),
  findsWidgets,
  reason: reason ?? '$label should be offered',
);

/// Asserts the page does not offer it at all (not merely disabled).
void expectNotOffered(String label, {String? reason}) => expect(
  find.byTooltip(label),
  findsNothing,
  reason: reason ?? '$label should not be offered',
);

void main() {
  late Directory root;
  late Directory work;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu_video_page');
    work = Directory.systemTemp.createTempSync('klhu_video_work');
  });
  tearDown(() {
    for (final dir in [root, work]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  /// A store holding one short pre-set, with nothing saved: the page shows it
  /// on its catalog-fallback path.
  ContentStore shortStore() => ContentStore(
    directory: root,
    loadCatalog: () async => [
      PresetContent(id: _presetId, language: 'en', text: _text),
    ],
    now: () => DateTime.utc(2026, 9, 26, 9),
  );

  Widget pageWith(
    ShortEngine engine,
    RecordingEncoder encoder, {
    ContentStore? store,
    PageFileStore? files,
    PagePlayer? player,
    Reader? reader,
  }) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale('es'),
    ],
    home: ReadingView(
      reader: reader ?? QuietReader(),
      contentStore: store ?? shortStore(),
      synthesizer: engine,
      videoEncoder: encoder,
      videoWorkDir: work,
      // The platform's own halves, faked: the page's availability answer comes
      // from the file store, and the player is what the review is pointed at.
      videoFileStore: files ?? PageFileStore(),
      videoPlayer: player ?? PagePlayer(),
    ),
  );

  /// Runs the page's real work — the engine's files, the painter's pictures,
  /// the PNG encoding — with the test clock standing still, until [until].
  ///
  /// The closing pump matters: work that lands during the last real turn can
  /// mark the page dirty only after that turn's own pump, so without it a
  /// caller can observe that the world moved on while the tree still shows the
  /// frame before it.
  Future<void> letWorkRun(
    WidgetTester tester,
    bool Function() until, {
    int rounds = 400,
  }) async {
    for (var i = 0; i < rounds; i++) {
      if (until()) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  /// The page offers the video action, the aspect prompt is answered with
  /// [choice], and the render starts.
  Future<void> startRender(WidgetTester tester, {String? choice}) async {
    await tester.tap(find.byTooltip('Video'));
    await tester.pump();
    expect(
      find.text('Video format'),
      findsOneWidget,
      reason: 'the aspect is offered before the render (FR-007)',
    );
    if (choice != null) {
      await tester.tap(find.text(choice));
      await tester.pump();
    }
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  /// The picture on screen, as the page shows it.
  RawImage picture(WidgetTester tester) =>
      tester.widget<RawImage>(find.byType(RawImage));

  /// The page's reading text as a widget. It paints a `RichText` directly, so
  /// `find.text` does not see it.
  Finder renderedContent() => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == _text);

  testWidgets(
    'the RENDERING state offers the picture and Stop and nothing else',
    (tester) async {
      final engine = ShortEngine()..hangOn = 1;
      final encoder = RecordingEncoder(work);
      await tester.pumpWidget(pageWith(engine, encoder));
      await loadPageContent(tester);
      expect(renderedContent(), findsOneWidget, reason: 'the page has content');

      await startRender(tester);
      await letWorkRun(tester, () => engine.isParked);

      // FR-019: the render owns the page. Every other action is gone, not just
      // disabled, and the only control is Stop.
      expect(find.byTooltip('Stop'), findsOneWidget);
      for (final action in [
        'Read',
        'Continue Read',
        'Edit',
        'Appearance',
        'Contents',
        'Voice',
        'Video',
      ]) {
        expect(
          find.byTooltip(action),
          findsNothing,
          reason: '$action is reachable during a render',
        );
      }
      // FR-009: progress while it runs — the sentence being written.
      await letWorkRun(tester,
          () => find.text('Rendering video, sentence 1 of 3').evaluate().isNotEmpty);
      expect(find.text('Rendering video, sentence 1 of 3'), findsOneWidget);

      // The picture: park pass 2 after the first frame, so the page is showing
      // the render's current frame while the render still has work to do.
      encoder.hangOnFrame = 1;
      engine.release();
      await letWorkRun(tester, () => encoder.frames.length == 1);

      final shown = picture(tester);
      // The plan's accessibility rule: the render's picture is announced as a
      // picture with the sentence being written, not left unlabelled.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Video preview',
        ),
        findsOneWidget,
      );
      final shownSize = (shown.image!.width, shown.image!.height);
      final written = await tester.runAsync(
        () => _pngSize(encoder.frames.first.png),
      );
      expect(shownSize, (
        1920,
        1080,
      ), reason: 'the picture is the chosen aspect\'s frame (FR-007)');
      expect(
        shownSize,
        written,
        reason:
            'the picture on screen is the frame written into the video '
            '(FR-020)',
      );
      expect(encoder.frames.first.repeat, greaterThan(0));

      // FR-019/FR-010: a touch on the page's text changes nothing.
      await tester.tap(find.byType(RawImage), warnIfMissed: false);
      await tester.pump();
      await tester.longPress(find.byType(RawImage), warnIfMissed: false);
      await tester.pump();
      expect(find.byTooltip('Stop'), findsOneWidget, reason: 'still rendering');
      expect(
        find.byTooltip('Read'),
        findsNothing,
        reason: 'a touch during a render changed what the page offers',
      );
      expect(find.text('Select a sentence or paragraph to read'), findsNothing);
      expect(
        find.text('Rendering video…'),
        findsOneWidget,
        reason: 'pass 2: the picture is the progress, not a sentence count',
      );

      encoder.hangOnFrame = null;
      encoder.release();
      await letWorkRun(tester, () => encoder.finishes == 1);
      // US3 changed what a render ends in: the finished video is the reader's to
      // decide about, so RENDERING is over and the review is up (FR-021).
      await letWorkRun(
          tester,
          () =>
              find.byKey(const ValueKey('video player')).evaluate().isNotEmpty);
      expect(
        find.byTooltip('Stop'),
        findsNothing,
        reason: 'the render is over',
      );
      expect(
        find.text('Save'),
        findsOneWidget,
        reason: 'the finished render is decided about, never silently kept',
      );
    },
  );

  testWidgets('the aspect chosen in the prompt is the frame rendered', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    await tester.pumpWidget(pageWith(engine, encoder));
    await loadPageContent(tester);

    await startRender(tester, choice: '9:16 vertical (Shorts)');
    await letWorkRun(tester, () => encoder.finishes == 1);
    await tester.pump();

    expect(
      encoder.startCalls.single.height,
      1920,
      reason:
          'the choice made before the render is what it rendered '
          '(FR-007)',
    );
    expect(encoder.startCalls.single.width, 1080);
  });

  testWidgets('Stop asks first, and dismissing it leaves the render running', (
    tester,
  ) async {
    final engine = ShortEngine()..hangOn = 1;
    final encoder = RecordingEncoder(work);
    await tester.pumpWidget(pageWith(engine, encoder));
    await loadPageContent(tester);
    await startRender(tester);
    await letWorkRun(tester, () => engine.isParked);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.text('Stop making the video?'), findsOneWidget);
    expect(find.text('The video will not be saved.'), findsOneWidget);
    expect(encoder.cancels, 0, reason: 'asking is not stopping');
    expect(engine.calls.length, 2, reason: 'the render was not paused');

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Stop making the video?'), findsNothing);
    expect(
      find.byTooltip('Stop'),
      findsOneWidget,
      reason: 'dismissing the box leaves the render running untouched',
    );

    // The render carries on: past the sentence it was writing, through pass 2,
    // to a finished file.
    engine.release();
    await letWorkRun(tester, () => encoder.finishes == 1);
    await letWorkRun(tester,
        () => find.textContaining('Video made:').evaluate().isNotEmpty);
    expect(encoder.cancels, 0);
    expect(encoder.frames, isNotEmpty, reason: 'the render finished normally');
    expect(
      find.textContaining('Video made:'),
      findsOneWidget,
      reason:
          'the finished render reports the file and its length '
          '(SC-001)',
    );
  });

  testWidgets('Stop confirmed ends the render with nothing written', (
    tester,
  ) async {
    final engine = ShortEngine()..hangOn = 1;
    final encoder = RecordingEncoder(work);
    await tester.pumpWidget(pageWith(engine, encoder));
    await loadPageContent(tester);
    await startRender(tester);
    await letWorkRun(tester, () => engine.isParked);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pump();

    // The page is idle at once (FR-019), and the render writes no file.
    expect(find.byTooltip('Read'), findsOneWidget);
    expect(find.textContaining('Rendering video'), findsNothing,
        reason: 'the page is idle again, not rendering');
    expect(encoder.finishes, 0, reason: 'confirming writes nothing');

    // What the render had in flight is abandoned: the encoder is cancelled and
    // the working directory holds nothing.
    engine.release();
    await letWorkRun(tester, () => encoder.cancels == 1);
    // The renderer deletes its own files, then the page removes the render's
    // directory: the cache is empty once that lands, not the moment the
    // encoder was cancelled (FR-009).
    await letWorkRun(tester, () => work.listSync(recursive: true).isEmpty);
    expect(encoder.finishes, 0);
    expect(
      work.listSync(recursive: true),
      isEmpty,
      reason:
          'a cancelled render leaves no working copy or audio behind '
          '(FR-009)',
    );
  });

  testWidgets('leaving a render asks the same way Stop does', (tester) async {
    final engine = ShortEngine()..hangOn = 0;
    final encoder = RecordingEncoder(work);
    final view = ReadingView(
      reader: QuietReader(),
      contentStore: shortStore(),
      synthesizer: engine,
      videoEncoder: encoder,
      videoWorkDir: work,
      // The platform's halves, faked: this case replaces the whole page, so it
      // needs them as much as `pageWith` does — the availability answer is what
      // offers the video action at all (US3 FR-010).
      videoFileStore: PageFileStore(),
      videoPlayer: PagePlayer(),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale('es'),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => view)),
                child: const Text('open the page'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open the page'));
    await tester.pump();
    await loadPageContent(tester);
    await startRender(tester);
    await letWorkRun(tester, () => engine.isParked);

    // Dismissed: the page stays, and the render keeps running.
    await tester.pageBack();
    await tester.pump();
    expect(
      find.text('Stop making the video?'),
      findsOneWidget,
      reason: 'leaving asks the same way Stop does (FR-019)',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(
      find.byTooltip('Stop'),
      findsOneWidget,
      reason: 'an unanswered leave keeps the render on screen',
    );
    expect(encoder.cancels, 0);

    // Confirmed: the page is left, and the render is cancelled.
    await tester.pageBack();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('open the page'),
      findsOneWidget,
      reason: 'the confirmed leave leaves the page',
    );
    engine.release();
    await letWorkRun(tester, () => encoder.cancels == 1);
    expect(encoder.finishes, 0);
  });

  // ---- US3: the review, the content's kept video, and who may act (rows 20,
  // 22–24, 27–29). The record's own rules are `video_record_test.dart`'s; what
  // is asserted here is what the PAGE offers and what it says.

  /// Renders the short content through to its end, so the page is at its review.
  Future<void> finishRender(
    WidgetTester tester,
    ShortEngine engine,
    RecordingEncoder encoder,
  ) async {
    await startRender(tester);
    await letWorkRun(tester, () => encoder.finishes == 1);
    // The render's own future completes a frame after the encoder reports it
    // finished, and that frame is what opens the review (FR-021): wait for the
    // review's own player rather than counting frames.
    await letWorkRun(
      tester,
      () => find.byKey(const ValueKey('video player')).evaluate().isNotEmpty,
    );
  }

  /// Waits until a decision has landed: the review is over and the page has said
  /// what happened. The platform calls land before the page finishes with them,
  /// so the tests wait for the page's own end state.
  ///
  /// The clock is advanced as well: the render's own "made the video" snack bar
  /// is still up when the decision is taken, and snack bars queue — the page's
  /// next message is shown once the first has expired, which takes real time in
  /// the app and pumped time here.
  Future<void> letReviewClose(WidgetTester tester, String message) async {
    for (var i = 0; i < 60; i++) {
      // Real time as well as pumped time: the decision finishes with file IO (the
      // working directory going), which only runs under `runAsync`.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text(message).evaluate().isNotEmpty) return;
    }
  }

  /// The working copy the fake encoder leaves behind.
  String workingPath() => '${work.path}/Klhu reading.mp4';

  testWidgets('the review plays the working copy, and offers every decision', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    final player = PagePlayer();
    await tester.pumpWidget(
      pageWith(engine, encoder, files: files, player: player),
    );
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);

    // FR-021: the video is watched before anything is kept, and the picture is
    // the working copy — not a library file.
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    await letWorkRun(tester, () => player.sources.isNotEmpty);
    expect(
      player.sources.toSet(),
      {workingPath()},
      reason: 'the player is pointed at the working copy (row 29)',
    );
    expect(find.byKey(const ValueKey('video player')), findsOneWidget);
    expect(
      File(workingPath()).existsSync(),
      isTrue,
      reason: 'the review needs the working copy to still be there',
    );
    expect(files.keeps, isEmpty, reason: 'nothing is kept yet');
    expectOffered(l10n.saveButton, reason: 'keeping is one of the decisions');
    expectOffered(l10n.discardButton, reason: 'throwing it away is another');
    expectOffered(l10n.videoShareButton, reason: 'sharing is the third');
    expect(find.byTooltip(l10n.stopButton), findsNothing,
        reason: 'the render is over');
  });

  testWidgets('keeping promotes the working copy and leaves the content with '
      'its video', (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    final player = PagePlayer();
    await tester.pumpWidget(
      pageWith(engine, encoder, files: files, player: player),
    );
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);

    expect(files.keeps, hasLength(1));
    expect(files.keeps.single.workingPath, workingPath());
    expect(files.keeps.single.previousUri, isNull,
        reason: 'nothing was kept for this content before');
    expect(files.keeps.single.displayName, endsWith('.mp4'),
        reason: 'the library entry is named after the content');
    expect(File(workingPath()).existsSync(), isFalse,
        reason: 'the working copy is consumed by keeping (FR-009/FR-021)');
    expect(find.text(l10n.videoSavedMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('video player')), findsNothing,
        reason: 'the decision is taken, so the review is over');

    // FR-022: the content now offers its kept video.
    expectOffered(l10n.videoPlayButton);
    expectOffered(l10n.videoShareButton);
    expectOffered(l10n.videoDeleteButton);
  });

  testWidgets('throwing the render away keeps nothing and says so', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    await tester.tap(offeredBy(l10n.discardButton));
    await letReviewClose(tester, l10n.videoNotSavedMessage);

    expect(files.keeps, isEmpty, reason: 'throwing a render away writes nothing');
    expect(files.shares, isEmpty);
    expect(File(workingPath()).existsSync(), isFalse);
    expect(find.text(l10n.videoNotSavedMessage), findsOneWidget);
    // Nothing is kept, so the content offers to record again and nothing else.
    expectOffered(l10n.videoButton);
    expect(find.byTooltip(l10n.videoPlayButton), findsNothing);
    expect(find.byTooltip(l10n.videoDeleteButton), findsNothing);
  });

  testWidgets('keeping again replaces the earlier video', (tester) async {
    // Row 19 on the page: a second render's keep names the first file.
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    await finishRender(tester, engine, encoder);
    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);
    final first = files.keeps.single;

    await finishRender(tester, engine, encoder);
    await tester.tap(offeredBy(l10n.saveButton));
    await letWorkRun(tester, () => files.keeps.length == 2);

    expect(files.keeps.last.previousUri, isNotNull,
        reason: 'the earlier kept file is replaced, not forgotten (FR-012)');
    expect(
      files.kept.keys.where((uri) => files.kept[uri] == first.displayName),
      hasLength(1),
      reason: 'one kept video per content, in the library itself',
    );
  });

  testWidgets('a kept video can be shared, and sharing keeps nothing', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);
    final uri = files.kept.keys.single;

    await tester.tap(offeredBy(l10n.videoShareButton));
    await letWorkRun(tester, () => files.shares.isNotEmpty);

    expect(files.shares, [uri],
        reason: 'a kept video is shared by its library uri (A12)');
    expect(files.keeps, hasLength(1), reason: 'sharing is not keeping');
    expectOffered(l10n.videoPlayButton, reason: 'and it is still there to play');
  });

  testWidgets('deleting a kept video warns, and only confirming deletes', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);
    final uri = files.kept.keys.single;

    // Dismissed: nothing happens at all.
    await tester.tap(offeredBy(l10n.videoDeleteButton));
    await tester.pump();
    expect(find.text(l10n.videoDeleteConfirmTitle), findsOneWidget,
        reason: 'every delete warns (FR-024)');
    await tester.tap(find.text(l10n.cancelButton));
    await tester.pump();
    expect(files.deletes, isEmpty,
        reason: 'dismissing the warning never deletes anything');
    expect(files.kept.containsKey(uri), isTrue);
    expectOffered(l10n.videoPlayButton,
        reason: 'and the video is still there to play');

    // Confirmed: the file and the record both go, and the content offers to
    // record again (FR-022/FR-024).
    await tester.tap(offeredBy(l10n.videoDeleteButton));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteButton));
    await letWorkRun(tester, () => files.deletes.isNotEmpty);
    await tester.pump();

    expect(files.deletes, [uri]);
    expect(files.kept.containsKey(uri), isFalse);
    expect(
      find.byTooltip(l10n.videoPlayButton),
      findsNothing,
      reason: 'the content no longer has a video',
    );
    expectOffered(l10n.videoButton, reason: 'and offers to record again');
  });

  testWidgets('a video removed outside the app is reported, not offered', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    // A kept video whose file has already gone: kept the normal way, and then
    // deleted from the library outside the app.
    final files = PageFileStore();
    final records = VideoRecordStore(files: files);
    final kept = await records.keep(
      _presetId,
      workingPath: workingPath(),
      displayName: 'One two…mp4',
    );
    files.kept.remove(kept.uri);

    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    expect(find.text(l10n.videoGoneMessage), findsOneWidget,
        reason: 'the app reports it as gone (FR-022)');
    expect(
      find.byTooltip(l10n.videoPlayButton),
      findsNothing,
      reason: 'never a play action that fails',
    );
    expectOffered(l10n.videoButton, reason: 'the content offers to record again');
    // And it was forgotten, not merely hidden.
    expect((await records.lookup('preset_short')).video, isNull);
  });

  testWidgets('the video action is offered from the idle page only', (
    tester,
  ) async {
    // FR-010: a read playing or parked owns the page, and so does an edit.
    final reader = ParkedReader();
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: ReadingView(
          reader: reader,
          contentStore: shortStore(),
          synthesizer: engine,
          videoEncoder: encoder,
          videoWorkDir: work,
          videoFileStore: PageFileStore(),
          videoPlayer: PagePlayer(),
        ),
      ),
    );
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    expectOffered(l10n.videoButton, reason: 'idle: the action is offered');

    // ⏭ Continue Read starts a full read with nothing selected, which is what
    // parks here (the plain Read action needs a selection first).
    await tester.tap(find.byTooltip(l10n.continueReadButton));
    await letWorkRun(tester, () => reader.started);
    expectNotOffered(l10n.videoButton, reason: 'a read owns the page');

    await tester.tap(find.byTooltip(l10n.pauseButton));
    await tester.pump();
    expectNotOffered(l10n.videoButton, reason: 'a parked read owns it too');

    // From PAUSED straight to EDIT: a parked read already offers the action, and
    // Continue Read does not (a read in progress owns the page).
    await tester.tap(find.byTooltip(l10n.editButton));
    await tester.pump();
    expectNotOffered(l10n.videoButton, reason: 'and so does an edit');
  });

  testWidgets('where the platform cannot render, nothing offers a video', (
    tester,
  ) async {
    // FR-010/D8: iOS, until its half exists.
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore()..available = false;
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    expectNotOffered(l10n.videoButton,
        reason: 'no action is offered where rendering is impossible');
    expectOffered(l10n.readButton, reason: 'and the rest of the page is normal');
  });

  testWidgets('leaving an undecided review keeps nothing', (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    final player = PagePlayer();
    final view = ReadingView(
      reader: QuietReader(),
      contentStore: shortStore(),
      synthesizer: engine,
      videoEncoder: encoder,
      videoWorkDir: work,
      videoFileStore: files,
      videoPlayer: player,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => view)),
                child: const Text('open the page'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open the page'));
    await tester.pump();
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;
    expectOffered(l10n.saveButton, reason: 'the review is up');

    await tester.pageBack();
    await letWorkRun(tester, () => !File(workingPath()).existsSync());
    await tester.pump();

    expect(find.text('open the page'), findsOneWidget,
        reason: 'the review is left without asking (nothing is at stake yet)');
    expect(files.keeps, isEmpty, reason: 'an undecided review keeps nothing');
    expect(File(workingPath()).existsSync(), isFalse,
        reason: 'and its working copy is cleaned up');
    expect(player.stops, greaterThan(0),
        reason: 'leaving stops playback (contract § Rules 4)');
  });
}

/// The pixel size of [bytes] as an encoded image.
Future<(int, int)> _pngSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = (image.width, image.height);
  image.dispose();
  codec.dispose();
  return size;
}
