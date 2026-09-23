/// Voice mapping entry: system voice ID to user-friendly display name.
///
/// Only EVIDENCE-BASED data lives here. Gender was measured on the device:
/// every voice was rendered with `synthesizeToFile` and the rendering's
/// fundamental frequency was tracked (male voices ~110-150 Hz, female
/// ~200-260 Hz). That was cross-checked against the gender field of the
/// engine's own voice manifest (`assets/voices-list-dsig.pb` inside
/// GoogleTTS.apk, emulator-5554, Sep 2026), and the two agree on every voice
/// below where both cues exist. `en-us-x-tpc` is the one exception: its F0 sits
/// in the overlap band, its spectral centroid sits in the male range and the
/// manifest calls it person 1 (female) — conflicting evidence, so no gender is
/// claimed for it.
///
/// The es-* and yue-HK rows were measured the same way on 2026-09-22 (see
/// `specs/007-reader-name-spanish-cantonese/voice-gender-evidence.md`); a voice
/// the manifest does not list takes its gender from F0 alone.
///
/// Deliberately NOT here:
///  - age (young/old): the engine exposes none, and its own "Install voice
///    data" screen lists voices as "Voice I..IV", so any value would be a guess;
///  - a dialect characteristic: a Cantonese voice is NAMED by its dialect
///    (`广东话 JAR`) because that is the region label the reader asked for, so a
///    dialect field would only repeat the name (spec 007 FR-010); for the other
///    regions the region word already does the same job;
///  - "(Local)"/"(Network)" suffixes: the measured local and network variants
///    of a code are the same voice — the suffix told the reader nothing;
///  - the words "English"/"Standard" in the English names: the picker already
///    says which language list is open.
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

/// Static mapping table for the voices this app can show: one row per voice
/// name the Google TTS engine reports for the `en`, `zh`, `es` and Cantonese
/// (`yue-HK`) lists. A voice the engine does not report falls back to its raw
/// system name (spec 002 FR-004).
class VoiceMappingTable {
  static const List<VoiceMapping> _entries = [
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccc-local',
      englishName: 'Mandarin CCC',
      chineseName: '普通话 CCC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccc-network',
      englishName: 'Mandarin CCC',
      chineseName: '普通话 CCC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccd-local',
      englishName: 'Mandarin CCD',
      chineseName: '普通话 CCD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ccd-network',
      englishName: 'Mandarin CCD',
      chineseName: '普通话 CCD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-cce-local',
      englishName: 'Mandarin CCE',
      chineseName: '普通话 CCE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-cce-network',
      englishName: 'Mandarin CCE',
      chineseName: '普通话 CCE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ssa-local',
      englishName: 'Mandarin SSA',
      chineseName: '普通话 SSA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-cn-x-ssa-network',
      englishName: 'Mandarin SSA',
      chineseName: '普通话 SSA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctc-local',
      englishName: 'Taiwanese Mandarin CTC',
      chineseName: '台湾国语 CTC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctc-network',
      englishName: 'Taiwanese Mandarin CTC',
      chineseName: '台湾国语 CTC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctd-local',
      englishName: 'Taiwanese Mandarin CTD',
      chineseName: '台湾国语 CTD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-ctd-network',
      englishName: 'Taiwanese Mandarin CTD',
      chineseName: '台湾国语 CTD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-cte-local',
      englishName: 'Taiwanese Mandarin CTE',
      chineseName: '台湾国语 CTE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'cmn-tw-x-cte-network',
      englishName: 'Taiwanese Mandarin CTE',
      chineseName: '台湾国语 CTE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-AU-language',
      englishName: 'Australian Default',
      chineseName: '澳大利亚默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-GB-language',
      englishName: 'UK Default',
      chineseName: '英式默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-IN-language',
      englishName: 'Indian Default',
      chineseName: '印度默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-NG-language',
      englishName: 'Nigerian Default',
      chineseName: '尼日利亚默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-US-language',
      englishName: 'US Default',
      chineseName: '美式默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aua-local',
      englishName: 'Australian AUA',
      chineseName: '澳大利亚 AUA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aua-network',
      englishName: 'Australian AUA',
      chineseName: '澳大利亚 AUA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aub-local',
      englishName: 'Australian AUB',
      chineseName: '澳大利亚 AUB',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aub-network',
      englishName: 'Australian AUB',
      chineseName: '澳大利亚 AUB',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-auc-local',
      englishName: 'Australian AUC',
      chineseName: '澳大利亚 AUC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-auc-network',
      englishName: 'Australian AUC',
      chineseName: '澳大利亚 AUC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aud-local',
      englishName: 'Australian AUD',
      chineseName: '澳大利亚 AUD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-au-x-aud-network',
      englishName: 'Australian AUD',
      chineseName: '澳大利亚 AUD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gba-local',
      englishName: 'UK GBA',
      chineseName: '英式 GBA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gba-network',
      englishName: 'UK GBA',
      chineseName: '英式 GBA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbb-local',
      englishName: 'UK GBB',
      chineseName: '英式 GBB',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbb-network',
      englishName: 'UK GBB',
      chineseName: '英式 GBB',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbc-local',
      englishName: 'UK GBC',
      chineseName: '英式 GBC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbc-network',
      englishName: 'UK GBC',
      chineseName: '英式 GBC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbd-local',
      englishName: 'UK GBD',
      chineseName: '英式 GBD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbd-network',
      englishName: 'UK GBD',
      chineseName: '英式 GBD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbg-local',
      englishName: 'UK GBG',
      chineseName: '英式 GBG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-gbg-network',
      englishName: 'UK GBG',
      chineseName: '英式 GBG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-rjs-local',
      englishName: 'UK RJS',
      chineseName: '英式 RJS',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-gb-x-rjs-network',
      englishName: 'UK RJS',
      chineseName: '英式 RJS',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-ena-local',
      englishName: 'Indian ENA',
      chineseName: '印度 ENA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-ena-network',
      englishName: 'Indian ENA',
      chineseName: '印度 ENA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-enc-local',
      englishName: 'Indian ENC',
      chineseName: '印度 ENC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-enc-network',
      englishName: 'Indian ENC',
      chineseName: '印度 ENC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-end-local',
      englishName: 'Indian END',
      chineseName: '印度 END',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-end-network',
      englishName: 'Indian END',
      chineseName: '印度 END',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-ene-local',
      englishName: 'Indian ENE',
      chineseName: '印度 ENE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-in-x-ene-network',
      englishName: 'Indian ENE',
      chineseName: '印度 ENE',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-ng-x-tfn-local',
      englishName: 'Nigerian TFN',
      chineseName: '尼日利亚 TFN',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-ng-x-tfn-network',
      englishName: 'Nigerian TFN',
      chineseName: '尼日利亚 TFN',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iob-local',
      englishName: 'US IOB',
      chineseName: '美式 IOB',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iob-network',
      englishName: 'US IOB',
      chineseName: '美式 IOB',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iog-local',
      englishName: 'US IOG',
      chineseName: '美式 IOG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iog-network',
      englishName: 'US IOG',
      chineseName: '美式 IOG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iol-local',
      englishName: 'US IOL',
      chineseName: '美式 IOL',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iol-network',
      englishName: 'US IOL',
      chineseName: '美式 IOL',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iom-local',
      englishName: 'US IOM',
      chineseName: '美式 IOM',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-iom-network',
      englishName: 'US IOM',
      chineseName: '美式 IOM',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-sfg-local',
      englishName: 'US SFG',
      chineseName: '美式 SFG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-sfg-network',
      englishName: 'US SFG',
      chineseName: '美式 SFG',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpc-local',
      englishName: 'US TPC',
      chineseName: '美式 TPC',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpc-network',
      englishName: 'US TPC',
      chineseName: '美式 TPC',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpd-local',
      englishName: 'US TPD',
      chineseName: '美式 TPD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpd-network',
      englishName: 'US TPD',
      chineseName: '美式 TPD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpf-local',
      englishName: 'US TPF',
      chineseName: '美式 TPF',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'en-us-x-tpf-network',
      englishName: 'US TPF',
      chineseName: '美式 TPF',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-ES-language',
      englishName: 'Spain Default',
      chineseName: '西班牙默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-US-language',
      englishName: 'US Default',
      chineseName: '美式默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eea-local',
      englishName: 'Spain EEA',
      chineseName: '西班牙 EEA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eea-network',
      englishName: 'Spain EEA',
      chineseName: '西班牙 EEA',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eec-local',
      englishName: 'Spain EEC',
      chineseName: '西班牙 EEC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eec-network',
      englishName: 'Spain EEC',
      chineseName: '西班牙 EEC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eed-local',
      englishName: 'Spain EED',
      chineseName: '西班牙 EED',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eed-network',
      englishName: 'Spain EED',
      chineseName: '西班牙 EED',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eee-local',
      englishName: 'Spain EEE',
      chineseName: '西班牙 EEE',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-es-x-eef-local',
      englishName: 'Spain EEF',
      chineseName: '西班牙 EEF',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esc-local',
      englishName: 'US ESC',
      chineseName: '美式 ESC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esc-network',
      englishName: 'US ESC',
      chineseName: '美式 ESC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esd-local',
      englishName: 'US ESD',
      chineseName: '美式 ESD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esd-network',
      englishName: 'US ESD',
      chineseName: '美式 ESD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esf-local',
      englishName: 'US ESF',
      chineseName: '美式 ESF',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-esf-network',
      englishName: 'US ESF',
      chineseName: '美式 ESF',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-sfb-local',
      englishName: 'US SFB',
      chineseName: '美式 SFB',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'es-us-x-sfb-network',
      englishName: 'US SFB',
      chineseName: '美式 SFB',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-HK-language',
      englishName: '广东话 Default',
      chineseName: '广东话默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-jar-local',
      englishName: '广东话 JAR',
      chineseName: '广东话 JAR',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-jar-network',
      englishName: '广东话 JAR',
      chineseName: '广东话 JAR',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yuc-local',
      englishName: '广东话 YUC',
      chineseName: '广东话 YUC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yuc-network',
      englishName: '广东话 YUC',
      chineseName: '广东话 YUC',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yud-local',
      englishName: '广东话 YUD',
      chineseName: '广东话 YUD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yud-network',
      englishName: '广东话 YUD',
      chineseName: '广东话 YUD',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yue-local',
      englishName: '广东话 YUE',
      chineseName: '广东话 YUE',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yue-network',
      englishName: '广东话 YUE',
      chineseName: '广东话 YUE',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yuf-local',
      englishName: '广东话 YUF',
      chineseName: '广东话 YUF',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'yue-hk-x-yuf-network',
      englishName: '广东话 YUF',
      chineseName: '广东话 YUF',
      gender: 'male',
    ),
    VoiceMapping(
      systemVoiceId: 'zh-CN-language',
      englishName: 'Mandarin Default',
      chineseName: '普通话默认语音',
      gender: 'female',
    ),
    VoiceMapping(
      systemVoiceId: 'zh-TW-language',
      englishName: 'Taiwanese Mandarin Default',
      chineseName: '台湾国语默认语音',
      gender: 'female',
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
