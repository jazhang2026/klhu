/// 019 US1 — the reading page's half of the head tag (quickstart rows 4, 5 and
/// 5b): a marked line is painted at the rung the ladder gives it — its size
/// **and** its weight, in the reader's own face — and the marker is painted
/// nowhere.
///
/// The harness is `reading_view_comment_test.dart`'s: a fake reader that records
/// what it was handed, the real page over a temp content store, and a clean mock
/// `shared_preferences` per test.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The reader's own title, a subtitle under it, and a body: the shape the marks
/// are written in (`spec.md`'s Input).
const String kHeadText = '# Basic Spanish 1\n\n## Greetings\n\nHola.';

/// What the page paints for it: the same text, both markers gone.
const String kHeadDisplay = 'Basic Spanish 1\n\nGreetings\n\nHola.';

/// The same text with the markers written as spaces — the control the read's own
/// group compares against (the same lengths, so the same offsets).
const String kSpacedText = '  Basic Spanish 1\n\n   Greetings\n\nHola.';

class FakeReader implements Reader {
  final List<String> spoken = [];
  final List<ParagraphSpeech> utterances = [];
  bool speaking = false;
  bool paused = false;

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
    speaking = true;
  }

  @override
  Future<void> stop() async {
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
  Future<List<VoiceEntry>> voicesFor(String language) async => const [];

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    utterances
      ..clear()
      ..addAll(paragraphs);
    for (final paragraph in paragraphs) {
      spoken.add(paragraph.text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

/// One run the page paints, as the reader would see it: its characters, its own
/// font size and its own weight — `null` meaning the run inherits the page's
/// own style (which is what FR-010's no-regression needs).
typedef Run = ({String text, double? fontSize, FontWeight? weight, String? family});

/// Every run the page paints for [plain], in paint order.
List<Run> runsOf(WidgetTester tester, {String? plain}) {
  final wanted = plain ?? kHeadDisplay;
  final found = <Run>[];
  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    final text = span.text ?? '';
    if (text.isNotEmpty) {
      found.add((
        text: text,
        fontSize: span.style?.fontSize,
        weight: span.style?.fontWeight,
        family: span.style?.fontFamily,
      ));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (rich.text.toPlainText() == wanted) walk(rich.text);
  }
  return found;
}

/// The run that paints exactly [text], or the only one that contains it.
Run runFor(WidgetTester tester, String text, {String? plain}) {
  final runs = runsOf(tester, plain: plain);
  final exact = runs.where((run) => run.text == text).toList();
  if (exact.length == 1) return exact.single;
  final containing = runs.where((run) => run.text.contains(text)).toList();
  expect(containing, hasLength(1), reason: 'one run paints "$text"');
  return containing.single;
}

/// The reading text's own root style — the one place the reader's face, weight
/// and size reach both the rich text and the editor (011 FR-009).
TextStyle rootStyle(WidgetTester tester) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (rich.text.toPlainText() == kHeadDisplay) return rich.text.style!;
  }
  throw StateError('the reading content is not on screen');
}

/// The page's own settling: a read's resolution is async (the content store and
/// the voices), so the pumps are real-time ones, exactly as the other page
/// files do it.
Future<void> settle(WidgetTester tester) async {
  for (var round = 0; round < 4; round++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-head-page-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A store of its own for each pump: the shipped presets are seeded **once**
  /// per directory, so two pumps in one test sharing a root would read the first
  /// text twice — the fixture's own one-time seeding, not a page behaviour.
  ContentStore headStore(String text, String name) {
    final dir = Directory('${root.path}/$name')..createSync(recursive: true);
    return sampleStore(dir, catalog: [
      PresetContent(id: 'head', language: 'en', text: text),
    ]);
  }

  Future<FakeReader> pumpPage(WidgetTester tester,
      {String text = kHeadText, String name = 'one'}) async {
    final fake = FakeReader();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ReadingView(
        key: ValueKey(name),
        reader: fake,
        contentStore: headStore(text, name),
      ),
    ));
    await loadPageContent(tester);
    return fake;
  }

  group('the page paints a marked line at its rung (FR-005/FR-006/FR-007)', () {
    testWidgets('at medium a title is 24 and a subtitle 18, both at the reader\'s own weight',
        (tester) async {
      await pumpPage(tester);
      final title = runFor(tester, 'Basic Spanish 1');
      expect(title.fontSize, 24);
      expect(title.weight, FontWeight.w400);
      final subtitle = runFor(tester, 'Greetings');
      expect(subtitle.fontSize, 18);
      expect(subtitle.weight, FontWeight.w400);
    });

    testWidgets('at small a subtitle is 14 and a title 18, both regular', (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'default||small'});
      await pumpPage(tester);
      expect(runFor(tester, 'Greetings').fontSize, 14);
      expect(runFor(tester, 'Basic Spanish 1').fontSize, 18);
      expect(runFor(tester, 'Greetings').weight, FontWeight.w400);
      expect(runFor(tester, 'Basic Spanish 1').weight, FontWeight.w400);
    });

    testWidgets('at large the title is 24 bold over a 24 regular subtitle', (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'default||large'});
      await pumpPage(tester);
      final title = runFor(tester, 'Basic Spanish 1');
      expect(title.fontSize, 24);
      expect(title.weight, FontWeight.w700);
      final subtitle = runFor(tester, 'Greetings');
      expect(subtitle.fontSize, 24);
      expect(subtitle.weight, FontWeight.w400);
    });

    testWidgets('at xlarge the subtitle is bold and the title black', (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'default||xlarge'});
      await pumpPage(tester);
      expect(runFor(tester, 'Greetings').weight, FontWeight.w700);
      expect(runFor(tester, 'Basic Spanish 1').weight, FontWeight.w900);
    });

    testWidgets('the body keeps the page\'s own size and weight', (tester) async {
      await pumpPage(tester);
      final body = runFor(tester, 'Hola.');
      expect(body.fontSize, isNull, reason: 'the body inherits the page\'s own style');
      expect(body.weight, isNull);
    });

    testWidgets('the marker is painted nowhere', (tester) async {
      await pumpPage(tester);
      final painted = runsOf(tester).map((run) => run.text).join();
      expect(painted, kHeadDisplay);
      expect(painted.contains('#'), isFalse);
    });

    testWidgets('every unmarked shape is painted exactly as before', (tester) async {
      const text = '#hashtag\n\n#1 best\n\n### note\n\n#\n\nHola # mid\n\n  # Title\n\n# Title #';
      await pumpPage(tester, text: text);
      // No mark at all: the display is the content and the page paints one run
      // — the shape 015 and 017 both leave alone (SC-003).
      final runs = runsOf(tester, plain: text);
      expect(runs, hasLength(1));
      expect(runs.single.fontSize, isNull);
      expect(runs.single.weight, isNull);
    });
  });

  group('a bold body\'s marks, and the ladder\'s top (FR-006/FR-007, SC-006)', () {
    testWidgets('below the top size a bold body\'s marks are bigger and lighter',
        (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'bold||medium'});
      await pumpPage(tester);
      final title = runFor(tester, 'Basic Spanish 1');
      expect(title.fontSize, 24);
      expect(title.weight, FontWeight.w400,
          reason: 'the rung carries the weight, and the rungs above a bold '
              'medium body are the regular ones');
      expect(runFor(tester, 'Greetings').fontSize, 18);
      expect(runFor(tester, 'Greetings').weight, FontWeight.w400);
    });

    testWidgets('a bold body at xlarge: the ladder ends, both marks equal',
        (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'bold||xlarge'});
      await pumpPage(tester);
      final title = runFor(tester, 'Basic Spanish 1');
      final subtitle = runFor(tester, 'Greetings');
      expect(title.fontSize, 24);
      expect(subtitle.fontSize, 24);
      expect(title.weight, FontWeight.w900);
      expect(subtitle.weight, FontWeight.w900);
    });

    testWidgets('the reader\'s own face is the family every rung paints in',
        (tester) async {
      SharedPreferences.setMockInitialValues({AppearanceStore.key: 'serif-bold||medium'});
      await pumpPage(tester);
      expect(rootStyle(tester).fontFamily, 'serif');
      for (final run in runsOf(tester)) {
        expect(run.family, isNull,
            reason: 'a mark changes size and weight, never the face');
      }
    });
  });

  group('the read hands the engine the words, never a marker (FR-004)', () {
    testWidgets("the page's own list, per press, carries the words without the markers",
        (tester) async {
      final reader = await pumpPage(tester);
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);
      expect(reader.utterances.map((s) => s.text).toList(),
          ['Basic Spanish 1', 'Greetings', 'Hola.']);
      expect(reader.spoken.join('|').contains('#'), isFalse,
          reason: 'no marker reaches the engine');
    });

    testWidgets('the markers written as spaces give the same list but for the markers',
        (tester) async {
      final marked = await pumpPage(tester);
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);

      final spaced = await pumpPage(tester, text: kSpacedText, name: 'two');
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);

      // ignore: avoid_print
      expect(marked.utterances, hasLength(3), reason: 'both reads happened');
      expect(spaced.utterances, hasLength(3));
      expect(spaced.utterances.map((s) => s.start).toList(),
          marked.utterances.map((s) => s.start).toList());
      expect(spaced.utterances.map((s) => s.end).toList(),
          marked.utterances.map((s) => s.end).toList());
      for (var i = 0; i < marked.utterances.length; i++) {
        expect(marked.utterances[i].text, spaced.utterances[i].text.trimLeft(),
            reason: 'the same words, the same spans; only the markers differ');
      }
    });
  });
}
