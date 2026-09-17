/// Pure-Dart text segmentation for tap-to-resolve read-aloud.
///
/// Sentences split on `. ! ? ;` + CJK `。！？；……` (delimiter kept with the
/// sentence, including trailing closing quotes/brackets). Paragraphs split on
/// blank lines; a single `\n` inside a paragraph does not break it. Page is
/// the full loaded text (v1 has no pagination).
enum SegmentUnit { sentence, paragraph, page }

class TextSegment {
  final int start;
  final int end;
  final SegmentUnit unit;

  const TextSegment(this.start, this.end, this.unit);
}

const _sentenceEnders = {'.', '!', '?', ';', '。', '！', '？', '；'};
const _closers = {'"', "'", '”', '’', '»', ')', ']', '}'};

bool _isEllipsisAt(String text, int i) {
  // ASCII "..." or CJK "……" treated as one sentence ender.
  if (text.startsWith('...', i)) return true;
  if (text[i] == '…' && i + 1 < text.length && text[i + 1] == '…') return true;
  return false;
}

int _enderLength(String text, int i) {
  if (text.startsWith('...', i)) return 3;
  if (text[i] == '…' && i + 1 < text.length && text[i + 1] == '…') return 2;
  return 1;
}

List<TextSegment> sentenceRanges(String text) {
  final ranges = <TextSegment>[];
  int start = 0;
  int i = 0;
  while (i < text.length) {
    int end = -1;
    if (_isEllipsisAt(text, i)) {
      end = i + _enderLength(text, i);
    } else if (_sentenceEnders.contains(text[i])) {
      end = i + 1;
    }
    if (end != -1) {
      // Absorb closing quotes/brackets right after the delimiter.
      while (end < text.length && _closers.contains(text[end])) {
        end++;
      }
      ranges.add(TextSegment(start, end, SegmentUnit.sentence));
      start = end;
      // Leading whitespace belongs to no sentence; taps there resolve
      // to the nearest sentence (tie goes to the earlier one).
      while (start < text.length &&
          (text[start] == ' ' ||
              text[start] == '\t' ||
              text[start] == '\n' ||
              text[start] == '\r')) {
        start++;
      }
      i = start;
    } else {
      i++;
    }
  }
  if (start < text.length) {
    ranges.add(TextSegment(start, text.length, SegmentUnit.sentence));
  }
  return ranges;
}

List<TextSegment> paragraphRanges(String text) {
  final ranges = <TextSegment>[];
  // Split on blank lines (two+ newlines possibly with spaces between).
  final blankLine = RegExp(r'\n[ \t]*\n+');
  int start = 0;
  for (final m in blankLine.allMatches(text)) {
    // Trim trailing newlines/spaces off the paragraph end.
    int end = m.start;
    while (end > start &&
        (text[end - 1] == '\n' ||
            text[end - 1] == ' ' ||
            text[end - 1] == '\t')) {
      end--;
    }
    if (end > start) {
      ranges.add(TextSegment(start, end, SegmentUnit.paragraph));
    }
    start = m.end;
  }
  // Trim leading whitespace of the last paragraph.
  while (start < text.length &&
      (text[start] == '\n' || text[start] == ' ' || text[start] == '\t')) {
    // Only skip newlines at the very start; keep simple.
    if (text[start] == '\n') {
      start++;
    } else {
      break;
    }
  }
  if (start < text.length) {
    int end = text.length;
    while (end > start && text[end - 1] == '\n') {
      end--;
    }
    ranges.add(TextSegment(start, end, SegmentUnit.paragraph));
  }
  return ranges;
}

TextSegment pageRange(String text) =>
    TextSegment(0, text.length, SegmentUnit.page);

int _clamp(int offset, String text) {
  if (text.isEmpty) return 0;
  if (offset < 0) return 0;
  if (offset >= text.length) return text.length - 1;
  return offset;
}

/// Resolve [offset] to its containing segment; whitespace taps fall back to
/// the nearest segment by boundary distance.
TextSegment _resolve(String text, int offset, List<TextSegment> ranges,
    SegmentUnit unit) {
  if (ranges.isEmpty) return TextSegment(0, text.length, unit);
  final o = _clamp(offset, text);
  for (final r in ranges) {
    if (o >= r.start && o < r.end) return r;
  }
  // Nearest by distance to segment boundaries.
  TextSegment best = ranges.first;
  int bestDist = _dist(o, best);
  for (final r in ranges.skip(1)) {
    final d = _dist(o, r);
    if (d < bestDist) {
      bestDist = d;
      best = r;
    }
  }
  return best;
}

int _dist(int o, TextSegment r) {
  if (o < r.start) return r.start - o;
  if (o >= r.end) return o - r.end + 1;
  return 0;
}

TextSegment resolveSentence(String text, int offset) =>
    _resolve(text, offset, sentenceRanges(text), SegmentUnit.sentence);

TextSegment resolveParagraph(String text, int offset) =>
    _resolve(text, offset, paragraphRanges(text), SegmentUnit.paragraph);
