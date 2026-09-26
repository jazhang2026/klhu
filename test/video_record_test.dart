/// The kept-video record and the review's own decisions (spec 012 US3):
/// quickstart scenarios 19–24 and 39's case for the app's existing delete.
///
/// This file defines the record's seam. `VideoRecordStore` answers a lookup,
/// writes one entry per content and forgets a stale one; `VideoReview` is the
/// undecided working copy with its three decisions. Everything below them is
/// the REAL file system (the test's own temp directory), the REAL record over
/// mocked `shared_preferences`, and a fake platform file store that records
/// what it was asked — so "the platform's keep was called with the first file's
/// uri" is a fact about this file, not about a mock's shape.
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
    final uri = 'content://media/external/video/media/${_next++}';
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

  group('19. keeping writes one entry and replaces what was there', () {
    test('a second keep names the first file as previousUri and leaves one '
        'entry', () async {
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

      final lookup = await records.lookup('content-a');
      expect(lookup.video?.uri, second.uri);
      // One entry per content, in the store itself (FR-012).
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw.keys.toList(), ['content-a']);
      expect(raw['content-a'], isA<Map<String, dynamic>>());
      expect((raw['content-a'] as Map<String, dynamic>)['uri'], second.uri);
      expect((raw['content-a'] as Map<String, dynamic>)['name'],
          'The Sun Rose.mp4');
      expect((raw['content-a'] as Map<String, dynamic>)['keptAt'], isA<int>());
    });

    test('two contents keep their own videos', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final a = await records.keep('content-a',
          workingPath: workingCopy('a.mp4').path, displayName: 'A.mp4');
      final b = await records.keep('content-b',
          workingPath: workingCopy('b.mp4').path, displayName: 'B.mp4');
      expect((await records.lookup('content-a')).video?.uri, a.uri);
      expect((await records.lookup('content-b')).video?.uri, b.uri);
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
      final lookup = await records.lookup('content-a');
      expect(lookup.video?.uri, kept.uri,
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
      expect((await records.lookup('content-a')).video, isNull);
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

  group('22. a record whose file is gone is reported, not played', () {
    test('a lookup whose uri no longer resolves reports it gone and forgets it',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final kept = await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');

      // Removed outside the app (a gallery delete, a cleared library).
      files.kept.remove(kept.uri);

      final lookup = await records.lookup('content-a');
      expect(lookup.video, isNull,
          reason: 'never a play action that fails (FR-022)');
      expect(lookup.wasStale, isTrue,
          reason: 'the app reports the video as gone');
      // Forgotten, so the next look is simply "nothing kept".
      final again = await records.lookup('content-a');
      expect(again.video, isNull);
      expect(again.wasStale, isFalse);
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw.containsKey('content-a'), isFalse);
    });

    test('a content with no entry is not stale', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final lookup = await records.lookup('content-a');
      expect(lookup.video, isNull);
      expect(lookup.wasStale, isFalse,
          reason: 'nothing was kept, so nothing was lost');
    });
  });

  group('24. deleting removes the file and the record', () {
    test('a confirmed delete calls the platform and forgets the entry',
        () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      final kept = await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');

      final gone = await records.delete('content-a');
      expect(gone, isTrue);
      expect(files.deletes, [kept.uri]);
      expect(files.kept.containsKey(kept.uri), isFalse,
          reason: 'the file is gone from the library');
      expect((await records.lookup('content-a')).video, isNull,
          reason: 'and the content offers to record a video again');
      final raw = jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(VideoRecordStore.key)!,
      ) as Map<String, dynamic>;
      expect(raw.containsKey('content-a'), isFalse);
    });

    test('a failed removal is reported, and the entry still goes', () async {
      final files = FakeFileStore();
      final records = recordsFor(files);
      await records.keep('content-a',
          workingPath: workingCopy('render.mp4').path,
          displayName: 'The Sun Rose.mp4');
      files.refuseDelete = true;

      final gone = await records.delete('content-a');
      expect(gone, isFalse, reason: 'the failure is reported, not swallowed');
      expect((await records.lookup('content-a')).video, isNull,
          reason: 'the entry goes either way, and the next lookup finds the '
              'file gone');
    });
  });

  group('the record is tolerant of what it finds on disk', () {
    test('a missing key is an empty record', () async {
      final records = recordsFor(FakeFileStore());
      expect((await records.lookup('content-a')).video, isNull);
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

      expect((await records.lookup('content-good')).video?.uri, keptUri,
          reason: 'the well-formed entry survives');
      expect((await records.lookup('content-nameless')).video, isNull);
      expect((await records.lookup('content-uriless')).video, isNull);
      expect((await records.lookup('content-not-an-object')).video, isNull);
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
      expect((await records.lookup('content-a')).video, isNull);
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
}
