import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/docx_extractor.dart';

void main() {
  group('DocxExtractor', () {
    late DocxExtractor extractor;

    setUp(() {
      extractor = const DocxExtractor();
    });

    test('rejects non-DOCX kinds', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'pdf');
      expect(result, isEmpty);
    });

    test('rejects DOCX with wrong kind casing', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'DOCX');
      expect(result, isEmpty);
    });

    test('handles empty bytes gracefully', () async {
      final bytes = Uint8List(0);
      final result = await extractor.extract(bytes, 'docx');
      expect(result, isEmpty);
    });

    test('handles malformed DOCX gracefully', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await extractor.extract(bytes, 'docx');
      // Should return empty string for graceful failure (FR-006)
      expect(result, isEmpty);
    });

    // TODO: Add integration test with real DOCX file when we have test fixtures
    // This would test:
    // - Successful text extraction from a valid DOCX
  });
}
