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
import 'package:klhu/platform/document_extractor.dart';
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
/// TXT decodes as UTF-8. A deferred kind (PDF, DOC, DOCX, EPUB) is handed to the
/// platform's own extraction through [extractor] (FR-001, FR-003, and the Q2
/// answer for the kinds the platform cannot read); the OCR functions answer
/// where the text layer is absent (FR-003).
Future<String> extractText(Uint8List bytes, String kind,
    {DocumentExtractor? extractor}) async {
  final lowerKind = kind.toLowerCase();
  if (lowerKind == 'txt') {
    return utf8.decode(bytes, allowMalformed: true);
  }
  return (extractor ?? const MethodChannelDocumentExtractor()).extract(
      bytes, lowerKind);
}

/// A read unit of a paged document: the text one read holds in memory at a
/// time, and the content range it owns (FR-002, Q1, SC-002) — the unit's own
/// trimmed text, the offsets the read's sentences point into.
class DocumentUnit {
  final String text;
  final int start;
  final int end;

  const DocumentUnit(this.text, this.start, this.end);
}

/// The read's units for [text]: the document's own pages when it has them, else
/// bounded segments of the extracted text (FR-002, Q1); an empty [text] yields
/// no units, so a read of nothing holds nothing (FR-003).
List<DocumentUnit> documentUnits(String text,
    {List<String>? pages, int maxChars = 4000}) {
  final owned = pages ?? const <String>[];
  if (owned.isNotEmpty) {
    final units = <DocumentUnit>[];
    var cursor = 0;
    for (final page in owned) {
      final start = cursor;
      final end = cursor + page.length;
      units.add(DocumentUnit(page.trim(), start, end));
      cursor = end;
    }
    return units;
  }
  final clean = text.trim();
  if (clean.isEmpty) return const <DocumentUnit>[];
  final units = <DocumentUnit>[];
  var start = 0;
  while (start < text.length) {
    final end = start + maxChars < text.length ? start + maxChars : text.length;
    units.add(DocumentUnit(text.substring(start, end).trim(), start, end));
    start = end;
  }
  return units;
}

/// The segments a read walks from extracted text: the document's own pages when
/// it has them (Q1), else bounded segments of the extracted text (FR-002).
List<String> documentSegments(String text, {List<String>? pages, int maxChars = 4000}) {
  return <String>[
    for (final unit in documentUnits(text, pages: pages, maxChars: maxChars))
      unit.text,
  ];
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
