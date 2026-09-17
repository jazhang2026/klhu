import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VoiceStore', () {
    test('save + load round-trips per language independently', () async {
      SharedPreferences.setMockInitialValues({});
      final store = VoiceStore();
      await store.saveVoice(
        const VoiceChoice(language: 'en', name: 'en-voice', locale: 'en-US'),
      );
      await store.saveVoice(
        const VoiceChoice(
          language: 'zh-Hans',
          name: 'zh-voice',
          locale: 'zh-Hans-CN',
        ),
      );

      final en = await store.loadVoice('en');
      final zh = await store.loadVoice('zh-Hans');
      expect(en?.name, 'en-voice');
      expect(en?.locale, 'en-US');
      expect(zh?.name, 'zh-voice');
      expect(zh?.locale, 'zh-Hans-CN');
    });

    test('load with nothing saved returns null (≡ OS default)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await VoiceStore().loadVoice('en'), isNull);
    });

    test('unparseable stored value returns null (≡ OS default)', () async {
      SharedPreferences.setMockInitialValues({'voice_en': 'garbage-no-sep'});
      expect(await VoiceStore().loadVoice('en'), isNull);
    });

    test('overwriting one language leaves the other intact', () async {
      SharedPreferences.setMockInitialValues({});
      final store = VoiceStore();
      await store.saveVoice(
        const VoiceChoice(language: 'en', name: 'a', locale: 'en-US'),
      );
      await store.saveVoice(
        const VoiceChoice(language: 'en', name: 'b', locale: 'en-GB'),
      );
      expect((await store.loadVoice('en'))?.name, 'b');
      expect(await store.loadVoice('zh-Hans'), isNull);
    });
  });
}
