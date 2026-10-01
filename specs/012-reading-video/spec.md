# Feature Specification: Reading Video

**Feature Branch**: `012-reading-video`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "I want to record the content reading into a mp4 video. Include the contents, hight lights, auto-scroll and reading voice. make it good as a youtube video."

**Input (requirement 14 of `text.txt`)**: the same words are item 14 of the wish list the user keeps in
the repository root — "14: I want to record the content reading into a mp4 video. Include the contents,
hight lights, auto-scroll and reading voice. make it good as a youtube video." The feature is scoped to
exactly that: one content, its reading, on video.

## Clarifications

### Session 2026-09-25

- **Q**: Does the video start at the content's first sentence, or at the highlighted sentence?
  **A**: "the video start at the content's first sentence if no highlighted sentence, or start at the
  highlighted sentence" — the video takes the page's own start point: the highlighted sentence when one
  is in force (010/011's position), the first sentence otherwise (FR-004).
- **Q**: Whose typeface and character size does the video's text use, and whose voice?
  **A**: "the video should have same font and char size as selected. and same voices as selected." — the
  video carries the reader's selected appearance (011 US2: typeface and character size) and the voice
  chosen per language (002's picker) over to the video. The video decides only its frame and the scale
  that maps the reading column onto it (FR-014, A3). This supersedes the first draft of this spec, which
  had the video choose its own look for legibility.
- **Q**: Which aspect and resolution, and who decides?
  **A**: "user can select: the aspect and resolution (FR-007) before start — 16:9 landscape 1080p(default)
  or 9:16 vertical for Shorts." — the format is a choice offered before the render starts, not a
  spec-fixed constant; 16:9 landscape 1080p is the default (FR-007, A8). This supersedes the first
  draft's single fixed format and its "no picker" assumption.
- **Q**: Should Stop act immediately?
  **A**: "Stop vedioing should have a confirm message box." — Stop asks for confirmation before anything
  happens; confirming ends the render with nothing written, dismissing leaves the render running untouched,
  and leaving the recording screen asks the same way (FR-019). This replaces the first draft's "Stop ends
  the render at once".
- **Q**: During a render, what may the user do?
  **A**: "allow Stop to stop the Vedio process. should we disable all other actions when Videoing?" — yes:
  rendering owns the page as a read does. Progress and a single Stop are offered, every other action is
  unavailable, a touch on the text does nothing, and leaving the screen asks first and then cancels with
  nothing written (FR-019). Stop is the one control that ends a render.
- **Q**: The reader's four follow-ups, verbatim: "1. I like to see the high lighted sentence move one by
  one and content scroll when vedio rendering?(progress of rending) 2. I like to play/view the vedio when
  finished. Then decide save or not save, share. 3. I like to reload saved vedio, play, share or delete.
  4. I like to be able to share my vedio through messeging, email, youtube.com, facebook.com ..."
  **A**: all four are added.
  **1** becomes FR-020: while a render runs the page shows the video's own picture as it is produced — the
  highlight moving sentence by sentence, the text scrolling — and that *is* the render's progress
  (US1 scenario 10, SC-014). This is cheaper than a progress bar and stronger evidence: the frames being
  previewed are the frames being written.
  **2** becomes FR-021: a finished render is played before anything is kept; the reader then keeps it,
  throws it away, or shares it, and only keeping writes a file into the library (US3, SC-015). This
  changes FR-011: it no longer says the render writes the file straight into the gallery.
  **3** becomes FR-022: the app remembers which video belongs to which content, so a kept video can be
  played, shared or deleted later from that content (US3 scenarios 6–8, SC-016).
  **4** becomes FR-023: sharing goes through the platform's own share sheet, so any installed app that
  accepts a video — messaging, email, cloud storage, the YouTube or Facebook app, a browser — can receive
  it. What the app does **not** do is upload: "share to youtube.com/facebook.com" means handing the file
  to those apps or to a browser, never an account or an API call (FR-013, out of scope).
- **Q**: "If share before save is hard, I can drop it. like view a photo/video in phone, the same share
  function we can use. list the apps to share, select an app, then upload the video in the selected app.
  (ex. wechat/wechat moment). delete video(and any other delete) in this app should have a worning."
  **A**: three answers.
  **Share before keeping is kept** — it is not hard, so there is no reason to drop it: sharing a file the
  gallery has not seen needs one readable URI, and `FileProvider` for it is already on this app's classpath
  transitively (research F10). The measured cost is a manifest entry plus a one-line paths resource, no
  dependency (research D11).
  **The share surface is the phone's own chooser, exactly as described** — list the apps, pick one, that app
  uploads (FR-023). One limit to know before the implement stage: the chooser lists the apps *that device*
  registers for sharing a video. WeChat's app registers for sending to a chat; **WeChat Moments is not
  exposed to the standard chooser at all** — targeting it would need the WeChat Open SDK, an appid and a
  third-party dependency, which the constitution's IV/A7 forbid here. So "share to Moments" is out of scope
  unless the reader wants that trade (research D13).
  **Every delete warns** — FR-024: deleting a video asks first, naming what is lost and that it cannot be
  undone, and this feature adds no delete path without that. The rule is the app's existing one, not a new
  invention: deleting a content already warns this way (`content_list_screen.dart:92` `_confirmDelete`, with
  `deleteConfirmTitle` "Delete this content?" and `deleteConfirmMessage` "This cannot be undone."), and the
  validation rows assert both.

### Session 2026-09-26

- **Q**: The reader, on seeing the first render's preview: "I see the preview frame on video rendering show
  different view compare to the continue page read. I like the vedio will show same content page as reading
  and same sentence by sentence high lighting. and auto scroll when needed. Is this what you are building?"
  **A**: it was not. The plan's own decisions (research D2/A3) had the video *paint the text onto the frame*:
  the paragraph a sentence belongs to, on a column derived from the frame (`min(0.88 × width, height)` — now
  `min(0.92 × width, 1.4 × height)`, with the block at the bottom: the reader's own two changes of 2026-09-28),
  with
  a highlight band on that sentence and a window that moved only inside a paragraph taller than the frame. So
  the video was a re-flow of the content rather than a view of the page, and no scroll settled. That gap was
  the plan's to surface when the preview first differed, and it was not surfaced; the answers below are the
  reader's, not the plan's.
- **Q**: "I drop my pick #5." (Option 5 was: capture the reading page's own surface into the video.) The
  reader's reasons: "the app tool bar and header shouldn't in. the video quality may be not good for
  publishing."
  **A**: dropped. The capture is out; FR-006's "the video MUST NOT be a recording of the phone's screen"
  stands, and no screen capture of the app's own tree is built either.
- **Q**: "I like to verify a new design: show only the one reading sentence in one frame. no high light and no
  scroll needed. So one new sentence need one new frame. add background images on the video(due to the empty
  view. and more like a real video). images uploaded into the image lib. images can be selected for the video.
  the image should be rendered to fit the video size. each image take average time for now. to set the
  start/end time of each image later."
  **A**: adopted (FR-002, FR-005, FR-014, FR-025–FR-029, US4), with the reader's own follow-ups:
  **A long sentence is kept whole** — "Long sentence, split it." was the first answer, and the reader
  replaced it later in this same session: "for now I like to keep whole sentence. one sentence in multiple
  line is acceptable. scroll up if it's too long. no smaller char." So a sentence that does not fit is drawn
  whole at the reader's own size, wrapped over as many lines as it needs, and scrolled upward inside its own
  frame when that block is taller than the frame's text area — never shrunk, never split (FR-014/FR-029). The
  scroll's position is proportional to the slot, the one estimate this feature admits: the voice is one
  utterance per sentence, so no finer timing exists to read a scroll from.
  **Timing by frame, not seconds** — "I mean start/end(inclusive) by frame, not by seconds." The schedule is
  each picture's inclusive start and end frame in the video's own frame numbers; the first cut shares the
  frames equally, and moving a start/end frame is a good-to-have for later (FR-026).
  **Pictures from the phone's gallery** — "images can use the phone's gallery. like other apps." Amended
  2026-09-27 on the reader's decision: the platform's own **file** dialog, then, not the photo picker — the
  pictures are files, made on the phone, on a PC or by an AI tool, so the file dialog is the one that finds
  them, and the only one with folders that every target has. No in-app gallery to build, no new permission,
  and every pick is read once and copied into the render's working directory (FR-025, D15).
  **Legibility** — one full-frame scrim between the picture and the text, in the frame's own background colour
  (the app's plain reading background), chosen over a band or a shadow (FR-027), so the reader's own text colour
  keeps reading over any photo. Its depth is a measured number, not an assumed one: spike S4 measured the
  alternatives on the reader's own pictures and **the dark layer fails where the light one holds** (D16,
  breakpoint.md row 42).
  **The reading page is unchanged** (FR-018/SC-009): it keeps its yellow tracking highlight, its follow and
  its scroll. The video is a different picture of the same reading, not a change to the reading.
- **Q**: The scrim, and how much of this is editable later.
  **A**: "the scrim: do what you do for now. later I like it editable same as image start/end frame. those
  will need to view the video first then make changes." — the scrim ships as decided — one layer, in the frame's
  own background colour, at the depth S4 measured (FR-027) — and the
  later good-to-have (FR-026) grows to cover it: the reader watches a finished render, moves a picture's
  start/end frame and the scrim, then renders again. Editing the finished file stays out of scope.
- **Q**: A sentence too long or too tall for the frame — shrink it, split it, or move it?
  **A**: "for now I like to keep whole sentence. one sentence in multiple line is acceptable. scroll up if it's
  too long. no smaller char." — so the reader's own size is absolute. A sentence is wrapped over as many lines
  as it needs and, if that block is taller than the frame's text area, it scrolls upward inside its own frame
  over its slot. No shrinking, no splitting and no horizontal slide, and no escape hatch is needed: scrolling
  absorbs any length, so the first cut's split (FR-029) is withdrawn.

### Session 2026-09-28

- **Q**: The reader, after using the app on the phone (LE2115, API 34), reported four things: "1. select images:
  only can select one image and re-select image. I like to select multiple images. set max images to 20.
  2. video player is not working in phone. only show a black view. click play button, not playing.
  3. video can be play from Files app's Videos folder. 4. like to have white background to the sentence
  characters. Don't do any change to the background images's color."
  **A**: (1) Several pictures at once, and choosing again **adds**: the app asks the platform for a
  multi-select file dialog and holds at most **20** pictures — a pick that would bring more than 20 keeps the
  first 20 and the page says so (FR-025, SC-022). Before this each pick replaced the last and nothing capped
  the count. (2) A defect in the app's own playback view, not a design decision: the review showed black and
  its controls did nothing, while the same file played from the device's Files app (3) — which says the file
  and the keep path are sound, and the fault is in the app's player (FR-021/SC-015; fixed as a defect task,
  not an amendment). (4) The full-frame scrim is **withdrawn**: instead of veiling the whole picture, a
  **white plate behind each painted line** carries the words, and the picture's own colours are untouched
  everywhere else — the reader's own words are the requirement (FR-027, SC-004). The plate's floor is the
  reader's text against white, 17.1:1 by construction, so the 4.5:1 floor holds without a veil, and S4's
  measured table (breakpoint row 42) stays as the record of the design it replaces.
- **Q**: Choosing pictures again after a first pick, and what a pick larger than 20 should do.
  **A**: "Choose again adds to the choice (batches accumulate), capped at 20" and "Keep the first 20 and say
  so on the page" — so the cap trims rather than refusing the pick, and the page says the cap was reached
  (FR-025/SC-022).
- **Q**: What shape the white behind the sentence takes.
  **A**: "A white plate behind each wrapped line's own box (picture visible everywhere else), only where a
  picture is behind the text" — one plate per line box, no full-frame layer anywhere, and the
  plain-background video (no pictures chosen) keeps the look it has today (FR-027/FR-028).
- **Q**: The reader's own phone test of the picture step, in their words: "选读者自己的图片、works / 超限提示、no
  need. not show. / 小窗口滚动、works / 长按换序, works. but only can move in displayed rows. need to able to move
  out of the disabled rows. use auto scroll. / Need to change button: \"Choose again\" to \"Choose more\""
  **A**: (1) Choosing through the platform's file dialog is **confirmed on the reader's own phone (LE2115)** —
  the same dialog, the same stored picks, the same thumbnails the page shows. (2) The overshoot message is
  **withdrawn**: the prompt says nothing about a choice larger than the video's sentences and offers the render
  anyway; the pictures past the last sentence are simply not drawn (FR-026, SC-022) — a change of rule, not of
  wording, and the sentence count the prompt used to resolve goes with it. (3) The small scrolling window is
  **confirmed on the phone** (FR-030). (4) The hold-and-drop reorder is **confirmed on the phone**, with one
  thing it could not do: reach a cell outside the two rows on screen — so a hold at either end of the window now
  scrolls it (FR-032, D21). (5) The button that adds pictures is renamed: **Choose more** (FR-031) — the reader's
  own words, and the copy in all four languages changed with it.
- **Q**: The reader's answers to the review's own three points: "(a) 保留已选并提示 (b) 底板会与背后区域撞色
  ——改为只统计文字所在条带； (c) use scrool. small show window, scroll to show others."
  **A**: (a) A pick that cannot be taken keeps the choice the reader already has, untouched, and says so
  (the refusal-and-warn rule, later withdrawn with the cap itself — see below). (b) The plate's tone is read
  over **the band the painted lines cover**, not over the picture as a whole (FR-027, D16's amendment): the
  plate then matches the strip it sits on, at the cost of a plate that may change between line steps inside
  one sentence whose band crosses the floor. (c) The shown pictures live in a **small window — two rows tall —
  that scrolls**, so a choice of thirty is one scroll rather than a dialog taller than the screen (FR-030,
  SC-023).
- **Q**: Choosing a large set of pictures over a short content, and where the picks live while the prompt is
  open: "1. (2) 选图当下落盘到应用私有目录、页面与渲染从文件读 2. 图多于句子时：show error message! force user
  to remove images. 3. OK." (with, before it, "remove max 20 images limit. keep all 30 images for now. user can
  delete images.")
  **A**: (1) The cap of 20 is **withdrawn** — every picture chosen is kept, the count on the page is the whole
  choice, and the reader's own remove is what takes one back (FR-025, FR-030, SC-022). (2) A pick is now
  **stored at the pick**: the bytes are read once, while the picker's own read grant is alive, and written into
  a file in a directory of the app's own, one directory per prompt — so the page's thumbnails and the render's
  copies are the same stored file and thirty photographs are thirty paths, not hundreds of megabytes in memory
  (FR-025, D18, SC-024). The directory goes when the render that used it is over, however it ended: nothing the
  reader chose outlives the prompt. (3) **Nothing bounds a choice** — not a count, and not the video's own
  sentences: a choice larger than the video has is a choice with pictures it has nowhere to draw, and those
  pictures are simply not drawn, exactly as the schedule has always treated a picture that found no sentence.
  The prompt names no limit and offers the render as it stands — no trim, no silent drop, no message to clear
  (FR-026, SC-022; the reader's own phone test of 2026-09-28: "超限提示、no need. not show."). The prompt's own
  content still scrolls, so its buttons stay reachable on a small screen however many pictures it holds. The reader may also **change the order**: holding a picture and dropping it on
  another picture's cell is what puts that picture there, and the order on screen is the order the video
  draws (FR-032, SC-025). One more thing was reported and fixed with the same run: **the review's picture was
  black** with the sound playing ("only show a black view. click play button, not playing") — a defect of the
  view's container rather than a design decision: the picture now renders into a texture (D20), measured before
  and after on the emulator (row 54) and confirmed by the reader on their own phone ("play button works on my
  LE2115 phone.", 2026-09-28). A defect, so not an amendment.
- **Q**: The reader's own follow-ups, after using the amended app on the phone: "remove 超限时保留前 20. add
  worning when selected more then 20 images." / "now we have add more images. let's have thumbnail review and
  image remove function." / "text background: black text on white background if background image has light
  color. white text on black background if background image has dark color."
  **A**: (1) The trim is **withdrawn**: a pick that would pass 20 is refused whole, the choice the reader
  already has stands untouched, and the page names how many were chosen and that nothing was added — so
  nothing the reader chose is ever dropped quietly (FR-025, SC-022). (2) The chosen pictures are shown as
  **thumbnails**, in the order chosen, each with its own remove: the reader sees the choice and takes one back
  before the render, without cancelling it (FR-030, SC-023). This is why a pick is read once at the pick —
  the page has the bytes to show, and the render writes exactly what the reader saw (D15/D17). (3) The plate
  is **the opposite of the picture's own tone**: black text on white over a light picture, white text on black
  over a dark one (FR-027, D16). The tone is the picture's own average luminance, at a floor of half, so the
  pair carries **21:1** either way and SC-004's floor is met without a veil and without measuring a picture
  for contrast. With no picture the frame keeps the reader's own text colour (FR-028).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A content becomes one video I can play anywhere (Priority: P1)

While the reading page is idle it offers a video action. Using it turns the content on screen into a
single video file: the same text, the same voice, and — sentence by sentence — the sentence being spoken
alone in the frame, with the reader's own pictures behind it (US4). There is no highlight and no scrolling
in the video, because the frame *is* the sentence being heard; a sentence too long to fit wraps over several
lines and scrolls upward inside its own frame, never shrunk and never split. When the render finishes the app
says where the video is and how long it is.

**Why this priority**: without this the feature does not exist, and it is the whole of the request
("record the content reading into a mp4 video … contents, highlights, auto-scroll and reading voice").
Every other story decorates this one.

**Independent Test**: take the shipped English pre-set (8 sentences, 334 characters), use the video
action, wait for the render, then play the file and inspect it with a standard media analyser: one video
stream at the chosen resolution and frame rate, one audio stream, a duration equal to the reading plus
the end hold (the card's 2.5 s was withdrawn on 2026-09-29); extract a frame inside each sentence's slot and find that sentence's text
alone as the frame's text (a long one showing its whole text over its slot, FR-029); with nothing highlighted
the video opens at the content's first
sentence and with a sentence highlighted it opens at that sentence (FR-004), and in both cases its last
voice segment is the content's last sentence.

**Acceptance Scenarios**:

1. **Given** a content open on the reading page and nothing being read, **When** the user starts the
   video action, **Then** it renders and reports a single video of that content; with nothing highlighted
   it opens at the content's first sentence, and with a sentence or paragraph highlighted it opens at that
   sentence — either way it ends after the content's last sentence.
2. **Given** that video, **When** it plays, **Then** the voice is the app's voice for each paragraph (the
   language the page would speak that paragraph in), the frame's text is the sentence being spoken at that
   moment, and no voice is heard while its sentence is not the frame's text.
3. **Given** a content longer than one screen, **When** its video plays, **Then** its sentences follow one
   another in the order the page reads them, each whole in the frame that carries it — the video needs no
   scrolling, because no frame carries text other than the sentence being heard.
4. **Given** a content that mixes English and Chinese paragraphs, **When** it is recorded, **Then** each
   paragraph is voiced in its own language and each sentence appears in its own paragraphs' script, as the
   page would read it.
5. **Given** a render in progress, **When** the user cancels it or leaves the recording screen, **Then**
   no file is left behind and the content's own state (text, reading position, appearance) is unchanged.
6. **Given** a read is playing or parked, **When** the user looks for the video action, **Then** it is not
   offered — a read in flight owns the page (011 FR-025's sibling rule).
7. **Given** an empty or whitespace-only content, **When** the user starts the video action, **Then** it
   is refused with the app's existing message and no file is written.
8. **Given** a render in progress, **When** the user looks at the reading page, **Then** the only control
   on offer is Stop — the page's other actions are unavailable and the text does not respond to a touch.
   Using Stop asks to confirm: confirming ends the render at once with no file written for that content and
   the page's idle controls back, while dismissing the confirmation leaves the render running untouched.
9. **Given** a content and nothing being read, **When** the user starts the video action, **Then** the
   aspect/resolution is offered first (16:9 landscape 1080p preselected, 9:16 vertical as the other
   choice), and the finished file has exactly the chosen shape.
10. **Given** a render in progress, **When** the user watches the reading page, **Then** the page shows
   the video's own picture as it is produced — the sentence being written into the video, whole, one
   sentence at a time, over whatever picture that frame carries — and that picture is the render's progress
   (FR-020): the sentence on the page is the sentence being written into the video.

---

### User Story 2 - The video is good enough to publish (Priority: P2)

The video looks like a video and not like a phone screen: the frame is the video's own (no app bar, no
buttons, no hints, no dialogs, no phone status bar, no notifications, no keyboard), it opens on its first
sentence (the card that used to name the content was withdrawn on 2026-09-29), the text is set at the reader's own size, every sentence whole and alone in
its frame over the reader's own picture with the scrim so the words read, and the reading's own
pace is kept — no long silences between sentences — before a short hold on the last sentence.

**Why this priority**: "make it good as a youtube video" is the second half of the request. P1 alone
would produce something functional and unwatchable.

**Independent Test**: inspect frames — the first frame is the first sentence's own and no frame carries the
content's name (the card was withdrawn on 2026-09-29); no frame contains any of the
app's controls or the device's status bar/navigation; the text block sits inside the frame with margins
at every sampled frame — and, where the sentence fits, at the **bottom** of the text area, so the picture has
the frame above the words to itself (the reader's own request of 2026-09-28); the sentence's own glyphs are the
frame's text, with no highlight band (the
sentence alone in the frame is what the frame highlights). Then measure, across the whole video, the
gap between the end of one sentence's voice and the start of the next, and the lead-in and end hold.

**Acceptance Scenarios**:

1. **Given** a finished video, **When** any frame is inspected, **Then** the app's own controls, hints,
   dialogs and the device's status bar/navigation are nowhere in it.
2. **Given** a finished video, **When** it opens, **Then** the first sentence is the very first frame —
   no card names the content, and no frame carries its name or language (amended 2026-09-29) — and its
   voice starts with that frame.
3. **Given** a finished video, **When** the gap between two consecutive sentences is measured, **Then**
   it is within the bound in FR-016, and the video ends holding the last sentence rather than cutting it
   off.
4. **Given** the reader has chosen a typeface and a character size (011 US2), **When** the video is made,
   **Then** the video's text is that typeface, in that size, always — no sentence is ever shrunk to fit, a
   long one wrapping and scrolling in its own frame instead (FR-029) — and recording the same content again
   after changing the choice shows the new one, so two renders of one content differ in the text they carry
   rather than in the video's layout.

---

### User Story 3 - The video is mine to watch, keep, share and delete (Priority: P3)

A finished render is played before anything is decided: the reader watches it, then keeps it, throws it
away, or shares it. A kept video is where the phone's video players and galleries look for videos, named
after the content, and its content still knows about it — so it can be played, shared or deleted later,
and re-recording replaces it instead of piling up copies.

**Why this priority**: the video is already useful the moment it exists (P1 makes it, and it can be pulled
off the device over USB), so the review step, the record and the delete path are what turn a file into
something the reader owns.

**Independent Test**: after a render, play the video in the app before keeping it; keep it and find it in
the device's video library under the content's name, playing from there; share it to another app from the
sheet; reopen its content later and play, share and finally delete it, then confirm the gallery no longer
lists it and the content offers to record again; render a content that already has a video and throw the
new one away, and find the old one untouched.

**Acceptance Scenarios**:

1. **Given** a finished render, **When** it is offered for review, **Then** the reader can play it in the
   app before anything is kept, and nothing is written to the video library yet.
2. **Given** a finished render the reader keeps, **When** the phone's video library is opened, **Then**
   the video is listed under the content's name and plays from there.
3. **Given** a finished render the reader throws away, **When** the video library is opened, **Then**
   there is no video for that content, and any earlier kept video for it is still there, untouched.
4. **Given** a finished render, **When** the reader shares it, **Then** the phone's own share list appears
   with the apps that accept a video, picking one hands that app the file — and the app itself uploads
   nothing, holds no account and bundles no platform's SDK.
5. **Given** a content that already has a kept video, **When** it is recorded again and kept, **Then**
   exactly one video for that content remains and it is the new one.
6. **Given** a content whose video was kept earlier, **When** the user returns to that content, **Then**
   the app offers to play, share or delete that video.
7. **Given** a kept video, **When** the user deletes it, **Then** a warning naming it appears first:
   dismissing the warning leaves the video where it is and still playable, and confirming it removes the
   file from the device's video library as well as from the app's record, after which the content offers to
   record a video again (FR-024).
8. **Given** the app has been restarted, **When** it is reopened, **Then** the earlier video is still in
   the library and still reachable from its content — the app did not delete it.

---

### User Story 4 - My video has my own pictures behind the text (Priority: P2)

With one sentence alone in the frame there is a lot of empty space, and a reading over a plain colour does
not look like a video. The reader picks pictures from their own files before the render starts; the
video draws them behind the sentence, each filling the frame, with the scrim between the picture and the text
— the frame's own background colour — so the words still read over any photo. As a first cut the chosen pictures share the video's length
equally, and the schedule is counted in the video's own frames — start frame and end frame — so a later
version can let the reader move a picture's start or end frame.

**Why this priority**: it is what makes the result look like a video rather than a caption card (US2's
"good enough to publish"), and it is the reader's own request. The feature works without it: no pictures
chosen renders on the plain background, refused for nothing.

**Independent Test**: render one content twice, once with nothing chosen and once with three pictures. In
the second, sample a frame inside each picture's range and find that picture filling the frame behind the
sentence; sample the seams between ranges and find no frame carrying a picture outside its own range; and
measure the sentence's contrast against what is behind it. In the first, find the plain background and a
video that rendered without pictures, no slower and nothing refused.

**Acceptance Scenarios**:

1. **Given** a content on the idle reading page, **When** the reader opens the video action, **Then** they
   can choose pictures from their own files with the platform's own file dialog and see what is chosen
   before the render starts.
2. **Given** chosen pictures, **When** the video is made, **Then** each picture fills the frame it is drawn
   in — covering it, without bars — and the sentence is drawn over it with the scrim between them, so the
   text still reads.
3. **Given** chosen pictures and a finished video, **When** its frames are inspected, **Then** each picture
   appears only inside its own inclusive start/end frame range, and every frame is covered by one chosen
   picture or by the plain background.
4. **Given** no pictures chosen, **When** the video is made, **Then** it renders on the plain background
   exactly as it would have before this story, refused for nothing and delayed for nothing.
5. **Given** a sentence too long to fit the frame, **When** the video is made, **Then** it is drawn whole at
   the reader's own size, wrapped over several lines and scrolled upward inside its own frame, and its slot's
   frames are all that one sentence — never split, never smaller.

---

### Edge Cases

- **More pictures chosen than the video has sentences**: equal shares still cover every sentence, so a picture
  that would get no sentence is simply not drawn — no frame is shared by two pictures, none in the spoken part
  left uncovered, and no picture change lands inside a sentence (FR-026/FR-028).
- **A picture's share lands mid-sentence**: it cannot. A share is a whole number of sentences, so a picture
  changes where a sentence changes — the reader never sees the picture swap while a sentence is on screen
  (2026-09-27, FR-026).
- **A sentence too long or too tall for the frame**: it is neither shrunk nor split — it wraps at the reader's
  own size and scrolls upward inside its own frame (FR-029), so its slot always carries that one sentence and
  its whole text is seen over the slot.
- **A content long enough that the render is minutes of work**: progress is shown and cancel works at any
  point; cancelling leaves no file (FR-009, SC-006).
- **The phone runs out of space, or the render fails halfway**: the failure is reported and no partial
  video is left in the library.
- **A render is stopped mid-way while a video for that content already exists**: nothing is written, so the
  previous video is untouched — a stopped render never leaves the content with a broken file (FR-012).
- **Stop tapped in error**: the confirmation is dismissed and the render carries on — stopping is never one
  tap, so an accidental tap cannot throw away minutes of work (FR-019).
- **A paragraph the page would voice in a language whose voice is missing on this device**: the video
  uses the same fallback voice the page would use — the video and the page must never disagree about the
  voice.
- **A content with one sentence**: still a video — one highlighted sentence, one voice
  segment, end hold.
- **A highlight sitting on the content's last sentence**: the video is that one sentence
  and the end hold; a short video is still a valid one (FR-004).
- **A text that mixes three languages**: per-paragraph languages exactly as the page decides them
  (004/007's locales).
- **The phone's text size changes between two renders**: the second video carries the new choice (FR-014)
  — the two videos are expected to differ in the text they show, not in the framing.
- **A read is started while a render runs**: impossible by construction — the render owns the page
  (FR-010) and the video action is idle-only.
- **A touch on the text while a render runs**: nothing happens, as during a read (011 FR-025).
- **The user rotates the phone or leaves the app mid-render**: the render cancels cleanly and nothing is
  written (A2, FR-009).
- **The spoken audio is longer than a nominal reading pace would suggest**: the frames follow the voice,
  never the other way round — the voice is the clock (A5).
- **The content is edited while nothing is rendering**: the next video is made from the text as it is
  when the render starts.
- **An empty or whitespace-only content**: refused with the app's existing message, no file (US1
  scenario 7).
- **Two renders of two different contents at once**: not offered — one render at a time.
- **The device's video library loses a kept file** (removed outside the app, or by the gallery): the app's
  record is stale — opening that content reports the video as gone, forgets the record, and offers to
  record again (FR-022).
- **A re-render is thrown away while an earlier video was kept**: the earlier video is still in the library
  and still reachable — throwing a render away never touches what was kept (FR-021).
- **A video is shared before it is kept**: the share sheet receives the app's own working copy; keeping is a
  separate decision and either order works (FR-021, FR-023, A12).
- **The reader leaves a finished render's review undecided**: keeping is never implied — nothing is kept,
  the working copy is cleaned up, and leaving asks first in the same way Stop does (FR-021, FR-019).
- **The delete warning is dismissed**: the video is still in the library and still playable, and its record
  is untouched — dismissing a warning never deletes anything (FR-024).
- **A video is deleted while its own playback is open**: playback stops, the file goes, and the content
  offers to record again (FR-022/FR-024).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reading page MUST offer, while it is idle, a control that produces a video of the
  content being read.
- **FR-002**: Each frame of the video MUST show the sentence being spoken at that moment — alone in the
  frame and whole (wrapped, and scrolled within the frame when it is too tall, per FR-029) — over the
  reader's own picture when pictures are chosen (FR-026/FR-027). The video MUST NOT show the content's other
  sentences, a highlight band, or a scrolling page: with one sentence in the frame, that sentence is what the
  frame highlights.
- **FR-003**: The voice in the video MUST be the app's own synthesised speech for each sentence, in the
  paragraph's own language and in the voice the reader chose for that language (002's picker) — the same
  voice and the same sentence-by-sentence order the page uses. It MUST NOT be a recording of the phone's
  speaker, of the screen, or of another app.
- **FR-004**: The video MUST start where the reading page would start: at the sentence the page's position
  names when a sentence or paragraph is highlighted (010/011), and at the content's first sentence when
  nothing is highlighted. It MUST run from that start to the content's last sentence and then stop —
  there is no end position, and no video of a selection on its own.
- **FR-005**: The text in the video at any moment MUST be the sentence whose voice is being heard at that
  moment, and no sentence's voice may be heard while its text is not what the frame shows.
- **FR-006**: The video frame MUST be the video's own: it MUST NOT contain the app's chrome (app bar,
  buttons, hints, dialogs, keyboard) or the device's own UI (status bar, notifications, navigation), and
  the video MUST NOT be a recording of the phone's screen.
- **FR-007**: The reader MUST be able to choose the video's aspect and resolution before the render starts:
  **16:9 landscape 1080p** (the default) or **9:16 vertical (1080×1920, Shorts-shaped)**. The choice MUST
  govern the frame and the layout of that video, and the video MUST be one file in a format standard
  players and video platforms accept: a common video codec and audio codec in the standard container, a
  constant frame rate, and exactly the chosen aspect/resolution.
- **FR-008**: The video MUST open on its first spoken sentence and MUST end by holding its last
  sentence briefly rather than cutting off the voice.
  <br>**Amended 2026-09-29 (the reader's own request).** The opening title card this requirement used to
  name — the content's name over its language, before the reading — **is withdrawn**: the first frame of
  the video is the first sentence's own, and nothing in any frame carries the content's name or its
  language. The reader's words, from reading the two renders of 2026-09-28: *"I want to remove the first
  title frame. and don't show the title in the top of 16:9 video."* The end hold is unchanged. Consequences
  the tasks own: the plan's slots are sentences plus the hold (no card slot, no `<VideoPlan>.title`,
  no card-drawing code in the painter, no language-label seam), SC-002's duration loses the card's 2.5 s,
  and FR-016's "lead-in" bound is vacuous — there is no lead-in.
- **FR-009**: A render MUST report progress while it runs and MUST be cancellable at any point; a
  cancelled, failed or abandoned render MUST leave no file behind and MUST leave the content's own state
  (text, reading position, appearance) unchanged.
- **FR-010**: The video control MUST NOT be offered while a read is playing or parked, and a render MUST
  NOT be interrupted by a touch on the text (011 FR-025's sibling rule: whichever owns the page keeps it).
- **FR-011**: A kept video MUST live where the device's video players and galleries find videos, under a
  name taken from the content, so the phone's gallery plays it and it survives the app being closed or
  restarted.
- **FR-012**: Keeping a video for a content that already has one MUST leave exactly one kept video for that
  content, and it is the new one.
- **FR-013**: The video MUST be produced on the device: no account, no backend, no upload and no network
  use (constitution IV), and the render MUST NOT depend on the phone being connected to anything.
- **FR-014**: The video's text MUST use the reader's selected typeface and character size (011 US2): that
  size is the size the video sets every sentence in — the video MUST NOT shrink it, and a sentence that does
  not fit wraps and scrolls within its own frame instead (FR-029). The frame size, the margins **and how much
  a line carries** are the plan's to choose — a line is 1.4× the width of the reader's own reading column, at the
  reader's own request of 2026-09-28 ("make the text line to be longer, will has less lines"), so a sentence that
  used to need four frames' worth of lines needs fewer. The **letters'** size is not what pays for that: a frame's
  letters are the size its own natural column has always given them, so the width a frame gives is width the line
  gets, and a frame with no width to give keeps its letters rather than shrinking them (the reader's own answer of
  2026-09-28, shown what the line cost on a portrait frame: "竖屏也保持原来的字大小"). The typeface and the
  character size are the reader's, and the video MUST NOT quietly override them.
- **FR-015**: An empty or whitespace-only content MUST be refused with the app's existing message and MUST
  produce no file.
- **FR-016**: The video's pacing MUST follow the voice: each sentence's frames MUST last exactly as long
  as that sentence's spoken audio, with no gap between consecutive sentences longer than 0.5 s and no end
  hold longer than 3 s. *(The lead-in bound — no lead-in longer than 3 s — is vacuous since the opening
  card was withdrawn on 2026-09-29: the video begins on its first sentence, so there is no lead-in at all.)*
- **FR-017**: The video's audio MUST be complete: every sentence the page would speak MUST be audible in
  the video, in order, with no sentence dropped, shortened or repeated.
- **FR-018**: The feature MUST NOT change how the reading page reads aloud, its controls or its
  appearance; the video is an additional capability, and the page's shipped behaviour (003/005/010/011)
  MUST keep working unchanged.
- **FR-019**: A render MUST own the page while it runs, exactly as a read does: the page offers the
  render's own picture advancing (FR-020) and a single **Stop**, and MUST NOT offer or accept any other
  action (reading, Continue Read, editing, the appearance screen, the contents list, the voice picker, or a
  second render). A touch on the text during a render MUST change nothing. Using **Stop** MUST ask for
  confirmation before anything happens: confirming ends the render at once with nothing written (FR-009),
  and dismissing the confirmation leaves the render running untouched — showing the confirmation MUST NOT
  pause the render, so the picture keeps advancing while the box is up. Leaving the recording screen MUST
  ask in the same way.
- **FR-020**: While a render runs, the page MUST show the video's own picture as it is produced — each
  frame the sentence being spoken, alone in the frame at the reader's own character size as the amended
  picture draws it (FR-002/FR-014/FR-029) — and that picture IS the render's progress, not a bar beside it.
  The picture the reader sees MUST be the frame being written into the video.
- **FR-021**: A finished render MUST be playable before anything is kept, and the reader MUST then be able
  to keep it, throw it away, or share it — all three from that one review. Only keeping writes a file into
  the device's library (FR-011): throwing it away MUST leave no file for that content and MUST leave an
  earlier kept video for that content untouched. Leaving the review without deciding MUST keep nothing.
  **The picture MUST be drawn**: playing a render MUST show the video, not a black surface with its sound — where
  the platform's own player is hosted in a view of ours it MUST render into a surface the app's own compositor
  can draw (D20, the defect the reader reported from the phone and `breakpoint.md` row 54's measurement).
- **FR-022**: The app MUST remember which video belongs to which content, so that a kept video can be
  played, shared or deleted later from that content. Deleting MUST ask first (FR-024) and MUST remove the
  file from the device's video library as well as from the app's record, after which that content offers to
  record a video again. A record whose file is gone MUST be reported as gone and forgotten rather than shown
  as playable.
- **FR-023**: Sharing MUST use the platform's own share surface: the app hands the file over and the
  platform lists the installed apps that accept a video for the reader to pick from, and the app the reader
  picks receives the file and uploads it itself (messaging, email, cloud storage, the YouTube or Facebook
  app, a browser, WeChat). The app MUST NOT upload anything itself, MUST NOT bundle or call any platform's
  SDK, MUST NOT hold an account, key or appid for any platform, and MUST NOT use the network (FR-013).
  Sharing MUST be available both before keeping and afterwards, and must not be a condition of keeping.
- **FR-024**: Deleting a video MUST warn before anything happens — a dialog that names what will be lost and
  says it cannot be undone — with the reader's explicit confirmation required and the file untouched when
  the warning is dismissed. Deleting MUST never be a single tap. The feature MUST NOT introduce any delete
  without such a warning, and the same rule already governs the app's other destructive delete (a content,
  `content_list_screen.dart:92`), which MUST keep warning.

- **FR-025**: Before a render starts the reader MUST be able to choose pictures for the video from their own
  files through the platform's own file dialog — no in-app gallery to build and no new permission — and MUST
  see what is chosen before the render begins. The dialog MUST let several pictures be chosen at once;
  choosing again MUST **add** to what is already chosen rather than replace it; and **the choice MUST NOT be
  capped**: every picture chosen is kept, in the order chosen, and the only way a picture leaves the choice is
  the reader's own remove (FR-030). What can be *rendered* is bounded by the video itself rather than by a
  count — the pictures may never outnumber the video's sentences (FR-026).
  **Each pick MUST be stored as it is chosen**: the picker's own read is spent at the pick, while its grant is
  alive, and the picture is written into a file in a **directory of the app's own** (the app's private cache,
  one file per picture, named for the picture with any directory part stripped); the page's thumbnails and the
  render's copies MUST both come from those stored files, so a choice of thirty photographs is thirty paths
  rather than hundreds of megabytes held in memory. The stored files MUST NOT be remembered: the directory
  MUST be removed once the render that used them is over — finished, stopped or failed — and MUST NOT survive
  the prompt. The prompt's own content MUST scroll when it is taller than the dialog, so the reader's ways to
  choose pictures and to start the render stay reachable on any screen.
  *(Amended 2026-09-27: the file dialog rather than the photo picker, so that the pictures can be files made
  anywhere — on the phone, on a PC, or by an AI tool — and so that the same selection works on every target the
  app builds for, folders included. D15. Amended 2026-09-28: several pictures at once, a second pick adding to
  the first, and the cap of 20 — the reader's own decisions after choosing pictures on the phone. Amended
  2026-09-28 again: "remove 超限时保留前 20 … add warning when selected more then 20 images" — the trim is
  withdrawn for a **refusal and a warning**, so nothing the reader chose is ever dropped quietly. Amended
  2026-09-28 again — the cap itself is **withdrawn**: "remove max 20 images limit. keep all 30 images for now.
  user can delete images." Every picture is kept and the reader's own remove is what takes one back (FR-030),
  and what is refused is not a pick but a choice larger than the video can draw (FR-026). Amended 2026-09-28
  again — the picks are **stored on disk at the pick** ("选图当下落盘到应用私有目录、页面与渲染从文件读", D18)
  and the prompt scrolls, since it now carries a message that can be several lines tall.)*
- **FR-026**: Each chosen picture MUST occupy an inclusive run of the video's frames: its start frame and
  its end frame, counted in the video's own frame numbers rather than in seconds. **A picture MUST change
  only where a sentence changes** (2026-09-27, the reader's own rule — "one sentence is the unit on screen;
  no picture lands or lifts inside a sentence"): a picture's run begins at a sentence's own first frame and
  ends immediately before the next picture's first sentence, so the frames a picture covers are whole
  sentences and the gaps that follow them (and, for the video's last sentence, the end hold — FR-008's own
  rule for the last sentence's run, D14). As a first cut the chosen pictures MUST share the video's
  **sentences** equally, in the order chosen, and the video's frames before the first sentence — the title
  card — MUST stay the plain background (FR-028). Moving a picture's start or end frame is a later
  good-to-have, expressed as which sentence it starts at (and, with it, the look between the picture and the
  text, FR-027) — both changed after watching a render, by rendering again (2026-09-26). **A choice MAY hold
  more pictures than the video has sentences, and that is not an error**: a picture the sentences cannot carry
  is simply not drawn, exactly as a schedule has always treated a picture that found no sentence. The prompt
  MUST NOT refuse, block or count the choice, MUST NOT name any limit, and MUST offer the render whatever the
  reader has chosen (the reader's own answer from the phone, 2026-09-28: "超限提示、no need. not show.").
  *(Added 2026-09-28: "show error message! force user to remove images." — **withdrawn the same day**, after the
  reader walked it on the phone: the message was not wanted, and what happens without it is the rule this
  requirement now states. The count came from the video's own sentence resolution, the same call the render
  makes — that work is withdrawn too, since nothing checks a choice against it any more. D18.)*
- **FR-027**: A picture MUST be drawn to fill the frame it is in — covering it, without bars, cropping what
  does not fit — with the sentence drawn over it. **The picture's own colours MUST NOT be veiled, tinted or
  faded anywhere**: what sits between the picture and the text is a **plate behind each painted line** — the
  line's own box, drawn from the picture up to the text — and no part of the frame outside those plates is
  changed by it. **The picture's own tone decides the plate and the ink**: where the picture reads light the
  text is **black on white**; where it reads dark the text is **white on black**. The tone MUST be read over
  **the band the painted lines themselves cover** — each line's own box mapped back onto the picture — and
  MUST NOT be read over the picture as a whole: a dark photograph whose sentence sits under a bright sky is
  plated for what is behind the words, not for the picture's average, so the plate can never clash with the
  strip it covers. With no picture the frame keeps the reader's own text colour (FR-028).
  *(Amended 2026-09-28: the reader's own decision after watching a render on the phone — "like to have white
  background to the sentence characters. Don't do any change to the background image's color." The full-frame
  scrim of the frame's own background colour at S4's measured 55 % is **withdrawn**: it tinted the whole
  picture, which is exactly what the reader did not want. Amended 2026-09-28 again: "black text on white
  background if background image has light color. white text on black background if background image has dark
  color" — the plate is the opposite of the picture's own tone, so the words read against a surface the
  picture cannot camouflage. Light and dark are read from the picture's own average luminance, at a floor of
  half; the pair is **21:1** either way, so the floor SC-004 asks for is met by construction, without a veil
  or a per-picture measurement of the text's contrast. S4's measured table stays in the record as the withdrawn
  design's numbers. D16. Amended 2026-09-28 again — after the reviewer's own point that a whole-picture average
  clashes with the strip the words cover ("底板会与背后区域撞色——改为只统计文字所在条带"): the tone is read
  over **the band the painted lines cover**, band by band, so the plate matches what it sits on. The cost is
  named rather than hidden: inside one sentence whose band crosses the light/dark floor, the plate and the ink
  may change from one line step to the next — the band actually behind the words is what decides, and the
  frames of a step carry that step's own band.)*
- **FR-028**: With no pictures chosen, and for any frame outside every picture's range, the frame MUST be
  the app's plain background. A render MUST NOT be refused or delayed for want of pictures.
- **FR-029**: A sentence that does not fit the frame MUST be drawn whole at the reader's own character size
  and wrapped over as many lines as it needs. It MUST NOT be shrunk, split across its own frames, truncated
  or cut. When the wrapped text is taller than the frame's text area it MUST scroll upward inside its own
  frame over that sentence's slot, so that every line of the sentence is inside the text area for part of the
  slot and no line is ever left clipped; a sentence that fits is drawn still, with no scroll. The scroll's
  position MUST be proportional to the elapsed fraction of the slot — the voice is one utterance per sentence,
  so it is an estimate by construction, which the reader has accepted (2026-09-26). The content's own text
  MUST NOT be changed.
- **FR-030**: The pictures chosen MUST be shown to the reader as **pictures** — each one a thumbnail, in the
  order chosen — and each MUST carry its own **remove**, so the reader can see the choice and take one back
  before the render starts. A removed picture MUST be gone from the render's own frames and from the count,
  and removing MUST NOT cancel the render or clear the rest of the choice. The thumbnails MUST be the chosen
  files themselves — the files the app stored for this prompt (FR-025, D18) — and MUST NOT be remembered once
  the render ends.
  *(Added 2026-09-28: "let's have thumbnail review and image remove function" — the reader's own follow-up to
  choosing several pictures at once, when a count was all the page said. D17.)*
- **FR-031**: Every string the reader reads MUST come from the app's own copy, in the app's own languages
  (FR-001's own rule): a pick that could not be stored says so, in the app's own words, rather than leaving a
  picture the render cannot open. The copy MUST also name the reader's own actions in the reader's own terms —
  the button that adds pictures to the choice says **Choose more**, because that is what it does (the reader's
  own correction from the phone, 2026-09-28: `"Choose again" to "Choose more"`).
- **FR-032**: The reader MUST be able to **change the order of the chosen pictures** before the render starts:
  holding a picture and dropping it on another picture's cell MUST put it where that one was, and the order the
  cells then stand in MUST be the order the video draws them in (FR-026). A drop on the picture's own cell MUST
  change nothing, and a move MUST NOT take a picture back, add one, cancel the prompt or change the count. The
  hold MUST start anywhere on the picture's own cell — not only on its remove, whose own tap target MUST NOT
  swallow the hold — and the reader MUST be told, in the app's own copy, that the order can be changed (FR-031).
  **A hold that reaches either end of the picture window MUST scroll the window**, and MUST keep scrolling while
  the hold stays there, so a picture can be moved to a cell that is not on screen: the whole choice is the
  reader's to move within, not only the rows in sight.
  *(Added 2026-09-28, the reader's own request that the review step let a picture be moved rather than only
  removed. D19. Amended 2026-09-28, after the reader walked it on the phone — the hold worked, but "only can move
  in displayed rows. need to able to move out of the disabled rows. use auto scroll." So the window follows the
  hold: the repeat stops the moment the hold leaves the window's ends or ends, D21.)*

### Key Entities *(include if feature involves data)*

- **Reading video**: the finished file for one content — the content it was made from, its name, its
  aspect/resolution, frame rate, duration and where it lives on the device. One per content (FR-012).
- **Render plan**: the video's timeline as the renderer builds it — one slot per sentence (its text
  range, its paragraph, its language/voice, its spoken length in frames) plus the end
  hold (the opening card was withdrawn on 2026-09-29, FR-008). This is what makes the video checkable: a
  slot's frames must show that sentence's own text alone.
- **The video's layout**: how the video puts its frame together — the sentence at the reader's own size,
  wrapped over as many lines as it needs and scrolled inside the frame when that block is too tall (FR-029),
  the picture behind it with a white plate behind each painted line (FR-027), the plain
  background, the end
  hold, and the margins. It carries the reader's appearance (typeface and character size) rather than
  replacing it (FR-014).
- **Picture schedule**: which picture is on screen when — the chosen pictures in order, each with its
  inclusive start frame and end frame in the video's own frame numbers (FR-026). Empty is a valid schedule:
  the plain background (FR-028).
- **A sentence's scroll**: where inside its own frame a wrapped sentence's text sits at a moment — from its
  first line at the top of the text area to its last line at the bottom, by the elapsed fraction of the
  sentence's slot (FR-029). A sentence that fits has no scroll: its text is still, and it sits at the **bottom**
  of the text area (the reader's own request of 2026-09-28: "move text block from top to bottom").
- **Kept video record**: which video belongs to which content — the content's identity, the file's name and
  where it lives — so a kept video can be found, played, shared or deleted later (FR-022). One record per
  content; it is what FR-012's "exactly one" is enforced against, and it can go stale when the library
  loses the file.

### Measurable Outcomes

- **SC-001**: A reader can turn an open content into a video without leaving the app and without a
  network connection, and the app reports the file's name and length when it is done.
- **SC-002**: The video plays from start to end in the device's own player and in a desktop player: one
  video stream at the chosen resolution and constant frame rate, one audio stream, and a duration equal
  to the reading plus the end hold (the card's 2.5 s was withdrawn on 2026-09-29) within 2 s.
- **SC-003**: The text in a frame is the sentence being spoken at that moment: sampling each sentence's
  slot (a frame at its start, its middle and its end) finds that sentence's own text as the frame's text in
  100 % of samples — and finds no other sentence's text in the frame (FR-002/FR-005).
- **SC-004**: No frame contains the app's controls or the device's status bar/navigation, and the text
  block has margins on all sides at every sampled frame. Where a picture is behind the text, the words sit on
  a plate — the line's own box — and their contrast against that plate measures at least 4.5:1 at every
  sampled frame: black on white over a light picture, white on black over a dark one, so the pair carries
  21:1 by construction and no picture can make the reader's own words fail (FR-027). The picture itself is
  unchanged by the text: sampling the frame outside the plates finds the picture's own colours, neither
  veiled nor tinted.
- **SC-005**: The video is publishable-shaped — video and audio codecs a video platform accepts, a
  constant frame rate, the chosen aspect/resolution — verified with a standard media analyser rather than
  by eye.
- **SC-006 (measured 2026-10-01 — the placeholder is gone)**: On the reference device a one-minute reading
  renders in about the video's own length rather than in minutes, with visible progress: 17 sentences,
  **69.3 s of 1080p30 video (2078 frames) rendered in 60.6 s of wall clock** on `emulator-5554` — 0.9× real
  time, 34 frames per second (row 36). The renderer's own account of that time puts **95 % of the app's own
  work in the encoder's path** — 47.1 s sending pictures (PNG encode plus the platform's own conversion)
  against 0.18 s of Dart rasterising for the same 17 pictures and 2.1 s of synthesis, with the muxer's finish
  at 11 ms; the app's passes are 49.5 s of the 60.6 s, the rest being the page's start-up — so the bottleneck
  is the platform half, not the painter. Cancelling at any point (checked at about 50 %) leaves no video file
  for that content. The superseded placeholder was "at most five minutes"; the measured number is from the AVD
  and has not been taken on the OnePlus 9.
- **SC-007**: A content mixing English and Chinese is voiced per paragraph in the video exactly as the
  page voices it: every spoken segment's language matches the language the page uses for that paragraph.
- **SC-008**: After the same content is rendered twice, the device holds exactly one video for it, and it
  is the second one.
- **SC-009**: The reading page itself is unchanged: its controls, reading, appearance and stored position
  behave exactly as 011's receipt shows.
- **SC-010**: With a sentence (or paragraph) highlighted, the video's first highlighted-and-voiced sentence
  is that sentence; with nothing highlighted, both name the content's first sentence; and the video always
  ends after the content's last sentence (FR-004).
- **SC-011**: Two videos of one content made at two different character sizes carry text whose rendered
  heights differ by the ratio of those sizes (within 10 %) — every sentence, however long, in the typeface
  chosen and never below the reader's size: the reader's choice reaches the video instead of being overridden
  by it, and no sentence is shrunk to fit (FR-014/FR-029).
- **SC-012**: Both offered aspects render and are exactly what the file is: a 16:9 render measures 1920×1080
  and a 9:16 render 1080×1920 in a standard media analyser, each at the constant frame rate, with the
  reader's choice made before the render and visible in the result (FR-007).
- **SC-013**: While a render runs, the page offers progress and Stop and nothing else: no reading, editing,
  appearance, contents, voice or second render is reachable and a touch on the text changes nothing. Stop
  and leaving both ask before they act — the render keeps running (the progress moves on) while the
  confirmation is up, dismissing it leaves the render to finish normally, and confirming it writes no file
  for that content and leaves the page idle (FR-019, FR-009).
- **SC-014**: While a render runs, the page shows the video's own picture and it advances sentence by
  sentence: sampling the page at two moments finds the sentence being spoken alone in the frame at the
  reader's own size, over the picture scheduled there where there is one, exactly as the frame being
  written at that moment, and the render's own frames bear it out (FR-020).
- **SC-015**: A finished render is playable in the app before anything is kept: with the reader playing it,
  the device's video library holds no video for that content; after keeping, it holds exactly one, playable
  under the content's name; after throwing the render away, it holds none and an earlier kept video for that
  content is still playable (FR-021, FR-011).
- **SC-016**: A kept video is reachable again from its content and can be played, shared and deleted there:
  after deleting, the device's video library no longer lists it and the content offers to record a video
  again; a record whose file was removed outside the app is reported as gone, not as playable (FR-022).
- **SC-017**: Sharing offers the file through the platform's share surface, whose list of apps is the
  device's own (verified on the reference device with at least one messaging app, one email app and one
  cloud app present): picking one hands it the file, and the app makes no network call, holds no account,
  key or appid, and bundles no platform SDK (FR-023, FR-013).
- **SC-018**: Deleting a kept video warns first: dismissing the warning leaves the video in the library and
  still playable, confirming it removes the file from the library and the app's record, and the app's other
  delete (a content) still warns as it does today (FR-024).

- **SC-019**: Pictures cover the video as scheduled: sampling every chosen picture's range finds that
  picture filling the frame behind the sentence, and sampling the seams between consecutive ranges finds no
  frame carrying a picture outside its own range (FR-026/FR-027).
- **SC-020**: A long sentence is neither split nor shrunk: every frame of its slot carries that sentence's
  own text, the whole of the sentence (every line of it) appears inside the frame's text area at some point
  in the slot with no line ever drawn outside it, and no other sentence's text is in those frames
  (FR-002/FR-029).
- **SC-021**: A render with no pictures chosen produces the video it would have produced without this change
  at all: the plain background, nothing refused and nothing delayed (FR-028).
- **SC-022**: Choosing pictures twice in one sitting leaves the page holding both picks — the count it names
  is the sum, not the last pick's — and nothing is capped or trimmed: every picture chosen is on the page with
  its own cell and its own remove, however many that is. A choice larger than the video's sentences is startable
  exactly as it stands — nothing is refused, named or blocked — and the render draws the pictures that found a
  sentence, leaving the rest undrawn (FR-025, FR-026, FR-030).
- **SC-023**: The page shows one thumbnail per chosen picture, in the order chosen, and each carries its own
  remove; taking one back leaves the others, lowers the count by one and leaves the render startable, and the
  render that follows draws the pictures that were left (FR-030).
- **SC-025**: Holding a picture and dropping it on another picture's cell leaves the choice with that picture
  in the position it was dropped on and every other picture keeping its own, with the count unchanged; the
  render that follows draws the pictures in that order, and a drop on the picture's own cell leaves the order
  exactly as it was (FR-032, FR-026). A hold taken to either end of the picture window scrolls the window while
  the hold stays there, so a picture can be dropped on a cell that was not on screen when the hold began — and
  the scrolling stops when the hold ends (FR-032).
- **SC-024**: The pictures the reader chooses exist as files in a directory of the app's own — one file per
  picture, in the order chosen, inside one directory per prompt — and the page shows those files and the render
  copies those files, so a choice of thirty pictures holds no photograph's pixels in memory; once the render
  that used them is over, however it ended, that directory is gone (FR-025, D18).

## Assumptions

- **A1 — start point and extent.** The video runs from the page's own start point — the highlighted
  sentence, or the first sentence when nothing is highlighted — to the content's last sentence. It never
  covers a selection on its own and never stops before the content's end (FR-004).
- **A2 — the render is silent and in-app.** The render does not play the audio aloud (the point is the
  file); it runs while the user stays in the app, and leaving the recording screen cancels it (FR-009).
- **A3 — the video carries the reader's appearance (clarified 2026-09-25; amended 2026-09-26 with the
  picture).** The video's text is the reader's selected typeface at their selected character size; what the
  video decides for itself is the frame, the text area and the margins it gives the sentence — its width no
  more than 1.4× the frame's height, so a line carries 1.4× the reader's own reading column of text (the reader's
  own request of 2026-09-28) — the scale that maps the reader's size onto that text area (the frame's own natural
  column, which is the size the letters have always had), where a sentence that fits sits (the bottom of the text
  area), and how a sentence taller than the text area scrolls inside its own frame (FR-029). Its background is the app's plain reading background, or the reader's own picture in its
  own colours with a white plate behind each painted line (FR-027/FR-028): the frame no longer paints the
  reading page, so there is no highlight for the
  app's highlight colour to fill. The consequence to accept: at the smallest offered size the video's text is
  genuinely small, because it is the size the reader asked for and it is never shrunk — the text area must
  therefore be sized generously enough that the smallest size is still legible at 100 %, and the plan proves it
  on the smallest size rather than the largest.
- **A4 — the phone's screen stays on.** The render keeps the screen awake while it runs. Because the
  video is not a screen recording, nothing about the phone's screen state appears in it either way.
- **A5 — the voice is the clock.** A sentence's slot is exactly as long as its spoken audio, plus a short
  constant padding between sentences (the bound is FR-016), so the video cannot drift from the voice.
- **A6 — feasibility on this platform is established, not assumed.** Per-sentence audio is available from
  the app's existing synthesised-speech path without capturing playback (the plugin's Android side
  implements a "synthesise this text to a file" call, verified in the package source on this host). The
  plan confirms it on the device, decides the frame/audio handoff, and keeps the platform-specific half
  isolated as the constitution requires. iOS is in scope for the shared codebase but cannot be validated
  on this host (no macOS): its half of the platform work stays unverified, as with 009's icons and 011's
  appearance.
- **A7 — no account, no backend, no network** (constitution IV), and no new third-party dependency for
  the phone's side of the work beyond what the platform provides (declared in the plan).
- **A8 — the format is the reader's choice, remembered (clarified 2026-09-25).** The choice offered before
  a render is exactly the two options (FR-007), with 16:9 landscape 1080p preselected, and the app keeps the
  last choice on this device — like the voice and appearance choices — so a second render does not re-ask.
  One aspect and one frame rate per video; a second render of the same content may use the other aspect and
  replaces the file (FR-012). Other formats, bitrates and quality tiers stay out of scope.
- **A9 — the reference device** for SC-006 is the AVD `emulator-5554` (API 36) and the OnePlus 9,
  whichever the row was measured on; the plan states which, and the APK stays a debug build for the
  `debugPrint` evidence.
- **A10 — the content is the app's own text** (008): no images, no captions read from a file, no
  thumbnails, no audio tracks supplied by the user.
- **A11 — the video is watched inside the app (clarified 2026-09-25).** Both the review's playback and a
  kept video's playback happen in the app, on a picture the app hosts itself (the platform's own player, so
  A7 still holds — no new package), which keeps the keep/throw-away/share decision on one screen. The
  alternative — handing the file to the device's own video player through an intent — is far less code but
  pushes the decision out of the app; a reviewer may prefer it, and FR-021/FR-022 are written so that
  swapping the player does not change what the reader can decide.
- **A12 — an unkept video can still be shared (clarified 2026-09-25).** Until the reader keeps it, the
  finished video is the app's own working copy, not a library entry; sharing hands that copy to the share
  sheet. Keeping is what puts a file where the phone's galleries look (FR-011), and the working copy is
  cleaned up either way once the review ends.

## Out of scope

- Publishing: **the app never uploads anything and has no account** (FR-013). Sharing hands the file to the
  phone's own share list, so messaging, email, cloud storage, the YouTube or Facebook app, a browser or
  WeChat may receive it and put it on a platform themselves — that upload is theirs, not this app's, and
  this app holds no API, key, login, appid or analytics for any of it. The feature ends at the reader's own
  file and that list. **Platform-targeted sharing that the chooser cannot express is out of scope**: WeChat
  Moments and similar in-app targets need the platform's own SDK and an appid (a third-party dependency the
  constitution's IV/A7 exclude here), so the feature promises the chooser's apps, not a specific platform's
  surfaces.
- Recording anything but the app's own render: no screen recording, no microphone, no other app's audio,
  no camera.
- Editing the video: no trimming, cuts, transitions, background music, sound effects, filters or
  per-sentence re-recording.
- Subtitle/caption files (SRT/VTT), thumbnails, chapters, playlists.
- Pictures as anything but a still behind the sentence: no bundled or downloaded image sets (the reader's
  own gallery is the only source, FR-025), no video clips or animated GIFs as backgrounds, no transitions,
  motion or pan-and-zoom between pictures, and no image search or download of any kind.
- Editing the picture schedule in the finished file: the schedule is chosen before a render and the file is
  never edited afterwards, so moving a picture's start or end frame later (FR-026's good-to-have) means
  rendering again. Trimming, cuts, transitions and the rest of video editing stay out (above).
- Per-word timing read from the voice: the app has one utterance per sentence and no finer timing exists, so
  a wrapping sentence's scroll position is proportional by construction (FR-029).
- More than one video per content, batch rendering of several contents, a screen that browses every video
  the app has made (a content offers play/share/delete for its own video, US3), or a queue.
- Bitrate, quality-tier, codec and frame-rate pickers, formats beyond the two aspects, and both aspects
  inside one video.
- A video that ends before the content's last sentence (there is no end position), or a video of a
  selection on its own (A1).
- Any voice other than the app's own synthesis, including human voice-over.
