/// Contract tests for the persisted Continue Read start position (spec 010,
/// FR-008/FR-009). The on-disk record is specified in
/// `specs/010-continue-read/contracts/read-position-format.md`: one
/// `shared_preferences` key per content, value `<offset>||<charCount>`,
/// validated on read, malformed ≡ absent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/models/language_preference.dart';
import 'package:klhu/read_position_store.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const contentKey = 'preset_en_sample';
  const otherKey = 'c_1758609612000_1a2b';
  const charCount = 334;

  ReadingPosition at(int offset) =>
      ReadingPosition(contentKey: contentKey, offset: offset, charCount: charCount);

  test('save + load round-trips the position for its text', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(214));

    final loaded = await store.load(contentKey, charCount);
    expect(loaded, isNotNull);
    expect(loaded!.offset, 214);
    expect(loaded.charCount, charCount);
    expect(loaded.contentKey, contentKey);
  });

  test('the stored value is exactly <offset>||<charCount>', () async {
    SharedPreferences.setMockInitialValues({});
    await ReadPositionStore().save(contentKey, at(214));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadPositionStore.keyFor(contentKey)), '214||334');
  });

  test('a length mismatch is discarded and leaves the record untouched',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(214));

    expect(await store.load(contentKey, charCount + 1), isNull);
    expect(await store.load(contentKey, charCount - 1), isNull);
    // Not repaired, not rewritten: the next gesture overwrites it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadPositionStore.keyFor(contentKey)), '214||334');
  });

  test('an offset at or past the end of the text is discarded', () async {
    SharedPreferences.setMockInitialValues({
      'read_position_$contentKey': '$charCount||$charCount',
    });
    expect(await ReadPositionStore().load(contentKey, charCount), isNull);
  });

  test('every malformed value reads as absent and never throws', () async {
    for (final raw in ['214', '214||', '||334', 'a||b', '-1||334',
      '214||334||5', '', ' 214||334', '214||334 ']) {
      SharedPreferences.setMockInitialValues({
        'read_position_$contentKey': raw,
      });
      expect(
        await ReadPositionStore().load(contentKey, charCount),
        isNull,
        reason: 'value "$raw" must read as no position',
      );
    }
  });

  test('nothing saved reads as absent', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ReadPositionStore().load(contentKey, charCount), isNull);
  });

  test('clear removes the record; load is then absent', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(96));
    await store.clear(contentKey);

    expect(await store.load(contentKey, charCount), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ReadPositionStore.keyFor(contentKey)), isFalse);
  });

  test('the second of two saves wins', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(10));
    await store.save(contentKey, at(200));

    expect((await store.load(contentKey, charCount))?.offset, 200);
  });

  test('a position for one content is never read for another', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(214));

    expect(await store.load(otherKey, charCount), isNull);
  });

  test('clearing one content leaves another content\'s record alone',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ReadPositionStore();
    await store.save(contentKey, at(214));
    await store.save(otherKey, at(96));

    await store.clear(contentKey);
    expect(await store.load(contentKey, charCount), isNull);
    expect((await store.load(otherKey, charCount))?.offset, 96);
  });

  test('the namespace cannot collide with the voice or language keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'voice_en': 'en-a||en-US',
      'voice_zh_Hans': 'zh-a||zh-Hans-CN',
      'voice_es': 'es-a||es-US',
      'interface_language': 'es',
    });
    final store = ReadPositionStore();
    // 'en' is a plausible short pre-set id: it must not address voice_en.
    await store.save('en', at(214));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('voice_en'), 'en-a||en-US');
    expect(prefs.getString('voice_zh_Hans'), 'zh-a||zh-Hans-CN');
    expect(prefs.getString('voice_es'), 'es-a||es-US');
    expect(prefs.getString('interface_language'), 'es');
    expect((await VoiceStore().loadVoice('en'))?.name, 'en-a');
    expect(LanguagePreference(prefs).loadLanguage(), 'es');
  });
}
