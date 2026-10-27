import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/native_ocr_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeOcrEngine', () {
    late Directory tempDir;
    late NativeOcrEngine engine;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ocr_engine_test_');
      engine = NativeOcrEngine(tempDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('handles empty bytes gracefully', () async {
      final bytes = Uint8List(0);
      final result = await engine.recognize(bytes, 'png');
      expect(result, isEmpty);
    });

    test('handles malformed image gracefully', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await engine.recognize(bytes, 'png');
      // Should return empty string for graceful failure (FR-006)
      expect(result, isEmpty);
    });

    // TODO: Add integration test with real image file when we have test fixtures
    // This would test:
    // - Successful text recognition from a valid image
    // - Different image formats (PNG, JPG)
    // Note: flutter_native_ocr requires mobile platform (iOS/Android) and
    // may not work in unit test environment; integration tests needed.
  });
}
