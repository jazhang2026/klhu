# Implementation Plan: Sentence-by-sentence reading

**Feature**: `016-sentence-reading` | **Spec**: [spec.md](./spec.md) | **Date**: 2026-10-09

**Grounding revision**: `409ffe1` — every site below was read on that tree, not from memory. (This section is
the research trail for this change; there is no separate `research.md` because the spec already carries the
four decisions with their costs, and what follows is the code those decisions land on.)

## 1. What today's code does, site by site

| What | Where | What it does |
|---|---|---|
| ▶ Read | `lib/reading_view.dart:1055-1059` (`_readSelection`) | `_highlight == null` → the hint `selectToReadMessage` and **return**; else `_readRange(seg.start, seg.end)` — no `track` |
| ⏭ Continue Read | `:1064-1066` (`_readContinue`) | `_readRange(_anchor ?? 0, _content.length, track: true)` |
| The shared read | `:1077-1112` (`_readRange`) | resolves speeches over `[start, end)`; an empty range is answered with `nothingToReadMessage` (`:1093-1097`); prints `klhu read range: start..end` (`:1102`); installs the per-sentence callback **only** when `track` (`:1108-1109`) |
| The tracking highlight | `:1123-1129` (`_onSpokenSentence`) | paints exactly the spoken sentence, then reveals it (`_followRead`) |
| The read's **end** | `:1243-1252` (`_runRead`'s `finally`) | on a natural end (same generation, still `speaking`) → `_mode = read`, `_highlight = null`, `await _clearAnchor()` — 011 FR-022 |
| Stop | `:1257-1270` (`_stop`) | the same clearing |
| The selection a gesture sets | `:1003-1014` (`_resolveAt`'s tail) | `_segmentAt(...)` → `_highlight` + `_anchor` → `_persistAnchor()` |
| The position | written `:1023-1038` (`_persistAnchor`), cleared `:547-553`, restored `:532-543` | `(offset, charCount)` — the record 011's row 23 reads as `(anchor, the text's length)` |
| The sentences themselves | `lib/segmenter.dart`'s `sentenceRanges` | cut **per paragraph** since 011's 2026-10-09 amendment — the rule FR-006 leans on, and the reason 016 lands after it |
| A comment's own span | `lib/speech_resolver.dart:190` (`_withComments`) | a comment is spoken **only when the read's range covers the comment's own span** — see §3, this is the one that bites |
| The comment's place | `lib/speech_resolver.dart:170-221` | one `ParagraphSpeech` per comment, `isComment: true`, merged just before the first speech starting at or after its tag |

## 2. The approach

**2.1 ▶ reads a step.** `_readSelection` gains the branches FR-001/FR-003 ask for, and the selection code the
gesture already uses (`:1004-1014`) is factored into one helper, `_select(TextSegment)` — the gesture and ▶
must set the highlight and the anchor the same way (**corrected 2026-10-12 by the implementation**: the helper
does *not* write the record — decision 5 retires it in §3.7, so `await _persistAnchor()` stays at the gesture's
own call site until that pass removes it):

- `_highlight == null` → `_select(firstSentence)` (FR-001), where `firstSentence` is
  `sentenceRanges(_content).first`; then read it.
- `_highlight` is a **sentence** → read `_highlight` (FR-002).
- `_highlight` is a **paragraph** → read it and stop (FR-003); the stepping rule does not apply to it.

**2.2 The read learns what it is.** `_readRange(start, end, {track = false, step = false})`. A step needs
neither `track` nor any new callback: **the range of the step is itself the record of what was read**, so the
next sentence is computable from it (§2.3). `track` stays `false` for ▶ — today's behaviour, and a one-sentence
highlight has nothing to follow. The alternative (turning tracking on for ▶ and reading the last
`SpokenSentence` instead) is noted in §5: it changes what a paragraph press paints while it plays, for no gain.

**2.3 The advance lives in the read's end.** In `_runRead`'s `finally`, when the read ends naturally:

- `step == false` (today's ⏭) → **unchanged**: `_highlight = null` + `_clearAnchor()`.
- `step == true` → look for **the next sentence**: the first range of `sentenceRanges(_content)` whose `start`
  is at or after the step's own range end. Found → `_highlight = next`, `_anchor = next.start` — **in memory:
  nothing is written to disk (FR-007)** — and reveal it (FR-012). Not found → `_highlight = null`,
  `_anchor = null` and **nothing shown at all** (FR-008 — the reader's own *no message* correction of
  2026-10-09; §2.5 owns that, and `nothingToReadMessage` stays where it is). The tap's own written record is
  not this path's business because §3.7 retires it with the store; what the tap leaves in force inside the
  session is the `_anchor` this path moves on.

**Nothing is written to disk at all** (decision 5, the reader's choice): the step's advance and the tap's own
`_persistAnchor()` stop writing together, and the restore path goes with them — the write path is removed in
§3.7 rather than left writing a record nothing reads.

The step's range end must be **the whole step** — see §3.1.

**2.4 The reveal gets its own seam.** `_followRead(gen, spoken)` takes a `SpokenSentence` (paragraph/sentence
indices plus offsets); the advance has only a `TextSegment`. The part that scrolls the range into view is
factored out (`_revealRange(TextSegment)`) and `_followRead` calls it, so both paths reveal by the same code
and 011 FR-002 cannot drift from FR-012.

**2.5 The end of the text** is FR-008's branch of §2.3 — clear, and **say nothing**: an unhighlighted page is
the message, and no string is added. `nothingToReadMessage` stays where it is (an empty *range*, `:1095`,
`:2023`, `:2149`) and is not reused for this.

**2.6 The message key goes.** `selectToReadMessage` is used at exactly one place, `lib/reading_view.dart:1062`,
which §2.1 removes. Delete it from `app_en.arb` + the three translations, run `flutter gen-l10n`, commit the
regenerated Dart. The app's key count is **108 → 107**, which is 015's row 16's number: that receipt is
corrected with its date in 015's own record (its rule, not this one's exception).

## 3. Ripple — what else touches these, and what must not move

**3.1 The comment sits outside its sentence's span — a step scoped to the sentence alone would drop it.**
`_withComments` speaks a comment only when the read's range covers `comment.contentStart..contentEnd`
(`lib/speech_resolver.dart:190`), and a comment's own span begins after its sentence's last character. So
`_readRange(sentence.start, sentence.end)` reads the sentence and **silently loses the comment**, breaking
FR-005. The step's range must therefore be **the step, not the sentence**: the sentence, extended over its own
comment's span when the sentence is that comment's owner. That needs one small helper next to 015's rule —
`stepEnd(content, commentsRead, sentence)` returning the sentence's own end or its comment's `contentEnd` — and
the advance's search key becomes *that* end, so the next step starts at the sentence after the comment, not at
the comment's first character.

**It needs a second helper as well, and the implementation found it (corrected 2026-10-12):** a raw
`sentenceRanges(_content)` over the *tagged* text holds a range **inside** the comment (`Hola. [注] Hi.` yields
`[注] Hi.`), and for a comment-headed text the list's first range is the comment's own characters — whose tag
would then reach the engine, which 015 FR-005 forbids. A `>=` search off `stepEnd` cannot repair that either:
the first press takes the list's first range, not a search. So `lib/comment.dart` also gains
`stepRanges(text)` — the app's own sentence ranges minus the ranges a comment's characters occupy, which is also
what makes the first step of a comment-headed text the sentence after the comment (016 T003/T010).

**3.2 The paragraph press keeps its meaning.** A long-press selection reads its paragraph and stops. It uses
`step == true` for the "do not clear" half of FR-004 only; its advance is a no-op because the unit is the
paragraph (FR-003). Stated here so the branch is deliberate rather than incidental.

**3.3 ⏭ is untouched.** FR-007's scope is a step's own highlight; `_readContinue` keeps `track: true,
step: false`, keeps reading to the end, and keeps dropping the highlight and the position when it ends
(011 FR-022, which 016 narrows for a step only). The shipped case that asserts exactly that —
`test/reading_view_continue_test.dart`'s *"tracking follows the read, and the read takes the position with
it"* — is a ⏭ case and **stays as it is**.

**3.4 A stale read cannot advance.** The `finally` already guards on `gen == _readGen`; the advance goes
behind that guard, so a tap or Stop that started a newer read cannot be followed by an advance from the old one.

**3.5 A paused read ends like any other.** The `finally` leaves the mode alone when the read was parked; when
the parked sentence is resumed and finishes, the same branch runs — FR-010, no special case.

**3.6 014 and 015 do not move.** The resolution is `resolveSpeeches`' own: in 多人对话 a step is one sentence of
a turn in its role's voice, and a comment rides its sentence in both text types. The only change is the range a
step asks for (§3.1).

**3.7 010's stored position retires — decision 5's own ripple, and the one place this spec reaches outside its
feature.** The record's whole life goes, not the step's half of it: `_restoreAnchor` (`:532-543`, called at
`:525`), `_persistAnchor` (`:1023-1038`) and the call the gesture makes to it (`:1014`), the `read_position_*`
key, `lib/read_position_store.dart` (its `ReadingPosition` at `:11` and its store, **`ReadPositionStore`** at
`:38` — the store class the plan's first draft called "the `Positions` store`") and that store's own 11 cases
in `test/read_position_store_test.dart` — a record nothing restores is dead code, and this repo does not keep
dead code. What stays is `_anchor`: the position **inside** the session, which no store ever carried.

**The ripple is wider than the two rows this section first named; corrected 2026-10-12 by the tasks stage
after reading the tree** (its full enumeration with line numbers is `tasks.md` § The stage's corrections item
1, and T016-T022 are the work):

- **Six shipped test files**, not two: the store's own file (deleted with its subject), `test/video_aspect_test.dart`
  (`:11` and its `:85-96` namespace case call `ReadPositionStore.keyFor` — a **compile error**, so the file
  cannot even load until it is re-cut), `test/reading_view_continue_test.dart` (the restore group `:441-...`
  and the four record-clearing cases `:494`/`:521`/`:545`/`:565`), `test/reading_view_follow_test.dart:405`
  (which seeds the record), `test/reading_view_dialogue_test.dart:250` (`expect(afterTap, isNotNull)`), and
  `test/reading_view_comment_test.dart:273`/`:290` with `test/reading_view_new_content_test.dart:195`/`:211`.
  `test/appearance_store_test.dart:81` names the prefix as a literal and **stays unmodified**.
- **Two doc comments** naming the retired type: `lib/appearance_store.dart:132`, `lib/video_aspect.dart:54`
  and `:65`.
- **Four more features' records** besides 010's and 011's: `specs/010-continue-read/contracts/read-position-format.md`
  (the contract itself, retired at its head), `specs/011-reading-experience/contracts/appearance-format.md:23`/`:28`/`:51`,
  `specs/014-dialogue-reading/` (its breakpoint rows citing `read_position_dialogue_fixture` at `:386`, `:408`,
  `:413`, `:416`, `:420`, `:421`, `:425`, `:426`, `:429`, plus `specs/014-dialogue-reading/data-model.md:257` and
  `specs/014-dialogue-reading/quickstart.md:353`),
  and `specs/015-comment-tag/data-model.md:180`.

010's FR-008 ("the position survives a restart") is amended in **010's own record** with its date, and 010's
rows 9 (`the position survives a restart`) and 14 (its device re-run), with 011's row 8's restore half, become
false and are re-cut as that amendment's rows rather than deleted quietly. A receipt that only **cited** the
record keeps its behaviour and gains a dated note (014's rows prove a tap anchors a sentence and a read
continues from it — both still true; only the line they read it off moved).

**011's FR-022 is the second place the wording goes stale**: its last clause — "a position outlives a restart
only while its highlight is up when the app is left" — becomes false, because under decision 5 a position never
outlives a restart at all. Its condition (the highlight is what keeps the position in force) still holds, so
the clause is replaced, not the FR: 011's record carries that dated line in the same pass as 010's.

**3.8 Nothing else in 010 moves.** Setting the position (FR-002), ⏭ reading from it (FR-004) and the
first-sentence fallback (FR-005) are all in-session behaviours: they stay, and FR-005's fallback is now also
what a launch does.

## 4. Tests and rows

**New unit/widget cases** (`test/reading_view_continue_test.dart` for the read's shape, or a new
`test/reading_view_step_test.dart` if the group grows past a handful — this feature takes the new file):

1. N presses of ▶ read sentences 1..N in order, one per press (SC-001).
2. After each press the highlight is the next sentence; after the last, nothing is highlighted and **nothing is
   shown** — an unhighlighted page is the whole message (SC-002, FR-008; the reader's own 2026-10-09
   correction, §2.5).
3. A paragraph-selected ▶ reads the paragraph and leaves the paragraph highlighted (FR-003).
4. A content whose sentence carries a comment reads both in one press (§3.1 — the case that fails if the range
   is not extended), and the next press starts at the following sentence (SC-004).
5. ⏭ after a step reads only the sentences not yet read, to the end (SC-003).
6. A relaunch restores **nothing** — no highlight, no position — after a step **and** after a tap (FR-007,
   decision 5), and ⏭ then starts at the first sentence. The shipped cases that asserted a round-trip
   (`test/reading_view_continue_test.dart`'s restore group) are re-cut as 010's amendment, not deleted quietly.
7. The store is gone with it: no `read_position_*` key is written by either path, and the types behind it leave
   the tree (§3.7).

**Shipped cases re-cut** (each named, because a case that asserted the old rule must be seen to change):
`test/reading_view_test.dart:199` "Read with nothing selected asks for a selection" (assertions at `:225-226`),
`test/reading_view_test.dart:229` "Read after a stop asks for a selection again" (`:263-264`) and
`test/reading_view_edit_test.dart:195` "Read speaks the pending sentence, and asks for one when there is none"
(`:217-218`) — three `findsOneWidget` cases that assert ▶ shows the warning. They become "▶ reads the first
sentence". The `findsNothing` cases beside them (`test/reading_view_edit_test.dart:223`,
`test/reading_view_video_test.dart:558`) stay.

**And the record's retirement takes five more shipped files with it** — corrected 2026-10-12 by the tasks
stage, which found §3.7's list short (see that section and `tasks.md` § The stage's corrections item 1):
`test/video_aspect_test.dart` (`:11`'s import, `:85-96`'s namespace case — a **compile error** once
`ReadPositionStore` leaves the tree), `test/reading_view_continue_test.dart` (the restore group `:441-...`,
which asserts the round-trip this feature retires, plus the record helpers at `:180`, `:453`, `:471`, `:484`),
`test/reading_view_follow_test.dart:405` (a case that **seeds** a `read_position_*` record and asserts the view
restores it), `test/reading_view_dialogue_test.dart:250` (`expect(afterTap, isNotNull)`), and
`test/reading_view_comment_test.dart` (`:273`, `:290`) with `test/reading_view_new_content_test.dart` (`:195`,
`:211`). `test/reading_view_continue_test.dart:302` — ⏭'s own case in §3.3 — is **not** touched, and neither is
`test/appearance_store_test.dart:81`, which names the prefix as a literal rather than through the store.

**Device rows** — quickstart additions and re-walks:

- A new row for the stepper on the reader's own shape (a title with no full stop over a punctuated paragraph is
  011 row 23's fixture and can be reused): press ▶ three times and read the app's own `klhu read range` and
  `klhu speak` lines for each press, plus the highlight's rows from a screenshot; then a fourth press and the
  end-of-text message.
- A row for the comment half (a content with a comment): one press reads the sentence **and** its comment.
- 011's rows 7, 8, 10, 20 and 010's 13-16 re-walked: the stepper touches the same highlight, position and
  follow machinery they measure — and **010's rows 9 and 14 are re-cut**, since "the position survives a
  restart" is what decision 5 retired; 011's row 8 keeps its off-screen-reveal half and loses its restore half
  as the same amendment's business.
- 012's render-from-a-position path (`lib/video_timeline.dart:128`) gets its first row here as a side effect: a
  step's position is a non-zero position, which is the case 011's amendment left unwalked.

## 5. Risks and the parts that are genuinely hard

1. **The comment's span outside its sentence's own** (§3.1) is the one that would ship a feature that drops the
   very thing 015 added, silently, on exactly the texts that use it. It is the first thing to write a test for.
2. **The advance's search key.** Getting "the next sentence" from the step's end rather than the sentence's end
   is easy to get wrong when a comment sits between two sentences of one paragraph (015 allows it), or when a
   paragraph's last sentence is followed by another paragraph. Both are cases to pin in §4's case 4.
3. **FR-022's narrowing is the load-bearing change.** A reader who stops pressing is left with a highlight that
   never clears — which is what FR-022 was written to prevent. The mitigation is that Stop, an edit, leaving the
   page and the end of the text all still clear it, and that a step survives only the session: a relaunch shows
   nothing (FR-007, the reader's own correction). The risk is that some later reader finds the old rule quoted
   in a row and reads the highlight's persistence as a bug.
4. **010's stored position is retired, and that is the largest thing here** (§3.7, decision 5). It is a
   deletion, not a narrowing: the record, the store and the restore path leave the tree, and 010's rows 9/14
   plus 011's row 8's restore half have to be re-cut as 010's own dated amendment. The risk is doing it quietly —
   a feature the reader once asked for ("Continue Read remembers where you were") disappears, and the only honest
   way to record that is in 010's spec and breakpoint, beside the ask that reversed it.
5. **The reveal seam** (§2.4) is where 011's follow machinery and this feature meet; if it is not factored out,
   a step's next sentence can be off screen while the highlight is on it, and the reader presses a key aimed at
   something they cannot see.
6. **Tracking for a step** — the alternative design of §2.2 (turn `track` on for ▶) would also paint the
   paragraph press's sentences one by one while it plays. It is not needed for the advance, and it changes a
   behaviour the reader has today; taken: not doing it.
7. **The key count** (§2.6) is the only number this spec moves outside its own record, and the spec says where
   it is corrected.

## 6. Out of scope

As spec.md lists it: auto-advance on a timer; ⏭'s meaning; the video and the editor beyond a position's normal
life; the sheet, the picker, removed roles and 015's comment switch.
