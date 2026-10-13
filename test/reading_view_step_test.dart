/// 016 — the stepping read (quickstart rows 2 and 3, and this feature's own
/// cases): one press reads one sentence and stops, the highlight moves AHEAD to
/// what the next press will read instead of clearing, a paragraph press keeps
/// its own unit, and a step is a sentence **plus its comment**.
///
/// The cases are the spec's own acceptance scenarios (US1's six, plus the two
/// edge cases a step creates), written against the page's behaviour — never
/// against values read off the implementation. The reader is a fake that
/// records the speeches it is handed with their offsets, so "what the press
/// read" is the range, not just the words.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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

  Future<void> pressRead(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Read'));
    await tester.pump();
  }

  group('US1: one press, one sentence, at the reader\'s own pace', () {
    testWidgets('each press reads one sentence, in order, and stops',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await pressRead(tester);
      expect(fake.speeches.length, 1);
      expect(fake.speeches.single.start, p1First);
      expect(fake.speeches.single.text, text.substring(p1First, p1Second).trimRight());

      await pressRead(tester);
      expect(fake.speeches.length, 1);
      expect(fake.speeches.single.start, p1Second);
      expect(fake.speeches.single.text,
          text.substring(p1Second, p2First - 2).trimRight());

      await pressRead(tester);
      expect(fake.speeches.single.start, p2First);
    });

    testWidgets('the highlight sits on the NEXT sentence, and is gone at the end',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await pressRead(tester);
      // Decision 1 (A) / FR-004: the highlight always points at what the NEXT
      // press will read, so the sentence just heard is no longer painted.
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isFalse);

      // Eight sentences in this text: the eighth press reads the last one and
      // ends with nothing left to point at.
      for (var i = 0; i < 7; i++) {
        await pressRead(tester);
      }
      expect(hasAnyYellow(tester), isFalse);
      // …and it says nothing: an unhighlighted page is the whole message
      // (FR-008, the reader's own correction).
      expect(find.text('Nothing left to read from here.'), findsNothing);
      expect(find.text('Select a sentence or paragraph to read'), findsNothing);

      // The end is not a mode: a further press is an ordinary fresh start
      // (FR-001) — the reader is never stuck.
      final before = fake.reads.length;
      await pressRead(tester);
      expect(fake.reads.length, before + 1);
      expect(fake.speeches.single.start, 0);
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
    });

    testWidgets('with nothing highlighted · read the first sentence',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await pressRead(tester);

      expect(fake.speeches.single.start, 0, reason: 'the text starts with a \\n');
      expect(fake.speeches.single.text, 'The sun rose over the quiet town.');
      expect(find.text('Select a sentence or paragraph to read'), findsNothing);
    });

    testWidgets('a long press reads its paragraph and leaves it highlighted',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await tester.longPressAt(offsetOf(tester, 'codebase runs'));
      await tester.pump();
      // The gesture picked the PARAGRAPH, and that is the painted span.
      expect(hasYellow(tester, text.substring(p2First, p3First - 2)), isTrue);

      // The paragraph press reads the paragraph — the reader's own unit is not
      // overruled by the stepping rule (FR-003).
      await tester.tap(find.byTooltip('Read'));
      await tester.pump();
      expect(fake.speeches.single.start, p2First);
      expect(fake.speeches.single.text, text.substring(p2First, p3First - 2));
    });
  });

  group("US1: a step is the sentence plus its comment", () {
    testWidgets('one press reads the sentence and its comment, and the next starts after it',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: commentText);

      await pressRead(tester);
      // The sentence's own speech, then the comment's (015) — the step's range
      // reaches over the comment's span, or the comment is dropped silently.
      expect(fake.spoken, ['Hola.', 'How are you?']);

      final afterStep = fake.spoken.length;
      await pressRead(tester);
      expect(fake.spoken.sublist(afterStep), ['Adiós.'],
          reason: 'the next step is the sentence after the comment');
    });

    testWidgets('a comment between two sentences of one paragraph rides its owner',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: inlineCommentText);

      await pressRead(tester);
      expect(fake.spoken, ['Hola.']);

      await pressRead(tester);
      expect(fake.spoken.sublist(1), ['Adiós.', 'Fine.'],
          reason: "the comment belongs to the sentence before it, and rides that press");
    });
  });
  group('US2: a step leaves nothing behind', () {
    testWidgets('⏭ after a step reads only the sentences the steps have not',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await pressRead(tester);
      await pressRead(tester);
      final reads = fake.reads.length;

      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();

      expect(fake.reads.length, reads + 1);
      // From the sentence the highlight sat on — not from the first one.
      expect(fake.speeches.first.start, p2First);
      expect(fake.speeches.first.text, text.substring(p2First, p3First - 2));
      expect(fake.speeches.last.end, readEnd);
    });

    testWidgets('Stop clears the highlight, so the next press starts at the first sentence',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);

      await pressRead(tester);
      expect(hasAnyYellow(tester), isTrue);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();

      expect(hasAnyYellow(tester), isFalse);
      await pressRead(tester);
      expect(fake.speeches.single.start, 0, reason: 'nothing is in force again');
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
    });

    testWidgets('a parked step advances when its sentence is resumed',
        (tester) async {
      final fake = RecordingReader()..hold = true;
      await openPage(tester, fake);

      await pressRead(tester);
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byTooltip('Resume'), findsOneWidget);

      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();
      fake.release();
      await tester.pump();

      // The step's advance applies to a read that was parked and finished, as
      // it does to a fresh one (FR-010).
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);
      expect(hasYellow(tester, 'The sun rose over the quiet town.'), isFalse);
    });

    testWidgets('a relaunch after a step brings nothing back, and writes nothing',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await pressRead(tester);
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final stored = <String, Object>{
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      };
      // Nothing was written down: the step's position lives in memory only
      // (FR-007).
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
    });

    testWidgets('a relaunch after a TAP brings nothing back either',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake);
      await tester.tapAt(offsetOf(tester, 'Birds sang'));
      await tester.pump();
      expect(hasYellow(tester, 'Birds sang in the tall trees.'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final stored = <String, Object>{
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      };
      expect(stored['read_position_$pageContentKey'], isNull,
          reason: 'a tap writes no position either (decision 5)');

      SharedPreferences.setMockInitialValues(stored);
      await tester.pumpWidget(const SizedBox());
      final relaunched = RecordingReader();
      await openPage(tester, relaunched);

      expect(hasAnyYellow(tester), isFalse);
      await tester.tap(find.byTooltip('Continue Read'));
      await tester.pump();
      expect(relaunched.speeches.first.start, 0);
    });
  });

  group('the reader\'s own content: a line with no delimiter before its tag',
      () {
    testWidgets('▶ walks the lines one at a time, and each keeps its comment',
        (tester) async {
      final fake = RecordingReader();
      await openPage(tester, fake, body: readerContent);

      // The title, with the comment that rides it.
      await pressRead(tester);
      expect(fake.speeches.first.start, 0);
      expect(fake.speeches.first.text.trim(), 'Basic Spanish 1');
      expect(fake.speeches.last.text.trim(), 'Greetings');

      // The very next line — not the third, which is where it used to land.
      await pressRead(tester);
      expect(fake.speeches.first.start, readerContent.indexOf('Hola'));
      expect(fake.speeches.first.text.trim(), 'Hola');
      expect(fake.speeches.last.text.trim(), 'Hello');

      // And then the line after that.
      await pressRead(tester);
      expect(fake.speeches.first.start, readerContent.indexOf('¿Cómo estás?'));
      expect(fake.speeches.last.text.trim(), 'How are you?');
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
