import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/language.dart';
import 'package:klhu/main.dart';
import 'package:klhu/models/language_preference.dart';
import 'package:klhu/reader_service.dart';
import 'content_fixtures.dart';
import 'package:klhu/services/localization_service.dart';
import 'package:klhu/voice_store.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:klhu/content_naming.dart';
import 'package:klhu/services/content_store.dart';

/// Voice inventory shaped like the emulator's Google TTS (spec 007 research.md
/// correction 1): two Spanish locales and NO `es-MX`.
const _voices = <dynamic>[
  {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
  {'name': 'es-ES-language', 'locale': 'es-ES'},
  {'name': 'es-es-x-eed-local', 'locale': 'es-ES'},
  {'name': 'es-US-language', 'locale': 'es-US'},
  {'name': 'es-us-x-esd-local', 'locale': 'es-US'},
  {'name': 'zh-CN-language', 'locale': 'zh-Hans-CN'},
];

class _FakeTts implements TtsBackend {
  @override
  Future<List<dynamic>> getVoices() async => _voices;

  @override
  Future<dynamic> setLanguage(String locale) async {}

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {}

  @override
  Future<dynamic> speak(String text) async {}

  @override
  Future<dynamic> stop() async {}

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {}

  @override
  void setCompletionHandler(VoidCallback callback) {}
}

class _FakeReader implements Reader {
  final List<List<ParagraphSpeech>> reads = [];
  final List<String> voiceRequests = [];

  @override
  Future<void> speak(String text, String language) async {}

  @override
  Future<void> stop() async {}

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
    voiceRequests.add(language);
    return const [];
  }

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(int index)? onParagraphStart,
  }) async {
    reads.add(paragraphs);
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

Future<SharedPreferences> _freshPrefs([Map<String, Object>? values]) async {
  SharedPreferences.setMockInitialValues(values ?? {});
  return SharedPreferences.getInstance();
}

/// The real app widget (main.dart), so the interface language, the app bar
/// title and the dropdown are exercised together.
Future<void> _pumpApp(
  WidgetTester tester, {
  required SharedPreferences prefs,
  Reader? reader,
  Locale? deviceLocale,
}) async {
  await tester.pumpWidget(KlhuApp(
    prefs: prefs,
    reader: reader ?? _FakeReader(),
    voiceStore: VoiceStore(),
    deviceLocale: deviceLocale,
  ));
  // Let the page's content load land, which also drains the storage deadline.
  await loadPageContent(tester);
}

void main() {
  group('fresh install follows a Spanish device locale (FR-007)', () {
    test('any Spanish device locale resolves to the shipped Spanish set', () {
      expect(
        LanguagePreference.resolveDefaultLanguage(const Locale('es', 'MX')),
        'es',
      );
      // The spec names es-MX, but only ONE Spanish translation and no es-MX
      // TTS voice exist on the engine: every Spanish device locale resolves to
      // the same set rather than falling back to English.
      expect(
        LanguagePreference.resolveDefaultLanguage(const Locale('es', 'ES')),
        'es',
      );
      expect(
        LanguagePreference.resolveDefaultLanguage(const Locale('es')),
        'es',
      );
    });

    test('non-Spanish device locales are unaffected', () {
      expect(LanguagePreference.resolveDefaultLanguage(const Locale('zh')), 'zh');
      expect(
        LanguagePreference.resolveDefaultLanguage(const Locale('zh', 'CN')),
        'zh',
      );
      expect(LanguagePreference.resolveDefaultLanguage(const Locale('en')), 'en');
      expect(LanguagePreference.resolveDefaultLanguage(null), 'en');
    });

    testWidgets('an es_MX device boots the app in Spanish', (tester) async {
      await _pumpApp(
        tester,
        prefs: await _freshPrefs(),
        deviceLocale: const Locale('es', 'MX'),
      );
      expect(find.text('KalaHoo Lectura'), findsOneWidget);
      expect(find.text('KalaHoo Reading'), findsNothing);
      expect(find.byTooltip('Leer'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      // Content is reached through the library now; the sample buttons are gone
      // in every interface language (008 FR-003).
      expect(find.text('Muestra en español'), findsNothing);
      expect(find.text('ES sample'), findsNothing);
    });
  });

  group('Spanish is a selectable, persistent interface language (FR-004/005)', () {
    test('resolveLocale("es") is a Spanish locale with no country claim',
        () async {
      final service = LocalizationService(await _freshPrefs());
      expect(service.resolveLocale('es'), const Locale('es'));
      expect(service.resolveLocale('es').languageCode, 'es');
    });

    test('the stored preference survives a restart', () async {
      final prefs = await _freshPrefs();

      // First run in English, user picks Español.
      final first = LocalizationService(prefs, deviceLocale: const Locale('en'));
      expect(first.loadLanguage(), 'en');
      await first.saveLanguage('es');

      // "Restart": a new service over the same storage, no device locale.
      final second = LocalizationService(prefs);
      expect(second.loadLanguage(), 'es');
      expect(second.getCurrentLocale(), const Locale('es'));
      expect(second.getCurrentLanguageCode(), 'es');
    });

    test('a saved Spanish choice outranks the device locale', () async {
      final prefs = await _freshPrefs({'interface_language': 'es'});
      final service =
          LocalizationService(prefs, deviceLocale: const Locale('zh'));
      expect(service.getCurrentLocale(), const Locale('es'));
    });

    testWidgets('picking Español switches the interface and persists it',
        (tester) async {
      final prefs = await _freshPrefs();

      await _pumpApp(tester, prefs: prefs, deviceLocale: const Locale('en'));
      expect(find.text('KalaHoo Reading'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect(find.text('KalaHoo Lectura'), findsOneWidget);
      expect(find.text('KalaHoo Reading'), findsNothing);
      expect(prefs.getString('interface_language'), 'es');

      // Restart straight into Spanish, without the dropdown.
      await _pumpApp(tester, prefs: prefs);
      expect(find.text('KalaHoo Lectura'), findsOneWidget);
    });
  });

  group('Spanish reading: sample, detection, speech locale (FR-006)', () {
    test('the bundled Spanish sample detects as es, paragraph by paragraph',
        () async {
      expect(kSampleTexts, contains(kSampleEsText));
      final speeches = await resolveParagraphSpeeches(
        kSampleEsText,
        0,
        kSampleEsText.length,
        (_) async => null,
      );
      expect(speeches, isNotEmpty);
      for (final speech in speeches) {
        expect(speech.language, 'es', reason: speech.text);
      }
    });

    test('Spanish speech uses es-US — the engine has no es-MX voice', () {
      // Measured on emulator-5554: the engine reports es-ES and es-US only,
      // so setLanguage('es-MX') would fall back to the engine default (English
      // audio for Spanish text). es-US is the Latin American variety the spec
      // targets. Evidence: specs/007-.../voice-gender-evidence.md.
      expect(ReaderService.localeFor('es'), 'es-US');
      expect(ReaderService.localeFor('en'), 'en-US');
      expect(ReaderService.localeFor('zh-Hans'), 'zh-Hans-CN');
    });

    test('the Spanish voice list carries every es* voice, nothing else',
        () async {
      final service = ReaderService(_FakeTts());
      final voices = await service.voicesFor('es');
      expect(voices.map((v) => v.name), [
        'es-ES-language',
        'es-es-x-eed-local',
        'es-US-language',
        'es-us-x-esd-local',
      ]);
      expect(voices.every((v) => v.locale.startsWith('es')), isTrue);
    });

    test('a Spanish read resolves each paragraph with its saved es voice',
        () async {
      const saved = VoiceChoice(
        language: 'es',
        name: 'es-us-x-esd-local',
        locale: 'es-US',
      );
      final speeches = await resolveParagraphSpeeches(
        kSampleEsText,
        0,
        kSampleEsText.length,
        (language) async => language == 'es' ? saved : null,
      );
      expect(speeches.length, 3);
      for (final speech in speeches) {
        expect(speech.language, 'es');
        expect(speech.voice?.name, 'es-us-x-esd-local');
      }
    });

    testWidgets('the OS-visible app title follows the interface language',
        (tester) async {
      // The Android task switcher / web tab title, not the app bar (FR-001/003).
      await _pumpApp(
        tester,
        prefs: await _freshPrefs(),
        deviceLocale: const Locale('es', 'MX'),
      );
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        'KalaHoo Lectura',
      );
    });

    test('the shipped catalog carries the Spanish pre-set and its title', () {
      // The UI path that loads it (last used content) is covered by the content
      // library tests; here the shipped data itself is checked.
      final presets = parsePresetCatalog(
          File('assets/content/presets.json').readAsStringSync());
      final spanish =
          presets.firstWhere((preset) => preset.language == 'es');

      expect(spanish.text, contains('El sol salió'));
      expect(contentNameFrom(spanish.text), contains('El sol salió'));
      expect(contentNameFrom(spanish.text), isNot(contains('\n')));
    });

    testWidgets('the picker itself is localized and offers the Spanish list',
        (tester) async {
      final backend = _FakeTts();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh'), Locale('es')],
        home: VoicePickerScreen(
          reader: ReaderService(backend),
          store: VoiceStore(),
          language: 'es',
        ),
      ));
      await tester.pumpAndSettle();

      // One segment per list, including Spanish (it used to be en/zh only, so
      // a Spanish reading session had no way back to the Spanish list).
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);
      // Count and characteristics read in the list's language.
      expect(find.text('4 voces'), findsOneWidget);
      expect(find.text('4 voices'), findsNothing);
      expect(find.textContaining('Femenina'), findsWidgets);
      expect(find.textContaining('Female'), findsNothing);
    });

    testWidgets('the voice picker opens on the Spanish list for Spanish text',
        (tester) async {
      final reader = _FakeReader();
      await _pumpApp(
        tester,
        prefs: await _freshPrefs(),
        reader: reader,
        deviceLocale: const Locale('es', 'MX'),
      );

      // Content now comes from the library (the sample buttons are gone, 008
      // FR-003): put Spanish text on the page through EDIT.
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(TextField), kSampleEsText);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      await tester.tap(find.byTooltip('Voz'));
      await tester.pumpAndSettle();

      // The picker asks for the ACTIVE paragraph's language, which is Spanish.
      expect(reader.voiceRequests, contains('es'));

      // Its preview line is Spanish (spec 007, sampleLineFor).
      expect(find.byType(VoicePickerScreen), findsOneWidget);
    });
  });
}
