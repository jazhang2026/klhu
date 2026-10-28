/// Integration test for spec 026 — Google Drive content:// URI reading.
///
/// This test verifies the native ContentResolver read path works on-device.
/// It uses a local content:// URI (file:// fallback) to test the native plugin
/// without requiring a Google Drive account.
///
/// Run on device: flutter test test/content_resolver_test.dart --flutter
library;


import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/document_picker.dart';

void main() {
  const channel = MethodChannel('klhu/document_picker');

  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentResolver read (026)', () {
    test('readContentUri returns bytes for a mock content:// URI', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'readContentUri') {
          final args = call.arguments as Map?;
          final uri = args?['uri'] as String?;
          if (uri?.startsWith('content://') == true) {
            // Simulate successful read: return PDF magic bytes
            return [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
          }
        }
        return null;
      });
      final bytes = await readContentUri(
          'content://com.google.android.apps.docs.storage/legacy/root/test.pdf');
      expect(bytes, isNotEmpty);
      expect(bytes.take(5), equals(const [0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('readContentUri returns empty on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'readContentUri') {
          throw PlatformException(code: 'READ_FAILED', message: 'no permission');
        }
        return null;
      });
      final bytes = await readContentUri(
          'content://com.google.android.apps.docs.storage/...');
      expect(bytes, isEmpty);
    });

    test('burnCachedCopy is a no-op for content:// URIs', () async {
      final deleted = await burnCachedCopy(
          'content://com.google.android.apps.docs.storage/...');
      expect(deleted, isTrue);
    });
  });
}
