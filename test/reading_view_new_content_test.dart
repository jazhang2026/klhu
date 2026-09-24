/// "+" from the contents list (spec 011 US3): quickstart scenario 19 — the
/// blank draft, the auto-named save, the refused empty save, the draft left
/// behind, and the content that was on screen before all of it.
///
/// The reader never speaks here: this story is about the page's own state, and
/// what the library holds afterwards.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// A reader that never speaks.
class SilentReader implements Reader {
  bool _speaking = false;

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    _speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> speak(String text, String language) async {}

  @override
  Future<void> stop() async => _speaking = false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  bool get isSpeaking => _speaking;

  @override
  bool get isPaused => false;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => [];

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-new-content-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> openPage(WidgetTester tester, ContentStore store) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: ReadingView(reader: SilentReader(), contentStore: store),
      ),
    );
    await loadPageContent(tester);
  }

  /// Opens the library and taps its add action (011 FR-015).
  Future<void> addContent(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Contents'));
    await loadPageContent(tester);
    await tester.tap(find.byTooltip('Add content'));
    await loadPageContent(tester);
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Contents'));
    await loadPageContent(tester);
  }

  /// How many entries the library holds (the seeded pre-sets included).
  Future<int> entryCount(WidgetTester tester, ContentStore store) async =>
      (await tester.runAsync(() => store.list()))!.length;

  Future<String?> storedPosition() async => (await SharedPreferences
          .getInstance())
      .getString('read_position_preset_en_sample');

  testWidgets('the add action opens a blank editor, with nothing created',
      (tester) async {
    final store = pageStore(root);
    await openPage(tester, store);
    expect(await entryCount(tester, store), 3);

    await addContent(tester);

    // A blank, editable, focused draft — and no entry behind it (FR-016):
    // asking for a content is not creating one.
    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '');
    expect(field.focusNode?.hasFocus, isTrue);
    expect(await entryCount(tester, store), 3,
        reason: 'the add action created an entry');
  });

  testWidgets('saving the draft creates an auto-named entry', (tester) async {
    final store = pageStore(root);
    await openPage(tester, store);
    await addContent(tester);

    await tester.enterText(find.byType(TextField), 'A brand new reading.');
    await tester.pump();
    await tester.tap(find.byTooltip('Save'));
    await loadPageContent(tester);

    // 008's rule names it from the text: no name prompt, and the text stays on
    // screen (saving does not navigate away).
    final entries = await tester.runAsync(() => store.list());
    expect(entries!.length, 4);
    expect(entries.map((e) => e.name), contains('A brand new reading.'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'A brand new reading.');

    // …and it is in the library, as a row of its own.
    await openList(tester);
    expect(find.text('A brand new reading.'), findsOneWidget);
  });

  testWidgets('an empty draft is refused and creates nothing', (tester) async {
    final store = pageStore(root);
    await openPage(tester, store);
    await addContent(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    await tester.pump();

    // 008's own refusal, message included (FR-018).
    expect(find.text('There is nothing to save'), findsOneWidget);
    expect(await entryCount(tester, store), 3);
  });

  testWidgets('leaving the draft creates nothing and keeps the library',
      (tester) async {
    final store = pageStore(root);
    await openPage(tester, store);
    await addContent(tester);
    await tester.enterText(find.byType(TextField), 'Never saved.');
    await tester.pump();

    // Out through the library: the unsaved-edit guard asks first, and
    // discarding the draft loads the picked entry (008's guard, unchanged).
    await openList(tester);
    await tester.tap(find.textContaining('El sol salió'));
    await loadPageContent(tester);
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await loadPageContent(tester);

    expect(await entryCount(tester, store), 3, reason: 'the draft was saved');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the content from before keeps its text and its position',
      (tester) async {
    final store = pageStore(root);
    await openPage(tester, store);

    // A 010 position on the content that is on screen.
    await tester.tapAt(offsetOf(tester, 'Birds sang'));
    await tester.pump();
    expect(await storedPosition(), isNotNull);

    // A draft, left behind with Done.
    await addContent(tester);
    await tester.enterText(find.byType(TextField), 'A draft that is left.');
    await tester.pump();
    await tester.tap(find.byTooltip('Done'));
    await tester.pump();

    // Nothing was created, and the earlier content's record is untouched
    // (FR-019) — the draft never belonged to it.
    expect(await entryCount(tester, store), 3);
    expect(await storedPosition(), isNotNull);

    // Re-opening that content brings its own position back.
    await openList(tester);
    await tester.tap(find.textContaining('The sun rose'));
    await loadPageContent(tester);
    expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
  });
}

/// The reading-content RichText, whatever text it currently holds.
RenderParagraph contentRender(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    final plain = widget.text.toPlainText();
    if (plain == kSampleEnText || plain == kSampleEsText) {
      return element.renderObject as RenderParagraph;
    }
  }
  throw StateError('reading content RichText not found');
}

/// A global point inside [target]'s first characters, so a tap resolves to it.
Offset offsetOf(WidgetTester tester, String target) {
  final render = contentRender(tester);
  final start = kSampleEnText.indexOf(target);
  if (start < 0) throw StateError('"$target" is not in the content');
  final box = render
      .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 3))
      .first;
  return render.localToGlobal(Offset(
    (box.left + box.right) / 2,
    (box.top + box.bottom) / 2,
  ));
}

bool hasYellow(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasYellow(rich.text, text)) return true;
  }
  return false;
}

bool _spanHasYellow(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text && span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (_spanHasYellow(child, text)) return true;
    }
  }
  return false;
}
