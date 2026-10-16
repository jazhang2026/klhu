# Quickstart: The page keeps something ahead of the read

## Prerequisites

`export PATH=$HOME/development/flutter/bin:$PATH`, the emulator `emulator-5554` (AVD `klhu`, API 36) up, package
`com.example.klhu`, and the line's own baseline — **every row below is read against it**:

```
flutter analyze                      → clean
flutter test --concurrency=2         → this tree's closing count, 0 failing
message keys per ARB (four files)    → this tree's count (this feature adds none)
test/*.dart files in the tree        → this tree's count
```

**Re-taken at the first row, not inherited**: 011's own receipt for its row 7 quotes `viewport=209` where
2026-10-16's run reads `196` on the same fixture (research §2). The walk's first action is to re-take the baseline.

## Automated checks

```
flutter analyze                                   → clean
flutter test --concurrency=2                      → the baseline's count + this feature's own cases, 0 failing
flutter test test/reading_view_follow_test.dart   → the rule, its no-move cases, the manual scroll
flutter test test/reading_view_step_test.dart     → the step's advance leaves a sentence ahead
python3 ~/.hermes/skills/software-development/spec-driven-development/scripts/check_artifact_refs.py specs/022-read-scroll-lead
```

## Scenarios

### 1. **[unit]** the lead fires one sentence early, before the last-visible sentence is highlighted — `1B`, `FR-001`/`FR-002` (`SC-001`, `SC-002`)

With a text taller than a 400×600 page and the read playing, the sentence whose **successor is the last visible one**
moves the page **at its own start** — one sentence before the sentence that would be the last visible one is
highlighted. After the move, that last-visible sentence **and** the one after it are at least partly inside the
viewport, so when the read reaches it, the app's own evidence line reports `below >= 1`. The move's own evidence
precedes the `klhu speak` line of the sentence it was fired at, and precedes the highlight of the sentence it was fired
for.

**Expected**: the sentence being read is never the bottom-most box on screen, and its voice never begins before the
move has been asked for.
**Evidence**: `test/reading_view_follow_test.dart` — the re-cut of 011's *long text: the spoken sentence comes into
view*, plus the captured log lines ordered against the read's own start.
**Proves FR-001, FR-002, SC-001, SC-002.**

### 2. **[unit]** nothing moves when a sentence already follows it — `FR-001`/`FR-003` (`SC-005`)

A sentence whose **next-next** sentence is already inside the viewport: `scrollPosition` returns the same pixels before
and after the report, and the reveal is not called at all.

**Expected**: the page is left alone; the rule is a relation, not a habit of moving.
**Evidence**: `test/reading_view_follow_test.dart` — a new case asserting the offset is unchanged across the report.
**Proves FR-001, FR-003, SC-005.**

### 3. **[unit]** the content's last sentence, and a read with nothing after it — `FR-005` (`SC-003`)

The read reaches the content's last sentence from a page whose bottom the sentence sits at: the page does not move,
and the line reports `below=0` — the reader's own exception ("unless its the last sentence of the content"). The same
holds for a read whose own range ends there.

**Expected**: no move, no reveal call, and a line that says why (nothing follows it).
**Evidence**: `test/reading_view_follow_test.dart` — a new case; the device half is row 11 below.
**Proves FR-005, SC-003.**

### 4. **[unit]** a text that fits the visible area moves by zero pixels — `FR-005` (`SC-003`)

011's own scenario 3, re-run: every report of a whole read of a short text leaves `scrollPosition.pixels` at 0.0.

**Expected**: the shipped rule's own half stands untouched (research §8).
**Evidence**: `test/reading_view_follow_test.dart` — *short text: no scroll*, unchanged as written.
**Proves FR-005, SC-003.**

### 5. **[unit]** a read started from a stored position obeys the rule from its first sentence — `FR-007`

A read that begins at a sentence below the fold (011's `FR-002` path): the position is brought into view **and** the
sentence after it, before that first sentence's own voice.

**Expected**: the first report of such a read already satisfies the rule.
**Evidence**: `test/reading_view_follow_test.dart` — the re-cut of 011's own position case, read off the same line.
**Proves FR-007.**

### 6. **[unit]** the move is minimal — `FR-003` (`SC-005`)

For each move: the sentence in force is still inside the viewport afterwards, its own top has not gone above the
viewport's top, and the page's new offset is the smallest that leaves the next sentence's read with a successor on
screen (the union rect of the sentence in force and the two after it, not a page turn).

**Expected**: the reading sentence is not carried off the top, and the page settles by one sentence at a time.
**Evidence**: `test/reading_view_follow_test.dart` — the offset and the two boxes read from the geometry the page
already reports.
**Proves FR-003, SC-005.**

### 7. **[unit]** a hand scroll stands, and a resume moves nothing — `FR-004` (`SC-004`)

Scrolling by hand during a sentence leaves the page where the reader put it (011's own `FR-005`); the same sentence
re-reported (a resume) moves nothing; the rule may fire again only at the next sentence's own start.

**Expected**: the once-per-sentence dedupe carries both halves — the reader's scroll is never fought.
**Evidence**: `test/reading_view_follow_test.dart` — *manual scroll is not undone; a resumed sentence repaints*,
re-run and extended with the rule's own firing.
**Proves FR-004, SC-004.**

### 8. **[unit]** the ▶ step's advance leaves a sentence ahead — `3A`, `FR-006` (`SC-007`)

A step's read ends, the highlight advances, and the page reveals it: afterwards the new highlight **and** a sentence
after it are at least partly inside the viewport, on the same `1B` trigger (the reveal fires at the step's own unit, so
the next press's highlight is never the last thing on screen). A press that starts a step reveals its own unit first (016's own fix of
2026-10-16) and then obeys the same rule.

**Expected**: stepping through a long text never leaves the highlight riding the bottom edge.
**Evidence**: `test/reading_view_step_test.dart` — a new case beside the walk row 15's own.
**Proves FR-006, SC-007.**

### 9. **[unit]** the evidence line carries the field the rule is about — `FR-009` (`SC-006`)

`klhu follow:` reads `p<i> s<j> visible=<0|1> top=<t> bottom=<b> viewport=<h> below=<n>`, with every existing field's
name and order unchanged, and `n` equal to the number of sentences with a box inside the viewport below the reported
one. Both parsers that read the line keep matching: the suite's `FollowLine.parse` and 011's driver regex.

**Expected**: one more field, no reordered one — a closed feature's parser reads the same numbers it always did.
**Evidence**: `test/reading_view_follow_test.dart` (the parser's own case), and `grep` of 011's driver regex.
**Proves FR-009, SC-006.**

### 10. **[device]** the walk: every non-final sentence keeps a sentence ahead of it — `SC-001`

011's own fixture (Extra large, display 1080×1000, the 8-sentence preset), its row 7 **re-walked** on this tree, and
the new row (driver key `24`) reading the extended line: **every** report for a sentence that is not the content's
last shows `below >= 1`, and no report shows the sentence being read as the bottom-most box on screen.

**Expected**: the reader's complaint is gone, measured off the app's own line — with the `before` figures (four of
seven non-final reports ending at the viewport's last pixel) quoted beside it from 2026-10-16's run.
**Evidence**: `klhu_walk_experience.py 7` and `… 24`; the reports quoted verbatim in `breakpoint.md`.
**Proves SC-001.**

### 11. **[device]** the last sentence and a fitting text move nothing — `SC-003`

On the same device: the read reaches the content's last sentence with `below=0` and no movement, and a text that fits
the area produces a whole read with no movement at all — **the new row (driver key `25`)**, which reads the shipped
preset at the display's own size and the app's own appearance (the reading area measures 657 logical px against the
text's own 198, so nothing can scroll): every sentence sits inside the area at once, and the highlight walks **down the
page** (its own top row 472 → 628 → 680 → 840 device px) while the page's offset stays put.

**Expected**: the exception the reader stated is what the device shows.
**Evidence**: `klhu_walk_experience.py 24` (the last sentence's own report) and `… 25` (the fitting text, walked);
011's own short-text case unchanged. Both runs printed in `breakpoint.md`.
**Proves SC-003.**

### 12. **[structural]** the tree, and what must not have moved — `FR-008` (`SC-006`)

`flutter analyze` clean; the suite's count against this tree's closing number, decomposed by file (011's two re-cut
cases, the new cases in two suites); the four ARBs at the **same** key count with `flutter gen-l10n` reproducing the
tree's Dart (no string was added); `git status --short android/ ios/` empty; `git diff --stat
lib/video_pictures.dart lib/video_timeline.dart lib/video_painter.dart` empty.

**Expected**: a Dart-only change on one page — no key, no state, no platform, the video untouched.
**Evidence**: the commands' own output, quoted.
**Proves FR-008, SC-006.**
