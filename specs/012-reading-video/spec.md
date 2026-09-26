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

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A content becomes one video I can play anywhere (Priority: P1)

While the reading page is idle it offers a video action. Using it turns the content on screen into a
single video file: the same text, the same voice, the same sentence-by-sentence yellow highlight and the
same self-scrolling page — framed as a video of a reading rather than a picture of a phone screen. When
the render finishes the app says where the video is and how long it is.

**Why this priority**: without this the feature does not exist, and it is the whole of the request
("record the content reading into a mp4 video … contents, highlights, auto-scroll and reading voice").
Every other story decorates this one.

**Independent Test**: take the shipped English pre-set (8 sentences, 334 characters), use the video
action, wait for the render, then play the file and inspect it with a standard media analyser: one video
stream at the chosen resolution and frame rate, one audio stream, a duration equal to the reading plus
the title card and the end hold; extract a frame inside each sentence's slot and find that sentence
highlighted and inside the visible text; with nothing highlighted the video opens at the content's first
sentence and with a sentence highlighted it opens at that sentence (FR-004), and in both cases its last
voice segment is the content's last sentence.

**Acceptance Scenarios**:

1. **Given** a content open on the reading page and nothing being read, **When** the user starts the
   video action, **Then** it renders and reports a single video of that content; with nothing highlighted
   it opens at the content's first sentence, and with a sentence or paragraph highlighted it opens at that
   sentence — either way it ends after the content's last sentence.
2. **Given** that video, **When** it plays, **Then** the voice is the app's voice for each paragraph (the
   language the page would speak that paragraph in), the highlight sits on the sentence being spoken,
   and no voice is heard while its sentence is out of view.
3. **Given** a content longer than one screen, **When** its video plays, **Then** the page inside the
   video scrolls by itself so the spoken sentence stays visible, exactly as the reading page does.
4. **Given** a content that mixes English and Chinese paragraphs, **When** it is recorded, **Then** each
   paragraph is voiced in its own language and highlighted per sentence, as the page would read it.
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
   the video's own picture as it is produced — the highlight moving sentence by sentence and the text
   scrolling — and that picture is the render's progress (FR-020): the sentence on the page is the
   sentence being written into the video.

---

### User Story 2 - The video is good enough to publish (Priority: P2)

The video looks like a video and not like a phone screen: the frame is the video's own (no app bar, no
buttons, no hints, no dialogs, no phone status bar, no notifications, no keyboard), it opens with a
title card naming the content, the text is set at a size that is legible at 100 % and laid out for that
frame, the highlight is the app's yellow, the scroll settles rather than jumps, and the reading's own
pace is kept — no long silences between sentences — before a short hold on the last sentence.

**Why this priority**: "make it good as a youtube video" is the second half of the request. P1 alone
would produce something functional and unwatchable.

**Independent Test**: inspect frames — the title card names the content; no frame contains any of the
app's controls or the device's status bar/navigation; the text block sits inside the frame with margins
at every sampled frame; the highlight band is the app's yellow. Then measure, across the whole video, the
gap between the end of one sentence's voice and the start of the next, and the lead-in and end hold.

**Acceptance Scenarios**:

1. **Given** a finished video, **When** any frame is inspected, **Then** the app's own controls, hints,
   dialogs and the device's status bar/navigation are nowhere in it.
2. **Given** a finished video, **When** it opens, **Then** a title card names the content before the
   reading starts, and the first sentence is highlighted and voiced after it.
3. **Given** a finished video, **When** the gap between two consecutive sentences is measured, **Then**
   it is within the bound in FR-016, and the video ends holding the last sentence rather than cutting it
   off.
4. **Given** the reader has chosen a typeface and a character size (011 US2), **When** the video is made,
   **Then** the video's text is that typeface at that size, mapped onto the frame — and recording the same
   content again after changing the choice shows the new one, so two renders of one content differ in the
   text they carry rather than in the video's layout.

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

### Edge Cases

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
- **A content with one sentence**: still a video — title card, one highlighted sentence, one voice
  segment, end hold.
- **A highlight sitting on the content's last sentence**: the video is the title card, that one sentence
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
- **FR-002**: The video MUST show the content's own text, the highlight moving over the sentence being
  spoken, and the page scrolling by itself to keep that sentence visible — the same three things the
  reading page shows (011 FR-001/FR-020/FR-024).
- **FR-003**: The voice in the video MUST be the app's own synthesised speech for each sentence, in the
  paragraph's own language and in the voice the reader chose for that language (002's picker) — the same
  voice and the same sentence-by-sentence order the page uses. It MUST NOT be a recording of the phone's
  speaker, of the screen, or of another app.
- **FR-004**: The video MUST start where the reading page would start: at the sentence the page's position
  names when a sentence or paragraph is highlighted (010/011), and at the content's first sentence when
  nothing is highlighted. It MUST run from that start to the content's last sentence and then stop —
  there is no end position, and no video of a selection on its own.
- **FR-005**: The highlight in the video MUST be the sentence whose voice is being heard at that moment,
  and no sentence's voice may be heard while its text is outside the visible text area in the video.
- **FR-006**: The video frame MUST be the video's own: it MUST NOT contain the app's chrome (app bar,
  buttons, hints, dialogs, keyboard) or the device's own UI (status bar, notifications, navigation), and
  the video MUST NOT be a recording of the phone's screen.
- **FR-007**: The reader MUST be able to choose the video's aspect and resolution before the render starts:
  **16:9 landscape 1080p** (the default) or **9:16 vertical (1080×1920, Shorts-shaped)**. The choice MUST
  govern the frame and the layout of that video, and the video MUST be one file in a format standard
  players and video platforms accept: a common video codec and audio codec in the standard container, a
  constant frame rate, and exactly the chosen aspect/resolution.
- **FR-008**: The video MUST open with a title card naming the content and MUST end by holding its last
  sentence briefly rather than cutting off the voice.
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
- **FR-014**: The video's text MUST use the reader's selected typeface and character size (011 US2), with
  the app's highlight colour, by mapping the reading column onto the video's frame at a scale that keeps
  that text legible. The frame size and the margins are the plan's to choose; the typeface and the
  character size are the reader's, and the video MUST NOT quietly override them.
- **FR-015**: An empty or whitespace-only content MUST be refused with the app's existing message and MUST
  produce no file.
- **FR-016**: The video's pacing MUST follow the voice: each sentence's frames MUST last exactly as long
  as that sentence's spoken audio, with no gap between consecutive sentences longer than 0.5 s, no
  lead-in longer than 3 s and no end hold longer than 3 s.
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
- **FR-020**: While a render runs, the page MUST show the video's own picture as it is produced — the
  highlight moving sentence by sentence over the content's text, the text scrolling — and that picture IS
  the render's progress, not a bar beside it. The picture the reader sees MUST be the frame being written
  into the video.
- **FR-021**: A finished render MUST be playable before anything is kept, and the reader MUST then be able
  to keep it, throw it away, or share it — all three from that one review. Only keeping writes a file into
  the device's library (FR-011): throwing it away MUST leave no file for that content and MUST leave an
  earlier kept video for that content untouched. Leaving the review without deciding MUST keep nothing.
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

### Key Entities *(include if feature involves data)*

- **Reading video**: the finished file for one content — the content it was made from, its name, its
  aspect/resolution, frame rate, duration and where it lives on the device. One per content (FR-012).
- **Render plan**: the video's timeline as the renderer builds it — one slot per sentence (its text
  range, its paragraph, its language/voice, its spoken length in frames) plus the title card and the end
  hold. This is what makes the video checkable: a slot's frames must show that sentence highlighted.
- **The video's layout**: how the video puts its frame together — the reading column's scale and margins,
  the background, the highlight colour, the title card, the end hold. It carries the reader's appearance
  (typeface and character size) rather than replacing it (FR-014).
- **Kept video record**: which video belongs to which content — the content's identity, the file's name and
  where it lives — so a kept video can be found, played, shared or deleted later (FR-022). One record per
  content; it is what FR-012's "exactly one" is enforced against, and it can go stale when the library
  loses the file.

### Measurable Outcomes

- **SC-001**: A reader can turn an open content into a video without leaving the app and without a
  network connection, and the app reports the file's name and length when it is done.
- **SC-002**: The video plays from start to end in the device's own player and in a desktop player: one
  video stream at the chosen resolution and constant frame rate, one audio stream, and a duration equal
  to the reading plus the title card and end hold (within 2 s).
- **SC-003**: Every sentence's highlight is visible while its voice is heard: sampling each sentence's
  slot (a frame at its start, its middle and its end) finds that sentence highlighted and inside the
  visible text area in 100 % of samples.
- **SC-004**: No frame contains the app's controls or the device's status bar/navigation, and the text
  block has margins on all sides at every sampled frame.
- **SC-005**: The video is publishable-shaped — video and audio codecs a video platform accepts, a
  constant frame rate, the chosen aspect/resolution — verified with a standard media analyser rather than
  by eye.
- **SC-006**: On the reference device, a one-minute reading renders in at most five minutes with visible
  progress, and cancelling at any point (checked at about 50 %) leaves no video file for that content.
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
  heights differ by the ratio of those sizes (within 10 %), each in the typeface chosen — the reader's
  choice reaches the video instead of being overridden by it (FR-014).
- **SC-012**: Both offered aspects render and are exactly what the file is: a 16:9 render measures 1920×1080
  and a 9:16 render 1080×1920 in a standard media analyser, each at the constant frame rate, with the
  reader's choice made before the render and visible in the result (FR-007).
- **SC-013**: While a render runs, the page offers progress and Stop and nothing else: no reading, editing,
  appearance, contents, voice or second render is reachable and a touch on the text changes nothing. Stop
  and leaving both ask before they act — the render keeps running (the progress moves on) while the
  confirmation is up, dismissing it leaves the render to finish normally, and confirming it writes no file
  for that content and leaves the page idle (FR-019, FR-009).
- **SC-014**: While a render runs, the page shows the video's own picture and it advances sentence by
  sentence: sampling the page at two moments finds the sentence highlighted and the visible text scrolled
  exactly as the frame being written at that moment, and the render's own frames bear it out (FR-020).
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

## Assumptions

- **A1 — start point and extent.** The video runs from the page's own start point — the highlighted
  sentence, or the first sentence when nothing is highlighted — to the content's last sentence. It never
  covers a selection on its own and never stops before the content's end (FR-004).
- **A2 — the render is silent and in-app.** The render does not play the audio aloud (the point is the
  file); it runs while the user stays in the app, and leaving the recording screen cancels it (FR-009).
- **A3 — the video carries the reader's appearance (clarified 2026-09-25).** The video's text is the
  reader's selected typeface at their selected character size, with the app's highlight colour and reading
  background; what the video decides for itself is the frame, the scale that maps the reading column onto
  it, and the margins. The consequence to accept: at the smallest offered size the video's text is
  genuinely small, because it is the size the reader asked for — the frame must therefore be sized
  generously enough that the smallest size is still legible at 100 %, and the plan proves it on the
  smallest size rather than the largest.
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
- More than one video per content, batch rendering of several contents, a screen that browses every video
  the app has made (a content offers play/share/delete for its own video, US3), or a queue.
- Bitrate, quality-tier, codec and frame-rate pickers, formats beyond the two aspects, and both aspects
  inside one video.
- A video that ends before the content's last sentence (there is no end position), or a video of a
  selection on its own (A1).
- Any voice other than the app's own synthesis, including human voice-over.
