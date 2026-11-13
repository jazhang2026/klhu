# Data Model: Tap-to-read — remove the Read button

No persistence changes. Everything below is page state inside `ReadingViewState`
(`lib/reading_view.dart`), in memory for the session only — the same lifetime rule 016 decision 5 set for
the position: nothing is written down, a restart is a clean page.

## State fields (changed or added)

| Field | Type | Meaning | Lifetime |
|---|---|---|---|
| `_highlight` | `TextSegment?` | The painted selection — after a tap-read it is the unit just read and **stays** | Until Stop/Edit/new content/another tap |
| `_anchor` | `int?` | The Continue Read start offset (content offsets). After a tap-read it is the **next** step's start, or null at text end | Same as before; cleared with the highlight wherever the read ends non-step |
| `_mode` | `_Mode` | `read` / `speaking` / `paused` / `edit` / `rendering` / `review` — unchanged | — |
| `_steppedRead` | `bool` | Set by `_readRange`: this read is a single-unit (step) read | Per `_readRange` call; survives Pause→Resume |
| `_stepEndKey` | `int` | End offset of the step's own range (comment-aware via `stepEnd`) | Same |
| `_readGen` | `int` | Read generation; stale `finally`s lose | Bumped by `_select`, `_stop`, each `_runRead` unit |
| `_continueReading` | `bool` **(new)** | A Continue Read wrap loop is armed | Set by `_readContinue`; cleared by `_stop`, `_enterEdit`, `_adoptAnchor`, and when the driver exits without pausing |
| `_readCompleted` | `bool` **(new)** | The last `_runRead` ended naturally (current gen, was speaking, `last`, no `ReaderException`) | Reset at each `_readRange`; set in `_runRead`'s finally |
| `_readFailed` | `bool` **(new)** | The last `_runRead` caught a `ReaderException` | Reset at each `_runRead` entry; set in its catch |
| `_pausedReadFrom` | `int?` **(new)** | Content offset where a parked paged read resumes its remaining units; null = nothing remains | Set when `_readRange` parks on Pause; consumed and cleared by the resume path |

## Interactions / transitions

```
tap/long-press (idle)
  → _resolveAt: stop() → _select(segment)          // highlight = segment, anchor = segment.start
  → _readSelection → _readRange(step: true)
  → natural end: _runRead finally (stepped, last)
      highlight UNCHANGED; _advanceAnchor(_stepEndKey) → anchor = next step start (or null)

⏭ Continue Read (idle)
  → _continueReading = true → _driveContinue(_anchor ?? 0)
  → _readRange(start, len, track: true): per unit _runRead(last: i == n-1)
      tracking highlight moves per spoken sentence (unchanged)
  → natural end of last unit: highlight + anchor cleared, _readCompleted = true
  → driver: _readCompleted → loop with start = 0  (wrap)
  → Pause: mode = paused, _pausedReadFrom = next unit start (or null), driver returns,
           _continueReading stays armed
  → Resume: _runRead(resume, last: _pausedReadFrom == null)
      → remaining units via _driveContinue(_pausedReadFrom); end → wrap continues
  → Stop: _continueReading = false, _readGen++, reader.stop() → all loops exit
```

## Invariants (amended)

- **Highlight ↔ anchor may diverge after a tap-read** (spec assumption): highlight = last unit read,
  anchor = next unread step. They still die together on Stop, Edit, and content change.
- A wrap loop never speaks after Stop: `_continueReading` is cleared synchronously in `_stop` before
  `reader.stop()` releases the parked loop.
- `_pausedReadFrom` is only meaningful while `_mode == paused`; entering Edit or loading content clears it
  with `_continueReading`.
