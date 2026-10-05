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
import 'package:klhu/services/content_store.dart';
import 'package:klhu/services/voice_mapping_service.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The page's half of US1 (014 — quickstart rows 15 and 18): the text-type entry
/// is offered in 标准 too, switching it changes the setting and nothing else, and
/// a dialogue read is the turns with the tags never spoken.
///
/// The harness is `reading_view_test.dart`'s: a fake reader that records what it
/// was handed, the real page over a temp content store, and a clean mock
/// `shared_preferences` per test.
class FakeReader implements Reader {
  final List<String> spoken = [];

  /// What the page handed the engine, in order. The *voice* is the part no
  /// widget test can see elsewhere, and the part US3's expectation is about.
  final List<ParagraphSpeech> utterances = [];
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
    utterances.clear();
    utterances.addAll(paragraphs);
    for (final paragraph in paragraphs) {
      spoken.add(paragraph.text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

bool _hasHighlight(InlineSpan span, String sentence) {
  if (span is TextSpan) {
    if (span.text == sentence && span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (_hasHighlight(child, sentence)) return true;
    }
  }
  return false;
}

bool hasYellowHighlight(WidgetTester tester, String sentence) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_hasHighlight(rich.text, sentence)) return true;
  }
  return false;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-dialogue-page-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// The reading page over [store], in the app's own localization setup.
  Future<FakeReader> pumpPage(WidgetTester tester, {ContentStore? store}) async {
    final fake = FakeReader();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ReadingView(
        reader: fake,
        contentStore: store ?? pageStore(root),
      ),
    ));
    await loadPageContent(tester);
    return fake;
  }

  /// Lets a write or a read that parks on a real event-loop turn finish — the
  /// page's own tests do this with [loadPageContent]; the dialog needs only a
  /// few of its rounds.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 4; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openChooser(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await settle(tester);
  }

  /// The chooser's own widgets. The role list and the pushed picker can show the
  /// same role name and the same voice, so a finder that does not say which
  /// surface it means finds both.
  Finder inChooser(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  Finder inPicker(Finder matching) =>
      find.descendant(of: find.byType(VoicePickerScreen), matching: matching);

  /// The one content's entry in the role store, decoded.
  Future<Map<String, Object?>> storedContent() async {
    final prefs = await SharedPreferences.getInstance();
    final all = jsonDecode(prefs.getString(RoleStore.key)!) as Map;
    return (all['p'] as Map).cast<String, Object?>();
  }

  Future<Map<String, Object?>?> storedRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RoleStore.key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  group('18. a content with no stored settings is today\'s page, plus one entry',
      () {
    testWidgets('the text-type action is offered and nothing else appears',
        (tester) async {
      await pumpPage(tester);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);

      await openChooser(tester);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Dialogue'), findsOneWidget);
      // Nothing about roles is on the page or in the chooser until the reader
      // asks for them (FR-022: the entry, not a list, is what is added).
      expect(find.text('Roles'), findsNothing);
    });

    testWidgets('it reads exactly as today: the text as written, tags and all',
        (tester) async {
      final store = sampleStore(root, catalog: [
        PresetContent(
          id: 'p',
          language: 'zh-Hans',
          text: '{阿明} 你好。\n\n{May} Hello there.',
        ),
      ]);
      final reader = await pumpPage(tester, store: store);
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);
      expect(reader.spoken, ['{阿明} 你好。', '{May} Hello there.']);
    });
  });

  group('15. the text type is the reader\'s, and switching touches nothing', () {
    testWidgets('choosing 多人对话 is remembered for that content',
        (tester) async {
      await pumpPage(tester);
      await openChooser(tester);
      await tester.tap(find.text('Dialogue'));
      await settle(tester);

      expect(find.text('Text type'), findsOneWidget);
      final stored = await storedRoles();
      expect(stored, {
        'preset_en_sample': {'type': 'dialogue'},
      },
          reason: 'one key, the content\'s own id, and 标准 is the absence');
    });

    testWidgets('it never edits the text and never opens the editor',
        (tester) async {
      final reader = await pumpPage(tester);
      expect(reader.spoken, isEmpty);
      await openChooser(tester);
      await tester.tap(find.text('Dialogue'));
      await settle(tester);

      // The content on screen is the same characters, still not editable.
      final rich = tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
          (r) => r.text.toPlainText() == kSampleEnText,
          orElse: () => throw StateError('content not found'));
      expect(rich.text.toPlainText(), kSampleEnText);
      expect(find.byType(TextField), findsNothing);
      final store = pageStore(root);
      // Real file IO, so it needs a real event-loop turn: on the fake clock a
      // store read never calls back. The three pre-sets are the catalog's own
      // (seeded on first read); a saved entry would be this feature having
      // written the reader's text.
      final entries = await tester.runAsync(() => store.list());
      expect(entries!.every((entry) => entry.origin == ContentOrigin.preset),
          isTrue,
          reason: 'nothing was saved, so nothing changed the content');
    });

    testWidgets('it keeps the highlight and writes no reading position',
        (tester) async {
      await pumpPage(tester);
      const firstSentence = 'The sun rose over the quiet town.';
      final topLeft = tester.getTopLeft(
          find.textContaining('Birds sang', findRichText: true));
      await tester.tapAt(topLeft + const Offset(10, 10));
      await tester.pump();
      expect(hasYellowHighlight(tester, firstSentence), isTrue);
      // A tap is what sets the position (010); the switch must not move it.
      final prefs = await SharedPreferences.getInstance();
      final afterTap = prefs.getString('read_position_preset_en_sample');
      expect(afterTap, isNotNull);

      await openChooser(tester);
      await tester.tap(find.text('Dialogue'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(hasYellowHighlight(tester, firstSentence), isTrue,
          reason: 'switching the type moves nothing (FR-020)');
      expect(prefs.getString('read_position_preset_en_sample'), afterTap,
          reason: 'the reader\'s place is where the tap put it (FR-020, SC-009)');
    });
  });

  group('a dialogue read on the page (FR-005, SC-001)', () {
    testWidgets('the turns are read and the tags are never spoken',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        RoleStore.key: '{"p":{"type":"dialogue"}}',
      });
      final store = sampleStore(root, catalog: [
        PresetContent(
          id: 'p',
          language: 'zh-Hans',
          text: '{阿明} 你好。\n\n{May} Hello there.',
        ),
      ]);
      final reader = await pumpPage(tester, store: store);
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);

      expect(reader.spoken, ['你好。', 'Hello there.']);
      for (final spoken in reader.spoken) {
        expect(spoken.contains('{'), isFalse);
        expect(spoken.contains('阿明'), isFalse);
        expect(spoken.contains('May'), isFalse);
      }
    });
  });

  group('16. the role list (FR-006, FR-016)', () {
    /// The page over a two-role dialogue with [voices] installed, opened in
    /// 多人对话 with [stored] as the content's settings.
    Future<FakeReader> pumpDialogue(
      WidgetTester tester, {
      required Map<String, Object?> stored,
      List<VoiceEntry> voices = const [],
    }) async {
      SharedPreferences.setMockInitialValues({
        RoleStore.key: jsonEncode({'p': stored}),
      });
      final reader = await pumpPage(
        tester,
        store: sampleStore(root, catalog: [
          PresetContent(
            id: 'p',
            language: 'zh-Hans',
            text: '{阿明} 你好。\n\n{阿芳} 我很好。',
          ),
        ]),
      );
      reader.voices = voices;
      // The list is built from the voices the device has, so it is read after the
      // page has asked for them.
      await openChooser(tester);
      return reader;
    }

    /// What the picker itself would call a voice — asserted as a relationship to
    /// the shipped naming, never as a frozen string.
    Future<String> labelOf(VoiceEntry voice) async => VoiceMappingService()
        .displayName(voice, await AppLocalizations.delegate.load(const Locale('en')),
            voiceListLanguage: 'zh-Hans');

    const ccc = VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN');
    const ccd = VoiceEntry(name: 'cmn-cn-x-ccd-local', locale: 'zh-CN');

    testWidgets('one row per role, with its turns and the voice it reads with',
        (tester) async {
      await pumpDialogue(tester,
          stored: {'type': 'dialogue'}, voices: const [ccc, ccd]);

      expect(inChooser(find.text('阿明')), findsOneWidget);
      expect(inChooser(find.text('阿芳')), findsOneWidget);
      expect(inChooser(find.textContaining('1 turn')), findsNWidgets(2));
      // The first role takes the reader's language pick's place in the ranking;
      // the second differs from it (FR-015) — so the two rows name two voices.
      expect(inChooser(find.textContaining(await labelOf(ccc))), findsOneWidget);
      expect(inChooser(find.textContaining(await labelOf(ccd))), findsOneWidget);
    });

    testWidgets('a picker opened for a role is titled with the role\'s name',
        (tester) async {
      await pumpDialogue(tester,
          stored: {'type': 'dialogue'}, voices: const [ccc]);
      await tester.tap(inChooser(find.text('阿明')));
      await settle(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.widgetWithText(AppBar, l10n.rolePickerTitle('阿明')),
          findsOneWidget,
          reason: 'the picker says whose voice it is answering for');
      expect(inPicker(find.text('Automatic')), findsOneWidget);
    });

    testWidgets('removing a role takes its row away and reads its lines as '
        'narration', (tester) async {
      final reader = await pumpDialogue(tester,
          stored: {'type': 'dialogue'}, voices: const [ccc, ccd]);
      expect(inChooser(find.text('阿芳')), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, '阿芳'),
        matching: find.byIcon(Icons.person_remove_outlined),
      ));
      await settle(tester);
      // The shipped confirmation shape: Cancel, then the filled action.
      expect(find.text('Remove this role?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove this role'));
      await settle(tester);

      expect(inChooser(find.text('阿芳')), findsNothing,
          reason: 'the removal takes the row out of the list (FR-006)');
      // A pre-set's version is the epoch, not the seeded entry's `updatedAt`:
      // its text ships and cannot change, and the catalog-fallback path has no
      // entry to read — both ways of opening it must agree or a removal would
      // hold on one and not the other (FR-007, quickstart row 25).
      final epoch = DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      expect((await storedContent())['removed'], [
        {'name': '阿芳', 'at': epoch},
      ], reason: 'stored against the text version it was made on (FR-007)');

      await tester.tap(find.text('Done'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);

      expect(reader.utterances.map((speech) => speech.text).toList(),
          ['你好。', '我很好。'],
          reason: 'the text still reads, whole');
      expect(reader.utterances.map((speech) => speech.voice?.name).toList(),
          ['cmn-cn-x-ccc-local', null],
          reason: '阿芳\'s line is narration now — the reading voice, which is '
              'the OS default while no language pick exists — and not the voice '
              'the assignment had given the role');
    });

    testWidgets('a name removed on an older version of the text is proposed '
        'again', (tester) async {
      await pumpDialogue(tester, stored: {
        'type': 'dialogue',
        'removed': [
          {'name': '阿芳', 'at': '2020-01-01T00:00:00.000Z'},
        ],
      });

      expect(inChooser(find.text('阿芳')), findsOneWidget,
          reason: 'saving the text moves its version, so the removal expires '
              'and the name is a role again (FR-007, research D4)');
    });
  });

  group('17. a role\'s voice is the reader\'s pick (FR-012, FR-013)', () {
    Future<FakeReader> pumpWithPick(WidgetTester tester,
        {Map<String, Object?> stored = const {'type': 'dialogue'}}) async {
      SharedPreferences.setMockInitialValues({
        RoleStore.key: jsonEncode({'p': stored}),
      });
      final reader = await pumpPage(
        tester,
        store: sampleStore(root, catalog: [
          PresetContent(
            id: 'p',
            language: 'zh-Hans',
            text: '{阿明} 你好。\n\n{阿芳} 我很好。',
          ),
        ]),
      );
      reader.voices = const [
        VoiceEntry(name: 'cmn-cn-x-ccc-local', locale: 'zh-CN'),
        VoiceEntry(name: 'cmn-cn-x-ccd-local', locale: 'zh-CN'),
      ];
      return reader;
    }

    testWidgets('tapping a voice stores it under that role and no language',
        (tester) async {
      await pumpWithPick(tester);
      await openChooser(tester);
      await tester.tap(inChooser(find.text('阿明')));
      await settle(tester);

      // The picker's own row for the second voice — not the role list's row
      // behind it, which names a voice too.
      await tester.tap(inPicker(find.textContaining('CCD')).first);
      await settle(tester);

      final content = await storedContent();
      expect(content['voices'], {
        '阿明': {'name': 'cmn-cn-x-ccd-local', 'locale': 'zh-CN'},
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('voice_zh_Hans'), isNull,
          reason: 'a role\'s pick is not the language\'s pick (FR-013)');
    });

    testWidgets('the automatic row clears the pick, and the list shows the '
        'assignment again', (tester) async {
      await pumpWithPick(tester, stored: {
        'type': 'dialogue',
        'voices': {
          '阿明': {'name': 'cmn-cn-x-ccd-local', 'locale': 'zh-CN'},
        },
      });
      await openChooser(tester);
      // The row shows the pick while one exists.
      expect(inChooser(find.textContaining('CCD')), findsOneWidget);

      await tester.tap(inChooser(find.text('阿明')));
      await settle(tester);
      await tester.tap(inPicker(find.text('Automatic')));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      final content = await storedContent();
      expect(content.containsKey('voices'), isFalse,
          reason: 'a cleared pick is no pick, so the role follows the '
              'assignment again (FR-012)');
      expect(inChooser(find.textContaining('CCC')), findsOneWidget,
          reason: 'the list is back to what the assignment gives 阿明');
    });
  });

  group('the language-level picker is today\'s screen', () {
    testWidgets('no title of its own, no automatic row', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byIcon(Icons.record_voice_over));
      await settle(tester);

      expect(find.widgetWithText(AppBar, 'Voice'), findsOneWidget);
      expect(find.text('Automatic'), findsNothing);
    });
  });

  group('32. the Format button (FR-024, SC-011)', () {
    /// The page over [text], in EDIT: the toolbar's four buttons are the only
    /// place the Format press lives.
    Future<void> pumpEditing(WidgetTester tester, String text) async {
      await pumpPage(
        tester,
        store: sampleStore(root, catalog: [
          PresetContent(id: 'p', language: 'zh-Hans', text: text),
        ]),
      );
      await tester.tap(find.byIcon(Icons.edit));
      await settle(tester);
      // EDIT's mount pushes the field's initial state, and the platform undo
      // stack throttles pushes to one per 500 ms: that push must land before
      // anything else changes the text, or the two coalesce into a single state
      // and there is nothing to undo. 008's own edit tests wait the same way
      // (`test/reading_view_edit_test.dart:513-519`).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    /// What the editor's controller holds — the reader's text, which is the
    /// thing a press changes.
    String editorText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    IconButton formatButton(WidgetTester tester) => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.format_line_spacing));

    testWidgets('one press heads every tag, and one Undo takes it back',
        (tester) async {
      const before = '{阿明} 你好。{阿芳} 我很好。';
      await pumpEditing(tester, before);
      expect(editorText(tester), before);
      // Enabled: there is something to format (the Undo button's own pattern).
      expect(formatButton(tester).onPressed, isNotNull);

      await tester.tap(find.byIcon(Icons.format_line_spacing));
      await settle(tester);
      expect(editorText(tester), '{阿明} 你好。\n\n{阿芳} 我很好。',
          reason: 'the tag that was read out loud is a paragraph head now');

      // One press is one undo entry — the button is the only thing that changed
      // the text, and one Undo restores it whole. The wait is the framework's,
      // not a gesture: `UndoHistory` throttles a push by 500 ms
      // (widgets/undo_history.dart, `_kThrottleDuration`), and an Undo inside
      // that window *cancels the pending push* instead of undoing it — the same
      // thing happens after a keystroke, which is why the device row must wait
      // too. One entry, once it lands.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byIcon(Icons.undo));
      await settle(tester);
      expect(editorText(tester), before,
          reason: 'one press is one undo step, and one Undo takes it back');
    });

    testWidgets('and it is disabled when the text is already in the format',
        (tester) async {
      await pumpEditing(tester, '{阿明} 你好。\n\n{阿芳} 我很好。');
      expect(formatButton(tester).onPressed, isNull,
          reason: 'disabled, not a silent no-op (FR-024)');
    });
  });
}
