import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/l10n/app_localizations_en.dart';
import 'package:klhu/l10n/app_localizations_zh.dart';
import 'package:klhu/models/voice_mapping.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/services/voice_mapping_service.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The engine's own inventory for the Chinese list (spec 007 research.md
/// correction 2): Mandarin (`cmn-*`) plus the 7 Cantonese voices (`yue-HK`),
/// which `locale.startsWith('zh')` used to filter out.
const _yueVoices = <Map<String, String>>[
  {'name': 'yue-HK-language', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-jar-local', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-jar-network', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yuc-local', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yuc-network', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yud-local', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yud-network', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yue-local', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yue-network', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yuf-local', 'locale': 'yue-HK'},
  {'name': 'yue-hk-x-yuf-network', 'locale': 'yue-HK'},
];

const _cmnVoices = <Map<String, String>>[
  {'name': 'zh-CN-language', 'locale': 'zh-CN'},
  {'name': 'cmn-cn-x-ssa-local', 'locale': 'zh-CN'},
  {'name': 'cmn-tw-x-ctc-local', 'locale': 'zh-TW'},
];

const _otherVoices = <Map<String, String>>[
  {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
  {'name': 'es-US-language', 'locale': 'es-US'},
];

List<dynamic> _engine({bool withCantonese = true}) => [
      ..._otherVoices,
      ..._cmnVoices,
      if (withCantonese) ..._yueVoices,
    ];

class _FakeTts implements TtsBackend {
  final List<dynamic> voices;
  final List<String> languages = [];
  final List<Map<String, String>> setVoices = [];
  final List<String> spoken = [];
  VoidCallback? _handler;

  _FakeTts({bool withCantonese = true}) : voices = _engine(withCantonese: withCantonese);

  @override
  Future<List<dynamic>> getVoices() async => voices;

  @override
  Future<dynamic> setLanguage(String locale) async {
    languages.add(locale);
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    setVoices.add(voice);
  }

  @override
  Future<dynamic> speak(String text) async {
    spoken.add(text);
    final h = _handler;
    if (h != null) scheduleMicrotask(h);
  }

  @override
  Future<dynamic> stop() async {}

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {}

  @override
  Future<dynamic> awaitSynthCompletion(bool awaitCompletion) async {}

  @override
  Future<dynamic> synthesizeToFile(String text, String fileName) async => 1;

  @override
  void setCompletionHandler(VoidCallback callback) {
    _handler = callback;
  }
}

/// The voice picker is opened from the reading view while the app locale is
/// put; its own labels come from the app, its voice names from the LIST
/// language ('zh-Hans').
Future<void> _pumpPicker(
  WidgetTester tester,
  Reader reader, {
  String language = 'zh-Hans',
  Locale locale = const Locale('en'),
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
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('es')],
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
  group('the Chinese voice list carries Cantonese (US3, FR-008)', () {
    test('voicesFor("zh-Hans") returns Mandarin AND the yue-HK voices',
        () async {
      final service = ReaderService(_FakeTts());
      final names = (await service.voicesFor('zh-Hans')).map((v) => v.name);

      // Regression: `locale.startsWith('zh')` hid every Cantonese voice.
      for (final voice in _yueVoices) {
        expect(names, contains(voice['name']), reason: voice['name']);
      }
      for (final voice in _cmnVoices) {
        expect(names, contains(voice['name']), reason: voice['name']);
      }
      expect(names, isNot(contains('en-us-x-sfg-local')));
      expect(names, isNot(contains('es-US-language')));
    });

    test('Cantonese is additive: a device without it still lists Chinese',
        () async {
      // The spec's "Cantonese unavailable" edge case: the list must degrade to
      // Mandarin, not to an error or an empty list.
      final service = ReaderService(_FakeTts(withCantonese: false));
      final voices = await service.voicesFor('zh-Hans');
      expect(voices.map((v) => v.name), contains('cmn-cn-x-ssa-local'));
      expect(voices.any((v) => v.name.startsWith('yue-')), isFalse);
    });
  });

  group('every Cantonese voice is named 广东话 (FR-010, SC-006)', () {
    test('no yue-HK row falls back to its raw system id', () {
      for (final voice in _yueVoices) {
        final mapping = VoiceMappingTable.lookup(voice['name']!);
        expect(mapping, isNotNull, reason: voice['name']);
      }
    });

    test('the names are Chinese characters in BOTH interfaces', () {
      for (final voice in _yueVoices) {
        final mapping = VoiceMappingTable.lookup(voice['name']!)!;
        expect(mapping.englishName, startsWith('广东话'),
            reason: voice['name']);
        expect(mapping.chineseName, startsWith('广东话'),
            reason: voice['name']);
        // The reader asked for Chinese characters only.
        expect(mapping.englishName.toLowerCase(), isNot(contains('cantonese')));
        expect(mapping.chineseName, isNot(contains('粤语')));
        // The dialect sits in the name; a dialect label would only repeat it.
        expect(mapping.dialect, isNull, reason: voice['name']);
        expect(mapping.age, isNull, reason: voice['name']);
        expect(mapping.gender, isNotNull, reason: voice['name']);
      }
    });

    test('the picker shows 广东话 rows in the English and Chinese UI alike', () {
      final service = VoiceMappingService();
      const jar = VoiceEntry(name: 'yue-hk-x-jar-local', locale: 'yue-HK');

      final zhList = service.displayName(jar, AppLocalizationsEn(),
          voiceListLanguage: 'zh-Hans');
      expect(zhList, contains('广东话'));
      expect(zhList, isNot(contains('yue-hk-x-jar-local')));

      final enList = service.displayName(jar, AppLocalizationsZh(),
          voiceListLanguage: 'en');
      expect(enList, contains('广东话'));
      expect(enList, isNot(contains('yue-hk-x-jar-local')));
    });
  });

  group('picking Cantonese IS the Chinese voice pick (FR-009)', () {
    test('a yue choice persists under the Chinese key, not a new one',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = VoiceStore();
      await store.saveVoice(const VoiceChoice(
        language: 'zh-Hans',
        name: 'yue-hk-x-jar-local',
        locale: 'yue-HK',
      ));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('voice_zh_Hans'), 'yue-hk-x-jar-local||yue-HK');
      expect(
        (await store.loadVoice('zh-Hans'))?.name,
        'yue-hk-x-jar-local',
      );
      // No separate Cantonese slot, and the other languages stay untouched.
      expect(VoiceStore.keyFor('zh-Hans'), 'voice_zh_Hans');
      expect(prefs.getString('voice_en'), isNull);
      expect(prefs.getString('voice_es'), isNull);
    });

    test('Chinese text read with a picked Cantonese voice speaks in Cantonese',
        () async {
      final backend = _FakeTts();
      final service = ReaderService(backend);
      await service.speakParagraphs([
        const ParagraphSpeech(
          text: '你好，今天天气很好。',
          language: 'zh-Hans',
          voice: VoiceChoice(
            language: 'zh-Hans',
            name: 'yue-hk-x-jar-local',
            locale: 'yue-HK',
          ),
          start: 0,
          end: 10,
        ),
      ]);

      expect(backend.spoken, ['你好，今天天气很好。']);
      // The picked voice's OWN locale reaches the engine — that is what makes
      // the engine speak Cantonese for Chinese text.
      expect(backend.languages, ['yue-HK']);
      expect(backend.setVoices, [
        {'name': 'yue-hk-x-jar-local', 'locale': 'yue-HK'},
      ]);
    });

    testWidgets('tap a 广东话 row: previews in Cantonese, stores the Chinese pick',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _FakeTts();
      await _pumpPicker(tester, ReaderService(backend), language: 'zh-Hans');

      expect(find.textContaining('广东话 JAR'), findsWidgets);
      expect(find.textContaining('普通话 SSA'), findsOneWidget);

      await tester.tap(find.textContaining('广东话 JAR').first);
      await tester.pumpAndSettle();

      // Preview spoke the Chinese sample line with the Cantonese voice…
      expect(backend.setVoices, [
        {'name': 'yue-hk-x-jar-local', 'locale': 'yue-HK'},
      ]);
      expect(backend.languages, ['yue-HK']);
      expect(backend.spoken, ['你好，这是我的朗读声音。']);

      // …and the pick persisted under the Chinese key.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('voice_zh_Hans'), 'yue-hk-x-jar-local||yue-HK');
      final selected =
          find.byWidgetPredicate((w) => w is ListTile && w.selected);
      expect(selected, findsOneWidget);
      expect(
        tester.widget<ListTile>(selected).title,
        isA<Text>().having((t) => t.data, 'data', contains('广东话 JAR')),
      );
    });

    testWidgets('the Chinese list keeps the English voices out', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPicker(tester, ReaderService(_FakeTts()), language: 'zh-Hans');
      expect(find.textContaining('US SFG'), findsNothing);
      expect(find.textContaining('广东话'), findsWidgets);
    });
  });
}
