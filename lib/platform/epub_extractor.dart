/// EPUB extraction using epub_decoder (spec 028 FR-003).
///
/// Implements DocumentExtractor for EPUB files, using pure Dart implementation
/// with chapter/section support. Returns empty string for malformed EPUB files
/// (graceful failure per FR-006).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:epub_decoder/epub_decoder.dart';
import 'package:klhu/platform/document_extractor.dart';
import 'package:xml/xml.dart';

/// EPUB extractor using epub_decoder.
///
/// Extracts text from EPUB files chapter by chapter using pure Dart
/// implementation. Returns empty string for malformed EPUB files (graceful
/// failure per FR-006).
class EpubExtractor implements DocumentExtractor {
  const EpubExtractor();

  @override
  Future<String> extract(Uint8List bytes, String kind) async {
    if (kind.toLowerCase() != 'epub') return '';
    try {
      final epub = Epub.fromBytes(bytes);
      final lines = <String>[];
      for (final section in epub.sections) {
        // section.content.fileContent is the raw XHTML bytes for this chapter.
        final doc = XmlDocument.parse(utf8.decode(section.content.fileContent));
        // Walk all element types that carry visible text in XHTML body content.
        const tags = <String>[
          'p', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
          'td', 'th', 'div', 'span', 'blockquote', 'pre',
        ];
        final chapterText = <String>[];
        for (final tag in tags) {
          for (final el in doc.findAllElements(tag)) {
            final t = el.innerText.trim();
            if (t.isNotEmpty) chapterText.add(t);
          }
        }
        lines.add(chapterText.join('\n'));
      }
      return lines.where((l) => l.trim().isNotEmpty).join('\n\n');
    } catch (_) {
      return '';
    }
  }
}
