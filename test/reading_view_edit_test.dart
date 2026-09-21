import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EditFakeReader implements Reader {
  final List<String> spoken = [];
  int stops = 0;
  bool speaking = false;

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
    speaking = !speaking;
  }

  @override
  bool get isSpeaking => speaking;

  @override
  bool get isPaused => !speaking && stops > 0;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => [];

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    for (var i = 0; i < paragraphs.length; i++) {
      onParagraphStart?.call(i);
      spoken.add(paragraphs[i].text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

class _HangingFakeReader extends _EditFakeReader {
  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    for (var i = 0; i < paragraphs.length; i++) {
      onParagraphStart?.call(i);
      spoken.add(paragraphs[i].text);
    }
    speaking = true;
    // Never completes: observes the view mid-speech. stop() releases it.
    await Completer<void>().future;
  }

  @override
  Future<void> stop() async {
    stops++;
    speaking = false;
  }
}

const _firstSentence = 'The sun rose over the quiet town.';

/// Offset inside the first sentence, measured on the live RichText
/// (READ/SPEAKING show RichText; the TextField exists only in EDIT).
Future<Offset> _tapFirstSentence(WidgetTester tester) async {
  // Content is always RichText now (single widget for both states).
  final topLeft = tester.getTopLeft(
      find.textContaining('The sun rose', findRichText: true));
  return topLeft + const Offset(10, 10);
}

bool _spanHasYellow(InlineSpan span, String sentence) {
  if (span is TextSpan) {
    if (span.text == sentence &&
        span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    if (span.children != null) {
      for (final child in span.children!) {
        if (_spanHasYellow(child, sentence)) return true;
      }
    }
  }
  return false;
}

bool _hasYellow(WidgetTester tester, String sentence) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasYellow(rich.text, sentence)) return true;
  }
  return false;
}

void main() {
  SharedPreferences.setMockInitialValues({});

  group('US2 direct-edit modes (003)', () {
    testWidgets('READ is default: RichText area, Edit offered, no paste box',
        (tester) async {
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
          ],
          home: ReadingView(reader: _EditFakeReader())));
      // READ shows RichText (yellow-highlight capable), no field, no caret.
      expect(find.byType(RichText), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
      // Paste box + Load are gone.
      expect(find.text('Paste text to read'), findsNothing);
      expect(find.text('Load'), findsNothing);
    });

    testWidgets('READ tap highlights sentence yellow, does not speak',
        (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tapAt(await _tapFirstSentence(tester));
      await tester.pump();
      expect(_hasYellow(tester, _firstSentence), isTrue);
      expect(fake.spoken, isEmpty);
    });

    testWidgets('Read speaks pending sentence; none pending shows hint',
        (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken, isEmpty);
      expect(find.text('Tap a sentence to read'), findsOneWidget);
      await tester.tapAt(await _tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.spoken, [_firstSentence]);
    });

    testWidgets('READ long-press highlights paragraph yellow',
        (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.longPressAt(await _tapFirstSentence(tester));
      await tester.pump();
      expect(
        _hasYellow(tester,
            'The sun rose over the quiet town. Birds sang in the tall trees.'),
        isTrue,
      );
      expect(fake.spoken, isEmpty);
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(
        fake.spoken,
        ['The sun rose over the quiet town. Birds sang in the tall trees.'],
      );
    });

    testWidgets('Edit mode: TextField, read buttons hidden, Done shows',
        (tester) async {
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
          ],
          home: ReadingView(reader: _EditFakeReader())));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Done'), findsOneWidget);
      expect(find.byTooltip('Read'), findsNothing);
      expect(find.byTooltip('Read page'), findsNothing);
      expect(find.byTooltip('Stop'), findsNothing);
    });

    testWidgets('typing in EDIT + Done commits; Read page speaks new text',
        (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tapAt(await _tapFirstSentence(tester));
      await tester.pump();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hello edited world.');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      // Back to RichText READ with the committed content.
      expect(find.byType(TextField), findsNothing);
      // Pending sentence cleared by editing: Read page reads new content.
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.spoken, ['Hello edited world.']);
    });

    testWidgets('Edit disabled while speaking, back after Stop',
        (tester) async {
      final fake = _HangingFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.isSpeaking, isTrue);
      Finder editBtn() =>
          find.descendant(of: find.byType(RawTooltip), matching: find.byType(IconButton));
      final btn1 = tester.widget<IconButton>(editBtn());
      expect(btn1.onPressed, isNull);
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      final btn2 = tester.widget<IconButton>(editBtn());
      expect(btn2.onPressed, isNotNull);
    });

    testWidgets('sample buttons load content in READ and EDIT',
        (tester) async {
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
          ],
          home: ReadingView(reader: _EditFakeReader())));
      await tester.tap(find.text('中文示例'));
      await tester.pump();
      expect(
        find.textContaining('清晨', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.tap(find.text('EN sample'));
      await tester.pump();
      // Sample load keeps EDIT mode (still editable, Done still shows).
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Done'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('The sun rose'),
      );
    });
  });

  group('US2 edge cases (003)', () {
    testWidgets('empty content: Read page hints, no crash', (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.spoken, isEmpty);
      expect(find.text('Nothing to read.'), findsOneWidget);
    });

    testWidgets('rapid Edit/Done toggling keeps content and mode',
        (tester) async {
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
          ],
          home: ReadingView(reader: _EditFakeReader())));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Edit'));
        await tester.pump();
        await tester.tap(find.byTooltip('Done'));
        await tester.pump();
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Read page'), findsOneWidget);
    });

    testWidgets('Done with unchanged text reads full page', (tester) async {
      final fake = _EditFakeReader();
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
        home: ReadingView(reader: fake)));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.spoken.length, 3);
    });
  });
}
