import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/language.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/reading_view.dart';
import 'package:klhu/voice_store.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mixed =
    'The sun rose over the quiet town. Birds sang.\n\n清晨的阳光洒在安静的小镇上。鸟儿在歌唱。';

Future<VoiceChoice?> _noVoice(String language) async => null;

class MixedFakeReader implements Reader {
  List<ParagraphSpeech> paragraphs = [];
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<void> speak(String text, String language) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  bool get isSpeaking => false;

  @override
  bool get isPaused => false;

  @override
  Future<List<VoiceEntry>> voicesFor(String language) async => [];

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> ps, {
    void Function(int index)? onParagraphStart,
  }) async {
    paragraphs = ps;
    // Mirror ReaderService: progress fires in paragraph order pre-utterance.
    for (var i = 0; i < ps.length; i++) {
      onParagraphStart?.call(i);
    }
  }

  @override
  Future<void> previewVoice(VoiceEntry voice, String sampleText) async {}
}

void main() {
  group('resolveParagraphSpeeches (unit)', () {
    test('mixed page splits into per-paragraph speeches in order', () async {
      final speeches =
          await resolveParagraphSpeeches(_mixed, 0, _mixed.length, _noVoice);
      expect(speeches.length, 2);
      expect(speeches[0].language, 'en');
      expect(speeches[1].language, 'zh-Hans');
      expect(speeches[0].text, contains('The sun rose'));
      expect(speeches[1].text, contains('清晨'));
      expect(speeches[0].voice, isNull); // no saved voice → OS default
    });

    test('sentence range inherits enclosing paragraph language', () async {
      // Inside the zh paragraph, first sentence only.
      final zhStart = _mixed.indexOf('清晨');
      final zhEnd = _mixed.indexOf('。') + 1;
      final speeches =
          await resolveParagraphSpeeches(_mixed, zhStart, zhEnd, _noVoice);
      expect(speeches.length, 1);
      expect(speeches.single.language, 'zh-Hans');
      expect(speeches.single.text, _mixed.substring(zhStart, zhEnd));
    });

    test('saved voice attaches to its language paragraph', () async {
      Future<VoiceChoice?> loader(String language) async => language == 'en'
          ? const VoiceChoice(language: 'en', name: 'en-b', locale: 'en-GB')
          : null;
      final speeches =
          await resolveParagraphSpeeches(_mixed, 0, _mixed.length, loader);
      expect(speeches[0].voice?.name, 'en-b');
      expect(speeches[1].voice, isNull);
    });
  });

  group('reading view mixed read (widget)', () {
    testWidgets('Read page on edited mixed text speaks per-paragraph voices',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = MixedFakeReader();
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
          home: ReadingView(reader: fake)),
      );

      // Paste box + Load are gone (003 US2): type directly in EDIT mode.
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), _mixed);
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();

      expect(fake.paragraphs.length, 2);
      expect(fake.paragraphs[0].language, 'en');
      expect(fake.paragraphs[1].language, 'zh-Hans');
    });
  });

  group('US3 paragraph tracking (003)', () {
    testWidgets('highlight advances per paragraph, clears on Stop',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _ManualFakeReader();
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
          home: ReadingView(reader: fake)),
      );
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      expect(fake.progress, isNotNull);

      fake.progress!(0);
      await tester.pump();
      expect(_hasYellow(tester, fake.paragraphs[0].text), isTrue);
      fake.progress!(2);
      await tester.pump();
      expect(_hasYellow(tester, fake.paragraphs[2].text), isTrue);
      expect(_hasYellow(tester, fake.paragraphs[0].text), isFalse);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(_hasAnyYellow(tester), isFalse);
    });

    testWidgets('stale progress after Stop never re-highlights',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _ManualFakeReader();
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
          home: ReadingView(reader: fake)),
      );
      await tester.tap(find.byTooltip('Read page'));
      await tester.pump();
      final progress = fake.progress!;
      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      // Late callback from the stopped loop: generation guard drops it.
      progress(0);
      await tester.pump();
      expect(_hasAnyYellow(tester), isFalse);
    });
  });
}

/// Yellow-highlight span scan over the reading RichText.
bool _spanHasYellow(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text &&
        span.style?.backgroundColor == Colors.yellow) {
      return true;
    }
    if (span.children != null) {
      for (final child in span.children!) {
        if (_spanHasYellow(child, text)) return true;
      }
    }
  }
  return false;
}

bool _hasYellow(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasYellow(rich.text, text)) return true;
  }
  return false;
}

bool _spanHasAnyYellow(InlineSpan span) {
  if (span is TextSpan) {
    if (span.style?.backgroundColor == Colors.yellow) return true;
    if (span.children != null) {
      for (final child in span.children!) {
        if (_spanHasAnyYellow(child)) return true;
      }
    }
  }
  return false;
}

bool _hasAnyYellow(WidgetTester tester) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanHasAnyYellow(rich.text)) return true;
  }
  return false;
}

/// Manual-drive fake: captures the progress callback and hangs mid-speech
/// so tests observe tracking; Stop releases the hang.
class _ManualFakeReader extends MixedFakeReader {
  void Function(int)? progress;
  Completer<void>? _release;

  @override
  Future<void> speakParagraphs(
    List<ParagraphSpeech> ps, {
    void Function(int index)? onParagraphStart,
  }) async {
    paragraphs = ps;
    progress = onParagraphStart;
    _release = Completer<void>();
    await _release!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _release?.complete();
  }
}
