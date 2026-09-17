import 'package:flutter/material.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/voice_store.dart';

/// Fixed preview line per language (spec assumption 2026-09-14).
String sampleLineFor(String language) => language == 'zh-Hans'
    ? '你好，这是我的朗读声音。'
    : 'Hello, this is my reading voice.';

/// Voice picker (002 US2): lists installed voices for [language],
/// tap previews the sample line in that voice and persists the choice.
class VoicePickerScreen extends StatefulWidget {
  final Reader reader;
  final VoiceStore store;
  final String language;

  const VoicePickerScreen({
    super.key,
    required this.reader,
    required this.store,
    required this.language,
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

  /// Per-row keys: autoscroll target for the selected row (~40 rows max).
  final Map<String, GlobalKey> _rowKeys = {};
  final ScrollController _scrollController = ScrollController();

  /// Estimated two-line ListTile height. Only used for the initial jump that
  /// brings an offscreen selected row into the laid-out range; the final
  /// centering is exact (ensureVisible on the live context).
  static const double _estimatedRowHeight = 72;

  String _keyFor(VoiceEntry voice) => '${voice.name}||${voice.locale}';

  @override
  void initState() {
    super.initState();
    _language = widget.language;
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
      final selected = await widget.store.loadVoice(_language);
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
          _rowKeys['${sel.name}||${sel.locale}']?.currentContext;
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
        (v) => v.name == sel.name && v.locale == sel.locale,
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
      _selected?.name == voice.name && _selected?.locale == voice.locale;

  Future<void> _onTap(VoiceEntry voice) async {
    try {
      // previewVoice owns stop-first (spec FR-009): no separate stop here.
      await widget.reader.previewVoice(
        voice,
        sampleLineFor(_language),
      );
      await widget.store.saveVoice(
        VoiceChoice(
          language: _language,
          name: voice.name,
          locale: voice.locale,
        ),
      );
      if (!mounted) return;
      setState(() {
        _selected = VoiceChoice(
          language: _language,
          name: voice.name,
          locale: voice.locale,
        );
        _previewError = null;
      });
      _scrollToSelectedSoon();
    } on ReaderException catch (e) {
      if (!mounted) return;
      setState(() => _previewError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<String>(
              // No markers anywhere in the picker (spec US1): the selected
              // segment is already evident from its fill color.
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'zh-Hans', label: Text('中文')),
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
    return switch (_status) {
        _PickerStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        _PickerStatus.empty => const Center(
            child: Text('No voices installed for this language.'),
          ),
        _PickerStatus.error => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load voices.'),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        _PickerStatus.ready => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _voices.length == 1
                      ? '1 voice'
                      : '${_voices.length} voices',
                ),
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
                      for (final voice in _voices)
                        ListTile(
                          key: _rowKeys.putIfAbsent(
                            _keyFor(voice),
                            GlobalKey.new,
                          ),
                          title: Text(voice.name),
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
