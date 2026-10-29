# Data model: AI access

**Feature**: `029-ai-access-kalahoo` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

## §1 `AIProvider` — one settable AI provider (spec Key Entities)

| field | meaning |
|---|---|
| name | the provider's own display name (e.g. "Google AI Studio (Gemini)", "OpenRouter", "NVIDIA NIM", or a reader-added name) |
| url | the provider's REST endpoint (e.g. Gemini `generativelanguage`, OpenRouter chat completions, NVIDIA NIM); fixed for a preset, reader-supplied for a user-added provider |
| registerTip | the static how-to-register tip for that provider (spec FR-002); empty for a provider without one |
| apiKey | the API key the reader filled in, if the provider needs one (spec FR-002); empty for a provider without one |
| active | whether the connectivity test passed for this provider — the test runs when the reader adds or edits the `apiKey`; a provider with a passing test is usable. A preset starts with `active:false` until the reader fills in the key and the test passes; a user-added provider is the same. Multiple providers can be `active:true` at once. |
| selected | the last provider the reader picked in the AI dialog's provider options dropdown — the default shown when the dialog opens. Updated whenever the reader picks a different provider in the dropdown (spec Q9, review 5). Set to the first `active` provider when the list loads. |

Presets (Google AI Studio/Gemini, OpenRouter 17 `:free`, NVIDIA NIM) and user-added providers share the same shape;
a preset is just a provider entry the reader has not customised — it saves exactly the same way a user-added
provider does. The reader can add a provider of their own (with their own `name` and `url`) — the provider list is
the reader's own state, not a fixed set.

When a reader adds or edits the `apiKey`, an auto-connectivity test follows; the provider's `active` state is set
only if that test passed. This is the same behaviour for a preset and for a user-added provider (FR-004).

The provider list persists in SharedPreferences under one namespace; the presets are a seed, the API keys, the
`active` and `selected` flags and the reader-added providers are the reader's own state.

## §2 `AIPrompt` — the prompt the reader submits (spec Key Entities)

| field | meaning |
|---|---|
| type | the generation type the reader picked: `text`, `image` or `video` (spec review round 4) |
| text | the reader's own prompt string (spec FR-003/FR-004) |
| includeReadingContent | whether the current reading content is included in the prompt (spec A3 — opt-in) |

The `type` is the routing field for the call: `text` → the provider's text model; `image` → the provider's image
model; `video` → the provider's video model (spec FR-004, updated at review round 4).

## §3 Generated content — lands as an ordinary content (D4)

| field | meaning |
|---|---|
| text | the model's answer, as reading content |
| language | the reading language the paragraph-level detection assigns (spec 003) |
| origin | `user` — it lands in the content library's list like hand-written content (mirror 027's D4) |

## §4 What is *not* stored

The prompt dialog is memory-only: the prompt string, its type and its optional content inclusion are not persisted;
only the provider's answer — as an ordinary content of §3 — is. The API key the reader typed *is* stored (it is a
setting, not a transient value); the provider's `active` state is stored too. Everything else is the reader's own
state, not generated content.
