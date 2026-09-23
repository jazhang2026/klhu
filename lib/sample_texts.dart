/// Bundled sample texts for tap-to-resolve read-aloud (EN + zh-Hans + es).
/// Used by T003 onward; spoken via [reader_service] with per-locale voices.
class SampleTexts {
  static const String en = '''
The sun rose over the quiet town. Birds sang in the tall trees.

Flutter makes it easy to build beautiful apps. A single codebase runs on both iOS and Android. Tap any sentence to hear it read aloud.

This is the third paragraph. It tests paragraph-level resolution across blank lines. Each block should highlight and speak in order.
''';

  static const String zhHans = '''
清晨的阳光洒在安静的小镇上。鸟儿在高大的树上歌唱。

Flutter 让构建精美应用变得简单。同一套代码可以运行在 iOS 和 Android 上。点击任意句子即可听到朗读。

这是第三段。它用于测试段落级别的解析。每个段落都应该按顺序高亮并朗读。
''';

  /// Latin American Spanish (spec 007): the accented characters and function
  /// words here are exactly what [detectLanguage]'s Spanish rule keys on.
  static const String es = '''
El sol salió sobre el pueblo tranquilo. Los pájaros cantaron en los árboles altos.

Flutter hace fácil crear aplicaciones hermosas. El mismo código funciona en iOS y Android. Toca cualquier oración para escucharla en voz alta.

Este es el tercer párrafo. Prueba la lectura por párrafos entre líneas vacías. Cada bloque se resalta y se lee en orden.
''';

  static const List<String> all = [en, zhHans, es];
}
