import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One offered video format: the app-level [name] the record stores, the frame
/// it renders at, and the rate its frames are played at (spec 012 FR-007).
///
/// The stored name is stable, so retuning a frame later is a code change rather
/// than a data migration (contract
/// `specs/012-reading-video/contracts/video-aspect-format.md`).
class VideoAspect {
  /// The name in the stored record: `landscape` or `vertical`.
  final String name;

  /// The frame the video is rendered at, and the rate it plays at.
  final int width;
  final int height;
  final int fps;

  const VideoAspect._(this.name, this.width, this.height, this.fps);

  /// The default: 16:9 landscape 1080p, what a fresh device renders and what an
  /// absent or unreadable record reads as.
  static const landscape = VideoAspect._('landscape', 1920, 1080, 30);

  /// 9:16 vertical 1080p, for Shorts-shaped uploads — the same frame turned on
  /// its side.
  static const vertical = VideoAspect._('vertical', 1080, 1920, 30);

  /// The offered set, in the order the prompt shows it.
  static const all = [landscape, vertical];

  /// What an absent, malformed or withdrawn record reads as.
  static const defaults = landscape;

  bool get isVertical => name == 'vertical';

  static VideoAspect? byName(String name) {
    for (final aspect in all) {
      if (aspect.name == name) return aspect;
    }
    return null;
  }

  /// The record's own value: its name.
  String encode() => name;

  /// Reads a stored value by the contract's read rules: a name this build
  /// offers, or the defaults. Never throws, and nothing is repaired or
  /// rewritten — the next confirm overwrites it.
  static VideoAspect decode(String? raw) => byName(raw ?? '') ?? defaults;
}

/// Persists the chosen video format in `shared_preferences`, the app's store for
/// per-device view state (`VoiceStore`, `ReadPositionStore`, `AppearanceStore`,
/// the interface language) — it is NOT library metadata and never touches
/// `index.json`.
///
/// The record contract is
/// `specs/012-reading-video/contracts/video-aspect-format.md`: key
/// `video_aspect`, value the choice's own name, written once per confirmed
/// choice — one `setString`, so there is no state in which a new frame sits
/// beside a stale rate.
class VideoAspectStore {
  /// The single key this store addresses, namespaced so it collides with no
  /// `voice_*`, `interface_language`, `read_position_*` or
  /// `reading_appearance` record.
  static const String key = 'video_aspect';

  /// The stored choice, or the defaults under every failure: a missing or
  /// read-only persistence layer must never block a render (contract § Error
  /// and repair states).
  Future<VideoAspect> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return VideoAspect.decode(prefs.getString(key));
    } catch (e) {
      debugPrint('klhu video aspect unreadable: $e');
      return VideoAspect.defaults;
    }
  }

  Future<void> save(VideoAspect aspect) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, aspect.encode());
    } catch (e) {
      // The choice stays in force for the session; the next launch is back to
      // the previous record.
      debugPrint('klhu video aspect not persisted: $e');
    }
  }
}
