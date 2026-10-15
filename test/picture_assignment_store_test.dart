/// The reader's assignment as a stored setting (spec 020, quickstart row 15):
/// one key per content, keyed by the content's own id, read **tolerantly** —
/// a malformed entry never costs the reader another content's assignment.
///
/// The store is the real one over mocked `shared_preferences`, the shape 015's
/// `role_store_test.dart` established: the cases that matter are the tolerant
/// reads, because a content whose assignment cannot be read must still render
/// as today.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/picture_assignment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two contents, as the app's own keys look: a shipped pre-set and a library
/// entry.
const _preset = 'preset_en_sample';
const _library = 'c_1700000000000_ab12';

PictureRun _run(String name, List<(int, int)> spans) =>
    PictureRun(name: name, spans: spans);

void main() {
  Future<String?> rawValue() async =>
      (await SharedPreferences.getInstance())
          .getString(PictureAssignmentStore.key);

  Future<void> storeRaw(Object? value) async {
    SharedPreferences.setMockInitialValues({
      PictureAssignmentStore.key: value is String ? value : jsonEncode(value),
    });
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('one key per content', () {
    test('each content answers its own runs, and nothing of another\'s',
        () async {
      final store = PictureAssignmentStore();
      await store.save(_preset, runs: [_run('a.png', [(0, 4), (5, 9)])]);
      await store.save(_library, runs: [_run('b.png', [(0, 3)])]);

      final preset = await store.load(_preset);
      final library = await store.load(_library);
      expect(preset.map((r) => r.name), ['a.png']);
      expect(preset.single.spans, [(0, 4), (5, 9)],
          reason: 'the spans are the sentences, in order');
      expect(library.map((r) => r.name), ['b.png']);
      // One key for the whole app, two entries inside it (data-model.md §2).
      expect(jsonDecode((await rawValue())!).keys,
          containsAll(<String>[_preset, _library]));
    });

    test('a content nothing was assigned on carries no entry', () async {
      expect(await PictureAssignmentStore().load(_preset), isEmpty);
      expect(await rawValue(), isNull);
    });

    test('clearing the runs leaves no entry behind', () async {
      final store = PictureAssignmentStore();
      await store.save(_preset, runs: [_run('a.png', [(0, 4)])]);
      expect(await rawValue(), isNotNull);

      await store.save(_preset, runs: const []);
      expect(await store.load(_preset), isEmpty);
      expect(await rawValue(), isNull,
          reason: 'the entry is gone, not emptied');
    });

    test('clearing one content leaves the other alone', () async {
      final store = PictureAssignmentStore();
      await store.save(_preset, runs: [_run('a.png', [(0, 4)])]);
      await store.save(_library, runs: [_run('b.png', [(0, 3)])]);

      await store.clearFor(_preset);
      expect(await store.load(_preset), isEmpty);
      expect((await store.load(_library)).single.name, 'b.png');
    });
  });

  group('a tolerant read', () {
    test('a malformed entry is ignored while its siblings stand', () async {
      await storeRaw({
        _preset: {'runs': 'not a list'},
        _library: {
          'runs': [
            {
              'name': 'b.png',
              'spans': [
                [0, 3],
              ],
            },
          ],
        },
      });

      final store = PictureAssignmentStore();
      expect(await store.load(_preset), isEmpty);
      expect((await store.load(_library)).single.name, 'b.png',
          reason: 'one bad byte is one content\'s, not two');
    });

    test('a run with no name, or a span that is not a pair, is dropped',
        () async {
      await storeRaw({
        _preset: {
          'runs': [
            {
              'spans': [
                [0, 3],
              ],
            },
            {'name': '', 'spans': []},
            {
              'name': 'a.png',
              'spans': [
                [0, 3],
                'nope',
                [7],
              ],
            },
          ],
        },
      });

      final runs = await PictureAssignmentStore().load(_preset);
      expect(runs.map((r) => r.name), ['a.png']);
      expect(runs.single.spans, [(0, 3)],
          reason: 'the well-formed span is kept and the others are not');
    });

    test('a store that is not JSON, or not an object, reads as nothing',
        () async {
      final store = PictureAssignmentStore();
      await storeRaw('{not json');
      expect(await store.load(_preset), isEmpty);

      await storeRaw([1, 2, 3]);
      expect(await store.load(_preset), isEmpty);

      await storeRaw({_preset: 'not an object'});
      expect(await store.load(_preset), isEmpty);
    });

    test('a read never rewrites what it could not read', () async {
      await storeRaw({_preset: {'runs': 'not a list'}});
      final before = await rawValue();

      expect(await PictureAssignmentStore().load(_preset), isEmpty);
      expect(await rawValue(), before,
          reason: 'no repair, no rewrite: the reader\'s bytes stay theirs');
    });
  });
}
