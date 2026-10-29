# Feature Specification: AI access

**Feature Branch**: `029-ai-access-kalahoo`

**Created**: 2026-10-28

**Status**: Draft

**Input**: the reader's wish list (`text.txt`), item 029 — add AI access for Kalahoo Reading; first supporting model is Google AI Studio (Gemini 2.5 Flash Lite), for free text/image/video generation; configuration: add an AI configuration page to select the model and input the API key; on the Edit page add an AI button to the right of the Format button, which opens a dialog to input the AI prompt; the AI prompt should be a string that will be sent to the AI model, and the reading content can optionally be included in the prompt.

**Refined at review (2026-10-29)** — the reader's follow-ups on the draft:
- The AI provider configuration button belongs on the **top tool bar**, not on the Edit page.
- The top tool bar gains a **Settings button that groups the settings tool buttons**; the AI config is one of them.
- The reader can **set multiple AI providers** and **select the one in force**.
- The AI prompt dialog is opened by the **AI button on the Edit page** (right of the Format button) — this AI button is **not** the Settings / AI provider configuration control.
- **AIProvider shape** (review 4): a provider has `name` and `url` fields; the `preset` field is not used. Presets and user-added providers save the same way. `active` is a per-provider field, true only when the connectivity test after an add/edit of the API key passed.
- **AI prompt type** (review 4): the dialog offers `text` / `image` / `video`; `AIPrompt.type` routes the call to the right model on the provider.
- **AI provider options dropdown** (review 4): the dialog has a provider selector (the *AIProvider options dropdown select*); only `active` providers are listed by default; the currently `selected` provider is always shown so the reader can switch back and re-test; choosing a different one updates the `AIProvider.selected` field on the provider the reader picks.

**Refined at review (2026-10-29, round 5)** — the reader's follow-ups on the draft:
- **`active`**: set to true only when the connectivity test passes (a provider with a passing test is usable). Multiple providers can be `active:true` at once — `active` is a capability flag, not a selector. A preset starts `active:false` until the reader fills in the key and the test passes; a user-added provider is the same.
- **`selected`**: the last provider the reader picked in the AI dialog's provider options dropdown — the default shown when the dialog opens. Updated whenever the reader picks a different provider in the dropdown. Set to the first `active` provider when the list loads.
- **Dropdown rule**: only `active` providers are listed by default; the currently `selected` provider is always shown so the reader can switch back and re-test.

## What this feature does

Adds the AI's first access to KalaHoo Reading, so a configured AI provider can be put to work on reading content.

- 029 adds AI access for Kalahoo Reading; the first supporting provider is Google AI Studio (Gemini 2.5 Flash Lite), for free text/image/video generation.
- The AI provider configuration lives behind a top tool bar button, grouped under a Settings button on that tool bar; the reader sets multiple AI providers and selects the one in force.
- The AI provider configuration ships with provider presets — Google AI Studio (Gemini), OpenRouter (its 17 `:free` models), NVIDIA NIM — each with a how-to-register tip and an API key field the reader fills in as needed.
- The AI button on the Edit page (to the right of the Format button) opens the AI prompt dialog; this AI button is not the Settings / AI provider configuration control. The dialog offers a generation type — text / image / video — a provider options dropdown (only `active` providers are listed), and the prompt string; the prompt is sent to the chosen provider's model of that type, and the reading content can optionally be included in the prompt.

## Clarifications

### The reader's answers — asked at this stage, answered by the reader's own words (2026-10-28 / 2026-10-29)

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | Which provider/model first? | **Google AI Studio (Gemini 2.5 Flash Lite).** | starting on a second provider before the first is proven. |
| **Q2** | What is the AI for, in this first pass? | **Generating reading content (text/image/video) from an AI prompt.** | turning the AI into a chat surface beside the reader. |
| **Q3** | Where does the reader set the AI provider, and how is it chosen? | **A top tool bar button, grouped under a Settings button on that tool bar; the reader sets multiple providers and selects one.** | an AI button parked on the Edit page. |
| **Q4** | How many providers are settable? | **More than one; the reader selects the one in force.** First supporting: Google AI Studio (Gemini 2.5 Flash Lite). | only a single provider for the app's lifetime. |
| **Q5** | Which free AI providers carry text/image/video generation, and do they need an API key? | **Several, all free: Google AI Studio (Gemini — free tier, no credit card, key from AI Studio), OpenRouter (17 free models incl. text+image+video), NVIDIA NIM (free with dev program, text+image+video), Groq (text+image), Mistral (text+image). All need an API key except OVHcloud's anonymous tier and Kilo Code's keyless free pool. | paid-only providers. |
| **Q6** | How are presets and user-added providers saved? | **The same way — one provider entry with `name`, `url`, `registerTip`, `apiKey`, `active`, `selected`; a preset is just a provider entry the reader has not customised.** | a separate preset table beside the reader's own providers. |
| **Q7** | When is a provider `active`? | **When the connectivity test after the reader adds or edits its `apiKey` passes. Multiple providers can be `active:true` at once — `active` is a capability flag, not a selector.** | a single-provider "in force" flag on every provider entry. |
| **Q8** | What types can the reader ask the AI for? | **text, image or video; the dialog offers the choice and the prompt's `type` field routes it to the right model on the chosen provider.** | the reader hard-coding a type per prompt. |
| **Q9** | How does the reader pick the provider for a prompt? | **A provider options dropdown in the AI dialog; only `active` providers are listed by default; the currently `selected` provider is always shown so the reader can switch back and re-test; choosing a different one updates that provider's `selected` field.** | the provider being locked to the last-selected one outside the dialog. |
| **Q10** | What is the difference between `active` and `selected`? | **`active` = the connectivity test passed (a reusable capability flag); `selected` = the last provider the reader picked in the dialog (the default shown when the dialog opens). Both can coexist: a provider may be `active:true` but not `selected`, and a provider may be `selected` but `active:false` (the reader switched before the test passed).** | treating the last-used provider as the only usable one. |

## User Scenarios & Testing

### User Story 1 - Generate reading content from an AI prompt (Priority: P1)

As a KalaHoo Reading user, I want to put an AI prompt through the AI from the Edit page, so I can have reading content made for me instead of writing it by hand.

**Why this priority**: AI access is the reader's latest open wish; the content, read and render surfaces already exist and keep their own contracts, so the AI seam is the next thing to land.

**Independent Test**: with an AI provider set through the top tool bar's Settings and a prompt submitted through the Edit page's AI button, the AI generates reading content; the generated content then behaves like any other content — it lands in the library, is readable, savable and turnable into video.

**Acceptance Scenarios**:

1. **Given** the reader opened the top tool bar and set an AI provider through the Settings group, **When** the reader taps the AI control in that group, **Then** the AI configuration is where the reader set the provider, its API key, and can add/edit/delete providers; the provider list shows each entry's `active` state (connectivity test passed) and `selected` flag.
2. **Given** a provider is set (its API key added and the connectivity test passed, so it is `active`) and the reader taps the AI button on the Edit page — the AI button is not the Settings / AI provider configuration control — **Then** a dialog opens to pick the generation type (text / image / video), the provider options dropdown (only `active` providers by default; the currently `selected` provider is always shown so the reader can switch back and re-test), and the prompt string.
3. **Given** an AI prompt of a chosen type and a chosen provider, **When** the reader submits it, **Then** the prompt is sent to that provider's model of that type as a string, with the reading content optionally included in the prompt, and the provider's `selected` field is updated to that provider.

## Edge Cases

- **No API key yet**: the AI provider configuration asks the reader to add one before generation can run; a key that fails the connectivity test leaves the provider `active` false.
- **Several providers set, all `active:true`**: the provider options dropdown lists all of them by default; the currently `selected` one is the one shown when the dialog opens.
- **Switching the provider from the dialog**: the provider options dropdown updates the `selected` field on the provider the reader picks; the next prompt goes to that provider. If the new provider is not yet `active`, the reader can still pick it to trigger a fresh connectivity test.
- **AI prompt without reading content**: the reading content is simply not included; the prompt alone drives the generation.
- **The AI call fails** (missing key, model error, network): the failure is surfaced, and the reader's configuration and prompt are kept.

## Requirements

### Functional Requirements

- **FR-001**: The app MUST put AI provider configuration behind a top tool bar button, grouped under a Settings button on that tool bar, that holds multiple AI providers and lets the reader select one.
- **FR-002**: The app MUST seed the provider list with the AI provider presets — Google AI Studio (Gemini), OpenRouter (its 17 `:free` models), NVIDIA NIM — each with a how-to-register tip and an API key field the reader fills in as needed. A preset saves the same way a user-added provider does: a single provider entry with `name`, `url`, `registerTip`, `apiKey`, `active` and `selected`.
- **FR-003**: The app MUST let the reader add their own AI provider (with their own `name` and `url`); the provider list is the reader's own state, not a fixed preset-only set.
- **FR-004**: When the reader adds or edits a provider's `apiKey`, the app MUST run a connectivity test; the provider's `active` field is set true iff that connectivity test passed. Multiple providers can be `active:true` at once — `active` is a capability flag, not a selector.
- **FR-005**: The app MUST open the AI prompt dialog from the AI button on the Edit page (to the right of the Format button); this AI button is not the Settings / AI provider configuration control. The dialog offers a generation type (text / image / video) and a provider options dropdown select (only `active` providers by default; the currently `selected` provider is always shown so the reader can switch back and re-test); picking a provider in the dropdown updates that provider's `selected` field.
- **FR-006**: The app MUST send the AI prompt to the chosen provider's model of the chosen type as a string, with the reading content optionally included in the prompt.
- **FR-007**: The app MUST handle AI failures gracefully (missing key, model error, network) without losing the reader's configuration or prompt.

### Key Entities

- **AIProvider**: one settable AI provider — a `name`, a `url`, a how-to-register tip, an API key the reader fills in as needed, an `active` flag (true only when the connectivity test after the key's add/edit passed; multiple providers can be `active:true` at once) and a `selected` flag (the last provider the reader picked in the dialog, the default shown when the dialog opens). Presets and user-added providers share this shape; several may be set, one is `selected`.
- **AIPrompt**: the AI prompt the reader submits — its `type` (text / image / video), the prompt string, and the optional reading-content inclusion.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The top tool bar's Settings group leads to AI provider configuration the reader can use to set multiple providers (including their own) and mark one `active` (connectivity passed) and one `selected` (the default shown when the dialog opens).
- **SC-002**: The AI button on the Edit page opens a dialog that offers a generation type, a provider options dropdown of the `active` providers (plus the currently `selected` provider so the reader can switch back), and a prompt string; the prompt is sent to the chosen provider's model of the chosen type, and the provider's `selected` field is updated.
- **SC-003**: The reading content can optionally be included in the AI prompt.

## Assumptions

- **A1**: The first supporting provider is Google AI Studio (Gemini 2.5 Flash Lite), for free text/image/video generation.
- **A2**: The AI call goes through the network; network use is declared in this spec (constitution IV).
- **A3**: Including the reading content in the AI prompt is opt-in.
- **A4**: The first supporting provider's free tier needs an API key from that provider (Google AI Studio); no credit card is required, and the tier is rate-limited.
- **A5**: "Free" means the provider's free tier — usage is capped by it, and the caps differ per provider and per model.
- **A6**: Only providers whose connectivity test passed (`active:true`) are listed in the AI dialog's provider options dropdown by default; the currently `selected` provider is always shown so the reader can switch back and trigger a fresh test, even if it is not yet `active`.

## Out of scope

- Providers beyond the presets and the reader's own additions — a provider the reader adds is a configuration matter, not a new feature.
- A paid / paid-only provider tier (A5).

## What this feature does not supersede

Nothing. It adds the first AI access on top of the existing content, read and render pipeline; no earlier requirement is withdrawn, and the pipeline keeps its own contracts (008, 003, 012, 016).
