import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the reader's pictures move in a video (spec 023 FR-009, D7).
///
/// One choice per device, kept beside the remembered format in the store the app
/// already uses for per-device view state (`VideoAspectStore`, `VoiceStore`, the
/// interface language) — **its own key**, not a field of the aspect's value: 012's
/// record contract enumerates that value's domain, and a compound value would
/// make every read of it a lie. The rules, the failure states and the invariants
/// are `specs/023-video-background-motion/contracts/video-motion-record.md`.
class VideoMotionStore {
  /// The single key this store addresses, namespaced so it collides with no
  /// `voice_*`, `video_aspect`, `interface_language` or `reading_appearance`
  /// record.
  static const String key = 'video_motion';

  /// The two values the record may hold.
  static const String on = 'on';
  static const String off = 'off';

  /// What a stored value means: anything but [on] is off, which is the item's
  /// 「可选」 read as the shipped behaviour — a video nobody asked to change.
  static bool decode(String? raw) => raw == on;

  static String encode(bool enabled) => enabled ? on : off;

  /// The stored choice, or `off` under every failure: a missing key, a value
  /// outside the domain, or a store that throws on the read. **Nothing is
  /// rewritten** here — the next confirmed prompt is the only writer.
  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(key));
    } catch (e) {
      debugPrint('klhu video motion unreadable: $e');
      return false;
    }
  }

  /// Writes the reader's confirmed choice. A failed write is swallowed (the
  /// aspect store's own rule): the render proceeds with the value in memory, and
  /// the next prompt falls back to the stored record or to off.
  Future<void> save(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encode(enabled));
    } catch (e) {
      debugPrint('klhu video motion not persisted: $e');
    }
  }
}
