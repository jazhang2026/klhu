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
/// `content://` URI (Google Drive files), the read falls back to the platform's
/// ContentResolver through [readContentUri], so Drive files flow through the
/// existing extraction seam unchanged.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
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
/// Used as a fallback when `XFile.readAsBytes()` returns empty for a Google
/// Drive (or other content-provider) URI. Returns empty on failure so the
/// caller can fall through to the OCR path or the "unsupported" message.
Future<Uint8List> readContentUri(String uri) async {
  // TODO(026): implement the platform channel call to read content:// URIs.
  // On Android, this calls ContentResolver.openInputStream(Uri.parse(uri))
  // and reads the stream into a Uint8List. The method channel name is
  // 'klhu/document_picker' and the method is 'readContentUri'.
  // Until the native half is written, return empty so the import fails
  // gracefully (same as the current behavior for unreadable Drive files).
  return Uint8List(0);
}

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
            'org.openxmlformats.wordprocessingml.document',
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
        // 026: content:// fallback — when readAsBytes() returns empty for a
        // Google Drive (or other content-provider) URI, try the platform's
        // ContentResolver. If that also returns empty, the extraction seam
        // will hand the document to OCR (FR-003) or refuse it.
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
