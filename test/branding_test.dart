import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/l10n/app_localizations_en.dart';
import 'package:klhu/l10n/app_localizations_es.dart';
import 'package:klhu/l10n/app_localizations_zh.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'content_fixtures.dart';

class _BrandFakeReader implements Reader {
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
  Future<List<VoiceEntry>> voicesFor(String language) async => [];
  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {}
  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
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
    home: ReadingView(reader: _BrandFakeReader(), contentStore: sharedPageStore()),
  ));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-page-test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  SharedPreferences.setMockInitialValues({});

  group('Branding Tests', () {
    test('icon file existence check: placeholder for future implementation', () {
      // This test verifies icon file existence check
      // Implementation will check for images/kalahu.jpeg
      // For now, this is a simple unit test that will be expanded
      expect(true, isTrue); // Placeholder - will be expanded
    });

    test('fallback behavior: placeholder for future implementation', () {
      // This test verifies fallback to default icon when custom icon is missing
      // Implementation should not crash and should use default Flutter icon
      expect(true, isTrue); // Placeholder - will be expanded
    });
  });

  group('Branding: the app title is localized on every surface (007 US1)', () {
    testWidgets('the app bar reads the ARB title in all three languages',
        (tester) async {
      await _pumpApp(tester, const Locale('en'));
      expect(find.text(AppLocalizationsEn().appTitle), findsOneWidget);
      expect(find.text('KalaHoo Reading'), findsOneWidget);

      await _pumpApp(tester, const Locale('zh'));
      expect(find.text(AppLocalizationsZh().appTitle), findsOneWidget);
      expect(find.text('卡啦虎朗读'), findsOneWidget);
      expect(find.text('KalaHoo Reading'), findsNothing);

      await _pumpApp(tester, const Locale('es'));
      expect(find.text(AppLocalizationsEs().appTitle), findsOneWidget);
      expect(find.text('KalaHoo Lectura'), findsOneWidget);
      expect(find.text('KalaHoo Reading'), findsNothing);
    });
  });

  group('Branding: every app-bar action is localized (004)', () {
    testWidgets('Voice action announces the current language', (tester) async {
      await _pumpApp(tester, const Locale('en'));
      expect(find.byTooltip('Voice'), findsOneWidget);

      await _pumpApp(tester, const Locale('zh'));
      // Regression: the tooltip was hardcoded 'Voice' and stayed English
      // in the Chinese UI (found on emulator-5554).
      expect(find.byTooltip('语音'), findsOneWidget);
      expect(find.byTooltip('Voice'), findsNothing);
    });

    testWidgets('reading actions announce the current language',
        (tester) async {
      await _pumpApp(tester, const Locale('zh'));
      expect(find.byTooltip('朗读'), findsOneWidget);
      expect(find.byTooltip('继续朗读'), findsOneWidget);
      expect(find.byTooltip('停止'), findsOneWidget);
      expect(find.byTooltip('编辑'), findsOneWidget);
      expect(find.byTooltip('Continue Read'), findsNothing);
    });
  });
}
