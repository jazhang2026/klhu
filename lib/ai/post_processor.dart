/// Post-processes raw AI text responses to strip conversational header/footer.
///
/// AI models often wrap their actual content in filler like "Sure! Here's your
/// story…" or "Let me know if you need anything else!". This module removes
/// those lines so the reading content lands cleanly.
///
/// The algorithm is heuristic, not perfect:
/// 1. Split the response into lines.
/// 2. Scan from the top, skipping lines that look like conversational filler.
/// 3. The first line that doesn't match a filler pattern is the content start.
/// 4. Scan from the bottom, skipping lines that look like sign-offs.
/// 5. The last non-filler line is the content end.
/// 6. If no clean split is found, return the original text unchanged.
library;

/// Conversational filler patterns — lines matching any of these are stripped.
/// Case-insensitive prefix matches.
const List<String> _headerFillerPatterns = [
  'sure',
  'here\'s your',
  'here is your',
  'here is a',
  'here\'s a',
  'ok ',
  'okay ',
  'alright',
  'here you',
  'i\'ve got',
  'i have got',
  'let me',
  'of course',
  'certainly',
  'absolutely',
  'great',
  'happy to',
  'glad to',
  'no problem',
  'here is the',
];

/// Sign-off / footer filler patterns — lines matching any of these are stripped.
const List<String> _footerFillerPatterns = [
  'let me know',
  'let me know if',
  'hope this helps',
  'hope this is helpful',
  'feel free to',
  'if you need',
  'if you have',
  'good luck',
  'enjoy reading',
  'let me know if you',
  'don\'t hesitate',
  'please let me',
  'is there anything',
  'anything else',
  'i hope you',
];

/// Whether [line] looks like conversational filler at the start of a response.
bool _isHeaderFiller(String line) {
  final lower = line.trim().toLowerCase();
  return _headerFillerPatterns.any(
      (pattern) => lower.startsWith(pattern.toLowerCase()));
}

/// Whether [line] looks like a sign-off at the end of a response.
bool _isFooterFiller(String line) {
  final lower = line.trim().toLowerCase();
  return _footerFillerPatterns.any(
      (pattern) => lower.startsWith(pattern.toLowerCase()));
}

/// Strip conversational header and footer from [rawText].
///
/// Returns the cleaned text, or [rawText] unchanged if no clean split is found.
/// The reader can always edit the result by hand.
String postProcessAiText(String rawText) {
  final lines = rawText.split('\n');
  if (lines.length <= 1) return rawText;

  // Find the first non-filler line (content start).
  int start = 0;
  while (start < lines.length && _isHeaderFiller(lines[start])) {
    start++;
  }

  // Find the last non-filler line (content end).
  int end = lines.length - 1;
  while (end >= 0 && _isFooterFiller(lines[end])) {
    end--;
  }

  // If the entire text is filler, return it unchanged.
  if (start > end) return rawText;

  // Return the cleaned portion, trimming blank lines at the edges.
  while (start < lines.length && lines[start].trim().isEmpty) {
    start++;
  }
  while (end >= 0 && lines[end].trim().isEmpty) {
    end--;
  }

  if (start > end) return rawText;

  final cleaned = lines.sublist(start, end + 1).join('\n');
  return cleaned.trim();
}
