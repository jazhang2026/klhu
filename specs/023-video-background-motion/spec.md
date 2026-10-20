# Feature Specification: Video Background Motion

**Feature Branch**: `023-video-background-motion`

**Created**: 2026-10-19

**Status**: Draft

**Input**: the reader's own words, item **023** of `text.txt`, quoted verbatim:

> 023. 给视频中的背景图片加一个动态效果(可选):
>     让背景图有轻微的移动和缩放效果，让视频更生动。移动方向可以是随机的。上下左右，远近和斜向都可以。
>     单个方向的移动距离不要超过图片本身的宽度或高度的10%。到边界时可以反弹回到原位。继续下一个方向的移动。

**What the ask is, against what the app renders today.** A rendered video's *background picture* is the picture the
reader picked for a sentence (020/021's per-sentence pictures), and the painter already draws it to fill the frame —
cover-cropped, never letterboxed (`lib/video_painter.dart:432`, the crop's own geometry in `_coverSource` at `:681`).
It does not move. The renderer paints **one picture per visual state** and reuses it across the frames of a run
(`lib/video_renderer.dart:318-330`), which is what keeps 012's render inside its measured budget. The words sit over
it on plates whose colour comes from the picture's tone under the band they cover
(`lib/video_painter.dart:409-424`). A video whose content has no pictures has only the plain background colour and
nothing to move (`:426-432`). With this feature's effect on, that framing is **inset before the picture moves**
(FR-013): the room every direction needs comes at the price of a 1.20 × tighter crop, and with the effect off none of
it applies.

## Clarifications

### Session 2026-10-19, at the plan gate — the reader's own answer: inset the framing, then move

The plan stage found that the cover crop fills one of the frame's dimensions to the pixel, so on this tree no picture
has room on both axes: the item's diagonals could be offered to nobody, and 「远」 could only be a cycle's return leg.
That finding was put to the reader as options, and they answered in three turns — *"对动态图，开始就先将图上下左右先留 10%
可不可以？有问题吗？"*, then *"因为有 9:16 和 16:9 的比例，横竖个 10% 是否可以改动？长的多一点 短的少一点？"*, then
**B**. This entry records what that settles, in their terms.

- **The framing is inset before the picture moves (FR-013).** The window the frame shows is the cover crop inset by
  **one twelfth of itself on each side** — `k = 5 / 6`, the picture presented **1.20 × tighter** than today's cover
  crop, **69.4 %** of its area. Both axes are inset equally because the window is drawn to the frame's own aspect: an
  inset on one axis only would stretch the picture. **Refused**: a flat tenth per side (`k = 0.8`: 1.25 ×, 64 % of the
  crop, for no direction it makes possible that `5/6` does not); an inset sized to equal on-screen pixels on both axes
  (`k ≈ 0.64`: 1.56 ×, 41 % — the most expensive of the three, for a symmetry the reader did not ask for); no inset at
  all (a picture of the frame's own aspect then has nothing to move on but the zoom).
- **The bound is read on the frame's own dimension, so the long side travels more than the short one (FR-003).** On a
  16:9 frame: up to **192 px across** and **108 px down**; on 9:16 the two swap, with no branch in the code. Because
  the inset framing fills the frame, a tenth of the frame is a tenth of *that* framing — and never more than a tenth of
  the picture's own dimension, which `FR-003`'s old bound still caps. `5/6` is exactly the inset that makes this
  possible: it leaves one twelfth of the crop on each side, which is one tenth of the inset framing.
- **Every direction is now offered, 「远近」 included.** The eight compass directions are available to every picture,
  because the inset gives both axes room (the earlier entry's "directions the crop leaves room for" is what this
  supersedes: the room is made first). The zoom is a direction of its own at each end: 「近」 tightens by a tenth
  (0.75 × the cover crop), 「远」 grows by a tenth (0.9167 × the cover crop) and **stops at the cover crop** — the
  widest framing that still fills the frame — so this entry's second bullet's "no gap" rule and its refusal of a true
  zoom-out stand, and the earlier reading of 「远」 as a cycle's return leg is superseded.
- **The price, said plainly.** With the effect on, a picture is shown 1.20 × tighter than the same video shows it
  today, before any motion: 69.4 % of the cover crop's area, and a 4032×3024 photo in a 16:9 frame loses a further
  336 px of width and 189 px of height at rest, on top of what the cover crop already took. With the effect **off**
  nothing of this applies — the file is the one the app renders today (`FR-011`, `SC-001`).

### Session 2026-10-19 — the reading this spec takes, and what it refuses

No question was put to the reader before this stage: the item is written, and every open point below is settled by
the tree or by the item's own wording. Each entry names the alternative it refuses, so a later stage does not
re-propose it.

- **"(可选)" is the reader's choice at the video setup, and the default is off.** A video is a file the reader keeps;
  a motion nobody asked for would change every video the app has ever rendered. So the effect is offered where the
  video is set up — 012's prompt, `_askVideoFormat` at `lib/reading_view.dart:2003` — is **off** unless turned on,
  and the choice is remembered per device the way the format is remembered (one key family, `VideoAspectStore` at
  `lib/video_aspect.dart:63`, whose read is tolerant and whose default is the shipped behaviour). **Refused**: always
  on (it rewrites what 012 shipped, and every receipt that measured a frame's bytes with it); per-picture or
  per-sentence choice (the reader asked for an effect on *the video's* pictures, and a second decision per picture is
  a second surface to learn).
- **The picture is the background — the frame must never show a gap.** The 10 % the item names is a **cap**, not a
  promise that the crop has room: `_coverSource` centres the crop, so a picture **wider** than the frame has slack
  only vertically and a picture of the frame's **own** aspect has none at all. So the motion is only offered in
  directions the crop leaves room for, and the visible window always stays inside the picture. **Refused**: scaling
  the picture below the frame (letterboxing it, or letting the background colour show at an edge) to gain movement.
- **"Far" is the widest safe framing, not a smaller picture.** Because the resting framing is already the cover crop —
  the widest framing that fills the frame — a motion that scaled *out* past it would open a gap. The near/far axis is
  therefore anchored **inside** it: the cycle may start a little nearer (a tighter crop) and travel toward the
  resting crop, which reads as moving away without ever exposing anything. **Refused**: a true zoom-out.
- **The words do not move, and they do not flicker.** The text block's geometry and the plate/ink decision stay what
  they are per slot (`lib/video_painter.dart:409-424`): the picture moves under them, the letters and their plates do
  not. **Refused**: moving the text with the picture (012's layout rules — the column, the scroll step, the safe
  insets — are what make a frame readable, and a moving block would re-litigate all of them), and re-deciding the
  plate's colour per frame (a plate that changes colour mid-sentence is a flicker, and the tone is read per slot
  today).
- **Frame-driven, so it lives in the file.** The motion is a function of the frame's own place in its slot — the same
  `progress` the scroll step already uses (`lib/video_painter.dart:355-390`) — not something a player would add. The
  app's own preview therefore shows the motion for free, and a video kept in the library keeps it.
- **"Random" is random per cycle, not a reproducible seed.** No shipped rule makes two renders of the same content
  identical: 012's requirements and its contracts say nothing about it (`grep -rn "deterministic\|reproduc" specs/012-reading-video/`
  → no rule), and 020's pictures are picked, not generated. So the direction is drawn fresh for each cycle, and the
  evidence this feature owes is the **bound**, never a particular direction. **Refused**: a stored seed (it would
  invent a reproducibility rule this feature does not need and every later row would have to honour).
- **The render's own numbers do not move; its cost does.** Frame rate, frame count, duration and the audio stream stay
  exactly what 012 produces. What changes is the renderer's frame-reuse: with the effect on, every frame is a new
  visual state, so the one-picture-per-state saving does not hold and 012's measured budget (row 36: **60.6 s** wall
  for 69.3 s / 2078 frames) is the number this feature must re-take. **Refused**: buying the saving back by stepping
  the motion only at visual-state boundaries — a motion that jumps once per line step is not the gentle movement the
  item asks for.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A picture in a video breathes instead of sitting frozen (Priority: P1)

The reader opens their own content, picks a picture for a sentence, and keeps the video. Watching it back, the picture
behind the words drifts and swells very slightly — the frame is alive, and the words are as steady as they were.

**Why this priority**: it is the whole ask. Everything else in this spec is the bound, the choice, or the price.

**Independent Test**: render a two-sentence content that carries one picture, with the effect on; sample the frames;
the picture's visible window differs from one frame to the next, and the text's own pixels do not.

**Acceptance Scenarios**:

1. **Given** a content with one picture and the effect on, **When** the video is rendered, **Then** the picture's
   visible window is not the same in every frame of its sentences — it moves and/or scales, gently, frame to frame.
2. **Given** the same render, **When** two frames of one slot are compared on the text's own area, **Then** the
   letters and their plates are identical.
3. **Given** a content with no pictures, **When** it is rendered with the effect on, **Then** every frame is what the
   app renders today — the effect has nothing to act on and says nothing.

---

### User Story 2 - The movement is bounded, and it comes back (Priority: P1)

The motion never grows into a pan across the whole picture: a direction runs out to its bound, the picture returns to
where it started, and the next direction begins. Nothing is ever cropped away that the reader had before, and no edge
of the frame ever shows the background where the picture should be.

**Why this priority**: this is the item's own clause (10 %, bounce, next direction) and the rule that keeps the
picture *the* background. A motion without it is a different feature.

**Independent Test**: sample every frame of a picture's range; assert the maximum displacement of the visible window
on each axis is within 10 % of the picture's own dimension, that the resting framing recurs, and that no sampled
frame shows the background colour where the picture is.

**Acceptance Scenarios**:

1. **Given** a picture and the effect on, **When** a cycle completes, **Then** the window travels no more than a tenth
   of the frame's own width or height in that direction — never more than a tenth of the picture's own — and returns to
   the exact framing it started from.
2. **Given** the same render, **When** the cycle ends, **Then** a new direction starts — a different one from the
   cycle before it, drawn at random among the directions the crop leaves room for.
3. **Given** a picture with no slack on one axis (a portrait photo in a landscape frame), **When** it moves, **Then**
   it travels on **both** axes — the framing was inset first (FR-013) — and every frame still shows the picture edge
   to edge, never the background.

---

### User Story 3 - The effect is the reader's, and off until they ask (Priority: P2)

At the video setup the reader sees one more choice beside the format: motion on the pictures. It is off unless they
turn it on; once on, it stays on for the next video on that device; turned off, videos render exactly as they do
today.

**Why this priority**: the item says *optional*. A video is a kept artefact, and the app does not change a kept
artefact's look without being asked.

**Independent Test**: open the video setup twice — first with the choice untouched, then after turning it on — and
read the stored record and the rendered frames each time.

**Acceptance Scenarios**:

1. **Given** a fresh device, **When** the video setup opens, **Then** the choice is offered and off.
2. **Given** the reader turns it on and renders, **Then** that render's frames move, and the next video's setup shows
   the choice already on.
3. **Given** the choice is off (or the record is missing, or unreadable), **When** a video is rendered, **Then** the
   frames are what the app renders today, with the same frame count, rate, duration and audio.

---

### User Story 4 - Each picture starts its own motion, at its own place (Priority: P3)

When the video's picture changes at a sentence boundary, the new picture begins from its own resting framing rather
than inheriting the last one's offset; and a picture that stays for several sentences keeps the motion it started
with instead of restarting at every sentence.

**Why this priority**: it is the difference between a considered effect and a twitch. It is separable — the bound and
the choice stand without it — but a later stage that ignores it will produce a visible jump and re-open it anyway.

**Independent Test**: render a content with two different pictures and sample the frames at the boundary and inside
one picture's run.

**Acceptance Scenarios**:

1. **Given** two pictures in one video, **When** the boundary frame is compared with the frame before it, **Then** the
   new picture's framing is its own resting framing (no carry-over of the previous offset).
2. **Given** one picture spanning two sentences, **When** the sentence boundary is crossed, **Then** the motion
   continues (it does not restart from the resting framing).

---

### Edge Cases

- **A content with no pictures.** Nothing is drawn but the background colour; with the effect on or off, the render is
  today's — the choice is remembered but has nothing to act on.
- **A picture of exactly the frame's aspect.** The cover crop is then the whole picture, so the room comes entirely
  from FR-013's inset: it has the same ten directions as any other picture, and the frame never letterboxes.
- **A slot of a handful of frames** (a very short sentence). The cycle compresses into what the slot has; it never
  jumps, and it never exceeds the bound to "fit" the motion in.
- **A slot that ends mid-cycle.** The next picture starts its own cycle at its own resting framing; the interrupted
  one is not resumed.
- **The end hold** (012 extends the last slot to the end of the audio). The motion continues through it as one cycle
  run, not a restart.
- **A picture chosen, then a sentence deleted** so the picture rides fewer sentences: the motion follows the slot the
  picture is actually drawn in.
- **Portrait and landscape frames.** The same rule, measured on the picture's own dimension; the 9:16 frame's safe
  insets (012's own rule for a 9:16 frame) are untouched — the motion is behind the text, not around it.
- **An unreadable motion record.** The effect reads as off; nothing blocks a render (the aspect store's own rule).
- **A re-render of the same content.** The direction may differ from the first render's; the bound, the resting
  framing and the words do not.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With the effect on and a picture in the slot, the frame's picture MUST move and/or scale from frame to
  frame — a still picture is what the feature exists to remove.
- **FR-002**: The offered directions MUST be up, down, left, right, nearer, farther and the diagonals between them,
  and every one of them MUST be available for every picture — the room they need is made by insetting the framing
  before the picture moves (FR-013).
- **FR-003**: In any one direction the visible window MUST NOT travel more than **10 % of the frame's own width or
  height** — its long side more than its short one — and never more than **10 % of the picture's own width or height**
  either (for the zoom axis, 10 % of the framing's own size each way).
- **FR-004**: A direction MUST end by returning the visible window to **the exact framing it started the cycle from**,
  after which the next direction starts.
- **FR-005**: The visible window MUST stay inside the picture at every frame: the frame never shows the background
  colour where the picture is. Every pan direction has room because the framing is inset first (FR-013), and the
  zoom's farther direction stops at the cover crop — the widest framing that still fills the frame.
- **FR-006**: The motion MUST be a function of the frame's own place in its slot, so it is written into the file and
  needs nothing from a player.
- **FR-007**: The text block, its line geometry, its plates and its ink MUST be identical to today's frame for the
  same slot: the picture moves, the words do not, and the plate's colour does not change within a slot.
- **FR-008**: Each picture MUST begin at its own resting framing (FR-013's inset framing) when it first appears, and a picture that spans
  several slots MUST continue its motion across them rather than restarting at each sentence boundary.
- **FR-009**: The video setup MUST offer the effect as a choice, **off** unless the reader turns it on; the choice
  MUST be remembered per device, read tolerantly, and an absent or unreadable record MUST read as off.
- **FR-010**: The effect MUST NOT change the frame rate, the frame count, the video's duration or its audio stream.
- **FR-011**: With the effect off — or with a content that has no pictures — the rendered file MUST be what the app
  renders today, pixel for pixel.
- **FR-012**: The render's own evidence line MUST gain the motion's own field (its direction and its amplitude in the
  picture's pixels) additively, so a device row can witness the bound without knowing which direction was drawn —
  012's existing fields and the rows that read them MUST keep working.
- **FR-013**: With the effect on, the framing the picture is drawn in at rest MUST be the cover crop **inset by one
  twelfth of itself on each side** — the framing is `5/6` of the cover crop, **1.20 × tighter**: both axes in equal proportion,
  the picture's own aspect preserved, never letterboxed, and the same inset for every picture and both frame aspects.
  With the effect off, the framing MUST be the cover crop, exactly as today.

### Key Entities *(include if feature involves data)*

- **The slot's picture framing**: the rectangle of the picture the frame shows — today the centred cover crop
  (`_coverSource`), and with the effect on the cover crop inset by one twelfth per side (FR-013). It is the thing the
  motion moves within, and its inset is what gives every direction room on both axes.
- **A motion cycle**: one direction, one amplitude (≤ 10 % of the picture's own dimension), an out phase and a return
  phase, and the slot whose frames carry it. Cycles run one after another for as long as the picture is on screen.
- **The reader's choice**: on/off, per device, defaulting to off; the only state this feature stores, beside the video
  format's own record.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: (measured, effect off) 012's own frame-measuring rows re-run on a render made with the choice off:
  **42/42** in its row 32 and **41/41** in its row 49 — the second after a one-line re-cut of that row's own label
  check, which 020's standing "Assign sentences" prompt row had made impossible to pass on any build (it read 40/41 on
  the base commit's build too; re-cut and re-run 2026-10-20, recorded in 012's `breakpoint.md`); and the file's own
  frames are what the pre-feature build produces for the same content, frame for frame (**measured 2026-10-20: 273
  frames each, one digest**).
- **SC-002**: (measured, effect on) across every frame of a picture's range, the visible window's displacement is
  **≤ 10 %** of the picture's own width and height on each axis — the operating cap is the frame's own tenth, which
  this bound contains (FR-003) — and **no frame** shows the background colour where the picture is: read off the
  rendered frames, not off the code.
- **SC-003**: (measured, effect on) the motion's own cycle is **8 seconds** — a long, slow breath rather than a rhythm —
  and the framing the picture rests at recurs once in each cycle. **Re-cut 2026-10-19 at the reader's own instruction on
  the device** (「移动间隔时间长一点（容易）」): the earlier 3 s was this spec's own number, and a 3 s cycle read as a
  rhythm they did not ask for. Measured on `emulator-5554`: **185 resting frames, longest gap 89 frames (3.0 s)** inside
  a 240-frame cycle.
- **SC-004**: (measured, effect on) between any two frames of one slot, a pixel difference restricted to the text
  area is **zero** — the words and their plates do not move or flicker.
- **SC-005**: (measured, cost) a render with the effect on is **≤ 1.5 ×** the same content's render with it off, on the
  reference device. **Measured 2026-10-19, on one content rendered both ways (743 frames, 24.89 s): 30 s against 19 s —
  1.58 ×** — and **1.43 ×** on the same build's earlier run: the figure sits **on** the criterion rather than inside it,
  and the two runs' spread is one render's noise. Two levers bought it: one painted image per six frames, and a drift of
  1–2 % of the frame over an 8 s cycle (the reader's own instruction after watching a larger, faster motion step on the
  phone). Painting one image per frame instead costs **2.21 ×**; the raw-RGBA channel, built to buy that back, measured
  **slower per image** than a PNG on this device and was withdrawn.
- **SC-006**: (measured, invariant) the render's frame count, frame rate, duration and audio stream are what 012's own
  checks read on the same content with the effect off.

## Assumptions

- **A1 — "可选" means the reader's toggle, defaulting to off.** The alternative (always on) is refused in
  Clarifications, and reversing this one decision is a change to FR-009 alone.
- **A2 — the 10 % is read on the frame's own dimension, and the picture's own 10 % is the ceiling** (the 2026-10-19
  plan-gate amendment): the inset framing is what makes the frame's tenth reachable on both axes, and the window never
  leaves the picture. The item's number is a cap; the cover crop is the far wall, and the picture's edge the outer one.
- **A3 — 30 fps is enough for gentleness.** A 3 s slot at 30 fps is 90 frames; 10 % of a picture's height over a
  half-cycle is ~45 steps, which reads as movement rather than steps. No frame-rate change is needed (and FR-010
  forbids one).
- **A4 — the tone under the words does not swing with the motion.** The amplitude is small and the tone is decided per
  slot; the plan must confirm on a real picture that a moved band does not straddle a plate/ink boundary, and say so
  if it does.
- **A5 — no new store family.** The choice rides the video settings' own per-device family
  (`lib/video_aspect.dart:63`); 012's contract enumerates the format's values and will need a field for this, which is
  the plan's task to shape.
- **A6 — the reference content and device are 012's own**: `emulator-5554`, the one-minute fixture, the measurement in
  `specs/012-reading-video/breakpoint.md` row 36. This feature's rows re-take that number rather than inventing a new
  benchmark.

## Out of scope

- Transitions between two pictures (cross-fade, slide, wipe); motion on the text, the plates or the column.
- Per-picture, per-sentence or per-role amplitude; a motion editor; easing curves the reader can choose.
- A true zoom-out (letterboxing the picture to gain travel) — refused in Clarifications.
- Any change to the audio, the frame rate, the duration, or the number of frames.
- Motion in the app's own video list thumbnails, or in any still preview.
- Making two renders of one content identical (no reproducibility rule is added).

## What this feature supersedes, and the receipts it re-measures

Nothing is superseded: the effect is off by default, so 012's shipped frames are what they were — and with it on,
012's cover crop is the *outer* wall the motion may travel to, never past. The one thing this feature changes about
what a reader sees without asking for it is nothing: the inset of FR-013 exists only in a video whose switch is on. What it does owe is
**re-measurement once the effect is on**: 012's row 36 (the one-minute render's wall time, 60.6 s) is the budget this
feature's SC-005 re-takes, and 012's frame-measuring rows (32 and 49) are the receipts SC-001 re-runs with the choice
off. No other feature's row reads a frame's bytes with a picture behind the words, so no other receipt moves.
