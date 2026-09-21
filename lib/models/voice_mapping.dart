/// Voice mapping entry: system voice ID to user-friendly display name.
///
/// Only EVIDENCE-BASED data lives here. Gender was measured on the device:
/// every voice was rendered with `synthesizeToFile` and the rendering's
/// fundamental frequency was tracked (male voices ~110-150 Hz, female
/// ~200-260 Hz). That was cross-checked against the gender field of the
/// engine's own voice manifest (`assets/voices-list-dsig.pb` inside
/// GoogleTTS.apk, version 20241125.02, emulator-5554, Sep 2026), and the two
/// agree on every voice below. `en-us-x-tpc` is the one exception: its F0 sits
/// in the overlap band, its spectral centroid sits in the male range and the
/// manifest calls it person 1 (female) — conflicting evidence, so no gender is
/// claimed for it.
///
/// Deliberately NOT here:
///  - age (young/old): the engine exposes none, and its own "Install voice
///    data" screen lists voices as "Voice I..IV", so any value would be a guess;
///  - dialect: the region is already in the display name ("普通话", "US"), so a
///    dialect label only repeats it;
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

/// Static mapping table for the voices this app can actually show: one row per
/// voice name the Google TTS engine reports for the `en` and `zh` lists
/// (51 English + 16 Chinese on emulator-5554). A voice the engine does not
/// report falls back to its raw system name (spec FR-004).
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
