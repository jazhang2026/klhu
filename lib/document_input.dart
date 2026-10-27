/// 025 — the document import's own answer, read off the picked document alone
/// (quickstart rows 1, 2 and 3; the plan's Phase 1).
///
/// What the seam answers: which kinds a document may be of (FR-001, re-cut by
/// Q2 — EPUB is the first-cut e-book format), what text an accepted document
/// yields and whether it is worth reading (FR-003, re-cut by Q3 — OCR), and how
/// a read walks large text — the document's own pages, else bounded segments
/// (FR-002, Q1).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

/// The document kinds this feature accepts (spec FR-001, re-cut by Q2 — EPUB is
/// the first-cut e-book format).
const List<String> supportedDocumentKinds = <String>['txt', 'pdf', 'doc', 'docx', 'epub'];

/// Is [kind] one this feature accepts?
bool isSupportedDocumentKind(String? kind) {
  if (kind == null || kind.isEmpty) return false;
  return supportedDocumentKinds.contains(kind.toLowerCase());
}

/// Extracts text from a document file.
///
/// For TXT files, decodes as UTF-8. For other formats (PDF, DOC, DOCX, EPUB),
/// this is a placeholder that returns an empty string — the actual extraction
/// uses platform facilities and OCR (research §3, Q3), which are added in
/// follow-up work.
String extractText(Uint8List bytes, String kind) {
  final lowerKind = kind.toLowerCase();
  if (lowerKind == 'txt') {
    return utf8.decode(bytes, allowMalformed: true);
  }
  // Placeholder for PDF, DOC, DOCX, EPUB extraction.
  // These require platform-specific libraries or OCR (Q3).
  return '';
}

/// The segments a read walks from extracted text: the document's own pages when
/// it has them (Q1), else bounded segments of the extracted text (FR-002).
List<String> documentSegments(String text, {List<String>? pages, int maxChars = 4000}) {
  final owned = pages ?? const <String>[];
  if (owned.isNotEmpty) {
    return <String>[for (final page in owned) page.trim()];
  }
  final clean = text.trim();
  if (clean.isEmpty) return const <String>[];
  final segments = <String>[];
  var start = 0;
  while (start < clean.length) {
    final end = start + maxChars < clean.length ? start + maxChars : clean.length;
    segments.add(clean.substring(start, end).trim());
    start = end;
  }
  return segments;
}

/// Does this document’s text need the OCR functions (FR-003, Q3)? A document
/// whose extraction came back empty and that can carry a picture — a PDF — does.
bool requiresOcr(String kind, String extractedText) {
  if (extractedText.trim().isNotEmpty) return false;
  return kind == 'pdf';
}

/// The landing (spec FR-004): the produced text becomes a user content through
/// the content store the reader already has — an ordinary content, savable,
/// editable and deletable like hand-written text; the read consumes it through
/// the unchanged segmenter.
Future<SavedContent> saveImported(
  ContentStore store,
  String text, {
  String? language,
}) async {
  return store.saveNew(text, language: language);
}
