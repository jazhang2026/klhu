/// Spec 034 widget tests: the Text type dialog's reading-language section,
/// its persistence, and read evidence that a pinned language reaches the
/// engine.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

class _FakeReader implements Reader {
  final List<ParagraphSpeech> utterances = [];
  bool speaking = false;

  @override
  Future<void> speak(String text, String language) async {
    speaking = true;
  }

  @override
  Future<void> stop() async {
    speaking = false;
  }

  @override
  Future<void> pause() async {
    speaking = false;
  }

  @override
  Future<void> resume() async => speaking = true;

  @override
  bool get isSpeaking => speaking;

  @override
  bool get isPaused => false;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => const [];

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    utterances
      ..clear()
      ..addAll(paragraphs);
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-readlang-page-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<_FakeReader> pumpPage(WidgetTester tester,
      {required ContentStore store}) async {
    final fake = _FakeReader();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ReadingView(reader: fake, contentStore: store),
    ));
    await loadPageContent(tester);
    return fake;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 4; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openTextType(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await settle(tester);
    expect(find.text('Text type'), findsOneWidget);
  }

  /// A store whose only content is a user entry — the section is hidden for
  /// pre-sets, so these tests need `isPreset == false`. The save is real file
  /// IO, so it runs inside [tester.runAsync].
  Future<ContentStore> userStore(
      WidgetTester tester, String text) async {
    final store = sampleStore(root, catalog: const []);
    await tester.runAsync(() => store.saveNew(text));
    return store;
  }

  group('reading-language section (US1)', () {
    testWidgets('shows Main text and Comments dropdowns; Auto carries the '
        'detected language', (tester) async {
      final store = await userStore(tester, 'Hello there. This is a plain English text.');
      await pumpPage(tester, store: store);
      await openTextType(tester);

      expect(find.text('Reading language'), findsOneWidget);
      expect(find.text('Main text'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));

      // Open the main dropdown: Auto shows what it detected, inline.
      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      expect(find.textContaining('Auto detected:'), findsWidgets);
      expect(find.text('English'), findsWidgets);
      expect(find.text('中文'), findsWidgets);
      expect(find.text('Español'), findsWidgets);
    });

    testWidgets('picking Español persists and reopens selected',
        (tester) async {
      final store = await userStore(tester, 'Hello there. This is a plain English text.');
      await pumpPage(tester, store: store);
      await openTextType(tester);

      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      await tester.tap(find.text('Español').last);
      await settle(tester);

      final entries = (await tester.runAsync(() => store.list()))!;
      expect(entries.single.readLang, 'es');

      // Reopen: the dropdown's value is the pick.
      await tester.tap(find.text('Done'));
      await settle(tester);
      await openTextType(tester);
      final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>).first);
      expect(dropdown.value, 'es');
    });

    testWidgets('the Comments dropdown persists commentLang',
        (tester) async {
      final store = await userStore(tester, 'Hello there. [注] How are you?');
      await pumpPage(tester, store: store);
      await openTextType(tester);

      await tester.tap(find.byType(DropdownButton<String>).last);
      await settle(tester);
      await tester.tap(find.text('Español').last);
      await settle(tester);

      final entries = (await tester.runAsync(() => store.list()))!;
      expect(entries.single.commentLang, 'es');
    });

    testWidgets('a preset shows no reading-language section', (tester) async {
      await pumpPage(tester, store: pageStore(root));
      await openTextType(tester);
      expect(find.text('Reading language'), findsNothing);
    });

    testWidgets('a pinned language reaches the engine on tap-read',
        (tester) async {
      final store = await userStore(tester, 'Hello there. This is a plain English text.');
      final entry = (await tester.runAsync(() => store.list()))!.single;
      await tester.runAsync(() => store.setReadLanguage(entry, readLang: 'es'));
      final reader = await pumpPage(tester, store: store);

      await tester.tapAt(offsetInText(tester, 'plain English'));
      await settle(tester);

      expect(reader.utterances, isNotEmpty);
      expect(reader.utterances.every((s) => s.language == 'es'), isTrue);
    });
  });

  group('role language override (US2)', () {
    const dialogueText = '{阿明} 你好。\n\n{Bob} 你好。';

    testWidgets('a role pin changes only that role\'s turns', (tester) async {
      final store = await userStore(tester, dialogueText);
      final entry = (await tester.runAsync(() => store.list()))!.single;
      await tester.runAsync(() => store.setReadLanguage(entry, roleLangs: const {'阿明': 'en'}));
      final reader = await pumpPage(tester, store: store);

      await openTextType(tester);
      await tester.tap(find.text('Dialogue'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);

      final byRole = {for (final s in reader.utterances) s.role: s.language};
      expect(byRole['阿明'], 'en');
      expect(byRole['Bob'], isNot('en'));
    });
  });
}
