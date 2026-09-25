import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:klhu/appearance_screen.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/content_list_screen.dart';
import 'package:klhu/language.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/read_position_store.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';
import 'package:klhu/l10n/app_localizations.dart';

/// Reading view (003, revised per emulator validation): RichText for
/// READ/SPEAKING with the 001 yellow highlight (tap selects sentence,
/// long-press selects paragraph, read tracking highlights the spoken
/// SENTENCE and keeps it on screen — 011 FR-020/FR-021); a TextField appears
/// ONLY in EDIT mode.
///
/// - READ (default): RichText, tap sentence / long-press paragraph, keyboard
///   never appears, no caret/selection UI. TalkBack gestures keep meanings.
///   The same gesture also sets the Continue Read start position (010).
///   ▶ Read speaks that selection and asks for one when nothing is selected
///   (011 FR-023/FR-024); ⏭ Continue Read reads it to the end of the text, and
///   from the first sentence when there is none (010 FR-004/FR-005, 011 FR-022).
/// - EDIT (Edit button, idle-only): fully editable TextField with native
///   type/paste/copy/cut; Read + Continue Read + Stop hidden, only Done shows.
///   Done commits the text and returns to READ.
/// - SPEAKING / PAUSED: RichText locked — a touch on the text changes nothing at
///   all: no selection, no position, and the read is NOT stopped, so a tap that
///   only woke a dimmed display or stopped the page's own fling cannot interrupt
///   the reading (011 FR-025). The tracking highlight moves with the spoken
///   sentence and the page follows it; Edit is disabled until Stop / natural end.
///
/// No gesture overloading (tap means one thing per state); typing-during-read
/// and Read-with-unsaved-edits are impossible by construction.
///
/// Content library (008): the app-bar Content action opens the unified list
/// and loads what it returns; EDIT offers Save and Undo beside Done. Save goes
/// through [ContentStore.saveEdited], so editing a pre-set produces new
/// content while editing a saved page updates it in place.
class ReadingView extends StatefulWidget {
  final Reader reader;
  final VoiceStore voiceStore;
  final ContentStore contentStore;
  final Function(String)? onLanguageChanged;
  final dynamic localizationService;

  ReadingView({
    super.key,
    Reader? reader,
    VoiceStore? voiceStore,
    ContentStore? contentStore,
    this.onLanguageChanged,
    this.localizationService,
  })  : reader = reader ?? ReaderService(),
        voiceStore = voiceStore ?? VoiceStore(),
        contentStore = contentStore ?? ContentStore();

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

enum _Mode { read, edit, speaking, paused }

/// A reported sentence's box against the visible area, in the visible area's
/// own coordinates: what the follow decision is made on and what the
/// `klhu follow:` evidence line prints.
class _SentenceGeometry {
  /// The paragraph the box was measured on — the reveal's target.
  final RenderParagraph paragraph;

  /// The box, in [paragraph]'s own coordinates (what `showOnScreen` wants).
  final Rect rect;

  /// Distance from the visible area's top edge to the box's top.
  final double top;

  /// Distance from the visible area's top edge to the box's bottom.
  final double bottom;

  /// Height of the visible area.
  final double viewport;

  const _SentenceGeometry({
    required this.paragraph,
    required this.rect,
    required this.top,
    required this.bottom,
    required this.viewport,
  });

  /// Fully inside the visible area: the page does not have to move for it.
  bool get visible => top >= 0 && bottom <= viewport;
}

class _ReadingViewState extends State<ReadingView> {
  final _textKey = GlobalKey();
  final _focusNode = FocusNode();
  TextEditingController? _editController;

  /// Scope for the platform undo stack, one per EDIT session so the stack can
  /// never reach back into a document that is no longer on screen (008).
  UndoHistoryController? _undoController;

  /// The library entry currently on screen, if any (the catalog fallback has
  /// none): what a Save edits in place instead of creating new content.
  SavedContent? _loaded;

  /// Empty until the library (or the shipped catalog) supplies a text: with the
  /// sample buttons gone, content only ever comes from the library (008).
  String _content = '';
  TextSegment? _highlight;
  _Mode _mode = _Mode.read;

  /// The Continue Read start position in force: an offset into [_content] at a
  /// sentence or paragraph start, or null for "read from the beginning"
  /// (FR-004/FR-005). Distinct from [_highlight]: tracking repaints the
  /// highlight per sentence, and the position must survive that.
  ///
  /// The two are in force together and die together (FR-022): a tap is the one
  /// gesture that sets both, the tracking highlight does not move the position,
  /// and every state a read leaves — Stop, the end of a read, EDIT — takes the
  /// highlight away and clears the position with it, in memory and on disk, so
  /// nothing can resume from a sentence that is no longer painted.
  int? _anchor;

  /// Which text [_anchor] belongs to — the library entry id, or the shipped
  /// pre-set's id on the catalog-fallback path. Null when the text has no name
  /// yet, which also means nothing can be persisted for it.
  String? _anchorKey;

  /// Position writes in flight: a tap supersedes an earlier one, so only the
  /// last position the user set may land on disk.
  int _anchorWrite = 0;

  /// Per-device position store (010 FR-008); `shared_preferences`, like the
  /// voice picks and the interface language.
  final _positions = ReadPositionStore();

  /// Per-device appearance store (011 US2): the reading text's typeface and
  /// size, in the same store as the app's other view state.
  final _appearances = AppearanceStore();

  /// The appearance in force. The defaults are the app's shipped look, which is
  /// also what an absent or malformed record reads as (contract § Read rules).
  ReadingAppearance _appearance = ReadingAppearance.defaults;

  ContentStore get _store => widget.contentStore;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
    _openInitialContent();
  }

  /// Puts the stored appearance in force. A record naming something this build
  /// does not offer already read as the defaults in the store, so there is
  /// nothing to validate here.
  Future<void> _loadAppearance() async {
    final stored = await _appearances.load();
    if (!mounted) return;
    if (stored.typeface.name == _appearance.typeface.name &&
        stored.size.name == _appearance.size.name) {
      return;
    }
    setState(() => _appearance = stored);
  }

  /// Opens the appearance screen and puts the confirmed choice in force; a
  /// dismissed screen (null) changes nothing and writes nothing (FR-008).
  Future<void> _openAppearance() async {
    final chosen = await Navigator.of(context).push<ReadingAppearance>(
      MaterialPageRoute(
        builder: (_) => AppearanceScreen(
          initial: _appearance,
          previewText: _previewText(),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _appearance = chosen);
    await _appearances.save(chosen);
  }

  /// What the appearance screen previews: the page's own first paragraph, short
  /// enough for the preview box.
  String _previewText() {
    final text = _content.trim();
    if (text.isEmpty) return '';
    final paragraphs = paragraphRanges(text);
    final first = paragraphs.isEmpty
        ? text
        : text.substring(paragraphs.first.start, paragraphs.first.end);
    return first.length <= 240 ? first : '${first.substring(0, 240)}…';
  }

  /// How long storage gets to answer before the page falls back to the shipped
  /// pre-set. A hung or absent storage plugin must never leave a blank page.
  static const Duration _storageDeadline = Duration(seconds: 3);

  /// Opens the last used content, else the first one, else the first shipped
  /// pre-set: a fresh install is never a blank page.
  Future<void> _openInitialContent() async {
    try {
      final entries = await _store.list().timeout(_storageDeadline);
      final last = await _store.lastOpened().timeout(_storageDeadline);
      final entry = last ?? (entries.isEmpty ? null : entries.first);
      if (entry != null) {
        await _loadEntry(entry);
        _reportStorageSignal();
        return;
      }
    } on Object {
      // Storage missing, unreadable or too slow to answer: reading still works
      // from the shipped catalog, which needs no storage at all.
    }
    await _loadCatalogFallback();
    _reportStorageSignal();
  }

  /// Surfaces the store's own signal ONCE, after the page has content: a
  /// damaged index that was moved aside and re-seeded, or an IO failure that
  /// left the library empty, otherwise looks to the user like "my contents
  /// vanished" with no explanation (contract § Error and repair states,
  /// FR-010). The signal is cleared so the next launch is quiet again.
  void _reportStorageSignal() {
    final signal = _store.lastError;
    if (signal == null || !mounted) return;
    _store.clearError();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _error = switch (signal) {
        ContentError.indexRepaired =>
          l10n?.libraryRepairedMessage ?? 'The library was repaired.',
        _ => l10n?.storageErrorMessage ?? 'Could not open the library.',
      };
    });
  }

  /// The first shipped pre-set, shown when the library holds nothing. It is not
  /// an entry and not marked as opened — saving still creates new content.
  Future<void> _loadCatalogFallback() async {
    final presets = await _store.catalog();
    if (presets.isEmpty || !mounted) return;
    final preset = presets.first;
    final previous = _anchorKey;
    setState(() {
      _content = preset.text;
      _loaded = null;
      _anchor = null;
      _anchorKey = preset.id;
      _editController?.value = TextEditingValue(
        text: preset.text,
        selection: TextSelection.collapsed(offset: preset.text.length),
      );
      _highlight = null;
      _error = null;
      _hint = null;
    });
    await _adoptAnchor(previous);
  }

  /// The text on screen changed (FR-007): the position in force belonged to the
  /// text being left — it is forgotten here and on disk — and the incoming
  /// content's own stored position is put back (FR-008).
  Future<void> _adoptAnchor(String? previous) async {
    if (previous != null && previous != _anchorKey) {
      await _positions.clear(previous);
    }
    await _restoreAnchor();
  }

  /// Puts the stored position for the content on screen back in force, and
  /// shows it: a restored position that read from an invisible offset would be
  /// a mystery button. A missing record, a malformed one or one computed on
  /// different text all mean "read from the beginning" (FR-005/FR-009).
  Future<void> _restoreAnchor() async {
    final key = _anchorKey;
    final length = _content.length;
    if (key == null || length == 0) return;
    final stored = await _positions.load(key, length);
    if (stored == null || !mounted) return;
    final segment = resolveSentence(_content, stored.offset);
    setState(() {
      _anchor = segment.start;
      _highlight = segment;
    });
  }

  /// Forgets the position: the visible text changed (FR-007). The record goes
  /// with the field, so a restart cannot bring the old offset back.
  Future<void> _clearAnchor() async {
    final key = _anchorKey;
    // A write still in flight is for text that no longer exists.
    _anchorWrite++;
    if (_anchor != null) setState(() => _anchor = null);
    if (key == null) return;
    await _positions.clear(key);
  }

  /// Invalidates a stale read's `finally` (tap/Stop during SPEAKING must win
  /// over the in-flight loop's cleanup).
  int _readGen = 0;

  /// Rapid toggle guard: consecutive pause/resume taps are queued, not
  /// stacked. Prevents a burst of taps from ending up in a spurious paused
  /// state after the read has already finished.
  bool _isPausing = false;
  bool _isResuming = false;

  bool get _isSpeakingOrPaused =>
      _mode == _Mode.speaking || _mode == _Mode.paused;

  String? _error;
  String? _hint;

  /// Guard against rapid language switching
  bool _isLanguageChanging = false;

  /// Build the language dropdown widget
  Widget _buildLanguageDropdown(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    
    final currentLanguage = widget.localizationService?.getCurrentLanguageCode() ?? 'en';

    return DropdownButton<String>(
      value: currentLanguage,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.language, size: 20),
      items: [
        DropdownMenuItem(
          value: 'en', 
          child: Text(l10n.englishNative),
        ),
        DropdownMenuItem(
          value: 'zh', 
          child: Text(l10n.chineseNative),
        ),
        DropdownMenuItem(
          value: 'es',
          child: Text(l10n.spanishNative),
        ),
      ],
      onChanged: (String? newLanguage) async {
        if (newLanguage == null || _isLanguageChanging) return;
        
        // Set guard to prevent rapid switching
        setState(() => _isLanguageChanging = true);
        
        // Full stop before the language change: resetting to READ drops any
        // paused/speaking state, or the UI keeps offering Resume for speech
        // that no longer exists (spec 005 scenario 7).
        await _stop();
        
        // Call the language change callback
        widget.onLanguageChanged?.call(newLanguage);
        
        // Reset guard after language change completes
        setState(() => _isLanguageChanging = false);
      },
    );
  }

  @override
  void dispose() {
    _disposeUndo();
    _editController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The undo stack belongs to one EDIT session; leaving EDIT ends it.
  void _disposeUndo() {
    _undoController?.removeListener(_onUndoChanged);
    _undoController?.dispose();
    _undoController = null;
  }

  void _onUndoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _enterEdit() async {
    if (_mode == _Mode.speaking) return;
    await widget.reader.stop();
    _editController ??= TextEditingController();
    // A valid selection, so the loaded text is the undo stack's first state
    // and the very first typed edit is already undoable.
    _editController!.value = TextEditingValue(
      text: _content,
      selection: TextSelection.collapsed(offset: _content.length),
    );
    _disposeUndo();
    _undoController = UndoHistoryController()..addListener(_onUndoChanged);
    setState(() {
      _mode = _Mode.edit;
      _highlight = null;
      _hint = null;
    });
    // EDIT paints no highlight, so no position is in force either (FR-022):
    // the offsets the editor can change are the ones a stored position is
    // measured against (010 FR-007).
    await _clearAnchor();
    _focusNode.requestFocus();
  }

  Future<void> _doneEdit() async {
    // Done commits the edit — and SAVES it first when the text changed, so
    // leaving the editor can never lose work (008's Done used to leave the
    // text on screen only, which silently dropped a new draft and any edit).
    // An empty text has nothing to save and is not a refusal to fix: the page
    // goes back to READ empty and the stored entry keeps its own text, as
    // before (008). Any other refusal (too long, storage error) keeps the
    // editor open with its message on screen, because the screen would
    // otherwise show text the library does not have.
    if (_hasUnsavedEdits && _editController!.text.trim().isNotEmpty) {
      if (!await _save()) return;
      if (!mounted) return;
    }
    setState(() {
      _content = _editController!.text;
      _mode = _Mode.read;
      _highlight = null;
    });
    _disposeUndo();
    await _clearAnchor();
  }

  // -------------------------------------------------------------------
  // Content library (008)
  // -------------------------------------------------------------------

  bool get _hasUnsavedEdits =>
      _mode == _Mode.edit && _editController?.text != _content;

  Future<void> _loadEntry(SavedContent entry) async {
    try {
      final text = await _store.read(entry);
      await _store.markOpened(entry.id);
      if (!mounted) return;
      final previous = _anchorKey;
      setState(() {
        _content = text;
        _loaded = entry;
        _anchor = null;
        _anchorKey = entry.id;
        _editController?.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _highlight = null;
        _error = null;
        _hint = null;
        // Loading during SPEAKING is impossible (the list is opened from a
        // READ-only action), but a stale PAUSED state must not survive.
        if (_mode == _Mode.speaking) _mode = _Mode.read;
      });
      await _adoptAnchor(previous);
    } on ContentStoreException {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)
              ?.damagedContentMessage ??
          'This content is damaged');
    }
  }

  Future<void> _openContentList() async {
    await widget.reader.stop();
    if (!mounted) return;
    final chosen = await Navigator.of(context).push<ContentListResult>(
      MaterialPageRoute(builder: (_) => ContentListScreen(store: _store)),
    );
    if (chosen == null || !mounted) return;
    // Both outcomes replace what is on screen, so 008's unsaved-edit guard is
    // asked once, before either.
    if (_hasUnsavedEdits && await _confirmDiscard() != true) return;
    switch (chosen) {
      case PickedContent(:final entry):
        await _loadEntry(entry);
        // A picked entry replaces the page: leaving EDIT with it is what the
        // user asked for (008).
        if (mounted && _mode == _Mode.edit) {
          setState(() => _mode = _Mode.read);
          _disposeUndo();
        }
      case NewContentRequest():
        await _startNewContent();
    }
  }

  /// The list's add action (011 FR-016): a blank page in EDIT, with no entry
  /// behind it. Nothing is created until Save names it from the text, and the
  /// content that was on screen keeps everything it had — its stored position
  /// included, because a draft never belonged to it (FR-019).
  Future<void> _startNewContent() async {
    await widget.reader.stop();
    if (!mounted) return;
    setState(() {
      _content = '';
      _loaded = null;
      _anchor = null;
      _anchorKey = null;
      _highlight = null;
      _error = null;
      _hint = null;
    });
    await _enterEdit();
  }

  /// True when the user chose to throw the edits away.
  Future<bool?> _confirmDiscard() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.unsavedChangesTitle ?? 'Unsaved changes'),
        content: Text(l10n?.unsavedChangesMessage ?? 'Unsaved changes'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.discardButton ?? 'Discard'),
          ),
        ],
      ),
    );
  }

  /// Save: a pre-set becomes new content, a saved page is updated in place;
  /// a refused save explains itself and writes nothing (008 FR-010/FR-019).
  /// Reports whether the text was written, so a caller that was about to leave
  /// the editor can stay in it instead.
  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context);
    final text = _editController!.text;
    try {
      final previous = _anchorKey;
      final saved = await _store.saveEdited(_loaded, text);
      if (!mounted) return true;
      setState(() {
        _content = text;
        _loaded = saved;
        _anchor = null;
        // Editing a pre-set produces a new entry: the position belongs to the
        // text this Save replaced.
        _anchorKey = saved.id;
      });
      _anchorWrite++;
      if (previous != null) await _positions.clear(previous);
      _showMessage(l10n?.savedMessage ?? 'Saved');
      return true;
    } on ContentStoreException catch (e) {
      if (!mounted) return false;
      _showMessage(switch (e.kind) {
        ContentError.emptyText =>
          l10n?.nothingToSaveMessage ?? 'There is nothing to save',
        ContentError.tooLarge => l10n?.contentTooLargeMessage(kMaxContentChars) ??
            'Too long to save',
        _ => l10n?.storageErrorMessage ?? 'Could not save.',
      });
      return false;
    }
  }

  void _undo() {
    final controller = _undoController;
    if (controller == null || !controller.value.canUndo) return;
    controller.undo();
    // Oldest state reached: say so rather than leaving a dead button.
    if (!controller.value.canUndo) {
      _showMessage(AppLocalizations.of(context)?.undoExhaustedMessage ??
          'Nothing more to undo');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onTapText(TapUpDetails details) async {
    // While a read is playing or parked, a touch on the text does NOTHING
    // (FR-025): the page is following the read, the user may be tapping to wake
    // a dimmed display or to stop the page's own fling, and neither may end the
    // read or move the position. Ending a read is Pause/Stop's job.
    if (_isSpeakingOrPaused) return;
    await _resolveAt(details.globalPosition, resolveSentence);
  }

  Future<void> _onLongPressText(LongPressStartDetails details) async {
    // Same rule as a tap, for the same reason (FR-025).
    if (_isSpeakingOrPaused) return;
    await _resolveAt(details.globalPosition, resolveParagraph);
  }

  /// Shared idle tap/long-press path: map the touch point to a text offset,
  /// resolve to the enclosing segment, highlight, set the Continue Read start
  /// position from the same segment (D1), and wait for a read action
  /// (data-model invariant).
  ///
  /// The gesture is arena-gated (`onTapUp`, not `onTapDown`): a touch that turns
  /// into a scroll, or the tap that stops the page's fling, never resolves a
  /// sentence (FR-025).
  Future<void> _resolveAt(Offset globalPosition,
      TextSegment Function(String, int) resolve) async {
    final obj = _textKey.currentContext?.findRenderObject();
    if (obj is! RenderParagraph) return;
    final pos =
        obj.getPositionForOffset(obj.globalToLocal(globalPosition));
    await widget.reader.stop();
    final segment = resolve(_content, pos.offset);
    setState(() {
      // Win over the stopped loop's `finally` below.
      _readGen++;
      _mode = _Mode.read;
      _highlight = segment;
      // A tap anchors the sentence it resolved to, a long-press its paragraph.
      _anchor = segment.start;
      _error = null;
      _hint = null;
    });
    await _persistAnchor();
  }

  /// Stores the position in force for the content on screen (FR-008).
  ///
  /// Written on the gesture that set it, not at read start, so a position the
  /// user set and never played is still remembered. The hop before the write
  /// lets a burst of taps supersede an earlier one, so the LAST position is the
  /// one that stays on disk (invariant I10).
  Future<void> _persistAnchor() async {
    final key = _anchorKey;
    final offset = _anchor;
    if (key == null || offset == null) return;
    final write = ++_anchorWrite;
    await Future<void>.microtask(() {});
    if (write != _anchorWrite) return;
    await _positions.save(
      key,
      ReadingPosition(
        contentKey: key,
        offset: offset,
        charCount: _content.length,
      ),
    );
  }

  /// ▶ Read (FR-023): speaks the SELECTION — the sentence a tap picked, or the
  /// paragraph a long-press picked — and nothing else. The page's gesture names
  /// the unit; the button reads exactly what is highlighted.
  ///
  /// With nothing highlighted there is no selection to scope the read to, so
  /// the page asks for one instead of reading aloud. Reading the text from its
  /// first sentence with nothing selected is ⏭ Continue Read's fallback (010
  /// FR-005), and two buttons that do the same thing explain neither.
  Future<void> _readSelection() async {
    final seg = _highlight;
    if (seg == null) {
      setState(() {
        _hint = AppLocalizations.of(context)?.selectToReadMessage ??
            'Select a sentence or paragraph to read';
        _error = null;
      });
      return;
    }
    await _readRange(seg.start, seg.end);
  }

  /// ⏭ Continue Read: the selection read to the end of the text — from the
  /// sentence a tap picked, from the paragraph a long-press picked, and from
  /// the first sentence when nothing is highlighted (010 FR-004/FR-005).
  Future<void> _readContinue() async {
    await _readRange(_anchor ?? 0, _content.length, track: true);
  }

  /// Shared read path (002 US1): resolve the range into per-paragraph
  /// speeches — each paragraph in its own language's picked voice, in order.
  /// A sentence tap inherits its enclosing paragraph's language (spec FR-001).
  /// With [track], the sentence being spoken is painted (011 FR-020) and kept
  /// on screen, and the highlight clears at end/Stop.
  Future<void> _readRange(int start, int end, {bool track = false}) async {
    final speeches = await resolveParagraphSpeeches(
      _content,
      start,
      end,
      widget.voiceStore.loadVoice,
    );
    if (speeches.isEmpty) {
      setState(() =>
          _hint = AppLocalizations.of(context)?.nothingToReadMessage ??
              'Nothing left to read from here.');
      return;
    }
    // Device evidence for the range actually read: `flutter_tts` never logs the
    // utterance text on Android, so this is what proves a read started where
    // the user pointed (research D10).
    debugPrint('klhu read range: $start..$end');
    final gen = ++_readGen;
    await _runRead(
      gen,
      () => widget.reader.speakParagraphs(
        speeches,
        onSentenceStart:
            track ? (spoken) => _onSpokenSentence(gen, spoken) : null,
      ),
    );
  }

  /// The last unit the page followed: re-reporting it — what a resume does for
  /// the sentence it interrupted — must not move the page (D9/FR-004).
  int _followedGen = -1;
  int _followedParagraph = -1;
  int _followedSentence = -1;

  /// The read reports the sentence it is about to speak (011 FR-020): paint
  /// exactly that span, then keep it on screen. One span, one measurement, one
  /// reveal — what is painted is what is followed.
  void _onSpokenSentence(int gen, SpokenSentence spoken) {
    if (!mounted || gen != _readGen) return;
    setState(() {
      _highlight = TextSegment(spoken.start, spoken.end, SegmentUnit.sentence);
    });
    _followRead(gen, spoken);
  }

  /// How long the page takes to move a sentence into view.
  static const Duration _revealDuration = Duration(milliseconds: 200);

  /// Brings the sentence being spoken into view, minimally.
  ///
  /// The box comes from the same [RenderParagraph] the tap path measures
  /// (`getBoxesForSelection`), and the move is the framework's own reveal
  /// (`showOnScreen` on the enclosing viewport): a sentence already fully
  /// visible is left alone, the sentence already playing is not dragged back
  /// after a manual scroll, and no scroll offset of this view's own is needed
  /// (research D1, constitution V).
  void _followRead(int gen, SpokenSentence spoken) {
    if (gen == _followedGen &&
        spoken.paragraph == _followedParagraph &&
        spoken.sentence == _followedSentence) {
      return;
    }
    final geometry = _measure(spoken);
    if (geometry == null) return;
    _followedGen = gen;
    _followedParagraph = spoken.paragraph;
    _followedSentence = spoken.sentence;
    if (geometry.visible) {
      _logFollow(spoken, geometry);
      return;
    }
    geometry.paragraph.showOnScreen(
      rect: geometry.rect,
      duration: _revealDuration,
      curve: Curves.easeOut,
    );
    // The evidence line reports the SETTLED state, one line per sentence: the
    // reveal is animated, so measuring here would report the sentence as off
    // screen — the very sentence the page is moving to. Post-frame callbacks
    // rather than a timer, so a test that never settles leaves nothing
    // pending.
    _logFollowWhenSettled(gen, spoken);
  }

  void _logFollowWhenSettled(int gen, SpokenSentence spoken, [int frames = 0]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _readGen) return;
      final settled = _measure(spoken);
      if (settled == null) return;
      // The animation runs for [_revealDuration]; a sentence that will not fit
      // at all is reported as it is rather than polled forever.
      if (!settled.visible && frames < 20) {
        _logFollowWhenSettled(gen, spoken, frames + 1);
        return;
      }
      _logFollow(spoken, settled);
    });
  }

  /// The reported sentence's box against the visible area, in the visible
  /// area's own coordinates — or null when there is no live paragraph to
  /// measure.
  _SentenceGeometry? _measure(SpokenSentence spoken) {
    final ctx = _textKey.currentContext;
    final obj = ctx?.findRenderObject();
    if (ctx == null || obj is! RenderParagraph) return null;
    final RenderObject? ancestor =
        ctx.findAncestorRenderObjectOfType<RenderAbstractViewport>();
    if (ancestor is! RenderBox) return null;
    final boxes = obj.getBoxesForSelection(
      TextSelection(baseOffset: spoken.start, extentOffset: spoken.end),
    );
    if (boxes.isEmpty) return null;
    final rect = boxes
        .map((box) => box.toRect())
        .reduce((a, b) => a.expandToInclude(b));
    final origin = ancestor.localToGlobal(Offset.zero);
    return _SentenceGeometry(
      paragraph: obj,
      rect: rect,
      top: obj.localToGlobal(rect.topLeft).dy - origin.dy,
      bottom: obj.localToGlobal(rect.bottomRight).dy - origin.dy,
      viewport: ancestor.size.height,
    );
  }

  /// The device walk's evidence line, in the app's other evidence lines' style
  /// (`klhu speak`, `klhu read range`): where the sentence being spoken sits in
  /// the visible area, and how tall that area is.
  void _logFollow(SpokenSentence spoken, _SentenceGeometry geometry) {
    debugPrint(
      'klhu follow: p${spoken.paragraph} s${spoken.sentence} '
      'visible=${geometry.visible ? 1 : 0} top=${geometry.top.round()} '
      'bottom=${geometry.bottom.round()} viewport=${geometry.viewport.round()}',
    );
  }

  /// SPEAKING while a read (or its continuation) runs, back to READ when it
  /// ends or throws. [gen] is the read generation the highlight callback was
  /// installed with; a stale one means a newer read owns the view now.
  Future<void> _runRead(int gen, Future<void> Function() start) async {
    if (mounted) setState(() => _mode = _Mode.speaking);
    try {
      await start();
    } on ReaderException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      // Leave the state alone when someone else owns it now: a stale
      // generation (tap/Stop started a newer read) or a PAUSE — the reader
      // kept the queue, so Resume must stay on screen instead of the buttons
      // silently falling back to idle.
      if (mounted && gen == _readGen && _mode == _Mode.speaking) {
        setState(() {
          _mode = _Mode.read;
          _highlight = null;
        });
        // The position lives only as long as the highlight that shows it
        // (011 FR-022): a read that has ended leaves nothing to continue from,
        // so ⏭ starts at the first sentence again instead of resuming from a
        // sentence nothing on screen points at.
        await _clearAnchor();
      }
    }
  }

  Future<void> _stop() async {
    _readGen++;
    _isPausing = false;
    _isResuming = false;
    await widget.reader.stop();
    setState(() {
      _mode = _Mode.read;
      _highlight = null;
    });
    // Stop takes the highlight away, and the position goes with it (FR-022):
    // ⏭ Continue Read starts at the first sentence afterwards rather than
    // resuming from a sentence the user can no longer see.
    await _clearAnchor();
  }

  Future<void> _pauseResume() async {
    if (_mode == _Mode.speaking) {
      if (_isPausing) return;
      _isPausing = true;
      // PAUSED first: the reader releases its parked loop while stopping the
      // audio, and the read's cleanup must not run under it.
      setState(() => _mode = _Mode.paused);
      await widget.reader.pause();
      if (mounted) setState(() => _isPausing = false);
    } else if (_mode == _Mode.paused) {
      if (_isResuming) return;
      _isResuming = true;
      // resume(), not pause(): the engine's pause is not a toggle (calling it
      // twice crashes the Android plugin), and the reader continues the queue
      // it kept. Same read generation: the continuation keeps updating the
      // highlight the read already installed.
      await _runRead(_readGen, () => widget.reader.resume());
      if (mounted) setState(() => _isResuming = false);
    }
  }

  /// Span tree for the reading area. A single RichText backs BOTH states
  /// (plain and highlighted) so selecting text can never change metrics:
  /// plain Text and RichText lay the same string out slightly differently.
  List<InlineSpan> _buildSpans() {
    final h = _highlight;
    if (h == null) return [TextSpan(text: _content)];
    return [
      TextSpan(text: _content.substring(0, h.start)),
      TextSpan(
        text: _content.substring(h.start, h.end),
        style: const TextStyle(backgroundColor: Colors.yellow),
      ),
      TextSpan(text: _content.substring(h.end)),
    ];
  }

  /// Explicit body style for the reading text. Two device-quirk-driven
  /// requirements (both found validating on Android emulator, Sep 2026):
  /// 1. Never capture `DefaultTextStyle.of(context)` here: above any local
  ///    wrapper the ambient style is MaterialApp's red-48px-monospace
  ///    fallback style (yellow double underline), which froze into the
  ///    content when captured explicitly.
  /// 2. Never leave the root span style null either: inherited paragraph
  ///    color mispaints as white on this GPU path — only an explicit color
  ///    paints. The theme's body color is also quantized to 32-bit sRGB
  ///    (extended-gamut Colors mispaint the same way).
  TextStyle _contentTextStyle(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium!;
    final color = body.color;
    final base = color == null ? body : body.copyWith(color: Color(color.toARGB32()));
    // The appearance seam (011 FR-009): this method is the ONE place the
    // reading text's style is built, and the rich text and the edit field both
    // go through it — so a chosen typeface and size reach both of them and
    // neither reaches the app's chrome. `default` sets no family, which leaves
    // the theme's own family (and the system's CJK fallback) in force.
    return base.copyWith(
      fontFamily: _appearance.typeface.familyFor(Theme.of(context).platform),
      fontSize: _appearance.size.points,
    );
  }

  /// Picker language (spec FR-003): language of the highlighted paragraph,
  /// else of the first paragraph; 'en' when there is no text.
  String _activeLanguage() {
    final anchor = _highlight?.start ?? 0;
    for (final para in paragraphRanges(_content)) {
      if (anchor >= para.start && anchor < para.end) {
        return detectLanguage(_content.substring(para.start, para.end));
      }
    }
    final paras = paragraphRanges(_content);
    if (paras.isEmpty) return 'en';
    final first = paras.first;
    return detectLanguage(_content.substring(first.start, first.end));
  }

  @override
  Widget build(BuildContext context) {
    final editing = _mode == _Mode.edit;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appTitle ?? 'klhu Read Aloud'),
        actions: [
          // Language dropdown
          if (widget.localizationService != null)
            _buildLanguageDropdown(context),
          IconButton(
            icon: const Icon(Icons.format_size),
            tooltip:
                AppLocalizations.of(context)?.appearanceButton ?? 'Appearance',
            // Idle-only (FR-014): changing the text's look mid-read would fight
            // the page's own tracking, which is measured on that text.
            onPressed: _isSpeakingOrPaused ? null : _openAppearance,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip:
                AppLocalizations.of(context)?.contentsButton ?? 'Contents',
            onPressed: () => _openContentList(),
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: AppLocalizations.of(context)?.voiceButton ?? 'Voice',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VoicePickerScreen(
                  reader: widget.reader,
                  store: widget.voiceStore,
                  language: _activeLanguage(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Content comes from the library only (008 FR-003): the sample
            // buttons are gone, replaced by the Content action in the app bar.
            const SizedBox(height: 8),
            Expanded(
              child: editing
                  // EDIT: the ONLY editable widget. Commits on Done.
                  ? TextField(
                      controller: _editController,
                      focusNode: _focusNode,
                      undoController: _undoController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: _contentTextStyle(context),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Edit text to read',
                      ),
                    )
                  // READ + SPEAKING: yellow-highlight RichText. No caret,
                  // no selection UI, no keyboard.
                  : SingleChildScrollView(
                      child: GestureDetector(
                        onTapUp: _onTapText,
                        onLongPressStart: _onLongPressText,
                        child: RichText(
                          key: _textKey,
                          // Explicit theme-derived style (see
                          // _contentTextStyle): neither ambient capture
                          // (fallback poison) nor null root (inherited white)
                          // paints correctly on this GPU path.
                          text: TextSpan(
                            style: _contentTextStyle(context),
                            children: _buildSpans(),
                          ),
                        ),
                      ),
                    ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_hint != null)
              Text(_hint!, style: const TextStyle(color: Colors.grey)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: editing
                  ? [
                      IconButton(
                        icon: const Icon(Icons.undo),
                        tooltip: AppLocalizations.of(context)?.undoButton,
                        // Disabled, not a silent no-op, with nothing to undo.
                        onPressed: (_undoController?.value.canUndo ?? false)
                            ? _undo
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.save_outlined),
                        tooltip: AppLocalizations.of(context)?.saveButton,
                        onPressed: () => _save(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: AppLocalizations.of(context)?.doneButton,
                        onPressed: _doneEdit,
                      ),
                    ]
                  : [
                      if (!_isSpeakingOrPaused)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          tooltip: AppLocalizations.of(context)?.readButton,
                          onPressed: _readSelection,
                        ),
                      if (!_isSpeakingOrPaused)
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          tooltip:
                              AppLocalizations.of(context)?.continueReadButton,
                          onPressed: _readContinue,
                        ),
                      if (_mode == _Mode.speaking)
                        IconButton(
                          icon: const Icon(Icons.pause),
                          tooltip: AppLocalizations.of(context)?.pauseButton,
                          onPressed: _isPausing ? null : _pauseResume,
                        ),
                      if (_mode == _Mode.paused)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          tooltip: AppLocalizations.of(context)?.resumeButton,
                          onPressed: _isResuming ? null : _pauseResume,
                        ),
                      IconButton(
                        icon: const Icon(Icons.stop),
                        tooltip: AppLocalizations.of(context)?.stopButton,
                        onPressed: _stop,
                      ),
                      IconButton(
                        // Idle-only: never enter EDIT mid-speech.
                        icon: const Icon(Icons.edit),
                        tooltip: AppLocalizations.of(context)?.editButton,
                        onPressed:
                            _mode == _Mode.speaking ? null : _enterEdit,
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
