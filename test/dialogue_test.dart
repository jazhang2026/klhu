import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/language.dart';

/// The dialogue rules themselves, with no widget, no store and no device: the
/// prefix rule, the turns, the roles, and the Format transformation
/// (specs/014-dialogue-reading, FR-003/004/005/006/009/011/024).
void main() {
  group('the prefix rule (FR-004)', () {
    test('a braced name at the paragraph head opens the turn', () {
      const text = '{阿明} 你好。';
      final turn = turnsOf(text).single;
      expect(turn.role, '阿明');
      expect(turn.text, '你好。');
      // The prefix is outside the span: never spoken, never highlighted.
      expect(text.substring(turn.contentStart, turn.contentEnd), '你好。');
    });

    test('the separator is optional: a colon and spaces are all part of it', () {
      for (final head in ['{阿明} 你好', '{阿明}: 你好', '{阿明} : 你好', '{阿明}:你好']) {
        final turn = turnsOf(head).single;
        expect(turn.role, '阿明', reason: head);
        expect(turn.text, '你好', reason: head);
      }
    });

    test('a name may be long and may hold spaces', () {
      final turn = turnsOf('{May Anne} hello').single;
      expect(turn.role, 'May Anne');
      expect(turn.text, 'hello');

      final long = turnsOf('{${'名' * 20}} 你好').single;
      expect(long.role, '名' * 20);
    });

    test('leading spaces before the tag are part of the prefix', () {
      final turn = turnsOf('  {阿明} 你好').single;
      expect(turn.role, '阿明');
      expect(turn.text, '你好');
    });

    test('a colon alone is never a speaker — narration, every shape', () {
      for (final line in [
        '12:30',
        'https://example.com/x',
        '时间：8 点',
        '他说：我来了',
        'May: hello',
      ]) {
        final turn = turnsOf(line).single;
        expect(turn.role, isNull, reason: line);
        expect(turn.text, line, reason: line);
      }
    });

    test('an unclosed brace, an empty name and full-width braces are narration',
        () {
      for (final text in ['{阿明 你好', '{} 你好', '｛阿明｝ 你好']) {
        final turn = turnsOf(text).single;
        expect(turn.role, isNull, reason: text);
        expect(turn.text, text, reason: text);
      }
    });

    test('a tag inside a paragraph is ordinary text, braces and all', () {
      const text = '{阿明} 你好。\n{阿芳} 我很好。';
      final turns = turnsOf(text);
      expect(turns.length, 1, reason: 'no blank line, so one paragraph');
      expect(turns.single.role, '阿明');
      expect(turns.single.text, '你好。\n{阿芳} 我很好。');
    });
  });

  group('a turn is a paragraph (FR-003)', () {
    test('a blank line is the only boundary', () {
      final turns = turnsOf('{阿明} 你好。\n\n{阿芳} 我很好。');
      expect(turns.map((t) => t.role), ['阿明', '阿芳']);
      expect(turns.map((t) => t.text), ['你好。', '我很好。']);
    });

    test('one paragraph is one turn however many lines and sentences it holds',
        () {
      const text = '{阿明} 你好。\n我很好。谢谢。';
      final turn = turnsOf(text).single;
      expect(turn.role, '阿明');
      expect(turn.text, '你好。\n我很好。谢谢。');
    });

    test('a tag-only paragraph is dropped, not counted and not read', () {
      expect(turnsOf('{阿明}'), isEmpty);
      expect(turnsOf('{阿明}\n\n你好。').map((t) => t.text), ['你好。']);
      // A tag-only first line: the content is the paragraph's other lines.
      final turn = turnsOf('{阿明}\n你好。').single;
      expect(turn.role, '阿明');
      expect(turn.text, '你好。');
    });

    test('trailing whitespace is not content', () {
      expect(turnsOf('{阿明} 你好。   ').single.text, '你好。');
    });

    test('a sub-range returns the turns it overlaps, clipped to it', () {
      const text = '{阿明} 你好。\n\n{阿芳} 我很好。';
      final secondStart = text.indexOf('{阿芳}');
      final turns = turnsOf(text, start: secondStart, end: text.length);
      expect(turns.length, 1);
      expect(turns.single.role, '阿芳');
      expect(turns.single.text, '我很好。');
    });
  });

  group('narration (FR-009)', () {
    test('a paragraph with no tag belongs to nobody', () {
      final turns = turnsOf('{阿明} 你好。\n\n旁白一句。\n\n{阿芳} 我很好。');
      expect(turns.map((t) => t.role), ['阿明', null, '阿芳']);
    });

    test('narration after a role is not attributed to it', () {
      final turns = turnsOf('{阿明} 你好。\n\n又是旁白。');
      expect(turns.last.role, isNull);
      expect(turns.last.text, '又是旁白。');
    });
  });

  group('the roles a text proposes (FR-006)', () {
    test('first-appearance order, with their readable turn counts', () {
      const text = '{B} 一。\n\n{A} 二。\n\n{B} 三。';
      final roles = rolesOf(turnsOf(text));
      expect(roles.map((r) => r.name), ['B', 'A']);
      expect(roles.map((r) => r.turnCount), [2, 1]);
    });

    test('the same name written differently is a different role', () {
      final roles = rolesOf(turnsOf('{May} 一。\n\n{may} 二。'));
      expect(roles.map((r) => r.name), ['May', 'may']);
    });

    test('a name with one turn is still a role', () {
      expect(rolesOf(turnsOf('{阿明} 你好。')).single.name, '阿明');
    });

    test('narration is never a role', () {
      expect(rolesOf(turnsOf('旁白。\n\n{阿明} 你好。')).map((r) => r.name), ['阿明']);
    });
  });

  group('a removed name (FR-007)', () {
    test('its paragraphs are narration afterwards, prefix still excluded', () {
      const text = '{阿芳} 我很好。\n\n{阿明} 你好。';
      final turns = turnsOf(text, removed: {'阿芳'});
      expect(turns.first.role, isNull);
      expect(turns.first.text, '我很好。');
      expect(rolesOf(turns).map((r) => r.name), ['阿明']);
    });
  });

  group('the tag does not decide the language (FR-011)', () {
    test('the language rule reads the turn content, not the prefix', () {
      const text = '{阿明} hello world';
      // The raw paragraph is CJK-wins… and the turn is English.
      expect(detectLanguage(text), 'zh-Hans');
      expect(detectLanguage(turnsOf(text).single.text), 'en');
    });
  });

  group('Format (FR-024)', () {
    test('a tag already heading its paragraph is left alone', () {
      const text = '{阿明} 你好。\n\n{阿芳} 我很好。';
      expect(formatForDialogue(text), text);
    });

    test('two tags on one line each get their own paragraph', () {
      expect(
        formatForDialogue('{阿明} 你好。{阿芳} 我很好。'),
        '{阿明} 你好。\n\n{阿芳} 我很好。',
      );
    });

    test('a tag on a paragraph second line gains one blank line', () {
      expect(
        formatForDialogue('你好。\n{阿芳} 我很好。'),
        '你好。\n\n{阿芳} 我很好。',
      );
    });

    test('a tag mid-line is pushed onto its own paragraph', () {
      expect(
        formatForDialogue('他说 {阿明} 你好。'),
        '他说 \n\n{阿明} 你好。',
      );
    });

    test('nothing to format: the text comes back byte-identical', () {
      for (final text in [
        'no tags here at all。',
        '{} 你好',
        '{阿明 你好',
        '｛阿明｝ 你好',
        '你好。\n\n我很好。',
      ]) {
        expect(formatForDialogue(text), text, reason: text);
      }
    });

    test('only blank lines are added — no other character changes', () {
      for (final text in [
        '{阿明} 你好。{阿芳} 我很好。',
        '你好。\n{阿芳} 我很好。',
        '他说 {阿明} 你好。',
      ]) {
        final formatted = formatForDialogue(text);
        expect(formatted.replaceAll('\n', ''), text.replaceAll('\n', ''),
            reason: text);
      }
    });

    test('every tag is a paragraph head afterwards, and pressing twice is '
        'pressing once', () {
      const text = '你好。\n{阿芳} 我很好。{阿明} 你也好。';
      final once = formatForDialogue(text);
      expect(turnsOf(once).map((t) => t.role), [null, '阿芳', '阿明']);
      expect(formatForDialogue(once), once);
    });
  });
}
