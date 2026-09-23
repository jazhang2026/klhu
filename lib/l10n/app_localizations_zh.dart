// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '卡啦虎朗读';

  @override
  String get englishNative => 'English';

  @override
  String get chineseNative => '中文';

  @override
  String get spanishNative => 'Español';

  @override
  String get readButton => '朗读';

  @override
  String get readPageButton => '朗读全文';

  @override
  String get stopButton => '停止';

  @override
  String get editButton => '编辑';

  @override
  String get doneButton => '完成';

  @override
  String get voiceButton => '语音';

  @override
  String get languageDropdown => '语言';

  @override
  String get hintText => '点击句子开始朗读';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get ageYoung => '年轻';

  @override
  String get ageOld => '年长';

  @override
  String get dialectStandard => '标准音';

  @override
  String get dialectMandarin => '普通话';

  @override
  String get dialectCantonese => '广东话';

  @override
  String get pauseButton => '暂停';

  @override
  String get resumeButton => '继续';

  @override
  String get sampleEn => '英文示例';

  @override
  String get sampleZh => '中文示例';

  @override
  String get sampleEs => '西班牙语示例';

  @override
  String voicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个语音',
    );
    return '$_temp0';
  }

  @override
  String get noVoices => '此语言没有已安装的语音。';

  @override
  String get voicesLoadFailed => '无法加载语音列表。';

  @override
  String get retryButton => '重试';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => '卡啦虎朗读';

  @override
  String get englishNative => 'English';

  @override
  String get chineseNative => '中文';

  @override
  String get spanishNative => 'Español';

  @override
  String get readButton => '朗读';

  @override
  String get readPageButton => '朗读全文';

  @override
  String get stopButton => '停止';

  @override
  String get editButton => '编辑';

  @override
  String get doneButton => '完成';

  @override
  String get voiceButton => '语音';

  @override
  String get languageDropdown => '语言';

  @override
  String get hintText => '点击句子开始朗读';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get ageYoung => '年轻';

  @override
  String get ageOld => '年长';

  @override
  String get dialectStandard => '标准音';

  @override
  String get dialectMandarin => '普通话';

  @override
  String get dialectCantonese => '广东话';

  @override
  String get pauseButton => '暂停';

  @override
  String get resumeButton => '继续';

  @override
  String get sampleEn => '英文示例';

  @override
  String get sampleZh => '中文示例';

  @override
  String get sampleEs => '西班牙语示例';

  @override
  String voicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个语音',
    );
    return '$_temp0';
  }

  @override
  String get noVoices => '此语言没有已安装的语音。';

  @override
  String get voicesLoadFailed => '无法加载语音列表。';

  @override
  String get retryButton => '重试';
}
