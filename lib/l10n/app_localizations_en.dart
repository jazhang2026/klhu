// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KalaHoo Reading';

  @override
  String get englishNative => 'English';

  @override
  String get chineseNative => '中文';

  @override
  String get spanishNative => 'Español';

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

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get ageYoung => 'Young';

  @override
  String get ageOld => 'Old';

  @override
  String get dialectStandard => 'Standard';

  @override
  String get dialectMandarin => 'Mandarin';

  @override
  String get dialectCantonese => '广东话';

  @override
  String get pauseButton => 'Pause';

  @override
  String get resumeButton => 'Resume';

  @override
  String get sampleEn => 'EN sample';

  @override
  String get sampleZh => '中文示例';

  @override
  String get sampleEs => 'ES sample';

  @override
  String voicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voices',
      one: '1 voice',
    );
    return '$_temp0';
  }

  @override
  String get noVoices => 'No voices installed for this language.';

  @override
  String get voicesLoadFailed => 'Could not load voices.';

  @override
  String get retryButton => 'Retry';
}
