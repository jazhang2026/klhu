# Data Model: Reading Experience

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Decisions**:
[research.md](./research.md) D1–D12 | **Date**: 2026-09-24

Three things this feature introduces, one of which is persisted — plus one shipped value it **changes**
(the tracking highlight, now the spoken sentence rather than the spoken paragraph, per the 2026-09-24
amendment) and two it reads but leaves alone (the Continue Read position, the library entry a Save
creates).

---

## 1. ReadingAppearance *(new, persisted)*

**Purpose**: the typeface and character size the reading text is rendered in, remembered per device
(spec FR-006–FR-011). It is view state, not content: one choice covers every text, every language and
every interface locale.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `typeface` | `String` — one of `default`, `serif`, `mono` | no | stored (contract `appearance-format.md`); unknown value → `default` |
| `size` | `String` — one of `small`, `medium`, `large`, `xlarge` | no | stored; unknown value → `medium` |

Derived, not stored: the platform font family (`default` → none, `serif` → `serif`/`Times New Roman`,
`mono` → `monospace`/`Courier New`) and the point size (`small` 12, `medium` 14, `large` 18,
`xlarge` 24 — `medium` is the shipped `bodyMedium`, so the default rendering is what the app shows
today).

**Relationships**: none. It is keyed by nothing — not by content, not by language, not by locale
(unlike `ReadingPosition`, which is keyed per content).

**Validation rules**

| Rule | Requirement |
|---|---|
| A `typeface` outside the offered set is treated as `default`, without an error | FR-011 |
| A `size` outside the offered set is treated as `medium`, without an error | FR-011 |
| The applied style reaches the reading text in READ and EDIT, and nothing else | FR-009 |
| The chosen value is read back after a restart | FR-010 |

**Worked example**: the user picks Serif + X-Large in Chinese; the stored record is
`reading_typeface = serif`, `reading_size = xlarge`; on the next launch the reading text paints in
`NotoSerif-Regular.ttf` at 24 pt, the app bar and buttons are untouched.

**States**

```
absent ──(load returns nothing / malformed)──▶ default (default/medium)
   │
   └──(a confirmed choice is written)──▶ chosen ──(a later confirmed choice)──▶ chosen
```

---

## 2. AppearanceDraft *(new, in memory only)*

**Purpose**: the candidate selection inside the appearance screen, so the text can be previewed
before anything is remembered (FR-008, US2 scenarios 1–4).

**Attributes**: `typeface` and `size` (same domains as `ReadingAppearance`), initialised from the
appearance in force.

**Validation rules**: a draft never reaches storage on its own; only a confirm does (FR-010).

**States**

```
opened(current) ──change a row──▶ previewing ──change a row──▶ previewing
       │                               │
       │                               ├──confirm──▶ popped draft ──▶ written (ReadingAppearance)
       └─────────back / dismiss────────┴───────────▶ popped nothing ──▶ nothing written
```

---

## 3. FollowTarget *(new, in memory only, one per read)*

**Purpose**: which sentence the read is on and whether the page can see it — what the follow routine
reads every utterance and what the evidence line reports (FR-001–FR-005).

**Attributes**

| Name | Type | Source |
|---|---|---|
| `generation` | `int` | the read's generation at the view (`reading_view.dart` `_readGen`) |
| `paragraph` | `int` | the service's utterance index |
| `sentence` | `int` | the service's sentence index inside that paragraph |
| `start` / `end` | `int` | absolute offsets into the content, from `sentenceRanges` (research D2) |
| `visible` | `bool` | measured after the reveal settles (research D3) |
| `top` / `bottom` / `viewport` | `int` (logical px) | measured box in viewport coordinates and the viewport's height |

**Derived**: the reveal rect (the sentence's box in the paragraph's own coordinates).

**Validation rules**

| Rule | Requirement |
|---|---|
| `0 <= start < end <= content.length` for every reported sentence | FR-001 |
| A sentence already fully inside the viewport is not scrolled to | FR-003 |
| The same `(generation, paragraph, sentence)` is followed at most once | FR-005 |
| Nothing is scrolled when the read ends, is stopped or is paused | FR-004 |

**Invariants a test can assert**

1. For a text that fits the viewport, the scroll offset is `0` for the whole read, and every reported
   target is `visible` with no reveal requested.
2. For a text longer than the viewport, after the read ends every reported target is `visible` and
   `0 <= top < bottom <= viewport` at the moment of its report.
3. A manual scroll during a sentence leaves the offset at the user's value until the next sentence's
   report; the next report moves the page at most to reveal that next sentence.
4. Offsets reported for a resumed read are inside the content and never decrease within one
   generation (the queue only advances, `reader_service.dart:319-374`).

---

## 4. DraftContent *(new, in memory only)*

**Purpose**: the blank, unnamed page the contents list's "+" starts (FR-015–FR-019).

**Attributes** (the page's existing state, in its draft form)

| Name | Value while drafting | Meaning |
|---|---|---|
| `_content` | `''` | nothing to read yet |
| `_loaded` | `null` | no library entry: a Save creates one (`saveEdited(null, …)`) |
| `_anchorKey` | `null` | no name yet, so no position can be written for it (`_persistAnchor` returns early) |
| `_anchor` | `null` | no start position |
| `_mode` | `edit` | the only state in which the page accepts typing |
| `_editController.text` | `''`, focused | the field the user types into |

**Validation rules**

| Rule | Requirement |
|---|---|
| Save creates a new entry with an auto-generated name, no name prompt | FR-017 |
| Save with empty or whitespace-only text is refused with the existing message, and creates nothing | FR-018 (with 008's rule) |
| Leaving without saving creates no entry and leaves the library unchanged | FR-019 |
| The content that was on screen before the "+" is unchanged, including its stored position | FR-019 |

**States**

```
requested ──page resets + EDIT──▶ drafting ──Save or Done (non-empty)──▶ entry created (auto-named)
                                     │                                        │
                                     ├──back through the library (Discard)──▶ abandoned (nothing created)
                                     └──Save (empty)──▶ refused, still drafting
```

Done and Save both persist: the check icon leaves the editor, so it saves the changed text first (an
empty text has nothing to save and is allowed to leave, leaving the stored entry's own text alone; any
other refusal keeps the editor open with its message). Only leaving a draft *without* saving it — back
through the library's unsaved-changes guard — creates nothing (FR-019).

**Worked example**: "+" → blank page in EDIT → the user types `夜色深沉。` → Save → a row
`夜色深沉。` appears at the top of the list (`c_<epochMillis>_<4 hex>`, language `zh-Hans`) and the
page shows it in READ.

---

## 4. ReadingHighlight *(existing, changed by the amendment)*

**Purpose**: the yellow span that shows what is being read (003). Its unit changes from the spoken
paragraph to the spoken **sentence** (FR-020/FR-021); everything else about it — the colour, the
single-`RichText` rendering, clearing at the end/Stop and on editing — is unchanged.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `_highlight` | `TextSegment` (`start`, `end`, `SegmentUnit.sentence`) | yes — null means nothing is painted | the tracking callback (D2), a tap (sentence) or a long-press (its paragraph) |

**Validation rules**

| Rule | Requirement |
|---|---|
| While reading, the painted span is exactly the sentence handed to the engine | FR-020, SC-008 |
| It advances once per sentence — never a neighbouring sentence, never the whole paragraph | FR-020 |
| A resumed read re-paints the sentence it repeats | FR-021 |
| It clears at the end of a read, on Stop and on any edit | FR-020 (003's rule, kept) |
| A tap still paints a sentence; a long-press still paints its paragraph | D11 (unchanged) |

**Invariants a test can assert**

1. Driving the reader's tracking callback for sentence *k* paints exactly the text of sentence *k* —
   the assertion reads the yellow span, which is what the shipped tests already do
   (`reading_view_test.dart:574`'s probe shape).
2. The painted span and the span the follow routine measures are the same offsets (one source of
   truth: the callback's `start`/`end`).
3. After a resume that repeats the interrupted sentence, the painted span is that sentence.
4. The span is null after the read ends, after Stop, and after entering EDIT.

**Worked example**: `… First sentence. Second sentence. …` — while the engine is on "Second sentence.",
the yellow covers exactly those sixteen characters and nothing else, and the reveal rect is that same
box.

## Existing values this feature reads but does not change

- **ReadingPosition** (010, unchanged): the Continue Read record. A draft has no key, so drafting and
  leaving writes no record; the previous content's record is untouched by a `null` save
  (`reading_view.dart:405-417` clears only the previous key).
- **SavedContent / the library index** (008, unchanged): the entry a Save creates is an ordinary row
  with an auto-generated name.
