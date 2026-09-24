import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One offered reading typeface: the app-level [name] the record stores and the
/// platform family it renders with (spec 011 US2).
///
/// The stored name is stable, so retuning the mapping later is a code change
/// rather than a data migration (contract
/// `specs/011-reading-experience/contracts/appearance-format.md`).
class ReadingTypeface {
  /// The name in the stored record: `default`, `serif` or `mono`.
  final String name;

  const ReadingTypeface._(this.name);

  /// The app's shipped look. No family is set, so the theme's own family
  /// renders — the app ships no font, and neither does this option add one.
  static const defaultFace = ReadingTypeface._('default');
  static const serif = ReadingTypeface._('serif');
  static const mono = ReadingTypeface._('mono');

  /// The offered set, in the order the screen shows it.
  static const all = [defaultFace, serif, mono];

  static ReadingTypeface? byName(String name) {
    for (final face in all) {
      if (face.name == name) return face;
    }
    return null;
  }

  /// The font family the platform is asked for; null keeps the theme's own.
  ///
  /// The named faces are platform fonts rather than bundled assets (research
  /// D5): the app ships no font file, so the system's own CJK-capable face
  /// stays in the fallback chain and Chinese text keeps rendering.
  String? familyFor(TargetPlatform platform) => switch (name) {
        'serif' => platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
            ? 'Times New Roman'
            : 'serif',
        'mono' => platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
            ? 'Courier New'
            : 'monospace',
        _ => null,
      };
}

/// One offered character size: the app-level [name] the record stores and the
/// point size it renders at.
class ReadingSize {
  /// The name in the stored record: `small`, `medium`, `large` or `xlarge`.
  final String name;

  /// The size the reading text renders at.
  final double points;

  const ReadingSize._(this.name, this.points);

  static const small = ReadingSize._('small', 12);

  /// The size the app ships today (`bodyMedium`, Material 3). The default is a
  /// no-op: an absent record renders exactly what the app always rendered.
  static const medium = ReadingSize._('medium', 14);
  static const large = ReadingSize._('large', 18);

  /// The largest offered size — the one FR-012's width guarantee is measured
  /// at.
  static const xlarge = ReadingSize._('xlarge', 24);

  /// The offered set, in the order the screen shows it.
  static const all = [small, medium, large, xlarge];

  static ReadingSize? byName(String name) {
    for (final size in all) {
      if (size.name == name) return size;
    }
    return null;
  }
}

/// The reading appearance in force: the reading text's typeface and character
/// size (spec 011 US2).
class ReadingAppearance {
  final ReadingTypeface typeface;
  final ReadingSize size;

  const ReadingAppearance({required this.typeface, required this.size});

  /// What an absent, malformed or withdrawn record reads as: the shipped look.
  static const defaults = ReadingAppearance(
    typeface: ReadingTypeface.defaultFace,
    size: ReadingSize.medium,
  );

  static const _separator = '||';

  /// The record's own grammar: `<typeface>||<size>`.
  String encode() => '${typeface.name}$_separator${size.name}';

  /// Reads a stored value by the contract's read rules: exactly two non-empty
  /// parts; a field naming something this build does not offer falls back ON
  /// ITS OWN, leaving the other field in force; anything else — an absent
  /// record, one part, three parts — is the defaults. Never throws, and
  /// nothing is repaired or rewritten: the next confirm overwrites it.
  static ReadingAppearance decode(String? raw) {
    if (raw == null) return defaults;
    final parts = raw.split(_separator);
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return defaults;
    }
    return ReadingAppearance(
      typeface:
          ReadingTypeface.byName(parts[0]) ?? ReadingTypeface.defaultFace,
      size: ReadingSize.byName(parts[1]) ?? ReadingSize.medium,
    );
  }
}

/// Persists the reading appearance in `shared_preferences`, the app's store for
/// per-device view state (`VoiceStore`, `ReadPositionStore`, the interface
/// language) — it is NOT library metadata and never touches `index.json`.
///
/// The record contract is
/// `specs/011-reading-experience/contracts/appearance-format.md`: key
/// `reading_appearance`, value `<typeface>||<size>`, written once per confirmed
/// choice — one `setString`, so there is no state in which a new typeface sits
/// beside a stale size because a write was cut short.
class AppearanceStore {
  /// The single key this store addresses, namespaced so it collides with no
  /// `voice_*`, `interface_language` or `read_position_*` record.
  static const String key = 'reading_appearance';

  /// The stored appearance, or the defaults under every failure: a missing or
  /// read-only persistence layer must never block reading (contract § Error and
  /// repair states).
  Future<ReadingAppearance> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ReadingAppearance.decode(prefs.getString(key));
    } catch (e) {
      debugPrint('klhu appearance unreadable: $e');
      return ReadingAppearance.defaults;
    }
  }

  Future<void> save(ReadingAppearance appearance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, appearance.encode());
    } catch (e) {
      // The look stays in force for the session; the next launch is back to
      // the previous record.
      debugPrint('klhu appearance not persisted: $e');
    }
  }
}
