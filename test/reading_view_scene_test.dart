/// 024 US2 — Format gives a scene tag its own paragraph and nothing else
/// (quickstart row 6).
///
/// One press, one undo step, and a diff of blank lines only: the page's own
/// editor, driven the way the reader drives it. The pure function is
/// `lib/scene_tag.dart`'s; this file proves the PRESS — that the button composes
/// it with 014's own transform, that it is disabled when there is nothing to do,
/// and that a text with no scene tag formats exactly as it did before.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/role_store.dart';
import 'package:klhu/scene_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The page's reader, silent: this row is about the editor's text, and a press
/// that spoke would be a different row's finding. The interface is the app's own
/// (`lib/reader_service.dart`), so a new member there fails this file loudly
/// rather than at runtime.
class SilentReader implements Reader {
  final List<String> spoken = [];
  List<VoiceEntry> voices = const [];
  bool speaking = false;
  bool paused = false;

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
    speaking = true;
  }

  @override
  Future<void> stop() async {
    speaking = false;
  }

  @override
  Future<void> pause() async {
    paused = true;
    speaking = false;
  }

  @override
  Future<void> resume() async {
    paused = false;
    speaking = true;
  }

  @override
  bool get isSpeaking => speaking;

  @override
  bool get isPaused => paused;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => voices;

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    for (final paragraph in paragraphs) {
      spoken.add(paragraph.text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-scene-format-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 4; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The page over [text], in EDIT, with the platform undo stack's own push
  /// landed — 014's Format row waits the same way (`_kThrottleDuration` is
  /// 500 ms, and an Undo inside that window cancels the pending push).
  Future<void> pumpEditing(WidgetTester tester, String text) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ReadingView(
        reader: SilentReader(),
        contentStore: sampleStore(root, catalog: [
          PresetContent(id: 'p', language: 'zh-Hans', text: text),
        ]),
      ),
    ));
    await loadPageContent(tester);
    await tester.tap(find.byIcon(Icons.edit));
    await settle(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  String editorText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  IconButton formatButton(WidgetTester tester) => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.format_line_spacing));

  group('the Format press and a scene tag', () {
    testWidgets('a tag mid-paragraph gains a blank line before it, and nothing else',
        (tester) async {
      const before = '他推门进来。\n[场景] 1：青石观蚁\n屋里很暗。';
      await pumpEditing(tester, before);
      expect(editorText(tester), before);
      expect(formatButton(tester).onPressed, isNotNull);

      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester), '他推门进来。\n\n[场景] 1：青石观蚁\n屋里很暗。',
          reason: 'the tag heads its own paragraph, and no character moved');

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byIcon(Icons.undo));
      await settle(tester);
      expect(editorText(tester), before,
          reason: 'one press is one undo step, and one Undo takes it back');
    });

    testWidgets('the press is idempotent: a second one changes nothing',
        (tester) async {
      const before = '他推门进来。\n[scene] 标题\n屋里很暗。';
      await pumpEditing(tester, before);
      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      final once = editorText(tester);
      expect(once, '他推门进来。\n\n[scene] 标题\n屋里很暗。');
      expect(formatForSceneTags(once), once);
      expect(formatButton(tester).onPressed, isNull,
          reason: 'nothing left to do, so the button is disabled');
    });

    testWidgets('a tag already heading its paragraph is left alone', (tester) async {
      const before = '[场景] 1：青石观蚁\n他推门进来。';
      await pumpEditing(tester, before);
      expect(formatButton(tester).onPressed, isNull);
      expect(formatForSceneTags(before), before);
    });

    testWidgets('two tags in a row both gain their own paragraph', (tester) async {
      const before = '他推门进来。\n[scene]\n[场景] 2：\n屋里很暗。';
      await pumpEditing(tester, before);
      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester), '他推门进来。\n\n[scene]\n\n[场景] 2：\n屋里很暗。');
    });

    testWidgets('a text with no scene tag formats exactly as 014 did',
        (tester) async {
      const before = '你好。{阿明} 我很好。';
      await pumpEditing(tester, before);
      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester), '你好。\n\n{阿明} 我很好。',
          reason: '014\'s own rule, unchanged: a tag with text before it takes '
              'the two breaks that make it a paragraph head');
    });

    testWidgets('the two rules compose in one press and one undo step',
        (tester) async {
      const before = '他推门进来。\n[场景] 1：青石观蚁\n{阿明} 屋里很暗。';
      await pumpEditing(tester, before);
      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester),
          '他推门进来。\n\n[场景] 1：青石观蚁\n\n{阿明} 屋里很暗。');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byIcon(Icons.undo));
      await settle(tester);
      expect(editorText(tester), before,
          reason: 'one press is one undo entry, whatever it wrote');
    });

    testWidgets('a tag inside a role store\'s own dialogue is not touched by the scene rule',
        (tester) async {
      // The composition is order-sensitive: 024's rule runs first, so 014's
      // answer is computed over the text 024 produced, and neither pass rewrites
      // the other's characters.
      SharedPreferences.setMockInitialValues({
        RoleStore.key: jsonEncode({
          'p': {
            'type': 'dialogue',
          },
        }),
      });
      const before = '你好。\n[escena] 3：夜\n我很好。';
      await pumpEditing(tester, before);
      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester), '你好。\n\n[escena] 3：夜\n我很好。');
    });
  });
}
