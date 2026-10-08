/// The kept-video record and the review's own decisions (spec 012 US3):
/// quickstart scenarios 19–24, 39's case for the app's existing delete, and the
/// record's own half of row 57 (the shipped one-object shape read as one video).
///
/// This file defines the record's seam. `VideoRecordStore` says what a
/// content's videos are — oldest first, forgetting and reporting the ones whose
/// files have gone — writes a keep by replacing the last entry or appending
/// after it, and removes one entry at a time (or one file at a time);
/// `VideoReview` is the undecided working copy with its three decisions.
/// Everything below them is the REAL file system (the test's own temp
/// directory), the REAL record over mocked `shared_preferences`, and a fake
/// platform file store that records what it was asked — so "the platform's keep
/// was called with the first file's uri" is a fact about this file, not about a
/// mock's shape.
///
/// The page-level halves of these rows (the warning a delete raises, the
/// content's offers, the review's screen) are asserted in
/// `reading_view_video_test.dart`, which owns the page's harness; both ticks
/// name which half lives where.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/content_list_screen.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/video_record.dart';
import 'package:klhu/video_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The platform's file channel, in memory: it records every call and answers
/// from what the library holds. "The library" here is a map of uri → name, so
/// a test can remove a file from outside the app and watch the record go stale.
class FakeFileStore implements VideoFileStore {
  /// uri → the name it is in the library under.
  final kept = <String, String>{};

  final keeps =
      <({String workingPath, String displayName, String? previousUri})>[];
  final shares = <String>[];
  final deletes = <String>[];

  bool available = true;

  /// When true, `delete` reports the file as still there (a removal that
  /// failed), which the app must report rather than swallow.
  bool refuseDelete = false;

  int _next = 1;

  /// When set, `keep` hands back this uri instead of a fresh one — a platform
  /// that has already given a file its own library identity.
  String? fixedUri;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  }) async {
    keeps.add((
      workingPath: workingPath,
      displayName: displayName,
      previousUri: previousUri,
    ));
    final uri = fixedUri ?? 'content://media/external/video/media/${_next++}';
    kept[uri] = displayName;
    // Write-then-delete, in that order (FR-012).
    if (previousUri != null) kept.remove(previousUri);
    return uri;
  }

  @override
  Future<void> share({required String source}) async => shares.add(source);

  @override
  Future<bool> delete({required String uri}) async {
    deletes.add(uri);
    if (refuseDelete) return false;
    kept.remove(uri);
    return true; // true also when it was already gone
  }

  @override
  Future<bool> exists({required String uri}) async => kept.containsKey(uri);
}

void main() {
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu_video_record');
  });
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A working copy the app has just rendered, as a real file.
  File workingCopy(String name) {
    final file = File('${root.path}/$name')..writeAsBytesSync([1, 2, 3, 4]);
    return file;
  }

  VideoRecordStore recordsFor(FakeFileStore files) => VideoRecordStore(
    files: files,
    now: () => DateTime.utc(2026, 9, 26, 10, 30),
  );

  group('19. keeping writes the content\'s videos, and a replacing keep '
      'rewrites the last one', () {
    test('a second keep that replaces names the first file as previousUri and '
        'leaves one entry', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final copy = workingCopy('render.mp4');

      final first = await records.keep(
        'content-a',
        workingPath: copy.path,
        displayName: 'The Sun Rose.mp4',
      );
      expect(files.keeps, hasLength(1));
      expect(files.keeps.single.previousUri, isNull,
          reason: 'nothing was there to replace');
      expect(files.keeps.single.workingPath, copy.path);
      expect(files.keeps.single.displayName, 'The Sun Rose.mp4');
      expect(first.uri, isNotEmpty);
      expect(first.name, 'The Sun Rose.mp4');

      final second = await records.keep(
        'content-a',
        workingPath: copy.path,
        displayName: 'The Sun Rose.mp4',
      );
      expect(files.keeps, hasLength(2));
      expect(files.keeps.last.previousUri, first.uri,
          reason: 'write-then-delete: the old file goes after the new one '
              'is in place (FR-012)');

      final lookup = await records.recordFor('content-a');
      expect(lookup.videos.map((v) => v.uri), [second.uri],
          reason: 'the replacement leaves the content its one entry');
      expect(lookup.latest?.uri, second.uri,
          reason: 'the content\'s own video is the last entry (FR-022)');
      expect(files.kept.containsKey(first.uri), isFalse,
          reason: 'the file that entry named is gone from the library');
      // One entry, held in an array, in the store itself (FR-012, FR-022).
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw.keys.toList(), ['content-a']);
      expect(raw['content-a'], isA<List<dynamic>>(),
          reason: 'the value is an array of entries (contract § Value)');
      final entries = raw['content-a'] as List<dynamic>;
      expect(entries, hasLength(1));
      expect((entries.single as Map<String, dynamic>)['uri'], second.uri);
      expect((entries.single as Map<String, dynamic>)['name'],
          'The Sun Rose.mp4');
      expect((entries.single as Map<String, dynamic>)['keptAt'], isA<int>());
    });

    test('a keep asked not to replace appends after the earlier video',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final first = await records.keep(
        'content-a',
        workingPath: workingCopy('first.mp4').path,
        displayName: 'The Sun Rose.mp4',
        replace: false,
      );
      final second = await records.keep(
        'content-a',
        workingPath: workingCopy('second.mp4').path,
        displayName: 'The Sun Rose.mp4',
        replace: false,
      );

      expect(files.keeps.last.previousUri, isNull,
          reason: 'no file was named to replace, so none was removed');
      expect(files.kept.keys, hasLength(2),
          reason: 'both files are in the library, the earlier one and this '
              'render (FR-012\'s amendment)');
      final lookup = await records.recordFor('content-a');
      expect(lookup.videos.map((v) => v.uri), [first.uri, second.uri],
          reason: 'oldest first, and the last one is the content\'s own video');
      expect(lookup.latest?.uri, second.uri);
    });

    test('two contents keep their own videos', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final a = await records.keep('content-a',
          workingPath: workingCopy('a.mp4').path, displayName: 'A.mp4');
      final b = await records.keep('content-b',
          workingPath: workingCopy('b.mp4').path, displayName: 'B.mp4');
      expect((await records.recordFor('content-a')).latest?.uri, a.uri);
      expect((await records.recordFor('content-b')).latest?.uri, b.uri);
      // Nothing was replaced: neither keep named a previous file.
      expect(files.keeps.every((k) => k.previousUri == null), isTrue);
    });
  });

  group('20. throwing a render away touches nothing that was kept', () {
    test('the working copy goes, nothing is written, the kept video stays',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final keptCopy = workingCopy('first.mp4');
      final kept = await records.keep('content-a',
          workingPath: keptCopy.path, displayName: 'The Sun Rose.mp4');
      files.keeps.clear();

      final second = workingCopy('second.mp4');
      final review = VideoReview(
        workingPath: second.path,
        contentKey: 'content-a',
        displayName: 'The Sun Rose.mp4',
        files: files,
        records: records,
      );
      await review.throwAway();

      expect(second.existsSync(), isFalse,
          reason: 'the working copy is cleaned up (FR-021)');
      expect(files.keeps, isEmpty,
          reason: 'throwing a render away never keeps anything');
      final lookup = await records.recordFor('content-a');
      expect(lookup.latest?.uri, kept.uri,
          reason: 'the kept video is untouched');
      expect(lookup.wasStale, isFalse);
      // Which is what the content's own actions follow from: it is still there
      // to play, share or delete.
      expect(await files.exists(uri: kept.uri), isTrue);
    });
  });

  group('21. sharing works before keeping and after it', () {
    test('sharing a working copy hands over its path and keeps nothing',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final copy = workingCopy('render.mp4');
      final review = VideoReview(
        workingPath: copy.path,
        contentKey: 'content-a',
        displayName: 'The Sun Rose.mp4',
        files: files,
        records: records,
      );

      await review.share();
      expect(files.shares, [copy.path]);
      expect(files.keeps, isEmpty, reason: 'sharing never implies keeping (A12)');

      // And the file is still there to decide about afterwards.
      await review.throwAway();
      expect(files.keeps, isEmpty);
      expect((await records.recordFor('content-a')).latest, isNull);
      expect(copy.existsSync(), isFalse);
    });

    test('sharing a kept video hands over its library uri, and keeping it was '
        'the only write', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final kept = await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');
      files.keeps.clear();

      await files.share(source: kept.uri);
      expect(files.shares, [kept.uri]);
      expect(files.keeps, isEmpty);
    });
  });

  group('22. a video whose file is gone is reported, and the others are left '
      'alone', () {
    test('a read reports that video gone, forgets it, and keeps the other one',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final first = await records.keep('content-a',
          workingPath: workingCopy('first.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);
      final second = await records.keep('content-a',
          workingPath: workingCopy('second.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);

      // Removed outside the app (a gallery delete, a cleared library).
      files.kept.remove(first.uri);

      final lookup = await records.recordFor('content-a');
      expect(lookup.gone.map((v) => v.uri), [first.uri],
          reason: 'the app reports that video as gone (FR-022)');
      expect(lookup.videos.map((v) => v.uri), [second.uri],
          reason: 'the content\'s other videos are untouched');
      expect(lookup.wasStale, isTrue);
      // Forgotten, so what is left is what can be played.
      final again = await records.recordFor('content-a');
      expect(again.gone, isEmpty);
      expect(again.videos.map((v) => v.uri), [second.uri]);
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect((raw['content-a'] as List<dynamic>), hasLength(1));
    });

    test('a content whose videos are all gone offers to record again',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final only = await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');
      files.kept.remove(only.uri);

      final lookup = await records.recordFor('content-a');
      expect(lookup.videos, isEmpty,
          reason: 'never a play action that fails (FR-022)');
      expect(lookup.gone.map((v) => v.uri), [only.uri]);
      expect(lookup.latest, isNull);
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw.containsKey('content-a'), isFalse);
    });

    test('a content with no entry is not stale', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final lookup = await records.recordFor('content-a');
      expect(lookup.videos, isEmpty);
      expect(lookup.gone, isEmpty);
      expect(lookup.wasStale, isFalse,
          reason: 'nothing was kept, so nothing was lost');
    });
  });

  group('24. deleting takes one video out, and the others stay', () {
    test('a confirmed delete removes that file and that entry, in place',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final first = await records.keep('content-a',
          workingPath: workingCopy('first.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);
      final second = await records.keep('content-a',
          workingPath: workingCopy('second.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);

      final gone = await records.delete(first.uri);
      expect(gone, isTrue);
      expect(files.deletes, [first.uri],
          reason: 'that video\'s own file, and no other');
      expect(files.kept.containsKey(first.uri), isFalse);
      final lookup = await records.recordFor('content-a');
      expect(lookup.videos.map((v) => v.uri), [second.uri],
          reason: 'the other video keeps its place and still plays');
    });

    test('forget takes the entry alone, leaving the file where it is', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final first = await records.keep('content-a',
          workingPath: workingCopy('first.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);
      final second = await records.keep('content-a',
          workingPath: workingCopy('second.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);

      // What a read does with an entry whose file has gone (contract § Read 4).
      await records.forget(first.uri);
      expect(files.deletes, isEmpty,
          reason: 'forgetting a record never touches the library');
      expect(files.kept.containsKey(first.uri), isTrue);
      expect((await records.recordFor('content-a')).videos.map((v) => v.uri),
          [second.uri]);
    });

    test('a failed removal is reported, and the entry still goes', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final kept = await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');
      files.refuseDelete = true;

      final gone = await records.delete(kept.uri);
      expect(gone, isFalse, reason: 'the failure is reported, not swallowed');
      expect((await records.recordFor('content-a')).videos, isEmpty,
          reason: 'the entry goes either way, and the next lookup finds the '
              'file gone');
    });

    test('the store never holds two entries naming the same uri', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final first = await records.keep('content-a',
          workingPath: workingCopy('first.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);
      // A platform that hands back a file's own library identity again.
      files.fixedUri = first.uri;

      await records.keep('content-a',
          workingPath: workingCopy('second.mp4').path,
          displayName: 'The Sun Rose.mp4', replace: false);

      final lookup = await records.recordFor('content-a');
      expect(lookup.videos, hasLength(1),
          reason: 'one entry per uri (contract § Invariants)');
      expect(lookup.videos.single.uri, first.uri);
    });
  });

  group('the record is tolerant of what it finds on disk', () {
    test('a missing key is an empty record', () async {
      final records = recordsFor(FakeFileStore());
      expect((await records.recordFor('content-a')).latest, isNull);
      expect(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key),
        isNull,
        reason: 'reading writes nothing',
      );
    });

    test('malformed entries are dropped and the good ones are kept, without '
        'rewriting the store', () async {
      final files = FakeFileStore();
      final keptUri = await files.keep(
        workingPath: '/tmp/x.mp4',
        displayName: 'Good.mp4',
      );
      final stored = jsonEncode({
        'content-good': {
          'name': 'Good.mp4',
          'uri': keptUri,
          'keptAt': 1000,
        },
        'content-nameless': {'uri': keptUri, 'keptAt': 1000},
        'content-uriless': {'name': 'Nope.mp4', 'keptAt': 1000},
        'content-not-an-object': 'nope',
      });
      SharedPreferences.setMockInitialValues({VideoRecordStore.key: stored});
      final records = recordsFor(files);

      expect((await records.recordFor('content-good')).latest?.uri, keptUri,
          reason: 'the well-formed entry survives');
      expect((await records.recordFor('content-nameless')).videos, isEmpty);
      expect((await records.recordFor('content-uriless')).videos, isEmpty);
      expect(
          (await records.recordFor('content-not-an-object')).videos, isEmpty);
      expect(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key),
        stored,
        reason: 'a read never rewrites what it could not understand',
      );
    });

    test('a value that is not an object at all is an empty record', () async {
      SharedPreferences.setMockInitialValues({
        VideoRecordStore.key: 'not json at all',
      });
      final records = recordsFor(FakeFileStore());
      expect((await records.recordFor('content-a')).videos, isEmpty);
      expect(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key),
        'not json at all',
      );
    });
  });

  group('39. the app\'s other delete still warns', () {
    testWidgets('deleting a content still asks, with its own warning',
        (tester) async {
      final store = ContentStore(
        directory: root,
        loadCatalog: () async => [
          PresetContent(id: 'preset_short', language: 'en', text: 'One two.'),
        ],
        now: () => DateTime.utc(2026, 9, 26, 9),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: ContentListScreen(store: store),
        ),
      );
      // The screen loads its rows through real file IO, so it needs the real
      // window rather than `pumpAndSettle` (which never settles behind its
      // spinner).
      await loadPageContent(tester);
      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();

      // The existing dialog, for a content (content_list_screen.dart:92): this
      // feature adds a second warned delete rather than replacing the first
      // (FR-024). Its own strings, so a rewording does not read as a regression.
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ContentListScreen)),
      )!;
      expect(find.text(l10n.deleteConfirmTitle), findsOneWidget);
      expect(find.text(l10n.deletePresetConfirmMessage), findsOneWidget);
      expect(find.text(l10n.cancelButton), findsOneWidget);
      expect(find.text(l10n.deleteButton), findsOneWidget);
    });
  });
  group('57. the videos kept under the shipped shape are still the reader\'s',
      () {
    test('a single-object value reads as a one-entry list, nothing lost or '
        'duplicated', () async {
      final files = FakeFileStore();
      final uri = await files.keep(
        workingPath: '/tmp/old.mp4',
        displayName: 'The Sun Rose.mp4',
      );
      // The shape 012 shipped with (2026-09-26 to 2026-10-06): one object per
      // content, not an array (contract § Read rules 5).
      final stored = jsonEncode({
        'content-a': {'name': 'The Sun Rose.mp4', 'uri': uri, 'keptAt': 1000},
      });
      SharedPreferences.setMockInitialValues({VideoRecordStore.key: stored});
      final records = recordsFor(files);

      final lookup = await records.recordFor('content-a');
      expect(lookup.videos, hasLength(1),
          reason: 'the video the reader kept is still theirs');
      expect(lookup.videos.single.uri, uri);
      expect(lookup.videos.single.name, 'The Sun Rose.mp4');
      expect(lookup.videos.single.keptAtMs, 1000);
      expect(lookup.gone, isEmpty);
      expect(lookup.latest?.uri, uri);
      expect(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key),
        stored,
        reason: 'reading an old shape rewrites nothing — the migration is a '
            'read rule, not a job (plan 2026-10-06 § The store)',
      );
    });

    test('the first write for that content persists the array shape', () async {
      final files = FakeFileStore();
      final uri = await files.keep(
        workingPath: '/tmp/old.mp4',
        displayName: 'The Sun Rose.mp4',
      );
      SharedPreferences.setMockInitialValues({
        VideoRecordStore.key: jsonEncode({
          'content-a': {'name': 'The Sun Rose.mp4', 'uri': uri, 'keptAt': 1000},
          'content-b': {'name': 'B.mp4', 'uri': '/media/b', 'keptAt': 2000},
        }),
      });
      final records = recordsFor(files);

      final second = await records.keep(
        'content-a',
        workingPath: workingCopy('render.mp4').path,
        displayName: 'The Sun Rose.mp4',
        replace: false,
      );

      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw['content-a'], isA<List<dynamic>>(),
          reason: 'that content is rewritten in the new shape');
      expect((raw['content-a'] as List<dynamic>).length, 2,
          reason: 'the video kept before this amendment is still in there');
      expect(
        ((raw['content-a'] as List<dynamic>).first
            as Map<String, dynamic>)['uri'],
        uri,
        reason: 'oldest first: the earlier video leads',
      );
      expect(
        ((raw['content-a'] as List<dynamic>).last
            as Map<String, dynamic>)['uri'],
        second.uri,
      );
      expect(raw['content-b'], isA<Map<String, dynamic>>(),
          reason: 'a content nobody wrote is left exactly as it was');
    });
  });

}
