import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:klhu/appearance_screen.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/content_list_screen.dart';
import 'package:klhu/content_naming.dart';
import 'package:klhu/dialogue.dart';
import 'package:klhu/language.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/platform/video_player.dart';
import 'package:klhu/read_position_store.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/role_store.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/services/content_store.dart';
import 'package:klhu/services/voice_mapping_service.dart';
import 'package:klhu/speech_resolver.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_list_screen.dart';
import 'package:klhu/video_painter.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_record.dart';
import 'package:klhu/video_renderer.dart';
import 'package:klhu/video_review.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

// The page's controls leave this much between themselves and the system's own
// bottom bar, over and above the bar's own inset (2026-10-02, on the OnePlus
// 13: "too much space, can be less ... try 15px" — 15 device pixels on that
// phone is 5, its panel being 3.0 to the logical one).
const double _controlBarGap = 5;

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

  /// What writes the render's per-sentence audio: the read's own engine, which
  /// `ReaderService` already is (D5 — the same voice resolution the read uses).
  /// A caller that hands over a [Reader] which cannot write files still reads
  /// fine; only a render needs this.
  final SentenceSynthesizer synthesizer;

  /// The platform's encoder (`klhu/video_encoder`).
  final VideoEncoder videoEncoder;

  /// The platform's file store (`klhu/video_files`): keeping, sharing, deleting
  /// and asking whether a kept video is still there (012 US3).
  final VideoFileStore videoFileStore;

  /// Where a video is watched (012 US3): the platform's own player, behind its
  /// own view.
  final VideoPlayer videoPlayer;

  /// Where a render's working files live — the app's cache directory, or a
  /// test's own. Each render gets its own subdirectory under it. A cancelled or
  /// failed render's subdirectory goes as soon as it reports; a finished one's
  /// stays until the review is decided, because the video in it is what the
  /// review plays.
  final Directory? videoWorkDir;

  /// The reader's own pictures, chosen from their files (FR-025): the
  /// platform's file dialog, behind its own seam. The real one is the app's; a
  /// test's own keeps the dialog out of the test.
  final PicturePicker picturePicker;

  final Function(String)? onLanguageChanged;
  final dynamic localizationService;

  ReadingView({
    super.key,
    Reader? reader,
    VoiceStore? voiceStore,
    ContentStore? contentStore,
    SentenceSynthesizer? synthesizer,
    VideoEncoder? videoEncoder,
    VideoFileStore? videoFileStore,
    VideoPlayer? videoPlayer,
    this.videoWorkDir,
    PicturePicker? picturePicker,
    this.onLanguageChanged,
    this.localizationService,
  })  : reader = reader ?? ReaderService(),
        voiceStore = voiceStore ?? VoiceStore(),
        contentStore = contentStore ?? ContentStore(),
        // The render speaks through the reader's own engine: `ReaderService` is
        // both, so the app has one engine for the read and for the video.
        synthesizer = synthesizer ?? _synthesizerOf(reader),
        videoEncoder = videoEncoder ?? MethodChannelVideoEncoder(),
        videoFileStore = videoFileStore ?? MethodChannelVideoFileStore(),
        videoPlayer = videoPlayer ?? PlatformVideoPlayer(),
        picturePicker = picturePicker ?? const FilePicturePicker();

  /// The engine a render speaks through — the reader's own when it can write
  /// files, else a fresh service (D5: the read and the render share one voice
  /// resolution).
  static SentenceSynthesizer _synthesizerOf(Reader? reader) {
    if (reader is SentenceSynthesizer) return reader as SentenceSynthesizer;
    return ReaderService();
  }

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

enum _Mode { read, edit, speaking, paused, rendering, review }

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

  /// The reader's dialogue settings for the text on screen (014): its text type,
  /// the names that are not roles, and the voice each role was given. Loaded
  /// with the text (see [_setAnchorKey]) and read on every read; nothing derived
  /// is kept here — the turns, the roles and the assignments are recomputed from
  /// the text and the device each time (research D1/D2/D5).
  RoleSettings _roles = RoleSettings.none;

  /// The version of the text on screen a removal is measured against (FR-007):
  /// a library entry's own `updatedAt`, or [_noVersion] for a shipped pre-set —
  /// the same value whichever way the pre-set was opened, which is what makes a
  /// removal hold across a restart (quickstart row 25).
  DateTime _rolesVersion = _noVersion;

  /// What a text whose `updatedAt` is not the text's version is versioned as: a
  /// shipped pre-set ([_loadEntry], [_loadCatalogFallback]) and a draft. Not
  /// `null`: a removal always carries the version it was made on.
  static final DateTime _noVersion = DateTime.fromMillisecondsSinceEpoch(0);

  /// The dialogue settings store (014 D6), one key for the whole app. Built on
  /// first use, like the video record, so a page that never opens the chooser
  /// never touches it.
  RoleStore? _roleStores;

  RoleStore get _roleStore => _roleStores ??= RoleStore();

  /// The device's voices, all three lists, as the assignment's candidate pool
  /// (FR-014). Fetched per read and per list rather than cached: a voice can be
  /// installed or removed while the app runs, and a stale pool would assign a
  /// voice the engine no longer has.
  Future<List<VoiceEntry>> _installedVoices() async => [
        for (final language in const ['en', 'zh-Hans', 'es'])
          ...await widget.reader.voicesFor(language),
      ];

  /// The render in flight, if any (012 US1). The page owns it for as long as it
  /// runs: while [_mode] is RENDERING it is the only thing on screen (FR-019).
  VideoRenderer? _renderer;

  /// The picture the render last painted — what the page shows while it runs,
  /// because that picture IS the progress (FR-020).
  VideoFrame? _frame;

  /// The line under the picture: which pass is running and how far it has come
  /// (FR-009).
  String _renderProgress = '';

  /// Which render owns the page's callbacks. A Stop or a leave bumps it, so
  /// nothing a stopped render reports afterwards can touch the page again.
  int _renderGen = 0;

  /// Every render writes into its own directory under
  /// [ReadingView.videoWorkDir], and the page removes it once the render
  /// reports — or, for a render that finished, once its review is decided. Two
  /// renders must never share one: a stopped render is still finishing its last
  /// write (and deleting its own files) while a new one may already be running.
  static int _renderDirSeq = 0;

  /// One directory of stored picks per video prompt ([_openVideoPrompt]).
  int _pictureDirSeq = 0;

  /// The picture window's own scroll position, where it sits on screen, and the
  /// repeat that keeps it moving while a picture is held at one of its ends
  /// (FR-032, D21).
  final ScrollController _pictureWindow = ScrollController();
  final GlobalKey _pictureWindowKey = GlobalKey();
  Timer? _windowScroll;
  int? _windowScrollDirection;

  /// How near an end of the picture window counts as "at the end", and how far
  /// one step of its own scroll moves.
  static const double _windowEdge = 36;
  static const double _windowStep = 24;

  /// Scrolls the picture window while a picture is held near either of its ends,
  /// so a picture can be moved to a cell that is not on screen (FR-032, D21) —
  /// the reader's own report from the phone of 2026-09-28: the hold worked, but
  /// "only can move in displayed rows. need to able to move out of the disabled
  /// rows. use auto scroll."
  ///
  /// The step repeats on a timer while the pointer stays in the band, because
  /// holding still at the end *is* how a reader asks for more: a step per pointer
  /// move would stop the window the moment they stopped moving.
  void _autoScrollWindow(Offset pointer) {
    final box =
        _pictureWindowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_pictureWindow.hasClients) return;
    final window = box.localToGlobal(Offset.zero) & box.size;
    final int direction;
    if (pointer.dy < window.top + _windowEdge) {
      direction = -1;
    } else if (pointer.dy > window.bottom - _windowEdge) {
      direction = 1;
    } else {
      _stopWindowScroll();
      return;
    }
    if (_windowScrollDirection == direction) return;
    _stopWindowScroll();
    _windowScrollDirection = direction;
    _windowScroll = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _stepWindow(direction),
    );
    // The first step is immediate: a reader who holds at the end sees the window
    // move rather than waiting for the timer's first beat.
    _stepWindow(direction);
  }

  /// One step of the window's own scroll, never past either end.
  void _stepWindow(int direction) {
    if (!_pictureWindow.hasClients) return;
    final position = _pictureWindow.position;
    final next = (_pictureWindow.offset + direction * _windowStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == _pictureWindow.offset) return;
    _pictureWindow.jumpTo(next);
  }

  /// The hold is over, or away from the window's ends: nothing keeps scrolling.
  void _stopWindowScroll() {
    _windowScroll?.cancel();
    _windowScroll = null;
    _windowScrollDirection = null;
  }

  /// Whether this platform can make, keep and play videos at all (FR-010, D8):
  /// both halves of the platform must answer yes, and the answer is what
  /// decides whether the action is offered. A control that fails when tapped is
  /// the thing this avoids.
  bool _videoAvailable = false;

  /// The render the reader has not decided about yet (FR-021): its working copy
  /// is on screen, nothing is kept, and the page's own controls are not offered.
  VideoReview? _review;

  /// Whether the keep the review is about to make replaces the content's earlier
  /// video (FR-012's amendment, 2026-10-06). The default is the shipped rule —
  /// one kept video, and it is the new one — and the review asks only when there
  /// is an earlier one to replace.
  bool _replaceKeptVideo = true;

  /// The directory the review's working copy lives in — this render's own.
  Directory? _reviewDir;

  /// The videos the content in force has kept (FR-022/FR-033), oldest first —
  /// the newest is the content's own. Its action is the idle page's: open them
  /// as a list, where each one carries its own play, share and delete.
  List<KeptVideo> _keptVideos = const <KeptVideo>[];

  /// Which content the kept-video look belongs to: a slow platform answer for a
  /// text the reader has already left must not land on the new one.
  int _keptGen = 0;

  /// The record, over the platform's file store. Built on first use so a page
  /// that never makes a video never touches the store.
  VideoRecordStore? _records;

  VideoRecordStore get _recordStore =>
      _records ??= VideoRecordStore(files: widget.videoFileStore);

  /// The remembered video format (012 A8), beside the voice, position and
  /// appearance records in the same per-device store.
  final _aspects = VideoAspectStore();

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
    _askVideoAvailability();
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
  ///
  /// Its roles are versioned by [_noVersion] like every other pre-set
  /// ([_loadEntry] does the same for a pre-set opened from the list): its text
  /// ships and cannot change — editing one saves a *new* content — and this path
  /// has no entry of its own to read a version from, so storage must not be
  /// needed to read the page.
  Future<void> _loadCatalogFallback() async {
    final presets = await _store.catalog();
    if (presets.isEmpty || !mounted) return;
    final preset = presets.first;
    final previous = _anchorKey;
    setState(() {
      _content = preset.text;
      _loaded = null;
      _anchor = null;
      _setAnchorKey(preset.id);
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

  /// The height of the actions' own row, in portrait (011 FR-026).
  static const double _actionRowHeight = 48;

  /// Whether the page's actions need a row of their own: a portrait window is
  /// too narrow to hold them beside the language. Measured on the reader's
  /// phone, 2026-10-06: the window is 360 dp wide and the bar's own controls
  /// need 488 dp, so the last actions were squeezed and pushed off the edge.
  bool get _actionsOnTheirOwnRow =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  /// The page's own actions, defined once and placed either beside the language
  /// (landscape, where the row has the room) or on their own row under the
  /// brand and the language (portrait, where it does not) — one list, so the
  /// two arrangements cannot drift apart.
  ///
  /// The buttons are Material's own size (48 dp) in both arrangements: the
  /// portrait bar carries six actions now that play, share and delete are one
  /// `Videos` action (the 2026-10-06 amendment, FR-033), and six 48 dp targets
  /// are 288 dp against the 360 dp the portrait row offers. The 40 dp this bar
  /// was squeezed to when it carried eight — 011's own record of that
  /// compromise — goes with the three actions that paid for it.
  List<Widget> _pageActions() {
    final l10n = AppLocalizations.of(context);
    return [
      IconButton(
        icon: const Icon(Icons.format_size),
        tooltip: l10n?.appearanceButton ?? 'Appearance',
        // Idle-only (FR-014): changing the text's look mid-read
        // would fight the page's own tracking, which is measured on
        // that text.
        onPressed: _isSpeakingOrPaused ? null : _openAppearance,
      ),
      IconButton(
        icon: const Icon(Icons.folder_open),
        tooltip: l10n?.contentsButton ?? 'Contents',
        onPressed: () => _openContentList(),
      ),
      // The text type (014 FR-022): offered in 标准 too, because the
      // chooser is where a dialogue is turned on; allowed mid-read,
      // since switching changes nothing but the setting (FR-020).
      IconButton(
        icon: const Icon(Icons.forum_outlined),
        tooltip: l10n?.textTypeButton ?? 'Text type',
        onPressed: _openTextType,
      ),
      IconButton(
        icon: const Icon(Icons.record_voice_over),
        tooltip: l10n?.voiceButton ?? 'Voice',
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
      // The video action, from the idle page only (FR-010): a read
      // playing or parked owns the page, and a platform that cannot
      // make videos is never offered the action at all.
      if (_canOfferVideo)
        IconButton(
          icon: const Icon(Icons.movie_outlined),
          tooltip: l10n?.videoButton ?? 'Video',
            onPressed: _openVideoPrompt,
        ),
      // The content's own videos, once it has any (FR-022/FR-033): one action
      // that opens them as a list, where each video carries its own play, share
      // and delete — and where the last row is what the old `Play video` opened.
      if (_keptVideos.isNotEmpty && _mode == _Mode.read)
        IconButton(
          icon: const Icon(Icons.video_library_outlined),
          tooltip: l10n?.videoListTitle ?? 'Videos',
          onPressed: _openVideoList,
        ),
    ];
  }

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
    // Nothing keeps scrolling a window that is going away (FR-032).
    _stopWindowScroll();
    _pictureWindow.dispose();
    // An abandoned render leaves nothing behind (FR-009): the page going away
    // is the reader leaving it, and the renderer cleans up what it wrote as
    // soon as it notices.
    _renderer?.cancel();
    // An undecided review keeps nothing (FR-021): leaving it throws the working
    // copy away and releases the player.
    _leaveReview();
    _disposeUndo();
    _editController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The review is being left without a decision: nothing is kept, the player is
  /// released, and the render's own files go with it (FR-021; player contract
  /// § Rules 4). Called by the page going away and by a pop.
  void _leaveReview() {
    final review = _review;
    _review = null;
    if (review == null) return;
    unawaited(review.throwAway());
    unawaited(widget.videoPlayer.stop());
    unawaited(_disposeReviewDir());
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

  /// The edit toolbar's Format press (FR-024, SC-011): the reader's text with
  /// every tag at the head of its own paragraph, assigned to the controller in
  /// ONE assignment — which is what makes the whole press a single undo entry,
  /// the way [_enterEdit] seeds the stack.
  ///
  /// The transform is `lib/dialogue.dart`'s, so the button does nothing but
  /// apply a pure function's answer; the text is saved by 008's existing path
  /// (Save or Done) and its refusals stay 008's own. Nothing is formatted behind
  /// the reader's back: this runs when the button is pressed and at no other
  /// time (A9, FR-020).
  void _formatDialogue() {
    final controller = _editController;
    if (controller == null) return;
    final formatted = formatForDialogue(controller.text);
    if (formatted == controller.text) return;
    controller.value = TextEditingValue(
      text: formatted,
      // The caret follows the text it was at the end of, as in `_enterEdit`.
      selection: TextSelection.collapsed(offset: formatted.length),
    );
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
        // A pre-set is versioned like the fallback versions it (FR-007): the
        // seeded entry's `updatedAt` is not the text's version — a pre-set's
        // text cannot change, and editing one saves a new content with its own
        // id — so a removal made after opening it either way is in force either
        // way.
        _setAnchorKey(entry.id,
            version: entry.isPreset ? null : entry.updatedAt);
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
      _setAnchorKey(null);
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
        _setAnchorKey(saved.id, version: saved.updatedAt);
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

  /// Shared read path (002 US1): resolve the range into speeches — each
  /// paragraph in its own language's picked voice, in order. A sentence tap
  /// inherits its enclosing paragraph's language (spec FR-001).
  ///
  /// The mode is the content's own (014): 标准 resolves exactly as it always
  /// has, one call, no voice list; 多人对话 resolves one speech per turn, in the
  /// turn's role's voice (FR-019 — the same list the video is built from).
  /// With [track], the sentence being spoken is painted (011 FR-020) and kept
  /// on screen, and the highlight clears at end/Stop.
  Future<void> _readRange(int start, int end, {bool track = false}) async {
    final speeches = await resolveSpeeches(
      content: _content,
      start: start,
      end: end,
      mode: _roles.isDialogue ? ReadingMode.dialogue : ReadingMode.standard,
      removed: _roles.removedFor(_rolesVersion),
      picks: _roles.voices,
      loadVoice: widget.voiceStore.loadVoice,
      // Only 多人对话 asks for the device's voices, and only because a role with
      // no pick falls back to an assignment over them (FR-014). 标准's path is
      // today's and never calls this (SC-005).
      loadInstalled: _installedVoices,
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

  // -------------------------------------------------------------------
  // The render (012 US1) and the review (012 US3)
  // -------------------------------------------------------------------

  bool get _isRendering => _mode == _Mode.rendering;

  bool get _isReview => _mode == _Mode.review;

  /// Whether the video action is offered at all (FR-010): from the idle page, on
  /// a platform that can make, keep and play videos, and for a text the library
  /// can own a video for.
  bool get _canOfferVideo =>
      _mode == _Mode.read && _videoAvailable && _anchorKey != null;

  /// FR-010/D8: the platform's two answers about video, asked once. Until both
  /// come back yes the action is not offered, so a device that cannot do this
  /// never shows a control that fails when tapped.
  Future<void> _askVideoAvailability() async {
    var canRender = false;
    var canKeep = false;
    try {
      canRender = await widget.videoEncoder.isAvailable();
    } catch (e) {
      debugPrint('klhu video encoder availability failed: $e');
    }
    try {
      canKeep = await widget.videoFileStore.isAvailable();
    } catch (e) {
      debugPrint('klhu video file store availability failed: $e');
    }
    if (!mounted) return;
    setState(() => _videoAvailable = canRender && canKeep);
  }

  /// What the content in force has kept (FR-022), asked whenever that content
  /// changes and again when the list comes back. A video whose file has gone is
  /// reported by name and forgotten rather than offered, and the content's other
  /// videos are left alone.
  Future<void> _refreshKeptVideo() async {
    final gen = ++_keptGen;
    final key = _anchorKey;
    if (key == null) {
      if (mounted) setState(() => _keptVideos = const <KeptVideo>[]);
      return;
    }
    late final VideoLookup lookup;
    try {
      lookup = await _recordStore.recordFor(key);
    } catch (e) {
      debugPrint('klhu reading the kept videos failed: $e');
      return;
    }
    if (!mounted || gen != _keptGen) return;
    setState(() => _keptVideos = lookup.videos);
    // Each video whose file has gone is reported by its own name, and that read
    // forgot it: what the page offers is what plays (FR-022).
    final l10n = AppLocalizations.of(context);
    for (final video in lookup.gone) {
      _showMessage(
        l10n?.videoGoneMessage(video.name) ?? '${video.name} is gone',
      );
    }
  }

  /// The text whose video-ownership is in force (FR-011). Setting it asks what
  /// that text has kept, so the idle page offers the right actions for it.
  void _setAnchorKey(String? key, {DateTime? version}) {
    _anchorKey = key;
    _rolesVersion = version ?? _noVersion;
    _refreshKeptVideo();
    unawaited(_loadRoles());
  }

  /// Read the content's dialogue settings (014 D6). A text with none — and a
  /// store that cannot be read — is 标准, exactly as today: this feature's
  /// failure mode is "the reader's dialogue settings are gone", never "the text
  /// will not read" (FR-002, FR-021).
  Future<void> _loadRoles() async {
    final key = _anchorKey;
    if (key == null) {
      if (mounted) setState(() => _roles = RoleSettings.none);
      return;
    }
    RoleSettings settings;
    try {
      settings = await _roleStore.load(key);
    } catch (e) {
      debugPrint('klhu role settings unreadable: $e');
      settings = RoleSettings.none;
    }
    // A slow answer for a text the reader has already left must not land on the
    // new one (the rule the kept-video look follows too).
    if (!mounted || key != _anchorKey) return;
    setState(() => _roles = settings);
  }

  /// Record the text type (FR-001) and read it back: the next read resolves
  /// through the new mode, and nothing else about the page moves — not the text,
  /// not its undo stack, not the position, not the highlight (FR-020). Switching
  /// mid-read is the reader's own action and is allowed: the read in flight keeps
  /// the speeches it started with.
  Future<void> _setDialogue(bool dialogue) async {
    final key = _anchorKey;
    setState(() {
      _roles = RoleSettings(
        isDialogue: dialogue,
        removed: _roles.removed,
        voices: _roles.voices,
      );
    });
    if (key == null) return;
    try {
      await _roleStore.setDialogue(key, dialogue: dialogue);
    } catch (e) {
      debugPrint('klhu role settings not saved: $e');
    }
  }

  /// The text type and the roles, from the page (FR-022, FR-006): one entry,
  /// offered in 标准 too — the chooser is where a dialogue is turned on in the
  /// first place. The switch is applied as the reader taps it (it changes nothing
  /// but the setting); in 多人对话 the chooser goes on to show the roles the text
  /// proposes, each with the voice it reads with and each opening the shipped
  /// picker for itself (FR-012).
  Future<void> _openTextType() async {
    final l10n = AppLocalizations.of(context);
    // Recomputed on open and after every change: the list must show what a read
    // would use, and that answer comes from the device's own voices (FR-016).
    var turns = turnsOf(_content, removed: _roles.removedFor(_rolesVersion));
    var roles = rolesOf(turns);
    var voices = await resolveRoleVoices(
      turns: turns,
      picks: _roles.voices,
      loadVoice: widget.voiceStore.loadVoice,
      loadInstalled: _installedVoices,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          Future<void> refresh() async {
            turns = turnsOf(_content, removed: _roles.removedFor(_rolesVersion));
            roles = rolesOf(turns);
            voices = await resolveRoleVoices(
              turns: turns,
              picks: _roles.voices,
              loadVoice: widget.voiceStore.loadVoice,
              loadInstalled: _installedVoices,
            );
            if (mounted) setDialog(() {});
          }

          return AlertDialog(
            scrollable: true,
            title: Text(l10n?.textTypeTitle ?? 'Text type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final dialogue in const [false, true])
                      ChoiceChip(
                        label: Text(dialogue
                            ? l10n?.textTypeDialogue ?? 'Dialogue'
                            : l10n?.textTypeStandard ?? 'Standard'),
                        selected: _roles.isDialogue == dialogue,
                        onSelected: (_) async {
                          await _setDialogue(dialogue);
                          await refresh();
                        },
                      ),
                  ],
                ),
                if (_roles.isDialogue) ...[
                  const Divider(height: 24),
                  Text(
                    l10n?.textTypeDialogueHint ??
                        'Each paragraph is a turn; a role tag at the head of a '
                            'paragraph names its speaker.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (roles.isEmpty)
                    Text(l10n?.roleListEmptyMessage ??
                        'No roles yet. A paragraph that starts with a role tag '
                            'belongs to that role.')
                  else
                    for (final role in roles)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(role.name),
                        subtitle: Text(
                          _roleSubtitle(role, voices[role.name], l10n),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: l10n?.roleRemoveButton ?? 'Remove this role',
                          onPressed: () async {
                            await _removeRole(role.name);
                            await refresh();
                          },
                        ),
                        onTap: () async {
                          await _openRoleVoice(role.name);
                          await refresh();
                        },
                      ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.doneButton ?? 'Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The shipped picker, opened for one role (D7): titled with the role's name,
  /// offering the *automatic* row, its pick read from and written to the role
  /// store — never the language's (FR-013).
  Future<void> _openRoleVoice(String role) async {
    final l10n = AppLocalizations.of(context);
    final key = _anchorKey;
    final turns = turnsOf(_content, removed: _roles.removedFor(_rolesVersion));
    final first = turns.firstWhere(
      (turn) => turn.role == role,
      orElse: () => turns.first,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VoicePickerScreen(
          reader: widget.reader,
          store: widget.voiceStore,
          // The picker lists one language's voices: the role's own, and its
          // segment control is there for a role that reads in another.
          language: detectLanguage(first.text),
          title: l10n?.rolePickerTitle(role) ?? role,
          clearable: true,
          initialSelection: _roles.pickFor(role),
          onPick: (choice) async {
            if (key == null) return;
            await _roleStore.setVoice(key, role: role, voice: choice);
            if (!mounted) return;
            setState(() => _roles = _roles.withVoice(role, choice));
          },
        ),
      ),
    );
  }

  /// A role row's remove action (FR-006, FR-007): the name stops being a role
  /// from this version of the text on, and every paragraph the text tags with it
  /// reads as narration instead. Confirmed in the shipped dialog shape
  /// (`_confirmDelete`, `_confirmDiscard`): it is the reader's decision, it
  /// changes how the text sounds, and it is not undoable with a second tap.
  ///
  /// Nothing 008 owns is touched: not the text, not its undo history, not the
  /// stored position (FR-020, ripple 3). A read in flight is not stopped either —
  /// the change is the reader's decision, and it applies from the next read.
  Future<void> _removeRole(String name) async {
    final l10n = AppLocalizations.of(context);
    final key = _anchorKey;
    if (key == null) return;
    // The version the settings were read against is the one the removal is made
    // against — the same value `removedFor` compares, so a removal the store
    // accepts is a removal in force (FR-007).
    final version = _rolesVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.roleRemoveConfirmTitle ?? 'Remove this role?'),
        content: Text(
          l10n?.roleRemoveConfirmMessage ??
              'Its paragraphs will be read as narration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.roleRemoveButton ?? 'Remove this role'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // The content's own version is what the removal is made against: saving the
    // text (008) moves it, which expires this removal and proposes the name
    // again (FR-007, research D4).
    await _roleStore.removeRole(key, name: name, at: version);
    if (!mounted) return;
    setState(() => _roles = _roles.withRemoval(name, version));
  }

  /// `2 turns · 普通话 CCC` — the turns the text gives the role and the voice it
  /// reads with, named the way the picker names voices (FR-016). No age is shown
  /// or modelled anywhere (FR-017).
  String _roleSubtitle(Role role, VoiceChoice? voice, AppLocalizations? l10n) {
    final count = l10n?.roleTurnCount(role.turnCount) ?? '${role.turnCount}';
    if (voice == null) {
      return '$count · ${l10n?.roleVoiceAutomatic ?? 'Automatic'}';
    }
    final label = l10n == null
        ? voice.name
        : VoiceMappingService().displayName(
            VoiceEntry(name: voice.name, locale: voice.locale),
            l10n,
            voiceListLanguage: detectLanguage(role.turns.first.text),
          );
    return '$count · $label';
  }

  /// Keeps what the review is showing (FR-011/FR-012): the working copy is
  /// promoted into the library, the content remembers it, and the reader is told
  /// the video was saved. Nothing is kept until this happens.
  Future<void> _keepReview() async {
    final review = _review;
    if (review == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await review.keep(replace: _replaceKeptVideo);
    } catch (e) {
      debugPrint('klhu keeping the video failed: $e');
      if (!mounted) return;
      _showMessage(l10n?.storageErrorMessage ??
          'Could not save. Check storage space and try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _review = null;
      _mode = _Mode.read;
    });
    // The record is read again rather than assumed: whether that keep replaced
    // the content's last entry or appended beside it is the record's own answer
    // (FR-012's amendment, 2026-10-06).
    await _refreshKeptVideo();
    await _disposeReviewDir();
    if (!mounted) return;
    _showMessage(l10n?.videoSavedMessage ?? 'Video saved');
  }

  /// Throws the render away (FR-021): the working copy goes and nothing was ever
  /// written into the library.
  Future<void> _discardReview() async {
    final review = _review;
    if (review == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await review.throwAway();
    } catch (e) {
      debugPrint('klhu discarding the video failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _review = null;
      _mode = _Mode.read;
    });
    await _disposeReviewDir();
    if (!mounted) return;
    _showMessage(l10n?.videoNotSavedMessage ?? 'Video not saved');
  }

  /// Shares what the review is showing (FR-023). Sharing is not deciding: the
  /// review stays up, and nothing is kept.
  Future<void> _shareReview() async {
    final review = _review;
    if (review == null) return;
    try {
      await review.share();
    } catch (e) {
      debugPrint('klhu sharing the video failed: $e');
    }
  }

  /// The review is decided, so its directory goes: it held this render's own
  /// files and nothing else.
  Future<void> _disposeReviewDir() async {
    final dir = _reviewDir;
    _reviewDir = null;
    if (dir != null) await _removeWorkingDir(dir);
  }

  /// FR-022/FR-033: the content's videos as a list the reader picks from. What
  /// the page's own Play action used to do — open the video kept most recently —
  /// is the list's last row's tap; a delete inside the list is what can leave
  /// this content with nothing, so the record is read again on the way back and
  /// the page's `Videos` action goes when the last one does.
  Future<void> _openVideoList() async {
    final key = _anchorKey;
    if (key == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoListScreen(
          contentKey: key,
          records: _recordStore,
          files: widget.videoFileStore,
          player: widget.videoPlayer,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshKeptVideo();
  }


  /// The review, while it is up: the render's own picture, and the three
  /// decisions (FR-021, FR-023).
  Widget _buildReviewArea(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final review = _review;
    if (review == null) return const SizedBox.shrink();
    return Column(
      children: [
        Expanded(
          child: Center(
            child: widget.videoPlayer.view(context, source: review.workingPath),
          ),
        ),
        const SizedBox(height: 16),
        // What a second keep does, put to the reader (FR-012's amendment,
        // 2026-10-06): replacing is the default and the shipped rule, and the
        // question is asked only when the content already has a video to
        // replace. Off leaves that earlier file in the library beside this one.
        if (_keptVideos.isNotEmpty)
          SwitchListTile(
            value: _replaceKeptVideo,
            onChanged: (value) => setState(() => _replaceKeptVideo = value),
            title: Text(
              l10n?.videoReplaceLabel ?? 'Replace the existing video',
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: _discardReview,
              child: Text(l10n?.discardButton ?? 'Discard'),
            ),
            TextButton.icon(
              onPressed: _shareReview,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n?.videoShareButton ?? 'Share'),
            ),
            FilledButton.icon(
              onPressed: _keepReview,
              icon: const Icon(Icons.save_alt),
              label: Text(l10n?.saveButton ?? 'Save'),
            ),
          ],
        ),
      ],
    );
  }

  /// The video action (FR-001): the format is asked for first, the prompt
  /// opens on the remembered choice (A8), and the reader's own pictures are
  /// chosen beside it (FR-025) — named before the render can start, and
  /// re-choosable until the reader's own confirm.
  Future<void> _openVideoPrompt() async {
    final l10n = AppLocalizations.of(context);
    final remembered = await _aspects.load();
    if (!mounted) return;
    // Where this prompt's pictures are stored (FR-025, D18): a directory of the
    // app's own, holding a file per picture, so the page shows files and the
    // render copies files rather than the app holding a phone photo's megabytes
    // in memory for as long as the prompt is open.
    final base = widget.videoWorkDir ?? await getTemporaryDirectory();
    final picturesDir = Directory(
      '${base.path}${Platform.pathSeparator}picks_${_pictureDirSeq++}',
    );
    await picturesDir.create(recursive: true);
    if (!mounted) return;
    try {
      final answer = await _askVideoFormat(
        l10n: l10n,
        remembered: remembered,
        picturesDir: picturesDir,
      );
      if (answer == null || !mounted) return;
      await _aspects.save(answer.aspect);
      await _startRender(answer.aspect, pictures: answer.pictures);
    } finally {
      // The render copies the stored pictures into its own directory as it works
      // and takes the copies with it (FR-009): once the render is over — however
      // it ended — what the app stored for the prompt is nobody's (FR-025).
      await discardPictures(picturesDir);
    }
  }

  /// Asks the reader for the video's format and its pictures (FR-001/FR-007/
  /// FR-025) and answers what they confirmed, or null when they cancelled.
  ///
  /// The format is asked for first, on the remembered choice (A8); the pictures
  /// are chosen beside it, are shown as the pictures they are, can be taken back
  /// and can be moved (FR-030/FR-032), and are **stored** as they are chosen
  /// (D18) — in [picturesDir], which the caller owns and removes.
  ///
  /// A choice may hold more pictures than the video has sentences — the reader's
  /// own answer from the phone of 2026-09-28, after watching for one: "超限提示、no
  /// need. not show." So the page says nothing about it and offers Start either
  /// way: each picture draws a sentence's own run of frames (FR-026), so the
  /// pictures past the last sentence are simply not drawn — the same answer the
  /// schedule has always given a picture that found no sentence.
  Future<({VideoAspect aspect, List<HeldPicture> pictures})?> _askVideoFormat({
    required AppLocalizations? l10n,
    required VideoAspect remembered,
    required Directory picturesDir,
  }) async {
    var chosen = remembered;
    // The pictures this prompt holds, stored at the pick: nothing here keeps them
    // once the render is done (FR-025), and nothing caps how many the reader may
    // keep — every picture chosen is kept, in the order chosen, and one they no
    // longer want is taken back by its own remove (2026-09-28: "remove max 20
    // images limit. keep all 30 images for now. user can delete images.").
    var held = const <HeldPicture>[];
    String? pickFailure;
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          // The prompt's own content grows with the reader's pictures and can
          // carry the message that says a choice is too large (FR-026): on a
          // short screen the actions must stay reachable, so the content scrolls
          // and the actions stay pinned.
          scrollable: true,
          title: Text(l10n?.videoAspectTitle ?? 'Video format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final aspect in VideoAspect.all)
                ChoiceChip(
                  label: Text(aspect.isVertical
                      ? l10n?.videoAspectVertical ?? '9:16 vertical (Shorts)'
                      : l10n?.videoAspectLandscape ??
                          '16:9 landscape 1080p'),
                  selected: chosen.name == aspect.name,
                  onSelected: (_) => setDialog(() => chosen = aspect),
                ),
              const Divider(height: 24),
              // What is chosen, said here before the render starts (FR-025) —
              // the sum of every pick, since choosing again adds (FR-025).
              Text(l10n?.videoPicturesChosen(held.length) ??
                  '${held.length} pictures chosen'),
              if (pickFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    pickFailure!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              // The chosen pictures themselves, each with its own remove and its
              // own place the reader can change (FR-030, FR-032): the reader
              // sees what the render will use — and in which order — before it
              // starts.
              if (held.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // A small window that scrolls (FR-030): two rows of
                  // thumbnails, so thirty pictures do not make the prompt
                  // thirty rows tall — the reader's own shape of 2026-09-28,
                  // "use scroll. small show window, scroll to show others".
                  child: ConstrainedBox(
                    key: _pictureWindowKey,
                    constraints:
                        const BoxConstraints(maxHeight: pictureWindowHeight),
                    child: SingleChildScrollView(
                      // A stable name for the window, so its own scroll can be
                      // read and driven in the page's tests (FR-030/FR-032).
                      key: const ValueKey('video picture window'),
                      controller: _pictureWindow,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < held.length; i++)
                            MovableThumbnail(
                              picture: held[i],
                              index: i,
                              removeLabel: l10n?.videoPicturesRemove ??
                                  'Remove this picture',
                              onRemove: () => setDialog(() {
                                held = [...held]..removeAt(i);
                                pickFailure = null;
                              }),
                              onMoveTo: (from) => setDialog(() {
                                held = movePicture(held, from, i);
                              }),
                              // A hold near either end of the window scrolls it,
                              // so a picture can be moved to a cell that is not
                              // on screen (FR-032, D21).
                              onDragUpdate: _autoScrollWindow,
                              onDragEnd: _stopWindowScroll,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n?.videoPicturesReorder ??
                        'Hold a picture and move it left or right to change '
                            'the order.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () => _choosePictures(
                  l10n: l10n,
                  picturesDir: picturesDir,
                  held: held,
                  onChosen: (next) => setDialog(() {
                    held = next;
                    pickFailure = null;
                  }),
                  onFailure: (message) =>
                      setDialog(() => pickFailure = message),
                ),
                icon: const Icon(Icons.image_outlined),
                label: Text(held.isEmpty
                    ? l10n?.videoPicturesButton ?? 'Choose pictures'
                    : l10n?.videoPicturesChooseMore ?? 'Choose more'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n?.cancelButton ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n?.videoStartButton ?? 'Start'),
            ),
          ],
        ),
      ),
    );
    return start == true ? (aspect: chosen, pictures: held) : null;
  }

  /// Asks the platform for the reader's pictures (FR-025) and answers with the
  /// choice the render will use.
  ///
  /// A dialog the reader cancelled changes nothing: what was chosen stands, so
  /// "choose again" is always a repick and never a quiet reset. A picker that
  /// failed says so with the app's own message and leaves the choice as it was —
  /// the render is still the reader's to confirm.
  ///
  /// The picks are **stored here**, once each, while the picker's own read grant
  /// is alive (D15/D18) — that is what lets the page show them (FR-030) and why
  /// the render never reads a pick again. What comes back is added to what the
  /// reader already had, in the order chosen (FR-025): there is no cap, so a pick
  /// is never refused and never trimmed.
  Future<void> _choosePictures({
    required AppLocalizations? l10n,
    required Directory picturesDir,
    required List<HeldPicture> held,
    required void Function(List<HeldPicture> held) onChosen,
    required void Function(String) onFailure,
  }) async {
    try {
      final chosen = await widget.picturePicker.pick();
      if (chosen.isEmpty) return;
      onChosen(mergePicks(
        held,
        await storePicks(picks: chosen, dir: picturesDir),
      ));
    } on Exception {
      onFailure(
        l10n?.videoPicturesFailed ?? 'Could not open your pictures. Try again.',
      );
    }
  }

  /// Runs one render to the end, in its own working directory, and back to
  /// idle.
  ///
  /// Nothing of the content's own state moves (FR-009/FR-018): the text, the
  /// position in force and the appearance are read, never written, and a
  /// cancelled or failed render leaves them exactly as they were.
  Future<void> _startRender(
    VideoAspect aspect, {
    List<HeldPicture> pictures = const [],
  }) async {
    final l10n = AppLocalizations.of(context);
    if (_content.trim().isEmpty) {
      // FR-015: refused with the app's existing message, and no render at all.
      setState(() {
        _hint = l10n?.nothingToReadMessage ?? 'Nothing left to read from here';
        _error = null;
      });
      return;
    }
    // The page's own start point, read before anything else touches the state
    // (FR-004): the sentence in force, else the content's first.
    final from = _anchor ?? 0;
    final title = _loaded?.name ?? contentNameFrom(_content);
    // The text this render belongs to (FR-011). The action is only offered for a
    // text the library can own a video for (`_canOfferVideo`), so the key is in
    // force here — and it is read now, because a review belongs to the text the
    // render was started from.
    final contentKey = _anchorKey!;
    final gen = ++_renderGen;
    // Whether this render's directory survives the call: a finished render's
    // does, because the review plays the working copy inside it (FR-021).
    var keepDir = false;
    final base = widget.videoWorkDir ?? await getTemporaryDirectory();
    final workDir = Directory('${base.path}/render_${_renderDirSeq++}');
    await workDir.create(recursive: true);
    if (!mounted) return;

    final renderer = VideoRenderer(
      synthesizer: widget.synthesizer,
      encoder: widget.videoEncoder,
      workDir: workDir,
      aspect: aspect,
      // The reader's own look reaches the frame (FR-014): the page's one style
      // seam and the app's background.
      readingStyle: _contentTextStyle(context),
      background: Theme.of(context).scaffoldBackgroundColor,
      // The reader's own pictures for this render (FR-025). They are copied into
      // the render's working directory before the first frame is painted — which
      // is the only place that can happen, because where a picture lands depends
      // on the sentences the render's own synth pass finds (FR-026).
      pictures: pictures,
    );
    setState(() {
      _mode = _Mode.rendering;
      _renderer = renderer;
      _frame = null;
      _renderProgress = l10n?.videoRenderingLabel ?? 'Rendering video…';
      _hint = null;
      _error = null;
    });

    try {
      final result = await renderer.render(
        content: _content,
        position: from,
        loadVoice: widget.voiceStore.loadVoice,
        // The video reads what the page reads (014 FR-018): the same content
        // type, the same removed names, the same per-role picks, over the same
        // device voice list — one resolver, two consumers.
        mode: _roles.isDialogue ? ReadingMode.dialogue : ReadingMode.standard,
        removed: _roles.removedFor(_rolesVersion),
        picks: _roles.voices,
        loadInstalled: _installedVoices,
        onProgress: (progress) => _reportRenderProgress(gen, progress),
        onFrame: (frame) {
          if (!mounted || gen != _renderGen) return;
          // Which picture is on screen, for the device row that pairs the page
          // with the file's own frames (quickstart 32, FR-020).
          debugPrint('klhu render preview frame=${frame.slot.startFrame} '
              'kind=${frame.slot.kind.name}');
          setState(() => _frame = frame);
        },
      );
      // A Stop or a leave already took the page back: what this render would
      // report is stale, and its files are its own to finish deleting.
      if (gen != _renderGen || !mounted) return;
      if (result.cancelled) {
        setState(() {
          _mode = _Mode.read;
          _renderer = null;
          _frame = null;
          _renderProgress = '';
        });
        return;
      }
      // The render finished, so the reader gets to decide about it (FR-021): the
      // working copy becomes the review, and nothing is kept until they say so.
      _reportRenderDone(result);
      keepDir = true;
      setState(() {
        _mode = _Mode.review;
        _renderer = null;
        _frame = null;
        _renderProgress = '';
        _reviewDir = workDir;
        // A new review asks again: the default answer replaces (FR-012).
        _replaceKeptVideo = true;
        _review = VideoReview(
          workingPath: result.path,
          contentKey: contentKey,
          // The library entry this render's file will take if it is kept
          // (FR-012), named for the **content** (FR-011). The file the render
          // wrote is named for the working directory's own file, which is the
          // same for every content — and the gallery is where the reader comes
          // back to this, so the name has to be the one they know it by. The
          // extension is the record's too: the app is what says this is an mp4.
          displayName: '$title.mp4',
          files: widget.videoFileStore,
          records: _recordStore,
        );
      });
    } on VideoRenderException catch (e) {
      // The reader is shown one message for three different failures, so the
      // failure itself has to be on the wire: on a device whose encoder or
      // engine refuses, this line is the only record of WHICH half refused and
      // in whose words. (A phone's render failing with "check storage space"
      // while the disk was 152 GB free is what put this line here.)
      debugPrint('klhu render failed kind=${e.kind.name} message=${e.message}');
      if (!mounted || gen != _renderGen) return;
      setState(() {
        _mode = _Mode.read;
        _renderer = null;
        _frame = null;
        _renderProgress = '';
        _error = switch (e.kind) {
          VideoFailureKind.nothingToRead =>
            l10n?.nothingToReadMessage ?? 'Nothing left to read from here',
          _ => l10n?.videoRenderFailedMessage ??
              'Could not make the video. Check storage space and try again.',
        };
      });
    } finally {
      // This render's own working files go with it — unless it finished, in
      // which case the directory holds the working copy the review is playing
      // and the review's decision is what cleans it up (FR-021).
      if (!keepDir) await _removeWorkingDir(workDir);
    }
  }

  /// FR-009's progress. Pass 1 is counted in sentences, which is a number the
  /// reader can follow; pass 2's progress is the picture itself (FR-020) and
  /// has no bar beside it.
  void _reportRenderProgress(int gen, VideoRenderProgress progress) {
    if (!mounted || gen != _renderGen) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _renderProgress = progress.pass == VideoRenderPass.synthesising
          ? l10n?.videoProgressLabel(progress.done, progress.total) ??
              'Rendering video'
          : l10n?.videoRenderingLabel ?? 'Rendering video…';
    });
  }

  /// SC-001: a finished render says which file it made and how long it is, plus
  /// the walker's own evidence line.
  void _reportRenderDone(VideoRenderResult result) {
    final name = result.path.split('/').last;
    final message = AppLocalizations.of(context)
            ?.videoDoneMessage(name, (result.durationMs / 1000).round()) ??
        'Video made';
    debugPrint('klhu render done: ${result.path} ${result.durationMs}ms '
        '${result.sizeBytes}B frames=${result.totalFrames}');
    // What the reader is told, in the reader's own words (SC-001). The message is
    // a SnackBar that lives a few seconds, so a device row that tries to read it
    // *off the page* is racing its lifetime — this line is what such a row can
    // read without a race, exactly as it reads every other wait in this feature.
    debugPrint('klhu render told: $message');
    _showMessage(message);
  }

  /// FR-019's confirmation, asked by Stop and by leaving. Dismissing it changes
  /// nothing at all: the render is neither paused nor stopped, and its picture
  /// keeps advancing while the box is up.
  Future<bool?> _confirmStop() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.videoStopConfirmTitle ?? 'Stop making the video?'),
        content: Text(
            l10n?.videoStopConfirmMessage ?? 'The video will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancelButton ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.stopButton ?? 'Stop'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopFromToolbar() async {
    if (await _confirmStop() == true && mounted) await _stopRender();
  }

  /// Leaving a render asks the same way Stop does (FR-019).
  Future<void> _leaveDuringRender() async {
    if (await _confirmStop() != true || !mounted) return;
    await _stopRender();
    if (mounted) Navigator.of(context).pop();
  }

  /// Stop the render and take the page back to idle at once (FR-019). The
  /// renderer finishes the call already in flight and then deletes everything
  /// it wrote (FR-009); [_renderGen] is what keeps its own report from touching
  /// a page that has already moved on.
  Future<void> _stopRender() async {
    _renderer?.cancel();
    _renderGen++;
    setState(() {
      _mode = _Mode.read;
      _renderer = null;
      _frame = null;
      _renderProgress = '';
    });
  }

  /// Best effort: the app's cache directory is the backstop, and a directory
  /// that will not go must not become an error on the page.
  Future<void> _removeWorkingDir(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('klhu render working directory not removed: $e');
    }
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

  /// The render's own picture and its progress (FR-009/FR-020). The picture IS
  /// the progress — there is no bar beside it: pass 1 is counted in sentences,
  /// and once the first frame is painted the picture carries the rest.
  ///
  /// The picture is announced as a picture with the pass in force rather than
  /// left as an unlabelled image, so TalkBack says what is being written.
  Widget _buildRenderArea(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final frame = _frame;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: frame == null
                ? const SizedBox.shrink()
                : Semantics(
                    label: l10n?.videoPreviewLabel ?? 'Video preview',
                    value: _renderProgress,
                    image: true,
                    child: RawImage(image: frame.image, fit: BoxFit.contain),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_renderProgress),
        ),
      ],
    );
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
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // A render owns the page (FR-019): leaving asks first, exactly as Stop
      // does, and the render is abandoned on the reader's word only.
      canPop: !_isRendering,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Leaving a review decides nothing about it (FR-021).
          _leaveReview();
          return;
        }
        _leaveDuringRender();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n?.appTitle ?? 'klhu Read Aloud'),
          // A render leaves the page with nothing but the render's own picture
          // and Stop (FR-019): the app bar's actions are not offered at all.
          // A render and a review both leave the page with nothing but their own
          // content (FR-019/FR-021): the app bar's actions are not offered at
          // all.
          actions: (_isRendering || _isReview)
              ? const <Widget>[]
              : <Widget>[
                  // Language dropdown
                  if (widget.localizationService != null)
                    _buildLanguageDropdown(context),
                  // Portrait gives the actions a row of their own, under the
                  // brand and the language (011 FR-026). Measured on the
                  // reader's phone (360 dp wide, 2026-10-06): the language takes
                  // 104 dp and the six actions beside it need 288 dp more, so
                  // Play video was squeezed to 16 dp and Share and Delete video
                  // were pushed off the edge entirely. Landscape has the room
                  // (792 dp) and keeps them on this row.
                  if (!_actionsOnTheirOwnRow) ..._pageActions(),
                ],
          bottom: (_actionsOnTheirOwnRow && !_isRendering && !_isReview)
              // The actions' own row, part of the app bar so the text below it
              // keeps the body's own layout (the top is the bar's business).
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(_actionRowHeight),
                  child: SizedBox(
                    height: _actionRowHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _pageActions(),
                    ),
                  ),
                )
              : null,
        ),
        // The page's controls sit on the bottom edge, and on a device that
        // draws edge-to-edge the system's own bar is drawn over that edge
        // (Android 15+; seen on the OnePlus 13, 2026-10-02): the system's
        // bottom inset is honoured, so Play/Stop clear the bar instead of
        // sharing its space. The top is the AppBar's business.
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            _controlBarGap + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              // Content comes from the library only (008 FR-003): the sample
              // buttons are gone, replaced by the Content action in the app bar.
              const SizedBox(height: 8),
              Expanded(
                child: _isRendering
                    // RENDERING (FR-019/FR-020): the render's own picture and
                    // nothing of the page. The text is not on screen while it
                    // runs, so no touch can reach it.
                    ? _buildRenderArea(context)
                    : _isReview
                        // REVIEW (FR-021): the video this render made, and the
                        // three decisions about it. Nothing of the page either.
                        ? _buildReviewArea(context)
                    : editing
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
                                // (fallback poison) nor null root (inherited
                                // white) paints correctly on this GPU path.
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
                // A render's only control is Stop, centred where the page's own
                // controls were (FR-019).
                mainAxisAlignment: _isRendering
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: _isRendering
                    ? [
                        IconButton(
                          icon: const Icon(Icons.stop),
                          tooltip: l10n?.stopButton ?? 'Stop',
                          onPressed: _stopFromToolbar,
                        ),
                      ]
                    // A review carries its own decisions, so the page's controls
                    // stay away from it (FR-021).
                    : _isReview
                    ? const <Widget>[]
                    : editing
                    ? [
                        // The one press that puts every tag at the head of its
                        // own paragraph (FR-024, SC-011). Wrapped in the
                        // controller so its state follows what the reader types
                        // rather than the last rebuild — the page has no other
                        // listener on the editor's text.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _editController!,
                          builder: (context, value, _) => IconButton(
                            icon: const Icon(Icons.format_line_spacing),
                            tooltip:
                                AppLocalizations.of(context)?.formatButton ??
                                    'Format',
                            // Disabled, not a silent no-op, when the press would
                            // change nothing — the Undo button's own pattern.
                            onPressed:
                                formatForDialogue(value.text) == value.text
                                    ? null
                                    : _formatDialogue,
                          ),
                        ),
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
      ),
    );
  }
}


/// How tall the window the chosen pictures are reviewed in is (FR-030): two rows
/// of thumbnails and the space between them — a small window the reader scrolls
/// inside, so the prompt stays a prompt however many pictures are kept
/// (2026-09-28: "use scroll. small show window, scroll to show others").
const double pictureWindowHeight = 152;

/// One chosen picture, as the reader sees it before the render (FR-030): the
/// picture itself, at thumbnail size, with its own remove.
///
/// The file comes from the pick's own read, stored in the app's own directory
/// when the picture was chosen (D18), so what the reader sees here is exactly
/// what the render will copy — and the decode is bounded by [cacheWidth], since a
/// phone photo is many megapixels and this is a thumbnail.
class ChosenThumbnail extends StatelessWidget {
  const ChosenThumbnail({
    super.key,
    required this.picture,
    required this.removeLabel,
    required this.onRemove,
  });

  final HeldPicture picture;

  /// What the remove button says, from the app's own copy (FR-031).
  final String removeLabel;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(picture.path),
            fit: BoxFit.cover,
            cacheWidth: 144,
            // A picture the platform handed over but nothing can decode is shown
            // as what it is — a hole in the choice — rather than crashing the
            // prompt the reader is standing in.
            errorBuilder: (context, error, stack) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 20),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            tooltip: removeLabel,
            onPressed: onRemove,
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              // A padded tap target is 48×48 — two thirds of the cell — and it
              // would take the hold that moves the picture with it: the corner
              // button is the size it looks, and the rest of the cell is the
              // reader's own to move (FR-032).
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
  );
}

/// One chosen picture in the review window (FR-030) with the reader's own way of
/// moving it (FR-032): hold it and drop it on another picture's cell to put it
/// where that one was.
///
/// The order the cells stand in **is** the order the video draws the pictures in
/// (FR-026), so a move here is a different video and not a different view of one.
/// A drop on the picture's own cell is not a move at all — [movePicture] hands
/// the choice back as it was, and a reader who let go where they started sees
/// nothing happen rather than a reorder they did not ask for.
class MovableThumbnail extends StatelessWidget {
  const MovableThumbnail({
    super.key,
    required this.picture,
    required this.index,
    required this.removeLabel,
    required this.onRemove,
    required this.onMoveTo,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final HeldPicture picture;

  /// Where this picture stands in the choice, which is what the drag carries.
  final int index;

  /// What the remove button says, from the app's own copy (FR-031).
  final String removeLabel;

  final VoidCallback onRemove;

  /// Move the picture at [from] to this cell.
  final void Function(int from) onMoveTo;

  /// Where the held picture is, while it is being moved: the page uses it to
  /// scroll the window when the hold reaches either end of it (FR-032, D21).
  final void Function(Offset globalPosition)? onDragUpdate;

  /// The hold is over, however it ended — dropped, cancelled or refused.
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) => DragTarget<int>(
    onWillAcceptWithDetails: (details) => details.data != index,
    onAcceptWithDetails: (details) => onMoveTo(details.data),
    builder: (context, candidate, rejected) => LongPressDraggable<int>(
      data: index,
      // Where the finger is while it moves, so a hold at either end of the
      // picture window can scroll it (FR-032, D21) — and so whatever that
      // started stops when the hold does.
      onDragUpdate: onDragUpdate == null
          ? null
          : (details) => onDragUpdate!(details.globalPosition),
      onDragEnd: (_) => onDragEnd?.call(),
      // What follows the finger is the picture alone: a thumbnail's own remove
      // is not what is being moved, and the drag has nowhere to put it.
      feedback: Material(
        color: Colors.transparent,
        child: ChosenThumbnail(
          picture: picture,
          removeLabel: removeLabel,
          onRemove: () {},
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: ChosenThumbnail(
          picture: picture,
          removeLabel: removeLabel,
          onRemove: onRemove,
        ),
      ),
      // The cell has to answer the pointer for the hold to start anywhere on it:
      // an `Image` answers no pointer on its own, so without this only the button
      // in the corner would start a drag (FR-032).
      child: ColoredBox(
        color: Colors.transparent,
        child: ChosenThumbnail(
          picture: picture,
          removeLabel: removeLabel,
          onRemove: onRemove,
        ),
      ),
    ),
  );
}
