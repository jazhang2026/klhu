/// Pure-Dart text segmentation for tap-to-resolve read-aloud.
///
/// Sentences split on `. ! ? ;` + CJK `。！？；……` (delimiter kept with the
/// sentence, including trailing closing quotes/brackets) — and a paragraph's
/// own end is a sentence's end too, so no sentence spans a blank line.
/// Paragraphs split on blank lines; a single `\n` inside a paragraph does not
/// break it. Page is the full loaded text (v1 has no pagination).
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

/// The sentences **inside one run of text**, by the delimiter rule alone.
///
/// `[from, to)` is that run — a paragraph, or the whole text — and the offsets
/// returned are the text's own. The delimiter stays with the sentence it ends,
/// and so do any closing quotes or brackets right after it; the whitespace that
/// follows a delimiter belongs to no sentence, and a tap there resolves to the
/// nearest one (the tie goes to the earlier).
List<TextSegment> _sentencesIn(String text, int from, int to) {
  final ranges = <TextSegment>[];
  int start = from;
  int i = from;
  while (i < to) {
    int end = -1;
    if (_isEllipsisAt(text, i) && i + _enderLength(text, i) <= to) {
      end = i + _enderLength(text, i);
    } else if (_sentenceEnders.contains(text[i])) {
      end = i + 1;
    }
    if (end != -1) {
      // Absorb closing quotes/brackets right after the delimiter.
      while (end < to && _closers.contains(text[end])) {
        end++;
      }
      ranges.add(TextSegment(start, end, SegmentUnit.sentence));
      start = end;
      // Leading whitespace belongs to no sentence; taps there resolve
      // to the nearest sentence (tie goes to the earlier one).
      while (start < to && _isSpace(text[start])) {
        start++;
      }
      i = start;
    } else {
      i++;
    }
  }
  if (start < to) {
    ranges.add(TextSegment(start, to, SegmentUnit.sentence));
  }
  return ranges;
}

bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';

/// The whole text's sentences, **cut per paragraph**.
///
/// A blank line ends a paragraph (`paragraphRanges`), and it ends a sentence
/// with it: no range returned here spans one. That is not a second rule on top
/// of [_sentencesIn] — it is the same rule applied to the runs the read already
/// uses. The read speaks one paragraph at a time (`reader_service.dart:412`) and
/// its language is detected per paragraph, one language per paragraph, so a
/// speech may not cross a blank line (`lib/language.dart`); the video cuts its
/// slots the same way (`video_timeline.dart:80`). The tap, the tracking
/// highlight and the restored position ask *this* function of the whole text
/// (`reading_view.dart:975`, `:538`) — 011's 2026-09-24 amendment binds those
/// three to the sentence being spoken, so all of them have to answer the same
/// unit. Before this, a title line with no full stop made the whole-text view a
/// single sentence covering the title **and** the paragraph under it, while the
/// read spoke them as two.
List<TextSegment> sentenceRanges(String text) {
  final ranges = <TextSegment>[];
  for (final para in paragraphRanges(text)) {
    ranges.addAll(_sentencesIn(text, para.start, para.end));
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
