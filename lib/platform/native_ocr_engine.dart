/// OCR using flutter_native_ocr (spec 028 FR-004).
///
/// Implements OcrEngine using Apple Vision on iOS and Google ML Kit on Android.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_native_ocr/flutter_native_ocr.dart';
import 'package:klhu/platform/ocr_engine.dart';
import 'package:path_provider/path_provider.dart';

/// OCR engine using flutter_native_ocr.
///
/// Recognizes text from images using platform-native OCR (Apple Vision on iOS,
/// Google ML Kit on Android). Returns empty string for unrecognizable images
/// (graceful failure per FR-006). Temporary files are deleted immediately
/// after recognition (FR-007).
///
/// The [tempDir] parameter is for testing only; in production it's obtained
/// from path_provider.
class NativeOcrEngine implements OcrEngine {
  final Directory? tempDir;

  const NativeOcrEngine({this.tempDir});

  @override
  Future<String> recognize(Uint8List bytes, String kind) async {
    // flutter_native_ocr works with image files, not bytes directly
    // Save bytes to temp file, recognize, then delete
    final dir = tempDir ?? await getTemporaryDirectory();
    final extension = _imageExtension(kind);
    final tempFile = File('${dir.path}/temp_ocr_${DateTime.now().millisecondsSinceEpoch}$extension');

    try {
      // Write bytes to temp file
      await tempFile.writeAsBytes(bytes);

      // Recognize text using flutter_native_ocr
      final ocr = FlutterNativeOcr();
      final text = await ocr.recognizeText(tempFile.path);

      return text;
    } catch (e) {
      // Log error and return empty string for graceful failure (FR-006)
      // In production, this should be logged
      return '';
    } finally {
      // Delete temporary file immediately (FR-007)
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  String _imageExtension(String kind) {
    final lower = kind.toLowerCase();
    if (lower == 'png') return '.png';
    if (lower == 'jpg' || lower == 'jpeg') return '.jpg';
    return '.png'; // default
  }
}
