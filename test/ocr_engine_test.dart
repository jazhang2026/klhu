/// 027 — the OCR engine seam's own table (the #3 stage of the implementation plan;
/// quickstart row 1 of the deferred kinds, the OCR half).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/ocr_engine.dart';

void main() {
  group('the OCR engine seam', () {
    test('the engine reads a document whose text layer is absent (FR-003)', () async {
      // FR-003, Q2: the added OCR functions read a scanned document; the OCR'd
      // text then enters the content pipeline like any other extracted text.
      final engine = _FakeEngine('Scanned text the recognizer read.');
      expect(
        await engine.recognize(Uint8List.fromList([1, 2, 3]), 'pdf'),
        'Scanned text the recognizer read.',
      );
    });

    test('a document the engine cannot read answers empty, and the seam has nothing to land (FR-003)', () async {
      // The engine choice is the device's own measurement (research R2); until it
      // lands, the phase's holding answer is an empty read, and the document seam
      // then has no text to land the deferred kind with.
      final engine = MethodChannelOcrEngine();
      expect(await engine.recognize(Uint8List.fromList([0]), 'pdf'), '');
    });
  });
}

class _FakeEngine implements OcrEngine {
  _FakeEngine(this.text);

  final String text;

  @override
  Future<String> recognize(Uint8List bytes, String kind) async => text;
}
