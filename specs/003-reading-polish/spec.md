# Spec: 003 Reading Polish

**Goal**: Picker selection readable at a glance; reading area directly
editable (no paste box); page reads show where the voice is.

**Prerequisites**: 002 done (55/55 green, analyze clean).

## US1 — Picker selection without marker (P1)

- No check mark / icon / '✓' anywhere in the picker (incl. the
  SegmentedButton's selected-segment check: `showSelectedIcon: false`).
- Selected row: green background (`selectedTileColor: green.shade200`) with
  dark text (`selectedColor: black`) — never green text. The selected STATE
  still sets the isSelected semantics flag, so TalkBack announces "selected"
  (probed live 2026-09-16; the flag, not a label, drives the announcement).
- On open and on select, list auto-scrolls so the selected row sits in
  the middle of the viewport (`Scrollable.ensureVisible`, alignment 0.5,
  post-frame). Offscreen rows have NO element (slivers inflate lazily even
  with eager children — verified 2026-09-16: only laid-out rows exist), so
  a missing context jumps near `index × 72` via an explicit ScrollController
  (shared with the Scrollbar) and retries, bounded, until the row lays out
  and centers exactly. Regression test: saved selection at row 39 of 40
  asserts offset > 0 after first pump.
- Visible scrollbar (always shown) so position in list is visible.
- Total count visible as a header ("N voices" / "1 voice").

**Accept**: select voice B → row B highlighted, centered, no marker;
TalkBack announces "selected"; count matches getVoices filter.

## US2 — Direct-edit reading area (P1)

Three explicit states, one area, no gesture overloading (revised per
emulator validation 2026-09-16: READ/SPEAKING show RichText with the 001
yellow highlight; the TextField exists ONLY in EDIT):

- READ (default): RichText. Single tap selects the enclosing sentence
  (yellow), long-press selects the paragraph (yellow); keyboard never
  appears, no caret/selection UI. TalkBack gestures keep system meanings.
- EDIT (via Edit button, enabled only when idle — never while speaking):
  TextField with full native type / paste / copy / cut / select-all.
  Read + Read page + Stop buttons are HIDDEN; only Done shows. Done commits
  the text and returns to READ (pending selection cleared).
- SPEAKING: RichText locked; tracking highlight (yellow) advances per
  paragraph (US3). Tap/long-press mid-read keeps stop-first, then selects.
  Edit is disabled until Stop / natural end.
- Remove the "Paste text to read" field and the Load button.
- EN sample / 中文示例 buttons keep loading sample texts (edit ops, visible
  in READ and EDIT; EDIT survives a sample load).
- Done with edited text clears any pending selection. Read with no pending
  selection keeps current behavior ('Tap a sentence first').

**Accept**: READ tap sentence → yellow + Read speaks it, no keyboard;
long-press → paragraph yellow; Edit → TextField with full typing/paste, no
Read buttons visible; Done → back to READ with committed text; Edit disabled
while speaking; no Load step anywhere.

## US3 — Read page tracks current paragraph (P2)

- Read page highlights ONLY the paragraph currently being spoken, and
  the highlight advances paragraph by paragraph as reading proceeds.
- Whole-page highlight goes away.
- Highlight clears when reading finishes or Stop is pressed.
- Needs progress out of `Reader.speakParagraphs` (e.g. per-paragraph
  callback wired to flutter_tts utterance start handler); fake-tts tests
  drive the callback manually.

**Accept**: mixed EN/zh page read → yellow band sits on exactly the
paragraph being spoken, moves with the voice, gone at end/Stop.

## Out of scope

- iPhone validation (no macOS), manual TalkBack ear-check (real device).
