/// The remembered video format (spec 012, quickstart scenario 18): the two
/// choices, the frame each one renders at, the default an absent or junk record
/// reads as, and the namespace it cannot collide with.
///
/// This file defines the API it tests: `lib/video_aspect.dart` does not exist
/// yet (T005 is written before T009 implements it).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/read_position_store.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the two choices (FR-007)', () {
    test('16:9 landscape 1080p is the default', () {
      expect(VideoAspect.defaults, VideoAspect.landscape);
      expect(VideoAspect.landscape.width, 1920);
      expect(VideoAspect.landscape.height, 1080);
      expect(VideoAspect.landscape.fps, 30);
      expect(VideoAspect.landscape.isVertical, isFalse);
    });

    test('9:16 vertical is the Shorts shape', () {
      expect(VideoAspect.vertical.width, 1080);
      expect(VideoAspect.vertical.height, 1920);
      expect(VideoAspect.vertical.isVertical, isTrue);
    });

    test('exactly the two offered options are offered', () {
      expect(VideoAspect.all.map((a) => a.name).toList(),
          ['landscape', 'vertical']);
    });

    test('the names are stable, because the record stores them', () {
      expect(VideoAspect.byName('landscape'), VideoAspect.landscape);
      expect(VideoAspect.byName('vertical'), VideoAspect.vertical);
      expect(VideoAspect.byName('square'), isNull);
    });
  });

  group('the record (contract video-aspect-format.md)', () {
    test('an absent record reads as the default', () async {
      expect(await VideoAspectStore().load(), VideoAspect.defaults);
    });

    test('a confirmed choice round-trips', () async {
      await VideoAspectStore().save(VideoAspect.vertical);
      expect((await VideoAspectStore().load()), VideoAspect.vertical);
      expect(await VideoAspectStore().load(), isNot(VideoAspect.landscape));
    });

    test('the record carries the name, not the frame', () async {
      await VideoAspectStore().save(VideoAspect.vertical);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoAspectStore.key), 'vertical');
    });

    test('a junk value reads as the default and is left alone', () async {
      SharedPreferences.setMockInitialValues({VideoAspectStore.key: 'portrait'});
      expect(await VideoAspectStore().load(), VideoAspect.defaults);
      // Not repaired and not rewritten: the next confirm overwrites it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoAspectStore.key), 'portrait');
    });

    test('an empty value reads as the default', () async {
      SharedPreferences.setMockInitialValues({VideoAspectStore.key: ''});
      expect(await VideoAspectStore().load(), VideoAspect.defaults);
    });

    test('the second save wins and there is only ever one record', () async {
      final store = VideoAspectStore();
      await store.save(VideoAspect.vertical);
      await store.save(VideoAspect.landscape);
      expect(await store.load(), VideoAspect.landscape);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(VideoAspectStore.key), 'landscape');
    });

    test('the namespace collides with no other record the app keeps', () async {
      final others = {
        AppearanceStore.key,
        VoiceStore.keyFor('en'),
        VoiceStore.keyFor('es'),
        VoiceStore.keyFor('zh-Hans'),
        ReadPositionStore.keyFor('any-content'),
        'interface_language',
      };
      expect(others, isNot(contains(VideoAspectStore.key)));
      expect(VideoAspectStore.key, startsWith('video_'));
    });
  });
}
