/// The remembered motion choice (spec 023 US3): quickstart scenario 7 — the two
/// values, the default every failure reads as, the one write per confirmed
/// prompt, and the namespace it cannot collide with.
///
/// The contract is `specs/023-video-background-motion/contracts/video-motion-record.md`;
/// this file is the code half of it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_motion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the choice (FR-009)', () {
    test('an absent key reads as off, and nothing is written for it', () async {
      expect(await VideoMotionStore().load(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(VideoMotionStore.key), isFalse,
          reason: 'a read never writes');
    });

    test('on round-trips through one string', () async {
      await VideoMotionStore().save(true);
      expect(await VideoMotionStore().load(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoMotionStore.key), VideoMotionStore.on);
    });

    test('off round-trips, and overwrites on without a second key', () async {
      await VideoMotionStore().save(true);
      await VideoMotionStore().save(false);
      expect(await VideoMotionStore().load(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoMotionStore.key), VideoMotionStore.off);
      expect(
        prefs.getKeys().where((k) => k.contains('video_motion')).toList(),
        ['video_motion'],
      );
    });
  });

  group('every failure reads as off, and none of them repairs the record', () {
    test('a value outside the domain reads off and is left as it is', () async {
      SharedPreferences.setMockInitialValues({VideoMotionStore.key: 'yes'});
      expect(await VideoMotionStore().load(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoMotionStore.key), 'yes',
          reason: 'the record is rewritten by a confirm, never by a read');
    });

    test('a store that throws on the read reads off, and does not throw',
        () async {
      // A value of the wrong type is what a corrupt or foreign record looks
      // like: `getString` raises, the store's own catch answers off.
      SharedPreferences.setMockInitialValues({VideoMotionStore.key: 42});
      expect(await VideoMotionStore().load(), isFalse);
    });

    test('an empty string is not on, and is not on by accident', () async {
      SharedPreferences.setMockInitialValues({VideoMotionStore.key: ''});
      expect(await VideoMotionStore().load(), isFalse);
    });
  });

  group('the namespace', () {
    test('saving the motion leaves 012\'s aspect record untouched', () async {
      SharedPreferences.setMockInitialValues(
          {VideoAspectStore.key: 'vertical'});
      await VideoMotionStore().save(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoAspectStore.key), 'vertical');
      expect(VideoAspect.decode(prefs.getString(VideoAspectStore.key)),
          VideoAspect.vertical);
    });

    test('the key is its own, and no other store\'s', () {
      expect(VideoMotionStore.key, 'video_motion');
      expect(VideoMotionStore.key, isNot(VideoAspectStore.key));
    });
  });
}
