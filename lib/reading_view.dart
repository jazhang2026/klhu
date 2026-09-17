import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:klhu/language.dart';
import 'package:klhu/reader_service.dart';
import 'package:klhu/segmenter.dart';
import 'package:klhu/sample_texts.dart';
import 'package:klhu/voice_picker_screen.dart';
import 'package:klhu/voice_store.dart';

/// Reading view (003, revised per emulator validation): RichText for
/// READ/SPEAKING with the 001 yellow highlight (tap selects sentence,
/// long-press selects paragraph, page-read tracking highlights the spoken
/// paragraph); a TextField appears ONLY in EDIT mode.
///
/// - READ (default): RichText, tap sentence / long-press paragraph, keyboard
///   never appears, no caret/selection UI. TalkBack gestures keep meanings.
/// - EDIT (Edit button, idle-only): fully editable TextField with native
///   type/paste/copy/cut; Read + Read page + Stop hidden, only Done shows.
///   Done commits the text and returns to READ.
/// - SPEAKING: RichText locked (no gestures resolve while speaking except
///   tap/long-press, which stop-first then select); tracking highlight moves
///   per paragraph; Edit disabled until Stop / natural end.
///
/// No gesture overloading (tap means one thing per state); typing-during-read
/// and Read-with-unsaved-edits are impossible by construction.
class ReadingView extends StatefulWidget {
  final Reader reader;
  final VoiceStore voiceStore;

  ReadingView({super.key, Reader? reader, VoiceStore? voiceStore})
      : reader = reader ?? ReaderService(),
        voiceStore = voiceStore ?? VoiceStore();

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

enum _Mode { read, edit, speaking }

class _ReadingViewState extends State<ReadingView> {
  final _textKey = GlobalKey();
  final _focusNode = FocusNode();
  TextEditingController? _editController;
  String _content = SampleTexts.en;
  TextSegment? _highlight;
  _Mode _mode = _Mode.read;

  /// Invalidates a stale read's `finally` (tap/Stop during SPEAKING must win
  /// over the in-flight loop's cleanup).
  int _readGen = 0;

  String? _error;
  String? _hint;

  @override
  void dispose() {
    _editController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSample(String language) async {
    // Switching text must not keep reading the old content.
    await widget.reader.stop();
    final text = language == 'zh-Hans' ? SampleTexts.zhHans : SampleTexts.en;
    setState(() {
      _content = text;
      _editController?.text = text;
      _highlight = null;
      _error = null;
      _hint = null;
      // EDIT survives (sample load is an edit op); SPEAKING drops to READ.
      if (_mode == _Mode.speaking) _mode = _Mode.read;
    });
  }

  Future<void> _enterEdit() async {
    if (_mode == _Mode.speaking) return;
    await widget.reader.stop();
    _editController ??= TextEditingController();
    _editController!.text = _content;
    setState(() {
      _mode = _Mode.edit;
      _highlight = null;
      _hint = null;
    });
    _focusNode.requestFocus();
  }

  void _doneEdit() {
    // Commit the edited text, leave EDIT.
    setState(() {
      _content = _editController!.text;
      _mode = _Mode.read;
      _highlight = null;
    });
  }

  Future<void> _onTapDown(TapDownDetails details) async {
    await _resolveAt(details.globalPosition, resolveSentence);
  }

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    await _resolveAt(details.globalPosition, resolveParagraph);
  }

  /// Shared tap/long-press path: map the touch point to a text offset,
  /// resolve to the enclosing segment, stop current speech, highlight,
  /// and wait for Read (data-model invariant).
  Future<void> _resolveAt(Offset globalPosition,
      TextSegment Function(String, int) resolve) async {
    final obj = _textKey.currentContext?.findRenderObject();
    if (obj is! RenderParagraph) return;
    final pos =
        obj.getPositionForOffset(obj.globalToLocal(globalPosition));
    await widget.reader.stop();
    setState(() {
      // Win over the stopped loop's `finally` below.
      _readGen++;
      _mode = _Mode.read;
      _highlight = resolve(_content, pos.offset);
      _error = null;
      _hint = null;
    });
  }

  Future<void> _readSelection() async {
    final seg = _highlight;
    if (seg == null) {
      // No tap yet: prompt instead of surprising the user with a full page.
      setState(() => _hint = 'Tap a sentence first, then Read.');
      return;
    }
    await _readRange(seg.start, seg.end);
  }

  Future<void> _readPage() async {
    final seg = pageRange(_content);
    await _readRange(seg.start, seg.end, track: true);
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
      setState(() => _hint = 'Nothing to read.');
      return;
    }
    final gen = ++_readGen;
    setState(() {
      _mode = _Mode.speaking;
    });

    void clearTracking() {
      _mode = _Mode.read;
      _highlight = null;
    }

    try {
      await widget.reader.speakParagraphs(
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
      );
    } on ReaderException catch (e) {
      setState(() => _error = e.message);
    } finally {
      // Stale generations (tap/Stop started a newer read) skip cleanup.
      if (mounted && gen == _readGen) setState(clearTracking);
    }
  }

  Future<void> _stop() async {
    _readGen++;
    await widget.reader.stop();
    setState(() {
      _mode = _Mode.read;
      _highlight = null;
    });
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
        title: const Text('klhu Read Aloud'),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Voice',
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
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _loadSample('en'),
                  child: const Text('EN sample'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadSample('zh-Hans'),
                  child: const Text('中文示例'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: editing
                  // EDIT: the ONLY editable widget. Commits on Done.
                  ? TextField(
                      controller: _editController,
                      focusNode: _focusNode,
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
                      ElevatedButton(
                          onPressed: _doneEdit, child: const Text('Done'), expanded: true),
                    ]
                  : [
                      ElevatedButton(
                          onPressed: _readSelection,
                          child: const Text('Read'), expanded: true),
                      ElevatedButton(
                          onPressed: _readPage,
                          child: const Text('Read page'), expanded: true),
                      ElevatedButton(
                          onPressed: _stop, child: const Text('Stop'), expanded: true),
                      ElevatedButton(
                        // Idle-only: never enter EDIT mid-speech.
                        onPressed:
                            _mode == _Mode.speaking ? null : _enterEdit,
                        child: const Text('Edit'), expanded: true,
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
