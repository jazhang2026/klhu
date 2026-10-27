import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/epub_extractor.dart';

void main() {
  group('EpubExtractor', () {
    late EpubExtractor extractor;

    setUp(() {
      extractor = const EpubExtractor();
    });

    test('rejects non-EPUB kinds', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'pdf');
      expect(result, isEmpty);
    });

    test('rejects EPUB with wrong kind casing', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'EPUB');
      expect(result, isEmpty);
    });

    test('handles empty bytes gracefully', () async {
      final bytes = Uint8List(0);
      final result = await extractor.extract(bytes, 'epub');
      expect(result, isEmpty);
    });

    test('handles malformed EPUB gracefully', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await extractor.extract(bytes, 'epub');
      // Should return empty string for graceful failure (FR-006)
      expect(result, isEmpty);
    });

    // TODO: Add integration test with real EPUB file when we have test fixtures
    // This would test:
    // - Successful text extraction from a valid EPUB
    // - Chapter-by-chapter extraction
  });
}
