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
  String get continueReadButton => 'Continuar leyendo';

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
  String get nothingToReadMessage => 'No queda nada por leer desde aquí';

  @override
  String get selectToReadMessage =>
      'Selecciona una frase o un párrafo para leer';

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

  @override
  String get contentsButton => 'Contenidos';

  @override
  String get contentsTitle => 'Contenidos';

  @override
  String get saveButton => 'Guardar';

  @override
  String get undoButton => 'Deshacer';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get discardButton => 'Descartar';

  @override
  String get deleteConfirmTitle => '¿Eliminar este contenido?';

  @override
  String get deleteConfirmMessage => 'Esta acción no se puede deshacer.';

  @override
  String get deletePresetConfirmMessage =>
      'Esta acción no se puede deshacer. Una muestra eliminada vuelve solo si reinstalas la aplicación.';

  @override
  String get savedMessage => 'Guardado';

  @override
  String get nothingToSaveMessage => 'No hay nada que guardar';

  @override
  String get undoExhaustedMessage => 'No hay más para deshacer';

  @override
  String contentTooLargeMessage(Object limit) {
    return 'Demasiado largo para guardar (límite: $limit caracteres)';
  }

  @override
  String get storageErrorMessage =>
      'No se pudo guardar. Verifica el espacio de almacenamiento e inténtalo de nuevo.';

  @override
  String get unsavedChangesTitle => 'Cambios sin guardar';

  @override
  String get unsavedChangesMessage => 'Tienes cambios que no están guardados.';

  @override
  String get noContentsMessage =>
      'Aún no hay contenidos. Escribe algo y toca Guardar.';

  @override
  String get damagedContentMessage => 'Este contenido está dañado';

  @override
  String get libraryRepairedMessage =>
      'La biblioteca se reparó: un índice dañado fue reemplazado y las muestras vuelven a estar disponibles.';

  @override
  String get addContentButton => 'Añadir contenido';

  @override
  String get appearanceButton => 'Apariencia';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get fontLabel => 'Tipografía';

  @override
  String get sizeLabel => 'Tamaño del texto';

  @override
  String get previewLabel => 'Vista previa';

  @override
  String get fontDefaultLabel => 'Predeterminada';

  @override
  String get fontSerifLabel => 'Serif';

  @override
  String get fontMonoLabel => 'Monoespaciada';

  @override
  String get sizeSmallLabel => 'Pequeño';

  @override
  String get sizeMediumLabel => 'Mediano';

  @override
  String get sizeLargeLabel => 'Grande';

  @override
  String get sizeXLargeLabel => 'Muy grande';

  @override
  String get videoButton => 'Vídeo';

  @override
  String get videoAspectTitle => 'Formato del vídeo';

  @override
  String get videoAspectLandscape => '16:9 horizontal 1080p';

  @override
  String get videoAspectVertical => '9:16 vertical (Shorts)';

  @override
  String get videoStartButton => 'Empezar';

  @override
  String get videoRenderingLabel => 'Generando el vídeo…';

  @override
  String videoProgressLabel(int index, int total) {
    return 'Generando el vídeo, frase $index de $total';
  }

  @override
  String get videoPreviewLabel => 'Vista previa del vídeo';

  @override
  String get videoStopConfirmTitle => '¿Detener la creación del vídeo?';

  @override
  String get videoStopConfirmMessage => 'El vídeo no se guardará.';

  @override
  String get videoLeaveTitle => '¿Salir del vídeo?';

  @override
  String get videoLeaveMessage => 'No se guarda nada hasta que pulses Guardar.';

  @override
  String get videoSavedMessage => 'Vídeo guardado';

  @override
  String get videoNotSavedMessage => 'Vídeo no guardado';

  @override
  String get videoReplacedMessage => 'Se reemplazó el vídeo anterior';

  @override
  String get videoShareButton => 'Compartir';

  @override
  String get videoShareTitle => 'Compartir vídeo';

  @override
  String get videoPlayButton => 'Reproducir vídeo';

  @override
  String get videoDeleteButton => 'Eliminar vídeo';

  @override
  String get videoDeleteConfirmTitle => '¿Eliminar este vídeo?';

  @override
  String get videoGoneMessage => 'Este vídeo ya no existe';

  @override
  String get videoRenderFailedMessage =>
      'No se pudo crear el vídeo. Comprueba el espacio de almacenamiento e inténtalo de nuevo.';

  @override
  String get videoUnavailableMessage =>
      'Este dispositivo no puede crear vídeos.';
}
