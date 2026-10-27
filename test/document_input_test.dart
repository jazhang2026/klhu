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
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/document_input.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/document_extractor.dart';
import 'package:klhu/platform/ocr_engine.dart';
import 'package:klhu/services/content_store.dart';

class _FakeExtractor implements DocumentExtractor {
  _FakeExtractor(this.answer);

  final String answer;

  @override
  Future<String> extract(Uint8List bytes, String kind) async => answer;
}

class _FakeOcrEngine implements OcrEngine {
  _FakeOcrEngine(this.text);

  final String text;

  @override
  Future<String> recognize(Uint8List bytes, String kind) async => text;
}

void main() {
  group('the document import seam', () {
    test('a supported text document yields its text', () {
  // FR-001: the accepted kinds are the reader's own list — PDF, DOCX, TXT and
  // popular e-book formats, EPUB the first cut (Q2). Legacy DOC is out of scope
  // for 028 (no Dart-level extraction library exists; scanned PDFs fall through
  // to OCR instead).
      expect(supportedDocumentKinds, containsAll(<String>[
        'txt',
        'pdf',
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

    test('a deferred kind goes through the platform extraction, and the unextractable answer holds (FR-001, FR-003)',
        () async {
      // FR-001: a deferred kind (PDF, DOC, DOCX, EPUB) is accepted and its text is
      // the platform's own extraction's answer through the seam.
      final extracted = await extractText(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
        'pdf',
        extractor: _FakeExtractor('The quick brown fox.'),
      );
      expect(extracted, 'The quick brown fox.');
      // FR-003, Q2: where the platform cannot read the kind, the OCR answer holds.
      expect(
        await extractText(Uint8List.fromList(<int>[1]), 'epub', extractor: _FakeExtractor('')),
        '',
      );
      expect(requiresOcr('pdf', ''), isTrue);
      expect(requiresOcr('epub', ''), isFalse);
      expect(requiresOcr('pdf', 'the text layer survived'), isFalse);
    });

    test('a scanned document is read through the added OCR functions, and the OCR text lands as content (FR-003, SC-001, SC-003)',
        () async {
      // FR-003/Q2: where the platform cannot read the kind, the added OCR functions
      // read the picture; the OCR'd text then enters the content pipeline like any
      // other extracted text (FR-004), spoken by the unchanged read (FR-001).
      final text = await extractText(
        Uint8List.fromList(<int>[9, 9, 9]),
        'pdf',
        extractor: _FakeExtractor(''),
        ocrEngine: _FakeOcrEngine('Scanned text the recognizer read.'),
      );
      expect(text, 'Scanned text the recognizer read.');
      expect(requiresOcr('pdf', ''), isTrue);
      // The OCR'd text is ordinary content: it lands through the store like any
      // other extracted text (FR-004), and the read speaks it like any other
      // content — the landing the pipeline already serves, unchanged.
      final root = await Directory.systemTemp.createTemp('klhu-ocr-test');
      addTearDown(() {
        if (!root.existsSync()) return;
        root.deleteSync(recursive: true);
      });
      final store = ContentStore(
        directory: root,
        loadCatalog: () async => const <PresetContent>[],
      );
      final saved = await saveImported(store, text, language: 'en');
      expect(saved.origin, ContentOrigin.user);
      expect(await store.read(saved), 'Scanned text the recognizer read.');
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

    test('the read’s units: pages own their range, else bounded segments own theirs', () {
      // FR-002, re-cut by Q1: the read walks the document’s own pages when it
      // has them, else bounded segments of the extracted text - each unit the
      // read holds in memory at a time, with the content range it owns (SC-002).
      final pages = documentUnits('first page',
          pages: <String>['first page', 'second page']);
      expect(pages.length, 2);
      expect(pages[0].text, 'first page');
      expect(pages[0].start, 0);
      expect(pages[0].end, 10);
      expect(pages[1].text, 'second page');
      expect(pages[1].start, 10);
      expect(pages[1].end, 21);
      final bounded = documentUnits('a sentence that is long enough to need cutting ' * 8,
          maxChars: 40);
      expect(bounded.length, greaterThan(1));
      expect(bounded.every((unit) => unit.text.isNotEmpty), isTrue);
      expect(bounded.first.end, greaterThan(0));
      expect(documentUnits('   '), isEmpty);
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
