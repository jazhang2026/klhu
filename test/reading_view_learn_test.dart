/// 035 — Learn mode on the reading page (quickstart walk's automated half):
/// the toggle swaps the control row, a tap starts the 3-cycle practice loop
/// through the injected fake TTS/STT seams, Stop summarizes, and re-tapping a
/// sentence restarts its run. Nothing here touches a platform channel.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/learn/speech_recognizer.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// Two sentences — enough to tell "the tapped one" from "the rest".
const String kLearnText =
    'The cat sat on the mat. It purred all afternoon.';

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
    speaking = false;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

/// A recognizer that answers every listen window with a fixed transcript.
class FakeStt implements SpeechRecognizer {
  bool initialized = false;
  bool available = true;
  final List<String> locales = [];
  int listenCalls = 0;
  String transcript;

  FakeStt({this.transcript = ''});

  @override
  Future<bool> initialize() async {
    initialized = true;
    return available;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String reason)? onError,
  }) async {
    listenCalls++;
    locales.add(localeId);
    if (transcript.isNotEmpty) {
      onResult(transcript, true);
    }
    onDone?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-learn-page-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ContentStore learnStore() => sampleStore(root, catalog: [
        PresetContent(id: 'learn', language: 'en', text: kLearnText),
      ]);

  Future<FakeReader> pumpPage(
    WidgetTester tester, {
    FakeStt? stt,
    Future<bool> Function()? micPermission,
  }) async {
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
        reader: fake,
        contentStore: learnStore(),
        speechRecognizer: stt ?? FakeStt(),
        micPermission: micPermission ?? () async => true,
      ),
    ));
    await loadPageContent(tester);
    return fake;
  }

  /// Lets the learn loop's chained async turns finish on the fake clock.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 6; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Taps the middle of the first character of [what] in the painted text.
  Future<void> tapOn(WidgetTester tester, String what) async {
    RenderParagraph? render;
    for (final element in find.byType(RichText).evaluate()) {
      final widget = element.widget as RichText;
      if (widget.text.toPlainText().contains('The cat')) {
        render = element.renderObject as RenderParagraph;
        break;
      }
    }
    expect(render, isNotNull, reason: 'the reading content is not on screen');
    final para = render!;
    final start = para.text.toPlainText().indexOf(what);
    expect(start, isNonNegative, reason: '"$what" is not on the page');
    final box = para
        .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 1))
        .first;
    await tester.tapAt(para.localToGlobal(Offset(
      (box.left + box.right) / 2,
      (box.top + box.bottom) / 2,
    )));
    await tester.pump();
  }

  group('US1: Learn mode entry', () {
    testWidgets('toggle swaps the control row and exit restores it',
        (tester) async {
      final stt = FakeStt();
      await pumpPage(tester, stt: stt);

      // Idle: the Learn toggle sits beside the read controls.
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();

      // Learn controls: status line, Stop, exit — no read controls.
      expect(find.text('Tap a sentence to practice'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsNothing);

      // Exit: the normal row returns untouched.
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.text('Tap a sentence to practice'), findsNothing);
    });

    testWidgets('a tap starts the sentence 3-cycle loop; comments never read',
        (tester) async {
      final stt = FakeStt(transcript: 'The cat sat on the mat.');
      final reader = await pumpPage(tester, stt: stt);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await tapOn(tester, 'The cat');
      await settle(tester);

      // Exactly three read→repeat cycles, each reading only the tapped
      // sentence — never the second one, never a comment.
      expect(reader.spoken.length, 3);
      expect(reader.spoken,
          everyElement('The cat sat on the mat.'));
      expect(reader.utterances.single.text, 'The cat sat on the mat.');
      expect(stt.listenCalls, 3);
      expect(stt.locales, everyElement('en_US'));

      // After the third attempt the session waits for the next tap.
      expect(find.textContaining('Done'), findsOneWidget);
    });

    testWidgets('a normal tap-read still works after exiting Learn',
        (tester) async {
      final reader = await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();

      await tapOn(tester, 'The cat');
      await settle(tester);
      expect(reader.spoken, contains('The cat sat on the mat.'));
    });
  });

  group('US3: Stop and summary', () {
    testWidgets('Stop summarizes practiced sentences, then exits to normal',
        (tester) async {
      final stt = FakeStt(transcript: 'The cat sat on the mat.');
      await pumpPage(tester, stt: stt);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await tapOn(tester, 'The cat');
      await settle(tester);

      await tester.tap(find.byIcon(Icons.stop));
      await settle(tester);

      // The summary sheet lists the practiced sentence with its score.
      expect(find.text('Learn session results'), findsOneWidget);
      expect(find.textContaining('The cat sat on the mat.'),
          findsWidgets);
      expect(find.textContaining('100%'), findsOneWidget);

      // Dismiss → normal controls, Learn fully exited.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });
  });

  group('US4: re-practice', () {
    testWidgets('re-tapping a completed sentence restarts its 3 cycles',
        (tester) async {
      final stt = FakeStt(transcript: 'The cat sat on the mat.');
      final reader = await pumpPage(tester, stt: stt);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await tapOn(tester, 'The cat');
      await settle(tester);
      expect(reader.spoken.length, 3);

      // Re-tap: a fresh run — three more reads, attempts accumulate.
      await tapOn(tester, 'The cat');
      await settle(tester);
      expect(reader.spoken.length, 6);
      expect(stt.listenCalls, 6);
      expect(find.textContaining('Done'), findsOneWidget);
    });
  });
}
