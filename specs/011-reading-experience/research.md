# Research: Reading Experience

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

Phase 0 decisions. D1–D3 cover the page following the read and the highlight it follows, D4–D6 the
text appearance, D7–D8 the contents-list "+", D9–D12 the follow rule, the walk driver, what the
highlight change leaves alone, and the copy.

## Grounding corrections

Checked against the checkout and the installed toolchain before planning. Two spec statements do not
survive the check; the plan uses the corrected form and nothing below keeps both versions. A third
item (the highlight's granularity) was a correction in the first version of this plan and is now a
deliberate change to shipped behaviour, recorded below the table.

| Item | The spec said | The system says | Evidence |
|---|---|---|---|
| Typeface source | Assumption: "faces the app **ships** or the platform guarantees" | The app ships **no font at all** (no `.ttf`/`.otf` in the tree; `assets/` holds only `content/presets.json`) and the theme sets no `fontFamily`. The plan therefore takes the platform-guaranteed route: no asset, no download, no runtime network (constitution IV) | `find . -name '*.ttf' -o -name '*.otf'` (excluding `build/`) → empty; `main.dart:83-86`; `find assets -type f` → `assets/content/presets.json` |
| No-clipping guarantee | FR-012 "keep every line of the text inside the page at the largest offered size" | Text **wraps**, so horizontal overflow cannot occur at any size; the real risk is a size so large that a line becomes a single word per line — a readability question, not a clipping one. The plan states the numeric check (the longest shipped line at the largest size inside a 360 dp-wide viewport, no paragraph-overflow exception) instead of a vague "no clipping" | `reading_view.dart:723-739` (one `RichText` in a `SingleChildScrollView`, free to wrap); the shipped widths: `TextPainter`-measured in the device row (quickstart 12) |

### Behaviour this feature changes: the tracking highlight (003, amended 2026-09-24)

The spec's Input and FR-001/SC-001 say "the highlighted sentence". The shipped system highlighted the
**paragraph** being read: the tracking callback fires once per paragraph (on its first sentence) and
the view paints that whole paragraph as one span, while the engine already receives one sentence at a
time (010) — so the yellow could span more than a screenful and could disagree with what was being
spoken. Evidence: `reading_view.dart:548-557` (`SegmentUnit.paragraph` from `onParagraphStart`),
`reader_service.dart:351-357` ("003's tracking is paragraph-level … nothing downstream counts the
calls"), `reading_service.dart`'s queue `:281-299`.

The amendment (`spec.md` **Input (amendment)**, FR-020/FR-021, SC-008) makes the highlight the
**sentence** being spoken. What the implement stage then owns:

- the tracking callback reports the sentence (D2), so the highlight, the spoken utterance and 010's
  resume point are the same unit — a resumed read re-paints the sentence it repeats;
- the page's follow target stops being a sub-range of a larger highlight and becomes exactly the
  painted span (D1), which also removes the "paragraph taller than the screen" caveat the first plan
  carried;
- behaviour 003 shipped and pinned changes: the tests asserting paragraph-level tracking are
  **rewritten** to pin sentence-level tracking, never deleted. Measured sites: 12 test files reference
  the callback; 9 hold fake `speakParagraphs` signatures that must take the new parameter; 4 read the
  yellow span (`reading_view_test.dart:574,588`, `reading_view_continue_test.dart:572,584`,
  `reading_view_mixed_test.dart:224,245`, `reading_view_edit_test.dart:106` — the last one's two
  selection tests, "tap highlights sentence" / "long-press highlights paragraph", are **unchanged**);
  3 drive the tracking callback per paragraph (`reading_view_continue_test.dart:286,289`,
  `reading_view_mixed_test.dart:213`, plus the drive inside `reading_view_test.dart`);
- the tap (sentence) and long-press (paragraph) *selection* highlights are not part of this change;
- the older specs' artifacts that state the old granularity are **reported to the user, not swept**
  (rewriting reviewed records is their call): `specs/003-reading-polish/spec.md:59-60`,
  `specs/003-reading-polish/plan.md:20`, `specs/003-reading-polish/tasks.md:65`,
  `specs/003-reading-polish/quickstart.md:20`, `specs/003-reading-polish/data-model.md:34`;
  `specs/005-voice-pause-resume/spec.md:106`, `specs/005-voice-pause-resume/breakpoint.md:108`;
  `specs/010-continue-read/data-model.md:54,83,94,144-145`, `specs/010-continue-read/plan.md:27,191`,
  `specs/010-continue-read/quickstart.md:119`.

Two further observations, recorded because they bound what the feature may claim:

- **The app bar's actions are not mode-gated today** (the contents list and the voice picker are
  tappable during a read — only Edit is idle-gated). Spec FR-014 asks for the *appearance* control to
  be idle-only, so the plan adds that gate to the new action alone and leaves the shipped actions as
  they are (`reading_view.dart:673-696`, `:799-805`).
- **The constitution's platform floors are not what the project files carry**: it says Android 10+
  (API 29+) and iOS 16+, while the build resolves `minSdk` to Flutter's default 24 and the Xcode
  project targets iOS 15.0. Pre-existing, unrelated to this feature (which adds no platform code) —
  reported to the user rather than silently changed. Evidence: `android/app/build.gradle.kts:22`;
  `FlutterExtension.kt:26` (`val minSdkVersion: Int = 24`); `ios/Runner.xcodeproj/project.pbxproj`
  (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`).

## Verified environment facts

| Fact | Value | Evidence |
|---|---|---|
| Toolchain | Flutter 3.47.5 stable, Dart SDK `^3.13.3` | `flutter --version`; `pubspec.yaml:24` |
| Dependencies in play | `shared_preferences ^2.5.5`, `flutter_tts ^4.2.3`, `intl ^0.20.3`, `path_provider ^2.1.6` | `pubspec.yaml:38-47` |
| New dependency | **none** — this feature adds no package and no asset | (design decision D4/D5) |
| Per-device settings home | `SharedPreferences.getInstance()`, used by `VoiceStore` and `ReadPositionStore`; the interface language goes through `LocalizationService` | `voice_store.dart:28,36`; `read_position_store.dart:51,69,89`; `localization_service.dart:13` |
| Reading text style seam | one method, `_contentTextStyle(context)`, built from `Theme.of(context).textTheme.bodyMedium!`; 4 occurrences in `lib/reading_view.dart`, 0 elsewhere | `reading_view.dart:645-650`; `grep -rc '_contentTextStyle' lib/*.dart` |
| Reading text size today | `bodyMedium` = **14.0** (Material 3) | Flutter SDK `material/text_theme.dart:52` |
| Text widget | one `RichText` (`key: _textKey`) in a `SingleChildScrollView`, no `ScrollController`; the same single-paragraph rule protects both display states | `reading_view.dart:619-621`, `:723-739` |
| Paragraph handle already used | tap→offset goes through the `RenderParagraph` found by `_textKey` | `reading_view.dart:461-464` |
| Reveal primitive | `RenderObject.showOnScreen({descendant, rect, duration, curve})` — a **rect** reveal, animated | Flutter SDK `rendering/object.dart:4140-4145` |
| Per-sentence geometry | `RenderParagraph.getBoxesForSelection(selection)` → `ui.TextBox` list | Flutter SDK `rendering/paragraph.dart:1129` |
| Sentence offsets today | computed inside the service (`sentenceRanges(paragraph.text)`) but **not** exposed: `_Utterance` carries text + paragraph + sentence index only | `reader_service.dart:281-299` |
| Reader contract | `Reader.speakParagraphs(speeches, {onParagraphStart})`; `Reader` is the fakeable seam for widget tests. This feature replaces that callback with the sentence-level one (D2) | `reader_service.dart:26-39` |
| Save path | `ContentStore.saveEdited(SavedContent?, String)` — a `null` loaded creates a new entry, an empty text raises `emptyText` → "There is nothing to save" | `content_store.dart:335`; `reading_view.dart:406`, `:419-427` |
| List route | `Navigator.push<SavedContent>`; the screen pops the tapped entry or null on back | `reading_view.dart:365-366`; `content_list_screen.dart:10-12`, `:148` |
| List route references | 3 sites: the view + 2 in `test/content_list_test.dart` (77, 133); no test taps the folder action | `grep -rn 'ContentListScreen\|push<SavedContent>' lib/ test/` |
| EDIT entry | `_enterEdit()` stops the reader, seeds the controller from `_content`, installs a fresh undo stack, focuses the field | `reading_view.dart:293-311` |
| Unsaved-edit guard | `_hasUnsavedEdits` + `_confirmDiscard()` already guard every content switch | `reading_view.dart:328-329`, `:369`, `:378-397` |
| Localizations | 4 ARBs × **45** message keys, template `app_en.arb`, generated files committed; a parity test gates template↔translation keys both ways | `python3 -c` key count per ARB; `l10n.yaml`; `test/l10n_keys_test.dart:41,57` |
| Prefs mocking in tests | `SharedPreferences.setMockInitialValues({})` in `setUp` (6 files); `reading_view_test`, `_edit_test`, `_mixed_test`, `_pause_test` do **not** mock it, so an unmocked `getInstance()` must stay harmless | `grep -rn setMockInitialValues test/*.dart` |
| Device | AVD `klhu` = `emulator-5554`, API 36, app `com.example.klhu`; 208 font files | `adb devices`; `ls /system/fonts | wc -l` |
| Device font map | `<family name="serif">` → `NotoSerif-Regular.ttf`; `<family lang="zh-Hans">` (lines 1411-1451) contains **both** `NotoSansCJK-Regular.ttc` and `NotoSerifCJK-Regular.ttc`; generics `monospace`, `sans-serif`, `sans-serif-condensed` exist | `/system/etc/fonts.xml` on the emulator |
| 010 walk helpers | module-level and importable: `adb`, `dump`, `tap_node`, `log_lines`, `yellow_pixels`, `sentence_starts`, `preset_text`, `wait_for_idle`, `step` | `specs/010-continue-read/scripts/klhu_walk_continue.py:38-270` |

## D1. Follow the read by revealing the spoken sentence's box

- **Decision**: keep the single `RichText`. At each spoken sentence, measure that sentence's box with
  `RenderParagraph.getBoxesForSelection` (min top, max bottom), convert it into viewport coordinates,
  and when the box is **not fully inside** the viewport call
  `showOnScreen(rect: box, duration: 200ms, curve: easeOut)` on the paragraph — the framework's own
  minimal reveal, which also clamps at both ends of the scrollable. The box is the span the highlight
  already paints (D2/FR-020), so the page follows exactly what the eye sees.
- **Rationale**: the paragraph is already the handle the page uses for gesture→offset
  (`reading_view.dart:461-464`), so the sentence's geometry comes from what is actually painted — no
  second layout to drift from the first. `showOnScreen` needs no `ScrollController`, no offset
  arithmetic and no clamping of its own; a text that fits produces no scroll at all, which is FR-003
  for free. With the highlight at sentence level there is one span, one measurement and one reveal,
  and no state in which the painted block and the followed sentence differ.
- **Alternatives considered**:
  - *Per-sentence widgets + `Scrollable.ensureVisible`* — rejected: it would break the
    single-`RichText` invariant the page depends on (the plain and highlighted states must lay out
    identically, `reading_view.dart:619-621`) and the gesture→offset math that assumes one paragraph.
  - *Manual `ScrollController.animateTo` with our own offset math* — rejected: reimplements
    `RenderAbstractViewport.getOffsetToReveal` (including the max-scroll clamp) for no gain.
  - *Re-laying the text in a throwaway `TextPainter` to measure* — rejected: duplicates layout; any
    style/width divergence silently measures a different paragraph than the one painted.
  - *`showOnScreen` on the whole paragraph* — rejected: it can only reveal the paragraph, which for a
    paragraph taller than the viewport leaves the spoken sentence off screen — the exact complaint.

## D2. The tracking callback reports the spoken sentence

- **Decision**: replace `onParagraphStart(int index)` with
  `onSentenceStart(SpokenSentence unit)` on `Reader.speakParagraphs`, where `SpokenSentence` is a small
  immutable value carrying the paragraph index, the sentence index and the sentence's absolute
  `start`/`end` offsets in the content. `_Utterance` gains those two offsets (it already computes them
  from `sentenceRanges`); the callback fires once per sentence, immediately before that sentence is
  handed to the engine, generation-guarded exactly as today. The view paints
  `TextSegment(start, end, SegmentUnit.sentence)` and reveals the same span.
- **Rationale**: one callback, one unit, no dead surface. With the highlight at sentence level (the
  amendment), nothing consumes paragraph-granular tracking any more, so keeping the old parameter
  would leave an unused argument on a contract that three specs share. The service is the only layer
  that maps text → absolute offsets, and it already does so to build its queue, so the sentence's
  identity and position exist there for free.
- **Ripple (measured, for the implement stage)**: 12 test files reference the old callback; 9 hold
  fake `speakParagraphs` signatures that must take the new parameter, because Dart rejects an override
  that omits a named parameter (`branding_test`, `spanish_localization_test`, `voice_picker_test`,
  `voice_picker_semantics_test`, `reading_view_test`, `_edit_test`, `_mixed_test`, `_pause_test`,
  `_continue_test`); `reader_service_test` drives the callback in 6 places (`:172`, `:183`, `:211`,
  `:244`, `:352`, `:397`). Expectations that pin **paragraph-level painting** change to sentence level;
  expectations about *when* a callback fires and in what order stand, because the drive is the same
  and only its unit is finer. The files whose fakes only forward the callback and never assert on
  granularity are signature-only edits.
- **Alternatives considered**:
  - *Keep `onParagraphStart` and add `onSentenceStart`* — rejected: an unused parameter on a published
    contract, and two tracking notions where the spec now has one.
  - *Keep firing `onParagraphStart` once per sentence* — rejected: the name would lie, and every
    reader of the seam would have to learn that "paragraph" means "sentence" here.
  - *Four positional parameters instead of a value object* — rejected: a four-argument positional
    callback invites mis-ordering at every call site; the value object names its fields.
  - *The view re-derives each sentence's range from `_content`* — rejected: a second implementation of
    the same mapping, and the two can disagree on a resumed read whose first "sentence" is a paragraph
    remainder (`reader_service.dart:274-280`).
  - *Report sentences but keep painting the paragraph* — rejected: that is the amendment's opposite,
    and it leaves the highlight disagreeing with the speech.

## D3. Evidence line for the follow behaviour

- **Decision**: the view logs, once per followed sentence and **after** the reveal settles:
  `klhu follow: p<i> s<j> visible=<0|1> top=<int> bottom=<int> viewport=<int>` (debug builds only, the
  same `debugPrint` channel as `klhu read range`). The device row asserts, for every line of a full
  read, `visible=1` and `0 <= top < bottom <= viewport`. The paint half is a pixel claim: the
  screenshot taken while a sentence is spoken is counted for yellow pixels **inside** the reported
  `top..bottom` band and outside it — inside > 0, outside ≈ 0 — which is what shows the highlight
  covers exactly the spoken sentence and nothing more (SC-008).
- **Rationale**: `flutter_tts` and the engine never report what is on screen, and the stored state
  says nothing about scrolling. This line is emitted by the layer that makes the decision and carries
  the two numbers the claim needs, at the granularity of the claim (per sentence) — the engine's own
  `klhu speak p<i> s<j>` line correlates with it 1:1. The band count is the sentence-level version of
  the page's existing paint-checking rule (010 relied on a whole-screen yellow count, which cannot
  tell one sentence's span from a whole paragraph's).
- **Alternatives considered**:
  - *Rely on a whole-screen yellow count alone* — rejected as the primary evidence: it cannot
    distinguish the amended sentence-level paint from the old paragraph paint, which is exactly the
    change under test. Kept as the coarse cross-check.
  - *Log the requested scroll target instead* — rejected: it states what the app asked for, not what
    the page shows once the animation has run.
  - *No line, reviewer's eye only* — rejected: a `[device]` row has to cite a line it reads.

## D4. The appearance lives in `shared_preferences`

- **Decision**: a new `lib/appearance_store.dart`, shaped like `ReadPositionStore`
  (`read_position_store.dart:38-108`): synchronous-shaped async load with **every** failure caught →
  the default appearance, `debugPrint` on failure, nothing repaired, nothing thrown. Namespaced keys
  (contract: `contracts/appearance-format.md`). The view holds it as a plain field, exactly as it
  holds `_positions` (`reading_view.dart:96`).
- **Rationale**: `shared_preferences` is already the app's per-device UI state store (voice picks,
  interface language, read positions) and needs no new dependency. The catch-everything shape keeps
  reading working when storage is absent — the property the four unmocked `reading_view_*` test files
  depend on (they never call `setMockInitialValues`).
- **Alternatives considered**:
  - *An optional constructor parameter on `ReadingView`* — rejected: no consumer needs a fake (the
    prefs mock covers every case) and the optional-parameter convention already exists only where a
    real fake is used (`reader`, `voiceStore`, `contentStore`); adding one would ripple through the 9
    test files that construct the view.
  - *The library's `index.json`* — rejected: it is library metadata, version-locked, and its
    unexpected-version path is a destructive repair (008's contract) — the wrong home for view state.
  - *One record per content* — rejected: the user asked for the app to remember **their** choice, not
    a per-text style; per-content records also have no id before a save exists.
  - *A new file under the documents directory* — rejected: a file, a path and a parse for two scalars,
    and `path_provider` is used for text that must not live in the prefs map (008 D1).

## D5. Three faces, mapped per platform, no bundled font

- **Decision**: the picker offers `default` (today's look: no family override), `serif` and `mono`,
  resolved through a small platform table — Android: `serif` / `monospace`; iOS: `Times New Roman` /
  `Courier New`; `default` never sets a family. The stored value is the app-level key, never the
  platform family name.
- **Rationale**: the app ships no font, and the constitution's simplicity principle ("YAGNI") is
  against pulling 10–20 MB of CJK-shaped assets into the repo for a comfort setting. The
  platform-guaranteed route is measurable on the validation device (fonts.xml declares `serif`,
  `monospace`, `sans-serif`), leaves the current look as the default, and lets the family set grow
  later without touching the stored format.
- **Measured nuance to carry into the validation row**: for Han text the generic families fall back to
  the lang-tagged CJK family, which on this device holds both a sans and a serif CJK face
  (`fonts.xml:1411-1451`). Whether the Han glyphs change with the face is a device-level question the
  walk answers with a screenshot and a text-region pixel comparison (quickstart 15) — the plan claims
  only what is required (no missing glyphs) and records what is observed.
- **Alternatives considered**:
  - *Bundle a Latin+CJK face per family* — rejected: 10–20 MB of assets for a comfort setting, plus a
    licence file and a font that ages with the repo (constitution V).
  - *Offer only sizes* — rejected: the user asked for a typeface choice (spec FR-006).
  - *Download a font on first run* — rejected: constitution IV (on-device first), and an offline
    failure path with no fallback worth writing.
  - *Advertise Android generics on iOS too* — rejected: `serif`/`monospace` are not CoreText family
    names; the picker would silently do nothing on iPhone. iOS names in the table are unverified on
    this host (no macOS) and that row stays `[structural]`/UNVERIFIED in the validation guide.

## D6. Four named sizes, the current size as the default

- **Decision**: sizes `small` 12, `medium` **14** (the shipped `bodyMedium`, so the default rendering is
  byte-identical to today), `large` 18, `xlarge` 24; the stored value is the **name**, the point size
  is a constant in the app. The chosen size/family is applied by `_contentTextStyle` alone, which both
  text-rendering modes already use.
- **Rationale**: one seam (`reading_view.dart:645`) covers the rich text and the edit field, so the
  choice cannot apply to one and not the other (FR-009); storing a name keeps a later retune from
  being a data migration, and keeps every stored value inside the pre-measured width guarantee
  (FR-012).
- **Alternatives considered**:
  - *Store a numeric point size* — rejected: an arbitrary stored number can be outside the measured
    width range, and the spec says the user picks from the sizes the app offers (FR-007).
  - *A free slider* — rejected: same reason; explicitly out of scope in the spec.
  - *Apply the choice through the theme* — rejected: it would change the app bar, buttons and dialogs
    too, which FR-009 forbids.

## D7. The contents list returns a typed result

- **Decision**: `ContentListScreen` pops a `ContentListResult` — `PickedContent(SavedContent entry)`
  or `NewContentRequest` — and `_openContentList` switches on it: the first path is today's
  `_loadEntry`, the second resets to a blank, unnamed page and reuses `_enterEdit()` (which seeds the
  controller from `_content`, installs the undo stack and focuses the field). The unsaved-edit guard
  (`_hasUnsavedEdits` + `_confirmDiscard`) runs before either path, as it does today.
- **Rationale**: the screen's existing rule is that "loading is the caller's decision"
  (`content_list_screen.dart:10-12`); a result type keeps that rule and gives the caller the one extra
  outcome it needs, typed rather than inferred. `_enterEdit` already implements "blank, editable, ready
  to type" for the empty-content case.
- **Alternatives considered**:
  - *A callback parameter on the screen* (`onAddNew`) — rejected: it pushes the caller's navigation
    intent into the screen, and the screen would still have to pop something to close.
  - *Create the entry when "+" is tapped* — rejected: violates FR-016/FR-018 (no entry before a
    successful save) and 008's naming rule (a name comes from the text).
  - *Pop a sentinel `SavedContent`* — rejected: a fake entry in a type that means "a real library row".
  - *`push<Object>` plus `is`-checks* — rejected: untyped route result.

## D8. The appearance control is a pushed screen with a live preview

- **Decision**: `lib/appearance_screen.dart`, reached from a new app-bar action on the reading page
  (icon `Icons.format_size`, tooltip from the ARB, **disabled while a read is playing** — the gate Edit
  already uses). The screen renders the text on screen (`_content`) in the candidate style, offers the
  typeface and size rows, and pops the chosen appearance; back/without confirming pops nothing, so no
  write happens.
- **Rationale**: a pushed screen is the app's existing pattern for a choice with a preview
  (`voice_picker_screen.dart`), gives the preview real room, and keeps "preview then confirm" (FR-008)
  and "nothing is remembered unless confirmed" (US2 scenario 4) as two separate outcomes of one route.
- **Alternatives considered**:
  - *A dialog or bottom sheet* — rejected: the preview needs vertical room on a phone, and the app has
    no such pattern.
  - *Inline controls over the reading area* — rejected: they would cover the very text being previewed.
  - *Apply immediately on tap, no confirm* — rejected: contradicts FR-008/US2 scenario 4 and would
    write a preference on every exploratory tap.

## D9. Follow only on a sentence change, never on a manual scroll

- **Decision**: the follow routine runs once per `onSentenceStart`, keyed by the read generation and
  the (paragraph, sentence) pair; it does nothing when that pair is unchanged or when the sentence is
  already fully visible. A manual scroll is therefore never undone until the read moves on (FR-005),
  and pausing/resuming at the same sentence does not yank the page back (FR-004's second half).
- **Rationale**: FR-003/FR-005 are both about *not* moving; the cheapest way to honour them is to make
  movement the exception that only a new sentence can trigger.
- **Alternatives considered**:
  - *Re-reveal on every callback invocation* — rejected: a resume re-reports its sentence
    (`reader_service.dart:351-357`), which would drag the page back under the user's finger.
  - *A scroll listener that re-asserts visibility* — rejected: it fights the user by construction.

## D10. The walk driver reuses 010's helpers

- **Decision**: `specs/011-reading-experience/scripts/klhu_walk_experience.py`, one function per
  quickstart scenario, dispatched by argv, importing 010's module for the shared mechanics
  (`sys.path.insert(0, '../010-continue-read/scripts'); import klhu_walk_continue as w`) instead of
  copying dump/tap/logcat/pixel helpers.
- **Rationale**: 010's helpers are module-level precisely so a later spec can reuse them
  (`klhu_walk_continue.py:38-270`); the new parts add only what 011 needs (the follow-line parser, the
  text-region pixel comparison, the list's add action).
- **Alternatives considered**: *copy the helpers* (rejected: two divergent copies of device mechanics);
  *extend 010's driver* (rejected: it is 010's transcript, and its scenario numbers are its own).

## D11. What the highlight change does *not* touch

- **Decision**: the gesture highlights keep their shipped granularity and lifetime — a tap selects and
  paints a sentence, a long-press selects and paints its paragraph, both cleared by a read end/Stop and
  by editing (`reading_view.dart:459-478`); Continue Read still starts at that selection (010). Only
  the **tracking** highlight changes unit (FR-020).
- **Rationale**: the amendment is about following the read, not about the selection UI three shipped
  specs and their tests pin. Keeping selection as-is also keeps long-press useful: it is the only way
  to scope a read to a whole paragraph, and the tests that assert it (`reading_view_edit_test.dart:168`,
  `:226`) stay green unchanged.
- **Alternatives considered**: *make long-press select a sentence too* — rejected: it would remove the
  coarse selection and rewrite 003/010 behaviour that is not under discussion; *paint the selection and
  the tracking span as two different colours* — rejected: the spec asks for one clear signal, and two
  colours on one line of text is worse to read than one.

## D12. Copy: new ARB keys in all four locales

- **Decision**: new message keys for the add action, the appearance screen and its rows
  (`addContentButton`, `appearanceButton`, `appearanceTitle`, `fontLabel`, `sizeLabel`,
  `previewLabel`, `fontDefaultLabel`, `fontSerifLabel`, `fontMonoLabel`, `sizeSmallLabel`,
  `sizeMediumLabel`, `sizeLargeLabel`, `sizeXLargeLabel`) added to `app_en.arb` (template) **and** the
  three translations, followed by `flutter gen-l10n`; the regenerated
  `lib/l10n/app_localizations*.dart` are committed.
- **Rationale**: `test/l10n_keys_test.dart` enforces key parity in both directions, so a partial
  translation fails the suite — the rename/translation work is one atomic edit.
  `git status --short lib/l10n` after generation is the proof it is reproducible.
- **Alternatives considered**: *English-only labels for a settings screen* — rejected: the app ships
  three interface languages and the parity test refuses the shape.
