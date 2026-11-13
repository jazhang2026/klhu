/// 032 — tap-to-read (quickstart rows and this feature's own cases): a tap or
/// long-press highlights AND reads its unit in one gesture, the highlight stays
/// on what was just read instead of advancing, a paragraph press keeps its own
/// unit, a step is a sentence **plus its comment**, and ⏭ Continue Read picks up
/// at the next step — then loops (US2 lives in `reading_view_continue_test.dart`).
///
/// The cases are the spec's own acceptance scenarios (US1's five, plus the edge
/// cases a tap creates), written against the page's behaviour — never against
/// values read off the implementation. The reader is a fake that records the
/// speeches it is handed with their offsets, so "what the tap read" is the
/// range, not just the words.
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
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

const text = kSampleEnText;

/// The key the page stores a pre-set's position under (010's own record).
const pageContentKey = 'preset_en_sample';

final p1First = text.indexOf('The sun rose');
final p1Second = text.indexOf('Birds sang');
final p2First = text.indexOf('Flutter makes');
final p2Second = text.indexOf('A single codebase');
final p3First = text.indexOf('This is the third');
final readEnd = text.trimRight().length;

/// A content whose sentence carries 015's comment, and one whose comment sits
/// between two sentences of the same paragraph (the case the step's range has
/// to reach over).
const commentText = 'Hola.\n\n[注] How are you?\n\nAdiós.';
const inlineCommentText = 'Hola. Adiós. [注] Fine.';

/// The reader's own content (2026-10-12), verbatim off their phone: a title,
/// then lines each followed by a blank line, one comment per line and **no
/// delimiter before the tag**. Every line is a step — it used to jump from the
/// title straight to the first line that happened to end with `?`.
const readerContent = 'Basic Spanish 1\n'
    '\n'
    '[comment]Greetings\n'
    '\n'
    'Hola [comment] Hello\n'
    '\n'
    '¿Cómo estás? [comment] How are you?';

/// Records what it was asked to speak, with the offsets.
class RecordingReader implements Reader {
  final List<List<ParagraphSpeech>> reads = [];
  void Function(SpokenSentence spoken)? onSentenceStart;
  final List<String> spoken = [];
  int stops = 0;
  bool hold = false;
  bool speaking = false;
  bool paused = false;
  Completer<void>? _parked;

  /// Lets a parked read finish.
  void release() {
    hold = false;
    _parked?.complete();
    _parked = null;
  }

  List<ParagraphSpeech> get speeches =>
      reads.isEmpty ? const <ParagraphSpeech>[] : reads.last;

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

/// A store on [root] whose only content is [body], for the comment cases.
ContentStore oneContentStore(Directory root, String body) => ContentStore(
      directory: root,
      loadCatalog: () async => [
        PresetContent(id: 'preset_step', language: 'en', text: body),
      ],
      now: () => DateTime.utc(2026, 10, 12),
    );

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-step-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> openPage(WidgetTester tester, RecordingReader fake,
      {Directory? on, String? body}) async {
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
        home: ReadingView(
          reader: fake,
          contentStore:
              body == null ? pageStore(on ?? root) : oneContentStore(on ?? root, body),
        ),
      ),
    );
    await loadPageContent(tester);
  }

  /// 032: the tap IS the read — one gesture highlights, reveals and speaks.
  /// [inText] names the body when the case brought its own.
  Future<void> tapRead(WidgetTester tester, String target,
      {String? inText}) async {
    await tester.tapAt(offsetInText(tester, target, inText: inText));
    await tester.pumpAndSettle();
  }

  group('US1: a tap reads one sentence, at the reader\'s own pace', () {
    testWidgets('each tap reads the tapped sentence and stops',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tapRead(tester, 'The sun rose');
      expect(fake.speeches.length, 1);
      expect(fake.speeches.single.text, 'The sun rose over the quiet town.');

      await tapRead(tester, 'Birds sang');
      expect(fake.speeches.length, 1);
      expect(fake.speeches.single.start, p1Second);
      expect(fake.speeches.single.text,
          text.substring(p1Second, p2First - 2).trimRight());

      await tapRead(tester, 'Flutter makes');
      expect(fake.speeches.single.start, p2First);
    });

    testWidgets('the highlight stays on the sentence just read',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tapRead(tester, 'Birds sang');
      // 032 FR-004: no auto-advance — the sentence just heard is what stays
      // painted, ready to be tapped again.
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isFalse);

      await tapRead(tester, 'Flutter makes');
      expect(hasYellow(tester, 'Flutter makes it easy to build beautiful apps.'),
          isTrue);
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isFalse);
    });

    testWidgets('tapping the highlighted sentence repeats its read',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tapRead(tester, 'Birds sang');
      expect(fake.reads.length, 1);

      await tapRead(tester, 'Birds sang');
      expect(fake.reads.length, 2);
      expect(fake.speeches.single.start, p1Second,
          reason: 'the same sentence was read again');
    });

    testWidgets('the tap brings its sentence into view before reading it',
        (tester) async {
      // 016 FR-012's rule, now on the tap itself: the unit a tap reads is
      // revealed before it is spoken — a step read does not track, so nothing
      // else would bring it into view. The page is parked at the bottom of a
      // long body and the tapped sentence sits near the fold.
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fake = RecordingReader()..hold = true;
      final body = List.generate(40, (i) => 'Sentence number ${i + 1} ends here.')
          .join('\n\n');
      await openPage(tester, fake, body: body);

      const target = 'Sentence number 20 ends here.';
      // The content is ONE RichText, so scrollUntilVisible cannot aim at a
      // span inside it — drag the page until the sentence's own point is on
      // screen, then tap there.
      final screen = tester.getRect(find.byType(Scaffold));
      var pos = offsetInText(tester, target, inText: body);
      for (var i = 0; i < 40 && pos.dy > screen.bottom - 40; i++) {
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -150));
        await tester.pumpAndSettle();
        pos = offsetInText(tester, target, inText: body);
      }
      expect(pos.dy, lessThan(screen.bottom - 20),
          reason: 'the sentence never scrolled into view');

      await tester.tapAt(pos);
      await tester.pumpAndSettle();

      expect(fake.speeches.single.text, target,
          reason: 'the tap read its own sentence');
      expect(stepTextIsInsideViewport(tester, target, body), isTrue,
          reason: 'the sentence being read is not inside the viewport');
      fake.release();
      await tester.pumpAndSettle();
    });

    testWidgets('a long press reads its paragraph and leaves it highlighted',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.longPressAt(offsetInText(tester, 'codebase runs'));
      await tester.pumpAndSettle();

      // The gesture picked the PARAGRAPH, and that is the painted span — and
      // the read, with no button press (032 FR-003).
      expect(hasYellow(tester, text.substring(p2First, p3First - 2)), isTrue);
      expect(fake.speeches.single.start, p2First);
      expect(fake.speeches.single.text, text.substring(p2First, p3First - 2));
    });
  });

  group("US1: a tap-read is the sentence plus its comment", () {
    testWidgets('tapping the sentence reads it and its comment',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: commentText);

      await tapRead(tester, 'Hola.');
      // The sentence's own speech, then the comment's (015) — the step's range
      // reaches over the comment's span, or the comment is dropped silently.
      expect(fake.spoken, ['Hola.', 'How are you?']);

      await tapRead(tester, 'Adiós.');
      expect(fake.spoken.sublist(2), ['Adiós.'],
          reason: 'the next tap is the sentence after the comment');
    });

    testWidgets('a comment between two sentences of one paragraph rides its owner',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: inlineCommentText);

      await tapRead(tester, 'Hola.');
      expect(fake.spoken, ['Hola.']);

      await tapRead(tester, 'Adiós.');
      expect(fake.spoken.sublist(1), ['Adiós.', 'Fine.'],
          reason: "the comment belongs to the sentence before it, and rides that tap");
    });
  });

  group('US1: the reader\'s own content — a line with no delimiter before its tag',
      () {
    testWidgets('taps walk the lines one at a time, and each keeps its comment',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: readerContent);

      // The title, with the comment that rides it.
      await tapRead(tester, 'Basic Spanish 1');
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.first.text.trim(), 'Basic Spanish 1');
      expect(fake.speeches.last.text.trim(), 'Greetings');

      // The very next line — not the third, which is where it used to land.
      await tapRead(tester, 'Hola');
      expect(fake.speeches.first.start, readerContent.indexOf('Hola'));
      expect(fake.speeches.first.text.trim(), 'Hola');
      expect(fake.speeches.last.text.trim(), 'Hello');

      // And then the line after that.
      await tapRead(tester, '¿Cómo estás?');
      expect(fake.speeches.first.start, readerContent.indexOf('¿Cómo estás?'));
      expect(fake.speeches.last.text.trim(), 'How are you?');
    });
  });

  group('US1: what a tap-read leaves for ⏭ and for Stop', () {
    testWidgets('⏭ after a tap-read starts from the NEXT sentence',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await tester.tapAt(offsetInText(tester, 'The sun rose'));
      await tester.pump();
      expect(fake.speeches.single.text, 'The sun rose over the quiet town.');

      // Park the tap-read, then end it: the highlight stays on the sentence
      // just read, and the position it leaves is the NEXT step (FR-005).
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();
      fake.release();
      await tester.pumpAndSettle();

      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isTrue);
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isFalse);

      fake.hold = true;
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      // The continue read's first speech starts at the second sentence — the
      // one the tap-read left the position on — not at the first.
      expect(fake.reads.last.first.start, p1Second);
      fake.release();
      fake.hold = false;
      await tester.tap(find.byTooltip('Stop'));
      await tester.pumpAndSettle();
    });

    testWidgets('Stop clears the highlight, and the next tap reads fresh',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tapRead(tester, 'Birds sang');
      expect(hasAnyYellow(tester), isTrue);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();

      expect(hasAnyYellow(tester), isFalse);
      await tapRead(tester, 'The sun rose');
      expect(fake.speeches.last.text, 'The sun rose over the quiet town.');
      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isTrue);
    });

    testWidgets('a parked tap-read keeps its highlight when resumed',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await tester.tapAt(offsetInText(tester, 'The sun rose'));
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byTooltip('Resume'), findsOneWidget);

      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();
      fake.release();
      await tester.pumpAndSettle();

      // 032 FR-004/FR-010: the step's advance is retired — a parked and resumed
      // read leaves the SAME highlight it had, not the next sentence.
      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isTrue);
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isFalse);
    });

    testWidgets('a relaunch after a tap brings nothing back, and writes nothing',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tapRead(tester, 'Birds sang');
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final stored = <String, Object>{
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      };
      // Nothing was written down: the tap's position lives in memory only.
      expect(stored['read_position_$pageContentKey'], isNull);

      // A relaunch: the same prefs, a brand new view.
      SharedPreferences.setMockInitialValues(stored);
      await tester.pumpWidget(const SizedBox());
      final relaunched = RecordingReader();
      await openPage(tester, relaunched);

      expect(hasAnyYellow(tester), isFalse, reason: 'no highlight comes back');
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      expect(relaunched.speeches.first.start, 0,
          reason: '⏭ starts at the first sentence (010 FR-005)');
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
    });
  });
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


/// The reading area's own scroll position (the page's only scrollable in READ).
ScrollPosition stepScrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position;
}

/// The reading content's own render paragraph, whatever text it holds.
///
/// [containing] is the content's own text when a case brings its own body: the
/// paragraph is addressed **by the text the case wrote**, never by the shipped
/// fixture's own first words (a helper that looked for the fixture's sentence threw
/// `reading content RichText not found` on a generated body, which reads like a
/// missing widget and is not one).
RenderParagraph stepContentRender(WidgetTester tester, [String? containing]) {
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    final plain = widget.text.toPlainText();
    if (containing != null ? plain.contains(containing) : plain.contains('The sun rose')) {
      return element.renderObject as RenderParagraph;
    }
  }
  throw StateError('reading content RichText not found');
}

/// Whether any part of [target]'s box is inside the reading area's viewport — the
/// rule 022 asks about a sentence's successor ("a sentence after it on screen").
bool stepTextIsAtLeastPartlyInsideViewport(
    WidgetTester tester, String target, String text) {
  final render = stepContentRender(tester, text);
  final start = text.indexOf(target);
  if (start < 0) throw StateError('"$target" is not in the content');
  final box = render
      .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + target.length))
      .first;
  final top = render.localToGlobal(Offset(box.left, box.top)).dy;
  final bottom = render.localToGlobal(Offset(box.right, box.bottom)).dy;
  final view = tester.getRect(find.byType(SingleChildScrollView).first);
  return bottom > view.top + 0.5 && top < view.bottom - 0.5;
}

/// Whether [target]'s own box sits inside the reading area's viewport — the
/// measurement 011's own follow suite takes, on this suite's fixture.
bool stepTextIsInsideViewport(WidgetTester tester, String target, String text) {
  final render = stepContentRender(tester, text);
  final start = text.indexOf(target);
  if (start < 0) throw StateError('"$target" is not in the content');
  final box = render
      .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + target.length))
      .first;
  final top = render.localToGlobal(Offset(box.left, box.top)).dy;
  final bottom = render.localToGlobal(Offset(box.right, box.bottom)).dy;
  final view = tester.getRect(find.byType(SingleChildScrollView).first);
  return top >= view.top - 0.5 && bottom <= view.bottom + 0.5;
}
