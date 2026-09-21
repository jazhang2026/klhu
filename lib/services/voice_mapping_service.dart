import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/voice_mapping.dart';
import 'package:klhu/reader_service.dart';

/// Service for looking up user-friendly voice names.
///
/// Uses [VoiceMappingTable] to resolve system voice IDs to display names
/// in the current locale. Falls back to the system voice name when no
/// mapping is found.
class VoiceMappingService {
  /// Get the display name for a voice in the current locale.
  ///
  /// Returns a formatted string like "Google US English Female (Young, Standard)"
  /// in English or "谷歌美式英语女声 (年轻, 标准音)" in Chinese.
  String displayName(VoiceEntry voice, AppLocalizations l10n) {
    final mapping = VoiceMappingTable.lookup(voice.name);
    if (mapping == null) {
      return voice.name;
    }

    final parts = <String>[];

    // Add name
    final name = l10n.localeName == 'zh' ? mapping.chineseName : mapping.englishName;
    parts.add(name);

    // Add characteristics
    final characteristics = <String>[];
    if (mapping.gender != null) {
      final genderLabel = mapping.gender == 'male' ? l10n.genderMale : l10n.genderFemale;
      characteristics.add(genderLabel);
    }
    if (mapping.age != null) {
      final ageLabel = mapping.age == 'old' ? l10n.ageOld : l10n.ageYoung;
      characteristics.add(ageLabel);
    }
    if (mapping.dialect != null) {
      final dialectLabel = _dialectLabel(mapping.dialect!, l10n);
      characteristics.add(dialectLabel);
    }

    if (characteristics.isNotEmpty) {
      parts.add('(${characteristics.join(', ')})');
    }

    return parts.join(' ');
  }

  String _dialectLabel(String dialect, AppLocalizations l10n) {
    switch (dialect) {
      case 'standard':
        return l10n.dialectStandard;
      case 'mandarin':
        return l10n.dialectMandarin;
      case 'cantonese':
        return l10n.dialectCantonese;
      default:
        return l10n.dialectStandard;
    }
  }
}
