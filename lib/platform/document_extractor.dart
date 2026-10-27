/// 027 — the platform's own text extraction for a deferred document kind,
/// behind the seam the document input grows through (spec 027, Phase 1; the
/// TXT-first cut of 025 deferred this capability to this feature).
library;

import 'dart:typed_data';

/// The platform's own text extraction for a document of a deferred kind (PDF,
/// DOC, DOCX, EPUB): the capability the reader's wish listed and the TXT-first
/// cut deferred to this feature.
///
/// An implementation reads the platform's own facilities; a kind it cannot read
/// answers empty, and the document seam then hands the document to the OCR
/// functions the spec's Q2 answer added (FR-003).
abstract class DocumentExtractor {
  /// The text the platform's own facilities extract from [bytes] of [kind];
  /// empty when the platform cannot read that kind.
  Future<String> extract(Uint8List bytes, String kind);
}

/// The platform's own extraction as the app holds it in this phase: the deferred
/// kinds are not readable yet, so every kind answers empty and the document seam
/// hands the document to OCR (FR-003, Q2).
class MethodChannelDocumentExtractor implements DocumentExtractor {
  const MethodChannelDocumentExtractor();

  @override
  Future<String> extract(Uint8List bytes, String kind) async => '';
}
