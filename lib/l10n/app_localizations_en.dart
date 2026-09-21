// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KalaHoo';

  @override
  String get englishNative => 'English';

  @override
  String get chineseNative => '中文';

  @override
  String get readButton => 'Read';

  @override
  String get readPageButton => 'Read page';

  @override
  String get stopButton => 'Stop';

  @override
  String get editButton => 'Edit';

  @override
  String get doneButton => 'Done';

  @override
  String get voiceButton => 'Voice';

  @override
  String get languageDropdown => 'Language';

  @override
  String get hintText => 'Tap a sentence to read';
}
