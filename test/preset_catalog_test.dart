/// Pre-set catalog tests (spec 008 T016).
///
/// Two things must hold: the shipped `assets/content/presets.json` is valid and
/// complete, and one malformed entry can never take the others down with it
/// (FR-017/FR-020, research D3/D11).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/content_naming.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

void main() {
  // Read the shipped file the way the app bundles it (declared in pubspec under
  // `assets/content/`), so the test fails if the data ever goes bad.
  String shippedCatalog() =>
      File('assets/content/presets.json').readAsStringSync();

  group('shipped catalog', () {
    test('parses into pre-sets with unique ids', () {
      final presets = parsePresetCatalog(shippedCatalog());

      expect(presets, hasLength(3));
      expect(presets.map((p) => p.id).toSet(), hasLength(3));
      expect(presets.map((p) => p.id),
          containsAll(['preset_en_sample', 'preset_zh_sample', 'preset_es_sample']));
    });

    test('every pre-set has the three reading languages covered', () {
      final presets = parsePresetCatalog(shippedCatalog());

      expect(presets.map((p) => p.language).toSet(),
          containsAll(['en', 'zh-Hans', 'es']));
      for (final preset in presets) {
        expect(preset.text.trim(), isNotEmpty);
        // Titles are auto-generated from the text: never empty, always one line.
        final title = contentNameFrom(preset.text);
        expect(title.trim(), isNotEmpty, reason: '${preset.id} has no title');
        expect(title, isNot(contains('\n')));
        expect(title.runes.length, lessThanOrEqualTo(kMaxContentNameChars));
        // Idiomatic text, not a placeholder: each pre-set carries a paragraph
        // break, which is what the per-paragraph reader needs.
        expect(preset.text, contains('\n\n'));
      }
    });

    test('a long first line is cut to one line with an ellipsis', () {
      final preset = PresetContent(
        id: 'preset_x',
        language: 'en',
        text: 'A very long opening line that will not fit on one row at all.\n'
            'Second paragraph.',
      );

      final title = contentNameFrom(preset.text);
      expect(title.endsWith('…'), isTrue);
      expect(title.runes.length, kMaxContentNameChars);
      expect(title, isNot(contains('Second')));
    });

    test('the version field is honoured, not ignored', () {
      final decoded = jsonDecode(shippedCatalog()) as Map<String, Object?>;

      expect(decoded['version'], 1);
    });
  });

  group('malformed catalog entries', () {
    test('an entry with no text is skipped, the rest survive', () {
      final presets = parsePresetCatalog('''
{
  "version": 1,
  "presets": [
    {"id": "preset_a", "language": "en", "name": {"en": "A"}, "text": "Ok."},
    {"id": "preset_b", "language": "en", "name": {"en": "B"}, "text": "   "},
    {"id": "preset_c", "language": "en", "name": {"en": "C"}, "text": "Also ok."}
  ]
}
''');

      expect(presets.map((p) => p.id), ['preset_a', 'preset_c']);
    });

    test('a leftover name map is ignored, not required', () {
      // Older catalogs shipped localized names; the model no longer reads them.
      final presets = parsePresetCatalog('''
{
  "version": 1,
  "presets": [
    {"id": "preset_a", "language": "en", "text": "Ok."},
    {"id": "preset_b", "language": "en", "name": {"en": "B"}, "text": "Also ok."}
  ]
}
''');

      expect(presets.map((p) => p.id), ['preset_a', 'preset_b']);
      expect(presets.first.text, 'Ok.');
    });

    test('a duplicate id is only kept once', () {
      final presets = parsePresetCatalog('''
{
  "version": 1,
  "presets": [
    {"id": "preset_a", "language": "en", "name": {"en": "A"}, "text": "First."},
    {"id": "preset_a", "language": "es", "name": {"es": "A"}, "text": "Second."}
  ]
}
''');

      expect(presets, hasLength(1));
      expect(presets.single.text, 'First.');
    });

    test('a JSON payload that is not a catalog yields no pre-sets', () {
      expect(parsePresetCatalog('[1, 2, 3]'), isEmpty);
      expect(parsePresetCatalog('{"version": 1}'), isEmpty);
      expect(parsePresetCatalog('not json at all'), isEmpty);
    });

    test('an entry whose text is blank is skipped', () {
      final presets = parsePresetCatalog('''
{
  "version": 1,
  "presets": [
    {"id": "preset_a", "language": "en", "text": "Ok."},
    {"id": "preset_b", "language": "en", "text": ""}
  ]
}
''');

      expect(presets.map((p) => p.id), ['preset_a']);
    });
  });
}
