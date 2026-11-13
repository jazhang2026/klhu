import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reading_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';
import 'reading_view_new_content_test.dart' show SilentReader;

void main() {
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu-ai-dialog');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  // Regression: the skill row's label + language chips overflowed a
  // RenderFlex by ~31px on a phone-width dialog (seen on OnePlus 13).
  testWidgets('AI prompt dialog fits a phone-width screen', (tester) async {
    // OnePlus 13-ish: 1440x3168 px @ ~3.5 dpr -> ~411x905 logical.
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
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
      ],
      home: ReadingView(
          reader: SilentReader(), contentStore: pageStore(root)),
    ));
    await loadPageContent(tester);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();
    await tester.tap(find.byTooltip('AI'));
    await tester.pumpAndSettle();
    expect(find.text('AI Prompt'), findsOneWidget);
  });

  testWidgets('reading page at phone width + large font', (tester) async {
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
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
      ],
      home: ReadingView(
          reader: SilentReader(), contentStore: pageStore(root)),
    ));
    await loadPageContent(tester);
    await tester.pumpAndSettle();
  });
}
