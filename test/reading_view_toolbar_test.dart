/// The reading page's toolbar (spec 011 FR-026): quickstart scenario 22.
///
/// In portrait the brand and the language keep the bar's own row and the actions
/// take a row under them, because a portrait window cannot hold both: measured
/// on the reader's phone (2026-10-06) the window is 360 dp wide and the bar's
/// controls need 488 dp, which squeezed Play video to 16 dp and pushed Share and
/// Delete video off the edge entirely. A landscape window has the room and keeps
/// the shipped single row — and in both arrangements every action the page
/// offers is drawn inside the window.
///
/// **The 2026-10-06 amendment (012 FR-033) is what those three became**: one
/// `Videos` action, so the portrait bar carries six where it carried eight. Six
/// 48 dp targets are 288 dp against the 360 dp the row offers, so this bar is
/// back to Material's own density — the 40 dp it was squeezed to (011's own
/// record of that compromise) is gone with the actions that paid for it. The
/// buttons are therefore asserted at their own size, not only for fitting.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/services/localization_service.dart';
import 'package:klhu/video_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// A read that parks: the page the toolbar is looked at is idle.
class QuietReader implements Reader {
  bool hold = true;
  bool speaking = false;
  bool paused = false;
  int stops = 0;
  Completer<void>? _parked;

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> paragraphs, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {
    speaking = paragraphs.isNotEmpty;
    if (hold) {
      final parked = Completer<void>();
      _parked = parked;
      await parked.future;
    }
    speaking = false;
  }

  @override
  Future<void> stop() async {
    stops++;
    speaking = false;
    paused = false;
    _parked?.complete();
    _parked = null;
  }

  @override
  Future<void> speak(String text, String language) async {}

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
  Future<List<VoiceEntry>> voicesFor(String language) async => [];

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

/// The library, faked: enough to keep a video and to answer for it, so the page
/// offers the kept video's own three actions (FR-022).
class FakeFileStore implements VideoFileStore {
  final kept = <String, String>{};
  int _next = 1;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> keep({
    required String workingPath,
    required String displayName,
    String? previousUri,
  }) async {
    final uri = 'content://media/external/video/media/${_next++}';
    kept[uri] = displayName;
    if (previousUri != null) kept.remove(previousUri);
    return uri;
  }

  @override
  Future<void> share({required String source}) async {}

  @override
  Future<bool> delete({required String uri}) async => kept.remove(uri) != null;

  @override
  Future<bool> exists({required String uri}) async => kept.containsKey(uri);
}

void main() {
  late Directory root;
  late Directory work;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('klhu-toolbar-test');
    work = Directory.systemTemp.createTempSync('klhu-toolbar-work');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  /// The page in the window the platform reports, with this device's own
  /// language control (011 FR-025's second row is about what the bar holds
  /// beside it).
  Future<void> openPage(
    WidgetTester tester, {
    Size viewport = const Size(360, 780),
    bool withVideo = false,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final files = FakeFileStore();
    if (withVideo) {
      await VideoRecordStore(files: files).keep(
        'preset_en_sample',
        workingPath: '${work.path}/working.mp4',
        displayName: 'One two…mp4',
      );
    }
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MaterialApp(
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
          contentStore: pageStore(root),
          localizationService: LocalizationService(prefs),
          videoFileStore: files,
        ),
      ),
    );
    await loadPageContent(tester);
    await tester.pump();
  }

  /// The action [label] names — however the page presents it (the requirement
  /// is that it is offered, not which widget carries it).
  Finder actionFor(String label) {
    final byTooltip = find.byTooltip(label);
    return byTooltip.evaluate().isNotEmpty ? byTooltip : find.text(label);
  }

  /// The language control the page draws in the bar's own row.
  final language = find.byType(DropdownButton<String>);

  const baseActions = <String>[
    'Appearance',
    'Contents',
    'Text type',
    'Voice',
  ];

  /// What a content with a kept video adds (FR-022/FR-033): one action that
  /// opens the videos as a list, where each row carries its own share and
  /// delete. The three actions it replaced are asserted away below.
  const keptVideoActions = <String>['Videos'];

  /// The three the amendment withdrew from the page — a control that came back
  /// on its own would be a second way to act on one video.
  const withdrawnActions = <String>[
    'Play video',
    'Share',
    'Delete video',
  ];

  testWidgets('portrait: the actions take a row under the brand and the language', (
    tester,
  ) async {
    await openPage(tester);

    expect(language, findsOneWidget, reason: 'the language is on the bar');
    expect(
      tester.getTopLeft(actionFor('Appearance')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(language).dy),
      reason: 'nothing but the language shares the bar\'s own row',
    );

    // Every action shares that one row — one row, not one per button.
    final tops = baseActions
        .map((label) => tester.getTopLeft(actionFor(label)).dy)
        .toSet();
    expect(tops, hasLength(1), reason: 'the actions are one row, not several');
  });

  testWidgets('portrait: every action is drawn inside the window', (
    tester,
  ) async {
    await openPage(tester, withVideo: true);

    for (final label in [...baseActions, ...keptVideoActions]) {
      final finder = actionFor(label);
      expect(finder, findsOneWidget, reason: '$label is offered');
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0.0), reason: '$label is on screen');
      expect(
        rect.right,
        lessThanOrEqualTo(360.0),
        reason: '$label is not pushed off the edge',
      );
    }
  });

  testWidgets('landscape: the actions stay beside the language, as shipped', (
    tester,
  ) async {
    await openPage(tester, viewport: const Size(780, 360), withVideo: true);

    final row = tester.getCenter(language).dy;
    for (final label in [...baseActions, ...keptVideoActions]) {
      final rect = tester.getRect(actionFor(label));
      expect(
        rect.center.dy,
        closeTo(row, 1.0),
        reason: '$label shares the bar\'s own row',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(780.0),
        reason: '$label is not pushed off the edge',
      );
    }
  });

  testWidgets('portrait: every action carries Material\'s own 48 dp target', (
    tester,
  ) async {
    // The 2026-10-06 amendment (012 FR-033) took the portrait bar from eight
    // actions to six, so the compact density this row was measured for is no
    // longer paid for: six 48 dp targets are 288 dp against the 360 dp the row
    // offers. What is asserted is the target the reader can hit — the widget's
    // own semantics rect, which is what the device's own dump reports, not the
    // painted box (Material draws a 40 dp button inside a 48 dp target).
    // The semantics tree is what carries the target a reader can hit, and the
    // framework checks the handle itself, so it goes back at the end of the
    // body rather than in a tear-down.
    final handle = tester.ensureSemantics();
    await openPage(tester, withVideo: true);

    for (final label in [...baseActions, ...keptVideoActions]) {
      final target = tester.getSemantics(actionFor(label)).rect.size;
      expect(target.height, greaterThanOrEqualTo(48.0),
          reason: '$label is a full-height target');
      expect(target.width, greaterThanOrEqualTo(48.0),
          reason: '$label is a full-width target');
    }
    handle.dispose();
  });

  testWidgets('the three actions the amendment withdrew are off the page', (
    tester,
  ) async {
    // FR-022/FR-033: play, share and delete act on the content's videos as a
    // list. A page control that came back would be a second way to act on the
    // newest video alone, and the newest alone is what the old actions could
    // reach.
    await openPage(tester, withVideo: true);

    for (final label in withdrawnActions) {
      expect(find.byTooltip(label), findsNothing,
          reason: '$label was replaced by Videos');
    }
  });
}
