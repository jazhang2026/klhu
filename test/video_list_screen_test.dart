/// A content's videos as a list (spec 012 FR-033, the 2026-10-06 amendment):
/// quickstart rows 56 and 58.
///
/// This file owns the screen's half of row 56 — rows in the record's own order,
/// a row's tap playing **that** video, each row's own share and delete, the
/// empty state, and a delete whose warning names the video — and all of row 58,
/// where every string on the screen is the app's own in the reader's own
/// language. The record's own rules (order, append vs replace, the migration)
/// are `video_record_test.dart`'s, and the page's half of row 56 (the three
/// actions that became one `Videos`) is `reading_view_video_test.dart`'s.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/video_list_screen.dart';
import 'package:klhu/video_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _contentKey = 'preset_short';

/// The device's video library, faked: it answers what it holds, and records what
/// it was asked to do, so "the second row's share handed over the second row's
/// file" is a fact about this file rather than about a mock's shape.
class FakeLibrary implements VideoFileStore {
  final kept = <String, String>{};
  final keeps = <String>[];
  final shares = <String>[];
  final deletes = <String>[];

  /// When true, `delete` reports the file as still there (a removal that
  /// failed), which the app must report rather than swallow.
  bool refuseDelete = false;

  int _next = 1;

  @override
  Future<bool> isAvailable() async => true;

  /// What a review's keep does on this device, so the rows the screen lists can
  /// be put in the library and the record the way the app puts them there.
  @override
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  }) async {
    keeps.add(displayName);
    final uri = 'content://media/external/video/media/${_next++}';
    kept[uri] = displayName;
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
    return true;
  }

  @override
  Future<bool> exists({required String uri}) async => kept.containsKey(uri);
}

/// The platform's player, faked: what the screen pointed at it, and whether it
/// was released before that video was deleted.
class FakePlayer implements VideoPlayer {
  final sources = <String>[];
  int stops = 0;

  @override
  Widget view(BuildContext context, {required String source}) {
    sources.add(source);
    return const SizedBox(key: ValueKey('video player'), width: 20, height: 20);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A content that holds [names], oldest first, each kept a day apart so the
  /// rows can be told apart by their own dates. Answers the store, the library
  /// and the uris in the record's own order.
  Future<({VideoRecordStore records, FakeLibrary library, List<String> uris})>
  contentWith(List<String> names) async {
    final library = FakeLibrary();
    var day = 0;
    final records = VideoRecordStore(
      files: library,
      // One day per keep, so a row's own date tells the rows apart (FR-033).
      now: () => DateTime.utc(2026, 10, 2 + day),
    );
    // Kept one at a time, so the record's own order is a fact rather than a
    // hand-written value: `keep both` appends (FR-012's amendment).
    for (var i = 0; i < names.length; i++) {
      day = i;
      await records.keep(
        _contentKey,
        workingPath: '/tmp/render-$i.mp4',
        displayName: names[i],
        replace: false,
      );
    }
    final stored = await records.recordFor(_contentKey);
    return (
      records: records,
      library: library,
      uris: stored.videos.map((v) => v.uri).toList(),
    );
  }

  Widget screenWith({
    required VideoRecordStore records,
    required FakeLibrary library,
    FakePlayer? player,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale('es'),
    ],
    home: VideoListScreen(
      contentKey: _contentKey,
      records: records,
      files: library,
      player: player ?? FakePlayer(),
    ),
  );

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(VideoListScreen)),
  )!;

  /// The screen reads its rows through real file IO, so a bare `pump` is not
  /// enough: the future has to be allowed to land.
  Future<void> openScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(screen);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
      if (find.byType(ListTile).evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
  }

  testWidgets('56. the content\'s videos are rows, oldest first, and each one '
      'is its own', (tester) async {
    final content = await contentWith(['The Sun Rose.mp4', 'The Sun Set.mp4']);
    await openScreen(
      tester,
      screenWith(records: content.records, library: content.library),
    );

    expect(find.byType(ListTile), findsNWidgets(2));
    // The app's own order: oldest first, so the newest is the last row — the
    // one the page's own Play action opens (FR-022).
    final titles = tester
        .widgetList<Text>(
          find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .toList();
    expect(titles.where((t) => t == 'The Sun Rose.mp4'), hasLength(1));
    expect(titles.where((t) => t == 'The Sun Set.mp4'), hasLength(1));
    expect(
      tester.getTopLeft(find.text('The Sun Rose.mp4')).dy,
      lessThan(tester.getTopLeft(find.text('The Sun Set.mp4')).dy),
      reason: 'the earlier video leads (FR-033)',
    );
    // Each row says when its own video was kept, in the reader's own locale:
    // the first row's date is the day that keep happened.
    final date = MaterialLocalizations.of(
      tester.element(find.byType(VideoListScreen)),
    ).formatShortDate(DateTime.utc(2026, 10, 2).toLocal());
    expect(find.text(date), findsOneWidget,
        reason: 'the first row carries the day it was kept (FR-033)');
    final l10n = l10nOf(tester);
    expect(find.byTooltip(l10n.videoListTitle), findsNothing,
        reason: 'the title is the screen\'s, not a control');
    expect(find.text(l10n.videoListTitle), findsOneWidget);
  });

  testWidgets('56. a tap on a row plays that video, not the first one',
      (tester) async {
    final content = await contentWith(['The Sun Rose.mp4', 'The Sun Set.mp4']);
    final player = FakePlayer();
    await openScreen(
      tester,
      screenWith(
        records: content.records,
        library: content.library,
        player: player,
      ),
    );

    // The second row (the newer video) — a tap anywhere else on the row.
    await tester.tap(find.byType(ListTile).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(player.sources, [content.uris[1]],
        reason: 'that row\'s own file, not the first row\'s (FR-033)');
    expect(find.byKey(const ValueKey('video player')), findsOneWidget);
  });

  testWidgets('56. a row\'s own share hands over that row\'s file',
      (tester) async {
    final content = await contentWith(['The Sun Rose.mp4', 'The Sun Set.mp4']);
    await openScreen(
      tester,
      screenWith(records: content.records, library: content.library),
    );
    final l10n = l10nOf(tester);

    final shares = find.byTooltip(l10n.videoShareButton);
    expect(shares, findsNWidgets(2), reason: 'each row carries its own share');
    await tester.tap(shares.at(1));
    await tester.pump();

    expect(content.library.shares, [content.uris[1]],
        reason: 'the second row handed over its own file (FR-023)');
    expect(content.library.kept, hasLength(2),
        reason: 'sharing is not deleting');
  });

  testWidgets('56. deleting warns by name and removes that row alone',
      (tester) async {
    final content = await contentWith(['The Sun Rose.mp4', 'The Sun Set.mp4']);
    final player = FakePlayer();
    await openScreen(
      tester,
      screenWith(
        records: content.records,
        library: content.library,
        player: player,
      ),
    );
    final l10n = l10nOf(tester);

    // Dismissed: nothing happens at all (FR-024, never a single tap).
    await tester.tap(find.byTooltip(l10n.videoDeleteButton).first);
    await tester.pump();
    expect(find.text(l10n.videoDeleteConfirmTitle), findsOneWidget);
    // The warning names the video being deleted, not the content (FR-033).
    expect(
      find.text(l10n.videoDeleteConfirmMessage('The Sun Rose.mp4')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.videoDeleteConfirmMessage('The Sun Set.mp4')),
      findsNothing,
      reason: 'the row tapped is the one named',
    );
    await tester.tap(find.text(l10n.cancelButton));
    await tester.pump();
    expect(content.library.deletes, isEmpty);
    expect(content.library.kept, hasLength(2));

    // Confirmed: that entry and that file go, the other row stays.
    await tester.tap(find.byTooltip(l10n.videoDeleteButton).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteButton));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(content.library.deletes, [content.uris[0]],
        reason: 'that video\'s own file (FR-024)');
    expect(content.library.kept.keys, [content.uris[1]],
        reason: 'the other video is still in the library');
    expect(player.stops, greaterThanOrEqualTo(1),
        reason: 'what is about to be deleted must not still be playing');
    expect(find.byType(ListTile), findsOneWidget,
        reason: 'one row is left');
    expect(find.text('The Sun Set.mp4'), findsOneWidget);
    expect((await content.records.recordFor(_contentKey)).videos, hasLength(1));
  });

  testWidgets('56. the last delete leaves the state that says so',
      (tester) async {
    final content = await contentWith(['Only.mp4']);
    await openScreen(
      tester,
      screenWith(records: content.records, library: content.library),
    );
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.videoDeleteButton));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteButton));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text(l10n.videoListEmptyMessage), findsOneWidget,
        reason: 'a content with no videos says so rather than showing an '
            'empty list (FR-033)');
  });

  testWidgets('56. a removal that failed is reported, and the row still goes',
      (tester) async {
    final content = await contentWith(['Only.mp4']);
    content.library.refuseDelete = true;
    await openScreen(
      tester,
      screenWith(records: content.records, library: content.library),
    );
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.videoDeleteButton));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteButton));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();

    expect(find.text(l10n.storageErrorMessage), findsOneWidget,
        reason: 'the failure is reported, not swallowed (contract § Write 2)');
    expect(find.byType(ListTile), findsNothing,
        reason: 'the entry goes either way, so no row offers a video that is '
            'not there');
  });

  testWidgets('58. the screen speaks the reader\'s language', (tester) async {
    for (final locale in const [
      Locale('en'),
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale('es'),
    ]) {
      final content = await contentWith(['One two.mp4']);
      await openScreen(
        tester,
        screenWith(
          records: content.records,
          library: content.library,
          locale: locale,
        ),
      );
      final l10n = await AppLocalizations.delegate.load(locale);

      expect(find.text(l10n.videoListTitle), findsOneWidget,
          reason: 'the title is the app\'s own copy in $locale');
      expect(find.byTooltip(l10n.videoShareButton), findsOneWidget);
      expect(find.byTooltip(l10n.videoDeleteButton), findsOneWidget);

      // And the warning is that locale's own, carrying the video's own name.
      await tester.tap(find.byTooltip(l10n.videoDeleteButton));
      await tester.pump();
      expect(find.text(l10n.videoDeleteConfirmMessage('One two.mp4')),
          findsOneWidget);
      expect(find.text(l10n.cancelButton), findsOneWidget);
      expect(find.text(l10n.deleteButton), findsOneWidget);
      await tester.tap(find.text(l10n.cancelButton));
      await tester.pump();
      // Nothing deleted, so the next locale starts from a screen with rows.
      expect(content.library.kept, hasLength(1));
    }
  });

  testWidgets('58. a content with no videos says so in the reader\'s language',
      (tester) async {
    final content = await contentWith(const []);
    await openScreen(
      tester,
      screenWith(
        records: content.records,
        library: content.library,
        locale: const Locale('es'),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));

    expect(find.text(l10n.videoListEmptyMessage), findsOneWidget);
    expect(find.text('Videos'), findsNothing,
        reason: 'no English-only copy on the screen (FR-031)');
  });
}
