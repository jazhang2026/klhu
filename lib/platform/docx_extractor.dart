/// DOCX extraction using docx_to_text (spec 028 FR-002).
///
/// Implements DocumentExtractor for DOCX files, using pure Dart implementation.
library;

import 'dart:typed_data';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:klhu/platform/document_extractor.dart';

/// DOCX extractor using docx_to_text.
///
/// Extracts text from DOCX files using pure Dart implementation. Returns empty
/// string for malformed DOCX files (graceful failure per FR-006).
class DocxExtractor implements DocumentExtractor {
  const DocxExtractor();

  @override
  Future<String> extract(Uint8List bytes, String kind) async {
    if (kind.toLowerCase() != 'docx') {
      return '';
    }

    try {
      // docx_to_text works directly with bytes, no temp file needed
      final text = docxToText(bytes);
      return text;
    } catch (e) {
      // Log error and return empty string for graceful failure (FR-006)
      // In production, this should be logged
      return '';
    }
  }
}
