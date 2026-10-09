/// 015 — the comment tag's own rule.
///
/// Everything here is DERIVED from the reader's text and recomputed on every
/// read: which marker opens a comment, where the comment's content begins and
/// ends, and which sentence it belongs to (data-model.md §1-§2). Nothing about a
/// comment is stored, and nothing here touches 014's own tag rule — the two
/// tags keep their own implementations and never call each other (research D2,
/// the reader's answer of 2026-10-08), which is why `lib/dialogue.dart`'s
/// `roleTagAt` is not so much as imported.
///
/// The tag has **four spellings**, one for each language the app's own locales
/// are written in, and all four are live in every content whatever language the
/// app itself is showing: the reader types the spelling their own keyboard
/// makes easy (FR-001, A1, research D11). The brackets are ASCII `[` `]` only —
/// `［注］`, a Chinese IME's own default, is the reader's ordinary text.
library;

import 'language.dart';
import 'segmenter.dart';

/// The spellings this app recognises, one row per language its own locales are
/// written in: English, Simplified Chinese, Traditional Chinese and Spanish
/// (FR-001, 2026-10-08). The ASCII rows are matched case-insensitively.
const List<String> commentSpellings = ['comment', '注', '註', 'nota'];

/// Whether [name] is one of [commentSpellings] — the ASCII rows in any case,
/// the CJK rows exactly (they have no case to fold).
bool isCommentSpelling(String name) {
  final lower = name.toLowerCase();
  return commentSpellings.any((spelling) => spelling.toLowerCase() == lower);
}

/// One marker in the reader's text: the tag's own characters, and where the
/// comment's content begins (data-model.md §1).
///
/// [start] is the offset of the opening `[` and [tagEnd] the first character
/// after the tag and the separator that belongs to it — the two ends are what
/// the page elides when it paints (FR-005: the tag's own characters are never
/// painted, and never spoken): everything in `[start, tagEnd)`.
///
/// [contentStart] is where the comment's **content** begins. It is [tagEnd] —
/// after the separator's spaces and its one optional colon — except for a tag
/// alone on its line, where the line break and the following indentation belong
/// to the tag's prefix and the content begins on the paragraph's next line
/// (014's own rule for a tag-only first line, `lib/dialogue.dart:138-145`).
/// That line break is **painted** all the same: the reader's own layout is what
/// FR-012 says the page shows, and only the marker's characters are removed
/// from it (research D3).
class CommentTag {
  /// The spelling as written — `comment` in whatever case, `注`, `註` or `nota`.
  final String name;

  /// Offset of the tag's opening `[`.
  final int start;

  /// Offset just past the tag's own characters *and* its separator.
  final int tagEnd;

  /// Offset of the comment's first content character.
  final int contentStart;

  const CommentTag({
    required this.name,
    required this.start,
    required this.tagEnd,
    required this.contentStart,
  });

  /// The tag's own characters and its separator — the span the page paints
  /// nowhere (FR-005).
  String textIn(String content) => content.substring(start, tagEnd);
}

/// One comment: its marker, its content, and the sentence it belongs to
/// (data-model.md §2). Derived from the text, never stored.
class Comment {
  final CommentTag tag;

  /// Offset just past the comment's last character — the paragraph's last
  /// non-whitespace character (FR-002).
  final int contentEnd;

  /// The comment's own characters.
  final String text;

  /// `detectLanguage(text)` — the comment's **own** content decides it, never
  /// the paragraph it sits in (FR-008, A3).
  final String language;

  /// The sentence this comment belongs to (FR-003): the offsets of its span in
  /// the text, or null when no sentence precedes the tag anywhere — the comment
  /// then belongs to nothing, is displayed, is never spoken and is in no frame.
  final int? ownerStart;
  final int? ownerEnd;

  const Comment({
    required this.tag,
    required this.contentEnd,
    required this.text,
    required this.language,
    required this.ownerStart,
    required this.ownerEnd,
  });

  int get contentStart => tag.contentStart;

  bool get hasOwner => ownerStart != null && ownerEnd != null;

  bool get hasContent => contentStart < contentEnd;
}

/// The comment a paragraph opens, or null when it opens none.
///
/// The **first** well-formed marker anywhere in the paragraph opens the
/// comment; every later marker in that paragraph is the comment's own
/// characters, because the comment runs to the paragraph's end — so there is
/// nothing to nest and a second marker is content, not a second comment (the
/// spec's own edge case, FR-002).
///
/// A marker is well-formed when its name is one of [commentSpellings] and the
/// whole pair sits on one line inside the paragraph. Anything else — the
/// full-width `［注］`, a near miss in any language, an unclosed bracket — is
/// `null`: the readers' own characters, displayed and read as written, never
/// repaired (A1, 014's A9).
CommentTag? commentTagAt(String text, int paragraphStart, int paragraphEnd) {
  if (paragraphStart < 0 || paragraphEnd > text.length) return null;
  var i = paragraphStart;
  while (true) {
    i = text.indexOf('[', i);
    if (i < 0 || i >= paragraphEnd) return null;
    final close = text.indexOf(']', i + 1);
    // The name never spans a line: a pair whose inside holds a line break is
    // not a marker, whatever it says.
    if (close > i + 1 &&
        close < paragraphEnd &&
        !text.substring(i, close).contains('\n') &&
        isCommentSpelling(text.substring(i + 1, close).trim())) {
      final tagEnd = _afterSeparator(text, close + 1, paragraphEnd);
      return CommentTag(
        name: text.substring(i + 1, close).trim(),
        start: i,
        tagEnd: tagEnd,
        contentStart: _contentStart(text, tagEnd, paragraphEnd),
      );
    }
    i = i + 1;
  }
}

/// Every comment [text] holds, in text order (FR-001-003).
///
/// One comment per paragraph at most, and a paragraph whose marker is at its
/// head is a comment with no content — it costs no utterance and no frame, and
/// its characters are not painted either (the spec's own edge case).
List<Comment> commentsOf(String text) {
  final paragraphs = paragraphRanges(text);
  final tags = <CommentTag?>[
    for (final paragraph in paragraphs)
      commentTagAt(text, paragraph.start, paragraph.end),
  ];
  final comments = <Comment>[];
  for (var i = 0; i < paragraphs.length; i++) {
    final tag = tags[i];
    if (tag == null) continue;
    var contentEnd = paragraphs[i].end;
    while (contentEnd > tag.contentStart && _isSpace(text[contentEnd - 1])) {
      contentEnd--;
    }
    final content = text.substring(tag.contentStart, contentEnd);
    final owner = _ownerOf(text, paragraphs, tags, i, tag);
    comments.add(
      Comment(
        tag: tag,
        contentEnd: contentEnd,
        text: content,
        language: detectLanguage(content),
        ownerStart: owner?.$1,
        ownerEnd: owner?.$2,
      ),
    );
  }
  return comments;
}

/// The sentence [tag] belongs to (FR-003): the last sentence that ends before
/// the tag, across paragraph boundaries.
///
/// It is computed in the app's own sentence unit, over the text a read would
/// speak — the paragraph's own text before the tag, and then the paragraphs
/// before it, each one up to its own tag when it has one (a comment's
/// characters are no sentence's span, FR-004). A text whose marker stands
/// before every sentence gives null: the comment belongs to nothing.
///
/// The unit is the segmenter's range, not "ends with a delimiter": for a run
/// with no delimiter before the tag (`Hola [注] Hi.`) the range is all the app
/// has, and it is what the read would have spoken.
(int, int)? _ownerOf(
  String text,
  List<TextSegment> paragraphs,
  List<CommentTag?> tags,
  int index,
  CommentTag tag,
) {
  final own = _lastSentence(text, paragraphs[index].start, tag.start);
  if (own != null) return own;
  for (var i = index - 1; i >= 0; i--) {
    final end = tags[i]?.start ?? paragraphs[i].end;
    final earlier = _lastSentence(text, paragraphs[i].start, end);
    if (earlier != null) return earlier;
  }
  return null;
}

/// The last sentence of `[from, to)`, in the text's own offsets, or null when
/// that range holds none (whitespace alone, or nothing).
(int, int)? _lastSentence(String text, int from, int to) {
  if (to <= from) return null;
  final ranges = sentenceRanges(text.substring(from, to));
  if (ranges.isEmpty) return null;
  final last = ranges.last;
  return (from + last.start, from + last.end);
}

/// What the reading page paints: the reader's text with every comment tag's own
/// characters elided, and the mapping between the two index spaces (data-model
/// §3, FR-005/FR-012).
///
/// The content itself is never rewritten — this is a derived view of it — so the
/// page keeps painting from the same text the app stores, edits, saves, reads
/// and renders, and only the two seams where a *display* offset is created or
/// consumed need the mapping: a tap's answer
/// ([toContent]) and a highlight's own box ([toDisplay]). For a text with no
/// tag the display **is** the content and both mappings are the identity, which
/// is what makes "a content with no tag paints what it painted before" true by
/// construction (SC-004).
class CommentDisplay {
  /// The string the page paints: the content minus every `[start, tagEnd)`.
  final String text;

  /// The text's own comments, in text order — the same ones [commentsOf] gives,
  /// so a caller that needs both (the page, for its taps) derives them once, and
  /// the elided spans are their tags (one source of truth, not two).
  final List<Comment> comments;

  const CommentDisplay._({
    required this.text,
    required this.comments,
  });

  /// The content offset a display offset is painted at.
  ///
  /// An offset inside an elided span answers the first content character after
  /// that span: those characters are not painted at all, so the character at the
  /// display position they occupied is the one that follows them (and for a
  /// comment's tag that character is inside the comment — research D3/D7).
  int toContent(int displayOffset) {
    var content = displayOffset;
    for (final comment in comments) {
      final tag = comment.tag;
      if (displayOffset < toDisplay(tag.start)) break;
      content += tag.tagEnd - tag.start;
    }
    return content;
  }

  /// Where a content offset is painted.
  ///
  /// An offset inside an elided span answers the span's display start, so a
  /// highlight whose end lands inside a tag paints no marker and still covers
  /// the comment's own characters (FR-005, FR-012).
  int toDisplay(int contentOffset) {
    var removed = 0;
    for (final comment in comments) {
      final tag = comment.tag;
      if (contentOffset <= tag.start) break;
      final inside = contentOffset < tag.tagEnd ? contentOffset : tag.tagEnd;
      removed += inside - tag.start;
    }
    return contentOffset - removed;
  }
}

/// The display of [content] — what the reading page paints (data-model §3).
CommentDisplay displayOf(String content) {
  final comments = commentsOf(content);
  if (comments.isEmpty) {
    return CommentDisplay._(text: content, comments: const []);
  }
  final buffer = StringBuffer();
  var cursor = 0;
  for (final comment in comments) {
    final tag = comment.tag;
    buffer.write(content.substring(cursor, tag.start));
    cursor = tag.tagEnd;
  }
  buffer.write(content.substring(cursor));
  return CommentDisplay._(text: buffer.toString(), comments: comments);
}

/// The separator and the spaces after it belong to the tag (FR-001): spaces,
/// one optional `:` or `：`, spaces.
int _afterSeparator(String text, int from, int paragraphEnd) {
  var j = from;
  while (j < paragraphEnd && (text[j] == ' ' || text[j] == '\t')) {
    j++;
  }
  if (j < paragraphEnd && (text[j] == ':' || text[j] == '：')) {
    j++;
    while (j < paragraphEnd && (text[j] == ' ' || text[j] == '\t')) {
      j++;
    }
  }
  return j;
}

/// Where the comment's content begins: after the tag's own characters, except
/// for a tag alone on its line — the content then begins on the paragraph's
/// next line, and the line break in between stays painted (research D3).
int _contentStart(String text, int tagEnd, int paragraphEnd) {
  var j = tagEnd;
  while (j < paragraphEnd && (text[j] == ' ' || text[j] == '\t')) {
    j++;
  }
  if (j < paragraphEnd && text[j] == '\n') {
    var k = j + 1;
    while (k < paragraphEnd && (text[k] == ' ' || text[k] == '\t')) {
      k++;
    }
    return k;
  }
  return tagEnd;
}

bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';
