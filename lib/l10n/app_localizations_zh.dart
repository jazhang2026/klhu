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
  String get continueReadButton => '继续朗读';

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
  String get nothingToReadMessage => '从这里开始没有可朗读的内容';

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

  @override
  String get contentsButton => '内容';

  @override
  String get contentsTitle => '内容';

  @override
  String currentContentLabel(Object name) {
    return '正在阅读：$name';
  }

  @override
  String get saveButton => '保存';

  @override
  String get undoButton => '撤销';

  @override
  String get deleteButton => '删除';

  @override
  String get cancelButton => '取消';

  @override
  String get discardButton => '放弃';

  @override
  String get deleteConfirmTitle => '删除此内容？';

  @override
  String get deleteConfirmMessage => '此操作无法撤销。';

  @override
  String get deletePresetConfirmMessage => '此操作无法撤销。删除的示例只有在重新安装应用后才会回来。';

  @override
  String get savedMessage => '已保存';

  @override
  String get nothingToSaveMessage => '没有可保存的内容';

  @override
  String get undoExhaustedMessage => '没有更多可撤销的操作';

  @override
  String contentTooLargeMessage(Object limit) {
    return '内容过长，无法保存（上限 $limit 个字符）';
  }

  @override
  String get storageErrorMessage => '无法保存。请检查存储空间后重试。';

  @override
  String get unsavedChangesTitle => '有未保存的更改';

  @override
  String get unsavedChangesMessage => '你有尚未保存的更改。';

  @override
  String get noContentsMessage => '还没有内容。输入文字后点击保存。';

  @override
  String get damagedContentMessage => '此内容已损坏';

  @override
  String get libraryRepairedMessage => '内容库已修复：损坏的索引已被替换，内置示例已恢复。';
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
  String get continueReadButton => '继续朗读';

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
  String get nothingToReadMessage => '从这里开始没有可朗读的内容';

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

  @override
  String get contentsButton => '内容';

  @override
  String get contentsTitle => '内容';

  @override
  String currentContentLabel(Object name) {
    return '正在阅读：$name';
  }

  @override
  String get saveButton => '保存';

  @override
  String get undoButton => '撤销';

  @override
  String get deleteButton => '删除';

  @override
  String get cancelButton => '取消';

  @override
  String get discardButton => '放弃';

  @override
  String get deleteConfirmTitle => '删除此内容？';

  @override
  String get deleteConfirmMessage => '此操作无法撤销。';

  @override
  String get deletePresetConfirmMessage => '此操作无法撤销。删除的示例只有在重新安装应用后才会回来。';

  @override
  String get savedMessage => '已保存';

  @override
  String get nothingToSaveMessage => '没有可保存的内容';

  @override
  String get undoExhaustedMessage => '没有更多可撤销的操作';

  @override
  String contentTooLargeMessage(Object limit) {
    return '内容过长，无法保存（上限 $limit 个字符）';
  }

  @override
  String get storageErrorMessage => '无法保存。请检查存储空间后重试。';

  @override
  String get unsavedChangesTitle => '有未保存的更改';

  @override
  String get unsavedChangesMessage => '你有尚未保存的更改。';

  @override
  String get noContentsMessage => '还没有内容。输入文字后点击保存。';

  @override
  String get damagedContentMessage => '此内容已损坏';

  @override
  String get libraryRepairedMessage => '内容库已修复：损坏的索引已被替换，内置示例已恢复。';
}
