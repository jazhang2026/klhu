import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/voice_store.dart';

/// Names a language the way the app does on screen — `'zh-Hans'` →
/// `'中文（简体）'` — for the place a content's language is shown on the page: the
/// list's rows. (The video's title card was the second caller until the reader
/// had it withdrawn on 2026-09-29 — spec 012 FR-008's amendment — so the
/// renderer no longer reaches this at all.)
///
/// [l10n] is nullable because the reading page can be built without
/// localisations; the raw code is what it falls back to, so a label is never
/// invented.
String languageLabelOf(AppLocalizations? l10n, String language) {
  if (l10n == null) return language;
  return switch (language) {
    'zh-Hans' => l10n.chineseNative,
    'es' => l10n.spanishNative,
    _ => l10n.englishNative,
  };
}

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

/// Spanish-only words: no English word is made of these letters, so ONE hit
/// already decides the paragraph.
///
/// The accents a Spanish word carries are exactly what a phone keyboard drops:
/// the phrasebook "Buenas tardes." arrives accent-less and was read in an
/// English voice (2026-10-02, on the OnePlus 13), as were "Hola.", "Gracias.",
/// "Por favor." and "Hasta luego." — none of them in the function-word list
/// below, so the paragraph fell through to English. Every entry here is a word
/// English does not have; the ones English borrowed ("nada", "hola") are in
/// deliberately, since a Spanish greeting is what the reader is looking at.
const Set<String> _spanishOnlyWords = {
  'hola', 'gracias', 'buenas', 'buenos', 'buena', 'bueno',
  'tardes', 'tarde', 'noches', 'noche', 'dias', 'manana',
  'hasta', 'luego', 'vamos', 'adios', 'senor', 'senora',
  'usted', 'ustedes', 'nosotros', 'ellos', 'ellas',
  'gusta', 'quiero', 'tengo', 'puedo', 'puedes', 'tiene', 'puede',
  'hacer', 'siento', 'estas', 'estoy',
  'vemos', 'entiendo', 'ayuda',
  'donde', 'cuando', 'porque', 'tambien', 'entonces', 'siempre',
  'nunca', 'ahora', 'aqui', 'alli', 'algo', 'nada', 'mucho', 'poco',
};

/// High-frequency Spanish function words, used for text that carries no accent
/// ("Hola, como estas" typed without accents). Two DISTINCT hits are required so
/// an English sentence containing "no", "son" or "me" cannot flip the paragraph
/// on its own — these words are English words too, which is why they are here
/// and not above.
const Set<String> _spanishWords = {
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
  'de', 'del', 'que', 'y', 'en', 'con', 'para', 'por', 'es', 'son',
  'está', 'están', 'este', 'esta', 'esto', 'muy', 'pero', 'como',
  'se', 'su', 'sus', 'al', 'mi', 'tu', 'yo', 'nos', 'les', 'más',
  'mas', 'favor',
};

/// Rule 2: Spanish accents, one Spanish-only word, or two distinct Spanish
/// function words.
String? _spanishRule(String paragraph) {
  if (_spanishLetters.hasMatch(paragraph)) return 'es';
  final hits = <String>{};
  for (final match in RegExp(r'[a-z]+', caseSensitive: false)
      .allMatches(paragraph.toLowerCase())) {
    final word = match.group(0)!;
    if (_spanishOnlyWords.contains(word)) return 'es';
    if (_spanishWords.contains(word)) hits.add(word);
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
