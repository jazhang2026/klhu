/// Auto-generated content names (spec 008 T007, research D7).
///
/// A saved page is named after its own first line; the user never types a
/// name, and a name that already exists in the same language gets a ` (2)`,
/// ` (3)` … suffix.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/content_naming.dart';
import 'package:klhu/models/content.dart' show kMaxContentNameChars;

void main() {
  group('preview from text', () {
    test('takes the first non-blank line', () {
      expect(contentNameFrom('\n\n   \nSecond line here\nthird line'),
          'Second line here');
    });

    test('collapses runs of whitespace', () {
      expect(contentNameFrom('  Hello    world\ttab  '), 'Hello world tab');
    });

    test('cuts a long line to the character budget with an ellipsis', () {
      const text =
          'The sun rose over the quiet town. Birds sang in the tall trees.';
      final name = contentNameFrom(text);
      expect(name.runes.length, kMaxContentNameChars);
      expect(name.endsWith('…'), isTrue);
      expect(name.startsWith('The sun rose over the'), isTrue);
    });

    test('leaves a line that just fits untouched', () {
      const text = 'Twenty four characters!!'; // exactly 24
      expect(contentNameFrom(text), text);
      expect(text.runes.length, kMaxContentNameChars);
    });

    test('cuts CJK by rune, never mid-character', () {
      final text = '中文' * 20;
      final name = contentNameFrom(text);
      expect(name.runes.length, kMaxContentNameChars);
      expect(name.endsWith('…'), isTrue);
      // No replacement characters from a split UTF-16 pair.
      expect(name.contains('\uFFFD'), isFalse);
    });

    test('is empty for whitespace-only text (refused before naming)', () {
      expect(contentNameFrom('   \n\t\n '), isEmpty);
      expect(contentNameFrom(''), isEmpty);
    });
  });

  group('uniqueness within one language', () {
    test('keeps the base name when it is free', () {
      expect(uniqueContentName('Morning notes', const []), 'Morning notes');
      expect(uniqueContentName('Morning notes', const ['Evening notes']),
          'Morning notes');
    });

    test('suffixes (2), (3) … on collision', () {
      expect(uniqueContentName('Notes', const ['Notes']), 'Notes (2)');
      expect(uniqueContentName('Notes', const ['Notes', 'Notes (2)']),
          'Notes (3)');
    });

    test('reuses a gap instead of counting up forever', () {
      expect(uniqueContentName('Notes', const ['Notes', 'Notes (3)']),
          'Notes (2)');
    });

    test('only compares against the names it is given', () {
      // The store passes one language's names: a same-named entry in another
      // language must not force a suffix.
      expect(uniqueContentName('Notes', const []), 'Notes');
    });
  });
}
