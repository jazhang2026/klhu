# Data Model: 003-reading-polish

Unchanged from 002 except where noted (`VoiceChoice`, `VoiceEntry`,
shared_preferences keys `voice_en` / `voice_zh_Hans` carry over as-is).

## ParagraphSpeech (+2 fields)

- Was: `text`, `language`, `voice` (002 `reader_service.dart`).
- New: `start`, `end` — offsets into the reading content the speech was
  resolved from (== the `from`/`to` overlap already computed in
  `resolveParagraphSpeeches`, now retained).
- Invariant: speeches for one read are ordered, non-overlapping, and their
  ranges tile the requested range. Tracking highlight reads ONLY these
  offsets — never recomputed in the view.

## PickerRow (transient, US1)

- `voice` (VoiceEntry), `selected` (== stored choice for active language),
  `rowKey` (per-row GlobalKey, autoscroll target).
- Invariant: exactly one row selected when a choice is stored and installed;
  zero when no choice or choice uninstalled (falls back to OS default, as 002).
- No `isSelected` icon/marker anywhere in the tree (spec US1).

## ReadingEditState (transient, US2/US3)

- `mode`: `read` | `edit` | `speaking` — the single source of what the
  area does. READ/SPEAKING show RichText with the yellow highlight
  (tap = sentence, long-press = paragraph, tracking = current paragraph);
  EDIT shows the only TextField (full native editing), Read/Read-page/Stop
  hidden, only Done shows.
- `_content` (String): the single source of reading text (replaces 002's
  field + `_pasteController`). EDIT commits the field text into it on Done;
  sample buttons set it (and the open field) directly.
- `_highlight`: `TextSegment?` — pending sentence/paragraph (tap/long-press)
  or tracked paragraph (US3). `null` after typing-commit, sample load, Done,
  end/Stop.
- Invariants: EDIT entered only when idle (button disabled while speaking;
  entering calls stop-first defensively). The TextField exists only in EDIT,
  so content can never change under a live read. Highlight is always yellow
  spans — never selection color.
