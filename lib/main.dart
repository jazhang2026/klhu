import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/services/localization_service.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final reader = ReaderService();
  final voiceStore = VoiceStore();
  runApp(KlhuApp(
    prefs: prefs,
    reader: reader,
    voiceStore: voiceStore,
    // The content library (008): app documents directory for the index and the
    // saved texts, seeded from the shipped preset catalog on first launch.
    contentStore: ContentStore(),
    // Fresh install follows the device language (spec 007 FR-007).
    deviceLocale: WidgetsBinding.instance.platformDispatcher.locale,
  ));
}

class KlhuApp extends StatefulWidget {
  final SharedPreferences prefs;
  final Reader reader;
  final VoiceStore voiceStore;

  /// Optional so widget tests can inject a store on a temp directory.
  final ContentStore? contentStore;

  /// Device locale: the interface language used until the user picks one.
  final Locale? deviceLocale;

  const KlhuApp({
    super.key,
    required this.prefs,
    required this.reader,
    required this.voiceStore,
    this.contentStore,
    this.deviceLocale,
  });

  @override
  State<KlhuApp> createState() => _KlhuAppState();
}

class _KlhuAppState extends State<KlhuApp> {
  late LocalizationService _localizationService;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _localizationService = LocalizationService(
      widget.prefs,
      deviceLocale: widget.deviceLocale,
    );
    _currentLocale = _localizationService.getCurrentLocale();
  }

  void _updateLanguage(String languageCode) {
    setState(() {
      _currentLocale = _localizationService.resolveLocale(languageCode);
    });
    // Persist so the preference survives a restart (FR-005 / SC-004).
    _localizationService.saveLanguage(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KalaHoo Reading',
      // The OS-visible title (Android task switcher, web tab) follows the
      // interface language too — otherwise Spanish and Chinese builds still
      // announce "KalaHoo Reading" outside the app itself (spec 007 FR-001/003).
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'KalaHoo Reading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
        Locale('es'),
      ],
      locale: _currentLocale,
      home: ReadingView(
        onLanguageChanged: _updateLanguage,
        localizationService: _localizationService,
        reader: widget.reader,
        voiceStore: widget.voiceStore,
        contentStore: widget.contentStore,
      ),
    );
  }
}
