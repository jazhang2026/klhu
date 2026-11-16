/// Read-language resolution (spec 034): the single seam every read goes
/// through — explicit overrides first, detection last.
///
/// Precedence (FR-004): role override → content main override → the
/// detector's answer for the unit. `detectLanguage` (`lib/language.dart`)
/// stays the "auto" value; a stronger detector swaps in behind it without
/// touching this file (FR-009).
library;

/// Languages a read can be pinned to — the three shipped locales.
const supportedReadLanguages = ['en', 'zh-Hans', 'es'];

/// The "detect it for me" setting value.
const autoLanguage = 'auto';

/// Resolve the read language for one unit.
///
/// [detected] is the detector's answer for this unit (paragraph or role
/// turn). [main] is the content's `readLang`. [role] is the dialogue role
/// name when resolving a turn; [roleLangs] its override map.
String resolveReadLanguage({
  required String detected,
  String main = autoLanguage,
  String? role,
  Map<String, String> roleLangs = const {},
}) {
  if (role != null) {
    final pick = roleLangs[role];
    if (pick != null && pick != autoLanguage) return pick;
  }
  if (main != autoLanguage) return main;
  return detected;
}

/// The language label key for a setting value, for UI display.
String readLanguageLabel(String value) => value;
