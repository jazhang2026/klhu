import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One start position for Continue Read (spec 010 FR-002…FR-009): where in
/// [contentKey]'s text the user last asked to continue from.
///
/// [charCount] is the length of the text [offset] was computed on. It is the
/// record's identity guard (research D6): a stored offset is only applied to
/// the text it was measured against, so a pre-set whose asset text changed
/// between app versions cannot point the read into the wrong place.
class ReadingPosition {
  /// The library entry id (`c_<epochMillis>_<4 hex>`), or a shipped pre-set's
  /// id (`preset_en_sample`) when the page shows the catalog fallback.
  final String contentKey;

  /// Character index into that text, always a sentence or paragraph start
  /// (D1: the resolved segment's start).
  final int offset;

  /// Length of the text the offset belongs to.
  final int charCount;

  const ReadingPosition({
    required this.contentKey,
    required this.offset,
    required this.charCount,
  });
}

/// Persists one [ReadingPosition] per content in `shared_preferences`, the
/// app's store for per-device view state (`VoiceStore`, the interface
/// language) — it is NOT library metadata and never touches `index.json`.
///
/// The record contract is `specs/010-continue-read/contracts/read-position-format.md`:
/// key `read_position_<contentKey>`, value `<offset>||<charCount>`. A missing,
/// malformed or stale record is not an error: [load] returns null, the caller
/// reads from the beginning, and nothing is repaired or rewritten.
class ReadPositionStore {
  static const _separator = '||';
  static const _prefix = 'read_position_';

  /// Decimal digits only: no sign, no whitespace, no float.
  static final _decimal = RegExp(r'^[0-9]+$');

  /// The single key this store addresses for [contentKey]. Namespaced so a
  /// content can never collide with `voice_*` or the language preference.
  static String keyFor(String contentKey) => '$_prefix$contentKey';

  Future<void> save(String contentKey, ReadingPosition position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(contentKey),
        '${position.offset}$_separator${position.charCount}',
      );
    } catch (e) {
      // A missing or read-only persistence layer must never block reading:
      // the position stays in memory for the session (contract § Error and
      // repair states).
      debugPrint('klhu read position not persisted: $e');
    }
  }

  /// The stored position for [contentKey], but only when it belongs to a text
  /// of [textLength] characters. Everything else — no record, a malformed
  /// value, a text that changed underneath it — reads as no position.
  Future<ReadingPosition?> load(String contentKey, int textLength) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(contentKey));
      if (raw == null) return null;
      final offset = _validOffset(raw, textLength);
      if (offset == null) return null;
      return ReadingPosition(
        contentKey: contentKey,
        offset: offset,
        charCount: textLength,
      );
    } catch (e) {
      debugPrint('klhu read position unreadable: $e');
      return null;
    }
  }

  /// Forget [contentKey]'s position: the text on screen changed (FR-007), so a
  /// restart must not bring the old offset back.
  Future<void> clear(String contentKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(contentKey));
    } catch (e) {
      debugPrint('klhu read position not cleared: $e');
    }
  }

  /// The read rules of the contract, as a pure function: exactly two non-empty
  /// decimal parts, a `charCount` of [textLength], and an offset inside the
  /// text.
  static int? _validOffset(String raw, int textLength) {
    final parts = raw.split(_separator);
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    if (!_decimal.hasMatch(parts[0]) || !_decimal.hasMatch(parts[1])) return null;
    final offset = int.parse(parts[0]);
    final charCount = int.parse(parts[1]);
    if (charCount != textLength) return null;
    if (offset >= textLength) return null;
    return offset;
  }
}
