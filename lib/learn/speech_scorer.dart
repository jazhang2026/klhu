/// Transcript-vs-target comparison for Learn mode (spec 035 FR-004/FR-011,
/// research R5). Pure Dart, fully on-device: normalizes both sides, aligns
/// tokens with an LCS, and reports accuracy plus missed/extra words.
library;

/// The outcome of comparing one recognized repeat against its sentence.
class ScoreResult {
  /// matched tokens / target tokens, clamped to 0.0–1.0.
  final double accuracy;

  /// The normalized recognized text (lowercase, punctuation stripped).
  final String transcript;

  /// Target tokens the alignment did not match, in target order.
  final List<String> missed;

  /// Recognized tokens the alignment did not match, in recognized order.
  final List<String> extra;

  const ScoreResult({
    required this.accuracy,
    required this.transcript,
    required this.missed,
    required this.extra,
  });
}

final _cjk = RegExp(r'[一-鿿]');
final _nonWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _spaces = RegExp(r'\s+');

/// Lowercase, drop punctuation/symbols, collapse whitespace.
String _normalize(String text) =>
    text.toLowerCase().replaceAll(_nonWord, ' ').replaceAll(_spaces, ' ').trim();

/// Whether [text] contains CJK ideographs — decides char- vs word-level diff.
bool _isCjk(String text) => _cjk.hasMatch(text);

/// Tokens for comparison: CJK targets compare per character, everything else
/// per whitespace-delimited word.
List<String> _tokens(String normalized, {required bool cjk}) {
  if (normalized.isEmpty) return const [];
  if (cjk) {
    return normalized.split('').where(_wordChar.hasMatch).toList();
  }
  return normalized.split(' ').where((w) => w.isNotEmpty).toList();
}

/// LCS alignment of [target] against [recognized]: the target indices and the
/// recognized indices that pair up under a longest common subsequence.
({Set<int> target, Set<int> recognized}) _align(
    List<String> target, List<String> recognized) {
  final m = target.length, n = recognized.length;
  final matchedTarget = <int>{};
  final matchedRecognized = <int>{};
  if (m == 0 || n == 0) return (target: matchedTarget, recognized: matchedRecognized);
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = target[i - 1] == recognized[j - 1]
          ? dp[i - 1][j - 1] + 1
          : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
    }
  }
  var i = m, j = n;
  while (i > 0 && j > 0) {
    if (target[i - 1] == recognized[j - 1]) {
      matchedTarget.add(i - 1);
      matchedRecognized.add(j - 1);
      i--;
      j--;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  return (target: matchedTarget, recognized: matchedRecognized);
}

/// Score [recognized] against [target]. [recognized] may be empty (silence).
ScoreResult scoreTranscript(String target, String recognized) {
  final targetNorm = _normalize(target);
  final recogNorm = _normalize(recognized);
  final cjk = _isCjk(targetNorm);
  final targetTokens = _tokens(targetNorm, cjk: cjk);
  final recogTokens = _tokens(recogNorm, cjk: cjk);

  if (targetTokens.isEmpty) {
    return ScoreResult(
        accuracy: 0, transcript: recogNorm, missed: const [], extra: const []);
  }

  final aligned = _align(targetTokens, recogTokens);
  final missed = <String>[
    for (var i = 0; i < targetTokens.length; i++)
      if (!aligned.target.contains(i)) targetTokens[i],
  ];
  final extra = <String>[
    for (var j = 0; j < recogTokens.length; j++)
      if (!aligned.recognized.contains(j)) recogTokens[j],
  ];

  return ScoreResult(
    accuracy: (aligned.target.length / targetTokens.length).clamp(0.0, 1.0),
    transcript: recogNorm,
    missed: missed,
    extra: extra,
  );
}
