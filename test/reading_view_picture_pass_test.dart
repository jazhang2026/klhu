/// The assignment pass's own strip (spec 021 US1, FR-001, FR-002, FR-003,
/// FR-006, FR-019): the reader's pictures themselves, each carrying its own
/// count, and the tap that selects one.
///
/// The pictures' paths point nowhere on purpose: the cell's `errorBuilder` shows
/// what a picture nothing can decode looks like, which is the dialog's own
/// behaviour — a widget test has no photographs to hand it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/picture_assignment_screen.dart';
import 'package:klhu/picture_cell.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';

const _content = 'One two. Three four. Five six.';

const _sunset = 'sunset.png';
const _hills = 'hills.png';
const _forest = 'forest.png';

List<HeldPicture> _picks() => const [
  HeldPicture(name: _sunset, path: '/picks/pick_0_sunset.png'),
  HeldPicture(name: _hills, path: '/picks/pick_1_hills.png'),
  HeldPicture(name: _forest, path: '/picks/pick_2_forest.png'),
];

void main() {
  late List<VideoSentence> sentences;

  /// What the pass answered, written when it pops; null while it is open or when
  /// the reader left without Done.
  AssignmentDraft? given;
  bool popped = false;

  Future<List<VideoSentence>> sentencesOf() async {
    final sentences = await videoSentencesFrom(
      content: _content,
      position: 0,
      loadVoice: (language) async => null,
    );
    expect(sentences, hasLength(3), reason: 'fixture drift');
    return sentences;
  }

  /// Opens the pass on three pictures, with the reader's own assignment given as
  /// sentence **indices** per picture name — the runs themselves are built over
  /// the render's own spans, the way the pass stores them.
  Future<void> pumpPass(
    WidgetTester tester, {
    Map<String, List<int>> assigned = const {},
  }) async {
    sentences = (await tester.runAsync(sentencesOf))!;
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
          pictures: _picks(),
          sentences: sentences,
          runs: [
            for (final picture in _picks())
              PictureRun(
                name: picture.name,
                spans: [
                  for (final index in assigned[picture.name] ?? const <int>[])
                    (sentences[index].start, sentences[index].end),
                ],
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The pass's own strings, read off the page the reader is standing in like
  /// the shipped suite reads its own: a key this feature mints is proved by the
  /// text the app ships, not by a literal here.
  AppLocalizations stringsOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PictureAssignmentScreen)))!;

  /// Opens the pass behind a route, so what the reader confirmed can be read from
  /// [given] **after** Done (the route's future completes when the page pops).
  Future<void> pumpPassRoute(
    WidgetTester tester, {
    Map<String, List<int>> assigned = const {},
  }) async {
    sentences = (await tester.runAsync(sentencesOf))!;
    given = null;
    popped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  given = await Navigator.of(context).push<AssignmentDraft>(
                    MaterialPageRoute(
                      builder: (_) => PictureAssignmentScreen(
                        pictures: _picks(),
                        sentences: sentences,
                        runs: [
                          for (final picture in _picks())
                            PictureRun(
                              name: picture.name,
                              spans: [
                                for (final index
                                    in assigned[picture.name] ?? const <int>[])
                                  (sentences[index].start, sentences[index].end),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The large picture the reader is looking at, when one is open.
  Finder largeCellOf(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is PictureCell && widget.size > 100 && widget.picture.name == name,
  );

  /// The reason the pass is showing, or null when it is showing none — the
  /// shipped suite's own reading of a refusal.
  String? shownRefusal(WidgetTester tester) {
    for (final bar in tester.widgetList<SnackBar>(find.byType(SnackBar))) {
      final content = bar.content;
      if (content is Text) return content.data;
    }
    return null;
  }

  /// The strip's own cells — the 72s. The small markers in the sentence list, the
  /// large picture's own cell and a confirmation's are all other sizes, which is
  /// what keeps each finder below unambiguous.
  Finder strip() => find.byWidgetPredicate(
    (widget) => widget is PictureCell && widget.size == 72,
  );

  /// The strip's cell for [name], found by the name the cell **carries** rather
  /// than paints (FR-002).
  Finder cellOf(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is PictureCell && widget.size == 72 && widget.picture.name == name,
  );

  /// A cell carrying [name] anywhere on the page — a confirmation's own, whose
  /// size is none of the strip's.
  Finder anyCellOf(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is PictureCell && widget.size > 40 && widget.picture.name == name,
  );

  int countOf(WidgetTester tester, String name) =>
      tester.widget<PictureCell>(cellOf(name)).count;

  bool selectedOf(WidgetTester tester, String name) =>
      tester.widget<PictureCell>(cellOf(name)).selected;

  Finder rows() => find.descendant(
    of: find.byType(PictureAssignmentScreen),
    matching: find.byType(ListTile),
  );

  bool heldBySelection(WidgetTester tester, int index) {
    final tile = tester.widgetList<ListTile>(rows()).elementAt(index);
    return (tile.leading! as Icon).icon == Icons.check_circle;
  }

  testWidgets('the strip shows the pictures themselves, not their names', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPass(tester);

    expect(strip(), findsNWidgets(3));
    expect(
      find.byType(ChoiceChip),
      findsNothing,
      reason: 'the chip whose label the reader could not read is gone',
    );
    for (final name in [_sunset, _hills, _forest]) {
      expect(find.text(name), findsNothing, reason: 'FR-002: no name is painted');
      // The name survives as the cell's own label. Read off the semantics node
      // the cell builds (`container: true`), not off the widget: the claim is
      // about what a screen reader meets, and the count may ride the same node.
      final node = tester.getSemantics(
        find
            .descendant(of: cellOf(name), matching: find.byType(Semantics))
            .first,
      );
      expect(
        node.label,
        contains(name),
        reason: 'FR-002: the name is the cell\'s own label',
      );
    }
    handle.dispose();
  });

  testWidgets('each cell carries the reader\'s own count, zero included', (
    tester,
  ) async {
    await pumpPass(tester, assigned: {_sunset: [0, 1]});

    expect(countOf(tester, _sunset), 2);
    expect(
      find.descendant(of: cellOf(_sunset), matching: find.text('2')),
      findsOneWidget,
      reason: 'FR-019: the number alone, at the top right',
    );
    expect(countOf(tester, _hills), 0);
    expect(
      find.descendant(of: cellOf(_hills), matching: find.text('0')),
      findsOneWidget,
      reason: 'FR-001: the number it holds — and the reader watches it change',
    );
  });

  testWidgets('one tap selects a picture, and the list below is that one\'s', (
    tester,
  ) async {
    await pumpPass(tester, assigned: {_sunset: [0], _hills: [1], _forest: [2]});

    expect(selectedOf(tester, _sunset), isTrue, reason: 'the page opens on the first');
    expect(heldBySelection(tester, 0), isTrue);
    expect(heldBySelection(tester, 1), isFalse);

    await tester.tap(cellOf(_hills));
    await tester.pumpAndSettle();

    expect(selectedOf(tester, _hills), isTrue, reason: 'the tapped cell is highlighted');
    expect(selectedOf(tester, _sunset), isFalse);
    expect(heldBySelection(tester, 1), isTrue, reason: 'the list is hills\' own now');
    expect(heldBySelection(tester, 0), isFalse);
    expect(rows(), findsNWidgets(3), reason: 'the whole content is listed');
  });

  testWidgets('giving a sentence changes that cell\'s count on the same tap', (
    tester,
  ) async {
    await pumpPass(tester);
    await tester.tap(cellOf(_hills));
    await tester.pumpAndSettle();
    expect(countOf(tester, _hills), 0);

    await tester.tap(rows().at(0));
    await tester.pumpAndSettle();

    expect(countOf(tester, _hills), 1);
    expect(
      find.descendant(of: cellOf(_hills), matching: find.text('1')),
      findsOneWidget,
      reason: 'the badge answers the same tap (FR-006, SC-002)',
    );
    expect(countOf(tester, _sunset), 0, reason: 'and no other cell moved');
  });

  testWidgets('a hold opens the picture large below, and Close brings the list '
      'back', (tester) async {
    await pumpPass(tester, assigned: {_sunset: [0]});
    await tester.longPress(cellOf(_hills));
    await tester.pumpAndSettle();

    expect(largeCellOf(_hills), findsOneWidget, reason: 'FR-004: below the strip');
    expect(rows(), findsNothing, reason: 'and the sentence list is hidden');
    expect(
      find.text(stringsOf(tester).assignmentNothingAssigned),
      findsOneWidget,
      reason: 'FR-019: the app\'s own words for the count live under it',
    );

    await tester.tap(find.text(stringsOf(tester).assignmentClose));
    await tester.pumpAndSettle();

    expect(largeCellOf(_hills), findsNothing);
    expect(rows(), findsNWidgets(3), reason: 'the list is back');
    expect(selectedOf(tester, _hills), isTrue, reason: 'on the same picture');
  });

  testWidgets('only a picture the reader gave nothing offers the move and the '
      'delete', (tester) async {
    await pumpPass(tester, assigned: {_sunset: [0]});

    final l10n = stringsOf(tester);

    await tester.longPress(cellOf(_hills));
    await tester.pumpAndSettle();
    expect(find.text(l10n.assignmentMoveLeft), findsOneWidget, reason: 'FR-005');
    expect(find.text(l10n.assignmentMoveRight), findsOneWidget);
    expect(find.text(l10n.assignmentDeletePicture), findsOneWidget);

    await tester.longPress(cellOf(_sunset));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.assignmentMoveLeft),
      findsNothing,
      reason: 'a picture holding a sentence of the reader\'s is not theirs to move',
    );
    expect(find.text(l10n.assignmentDeletePicture), findsNothing);
  });

  testWidgets('a move shows on the strip at once, and the answer carries the new '
      'order', (tester) async {
    await pumpPassRoute(tester);
    final before = tester
        .widgetList<PictureCell>(strip())
        .map((cell) => cell.picture.name)
        .toList();
    expect(before, [_sunset, _hills, _forest]);

    await tester.longPress(cellOf(_hills));
    await tester.pumpAndSettle();
    await tester.tap(find.text(stringsOf(tester).assignmentMoveLeft));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<PictureCell>(strip()).map((cell) => cell.picture.name),
      [_hills, _sunset, _forest],
      reason: 'FR-006: the thumbnails answer at once',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(given!.pictures.map((picture) => picture.name), [
      _hills,
      _sunset,
      _forest,
    ], reason: 'and the order it answers with is the order the render walks');
    expect(
      given!.runs,
      isEmpty,
      reason: 'FR-016: the answer carries the reader\'s runs, never the fallback',
    );
  });

  testWidgets('the delete asks first, naming the picture, and cancelling changes '
      'nothing', (tester) async {
    await pumpPass(tester);

    final l10n = stringsOf(tester);

    await tester.longPress(cellOf(_hills));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.assignmentDeletePicture));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget, reason: 'FR-008: it asks');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: largeCellOf(_hills),
      ),
      findsOneWidget,
      reason: 'the confirmation names the picture, not its file name',
    );

    await tester.tap(find.text(l10n.cancelButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widgetList<PictureCell>(strip()).map((cell) => cell.picture.name),
      [_sunset, _hills, _forest],
      reason: 'cancelling leaves the pictures as they were',
    );
  });

  testWidgets('confirming the delete takes the picture out of the record', (
    tester,
  ) async {
    await pumpPassRoute(tester);

    final l10n = stringsOf(tester);

    await tester.longPress(cellOf(_hills));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.assignmentDeletePicture));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteButton));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<PictureCell>(strip()).map((cell) => cell.picture.name),
      [_sunset, _forest],
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(given!.pictures.map((picture) => picture.name), [_sunset, _forest]);
    expect(given!.runs, isEmpty, reason: 'and nothing was assigned to the one gone');
  });

  group('a sentence on another picture', () {
    testWidgets('the confirmation shows both pictures', (tester) async {
      await pumpPass(tester, assigned: {_sunset: [0]});

      final l10n = stringsOf(tester);
      await tester.tap(cellOf(_hills));
      await tester.pumpAndSettle();

      await tester.tap(rows().at(0));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget, reason: 'FR-011');
      expect(
        find.text(l10n.assignmentSwitchTitle),
        findsOneWidget,
        reason: 'the reader is asked, not told',
      );
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: anyCellOf(_sunset)),
        findsOneWidget,
        reason: 'the sentence\'s own picture',
      );
      expect(
        find.descendant(of: dialog, matching: anyCellOf(_hills)),
        findsOneWidget,
        reason: 'and the one the reader selected',
      );
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pumpPass(tester, assigned: {_sunset: [0]});

      final l10n = stringsOf(tester);
      await tester.tap(cellOf(_hills));
      await tester.pumpAndSettle();
      await tester.tap(rows().at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.cancelButton));
      await tester.pumpAndSettle();

      expect(countOf(tester, _sunset), 1, reason: 'FR-012: cancel is identical');
      expect(countOf(tester, _hills), 0);
    });

    testWidgets('confirming moves exactly one sentence', (tester) async {
      await pumpPassRoute(tester, assigned: {_sunset: [0]});

      final l10n = stringsOf(tester);
      await tester.tap(cellOf(_hills));
      await tester.pumpAndSettle();
      await tester.tap(rows().at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.assignmentSwitchConfirm));
      await tester.pumpAndSettle();

      expect(countOf(tester, _sunset), 0, reason: 'the reader confirmed it');
      expect(countOf(tester, _hills), 1);
      expect(
        countOf(tester, _sunset) + countOf(tester, _hills),
        1,
        reason: 'exactly one sentence moved, and no other was handed out',
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(given!.runs.map((run) => run.name), [_hills]);
      expect(
        given!.runs.single.spans,
        [(sentences[0].start, sentences[0].end)],
        reason: 'the sentence\'s own span, in its new picture\'s run (FR-013)',
      );
    });

    testWidgets('a middle sentence is refused with that rule\'s own words, and no '
        'confirmation appears', (tester) async {
      await pumpPass(tester, assigned: {_sunset: [0, 1, 2]});

      final l10n = stringsOf(tester);
      await tester.tap(cellOf(_hills));
      await tester.pumpAndSettle();

      await tester.tap(rows().at(1));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing, reason: 'FR-012: no box');
      expect(
        shownRefusal(tester),
        l10n.assignmentRefusedMiddle,
        reason: 'the rule that refused it says so (FR-003, FR-016)',
      );
      expect(countOf(tester, _sunset), 3, reason: 'and nothing changed');
    });

    testWidgets('a switch that would leave the target gapped is refused the same '
        'way', (tester) async {
      await pumpPass(tester, assigned: {_sunset: [0], _hills: [2]});

      final l10n = stringsOf(tester);
      await tester.tap(cellOf(_sunset));
      await tester.pumpAndSettle();

      await tester.tap(rows().at(2));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(shownRefusal(tester), l10n.assignmentRefusedNotContinuous);
      expect(countOf(tester, _sunset), 1);
      expect(countOf(tester, _hills), 1);
    });
  });

  testWidgets('another picture\'s sentence says which picture holds it, by the '
      'picture', (tester) async {
    await pumpPass(tester, assigned: {_sunset: [0], _hills: [1]});
    await tester.tap(cellOf(_forest));
    await tester.pumpAndSettle();

    final holder = tester.widget<PictureCell>(
      find.descendant(of: rows().at(0), matching: find.byType(PictureCell)),
    );
    expect(holder.picture.name, _sunset);
    expect(
      find.descendant(of: rows().at(0), matching: find.text(_sunset)),
      findsNothing,
      reason: 'the holder is named by its picture, never by its file name',
    );
  });
}
