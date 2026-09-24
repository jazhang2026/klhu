/// Continue Read through the widget (spec 010 US1): the anchor's whole life
/// cycle — set by tap/long-press, shown, persisted, restored, cleared — plus
/// the renamed toolbar label. Quickstart scenarios 1–11.
///
/// The reader is a fake that RECORDS the speeches it is handed with their
/// offsets ([ParagraphSpeech.start]/[ParagraphSpeech.end]), because every
/// assertion here is about where a read starts, not just what it says.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The shipped EN pre-set, the text every shortcut below indexes into.
const text = kSampleEnText;

/// Second sentence of the first paragraph.
final s2Start = text.indexOf('Birds sang');
final p1Start = text.indexOf('The sun rose');
final p1End = text.indexOf('\n\n');
final p2Start = text.indexOf('Flutter makes');
final p2Sentence2Start = text.indexOf('A single codebase');
final p3Start = text.indexOf('This is the third');

/// End of the last paragraph (the trailing newline is not read).
final readEnd = text.trimRight().length;

const contentKey = 'preset_en_sample';

/// Records what it was asked to speak, with the offsets, and can park a read
/// so a test can observe the view mid-read.
class RecordingReader implements Reader {
  final List<List<ParagraphSpeech>> reads = [];
  void Function(SpokenSentence spoken)? onSentenceStart;
  final List<String> spoken = [];
  int stops = 0;
  bool hold = false;
  bool speaking = false;
  bool paused = false;
  Completer<void>? _parked;

  List<ParagraphSpeech> get speeches =>
      reads.isEmpty ? const <ParagraphSpeech>[] : reads.last;

  /// Fires the tracking callback the read installed, as the service does, for
  /// the FIRST sentence of [paragraph] — the unit tracking paints now (011
  /// FR-020).
  SpokenSentence fireFirstSentence(int paragraph) {
    final spoken =
        spokenSentences(speeches[paragraph], paragraph).first;
    onSentenceStart?.call(spoken);
    return spoken;
  }

  /// Lets the parked read finish (and stops parking the next one).
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
    reads.add(paragraphs);
    for (final p in paragraphs) {
      spoken.add(p.text);
    }
    this.onSentenceStart = onSentenceStart;
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
  Future<void> speak(String text, String language) async {
    spoken.add(text);
    speaking = true;
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
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-continue-test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  // The view's default VoiceStore and the position store are both real
  // shared_preferences: mock them per test.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openPage(
    WidgetTester tester,
    RecordingReader fake, {
    Locale? locale,
    Directory? on,
  }) async {
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
        home: ReadingView(reader: fake, contentStore: pageStore(on ?? root)),
      ),
    );
    await loadPageContent(tester);
  }

  Future<void> continueRead(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Continue Read'));
    await tester.pump();
  }

  Future<String?> record() async =>
      (await SharedPreferences.getInstance()).getString('read_position_$contentKey');

  group('US1: Continue Read with a start position', () {
    testWidgets('the toolbar offers Continue Read in every shipped locale',
        (tester) async {
      final fake = RecordingReader();
      final labels = <Locale, String>{
        Locale('en'): 'Continue Read',
        Locale('zh'): '继续朗读',
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'): '继续朗读',
        Locale('es'): 'Continuar leyendo',
      };
      for (final entry in labels.entries) {
        await openPage(tester, fake, locale: entry.key);
        expect(find.byTooltip(entry.value), findsOneWidget,
            reason: 'locale ${entry.key}');
        expect(find.byTooltip('Read page'), findsNothing);
      }
    });

    testWidgets('with no position set it reads the whole text, as before',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await continueRead(tester);

      expect(fake.speeches.length, 3);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.first.text, text.substring(0, p1End));
      expect(fake.speeches.map((s) => s.text).join('\n\n'), text.trimRight());
      expect(fake.speeches.last.end, readEnd);
      expect(await record(), isNull);
    });

    testWidgets('a tap sets the position; Continue Read starts there',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      // Feedback before any read (FR-006): the tapped sentence is painted.
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
      expect(fake.reads, isEmpty);

      await continueRead(tester);

      expect(fake.speeches.first.start, s2Start);
      expect(fake.speeches.first.text, text.substring(s2Start, p1End));
      // From the anchor to the end of the text: every paragraph in order, with
      // only the blank line between paragraphs left out.
      expect(fake.speeches.map((s) => s.text).join('\n\n'),
          text.substring(s2Start, readEnd));
      expect(fake.speeches.last.end, readEnd);
      for (var i = 0; i + 1 < fake.speeches.length; i++) {
        expect(text.substring(fake.speeches[i].end, fake.speeches[i + 1].start),
            '\n\n');
      }
      expect(await record(), '$s2Start||${text.length}');
    });

    testWidgets('a long-press sets the position at the paragraph start',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.longPressAt(offsetOf(tester, 'codebase runs'));
      await tester.pump();
      await continueRead(tester);

      // The paragraph start, not the sentence the finger landed in.
      expect(fake.speeches.first.start, p2Start);
      expect(fake.speeches.first.text, text.substring(p2Start, p3Start - 2));
      expect(await record(), '$p2Start||${text.length}');
    });

    testWidgets('a tap while speaking stops the read and re-anchors',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await continueRead(tester);
      expect(fake.speaking, isTrue);
      // Speaking: the read actions are replaced by Pause.
      expect(find.byTooltip('Continue Read'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
      final stopsBefore = fake.stops;

      fake.hold = false;
      await tester.tapAt(offsetOf(tester, 'third paragraph'));
      await tester.pump();

      expect(fake.stops, greaterThan(stopsBefore));
      expect(find.byTooltip('Continue Read'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(hasYellow(tester, 'This is the third paragraph.'), isTrue);

      await continueRead(tester);
      expect(fake.speeches.first.start, p3Start);
    });

    testWidgets('tracking follows the read; the position outlives it',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await tester.tapAt(offsetOf(tester, 'codebase runs'));
      await tester.pump();
      await continueRead(tester);
      // A tap anchors the sentence it landed in, not its paragraph.
      expect(fake.speeches.length, 2);

      // The read tracks per SENTENCE, from the anchored one on (011 FR-020):
      // the same span the engine is speaking, not the paragraph around it.
      final first = fake.fireFirstSentence(0);
      await tester.pump();
      expect(hasYellow(tester, text.substring(first.start, first.end)), isTrue);
      final second = fake.fireFirstSentence(1);
      await tester.pump();
      expect(
          hasYellow(tester, text.substring(second.start, second.end)), isTrue);
      expect(hasYellow(tester, text.substring(first.start, first.end)), isFalse);

      fake.release();
      await tester.pump();
      await tester.pump();
      // End of the read clears the tracking highlight…
      expect(hasAnyYellow(tester), isFalse);
      // …and leaves the position alone: Continue Read starts there again.
      expect(await record(), '$p2Sentence2Start||${text.length}');
      await continueRead(tester);
      expect(fake.speeches.first.start, p2Sentence2Start);
    });

    testWidgets('rapid taps leave the last position in force', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      // No frame in between: the gestures queue up.
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.tapAt(offsetOf(tester, 'codebase runs'));
      await tester.tapAt(offsetOf(tester, 'third paragraph'));
      await tester.pump();
      await continueRead(tester);

      expect(fake.speeches.first.start, p3Start);
      expect(await record(), '$p3Start||${text.length}');
    });

    testWidgets('mixed content reads per paragraph from a non-zero anchor',
        (tester) async {
      const mixed = 'The sun rose over the quiet town. Birds sang.\n\n'
          '清晨的阳光洒在安静的小镇上。鸟儿在歌唱。';
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), mixed);
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      final anchor = mixed.indexOf('Birds sang');
      await tester.tapAt(offsetOf(tester, 'Birds sang', inText: mixed));
      await tester.pump();
      await continueRead(tester);

      expect(fake.speeches.length, 2);
      expect(fake.speeches[0].start, anchor);
      expect(fake.speeches[0].text, 'Birds sang.');
      expect(fake.speeches[0].language, 'en');
      expect(fake.speeches[1].text, mixed.substring(mixed.indexOf('清晨')));
      expect(fake.speeches[1].language, 'zh-Hans');
    });
  });

  group('US1: nothing left to read', () {
    testWidgets('an empty text explains itself instead of reading',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      await continueRead(tester);

      expect(fake.reads, isEmpty);
      expect(find.text('Nothing left to read from here'), findsOneWidget);
    });

    testWidgets('the message is localized, not the old hardcoded English',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, locale: const Locale('es'));
      await tester.tap(find.byTooltip('Editar'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Listo'));
      await tester.pump();

      await tester.tap(find.byTooltip('Continuar leyendo'));
      await tester.pump();

      expect(fake.reads, isEmpty);
      expect(find.text('No queda nada por leer desde aquí'), findsOneWidget);
      expect(find.text('Nothing to read.'), findsNothing);
    });
  });

  group('US1: the position survives a restart, and a text change forgets it',
      () {
    testWidgets('a fresh view restores the stored position', (tester) async {
      final first = RecordingReader();
      await openPage(tester, first);
      await tester.longPressAt(offsetOf(tester, 'codebase runs'));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      final stored = <String, Object>{
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      };
      expect(stored['read_position_$contentKey'], '$p2Start||${text.length}');

      // A restart: same prefs, a brand new view.
      SharedPreferences.setMockInitialValues(stored);
      await tester.pumpWidget(const SizedBox());
      final second = RecordingReader();
      await openPage(tester, second);

      // D8: the restored position is shown, not silent — its sentence, which
      // is what a read from it starts with.
      expect(hasYellow(tester, 'Flutter makes it easy to build beautiful apps.'),
          isTrue);
      await continueRead(tester);
      expect(second.speeches.first.start, p2Start);
    });

    testWidgets('a malformed stored position is ignored', (tester) async {
      SharedPreferences.setMockInitialValues({
        'read_position_$contentKey': 'garbage-no-separator',
      });
      final fake = RecordingReader();
      await openPage(tester, fake);

      expect(hasAnyYellow(tester), isFalse);
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
    });

    testWidgets('a stored position whose text length changed is ignored',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'read_position_$contentKey': '$p2Start||${text.length + 1}',
      });
      final fake = RecordingReader();
      await openPage(tester, fake);

      expect(hasAnyYellow(tester), isFalse);
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
    });

    testWidgets('a committed edit clears the position and its record',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      expect(await record(), isNotNull);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'A new text entirely.');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      expect(await record(), isNull);
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.single.text, 'A new text entirely.');
    });

    testWidgets('Save clears the position and its record', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      expect(await record(), isNotNull);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Saved text. Second one.');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await loadPageContent(tester);

      expect(await record(), isNull);
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      // One paragraph, so one speech: the sentence split of FR-011 lives in
      // the service's queue, not here.
      expect(fake.speeches.single.text, 'Saved text. Second one.');
    });

    testWidgets('emptying the text clears the position and its record',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      expect(await record(), isNotNull);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      expect(await record(), isNull);
      await continueRead(tester);
      expect(fake.reads, isEmpty);
    });

    testWidgets('switching content clears the position and its record',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      expect(await record(), isNotNull);

      await tester.tap(find.byTooltip('Contents'));
      await loadPageContent(tester);
      await tester.tap(find.textContaining('El sol salió'));
      await loadPageContent(tester);

      expect(await record(), isNull);
      expect(hasAnyYellow(tester), isFalse);
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.map((s) => s.text).join('\n\n'),
          kSampleEsText.trimRight());
    });
  });
}

/// The reading-content RichText, whatever text it currently holds.
RenderParagraph contentRender(WidgetTester tester, [String? expected]) {
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    final plain = widget.text.toPlainText();
    if (expected == null
        ? (plain == kSampleEnText || plain == kSampleZhText)
        : plain == expected) {
      return element.renderObject as RenderParagraph;
    }
  }
  throw StateError('reading content RichText not found');
}

/// A global point inside [target]'s first characters, so a tap resolves to it.
Offset offsetOf(WidgetTester tester, String target, {String? inText}) {
  final content = inText ?? kSampleEnText;
  final render = contentRender(tester, content);
  final start = content.indexOf(target);
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

bool hasYellow(WidgetTester tester, String sentence) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasYellow(rich.text, sentence)) return true;
  }
  return false;
}

bool hasAnyYellow(WidgetTester tester) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasAnyYellow(rich.text)) return true;
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

bool _spanHasAnyYellow(InlineSpan span) {
  if (span is TextSpan) {
    if (span.style?.backgroundColor == Colors.yellow) return true;
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (_spanHasAnyYellow(child)) return true;
    }
  }
  return false;
}
