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
/// (`refusedAdd`, `refusedRemove`, `mayMove`) and this page only shows what they
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
import 'picture_cell.dart';
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
  late final List<HeldPicture> _pictures = List<HeldPicture>.of(widget.pictures);

  /// The reader's answer so far: one run per picture, in [_pictures]' own order,
  /// so the page and the render share one order.
  ///
  /// Seeded from what is stored, **filtered to the pictures in force**: a run
  /// whose picture is not here belongs to FR-014's warning, not to this page.
  late final List<PictureRun> _runs = <PictureRun>[
    for (final picture in widget.pictures)
      widget.runs.firstWhere(
        (run) => run.name == picture.name,
        orElse: () => PictureRun(name: picture.name, spans: const []),
      ),
  ];

  /// The picture the reader is assigning to: the one the page was opened on
  /// (FR-014's warning names it), else the first, until they choose another.
  late int _selected = _indexOf(widget.inView) ?? 0;

  /// The picture the reader is looking at large, or null (FR-004): a hold on a
  /// thumbnail opens it below the strip, hides the sentence list, and `Close`
  /// brings the list back on the same picture.
  int? _large;

  /// A key per picture's own cell, so the strip can scroll one to its middle
  /// (FR-007). Keyed by the picture's own name, which survives a move.
  final Map<String, GlobalKey> _cellKeys = <String, GlobalKey>{};

  GlobalKey _cellKey(String name) =>
      _cellKeys.putIfAbsent(name, () => GlobalKey());

  /// Scrolls the picture at [picture] to the middle of the strip (FR-007) — after
  /// the frame that changed the strip, so the cell is where this reads it.
  void _centreOn(int picture) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cell = _cellKey(_pictures[picture].name).currentContext;
        if (cell == null) return;
        Scrollable.ensureVisible(
          cell,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });

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
  /// One tap on a sentence, and what it means depends on **whose** it is
  /// (FR-003, FR-011): the selected picture's own is given back or taken, nobody's
  /// is given to it, and another picture's is proposed as a switch — after the
  /// rules have answered, because a sentence the holder cannot let go of (or the
  /// target cannot take) is refused with its own reason and no box appears.
  void _tap(int index) {
    final holder = holderOf(
      sentences: widget.sentences,
      runs: _runs,
      index: index,
    );
    if (holder != null && holder != _selected) {
      _proposeSwitch(holder, index);
      return;
    }
    final refusal = holder == _selected
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

  /// The reader's tap on another picture's sentence (FR-011, FR-012): the rules
  /// answer first, and where they allow it the reader is shown **both** pictures
  /// and asked to confirm. Confirming applies the repair the rule defines.
  Future<void> _proposeSwitch(int holder, int index) async {
    final l10n = AppLocalizations.of(context);
    final refusal = refusedSwitch(
      sentences: widget.sentences,
      runs: _runs,
      picture: _selected,
      index: index,
    );
    if (refusal != null) {
      _refuse(refusal);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n?.assignmentSwitchTitle ??
              'Give this sentence to the selected picture?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.sentences[index].text.trim()),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PictureCell(
                  picture: _pictures[holder],
                  count: _runs[holder].spans.length,
                  size: 112,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward),
                ),
                PictureCell(
                  picture: _pictures[_selected],
                  count: _runs[_selected].spans.length,
                  size: 112,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.assignmentSwitchBody(widget.sentences[index].text.trim()) ??
                  'It belongs to another picture now; it moves to the selected '
                      'one.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // 015's own word for it, reused rather than minted again.
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.assignmentSwitchConfirm ?? 'Move it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final switched = applySwitch(
      sentences: widget.sentences,
      runs: _runs,
      picture: _selected,
      index: index,
    );
    setState(() {
      for (var picture = 0; picture < switched.length; picture++) {
        _runs[picture] = switched[picture];
      }
    });
    _refuseNothing();
  }

  /// A switch is an edit the reader confirmed, and its own visible answer is the
  /// thumbnails' counts (FR-012); this only clears a refusal still on screen.
  void _refuseNothing() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

  /// Moves the picture at [from] to [to] (FR-006): the pictures, their runs and
  /// the strip's own order in one gesture, so the order the page shows is the
  /// order the render will walk. 012's own helper does the moving.
  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      // In place, because the page's own lists are what the cells and the
      // sentence list are built from: the same length, a new order.
      final movedPictures = movePicture(_pictures, from, to);
      for (var i = 0; i < movedPictures.length; i++) {
        _pictures[i] = movedPictures[i];
      }
      final movedRuns = movePicture(_runs, from, to);
      for (var i = 0; i < movedRuns.length; i++) {
        _runs[i] = movedRuns[i];
      }
      _selected = to;
      _large = to;
    });
    _centreOn(to);
  }

  /// Takes a picture out of the pass, after asking (FR-008, FR-009). The
  /// confirmation names the picture by its own cell — never by its file name —
  /// and cancelling changes nothing: the pictures, the order and the record are
  /// what they were.
  Future<void> _deletePicture(int picture) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.assignmentDeleteTitle ?? 'Delete this picture?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PictureCell(
              picture: _pictures[picture],
              count: _runs[picture].spans.length,
              size: 120,
              showCount: false,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.assignmentDeleteBody ??
                  'This picture will be removed from this video.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.deleteButton ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _pictures.removeAt(picture);
      _runs.removeAt(picture);
      _large = null;
      if (_selected >= _pictures.length) _selected = _pictures.length - 1;
    });
    _centreOn(_selected);
  }

  /// The picture the reader held, large, below the strip (FR-004): the app's own
  /// words for its count under it (FR-019), the three controls when the reader
  /// gave it nothing (FR-005), and `Close`.
  Widget _bigPicture(AppLocalizations? l10n, int picture) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Center(
          child: PictureCell(
            picture: _pictures[picture],
            count: _runs[picture].spans.length,
            size: 220,
          ),
        ),
        const SizedBox(height: 12),
        Text(_countLabel(l10n, _runs[picture].spans.length)),
        if (mayMove(_runs, picture))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                // A picture already at an end of the order has nowhere to go, so
                // the control says so rather than doing nothing.
                onPressed: picture > 0 ? () => _move(picture, picture - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: Text(l10n?.assignmentMoveLeft ?? 'Move left'),
              ),
              TextButton.icon(
                onPressed: picture < _pictures.length - 1
                    ? () => _move(picture, picture + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: Text(l10n?.assignmentMoveRight ?? 'Move right'),
              ),
            ],
          ),
        if (mayMove(_runs, picture))
          TextButton.icon(
            onPressed: () => _deletePicture(picture),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n?.assignmentDeletePicture ?? 'Delete this picture'),
          ),
        TextButton(
          onPressed: () => setState(() => _large = null),
          child: Text(l10n?.assignmentClose ?? 'Close'),
        ),
      ],
    ),
  );

  /// The count in the app's own words — `N sentences` / `No sentences assigned`
  /// (FR-019): on the thumbnails it is the number alone, and this is where those
  /// words live instead.
  String _countLabel(AppLocalizations? l10n, int count) => count == 0
      ? (l10n?.assignmentNothingAssigned ?? 'No sentences assigned')
      : (l10n?.assignmentSentenceCount(count) ?? '$count sentences');

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

  /// The picture holding [index], when it is not the selected one: what the
  /// sentence list marks a sentence of another picture's with (FR-003).
  ///
  /// A picture, not its name — the name is not painted anywhere on this page
  /// (FR-002), and a list that named it would be the one place it came back.
  int? _holderPicture(int index) {
    for (var picture = 0; picture < _pictures.length; picture++) {
      if (picture == _selected) continue;
      if (indicesOfSpans(_runs[picture].spans, widget.sentences)
          .contains(index)) {
        return picture;
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

  /// One picture in the strip (FR-001, FR-002, FR-003, FR-004): the picture
  /// itself with its own count, the highlight when it is the one the reader is
  /// assigning to, a tap that selects it and a hold that opens it large.
  Widget _cell(int picture) => GestureDetector(
    key: _cellKey(_pictures[picture].name),
    onTap: () {
      setState(() => _selected = picture);
      _centreOn(picture);
    },
    // A hold is not a move any more (D10): it opens the picture large, which is
    // where the controls that do move it live (FR-004, FR-005).
    onLongPress: () => setState(() {
      _selected = picture;
      _large = picture;
    }),
    child: PictureCell(
      picture: _pictures[picture],
      count: _runs[picture].spans.length,
      selected: picture == _selected,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedSentences;
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
                    child: _cell(picture),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_large != null)
            Expanded(
              child: SingleChildScrollView(child: _bigPicture(l10n, _large!)),
            )
          else
          Expanded(
            child: ListView.builder(
              itemCount: widget.sentences.length,
              itemBuilder: (context, index) {
                final mine = selected.contains(index);
                final holder = mine ? null : _holderPicture(index);
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
                  // belongs to one picture (FR-005), and the reader sees which
                  // one — as the picture, never as its file name (FR-002).
                  trailing: holder == null
                      ? null
                      : SizedBox(
                          width: 28,
                          height: 28,
                          child: PictureCell(
                            picture: _pictures[holder],
                            count: _runs[holder].spans.length,
                            size: 28,
                            showCount: false,
                          ),
                        ),
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
