# Feature Specification: Read-Along Language Learning

**Feature Branch**: `035-read-along`

**Created**: 2026-11-18

**Status**: Implemented (device-verified on OnePlus 9)

**Input**: User description: "like to have new language learning function: user follow the kalahoo reading. User tap the following button to start learning. User tap a sentence to start the learning. The sentence is highlighted. Kalahoo read a sentence. User follow kalahoo's reading. Repeat 3 times. User can tap any sentence to repeat the reading. On user's reading, kalahoo use mic to record the reading and compare with kalahoo's reading. When user tap stop button, show the result of the comparison." — clarified by the reader: fully on-device (no cloud, no AI); Learn is a new function and changes nothing about existing reading functions; the cycle is Kalahoo reads → user follows → repeated 3 times; comments are never read in Learn. **Amended 2026-11-18**: speech-to-text comparison was dropped after device testing showed platform speech recognition is unreliable across devices (missing language packs, blocked services). Learn now detects whether the learner actually spoke during each repeat (voice-activity detection) and keeps the attempt's audio so the learner can play it back — no transcription, no accuracy score. **Amended again 2026-11-18**: the three-cycle repeat was dropped for instability — each sentence tap now runs ONE read+record attempt; recordings accumulate per sentence until Stop, and Stop ends the session and drops the recordings.

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

For the tapped sentence, KalaHoo reads the sentence aloud; when the reading finishes, the microphone opens and the learner repeats the sentence once. That read-then-record pair runs once per tap. Each repeat is recorded on-device; the app detects whether the learner actually spoke during the window and keeps the audio so the learner can play it back.

**Why this priority**: This is the core learning loop — the entire value of the feature. It is testable on its own once US1 provides the entry point.

**Independent Test**: In Learn mode on a short text, tap one sentence and speak along; verify one read-then-record cycle runs per tap, the recording opens only after the TTS finishes (never during it), the attempt reports whether voice was detected, and the recording can be played back.

**Acceptance Scenarios**:

1. **Given** a tapped sentence in Learn mode, **When** the cycle starts, **Then** KalaHoo reads the sentence once, then the microphone records the learner's repeat once.
2. **Given** a learner repeat just captured, **When** the recording window closes, **Then** the app reports whether voice activity was detected and the attempt's audio is kept for playback — with no audio leaving the device.
3. **Given** a silent or noise-only repeat window, **When** it closes, **Then** the attempt is marked "no voice detected" and the session waits for the next tap.
4. **Given** a comment in the text, **When** Learn mode runs, **Then** the comment is never read aloud — it remains display-only, exactly as comments behave elsewhere.

---

### User Story 3 - Stop and see the session result (Priority: P2)

The learner taps Stop at any point; Learn ends and a result summary shows how each attempted sentence went — which sentences were practiced, how many attempts captured voice vs. detected none, and the attempt recordings available for playback.

**Why this priority**: The session only pays off if the learner can review it. It depends on US2's per-attempt results but is independently useful once they exist.

**Independent Test**: Run partial and full sessions, tap Stop, and verify a summary lists per-sentence results consistent with what was captured, including playable attempt audio.

**Acceptance Scenarios**:

1. **Given** a Learn session with several voice-captured attempts, **When** the learner taps Stop, **Then** a summary shows each practiced sentence's result.
2. **Given** a session where some attempts detected no voice, **When** the summary shows, **Then** those attempts are marked distinctly rather than silently dropped.
3. **Given** the summary, **When** the learner plays an attempt recording, **Then** they hear their own repeat from that attempt.
4. **Given** the summary, **When** the learner dismisses it, **Then** they return to the reading page in normal mode.

---

### User Story 4 - Re-practice any sentence (Priority: P3)

At any time in Learn mode the learner can tap any sentence — including one already practiced — to record another attempt on it, or tap the highlighted sentence to repeat it.

**Why this priority**: Freedom to retry is what makes it practice rather than a one-shot test; it rides on US1/US2 and adds no new machinery.

**Independent Test**: Tap sentence A, let it cycle, tap sentence B, then tap A again; verify each tap restarts that sentence's cycle cleanly.

**Acceptance Scenarios**:

1. **Given** a sentence mid-cycle, **When** the learner taps another sentence, **Then** the tap is ignored — one read+record runs at a time; the next tap works once the current attempt finishes.
2. **Given** a practiced sentence, **When** the learner taps it again, **Then** another read+record attempt is appended to it.

---

### Edge Cases

- Microphone permission denied: Learn still opens; the first repeat attempt explains that the mic is needed and offers the path to grant it; cycles without capture are marked accordingly and produce no recordings.
- No voice detected during a repeat window (silence, noise): the attempt is marked "no voice detected" and the session waits for the next tap.
- Recording failure (audio subsystem busy, storage error): the attempt is marked failed and the cycle continues; the read-aloud part is unaffected.
- Learner backgrounds the app mid-cycle: the cycle pauses; returning resumes or restarts cleanly without phantom recordings.
- TTS fails mid-cycle: the cycle stops for that sentence with an error note; other sentences remain usable.
- Very long sentences: the recording window is bounded; whatever was captured is kept and voice detection runs on it.
- Loud environment / KalaHoo's own speaker output bleeding into the mic: the mic session opens before the read but is paused — no audio is written until the read fully completes and the capture resumes, so TTS is never recorded; residual bleed is the learner's environment, not an app error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reading page MUST offer a Learn entry point that puts the page into Learn mode without altering any existing function (read, continue read, pause/resume, text type, appearance, video).
- **FR-002**: Learn mode MUST reuse the page's sentence model, highlighting, and auto-scroll so the practiced sentence is always visible — comments are never read in Learn mode.
- **FR-003**: For each sentence tap the system MUST run one cycle of: open the microphone paused → read the sentence aloud → resume recording the learner's repeat → close the microphone → wait for the next tap. No audio may be written until the read has fully finished (the mic is paused during TTS, so the read is never recorded).
- **FR-004**: Each repeat MUST be recorded to a local audio file and analyzed on-device for voice activity (did the learner speak). No audio may leave the device; no cloud service, AI provider, or speech-recognition engine may be used.
- **FR-005**: Per-attempt results MUST be visible on or beside the practiced sentence as they are produced: voice captured vs. no voice detected.
- **FR-006**: Tapping any sentence in Learn mode MUST run one read+record attempt for it; tapping an already-practiced sentence appends another attempt; tapping the currently highlighted sentence MUST repeat it.
- **FR-007**: A Stop control MUST end the Learn session and present a result summary covering every sentence practiced in the session, including attempts with no voice detected.
- **FR-008**: Learn mode MUST work identically for every read language — voice detection is language-agnostic, so no per-language setup is needed.
- **FR-009**: Microphone permission MUST be requested only when a repeat is first attempted, with a clear explanation on denial; the app MUST degrade to read-only cycles (no recordings) rather than fail.
- **FR-010**: After each attempt the session MUST wait for the learner to tap the next sentence — it MUST NOT auto-advance.
- **FR-011**: Each captured attempt's audio MUST be playable back by the learner (per-attempt playback and/or from the session summary). Recordings are kept for the Learn session and deleted when the session ends — they are not persisted.
- **FR-012**: The Learn entry point MUST be a mode toggle beside the existing reading-page controls that switches the page between normal and Learn controls; exiting Learn returns to normal controls.

### Key Entities *(include if feature involves data)*

- **Practice attempt**: one learner repeat of one sentence — the recorded audio file, whether voice activity was detected, its duration, and its position in the sentence's attempt history.
- **Sentence result**: the aggregate shown for a practiced sentence — attempts made, voice-captured count, no-voice count.
- **Learn session**: the set of sentence results plus their attempt recordings accumulated between entering and stopping Learn mode; presented as the Stop summary; recordings deleted at session end.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A learner can start Learn, tap sentences to record reads, and see per-attempt voice results and playback without any instruction beyond the on-screen prompts.
- **SC-002**: 100% of capture and voice detection happens on-device — the feature functions fully with networking disabled and requires no speech-recognition language packs.
- **SC-003**: A repeat attempt reports its voice result within ~1 second of the recording window closing.
- **SC-004**: Leaving Learn mode and returning to normal reading shows zero change in existing behavior (regression-free).
- **SC-005**: Denying microphone permission never blocks reading aloud or navigating the text — only recording is lost.

## Assumptions

- "Detect and record the user's voice" means: verify speech occurred during each repeat window (energy-based voice-activity detection) and keep the audio for playback — no transcription and no accuracy scoring (amended 2026-11-18 after platform STT proved unreliable across devices).
- The microphone captures only the learner's repeat; the mic session may be opened before the read but stays paused — audio capture resumes only after the TTS utterance completes, so the read is never recorded and the repeat is never clipped by recorder startup latency.
- ~~"Repeat 3 times"~~ superseded: each sentence tap runs one read+record attempt (amended 2026-11-18 — three-cycle flow proved unstable on device).
- Learn sessions and their recordings are not persisted; results and audio live for the session, are shown on Stop, and are deleted when the summary is dismissed or Learn is exited.
- Sentence taps during an in-flight read+record cycle are ignored (no highlight, no new attempt) — one cycle runs at a time.
- Voice detection is language-agnostic — it works identically for English, Simplified Chinese, Spanish, and any future read language.
- Android is the primary verification target; iOS support follows the same on-device constraint.
- "mac" in the original request is read as "mic".
- Existing specs' machinery is reused where it already exists (sentence splitting/highlighting from tap-to-read, TTS queue and per-language voices) — Learn adds a mode, not a rewrite.

## Clarifications

- **After each attempt**: the session waits — the learner taps the next sentence (no auto-advance). Practiced sentences keep their attempt results and recordings visible until Stop.
- **Result detail**: each attempt shows whether voice was detected; captured audio is kept for playback (amended — was accuracy %, transcript, missed/extra words under the dropped STT design).
- **Entry point**: a mode toggle beside the existing reading-page controls switches between normal and Learn controls.
