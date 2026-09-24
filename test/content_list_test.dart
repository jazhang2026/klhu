/// Widget tests for the content list (spec 008 T010, extended by 011 US3).
///
/// The screen is presented the same way the reading view presents it: pushed
/// as a route that resolves to the chosen result — a picked entry, a request
/// for a new content, or null when dismissed.
///
/// Widget tests run inside a fake-async zone, where real file IO only makes
/// progress inside a `tester.runAsync` window — [settle] opens one, so the
/// store can finish and the screen can render the result.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/content_list_screen.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('klhu-list-test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ContentStore buildStore({List<PresetContent> catalog = const []}) =>
      ContentStore(
        directory: root,
        loadCatalog: () async => catalog,
        now: () => DateTime.utc(2026, 9, 23, 10, 22, 3),
      );

  PresetContent preset(String id, String language, String text) =>
      PresetContent(id: id, language: language, text: text);

  /// Opens real event-loop windows so the store's chained file IO can finish
  /// (widget tests otherwise run in a fake-async zone that never yields to it),
  /// pumping between them so the continuations run too.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 8; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    for (var round = 0;
        round < 10 &&
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  Widget harness(ContentStore store, {Locale locale = const Locale('en')}) =>
      MaterialApp(
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
        home: ContentListScreen(store: store),
      );

  testWidgets('lists every entry with its language tag', (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
      preset('preset_zh_sample', 'zh-Hans', '你好。'),
    ]);
    await tester.runAsync(() => store.saveNew('My own notes.'));

    await tester.pumpWidget(harness(store));
    await settle(tester);

    expect(find.text('Hello there.'), findsOneWidget);
    expect(find.text('你好。'), findsOneWidget);
    expect(find.text('My own notes.'), findsOneWidget);
    expect(find.textContaining('中文 ·'), findsOneWidget);
    // Both English entries carry the English tag.
    expect(find.textContaining('English ·'), findsNWidgets(2));
  });

  testWidgets('a pre-set title comes from its text, not the interface language',
      (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);

    await tester.pumpWidget(
        harness(store, locale: const Locale.fromSubtags(languageCode: 'zh')));
    await settle(tester);

    // Auto-generated names apply to pre-sets too (spec 008): the row echoes its
    // own content instead of a translated label.
    expect(find.text('Hello there.'), findsOneWidget);
    expect(find.text('英文示例'), findsNothing);
  });

  testWidgets('tapping a row returns that entry to the caller',
      (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);
    ContentListResult? result;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ContentListResult>(
                MaterialPageRoute(
                    builder: (_) => ContentListScreen(store: store)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hello there.'));
    await tester.pumpAndSettle();

    expect(result, isA<PickedContent>());
    expect((result! as PickedContent).entry.id, 'preset_en_sample');
  });

  testWidgets('the add action asks for a new content, not an entry',
      (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);
    ContentListResult? result;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ContentListResult>(
                MaterialPageRoute(
                    builder: (_) => ContentListScreen(store: store)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.pumpAndSettle();

    // The action is a named control of its own, in the app bar (011 FR-015):
    // its tooltip is the accessible name, as for the row deletes.
    await tester.tap(find.byTooltip('Add content'));
    await tester.pumpAndSettle();

    expect(result, isA<NewContentRequest>());
    // Nothing was created by asking: the page decides what "+" means.
    final entries = await tester.runAsync(() => store.list());
    expect(entries!.map((e) => e.id), ['preset_en_sample']);
  });

  testWidgets('going back from the list resolves to nothing', (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);
    ContentListResult? result;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ContentListResult>(
                MaterialPageRoute(
                    builder: (_) => ContentListScreen(store: store)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('an empty library explains itself', (tester) async {
    await tester.pumpWidget(harness(buildStore()));
    await settle(tester);

    expect(
        find.text('No contents yet. Write something, then tap Save.'),
        findsOneWidget);
  });

  testWidgets('deleting asks first; Cancel keeps the entry', (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);

    await tester.pumpWidget(harness(store));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this content?'), findsOneWidget);
    // A pre-set warns that only a reinstall brings it back.
    expect(find.textContaining('reinstall'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Hello there.'), findsOneWidget);
    final entries = await tester.runAsync(() => store.list());
    expect(entries, hasLength(1));
  });

  testWidgets('confirming the dialog deletes the entry', (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);
    await tester.runAsync(() => store.saveNew('My own notes.'));

    await tester.pumpWidget(harness(store));
    await settle(tester);
    // The first row is the newest entry (updatedAt descending).
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('This cannot be undone.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(find.text('My own notes.'), findsNothing);
    expect(find.text('Hello there.'), findsOneWidget);
    final entries = await tester.runAsync(() => store.list());
    expect(entries!.map((e) => e.id), ['preset_en_sample']);
  });

  testWidgets('a damaged entry is labelled and can be deleted',
      (tester) async {
    final store = buildStore();
    final saved = await tester.runAsync(() => store.saveNew('Vanishing.'));
    for (final file in Directory('${root.path}/contents').listSync()) {
      file.deleteSync();
    }

    await tester.pumpWidget(harness(store));
    await settle(tester);

    expect(find.text('Vanishing.'), findsOneWidget);
    expect(find.text('This content is damaged'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('This cannot be undone.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(saved!.name, 'Vanishing.');
    final entries = await tester.runAsync(() => store.list());
    expect(entries, isEmpty);
  });

  testWidgets('rows are operable without sight or gestures (T024)',
      (tester) async {
    final store = buildStore(catalog: [
      preset('preset_en_sample', 'en', 'Hello there.'),
    ]);

    await tester.pumpWidget(harness(store));
    await settle(tester);

    final handle = tester.ensureSemantics();
    try {
      // The row is a separately focusable node from its delete action
      // (asserted next), so the row's own label is title + subtitle…
      final data =
          tester.getSemantics(find.byType(ListTile)).getSemanticsData();
      expect(data.label, contains('Hello there.'));
      expect(data.label, contains('English'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      // …while the delete control is a NAMED, activatable node of its own:
      // on Android the engine sets a node's contentDescription from its
      // tooltip whenever the label is empty (AccessibilityBridge →
      // BaseRoleConfigurator.setContentDescription(tooltip)), so the tooltip
      // IS the accessible name of a tooltipped IconButton. Dropping the
      // tooltip would silently un-name the control.
      final deleteNode = tester.getSemantics(find.byTooltip('Delete'));
      expect(deleteNode.getSemanticsData().tooltip, 'Delete');
      expect(deleteNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue);
    } finally {
      handle.dispose();
    }

    // A touch target the size guidance allows (Material's 48dp minimum; the
    // spec's floor is 44). ListTile's default padding gives this for two lines.
    expect(tester.getSize(find.byType(ListTile)).height,
        greaterThanOrEqualTo(44));
  });
}
