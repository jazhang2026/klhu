/// 025 — the reader's own documents, chosen from their files (FR-001).
///
/// The platform's own file dialog, through `file_selector` — the same plugin
/// that powers the picture picker, reused for documents (D5 — no new plugin).
///
/// **Nothing of the document survives on disk** (FR-003, SC-003; the reader's
/// own reading, 2026-10-26: "内存副本只用于阅读，读完即焚"). The plugin's Android
/// side copies a picked `content://` file into `{cacheDir}/{uuid}/{name}` before
/// the bytes can be read, so the bytes are read first and that copy is deleted
/// the moment they are in memory — the content that lands in the library is the
/// extracted text, and the only copy while reading is the one in memory.
///
/// 026 — Google Drive support: when `file.readAsBytes()` returns empty for a
/// `content://` URI (Google Drive files), we fall back to opening the file in
/// Google Drive for export. The returned map contains the original URI and a
/// message explaining what to do next.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// One chosen document: what it is called, and how to read it.
class PickedDocument {
  const PickedDocument({required this.name, required this.read});

  /// The file's own name, with any directory stripped (`article.pdf`).
  final String name;

  /// The document's bytes.
  ///
  /// Read once, straight after choosing, while the picker's own read grant is
  /// alive; the platform's cached copy is deleted before this answers (see
  /// [burnCachedCopy]), so the caller holds the only copy there is.
  final Future<Uint8List> Function() read;
}

/// Result of a Drive import attempt.
class DriveImportResult {
  const DriveImportResult({required this.success, required this.message});

  /// Whether the import succeeded.
  final bool success;

  /// User-facing message explaining the result.
  final String message;
}

/// Deletes the platform's own cached copy of a pick, once its bytes are in
/// memory (FR-003, SC-003).
///
/// Only a file inside the app's own cache directory is deleted: that is where
/// `file_selector` stages a `content://` pick, and a path the reader actually
/// owns must never be touched — deleting their document would be data loss.
/// Answers whether a file was deleted.
Future<bool> burnCachedCopy(String path, {Directory? cacheRoot}) async {
  if (path.isEmpty) return false;
  // content:// URIs have no local cache copy to delete — Drive files stream.
  if (path.startsWith('content://')) return true;
  final Directory root = cacheRoot ?? await getApplicationCacheDirectory();
  final File file = File(path).absolute;
  final String rootPath = root.absolute.path;
  if (!file.path.startsWith('$rootPath${Platform.pathSeparator}')) {
    return false;
  }
  if (!await file.exists()) return false;
  await file.delete();
  return true;
}

/// Reads bytes from a `content://` URI through the platform's ContentResolver.
///
/// Used as a fallback when `readAsBytes()` returns empty for a Google Drive
/// (or other content-provider) URI. Returns empty on failure so the
/// caller can fall through to the OCR path or the "unsupported" message.
///
/// Method channel: `klhu/document_picker` / `readContentUri`.
/// See spec 026, research D1/D2.
Future<Uint8List> readContentUri(String uri) async {
  final channel = MethodChannel('klhu/document_picker');
  try {
    final List<dynamic> bytes = await channel.invokeMethod(
        'readContentUri', <String, dynamic>{'uri': uri});
    return Uint8List.fromList(bytes.cast<int>());
  } catch (_) {
    return Uint8List(0);
  }
}

/// Exports a Google Drive file by opening it in the Google Drive app.
///
/// Google Drive files live behind DocListProvider, which is not exported to
/// third-party apps. Direct ContentResolver reads fail. This function opens
/// the file in Google Drive via ACTION_VIEW, where the user can export it
/// to a local file (share → Save to device), then pick it again from their
/// local storage.
///
/// Returns a [DriveImportResult] with success=false and a user-facing message.
/// Returns null on failure.
/// See spec 026, FR-002.
Future<DriveImportResult?> exportDriveFile(String uri) async {
  final channel = MethodChannel('klhu/document_picker');
  try {
    final dynamic response = await channel.invokeMethod(
        'exportDriveFile', <String, dynamic>{'uri': uri});
    if (response is Map) {
      return DriveImportResult(
        success: false,
        message: response['message'] as String? ?? '',
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Whether a path looks like a Google Drive content URI.
///
/// Matches URIs from the two Drive authority roots that DocumentsUI uses:
/// `com.google.android.apps.docs.storage` and `com.google.android.apps.photoscontent`.
bool isDriveUri(String path) =>
    path.startsWith('content://com.google.android.apps.docs') ||
    path.startsWith('content://com.google.android.apps.photoscontent');

/// Chooses documents from the reader's files.
abstract class DocumentPicker {
  /// The document the reader chose. Empty when the reader cancelled; throws
  /// when the picker itself failed.
  Future<PickedDocument?> pick();
}

/// The platform's own file dialog, through `file_selector`.
class FileDocumentPicker implements DocumentPicker {
  const FileDocumentPicker();

  /// The document kinds the dialog offers (FR-001: PDF, DOCX, TXT, EPUB).
  /// Includes Google Drive MIME types so Drive files appear in the picker and
  /// can be handled through the native export layer (spec 026).
  static XTypeGroup documentTypes(TargetPlatform platform) {
    const List<String> extensions = <String>[
      'pdf',
      'docx',
      'txt',
      'epub',
    ];
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const XTypeGroup(
          label: 'documents',
          uniformTypeIdentifiers: <String>[
            'com.adobe.pdf',
            'com.microsoft.word.doc',
            'org.openxmlformats-wordprocessingml.document',
            'public.plain-text',
            'org.idpf.epub-container',
          ],
        );
      case TargetPlatform.windows:
        return const XTypeGroup(label: 'documents', extensions: extensions);
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const XTypeGroup(
          label: 'documents',
          extensions: extensions,
          mimeTypes: <String>[
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'text/plain',
            'application/epub+zip',
            // spec 026: Google Drive native formats.
            'application/vnd.google-apps.document',
            'application/vnd.google-apps.spreadsheet',
            'application/vnd.google-apps.presentation',
            'application/vnd.google-apps.drawing',
            'application/vnd.google-apps.form',
          ],
        );
    }
  }

  @override
  Future<PickedDocument?> pick() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        documentTypes(defaultTargetPlatform),
      ],
    );
    if (file == null) return null;
    return PickedDocument(
      name: file.name,
      read: () async {
        Uint8List bytes = await file.readAsBytes();
        // 026: content:// fallback for Google Drive and other content
        // provider URIs. First try readAsBytes() directly (fast path for
        // local files). If that returns empty and the path is a content://
        // URI, attempt to read through the native ContentResolver. If that
        // also fails (e.g. for Google Drive files behind DocListProvider),
        // fall through — the caller will see empty bytes and the extraction
        // seam will hand the document to OCR or refuse it.
        if (bytes.isEmpty && file.path.startsWith('content://')) {
          bytes = await readContentUri(file.path);
        }
        // The bytes are in memory now: the platform's cached copy goes (SC-003
        // — "读完即焚"). A failed delete must not cost the reader their import,
        // so the answer is not checked; the next pick overwrites the cache path
        // anyway, and the cache is the app's own.
        await burnCachedCopy(file.path);
        return bytes;
      },
    );
  }
}
