/// Continue Read through the widget (spec 010 US1): the anchor's whole life
/// cycle — set by tap/long-press, shown, persisted, restored, cleared, and
/// ended with the highlight that shows it (011 FR-022) — plus the renamed
/// toolbar label. Quickstart scenarios 1–11.
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
    });

    testWidgets('a tap reads its sentence; Continue Read starts at the next step',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pumpAndSettle();
      // 032 FR-002/FR-004: the tap IS the read — the sentence is spoken and
      // stays painted; only the position moved, to the NEXT step.
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
      expect(fake.speeches.single.start, s2Start);
      final before = fake.reads.length;

      await continueRead(tester);

      // ⏭ picks up where the tap-read left off: the sentence AFTER the one
      // just heard, not the heard one again (032 FR-005). The pass is indexed,
      // not `reads.last` — 032's wrap may already have started the next pass.
      final pass = fake.reads[before];
      expect(pass.first.start, p2Start);
      expect(pass.first.text, text.substring(p2Start, p3Start - 2));
      expect(pass.map((s) => s.text).join('\n\n'),
          text.substring(p2Start, readEnd));
      expect(pass.last.end, readEnd);
      for (var i = 0; i + 1 < pass.length; i++) {
        expect(text.substring(pass[i].end, pass[i + 1].start), '\n\n');
      }
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
    });

    testWidgets('a long-press reads its paragraph; Continue Read starts after it',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.longPressAt(offsetOf(tester, 'codebase runs'));
      await tester.pumpAndSettle();
      // The paragraph was read whole and stays highlighted (032 FR-003/FR-004).
      expect(hasYellow(tester, text.substring(p2Start, p3Start - 2)), isTrue);
      expect(fake.speeches.single.start, p2Start);
      final before = fake.reads.length;

      await continueRead(tester);

      // The position moved past the paragraph: the next step is the first
      // sentence of the LAST paragraph.
      final pass = fake.reads[before];
      expect(pass.first.start, p3Start);
      expect(pass.first.text, text.substring(p3Start, readEnd));
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
    });

    testWidgets('a touch during a read changes nothing (FR-025)',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await continueRead(tester);
      expect(fake.speaking, isTrue);
      // Speaking: the read actions are replaced by Pause.
      expect(find.byTooltip('Continue Read'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
      final stopsBefore = fake.stops;

      // A tap and a long-press on the text do NOTHING while the read plays: no
      // stop, no selection, no position. A touch may only have woken a dimmed
      // display or stopped the page's own fling, and neither may interrupt the
      // reading (FR-025) — 010 US1 scenario 5's stop-and-re-anchor is gone.
      await tester.tapAt(offsetOf(tester, 'third paragraph'));
      await tester.pump();
      await tester.longPressAt(offsetOf(tester, 'third paragraph'));
      await tester.pump();

      expect(fake.stops, stopsBefore);
      expect(fake.speaking, isTrue);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(hasAnyYellow(tester), isFalse, reason: 'nothing was selected');

      // PAUSED is a read in progress too: the same touch changes nothing, so
      // Resume stays on offer and nothing was re-anchored.
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tapAt(offsetOf(tester, 'third paragraph'));
      await tester.pump();

      expect(fake.paused, isTrue);
      expect(fake.stops, stopsBefore);
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Continue Read'), findsNothing);
    });

    testWidgets('tracking follows the read, and the read takes the position with it',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.tapAt(offsetOf(tester, 'codebase runs'));
      await tester.pumpAndSettle();
      // Park only the ⏭ read — the tap's own read must finish first.
      fake.hold = true;
      await continueRead(tester);
      // The tap read its own sentence first; ⏭'s pass is the read after it,
      // starting at the NEXT step (032 FR-005).
      expect(fake.reads.length, greaterThanOrEqualTo(2));
      final pass = fake.reads[1];
      expect(pass.length, 2);

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
      // 032 FR-007: the pass ending does NOT end the read — it wraps to the
      // first sentence and tracking keeps painting. Stop is the only end.
      expect(fake.reads.length, greaterThan(2),
          reason: 'the finished pass wrapped to the first sentence');
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      // Stop clears the tracking highlight… (FR-020)
      expect(hasAnyYellow(tester), isFalse);
      // …and the position goes with it, in memory and on disk (FR-022): a
      // stopped read leaves nothing to continue from, so a later ⏭ starts at
      // the first sentence.
      final stoppedAt = fake.reads.length;
      await continueRead(tester);
      expect(fake.reads.length, greaterThan(stoppedAt));
      expect(fake.reads.last.first.start, 0);
    });

    testWidgets('Stop drops the position, in memory and on disk', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();

      // The highlight is gone, so the position is gone with it (FR-022) — the
      // leftovers must not decide where the next read starts.
      expect(hasAnyYellow(tester), isFalse);
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.first.text, text.substring(0, p1End));
    });

    testWidgets('rapid taps leave the last position in force', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      // No frame in between: the gestures queue up — and each is a READ now
      // (032), so the last tap's own read is what counts.
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.tapAt(offsetOf(tester, 'codebase runs'));
      await tester.tapAt(offsetOf(tester, 'third paragraph'));
      await tester.pumpAndSettle();
      final before = fake.reads.length;
      await continueRead(tester);

      // …and the one the read starts from: the step AFTER the last tap's
      // sentence — 'It tests paragraph-level…', not the paragraph's start.
      expect(fake.reads[before].first.start,
          text.indexOf('It tests paragraph-level'));
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
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
      // Done saves before it leaves the editor: the store write is real file
      // IO, so a real event-loop window is needed to see READ again.
      await loadPageContent(tester);

      final anchor = mixed.indexOf('Birds sang');
      await tester.tapAt(offsetOf(tester, 'Birds sang', inText: mixed));
      await tester.pumpAndSettle();
      // The tap read 'Birds sang.'; ⏭ continues at the NEXT step — the first
      // sentence of the Chinese paragraph (032 FR-005). The save's SnackBar
      // still covers the bottom bar: let it time out first.
      final zhStart = mixed.indexOf('清晨');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final before = fake.reads.length;
      await continueRead(tester);
      final pass = fake.reads[before];

      expect(pass.length, 1);
      expect(pass[0].start, zhStart);
      expect(pass[0].text, mixed.substring(zhStart));
      expect(pass[0].language, 'zh-Hans');
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
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
      // The earlier tap was itself a read (032) — what matters is that ⏭
      // adds nothing once the text is empty.
      final before = fake.reads.length;
      await continueRead(tester);

      expect(fake.reads.length, before);
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

  group('US1: a relaunch is a clean page, and a text change forgets the place',
      () {
    testWidgets('a fresh view restores NOTHING — no highlight, ⏭ from the top',
        (tester) async {
      final first = RecordingReader();
      await openPage(tester, first);
      await tester.longPressAt(offsetOf(tester, 'codebase runs'));
      await tester.pump();
      // The long press picked the paragraph, and that is the painted span.
      expect(hasYellow(tester, text.substring(p2Start, p3Start - 2)), isTrue);

      // A restart: the same prefs, a brand new view. 016 decision 5 retired the
      // record this group used to seed and read back ("重启一律干净"): nothing
      // was written, so nothing comes back.
      final prefs = await SharedPreferences.getInstance();
      final stored = <String, Object>{
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      };
      expect(stored['read_position_$contentKey'], isNull);
      SharedPreferences.setMockInitialValues(stored);
      await tester.pumpWidget(const SizedBox());
      final second = RecordingReader();
      await openPage(tester, second);

      expect(hasAnyYellow(tester), isFalse,
          reason: 'no highlight is restored (FR-007)');
      await continueRead(tester);
      expect(second.speeches.first.start, 0,
          reason: 'and ⏭ starts at the first sentence (010 FR-005)');
    });

    testWidgets('a committed edit clears the position in force', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      // EDIT paints no highlight, so the position is gone the moment the
      // editor opens (011 FR-022); the commit below only keeps it gone.
      await tester.enterText(find.byType(TextField), 'A new text entirely.');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      // Done saves the new text before it leaves the editor (the check icon
      // persists): that write is real file IO, so the anchor is cleared — and
      // the record with it — inside a real event-loop window.
      await loadPageContent(tester);

      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.single.text, 'A new text entirely.');
    });

    testWidgets('Save clears the position in force', (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Saved text. Second one.');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await loadPageContent(tester);

      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await continueRead(tester);
      expect(fake.speeches.first.start, 0);
      // One paragraph, so one speech: the sentence split of FR-011 lives in
      // the service's queue, not here.
      expect(fake.speeches.single.text, 'Saved text. Second one.');
    });

    testWidgets('emptying the text clears the position in force',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      // The earlier tap was itself a read (032) — what matters is that ⏭
      // adds nothing once the text is empty.
      final before = fake.reads.length;
      await continueRead(tester);
      expect(fake.reads.length, before);
    });

    testWidgets('switching content clears the position in force',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();

      await tester.tap(find.byTooltip('Contents'));
      await loadPageContent(tester);
      await tester.tap(find.textContaining('El sol salió'));
      await loadPageContent(tester);

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
