import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'KalaHoo Reading'**
  String get appTitle;

  /// No description provided for @englishNative.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishNative;

  /// No description provided for @chineseNative.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chineseNative;

  /// No description provided for @spanishNative.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get spanishNative;

  /// No description provided for @readButton.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readButton;

  /// No description provided for @continueReadButton.
  ///
  /// In en, this message translates to:
  /// **'Continue Read'**
  String get continueReadButton;

  /// No description provided for @stopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopButton;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @voiceButton.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceButton;

  /// No description provided for @languageDropdown.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageDropdown;

  /// No description provided for @hintText.
  ///
  /// In en, this message translates to:
  /// **'Tap a sentence to read'**
  String get hintText;

  /// No description provided for @nothingToReadMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to read from here'**
  String get nothingToReadMessage;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @ageYoung.
  ///
  /// In en, this message translates to:
  /// **'Young'**
  String get ageYoung;

  /// No description provided for @ageOld.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get ageOld;

  /// No description provided for @dialectStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get dialectStandard;

  /// No description provided for @dialectMandarin.
  ///
  /// In en, this message translates to:
  /// **'Mandarin'**
  String get dialectMandarin;

  /// No description provided for @dialectCantonese.
  ///
  /// In en, this message translates to:
  /// **'广东话'**
  String get dialectCantonese;

  /// No description provided for @pauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseButton;

  /// No description provided for @resumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeButton;

  /// No description provided for @voicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voice} other{{count} voices}}'**
  String voicesCount(int count);

  /// No description provided for @noVoices.
  ///
  /// In en, this message translates to:
  /// **'No voices installed for this language.'**
  String get noVoices;

  /// No description provided for @voicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load voices.'**
  String get voicesLoadFailed;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @contentsButton.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get contentsButton;

  /// No description provided for @contentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get contentsTitle;

  /// No description provided for @currentContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading: {name}'**
  String currentContentLabel(Object name);

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @undoButton.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @discardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardButton;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this content?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteConfirmMessage;

  /// No description provided for @deletePresetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. A deleted sample returns only if you reinstall the app.'**
  String get deletePresetConfirmMessage;

  /// No description provided for @savedMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedMessage;

  /// No description provided for @nothingToSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to save'**
  String get nothingToSaveMessage;

  /// No description provided for @undoExhaustedMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing more to undo'**
  String get undoExhaustedMessage;

  /// No description provided for @contentTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'Too long to save (limit: {limit} characters)'**
  String contentTooLargeMessage(Object limit);

  /// No description provided for @storageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Check storage space and try again.'**
  String get storageErrorMessage;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have changes that are not saved.'**
  String get unsavedChangesMessage;

  /// No description provided for @noContentsMessage.
  ///
  /// In en, this message translates to:
  /// **'No contents yet. Write something, then tap Save.'**
  String get noContentsMessage;

  /// No description provided for @damagedContentMessage.
  ///
  /// In en, this message translates to:
  /// **'This content is damaged'**
  String get damagedContentMessage;

  /// No description provided for @libraryRepairedMessage.
  ///
  /// In en, this message translates to:
  /// **'The content library was repaired: a damaged index was replaced and the shipped samples are back.'**
  String get libraryRepairedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
