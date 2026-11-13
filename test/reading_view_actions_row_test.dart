import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';
import 'reading_view_video_test.dart'
    show PageFileStore, PagePlayer, QuietPicker, QuietReader,
        RecordingEncoder;

void main() {
  late Directory root;
  late Directory work;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu-actions');
    work = Directory.systemTemp.createTempSync('klhu-actions-work');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    work.deleteSync(recursive: true);
  });

  ContentStore store() => ContentStore(
        directory: root,
        loadCatalog: () async => [
          PresetContent(
              id: 'preset_actions', language: 'en', text: kSampleEnText),
        ],
        now: () => DateTime.utc(2026, 9, 26, 9),
      );

  // Regression: with every page action offered (video included), the
  // portrait action row is 8 x 48dp = 384dp and overflowed a ~350dp window
  // on a phone set to a larger display size (OnePlus 13).
  testWidgets('action row scrolls instead of overflowing on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(1120, 2400);
    tester.view.devicePixelRatio = 3.5; // ~320dp wide
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ReadingView(
        reader: QuietReader(),
        contentStore: store(),
        videoEncoder: RecordingEncoder(work),
        videoWorkDir: work,
        videoFileStore: PageFileStore(),
        videoPlayer: PagePlayer(),
        picturePicker: QuietPicker(),
      ),
    ));
    await loadPageContent(tester);
    await tester.pumpAndSettle();

    // Every action is still reachable: the row scrolls horizontally.
    expect(find.byTooltip('Settings'), findsOneWidget);
    // And the actions still lead from the right edge they always did.
    expect(tester.getCenter(find.byTooltip('Settings')).dx,
        greaterThan(200));
  });
}
