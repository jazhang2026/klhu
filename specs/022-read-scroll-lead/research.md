# Research: The page keeps something ahead of the read

Grounding done before the plan, on the tree as it stands on 2026-10-16. Each item is a fact this plan rests on, with
the command or the line it came from.

## §1 — What the app does today, measured (the spec's own basis, re-taken here)

011's walk row 7 was re-run on this tree (`emulator-5554`, Extra large, display 1080×1000, 011's 8-sentence preset):

```
klhu speak: 8 utterances | klhu follow: 8 reports | 5 frames | viewport=196 logical
klhu follow: p0 s0 visible=1 top=3   bottom=31  viewport=196
klhu follow: p0 s1 visible=1 top=37  bottom=65  viewport=196
klhu follow: p1 s0 visible=1 top=105 bottom=167 viewport=196
klhu follow: p1 s1 visible=1 top=134 bottom=196 viewport=196
klhu follow: p1 s2 visible=1 top=134 bottom=196 viewport=196
klhu follow: p2 s0 visible=1 top=168 bottom=196 viewport=196
klhu follow: p2 s1 visible=1 top=100 bottom=196 viewport=196
klhu follow: p2 s2 visible=1 top=134 bottom=196 viewport=196
RESULT: PASS
```

- **Four of the seven non-final sentences** were reported with `bottom=196` — the viewport's own last pixel — so the
  sentence being read was the bottom-most thing on screen while it was spoken. That is the complaint, in the app's
  numbers.
- **Every report reads `visible=1`.** 011's own rule (`FR-003`: never scroll while the sentence being read is fully
  visible) is satisfied *at every sentence*, which is why this feature is a new rule and not a defect report: the two
  questions are different ones (§8).
- The fixtures' sentences measure ~28 px against a 196 px area, so the area holds ~7 sentences: the rule is
  satisfiable here with room to spare, and the walk's fixture can show both a satisfied and an unsatisfied report.

## §2 — The `viewport` number disagrees with 011's own receipt, and neither is inherited

011's `breakpoint.md` quotes `viewport=209` for the same row on the same fixture; today's run reads `196`. **Nothing
in the tree was changed between the two runs that a reader could point at** (011 closed on 2026-10-12, and the page's
own reading area has been re-cut by 016, 017 and 019 since). The plan's rule: the walk's **first action is to re-take
the baseline** and the new rows quote their own run — a figure inherited from a receipt taken weeks ago would be a
number nobody measured on the tree it is used to judge.

## §3 — The rule already has its own "once per sentence" guard, and it is not new

`_followRead` (`lib/reading_view.dart:1147`) compares `gen`, `paragraph` and `sentence` before it measures anything,
and returns when all three are the same as the last report. So:

- the lead fires **once per sentence**, at that sentence's own start — which is exactly what the spec's `FR-004`
  needs and what keeps a hand scroll standing (011's own `FR-005`);
- a **resumed** sentence re-reporting itself (011's D9: "re-reporting must not move the page") is ignored by the same
  three fields, so the new rule cannot drag the page back on a resume either;
- no new guard, no new field, no new state is needed for either.

## §4 — The next sentence's box is measurable while off screen: the whole text is one paragraph

`_measureSpan` (`:1209`) measures through `_textKey.currentContext.findRenderObject()` and `getBoxesForSelection` on
that single `RenderParagraph` — the page's own rendering of the text (015's tags removed for display, mapped back for
content offsets). A sentence **below the fold** is therefore measurable before anything scrolls, which is what makes
D2 possible at all. This is the assumption the plan's own first checkpoint tests: if the page ever renders one widget
per paragraph, the lead's measurement stops being available off screen and the plan says so rather than assuming it.

## §5 — "Before the voice" is reachable, and the reveal's own window is 200 ms

`lib/reader_service.dart:37` documents `onSentenceStart` as firing "once per sentence, **immediately before that**"
sentence is spoken; the call is at `:570` and the `await _tts.speak(unit.text)` at `:594`. So the page is told about a
sentence **before** the engine is asked to speak it, and acting in that callback is acting before the voice — which is
what `FR-002` needs and what the reader's own words ("start the auto scroll before highlight/read last sentence on
screen") describe.

The reveal itself is animated: `_revealDuration = Duration(milliseconds: 200)` (`:1137`), handed to
`showOnScreen(duration:)`. So "the move started" and "the page has settled" are different moments ~200 ms apart; the
spec's Clarifications 1 first recorded that window as the one place `1A` is weaker than the reader's own words.
**2026-10-16, later the same day: the reader restated the requirement unchanged ("This is not changed."), so the window
is refused as the design and the trigger moved one sentence earlier (`1B`).** The consequence for this section is the
one that matters: firing at the **previous** sentence's start is still firing before *its* voice (the seam is the same
one), and the 200 ms reveal now runs while that previous sentence is read — so the page has settled by the time the
last-visible sentence is highlighted, which is what the reader's own words ask for.

## §6 — The step's own reveal is today's fix, and the lead lands on the same helper

The ▶ press did not reveal the unit it was about to read (`_readSelection` read with `step: true` and no tracking, so
no sentence report ever reached the follow; the only reveal was `_advanceStep`'s, after the sentence). That was fixed
the same day as this stage's own work, with its own case and device row, in `specs/016-sentence-reading`'s record
(Amendment, T035). Consequence for this plan: `3A` has **one** place to land (`_revealLead`, D5), and its prerequisite
is already in the tree — the walk's row 15 is re-run after this feature lands (plan's "what this re-measures").

## §7 — Two parsers read the line this feature extends

`klhu follow:` is parsed in two places, and both are regex-shaped, so an **appended** field keeps them matching:

- `FollowLine.parse` (`test/reading_view_follow_test.dart:677`) — the follow suite's own reader, whose fields are
  asserted per case (`visible`, `top`, `bottom`, `viewport`);
- 011's own walk driver (`specs/011-reading-experience/scripts/klhu_walk_experience.py`, `follow_lines()`) — the
  regex `p(\d+) s(\d+) visible=(\d) top=(-?\d+) bottom=(-?\d+) viewport=(\d+)`.

The plan therefore appends `below=<n>` and re-runs both; it does **not** reorder a field, because a changed order
would make a closed feature's parser read the wrong number silently rather than fail.

## §8 — 011's `FR-003` is not in conflict with this feature; the two ask different questions

011's `FR-003` forbids a scroll while the sentence being read is already fully visible, and its scenario 3 says a text
that fits never scrolls. The measured reports in §1 show the shipped rule being satisfied while the reader's own
complaint holds — because the reader's question is *what is visible after it*, which 011's rule never asked. So:

- the **text that fits** half of `FR-003` stands untouched (nothing to scroll, and the rule is satisfied by the
  sentences that follow the reading one on screen anyway);
- the **"already fully visible"** half is narrowed in exactly one case: when that sentence is also the last one
  visible. Recorded in 011's own spec, dated, with a pointer in its `tasks.md` — 011's artifacts are left as written.
- 011's `SC-001` ("no sentence is spoken out of sight") stays true and stops being sufficient; the stricter criterion
  is `spec.md`'s `SC-001`.

## §9 — Nothing else in the tree needs to move

- **The strings**: no new copy — the page already has every word it shows; the four ARBs are untouched, so no key count
  moves (021's own slot-19 lesson about totals is not triggered).
- **The state**: no new stored key — the rule is evaluated while a read plays and remembered nowhere.
- **The platform**: no plugin, no manifest, no Android/iOS file.
- **The video**: 012's schedule has no viewport notion, and the review page's own playback does not follow sentences.
- **The read**: voices, order, pauses and the comment rule are untouched; the page may not delay the voice (`4A`).
