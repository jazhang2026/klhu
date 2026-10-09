/// 015 US1 — the reading page's half of the comment tag (quickstart rows 5 and
/// 13's display/tap half): the marker is painted nowhere while the comment's
/// words stay where the reader wrote them, a tap answers through the mapping
/// and the comment rule, and the reader's own offsets are still content offsets.
///
/// The harness is `reading_view_dialogue_test.dart`'s: a fake reader that records
/// what it was handed, the real page over a temp content store, and a clean mock
/// `shared_preferences` per test.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/role_store.dart';
import 'package:klhu/services/content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// The reader's own example: one Spanish sentence, a blank line, and the English
/// comment under it — the tag alone on its line, which is the shape whose line
/// break must stay painted.
const String kCommentText = 'Hola.\n\n[注] How are you?';

/// What the page paints for it: the same text with the tag's own characters and
/// its separator gone (FR-005, FR-012).
const String kCommentDisplay = 'Hola.\n\nHow are you?';

/// The comment's own characters, as the reader wrote them.
const String kCommentBody = 'How are you?';

/// Where the comment's content begins in [kCommentText] (the character after
/// the tag and its separator).
final int kCommentStart = kCommentText.indexOf(kCommentBody);

class FakeReader implements Reader {
  final List<String> spoken = [];
  final List<ParagraphSpeech> utterances = [];
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
  Future<List<VoiceEntry>> voicesFor(String language) async => const [];

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    utterances
      ..clear()
      ..addAll(paragraphs);
    for (final paragraph in paragraphs) {
      spoken.add(paragraph.text);
    }
    speaking = paragraphs.isNotEmpty;
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

/// The text the page paints for the content on screen.
String paintedText(WidgetTester tester) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    final plain = rich.text.toPlainText();
    if (plain.contains('Hola.')) return plain;
  }
  throw StateError('the reading content is not on screen');
}

/// Every span the page paints with the tracking highlight's own style.
List<String> highlighted(WidgetTester tester) {
  final found = <String>[];
  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    final text = span.text ?? '';
    if (text.isNotEmpty && span.style?.backgroundColor == Colors.yellow) {
      found.add(text);
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(rich.text);
  }
  return found;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-comment-page-test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ContentStore commentStore({String text = kCommentText}) => sampleStore(root, catalog: [
        PresetContent(id: 'comments', language: 'es', text: text),
      ]);

  /// The reading page over the one content, in the app's own localization setup.
  Future<FakeReader> pumpPage(WidgetTester tester, {String text = kCommentText}) async {
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
        contentStore: commentStore(text: text),
      ),
    ));
    await loadPageContent(tester);
    return fake;
  }

  /// The render object the reading text is painted by: what the page's own tap
  /// path measures, so a tap here goes through the same two mappings.
  RenderParagraph contentRender(WidgetTester tester) {
    for (final element in find.byType(RichText).evaluate()) {
      final widget = element.widget as RichText;
      if (widget.text.toPlainText() == kCommentDisplay) {
        return element.renderObject as RenderParagraph;
      }
    }
    throw StateError('the reading content is not on screen');
  }

  /// Taps the middle of the first character of [what] — a DISPLAY offset, i.e.
  /// what the reader sees, which is the whole point of the mapping.
  Future<void> tapOn(WidgetTester tester, String what) async {
    final render = contentRender(tester);
    final start = kCommentDisplay.indexOf(what);
    expect(start, isNonNegative, reason: '"$what" is not on the page');
    final box = render
        .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + 1))
        .first;
    await tester.tapAt(render.localToGlobal(Offset(
      (box.left + box.right) / 2,
      (box.top + box.bottom) / 2,
    )));
    await tester.pump();
  }

  /// The stored reading position for the one content, as `offset||charCount`.
  Future<String?> storedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('read_position_comments');
  }

  /// Lets a write, a read or the sheet's own rounds finish on the fake clock —
  /// `reading_view_dialogue_test.dart`'s helper, same rounds.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 4; round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// 014's own sheet, through the control that already opens it (FR-022).
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await settle(tester);
  }

  /// The switch the sheet carries, as the reader sees it.
  bool switchInSheet(WidgetTester tester) =>
      tester.widget<SwitchListTile>(inSheet(find.byType(SwitchListTile))).value;

  /// The one content's entry in the role store, decoded.
  Future<Map<String, Object?>?> storedRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RoleStore.key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  group('5. the page paints the text minus the tags', () {
    testWidgets('the marker is painted nowhere and the words stay where they were',
        (tester) async {
      await pumpPage(tester);
      final painted = paintedText(tester);
      expect(painted, kCommentDisplay);
      expect(painted.contains('['), isFalse,
          reason: 'no marker character reaches the page (FR-005, FR-012)');
      expect(painted, isNot(kCommentText));
      // The reader's own layout: the comment is still on its own line, under a
      // blank line, and its characters are all there.
      expect(painted.split('\n').last.trim(), kCommentBody);
      expect(painted.contains('Hola.'), isTrue);
      // What the store hands out still carries the tag, and what the page paints
      // is exactly that text minus the tag's own characters — the display is
      // derived on the way to the screen, and nothing was rewritten to get it
      // (FR-015: the store's own text is the reader's).
      final stored = await commentStore().presetFor('comments');
      expect(stored!.text, kCommentText);
      expect(kCommentText.replaceFirst('[注] ', ''), painted);
    });

    testWidgets('the editor still shows the tag the reader wrote', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, kCommentText,
          reason: 'the editor is where the reader writes the tag (FR-012)');
    });

  });

  group("13. a tap answers through the mapping and the comment rule", () {
    testWidgets('inside the comment it answers the comment itself', (tester) async {
      await pumpPage(tester);
      await tapOn(tester, 'How are you?');

      expect(highlighted(tester), [kCommentBody],
          reason: 'the highlight covers the comment exactly (FR-012)');
      expect(await storedPosition(), '$kCommentStart||${kCommentText.length}',
          reason: 'the position is a CONTENT offset (FR-012, SC-009)');
    });

    testWidgets('the character right after the elision is still the comment',
        (tester) async {
      await pumpPage(tester);
      // The last character of the comment's line: the mapping has to have moved
      // past the whole elided tag for this one.
      await tapOn(tester, '?');
      expect(highlighted(tester), [kCommentBody]);
    });

    testWidgets('on the sentence above it answers that sentence', (tester) async {
      await pumpPage(tester);
      await tapOn(tester, 'Hola.');
      expect(highlighted(tester), ['Hola.']);
      expect(await storedPosition(), '0||${kCommentText.length}');
    });
  });

  group("13. the sheet's switch: this content's comments, read or not", () {
    testWidgets('the text type sheet carries it, in both text types',
        (tester) async {
      await pumpPage(tester);
      await openSheet(tester);
      expect(inSheet(find.text('Read the comments')), findsOneWidget);
      expect(switchInSheet(tester), isTrue,
          reason: 'the shipped default is read (FR-006)');

      await tester.tap(inSheet(find.text('Dialogue')));
      await settle(tester);
      expect(inSheet(find.text('Read the comments')), findsOneWidget,
          reason: 'the sheet is one entry for both text types (FR-014)');
      expect(switchInSheet(tester), isTrue);
    });

    testWidgets('toggling it stores the choice, and nothing else',
        (tester) async {
      await pumpPage(tester);
      await openSheet(tester);
      await tester.tap(inSheet(find.byType(SwitchListTile)));
      await settle(tester);

      expect(switchInSheet(tester), isFalse);
      expect(await storedRoles(), {
        'comments': {'comments': false},
      },
          reason: 'one key (the content\'s own id), one field, and read is the '
              'absence of it');
    });

    testWidgets('the next read honours it', (tester) async {
      final reader = await pumpPage(tester);
      // ⏭ Continue Read from the top: the read covers the comment's own text,
      // which is what the switch has to change (010's own control).
      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);
      expect(reader.utterances.map((s) => s.text).toList(),
          ['Hola.', 'How are you?'],
          reason: 'the comment is read, right after its sentence');

      await tester.tap(find.byIcon(Icons.stop));
      await settle(tester);
      await openSheet(tester);
      await tester.tap(inSheet(find.byType(SwitchListTile)));
      await settle(tester);
      await tester.tap(inSheet(find.text('Done')));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.skip_next));
      await settle(tester);
      expect(reader.utterances.map((s) => s.text).toList(), ['Hola.'],
          reason: 'with the comments off the comment is not an utterance at all '
              '(FR-006, SC-002)');
    });

    testWidgets('nothing else on the page moves', (tester) async {
      await pumpPage(tester);
      await tapOn(tester, 'Hola.');
      expect(highlighted(tester), ['Hola.']);

      await openSheet(tester);
      await tester.tap(inSheet(find.byType(SwitchListTile)));
      await settle(tester);
      await tester.tap(inSheet(find.text('Done')));
      await settle(tester);

      expect(paintedText(tester), kCommentDisplay,
          reason: 'the text is not touched by the setting');
      expect(highlighted(tester), ['Hola.'],
          reason: 'the highlight in force is not touched either');

      // And the setting survives the text type being chosen afterwards — the
      // trap plan ripple 4 named: a hand-built settings object must carry it.
      await openSheet(tester);
      await tester.tap(inSheet(find.text('Dialogue')));
      await settle(tester);
      expect(switchInSheet(tester), isFalse);
      expect(await storedRoles(), {
        'comments': {'type': 'dialogue', 'comments': false},
      });
    });

    testWidgets('a reopen reads the stored choice back, and the tap follows it',
        (tester) async {
      // As if the reader had turned them off in an earlier session.
      SharedPreferences.setMockInitialValues({
        RoleStore.key: jsonEncode({
          'comments': {'comments': false},
        }),
      });
      await pumpPage(tester);

      await tapOn(tester, 'How are you?');
      expect(highlighted(tester), ['Hola.'],
          reason: 'with the comments off a tap inside a comment answers the '
              'sentence it belongs to (FR-012, SC-009)');
      await openSheet(tester);
      expect(switchInSheet(tester), isFalse,
          reason: 'the choice was remembered across the reopen');
    });
  });

  group('21. the role list is comment-aware (FR-011)', () {
    testWidgets('a role whose paragraph is nothing but a comment is not a role',
        (tester) async {
      // The one shape where the role list can tell the two scans apart: a
      // paragraph that holds a role tag AND nothing but a comment contributes
      // no turn, so it names no role (FR-011, SC-005).
      const text = '{阿明} [注] Hello.\n\n{May} Hi.';
      await pumpPage(tester, text: text);
      await openSheet(tester);
      await tester.tap(inSheet(find.text('Dialogue')));
      await settle(tester);

      expect(inSheet(find.text('May')), findsOneWidget);
      expect(inSheet(find.text('阿明')), findsNothing,
          reason: "阿明's paragraph holds nothing but a comment (FR-011)");
    });
  });
}
