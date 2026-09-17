# Data Model: 001-read-aloud

## ReadingText
- `source`: paste | bundled-en | bundled-zh
- `content`: full string
- `language`: en | zh-Hans (per device locale; sample tagged)

## TextRange
- `start`, `end`: char offsets into content
- `unit`: sentence | paragraph | page

## Selection
- `tapOffset` → resolved `TextRange` + highlighted rendering
- Invariant: resolved range always within content bounds; whitespace tap → nearest sentence

## Utterance
- `text` (resolved range substring), `language`, `state`: idle | speaking | stopped
- Stop → state stopped <1s; new tap while speaking stops current, highlights new, waits for Read
