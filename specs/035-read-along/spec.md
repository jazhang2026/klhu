# Feature Specification: Read-Along Language Learning

**Feature Branch**: `035-read-along`

**Created**: 2026-11-18

**Status**: Draft

**Input**: User description: "like to have new language learning function: user follow the kalahoo reading. User tap the following button to start learning. User tap a sentence to start the learning. The sentence is highlighted. Kalahoo read a sentence. User follow kalahoo's reading. Repeat 3 times. User can tap any sentence to repeat the reading. On user's reading, kalahoo use mic to record the reading and compare with kalahoo's reading. When user tap stop button, show the result of the comparison." — clarified by the reader: fully on-device (no cloud, no AI); Learn is a new function and changes nothing about existing reading functions; the cycle is Kalahoo reads → user follows → repeated 3 times; comments are never read in Learn.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start a Learn session on a text (Priority: P1)

A reader who wants to practice a language opens a saved text and enters Learn mode from the reading page. The page looks and behaves like the normal reading page — same sentences, same highlighting, same auto-scroll — but carries Learn controls instead of read controls. Nothing about the existing Read / Continue Read / Text type functions changes.

**Why this priority**: Without a way in, nothing else in the feature is reachable. This is the entry point and the mode boundary that guarantees existing functions stay untouched.

**Independent Test**: Enter Learn on any saved text; verify the reading page shows Learn controls, tapping a sentence highlights it, and every pre-existing control (read, continue, text type, appearance) still works exactly as before.

**Acceptance Scenarios**:

1. **Given** a saved text open on the reading page, **When** the reader activates Learn, **Then** the page enters Learn mode and the Learn controls replace the read controls.
2. **Given** Learn mode, **When** the reader taps a sentence, **Then** that sentence is highlighted and its follow-along cycle begins.
3. **Given** Learn mode, **When** the reader taps a different sentence mid-cycle, **Then** the current cycle stops and the new sentence's cycle begins.
4. **Given** any mode, **When** the reader leaves Learn, **Then** the page returns to its previous state with all existing functions unchanged.

---

### User Story 2 - Follow-along cycle on one sentence (Priority: P1)

For the highlighted sentence, KalaHoo reads the sentence aloud; when the reading finishes, the microphone opens and the learner repeats the sentence. That read-then-repeat pair happens three times for the sentence. Each repeat is captured on-device and compared against the sentence text, producing an accuracy score for that attempt.

**Why this priority**: This is the core learning loop — the entire value of the feature. It is testable on its own once US1 provides the entry point.

**Independent Test**: In Learn mode on a short text, tap one sentence and speak along; verify three read-then-repeat cycles run, each repeat is captured after the TTS finishes (never during it), and each attempt yields a score.

**Acceptance Scenarios**:

1. **Given** a highlighted sentence in Learn mode, **When** the cycle starts, **Then** KalaHoo reads the sentence once, then the microphone records the learner's repeat — and this read-then-record pair repeats for a total of three learner repeats.
2. **Given** a learner repeat just captured, **When** it finishes, **Then** an on-device comparison of the transcript against the sentence produces a score shown for that attempt — with no audio or text leaving the device.
3. **Given** a sentence whose resolved language is not supported for on-device recognition, **When** a repeat is attempted, **Then** the cycle still runs (read + record window) but no score is produced and the learner is told recognition is unavailable.
4. **Given** a comment in the text, **When** Learn mode runs, **Then** the comment is never read aloud — it remains display-only, exactly as comments behave elsewhere.

---

### User Story 3 - Stop and see the session result (Priority: P2)

The learner taps Stop at any point; Learn ends and a result summary shows how each attempted sentence scored — which sentences were practiced, their best/last accuracy, and which attempts could not be scored.

**Why this priority**: The comparison only pays off if the learner can see it. It depends on US2's per-attempt scores but is independently useful once they exist.

**Independent Test**: Run partial and full sessions, tap Stop, and verify a summary lists per-sentence results consistent with what was captured.

**Acceptance Scenarios**:

1. **Given** a Learn session with several scored attempts, **When** the learner taps Stop, **Then** a summary shows each practiced sentence's result.
2. **Given** a session where some attempts failed recognition, **When** the summary shows, **Then** those attempts are marked as unscored rather than silently dropped.
3. **Given** the summary, **When** the learner dismisses it, **Then** they return to the reading page in normal mode.

---

### User Story 4 - Re-practice any sentence (Priority: P3)

At any time in Learn mode the learner can tap any sentence — including one already practiced — to restart its three-cycle practice, or tap the highlighted sentence to repeat it.

**Why this priority**: Freedom to retry is what makes it practice rather than a one-shot test; it rides on US1/US2 and adds no new machinery.

**Independent Test**: Tap sentence A, let it cycle, tap sentence B, then tap A again; verify each tap restarts that sentence's cycle cleanly.

**Acceptance Scenarios**:

1. **Given** a sentence mid-cycle, **When** the learner taps another sentence, **Then** the first cycle is abandoned and the tapped sentence starts fresh.
2. **Given** a completed sentence, **When** the learner taps it again, **Then** its three-cycle practice restarts.

---

### Edge Cases

- Microphone permission denied: Learn still opens; the first repeat attempt explains that the mic is needed and offers the path to grant it; cycles without capture do not produce scores.
- No speech detected during a repeat window (silence, noise): the attempt is marked unscored and the cycle continues to the next repeat.
- Speech recognition unavailable on the device (missing engine, unsupported locale): cycles still read aloud; attempts are marked unscored with an explanation.
- Learner backgrounds the app mid-cycle: the cycle pauses; returning resumes or restarts cleanly without phantom recordings.
- TTS fails mid-cycle: the cycle stops for that sentence with an error note; other sentences remain usable.
- Very long sentences: recognition window is bounded; partial captures are scored on what was heard or marked unscored.
- Code-switching (sentence mixes languages): scoring uses the sentence's resolved read language; mismatches simply lower the score.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reading page MUST offer a Learn entry point that puts the page into Learn mode without altering any existing function (read, continue read, pause/resume, text type, appearance, video).
- **FR-002**: Learn mode MUST reuse the page's sentence model, highlighting, and auto-scroll so the practiced sentence is always visible — comments are never read in Learn mode.
- **FR-003**: For each practiced sentence the system MUST run exactly three cycles of: read the sentence aloud → open the microphone → capture the learner's repeat → close the microphone. Recording MUST NOT begin until the read has fully finished.
- **FR-004**: Each captured repeat MUST be compared on-device against the sentence text, producing a per-attempt accuracy score. No audio, transcript, or text may leave the device; no cloud service or AI provider may be used.
- **FR-005**: Per-attempt scores MUST be visible on or beside the practiced sentence as they are produced.
- **FR-006**: Tapping any sentence in Learn mode MUST start (or restart) that sentence's three-cycle practice; tapping the currently highlighted sentence MUST repeat it.
- **FR-007**: A Stop control MUST end the Learn session and present a result summary covering every sentence practiced in the session, including unscored attempts.
- **FR-008**: Learn mode MUST resolve each sentence's language through the same read-language settings used for reading (per-content and per-role overrides, then detection), so recognition matches what was read aloud.
- **FR-009**: Microphone permission MUST be requested only when a repeat is first attempted, with a clear explanation on denial; the app MUST degrade to read-only cycles (no scores) rather than fail.
- **FR-010**: After a sentence completes its three cycles the session MUST wait for the learner to tap the next sentence — it MUST NOT auto-advance.
- **FR-011**: Each scored attempt MUST show its accuracy percentage plus the recognized transcript and the missed/extra words, computed on-device.
- **FR-012**: The Learn entry point MUST be a mode toggle beside the existing reading-page controls that switches the page between normal and Learn controls; exiting Learn returns to normal controls.

### Key Entities *(include if feature involves data)*

- **Practice attempt**: one learner repeat of one sentence — the recognized transcript, its accuracy score (or unscored reason), and its position in the sentence's three-cycle run.
- **Sentence result**: the aggregate shown for a practiced sentence — attempts made, best/last score, unscored count.
- **Learn session**: the set of sentence results accumulated between entering and stopping Learn mode; presented as the Stop summary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A learner can start Learn, practice one sentence through all three cycles, and see scores without any instruction beyond the on-screen prompts.
- **SC-002**: 100% of speech capture and comparison happens on-device — the feature functions fully with networking disabled.
- **SC-003**: A repeat attempt produces its score within 3 seconds of the learner finishing speaking.
- **SC-004**: Leaving Learn mode and returning to normal reading shows zero change in existing behavior (regression-free).
- **SC-005**: Denying microphone permission never blocks reading aloud or navigating the text — only scoring is lost.

## Assumptions

- "Compare" means on-device speech recognition producing a transcript, diffed against the sentence text for an accuracy score — not acoustic/pronunciation scoring.
- The microphone captures only the learner's repeat; each capture window opens strictly after the TTS utterance completes.
- "Repeat 3 times" means three learner repeats per sentence (each preceded by one KalaHook read), as clarified by the reader.
- Learn sessions are not persisted; results live for the session and are shown on Stop.
- Target languages for recognition are the app's existing read languages (English, Simplified Chinese, Spanish); other resolved languages produce unscored attempts.
- Android is the primary verification target; iOS support follows the same on-device constraint where the platform allows.
- "mac" in the original request is read as "mic".
- Existing specs' machinery is reused where it already exists (sentence splitting/highlighting from tap-to-read, TTS queue and per-language voices, read-language resolution) — Learn adds a mode, not a rewrite.

## Clarifications

- **After three cycles**: the session waits — the learner taps the next sentence (no auto-advance). Practiced sentences keep their scores visible.
- **Result detail**: each attempt shows accuracy %, the recognized transcript, and missed/extra words.
- **Entry point**: a mode toggle beside the existing reading-page controls switches between normal and Learn controls.
