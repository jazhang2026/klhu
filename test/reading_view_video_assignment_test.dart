/// The assignment pass, and the seam that reaches it (spec 020 US1 —
/// quickstart row 6's widget half).
///
/// Two subjects, one file, because they are one story: the **page** the reader
/// assigns on (driven here directly: its own widget, its own sentences, its own
/// answer), and the **dialog's own seam** — one line beside the pick, opening
/// that page on the sentences the render will speak, with the answer reaching
/// the renderer's own line and the frames it paints.
///
/// The page's harness is 012's own test file's, **imported rather than copied**
/// (`ShortEngine`, `RecordingEncoder`, `PageFileStore`, `PagePlayer`,
/// `PickingPictures`, `picked`, `redPng`/`bluePng`, `pixelOf`): the fakes that
/// prove the dialog's picks reach the frames are what prove the assignment does.
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/picture_assignment.dart';
import 'package:klhu/picture_assignment_screen.dart';
import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';
import 'reading_view_video_test.dart';

/// Three sentences, two paragraphs — 012's own short fixture, so the frame
/// numbers below are the ones its suite already works with.
const _text = 'One two. Three four.\n\nFive six.';

const _presetId = 'preset_short';

/// The three pictures the reader picks in these cases (`_sunset` is the one the
/// harness paints red, so a frame's colour names its own picture).
const _sunset = 'sunset.png';
const _hills = 'hills.png';
const _forest = 'forest.png';

/// The content the reader assigns on, **before it is edited** — four sentences,
/// so one run can stand while two go stale (FR-014's own shape).
const _oldText = 'One two. Three four.\n\nFive six. Seven eight.';

/// The **same content, edited** — its first sentence untouched and the rest
/// changed: a stored run that named the first sentence still matches (the span
/// is the same in both texts), and every run that named a later one does not.
const _changedText = 'One two. The text changed here.\n\nAnd so did this. '
    'And this too.';

void main() {
  late Directory root;
  late Directory work;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu_assignment_page');
    work = Directory.systemTemp.createTempSync('klhu_assignment_work');
  });
  tearDown(() {
    for (final dir in [root, work]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  /// The library's own catalog. [text] is the content **as it stands now**: an
  /// edit to the content is a second store with the same id and a different
  /// text, which is exactly what the reader's own edit does (FR-014).
  ContentStore shortStore({String text = _text}) => ContentStore(
    directory: root,
    loadCatalog: () async => [
      PresetContent(id: _presetId, language: 'en', text: text),
    ],
    now: () => DateTime.utc(2026, 10, 14, 9),
  );

  Widget pageWith(
    ShortEngine engine,
    RecordingEncoder encoder, {
    PicturePicker? picker,
    String text = _text,
    ContentStore? store,
  }) => MaterialApp(
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
    home: ReadingView(
      reader: QuietReader(),
      contentStore: store ?? shortStore(text: text),
      synthesizer: engine,
      videoEncoder: encoder,
      videoWorkDir: work,
      videoFileStore: PageFileStore(),
      videoPlayer: PagePlayer(),
      picturePicker: picker ?? QuietPicker(),
    ),
  );

  /// The page's real work — the engine's files, the painter's pictures, the PNG
  /// encoding — with the test clock standing still, until [until]. The closing
  /// pump is 012's own note: work that lands during the last real turn can mark
  /// the page dirty after that turn's pump.
  Future<void> letWorkRun(
    WidgetTester tester,
    bool Function() until, {
    int rounds = 400,
  }) async {
    for (var i = 0; i < rounds; i++) {
      if (until()) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  /// The video dialog, open, with the pictures [names] chosen — each a real PNG
  /// of its own colour, so the assignment's effect on a frame can be read.
  Future<void> openDialogWith(
    WidgetTester tester,
    ShortEngine engine,
    RecordingEncoder encoder,
    List<String> names, {
    String text = _text,
    ContentStore? store,
  }) async {
    final picker = PickingPictures([
      [
        for (final name in names)
          picked(name, await (name == _sunset ? redPng(tester) : bluePng(tester))),
      ],
    ]);
    await tester.pumpWidget(
      pageWith(engine, encoder, picker: picker, text: text, store: store),
    );
    await loadPageContent(tester);

    await tester.tap(find.byTooltip('Video'));
    await letWorkRun(
      tester,
      () => find.text('Video format').evaluate().isNotEmpty,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    final button = find.text(l10n.videoPicturesButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await letWorkRun(
      tester,
      () => find.byType(MovableThumbnail).evaluate().length == picker.handedOver,
    );
  }

  /// The page's reading of the render's own sentences: the same three the video
  /// timeline will speak.
  Future<List<VideoSentence>> sentencesOf() async {
    final sentences = await videoSentencesFrom(
      content: _text,
      position: 0,
      loadVoice: (language) async => null,
    );
    expect(sentences, hasLength(3), reason: 'fixture drift');
    return sentences;
  }

  /// What the pass answered, written when it pops; null while it is open or when
  /// the reader left without Done ([popped] tells the two apart).
  AssignmentDraft? given;
  bool popped = false;

  /// Opens the assignment pass on [pictures] and [sentences].
  ///
  /// What the reader confirmed is read from [given] and [popped] **after** Done:
  /// the route's own future completes when the page pops, so a value returned
  /// from here would always be the value before the reader did anything.
  Future<void> openPass(
    WidgetTester tester, {
    required List<HeldPicture> pictures,
    required List<VideoSentence> sentences,
    List<PictureRun> runs = const [],
  }) async {
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
                        pictures: pictures,
                        sentences: sentences,
                        runs: runs,
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


  /// The sentence rows of the open pass, in the order it shows them.
  List<String> passRows(WidgetTester tester) => tester
      .widgetList<ListTile>(
        find.descendant(
          of: find.byType(PictureAssignmentScreen),
          matching: find.byType(ListTile),
        ),
      )
      .map((row) => (row.title! as Text).data!)
      .toList();

  /// The name line of every picture chip, in the pass's own order.
  List<String> passChips(WidgetTester tester) => tester
      .widgetList<ChoiceChip>(
        find.descendant(
          of: find.byType(PictureAssignmentScreen),
          matching: find.byType(ChoiceChip),
        ),
      )
      .map((chip) => ((chip.label as Column).children.first as Text).data!)
      .toList();

  /// The count line under picture [name]'s chip.
  String passCount(WidgetTester tester, String name) {
    final chips = tester.widgetList<ChoiceChip>(
      find.descendant(
        of: find.byType(PictureAssignmentScreen),
        matching: find.byType(ChoiceChip),
      ),
    );
    for (final chip in chips) {
      final column = chip.label as Column;
      if ((column.children.first as Text).data == name) {
        return (column.children[1] as Text).data!;
      }
    }
    throw StateError('no chip for $name');
  }

  Future<void> tapSentence(WidgetTester tester, String text) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PictureAssignmentScreen),
        matching: find.text(text),
      ),
    );
    await tester.pumpAndSettle();
  }

    /// The chip itself, not the sentence list's own label for the same picture
  /// (a held sentence shows its holder's name): the chip is the one inside a
  /// `ChoiceChip`, and there is exactly one of those per picture.
  Finder chipOf(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(ChoiceChip))
      .first;

  /// A library holding the reader's **own** content — no pre-set, because
  /// FR-014's story is a content **edited under** an assignment and a pre-set
  /// cannot be edited in place (016's own rule: editing a pre-set makes new
  /// content, with a new id, and the assignment would not follow it). Answers the
  /// store and the entry, so a case can edit the text between two visits.
  ///
  /// Every store call here runs inside `runAsync`: this is real file work, and
  /// work started on the test's own clock never calls back (012's own note).
  Future<(ContentStore, SavedContent)> ownLibrary(WidgetTester tester,
      String text) async {
    final store = ContentStore(
      directory: root,
      loadCatalog: () async => [],
      now: () => DateTime.utc(2026, 10, 14, 9),
    );
    final entry = await tester.runAsync(
      () => store.saveNew(text, language: 'en'),
    );
    return (store, entry!);
  }

  /// The reader's own assignment on the **old** text: sunset the first sentence,
  /// hills the second, forest the last two — in order, as the rule asks — then
  /// the prompt is left without rendering (the store keeps the assignment).
  Future<void> assignOnTheOldText(
    WidgetTester tester,
    ContentStore store,
  ) async {
    await openDialogWith(
      tester,
      ShortEngine(),
      RecordingEncoder(work),
      [_sunset, _hills, _forest],
      store: store,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReadingView)),
    )!;
    await tester.tap(find.text(l10n.assignmentOpenButton));
    await letWorkRun(
      tester,
      () => find.byType(PictureAssignmentScreen).evaluate().isNotEmpty,
    );
    await tapSentence(tester, 'One two.');
    await tester.tap(find.text(_hills));
    await tester.pumpAndSettle();
    await tapSentence(tester, 'Three four.');
    await tester.tap(find.text(_forest));
    await tester.pumpAndSettle();
    await tapSentence(tester, 'Five six.');
    await tapSentence(tester, 'Seven eight.');
    await tester.tap(find.text('Done'));
    await letWorkRun(
      tester,
      () => find.byType(PictureAssignmentScreen).evaluate().isEmpty,
    );
    await tester.tap(find.text('Cancel'));
    await letWorkRun(tester, () => find.text('Video format').evaluate().isEmpty);
  }

  group('the pass itself', () {
    late List<VideoSentence> sentences;
    late List<HeldPicture> pictures;

    setUp(() async {
      sentences = await sentencesOf();
      pictures = const [
        HeldPicture(name: _sunset, path: '/picks/pick_0_sunset.png'),
        HeldPicture(name: _hills, path: '/picks/pick_1_hills.png'),
      ];
    });

    testWidgets('shows the render\'s own sentences, and the pictures in their '
        'order', (tester) async {
      await openPass(tester, pictures: pictures, sentences: sentences);

      // The sentences are the render's own, in the render's own order: what the
      // reader assigns here is what the video will paint (D6).
      expect(passRows(tester), ['One two.', 'Three four.', 'Five six.']);
      expect(passChips(tester), [_sunset, _hills]);
      expect(passCount(tester, _sunset), 'No sentences assigned');
      expect(passCount(tester, _hills), 'No sentences assigned');
    });

    testWidgets('a tap gives the sentence to the picture selected, and the '
        'count moves', (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
      );

      await tapSentence(tester, 'One two.');
      expect(passCount(tester, _sunset), '1 sentence');
      await tapSentence(tester, 'Three four.');
      expect(passCount(tester, _sunset), '2 sentences');

      // The second picture carries the third sentence.
      await tester.tap(find.text(_hills));
      await tester.pumpAndSettle();
      await tapSentence(tester, 'Five six.');
      expect(passCount(tester, _hills), '1 sentence');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(popped, isTrue, reason: 'Done answers the reader\'s runs');
      final runs = given!.runs;
      expect(runs.map((run) => run.name), [_sunset, _hills]);
      expect(runs.first.spans, [
        (sentences[0].start, sentences[0].end),
        (sentences[1].start, sentences[1].end),
      ]);
      expect(runs.last.spans, [(sentences[2].start, sentences[2].end)]);
    });

    testWidgets('a sentence another picture holds says so', (tester) async {
      await openPass(tester, pictures: pictures, sentences: sentences);

      await tester.tap(find.text(_hills));
      await tester.pumpAndSettle();
      await tapSentence(tester, 'Five six.');
      // Back on the first picture, that sentence is visibly someone else's —
      // FR-002's "each picture's own sentences visible" (FR-005: a sentence
      // belongs to one picture).
      await tester.tap(find.text(_sunset));
      await tester.pumpAndSettle();

      final rows = tester.widgetList<ListTile>(
        find.descendant(
          of: find.byType(PictureAssignmentScreen),
          matching: find.byType(ListTile),
        ),
      );
      expect(rows.last.trailing, isA<Text>());
      expect((rows.last.trailing! as Text).data, _hills);
    });

    testWidgets('a stored run opens in force; Done answers it back',
        (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(
            name: _hills,
            spans: [(sentences[2].start, sentences[2].end)],
          ),
        ],
      );

      expect(passCount(tester, _hills), '1 sentence');
      expect(passCount(tester, _sunset), 'No sentences assigned');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final runs = given!.runs;
      expect(runs.map((run) => run.name), [_hills],
          reason: 'a picture holding nothing is not a decision');
      expect(runs.single.spans, [(sentences[2].start, sentences[2].end)]);
    });

    testWidgets('nothing assigned is answered as nothing', (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(given!.runs, isEmpty,
          reason: 'an empty answer is the no-assignment state (FR-009)');
    });

    testWidgets('leaving without Done answers nothing', (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
      );

      await tapSentence(tester, 'One two.');
      // The system's own back: the reader changed their mind.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(popped, isTrue, reason: 'the page popped: the reader left it');
      expect(given, isNull,
          reason: 'what the pass was handed stands until Done (FR-012\'s rule '
              'for a cancelled edit)');
    });
  });

  group('the pass\'s refusals, and the drag (US2)', () {
    late List<VideoSentence> sentences;
    late List<HeldPicture> pictures;

    setUp(() async {
      sentences = await sentencesOf();
      pictures = const [
        HeldPicture(name: _sunset, path: '/picks/pick_0_sunset.png'),
        HeldPicture(name: _hills, path: '/picks/pick_1_hills.png'),
      ];
    });

    /// The reason the pass is showing, or null when it is showing none.
    String? shownRefusal(WidgetTester tester) {
      final bars = tester.widgetList<SnackBar>(
        find.byType(SnackBar),
      );
      for (final bar in bars) {
        final content = bar.content;
        if (content is Text) return content.data;
      }
      return null;
    }

    Future<void> holdChip(WidgetTester tester, String name) async {
      await tester.longPress(chipOf(name));
      await tester.pumpAndSettle();
    }

    testWidgets('a sentence that is not next to the run is refused with its '
        'reason, and nothing moves', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(
            name: _sunset,
            spans: [(sentences[0].start, sentences[0].end)],
          ),
        ],
      );

      await tapSentence(tester, 'Five six.');

      expect(shownRefusal(tester), l10n.assignmentRefusedNotContinuous);
      expect(passCount(tester, _sunset), '1 sentence',
          reason: 'FR-012: a refusal leaves the assignment in force alone');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(given!.runs.single.spans,
          [(sentences[0].start, sentences[0].end)]);
    });

    testWidgets('the sentence right after the run joins it', (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(
            name: _sunset,
            spans: [(sentences[0].start, sentences[0].end)],
          ),
        ],
      );

      await tapSentence(tester, 'Three four.');

      expect(shownRefusal(tester), isNull);
      expect(passCount(tester, _sunset), '2 sentences');
    });

    testWidgets('a middle sentence refuses to be taken back; an end one goes',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(name: _sunset, spans: [
            for (final sentence in sentences)
              (sentence.start, sentence.end),
          ]),
        ],
      );

      await tapSentence(tester, 'Three four.');
      expect(shownRefusal(tester), l10n.assignmentRefusedMiddle);
      expect(passCount(tester, _sunset), '3 sentences');

      await tapSentence(tester, 'One two.');
      expect(passCount(tester, _sunset), '2 sentences',
          reason: 'an end of the run is always free to take back');
    });

    testWidgets('a picture holding sentences refuses the drag, with its reason',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(
            name: _sunset,
            spans: [(sentences[0].start, sentences[0].end)],
          ),
        ],
      );

      await holdChip(tester, _sunset);

      expect(shownRefusal(tester), l10n.assignmentRefusedHoldsSentences);
      expect(passChips(tester), [_sunset, _hills],
          reason: 'the order in force is unchanged (FR-015)');
    });

    testWidgets('a picture holding nothing drags, and the answer carries the '
        'new order', (tester) async {
      await openPass(
        tester,
        pictures: pictures,
        sentences: sentences,
        runs: [
          PictureRun(
            name: _hills,
            spans: [(sentences[0].start, sentences[0].end)],
          ),
        ],
      );

      // The hold starts on the chip holding nothing and ends on the other one:
      // the same gesture 012's own picker uses for its pictures.
      final gesture = await tester.startGesture(
        tester.getCenter(chipOf(_sunset)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(chipOf(_hills)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(passChips(tester), [_hills, _sunset],
          reason: 'the pass shows the new order (FR-015)');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(given!.pictures.map((picture) => picture.name), [_hills, _sunset],
          reason: 'and the order it answers with is the order the render walks');
      expect(given!.runs.map((run) => run.name), [_hills],
          reason: 'the runs follow their pictures');
    });
  });

  group('the stale warning, before the render (US5)', () {
    /// Every case starts the same way: the reader assigns on the text as it was,
    /// the content changes under the assignment, and they come back to the video
    /// screen and pick the same three files again — which is when the stored
    /// runs re-attach by name (FR-010) and one of them turns out not to fit.
    Future<({ShortEngine engine, RecordingEncoder encoder, AppLocalizations l10n})>
        stalelyAssigned(WidgetTester tester) async {
      final (store, entry) = await ownLibrary(tester, _oldText);
      await assignOnTheOldText(tester, store);

      // The content changes under the assignment — the reader's own edit
      // (016's path) — and they come back to the video screen: a **new page**,
      // so the content is read again (`pumpWidget` alone would keep the loaded
      // state, and the old text with it).
      await tester.runAsync(() => store.update(entry, _changedText));
      await tester.pumpWidget(const SizedBox());
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await openDialogWith(
        tester,
        engine,
        encoder,
        [_sunset, _hills, _forest],
        store: store,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReadingView)),
      )!;
      expect(
        find.text(l10n.assignmentSentenceCount(4)),
        findsOneWidget,
        reason: 'the stored assignment came back with the same files (FR-010)',
      );
      return (engine: engine, encoder: encoder, l10n: l10n);
    }

    testWidgets('the warning comes before the render\'s own line, names what '
        'no longer fits, and its tap opens the pass on that picture',
        (tester) async {
      final fixture = await stalelyAssigned(tester);
      final l10n = fixture.l10n;

      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await tester.tap(find.text('Start'));
        await letWorkRun(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        expect(
          logs.where((line) => line.startsWith('klhu render pictures=')),
          isEmpty,
          reason: 'SC-008: the warning is before the render\'s own line',
        );
      });

      expect(find.text(l10n.assignmentStaleWarning(2)), findsOneWidget,
          reason: 'two runs no longer fit');
      expect(find.text(l10n.assignmentStaleDetail(_hills, '1')), findsOneWidget,
          reason: 'named, with what it held');
      expect(find.text(l10n.assignmentStaleDetail(_forest, '2')),
          findsOneWidget);

      // The telling is the gesture (FR-014): the line that names a picture.
      await tester.tap(find.text(l10n.assignmentStaleDetail(_hills, '1')));
      await letWorkRun(
        tester,
        () => find.byType(PictureAssignmentScreen).evaluate().isNotEmpty,
      );

      expect(tester.widget<ChoiceChip>(chipOf(_hills)).selected, isTrue,
          reason: 'the pass opens with the offending picture in view');
      expect(passCount(tester, _hills), 'No sentences assigned',
          reason: 'the run that no longer fits is not in force');
      expect(passCount(tester, _sunset), '1 sentence',
          reason: 'and the one that still fits stands');
      expect(passCount(tester, _forest), 'No sentences assigned');
    });

    testWidgets('started anyway, the render uses the runs that still fit and '
        'the current text', (tester) async {
      final fixture = await stalelyAssigned(tester);
      final l10n = fixture.l10n;
      final encoder = fixture.encoder;

      // What the resolver answers for this fixture, asserted here so the
      // frames below are read against a pinned story: the first sentence's run
      // stands, the two that named later sentences do not. The stored runs are
      // the old text's own spans, which is exactly what the page stored.
      final before = await videoSentencesFrom(
        content: _oldText,
        position: 0,
        loadVoice: (language) async => null,
      );
      expect(before, hasLength(4), reason: 'fixture drift');
      final now = await videoSentencesFrom(
        content: _changedText,
        position: 0,
        loadVoice: (language) async => null,
      );
      final stored = [
        PictureRun(name: _sunset, spans: [(before[0].start, before[0].end)]),
        PictureRun(name: _hills, spans: [(before[1].start, before[1].end)]),
        PictureRun(name: _forest, spans: [
          (before[2].start, before[2].end),
          (before[3].start, before[3].end),
        ]),
      ];
      final answer = assignmentsFor(
        sentences: now,
        pictures: [
          for (final name in [_sunset, _hills, _forest])
            HeldPicture(name: name, path: '/picks/$name'),
        ],
        runs: stored,
      );
      expect(answer.stale.map((run) => run.name), [_hills, _forest]);
      expect(
        runsThatFit(answer, stored).single.name,
        _sunset,
        reason: 'the runs the reader made, not the fallback answer',
      );

      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await tester.tap(find.text('Start'));
        await letWorkRun(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        // The warning's own Start: the reader starts the render anyway. `.last`
        // is the warning — the video prompt is an `AlertDialog` too, and it sits
        // under this one with a Start of its own.
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog).last,
            matching: find.text(l10n.videoStartButton),
          ),
        );
        await letWorkRun(tester, () => encoder.finishes == 1);
      });

      final line = logs.firstWhere(
        (line) => line.startsWith('klhu render pictures='),
      );
      expect(line, contains('sentences=4'),
          reason: 'the text in force, not the one the runs were made on');
      expect(line, contains('pictures=3'));

      final ranges = RegExp(r'ranges=([^ ]*)').firstMatch(line)!.group(1)!;
      final split = ranges.split(',');
      expect(split, hasLength(3), reason: line);
      expect(int.parse(split[0].split('..')[0]), 0,
          reason: 'the run that still fits opens the video (FR-014)');
      for (var i = 1; i < split.length; i++) {
        expect(int.parse(split[i].split('..')[0]),
            int.parse(split[i - 1].split('..')[1]) + 1,
            reason: 'the ranges still meet at sentence boundaries');
      }

      final background = Theme.of(
        tester.element(find.byType(ReadingView)),
      ).scaffoldBackgroundColor.toARGB32();
      final early = await tester.runAsync(
        () => pixelOf(encoder.frames.first.png),
      );
      final late = await tester.runAsync(
        () => pixelOf(encoder.frames.last.png),
      );
      expect(early, isNot(background),
          reason: 'the assignment\'s own picture still reaches the frames');
      expect(early, isNot(late),
          reason: 'and the pictures that still hold sentences are painted');
    });
  });

  group('the dialog\'s own seam', () {
    testWidgets('the dialog offers the assignment line, and it waits for a '
        'picture', (tester) async {
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await tester.pumpWidget(pageWith(engine, encoder));
      await loadPageContent(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReadingView)),
      )!;

      await tester.tap(find.byTooltip('Video'));
      await letWorkRun(
        tester,
        () => find.text('Video format').evaluate().isNotEmpty,
      );

      // Offered beside the pick (FR-001) — and with no picture picked there is
      // nothing to assign a sentence to, so it does not open.
      final line = find.text(l10n.assignmentOpenButton);
      expect(line, findsOneWidget);
      expect(find.text(l10n.assignmentNothingAssigned), findsOneWidget,
          reason: 'the line says what is assigned now: nothing');
      await tester.tap(line);
      await tester.pump();
      expect(find.byType(PictureAssignmentScreen), findsNothing);
      expect(find.text('Video format'), findsOneWidget,
          reason: 'the dialog is still the page\'s own');
    });

    testWidgets('the line opens the pass on the sentences the render will '
        'speak', (tester) async {
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await openDialogWith(tester, engine, encoder, [_sunset, _hills]);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReadingView)),
      )!;

      await tester.tap(find.text(l10n.assignmentOpenButton));
      await letWorkRun(
        tester,
        () => find.byType(PictureAssignmentScreen).evaluate().isNotEmpty,
      );

      expect(passRows(tester), ['One two.', 'Three four.', 'Five six.'],
          reason: 'the page resolved the video\'s own sentences, once (D6)');
      expect(passChips(tester), [_sunset, _hills],
          reason: 'and the pictures in the order they were picked');
    });

    testWidgets('a sentence highlighted is still the whole content, from its '
        'first sentence (020 FR-017)', (tester) async {
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await tester.pumpWidget(pageWith(engine, encoder));
      await loadPageContent(tester);

      // The reader taps the content's **last** sentence, which puts the page's
      // own position in force — the state 012 FR-004 used to make the video
      // start at. 020 FR-017 supersedes that half: the video is the whole
      // content, from its first sentence to its last, and the position decides
      // where a READ starts only.
      await tapSentenceInContent(tester, 'Five six.');
      expect(hasYellow(tester, 'Five six.'), isTrue,
          reason: 'the tap put the page\'s position in force (010/016)');

      await tester.tap(find.byTooltip('Video'));
      await letWorkRun(
        tester,
        () => find.text('Video format').evaluate().isNotEmpty,
      );

      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await tester.tap(find.text('Start'));
        await letWorkRun(tester, () => encoder.finishes == 1);
      });

      final line = logs.firstWhere((l) => l.startsWith('klhu render pictures='));
      expect(line, contains('sentences=3'),
          reason: 'the whole content, wherever the page is: the highlighted '
              'sentence does not cut the video');
      final first = logs.firstWhere((l) => l.startsWith('klhu render slot=0/'));
      expect(first, contains('span=0..8'),
          reason: 'and it opens on the content\'s own first sentence');
    });

    testWidgets('the runs reach the renderer\'s own line and the frames',
        (tester) async {
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await openDialogWith(tester, engine, encoder, [_sunset, _hills]);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReadingView)),
      )!;

      // The first picture keeps the first sentence; the second takes the rest.
      await tester.tap(find.text(l10n.assignmentOpenButton));
      await letWorkRun(
        tester,
        () => find.byType(PictureAssignmentScreen).evaluate().isNotEmpty,
      );
      await tapSentence(tester, 'One two.');
      await tester.tap(find.text(_hills));
      await tester.pumpAndSettle();
      await tapSentence(tester, 'Three four.');
      await tapSentence(tester, 'Five six.');
      await tester.tap(find.text('Done'));
      await letWorkRun(
        tester,
        () => find.byType(PictureAssignmentScreen).evaluate().isEmpty,
      );
      expect(find.text(l10n.assignmentSentenceCount(3)), findsOneWidget,
          reason: 'the dialog says what is assigned now');

      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await tester.tap(find.text('Start'));
        await letWorkRun(tester, () => encoder.finishes == 1);
        await letWorkRun(
          tester,
          () => find.byKey(const ValueKey('video player')).evaluate().isNotEmpty,
        );
      });

      // The renderer's own line, parsed the way the device rows read it: the
      // ranges are the reader's runs, in order.
      final line = logs.firstWhere((l) => l.startsWith('klhu render pictures='));
      final ranges = RegExp(r'ranges=([^ ]*)').firstMatch(line)!.group(1)!;
      final split = ranges.split(',');
      expect(split, hasLength(2), reason: line);
      final first = RegExp(r'^(\d+)\.\.(\d+)$').firstMatch(split[0])!;
      final second = RegExp(r'^(\d+)\.\.(\d+)$').firstMatch(split[1])!;
      expect(int.parse(first.group(1)!), 0,
          reason: 'the first picture opens the video');
      expect(int.parse(first.group(2)!), int.parse(second.group(1)!) - 1,
          reason: 'the two ranges meet at a sentence boundary (FR-026)');

      // And the assignment reached the frames. The encoder records the frames
      // it was handed, each once with the run it stands for (012's own shape),
      // so the video's first and last frames are the two pictures' own colours
      // — and neither is the plain background a render with no picture paints.
      final background = Theme.of(
        tester.element(find.byType(ReadingView)),
      ).scaffoldBackgroundColor.toARGB32();
      final early = await tester.runAsync(
        () => pixelOf(encoder.frames.first.png),
      );
      final late = await tester.runAsync(
        () => pixelOf(encoder.frames.last.png),
      );
      expect(early, isNot(background),
          reason: 'the first sentence paints the first picture');
      expect(late, isNot(background),
          reason: 'and the last sentence paints the second');
      expect(early, isNot(late),
          reason: 'the two pictures are two different pictures');
    });

    testWidgets('the reader can render without assigning, and it is 012\'s own '
        'video', (tester) async {
      final engine = ShortEngine();
      final encoder = RecordingEncoder(work);
      await openDialogWith(tester, engine, encoder, [_sunset, _hills]);

      final logs = <String>[];
      await withCapturedLogs(logs, () async {
        await tester.tap(find.text('Start'));
        await letWorkRun(tester, () => encoder.finishes == 1);
      });

      final line = logs.firstWhere((l) => l.startsWith('klhu render pictures='));
      expect(
        RegExp(r'ranges=([^ ]*)').firstMatch(line)!.group(1),
        '0..65,66..137',
        reason: 'two pictures over three sentences, 012\'s own even split: '
            'two sentences then one — the second range opens at sentence 3\'s '
            'own first frame',
      );
    });
  });
}

/// Taps the sentence holding [text] in the page's own reading text: the
/// reader's own gesture, which sets the page's position (010/016).
Future<void> tapSentenceInContent(WidgetTester tester, String text) async {
  final content = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText() == _text,
  );
  final render = tester.renderObject<RenderParagraph>(content);
  final at = _text.indexOf(text);
  expect(at, isNot(-1), reason: 'the fixture holds "$text"');
  final box = render
      .getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: at + 3),
      )
      .first;
  await tester.tapAt(
    render.localToGlobal(
      Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
    ),
  );
  await tester.pump();
}

/// Whether [text] is painted with the page's own highlight band: the page's
/// position is visible on screen, which is what makes the case above about a
/// state the reader is actually in.
bool hasYellow(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasYellow(rich.text, text)) return true;
  }
  return false;
}

bool _spanHasYellow(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text && span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (_spanHasYellow(child, text)) return true;
    }
  }
  return false;
}

/// Runs [body] with `debugPrint` captured — the app's own evidence lines are
/// what the device rows read, so their shape is read here too.
///
/// `debugPrint` is restored in the body's own `finally` rather than a tearDown:
/// the binding asserts it is back to normal at the end of the test BODY.
Future<void> withCapturedLogs(
  List<String> logs,
  Future<void> Function() body,
) async {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
}
