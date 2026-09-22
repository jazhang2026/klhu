import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Models the two TTS contracts the pause/resume UI is built on:
///
/// 1. `pause()` is a TOGGLE — the view calls the same method to pause and to
///    resume, so a resume must not re-issue the read.
/// 2. A page read stays in flight until Stop / natural end, so "paused"
///    (not "finished") is an observable state.
class _PauseFakeReader implements Reader {
  _PauseFakeReader({this.hang = true});

  /// When true, `speakParagraphs` never completes by itself (a long page).
  final bool hang;

  final List<String> spoken = [];
  int stops = 0;
  int pauseCalls = 0;
  bool speaking = false;
  bool paused = false;
  Completer<void>? _inFlight;

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
    speaking = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    final wasPaused = paused;
    speaking = false;
    paused = false;
    // Engine behavior the pre-fix language switch tripped over: pausing
    // parks the current utterance's completion callback, and stopping a
    // PAUSED utterance does not deliver it, so a parked speakParagraphs
    // await never resolves and its cleanup never runs. Only a stop during
    // actual speech releases the loop.
    if (!wasPaused) {
      _inFlight?.complete();
      _inFlight = null;
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    paused = !paused;
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
    for (var i = 0; i < paragraphs.length; i++) {
      onParagraphStart?.call(i);
      spoken.add(paragraphs[i].text);
    }
    speaking = paragraphs.isNotEmpty;
    if (!hang || paragraphs.isEmpty) return;
    _inFlight = Completer<void>();
    await _inFlight!.future;
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
    testWidgets('Read page swaps Read for Pause; Pause calls the engine once',
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
      // Pausing must not end the read: Stop is the only way out of it.
      expect(fake.stops, 0);
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    });

    testWidgets('Resume toggles the engine instead of restarting the read',
        (tester) async {
      final fake = _PauseFakeReader();
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      final readCallsAfterStart = fake.spoken.length;

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();

      expect(fake.pauseCalls, 2);
      expect(fake.isPaused, isFalse);
      expect(fake.stops, 0);
      // Back to SPEAKING on the same read: no second round of paragraphs.
      expect(fake.spoken.length, readCallsAfterStart);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsNothing);
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

      expect(fake.stops, 1);
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

      expect(fake.stops, greaterThanOrEqualTo(1));
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
      expect(fake.stops, greaterThanOrEqualTo(1));
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
      final fake = _PauseFakeReader(hang: false);
      await _pumpView(tester, reader: fake);
      await _startPageRead(tester);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(find.byTooltip('Read page'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('rapid toggling: one engine call per tap, last tap wins',
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
      // Each tap maps to exactly one engine toggle (never a stacked pair).
      expect(fake.pauseCalls, 5);
      // Last tap was Pause, so the UI must offer Resume.
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(fake.isPaused, isTrue);
      expect(fake.stops, 0);
    });
  });
}
