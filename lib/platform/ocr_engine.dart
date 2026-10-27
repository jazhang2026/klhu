/// 027 — the OCR engine the document seam's OCR functions read through (spec FR-003, Q2).
///
/// The functions that read a document whose text layer is absent — a scanned PDF —
/// are the reader's own addition (the Q2 answer); the engine is the platform's own
/// capability behind them, and the seam hands the OCR functions the bytes.
library;

import 'dart:typed_data';

/// The OCR functions' engine: turns a document's bytes into text when the text
/// layer is absent (FR-003).
abstract class OcrEngine {
  /// The text the engine reads from [bytes] of a document of [kind]; empty when
  /// the engine cannot read that document.
  Future<String> recognize(Uint8List bytes, String kind);
}

/// The platform's own OCR as the app holds it in this phase: the engine has not
/// landed, so a document it cannot read answers empty, and the document seam then
/// has no text to land (FR-003).
class MethodChannelOcrEngine implements OcrEngine {
  const MethodChannelOcrEngine();

  @override
  Future<String> recognize(Uint8List bytes, String kind) async => '';
}
