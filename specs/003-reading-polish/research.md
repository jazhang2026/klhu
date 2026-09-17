# Research: 003-reading-polish

## US1 — Selected row without marker

- `ListTile(selected: true)` merges "selected" into semantics: TalkBack
  announces "selected" with no trailing widget. The T019 guarantee survives
  the ✓ removal; `voice_picker_semantics_test.dart` already proves the
  announcement path — extend with a no-✓-anywhere assertion.
- Highlight color: `selectedTileColor` on the ListTile (theme-derived, keep
  default unless emulator shows the same quantization mispaint as
  `_contentTextStyle` — verify visually at implement time).
- Auto-center: `Scrollable.ensureVisible(context, alignment: 0.5)` in a
  post-frame callback, on load-ready (when a choice is selected) and on every
  select. Needs a `BuildContext` for the selected row: one `GlobalKey` per row
  (list is ~40 rows max per T014 counts — cheap) or a single key moved to the
  selected tile. Decision: per-row keys (simpler, no key-migration bugs).
- Scrollbar: `Scrollbar(thumbVisibility: true)` wrapping the list. Requires
  `ListView.builder` (indexed, pairs with per-row keys); same entries as now.
- Count: header line `"N voices"` above the list (not AppBar subtitle — stays
  visible during scroll, updates with language switch). Count == filtered list
  length == getVoices prefix filter (existing `voicesFor`).
- Risk: `ensureVisible` on a just-built list does nothing if the row isn't
  laid out yet — post-frame callback after `ready` setState covers it; test
  asserts selected row exists with `selected: true`, not pixel position
  (behavior contract, not snapshot).

## US2 — Direct-edit reading area

- Widget: RichText for READ/SPEAKING (001 `_buildSpans` yellow spans,
  same `_contentTextStyle` with its GPU-mispaint constraints); a TextField
  (multiline, expands, outlined + 'Edit text to read' label) exists ONLY in
  EDIT, seeded from `_content` on entry.
- Modes (final design per emulator validation 2026-09-16): READ/SPEAKING
  show RichText with the 001 yellow highlight; the TextField exists ONLY in
  EDIT (Edit button, idle-only, autofocus; Done commits text and returns to
  READ). No gesture overloading and no detector-vs-field arena fight: the
  proven 001 GestureDetector (tap sentence / long-press paragraph) works on
  RichText because RichText has no competing recognizers. An earlier
  iteration (TextField everywhere + controller-listener on native
  tap-collapse) was abandoned: tap looked like edit-select and long-press
  paragraph had no native equivalent.
- Tap/long-press (READ/SPEAKING): the 001 `_resolveAt` shape on the RichText
  (`RenderParagraph.getPositionForOffset`), tap → sentence, long-press →
  paragraph. No RenderEditable mapping, no arena fight, no fallback needed.
- Selection as highlight: does not apply — highlight is yellow spans, never
  the selection. The TextField selection is purely EDIT-internal.
- Committing: Done copies the field text into `_content` and clears the
  highlight; sample buttons set both. No `onChanged`-clears-pending path —
  pending state only exists on the RichText side.
- No caret anywhere outside EDIT: READ/SPEAKING show RichText (no caret,
  no selection UI); EDIT has a fully native caret with handles/long-press.
  Nothing custom in any gesture arena.
- Removed: `_pasteController`, paste `TextField`, Load button. Kept: sample
  buttons (load into controller, visible in READ and EDIT), Read / Read page
  / Stop (READ and SPEAKING only — hidden in EDIT), hint + error lines, new
  Edit / Done toggle.
- Alternative rejected: always-editable field with tap-select — single tap
  cannot mean caret-place and sentence-select at once, and overloading tap
  collides with TalkBack's focus/activate gestures. Explicit modes cost one
  tap (Edit) and remove the whole conflict class, including typing-during-read
  (impossible by construction) and Read-with-unsaved-edits (Done commits).
- Alternative rejected: separate view/edit mode toggle — spec wants the area
  itself editable, and a mode toggle doubles the test matrix for no gain.

## US3 — Paragraph tracking

- No new platform handler needed: `speakParagraphs` already speaks strictly
  sequentially awaiting per-paragraph completion. Invoking
  `onParagraphStart(i)` immediately before each `speak()` IS utterance-start
  for tracking purposes (ordering guarantee comes from the existing loop, not
  from flutter_tts callbacks).
- Callback signature: `speakParagraphs(paragraphs, {void Function(int index)?
  onParagraphStart})` on the `Reader` interface; `ReaderService` and the test
  fake both implement it. Optional named param keeps existing call sites
  compiling (picker preview doesn't pass it).
- Generation guard: callback fires only when `generation == _generation`;
  `stop()` bumps the generation first, so a stale loop can neither speak nor
  `setState` after Stop. View additionally checks `mounted`.
- Highlight source: `ParagraphSpeech` gains `start`/`end` content offsets
  (populated from the existing `from`/`to` in `resolveParagraphSpeeches` —
  zero new computation). View highlight = `speeches[i]` range; clears in the
  `finally` after the loop (natural end) and in `_stop`.
- Alternative rejected: recomputing paragraph ranges in the view to map index
  → range duplicates the resolver loop and can drift from what is spoken.
  Offsets on the speech object keep one source of truth.
