/// 019 — the head tag's own rule: `#` a title, `##` a subtitle.
///
/// Everything here is DERIVED from the reader's text and recomputed on every
/// read: which lines carry a mark, which of the two marks it is, the characters
/// that belong to the marker, and the line the mark rules (data-model.md §
/// HeadTag). Nothing about a mark is stored, and nothing here knows about a
/// comment: the caller passes the spans a mark may not be recognised in (015's
/// comments), so the two rules keep their own files and never call each other
/// (research D7, the same separation 014's and 015's rules keep).
///
/// The rule is deliberately narrow and every clause errs towards the reader's
/// own text: a shape that fails any of them is painted **and read** as written
/// (FR-002, FR-014), never repaired and never silently dropped.
library;

import 'segmenter.dart';

/// One mark in the reader's text (data-model.md § HeadTag).
class HeadTag {
  /// `1` for `#` (a title), `2` for `##` (a subtitle). No other value exists:
  /// `### ` and longer runs are the reader's own text (FR-002).
  final int level;

  /// The offset of the line's first `#`.
  final int start;

  /// Just past the marker **and its one space** — the span `[start, markEnd)`
  /// is what the display elides and what the voice never hears (FR-003,
  /// FR-004).
  final int markEnd;

  /// The offset of the first character the mark paints: the line's own text
  /// begins here (FR-005).
  final int lineStart;

  /// Just past the line's last character — the `\n` that ends the line
  /// excluded, or the paragraph's own end (FR-008: a mark rules the line it
  /// starts, never the paragraph).
  final int lineEnd;

  const HeadTag({
    required this.level,
    required this.start,
    required this.markEnd,
    required this.lineStart,
    required this.lineEnd,
  });

  /// The marker's own characters, as written: the `#`s and the one space.
  String markerIn(String content) => content.substring(start, markEnd);
}

/// Every mark [text] holds, in text order (FR-001/FR-002/FR-008).
///
/// [inside] are the spans a mark is **not** recognised in — 015's comments'
/// own `[tag.start, contentEnd)`, computed by the caller so this rule stays
/// independent of that one (FR-009, research D7).
List<HeadTag> headTagsOf(String text, {List<(int, int)> inside = const []}) {
  final marks = <HeadTag>[];
  for (final paragraph in paragraphRanges(text)) {
    var lineStart = paragraph.start;
    while (lineStart < paragraph.end) {
      final lineEnd = _lineEndOf(text, lineStart, paragraph.end);
      final marker = _markAt(text, lineStart, lineEnd);
      if (marker != null && !_isInside(lineStart, inside)) {
        marks.add(HeadTag(
          level: marker.$1,
          start: lineStart,
          markEnd: marker.$2,
          lineStart: marker.$2,
          lineEnd: lineEnd,
        ));
      }
      if (lineEnd >= paragraph.end) break;
      lineStart = lineEnd + 1;
    }
  }
  return marks;
}

/// The end of the line that begins at [from]: the `\n` that closes it, or [to]
/// — the end of the run the line lives in.
int _lineEndOf(String text, int from, int to) {
  final newline = text.indexOf('\n', from);
  return (newline < 0 || newline > to) ? to : newline;
}

/// The mark the line `[from, to)` carries, as `(level, markEnd)`, or null.
///
/// A mark is a line's **first** characters and nothing else (FR-001): one or
/// two `#`, then exactly one ASCII space, then at least one character that is
/// neither a space nor a tab. A line whose own text ends with a `#`-sequence is
/// refused **whole** — a trailing `#` closer is not this app's rule, and SC-003
/// keeps that shape byte-identical to today (research D2's reading of FR-002).
(int, int)? _markAt(String text, int from, int to) {
  if (from >= to || text[from] != '#') return null;
  var i = from;
  while (i < to && text[i] == '#') {
    i++;
  }
  final level = i - from;
  if (level > 2) return null;
  if (i >= to || text[i] != ' ') return null;
  final after = i + 1;
  if (after >= to || text[after] == ' ' || text[after] == '\t') return null;
  var last = to - 1;
  while (last >= after && (text[last] == ' ' || text[last] == '\t')) {
    last--;
  }
  if (last < after) return null;
  if (text[last] == '#') return null;
  return (level, after);
}

bool _isInside(int offset, List<(int, int)> spans) =>
    spans.any((span) => offset >= span.$1 && offset < span.$2);
