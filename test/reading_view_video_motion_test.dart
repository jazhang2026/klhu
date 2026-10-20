/// The prompt's motion switch (spec 023 US3): quickstart scenario 8 — one row
/// under the format chips, off on a fresh device, on where the record says on,
/// its answer reaching the render (the app's own `klhu render motion` line), and
/// a cancelled prompt leaving the record it found.
///
/// The page's own harness lives in `reading_view_video_test.dart` (the reader,
/// the engine, the encoder and the platform halves are declared there because
/// 012's prompt cases need them); this file imports that harness rather than
/// re-declaring five fakes, and drives the same real pipeline — the page, the
/// real renderer, the real painter.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/video_motion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';
import 'reading_view_video_test.dart';

const _text = 'One two. Three four.\n\nFive six.';
const _presetId = 'preset_short';

/// A real PNG at a 4:3 shape, so the motion has room on both axes.
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

/// The reader's own pick, handed over once: one picture, and the file dialog
/// never opens.
class _OnePicker implements PicturePicker {
  _OnePicker(this.png);

  final Uint8List png;

  @override
  Future<List<PickedPicture>> pick() async => [
        PickedPicture(name: 'quadrants.png', read: () async => png),
      ];
}

void main() {
  late Directory root;
  late Directory work;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu_video_motion_page');
    work = Directory.systemTemp.createTempSync('klhu_video_motion_work');
  });

  tearDown(() {
    for (final dir in [root, work]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  Widget pageWith(ShortEngine engine, RecordingEncoder encoder,
          {PicturePicker? picker}) =>
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
        home: ReadingView(
          reader: QuietReader(),
          contentStore: ContentStore(
            directory: root,
            loadCatalog: () async => [
              PresetContent(id: _presetId, language: 'en', text: _text),
            ],
            now: () => DateTime.utc(2026, 9, 26, 9),
          ),
          synthesizer: engine,
          videoEncoder: encoder,
          videoWorkDir: work,
          videoFileStore: PageFileStore(),
          videoPlayer: PagePlayer(),
          picturePicker: picker ?? QuietPicker(),
        ),
      );

  /// Runs the page's real work until [until], as 012's harness does.
  Future<void> letWorkRun(
    WidgetTester tester,
    bool Function() until, {
    int rounds = 400,
  }) async {
    for (var i = 0; i < rounds; i++) {
      if (until()) break;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    await tester.pump();
  }

  /// Opens the video prompt on the page's own action.
  Future<void> openPrompt(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Video'));
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    expect(find.text('Video format'), findsOneWidget);
  }

  Finder switchFinder() =>
      find.byKey(const ValueKey('video motion switch'));

  /// The reader's own way to choose a picture: the prompt holds it once the
  /// page has written the pick into its own directory (D18).
  Future<void> chooseAPicture(WidgetTester tester) async {
    final button = find.text('Choose pictures');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await letWorkRun(tester, () => find.byType(MovableThumbnail).evaluate().isNotEmpty);
    expect(find.byType(MovableThumbnail), findsOneWidget);
  }

  testWidgets('a fresh device offers the motion switch, off', (tester) async {
    await tester.pumpWidget(pageWith(ShortEngine(), RecordingEncoder(work)));
    await loadPageContent(tester);
    await openPrompt(tester);

    expect(switchFinder(), findsOneWidget,
        reason: 'one row under the format chips (FR-009)');
    final tile = tester.widget<SwitchListTile>(switchFinder());
    expect(tile.value, isFalse, reason: 'the item says (可选): off unless asked');
    expect(find.text('Picture moves gently'), findsOneWidget);
    // The prompt's own order is unchanged: the chips above it, Start below.
    expect(find.text('Video format'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('the record holding on opens the prompt with it on',
      (tester) async {
    SharedPreferences.setMockInitialValues({VideoMotionStore.key: 'on'});
    await tester.pumpWidget(pageWith(ShortEngine(), RecordingEncoder(work)));
    await loadPageContent(tester);
    await openPrompt(tester);

    expect(tester.widget<SwitchListTile>(switchFinder()).value, isTrue);
  });

  testWidgets('switching it on reaches the render, and the render says so',
      (tester) async {
    // The picture is decoded and encoded on the real clock: an image decode
    // started inside the fake clock never calls back.
    final png = await tester.runAsync(() => _png());
    await tester.pumpWidget(pageWith(ShortEngine(), RecordingEncoder(work),
        picker: _OnePicker(png!)));
    await loadPageContent(tester);
    await openPrompt(tester);
    await chooseAPicture(tester);

    await tester.tap(switchFinder());
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switchFinder()).value, isTrue);

    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await tester.tap(find.text('Start'));
      await tester.pump();
      await letWorkRun(
        tester,
        () => logs.any((l) => l.startsWith('klhu render motion')),
      );
    } finally {
      debugPrint = original;
    }

    final motionLines =
        logs.where((l) => l.startsWith('klhu render motion')).toList();
    expect(motionLines, isNotEmpty,
        reason: 'the switch\'s answer is read once, and the render carries it.'
            ' Logs: $logs');
    // The record is written on the same confirm, so the next prompt opens on it.
    expect(await VideoMotionStore().load(), isTrue);

    // Leave the page at rest: Stop, then the confirmation's own Stop.
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await letWorkRun(
      tester,
      () => find.byTooltip('Video').evaluate().isNotEmpty,
    );
  });

  testWidgets('cancelling the prompt writes nothing', (tester) async {
    await tester.pumpWidget(pageWith(ShortEngine(), RecordingEncoder(work)));
    await loadPageContent(tester);
    await openPrompt(tester);

    await tester.tap(switchFinder());
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switchFinder()).value, isTrue);

    await tester.tap(find.text('Cancel'));
    await letWorkRun(tester, () => switchFinder().evaluate().isEmpty);

    expect(await VideoMotionStore().load(), isFalse,
        reason: 'a dismissed prompt leaves the record it found (the contract)');
  });
}
