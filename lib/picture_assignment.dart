/// The reader's assignment — which sentences each picked picture carries
/// (spec 020 D1/D4/D7, `data-model.md` §1-§3).
///
/// The whole of this feature's rule lives here, and the pass, the warning before
/// a render and the render itself all read the same answer: one resolver, read
/// twice, so what the reader was warned about cannot disagree with what the
/// render then does. Nothing in this file paints, stores or speaks.
library;

import 'video_pictures.dart';
import 'video_timeline.dart';

/// One picture's own sentences, as the reader assigned them: the picture's own
/// **file name**, and the sentences it carries as the content spans they occupy.
class PictureRun {
  const PictureRun({required this.name, required this.spans});

  /// The picture's own name as the reader picked it (`HeldPicture.name`).
  ///
  /// Deliberately **not** the prompt's own path: that path lives in a directory
  /// the prompt deletes the moment the render ends (`discardPictures`), so a key
  /// made of it could not outlive one visit — research D7, and the reader's own
  /// answer of 2026-10-14. Two picks carrying the same name are resolved by the
  /// first in the pick order, which is what the pass shows.
  final String name;

  /// The sentences this picture carries, as `(start, end)` content offsets, in
  /// ascending order. A span is a sentence's **own** span — the pair the video
  /// speaks — so a span the render's sentence list does not know is a fact about
  /// the text that changed, not a guess about where it moved to.
  final List<(int, int)> spans;

  bool get isEmpty => spans.isEmpty;
}

/// One picture's sentences for **this** render: indices into the sentence list
/// the render was built from, ascending, possibly empty.
///
/// Empty is the reader's own "0 sentences on this picture" (FR-003) — a legal
/// decision — and not an absence: the picture is in the pass, and only the
/// render skips it (FR-007).
class AssignedRun {
  const AssignedRun({required this.name, required this.sentences});

  /// The picture's own file name, carried through so a caller can name it in a
  /// warning or show it on the pass.
  final String name;

  final List<int> sentences;
}

/// What one render's assignment comes to (research D4): the sentences each
/// picture holds, and the reader's own runs that no longer fit.
class AssignmentAnswer {
  const AssignmentAnswer({required this.effective, required this.stale});

  /// The no-assignment state: the reader assigned nothing, or nothing of what
  /// they assigned survived this render's sentence list.
  ///
  /// Deliberately an **empty list** rather than one empty run per picture: a
  /// list of empty runs is itself a decision, and here no decision was made —
  /// the render is 012's own (FR-009).
  static const AssignmentAnswer none = AssignmentAnswer(
    effective: <AssignedRun>[],
    stale: <PictureRun>[],
  );

  /// One entry per picture, in the pictures' **display order** — what the pass
  /// shows and what the split walks. Empty exactly when nothing is in force.
  final List<AssignedRun> effective;

  /// The reader's runs that were not applied: their picture is not among the
  /// picks in force, or their spans match no sentence of this render. FR-014's
  /// warning names these, which is why the answer carries them rather than
  /// quietly dropping them.
  final List<PictureRun> stale;

  bool get isInForce => effective.isNotEmpty;
}

/// The sentence indices [spans] name in [sentences], ascending — the one place a
/// stored run is read as sentences.
///
/// A span that no sentence answers with is **dropped** rather than an error:
/// that is FR-014's own detection, and it is what lets a run one of whose spans
/// still matches keep those and lose only the rest.
List<int> indicesOfSpans(
  List<(int, int)> spans,
  List<VideoSentence> sentences,
) {
  // The spans the render actually speaks, so a run is matched against the text
  // as it is now rather than against a number that may mean something else.
  final bySpan = <(int, int), int>{
    for (var i = 0; i < sentences.length; i++)
      (sentences[i].start, sentences[i].end): i,
  };
  return <int>[for (final span in spans) ?bySpan[span]]..sort();
}

/// Why an edit the reader proposed is refused (FR-003, FR-004, FR-012, FR-016).
///
/// The reason is a value rather than a message: **which rule was broken** is the
/// behaviour, and the pass turns it into the reader's own language with the key
/// each case names. A refusal never changes the assignment in force (FR-012) —
/// the caller simply does not apply the edit.
enum AssignmentRefusal {
  /// FR-003: a picture's sentences must be continuous — the sentence proposed
  /// is not next to the ones this picture already holds.
  notContinuous,

  /// FR-004: sentences are assigned in order across pictures — the sentence
  /// proposed starts before one an earlier picture already holds, or a later
  /// picture already holds one that starts after it.
  notInOrder,

  /// FR-016: only the first or last sentence of a run can be taken back;
  /// removing one from the middle would leave that picture's sentences in two.
  middleOfRun,

  /// FR-015: a picture that holds a sentence of the reader's cannot take
  /// another place. The tail fallback does **not** count (spec 021 D3), so this
  /// is no longer what decides the controls — the pass hides them (T012) — and
  /// the reason stays for the record of what it answered.
  holdsSentences,
}

/// Why adding the sentence at [index] to the picture at [picture] is refused, or
/// null when it is accepted (FR-003, FR-004).
///
/// **The order rule is read first, and both ways round** — the proposal is
/// checked against every other picture's own sentences, before and after — and
/// the continuity rule second: a sentence that would land in another picture's
/// territory is answered as "not in order", which is the more useful reason when
/// both are broken (FR-012 asks for the rule that was broken, not for all of
/// them).
///
/// A boundary sentence — the first of a later picture's run, the last of an
/// earlier one's — is that picture's, and is refused here (spec 021): a tap on
/// it is the **switch**'s gesture, and the reader is asked to confirm the
/// sentence leaving its holder. Nothing is assigned across a boundary.
AssignmentRefusal? refusedAdd({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int picture,
  required int index,
}) {
  if (picture < 0 || picture >= runs.length) return null;
  final own = indicesOfSpans(runs[picture].spans, sentences);
  // Already this picture's: the same tap is the gesture that takes it back.
  if (own.contains(index)) return null;

  for (var other = 0; other < runs.length; other++) {
    if (other == picture) continue;
    final held = indicesOfSpans(runs[other].spans, sentences);
    if (held.isEmpty) continue;
    // Inclusive on both sides: a run's own last (or first) sentence is that
    // picture's, so it is refused here rather than written into two runs — the
    // shape the reader reported on 2026-10-15, where a neighbour's last
    // sentence passed both comparisons and landed in this picture's run as
    // well. What the reader wanted from that tap is `refusedSwitch`, which
    // takes the sentence away from its holder first.
    if (other < picture && index <= held.last) {
      return AssignmentRefusal.notInOrder;
    }
    if (other > picture && index >= held.first) {
      return AssignmentRefusal.notInOrder;
    }
  }

  if (own.isNotEmpty && (index < own.first - 1 || index > own.last + 1)) {
    return AssignmentRefusal.notContinuous;
  }
  return null;
}

/// Why taking the sentence at [index] from the picture at [picture] is refused,
/// or null when it is accepted (FR-016).
///
/// Either **end** of a run is always the reader's to take back; one in the
/// middle is not, because what would be left is two runs on one picture.
AssignmentRefusal? refusedRemove({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int picture,
  required int index,
}) {
  if (picture < 0 || picture >= runs.length) return null;
  final own = indicesOfSpans(runs[picture].spans, sentences);
  if (own.length > 1 && index != own.first && index != own.last) {
    return AssignmentRefusal.middleOfRun;
  }
  return null;
}

/// Which picture's run holds the sentence at [index], or null when no run does
/// (spec 021 D4).
///
/// The pass reads this before it decides what a tap means — the picture's own
/// (take it back), another picture's (propose the switch), or nobody's (give it
/// to the selected picture) — and the switch's own rule reads it the same way,
/// so "mine" cannot come out one way on the page and another in the rule.
int? holderOf({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int index,
}) {
  for (var p = 0; p < runs.length; p++) {
    if (indicesOfSpans(runs[p].spans, sentences).contains(index)) return p;
  }
  return null;
}

/// The reader's own [runs] with the sentence at [index] taken away from the
/// picture at [picture]: the span goes, the picture and its other spans stay
/// (spec 021 D4). The holder's own rule is what says whether it may go —
/// this is the edit, not the answer to whether the edit is allowed.
List<PictureRun> withoutSentence({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int picture,
  required int index,
}) {
  if (picture < 0 || picture >= runs.length) return runs;
  final span = (sentences[index].start, sentences[index].end);
  return [
    for (var p = 0; p < runs.length; p++)
      if (p != picture)
        runs[p]
      else
        PictureRun(
          name: runs[p].name,
          spans: [for (final held in runs[p].spans) if (held != span) held],
        ),
  ];
}

/// Why giving the sentence at [index], which another picture's run holds, to
/// the picture at [picture] is refused, or null when the reader may be warned
/// and asked to confirm it (FR-011, FR-012, FR-013).
///
/// The switch is a **repair**, not a second assignment: the sentence leaves the
/// picture that holds it, and only then does the target's own rule answer for
/// it. So the holder's rule is read first — only an **end** of the holder's run
/// can leave without leaving two behind, which is FR-016's own reason
/// (`middleOfRun`) — and the target's rule second, against the runs the holder
/// has already let go of.
///
/// Null is the answer for a sentence the target itself holds and for one no run
/// holds: neither is a switch, and `refusedAdd` is what answers those taps.
AssignmentRefusal? refusedSwitch({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int picture,
  required int index,
}) {
  if (picture < 0 || picture >= runs.length) return null;
  final holder = holderOf(sentences: sentences, runs: runs, index: index);
  if (holder == null || holder == picture) return null;
  if (refusedRemove(
        sentences: sentences,
        runs: runs,
        picture: holder,
        index: index,
      ) !=
      null) {
    return AssignmentRefusal.middleOfRun;
  }
  return refusedAdd(
    sentences: sentences,
    runs: withoutSentence(
      sentences: sentences,
      runs: runs,
      picture: holder,
      index: index,
    ),
    picture: picture,
    index: index,
  );
}

/// The reader's own [runs] with the sentence at [index] given to the picture at
/// [picture] — the repair the switch applies once the reader has confirmed it
/// (FR-012).
///
/// The span leaves whoever held it and joins the target's own spans **in the
/// content's order**, so the run a render reads is still ascending and a
/// sentence that was in one picture's run is in exactly one after the call:
/// FR-013 by construction, rather than by a caller remembering to remove first.
List<PictureRun> applySwitch({
  required List<VideoSentence> sentences,
  required List<PictureRun> runs,
  required int picture,
  required int index,
}) {
  if (picture < 0 || picture >= runs.length) return runs;
  final span = (sentences[index].start, sentences[index].end);
  final holder = holderOf(sentences: sentences, runs: runs, index: index);
  return [
    for (var p = 0; p < runs.length; p++)
      if (p == holder)
        PictureRun(
          name: runs[p].name,
          spans: [for (final held in runs[p].spans) if (held != span) held],
        )
      else if (p == picture) ...[
        PictureRun(
          name: runs[p].name,
          spans: [...runs[p].spans, span]
            ..sort((a, b) => a.$1.compareTo(b.$1)),
        ),
      ] else
        runs[p],
  ];
}

/// Whether the picture at [picture] may take another place (FR-015, spec 021
/// D3): only one the **reader** gave nothing may.
///
/// The reader's own [runs] are the question, not the resolver's answer, because
/// that answer carries FR-006's tail fallback as well: a picture the render
/// feeds by itself is still a picture the reader assigned nothing to, and
/// moving it is theirs to do. Counting the fallback as holding is what refused
/// a move on a picture the reader had left empty (their report of 2026-10-15),
/// and it is why this reads [runs].
bool mayMove(List<PictureRun> runs, int picture) =>
    picture >= 0 && picture < runs.length && runs[picture].spans.isEmpty;

/// The reader's own [runs], minus the ones the resolver could not apply — what
/// still fits after a content edit (FR-014), in the record's own form, ready for
/// the pass to open on and for the render to walk.
///
/// **Not [AssignmentAnswer.effective], and the difference matters**: that answer
/// carries FR-006's fallback as well — the sentences no run names, handed to the
/// pictures by the render's own rule. The fallback is an **outcome of the
/// render**, not a decision of the reader (FR-011), so it must not be written
/// back into the record, and a pass opened on it would show the reader sentences
/// they never assigned. What the reader decided, and what survives, is this.
List<PictureRun> runsThatFit(
  AssignmentAnswer answer,
  List<PictureRun> runs,
) => [
  for (final run in runs)
    if (!answer.stale.any((stale) => _isTheSameRun(stale, run))) run,
];

/// Whether two runs are the same run of the record: same picture, same spans.
/// Records compare by value, so the spans are.
bool _isTheSameRun(PictureRun a, PictureRun b) {
  if (a.name != b.name || a.spans.length != b.spans.length) return false;
  for (var i = 0; i < a.spans.length; i++) {
    if (a.spans[i] != b.spans[i]) return false;
  }
  return true;
}

/// What the assignment pass answers with: the pictures in the order the reader
/// left them, and the runs that go with them, one per picture.
///
/// The order is why this is a record rather than a bare list of runs: a drag in
/// the pass is about the order the **render** walks (FR-015), and a picture
/// holding nothing has no run to carry that order in.
class AssignmentDraft {
  const AssignmentDraft({required this.pictures, required this.runs});

  final List<HeldPicture> pictures;

  /// One entry per picture, in [pictures]' own order. A run holding nothing is
  /// legal here — the reader left that picture nothing — and is not stored: it
  /// says nothing (FR-009).
  final List<PictureRun> runs;
}

/// Resolves the reader's [runs] against this render's [sentences] and the
/// pictures in force [pictures] (FR-006, FR-007, FR-010, FR-014).
///
/// The rules, in the order they decide:
///
/// 1. **Matching, by name** — a run belongs to the **first** pick carrying its
///    name; a run whose name is in no pick is `stale`, and nothing is
///    re-pointed at its place (FR-010, research D7). Inside a matched run, a
///    span this render's sentence list does not know is dropped; a run one of
///    whose spans still matches stands with those spans, and a run with nothing
///    left is `stale` (FR-014).
/// 2. **The tail** — the sentences after the last assigned one go to the
///    pictures **after** it that hold nothing, split the way 012 splits them
///    (`each = n ~/ r`, the remainder to the first); with no such picture they
///    stay on the last assigned one. (The reader's refinement of 2026-10-13:
///    an unassigned tail is not one long hold.)
/// 3. **The gap keeps the picture before it** — a sentence still unassigned
///    belongs to the nearest picture before it that holds something, and a
///    sentence before the first assigned one belongs to the first picture
///    (FR-006: every sentence is painted, and the first sentence paints the
///    first picture).
///
/// A picture nothing reaches holds nothing; the render skips it (FR-007).
AssignmentAnswer assignmentsFor({
  required List<VideoSentence> sentences,
  required List<HeldPicture> pictures,
  required List<PictureRun> runs,
}) {
  // 1. Matching. `held[p]` is what picture p holds so far.
  final held = <int, List<int>>{
    for (var p = 0; p < pictures.length; p++) p: <int>[],
  };
  final stale = <PictureRun>[];
  for (final run in runs) {
    final at = pictures.indexWhere((picture) => picture.name == run.name);
    if (at < 0) {
      // The reader assigned a picture that is not among the picks in force. It
      // is named, and nothing takes its place.
      stale.add(run);
      continue;
    }
    final matched = indicesOfSpans(run.spans, sentences);
    if (matched.isEmpty) {
      stale.add(run);
      continue;
    }
    held[at]!.addAll(matched);
  }

  if (held.values.every((sentenceIndices) => sentenceIndices.isEmpty)) {
    // Nothing survived: not an assignment at all (FR-009), with the runs this
    // render could not use named for FR-014's warning.
    return AssignmentAnswer(effective: const <AssignedRun>[], stale: stale);
  }

  final owner = List<int?>.filled(sentences.length, null);
  for (final entry in held.entries) {
    for (final index in entry.value) {
      owner[index] = entry.key;
    }
  }

  // 2. The tail, before the gaps: otherwise the gaps would swallow it whole.
  var lastAssigned = -1;
  for (var i = 0; i < owner.length; i++) {
    if (owner[i] != null) lastAssigned = i;
  }
  final lastHolding = owner[lastAssigned]!;
  final tail = <int>[
    for (var i = lastAssigned + 1; i < sentences.length; i++) i,
  ];
  final trailing = <int>[
    for (var p = lastHolding + 1; p < pictures.length; p++)
      if (held[p]!.isEmpty) p,
  ];
  if (tail.isNotEmpty && trailing.isNotEmpty) {
    // 012's own even split of the tail over the pictures left holding nothing.
    final each = tail.length ~/ trailing.length;
    final extra = tail.length % trailing.length;
    var at = 0;
    for (var k = 0; k < trailing.length; k++) {
      for (var n = 0; n < each + (k < extra ? 1 : 0); n++) {
        owner[tail[at++]] = trailing[k];
      }
    }
  }

  // 3. The gaps: the picture before them stays (FR-006) — and the first
  // sentence, which has none before it, paints the first picture.
  int? before;
  for (var i = 0; i < owner.length; i++) {
    if (owner[i] != null) {
      before = owner[i];
      continue;
    }
    owner[i] = before ?? 0;
  }

  return AssignmentAnswer(
    effective: <AssignedRun>[
      for (var p = 0; p < pictures.length; p++)
        AssignedRun(
          name: pictures[p].name,
          sentences: <int>[
            for (var i = 0; i < owner.length; i++)
              if (owner[i] == p) i,
          ],
        ),
    ],
    stale: stale,
  );
}
