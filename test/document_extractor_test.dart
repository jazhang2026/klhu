/// 027 — the platform extraction seam's own table (Phase 1 of the implementation
/// plan; quickstart row 1 of the deferred kinds).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/document_extractor.dart';

void main() {
  group('the platform extraction seam', () {
    test('a deferred kind the platform cannot read answers empty, for OCR (FR-003)', () async {
      // FR-003, Q2: where a deferred kind's text cannot be extracted, the
      // document seam hands the document to the OCR functions. Until the
      // platform's extraction capability lands (Phase 2), the seam answers
      // empty for every kind.
      final extractor = MethodChannelDocumentExtractor();
      expect(await extractor.extract(Uint8List.fromList([0]), 'pdf'), '');
      expect(await extractor.extract(Uint8List.fromList([0]), 'epub'), '');
    });
  });
}
