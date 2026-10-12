/// The reading appearance's record contract (spec 011 US2):
/// `specs/011-reading-experience/contracts/appearance-format.md` — the read
/// rules, the write protocol and the invariants a test can assert.
///
/// The read rules are pure functions, so most of this file needs no prefs at
/// all; the store's own half uses the mocked `shared_preferences` map.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/appearance_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the read rules (contract § Read rules)', () {
    test('no record is the defaults', () {
      expect(ReadingAppearance.decode(null).encode(), 'default||medium');
    });

    test('a well-formed record round-trips', () {
      final held = ReadingAppearance.decode('serif||xlarge');
      expect(held.typeface.name, 'serif');
      expect(held.size.name, 'xlarge');
      expect(held.encode(), 'serif||xlarge');
    });

    test('the three bold names round-trip and fall back per field (017 T002)', () {
      for (final name in const ['bold', 'serif-bold', 'mono-bold']) {
        final held = ReadingAppearance.decode('$name||xlarge');
        expect(held.typeface.name, name);
        expect(held.size.name, 'xlarge');
        expect(held.encode(), '$name||xlarge');
      }
      final unknownSize = ReadingAppearance.decode('serif-bold||huge');
      expect(unknownSize.typeface.name, 'serif-bold');
      expect(unknownSize.size.name, 'medium');
    });

    test('every offered face encodes as exactly two parts (017 INV-1)', () {
      for (final face in ReadingTypeface.all) {
        for (final size in ReadingSize.all) {
          final parts =
              ReadingAppearance(typeface: face, size: size).encode().split('||');
          expect(parts.length, 2, reason: '${face.name}||${size.name}');
          expect(parts[0], isNotEmpty);
          expect(parts[1], isNotEmpty);
        }
      }
    });

    test('a field that names nothing the app ships falls back on its own', () {
      // Invariant 3: the other field still applies.
      final unknownFace = ReadingAppearance.decode('Helvetica||xlarge');
      expect(unknownFace.typeface.name, 'default');
      expect(unknownFace.size.name, 'xlarge');

      final unknownSize = ReadingAppearance.decode('serif||huge');
      expect(unknownSize.typeface.name, 'serif');
      expect(unknownSize.size.name, 'medium');
    });

    // Invariant 4: every malformed shape reads as the defaults, and none of
    // them throws — a stale or hand-edited value is not an error.
    for (final malformed in const [
      '',
      'serif',
      'serif||',
      '||xlarge',
      'serif||xlarge||extra',
    ]) {
      test('malformed "$malformed" reads as the defaults', () {
        expect(ReadingAppearance.decode(malformed).encode(), 'default||medium');
      });
    }
  });

  group('AppearanceStore (contract § Write protocol)', () {
    test('save then load round-trips', () async {
      final store = AppearanceStore();
      await store.save(const ReadingAppearance(
        typeface: ReadingTypeface.serif,
        size: ReadingSize.xlarge,
      ));
      final held = await store.load();
      expect(held.encode(), 'serif||xlarge');
    });

    test('one confirm writes exactly one key, under no other record\'s name',
        () async {
      final store = AppearanceStore();
      await store.save(const ReadingAppearance(
        typeface: ReadingTypeface.mono,
        size: ReadingSize.large,
      ));
      final prefs = await SharedPreferences.getInstance();
      // Invariant 7: one write per confirm — not one key per field, so a
      // half-finished write can never leave a new face beside a stale size.
      expect(prefs.getKeys(), {AppearanceStore.key});
      expect(prefs.getString(AppearanceStore.key), 'mono||large');
      // Invariant 5: the namespace collides with no existing record.
      expect(AppearanceStore.key, 'reading_appearance');
      expect(AppearanceStore.key, isNot(startsWith('voice_')));
      expect(AppearanceStore.key, isNot(startsWith('read_position_')));
      expect(AppearanceStore.key, isNot('interface_language'));
    });

    test('the last confirm wins, and never appends a second record', () async {
      final store = AppearanceStore();
      await store.save(const ReadingAppearance(
        typeface: ReadingTypeface.serif,
        size: ReadingSize.small,
      ));
      await store.save(const ReadingAppearance(
        typeface: ReadingTypeface.defaultFace,
        size: ReadingSize.medium,
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {AppearanceStore.key});
      expect((await store.load()).encode(), 'default||medium');
    });

    test('a malformed stored value loads as the defaults, left in place',
        () async {
      SharedPreferences.setMockInitialValues({
        AppearanceStore.key: 'garbage-no-separator',
      });
      final store = AppearanceStore();
      expect((await store.load()).encode(), 'default||medium');
      final prefs = await SharedPreferences.getInstance();
      // Not repaired or rewritten: the next confirm is what overwrites it.
      expect(prefs.getString(AppearanceStore.key), 'garbage-no-separator');
    });
  });

  group('the offered sets (contract § What the keys mean when rendered)', () {
    test('six typefaces, four sizes, and medium is the size the app ships',
        () {
      // Re-cut by 017 T002: the offered list is the contract's six names, and
      // this is the case that pins it (the widget tests' label loops do not).
      expect(ReadingTypeface.all.map((face) => face.name),
          ['default', 'bold', 'serif', 'serif-bold', 'mono', 'mono-bold']);
      expect(ReadingSize.all.map((size) => size.name),
          ['small', 'medium', 'large', 'xlarge']);
      // Invariant 2's "the default is a no-op" is pinned where the style is
      // actually built: the widget tests assert the page's own style seam under
      // the app's theme (`medium` == what the page rendered before, size 14, no
      // family). A bare `ThemeData()` has no explicit `bodyMedium` size at all,
      // so comparing against it here would assert nothing.
      expect(ReadingSize.all.first.points, lessThan(ReadingSize.medium.points));
      expect(ReadingSize.all.last.points, greaterThan(ReadingSize.large.points));
    });

    test('default asks for no family; the named faces map per platform', () {
      expect(ReadingTypeface.defaultFace.familyFor(TargetPlatform.android),
          isNull);
      expect(ReadingTypeface.serif.familyFor(TargetPlatform.android), 'serif');
      expect(ReadingTypeface.mono.familyFor(TargetPlatform.android),
          'monospace');
      // The iOS column is the CoreText name for the same intent (D5).
      expect(ReadingTypeface.serif.familyFor(TargetPlatform.iOS),
          'Times New Roman');
      expect(ReadingTypeface.mono.familyFor(TargetPlatform.iOS),
          'Courier New');
    });

    test('a comment is one offered size down, and smaller at the smallest '
        '(017 INV-3/INV-4)', () {
      expect(ReadingSize.xlarge.commentPoints, ReadingSize.large.points);
      expect(ReadingSize.large.commentPoints, ReadingSize.medium.points);
      expect(ReadingSize.medium.commentPoints, ReadingSize.small.points);
      // Nothing smaller is offered to fall to, and the reader asked for a
      // visible difference: the derived 10 (017 decision 2).
      expect(ReadingSize.small.commentPoints, 10);
      // The invariant the reader's own words make: strictly smaller, always.
      for (final size in ReadingSize.all) {
        expect(size.commentPoints, lessThan(size.points), reason: size.name);
      }
    });

    test('a bold value keeps its family and changes only the weight (017 INV-9)',
        () {
      // D5: `bold` names no family either (the theme's own, the device's one
      // real-bold family); the named bolds keep their regular's family.
      expect(ReadingTypeface.bold.familyFor(TargetPlatform.android), isNull);
      expect(ReadingTypeface.serifBold.familyFor(TargetPlatform.android),
          'serif');
      expect(ReadingTypeface.monoBold.familyFor(TargetPlatform.android),
          'monospace');
      expect(ReadingTypeface.serifBold.familyFor(TargetPlatform.iOS),
          'Times New Roman');
      expect(ReadingTypeface.monoBold.familyFor(TargetPlatform.iOS),
          'Courier New');

      for (final face in const [
        ReadingTypeface.bold,
        ReadingTypeface.serifBold,
        ReadingTypeface.monoBold,
      ]) {
        expect(face.weight, FontWeight.w700, reason: face.name);
      }
      for (final face in const [
        ReadingTypeface.defaultFace,
        ReadingTypeface.serif,
        ReadingTypeface.mono,
      ]) {
        expect(face.weight, isNot(FontWeight.w700), reason: face.name);
      }
    });
  });
}
