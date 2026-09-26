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
  String get continueReadButton => 'Continue Read';

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
  String get nothingToReadMessage => 'Nothing left to read from here';

  @override
  String get selectToReadMessage => 'Select a sentence or paragraph to read';

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

  @override
  String get addContentButton => 'Add content';

  @override
  String get appearanceButton => 'Appearance';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get fontLabel => 'Typeface';

  @override
  String get sizeLabel => 'Text size';

  @override
  String get previewLabel => 'Preview';

  @override
  String get fontDefaultLabel => 'Default';

  @override
  String get fontSerifLabel => 'Serif';

  @override
  String get fontMonoLabel => 'Mono';

  @override
  String get sizeSmallLabel => 'Small';

  @override
  String get sizeMediumLabel => 'Medium';

  @override
  String get sizeLargeLabel => 'Large';

  @override
  String get sizeXLargeLabel => 'Extra large';

  @override
  String get videoButton => 'Video';

  @override
  String get videoAspectTitle => 'Video format';

  @override
  String get videoAspectLandscape => '16:9 landscape 1080p';

  @override
  String get videoAspectVertical => '9:16 vertical (Shorts)';

  @override
  String get videoStartButton => 'Start';

  @override
  String get videoRenderingLabel => 'Rendering video…';

  @override
  String videoProgressLabel(int index, int total) {
    return 'Rendering video, sentence $index of $total';
  }

  @override
  String get videoPreviewLabel => 'Video preview';

  @override
  String get videoStopConfirmTitle => 'Stop making the video?';

  @override
  String get videoStopConfirmMessage => 'The video will not be saved.';

  @override
  String get videoLeaveTitle => 'Leave the video?';

  @override
  String get videoLeaveMessage => 'Nothing is saved until you tap Save.';

  @override
  String get videoSavedMessage => 'Video saved';

  @override
  String get videoNotSavedMessage => 'Video not saved';

  @override
  String get videoReplacedMessage => 'The earlier video was replaced';

  @override
  String get videoShareButton => 'Share';

  @override
  String get videoShareTitle => 'Share video';

  @override
  String get videoPlayButton => 'Play video';

  @override
  String get videoDeleteButton => 'Delete video';

  @override
  String get videoDeleteConfirmTitle => 'Delete this video?';

  @override
  String get videoGoneMessage => 'This video is gone';

  @override
  String get videoRenderFailedMessage =>
      'Could not make the video. Check storage space and try again.';

  @override
  String get videoUnavailableMessage => 'This device cannot make videos.';
}
