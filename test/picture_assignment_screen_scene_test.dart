/// 024 US3 — the assignment page's own option: there when the content has
/// scenes, absent when it does not, and asking before it replaces anything
/// (quickstart row 8).
///
/// The page is pumped directly, as 021's own rows pump it: the option is a fact
/// about the page the reader stands in, and the strings it shows are read from
/// the ARBs through `AppLocalizations`, never from a literal here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/picture_assignment_screen.dart';
import 'package:klhu/picture_cell.dart';
import 'package:klhu/scene_tag.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';

/// The quickstart's fixture: a preamble, three scenes, six sentences' worth of
/// text (the `？」` split is the segmenter's, not this feature's).
const _fixture = '她走进院子。\n'
    '\n'
    '[场景] 1：青石观蚁\n'
    '他推门进来。屋里很暗。\n'
    '\n'
    '[scene]\n'
    '「有人吗？」她说。门开了。\n'
    '\n'
    '[场景] 2：\n'
    '脚步声远了。\n';

/// The same content with no scene tag at all — the shape the option must not be
/// offered on (FR-008).
const _plain = '她走进院子。\n\n他推门进来。屋里很暗。\n\n「有人吗？」她说。门开了。\n\n脚步声远了。\n';

List<HeldPicture> _picks(int count) => [
      for (var i = 0; i < count; i++)
        HeldPicture(name: 'p$i.png', path: '/picks/pick_${i}_p$i.png'),
    ];

void main() {
  late List<VideoSentence> sentences;
  late List<Scene> scenes;

  setUp(() {
    sentences = const [];
    scenes = const [];
  });

  /// The page over [text]'s own sentences and scenes, with the reader's
  /// assignment given as sentence **indices** per picture name.
  Future<void> pumpPass(
    WidgetTester tester, {
    String text = _fixture,
    int pictures = 5,
    Map<String, List<int>> assigned = const {},
  }) async {
    sentences = (await tester.runAsync(
      () => videoSentencesFrom(
        content: text,
        position: 0,
        loadVoice: (language) async => null,
      ),
    ))!;
    scenes = scenesOf(text);
    final picked = _picks(pictures);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: PictureAssignmentScreen(
          pictures: picked,
          sentences: sentences,
          runs: [
            for (final picture in picked)
              PictureRun(
                name: picture.name,
                spans: [
                  for (final index in assigned[picture.name] ?? const <int>[])
                    (sentences[index].start, sentences[index].end),
                ],
              ),
          ],
          scenes: scenes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations stringsOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PictureAssignmentScreen)))!;

  /// One picture's own count, read off its strip cell — the page's own answer
  /// to "how many sentences does this picture hold". The 72s are the strip's
  /// cells only; the sentence list's markers are smaller.
  int countOf(WidgetTester tester, int picture) => tester
      .widget<PictureCell>(find.byWidgetPredicate((widget) =>
          widget is PictureCell &&
          widget.size == 72 &&
          widget.picture.name == 'p$picture.png'))
      .count;

  group('the option', () {
    testWidgets('it is absent for a content with no scene, and present with scenes',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await pumpPass(tester, text: _plain);
      expect(scenes, isEmpty);
      expect(find.text(l10n.assignmentScenesButton), findsNothing,
          reason: 'a content with no scene offers no pairing (FR-008)');

      await pumpPass(tester);
      expect(scenes, hasLength(3));
      expect(find.text(l10n.assignmentScenesButton), findsOneWidget);
      // The label is the ARB's, in every shipped locale — four files, four
      // strings, and no hard-coded literal anywhere on the page.
      for (final locale in const [
        Locale('en'),
        Locale('zh'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale('es'),
      ]) {
        final strings = await AppLocalizations.delegate.load(locale);
        expect(strings.assignmentScenesButton, isNotEmpty, reason: '$locale');
        expect(strings.assignmentScenesConfirm, isNotEmpty, reason: '$locale');
        expect(strings.assignmentScenesBody(3), contains('3'),
            reason: '$locale names the runs');
      }
    });

    testWidgets('with nothing assigned it writes the pairing and asks no question',
        (tester) async {
      await pumpPass(tester);
      expect(countOf(tester, 0), 0);

      await tester.tap(find.text(stringsOf(tester).assignmentScenesButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'nothing is replaced, so nothing is asked (FR-012)');
      // The i-th picture takes the i-th scene: 2, 3, 1 sentences on the first
      // three, and the preamble in nobody's run.
      expect(countOf(tester, 0), 2);
      expect(countOf(tester, 1), 3);
      expect(countOf(tester, 2), 1);
      expect(countOf(tester, 3), 0);
      expect(countOf(tester, 4), 0);
    });

    testWidgets('the pairing is a plain assignment: a tap still edits it',
        (tester) async {
      await pumpPass(tester);
      await tester.tap(find.text(stringsOf(tester).assignmentScenesButton));
      await tester.pumpAndSettle();
      expect(countOf(tester, 0), 2);

      // The preamble is nobody's, so giving it to the first picture works like
      // any other tap (FR-011: the result is an ordinary assignment).
      await tester.tap(find.text('她走进院子。'));
      await tester.pumpAndSettle();
      expect(countOf(tester, 0), 3);
    });

    testWidgets('with something assigned it asks first, naming how many runs go',
        (tester) async {
      await pumpPass(tester, assigned: {'p0.png': [0], 'p1.png': [6]});
      final l10n = stringsOf(tester);
      expect(countOf(tester, 0), 1);
      expect(countOf(tester, 1), 1);

      await tester.tap(find.text(l10n.assignmentScenesButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'the pairing would replace what those pictures hold (FR-012)');
      expect(find.descendant(
              of: find.byType(AlertDialog), matching: find.text(l10n.assignmentScenesTitle)),
          findsOneWidget);
      // Three scenes own sentences, so three runs go.
      expect(find.descendant(
              of: find.byType(AlertDialog), matching: find.text(l10n.assignmentScenesBody(3))),
          findsOneWidget);
      expect(find.descendant(
              of: find.byType(AlertDialog), matching: find.text(l10n.assignmentScenesConfirm)),
          findsOneWidget);
    });

    testWidgets('a refusal leaves the runs exactly as they were', (tester) async {
      await pumpPass(tester, assigned: {'p0.png': [0], 'p1.png': [6]});
      final before0 = countOf(tester, 0);
      final before1 = countOf(tester, 1);

      await tester.tap(find.text(stringsOf(tester).assignmentScenesButton));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(countOf(tester, 0), before0, reason: 'a refusal changes nothing');
      expect(countOf(tester, 1), before1);
    });

    testWidgets('confirming the question writes the pairing', (tester) async {
      await pumpPass(tester, assigned: {'p0.png': [0], 'p1.png': [6]});
      final l10n = stringsOf(tester);

      await tester.tap(find.text(l10n.assignmentScenesButton));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text(l10n.assignmentScenesConfirm)));
      await tester.pumpAndSettle();

      expect(countOf(tester, 0), 2);
      expect(countOf(tester, 1), 3);
      expect(countOf(tester, 2), 1);
      expect(countOf(tester, 3), 0);
      expect(countOf(tester, 4), 0);
    });

    testWidgets('the pairing is an ordinary edit: a held sentence can be taken back',
        (tester) async {
      await pumpPass(tester);
      await tester.tap(find.text(stringsOf(tester).assignmentScenesButton));
      await tester.pumpAndSettle();
      expect(countOf(tester, 2), 1, reason: 'the third scene\'s one sentence');

      // The third scene owns exactly one sentence, so it is both ends of that
      // run: taking it back is allowed, which is what "an ordinary assignment"
      // means for the reader (FR-011, FR-016).
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is PictureCell && widget.size == 72 && widget.picture.name == 'p2.png'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('脚步声远了。'));
      await tester.pumpAndSettle();
      expect(countOf(tester, 2), 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
