# Feature Specification: Read Language

**Feature Branch**: `034-read-language`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description (text.txt follow-up): automatic language
detection misreads Spanish as English; add per-content language properties
(main + per-role for dialogue), auto-detect first with user-visible,
user-changeable results in the Text type dialog; changes apply on the next
read.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Content default read language, visible and correctable (Priority: P1)

A reader opens a content whose text is Spanish but was detected as English.
In the Text type dialog they see the detected language for the content's
main text, change it to Spanish, and every read from then on — taps,
Continue Read — uses the Spanish voice. The detection still runs first:
content that is detected correctly needs no correction at all.

**Why this priority**: This is the reported bug's direct fix — the reader
can correct a wrong guess once, permanently, per content.

**Independent Test**: Open a Spanish content detected as English → Text
type dialog → set language to Spanish → tap a sentence → the read uses the
Spanish voice; reopen the dialog → Spanish is still selected.

**Acceptance Scenarios**:

1. **Given** a content whose detected language is wrong, **When** the reader
   opens Text type and picks the correct language, **Then** the next read of
   any part of the main text uses that language's voice.
2. **Given** the reader never touches the language setting, **When** they
   read, **Then** behavior is exactly today's auto-detection — no regression.
3. **Given** a content is edited so its text changes language, **When** the
   reader has NOT overridden the language, **Then** detection re-runs and
   the new guess is shown; a manual override, once set, is kept until the
   reader changes it.

---

### User Story 2 - Per-role language override for dialogue (Priority: P1)

In a dialogue content, each role's turns are read in that role's own
language — today detected per turn. The Text type dialog's role list shows
each role's detected language, and the reader can pin a different language
to a specific role (e.g. a role whose name is Chinese but whose lines are
English, or vice versa). A role with no override keeps detection.

**Why this priority**: Mixed-language dialogue is where detection fails
most often (short turns, names, single words), and per-role voices are the
app's signature feature — a wrong language there is the most audible bug.

**Independent Test**: Open a dialogue where one role's turns are detected
wrong → Text type → role list → set that role's language → read → that
role's lines use the chosen voice while others keep detection.

**Acceptance Scenarios**:

1. **Given** a dialogue role detected as the wrong language, **When** the
   reader sets that role's language in the role list, **Then** that role's
   turns read in the chosen language and other roles are unaffected.
2. **Given** a role the reader has never touched, **When** new turns for it
   appear (edited text), **Then** its language is re-detected and shown.
3. **Given** the reader switches the content between Standard and Dialogue,
   **When** they return, **Then** per-role overrides set earlier are still
   in force.

---

### User Story 3 - Stronger on-device language detection (Priority: P2)

Detection stops being the weak link: a compact on-device statistical
detector (character n-gram model, pure Dart, bundled with the app — no
network, no native code, ~hundreds of KB) identifies the language of each
paragraph/turn far more reliably than the rule table, especially short
accent-less Spanish. The rule table remains as the fallback for
low-confidence cases. Users still see and can override the result in the
Text type dialog (US1/US2).

**Why this priority**: P2 — the override (US1/US2) already lets readers fix
mistakes; a better detector reduces how often they must. It is independently
valuable: better auto-detection helps every content, including presets that
can't be overridden.

**Independent Test**: Feed the detector accent-less Spanish sentences that
today fall back to English ("Voy al cine.", "Nos vemos manana.") → returns
`es`; English and Chinese controls still correct; confidence-low inputs
fall back to the rule table's answer.

**Acceptance Scenarios**:

1. **Given** a paragraph of ordinary Spanish without accents, **When** it is
   read, **Then** it is detected as Spanish and read in the Spanish voice.
2. **Given** ambiguous or symbol-only text, **When** the detector's
   confidence is low, **Then** the rule table's answer is used — behavior
   never gets worse than today.
3. **Given** the detector runs, **When** any check executes, **Then** no
   network access or platform channel is involved (fully on-device,
   testable in `flutter test`).

---

### Edge Cases

- A content with no detectable language signal at all (numbers, emoji,
  symbols) — defaults to English as today; the reader can still override.
- A role that appears, is removed from the role list, and reappears — the
  override follows the role name.
- Two contents with the same text — each keeps its own settings (settings
  are per content entry, not per text).
- The app UI language differs from the content language — detection and
  overrides are about the *content*, never the UI locale.
- Comment tags (`[comment]…[/comment]`): comments keep their own
  per-comment detection; the content default does NOT rewrite them
  (unchanged behavior — see Assumptions).
- Very long content where detection and override must agree: the override
  wins everywhere detection would have run for main text.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each content MUST carry a persisted main-text read language:
  either "auto" (the detector's answer) or an explicit choice of the
  supported languages (English, Simplified Chinese, Spanish).
- **FR-002**: The Text type dialog MUST show the effective main-text
  language (the detection result when on auto) and let the reader set it to
  auto or any supported language.
- **FR-003**: In dialogue mode, each role MUST carry an optional persisted
  language override; the role list MUST show each role's effective
  language and offer per-role auto/explicit choice.
- **FR-004**: Language resolution for a read MUST be: explicit override →
  detection — applied at every point detection runs today (per-paragraph
  main text, per-role turns), so taps, paragraph reads, and Continue Read
  all honor it.
- **FR-005**: Changes MUST take effect on the next read; an in-progress
  read is never re-voiced mid-sentence.
- **FR-006**: Detection MUST still run for unset content/roles so the
  dialog always shows a concrete effective language, and so new content
  needs zero setup.
- **FR-007**: Settings MUST persist across app restarts and content
  reloads, scoped to the content entry (id), and MUST NOT leak between
  contents.
- **FR-008**: All new UI strings MUST be localized in the four shipped
  locales (en, zh, zh-Hans, es).
- **FR-009**: The language-resolution path MUST be a single seam so a
  stronger detector can replace the rule table later without touching
  storage or UI.
- **FR-010**: Detection MUST use an on-device statistical model (bundled,
  pure Dart, no network/native code) as the primary detector, with the
  existing rule table as the low-confidence fallback — never worse than
  today's detection.
- **FR-011**: The detector MUST cover at least English, Simplified Chinese,
  and Spanish, and MUST return a confidence signal so fallback decisions
  are explicit, not silent.

### Key Entities *(include if feature involves data)*

- **ContentLanguageSetting**: per content entry — `mainLanguage`
  (`auto` | `en` | `zh-Hans` | `es`) and `roleLanguages`
  (role name → `auto` | language). Persisted with the content's index
  record; defaults to all-auto for existing contents (no migration).
- **Detected language**: the rule table's per-unit answer (paragraph /
  turn / comment), unchanged — it is the "auto" value shown in the dialog.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader corrects a misdetected content language in ≤ 3 taps
  (open Text type → pick language → close) and every subsequent read uses
  it — verified by voice/language evidence, no re-correction needed.
- **SC-002**: 100% of reads honor an explicit override; auto contents read
  identically to today (no regression in the existing language tests).
- **SC-003**: A dialogue role override affects only that role's turns —
  other roles' languages are bit-identical to before.
- **SC-004**: Settings survive force-stop + relaunch for every content,
  including after the content is edited.
- **SC-005**: On a held-out set of ≥30 sentences per language (including
  accent-less Spanish and short turns), the detector's top-1 accuracy is
  ≥90% for en/es and ≥98% for zh-Hans; low-confidence inputs fall back to
  the rule table rather than guessing.

## Assumptions

- Supported read languages remain the three shipped ones (en, zh-Hans, es);
  adding a fourth is out of scope.
- Comments keep per-comment detection; a comment-language override is a
  possible later spec, not this one.
- "Text type dialog" means the existing chooser opened from the toolbar's
  Text type action — the role list and new language rows live there.
- The detector is upgraded in this spec (US3): a bundled pure-Dart
  statistical model primary + rule-table fallback; the `detectLanguage`
  signature may gain a confidence-aware variant behind the FR-009 seam.
- Preset contents (shipped samples) are read-only for settings — overrides
  apply to saved/imported contents; presets keep detection (their language
  is known anyway).
