# Data model: What the rule is a relation between

**Feature**: `022-read-scroll-lead` | **Date**: 2026-10-16 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

**Purpose**: this feature stores nothing and adds no entity. What it needs is a precise statement of the **relation**
the rule tests while a read plays, and of the one thing the app must report about it. Both are written here because the
implementation's whole risk is in the relation being read off the wrong pair of boxes.

## The values in play, and where each comes from

| value | type | source | notes |
|---|---|---|---|
| the sentence in force | `SpokenSentence` (`paragraph`, `sentence`, `start`, `end`) | the reader's own report, fired at each sentence's start (`lib/reader_service.dart:37`) | the unit 011's follow already measures and the highlight already paints — **one** unit, not a block |
| its own box | `_SentenceGeometry` (`lib/reading_view.dart:1274`) — `rect`, `top`, `bottom`, `viewport`, `visible`, `paragraph` | `_measureSpan(spoken.start, spoken.end)` | `top`/`bottom` are distances from the viewport's own top edge; `viewport` is the visible area's height; `visible` says the box is **wholly** inside |
| the next sentence's own box | the same shape, for the sentence **after** the one in force | `_measureSpan(next.start, next.end)`, where `next` comes from the same list the read was resolved from (`sentenceRanges`/`stepRanges`) | measurable **before** any scroll, because the whole text is one `RenderParagraph` |
| the reveal's own rect | `Rect`, in the paragraph's coordinate space | `Rect.fromLTRB(…, current.top, …, next.bottom)` | what `_scrollIntoView` hands `showOnScreen`; the move is exactly the smallest one that satisfies the rule |
| the viewport's own bottom | `geometry.viewport` | the same measurement | the line the rule is compared against |

## The relation, in one sentence

> While a read plays, **the sentence in force is not the bottom-most sentence box on screen** — unless it is the
> content's last sentence, or nothing follows it in the resolved read.

## Invariants

- **INV-1** (the rule): at the moment a sentence becomes the sentence in force, either a sentence **after** it has a
  box at least partly inside the viewport, or the rule does not apply (the content's last sentence; a read with
  nothing after it; a text that fits in the visible area).
- **INV-2** (the timing, `1B`): the rule is evaluated at the start of the sentence **before** the one that would be the
  last visible — the same callback the app fires immediately before the engine speaks that sentence — so the move has
  started before *that* sentence's voice and has **settled** before the last-visible sentence's highlight lands. A move
  that begins at or after that highlight is not this rule (the window Clarifications 1 first accepted was refused by the
  reader on 2026-10-16).
- **INV-3** (minimality): the move is the smallest one that makes INV-1 true **one sentence later** — the union rect of
  the sentence in force, the sentence after it and the sentence after that, so that when the next sentence becomes the
  sentence in force, a sentence after *it* is already visible. It never carries the sentence in force above the
  viewport's own top, never turns a page, and never moves when the next-next sentence is already on screen.
- **INV-4** (once per sentence): the rule fires at most once per sentence, at that sentence's own start. A scroll the
  reader makes during the sentence stands until the highlight moves on (011's own rule), and a resumed sentence
  re-reporting itself moves nothing.
- **INV-5** (nothing is remembered): the relation is evaluated while the read plays; no offset, no lead and no state
  about it is stored anywhere, and no message key is added.
- **INV-6** (what the app must report): the app's own evidence line carries, for the sentence it reports, **how many
  sentences' boxes are inside the viewport below it** — the fact the rule is about, readable off the device by a
  walked row. The line's existing fields keep their names and their order (`p`, `s`, `visible`, `top`, `bottom`,
  `viewport`), and the new one is appended (`below`).

## What this model refuses

- **A distance from the bottom edge** ("scroll when the sentence is within N px of the bottom"): it needs a constant
  nobody can justify, and it cannot express the content's own exception (the last sentence is *always* near the
  bottom). The rule is positional (INV-1), not metric.
- **A count of sentences** ("keep at least three sentences visible below"): it costs a measurement per sentence and
  answers a different question than the reader asked; a viewport that holds two sentences would be unsatisfiable.
- **A stored lead**: a persisted "how far ahead the page keeps" would be state this feature does not own (the
  appearance settings are 011's) and would have to be migrated; INV-5 refuses it.
- **Reading the rule off the paint**: what the viewport clipped is the layout's own business behind the framework's
  reveal; the model reads boxes, not pixels, and the *walk* reads the paint as evidence that the boxes were right.
