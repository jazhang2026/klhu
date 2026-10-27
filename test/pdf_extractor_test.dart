import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/pdf_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfExtractor', () {
    late Directory tempDir;
    late PdfExtractor extractor;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('pdf_extractor_test_');
      extractor = PdfExtractor(tempDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects non-PDF kinds', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'docx');
      expect(result, isEmpty);
    });

    test('rejects PDF with wrong kind casing', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await extractor.extract(bytes, 'PDF');
      expect(result, isEmpty);
    });

    test('handles empty bytes gracefully', () async {
      final bytes = Uint8List(0);
      final result = await extractor.extract(bytes, 'pdf');
      expect(result, isEmpty);
    });

    test('handles malformed PDF gracefully', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await extractor.extract(bytes, 'pdf');
      // Should return empty string for graceful failure (FR-006)
      expect(result, isEmpty);
    });

    // TODO: Add integration test with real PDF file when we have test fixtures
    // This would test:
    // - Successful text extraction from a valid PDF
    // - Page-by-page extraction support
    // - Encrypted PDF rejection (returns empty)
  });
}
