/// The page follows the read (spec 011 US1, the 2026-09-24 amendment):
/// quickstart scenarios 2–6. The step is the sentence being spoken — the same
/// unit the yellow highlight paints, the engine speaks and 010 resumes from —
/// so every assertion here is about the SPAN the read reported, not about a
/// paragraph that contains it.
///
/// The reader is a fake that plans the read the way [ReaderService] does
/// (paragraph.start + the sentence's own range) and reports sentences on
/// demand, so a test can put the page in any tracking state without waiting
/// for audio to play.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// A content far taller than the test viewport, in one paragraph so the read
/// is one speech of many sentences.
const int kLongSentences = 120;
final String longText =
    List.generate(kLongSentences, (i) => 'Sentence number $i.').join(' ');
const String longKey = 'preset_long';

/// The view's seam for tracking: plans the read exactly as the service does
/// and fires the installed callback on demand.
class FollowingReader implements Reader {
  final List<ParagraphSpeech> speeches = [];
  final List<SpokenSentence> reported = [];
  void Function(SpokenSentence spoken)? onSentenceStart;
  bool hold = true;
  bool speaking = false;
  bool paused = false;
  int stops = 0;
  Completer<void>? _parked;

  /// Every sentence the handed read will speak, in order, with absolute
  /// offsets — the plan the service would hand to the engine.
  List<SpokenSentence> get plan {
    final units = <SpokenSentence>[];
    for (var i = 0; i < speeches.length; i++) {
      final ranges = sentenceRanges(speeches[i].text);
      for (var j = 0; j < ranges.length; j++) {
        units.add(SpokenSentence(
          paragraph: i,
          sentence: j,
          start: speeches[i].start + ranges[j].start,
          end: speeches[i].start + ranges[j].end,
        ));
      }
    }
    return units;
  }

  /// Reports [spoken] as the engine starting it (what the service does before
  /// each utterance).
  void fire(SpokenSentence spoken) {
    reported.add(spoken);
    onSentenceStart?.call(spoken);
  }

  void fireAt(int index) => fire(plan[index]);

  /// Lets the parked read finish.
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
    speeches
      ..clear()
      ..addAll(paragraphs);
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
    root = Directory.systemTemp.createTempSync('klhu-follow-test');
    // The view's default VoiceStore and the 010 position store are both real
    // shared_preferences: one clean mock per test.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A viewport of the test's choosing: 400x600 leaves a reading area a little
  /// under 500px tall, so which texts fit is decided here and not by the host.
  void useViewport(WidgetTester tester,
      [Size size = const Size(400, 600)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ContentStore longStore() => ContentStore(
        directory: root,
        loadCatalog: () async => [
          PresetContent(id: longKey, language: 'en', text: longText),
        ],
        now: () => DateTime.utc(2026, 9, 24, 9, 0, 0),
      );

  Future<void> openPage(WidgetTester tester, FollowingReader fake,
      {ContentStore? store}) async {
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
          Locale('es'),
        ],
        home: ReadingView(reader: fake, contentStore: store ?? longStore()),
      ),
    );
    await loadPageContent(tester);
  }

  Future<void> continueRead(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Continue Read'));
    await tester.pump();
  }

  group('US1 (amendment): the page follows the spoken sentence', () {
    testWidgets('short text: no scroll', (tester) async {
      useViewport(tester);
      final fake = FollowingReader();
      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await openPage(tester, fake, store: pageStore(root));
        await continueRead(tester);
        expect(fake.plan, isNotEmpty);

        for (final spoken in fake.plan) {
          fake.fire(spoken);
          await tester.pump();
          expect(scrollPosition(tester).pixels, 0.0,
              reason: 'report at ${spoken.start} moved a text that fits');
          // The paint is the reported span, not its paragraph (FR-020).
          expect(
            hasYellow(tester, sentText(kSampleEnText, spoken)),
            isTrue,
            reason: 'the report at ${spoken.start} is not painted',
          );
        }

        // One follow line per report, each one saying the sentence is already
        // on screen — so the framework's reveal was never needed
        // (FR-003/SC-003).
        final follow =
            logs.where((line) => line.startsWith('klhu follow:')).toList();
        expect(follow.length, fake.plan.length);
        expect(follow.every((line) => line.contains('visible=1')), isTrue);
      });
    });

    testWidgets('long text: the spoken sentence comes into view',
        (tester) async {
      useViewport(tester);
      final fake = FollowingReader();
      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await openPage(tester, fake);
        await continueRead(tester);
        expect(fake.plan.length, greaterThan(20));

        // The last sentence of the read is far below the fold.
        final spoken = fake.plan.last;
        fake.fire(spoken);
        await tester.pumpAndSettle();

        expect(scrollPosition(tester).pixels, greaterThan(0.0),
            reason: 'a sentence below the fold did not move the page');
        expect(boxIsInsideViewport(tester, spoken), isTrue,
            reason: 'the revealed sentence is not inside the viewport');
        // …and the span that was revealed is the span that was painted.
        expect(hasYellow(tester, sentText(longText, spoken)), isTrue);

        final geometry = FollowLine.parse(logs.last);
        expect(geometry.visible, 1);
        expect(geometry.top, greaterThanOrEqualTo(0));
        expect(geometry.bottom, greaterThan(geometry.top));
        expect(geometry.bottom, lessThanOrEqualTo(geometry.viewport));
      });
    });

    testWidgets('Continue Read from a stored position shows it first',
        (tester) async {
      useViewport(tester);
      final offset = longText.indexOf('Sentence number 60.');
      SharedPreferences.setMockInitialValues({
        'read_position_$longKey': '$offset||${longText.length}',
      });
      final fake = FollowingReader();
      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await openPage(tester, fake);

        // 010 D8: the restored position is shown before any read starts.
        expect(hasYellow(tester, 'Sentence number 60.'), isTrue);
        await continueRead(tester);
        expect(fake.plan.first.start, offset);

        fake.fireAt(0);
        await tester.pumpAndSettle();
        expect(hasYellow(tester, 'Sentence number 60.'), isTrue);
        expect(boxIsInsideViewport(tester, fake.plan.first), isTrue);
        expect(FollowLine.parse(logs.last).visible, 1);
      });
    });

    testWidgets('manual scroll is not undone; a resumed sentence repaints',
        (tester) async {
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      await continueRead(tester);
      final spoken = fake.plan[0];
      fake.fire(spoken);
      await tester.pumpAndSettle();

      // Scroll away by hand, then re-report the SAME sentence — exactly what a
      // resume does for the sentence it interrupted.
      final position = scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final manual = position.pixels;
      expect(manual, greaterThan(0.0));

      fake.fire(spoken);
      await tester.pumpAndSettle();
      expect(scrollPosition(tester).pixels, manual,
          reason: 'a resumed sentence dragged the page back (FR-004/FR-005)');
      // …and it puts the highlight back on the sentence being repeated.
      expect(hasYellow(tester, sentText(longText, spoken)), isTrue);

      // The next sentence is revealed, minimally: the page moves, but that one
      // sentence ends up inside the viewport.
      fake.fireAt(1);
      await tester.pumpAndSettle();
      expect(hasYellow(tester, sentText(longText, fake.plan[1])), isTrue);
      expect(boxIsInsideViewport(tester, fake.plan[1]), isTrue);
    });

    testWidgets('offsets are in range and never go backwards in one read',
        (tester) async {
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      // An anchored read: its first speech is a paragraph remainder, the case
      // the reader clips to whole sentences. The tap must land on a sentence
      // that is on screen — a point below the fold belongs to no gesture.
      await tester.tapAt(offsetOf(tester, 'Sentence number 2.', longText));
      await tester.pump();
      await continueRead(tester);
      expect(fake.plan.first.start, longText.indexOf('Sentence number 2.'));

      final starts = <int>[];
      for (final spoken in fake.plan) {
        expect(spoken.start, greaterThanOrEqualTo(0));
        expect(spoken.end, greaterThan(spoken.start));
        expect(spoken.end, lessThanOrEqualTo(longText.length));
        fake.fire(spoken);
        await tester.pump();
        starts.add(spoken.start);
      }
      expect(starts, orderedEquals(List<int>.of(starts)..sort()));
      expect(reportedYellowIsLastSentence(tester, fake), isTrue);
    });

    testWidgets('the highlight clears at the end of the read and on Stop',
        (tester) async {
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      await continueRead(tester);
      fake.fireAt(1);
      await tester.pump();
      expect(hasAnyYellow(tester), isTrue);

      // Natural end: the fake released, so the read finishes.
      fake.release();
      await tester.pump();
      await tester.pump();
      expect(hasAnyYellow(tester), isFalse);

      // Stop mid-read clears it too (003's rule, kept).
      await continueRead(tester);
      fake.fireAt(2);
      await tester.pump();
      expect(hasAnyYellow(tester), isTrue);
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(hasAnyYellow(tester), isFalse);
    });
  });
}

/// The text of the span [spoken] names, inside [content].
String sentText(String content, SpokenSentence spoken) =>
    content.substring(spoken.start, spoken.end);

bool reportedYellowIsLastSentence(WidgetTester tester, FollowingReader fake) {
  final last = fake.reported.last;
  return hasYellow(tester, longText.substring(last.start, last.end));
}

/// The reading area's scroll position (the page's only scrollable in READ).
ScrollPosition scrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position;
}

/// The reading content's render paragraph, whatever text it holds.
RenderParagraph contentRender(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    if (widget.text.toPlainText() == longText ||
        widget.text.toPlainText() == kSampleEnText) {
      return element.renderObject as RenderParagraph;
    }
  }
  throw StateError('reading content RichText not found');
}

/// [spoken]'s box in global coordinates, measured on the rendered paragraph.
Rect sentenceBox(WidgetTester tester, SpokenSentence spoken) {
  final render = contentRender(tester);
  final boxes = render.getBoxesForSelection(
    TextSelection(baseOffset: spoken.start, extentOffset: spoken.end),
  );
  if (boxes.isEmpty) {
    throw StateError('no boxes for ${spoken.start}..${spoken.end}');
  }
  final rect = boxes
      .map((box) => box.toRect())
      .reduce((a, b) => a.expandToInclude(b));
  return render.localToGlobal(rect.topLeft) & rect.size;
}

/// The page's visible area, in global coordinates.
Rect viewportRect(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byType(SingleChildScrollView),
  );
  return box.localToGlobal(Offset.zero) & box.size;
}

/// FR-001/SC-001 expressed as geometry: the reported sentence is fully inside
/// the visible area by the time it is reported.
bool boxIsInsideViewport(WidgetTester tester, SpokenSentence spoken) {
  final box = sentenceBox(tester, spoken);
  final view = viewportRect(tester);
  return box.top >= view.top - 0.5 && box.bottom <= view.bottom + 0.5;
}

/// A global point inside [target]'s first characters, so a tap resolves to it.
Offset offsetOf(WidgetTester tester, String target, String text) {
  final render = contentRender(tester);
  final start = text.indexOf(target);
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

/// Runs [body] with `debugPrint` captured into [logs]: the `klhu follow:` line
/// is the evidence the device walk reads, so its shape is pinned here too.
///
/// `debugPrint` is a foundation debug variable and the binding asserts it is
/// back to normal by the end of the test BODY — so it is restored here, not in
/// a tearDown (which runs after that check).
Future<void> withCapturedLogs(
  List<String> logs,
  Future<void> Function() body,
) async {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
}

/// The parsed `klhu follow:` evidence line: which sentence, whether it was
/// already visible, and its box against the visible area's height.
class FollowLine {
  final int paragraph;
  final int sentence;
  final int visible;
  final int top;
  final int bottom;
  final int viewport;

  const FollowLine({
    required this.paragraph,
    required this.sentence,
    required this.visible,
    required this.top,
    required this.bottom,
    required this.viewport,
  });

  static FollowLine parse(String line) {
    final match = RegExp(
      r'^klhu follow: p(\d+) s(\d+) visible=(\d+) top=(-?\d+) '
      r'bottom=(-?\d+) viewport=(\d+)$',
    ).firstMatch(line);
    if (match == null) {
      throw FormatException('unexpected follow line: $line');
    }
    return FollowLine(
      paragraph: int.parse(match.group(1)!),
      sentence: int.parse(match.group(2)!),
      visible: int.parse(match.group(3)!),
      top: int.parse(match.group(4)!),
      bottom: int.parse(match.group(5)!),
      viewport: int.parse(match.group(6)!),
    );
  }
}
