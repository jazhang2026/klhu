import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
/// paragraph); a TextField appears ONLY in EDIT mode.
///
/// - READ (default): RichText, tap sentence / long-press paragraph, keyboard
///   never appears, no caret/selection UI. TalkBack gestures keep meanings.
///   The same gesture also sets the Continue Read start position (010).
/// - EDIT (Edit button, idle-only): fully editable TextField with native
///   type/paste/copy/cut; Read + Continue Read + Stop hidden, only Done shows.
///   Done commits the text and returns to READ.
/// - SPEAKING: RichText locked (no gestures resolve while speaking except
///   tap/long-press, which stop-first then select); tracking highlight moves
///   per paragraph; Edit disabled until Stop / natural end.
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
  /// highlight per paragraph, and the position must survive that.
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

  ContentStore get _store => widget.contentStore;

  @override
  void initState() {
    super.initState();
    _openInitialContent();
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
    _focusNode.requestFocus();
  }

  Future<void> _doneEdit() async {
    // Commit the edited text, leave EDIT.
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
    final picked = await Navigator.of(context).push<SavedContent>(
      MaterialPageRoute(builder: (_) => ContentListScreen(store: _store)),
    );
    if (picked == null || !mounted) return;
    if (_hasUnsavedEdits && await _confirmDiscard() != true) return;
    await _loadEntry(picked);
    if (mounted && _mode == _Mode.edit) {
      setState(() => _mode = _Mode.read);
      _disposeUndo();
    }
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
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final text = _editController!.text;
    try {
      final previous = _anchorKey;
      final saved = await _store.saveEdited(_loaded, text);
      if (!mounted) return;
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
    } on ContentStoreException catch (e) {
      if (!mounted) return;
      _showMessage(switch (e.kind) {
        ContentError.emptyText =>
          l10n?.nothingToSaveMessage ?? 'There is nothing to save',
        ContentError.tooLarge => l10n?.contentTooLargeMessage(kMaxContentChars) ??
            'Too long to save',
        _ => l10n?.storageErrorMessage ?? 'Could not save.',
      });
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

  Future<void> _onTapDown(TapDownDetails details) async {
    await _resolveAt(details.globalPosition, resolveSentence);
  }

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    await _resolveAt(details.globalPosition, resolveParagraph);
  }

  /// Shared tap/long-press path: map the touch point to a text offset,
  /// resolve to the enclosing segment, stop current speech, highlight, set the
  /// Continue Read start position from the same segment (D1), and wait for a
  /// read action (data-model invariant).
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

  Future<void> _readSelection() async {
    final seg = _highlight;
    if (seg == null) {
      // No tap yet: nothing is highlighted, so there is nothing to scope the
      // read to. Start at the first sentence instead of hinting the user away
      // from a button that otherwise looks broken.
      await _readContinue();
      return;
    }
    await _readRange(seg.start, seg.end);
  }

  Future<void> _readContinue() async {
    // The page read with a starting offset: with no position set this is
    // exactly the read the app shipped before (FR-005).
    await _readRange(_anchor ?? 0, _content.length, track: true);
  }

  /// Shared read path (002 US1): resolve the range into per-paragraph
  /// speeches — each paragraph in its own language's picked voice, in order.
  /// A sentence tap inherits its enclosing paragraph's language (spec FR-001).
  /// With [track], the yellow highlight follows each spoken paragraph (US3)
  /// and clears at end/Stop.
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
        onParagraphStart: track
            ? (i) {
                if (!mounted || gen != _readGen) return;
                setState(() {
                  _highlight = TextSegment(
                    speeches[i].start,
                    speeches[i].end,
                    SegmentUnit.paragraph,
                  );
                });
              }
            : null,
      ),
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
    if (color == null) return body;
    return body.copyWith(color: Color(color.toARGB32()));
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
                        onTapDown: _onTapDown,
                        onLongPressStart: _onLongPressStart,
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
                        onPressed: _save,
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
