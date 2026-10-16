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

    testWidgets('022: the word the new line carries — how many sentences are '
        'visible below the one reported (FR-009)', (tester) async {
      // 022's own case (tasks T002). The rule it serves is positional: the page
      // moves when the sentence after the one in force is the last visible one,
      // so the line must say what follows the reported sentence, in the app's own
      // numbers, for a walked row to read (data-model INV-6).
      useViewport(tester);
      final fake = FollowingReader();
      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await openPage(tester, fake);
        await continueRead(tester);
        fake.fire(fake.plan.first);
        await tester.pumpAndSettle();
      });

      final line = logs.last;
      expect(
        RegExp(r'^klhu follow: p\d+ s\d+ visible=\d top=-?\d+ bottom=-?\d+ '
                r'viewport=\d+ below=\d+$')
            .hasMatch(line),
        isTrue,
        reason: 'the report carries no count of what follows it: $line',
      );
    });

    testWidgets('022: the reader of this suite reads the appended field, and still '
        'reads a line without it (FR-009)', (tester) async {
      // 022's own case (tasks T004). `FollowLine`'s pattern is **anchored**, so
      // the appended field is a re-cut of this suite's own reader — 011's driver
      // regex in `klhu_walk_experience.py` is unanchored and keeps matching.
      final parsed = FollowLine.parse(
        'klhu follow: p1 s2 visible=1 top=7 bottom=19 viewport=196 below=3',
      );
      expect(parsed.below, 3);
      expect(parsed.viewport, 196, reason: 'the six fields it always had are first');
      final old = FollowLine.parse(
        'klhu follow: p1 s2 visible=1 top=7 bottom=19 viewport=196',
      );
      expect(old.below, isNull, reason: 'a line without the field is still readable');
    });

    testWidgets('022: the page moves one sentence early — for the sentence whose '
        'successor is the last one visible, before that successor is highlighted '
        '(1B, FR-001/FR-002)', (tester) async {
      // The reader's own rule, read literally (2026-10-16): the auto-scroll starts
      // **before** the highlight of the sentence that would be the last one on
      // screen — so the sentence being read is never the bottom-most box.
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      await continueRead(tester);
      expect(fake.plan.length, greaterThan(20), reason: 'fixture drift');

      final view = viewportRect(tester);
      var moved = -1;
      for (var i = 0; i + 2 < fake.plan.length; i++) {
        // The sentence has to be **on screen** for the move to be the lead's:
        // 011's own rule moves the page when the sentence being read is below the
        // fold, and that is a different doorway (it is the one that ships).
        final onScreen = boxIsInsideViewport(tester, fake.plan[i]);
        // The state the rule is about, read **before** the report: is the second
        // sentence after this one below the fold while this one is on screen?
        final secondBefore = sentenceBox(tester, fake.plan[i + 2]).top;
        final before = scrollPosition(tester).pixels;
        fake.fire(fake.plan[i]);
        await tester.pumpAndSettle();
        if (onScreen &&
            secondBefore > view.bottom &&
            scrollPosition(tester).pixels > before) {
          moved = i;
          break;
        }
      }
      expect(moved, greaterThan(-1),
          reason: 'no sentence that was on screen, with its second-next below the '
              'fold, moved the page');
      expect(boxIsInsideViewport(tester, fake.plan[moved + 1]), isTrue,
          reason: 'the sentence after the one in force is not on screen');
      final after = sentenceBox(tester, fake.plan[moved + 2]);
      expect(after.top, lessThan(view.bottom),
          reason: 'nothing follows the sentence that is next to be read');
    });

    testWidgets('022: the move is a nudge — the sentence in force stays on screen, '
        'never above the top, and the page is not turned (FR-003, SC-005)',
        (tester) async {
      // US2's own case (tasks T008). "Just enough" is a claim about the rect the
      // reveal is handed: this sentence's own top through the further of the two
      // below it — so the sentence being read is still visible, its own top never
      // goes above the viewport's, and the page moves by less than its height.
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      await continueRead(tester);
      final view = viewportRect(tester);

      var checked = 0;
      for (var i = 0; i + 2 < fake.plan.length && checked < 3; i++) {
        final onScreen = boxIsInsideViewport(tester, fake.plan[i]);
        final secondBefore = sentenceBox(tester, fake.plan[i + 2]).top;
        final before = scrollPosition(tester).pixels;
        fake.fire(fake.plan[i]);
        await tester.pumpAndSettle();
        final moved = scrollPosition(tester).pixels - before;
        if (!onScreen || secondBefore <= view.bottom || moved <= 0) continue;
        expect(boxIsInsideViewport(tester, fake.plan[i]), isTrue,
            reason: 'the move carried the sentence in force off screen');
        expect(sentenceBox(tester, fake.plan[i]).top,
            greaterThanOrEqualTo(view.top - 0.5),
            reason: 'the sentence in force went above the viewport');
        expect(moved, lessThan(view.height),
            reason: 'the page was turned rather than nudged ($moved px)');
        checked++;
      }
      expect(checked, greaterThan(0),
          reason: 'the fixture produced no lead move to measure');
    });

    testWidgets('022: nothing moves when a sentence after the next one is already '
        'on screen (FR-001, SC-005)', (tester) async {
      // US2's own control (tasks T008): the rule is a relation, not a habit of
      // moving. It is green before this feature's rule exists as well — a control
      // is recorded as one, never as a RED.
      useViewport(tester);
      final fake = FollowingReader();
      await openPage(tester, fake);
      await continueRead(tester);

      final view = viewportRect(tester);
      var checked = 0;
      for (var i = 0; i + 2 < fake.plan.length && checked < 3; i++) {
        final secondBefore = sentenceBox(tester, fake.plan[i + 2]).top;
        if (secondBefore > view.bottom) continue;   // the rule may move for this one
        final before = scrollPosition(tester).pixels;
        fake.fire(fake.plan[i]);
        await tester.pumpAndSettle();
        expect(scrollPosition(tester).pixels, before,
            reason: 'a sentence with two after it on screen still moved the page');
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'no report had two sentences after it');
    });

    // A case lived here — "Continue Read from a stored position shows it
    // first" — which seeded a `read_position_*` record and asserted the view
    // restored it before any read (010 D8). 016 decision 5 retires the record
    // itself: there is nothing to seed and nothing to restore, and the reader
    // asked for exactly that ("重启一律干净"). The reveal it proved lives on in
    // the case above (a manual scroll, then a read from a position in force),
    // and its device half is re-walked as 016's quickstart row 10 — 011's own
    // row 8, whose restore half 011's record notes with its date (016 T020).

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

      // **022's own extension of this case (2026-10-16, tasks T010)**: the new rule
      // fires at this sentence's own start and not again while it is read, so the
      // hand scroll above is still standing; and the move the rule makes is the
      // lead's — a sentence ahead of this one, not this one dragged back.
      final held = scrollPosition(tester).pixels;
      fake.fire(fake.plan[1]);
      await tester.pumpAndSettle();
      expect(scrollPosition(tester).pixels, held,
          reason: 'a re-reported sentence moved the page (011 FR-005, 022 FR-004)');
      final view = viewportRect(tester);
      if (sentenceBox(tester, fake.plan[3]).top > view.bottom) {
        expect(sentenceBox(tester, fake.plan[2]).top, lessThan(view.bottom),
            reason: 'the sentence after this one has nothing after it on screen');
      }
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

  /// **022's own field (2026-10-16)**: how many sentences have a box inside the
  /// viewport **below** the reported one — null for a line that does not carry it,
  /// which is what keeps this reader able to read the six-field line the older
  /// receipts quote. The pattern is anchored, so the appended field is a re-cut of
  /// this reader rather than a silent match (011's driver regex is unanchored and
  /// reads both shapes).
  final int? below;

  const FollowLine({
    required this.paragraph,
    required this.sentence,
    required this.visible,
    required this.top,
    required this.bottom,
    required this.viewport,
    this.below,
  });

  static FollowLine parse(String line) {
    final match = RegExp(
      r'^klhu follow: p(\d+) s(\d+) visible=(\d+) top=(-?\d+) '
      r'bottom=(-?\d+) viewport=(\d+)(?: below=(\d+))?$',
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
      below: match.group(7) == null ? null : int.parse(match.group(7)!),
    );
  }
}
