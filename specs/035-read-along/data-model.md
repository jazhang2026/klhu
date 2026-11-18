# Data Model: Read-Along Language Learning (035)

All entities are in-memory only — Learn sessions are ephemeral per spec. No persistence, no schema changes to `SavedContent`.

## Entities

### `LearnAttempt` — one learner repeat of one sentence

| Field | Type | Notes |
|---|---|---|
| `sentenceKey` | `String` | stable identity of the practiced sentence (e.g. content offset range `start:end`) |
| `sentenceText` | `String` | the target text used for scoring |
| `attemptIndex` | `int` | 1..3 within the sentence's cycle |
| `transcript` | `String?` | recognized text; null when unscored |
| `status` | `AttemptStatus` | `scored` / `unscored` / `failed` |
| `accuracy` | `double?` | 0.0–1.0; null unless `scored` |
| `missedWords` | `List<String>` | target tokens not matched; empty unless `scored` |
| `extraWords` | `List<String>` | recognized tokens not in target; empty unless `scored` |
| `unscoredReason` | `String?` | `noSpeech` / `recognitionUnavailable` / `unsupportedLanguage` / `permissionDenied` / `error` |

### `SentenceResult` — aggregate for one practiced sentence

| Field | Type | Notes |
|---|---|---|
| `sentenceKey` | `String` | matches attempts |
| `sentenceText` | `String` | display text (truncated in UI) |
| `attempts` | `List<LearnAttempt>` | in order |
| `bestAccuracy` | `double?` | max over scored attempts |
| `lastAccuracy` | `double?` | most recent scored attempt |
| `scoredCount` | `int` | derived |
| `unscoredCount` | `int` | derived |

### `LearnSession` — the whole Learn mode session

| Field | Type | Notes |
|---|---|---|
| `results` | `Map<String, SentenceResult>` | insertion-ordered by first practice |
| `currentKey` | `String?` | sentence mid-cycle, if any |
| `cycleIndex` | `int` | 0–2 attempts completed for current sentence |
| `state` | `LearnState` | see state machine |

## `LearnState` (state machine)

```text
idle ──tap sentence──▶ reading ──TTS done──▶ listening ──final result──▶ scoring
  ▲                     │                     │                        │
  │                     │ TTS error            │ silence/timeout/error  │ score computed
  │                     ▼                     ▼                        ▼
  │                  idle(error)          unscored attempt ──────────▶ nextOrDone
  │                                                                      │
  │                                              cycleIndex<3? yes ─────┤
  │                                              no (3 done)            ▼
  │                                                                   waiting
  │                                          tap another sentence ────▶ reading
  │                                          Stop ────────────────────▶ stopped
```

- `waiting`: sentence finished 3 cycles; session idles until learner taps next sentence or Stop (FR-010).
- `stopped`: terminal; produces `summary()` and returns page to normal controls.
- Any sentence tap while `reading`/`listening` abandons the current cycle and restarts for the new sentence (US4).

## `ScoreResult` — output of the pure-Dart scorer

| Field | Type | Notes |
|---|---|---|
| `accuracy` | `double` | matched / target token count, clamped 0–1 |
| `transcript` | `String` | normalized recognized text |
| `missed` | `List<String>` | target tokens unmatched by LCS alignment |
| `extra` | `List<String>` | recognized tokens unmatched |

Tokenization rules (`speech_scorer.dart`):
- Normalize: Unicode lowercase → strip punctuation/symbols → collapse whitespace.
- Latin targets (en/es): whitespace-delimited word tokens.
- CJK targets (zh): character unigrams (simpler than bigrams; adequate for character-accuracy feedback).
- Empty target → accuracy defined as 0.0 with empty missed/extra (defensive; sentences are never empty in practice).
- Empty transcript → accuracy 0.0, all target tokens missed, no extras.

## `SpeechRecognition` seam (`speech_recognizer.dart`)

```dart
abstract class SpeechRecognizer {
  Future<bool> initialize();                       // false → recognitionUnavailable
  Future<void> listen({
    required String localeId,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function() onDone,               // endpointing or stop()
    required void Function(String reason) onError,
  });
  Future<void> stop();
}
```

- `PlatformSpeechRecognizer` wraps `speech_to_text` with `onDevice: true`, `listenFor`/`pauseFor` bounds.
- `FakeSpeechRecognizer` (test/) scripts results/errors deterministically.
- `localeIdFor(language)` maps `en`→`en_US`, `zh`→`zh_CN`, `es`→`es_ES`; anything else → null → `unsupportedLanguage` unscored path.

## Validation rules (from spec FRs)

- Exactly 3 learner repeats per sentence cycle; recording never opens before TTS completion (FR-003).
- Comments never enter the learn path — sentence resolution excludes them by construction (FR-002).
- Mic permission requested lazily at first repeat; denial → read-only cycles, `permissionDenied` unscored (FR-009).
- Session results cover every practiced sentence incl. unscored attempts (FR-007).
- Language resolution reuses 034 path: role override → main override → detection (FR-008).

## Relationships

```text
ReadingView ──owns──▶ LearnController ──uses──▶ LearnSession (state)
                          │                        │
                          ├──uses──▶ SpeechRecognizer (seam → speech_to_text)
                          ├──uses──▶ speech_scorer (pure fn)
                          └──uses──▶ ReaderService/Reader (existing TTS, completion-gated)
LearnSession ──contains──▶ Map<sentenceKey, SentenceResult> ──contains──▶ List<LearnAttempt>
```

No persistence; no changes to `SavedContent`, `ContentStore`, or any stored schema.

## Non-goals (explicit)

- No audio recording/playback storage — transcript only.
- No pronunciation/acoustic scoring.
- No session persistence or history.
- No changes to read/continue/text-type/appearance/video functions.
