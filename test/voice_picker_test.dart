import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool get isSpeaking => false;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async {
    if (failList) throw ReaderException('getVoices failed');
    return voicesByLanguage[language] ?? [];
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> ps, {
    void Function(int index)? onParagraphStart,
  }) async {}

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {
    // Mirrors ReaderService: preview is stop-first (spec FR-009).
    await stop();
    previewed.add(voice);
  }
}

PickerFakeReader _fake({bool failList = false}) => PickerFakeReader(
      voicesByLanguage: {
        'en': const [
          VoiceEntry(name: 'en-a', locale: 'en-US'),
          VoiceEntry(name: 'en-b', locale: 'en-GB'),
        ],
        'zh-Hans': const [
          VoiceEntry(name: 'zh-a', locale: 'zh-Hans-CN'),
        ],
      },
      failList: failList,
    );

Future<void> _pumpPicker(
  WidgetTester tester,
  Reader reader, {
  String language = 'en',
}) async {
  // NOTE: no mock reset here — repumps must preserve saved choices.
  // Each test resets explicitly with SharedPreferences.setMockInitialValues.
  await tester.pumpWidget(
    MaterialApp(
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
      expect(find.text('en-a'), findsOneWidget);
      expect(find.text('en-b'), findsOneWidget);
      expect(find.text('zh-a'), findsNothing);
    });

    testWidgets('tap previews in tapped voice and persists choice',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake);
      await tester.tap(find.text('en-b'));
      await tester.pumpAndSettle();
      expect(fake.stops, 1); // preview stops current speech first
      expect(fake.previewed.map((v) => v.name), ['en-b']);
      // Persisted: a fresh screen marks en-b selected (highlight, no marker).
      await _pumpPicker(tester, fake);
      expect(find.byIcon(Icons.check), findsNothing);
      final selected = find.byWidgetPredicate(
        (w) => w is ListTile && w.selected,
      );
      expect(selected, findsOneWidget);
      expect(
        tester.widget<ListTile>(selected).title,
        isA<Text>().having((t) => t.data, 'data', 'en-b'),
      );
    });

    testWidgets('zh language lists zh voices, previews zh sample',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake, language: 'zh-Hans');
      expect(find.text('zh-a'), findsOneWidget);
      expect(find.text('en-a'), findsNothing);
      await tester.tap(find.text('zh-a'));
      await tester.pumpAndSettle();
      expect(fake.previewed.map((v) => v.name), ['zh-a']);
    });

    testWidgets('in-picker language switch reloads the other list',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, _fake());
      expect(find.text('en-a'), findsOneWidget);
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('zh-a'), findsOneWidget);
      expect(find.text('en-a'), findsNothing);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('en-a'), findsOneWidget);
      expect(find.text('zh-a'), findsNothing);
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
      expect(find.text('en-a'), findsOneWidget);
    });

    testWidgets('rapid taps: latest preview wins, stays selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _fake();
      await _pumpPicker(tester, fake);
      await tester.tap(find.text('en-a'));
      await tester.tap(find.text('en-b'));
      await tester.pumpAndSettle();
      // Each preview stops the previous one first (single audio stream).
      expect(fake.stops, 2);
      expect(fake.previewed.map((v) => v.name), ['en-a', 'en-b']);
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
      await tester.tap(find.text('en-a'));
      await tester.pumpAndSettle();
      await _pumpPicker(tester, fake, language: 'zh-Hans');
      await tester.tap(find.text('zh-a'));
      await tester.pumpAndSettle();
      // Restart: each language shows its own choice (highlight, no marker).
      await _pumpPicker(tester, fake, language: 'en');
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        tester.widget<ListTile>(find.byWidgetPredicate(
          (w) => w is ListTile && w.selected,
        )).title,
        isA<Text>().having((t) => t.data, 'data', 'en-a'),
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
      await tester.tap(find.text('en-b'));
      await tester.pumpAndSettle();
      // No check mark / icon anywhere in the picker list.
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
        isA<Text>().having((t) => t.data, 'data', 'en-b'),
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
      // 40 English voices; en-39 preselected (bottom of the list).
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
      // Selected row highlighted …
      expect(
        find.byWidgetPredicate((w) => w is ListTile && w.selected),
        findsOneWidget,
      );
      // … and scrolled into view (list starts at top otherwise).
      final list = tester.widget<Scrollable>(find.descendant(
        of: find.byType(VoicePickerScreen),
        matching: find.byType(Scrollable),
      ));
      expect(list.controller!.offset, greaterThan(0));
    });
  });
}
