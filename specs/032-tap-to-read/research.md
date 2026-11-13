# Research: Tap-to-read — remove the Read button

All decisions below were resolved with the user on 2026-11-12 before planning; this file records the
technical reasoning and the code facts each decision rests on.

## D1 — How a tap starts a read

**Decision**: `_resolveAt` keeps its job (offset → segment → `_select`) and then awaits `_readSelection()`.
`_readSelection` already branches correctly: a highlighted sentence reads `stepEnd(...)` with `step: true`,
a highlighted paragraph reads its whole span with `step: true`, and both reveal the range before speaking.

**Rationale**: the smallest possible diff — the gesture and the button converge on one code path, exactly as
016 intended when it wrote "the gesture and ▶ Read must set a selection the same way". No new read path, no
duplicated speech resolution.

**Alternatives considered**: (a) a separate `_readTapped` duplicating `_readSelection`'s branches — rejected,
double maintenance; (b) moving the read trigger into `_select` — rejected, `_select` is also called by
non-gesture paths that must not speak.

**Code facts**: `_onTapText`/`_onLongPressText` (`reading_view.dart:1376-1389`) already gate on
`_isSpeakingOrPaused`, so FR-009 needs no new guard. `_resolveAt` (`:1399-1412`) awaits
`widget.reader.stop()` before selecting, so a tap-read never overlaps a finishing read.

## D2 — What a finished step read leaves behind

**Decision**: replace `_advanceStep` with `_advanceAnchor`. On a step read's natural end the page sets
`_anchor` to the first `stepRanges(_spoken)` entry at or after `_stepEndKey` — and does **not** touch
`_highlight`. `_advanceStep` is deleted (its only caller was `_runRead`'s finally).

**Rationale**: spec FR-004/FR-005 — the highlight names what was just read; the anchor names what ⏭ reads
next. `stepRanges` (not `sentenceRanges`) is used so comment-interior sentences are skipped exactly as the
read's own stepping rule does; `_stepEndKey` already carries `stepEnd`'s comment-aware end, so the next
anchor lands after the comment, not on its tag.

**Offset space verified**: `_spoken` is `_commentDisplay.masked` (`reading_view.dart:3430`), which blanks
scene-tag lines to same-length spaces (`comment.dart:322-329`) — offsets are the content's own, so an anchor
taken from `stepRanges(_spoken)` is a valid `_content` offset, same as today's `_advanceStep`.

## D3 — The Continue Read wrap

**Decision**: two page fields — `_continueReading` (the loop is armed) and `_readCompleted` (the last
`_runRead` ended naturally, i.e. gen current + mode speaking + no `ReaderException`). `_readContinue` loops
`_readRange(_anchor ?? 0, _content.length, track: true)`; after each pass, a paused mode returns (the loop
stays armed for resume), `!_readCompleted` breaks (Stop/error), otherwise it loops — `_anchor` was cleared
by the finishing read, so the next pass starts at 0.

**Rationale**: natural end, Pause and Stop are indistinguishable by page state alone after `_readRange`
returns (all leave `_anchor == null`, `_mode == read`, `_highlight == null`). `_readCompleted` is set only
inside `_runRead`'s finally when `gen == _readGen && _mode == _Mode.speaking && last && !_readFailed` —
Pause skips the block (mode is `paused`), Stop skips it (gen is stale), an error sets `_readFailed` in the
catch. That is the only place that knows the difference.

**Resume**: `_pauseResume`'s resume branch re-enters the driver when `_continueReading` is still armed —
after `widget.reader.resume()` finishes the parked unit, `_driveContinue` is invoked from
`_pausedReadFrom ?? 0`, so the wrap survives a pause/resume cycle (spec US2 scenario 4).

**Alternatives considered**: (a) wrap inside `_readRange` — rejected, `_readRange` doesn't own the loop
semantics and step reads share it; (b) a timer/`Future.delayed` chain — rejected, constitution V and the
app's no-timer rule (016 out-of-scope already banned auto-advance timers); (c) wrap only on uninterrupted
reads — rejected by the user's "keep other functions" answer.

## D4 — Inter-unit Pause/Stop guard (FR-010)

**Decision**: in `_readRange`'s non-step loop, after each `_runRead`: `if (_mode == _Mode.paused)` park —
record `_pausedReadFrom = reads[i + 1].start` (or null on the last unit) and return; `if (_readGen != gen)`
return — a Stop or a newer read superseded this one. Resume passes `last: _pausedReadFrom == null` to
`_runRead` so a non-final unit's resume doesn't clear the anchor, then `_driveContinue` picks up the
remainder.

**Rationale**: today the loop speaks the next unit unconditionally — Pause during unit *i* of a >4000-char or
paged document is silently skipped, and Stop's `_readGen` bump is overwritten by the next `++_readGen`.
The wrap makes this reachable in normal use, so the guard ships with it (spec assumption).

**Code facts**: `documentUnits` (`document_input.dart:98-122`) yields multiple units for texts >4000 chars
or paged documents; `_runRead`'s finally sets `_mode = read` after every unit, so mode alone can't detect
"still going" — the `_readGen != gen` check is the stop signal.

## D5 — Toolbar and l10n

**Decision**: delete the `Icons.play_arrow`/`readButton` `IconButton` (`reading_view.dart:3694-3699`) and
the `readButton` key from all four ARBs; regenerate `app_localizations*.dart` with `flutter gen-l10n`.

**Rationale**: user: "let's just remove the Read button". The key has exactly one consumer (the tooltip);
`test/l10n_keys_test.dart` (per 016 FR-013) fails on keys the template drops but a translation keeps, so all
four ARBs must go together.

## D6 — Test strategy

Widget tests already have the primitives: `offsetOf(tester, 'text')` (`content_fixtures.dart:129`) taps by
content, `RecordingReader`/`FakeReader` record speeches with offsets, `hasYellow`/`hasAnyYellow` inspect the
highlight. Step tests' `pressRead` helper becomes `tapSentence(tester, '…')`. Walk scripts' `readButton`
lookups are replaced by direct text taps or removed where the Read press was only setup.

**Risk noted**: the tap→speak path adds an `await resolveSpeeches` window before `_mode` becomes `speaking`;
a second tap inside it passes the idle guard. Last tap wins via `_readGen` (D1's generation guard), so the
outcome is correct — recorded here, not fixed, because closing it would need a new busy state for a
sub-100 ms window.
