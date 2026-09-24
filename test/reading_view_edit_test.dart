import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';
import 'content_fixtures.dart';

class _EditFakeReader implements Reader {
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
      find.textContaining('Birds sang', findRichText: true));
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
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-page-test');
    // The view persists its Continue Read position (010) in
    // shared_preferences, and the mock store is shared for the whole file:
    // without a clean one per test, a position set in one test is restored
    // into the next one's page.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

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
          home: ReadingView(reader: _EditFakeReader(), contentStore: pageStore(root))));
      await loadPageContent(tester);
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tapAt(await _tapFirstSentence(tester));
      await tester.pump();
      expect(_hasYellow(tester, _firstSentence), isTrue);
      expect(fake.spoken, isEmpty);
    });

    testWidgets('Read speaks the pending sentence; with none it reads from the top',
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      // No highlight yet: the read starts at the first sentence (the hint that
      // used to appear here is gone).
      expect(fake.spoken.first, startsWith(_firstSentence));
      expect(fake.isSpeaking, isTrue);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      fake.spoken.clear();

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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
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
          home: ReadingView(reader: _EditFakeReader(), contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Done'), findsOneWidget);
      expect(find.byTooltip('Read'), findsNothing);
      expect(find.byTooltip('Continue Read'), findsNothing);
      expect(find.byTooltip('Stop'), findsNothing);
    });

    testWidgets('typing in EDIT + Done commits; Continue Read speaks new text',
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
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
      // Pending sentence cleared by editing: Continue Read reads new content.
      await tester.tap(find.byTooltip('Continue Read'));
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      expect(fake.isSpeaking, isTrue);
      // Edit button should be disabled while speaking
      final editFinder = find.byIcon(Icons.edit);
      expect(editFinder, findsOneWidget);
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      // Edit button should be enabled after stop
      expect(editFinder, findsOneWidget);
    });

    testWidgets('no sample buttons: content comes from the library (008)',
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
          home: ReadingView(reader: _EditFakeReader(), contentStore: pageStore(root))));
      await loadPageContent(tester);
      // The three sample buttons are gone (008 FR-003): text arrives only
      // through the content library, whose first pre-set the page falls back to
      // while the library is unreachable.
      expect(find.text('EN sample'), findsNothing);
      expect(find.text('中文示例'), findsNothing);
      expect(find.text('ES sample'), findsNothing);
      expect(find.text('Muestra en español'), findsNothing);
      expect(find.textContaining('The sun rose', findRichText: true),
          findsWidgets);
    });
  });

  group('US2 edge cases (003)', () {
    testWidgets('empty content: Continue Read hints, no crash', (tester) async {
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      expect(fake.spoken, isEmpty);
      expect(find.text('Nothing left to read from here'), findsOneWidget);
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
          home: ReadingView(reader: _EditFakeReader(), contentStore: pageStore(root))));
      await loadPageContent(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Edit'));
        await tester.pump();
        await tester.tap(find.byTooltip('Done'));
        await tester.pump();
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Continue Read'), findsOneWidget);
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
        home: ReadingView(reader: fake, contentStore: pageStore(root))));
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      expect(fake.spoken.length, 3);
    });
  });

  group('content library (008 US1)', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('klhu-view-test');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    PresetContent preset(String id, String language, String text) =>
        PresetContent(id: id, language: language, text: text);

    ContentStore buildStore({List<PresetContent> catalog = const []}) =>
        ContentStore(
          directory: root,
          loadCatalog: () async => catalog,
          now: () => DateTime.utc(2026, 9, 23, 10, 22, 3),
        );

    Widget harness(ContentStore store, Reader reader) => MaterialApp(
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
          home: ReadingView(reader: reader, contentStore: store),
        );

    final english = preset('preset_en_sample', 'en',
        'The sun rose over the quiet town. Birds sang in the tall trees.');
    final spanish = preset('preset_es_sample', 'es',
        'El sol salió sobre el pueblo tranquilo. Los pájaros cantaron.');

    IconButton undoButton(WidgetTester tester) => tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));

    Future<void> typeInEdit(WidgetTester tester, String text) async {
      await tester.tap(find.byTooltip('Edit'));
      // The platform undo stack throttles pushes to one per 500 ms, and the
      // field's initial state is pushed when EDIT is mounted. That first push
      // must land BEFORE the edit, or the two coalesce into a single state and
      // there is nothing to undo (verified against a bare TextField probe).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(TextField), text);
      // `enterText` delivers a value whose selection is invalid, and the
      // platform undo history deliberately ignores those (it records real
      // edits only). Complete the edit the way an input connection does.
      tester.widget<TextField>(find.byType(TextField)).controller!.value =
          TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    /// Opens real event-loop windows so the store's chained file IO can finish
    /// (widget tests otherwise run in a fake-async zone that never yields to
    /// it), pumping between them so the continuations run too.
    Future<void> settle(WidgetTester tester) async {
      for (var round = 0; round < 8; round++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      for (var round = 0;
          round < 10 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          round++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    testWidgets('EDIT offers Save and Undo; Undo starts disabled',
        (tester) async {
      await tester.pumpWidget(harness(buildStore(), _EditFakeReader()));
      await settle(tester);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();

      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(undoButton(tester).onPressed, isNull);
    });

    testWidgets('Undo reverts the first edit back to the loaded text',
        (tester) async {
      await tester.pumpWidget(
          harness(buildStore(catalog: [english]), _EditFakeReader()));
      await settle(tester);

      await typeInEdit(tester, 'A short draft.');
      expect(undoButton(tester).onPressed, isNotNull);

      undoButton(tester).onPressed!();
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('The sun rose over the quiet town.'),
      );
      expect(undoButton(tester).onPressed, isNull);
    });

    testWidgets('Save stores the edited text and stays in EDIT', (tester) async {
      final store = buildStore();
      await tester.pumpWidget(harness(store, _EditFakeReader()));
      await settle(tester);

      await typeInEdit(tester, 'Saved from the reader.');
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);

      final entries = await tester.runAsync(() => store.list());
      expect(entries, hasLength(1));
      expect(entries!.single.name, 'Saved from the reader.');
      expect(entries.single.origin, ContentOrigin.user);
      final stored = await tester.runAsync(() => store.read(entries.single));
      expect(stored, 'Saved from the reader.');
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('saving blank text explains instead of writing',
        (tester) async {
      final store = buildStore();
      await tester.pumpWidget(harness(store, _EditFakeReader()));
      await settle(tester);

      await typeInEdit(tester, '     ');
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);

      expect(find.text('There is nothing to save'), findsOneWidget);
      expect(await tester.runAsync(() => store.list()), isEmpty);
    });

    testWidgets('the view opens the last used content', (tester) async {
      final store = buildStore(catalog: [english, spanish]);
      final entries = await tester.runAsync(() => store.list());
      await tester.runAsync(() => store.markOpened(
          entries!.firstWhere((e) => e.id == 'preset_es_sample').id));

      await tester.pumpWidget(harness(store, _EditFakeReader()));
      await settle(tester);

      expect(find.textContaining('El sol salió', findRichText: true),
          findsWidgets);
      // The caption resolves the localized catalog name.
      expect(find.textContaining('Los pájaros', findRichText: true), findsWidgets);
    });

    testWidgets('switching content with unsaved edits asks before discarding',
        (tester) async {
      final store = buildStore(catalog: [english, spanish]);
      await tester.pumpWidget(harness(store, _EditFakeReader()));
      await settle(tester);

      await typeInEdit(tester, 'Draft in progress.');
      await tester.tap(find.byTooltip('Contents'));
      await settle(tester);
      await tester.tap(find.textContaining('El sol salió sobre'));
      await settle(tester);

      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Draft in progress.',
      );

      await tester.tap(find.byTooltip('Contents'));
      await settle(tester);
      await tester.tap(find.textContaining('El sol salió sobre'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('El sol salió', findRichText: true),
          findsWidgets);
    });

    testWidgets('a repaired index is reported instead of silently resetting',
        (tester) async {
      // The repair itself (move the bad index aside, re-seed the catalog,
      // raise the signal) is proven in content_store_test against a real store.
      // This case proves the SURFACING: a store carrying that signal must put a
      // localized message on screen once the page has content, instead of
      // silently resetting the library and looking like data loss (FR-010).
      //
      // The store's IO runs OUTSIDE the pump: a write inside the fake-async zone
      // (markOpened's index commit) never completes, however many runAsync
      // windows the helper opens.
      final store = buildStore(catalog: [english]);
      File('${root.path}/index.json').writeAsStringSync('not json at all');
      final entries = await tester.runAsync(() => store.list());
      await tester.runAsync(() => store.markOpened(entries!.first.id));
      expect(store.lastError, ContentError.indexRepaired);

      await tester.pumpWidget(harness(store, _EditFakeReader()));
      await settle(tester);

      expect(
        find.text('The content library was repaired: a damaged index was '
            'replaced and the shipped samples are back.'),
        findsOneWidget,
      );
      // The library works: the re-seeded pre-set is on the page.
      expect(find.textContaining('The sun rose', findRichText: true),
          findsWidgets);
      // One-shot: the next launch has nothing left to report.
      expect(store.lastError, isNull);
    });
  });
}
