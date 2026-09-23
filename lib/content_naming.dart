/// Auto-generated names for saved content (spec 008, research D7).
///
/// The user never types a name: a saved page is named after its own first
/// line, and a name that is already used in the same language gets a ` (2)`,
/// ` (3)` … suffix.
library;

import 'package:klhu/models/content.dart' show kMaxContentNameChars;

/// The preview name of [text]: its first non-blank line, whitespace collapsed,
/// cut to [maxChars] runes with a trailing ellipsis.
///
/// Empty for whitespace-only text, which the store refuses before naming, so
/// a saved entry's name is never blank.
String contentNameFrom(String text, {int maxChars = kMaxContentNameChars}) {
  for (final line in text.split('\n')) {
    final collapsed = line.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) continue;
    return _cut(collapsed, maxChars);
  }
  return '';
}

/// Runewise, so a cut can never split a surrogate pair.
String _cut(String value, int maxChars) {
  final runes = value.runes.toList();
  if (runes.length <= maxChars) return value;
  return '${String.fromCharCodes(runes.take(maxChars - 1))}…';
}

/// [base], with the smallest free ` (n)` suffix. [taken] is what exists in the
/// entry's own language, so the same words in another language stay unsuffixed.
String uniqueContentName(String base, Iterable<String> taken) {
  final existing = taken.toSet();
  if (!existing.contains(base)) return base;
  for (var n = 2;; n++) {
    final candidate = '$base ($n)';
    if (!existing.contains(candidate)) return candidate;
  }
}
