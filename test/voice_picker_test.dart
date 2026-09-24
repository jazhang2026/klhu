import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PickerFakeReader implements Reader {
  final Map<String, List<VoiceEntry>> voicesByLanguage;
  bool failList;
  final List<VoiceEntry> previewed = [];
  int stops = 0;

  PickerFakeReader({required this.voicesByLanguage, this.failList = false});

  @override
  Future<void> speak(String text, String language) async {}

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  bool get isSpeaking => false;

  @override
  bool get isPaused => false;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async {
    if (failList) throw ReaderException('getVoices failed');
    return voicesByLanguage[language] ?? [];
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> ps, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {}

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {
    await stop();
    previewed.add(voice);
  }
}

/// Voice names as the Google TTS engine actually reports them.
PickerFakeReader _fake({bool failList = false}) => PickerFakeReader(
      voicesByLanguage: {
        'en': const [
          VoiceEntry(name: 'en-us-x-sfg-local', locale: 'en-US'),
          VoiceEntry(name: 'en-gb-x-gba-local', locale: 'en-GB'),
        ],
        'zh-Hans': const [
          VoiceEntry(name: 'cmn-cn-x-ssa-local', locale: 'zh-CN'),
        ],
      },
      failList: failList,
    );

Future<void> _pumpPicker(
  WidgetTester tester,
  Reader reader, {
  String language = 'en',
}) async {
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
      ],
      home: VoicePickerScreen(
        reader: reader,
        store: VoiceStore(),
        language: language,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('voice picker (widget)', () {
    testWidgets('lists active-language voices only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      expect(find.textContaining('US SFG'), findsOneWidget);
      expect(find.textContaining('UK GBA'), findsOneWidget);
      expect(find.textContaining('普通话'), findsNothing);
    });

    testWidgets('tap previews in tapped voice and persists choice',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake);
      await tester.tap(find.textContaining('UK GBA'));
      await tester.pumpAndSettle();
      expect(fake.stops, 1);
      expect(fake.previewed.map((v) => v.name), ['en-gb-x-gba-local']);
      await _pumpPicker(tester, fake);
      expect(find.byIcon(Icons.check), findsNothing);
      final selected = find.byWidgetPredicate(
        (w) => w is ListTile && w.selected,
      );
      expect(selected, findsOneWidget);
      expect(
        tester.widget<ListTile>(selected).title,
        isA<Text>().having((t) => t.data, 'data', contains('UK GBA')),
      );
    });

    testWidgets('zh language lists zh voices, previews zh sample',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake, language: 'zh-Hans');
      expect(find.textContaining('普通话'), findsOneWidget);
      expect(find.textContaining('US SFG'), findsNothing);
      await tester.tap(find.textContaining('普通话'));
      await tester.pumpAndSettle();
      expect(fake.previewed.map((v) => v.name), ['cmn-cn-x-ssa-local']);
    });

    testWidgets('in-picker language switch reloads the other list',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      expect(find.textContaining('US SFG'), findsOneWidget);
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.textContaining('普通话'), findsOneWidget);
      expect(find.textContaining('US SFG'), findsNothing);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.textContaining('US SFG'), findsOneWidget);
      expect(find.textContaining('普通话'), findsNothing);
    });

    testWidgets('empty voice list shows empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(
        tester,
        PickerFakeReader(voicesByLanguage: {'en': const []}),
      );
      expect(find.textContaining('No voices'), findsOneWidget);
    });

    testWidgets('load failure shows error with retry', (tester) async {
      final fake = _fake(failList: true);
      SharedPreferences.setMockInitialValues({});
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
          ],
          home: VoicePickerScreen(
            reader: fake,
            store: VoiceStore(),
            language: 'en',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load'), findsOneWidget);
      fake.failList = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('US SFG'), findsOneWidget);
    });

    testWidgets('rapid taps: latest preview wins, stays selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake);
      await tester.tap(find.textContaining('US SFG'));
      await tester.tap(find.textContaining('UK GBA'));
      await tester.pumpAndSettle();
      expect(fake.stops, 2);
      expect(fake.previewed.map((v) => v.name), [
        'en-us-x-sfg-local',
        'en-gb-x-gba-local',
      ]);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is ListTile && w.selected),
        findsOneWidget,
      );
    });

    testWidgets('en and zh choices persist independently (US3)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake, language: 'en');
      await tester.tap(find.textContaining('US SFG'));
      await tester.pumpAndSettle();
      await _pumpPicker(tester, fake, language: 'zh-Hans');
      await tester.tap(find.textContaining('普通话'));
      await tester.pumpAndSettle();
      await _pumpPicker(tester, fake, language: 'en');
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        tester.widget<ListTile>(find.byWidgetPredicate(
          (w) => w is ListTile && w.selected,
        )).title,
        isA<Text>().having((t) => t.data, 'data', contains('US SFG')),
      );
      await _pumpPicker(tester, fake, language: 'zh-Hans');
      expect(
        find.byWidgetPredicate((w) => w is ListTile && w.selected),
        findsOneWidget,
      );
    });
  });

  group('picker polish US1 (003)', () {
    testWidgets('selected row highlighted via ListTile.selected, no marker',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake);
      await tester.tap(find.textContaining('UK GBA'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(VoicePickerScreen),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      final selected = find.byWidgetPredicate(
        (w) => w is ListTile && w.selected,
      );
      expect(selected, findsOneWidget);
      expect(
        tester.widget<ListTile>(selected).title,
        isA<Text>().having((t) => t.data, 'data', contains('UK GBA')),
      );
    });

    testWidgets('count header matches filtered list per language',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      expect(find.text('2 voices'), findsOneWidget);
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('1 voice'), findsOneWidget);
      expect(find.text('2 voices'), findsNothing);
    });

    testWidgets('scrollbar always visible; list is indexed builder',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      final bar = find.byType(Scrollbar);
      expect(bar, findsOneWidget);
      expect(tester.widget<Scrollbar>(bar).thumbVisibility, isTrue);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('first open centers a saved selection deep in the list',
        (tester) async {
      final voices = [
        for (var i = 0; i < 40; i++)
          VoiceEntry(name: 'en-$i', locale: 'en-US'),
      ];
      SharedPreferences.setMockInitialValues(
          {'voice_en': 'en-39||en-US'});
      await _pumpPicker(
        tester,
        PickerFakeReader(voicesByLanguage: {'en': voices}),
      );
      expect(
        find.byWidgetPredicate((w) => w is ListTile && w.selected),
        findsOneWidget,
      );
      final list = tester.widget<Scrollable>(find.descendant(
        of: find.byType(VoicePickerScreen),
        matching: find.byType(Scrollable),
      ));
      expect(list.controller!.offset, greaterThan(0));
    });
  });

  group('voice mapping display names', () {
    testWidgets('shows the mapped name with the measured gender',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      expect(find.textContaining('US SFG'), findsOneWidget);
      expect(find.textContaining('US SFG (Female)'), findsOneWidget);
      expect(find.textContaining('UK GBA (Female)'), findsOneWidget);
    });

    testWidgets('unmapped voice shows system name as fallback', (tester) async {
      final fake = PickerFakeReader(
        voicesByLanguage: {
          'en': const [
            VoiceEntry(name: 'unknown-voice', locale: 'en-US'),
          ],
        },
      );
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, fake);
      expect(find.text('unknown-voice'), findsOneWidget);
    });
  });
}
