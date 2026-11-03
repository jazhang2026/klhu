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

  /// The display name shown in the skill picker.
  final String name;

  /// A one-liner explaining what the skill does.
  final String description;

  /// The prompt template with `{{variable}}` placeholders. Rendered by the
  /// dialog before sending.
  final String template;

  /// The generation type this skill targets. Currently always [AIPromptType.text].
  final AIPromptType defaultType;

  /// Whether this skill was shipped with the app (`true`) or created by the
  /// reader (`false`).
  final bool isBuiltIn;

  const AISkill({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    this.defaultType = AIPromptType.text,
    this.isBuiltIn = true,
  });

  AISkill copyWith({
    String? id,
    String? name,
    String? description,
    String? template,
    AIPromptType? defaultType,
    bool? isBuiltIn,
  }) {
    return AISkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      template: template ?? this.template,
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
        'description': description,
        'template': template,
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
      description: json['description'] as String? ?? '',
      template: json['template'] as String? ?? '',
      defaultType: type,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }
}
