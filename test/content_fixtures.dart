/// Shared fixtures for the content library tests (spec 008).
///
/// The texts mirror the shipped pre-sets in `assets/content/presets.json` —
/// the same strings the page shows on a fresh launch (the catalog fallback).
/// `lib/sample_texts.dart` no longer exists: content is data, not code.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

const String kSampleEnText = '''
The sun rose over the quiet town. Birds sang in the tall trees.

Flutter makes it easy to build beautiful apps. A single codebase runs on both iOS and Android. Tap any sentence to hear it read aloud.

This is the third paragraph. It tests paragraph-level resolution across blank lines. Each block should highlight and speak in order.
''';

const String kSampleZhText = '''
清晨的阳光洒在安静的小镇上。鸟儿在高大的树上歌唱。

Flutter 让构建精美应用变得简单。同一套代码可以运行在 iOS 和 Android 上。点击任意句子即可听到朗读。

这是第三段。它用于测试段落级别的解析。每个段落都应该按顺序高亮并朗读。
''';

const String kSampleEsText = '''
El sol salió sobre el pueblo tranquilo. Los pájaros cantaron en los árboles altos.

Flutter hace fácil crear aplicaciones hermosas. El mismo código funciona en iOS y Android. Toca cualquier oración para escucharla en voz alta.

Este es el tercer párrafo. Prueba la lectura por párrafos entre líneas vacías. Cada bloque se resalta y se lee en orden.
''';

const List<String> kSampleTexts = [kSampleEnText, kSampleZhText, kSampleEsText];

/// The three pre-sets in catalog shape, in the order the catalog ships them.
List<PresetContent> samplePresets() => [
      PresetContent(
        id: 'preset_en_sample',
        language: 'en',
        text: kSampleEnText,
      ),
      PresetContent(
        id: 'preset_zh_sample',
        language: 'zh-Hans',
        text: kSampleZhText,
      ),
      PresetContent(
        id: 'preset_es_sample',
        language: 'es',
        text: kSampleEsText,
      ),
    ];

/// A store on [root] seeded from [samplePresets], on a fixed clock.
ContentStore sampleStore(Directory root, {List<PresetContent>? catalog}) =>
    ContentStore(
      directory: root,
      loadCatalog: () async => catalog ?? samplePresets(),
      now: () => DateTime.utc(2026, 9, 23, 10, 22, 3),
    );

/// A temp directory for one test, removed on the way out.
Directory makeTempRoot(String prefix) =>
    Directory.systemTemp.createTempSync(prefix);

/// Pumps until a screen's async content load has landed.
///
/// The store's chained file IO and the asset read only complete in a real
/// event-loop turn, while the storage deadline is a fake-clock timer that only
/// fires when a pump advances time — so the wait does both.
Future<void> loadPageContent(WidgetTester tester, {int rounds = 6}) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  for (var round = 0; round < rounds; round++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A store seeded from [samplePresets] on [root], for the many widget tests that
/// just need the page to have content. No platform channel is involved (the
/// directory is injected), so the load completes under `loadPageContent`.
ContentStore pageStore(Directory root) => ContentStore(
      directory: root,
      loadCatalog: () async => samplePresets(),
      now: () => DateTime.utc(2026, 9, 23, 10, 22, 3),
    );

Directory? _sharedRoot;
ContentStore? _sharedStore;

/// [pageStore] for view instances built outside `main()` (helpers, local widget
/// classes) where a setUp-created root is not in scope. One temp dir per file.
ContentStore sharedPageStore() {
  _sharedRoot ??= Directory.systemTemp.createTempSync('klhu-page-shared');
  return _sharedStore ??= pageStore(_sharedRoot!);
}
