import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content_fixtures.dart';
import 'dart:io';

// T019: TalkBack operability via semantics (manual double-tap on the
// emulator succeeds ~1/10 across ALL buttons — system-wide emulator
// timing, not app-specific). These tests prove what TalkBack needs:
// every control exposes a tap action + label, selected state announced.

class _SemFakeReader implements Reader {
  @override
  Future<void> speak(String text, String language) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  bool get isSpeaking => false;
  @override
  bool get isPaused => false;
  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => language == 'en'
      ? const [VoiceEntry(name: 'en-a', locale: 'en-US')]
      : const [VoiceEntry(name: 'zh-a', locale: 'zh-Hans-CN')];
  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> ps, {
    void Function(SpokenSentence spoken)? onSentenceStart,
  }) async {}
  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('klhu-page-test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('T019 talkback semantics', () {
    testWidgets('reading view exposes Voice action with tap + label',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(home: ReadingView(reader: _SemFakeReader(), contentStore: pageStore(root))),
      );
      await loadPageContent(tester);
      await tester.pumpAndSettle();
      final voiceBtn = find.byTooltip('Voice');
      expect(voiceBtn, findsOneWidget);
      expect(
        tester.getSemantics(voiceBtn),
        matchesSemantics(
          tooltip: 'Voice',
          hasTapAction: true,
          hasFocusAction: true,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('picker rows expose tap action; selection announced',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        SharedPreferences.setMockInitialValues({});
        final fake = _SemFakeReader();
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
            ],
            home: VoicePickerScreen(
              reader: fake,
              store: VoiceStore(),
              language: 'en',
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Row tappable.
        final row = find.text('en-a');
        expect(row, findsOneWidget);
        expect(
          tester.getSemantics(find.byType(ListTile).first),
          matchesSemantics(
            hasTapAction: true,
            hasFocusAction: true,
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            isFocusable: true,
            hasSelectedState: true,
          ),
        );
        // Tap selects; merged tile semantics announce selection (no marker).
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsNothing);
        final selectedTile = find.byWidgetPredicate(
          (w) => w is ListTile && w.selected,
        );
        expect(selectedTile, findsOneWidget);
        // Selected STATE (not a label): TalkBack announces "selected" from
        // the flag that ListTile.selected sets — no marker widget needed.
        expect(
          tester.getSemantics(selectedTile),
          matchesSemantics(
            hasTapAction: true,
            hasFocusAction: true,
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            isFocusable: true,
            hasSelectedState: true,
            isSelected: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
