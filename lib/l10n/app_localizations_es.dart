// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'KalaHoo Lectura';

  @override
  String get englishNative => 'English';

  @override
  String get chineseNative => '中文';

  @override
  String get spanishNative => 'Español';

  @override
  String get readButton => 'Leer';

  @override
  String get readPageButton => 'Leer página';

  @override
  String get stopButton => 'Detener';

  @override
  String get editButton => 'Editar';

  @override
  String get doneButton => 'Listo';

  @override
  String get voiceButton => 'Voz';

  @override
  String get languageDropdown => 'Idioma';

  @override
  String get hintText => 'Toca una oración para leer';

  @override
  String get genderMale => 'Masculina';

  @override
  String get genderFemale => 'Femenina';

  @override
  String get ageYoung => 'Joven';

  @override
  String get ageOld => 'Mayor';

  @override
  String get dialectStandard => 'Estándar';

  @override
  String get dialectMandarin => 'Mandarín';

  @override
  String get dialectCantonese => '广东话';

  @override
  String get pauseButton => 'Pausar';

  @override
  String get resumeButton => 'Reanudar';

  @override
  String get sampleEn => 'Muestra en inglés';

  @override
  String get sampleZh => 'Muestra en chino';

  @override
  String get sampleEs => 'Muestra en español';

  @override
  String voicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voces',
      one: '1 voz',
    );
    return '$_temp0';
  }

  @override
  String get noVoices => 'No hay voces instaladas para este idioma.';

  @override
  String get voicesLoadFailed => 'No se pudieron cargar las voces.';

  @override
  String get retryButton => 'Reintentar';
}
