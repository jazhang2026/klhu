/// 025 — the picked document's cached copy is burned once its bytes are read
/// (SC-003, FR-003: the only copy while reading is the one in memory).
///
/// `file_selector`'s Android side stages a `content://` pick at
/// `{cacheDir}/{uuid}/{name}` (`FileUtils.java`), and never deletes it. The
/// reader's own rule (2026-10-26: 内存副本只用于阅读，读完即焚) makes that copy the
/// app's business, so `burnCachedCopy` deletes it — and only it: a path the
/// reader actually owns is left alone, because deleting the reader's document
/// would be data loss, not cleanup.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/document_picker.dart';

void main() {
  late Directory cache;
  late Directory readerFiles;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('klhu-cache-test');
    readerFiles = await Directory.systemTemp.createTemp('klhu-owner-test');
  });

  tearDown(() {
    for (final Directory dir in <Directory>[cache, readerFiles]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  test('the platform’s staged copy is deleted once its bytes are read', () async {
    // The shape file_selector leaves behind: cache/<uuid>/<name>.
    final Directory staged = Directory('${cache.path}/432143d9-30d2')
      ..createSync(recursive: true);
    final File copy = File('${staged.path}/article.txt')
      ..writeAsStringSync('深秋的夜来得很早。');
    expect(copy.existsSync(), isTrue);

    expect(await burnCachedCopy(copy.path, cacheRoot: cache), isTrue);
    expect(copy.existsSync(), isFalse);
  });

  test('a file the reader owns is never deleted', () async {
    final File own = File('${readerFiles.path}/article.txt')
      ..writeAsStringSync('my own document');
    expect(await burnCachedCopy(own.path, cacheRoot: cache), isFalse);
    expect(own.existsSync(), isTrue);
    expect(own.readAsStringSync(), 'my own document');
  });

  test('an empty path, or one already gone, is answered without throwing',
      () async {
    expect(await burnCachedCopy('', cacheRoot: cache), isFalse);
    expect(
      await burnCachedCopy('${cache.path}/never-written.txt', cacheRoot: cache),
      isFalse,
    );
  });

  test('a sibling directory whose name only starts with the cache root is not it',
      () async {
    // `${cache.path}-backup` shares a prefix with the cache root; a plain
    // startsWith would delete a file outside the cache (SC-003 is about the
    // cache, not about anything whose name resembles it).
    final Directory sibling = Directory('${cache.path}-backup')
      ..createSync(recursive: true);
    addTearDown(() {
      if (sibling.existsSync()) sibling.deleteSync(recursive: true);
    });
    final File outside = File('${sibling.path}/article.txt')
      ..writeAsStringSync('not in the cache');
    expect(await burnCachedCopy(outside.path, cacheRoot: cache), isFalse);
    expect(outside.existsSync(), isTrue);
  });
}
