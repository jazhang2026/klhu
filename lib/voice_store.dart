import 'package:shared_preferences/shared_preferences.dart';

/// One persisted voice pick for a reading language.
class VoiceChoice {
  final String language; // 'en' | 'zh-Hans' | 'es'
  final String name;
  final String locale;

  const VoiceChoice({
    required this.language,
    required this.name,
    required this.locale,
  });
}

/// Persists one [VoiceChoice] per language in shared_preferences.
/// Missing or unparseable value ≡ no choice → caller uses the OS default.
class VoiceStore {
  static const _separator = '||';

  static String keyFor(String language) => switch (language) {
        'zh-Hans' => 'voice_zh_Hans',
        'es' => 'voice_es',
        _ => 'voice_en',
      };

  Future<void> saveVoice(VoiceChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(choice.language),
      '${choice.name}$_separator${choice.locale}',
    );
  }

  Future<VoiceChoice?> loadVoice(String language) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(language));
    if (raw == null) return null;
    final parts = raw.split(_separator);
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return null;
    }
    return VoiceChoice(language: language, name: parts[0], locale: parts[1]);
  }
}
