# Quickstart: 003-reading-polish

1. Picker (US1): extend `lib/voice_picker_screen.dart` (selected highlight,
   autoscroll, scrollbar, count) + widget tests incl. no-✓ assertion;
   `voice_picker_semantics_test.dart` stays green
2. Direct-edit (US2): swap reading area to `TextField` with read/edit/speaking
   modes in `lib/reading_view.dart`; remove paste field + Load; Edit button
   (idle-only) ↔ Done; Read/Read-page/Stop hidden in EDIT; tap-to-sentence
   via `RenderEditable` offset in READ; `onChanged` clears pending sentence
3. Tracking (US3): `ParagraphSpeech` + start/end, `speakParagraphs`
   `onParagraphStart`, view advances/clears highlight + fake-tts tests
4. `flutter analyze` clean, full `flutter test` green (002's 55 must stay green)
5. Verify on Android emulator EN + zh-Hans:
   - US1: select voice B → row B highlighted + centered, no marker anywhere;
     count == list length; TalkBack announces "selected"
   - US2: READ tap sentence → Read speaks it, no keyboard pops; Edit → field
     editable with full typing/paste, Read/Read-page/Stop hidden, only Done;
     Done → back to READ; Edit disabled while speaking; paste/type in area →
     Read page speaks it, no Load step
   - US3: mixed page read → highlight sits on exactly the spoken paragraph,
     advances with the voice, gone at end and on Stop
