/// Guard for the 007 regression class: a string added to the template ARB and
/// only some of the translations still compiles, still generates, and renders
/// English in the locale nobody re-checked. Every message key in the template
/// must exist in every translation file this app ships.
///
/// The ARB files are localization DATA (`flutter gen-l10n` consumes them), so
/// comparing their key sets is a contract test, not a source-shape assertion.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Message keys only: `@key` entries carry metadata for the template and are
/// never required in a translation file.
Set<String> _messageKeys(String path) {
  final decoded = json.decode(File(path).readAsStringSync());
  return {
    for (final key in (decoded as Map<String, Object?>).keys)
      if (!key.startsWith('@')) key,
  };
}

void main() {
  const arbDir = 'lib/l10n';
  const template = '$arbDir/app_en.arb';

  List<File> translations() => Directory(arbDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && f.path != template)
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the app ships more than the template locale', () {
    expect(translations(), isNotEmpty,
        reason: 'no translation ARBs found under $arbDir');
  });

  test('every template key exists in every translation ARB', () {
    final wanted = _messageKeys(template);
    expect(wanted, isNotEmpty);

    final missing = <String, List<String>>{};
    for (final file in translations()) {
      final have = _messageKeys(file.path);
      final gaps = wanted.difference(have).toList()..sort();
      if (gaps.isNotEmpty) missing[file.path] = gaps;
    }

    expect(missing, isEmpty,
        reason: 'these keys would render the English fallback in that locale: '
            '$missing');
  });

  test('no translation ARB carries a key the template dropped', () {
    final wanted = _messageKeys(template);

    final extra = <String, List<String>>{};
    for (final file in translations()) {
      final leftovers = _messageKeys(file.path).difference(wanted).toList()
        ..sort();
      if (leftovers.isNotEmpty) extra[file.path] = leftovers;
    }

    expect(extra, isEmpty, reason: 'dead keys (the 008 T023 class): $extra');
  });
}
