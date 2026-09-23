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

  @override
  String get contentsButton => 'Contents';

  @override
  String get contentsTitle => 'Contents';

  @override
  String currentContentLabel(Object name) {
    return 'Reading: $name';
  }

  @override
  String get saveButton => 'Save';

  @override
  String get undoButton => 'Undo';

  @override
  String get deleteButton => 'Delete';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get discardButton => 'Discard';

  @override
  String get deleteConfirmTitle => 'Delete this content?';

  @override
  String get deleteConfirmMessage => 'This cannot be undone.';

  @override
  String get deletePresetConfirmMessage =>
      'This cannot be undone. A deleted sample returns only if you reinstall the app.';

  @override
  String get savedMessage => 'Saved';

  @override
  String get nothingToSaveMessage => 'There is nothing to save';

  @override
  String get undoExhaustedMessage => 'Nothing more to undo';

  @override
  String contentTooLargeMessage(Object limit) {
    return 'Too long to save (limit: $limit characters)';
  }

  @override
  String get storageErrorMessage =>
      'Could not save. Check storage space and try again.';

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesMessage => 'You have changes that are not saved.';

  @override
  String get noContentsMessage =>
      'No contents yet. Write something, then tap Save.';

  @override
  String get damagedContentMessage => 'This content is damaged';

  @override
  String get libraryRepairedMessage =>
      'The content library was repaired: a damaged index was replaced and the shipped samples are back.';
}
