/// The AI provider entry the reader configures. Presets (Google AI Studio/Gemini,
/// OpenRouter `:free`, NVIDIA NIM) and user-added providers share this shape —
/// a preset is just an entry the reader has not customised (data-model §1).
library;

/// One AI provider the reader has set up. The `active` flag is set only when the
/// connectivity test after an add/edit of the API key passes (spec FR-004, Q7);
/// `selected` is the last provider the reader picked in the AI dialog's dropdown,
/// the default shown when the dialog opens (Q9/Q10).
class AIProvider {
  /// The provider's own display name (e.g. "Google AI Studio (Gemini)", "OpenRouter",
  /// "NVIDIA NIM", or a reader-added name).
  final String name;

  /// The provider's REST endpoint (e.g. Gemini `generativelanguage`, OpenRouter chat
  /// completions, NVIDIA NIM); fixed for a preset, reader-supplied for a user-added
  /// provider.
  final String url;

  /// The static how-to-register tip for that provider (spec FR-002); empty for a
  /// provider without one.
  final String registerTip;

  /// The API key the reader filled in, if the provider needs one (spec FR-002);
  /// empty for a provider without one.
  final String apiKey;

  /// Whether the connectivity test passed for this provider — the test runs when
  /// the reader adds or edits the [apiKey]; a provider with a passing test is
  /// usable. Multiple providers can be `active` at once (Q7).
  final bool active;

  /// The last provider the reader picked in the AI dialog's provider options
  /// dropdown — the default shown when the dialog opens. Updated whenever the
  /// reader picks a different provider in the dropdown (Q9). Set to the first
  /// `active` provider when the list loads.
  final bool selected;

  const AIProvider({
    required this.name,
    required this.url,
    required this.registerTip,
    required this.apiKey,
    this.active = false,
    this.selected = false,
  });

  /// A copy with the given fields replaced.
  AIProvider copyWith({
    String? name,
    String? url,
    String? registerTip,
    String? apiKey,
    bool? active,
    bool? selected,
  }) =>
      AIProvider(
        name: name ?? this.name,
        url: url ?? this.url,
        registerTip: registerTip ?? this.registerTip,
        apiKey: apiKey ?? this.apiKey,
        active: active ?? this.active,
        selected: selected ?? this.selected,
      );

  @override
  bool operator ==(Object other) =>
      other is AIProvider &&
      name == other.name &&
      url == other.url &&
      registerTip == other.registerTip &&
      apiKey == other.apiKey &&
      active == other.active &&
      selected == other.selected;

  @override
  int get hashCode => Object.hash(name, url, registerTip, apiKey, active, selected);

  /// Encode to a JSON map for persistence (config_store.dart).
  Map<String, Object?> toJson() => {
        'name': name,
        'url': url,
        'registerTip': registerTip,
        'apiKey': apiKey,
        'active': active,
        'selected': selected,
      };

  /// Decode from a JSON map written by [toJson]. A malformed entry returns a
  /// default preset — never throws, so a corrupt store never breaks reading.
  factory AIProvider.fromJson(Map<String, Object?> json) {
    return AIProvider(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      registerTip: json['registerTip'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      active: json['active'] == true,
      selected: json['selected'] == true,
    );
  }

  /// The three shipped presets, in the order the reader sees them.
  static const List<AIProvider> presets = [
    // Google AI Studio (Gemini) — free tier, no credit card (research D3, Q5).
    AIProvider(
      name: 'Google AI Studio (Gemini)',
      url: 'https://generativelanguage.googleapis.com/v1beta',
      registerTip:
          'Go to https://aistudio.google.com/app/apikey and create a free API key.',
      apiKey: '',
      active: false,
      selected: true,
    ),
    // OpenRouter — 17 free models including text+image+video (research D3, Q5).
    AIProvider(
      name: 'OpenRouter (:free)',
      url: 'https://openrouter.ai/api/v1',
      registerTip:
          'Go to https://openrouter.ai/keys and create a free API key.',
      apiKey: '',
      active: false,
      selected: false,
    ),
    // NVIDIA NIM — free with NVIDIA developer program (research D3, Q5).
    AIProvider(
      name: 'NVIDIA NIM',
      url: 'https://integrate.api.nvidia.com/v1',
      registerTip:
          'Go to https://build.nvidia.com and sign up for the NVIDIA Developer Program to get a free API key.',
      apiKey: '',
      active: false,
      selected: false,
    ),
  ];
}
