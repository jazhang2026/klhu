# Tasks: 003 Reading Polish

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md` from `/specs/003-reading-polish/`

**Prerequisites**: 002 done (55/55 green, analyze clean); no new deps, no storage changes

**Tests**: Required by constitution (TDD) — tests written first and fail before implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (picker/P1), US2 (direct-edit/P1), US3 (tracking/P2)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify baseline green before touching anything

- [x] T001 Confirm `flutter analyze` clean and full `flutter test` green on 002 code (55/55) — no dep changes in 003 (DONE 2026-09-16: analyze clean, 55/55 green)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Offsets + progress callback every story's highlight depends on

- [x] T002 [P] Write callback + offset tests (DONE 2026-09-16: 3 callback cases in reader_service_test + 2 offset cases in language_test, red-first via missing members)
- [x] T003 [P] Implement (DONE 2026-09-16: ParagraphSpeech +start/end, resolveParagraphSpeeches retains from/to, speakParagraphs onParagraphStart generation-guarded; 4 Reader fakes updated, MixedFakeReader drives callback; 60/60 green, analyze clean)

**Checkpoint**: `flutter test` green; foundation ready.

---

## Phase 3: User Story 1 - Picker selection without marker (Priority: P1)

**Goal**: Selected row highlighted + centered, no marker anywhere, scrollbar always visible, count matches list.

**Independent Test**: Android emulator: select voice B → row B highlighted and centered, no ✓/icon anywhere; count == getVoices filter length; TalkBack announces "selected".

- [x] T004 [US1] Write picker polish tests (DONE 2026-09-16: icon→selected assertions migrated in 3 widget + 1 semantics test; 3 new US1 cases — red-first, 7 failures)
- [x] T005 [US1] Implement picker polish (DONE 2026-09-16, revised per validation: green.shade200 background + black text — never green text; EAGER ListView so first-open autoscroll finds offscreen selected rows; 76/76 green, analyze clean. Correction: 'Selected' announcement comes from the isSelected semantics flag ListTile.selected sets — probed live, not from a label)
- [x] T006 [US1] Validate on Android emulator per quickstart US1 (PASS 2026-09-16: green row bg, first-open centering with saved EN voice, no marker, count matches, TalkBack "selected") — iPhone pending (no macOS)

**Checkpoint**: US1 fully functional and testable independently.

---

## Phase 4: User Story 2 - Direct-edit reading area (Priority: P1)

**Goal**: READ/EDIT/SPEAKING modes; READ tap-selects with no keyboard; EDIT has full native editing and zero read buttons; Edit idle-only.

**Independent Test**: Android emulator: READ tap sentence → Read speaks it, no keyboard; Edit → type/paste freely, no Read/Read-page/Stop visible, only Done; Done → READ; Edit disabled while speaking; no Load step anywhere.

- [x] T007 [US2] Write edit-mode tests (DONE 2026-09-16, revised: RichText yellow tap/long-press + EDIT-only TextField cases)
- [x] T008 [US2] Implement modes (DONE 2026-09-16, revised per emulator validation: READ/SPEAKING RichText with 001 yellow spans — tap sentence, long-press paragraph restored; TextField ONLY in EDIT, Done commits; controller-listener experiment REMOVED — a wrapping detector never fires against the field's recognizers, and selection-color highlight rejected for yellow; 001/002 reading-view tests restored to span assertions)
- [x] T009 [US2] Validate on Android emulator per quickstart US2 (PASS 2026-09-16: tap/long-press yellow, Edit flow with hidden read buttons + Done commit) — iPhone pending

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 - Read page tracks current paragraph (Priority: P2)

**Goal**: Exactly the spoken paragraph highlighted, advancing with the voice, cleared at end/Stop. Requires US2 (selection IS the tracking highlight).

**Independent Test**: Android emulator: mixed EN/zh page read → highlight sits on exactly the spoken paragraph, moves with the voice, gone at end and on Stop.

- [x] T010 [US3] Write tracking tests (DONE 2026-09-16: advance-per-paragraph + clear-on-Stop + stale-generation guard, manual-drive fake — red-first)
- [x] T011 [US3] Wire onParagraphStart (DONE 2026-09-16: trackingRange → controller selection, guarded clears in finally + Stop; mixed widget test migrated to EDIT flow)

**Checkpoint**: All stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T012 Edge-case pass (DONE 2026-09-16: empty-content hint, rapid Edit/Done, Done-unchanged full read — 3 widget tests)
- [x] T013 Run `quickstart.md` validation end-to-end EN + zh-Hans on Android emulator (PASS 2026-09-16: US1 green-row + first-open center, US2 yellow tap/long-press + Edit flow, US3 tracking — all on current build; code: analyze clean, 77/77 green)

---

## Dependencies & Execution Order

- T001 → (T002→T003) → US1 (T004→T005→T006) → US2 (T007→T008→T009) → US3 (T010→T011, no separate emulator trip — fold into T013 if T009 just passed) → Polish (T012→T013)
- T002/T003 writable in parallel with T004 (different files); tests before implementation per task
- US3 hard-depends on US2 (tracking rides the EDIT-state selection); US1 independent — may swap before US2 if preferred
- Stories sequential P1 → P1 → P2 (single developer); US1 is shippable alone
