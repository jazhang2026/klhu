/// The one place a read is resolved, in both modes (FR-019).
///
/// 标准 delegates straight to `resolveParagraphSpeeches` (`lib/language.dart:110`)
/// and touches nothing else; 多人对话 turns the text into turns first
/// (`lib/dialogue.dart`) and resolves each one into the same type. The page, the
/// reader service and the video all consume `List<ParagraphSpeech>` — the single
/// interface they already agree on — so nothing downstream learns that roles
/// exist: the reader service still cuts each speech into sentences with its own
/// `_sentencesOf`, the highlight still reads `start`/`end`, 010's resume offset is
/// still a content offset, and 012's video still receives one entry per sentence
/// (research D1).
library;

import 'package:flutter/foundation.dart';

import 'dialogue.dart';
import 'language.dart';
import 'models/voice_mapping.dart';
import 'reader_service.dart';
import 'voice_store.dart';

/// How a content is read: 标准 is one voice over the text as written; 多人对话
/// reads one paragraph per speaker (FR-001, FR-002).
enum ReadingMode { standard, dialogue }

/// The speeches [content] reads as, within `[start, end)`.
///
/// [loadVoice] is the reader's pick per language (the shipped seam, unchanged:
/// null ≡ the OS default). In [ReadingMode.dialogue] the resolver also needs the
/// voices the device has — [loadInstalled] — because a role's voice falls back to
/// an assignment over that list (FR-014). 标准 never calls it: its path is
/// today's, one call, no voice list (FR-002, SC-005).
///
/// [removed] and [picks] are the reader's own decisions for this content
/// (`RoleSettings.removedFor` and `RoleSettings.voices`): the names that are not
/// roles, and the voice each role was given. Nothing is read from a store here —
/// the caller passes what it loaded, so the resolution stays a pure function of
/// the text, the range and the device.
Future<List<ParagraphSpeech>> resolveSpeeches({
  required String content,
  int start = 0,
  int? end,
  ReadingMode mode = ReadingMode.standard,
  Set<String> removed = const {},
  Map<String, VoiceChoice> picks = const {},
  required Future<VoiceChoice?> Function(String language) loadVoice,
  Future<List<VoiceEntry>> Function()? loadInstalled,
}) async {
  final to = end ?? content.length;
  if (mode == ReadingMode.standard) {
    return resolveParagraphSpeeches(content, start, to, loadVoice);
  }

  final turns = turnsOf(content, start: start, end: to, removed: removed);
  if (turns.isEmpty) return const [];

  final voices = await _assign(
    turns: turns,
    picks: picks,
    loadVoice: loadVoice,
    loadInstalled: loadInstalled,
  );

  // The assignment, printed once per dialogue read (research D10): it is
  // computed from the device's own voice list, so no UI dump and no static table
  // can show what a role actually read with — this line is where that answer
  // exists.
  debugPrint('klhu roles ${_assignmentLine(turns, voices)}');

  return [
    for (var i = 0; i < turns.length; i++)
      ParagraphSpeech(
        text: turns[i].text,
        language: detectLanguage(turns[i].text),
        voice: voices[i],
        start: turns[i].contentStart,
        end: turns[i].contentEnd,
        role: turns[i].role,
      ),
  ];
}

/// The voice each proposed role reads with, in first-appearance order: the
/// reader's pick, or what the assignment gives it (FR-012, FR-016).
///
/// The role list and the read cannot disagree: this is the same resolution the
/// read uses (`_assign`), over the same device list, so what the list shows is
/// what the engine is given.
Future<Map<String, VoiceChoice?>> resolveRoleVoices({
  required List<Turn> turns,
  required Map<String, VoiceChoice> picks,
  required Future<VoiceChoice?> Function(String language) loadVoice,
  Future<List<VoiceEntry>> Function()? loadInstalled,
}) async {
  final voices = await _assign(
    turns: turns,
    picks: picks,
    loadVoice: loadVoice,
    loadInstalled: loadInstalled,
  );
  final byRole = <String, VoiceChoice?>{};
  for (var i = 0; i < turns.length; i++) {
    final role = turns[i].role;
    // The first turn of a role: a role's voice is stable across its turns in one
    // language, and a two-language role is listed by its opening turn.
    if (role != null) byRole.putIfAbsent(role, () => voices[i]);
  }
  return byRole;
}

/// One voice per turn, with the reader's language picks resolved first (they are
/// async; the assignment needs a synchronous lookup).
Future<List<VoiceChoice?>> _assign({
  required List<Turn> turns,
  required Map<String, VoiceChoice> picks,
  required Future<VoiceChoice?> Function(String language) loadVoice,
  Future<List<VoiceEntry>> Function()? loadInstalled,
}) async {
  final languages = {for (final turn in turns) detectLanguage(turn.text)};
  final picksByLanguage = <String, VoiceChoice?>{
    for (final language in languages) language: await loadVoice(language),
  };
  return assignTurnVoices(
    turns: turns,
    picks: picks,
    installed: await loadInstalled?.call() ?? const [],
    languagePick: (language) => picksByLanguage[language],
  );
}

/// `阿明→yue-hk-x-yud-local(male) narration(zh-Hans)→cmn-cn-x-ccc-local …` — one
/// entry per role in first-appearance order, then one per language that has
/// narration, each with the voice it reads with and that voice's recorded gender
/// where the app has one (research D10).
String _assignmentLine(List<Turn> turns, List<VoiceChoice?> voices) {
  final parts = <String>[];
  final roles = <String>{};
  final narrations = <String>{};
  for (var i = 0; i < turns.length; i++) {
    final role = turns[i].role;
    if (role == null) {
      final language = detectLanguage(turns[i].text);
      if (narrations.add(language)) {
        parts.add('narration($language)→${_voiceLabel(voices[i])}');
      }
      continue;
    }
    if (roles.add(role)) parts.add('$role→${_voiceLabel(voices[i])}');
  }
  return parts.join(' ');
}

String _voiceLabel(VoiceChoice? voice) {
  if (voice == null) return 'os-default';
  final gender = VoiceMappingTable.lookup(voice.name)?.gender;
  return gender == null ? voice.name : '${voice.name}($gender)';
}
