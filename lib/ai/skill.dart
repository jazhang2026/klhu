/// One AI skill: a prompt template the reader picks to shape the AI's output.
///
/// Skills let the reader turn a simple request into properly formatted
/// KalaHoo Reading content — role tags `{name}`, comment tags `[comment]`, etc.
/// — without manually editing the prompt each time.
library;

import 'prompt.dart';

/// One AI skill entry (data-model §1).
class AISkill {
  /// A stable identifier. Built-in skills use fixed IDs; custom skills get a
  /// UUID at save time.
  final String id;

  /// The display name shown in the skill picker. Used as fallback when no
  /// locale-specific name is available.
  final String name;

  /// Localized display names keyed by locale name (e.g. `'en'`, `'zh'`,
  /// `'es'`). Falls back to [name].
  final Map<String, String> localizedNames;

  /// A one-liner explaining what the skill does. Used as fallback when no
  /// locale-specific description is available.
  final String description;

  /// Localized descriptions keyed by locale name. Falls back to [description].
  final Map<String, String> localizedDescriptions;

  /// The prompt template with `{{variable}}` placeholders. Rendered by the
  /// dialog before sending. Used as fallback when no locale-specific template
  /// is available.
  final String template;

  /// Localized templates keyed by locale name. Falls back to [template].
  final Map<String, String> localizedTemplates;

  /// The generation type this skill targets. Currently always [AIPromptType.text].
  final AIPromptType defaultType;

  /// Whether this skill was shipped with the app (`true`) or created by the
  /// reader (`false`).
  final bool isBuiltIn;

  const AISkill({
    required this.id,
    required this.name,
    this.localizedNames = const {},
    required this.description,
    this.localizedDescriptions = const {},
    required this.template,
    this.localizedTemplates = const {},
    this.defaultType = AIPromptType.text,
    this.isBuiltIn = true,
  });

  /// Returns the display name for [locale] (e.g. `'en'`, `'zh'`, `'es'`),
  /// falling back to [name].
  String displayName(String locale) =>
      localizedNames[locale] ?? localizedNames['en'] ?? name;

  /// Returns the prompt template for [locale], falling back to [template].
  String promptTemplate(String locale) =>
      localizedTemplates[locale] ?? localizedTemplates['en'] ?? template;

  /// Returns the description for [locale], falling back to [description].
  String descriptionFor(String locale) =>
      localizedDescriptions[locale] ?? localizedDescriptions['en'] ?? description;

  AISkill copyWith({
    String? id,
    String? name,
    Map<String, String>? localizedNames,
    String? description,
    Map<String, String>? localizedDescriptions,
    String? template,
    Map<String, String>? localizedTemplates,
    AIPromptType? defaultType,
    bool? isBuiltIn,
  }) {
    return AISkill(
      id: id ?? this.id,
      name: name ?? this.name,
      localizedNames: localizedNames ?? this.localizedNames,
      description: description ?? this.description,
      localizedDescriptions: localizedDescriptions ?? this.localizedDescriptions,
      template: template ?? this.template,
      localizedTemplates: localizedTemplates ?? this.localizedTemplates,
      defaultType: defaultType ?? this.defaultType,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AISkill && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  /// Encode to JSON for SharedPreferences persistence (data-model §2).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localizedNames': localizedNames,
        'description': description,
        'localizedDescriptions': localizedDescriptions,
        'template': template,
        'localizedTemplates': localizedTemplates,
        'defaultType': defaultType.name,
        'isBuiltIn': isBuiltIn,
      };

  /// Decode from JSON; returns null if the shape is malformed.
  factory AISkill.fromJson(Map<String, dynamic> json) {
    final typeStr = json['defaultType'] as String? ?? 'text';
    AIPromptType type;
    switch (typeStr) {
      case 'text':
        type = AIPromptType.text;
        break;
      case 'image':
        type = AIPromptType.image;
        break;
      case 'video':
        type = AIPromptType.video;
        break;
      default:
        type = AIPromptType.text;
    }
    return AISkill(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      localizedNames: (json['localizedNames'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          {},
      description: json['description'] as String? ?? '',
      localizedDescriptions: (json['localizedDescriptions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          {},
      template: json['template'] as String? ?? '',
      localizedTemplates: (json['localizedTemplates'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          {},
      defaultType: type,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }
}
