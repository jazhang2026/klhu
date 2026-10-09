/// The one place a read is resolved, in both modes (FR-019).
///
/// 标准 delegates straight to 015's per-paragraph resolution — today's
/// `resolveParagraphSpeeches` (`lib/language.dart:110`) with the comment's own
/// split — and 多人对话 turns the text into turns first (`lib/dialogue.dart`) and
/// resolves each one into the same type. The page, the reader service and the
/// video all consume `List<ParagraphSpeech>` — the single interface they already
/// agree on — so nothing downstream learns that roles or comments exist: the
/// reader service still cuts each speech into sentences with its own
/// `_sentencesOf`, the highlight still reads `start`/`end`, 010's resume offset is
/// still a content offset, and 012's video still receives one entry per sentence
/// (research D1).
///
/// 015 adds the **comment** to this one resolution (FR-009): a comment is a
/// second speech beside its sentence's own — its content, its own detected
/// language, that language's own voice — placed where its own text sits, so the
/// read's order is the list's order and no consumer grows a second path. With the
/// setting off its entry is not emitted at all, which is what makes "the switch
/// is off" and "there is no comment" the same answer here (research D1, D5).
library;

import 'package:flutter/foundation.dart';

import 'comment.dart';
import 'dialogue.dart';
import 'language.dart';
import 'models/voice_mapping.dart';
import 'reader_service.dart';
import 'segmenter.dart';
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
///
/// [commentsRead] is 015's own setting (FR-006): the shipped default is `true`,
/// and with it `false` no comment's characters reach the returned list.
Future<List<ParagraphSpeech>> resolveSpeeches({
  required String content,
  int start = 0,
  int? end,
  ReadingMode mode = ReadingMode.standard,
  Set<String> removed = const {},
  Map<String, VoiceChoice> picks = const {},
  bool commentsRead = true,
  required Future<VoiceChoice?> Function(String language) loadVoice,
  Future<List<VoiceEntry>> Function()? loadInstalled,
}) async {
  final to = end ?? content.length;
  // 015: the comments this text holds, derived once. A comment is SPOKEN when the
  // setting reads them, when it has content, and when a sentence precedes it
  // somewhere in the text (FR-003) — a tag at the very head belongs to nothing,
  // so it is displayed and never spoken.
  final comments = commentsOf(content);
  final spoken = commentsRead
      ? [
          for (final comment in comments)
            if (comment.hasContent && comment.hasOwner) comment,
        ]
      : const <Comment>[];

  if (mode == ReadingMode.standard) {
    final speeches =
        await _paragraphSpeeches(content, start, to, loadVoice, comments);
    return _withComments(speeches, spoken, content, start, to, loadVoice);
  }

  final turns = turnsOf(content,
      start: start, end: to, removed: removed, comments: comments);
  final turnSpeeches =
      await _turnSpeeches(turns, picks, loadVoice, loadInstalled);
  return _withComments(turnSpeeches, spoken, content, start, to, loadVoice);
}

/// 标准's own read: today's per-paragraph resolution (`lib/language.dart:110`)
/// with 015's one split — a paragraph's speakable text stops at its comment's
/// tag, and its language is detected on what is left, so a comment's characters
/// are no sentence's span and no sentence's language (FR-004, FR-008, FR-010).
///
/// For a text with no comment this is `resolveParagraphSpeeches` character for
/// character, including its treatment of the range and of a mid-paragraph start
/// (SC-004).
Future<List<ParagraphSpeech>> _paragraphSpeeches(
  String content,
  int start,
  int end,
  Future<VoiceChoice?> Function(String language) loadVoice,
  List<Comment> comments,
) async {
  final speeches = <ParagraphSpeech>[];
  for (final para in paragraphRanges(content)) {
    if (para.start >= end || para.end <= start) continue;
    final comment = _commentIn(comments, para);
    var speakableEnd = comment != null ? comment.tag.start : para.end;
    // What a sentence says ends at its own last character: only whitespace can
    // sit between it and its tag (`Comment.contentEnd`'s own trimming, one
    // paragraph earlier). A content with no comment is untouched.
    while (comment != null &&
        speakableEnd > para.start &&
        _isSpace(content[speakableEnd - 1])) {
      speakableEnd--;
    }
    final language = detectLanguage(content.substring(para.start, speakableEnd));
    final from = start < para.start ? para.start : start;
    final to = end > speakableEnd ? speakableEnd : end;
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

/// 多人对话's own read: one speech per turn, in the turn's own language and the
/// role's voice (014's D1/D5, unchanged).
Future<List<ParagraphSpeech>> _turnSpeeches(
  List<Turn> turns,
  Map<String, VoiceChoice> picks,
  Future<VoiceChoice?> Function(String language) loadVoice,
  Future<List<VoiceEntry>> Function()? loadInstalled,
) async {
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

/// One speech per comment the read covers, placed where its own text sits
/// (FR-007).
///
/// The position is the whole of the ordering rule: a comment's tag always sits
/// after the sentence it belongs to (research D4), so its entry goes just before
/// the first speech that starts at or after the tag — immediately after the piece
/// of text its owner ends in. A comment with no speech after it (the text ends
/// there, or the range does) reads last; one whose own span the range does not
/// cover is not read at all.
Future<List<ParagraphSpeech>> _withComments(
  List<ParagraphSpeech> speeches,
  List<Comment> spoken,
  String content,
  int start,
  int end,
  Future<VoiceChoice?> Function(String language) loadVoice,
) async {
  if (spoken.isEmpty) return speeches;
  final pending = <({int tagStart, ParagraphSpeech speech})>[];
  for (final comment in spoken) {
    if (comment.contentStart >= end || comment.contentEnd <= start) continue;
    final from = start > comment.contentStart ? start : comment.contentStart;
    final to = end < comment.contentEnd ? end : comment.contentEnd;
    if (from >= to) continue;
    pending.add((
      tagStart: comment.tag.start,
      speech: ParagraphSpeech(
        text: content.substring(from, to),
        language: comment.language,
        voice: await loadVoice(comment.language),
        start: from,
        end: to,
        isComment: true,
      ),
    ));
  }
  if (pending.isEmpty) return speeches;
  pending.sort((a, b) => a.tagStart.compareTo(b.tagStart));

  final merged = <ParagraphSpeech>[];
  var next = 0;
  for (final speech in speeches) {
    while (next < pending.length && pending[next].tagStart <= speech.start) {
      merged.add(pending[next].speech);
      next++;
    }
    merged.add(speech);
  }
  while (next < pending.length) {
    merged.add(pending[next].speech);
    next++;
  }
  return merged;
}

/// The comment [paragraph] holds, or null (one per paragraph at most).
Comment? _commentIn(List<Comment> comments, TextSegment paragraph) {
  for (final comment in comments) {
    if (comment.tag.start >= paragraph.start &&
        comment.tag.start < paragraph.end) {
      return comment;
    }
  }
  return null;
}

bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';

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
