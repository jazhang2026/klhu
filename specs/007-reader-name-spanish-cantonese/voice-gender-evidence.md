# Voice gender evidence — es-* and yue-HK, emulator-5554 (2026-09-22)

Method (same as spec 005): `TtsProbe.java` under `app_process` -> `TextToSpeech.synthesizeToFile` per voice, locale-appropriate sample text (Spanish for `es*`, Chinese for `yue*`, English otherwise) -> host-side F0 tracking (`f0_pitch_report.py`, autocorrelation, 40 ms frames), cross-checked against the gender bit of the engine's own manifest (`assets/voices-list-dsig.pb` in GoogleTTS.apk; 16 = person, 1 = female, 2 = male).

Classifier controls in the same run: `en-us-x-sfg` 220.2 Hz (female), `en-gb-x-rjs` 124.4 Hz (male).

| voice | median F0 (Hz) | manifest | cue used | gender written |
|---|---|---|---|---|
| es-ES-language | 212.4 | — | f0 | female |
| es-US-language | 250.0 | — | f0 | female |
| es-es-x-eea-local | 208.7 | 1 | manifest person=1 | female |
| es-es-x-eea-network | 195.9 | 1 | manifest person=1 | female |
| es-es-x-eec-local | 192.0 | 1 | manifest person=1 | female |
| es-es-x-eec-network | 182.2 | 1 | manifest person=1 | female |
| es-es-x-eed-local | 121.8 | 2 | manifest person=2 | male |
| es-es-x-eed-network | 117.4 | 2 | manifest person=2 | male |
| es-es-x-eee-local | 212.4 | 1 | manifest person=1 | female |
| es-es-x-eef-local | 110.6 | 2 | manifest person=2 | male |
| es-us-x-esc-local | 250.0 | 1 | manifest person=1 | female |
| es-us-x-esc-network | 240.0 | 1 | manifest person=1 | female |
| es-us-x-esd-local | 144.6 | 2 | manifest person=2 | male |
| es-us-x-esd-network | 145.5 | 2 | manifest person=2 | male |
| es-us-x-esf-local | 152.9 | 2 | manifest person=2 | male |
| es-us-x-esf-network | 154.1 | 2 | manifest person=2 | male |
| es-us-x-sfb-local | 237.6 | — | f0 | female |
| es-us-x-sfb-network | 235.3 | — | f0 | female |
| yue-HK-language | 216.2 | — | f0 | female |
| yue-hk-x-jar-local | 216.2 | — | f0 | female |
| yue-hk-x-jar-network | 213.3 | — | f0 | female |
| yue-hk-x-yuc-local | 240.0 | — | f0 | female |
| yue-hk-x-yuc-network | 238.8 | — | f0 | female |
| yue-hk-x-yud-local | 132.6 | 2 | manifest person=2 | male |
| yue-hk-x-yud-network | 126.5 | 2 | manifest person=2 | male |
| yue-hk-x-yue-local | 195.1 | 1 | manifest person=1 | female |
| yue-hk-x-yue-network | 195.9 | 1 | manifest person=1 | female |
| yue-hk-x-yuf-local | 139.5 | 2 | manifest person=2 | male |
| yue-hk-x-yuf-network | 137.1 | 2 | manifest person=2 | male |

## Notes

- `es-MX` is **not** a TTS locale on this engine: the sweep reports `es-ES` and `es-US` only, and `es-US-language` (250.0 Hz, identical clip to `es-us-x-esc`) is the US-Spanish default. Speech therefore uses `es-US`; `es-MX` remains the interface locale (see `research.md`).
- `es-ES-language` (212.4 Hz) resolves to `es-es-x-eee` (212.4 Hz), and `yue-HK-language` (216.2 Hz) resolves to `yue-hk-x-jar` (216.2 Hz) — the locale default is the same voice, labelled `… Default` consistently.
- `yue-hk-x-jar` and `yue-hk-x-yuc` have no manifest entry on this engine build; their gender comes from F0 alone (216.2 / 240.0 Hz, unambiguous female range) and is recorded as such in the `cue used` column.
- No voice in this sweep landed in the 150-180 Hz decision band, so no row is left blank for ambiguity. Age stays off every row (unmeasurable).
- The engine's inventory is not stable across engine updates: the 2026-09-21 sweep saw 51 English voices, this one sees 39, matching what the app's own `getVoices` logged the same day. Rows for voices this device no longer reports are harmless (lookup is a fallback-safe map) and are kept.
