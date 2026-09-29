# Data Model: Reading Video

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Decisions**:
[research.md](./research.md) D1–D19 | **Date**: 2026-09-25 (amended 2026-09-26 with the picture,
amended 2026-09-28 with the plate's band tone, the stored picks and the order change — and again the same day, on the
reader's own phone test: the sentence bound withdrawn, and the picture window following a hold at its end)

Seven things this feature introduces — two of them persisted — plus one shipped value it **changes** (the
reading page's state machine gains RENDERING and REVIEW, whose rules are the read's own ownership rule
extended), and four it reads but leaves alone (the content, its text, the reader's appearance, the reading
position). The seventh — the picture schedule (7) — and the frame's own shape in (2) and (3) come from the
2026-09-26 amendment: one sentence per frame at the reader's own size, over the reader's own pictures with a
**white plate behind each painted line** and no veil over the picture (D16, amended 2026-09-28) (FR-002,
FR-025–FR-029).

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
(30 fps), and — from the frame — the text area's width, its margins and the scale that maps the
reader's chosen character size onto it (spec A3; the smallest size must stay legible at 100 %). The amended
picture (7, D14) changes what that area holds — one sentence, wrapped and scrolled a line at a time — not the
rule that derives it.

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
the next render offers the choice with `vertical` pre-selected and produces a 1080×1920 file whose text area
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
| `endHold` | `Slot` — a fixed closing slot | no | FR-008 |
| `totalFrames` | `int` — Σ of every slot's frames | no | derived |
| `pictures` | `PictureSchedule` (7) — the reader's held pictures with the frame range each is drawn in; empty is a valid schedule | no | the reader's pictures before the render (FR-025–FR-028) |
| `style` | the reader's typeface and character size, the app's plain background, and the plate's own colour (white, `#FFFFFF`) | no | `AppearanceStore` + the app's theme (FR-014, A3; D16) |

**Slot** (one sentence, or the end hold — the title card was withdrawn on 2026-09-29, FR-008's amendment)

| Name | Type | Nullable | Source |
|---|---|---|---|
| `paragraph` / `sentence` | `int` | no | the sentence's indices, as the tracking callback reports them |
| `span` | `(int start, int end)` | no | absolute offsets in the content |
| `language` / `voice` | `String` / voice id | no | the same resolution the read uses (FR-003) |
| `audioPath` | `String` | yes (never for a sentence slot) | pass 1's file |
| `audioMs` | `int` — the spoken length, read from the audio file's header | yes (never for a sentence slot) | pass 1 (A5) |
| `frames` | `int` — `round(audioMs × fps / 1000)` (sentence), or the fixed count (hold) | no | derived |
| `startFrame` | `int` — the running total of the slots before it | no | derived |

**Relationships**: one `RenderPlan` per render; its slots are drawn from the content's segmentation, so a
content edited between renders yields a different plan and never a half-old one.

**Validation rules**

| Rule | Requirement |
|---|---|
| Slots are in reading order, contiguous in frames, and cover every sentence from the start point to the content's last | FR-004, FR-017 |
| The gap between two consecutive sentence slots is constant and within the stated bound; the hold is within its own | FR-016 |
| A sentence slot's frames equal its own audio's length in frames (so the picture cannot drift from the voice) | A5, FR-016 |
| A slot's frames always show that sentence's own text as the frame's text — at the reader's own size, inside the frame's text area — and no other sentence's text | FR-002, FR-005, FR-014 |
| A slot whose sentence is taller than the text area scrolls it upward by whole lines, every line inside the text area at some point in the slot and none clipped | FR-029, SC-020 |
| A sentence that **fits** its text area sits at the bottom of it: the last line's box ends where the text area ends, and the picture has the frame above the words | FR-029, D22 |
| A line carries up to `lineLengthGain` (1.4) times the reader's own reading column of characters — the column's width is `min(0.92 × frame width, 1.4 × frame height)` — while the letters keep the size their own frame has always set them (`lettersColumnFraction`, 0.88): 16:9 gets 1512 px of column with 1.400× a line, 9:16 gets 994 px with 1.045×, and neither gets different letters | A3, D6 (amended 2026-09-28) |
| The frames inside a picture's range carry that picture behind the text; the frames outside every range carry the plain background | FR-026, FR-027, FR-028 |
| An empty or whitespace-only content yields no plan at all | FR-015 |

**Worked example**: the shipped English pre-set (8 sentences, 334 characters) recorded as `landscape`
starting at sentence 3. The plan's first slot is sentence 3 at frame 0 (the video opens on its first spoken
sentence — the card was withdrawn on 2026-09-29), its `frames` is `round(2140 × 30 / 1000) = 64`
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
| `scrollStep` | `int` — which line step of its sentence this frame shows, `0` when the sentence fits | no | the elapsed fraction of the slot quantised to the text's line height (D14, FR-029) |
| `picture` | the picked picture drawn behind it, or nothing | yes | the schedule's range covering `index` (FR-026–FR-028) |

**Relationships**: every `RenderedFrame` belongs to exactly one slot; Σ `repeat` over a render = the plan's
`totalFrames`.

**Validation rules**

| Rule | Requirement |
|---|---|
| The picture the reader sees during the render is a `RenderedFrame`'s image, and its bytes are what the encoder got | FR-020, SC-014 |
| A frame is produced when the visual state changes — the slot's sentence, its scroll step, or the picture covering it — not once per frame time | D2 (the cost), D14 |
| A frame's text is the slot's sentence alone, at the reader's own size, inside the picture area with margins on all sides | FR-002, FR-006, FR-014, SC-003/SC-004 |
| A frame's picture fills it — no bars, cropped — with a white plate behind each painted line and nothing else between the picture and the text: the plate holds 17.1:1 against the reader's text, and the picture's own colours are unchanged outside the plates | FR-027, SC-019 |

**Worked example**: a 4-second sentence at 30 fps whose wrapped text occupies four lines produces five
`RenderedFrame`s over its slot — one per line step, from its first line at the top to its last at the bottom —
each carried for the frames until the next step; a sentence that fits produces exactly one. The encoder writes
four seconds of frames from five rasters rather than 120.

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
| `pictures` | `PictureSchedule` | yes | the reader's held pictures, from the picker until the render starts (FR-025) |
| `held` | `List<HeldPicture>` — every picture chosen so far, in the order chosen, each **stored as a file at its own pick** (name + path) | no (empty is valid) | accumulated across picks: a second pick adds to the first, and **nothing is capped** (FR-025, SC-022). The stored files are what FR-030 shows and what the render copies (D17/D18) |
| `picturesDir` | `Directory` — the prompt's own directory of stored picks, one directory per prompt | no | created before the prompt opens and removed once the render that used it is over, however it ended (FR-025, D18, SC-024) |
| `pickFailure` | `String?` — the page's own message where a pick could not be stored | no (null when the last pick was stored) | a pick whose own read failed is not half a choice, and the page says so rather than showing a picture nothing can open (FR-031) |
| `review` | `VideoReview` | yes | present only in REVIEW |

**Validation rules**

| Rule | Requirement |
|---|---|
| RENDERING offers the picture and Stop; nothing else on the page is reachable, and the text is inert | FR-019 |
| Stop asks first; dismissing continues the render; confirming writes nothing | FR-019, FR-024 (the same dialog shape) |
| Leaving asks in the same way, from either state | FR-019 |
| The video action is offered only from the idle state, and only where the platform can render | FR-010, D8 |
| The reader sees which pictures are chosen before the render starts — as the files the app stored for this prompt — and they are not remembered once the render ends | FR-025, D15/D18 |
| Choosing again ADDS to the choice — the count the page names is the sum of every pick, and the button that does it is named for what it does (*Choose more*) — and **nothing is capped or trimmed**: every picture chosen has its own cell and its own remove, however many that is | FR-025, FR-031, SC-022 |
| A choice larger than the video's sentences is silent and startable: the prompt names no limit and offers the render as it stands, and the pictures that found no sentence are simply not drawn | FR-026, SC-022 |
| Every chosen picture is shown as a thumbnail in the order chosen, each with its own remove; taking one back lowers the count by one and leaves the rest of the choice and the render startable | FR-030, SC-023 |
| Holding a picture and dropping it on another picture's cell puts it where that one was and leaves every other picture in place; a drop on its own cell changes nothing, and the order on screen is the order the render draws | FR-032, SC-025 |
| A hold at either end of the picture window scrolls the window while the hold stays there — so a cell that was not on screen can be dropped on — and the scrolling stops when the hold leaves or ends | FR-032, D21 |
| The stored picks exist only while the prompt and the render that used them exist: the directory is gone once the render is over, however it ended | FR-025, D18, SC-024 |
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

## 7. PictureSchedule *(new, in memory only — its copies live with the working copy)*

**Purpose**: which picture is on screen when (spec FR-025–FR-028, D15). It exists so the pictures the reader
chose have a place in the plan's own frame numbering, and so "no pictures" is a value the plan carries rather
than a special case in the painter.

**Attributes**

| Name | Type | Nullable | Source |
|---|---|---|---|
| `pictures` | `List<PictureSlot>` — in the order the reader chose them | no (an empty list is valid) | the phone's picker, before the render (FR-025) |
| `plateColour` | `Color` — white (`#FFFFFF`) over a light picture, black (`#000000`) over a dark one: the plate behind each painted line | no | the picture's own tone decides it, and the reader's rule of 2026-09-28 fixes the pair (D16, FR-027) |
| `inkColour` | `Color` — black over a light picture, white over a dark one; the reader's own colour where the frame has no picture | no | the pair with `plateColour`, 21:1 either way (FR-027/FR-028) |
| `tone` | `PictureTone?` — `light` or `dark`: read over **the band the painted lines cover**, at a floor of 0.5; null with no picture | yes where a picture is drawn | measured from the picture's own pixels, band by band, with the picture's pixels converted once; the plate follows the band actually behind the words (D16 as amended 2026-09-28) |
| `pictureCount` | `int` — how many pictures the schedule holds | no | the reader's choice, bounded by the plan's own sentences rather than by a number: a choice with more pictures than sentences is not startable (FR-025/FR-026, D18; the former `maxPictures = 20` is withdrawn) |

**PictureSlot** (one chosen picture)

| Name | Type | Nullable | Source |
|---|---|---|---|
| `name` | `String` — what the picker called it, kept for the copy's own name | no | the picker's seam (T045, FR-025) |
| `storedPath` | `String` — the file the app wrote the picture into at the pick, inside the prompt's own directory | no | `storePicks` at the pick, while the picker's grant is alive: the page showed this file and the render copies this file (D18, SC-024) |
| `copyPath` | `String` — the picture's copy inside the render's working directory | no | copied once before pass 2 reads it (D15/D18) |
| `startFrame` / `endFrame` | `int` — **inclusive**, in the video's own frame numbers | no | equal shares of the plan's **sentences** in the order chosen: the first sentence's first frame to the frame before the next picture's first sentence (FR-026) |

**HeldPicture** (one picture the reader chose, as the page holds it between the pick and the render)

| Name | Type | Nullable | Source |
|---|---|---|---|
| `name` | `String` — the file's own name, with any directory part stripped | no | the pick's own name, sanitised by `storePicks` (D18) |
| `path` | `String` — the file inside the prompt's own directory that holds this picture | no | written at the pick, read by the page's thumbnails and copied by the render (D18, SC-024) |

**Relationships**: one schedule per render, held by the plan (2); each `PictureSlot`'s range names frames in
that plan's timeline; the copies live beside the working copy and end with it (D11's rules, D15); and the
schedule's order is the order of the reader's own cells, which FR-032 lets them change (D19).

**Validation rules**

| Rule | Requirement |
|---|---|
| An empty schedule is valid: the plain background, nothing refused and nothing delayed for want of a picture | FR-028, SC-021 |
| Each range is inclusive and in the video's own frame numbers, and the ranges partition the spoken part — from the first sentence's first frame to the video's last — with no frame in two ranges and none left uncovered; since the card was withdrawn (2026-09-29) that first frame is the video's own frame 0 | FR-026, SC-019 |
| **A range begins at a sentence's own first frame and ends immediately before the next range's first sentence: no boundary falls inside a sentence**, so no picture lands or lifts while a sentence is on screen | FR-026 |
| The shares are equal over the plan's sentences in the order chosen — so their frame lengths may differ — and a picture whose share holds no sentence at all is not drawn | FR-026 |
| A picture is drawn to fill the frame it is in — covering it, cropped where the shapes differ — with a **white plate behind each painted line** carrying the words; nothing else is drawn between the picture and the text | FR-027, SC-019 |
| Each chosen picture is copied into the working directory once, before any frame is written, and the copies are gone when the render ends, however it ended | FR-009, D15 |

**Worked example**: the reader picks three pictures for a six-sentence content → two sentences each: A covers
sentence 1's first frame up to the frame before sentence 3 (the gap after sentence 2 included), B takes
sentences 3 and 4, C takes sentences 5 and 6 **and the end hold**, and a picture starts at the video's frame
0 (the video opens on its first sentence — no card's worth of plain background first, 2026-09-29). The frame
at the seam carries B and not A, and no seam sits inside a sentence: the reader never sees the picture change
mid-sentence. A reader who picks nothing leaves the schedule empty and gets the plain-background video at the
same speed.

**States**

```
empty ──(the reader picks)──▶ chosen ──(the render starts: the copies are made)──▶ drawn, one range at a time
                                                                                        │
                                                       (finished, cancelled or failed)──▶ gone: the copies are
                                                                                        deleted with the working copy
```

---

## Read but left alone

| Value | Why it is untouched |
|---|---|
| The content and its text (008) | The video is made from the text as it is when the render starts; the render never edits it (FR-018) |
| The reader's appearance (011) | The video carries it into its own frame (FR-014); the setting itself is not written by this feature |
| The reading position (010) | The render reads it as its start point (FR-004) and never moves it (FR-009) |
| The voice choice per language (002) | The render reads it per sentence (FR-003) and never writes it |
