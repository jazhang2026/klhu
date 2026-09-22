import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake at the [Reader] seam, modelling the contract [ReaderService] actually
/// offers the view:
///
/// 1. [pause] stops the audio and KEEPS the queue plus the paragraph it was on.
/// 2. [resume] continues from that paragraph — it does not restart the read,
///    and it does not call the engine's own pause again (doing so crashes the
///    Android plugin: it re-truncates the remembered remainder of the
///    utterance, `StringIndexOutOfBoundsException`).
/// 3. [stop] discards the queue: nothing can resume afterwards.
///
/// A read stays in flight until the paragraph ends, Stop arrives, or the read
/// is paused — so "paused" is observable, not "finished".
class _PauseFakeReader implements Reader {
  _PauseFakeReader({this.autoAdvance = false});

  /// True = every paragraph ends immediately by itself (a short page).
  final bool autoAdvance;

  final List<String> spoken = [];
  final List<int> paragraphStarts = [];
  int stopCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  bool speaking = false;
  bool paused = false;

  List<ParagraphSpeech> _queue = const [];
  int _cursor = 0;
  void Function(int)? _onParagraphStart;
  Completer<void>? _utterance;

  /// Let the paragraph in flight end on its own (what a long page does).
  void endParagraph() {
    final done = _utterance;
    _utterance = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    paused = true;
    speaking = false;
    // The service stops the engine and releases the parked loop; at this seam
    // the queue and the position survive.
    endParagraph();
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    paused = false;
    speaking = true;
    // The interrupted paragraph is read again, then the rest follows.
    await _playFrom(_cursor);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    paused = false;
    speaking = false;
    _queue = const [];
    _cursor = 0;
    endParagraph();
  }

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
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
    _queue = paragraphs;
    _cursor = 0;
    paused = false;
    _onParagraphStart = onParagraphStart;
    speaking = paragraphs.isNotEmpty;
    await _playFrom(0);
  }

  Future<void> _playFrom(int from) async {
    for (var i = from; i < _queue.length; i++) {
      _cursor = i;
      _onParagraphStart?.call(i);
      spoken.add(_queue[i].text);
      paragraphStarts.add(i);
      if (autoAdvance) continue;
      final done = Completer<void>();
      _utterance = done;
      await done.future;
      if (paused) return; // the view's resume() re-enters from _cursor
    }
    speaking = false;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

Future<void> _pumpView(
  WidgetTester tester, {
  required Reader reader,
  LocalizationService? service,
  void Function(String)? onLanguageChanged,
}) async {
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
    home: ReadingView(
      reader: reader,
      localizationService: service,
      onLanguageChanged: onLanguageChanged,
    ),
  ));
}

/// Starts a page read and leaves the view in SPEAKING.
Future<void> _startPageRead(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Read page'));
  await tester.pump();
}

/// Opens the app-bar language dropdown and picks the other language.
Future<void> _switchLanguage(WidgetTester tester, String nativeName) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nativeName).last);
  await tester.pumpAndSettle();
}

/// Root that owns the locale, the way `main.dart` does: the language
/// callback both persists the code and rebuilds the app in the new locale
/// (ReadingView only *asks* for the switch; it does not own the locale).
class _LocaleHost extends StatefulWidget {
  const _LocaleHost({required this.reader, required this.service});

  final Reader reader;
  final LocalizationService service;

  @override
  State<_LocaleHost> createState() => _LocaleHostState();
}

class _LocaleHostState extends State<_LocaleHost> {
  late Locale _locale = widget.service.getCurrentLocale();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
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
      home: ReadingView(
        reader: widget.reader,
        localizationService: widget.service,
        onLanguageChanged: (code) {
          widget.service.saveLanguage(code);
          setState(() => _locale = widget.service.resolveLocale(code));
        },
      ),
    );
  }
}

void main() {
  // The view's default VoiceStore is real shared_preferences: mock it per
  // test, or resolving speeches throws before the read ever starts.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('US2 P1: pause/resume page read (005)', () {
    testWidgets('Read page swaps Read for Pause; Pause keeps the queue',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);

      expect(fake.isSpeaking, isTrue);
      // Read + Read page hide while speaking; Pause takes their place.
      expect(find.byTooltip('Read'), findsNothing);
      expect(find.byTooltip('Read page'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsNothing);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      expect(fake.pauseCalls, 1);
      expect(fake.isPaused, isTrue);
      // Pausing must not end the read: no full stop, queue still held.
      expect(fake.stopCalls, 0);
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    });

    testWidgets('Resume continues from the paused paragraph, nothing skipped',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      expect(fake.paragraphStarts, [0]);

      // Paragraph 0 finishes on its own; paragraph 1 starts.
      fake.endParagraph();
      await tester.pump();
      expect(fake.paragraphStarts, [0, 1]);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final spokenAtPause = fake.spoken.length;

      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();

      expect(fake.resumeCalls, 1);
      expect(fake.isPaused, isFalse);
      expect(fake.isSpeaking, isTrue);
      // Back in SPEAKING, and the interrupted paragraph 1 is read again
      // rather than the read restarting from paragraph 0.
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(fake.paragraphStarts, [0, 1, 1]);
      expect(fake.spoken[spokenAtPause], fake.spoken[spokenAtPause - 1]);

      // The rest of the queue follows in order and the read ends cleanly.
      fake.endParagraph();
      await tester.pump();
      expect(fake.paragraphStarts, [0, 1, 1, 2]);
      fake.endParagraph();
      await tester.pump();
      expect(fake.isSpeaking, isFalse);
      expect(fake.stopCalls, 0);
      expect(find.byTooltip('Read page'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    });

    testWidgets('Stop while paused resets to idle and clears Resume',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();

      expect(fake.stopCalls, 1);
      expect(fake.isPaused, isFalse);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.byTooltip('Read'), findsOneWidget);
      expect(find.byTooltip('Read page'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('a sentence tap while paused fully stops (no phantom resume)',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      final topLeft = tester.getTopLeft(
          find.textContaining('The sun rose', findRichText: true));
      await tester.tapAt(topLeft + const Offset(10, 10));
      await tester.pump();

      expect(fake.stopCalls, greaterThanOrEqualTo(1));
      expect(fake.isPaused, isFalse);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.byTooltip('Read page'), findsOneWidget);
    });

    testWidgets('switching language while paused returns to idle (scenario 7)',
        (tester) async {
      final service =
          LocalizationService(await SharedPreferences.getInstance());
      final fake = _PauseFakeReader();
      await tester.pumpWidget(_LocaleHost(reader: fake, service: service));
      await _startPageRead(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byTooltip('Resume'), findsOneWidget);

      await _switchLanguage(tester, '中文');

      // Regression (005 scenario 7): the dropdown used to call the engine's
      // stop() and leave _mode alone, so the view kept offering Resume for
      // speech that no longer existed — a resume would then flip to a
      // phantom SPEAKING state with no audio.
      expect(fake.stopCalls, greaterThanOrEqualTo(1));
      expect(fake.isPaused, isFalse);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      // Idle in the NEW language: 朗读 / 朗读全文 / 停止 / 编辑.
      expect(find.byTooltip('朗读全文'), findsOneWidget);
      expect(find.byTooltip('编辑'), findsOneWidget);
      expect(find.byTooltip('Read page'), findsNothing);
      expect(service.loadLanguage(), 'zh');
    });

    testWidgets('a read that ends on its own leaves no pause state behind',
        (tester) async {
      final fake = _PauseFakeReader(autoAdvance: true);
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(find.byTooltip('Read page'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('rapid toggling: one call per tap, last tap wins',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);

      // Pause, Resume, Pause, Resume, Pause, one frame apart (the button
      // swaps each time, so the tree has to rebuild between taps).
      for (final tooltip in [
        'Pause',
        'Resume',
        'Pause',
        'Resume',
        'Pause',
      ]) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      // Each tap maps to exactly one call: pause is never called twice in a
      // row, which is the engine call that throws in the Android plugin.
      expect(fake.pauseCalls, 3);
      expect(fake.resumeCalls, 2);
      // Last tap was Pause, so the UI must offer Resume.
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(fake.isPaused, isTrue);
      expect(fake.stopCalls, 0);
    });
  });
}
