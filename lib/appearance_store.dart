import 'dart:ui' show FontWeight;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One offered reading typeface: the app-level [name] the record stores, the
/// platform family it renders with, and the [weight] it is painted at
/// (spec 011 US2; the three bold values are spec 017).
///
/// The stored name is stable, so retuning the mapping later is a code change
/// rather than a data migration (contract
/// `specs/011-reading-experience/contracts/appearance-format.md`).
class ReadingTypeface {
  /// The name in the stored record: `default`, `bold`, `serif`, `serif-bold`,
  /// `mono` or `mono-bold`.
  final String name;

  /// The weight this face is painted at. Code only — the record stores the name
  /// and nothing else (017 D1), so a bold value is a new *value* of an existing
  /// field and the grammar `<typeface>||<size>` with its read rules do not move.
  final FontWeight weight;

  const ReadingTypeface._(this.name, [this.weight = FontWeight.normal]);

  /// The app's shipped look. No family is set, so the theme's own family
  /// renders — the app ships no font, and neither does this option add one.
  static const defaultFace = ReadingTypeface._('default');

  /// 017: the default family in bold — the family the walked device paints a
  /// real bold with (its variable `wght` axis; 017 research D5).
  static const bold = ReadingTypeface._('bold', FontWeight.w700);
  static const serif = ReadingTypeface._('serif');
  static const serifBold = ReadingTypeface._('serif-bold', FontWeight.w700);
  static const mono = ReadingTypeface._('mono');
  static const monoBold = ReadingTypeface._('mono-bold', FontWeight.w700);

  /// The offered set, in the order the screen shows it: each family, then its
  /// bold (017 decision 5).
  static const all = [defaultFace, bold, serif, serifBold, mono, monoBold];

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
  /// stays in the fallback chain and Chinese text keeps rendering. A bold value
  /// asks for the same family as its regular (`bold` alone names none, so the
  /// theme's own family carries the weight — 017 D5).
  String? familyFor(TargetPlatform platform) => switch (name) {
        'serif' || 'serif-bold' => platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
            ? 'Times New Roman'
            : 'serif',
        'mono' || 'mono-bold' => platform == TargetPlatform.iOS ||
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

  /// The size a comment's own characters are painted at when the reading text
  /// is at [points] (017 D2): the NEXT offered size down, and — below the
  /// smallest offered size — the derived 10, because the reader asked for a
  /// visible difference and no smaller size is offered to fall to.
  ///
  /// The one helper both paints go through: the page's span split and the
  /// video's block, so a page and a frame can never disagree about it. Nothing
  /// is stored and no control offers it (017 FR-012).
  static double commentPointsFor(double points) {
    double? below;
    for (final size in all) {
      if (size.points < points) below = size.points;
    }
    return below ?? 10;
  }

  /// This size's own comment size — [commentPointsFor] on [points].
  double get commentPoints => commentPointsFor(points);

  /// 019: the ladder a mark's and a comment's look is derived from — the four
  /// offered sizes in the reader's own order, then the **largest** offered size
  /// at the bold weight 017's faces carry and at the black weight beyond them
  /// (FR-006, data-model.md § The ladder).
  ///
  /// A rung carries **both** a size and a weight: the ladder is one list, and
  /// the two heavier rungs are values no control offers — 017's derived
  /// ten-point comment size is the precedent (FR-010, A6).
  static const List<(double, FontWeight)> rungs = [
    (12, FontWeight.w400),
    (14, FontWeight.w400),
    (18, FontWeight.w400),
    (24, FontWeight.w400),
    (24, FontWeight.w700),
    (24, FontWeight.w900),
  ];

  /// The rung a reader's own choice sits on (FR-006): the last rung **not
  /// above** their choice — their size at their face's weight.
  ///
  /// A bold face below the top size sits where its size sits, which is what
  /// makes a bold body's marks the regular rungs above it.
  static int rungOf(double points, FontWeight weight) {
    var rung = 0;
    for (var i = 0; i < rungs.length; i++) {
      final above = rungs[i].$1 > points ||
          (rungs[i].$1 == points && rungs[i].$2.value > weight.value);
      if (above) break;
      rung = i;
    }
    return rung;
  }

  /// 019: the rung a mark is painted at — **two** steps above the reader's own
  /// for a title (`level == 1`), **one** for a subtitle, clamped at the
  /// ladder's last rung (FR-006).
  static (double, FontWeight) headingRungFor(
      double points, FontWeight weight, int level) {
    final up = rungOf(points, weight) + (level == 1 ? 2 : 1);
    return rungs[up < rungs.length ? up : rungs.length - 1];
  }

  /// 019/017: the rung a comment is painted at — the step **down**, the weight
  /// first and the size second (FR-015): from a body heavier than the regular
  /// weight the comment is the **same size at `w400`**; from a regular body it
  /// is 017's own next size down, and below the smallest offered size, 017's
  /// derived 10.
  static (double, FontWeight) commentRungFor(
      double points, FontWeight weight) {
    if (weight.value > FontWeight.w400.value) {
      return (points, FontWeight.w400);
    }
    return (commentPointsFor(points), FontWeight.w400);
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
  /// `voice_*` or `interface_language` record.
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
