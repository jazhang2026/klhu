/// The assignment pass — the reader's own page for giving sentences to pictures
/// (spec 020 US1, FR-001–FR-003).
///
/// One line in the video dialog opens this page (the reader's own layout **(A)**
/// of `ui-sketch.html`, decided 2026-10-13): the pictures in force across the
/// top, each with its own count, and the sentences the render will speak down the
/// page. Tapping a sentence gives it to the picture selected, or takes it back;
/// holding a picture that holds nothing moves it in the order the render walks;
/// `Done` answers the reader's runs **and the order they are in**.
///
/// Every rule the reader can break is answered here, with its reason (US2,
/// FR-012): the rules themselves live in `lib/picture_assignment.dart`
/// (`refusedAdd`, `refusedRemove`, `mayDrag`) and this page only shows what they
/// answer — a refusal leaves the assignment in force exactly as it was.
///
/// It is deliberately a plain page over data it is **handed**: the pictures in
/// force and the render's own sentence list come from the page that opened it
/// (D6), so nothing here can show a sentence the video will not speak. It paints
/// no frames, speaks nothing and writes nothing — the page that opened it stores
/// the answer (FR-010), and the resolver reads it back (research D4).
///
/// **What the page shows is what the reader assigned, not what the render will
/// paint.** An unassigned sentence is left plainly unassigned rather than drawn
/// as belonging to the picture before it (FR-006's fallback): that fallback is an
/// outcome of the render, not a decision of the reader's, and this is the page
/// where decisions are made (research §4's open presentation question, settled
/// here — the plan left it to this stage). The one place the fallback does show
/// up is the drag: a picture the tail feeds holds sentences, so it refuses to
/// move (FR-015, the reader's own rule of 2026-10-13).
library;

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'picture_assignment.dart';
import 'video_pictures.dart';
import 'video_timeline.dart';

class PictureAssignmentScreen extends StatefulWidget {
  const PictureAssignmentScreen({
    super.key,
    required this.pictures,
    required this.sentences,
    required this.runs,
    this.inView,
  });

  /// The pictures in force, in the order the render will walk them.
  final List<HeldPicture> pictures;

  /// The sentences **the render will speak**, in the render's own order.
  final List<VideoSentence> sentences;

  /// What is assigned now, as it is stored.
  final List<PictureRun> runs;

  /// The picture the page opens on — FR-014's own gesture: the warning names a
  /// picture, the reader taps it, and they land on **that** one rather than
  /// hunting through the strip for it. Null (or a name not among [pictures])
  /// opens on the first.
  final String? inView;

  @override
  State<PictureAssignmentScreen> createState() =>
      _PictureAssignmentScreenState();
}

class _PictureAssignmentScreenState extends State<PictureAssignmentScreen> {
  /// The pictures in force, in the order the reader leaves them: a drag moves
  /// this list and [_runs] **together**, so a run always names its own picture.
  late List<HeldPicture> _pictures = List<HeldPicture>.of(widget.pictures);

  /// The reader's answer so far: one run per picture, in [_pictures]' own order,
  /// so the page and the render share one order.
  ///
  /// Seeded from what is stored, **filtered to the pictures in force**: a run
  /// whose picture is not here belongs to FR-014's warning, not to this page.
  late List<PictureRun> _runs = <PictureRun>[
    for (final picture in widget.pictures)
      widget.runs.firstWhere(
        (run) => run.name == picture.name,
        orElse: () => PictureRun(name: picture.name, spans: const []),
      ),
  ];

  /// The picture the reader is assigning to: the one the page was opened on
  /// (FR-014's warning names it), else the first, until they choose another.
  late int _selected = _indexOf(widget.inView) ?? 0;

  /// Where a picture with this name sits in force, or null when it is not here.
  int? _indexOf(String? name) {
    final index = name == null
        ? -1
        : _pictures.indexWhere((picture) => picture.name == name);
    return index < 0 ? null : index;
  }

  /// The sentences the selected picture holds, in the render's own order.
  Set<int> get _selectedSentences =>
      indicesOfSpans(_runs[_selected].spans, widget.sentences).toSet();

  /// The assignment as it stands, read the way the render will read it — which
  /// is what says who may be moved (FR-015's fallback case).
  AssignmentAnswer get _answer => assignmentsFor(
    sentences: widget.sentences,
    pictures: _pictures,
    runs: _runs,
  );

  /// One tap on a sentence: give it to the selected picture, take it back, or
  /// say which rule refuses it — and change nothing when it is refused (FR-012).
  void _tap(int index) {
    final refusal = _selectedSentences.contains(index)
        ? refusedRemove(
            sentences: widget.sentences,
            runs: _runs,
            picture: _selected,
            index: index,
          )
        : refusedAdd(
            sentences: widget.sentences,
            runs: _runs,
            picture: _selected,
            index: index,
          );
    if (refusal != null) {
      _refuse(refusal);
      return;
    }
    _toggle(index);
  }

  /// Gives [index] to the selected picture, or takes it back — one gesture, one
  /// decision, and the run's spans stay ascending (the record's own contract).
  void _toggle(int index) {
    final sentence = widget.sentences[index];
    final span = (sentence.start, sentence.end);
    final spans = List<(int, int)>.of(_runs[_selected].spans);
    if (!spans.remove(span)) spans.add(span);
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    setState(() {
      _runs[_selected] = PictureRun(name: _runs[_selected].name, spans: spans);
    });
  }

  /// Moves the picture at [from] to [to] (FR-015, SC-009): the pictures and
  /// their runs in one gesture, so the order the page shows is the order the
  /// render will walk. 012's own helper does the moving — one list's own rule,
  /// read twice.
  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      _pictures = movePicture(_pictures, from, to);
      _runs = movePicture(_runs, from, to);
      _selected = to;
    });
  }

  /// Says which rule was broken (FR-012), where the reader is looking.
  void _refuse(AssignmentRefusal refusal) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_reason(l10n, refusal))));
  }

  String _reason(AppLocalizations? l10n, AssignmentRefusal refusal) =>
      switch (refusal) {
        AssignmentRefusal.notContinuous =>
          l10n?.assignmentRefusedNotContinuous ??
              'Only the sentences next to the ones this picture already has '
                  'can be added.',
        AssignmentRefusal.notInOrder =>
          l10n?.assignmentRefusedNotInOrder ??
              'That sentence comes before sentences an earlier picture already '
                  'has.',
        AssignmentRefusal.middleOfRun =>
          l10n?.assignmentRefusedMiddle ??
              'Only the first or last sentence of a picture can be removed.',
        AssignmentRefusal.holdsSentences =>
          l10n?.assignmentRefusedHoldsSentences ??
              'This picture holds sentences; un-assign them before moving it.',
      };

  /// The name of the picture holding [index], when it is not the selected one.
  String? _holderOf(int index) {
    for (var picture = 0; picture < _pictures.length; picture++) {
      if (picture == _selected) continue;
      if (indicesOfSpans(_runs[picture].spans, widget.sentences)
          .contains(index)) {
        return _runs[picture].name;
      }
    }
    return null;
  }

  /// The reader's answer: **a run that holds nothing is not a decision**, so it
  /// is left out — an empty answer is the no-assignment state the render reads
  /// as 012's own split (FR-009). The pictures themselves stay in the order,
  /// because a drag can put a picture holding nothing somewhere else and the
  /// render walks that order (FR-015).
  void _done() => Navigator.of(context).pop(
    AssignmentDraft(
      pictures: _pictures,
      runs: <PictureRun>[
        for (final run in _runs)
          if (!run.isEmpty) run,
      ],
    ),
  );

  String _countLabel(AppLocalizations? l10n, int count) => count == 0
      ? (l10n?.assignmentNothingAssigned ?? 'No sentences assigned')
      : (l10n?.assignmentSentenceCount(count) ?? '$count sentences');

  /// One picture: its name, its own count, and the reader's two gestures on it —
  /// select (a tap) and, when it holds nothing, move it (a hold and a drop, the
  /// gesture 012's own picker taught the reader).
  Widget _chip(int picture, AppLocalizations? l10n, bool mayMove) {
    final chip = ChoiceChip(
      selected: picture == _selected,
      onSelected: (_) => setState(() => _selected = picture),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_pictures[picture].name),
          Text(
            _countLabel(l10n, _runs[picture].spans.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    // **Every** chip takes a drop: a picture holding nothing may move to any
    // place the reader picks, including a place a picture with sentences holds
    // (which is why the drop and the lift are two different questions).
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (dragged) => _move(dragged.data, picture),
      builder: (context, candidate, rejected) => mayMove
          ? LongPressDraggable<int>(
              data: picture,
              feedback: Material(color: Colors.transparent, child: chip),
              childWhenDragging: Opacity(opacity: 0.4, child: chip),
              child: chip,
            )
          // A picture that holds sentences does not lift — with its reason
          // (FR-015, FR-012): the hold says so instead of moving it.
          : GestureDetector(
              onLongPress: () => _refuse(AssignmentRefusal.holdsSentences),
              child: chip,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedSentences;
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.assignmentOpenButton ?? 'Assign sentences'),
        actions: [
          TextButton(
            onPressed: _done,
            // 015's own word for it, reused rather than minted again: the
            // reader's Done is the reader's Done.
            child: Text(l10n?.doneButton ?? 'Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (var picture = 0; picture < _pictures.length; picture++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chip(picture, l10n, mayDrag(answer, picture)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.sentences.length,
              itemBuilder: (context, index) {
                final mine = selected.contains(index);
                final holder = mine ? null : _holderOf(index);
                return ListTile(
                  title: Text(widget.sentences[index].text.trim()),
                  leading: Icon(
                    mine ? Icons.check_circle : Icons.radio_button_unchecked,
                    semanticLabel: mine
                        ? (l10n?.assignmentRemoveSentence ??
                              'Remove this sentence')
                        : null,
                  ),
                  // Whose it is, when it is another picture's: a sentence
                  // belongs to one picture (FR-005), and the reader can see
                  // which.
                  trailing: holder == null ? null : Text(holder),
                  onTap: () => _tap(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
