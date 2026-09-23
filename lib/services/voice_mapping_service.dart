import 'package:flutter/widgets.dart' show Locale;
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/voice_mapping.dart';
import 'package:klhu/reader_service.dart';

/// Service for looking up user-friendly voice names.
///
/// Uses [VoiceMappingTable] to resolve system voice IDs to display names
/// in the current locale. Falls back to the system voice name when no
/// mapping is found.
class VoiceMappingService {
  /// Get the display name for a voice.
  ///
  /// [voiceListLanguage] is the language the voice LIST is rendered in
  /// ('en', 'zh-Hans', 'es'); it picks the mapped name AND the characteristic
  /// labels. It defaults to the app locale.
  ///
  /// Labels are resolved from [voiceListLanguage], never from [l10n]: the
  /// picker shows the other language's voices while the app locale stays
  /// put, so reading a zh label off the app's [l10n] renders the
  /// half-translated "国语女声（本地） (Female, Young, Mandarin)".
  ///
  /// Returns a formatted string like "Google US English Female (Young, Standard)"
  /// in English or "谷歌美式英语女声 (年轻, 标准音)" in Chinese.
  String displayName(VoiceEntry voice, AppLocalizations l10n,
      {String? voiceListLanguage}) {
    final mapping = VoiceMappingTable.lookup(voice.name);
    if (mapping == null) {
      return voice.name;
    }

    // Determine display language: explicit parameter wins, else app locale.
    // Labels follow the LIST language for all three lists (en/zh/es): the
    // Spanish list used to fall through to the English branch, so a Spanish
    // reading session showed "US SFB (Female)" while the ARB already had
    // "Femenina" (found on emulator-5554, spec 007 SC-002).
    final effectiveLocale = voiceListLanguage ?? l10n.localeName;
    final code = effectiveLocale.split(RegExp(r'[-_]')).first.toLowerCase();
    final isZh = code == 'zh';
    final labels =
        lookupAppLocalizations(Locale(isZh ? 'zh' : (code == 'es' ? 'es' : 'en')));

    final parts = <String>[isZh ? mapping.chineseName : mapping.englishName];

    final characteristics = <String>[];
    if (mapping.gender != null) {
      characteristics.add(
          mapping.gender == 'male' ? labels.genderMale : labels.genderFemale);
    }
    if (mapping.age != null) {
      characteristics
          .add(mapping.age == 'old' ? labels.ageOld : labels.ageYoung);
    }
    if (mapping.dialect != null) {
      characteristics.add(_dialectLabel(mapping.dialect!, labels));
    }

    if (characteristics.isNotEmpty) {
      parts.add('(${characteristics.join(', ')})');
    }

    return parts.join(' ');
  }

  String _dialectLabel(String dialect, AppLocalizations labels) {
    switch (dialect) {
      case 'mandarin':
        return labels.dialectMandarin;
      case 'cantonese':
        return labels.dialectCantonese;
      default:
        return labels.dialectStandard;
    }
  }
}
