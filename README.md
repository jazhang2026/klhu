# klhu — KalaHoo Reading

A read-aloud reader for language learners: tap a sentence (or the whole page)
and the app speaks it, in the right voice for the language it is written in.
Ships English, 简体中文 (with the Cantonese voices alongside) and Español.

## Features

**Reading aloud**
- Tap a sentence to hear that sentence, or `Read page` to read the page
  paragraph by paragraph with the highlight following along.
- The language is detected **per paragraph** (CJK → Simplified Chinese, Spanish
  accents/function words → Spanish, else English), so one text can mix
  languages and every paragraph still gets its own voice, in order.
- `Pause` keeps the queue and the paragraph in flight; `Resume` re-enters from
  that paragraph (paragraph-granular — there is no dependable mid-utterance
  position). `Stop` discards the queue. A read that ends by itself leaves no
  paused state behind.

**Voices**
- The voice picker lists exactly the voices the OS has installed for the active
  language, with the Chinese list carrying the Cantonese (`yue-HK`) voices: a
  dialect is a voice choice, not a second language.
- Names carry region + engine code and the gender is the only characteristic —
  and genders are **measured** (median F0 per voice, cross-checked against the
  engine's manifest), never guessed. Evidence: `specs/007-…/voice-gender-evidence.md`.
- The pick persists per language; the interface language is a separate choice.

**Editing and the content library**
- Direct edit mode (`Edit`) with the platform undo stack (`Undo` disables itself
  when the history is exhausted and says so), `Save`, `Done`.
- Saved content, written text and the shipped pre-sets live in **one list**:
  tap to load, delete behind a confirmation that warns it cannot be undone (a
  pre-set adds "…returns only if you reinstall the app").
- Titles are generated **from the content** (first non-blank line, whitespace
  collapsed, ≤ 24 characters with an ellipsis, ` (2)` on collision) — never
  translated, so a title cannot drift from the text it names.
- Saving an edited pre-set creates **new** content; the shipped original is
  never modified. Deleting a pre-set writes a tombstone: it stays gone across
  restarts and comes back if the app is reinstalled.
- Storage is one file per content plus a versioned `index.json` under the app
  documents directory (`app_flutter/content/` on Android). The list reads the
  index only — never the texts — so its latency does not grow with text size.
  Writes are `.tmp` + rename, text before index, guards before any write.
- A damaged index is moved aside as `index.corrupt-<ts>.json`, the pre-sets are
  re-seeded, and the repair is **reported** on screen instead of looking like
  data loss. An entry whose text file is gone is listed as damaged and can be
  deleted; the rest of the library keeps working.

**Video**
- `Video` on the reading page renders the content to a **video on the device** — no
  account, no backend, no upload — and shows the video's own picture while it is
  written; `Stop` asks before it throws the render away.
- One sentence per frame, at the reader's own typeface and size, wrapped and
  scrolled a line at a time when it is taller than the frame; the video's last
  frame holds the end. The reader may choose pictures from their own files first
  (any number, re-orderable by hand, removable) — each fills the frame behind the
  sentence, with the words plated so they still read — and choosing none gives
  the plain-background video.
- The finished render plays **before** anything is decided, then `Save` puts it in
  the phone's own gallery under the content's name (one per content, replacing the
  old one), `Share` hands it to the phone's own share list, and `Discard` leaves
  nothing. A kept video is playable, shareable and deletable again from the
  content, and deleting it warns first.
- The video is **rendered, never recorded** (no screen capture, no microphone):
  Dart paints each frame, the Android half encodes them, and the voice is the
  clock — every sentence is synthesised first and the frames follow the audio
  file's own length. Aspect: `16:9 landscape 1080p` or `9:16 vertical (Shorts)`,
  remembered per device.

**Interface and accessibility**
- Interface languages: English, 简体中文, Español — including the OS-visible app
  title, on a fresh install following the device locale.
- Every icon control carries a localized tooltip (which is what Android
  announces as its name), dialog buttons need no gestures, rows are ≥ 44 pt, and
  the semantics tree is asserted in tests.

## Development

```bash
export PATH=$HOME/development/flutter/bin:$PATH   # SDK lives in ~/development/flutter
flutter pub get
flutter gen-l10n                                  # after editing any lib/l10n/*.arb
flutter analyze
flutter test --concurrency=2                      # emulator up ⇒ never the default concurrency on this box
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Launcher icons

The icon comes from `images/kalahoo.jpeg` (1024×1024), configured in
`pubspec.yaml` under `flutter_launcher_icons:`. Regenerating is one command:

```bash
dart run flutter_launcher_icons        # writes android/…/res + ios/…/AppIcon.appiconset
flutter test test/app_icon_test.dart   # the asset contract: sizes, formats, catalogue
```

- `flutter_launcher_icons` is a **dev** dependency; no build step reads the source
  image (so a missing source cannot break a build — the generator itself fails
  loudly), and the source is deliberately **not** a bundled asset.
- After a run, check `git status`: the generator also rewrites
  `ios/Runner.xcodeproj/project.pbxproj` (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
  from `YES` to `AppIcon`, which is the wrong setting — the icon name is already
  declared by `ASSETCATALOG_COMPILER_APPICON_NAME`). Revert it:
  `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.
- Android gets an adaptive icon (white background + the art inset 16 %), so
  launcher masks do not clip the subject; iOS icons are written without an alpha
  channel, which the App Store requires. The iOS set is generated and checked
  structurally here but **not validated** (no macOS on this host).

The emulator/device walk for each feature is scripted — under
`specs/<feature>/scripts/` (`specs/009-app-icon/scripts/`, `specs/010-continue-read/scripts/`,
`specs/011-reading-experience/scripts/`, `specs/012-reading-video/scripts/`); findings, per-scenario
PASS/FAIL rows and the divergences are recorded in `specs/<feature>/breakpoint.md`. A walk driver takes
`ADB_SERIAL` / `KLHU_REPO` / `KLHU_OUT` and prints `RESULT: PASS|FAIL`, so a row can be
re-run on demand.

### Continue Read (010)

The reading page's ▶ reads the highlighted sentence; with nothing highlighted it starts at
the first sentence (a tap/long-press highlights a sentence/paragraph **and** sets the start
position). Continue Read reads from that position to the end, shows the position again after
a restart, and forgets it the moment the visible text changes. Pause/resume works at
sentence granularity: resuming repeats the sentence that was interrupted, never the
paragraph from its top.

```bash
cd specs/010-continue-read/scripts
python3 klhu_walk_continue.py 13      # 13|14|15 the position: set, survive a restart, absent
python3 klhu_walk_continue.py 16      # 16|17 pause/resume + whole reads in EN, ZH, ES
```

Both the range a read started from (`klhu read range: <start>..<end>`) and the sentence
handed to the engine (`klhu speak p<i> s<j> "…"`) are `debugPrint` lines, so a device row is
read from a **debug** build's `adb logcat -s flutter` — and the engine's own
`Synthesis request for locale <tag>` lines are what says which language actually spoke.

### Reading experience (011)

The highlight marks the **sentence** being spoken and the page follows it: a read that starts
below the fold scrolls its position into view, a manual scroll is left alone until the next
sentence, and a resumed read re-paints the sentence it repeats, so the paint and the utterance
agree. The app bar's appearance control — idle only, disabled while a read plays — opens a
screen that previews the page's own text in three typefaces (`default`/`serif`/`mono`) and four
sizes (`small`/`medium`/`large`/`xlarge` = 12/14/18/24 pt); confirming applies the choice to the
reading text **and** the editor and never to the app's chrome, and stores it per device in
`shared_preferences` under `reading_appearance` as `<typeface>||<size>` (dismissing writes
nothing; a malformed record falls back per field). The content list gained a `+`: it resolves to
a request for a **new content**, the page opens a blank focused draft, and Save names the entry
from its text (008's rule, no name prompt) — an empty draft is refused with the existing message,
and leaving a draft creates nothing and leaves the previous content's stored position alone.

```bash
cd specs/011-reading-experience/scripts
python3 klhu_walk_experience.py 7     # 7|8 the page follows a read; an off-screen position comes back
python3 klhu_walk_experience.py 9     # 9|10 a fitting text never moves; Stop keeps the page
python3 klhu_walk_experience.py 16    # 16 the appearance record, a restart, the render
python3 klhu_walk_experience.py 17    # 17 "+" saves a named draft; an empty Save adds nothing
python3 klhu_walk_experience.py 20    # 20|21 the two read buttons, and a touch during a read
```

▶ Read speaks the page's own selection and asks for one when nothing is highlighted; ⏭ Continue Read
reads from that selection (or from the top when there is none), and the position lives exactly as long
as the highlight that shows it. A touch on the text never interrupts a read — playing or paused (011's
2026-09-25 amendments, superseding 010's "a tap during a read stops it": a tap is also how a dimmed
display is woken and how the page's own fling is stopped). Rows 20–21 of
`specs/011-reading-experience/breakpoint.md` are the receipts.

The driver imports `specs/010-continue-read/scripts/klhu_walk_continue.py` for the shared device
mechanics. Rows 7, 8 and 10 are about a page that has to move: at the default display this AVD's
reading area is 718 logical px tall while the longest shipped text is 226, so those parts set
X-Large on the appearance screen and shrink the display (`adb shell wm size 1080x1000`, reset when
the part ends). The highlight is measured as pixels: the app's `klhu follow` geometry is mapped to
the screen (`origin + top × dpr`, origin = the text node's top) and the yellow rows must be that
band with nothing outside it — `breakpoint.md` records the numbers.

### Reading video (012)

The **first feature in this repository with a platform-specific half**: the frames are painted in Dart
(one `TextPainter` fed the page's own style seam — no second text engine) and encoded in Kotlin
(`MediaCodec` AVC + AAC through `MediaMuxer`), with `lib/platform/` as the only seam between them. The
audio is the engine's own file synthesis: pass 1 writes every sentence to its own WAV and reads the exact
length out of the header, pass 2 paints frames to that timeline — so the picture cannot drift from the
voice. The pictures are the reader's own files, chosen through flutter.dev's `file_selector` (the one
dependency this feature adds: no picker of ours, no new permission, no gallery screen).

```bash
cd specs/012-reading-video/scripts
python3 klhu_walk_video.py 31     # a real render, both aspects, probed with ffprobe
python3 klhu_walk_video.py 32     # every sampled frame is its slot's sentence, the screen matched
python3 klhu_walk_video.py 33     # the file's life: review → throw away → keep → play → share → delete
python3 klhu_walk_video.py 34     # a confirmed Stop at ~50 % leaves no file and the library alone
python3 klhu_walk_video.py 36     # spike S2: a one-minute reading, timed, with the bottleneck named
python3 klhu_walk_video.py 49     # the reader's own pictures: every range of a render, frame by frame
KLHU_SKIP_PLAY=1 python3 klhu_walk_video.py 33   # skip the two player steps on a small host
```

The app's own lines are the clock (nothing here sleeps for a moment that lasts seconds):
`klhu render done: <path> <ms>ms <bytes>B frames=<n>`, one
`klhu render slot=i/n frame=start/total kind= frames= scroll= picture= tone= span=a..b text=n` per picture
written, `klhu render time synth=… paint=… send=… finish=…` per render, and `klhu render told: <message>`
for the message the reader was shown. The Kotlin half has **no unit tests and cannot have any that run in
`flutter test`** — the rows above are its whole coverage, which is why it is kept logic-free.

### Dialogue reading (014)

A content can be read as a **dialogue**: a `{角色}` tag at a paragraph's head makes that paragraph the role's
turn, and every role speaks in its own voice out of the app's own language lists — narration (an untagged
paragraph, or a name the reader removed) reads in the ordinary reading voice, a pick decides both the voice
and the pronunciation for that role, and the tag itself is **never spoken**. The reader confirms the roster
the text proposed, and the type is a per-content setting: a content with no type reads exactly as it read
before this feature, and switching it touches nothing else. The editor's 排版/Format is the writer's one
press — it moves every tag to the head of its own paragraph by adding blank lines and nothing else, in one
undo step. The same resolution feeds the video: a dialogue's render speaks each turn in its role's voice and
no frame ever shows a tag. The feature adds no dependency and no platform code.

```bash
cd specs/014-dialogue-reading/scripts
python3 klhu_walk_dialogue.py 23   # four roles: turns, one utterance per sentence, the tag never spoken
python3 klhu_walk_dialogue.py 24   # the assignment against the device's own voices (24 roles, 15 voices)
python3 klhu_walk_dialogue.py 25   # a pick and a removal survive a force-stop, and go with the content
python3 klhu_walk_dialogue.py 26   # switching the type mid-read keeps the reader's place and highlight
python3 klhu_walk_dialogue.py 27   # the dialogue's video: no tag in a frame, a voice per turn
python3 klhu_walk_dialogue.py 28   # spike S1: the device's distinct voices per language and gender
python3 klhu_walk_dialogue.py 33   # the editor's Format press, with the reader's own hands
```

The app's own lines are the evidence, not a still: `klhu roles` (the text's proposal), `klhu speak` per
utterance with its role and its voice, and `role=` on each of the renderer's own lines. The rows, their raw
output, the spike's answer and the two faults this walk found in its own readers are in
`specs/014-dialogue-reading/breakpoint.md`.

## Specs

Development is spec-driven: each feature has `specs/<NNN>-<name>/` with
`spec.md` (requirements + acceptance scenarios), `plan.md`, `research.md`
(measured facts about the device/TTS engine), `data-model.md`/`contracts/` where
it matters, `tasks.md` (one task per artifact, ticked as verified) and
`breakpoint.md` (what the device actually showed).

| Spec | What it added |
|---|---|
| 001-read-aloud | flutter_tts reading, sentence/page ranges, tap-to-read |
| 002-voice-picker | per-language voice list, picked voice persists |
| 003-reading-polish | read/edit modes, highlight, mixed-language paragraphs |
| 004-app-branding-i18n | app title/localization scaffolding |
| 005-voice-pause-resume | pause/resume + voice mapping with measured genders |
| 007-reader-name-spanish-cantonese | Spanish + Cantonese, localized reader name |
| 008-content-storage | the content library: save/list/load/edit/delete, pre-sets as data |
| 009-app-icon | branded launcher icon on Android + iOS from `images/kalahoo.jpeg`, adaptive on Android 8+ |
| 010-continue-read | Continue Read: tap a sentence / long-press a paragraph to set the start position, read from there, resume after pause at the sentence |
| 011-reading-experience | the highlight follows the read sentence by sentence, a per-device typeface/size for the reading text, `+` to add a content from the library |
| 014-dialogue-reading | a content can be read as a dialogue — `{角色}` tags at a paragraph's head, one voice per role from the app's own lists, the reader's confirmed roster and picks stored per content, and the editor's Format press |
| 012-reading-video | the reader's content becomes a video on the device — one sentence per frame at the reader's own size, the reader's own pictures behind it, the engine's voice as the clock — then kept in the gallery, played, shared and deleted; the repository's first platform-specific half |

## Known limitations

- iOS is untested (no macOS on the development host); Android is validated on
  `emulator-5554` (AVD `klhu`, API 36) and on a OnePlus 9.
- The list-open latency bar (≤ 500 ms with a seeded library) is not measured on
  device: dump-based polling costs ~2 s per sample. The structural claim — the
  list never reads text — is covered by a unit test.

## Project development based on spec-kit.
