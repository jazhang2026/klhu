import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'content_fixtures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

class FakeReader implements Reader {
  final List<String> spoken = [];
  int stops = 0;
  bool speaking = false;
  bool paused = false;

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
    speaking = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    speaking = false;
  }

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
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    for (final p in paragraphs) {
      spoken.add(p.text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

class FailingReader extends FakeReader {
  @override
  Future<void> speak(String text, String language) async {
    // Mirrors ReaderService locale mapping ('en' → 'en-US').
    throw ReaderException('Voice not available for en-US');
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    throw ReaderException('Voice not available for en-US');
  }
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-page-test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  // ReadingView's default VoiceStore is real shared_preferences: mock it.
  SharedPreferences.setMockInitialValues({});

  // First sentence of the bundled EN sample.
  const firstSentence = 'The sun rose over the quiet town.';

  Future<Offset> tapFirstSentence(WidgetTester tester) async {
    // Content is always RichText now (single widget for both states).
    final topLeft = tester.getTopLeft(
        find.textContaining('Birds sang', findRichText: true));
    return topLeft + const Offset(10, 10);
  }

  bool hasYellowHighlight(WidgetTester tester, String sentence) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      if (_spanHasHighlight(rich.text, sentence)) return true;
    }
    return false;
  }

  bool hasAnyYellow(WidgetTester tester) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      if (_spanHasAnyYellow(rich.text)) return true;
    }
    return false;
  }

  group('US1 P1: tap sentence, hear it read', () {
    testWidgets('tap highlights the tapped sentence', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      expect(hasYellowHighlight(tester, firstSentence), isTrue);
      // Tap alone does not speak; it waits for Read (data-model invariant).
      expect(fake.spoken, isEmpty);
    });

    testWidgets('Read speaks the highlighted sentence', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken, [firstSentence]);
    });

    testWidgets('Stop halts speech', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.isSpeaking, isTrue);
      final stopsBefore = fake.stops;
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(fake.isSpeaking, isFalse);
      expect(fake.stops, stopsBefore + 1);
    });

    testWidgets('Read with no tap prompts instead of reading page',
        (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken, isEmpty);
      expect(find.text('Tap a sentence to read'), findsOneWidget);
    });

    testWidgets('missing voice shows error instead of crashing', (tester) async {
      final fake = FailingReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(
          find.text('Voice not available for en-US'), findsOneWidget);
    });

    testWidgets('switching content stops ongoing speech', (tester) async {
      final root = Directory.systemTemp.createTempSync('klhu-switch-test');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final store = ContentStore(
        directory: root,
        loadCatalog: () async => [
          PresetContent(
              id: 'preset_en_sample', language: 'en', text: kSampleEnText),
          PresetContent(
              id: 'preset_es_sample', language: 'es', text: kSampleEsText),
        ],
        now: () => DateTime.utc(2026, 9, 23, 10, 22, 3),
      );
      final fake = FakeReader();
      Future<void> settle() async {
        for (var round = 0; round < 6; round++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
      }

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
          Locale('es'),
        ],
        home: ReadingView(reader: fake, contentStore: store)));
      await settle();
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.isSpeaking, isTrue);
      final stopsBefore = fake.stops;

      // Content now switches through the library, not a sample button.
      await tester.tap(find.byTooltip('Contents'));
      await settle();
      await tester.tap(find.textContaining('El sol salió'));
      await settle();

      expect(fake.stops, stopsBefore + 1);
      expect(fake.isSpeaking, isFalse);
    });

    testWidgets('content stays one RichText across select (no font jump)',
        (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      Finder contentText() =>
          find.text(kSampleEnText, findRichText: false);
      // Plain-Text widget must never hold the content, before or after tap:
      // the Text/RichText swap rendered different metrics (font jump).
      expect(contentText(), findsNothing);
      await tester.tapAt(await tapFirstSentence(tester));
      await tester.pump();
      expect(contentText(), findsNothing);
      expect(hasYellowHighlight(tester, firstSentence), isTrue);
    });

    testWidgets('content text has explicit classic theme style', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      // Regression (emulator validation, Sep 2026): the root span must carry
      // an explicit style — ambient capture freezes MaterialApp's red-48px
      // fallback in, and a null root mispaints inherited color as white on
      // this GPU path. Only an explicit classic-sRGB theme color paints.
      final content = find.byWidgetPredicate((w) =>
          w is RichText &&
          (w.text.toPlainText() == kSampleEnText ||
              w.text.toPlainText() == kSampleZhText));
      final style = (tester.widget<RichText>(content).text as TextSpan).style;
      expect(style, isNotNull);
      expect(style!.color, isNot(equals(const Color(0xD0FF0000))));
      expect(style.fontSize, equals(14.0));
      expect(style.decoration, equals(TextDecoration.none));
      final body =
          Theme.of(tester.element(content)).textTheme.bodyMedium!;
      expect(style.color!.toARGB32(), equals(body.color!.toARGB32()));
    });
  });

  group('US2 P2: long-press paragraph, hear it read', () {
    // First paragraph of the bundled EN sample.
    const firstParagraph =
        'The sun rose over the quiet town. Birds sang in the tall trees.';

    testWidgets('long-press highlights the whole paragraph', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.longPressAt(await tapFirstSentence(tester));
      await tester.pump();
      expect(hasYellowHighlight(tester, firstParagraph), isTrue);
      expect(fake.spoken, isEmpty);
    });

    testWidgets('Read speaks the highlighted paragraph in order',
        (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.longPressAt(await tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken, [firstParagraph]);
    });

    testWidgets('single tap still resolves sentence after long-press',
        (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      final pos = await tapFirstSentence(tester);
      await tester.longPressAt(pos);
      await tester.pump();
      await tester.tapAt(pos);
      await tester.pump();
      expect(hasYellowHighlight(tester, firstSentence), isTrue);
    });
  });

  group('US3 P3: read whole page', () {
    testWidgets('Read page speaks each paragraph in order', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      // 002 US1: one speech per paragraph (not one for the whole page).
      expect(fake.spoken.length, 3);
      expect(fake.spoken.join('\n\n'), kSampleEnText.trimRight());
    });

    testWidgets('Read page clears tracking highlight at end', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      // FakeReader ignores the progress callback, so no intermediate
      // highlight is observable here — but the end state must be clean
      // (intermediate advance is covered by the US3 tracking tests).
      expect(hasAnyYellow(tester), isFalse);
    });

    testWidgets('Stop halts page read', (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.isSpeaking, isTrue);
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(fake.isSpeaking, isFalse);
    });

    testWidgets('sentence tap after Read page narrows to sentence',
        (tester) async {
      final fake = FakeReader();
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      // Measure on the live RichText: plain-Text and RichText metrics
      // differ slightly, so a position from one mis-maps on the other.
      final render = _contentRender(tester);
      const target = 'Birds sang in the tall trees.';
      final start = kSampleEnText.indexOf(target);
      final box = render
          .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + 5))
          .first;
      final pos = render.localToGlobal(Offset(
          (box.left + box.right) / 2, (box.top + box.bottom) / 2));
      await tester.tapAt(pos);
      await tester.pump();
      expect(hasYellowHighlight(tester, 'Birds sang in the tall trees.'),
          isTrue);
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken.last, 'Birds sang in the tall trees.');
    });
  });
}

/// Render object of the reading content (always a RichText).
RenderParagraph _contentRender(WidgetTester tester) {
  for (final e in find.byType(RichText).evaluate()) {
    final w = e.widget as RichText;
    if (w.text.toPlainText() == kSampleEnText ||
        w.text.toPlainText() == kSampleZhText) {
      return e.renderObject as RenderParagraph;
    }
  }
  throw StateError('reading content RichText not found');
}

bool _spanHasHighlight(InlineSpan span, String sentence) {
  if (span is TextSpan) {
    if (span.text == sentence &&
        span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    if (span.children != null) {
      for (final child in span.children!) {
        if (_spanHasHighlight(child, sentence)) return true;
      }
    }
  }
  return false;
}

bool _spanHasAnyYellow(InlineSpan span) {
  if (span is TextSpan) {
    if (span.style?.backgroundColor == Colors.yellow) return true;
    if (span.children != null) {
      for (final child in span.children!) {
        if (_spanHasAnyYellow(child)) return true;
      }
    }
  }
  return false;
}
