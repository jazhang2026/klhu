/// The dialogue rules: what a paragraph's head says about its speaker, which
/// turns a text is made of, which roles it proposes, and — when the reader has
/// not chosen — which voice each of them reads with.
///
/// Everything here is DERIVED: it is recomputed from the text and the device on
/// every read, so nothing can go stale (data-model.md §1). The only things this
/// feature stores are the reader's own decisions — the text type, the names that
/// are *not* roles, and the voice each role was given — and they live in
/// `lib/role_store.dart`.
///
/// The rules below are the reader's own, settled on 2026-10-02 and 2026-10-03
/// (`specs/014-dialogue-reading/research.md` D2, D3, D5, D12). Each function
/// names the requirement it implements so the rule and the spec line can be read
/// side by side.
library;

import 'models/voice_mapping.dart';
import 'comment.dart';
import 'language.dart';
import 'reader_service.dart';
import 'segmenter.dart';
import 'voice_store.dart';

/// One role tag at a paragraph's head: the reader's `{name}` prefix.
///
/// [start] is the offset of the `{` itself, [contentStart] the offset of the
/// first character that is content (after the tag, the optional separator and
/// the spaces that follow it). The prefix is the only thing a read excludes:
/// it is never spoken, highlighted or painted (FR-005).
class RoleTag {
  final String name;
  final int start;
  final int contentStart;

  const RoleTag({
    required this.name,
    required this.start,
    required this.contentStart,
  });
}

/// One turn: a paragraph of the content and the speaker it belongs to.
///
/// A turn is a PARAGRAPH, however many lines and sentences it holds, and the
/// blank line between paragraphs is the only boundary (FR-003, 2026-10-03). A
/// paragraph whose first line carries no tag is one NARRATION turn
/// ([role] == null) and is never attributed to the paragraph above it (FR-009).
class Turn {
  /// The role's name as written at the paragraph's head, or null for narration.
  final String? role;

  /// Offset of the first character of the content (the prefix is outside it).
  final int contentStart;

  /// Offset just past the paragraph's last non-whitespace character.
  final int contentEnd;

  /// `content.substring(contentStart, contentEnd)` — the paragraph's own line
  /// breaks are inside it, which is what makes a speaker's second line part of
  /// that speaker's turn.
  final String text;

  const Turn({
    this.role,
    required this.contentStart,
    required this.contentEnd,
    required this.text,
  });

  bool get isNarration => role == null;

  /// The number of characters read (and highlighted) for this turn.
  int get length => contentEnd - contentStart;
}

/// One speaker named in one content, as far as this content is concerned.
///
/// A role is not shared between contents or devices (FR-008). The reader's pick
/// for it and the voice it falls back to are NOT fields here: the pick is stored
/// (`RoleSettings.voices`) and the fallback is computed per read
/// ([assignTurnVoices]) — data-model.md §3, §4.
class Role {
  final String name;

  /// The role's readable turns, in text order.
  final List<Turn> turns;

  const Role({required this.name, required this.turns});

  /// What the role list shows (FR-006) — readable turns only, so a paragraph
  /// that is only a tag does not inflate a count.
  int get turnCount => turns.length;
}

/// The prefix rule (FR-004): is this paragraph headed by a braced tag?
///
/// ```text
/// paragraph head := the paragraph's first line, its leading spaces trimmed
/// tag            := '{' name '}'  — ASCII braces only
/// name           := between the braces, trimmed, at least one character,
///                   never spanning a line, ended by the first '}'
/// separator      := spaces, an optional single ':' or '：', spaces
/// ```
///
/// Returns null for anything else — `12:30`, `https://…`, `时间：8 点`,
/// `他说：我来了`, `{阿明` (no closing brace), `{}` and a full-width `｛阿明｝`
/// (a Chinese IME's own default) are all narration. The rule is mechanical and
/// deliberately narrow: what braces cannot settle — that `{laughs}` was not a
/// speaker — is the reader's to correct in the role list, and a text whose turns
/// are not separated by blank lines is one turn whose braces are heard, with one
/// Format press (FR-024) as the remedy (research D3).
///
/// A tag ANYWHERE ELSE in a paragraph is ordinary text: it names no speaker, it
/// is not removed, and it is spoken, highlighted and painted like any other
/// characters. Only the head is a prefix.
RoleTag? roleTagAt(String text, int paragraphStart, int paragraphEnd) {
  if (paragraphStart < 0 || paragraphEnd > text.length) return null;
  final head = _lineRange(text, paragraphStart, paragraphEnd);
  var i = head.$1;
  while (i < head.$2 && (text[i] == ' ' || text[i] == '\t')) {
    i++;
  }
  if (i >= head.$2 || text[i] != '{') return null;
  final close = text.indexOf('}', i + 1);
  // No closing brace on this line: `{阿明` is not a tag (and never spans lines).
  if (close < 0 || close >= head.$2) return null;
  final name = text.substring(i + 1, close).trim();
  if (name.isEmpty) return null;
  var j = close + 1;
  while (j < head.$2 && (text[j] == ' ' || text[j] == '\t')) {
    j++;
  }
  if (j < head.$2 && (text[j] == ':' || text[j] == '：')) {
    j++;
    while (j < head.$2 && (text[j] == ' ' || text[j] == '\t')) {
      j++;
    }
  }
  // A tag-only first line: the content begins on the paragraph's next line, so
  // the line break after the prefix is part of the prefix, not of the content.
  if (j >= head.$2 && head.$2 < paragraphEnd) {
    j = head.$2 + 1;
    while (j < paragraphEnd && (text[j] == ' ' || text[j] == '\t')) {
      j++;
    }
  }
  return RoleTag(name: name, start: i, contentStart: j);
}

/// The turns [text] is made of, in order, one per paragraph.
///
/// [start]/[end] is the range the caller is about to read (the page's selection,
/// or the whole content for the video); only turns that overlap it are returned,
/// clipped to it, exactly as `resolveParagraphSpeeches` treats paragraphs today
/// (`lib/language.dart:117`). A turn whose content is empty — a paragraph that
/// is only a tag — is dropped, so it is never counted, read or painted.
///
/// [removed] is the set of names the reader has said are not roles: their
/// paragraphs are narration turns here (FR-007), which is what makes a removal
/// change what is SPOKEN without changing what is displayed (FR-020).
///
/// [comments] is 015's own seam: the comments `lib/comment.dart` derived from
/// the same text. A turn's own content stops at a comment's tag (FR-011), and a
/// paragraph that is nothing but a comment produces no turn at all — its
/// content is empty either way, so it adds no utterance, no role and no count.
/// The parameter defaults to empty, so every 014 caller keeps today's scan.
List<Turn> turnsOf(
  String text, {
  int start = 0,
  int? end,
  Set<String> removed = const {},
  List<Comment> comments = const [],
}) {
  final to = end ?? text.length;
  final turns = <Turn>[];
  for (final para in paragraphRanges(text)) {
    if (para.start >= to || para.end <= start) continue;
    // Where the paragraph's own text stops: a comment's characters are not a
    // turn's, and nothing about the speaker changes with them (FR-011).
    final commentStart = _commentTagIn(comments, para.start, para.end);
    final paraEnd =
        commentStart != null && commentStart < para.end ? commentStart : para.end;
    final tag = roleTagAt(text, para.start, paraEnd);
    final role =
        tag != null && !removed.contains(tag.name) ? tag.name : null;
    // A removed name keeps its prefix out of the content: the span stays where
    // it was, only the speaker changes (FR-007).
    final from = tag != null ? tag.contentStart : para.start;
    final contentStart = from < start ? start : from;
    var contentEnd = paraEnd > to ? to : paraEnd;
    // The paragraph ranges trim a trailing blank line but not the last
    // paragraph's trailing spaces; a turn's content ends at its last
    // non-whitespace character either way (data-model.md §2).
    while (contentEnd > contentStart && _isSpace(text[contentEnd - 1])) {
      contentEnd--;
    }
    if (contentStart >= contentEnd) continue;
    turns.add(
      Turn(
        role: role,
        contentStart: contentStart,
        contentEnd: contentEnd,
        text: text.substring(contentStart, contentEnd),
      ),
    );
  }
  return turns;
}

/// The roles [turns] proposes, in first-appearance order — the order the text
/// introduces them, which is the order the reader sees (FR-006).
///
/// It is a PROPOSAL, never a gate (research D7): a name is a role because the
/// text writes it at a paragraph's head, and the reader's only correction is to
/// remove one ([turnsOf]'s [removed]) or to write the text differently.
List<Role> rolesOf(List<Turn> turns) {
  final order = <String>[];
  final byName = <String, List<Turn>>{};
  for (final turn in turns) {
    final role = turn.role;
    if (role == null) continue;
    final bucket = byName.putIfAbsent(role, () {
      order.add(role);
      return <Turn>[];
    });
    bucket.add(turn);
  }
  return [
    for (final name in order) Role(name: name, turns: byName[name]!),
  ];
}

/// FR-024: the reader's own text with the blank lines every tag needs to head its
/// own paragraph — and NOTHING else.
///
/// `\n\n` is inserted before a tag that has content on its line, and a single
/// `\n` before a tag that already begins a line — either way the tag ends up
/// under exactly one blank line, which is the smallest edit that makes it a
/// paragraph head. No character of the reader's words is altered, no tag is
/// added or removed and no separator is rewritten (the reader's answer,
/// 2026-10-03): the difference between the input and the result is blank lines
/// and only blank lines, which is what makes one Undo enough to take it back. A
/// text with nothing to format comes back byte-identical, so the editor's button
/// knows when to be disabled, and pressing it twice is pressing it once.
///
/// The premise the reader accepted: a brace pair is taken to be a speaker, so a
/// `{laughs}`-style pair becomes a paragraph head and is then proposed as a role
/// — the role list is where you remove it.
String formatForDialogue(String text) {
  final heads = <int>{};
  for (final para in paragraphRanges(text)) {
    final tag = roleTagAt(text, para.start, para.end);
    if (tag != null) heads.add(tag.start);
  }
  final insertAt = <int>[];
  var i = 0;
  while ((i = text.indexOf('{', i)) >= 0) {
    final close = text.indexOf('}', i + 1);
    // The tag grammar: at least one character, never spanning a line.
    final newline = text.indexOf('\n', i);
    if (close > i + 1 &&
        (newline < 0 || close < newline) &&
        text.substring(i + 1, close).trim().isNotEmpty &&
        !heads.contains(i)) {
      insertAt.add(i);
    }
    i++;
  }
  if (insertAt.isEmpty) return text;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final at in insertAt) {
    buffer.write(text.substring(cursor, at));
    // A tag that already starts a line needs one line break to gain a blank
    // line; a tag with text before it needs two.
    buffer.write(at > 0 && text[at - 1] == '\n' ? '\n' : '\n\n');
    cursor = at;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// Every tag occurrence in [text], anywhere, as the offsets of its `{`.
///
/// The same grammar [roleTagAt] applies at a paragraph's head, searched
/// throughout — this is what a read EXCLUDES nothing for: it exists so a caller
/// can count what a text holds, not so it can strip it.
List<int> tagOffsets(String text) {
  final offsets = <int>[];
  var i = 0;
  while ((i = text.indexOf('{', i)) >= 0) {
    final close = text.indexOf('}', i + 1);
    final newline = text.indexOf('\n', i);
    if (close > i + 1 &&
        (newline < 0 || close < newline) &&
        text.substring(i + 1, close).trim().isNotEmpty) {
      offsets.add(i);
    }
    i++;
  }
  return offsets;
}

/// The voices a read of [turns] uses, one entry per turn (FR-012–FR-015).
///
/// The reader's pick for a role wins outright, whatever the turn's language
/// (FR-013). Everything else is DERIVED here and never stored (FR-014): a voice
/// that is uninstalled simply yields a different assignment instead of a
/// dangling reference, and the same content with the same picks on the same
/// device always assigns the same voices.
///
/// The ranking (data-model.md §4), applied per (role, language) in the order the
/// roles first appear:
///
/// 1. the turn's language — never overridden: an English turn is never read by a
///    Chinese voice;
/// 2. the same dialect as the reader's pick for that language, when that pick
///    has one — read from the voice's own locale (`yue-HK` against `zh-CN`), see
///    [_dialectFamily] for why the mapping table's `dialect` is not the signal;
/// 3. the reader's own pick for that language, first (it satisfies 1 and 2);
/// 4. a recorded gender that differs from the roles already placed, so the
///    second role does not sound like the first;
/// 5. the voice's own name, ascending — a total order, so nothing depends on the
///    order the engine happened to report.
///
/// A voice is used for one role before it is reused for another; when the device
/// lists fewer suitable voices than there are roles, a voice IS reused and the
/// list shows it — the app neither refuses to read nor silently invents a voice
/// (FR-015, SC-004). Gender is used only for rule 4: the app never claims a role
/// is male or female (research D5).
///
/// A narration turn reads in the reader's pick for its language, or the OS
/// default — today's behaviour, exactly (FR-002).
List<VoiceChoice?> assignTurnVoices({
  required List<Turn> turns,
  required Map<String, VoiceChoice> picks,
  required List<VoiceEntry> installed,
  VoiceChoice? Function(String language)? languagePick,
}) {
  // Keyed by role AND language: a role whose turns are in two languages reads in
  // two voices, and a role's turns in one language sound the same throughout
  // (data-model.md §4).
  final assigned = <String, VoiceChoice?>{};
  final usedByRole = <String, Set<String>>{};
  final placedGenders = <String>{};

  VoiceChoice? forRole(String role, String language) {
    final pick = picks[role];
    if (pick != null) return pick;
    final key = '$role||$language';
    if (assigned.containsKey(key)) return assigned[key];

    final pickForLanguage = languagePick?.call(language);
    final candidates = _candidates(installed, language);
    if (candidates.isEmpty) {
      assigned[key] = null;
      return null;
    }
    final pickFamily = pickForLanguage == null
        ? null
        : _dialectFamily(pickForLanguage.locale);
    bool isPick(VoiceEntry v) =>
        pickForLanguage != null &&
        v.name == pickForLanguage.name &&
        v.locale == pickForLanguage.locale;
    bool sameDialect(VoiceEntry v) =>
        pickFamily != null && _dialectFamily(v.locale) == pickFamily;

    bool differs(VoiceEntry v) {
      final gender = VoiceMappingTable.lookup(v.name)?.gender;
      return gender != null && !placedGenders.contains(gender);
    }

    final ranked = [...candidates]..sort((a, b) {
        final byPick = _flag(isPick(b)) - _flag(isPick(a));
        if (byPick != 0) return byPick;
        final byDialect = _flag(sameDialect(b)) - _flag(sameDialect(a));
        if (byDialect != 0) return byDialect;
        final byGender = _flag(differs(b)) - _flag(differs(a));
        if (byGender != 0) return byGender;
        return a.name.compareTo(b.name);
      });
    // Counted by voice, not by name: the engine reports one voice twice
    // (`…-local`, `…-network`) and the two are one voice, so the code is what a
    // role takes. Handing the next role the other copy is what the OnePlus 13 did
    // — the reader heard one voice read two roles, and the render could not be
    // muxed (the copies write 24 kHz and 48 kHz).
    final taken = usedByRole.values.expand((identities) => identities).toSet();
    final unused = ranked.where((v) => !taken.contains(_identity(v))).toList();
    final chosen = unused.isNotEmpty ? unused.first : ranked.first;

    (usedByRole[role] ??= <String>{}).add(_identity(chosen));
    final gender = VoiceMappingTable.lookup(chosen.name)?.gender;
    if (gender != null) placedGenders.add(gender);
    final choice = VoiceChoice(
      language: language,
      name: chosen.name,
      locale: chosen.locale,
    );
    assigned[key] = choice;
    return choice;
  }

  return [
    for (final turn in turns)
      turn.role == null
          ? languagePick?.call(detectLanguage(turn.text))
          : forRole(turn.role!, detectLanguage(turn.text)),
  ];
}

/// The installed voices of one reading language, name-ascending and one row per
/// voice.
///
/// The engine reports the local and network copies of one voice as two rows
/// (`…-local`, `…-network`) under one name; assigning both to two roles would
/// give the reader one voice reading two roles, so a voice is counted once —
/// the `-local` row, which sorts first (research D5). Both copies write the same
/// words; they do not write the same sample rate (24 kHz on-device, 48 kHz on the
/// network), so a read that used both could not be muxed either.
List<VoiceEntry> _candidates(List<VoiceEntry> installed, String language) {
  final matches = installed
      .where((v) => _matchesLanguage(v.locale, language))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final seen = <String>{};
  return [
    for (final voice in matches)
      if (seen.add(_identity(voice))) voice,
  ];
}

/// What the assignment counts a voice as. A voice the mapping table knows is its
/// row (`englishName|gender|dialect`), which the engine's two copies share; a
/// voice the table does not know is its code, by the engine's own naming
/// ([voiceIdentity]) — the phone's newer engine reports voices the table has
/// never seen, and counting their twins separately is how two roles got one
/// voice there.
String _identity(VoiceEntry voice) {
  final mapping = VoiceMappingTable.lookup(voice.name);
  if (mapping != null) {
    return '${mapping.englishName}|${mapping.gender}|${mapping.dialect}';
  }
  return voiceIdentity(voice.name);
}

int _flag(bool value) => value ? 1 : 0;

/// Whitespace a turn's content never ends on: spaces, tabs and the line breaks
/// a paragraph may carry at its tail.
bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';

/// The offset of the first comment tag inside `[from, to)`, or null (015).
///
/// The comment rule itself lives in `lib/comment.dart` and never calls back
/// here: this is the whole of the seam between the two tags' implementations
/// (research D2).
int? _commentTagIn(List<Comment> comments, int from, int to) {
  for (final comment in comments) {
    if (comment.tag.start >= from && comment.tag.start < to) {
      return comment.tag.start;
    }
  }
  return null;
}

/// The dialect signal this app actually has: the voice's own LOCALE, not the
/// mapping table's `dialect` field.
///
/// `VoiceMapping.dialect` is declared but no row sets it, deliberately —
/// 007 FR-010's own reason is that a Cantonese voice is *named* by its dialect
/// (`广东话 JAR`), so the field would only repeat the name. The locale does
/// distinguish them, and it is what the engine is told before each utterance
/// (`lib/reader_service.dart:458-469`): `yue-HK` for Cantonese against
/// `zh-CN`/`cmn-CN` for Mandarin. Mandarin is written both ways (`zh`, `cmn`) and
/// is one list, so those two collapse; every other language has one family and
/// this rule is inert for it.
String _dialectFamily(String locale) {
  final primary = locale.toLowerCase().split(RegExp(r'[-_]')).first;
  return primary == 'cmn' ? 'zh' : primary;
}

/// Voice-list membership per reading language — the same table the reader
/// service reads (`lib/reader_service.dart:280-291`): Cantonese (`yue-HK`) is a
/// Chinese voice choice, not a separate language (007 FR-008). Kept here rather
/// than made public there so the reader service stays untouched (research D1).
bool _matchesLanguage(String locale, String language) {
  final lower = locale.toLowerCase();
  return switch (language) {
        'zh-Hans' => ['zh', 'cmn', 'yue'],
        'es' => ['es'],
        _ => ['en'],
      }
      .any(lower.startsWith);
}

/// The reading language [locale] belongs to, or null when it belongs to none of
/// the three this app reads — the reverse of [_matchesLanguage], used where a
/// stored pick has to be rebuilt from its locale alone (`lib/role_store.dart`).
String? languageOfVoice(String locale) {
  for (final language in const ['en', 'zh-Hans', 'es']) {
    if (_matchesLanguage(locale, language)) return language;
  }
  return null;
}

/// The first line of a paragraph, as `(start, end)` — tags never span a line.
(int, int) _lineRange(String text, int paragraphStart, int paragraphEnd) {
  final newline = text.indexOf('\n', paragraphStart);
  final end = newline < 0 || newline > paragraphEnd ? paragraphEnd : newline;
  return (paragraphStart, end);
}
