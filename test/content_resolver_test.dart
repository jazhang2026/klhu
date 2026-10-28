/// Integration test for spec 026 — Google Drive content:// URI reading.
///
/// Tests:
///  1. readContentUri returns bytes from the platform channel for a mock URI.
///  2. readContentUri returns empty on platform exception (graceful failure).
///  3. burnCachedCopy is a no-op for content:// URIs (SC-003).
///  4. exportDriveFile returns a Map on success, null on failure.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/document_picker.dart';

void main() {
  const channel = MethodChannel('klhu/document_picker');

  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentResolver read (026)', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, _mockReadContentUri);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('readContentUri returns bytes from platform channel for Drive URI',
        () async {
      final bytes = await readContentUri(
          'content://com.google.android.apps.docs.storage/legacy/root/test.pdf');
      expect(bytes, isNotEmpty);
      expect(bytes, equals(const [0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('readContentUri returns empty on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, _mockReadError);
      final bytes = await readContentUri(
          'content://com.google.android.apps.docs.storage/...');
      expect(bytes, isEmpty);
    });

    test('burnCachedCopy is a no-op for content:// URIs (026 SC-003)',
        () async {
      final deleted = await burnCachedCopy(
          'content://com.google.android.apps.docs.storage/...');
      expect(deleted, isTrue);
    });
  });

  group('exportDriveFile (026 FR-002)', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, _mockExportSuccess);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('exportDriveFile returns Map on success', () async {
      final result = await exportDriveFile(
          'content://com.google.android.apps.docs.storage/document/raw/1a2b3c');
      expect(result, isNotNull);
      expect(result!['uri'], contains('content://'));
      expect(result['message'], isNotEmpty);
    });

    test('exportDriveFile returns null on failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, _mockExportError);
      final result = await exportDriveFile(
          'content://com.google.android.apps.docs.storage/...');
      expect(result, isNull);
    });
  });

  group('isDriveUri (026)', () {
    test('recognizes docs.storage authority', () {
      expect(isDriveUri('content://com.google.android.apps.docs.storage/...'), true);
    });

    test('recognizes photoscontent authority', () {
      expect(isDriveUri('content://com.google.android.apps.photoscontent/...'), true);
    });

    test('rejects non-Drive URIs', () {
      expect(isDriveUri('content://com.android.providers.media/...'), false);
      expect(isDriveUri('/sdcard/Download/test.pdf'), false);
    });
  });
}

/// Mock for readContentUri: returns mock PDF bytes.
Future<dynamic> _mockReadContentUri(MethodCall call) async {
  if (call.method == 'readContentUri') return [0x25, 0x50, 0x44, 0x46, 0x2D];
  return null;
}

/// Mock for readContentUri: throws PlatformException.
Future<dynamic> _mockReadError(MethodCall call) async {
  if (call.method == 'readContentUri') {
    throw PlatformException(code: 'READ_FAILED', message: 'permission denied');
  }
  return null;
}

/// Mock for exportDriveFile: returns a Map with uri and message.
Future<dynamic> _mockExportSuccess(MethodCall call) async {
  if (call.method == 'exportDriveFile') {
    return {'uri': call.arguments['uri'] as String, 'message': '请导出后重新选择'};
  }
  return null;
}

/// Mock for exportDriveFile: throws PlatformException.
Future<dynamic> _mockExportError(MethodCall call) async {
  if (call.method == 'exportDriveFile') {
    throw PlatformException(code: 'EXPORT_FAILED', message: 'export failed');
  }
  return null;
}
