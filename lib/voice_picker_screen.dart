import 'package:flutter/material.dart';
import 'package:klhu/models/voice_mapping.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_store.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/services/voice_mapping_service.dart';

/// Fixed preview line per language (spec assumption 2026-09-14, extended by
/// spec 007 with the Spanish line).
String sampleLineFor(String language) => switch (language) {
      'zh-Hans' => '你好，这是我的朗读声音。',
      'es' => 'Hola, esta es mi voz de lectura.',
      _ => 'Hello, this is my reading voice.',
    };

/// Voice picker (002 US2): lists installed voices for [language],
/// tap previews the sample line in that voice and persists the choice.
/// Displays user-friendly names with characteristics via [VoiceMappingService].
///
/// 014 opens the same screen for a ROLE (D7): the language picker's own path
/// passes none of the four parameters below, so that screen is exactly what
/// ships — a title of its own, no *automatic* row, the selected row read from
/// [store] and a tap saved through it.
class VoicePickerScreen extends StatefulWidget {
  final Reader reader;
  final VoiceStore store;
  final String language;

  /// Shown instead of the screen's own title — the role's name (014).
  final String? title;

  /// Offer a first row meaning *follow the automatic assignment* (014 FR-012):
  /// tapping it hands the role back to the ranking. False for the language path,
  /// where a language's voice has always been a pick.
  final bool clearable;

  /// What to show as chosen. The language path passes nothing and the pick is
  /// read from [store]; a role's pick lives in `lib/role_store.dart`, which this
  /// screen knows nothing about, so the page hands it over.
  final VoiceChoice? initialSelection;

  /// Where a pick goes — and a clear, as null. The language path passes nothing
  /// and the pick is written through [store]; for a role the page passes a
  /// closure onto the role store, so a role's voice can never be written as the
  /// language's voice (FR-013).
  final Future<void> Function(VoiceChoice? choice)? onPick;

  const VoicePickerScreen({
    super.key,
    required this.reader,
    required this.store,
    required this.language,
    this.title,
    this.clearable = false,
    this.initialSelection,
    this.onPick,
  });

  @override
  State<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

enum _PickerStatus { loading, ready, empty, error }

class _VoicePickerScreenState extends State<VoicePickerScreen> {
  _PickerStatus _status = _PickerStatus.loading;
  List<VoiceEntry> _voices = [];
  VoiceChoice? _selected;
  String? _previewError;
  late String _language;
  late VoiceMappingService _mappingService;

  /// Per-row keys: autoscroll target for the selected row (~40 rows max).
  final Map<String, GlobalKey> _rowKeys = {};
  final ScrollController _scrollController = ScrollController();

  /// Estimated two-line ListTile height. Only used for the initial jump that
  /// brings an offscreen selected row into the laid-out range; the final
  /// centering is exact (ensureVisible on the live context).
  static const double _estimatedRowHeight = 72;

  /// One row per voice, so a row is named by the VOICE, not by the copy it was
  /// stored as: a pick made of a network copy still finds — and highlights — the
  /// voice's single row (2026-10-06).
  String _keyFor(String name, String locale) =>
      '${voiceIdentity(name)}||$locale';

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _mappingService = VoiceMappingService();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoicePickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same-type repumps reuse this state (e.g. language switch without a
    // remount): reload or the list stays stuck on the previous language.
    if (oldWidget.language != widget.language) {
      _language = widget.language;
      _load();
    } else if (oldWidget.reader != widget.reader ||
        oldWidget.store != widget.store) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _status = _PickerStatus.loading;
      _previewError = null;
      _rowKeys.clear();
    });
    try {
      final voices = await widget.reader.voicesFor(_language);
      // A role's pick is not in [store]: the page hands it over (014 D7).
      final selected = widget.onPick == null
          ? await widget.store.loadVoice(_language)
          : widget.initialSelection;
      if (!mounted) return;
      setState(() {
        _voices = voices;
        _selected = selected;
        _status =
            voices.isEmpty ? _PickerStatus.empty : _PickerStatus.ready;
      });
      _scrollToSelectedSoon();
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _PickerStatus.error);
    }
  }

  /// Center the selected row post-frame (on open and on select).
  /// No-op when nothing is selected. Offscreen rows have no element yet
  /// (slivers inflate lazily even with eager children), so when the context
  /// is missing we jump near the estimated offset and retry — the next frame
  /// lays the row out and ensureVisible centers it exactly.
  void _scrollToSelectedSoon([int tries = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _status != _PickerStatus.ready) return;
      final sel = _selected;
      if (sel == null) return;
      final ctx =
          _rowKeys[_keyFor(sel.name, sel.locale)]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
        return;
      }
      if (tries >= 5 || !_scrollController.hasClients) return;
      final i = _voices.indexWhere(
        (v) =>
            voiceIdentity(v.name) == voiceIdentity(sel.name) &&
            v.locale == sel.locale,
      );
      if (i < 0) return;
      _scrollController.jumpTo(
        (i * _estimatedRowHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
      _scrollToSelectedSoon(tries + 1);
    });
  }

  bool _isSelected(VoiceEntry voice) =>
      _selected != null &&
      voiceIdentity(_selected!.name) == voiceIdentity(voice.name) &&
      _selected!.locale == voice.locale;

  Future<void> _onTap(VoiceEntry voice) async {
    try {
      // previewVoice owns stop-first (spec FR-009): no separate stop here.
      await widget.reader.previewVoice(
        voice,
        sampleLineFor(_language),
      );
      final choice = VoiceChoice(
        language: _language,
        name: voice.name,
        locale: voice.locale,
      );
      final onPick = widget.onPick;
      if (onPick == null) {
        await widget.store.saveVoice(choice);
      } else {
        await onPick(choice);
      }
      if (!mounted) return;
      setState(() {
        _selected = choice;
        _previewError = null;
      });
      _scrollToSelectedSoon();
    } on ReaderException catch (e) {
      if (!mounted) return;
      setState(() => _previewError = e.message);
    }
  }

  /// The *automatic* row (014 FR-012): the role goes back to the assignment.
  Future<void> _onClear() async {
    final onPick = widget.onPick;
    // The row is only offered when the page opened this screen for a role, and
    // that path always passes a sink.
    if (onPick == null) return;
    await onPick(null);
    if (!mounted) return;
    setState(() {
      _selected = null;
      _previewError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.voiceButton)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<String>(
              // No markers anywhere in the picker (spec US1): the selected
              // segment is already evident from its fill color.
              showSelectedIcon: false,
              // One segment per pickable list, Spanish included: the picker
              // opens on the reading text's language, so without the Spanish
              // segment a Spanish voice could only be picked from Spanish text
              // (found on emulator-5554, spec 007 US2).
              segments: [
                ButtonSegment(value: 'en', label: Text(l10n.englishNative)),
                ButtonSegment(value: 'es', label: Text(l10n.spanishNative)),
                ButtonSegment(value: 'zh-Hans', label: Text(l10n.chineseNative)),
              ],
              selected: {_language},
              onSelectionChanged: (selection) {
                final next = selection.first;
                if (next == _language) return;
                setState(() => _language = next);
                _load();
              },
            ),
          ),
          Expanded(child: _statusBody()),
        ],
      ),
    );
  }

  Widget _statusBody() {
    final l10n = AppLocalizations.of(context)!;
    return switch (_status) {
        _PickerStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        _PickerStatus.empty => Center(
            child: Text(l10n.noVoices),
          ),
        _PickerStatus.error => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.voicesLoadFailed),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _load,
                  child: Text(l10n.retryButton),
                ),
              ],
            ),
          ),
        _PickerStatus.ready => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.voicesCount(_voices.length)),
              ),
              if (_previewError != null)
                Text(
                  _previewError!,
                  style: const TextStyle(color: Colors.red),
                ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  // Eager children (not builder): keeps per-row keys stable
                  // across rebuilds (~40 rows max — cheap). NOTE: eager
                  // widgets still inflate elements lazily — offscreen rows
                  // gain a context only after scrolling near; see
                  // _scrollToSelectedSoon's jump-then-center.
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      // The role path's own row (014 FR-012): what the role reads
                      // with when the reader has not chosen — the assignment.
                      if (widget.clearable)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome),
                          title: Text(l10n.roleVoiceAutomatic),
                          selected: _selected == null,
                          onTap: _onClear,
                        ),
                      for (final voice in _voices)
                        ListTile(
                          key: _rowKeys.putIfAbsent(
                            _keyFor(voice.name, voice.locale),
                            GlobalKey.new,
                          ),
                          title: Text(_mappingService.displayName(voice, l10n, voiceListLanguage: _language)),
                          subtitle: Text(voice.locale),
                          // Highlight WITHOUT marker: green background (not
                          // green text) + selected state keeps the TalkBack
                          // "selected" announcement (T019).
                          selected: _isSelected(voice),
                          selectedTileColor: Colors.green.shade200,
                          selectedColor: Colors.black,
                          onTap: () => _onTap(voice),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      };
  }
}
