/// 031 — the image-prompt tag's own rule: `[image_prompt]`, `[图像提示]`,
/// `[imagem]`, `[prompt_img]`.
///
/// Everything here is DERIVED from the reader's text and recomputed on every
/// open: which lines carry the tag, where the prompt text begins. Nothing about
/// an image prompt is stored, and nothing here touches scene or comment tags —
/// the caller pairs image-prompt tags with scene tags after parsing both
/// independently (research D2).
///
/// The tag has **four spellings**, one for each language the app's own locales
/// are written in (FR-001, the reader's `please include: 图像提示、imagem、prompt_img`
/// of 2026-11-05). The ASCII rows are matched case-insensitively; the CJK rows
/// exactly (they have no case to fold). The brackets are ASCII `[` `]` only —
/// `［图像提示］`, a Chinese IME's own default, is the reader's ordinary text.
///
/// The tag is a **line**: it opens at a line's head, whatever follows the closing
/// `]` on that same line is the prompt text. The whole line — tag, prompt text and
/// the break that ends it — belongs to the marker (data-model §1). That is why
/// this file's unit is the line and not a character span: masking and eliding both
/// read the same numbers.
library;

import 'segmenter.dart';
import 'scene_tag.dart';

/// The spellings this app recognises, one row per language its own locales are
/// written in: English, Simplified Chinese, Traditional Chinese and Spanish
/// (FR-001, the reader's of 2026-11-05). The ASCII rows are matched
/// case-insensitively.
const List<String> imagePromptSpellings = [
  'image_prompt',
  '图像提示',
  '圖像提示',
  'imagem',
  'prompt_img',
];

/// Whether [name] is one of [imagePromptSpellings] — the ASCII rows in any case,
/// the CJK rows exactly.
bool isImagePromptSpelling(String name) {
  final lower = name.toLowerCase();
  return imagePromptSpellings
      .any((spelling) => spelling.toLowerCase() == lower);
}

/// One tag in the reader's text, and the line it rules (data-model §1).
class ImagePromptTag {
  /// The spelling as written — `image_prompt`/`imagem`/`prompt_img` in whatever
  /// case, `图像提示` exactly.
  final String spelling;

  /// Offset of the line's first `[`, after the line's leading spaces/tabs.
  final int start;

  /// Just past the closing `]`.
  final int markEnd;

  /// Offset of the prompt text's first character — after the tag, separator,
  /// and any leading spaces.
  final int contentStart;

  /// The line's first character, its leading spaces/tabs included — where the
  /// span that is masked and elided starts.
  final int lineStart;

  /// Just past the line's last non-whitespace character — the `\n` that ends
  /// the line excluded.
  final int lineEnd;

  const ImagePromptTag({
    required this.spelling,
    required this.start,
    required this.markEnd,
    required this.contentStart,
    required this.lineStart,
    required this.lineEnd,
  });

  /// The span every surface uses: the line and the break that ends it.
  (int, int) spanIn(String text) =>
      (lineStart, lineEnd < text.length ? lineEnd + 1 : text.length);

  /// The tag's own characters, as written.
  String markerIn(String text) => text.substring(start, markEnd);

  /// The prompt text the line carries after its `]` — empty for a tag alone.
  String promptIn(String text) => text.substring(contentStart, lineEnd);
}

/// Every tag [text] holds, in text order (FR-001, FR-002).
///
/// [inside] are the spans a tag is **not** recognised in — a comment's own
/// `[tag.start, contentEnd)` and a marked line's `(start, lineEnd)`, computed by
/// the caller so this rule stays independent of those two.
///
/// A tag is a line's **first** non-space characters: `[`, one of
/// [imagePromptSpellings], `]`, then whatever prompt text the reader wrote after
/// it. A shape that fails any clause is the reader's own text — painted, read
/// and counted as written, never repaired (FR-007).
List<ImagePromptTag> imagePromptTagsOf(
  String text, {
  List<(int, int)> inside = const [],
}) {
  final tags = <ImagePromptTag>[];
  var lineStart = 0;
  while (true) {
    final newline = text.indexOf('\n', lineStart);
    final rawEnd = newline < 0 ? text.length : newline;
    var lineEnd = rawEnd;
    while (lineEnd > lineStart && _isLineTail(text[lineEnd - 1])) {
      lineEnd--;
    }
    final tag = _tagAt(text, lineStart, lineEnd);
    if (tag != null && !_isInside(tag.start, inside)) {
      tags.add(tag);
    }
    if (newline < 0) break;
    lineStart = newline + 1;
  }
  return tags;
}

/// One scene: the tag, its image prompt (if any), and the sentences it owns.
///
/// The image prompt is the last `[image_prompt]` line within this scene's span,
/// or null if none exists.
class SceneWithPrompt {
  final SceneTag sceneTag;
  final ImagePromptTag? imagePrompt;
  final int ordinal;
  final int first;
  final int last;
  final int sentenceCount;

  const SceneWithPrompt({
    required this.sceneTag,
    this.imagePrompt,
    required this.ordinal,
    required this.first,
    required this.last,
    required this.sentenceCount,
  });
}

/// Pair each [Scene] with its image prompt (if any), using [imagePromptTags].
///
/// A scene's prompt is the last `[image_prompt]` tag whose span falls within
/// the scene's `[first, last)` range. Orphaned prompts (not inside any scene)
/// are skipped.
List<SceneWithPrompt> scenesWithPrompts(
  List<Scene> scenes,
  List<ImagePromptTag> imagePromptTags,
) {
  if (scenes.isEmpty) return const [];
  final result = <SceneWithPrompt>[];
  for (var i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    ImagePromptTag? prompt;
    for (final tag in imagePromptTags) {
      final (from, to) = tag.spanIn('');
      // Check if the tag's line falls within the scene's range.
      if (tag.lineStart >= scene.first && tag.lineStart < scene.last) {
        prompt = tag; // Last matching tag wins.
      }
    }
    result.add(SceneWithPrompt(
      sceneTag: scene.tag,
      imagePrompt: prompt,
      ordinal: scene.ordinal,
      first: scene.first,
      last: scene.last,
      sentenceCount: scene.sentenceCount,
    ));
  }
  return result;
}

/// What each of [text]'s tags owns, in text order.
List<SceneWithPrompt> scenesWithPromptsOf(
  String text, {
  List<(int, int)> inside = const [],
}) {
  final scenes = scenesOf(text, inside: inside);
  final prompts = imagePromptTagsOf(text, inside: inside);
  return scenesWithPrompts(scenes, prompts);
}

/// [text] with every image-prompt line replaced by spaces of the same length.
String imagePromptMasked(
  String text, {
  List<(int, int)> inside = const [],
}) =>
    _maskedFromTags(text, imagePromptTagsOf(text, inside: inside));

/// The mask of [tags].
String _maskedFromTags(String text, List<ImagePromptTag> tags) {
  if (tags.isEmpty) return text;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final tag in tags) {
    final (from, to) = tag.spanIn(text);
    if (from > cursor) buffer.write(text.substring(cursor, from));
    buffer.write(' ' * (to - from));
    cursor = to;
  }
  if (cursor < text.length) buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// Try to read a tag at [lineStart..lineEnd]. Returns null if the line does not
/// begin with a recognised spelling.
ImagePromptTag? _tagAt(String text, int lineStart, int lineEnd) {
  // Skip leading whitespace.
  var at = lineStart;
  while (at < lineEnd && _isSpace(text[at])) at++;
  if (at >= lineEnd || text[at] != '[') return null;
  // Find the closing `]`.
  var close = text.indexOf(']', at);
  if (close < 0 || close >= lineEnd) return null;
  // Extract and check the spelling.
  final name = text.substring(at + 1, close).trim();
  if (!isImagePromptSpelling(name)) return null;
  // The prompt text starts after `]` and any trailing whitespace.
  var contentStart = close + 1;
  while (contentStart < lineEnd && _isSpace(text[contentStart])) contentStart++;
  return ImagePromptTag(
    spelling: name,
    start: at,
    markEnd: close + 1,
    contentStart: contentStart,
    lineStart: lineStart,
    lineEnd: lineEnd,
  );
}

bool _isInside(int pos, List<(int, int)> inside) {
  for (final (from, to) in inside) {
    if (pos >= from && pos < to) return true;
  }
  return false;
}

bool _isLineTail(char) => char == ' ' || char == '\t' || char == '\r';
bool _isSpace(char) => char == ' ' || char == '\t' || char == '\n' || char == '\r';
