# Data Model: Reading Video

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Decisions**:
[research.md](./research.md) D1–D13 | **Date**: 2026-09-25

Six things this feature introduces — two of them persisted — plus one shipped value it **changes** (the
reading page's state machine gains RENDERING and REVIEW, whose rules are the read's own ownership rule
extended), and four it reads but leaves alone (the content, its text, the reader's appearance, the reading
position).

---

## 1. VideoAspect *(new, persisted)*

**Purpose**: the shape of the video the reader asks for before a render starts (spec FR-007, A8). One
choice per device, remembered like the voice and appearance choices, because the same reader records the
same way twice.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `aspect` | `String` — one of `landscape`, `vertical` | no | stored (contract `video-aspect-format.md`); unknown value → `landscape` |

Derived, not stored: the frame (`landscape` → 1920×1080, `vertical` → 1080×1920), the constant frame rate
(30 fps), and — from the frame — the reading column's width, its margins and the scale that maps the
reader's chosen character size onto the frame (spec A3; the smallest size must stay legible at 100 %).

**Relationships**: none. Keyed by nothing — not by content, not by language (unlike `KeptVideoRecord`,
which is keyed per content).

**Validation rules**

| Rule | Requirement |
|---|---|
| An `aspect` outside the two values is treated as `landscape`, without an error | FR-007 |
| The choice is offered before every render and pre-selected with the remembered one | FR-007, A8 |
| The choice reaches the render's frame and layout, and nothing else in the app | FR-014, A3 |
| The chosen value is read back after a restart | A8 |

**Worked example**: the reader records once as `vertical`; the stored record is `video_aspect = vertical`;
the next render offers the choice with `vertical` pre-selected and produces a 1080×1920 file whose column
is laid out for that frame.

**States**

```
absent ──(load returns nothing / malformed)──▶ landscape (default)
   │
   └──(a render is started with a choice)──▶ chosen ──(a later render)──▶ chosen
```

---

## 2. RenderPlan *(new, in memory only)*

**Purpose**: the video's timeline, built at the moment a render starts and never persisted (spec FR-004,
FR-016/FR-017, A5). It is the single source of truth for what the video contains and when, which is what
makes the result checkable frame by frame.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `aspect` | `VideoAspect` | no | the choice read at start (1) |
| `frameWidth` / `frameHeight` | `int` | no | derived from `aspect` |
| `fps` | `int` — `30` | no | fixed (spec A8) |
| `startSentence` | `TextSegment` | no | the page's position when a highlight is in force, else the content's first sentence (FR-004) |
| `slots` | `List<Slot>` — one per sentence from `startSentence` to the content's last | no | `sentenceRanges`/`paragraphRanges` (`segmenter.dart`) + the language/voice resolution the read uses |
| `titleCard` | `Slot` — a fixed lead-in slot | no | FR-008 |
| `endHold` | `Slot` — a fixed closing slot | no | FR-008 |
| `totalFrames` | `int` — Σ of every slot's frames | no | derived |
| `style` | the reader's typeface, character size, highlight colour and background | no | `AppearanceStore` + the app's theme (FR-014, A3) |

**Slot** (one sentence, or the title card, or the end hold)

| Name | Type | Nullable | Source |
|---|---|---|---|
| `paragraph` / `sentence` | `int` | no | the sentence's indices, as the tracking callback reports them |
| `span` | `(int start, int end)` | no | absolute offsets in the content |
| `language` / `voice` | `String` / voice id | no | the same resolution the read uses (FR-003) |
| `audioPath` | `String` | yes (never for a sentence slot) | pass 1's file |
| `audioMs` | `int` — the spoken length, read from the audio file's header | yes (never for a sentence slot) | pass 1 (A5) |
| `frames` | `int` — `round(audioMs × fps / 1000)` (sentence), or the fixed count (title card, hold) | no | derived |
| `startFrame` | `int` — the running total of the slots before it | no | derived |

**Relationships**: one `RenderPlan` per render; its slots are drawn from the content's segmentation, so a
content edited between renders yields a different plan and never a half-old one.

**Validation rules**

| Rule | Requirement |
|---|---|
| Slots are in reading order, contiguous in frames, and cover every sentence from the start point to the content's last | FR-004, FR-017 |
| The gap between two consecutive sentence slots is constant and within the stated bound; the lead-in and the hold are within theirs | FR-016 |
| A sentence slot's frames equal its own audio's length in frames (so the picture cannot drift from the voice) | A5, FR-016 |
| A slot's frames always show that sentence highlighted and inside the column | FR-005 |
| An empty or whitespace-only content yields no plan at all | FR-015 |

**Worked example**: the shipped English pre-set (8 sentences, 334 characters) recorded as `landscape`
starting at sentence 3. Slots 0–2 are the title card and the first two sentences… the plan's first sentence
slot is sentence 3 at frame 90 (3 s title card at 30 fps), its `frames` is `round(2140 × 30 / 1000) = 64`
for a 2.14 s utterance, and the file's last frame lands inside the end hold — not on a cut.

**States**

```
absent ──(a render starts)──▶ building (pass 1: audio per slot) ──▶ complete (every slot's frames known)
   │                                                                     │
   └──(a render starts and the content is empty)──▶ refused (no plan)     └──(pass 2 consumes it in order)
```

---

## 3. RenderedFrame *(new, in memory only, transient)*

**Purpose**: one picture the renderer produced, which is **both** what the reader watches while the render
runs and what the encoder receives (spec FR-020) — one rasterisation, two consumers, no synchronising to
get wrong.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `index` | `int` — its first frame's index in the timeline | no | derived from the slot being written |
| `repeat` | `int` — how many frames it stands for | no | how long the visual state stays unchanged |
| `image` | `ui.Image` | no | painted by `TextPainter` + `PictureRecorder` at the plan's frame size (D2) |
| `bytes` | `Uint8List` — the image, encoded for the channel | no | derived from `image` |
| `slotIndex` | `int` | no | the slot it belongs to |

**Relationships**: every `RenderedFrame` belongs to exactly one slot; Σ `repeat` over a render = the plan's
`totalFrames`.

**Validation rules**

| Rule | Requirement |
|---|---|
| The picture the reader sees during the render is a `RenderedFrame`'s image, and its bytes are what the encoder got | FR-020, SC-014 |
| A frame is produced when the visual state changes (highlight or scroll), not once per frame time | D2 (the cost) |
| A frame's highlight is the slot's sentence, and its text is inside the column with margins | FR-005, FR-006, SC-003/SC-004 |
| The frame's text is the reader's typeface and size, mapped to this frame | FR-014 |

**Worked example**: a 4-second sentence at 30 fps where the highlight moves twice and the page scrolls once
produces three `RenderedFrame`s (repeats 12, 74, 34 = 120 frames), so the encoder writes four seconds of
frames from three rasters.

**States**: created on a state change → consumed (previewed and sent) → released. Nothing persists past the
render.

---

## 4. KeptVideoRecord *(new, persisted)*

**Purpose**: which content owns which kept video (spec FR-011/FR-012/FR-022), so a video the reader kept is
reachable again for playing, sharing or deleting, and so "one video per content" has something to be
enforced against.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| key | `String` — the content's own key | no | the same keying the read position and the library already use |
| `displayName` | `String` — the name the file carries in the library | no | taken from the content's name (FR-011) |
| `uri` | `String` — where the file lives (a library URI, or a path below API 29) | no | the platform's answer to keeping it (D7) |
| `keptAt` | `int` — epoch milliseconds | no | when it was kept |

**Relationships**: at most one entry per content (FR-012), and each entry names a file the device's video
library holds. Deleting the content (the existing delete) does not touch its video — a separate decision the
spec does not make.

**Validation rules**

| Rule | Requirement |
|---|---|
| Keeping while an entry exists replaces it, leaving exactly one | FR-012 |
| A lookup whose file is gone reports the video as gone, forgets the entry, and leaves the content able to record again | FR-022 |
| Deleting removes the entry **and** the file from the library | FR-022 |
| A missing or malformed store reads as empty, without an error (its `AppearanceStore`/`ReadPositionStore` behaviour) | ripple note 5 |

**Worked example**: the reader keeps a video for "The Little Prince" → the store holds one entry naming
`Movies/Klhu/The Little Prince.mp4`; the gallery lists it; the reader re-records and keeps again → still one
entry, and the URI in it is the new file's; the reader deletes the video → the entry goes and the gallery no
longer lists it.

**States**

```
absent ──(keep)──▶ kept ──(keep again: replaced)──▶ kept
                    │
                    ├──(delete, confirmed)──▶ absent (file and entry gone)
                    └──(the file vanishes outside the app)──▶ stale ──(next lookup: reported gone)──▶ absent
```

---

## 5. VideoReview *(new, in memory only)*

**Purpose**: the finished render waiting for the reader's decision (spec FR-021, A12). It exists so that
"not kept" is the default: nothing reaches the gallery until the reader says so.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `workingPath` | `String` — the app's own copy, in its cache directory | no | the render's output (D11) |
| `aspect` / `durationMs` / `sizeBytes` | the file's own facts | no | the render's result |
| `decision` | `undecided` \| `kept` \| `thrownAway` | no | the reader's action |

**Relationships**: one review per finished render; keeping it creates or replaces a `KeptVideoRecord` (4).

**Validation rules**

| Rule | Requirement |
|---|---|
| Nothing is written to the device's video library until the reader keeps | FR-021, SC-015 |
| Throwing it away deletes the working copy and leaves a kept video for that content untouched | FR-021 |
| Sharing is available while undecided and does not imply keeping | FR-023, A12 |
| Leaving the review undecided keeps nothing, asks first, and cleans the working copy up | FR-021 |

**Worked example**: a render finishes with a 41 s working copy; the reader plays it, shares it to WeChat,
then throws it away — the library is untouched, the working copy is gone, and an older video for the same
content is still playable.

**States**

```
undecided ──(keep)──▶ kept (working copy promoted into the library, entry written)
    │
    ├──(throw away)──▶ thrownAway (working copy deleted, nothing kept)
    └──(leave, after confirming)──▶ thrownAway
```

---

## 6. The reading page's states *(changed — a shipped value)*

**Purpose**: the render and its review are states of the reading page, not new screens (spec FR-019/FR-021,
D10), so the page's ownership rule stays the read's own rule rather than a second one.

**Attributes added to the page's state**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `plan` | `RenderPlan` | yes | present only in RENDERING |
| `progress` | `(slotIndex, frameIndex, totalFrames)` | yes | the renderer's own count (FR-009) |
| `frame` | `RenderedFrame` | yes | the picture shown while rendering (FR-020) |
| `review` | `VideoReview` | yes | present only in REVIEW |

**Validation rules**

| Rule | Requirement |
|---|---|
| RENDERING offers the picture and Stop; nothing else on the page is reachable, and the text is inert | FR-019 |
| Stop asks first; dismissing continues the render; confirming writes nothing | FR-019, FR-024 (the same dialog shape) |
| Leaving asks in the same way, from either state | FR-019 |
| The video action is offered only from the idle state, and only where the platform can render | FR-010, D8 |
| The page's shipped behaviour (003/005/010/011) is untouched by the two new states | FR-018, SC-009 |

**Worked example**: the reader taps the video action, chooses `vertical`, watches the picture advance and
taps Stop by mistake; the confirmation is dismissed and the render continues; on finishing, the review
appears, the video is played, kept, and the page returns to idle with the new entry in the library.

**States**

```
READ ──(the video action, aspect chosen)──▶ RENDERING ──(the render finishes)──▶ REVIEW ──(keep/throw away)──▶ READ
  ▲                                              │                                        │
  └──────────(Stop → confirmed: nothing written)──┘◀──(Stop/leave → dismissed: still rendering)┘
```

---

## Read but left alone

| Value | Why it is untouched |
|---|---|
| The content and its text (008) | The video is made from the text as it is when the render starts; the render never edits it (FR-018) |
| The reader's appearance (011) | The video carries it into its own frame (FR-014); the setting itself is not written by this feature |
| The reading position (010) | The render reads it as its start point (FR-004) and never moves it (FR-009) |
| The voice choice per language (002) | The render reads it per sentence (FR-003) and never writes it |
