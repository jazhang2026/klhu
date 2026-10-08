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
import 'package:klhu/content_naming.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/video_list_screen.dart';
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
    PicturePicker? picker,
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
      // The reader's own pictures (FR-025): faked here, because the real one
      // opens the platform's file dialog. Quieter by default, so a row about
      // anything else renders the plain-background video.
      picturePicker: picker ?? QuietPicker(),
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
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
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

  /// Taps [button] — the reader's own way to choose pictures — and lets the page
  /// do what follows: the picker's reads and the writing of every pick into the
  /// app's own directory (D18) are real file work, so the real event loop drives
  /// them, and the wait is for the pictures handed over to be the pictures on
  /// screen. Never a fixed count and never pumpAndSettle: the page's reader ticks,
  /// so the tree never goes quiet, and what has to land is the reader's pictures.
  Future<void> choosePictures(
    WidgetTester tester,
    Finder button,
    int Function() handedOver,
  ) async {
    // The prompt's content scrolls (it grows with the reader's pictures), so the
    // reader's own way to choose is brought to where a finger could reach it.
    await tester.ensureVisible(button);
    await tester.tap(button);
    await letWorkRun(
      tester,
      () => find.byType(MovableThumbnail).evaluate().length == handedOver(),
    );
  }

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

    // FR-022/FR-033: the content now offers its videos — one action, which
    // opens them as a list (the 2026-10-06 amendment).
    expectOffered(l10n.videoListTitle);
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
    expect(find.byTooltip(l10n.videoListTitle), findsNothing,
        reason: 'a content with no videos has no list to open');
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

  testWidgets('a keep asked not to replace leaves the earlier video too', (
    tester,
  ) async {
    // FR-012's amendment (2026-10-06, row 35 on the reader's phone): a second
    // keep replaces by default, and the reader can ask for both.
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
    final first = files.kept.keys.single;

    await finishRender(tester, engine, encoder);
    expect(
      tester.widget<Switch>(find.byType(Switch)).value,
      isTrue,
      reason: 'the offered answer is the shipped rule: replace',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
      tester.widget<Switch>(find.byType(Switch)).value,
      isFalse,
      reason: 'the reader turned the replacement off',
    );

    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);
    await tester.pump();

    expect(
      files.keeps.last.previousUri,
      isNull,
      reason: 'nothing was named to replace, so nothing was removed (FR-012)',
    );
    expect(
      files.kept,
      hasLength(2),
      reason: 'both files are in the library, the earlier one and this render',
    );
    expect(files.kept.containsKey(first), isTrue);
    // The content's own record is one entry per content: it comes to point at
    // the render just kept, which is the one the page offers to play.
    final record =
        (await VideoRecordStore(files: files).recordFor(_presetId)).latest;
    expect(record, isNotNull);
    expect(
      record!.uri,
      files.kept.keys.last,
      reason: 'the content plays what was just kept — its own last entry',
    );
    expectOffered(l10n.videoListTitle);
  });

  testWidgets('the replacement question is asked only when there is one to replace', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;

    // Nothing kept for this content yet: the first render's review asks nothing.
    await finishRender(tester, engine, encoder);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);

    // Now there is one, so the second render's review asks.
    await finishRender(tester, engine, encoder);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  /// Opens the content's videos from the page, and waits until the list is
  /// really there: the record read has landed (so there are rows) **and** the
  /// route has finished sliding in. A material route 800 px wide slides from the
  /// right, so a tap taken mid-transition derives an offset outside the window
  /// and lands on nothing.
  Future<void> openVideoList(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(offeredBy(l10n.videoListTitle));
    await letWorkRun(
      tester,
      () => find.byType(VideoListScreen).evaluate().isNotEmpty,
    );
    await letWorkRun(tester, () => find.byType(ListTile).evaluate().isNotEmpty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('the page offers one Videos action, and the three it replaced '
      'are gone', (tester) async {
    // Row 56's page half (FR-022/FR-033, the 2026-10-06 amendment): play, share
    // and delete act on the content's list of videos now, so the page offers
    // the list and each row carries its own share and delete. What the page's
    // own Play action used to do is the list's last row's tap.
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

    expectOffered(l10n.videoListTitle,
        reason: 'the content offers its videos as a list');
    expect(find.byTooltip('Play video'), findsNothing,
        reason: 'the three actions the list replaced are off the page');
    expect(find.byTooltip('Delete video'), findsNothing);
    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Videos opens the content\'s list, and its row plays that video', (
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
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);
    final uri = files.kept.keys.single;

    await openVideoList(tester, l10n);

    expect(find.byType(VideoListScreen), findsOneWidget,
        reason: 'one action opens the content\'s videos (FR-022)');
    expect(find.byType(ListTile), findsOneWidget,
        reason: 'one video kept, so one row (FR-033)');

    // And a tap on the row plays that video, which is what the page's own Play
    // action used to open (FR-022).
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.sources, contains(uri),
        reason: 'the row plays the video the page kept');
  });

  testWidgets('the list\'s delete warns by name, and what it leaves is a page '
      'with nothing to offer', (tester) async {
    // Row 56's page half again, for the file's life cycle (FR-022/FR-024): the
    // row's delete is the page's own delete now, and the page reads the record
    // again when the list comes back, so a content with nothing left offers to
    // record again. The warning's own case lives in `video_list_screen_test.dart`.
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
    final kept =
        (await VideoRecordStore(files: files).recordFor(_presetId)).latest!;

    await openVideoList(tester, l10n);

    // Dismissed on the row: nothing happens at all.
    await tester.tap(find.byTooltip(l10n.videoDeleteButton));
    await tester.pump();
    expect(find.text(l10n.videoDeleteConfirmTitle), findsOneWidget,
        reason: 'every delete warns (FR-024)');
    expect(find.text(l10n.videoDeleteConfirmMessage(kept.name)), findsOneWidget,
        reason: 'and the warning names the video being deleted (FR-033)');
    await tester.tap(find.text(l10n.cancelButton));
    await tester.pump();
    expect(files.deletes, isEmpty,
        reason: 'dismissing the warning never deletes anything');
    expect(files.kept.containsKey(uri), isTrue);

    // Confirmed: the file and its entry both go (FR-024/contract § Write 2).
    await tester.tap(find.byTooltip(l10n.videoDeleteButton));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteButton));
    await letWorkRun(tester, () => files.deletes.isNotEmpty);
    await tester.pump();

    expect(files.deletes, [uri]);
    expect(files.kept.containsKey(uri), isFalse);
    expect(
      (await VideoRecordStore(files: files).recordFor(_presetId)).videos,
      isEmpty,
    );

    // Back on the page: the content offers to record again, and no list.
    await tester.pageBack();
    await letWorkRun(
      tester,
      () => find.byType(VideoListScreen).evaluate().isEmpty,
    );
    await letWorkRun(
      tester,
      () => find.byTooltip(l10n.videoListTitle).evaluate().isEmpty,
    );
    await tester.pump();
    expect(find.byTooltip(l10n.videoListTitle), findsNothing,
        reason: 'nothing is kept, so there is no list to open');
    expectOffered(l10n.videoButton, reason: 'and it offers to record again');
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

    expect(find.text(l10n.videoGoneMessage('One two…mp4')), findsOneWidget,
        reason: 'the app reports that video gone, by its own name (FR-022)');
    expect(
      find.byTooltip(l10n.videoListTitle),
      findsNothing,
      reason: 'never an action that opens a video that is not there',
    );
    expectOffered(l10n.videoButton, reason: 'the content offers to record again');
    // And it was forgotten, not merely hidden.
    expect((await records.recordFor('preset_short')).videos, isEmpty);
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

  testWidgets('a kept video is named for the content, not for the render', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final files = PageFileStore();
    await tester.pumpWidget(pageWith(engine, encoder, files: files));
    await loadPageContent(tester);
    await finishRender(tester, engine, encoder);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    // The content's own name, by the app's own rule for naming a content — the
    // same rule the page names the render with. (SC-001's "Video made: …" line
    // names the *file* the render wrote, which is the working directory's, so it
    // is not this.)
    final name = contentNameFrom(_text);

    await tester.tap(offeredBy(l10n.saveButton));
    await letReviewClose(tester, l10n.videoSavedMessage);

    expect(files.keeps, hasLength(1));
    expect(files.keeps.single.displayName, startsWith(name),
        reason: 'the kept video is named for its content, not for the file the '
            'encoder wrote (${files.keeps.single.workingPath})');
    expect(files.keeps.single.displayName, isNot(contains('/')),
        reason: 'a library name is a name, not a path');
  });

  testWidgets('choosing again adds to the choice, with nothing capped',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [for (var i = 0; i < 12; i++) picked('a$i.png', await redPng(tester))],
      [for (var i = 0; i < 12; i++) picked('b$i.png', await bluePng(tester))],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);
    expect(find.text(l10n.videoPicturesChosen(12)), findsOneWidget,
        reason: 'twelve pictures chosen, one cell each (FR-030)');
    expect(find.byType(MovableThumbnail), findsNWidgets(12));

    // Choosing again ADDS (FR-025), and **nothing is capped**: the reader's own
    // instruction of 2026-09-28 — "remove max 20 images limit. keep all 30
    // images for now. user can delete images." — so the second pick is taken
    // whole and every picture keeps its own cell.
    await choosePictures(tester, find.text(l10n.videoPicturesChooseMore), () => picker.handedOver);

    expect(picker.calls, 2, reason: 'the reader chose twice');
    expect(find.text(l10n.videoPicturesChosen(24)), findsOneWidget,
        reason: 'both picks are held: the count is the sum');
    expect(find.byType(MovableThumbnail), findsNWidgets(24),
        reason: 'and each one has its own cell — none is refused or trimmed');
    expect(
      tester
          .widgetList<MovableThumbnail>(find.byType(MovableThumbnail))
          .map((cell) => cell.picture.name)
          .toList(),
      <String>[
        for (var i = 0; i < 12; i++) 'a$i.png',
        for (var i = 0; i < 12; i++) 'b$i.png',
      ],
      reason: 'in the order chosen: the first pick keeps its place (FR-025)',
    );
  });

  testWidgets('the review window is small, and scrolling shows the rest',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [for (var i = 0; i < 12; i++) picked('a$i.png', await redPng(tester))],
      [for (var i = 0; i < 12; i++) picked('b$i.png', await bluePng(tester))],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);
    await choosePictures(tester, find.text(l10n.videoPicturesChooseMore), () => picker.handedOver);

    // FR-030: the review window is two rows tall whatever the count is — the
    // reader's own shape of 2026-09-28, "use scroll. small show window, scroll
    // to show others" — so the prompt stays the size of a prompt with thirty
    // pictures in it.
    final window = find
        .ancestor(
          of: find.byType(MovableThumbnail).first,
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    final cells = find
        .ancestor(
          of: find.byType(MovableThumbnail).first,
          matching: find.byType(Wrap),
        )
        .first;
    expect(tester.getSize(window).height, pictureWindowHeight,
        reason: 'the window is two rows of thumbnails tall');
    expect(tester.getSize(cells).height, greaterThan(pictureWindowHeight),
        reason: 'and the cells do not all fit — which is what the window is for');
    final last = find.byType(MovableThumbnail).last;
    final windowRect = tester.getRect(window);
    expect(tester.getRect(last).top, greaterThan(windowRect.bottom),
        reason: 'the last picture is below the window before the reader scrolls');

    await tester.drag(window, const Offset(0, -400));
    await tester.pump();

    expect(tester.getRect(find.byType(MovableThumbnail).last).top,
        lessThan(windowRect.bottom),
        reason: 'scrolling inside the window brings the others into it');
  });

  testWidgets('holding a picture moves it, and the order reaches the render',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [
        picked('one.png', await redPng(tester)),
        picked('two.png', await bluePng(tester)),
        picked('three.png', await greenPng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);
    expect(
      tester
          .widgetList<MovableThumbnail>(find.byType(MovableThumbnail))
          .map((cell) => cell.picture.name)
          .toList(),
      ['one.png', 'two.png', 'three.png'],
      reason: 'the cells stand in the order the reader chose (FR-025)',
    );

    // FR-032: the reader holds a picture and moves it — the first onto the
    // third, which is "move one image to the right" (2026-09-28: "use can
    // tap+hold move one image to left/right"). Long enough for the long press
    // to be recognised, then a move to the other cell.
    final cells = find.byType(MovableThumbnail);
    final gesture = await tester.startGesture(tester.getCenter(cells.first));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(cells.last));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      tester
          .widgetList<MovableThumbnail>(find.byType(MovableThumbnail))
          .map((cell) => cell.picture.name)
          .toList(),
      ['two.png', 'three.png', 'one.png'],
      reason: 'the moved picture took the cell it was dropped on, and the two '
          'it passed moved up one',
    );

    // And the order is the video's own (FR-026): the renderer copies the
    // pictures into its working directory in the order the cells stand, and the
    // schedule it builds from them is the order they are drawn in. Parked on
    // the first frame, the copies are still there to read.
    encoder.hangOnFrame = 0;
    await tester.tap(find.text(l10n.videoStartButton));
    await tester.pump();
    await letWorkRun(tester, () => encoder.startCalls.isNotEmpty);
    final copies = work
        .listSync(recursive: true)
        .map((entity) => entity.uri.pathSegments.last)
        .where((name) => name.startsWith('picture_'))
        .toList()
      ..sort();
    expect(copies, ['picture_0_two.png', 'picture_1_three.png', 'picture_2_one.png'],
        reason: 'the render writes them in the reader\'s own order');

    encoder.release();
    await letWorkRun(tester, () => encoder.finishes == 1);
  });

  testWidgets('a hold at the window\'s own end scrolls it (FR-032, D21)',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    // Twenty-four pictures in a window two rows tall: the rest are out of sight,
    // and the reader's own report from the phone is that a hold could only move
    // a picture between the rows on screen — "need to able to move out of the
    // disabled rows. use auto scroll."
    final picker = PickingPictures([
      [for (var i = 0; i < 24; i++) picked('a$i.png', await redPng(tester))],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton),
        () => picker.handedOver);
    expect(find.byType(MovableThumbnail), findsNWidgets(24));

    final window = find.byKey(const ValueKey('video picture window'));
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(of: window, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(offset(), 0, reason: 'the window opens at the first picture');

    final cells = find.byType(MovableThumbnail);
    final start = tester.getCenter(cells.first);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // the hold itself
    // The finger goes past the window's bottom edge and waits there: holding at
    // the end is how a reader asks for more.
    await gesture.moveTo(
      Offset(start.dx, tester.getRect(window).bottom + 8),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(offset(), greaterThan(0),
        reason: 'a hold at the end of the window scrolls it, so a picture can '
            'reach a cell that is not on screen');

    // And the picture is dropped on a cell the scroll brought into view.
    await gesture.moveTo(tester.getCenter(cells.last));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final order = tester
        .widgetList<MovableThumbnail>(cells)
        .map((cell) => cell.picture.name)
        .toList();
    expect(order, hasLength(24), reason: 'a move changes no count (FR-032)');
    expect(order.first, isNot('a0.png'),
        reason: 'the picture that was held left the first row it started in');
    expect(order, contains('a0.png'));
  });

  testWidgets('a hold at the window\'s own top scrolls it back (FR-032, D21)',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [for (var i = 0; i < 24; i++) picked('a$i.png', await redPng(tester))],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton),
        () => picker.handedOver);

    final window = find.byKey(const ValueKey('video picture window'));
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(of: window, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;

    // The reader scrolls the window down the ordinary way first, so the hold
    // below has somewhere to come back from.
    await tester.drag(window, const Offset(0, -80));
    await tester.pump();
    final scrolled = offset();
    expect(scrolled, greaterThan(0),
        reason: 'a plain drag scrolls the window, which is what FR-030 gives it');

    // The hold has to start on a cell the scroll left **inside** the window — the
    // first cells are above it now — so the one under the window's own top edge
    // is the one held.
    final cells = find.byType(MovableThumbnail);
    final windowRect = tester.getRect(window);
    final held = cells.evaluate().map((cell) {
      final box = cell.renderObject! as RenderBox;
      return box.localToGlobal(box.size.center(Offset.zero));
    }).firstWhere(windowRect.contains);

    final gesture = await tester.startGesture(held);
    await tester.pump(const Duration(milliseconds: 600)); // the hold itself
    // The finger goes past the window's top edge and waits there.
    await gesture.moveTo(Offset(held.dx, windowRect.top - 8));
    await tester.pump(const Duration(milliseconds: 300));

    expect(offset(), lessThan(scrolled),
        reason: 'a hold at the window\'s top end scrolls it back — the reader\'s '
            'own phone test of 2026-09-28 confirms both directions: "自动滚动 '
            'fixed up and down"');

    await gesture.up();
    await tester.pump();
    final resting = offset();
    await tester.pump(const Duration(milliseconds: 400));
    expect(offset(), resting,
        reason: 'and letting go stops it: nothing keeps scrolling a hold that '
            'is over');
  });

  testWidgets('more pictures than sentences is accepted, the extras undrawn',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    // The fixture is three sentences, so four pictures is one the video has
    // nowhere to draw — and the reader's own answer from the phone of
    // 2026-09-28 is that this is fine and silent: "超限提示、no need. not show."
    final picker = PickingPictures([
      [
        for (final name in ['a.png', 'b.png', 'c.png', 'd.png'])
          picked(name, await redPng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton),
        () => picker.handedOver);

    expect(find.text(l10n.videoPicturesChosen(4)), findsOneWidget);
    expect(find.byType(MovableThumbnail), findsNWidgets(4),
        reason: 'all four are the reader\'s own, each with its own cell and '
            'its own remove: nothing is refused, trimmed or blocked (FR-025)');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, l10n.videoStartButton),
          )
          .onPressed,
      isNotNull,
      reason: 'the render is offered whatever the count: the picture past the '
          'video\'s last sentence is simply not drawn (FR-026)',
    );

    await tester.tap(find.text(l10n.videoStartButton));
    await letWorkRun(tester, () => encoder.startCalls.length == 1);
    expect(encoder.startCalls, hasLength(1),
        reason: 'and the render goes ahead — a choice over the sentence count is '
            'not an error the reader has to fix');
  });
  testWidgets('the picks are stored where the app owns them, and are not kept',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [
        picked('sunset.png', await redPng(tester)),
        picked('hills.png', await bluePng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);

    // D18: the picks are files in a directory of the app's own, one per prompt —
    // the page shows those files, so thirty photographs are thirty paths and not
    // a few hundred megabytes held in memory.
    final picksDir = Directory('${work.path}/picks_0');
    expect(picksDir.existsSync(), isTrue,
        reason: 'the prompt owns a directory of its own for its pictures');
    expect(
      picksDir
          .listSync()
          .map((entity) => entity.uri.pathSegments.last)
          .toList()
        ..sort(),
      ['pick_0_sunset.png', 'pick_1_hills.png'],
      reason: 'one file per picture, in the order chosen, under the name it '
          'came with',
    );

    // And what the reader sees is the stored file (FR-030), not a copy held in
    // memory that the render would have to be given again.
    final shown = tester.widgetList<Image>(
      find.descendant(
        of: find.byType(ChosenThumbnail),
        matching: find.byType(Image),
      ),
    );
    // The thumbnail bounds its own decode ([ChosenThumbnail]'s cacheWidth), so
    // the provider on the widget is the resizing one around the file's.
    String shownPath(Image image) {
      final provider = image.image;
      final file = provider is ResizeImage ? provider.imageProvider : provider;
      return (file as FileImage).file.path;
    }

    expect(
      shown.map(shownPath).toList(),
      [
        '${picksDir.path}${Platform.pathSeparator}pick_0_sunset.png',
        '${picksDir.path}${Platform.pathSeparator}pick_1_hills.png',
      ],
      reason: 'every thumbnail shows the prompt\'s own stored file, in the order '
          'the reader chose them (FR-030, D18)',
    );

    // The render copies them into its own directory and takes the copies with it;
    // the stored picks belong to the prompt and go with it (FR-025).
    await tester.tap(find.text(l10n.videoStartButton));
    await letWorkRun(tester, () => encoder.finishes == 1);
    await letWorkRun(tester, () => !picksDir.existsSync());
    expect(picksDir.existsSync(), isFalse,
        reason: 'the picks are never remembered once the render is over');
  });

  testWidgets('the chosen pictures are shown, and one can be taken back',
      (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [
        picked('sunset.png', await redPng(tester)),
        picked('hills.png', await bluePng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);

    // FR-030: the reader sees the pictures the render will use, each with its
    // own remove — the picture itself, not just a count.
    expect(find.byType(ChosenThumbnail), findsNWidgets(2));
    expect(find.byTooltip(l10n.videoPicturesRemove), findsNWidgets(2));
    expect(find.text(l10n.videoPicturesChosen(2)), findsOneWidget);

    // Taking one back takes exactly one back, and the count follows.
    await tester.tap(find.byTooltip(l10n.videoPicturesRemove).first);
    await tester.pump();
    expect(find.byType(ChosenThumbnail), findsOneWidget,
        reason: 'the remove removes its own picture and no other');
    expect(find.text(l10n.videoPicturesChosen(1)), findsOneWidget);

    // And what is left is what renders: the reader's confirm still stands.
    await tester.tap(find.text(l10n.videoStartButton));
    await letWorkRun(tester, () => encoder.startCalls.length == 1);
    expect(encoder.startCalls, hasLength(1),
        reason: 'the removal is part of the choice, not a cancel');
  });

  testWidgets('the chosen pictures are shown before the render', (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [
        picked('one.png', await redPng(tester)),
        picked('two.png', await bluePng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );

    // FR-025: the pictures are the reader's own files, chosen here, and the page
    // names what is chosen before anything renders.
    expect(find.text(l10n.videoPicturesChosen(0)), findsOneWidget,
        reason: 'the step is up, with nothing chosen yet');
    expect(find.text(l10n.videoPicturesButton), findsOneWidget,
        reason: 'and it offers to choose');
    expect(encoder.startCalls, isEmpty,
        reason: 'opening the step renders nothing');

    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);

    expect(picker.calls, 1, reason: 'the picker is the reader\'s own dialog');
    expect(find.text(l10n.videoPicturesChosen(2)), findsOneWidget,
        reason: 'the page names how many pictures are chosen');
    expect(find.text(l10n.videoPicturesChooseMore), findsOneWidget,
        reason: 'and lets the reader choose again');
    expect(find.text(l10n.videoPicturesButton), findsNothing);
    expect(encoder.startCalls, isEmpty,
        reason: 'choosing is not confirming: the render waits for the reader');
  });

  testWidgets('the render starts on the reader\'s own confirm, and the picks '
      'are not remembered', (tester) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      [
        picked('one.png', await redPng(tester)),
        picked('two.png', await bluePng(tester)),
      ],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);
    expect(find.text(l10n.videoPicturesChosen(2)), findsOneWidget);

    await tester.tap(find.text(l10n.videoStartButton));
    await letWorkRun(tester, () => encoder.finishes == 1);
    await letWorkRun(
      tester,
      () => find.byKey(const ValueKey('video player')).evaluate().isNotEmpty,
    );

    expect(encoder.startCalls, hasLength(1),
        reason: 'the reader\'s own confirm is what renders (FR-025)');
    // The picks reached the frames: the first sentence's frame carries its
    // picture — its own colours away from the words, with the sentence on white
    // plates (FR-027, D16 as amended on 2026-09-28), not the plain background.
    final background = Theme.of(
      tester.element(find.byType(ReadingView)),
    ).scaffoldBackgroundColor.toARGB32();
    final behindTheText =
        await tester.runAsync(() => pixelOf(encoder.frames[1].png));
    expect(behindTheText, isNot(background),
        reason: 'the chosen picture fills the frame behind the sentence');

    // Not remembered: the picks belonged to the render that used them, so the
    // next one is asked for again from nothing (FR-025).
    await tester.tap(offeredBy(l10n.discardButton));
    await letReviewClose(tester, l10n.videoNotSavedMessage);
    await tester.tap(offeredBy(l10n.videoButton));
    // The prompt opens once the video's own sentences are resolved again.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    expect(find.text(l10n.videoPicturesChosen(0)), findsOneWidget,
        reason: 'nothing is held after the render it was chosen for');
    expect(find.text(l10n.videoPicturesButton), findsOneWidget,
        reason: 'the reader is asked again, not told what they had');
  });

  testWidgets('choosing none still makes the plain-background video', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = QuietPicker();
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(
      tester,
      find.text(l10n.videoPicturesButton),
      // Nothing was chosen, so there is nothing on screen to wait for: the
      // wait's own closing pump lands the picker's own answer.
      () => 0,
    );
    expect(find.text(l10n.videoPicturesChosen(0)), findsOneWidget,
        reason: 'the dialog was opened and cancelled: still nothing chosen');

    await tester.tap(find.text(l10n.videoStartButton));
    await letWorkRun(tester, () => encoder.finishes == 1);

    expect(encoder.frames, isNotEmpty);
    final background = Theme.of(
      tester.element(find.byType(ReadingView)),
    ).scaffoldBackgroundColor.toARGB32();
    for (final frame in encoder.frames) {
      expect(
        await tester.runAsync(() => pixelOf(frame.png)),
        background,
        reason: 'with nothing chosen every frame is the plain background '
            '(FR-028)',
      );
    }
  });

  testWidgets('a picker that failed is said, and the reader can try again', (
    tester,
  ) async {
    final engine = ShortEngine();
    final encoder = RecordingEncoder(work);
    final picker = PickingPictures([
      Exception('the file dialog could not be opened'),
      [picked('one.png', await redPng(tester))],
    ]);
    await tester.pumpWidget(pageWith(engine, encoder, picker: picker));
    await loadPageContent(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(ReadingView)))!;

    await tester.tap(find.byTooltip('Video'));
    // The prompt opens once the video's own sentences are resolved — the same
    // store read a read's voice resolution makes (FR-026's count) — so the real
    // event loop drives it rather than the test clock.
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);

    expect(find.text(l10n.videoPicturesFailed), findsOneWidget,
        reason: 'the page says the picker failed rather than swallowing it');
    expect(encoder.startCalls, isEmpty, reason: 'and nothing renders');
    expect(find.text(l10n.videoPicturesChosen(0)), findsOneWidget,
        reason: 'the reader is left exactly where they were');

    // And the reader can try again: the step is still there.
    await choosePictures(tester, find.text(l10n.videoPicturesButton), () => picker.handedOver);
    expect(picker.calls, 2);
    expect(find.text(l10n.videoPicturesChosen(1)), findsOneWidget,
        reason: 'the second try\'s picture is the one chosen');
    expect(find.text(l10n.videoPicturesFailed), findsNothing,
        reason: 'and the failure is past');
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

/// One pixel of a frame the encoder received, as `0xAARRGGBB` — the same shape
/// as `Color.toARGB32()`, and the frames are real PNGs, so this is the picture
/// the render wrote rather than a claim about it.
Future<int> pixelOf(Uint8List png, {int x = 6, int y = 6}) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * image.width + x) * 4;
  final bytes = data!.buffer.asUint8List();
  final pixel = (bytes[offset + 3] << 24) |
      (bytes[offset] << 16) |
      (bytes[offset + 1] << 8) |
      bytes[offset + 2];
  image.dispose();
  codec.dispose();
  return pixel;
}

/// A real PNG of one colour, as a Uint8List — what the reader's own file holds.
Future<Uint8List> pngOf(int argb, {int side = 8}) async {
  final bytes = Uint8List(side * side * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = (argb >> 24) & 0xFF;
    bytes[i + 1] = (argb >> 16) & 0xFF;
    bytes[i + 2] = (argb >> 8) & 0xFF;
    bytes[i + 3] = 0xFF;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, side, side, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The fixture pictures, built where the engine's own loop is running: a
/// `testWidgets` body has a fake clock, and an image decode started inside it
/// never calls back — which is a hang, not a failure.
Future<Uint8List> redPng(WidgetTester tester) async =>
    (await tester.runAsync(() => pngOf(0xFFFF0000)))!;

Future<Uint8List> bluePng(WidgetTester tester) async =>
    (await tester.runAsync(() => pngOf(0xFF0000FF)))!;

Future<Uint8List> greenPng(WidgetTester tester) async =>
    (await tester.runAsync(() => pngOf(0xFF00FF00)))!;

/// A picture the reader chose: a name and the bytes it reads.
PickedPicture picked(String name, Uint8List png) =>
    PickedPicture(name: name, read: () async => png);

/// The reader who chooses nothing: the dialog opens and is cancelled.
class QuietPicker implements PicturePicker {
  int calls = 0;

  @override
  Future<List<PickedPicture>> pick() async {
    calls++;
    return const [];
  }
}

/// The reader's answers to the file dialog, in order (FR-025): each entry is
/// either the pictures that round produced or an [Exception] the picker throws.
class PickingPictures implements PicturePicker {
  PickingPictures(this.answers);

  final List<Object> answers;
  int calls = 0;

  /// How many pictures the reader's own dialog has handed over so far: the
  /// pictures the page should be showing once its storing has landed.
  int get handedOver => answers
      .take(calls)
      .whereType<List<PickedPicture>>()
      .fold(0, (total, answer) => total + answer.length);

  @override
  Future<List<PickedPicture>> pick() async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (answer is Exception) throw answer;
    return answer as List<PickedPicture>;
  }
}
