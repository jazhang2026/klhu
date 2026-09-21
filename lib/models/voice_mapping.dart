/// Voice mapping entry: system voice ID to user-friendly display name.
///
/// Maps platform voice IDs (e.g., from flutter_tts `getVoices`) to
/// human-readable names with characteristics (gender, age, dialect)
/// in both English and Chinese.
class VoiceMapping {
  /// The system voice identifier returned by flutter_tts.
  final String systemVoiceId;

  /// User-friendly name in English.
  final String englishName;

  /// User-friendly name in Chinese.
  final String chineseName;

  /// Gender characteristic: "male", "female", or null.
  final String? gender;

  /// Age characteristic: "young", "old", or null.
  final String? age;

  /// Dialect characteristic: "standard", "mandarin", "cantonese", or null.
  final String? dialect;

  const VoiceMapping({
    required this.systemVoiceId,
    required this.englishName,
    required this.chineseName,
    this.gender,
    this.age,
    this.dialect,
  });
}

/// Static mapping table for common TTS voices.
///
/// Covers Google TTS, Samsung TTS, and iOS built-in voices for
/// en-US, en-GB, and zh-Hans-CN locales.
class VoiceMappingTable {
  static const List<VoiceMapping> _entries = [
    // Google TTS English voices (Android)
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:en-US-x-sfg',
      englishName: 'Google US English Female',
      chineseName: '谷歌美式英语女声',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:en-US-x-sfm',
      englishName: 'Google US English Male',
      chineseName: '谷歌美式英语男声',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:en-GB-x-sfg',
      englishName: 'Google British English Female',
      chineseName: '谷歌英式英语女声',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:en-GB-x-sfm',
      englishName: 'Google British English Male',
      chineseName: '谷歌英式英语男声',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    // iOS English voices
    VoiceMapping(
      systemVoiceId: 'en-US',
      englishName: 'Samantha (iOS)',
      chineseName: '萨曼莎（iOS）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-GB',
      englishName: 'Daniel (iOS)',
      chineseName: '丹尼尔（iOS）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    // Chinese (Simplified) voices
    VoiceMapping(
      systemVoiceId: 'zh-Hans-CN',
      englishName: 'Chinese Simplified Female',
      chineseName: '简体中文女声',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'zh-CN',
      englishName: 'Chinese Male',
      chineseName: '中文男声',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
    // Cantonese voice
    VoiceMapping(
      systemVoiceId: 'zh-HK',
      englishName: 'Cantonese Female',
      chineseName: '粤语女声',
      gender: 'female',
      age: 'young',
      dialect: 'cantonese',
    ),
    // Google Chinese voices
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:zh-CN-x-hf',
      englishName: 'Google Chinese Female',
      chineseName: '谷歌中文女声',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'com.google.android.tts:zh-CN-x-hm',
      englishName: 'Google Chinese Male',
      chineseName: '谷歌中文男声',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
    // Emulator-specific English voices
    VoiceMapping(
      systemVoiceId: 'en-ng-x-tfn-local',
      englishName: 'Nigerian English Female (Local)',
      chineseName: '尼日利亚英语女声（本地）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aub-local',
      englishName: 'Australian English Male (Local)',
      chineseName: '澳大利亚英语男声（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbc-local',
      englishName: 'British English Male (Local)',
      chineseName: '英式英语男声（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iob-network',
      englishName: 'US English Female (Network)',
      chineseName: '美式英语女声（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpd-network',
      englishName: 'US English Deep (Network)',
      chineseName: '美式英语深沉（网络）',
      gender: 'male',
      age: 'old',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpc-network',
      englishName: 'US English Cheerful (Network)',
      chineseName: '美式英语欢快（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-end-local',
      englishName: 'Indian English Male (Local)',
      chineseName: '印度英语男声（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-ena-network',
      englishName: 'Indian English Female (Network)',
      chineseName: '印度英语女声（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbb-local',
      englishName: 'British English Female (Local)',
      chineseName: '英式英语女声（本地）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-AU-language',
      englishName: 'Australian English',
      chineseName: '澳大利亚英语',
      gender: null,
      age: null,
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iol-network',
      englishName: 'US English Old (Network)',
      chineseName: '美式英语老年（网络）',
      gender: 'male',
      age: 'old',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iom-network',
      englishName: 'US English Medium (Network)',
      chineseName: '美式英语中音（网络）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gba-network',
      englishName: 'British English Female (Network)',
      chineseName: '英式英语女声（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iom-local',
      englishName: 'US English Medium (Local)',
      chineseName: '美式英语中音（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-auc-network',
      englishName: 'Australian English Female (Network)',
      chineseName: '澳大利亚英语女声（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'standard',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iop-network',
      englishName: 'US English Police (Network)',
      chineseName: '美式英语警笛（网络）',
      gender: 'male',
      age: 'young',
      dialect: 'standard',
    ),
    // Emulator-specific Chinese voices (from XML dump)
    VoiceMapping(
      systemVoiceId: 'zh-TW-language',
      englishName: 'Chinese Traditional',
      chineseName: '中文（繁体）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'zh-TW',
      englishName: 'Chinese Traditional TW',
      chineseName: '中文（台湾）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-cce-local',
      englishName: 'Chinese Mainland Female (Local)',
      chineseName: '国语女声（本地）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ssa-local',
      englishName: 'Chinese Mainland Male (Local)',
      chineseName: '国语男声（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctd-network',
      englishName: 'Chinese Taiwan Female (Network)',
      chineseName: '中文（台湾女声，网络）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccd-network',
      englishName: 'Chinese Mainland Female (Network)',
      chineseName: '国语女声（网络）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccc-local',
      englishName: 'Chinese Mainland Male (Local)',
      chineseName: '国语男声（本地）',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccc-network',
      englishName: 'Chinese Mainland Male (Network)',
      chineseName: '国语男声（网络）',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-cte-network',
      englishName: 'Chinese Taiwan Female (Network)',
      chineseName: '中文（台湾女声，网络）',
      gender: 'female',
      age: 'young',
      dialect: 'mandarin',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctc-network',
      englishName: 'Chinese Taiwan Male (Network)',
      chineseName: '中文（台湾男声，网络）',
      gender: 'male',
      age: 'young',
      dialect: 'mandarin',
    ),
  ];

  /// Look up mapping by system voice ID.
  /// Returns null if not found.
  static VoiceMapping? lookup(String systemVoiceId) {
    return _entries.where((m) => m.systemVoiceId == systemVoiceId).firstOrNull;
  }

  /// Returns all available mappings.
  static List<VoiceMapping> all() => _entries;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
