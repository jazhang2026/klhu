/// The reading appearance through the widget (spec 011 US2): quickstart
/// scenarios 11–15 — the idle-only action, the offered sets, the style seam
/// (reading text and editor, never the chrome), the remembered record and the
/// dismissed change.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/appearance_screen.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// A read that parks: the tests need the page to stay mid-read.
class HoldingReader implements Reader {
  bool hold = true;
  bool speaking = false;
  bool paused = false;
  int stops = 0;
  Completer<void>? _parked;

  void release() {
    hold = false;
    _parked?.complete();
    _parked = null;
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    speaking = paragraphs.isNotEmpty;
    if (hold) {
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
    }
    speaking = false;
  }

  @override
  Future<void> stop() async {
    stops++;
    speaking = false;
    paused = false;
    _parked?.complete();
    _parked = null;
  }

  @override
  Future<void> speak(String text, String language) async {}

  @override
  Future<void> pause() async {
    paused = true;
    speaking = false;
  }

  @override
  Future<void> resume() async {
    paused = false;
    speaking = true;
  }

  @override
  bool get isSpeaking => speaking;

  @override
  bool get isPaused => paused;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => [];

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-appearance-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// The appearance action's label in every shipped locale.
  final labels = <Locale, String>{
    Locale('en'): 'Appearance',
    Locale('zh'): '外观',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'): '外观',
    Locale('es'): 'Apariencia',
  };

  Future<void> openPage(
    WidgetTester tester, {
    Reader? reader,
    Locale? locale,
    Size viewport = const Size(400, 640),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
        home: ReadingView(
          reader: reader ?? HoldingReader(),
          contentStore: pageStore(root),
        ),
      ),
    );
    await loadPageContent(tester);
  }

  Future<String?> stored() async =>
      (await SharedPreferences.getInstance()).getString(AppearanceStore.key);

  /// The reading content's own span style (never the chrome's).
  TextStyle contentStyle(WidgetTester tester) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      if (rich.text.toPlainText() == kSampleEnText) {
        return (rich.text as TextSpan).style!;
      }
    }
    throw StateError('reading content RichText not found');
  }

  IconButton action(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.format_size));

  Future<void> openScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, Icons.format_size));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceScreen), findsOneWidget);
  }

  /// Taps one of the screen's option chips, by its label.
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(AppearanceScreen),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(AppearanceScreen),
      matching: find.text('Done'),
    ));
    await tester.pumpAndSettle();
  }

  /// The read actions' labels in every shipped locale (test 11 drives a read in
  /// each of them).
  final readLabels = <Locale, (String read, String stop)>{
    Locale('en'): ('Read', 'Stop'),
    Locale('zh'): ('朗读', '停止'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'): ('朗读', '停止'),
    Locale('es'): ('Leer', 'Detener'),
  };

  testWidgets('11. the action is offered in every locale, idle-only',
      (tester) async {
    for (final entry in labels.entries) {
      final fake = HoldingReader();
      final (read, stop) = readLabels[entry.key]!;
      await openPage(tester, reader: fake, locale: entry.key);
      expect(find.byTooltip(entry.value), findsOneWidget,
          reason: 'locale ${entry.key}');
      // Idle: offered.
      expect(action(tester).onPressed, isNotNull, reason: 'locale ${entry.key}');

      // Reading: present but disabled — an appearance change mid-read would
      // fight the page's own tracking (FR-014).
      await tester.tap(find.byTooltip(read));
      await tester.pump();
      expect(action(tester).onPressed, isNull, reason: 'locale ${entry.key}');
      await tester.tap(find.byTooltip(stop));
      await tester.pump();
      expect(action(tester).onPressed, isNotNull);
    }
  });

  testWidgets('12. the offered sets are the contract\'s; xlarge fits the width',
      (tester) async {
    await openPage(tester);
    await openScreen(tester);

    // Three typefaces, four sizes, in the contract's order (scenario 12).
    for (final label in const ['Default', 'Serif', 'Mono']) {
      expect(find.text(label), findsOneWidget, reason: 'typeface $label');
    }
    for (final label in const ['Small', 'Medium', 'Large', 'Extra large']) {
      expect(find.text(label), findsOneWidget, reason: 'size $label');
    }
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The largest offered size on a 360dp-wide page still lays inside it
    // (FR-012): the paragraph is never wider than the space it has.
    SharedPreferences.setMockInitialValues({
      AppearanceStore.key: 'serif||xlarge',
    });
    await tester.pumpWidget(const SizedBox());
    await openPage(tester, viewport: const Size(360, 640));

    expect(tester.takeException(), isNull);
    final style = contentStyle(tester);
    expect(style.fontSize, ReadingSize.xlarge.points);
    final textWidth = tester
        .getSize(find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == kSampleEnText))
        .width;
    expect(textWidth, lessThanOrEqualTo(360 - 32),
        reason: 'the largest size spilled outside the page');
  });

  testWidgets('13. confirming styles the text and the editor, not the chrome',
      (tester) async {
    await openPage(tester);
    expect(contentStyle(tester).fontSize, ReadingSize.medium.points);

    await openScreen(tester);
    await choose(tester, 'Serif');
    await choose(tester, 'Extra large');
    await confirm(tester);

    final style = contentStyle(tester);
    expect(style.fontFamily, 'serif');
    expect(style.fontSize, ReadingSize.xlarge.points);
    expect(await stored(), 'serif||xlarge');

    // The editor follows the same seam (FR-009)…
    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontFamily, 'serif');
    expect(field.style?.fontSize, ReadingSize.xlarge.points);

    // …while the app's chrome keeps its own style.
    final title = tester.widget<Text>(find.text('KalaHoo Reading'));
    expect(title.style, isNull,
        reason: 'the appearance leaked into the app bar');
  });

  testWidgets('14. a fresh view renders the stored appearance', (tester) async {
    SharedPreferences.setMockInitialValues({AppearanceStore.key: 'mono||large'});
    await openPage(tester);

    final style = contentStyle(tester);
    expect(style.fontFamily, 'monospace');
    expect(style.fontSize, ReadingSize.large.points);
    expect(style.fontSize, isNot(ReadingSize.medium.points));
  });

  testWidgets('15. dismissing leaves the record and the look alone',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppearanceStore.key: 'serif||xlarge',
    });
    await openPage(tester);

    await openScreen(tester);
    await choose(tester, 'Default');
    await choose(tester, 'Small');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await stored(), 'serif||xlarge',
        reason: 'an abandoned preview wrote the record');
    final style = contentStyle(tester);
    expect(style.fontFamily, 'serif');
    expect(style.fontSize, ReadingSize.xlarge.points);
  });
}
