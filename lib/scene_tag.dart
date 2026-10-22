/// 024 — the scene tag's own rule: `[scene]`, `[场景]`, `[場景]`, `[escena]`.
///
/// Everything here is DERIVED from the reader's text and recomputed on every
/// open: where the tags stand, which sentences each scene owns, and what the
/// text looks like with every tag line masked to spaces (data-model §1–§3).
/// Nothing about a scene is stored, and nothing here knows about a comment or a
/// mark: the caller passes the spans a scene may not be recognised in (015's
/// comments, 019's marked lines), the way `lib/head_tag.dart:58` already takes
/// its own `inside`, so the three rules keep their own files and never call each
/// other (research D1).
///
/// The tag is a **line**: it opens at a line's head, whatever it writes after
/// the closing `]` is the scene's heading, and the whole line — tag, heading and
/// the break that ends it — belongs to the marker (spec item 10, the reader's
/// own `keep 1`). That is why this file's unit is the line and not a character
/// span: masking and eliding both read the same numbers (data-model I8).
///
/// The brackets are ASCII `[` `]` only — `［场景］`, a Chinese IME's own default,
/// is the reader's ordinary text, and the two ASCII spellings are matched in
/// whatever case the reader typed them (FR-001, research D2).
library;

import 'segmenter.dart';

/// The spellings this app recognises, one row per language its own locales are
/// written in: English, Simplified Chinese, Traditional Chinese and Spanish
/// (FR-001, the reader's `please include: 場景、escena` of 2026-10-20). The ASCII
/// rows are matched case-insensitively.
const List<String> sceneSpellings = ['scene', '场景', '場景', 'escena'];

/// Whether [name] is one of [sceneSpellings] — the ASCII rows in any case, the
/// CJK rows exactly (they have no case to fold).
bool isSceneSpelling(String name) {
  final lower = name.toLowerCase();
  return sceneSpellings.any((spelling) => spelling.toLowerCase() == lower);
}

/// One tag in the reader's text, and the line it rules (data-model §1).
class SceneTag {
  /// The spelling as written — `scene`/`escena` in whatever case, `场景`,
  /// `場景`.
  final String spelling;

  /// Offset of the line's first `[`, after the line's leading spaces/tabs.
  final int start;

  /// Just past the closing `]`.
  final int markEnd;

  /// The line's first character, its leading spaces/tabs **included** — where
  /// the span that is masked and elided starts.
  final int lineStart;

  /// [markEnd], skipping the spaces/tabs that follow the `]`: the heading's own
  /// first character.
  final int headingStart;

  /// Just past the line's last character — the `\n` that ends the line
  /// **excluded**, and its trailing spaces/tabs/`\r` excluded too.
  final int lineEnd;

  const SceneTag({
    required this.spelling,
    required this.start,
    required this.markEnd,
    required this.lineStart,
    required this.headingStart,
    required this.lineEnd,
  });

  /// The span every surface uses: the line and the break that ends it
  /// (data-model §1). A last line that carries no break ends at the text's end.
  (int, int) spanIn(String text) =>
      (lineStart, lineEnd < text.length ? lineEnd + 1 : text.length);

  /// The tag's own characters, as written.
  String markerIn(String text) => text.substring(start, markEnd);

  /// The heading the line carries after its `]` — empty for a tag alone.
  String headingIn(String text) => text.substring(headingStart, lineEnd);
}

/// One scene: the tag, and the sentences it owns (data-model §2).
class Scene {
  final SceneTag tag;

  /// 0-based position among the text's scenes, in text order.
  final int ordinal;

  /// The content offsets bounding what this scene owns: from just past its own
  /// line's break to the next tag's line start, or the text's end.
  final int first;
  final int last;

  /// How many of the text's sentences fall in `[first, last)` — 0 for a scene
  /// with nothing between it and the next tag.
  final int sentenceCount;

  const Scene({
    required this.tag,
    required this.ordinal,
    required this.first,
    required this.last,
    required this.sentenceCount,
  });

  /// Whether this scene owns the text that begins at [textStart] — a sentence's
  /// own first character, with the leading whitespace of a paragraph's first
  /// sentence skipped, so a sentence that runs through a tag line's masked
  /// spaces is the scene's from its first spoken character (FR-003).
  bool owns(int textStart) => textStart >= first && textStart < last;
}

/// Every tag [text] holds, in text order (FR-001, FR-002).
///
/// [inside] are the spans a tag is **not** recognised in — a comment's own
/// `[tag.start, contentEnd)` and a marked line's `(start, lineEnd)`, computed by
/// the caller so this rule stays independent of those two (FR-015, research D1).
///
/// A tag is a line's **first** non-space characters: `[`, one of
/// [sceneSpellings], `]`, then whatever heading the reader wrote after it. A
/// shape that fails any clause is the reader's own text — painted, read and
/// counted as written, never repaired (FR-007).
List<SceneTag> sceneTagsOf(String text, {List<(int, int)> inside = const []}) {
  final tags = <SceneTag>[];
  var lineStart = 0;
  while (true) {
    final newline = text.indexOf('\n', lineStart);
    final rawEnd = newline < 0 ? text.length : newline;
    // The line's own end: its trailing spaces, tabs and the CR of a CRLF line
    // are not the line (data-model §1).
    var lineEnd = rawEnd;
    while (lineEnd > lineStart && _isLineTail(text[lineEnd - 1])) {
      lineEnd--;
    }
    final tag = _tagAt(text, lineStart, lineEnd);
    if (tag != null && !_isInside(tag.start, inside)) tags.add(tag);
    if (newline < 0) break;
    lineStart = newline + 1;
  }
  return tags;
}

/// What each of [text]'s tags owns, in text order (FR-003, FR-014, FR-017).
///
/// The unit is the **read's own sentence** — `sentenceRanges` of the masked text
/// (data-model §3), so a tag line contributes no sentence and the sentences this
/// rule counts are the ones a read speaks. A sentence belongs to a scene when
/// the sentence's **own first character** lies in the scene's range: the first
/// sentence of a paragraph that opens with a tag line starts on that line (its
/// range carries the masked spaces), and its text — `他推门进来。` — is the
/// scene's. Reading the range's raw start instead would silently hand the first
/// sentence of every tagged paragraph to nobody, which is the shape the fixture
/// in the quickstart measures (`2, 2, 1` sentences on its three scenes).
///
/// The heading on a tag line is owned by nobody (FR-017) and the sentences
/// before the first tag are too (FR-014): neither begins inside a scene's range.
List<Scene> scenesOf(String text, {List<(int, int)> inside = const []}) =>
    scenesFromTags(text, sceneTagsOf(text, inside: inside));

/// The scenes of [tags] — the derivation [scenesOf] makes, for a caller that has
/// already read the tags (one derivation, two uses: data-model I8).
List<Scene> scenesFromTags(String text, List<SceneTag> tags) {
  if (tags.isEmpty) return const [];
  final masked = maskedFromTags(text, tags);
  final sentences = sentenceRanges(masked);
  final scenes = <Scene>[];
  for (var i = 0; i < tags.length; i++) {
    final tag = tags[i];
    // The tag's own break is part of the marker, so what it owns begins after it
    // — and a last line with no break owns whatever follows its end, which is
    // nothing.
    final first = tag.lineEnd < text.length ? tag.lineEnd + 1 : text.length;
    final last = i + 1 < tags.length ? tags[i + 1].lineStart : text.length;
    var count = 0;
    for (final sentence in sentences) {
      final begin = _textStart(masked, sentence);
      if (begin >= first && begin < last) count++;
    }
    scenes.add(
      Scene(
        tag: tag,
        ordinal: i,
        first: first,
        last: last,
        sentenceCount: count,
      ),
    );
  }
  return scenes;
}

/// Where the sentence [sentence] begins to say something: its own first
/// character, the leading whitespace the segmenter leaves in a paragraph's first
/// sentence skipped.
int _textStart(String text, TextSegment sentence) {
  var at = sentence.start;
  while (at < sentence.end && _isSpace(text[at])) {
    at++;
  }
  return at;
}

bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';

/// [text] with every tag line replaced by spaces of the same length — the string
/// the speech-bearing derivations are cut from (data-model §3, plan D5).
///
/// Every offset outside a tag line is unchanged and the length is the same, so a
/// sentence the read speaks is still the content's own span (data-model I1, I3).
/// Inside a tag line every character becomes a space: the heading's `：` and any
/// `。` in it are spaces too, so nothing there starts or ends a sentence — the
/// hard case `[scene] 第一场。他说。` yields no sentence for `第一场。` and swallows
/// none of `他说。` (FR-005).
///
/// A text with no tag is returned **as it is**, which is what makes a tag-free
/// content's every derived list the one it had before this feature (FR-016).
String sceneMasked(String text, {List<(int, int)> inside = const []}) =>
    maskedFromTags(text, sceneTagsOf(text, inside: inside));

/// The mask of [tags] — [sceneMasked]'s own derivation, for a caller that has
/// already read the tags (the page's display, data-model I8).
String maskedFromTags(String text, List<SceneTag> tags) {
  if (tags.isEmpty) return text;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final tag in tags) {
    final (from, to) = tag.spanIn(text);
    if (from > cursor) buffer.write(text.substring(cursor, from));
    buffer.write(' ' * (to - from));
    cursor = to;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// The reader's own text with every scene tag at the head of its own paragraph —
/// and NOTHING else (FR-006, SC-004, data-model I10).
///
/// One `\n` goes in at the tag's own line start when that line does not already
/// begin a paragraph: the smallest edit that gives the tag a paragraph of its
/// own. No character of the reader's words is altered, no tag is added or
/// removed, and a heading on the tag line stays where the reader put it. A text
/// already in the format comes back byte-identical, so pressing the button twice
/// is pressing it once, the editor's button knows when it has nothing to do, and
/// one Undo is enough to take the press back.
String formatForSceneTags(String text, {List<(int, int)> inside = const []}) {
  final tags = sceneTagsOf(text, inside: inside);
  if (tags.isEmpty) return text;
  final heads = {for (final para in paragraphRanges(text)) para.start};
  final insertAt = <int>[
    for (final tag in tags)
      if (tag.lineStart > 0 && !heads.contains(tag.lineStart)) tag.lineStart,
  ];
  if (insertAt.isEmpty) return text;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final at in insertAt) {
    buffer.write(text.substring(cursor, at));
    buffer.write('\n');
    cursor = at;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// The tag the line `[lineStart, lineEnd)` carries, or null.
SceneTag? _tagAt(String text, int lineStart, int lineEnd) {
  var i = lineStart;
  while (i < lineEnd && (text[i] == ' ' || text[i] == '\t')) {
    i++;
  }
  if (i >= lineEnd || text[i] != '[') return null;
  final close = text.indexOf(']', i + 1);
  // The pair never spans a line: a `]` on a later line does not close this one.
  if (close < 0 || close >= lineEnd) return null;
  final spelling = text.substring(i + 1, close).trim();
  if (!isSceneSpelling(spelling)) return null;
  var heading = close + 1;
  while (heading < lineEnd && (text[heading] == ' ' || text[heading] == '\t')) {
    heading++;
  }
  return SceneTag(
    spelling: spelling,
    start: i,
    markEnd: close + 1,
    lineStart: lineStart,
    headingStart: heading,
    lineEnd: lineEnd,
  );
}

bool _isLineTail(String char) => char == ' ' || char == '\t' || char == '\r';

bool _isInside(int offset, List<(int, int)> spans) =>
    spans.any((span) => offset >= span.$1 && offset < span.$2);
