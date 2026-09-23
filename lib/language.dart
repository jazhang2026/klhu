import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/voice_store.dart';

/// Per-paragraph language detection for mixed-language reads (002).
///
/// Content rule: one language per paragraph — a language switch must start a
/// new paragraph. Detection is a rule table so a third language is a new rule
/// row, not new branches: first matching rule wins, fallback is English.
typedef _LanguageRule = String? Function(String paragraph);

/// Rule 1: CJK ideograph presence → Simplified Chinese.
String? _cjkRule(String paragraph) {
  // CJK Unified Ideographs, Extension A, Compatibility Ideographs.
  // (CJK punctuation like 。！？ alone does NOT flip the paragraph.)
  const cjk = '\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff';
  return RegExp('[$cjk]').hasMatch(paragraph) ? 'zh-Hans' : null;
}

const List<_LanguageRule> _rules = [_cjkRule, _spanishRule];

/// Spanish-only letters: á é í ó ú ü ñ ¿ ¡. English text has none of them, so a
/// single occurrence is already decisive.
final RegExp _spanishLetters = RegExp('[áéíóúüñ¿¡]', caseSensitive: false);

/// High-frequency Spanish function words, used for text that carries no accent
/// ("Hola, como estas" typed without accents). Two DISTINCT hits are required so
/// an English sentence containing "no" or "son" cannot flip the paragraph.
const Set<String> _spanishWords = {
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
  'de', 'del', 'que', 'y', 'en', 'con', 'para', 'por', 'es', 'son',
  'está', 'están', 'este', 'esta', 'esto', 'muy', 'pero', 'como',
  'se', 'su', 'sus', 'al', 'mi', 'tu', 'yo', 'nos', 'les', 'más',
};

/// Rule 2: Spanish accents, or two distinct Spanish function words.
String? _spanishRule(String paragraph) {
  if (_spanishLetters.hasMatch(paragraph)) return 'es';
  final hits = <String>{};
  for (final match in RegExp(r'[a-z]+', caseSensitive: false)
      .allMatches(paragraph.toLowerCase())) {
    if (_spanishWords.contains(match.group(0))) hits.add(match.group(0)!);
    if (hits.length >= 2) return 'es';
  }
  return null;
}

/// Detect the language of one paragraph: `'zh-Hans'`, `'es'` or `'en'`.
String detectLanguage(String paragraph) {
  for (final rule in _rules) {
    final hit = rule(paragraph);
    if (hit != null) return hit;
  }
  return 'en';
}

/// Split the [start]/[end] range of [content] into per-paragraph speeches.
///
/// Language is detected on each FULL paragraph (a sentence tap inherits its
/// enclosing paragraph's language); the spoken text is the overlap with the
/// requested range. [loadVoice] supplies the picked voice per language
/// (null ≡ OS default).
Future<List<ParagraphSpeech>> resolveParagraphSpeeches(
  String content,
  int start,
  int end,
  Future<VoiceChoice?> Function(String language) loadVoice,
) async {
  final speeches = <ParagraphSpeech>[];
  for (final para in paragraphRanges(content)) {
    if (para.start >= end || para.end <= start) continue;
    final language = detectLanguage(content.substring(para.start, para.end));
    final from = start < para.start ? para.start : start;
    final to = end > para.end ? para.end : end;
    if (from >= to) continue;
    speeches.add(
      ParagraphSpeech(
        text: content.substring(from, to),
        language: language,
        voice: await loadVoice(language),
        start: from,
        end: to,
      ),
    );
  }
  return speeches;
}
