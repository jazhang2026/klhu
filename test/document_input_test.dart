/// 025 — the document import's own answer, read off the picked document alone
/// (quickstart rows 1, 2 and 3; the plan's Phase 1).
///
/// What the seam answers: which kinds a document may be of (FR-001, re-cut by
/// Q2 — EPUB is the first-cut e-book format), what text an accepted document
/// yields and whether it is worth reading (FR-003, re-cut by Q3 — OCR), and how
/// a read walks large text — the document's own pages, else bounded segments
/// (FR-002, Q1).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/document_input.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

void main() {
  group('the document import seam', () {
    test('a supported text document yields its text', () {
      // FR-001: the accepted kinds are the reader's own list — PDF, DOC, DOCX,
      // TXT and popular e-book formats, EPUB the first cut (Q2).
      expect(supportedDocumentKinds, containsAll(<String>[
        'txt',
        'pdf',
        'doc',
        'docx',
        'epub',
      ]));
      expect(isSupportedDocumentKind('txt'), isTrue);
      expect(isSupportedDocumentKind('pdf'), isTrue);
      expect(isSupportedDocumentKind('epub'), isTrue);
      expect(isSupportedDocumentKind('rtf'), isFalse);
      expect(isSupportedDocumentKind(null), isFalse);
      expect(isSupportedDocumentKind(''), isFalse);
    });

    test('the no-text case is OCR’s to answer', () {
      // FR-003, re-cut by Q3: where a document’s text cannot be extracted, the
      // added OCR functions read it.
      expect(requiresOcr('pdf', ''), isTrue);
      expect(requiresOcr('pdf', '   \n  '), isTrue);
      expect(requiresOcr('txt', ''), isFalse);
      expect(requiresOcr('txt', 'hello'), isFalse);
    });

    test('the page/segment choice: pages own their text, else bounded segments',
        () {
      // FR-002, re-cut by Q1: the phone’s original document’s pages when the
      // document has them, bounded segments of the extracted text otherwise.
      expect(
        documentSegments('first page', pages: <String>['first page', 'second page']),
        <String>['first page', 'second page'],
      );
      final bounded = documentSegments('a sentence that is long enough to need cutting ' * 8,
          maxChars: 40);
      expect(bounded.length, greaterThan(1));
      expect(bounded.every((segment) => segment.isNotEmpty), isTrue);
      expect(documentSegments('   '), isEmpty);
    });
  });

  group('the landing', () {
    test('the produced text becomes a user content through the store (FR-004)',
        () async {
      final root = await Directory.systemTemp.createTemp('klhu-import-test');
      addTearDown(() {
        if (!root.existsSync()) return;
        root.deleteSync(recursive: true);
      });
      final store = ContentStore(
        directory: root,
        loadCatalog: () async => const <PresetContent>[],
      );
      final saved = await saveImported(
        store,
        'Imported text\nsecond line.',
        language: 'en',
      );

      expect(saved.origin, ContentOrigin.user);
      expect(await store.read(saved), 'Imported text\nsecond line.');
      expect((await store.list()).single.id, saved.id);
    });
  });
}
