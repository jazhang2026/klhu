# Tasks: Read-Along Language Learning

**Input**: Design documents from `/specs/035-read-along/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: INCLUDED — constitution III (test-first) requires failing tests before implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Path Conventions

- Single project: `lib/`, `test/`, `specs/` at repository root

---

## Phase 1: Setup

- [X] T001 Create git branch `035-read-along` from `main`
- [X] T002 [P] Add dependencies `speech_to_text: ^7.5.0` and
  `permission_handler: ^13.0.2` to `pubspec.yaml`; run `flutter pub get`
- [X] T003 [P] Add `RECORD_AUDIO` permission to
  `android/app/src/main/AndroidManifest.xml`; add iOS
  `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription`
  strings to `ios/Runner/Info.plist` (and macOS equivalent if present)
- [X] T004 [P] Add Learn-mode l10n keys to `lib/l10n/app_en.arb`,
  `app_es.arb`, `app_zh.arb`, `app_zh_Hans.arb` (toggle tooltip, mic
  listening/recording states, score labels, missed/extra words, unscored
  reasons, Stop-summary title/empty state, permission-denied hint) and
  regenerate localizations

## Phase 2: Foundational (blocking prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 [P] Create `lib/learn/speech_scorer.dart`: `ScoreResult`
  `{accuracy, transcript, missed, extra}` + `scoreTranscript(target,
  recognized)` — normalization (lowercase, strip punctuation, collapse
  whitespace), Latin whitespace tokens vs CJK character unigrams, LCS
  alignment → matched/target accuracy — pure Dart per data-model.md
- [X] T006 [P] Create `lib/learn/speech_recognizer.dart`: `SpeechRecognizer`
  abstract seam (`initialize`, `listen(localeId, onResult, onDone,
  onError)`, `stop`) + `PlatformSpeechRecognizer` wrapping
  `speech_to_text` with `SpeechListenOptions(onDevice: true,
  listenFor: ~15s, pauseFor: ~3s)` + `localeIdFor(language)` mapping
  en→en_US, zh→zh_CN, es→es_ES, else null — per research.md R1/R2/R8
- [X] T007 Create `lib/learn/learn_session.dart`: `LearnAttempt`,
  `SentenceResult`, `LearnSession`, `LearnState` state machine
  (idle→reading→listening→scoring→waiting→stopped), `summary()`,
  cycle counting (exactly 3 attempts per sentence), unscored-reason
  enum — pure Dart, no Flutter imports — per data-model.md
- [X] T008 Create `test/learn_session_test.dart`: 3-cycle progression,
  sentence switch mid-cycle, waiting state after 3rd attempt, Stop
  summary aggregation incl. unscored attempts — tests FIRST (must fail
  before T007 lands is acceptable order: write test, then implement)
- [X] T009 [P] Create `test/speech_scorer_test.dart`: normalization,
  en/es word-level diffs (perfect/partial/total mismatch), zh character
  diffs, empty transcript, empty target — tests FIRST
- [X] T010 [P] Create `test/speech_recognizer_test.dart`: `FakeSpeechRecognizer`
  + locale mapping tests; verify seam signatures drive listen/stop/error
  without platform channels

**Checkpoint**: scorer, session machine, and recognizer seam are green;
user story work can begin.

## Phase 3: US1 — Start a Learn session (P1) 🎯 MVP

**Goal**: mode toggle beside existing controls swaps page into Learn
controls; tapping a sentence highlights it; leaving Learn restores normal
controls with zero change to existing functions.

**Independent Test**: enter Learn on a saved text, tap a sentence, verify
highlight + Learn controls; exit and verify read/continue/edit unchanged.

- [X] T011 [US1] Create `lib/learn/learn_controller.dart` skeleton:
  owns `LearnSession`, exposes `active` flag, `startSentence(segment)`,
  `stop()`, and a `ChangeNotifier`/callback surface for UI state —
  TTS/mic wiring stubbed for US2
- [X] T012 [P] [US1] Create `test/reading_view_learn_test.dart` (US1 cases):
  toggle button present in idle control row; tapping it swaps to Learn
  controls (mic state + Stop + exit toggle); Learn tap highlights the
  tapped sentence and begins its cycle (fake reader/recognizer injected);
  exit Learn restores original controls; existing tap-read and Continue
  Read still work after exit — tests FIRST
- [X] T013 [US1] Wire Learn toggle + Learn control row into
  `lib/reading_view.dart`: additive `_learnActive`/`_learn` state, toggle
  IconButton in the existing bottom `Row` (idle branch only), branch in
  `_onTapText`/`_resolveAt` path so Learn taps select+highlight without
  triggering normal read; Learn controls show mic state, Stop, exit —
  per FR-001/FR-012, no changes to non-Learn paths
- [X] T014 [US1] Ensure Learn mode interacts correctly with existing
  guards: disabled during EDIT/review/rendering; `_isSpeakingOrPaused`
  semantics preserved for Learn's own TTS playback; wakelock held while
  Learn reads (reuse existing sync); leaving page disposes Learn state

## Phase 4: US2 — Follow-along cycle (P1)

**Goal**: per sentence — KalaHoo reads → mic captures repeat → score →
×3; comments never read; unscored degradation paths.

**Independent Test**: tap one sentence with fake TTS + fake recognizer;
verify 3 read-then-record cycles, per-attempt scores, comment exclusion.

- [X] T015 [P] [US2] Extend `test/reading_view_learn_test.dart` (US2 cases)
  and/or `test/learn_controller_test.dart`: TTS completion awaited before
  `listen()` opens (ordering assertion on fakes); 3 cycles per sentence;
  final transcript scored via `scoreTranscript`; attempts recorded on
  `LearnSession`; comments never passed to reader — tests FIRST
- [X] T016 [US2] Implement cycle orchestration in
  `lib/learn/learn_controller.dart`: read sentence via existing
  `Reader`/`ReaderService` speak path → await completion → request mic
  permission lazily (first attempt only) → `SpeechRecognizer.listen` →
  on final result `stop()` + score + record attempt → next cycle or
  `waiting`; handle silence/timeout/error → unscored attempt; TTS error →
  idle-with-error — per FR-003/FR-009, research R4
- [X] T017 [US2] Map resolved read language → `localeId` for recognition
  (reuse speech_resolver output; unsupported → `unsupportedLanguage`
  unscored); ensure Learn reads resolve language exactly like tap-read
  (role override → main override → detection) — FR-008
- [X] T018 [US2] Surface per-attempt result UI in `lib/reading_view.dart`:
  score badge/status near the practiced sentence or in the Learn control
  area (accuracy %, transcript, missed/extra words per FR-011); mic
  listening indicator during capture; unscored reasons localized
- [X] T019 [US2] Handle edge cases: mic permission denied → read-only
  cycles with `permissionDenied` unscored; recognizer initialize false →
  `recognitionUnavailable`; backgrounding mid-cycle → clean pause/restart;
  tapping another sentence mid-cycle abandons and restarts (US4 overlap)

## Phase 5: US3 — Stop and see session result (P2)

**Goal**: Stop ends Learn and shows per-sentence summary incl. unscored.

**Independent Test**: run partial session, Stop, verify summary lists
practiced sentences with scores and unscored counts; dismiss → normal mode.

- [X] T020 [P] [US3] Add US3 cases to `test/reading_view_learn_test.dart`:
  Stop during idle/waiting/listening states; summary shows each sentence's
  best/last score + attempt/unscored counts; dismiss returns to normal
  controls — tests FIRST
- [X] T021 [US3] Implement Stop + summary in `lib/reading_view.dart` +
  `lib/learn/learn_controller.dart`: Stop callable from Learn controls in
  any state → session `stopped` → modal bottom sheet/dialog listing
  `LearnSession.summary()` (per-sentence text, score, attempts, unscored
  reasons) → dismiss exits Learn to normal controls — FR-007, research R9
- [X] T022 [US3] Verify summary handles empty session (Stop before any
  sentence) and all-unscored sessions gracefully (localized empty states)

## Phase 6: US4 — Re-practice any sentence (P3)

**Goal**: tap any sentence (incl. completed) restarts its 3-cycle practice.

**Independent Test**: practice A, practice B, re-tap A → A restarts cleanly.

- [X] T023 [P] [US4] Add US4 cases to `test/reading_view_learn_test.dart`:
  tap completed sentence restarts its cycle; prior `SentenceResult`
  preserved/appended per data-model (attempts accumulate or reset —
  confirm with spec: re-practice = new 3-cycle run, result updates);
  rapid re-taps don't corrupt session state — tests FIRST
- [X] T024 [US4] Verify/adjust `LearnSession` + tap path so re-tapping a
  sentence starts a fresh 3-cycle run while keeping session history
  coherent (decide: attempts append to same SentenceResult vs reset —
  document choice in code)

## Phase 7: Polish & cross-cutting

- [X] T025 Run `flutter analyze --no-pub` — clean (pre-existing warnings only)
- [X] T026 Run `flutter test --concurrency=2` — all tests pass
- [X] T027 [P] Update `specs/035-read-along/quickstart.md` if implementation
  deviates; check off completed quickstart scenarios
- [ ] T028 Device walk on OnePlus 13 (`38821a76`) per quickstart.md all 10
  steps: toggle, 3 cycles, echo gating, wait state, comments, Stop summary,
  permission denial, regression spot-check, language matching, airplane-mode
- [ ] T029 Commit feature work on `035-read-along` branch; merge to `main`
  after user approval

---

## Dependencies

```text
Phase 1 (Setup) ──▶ Phase 2 (Foundational) ──▶ US1 (P1) ──▶ US2 (P1)
                                                  │            │
                                                  └──▶ US3 (P2) ──▶ US4 (P3) ──▶ Polish
```

- US2 depends on US1 (needs Learn mode + tap path)
- US3 depends on US2 (needs scored attempts to summarize)
- US4 depends on US1+US2 (re-tap of working cycle)
- MVP = Phase 1 + 2 + US1 (+ minimal US2 stub) — entry point demonstrable

## Parallel opportunities

- Phase 1: T002/T003/T004 parallel
- Phase 2: T005/T006/T010 parallel (different files)
- Within stories: test tasks [P] can run alongside unrelated impl tasks
  in other files; widget test file shared across US1–US4 so story test
  additions are sequential

## Implementation strategy

MVP first: Setup → Foundational → US1 gives a working Learn mode shell.
Then US2 makes it functional, US3 adds the payoff (summary), US4 polish.
Each phase independently testable per quickstart.md.

## Notes

- `ReadingView` is ~4900 lines — keep Learn wiring minimal; all logic in
  `lib/learn/` per plan.md R6.
- Widget tests must inject fakes for `SpeechRecognizer` + `Reader`; never
  touch real `speech_to_text`/`permission_handler` platform channels.
- If `speech_to_text` APIs differ from assumed signatures, adapt
  `PlatformSpeechRecognizer` only — seam contract stays.
- iOS permission strings added in T003 even though Android is the
  verification target (cheap, prevents future surprise — research.md).
- Constitution III: every story phase writes failing tests before impl.
- Constitution IV: no network calls anywhere in Learn path; verify in
  review that no provider client is touched.

## Task count

- Setup: 4 | Foundational: 6 | US1: 4 | US2: 5 | US3: 3 | US4: 2 | Polish: 5
- **Total: 29 tasks**

## Suggested MVP scope

Phases 1–3 (T001–T014): Learn mode entry + sentence selection working
with stubbed cycle — demoable on device before scoring lands.

## Format validation

All tasks follow `- [ ] T### [P?] [US#?] description with file path`.
Story labels only on US-phase tasks; Setup/Foundational/Polish unlabeled.
Every task names an exact file path.

## Status

Ready for `/speckit-implement` (test-first per constitution III).

## Phase 8+: optional follow-ups (out of scope)

- Audio recording/playback of learner attempts (spec non-goal).
- Pronunciation scoring (spec non-goal).
- Session persistence/history (spec assumption: ephemeral).
- Cantonese STT support if/when zh-HK becomes a read language.

END OF TASKS
