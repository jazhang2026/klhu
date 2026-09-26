/// Spike S1 (spec 012, T003) — what does this device's speech engine actually
/// write to disk, and does the file carry its own length?
///
/// Throwaway probe. Run it on the reference device, then read the report off
/// the device (or the log):
///
///     flutter run -d emulator-5554 -t specs/012-reading-video/scripts/probe_synthesize.dart
///     adb shell run-as com.example.klhu cat /data/data/com.example.klhu/cache/s1_report.txt
///     adb exec-out run-as com.example.klhu cat \
///       /data/data/com.example.klhu/cache/s1_en.wav > /tmp/s1_en.wav   # then ffprobe it
///
/// The answer is recorded in `specs/012-reading-video/breakpoint.md`; this file
/// stays as the method that produced it. Nothing under `lib/` imports it, and
/// the probe exits the app itself when it is done.
///
/// Why the report is a file: `dart:io`'s `stdout` is not forwarded from the
/// Android embedder (the first run of this probe produced no console output at
/// all), so the answer is written where it can be read back with `run-as` — the
/// log line alone is not a receipt.
///
/// Why it exists: the renderer's timeline (research D3) needs each sentence's
/// exact length, and the plan's answer assumed that can be read out of the
/// file's own header. The plugin's call exists both in Dart and in Kotlin (F1),
/// but the engine's half is the part nobody has verified (F5) — and the format
/// decides whether the duration is in a header (RIFF/WAVE) or has to be decoded
/// (MPEG/Opus).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// One sentence to write, with the language the app would set for it.
class _Case {
  const _Case(this.label, this.text, this.language, {this.pickVoice = false});

  final String label;
  final String text;
  final String language;

  /// Whether to resolve a voice from the engine's installed list and set it
  /// before writing — the path `reader_service.dart:374-387` takes for a picked
  /// voice, and the one FR-003 needs to hold for the video's audio too.
  final bool pickVoice;
}

const _cases = <_Case>[
  _Case('en', 'The quick brown fox jumps over the lazy dog.', 'en-US'),
  _Case('zh', '从这里开始没有可朗读的内容。', 'zh-CN'),
  _Case('zh-picked', '从这里开始没有可朗读的内容。', 'zh-CN', pickVoice: true),
];

final _lines = <String>[];

/// Records a line both ways: the log for a live run, the report for a read-back
/// (see the note at the top of this file).
void _say(String line) {
  _lines.add(line);
  debugPrint('S1 $line');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tts = FlutterTts();
  final dir = await getTemporaryDirectory();

  // FlutterTtsPlugin.kt holds the Dart future until the engine reports
  // completion only when this flag is on; without it the call resolves before
  // the file exists, which is exactly the trap pass 1 would fall into.
  await tts.awaitSynthCompletion(true);
  _say('engine=${await tts.getDefaultEngine}');
  final raw = await tts.getVoices;
  final installed = raw is List ? raw : const <dynamic>[];
  _say('voices=${installed.length}');
  _say('zh voices=${_zhVoiceNames(installed)}');

  for (final probe in _cases) {
    final file = File('${dir.path}/s1_${probe.label}.wav');
    if (file.existsSync()) file.deleteSync();

    final picked = probe.pickVoice ? _firstZhVoice(installed) : null;
    final language = await tts.setLanguage(picked?['locale'] ?? probe.language);
    var chosen = '';
    if (picked != null) {
      try {
        final ok = await tts.setVoice(picked);
        chosen = ' setVoice=${picked['name']}|${picked['locale']} -> $ok';
      } catch (e) {
        chosen = ' setVoice threw=$e';
      }
    }
    final started = DateTime.now();
    dynamic result;
    var thrown = '';
    try {
      result = await tts.synthesizeToFile(probe.text, file.path, true);
    } catch (e) {
      thrown = ' threw=$e';
    }
    final ms = DateTime.now().difference(started).inMilliseconds;

    _say('${probe.label} lang=${probe.language} setLanguage=$language$chosen '
        'result=$result$thrown wall=${ms}ms ${_describe(file)}');
  }

  await tts.stop();
  await File('${dir.path}/s1_report.txt').writeAsString('${_lines.join('\n')}\n');
  _say('report=${dir.path}/s1_report.txt');
  exit(0);
}

/// The Chinese names and locales the engine offers, in the picker's order — the
/// list a picked voice has to come from (`reader_service.dart:374-379`).
List<String> _zhVoiceNames(List<dynamic> voices) {
  final names = <String>[];
  for (final v in voices) {
    if (v is! Map) continue;
    final locale = v['locale']?.toString() ?? '';
    if (!locale.toLowerCase().startsWith('zh')) continue;
    names.add('${v['name']}@$locale');
    if (names.length == 12) break;
  }
  return names;
}

/// The first Chinese voice that is NOT the language's own default, so the picked
/// case proves a *chosen* voice is honoured rather than the default twice.
Map<String, String>? _firstZhVoice(List<dynamic> voices) {
  for (final v in voices) {
    if (v is! Map) continue;
    final name = v['name']?.toString();
    final locale = v['locale']?.toString();
    if (name == null || locale == null) continue;
    if (!locale.toLowerCase().startsWith('zh')) continue;
    if (name == 'zh-CN-language') continue;
    return {'name': name, 'locale': locale};
  }
  return null;
}

/// What the file itself says: its container, its size, and — for a RIFF/WAVE
/// file, which carries its own sample count — its length in milliseconds.
String _describe(File file) {
  if (!file.existsSync()) return 'file=none';
  final bytes = file.readAsBytesSync();
  if (bytes.length < 12) return 'file=${bytes.length}B magic=short';
  final magic = String.fromCharCodes(bytes.sublist(0, 4));
  final head = 'hex0=${_hex(bytes, 16)}';
  if (magic != 'RIFF') return 'file=${bytes.length}B magic=$magic $head';
  return 'file=${bytes.length}B magic=RIFF $head ${_wav(bytes)}';
}

String _hex(Uint8List bytes, int count) {
  final end = count < bytes.length ? count : bytes.length;
  return bytes
      .sublist(0, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Walks a RIFF/WAVE file's chunks for the two that matter: `fmt ` (sample
/// rate, channels, bits per sample) and `data` (the payload's length).
String _wav(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  int? rate;
  int? channels;
  int? bits;
  int? data;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final length = view.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ' && offset + 24 <= bytes.length) {
      channels = view.getUint16(offset + 10, Endian.little);
      rate = view.getUint32(offset + 12, Endian.little);
      bits = view.getUint16(offset + 22, Endian.little);
    } else if (id == 'data') {
      data = length;
    }
    offset += 8 + length + (length.isOdd ? 1 : 0);
  }
  int? frames;
  if (rate != null && channels != null && bits != null && data != null) {
    if (channels > 0 && bits > 0) {
      frames = (data / (bits / 8) / channels).round();
    }
  }
  final ms =
      frames != null && rate != null && rate > 0 ? (frames * 1000 / rate).round() : null;
  return 'fmt={rate:$rate ch:$channels bits:$bits} data=$data '
      'frames=$frames ms=$ms';
}
