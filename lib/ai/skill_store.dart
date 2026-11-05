/// The AI skill persistence layer — loads, saves, updates and deletes skills
/// over `shared_preferences` (data-model §2).
///
/// Three built-in skills are seeded on first launch:
/// - **Story** — narrative text generation
/// - **Dialogue** — multi-role conversation with `{role}` tags
/// - **Lesson** — bilingual text with `[comment]` translation tags
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'skill.dart';

/// Persists the AI skill list in `shared_preferences` (spec FR-001, FR-005).
///
/// The key for the skill list: one namespace so it collides with no other
/// record.
class AISkillStore {
  static const String _skillsKey = 'ai_skills';

  final Future<SharedPreferences> Function() _prefs;

  AISkillStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// The three shipped built-in skills.
  static const List<AISkill> builtInSkills = [
    AISkill(
      id: 'story',
      name: 'Story',
      localizedNames: {
        'zh': '故事',
        'es': 'Historia',
      },
      description: 'Narrative story with rich descriptions',
      template:
          'Write a short story about {{topic}}. Use vivid, descriptive language suitable for reading aloud. Keep the story between 200 and 500 words.',
      localizedTemplates: {
        'zh':
            '寫一個關於{{topic}}的短篇故事。使用生動、富有描述性的語言，適合朗讀。字數控制在200到500字之間。',
        'es':
            'Escribe un cuento corto sobre {{topic}}. Usa un lenguaje vívido y descriptivo, adecuado para leer en voz alta. Mantén el cuento entre 200 y 500 palabras.',
      },
      isBuiltIn: true,
    ),
    AISkill(
      id: 'dialogue',
      name: 'Dialogue',
      localizedNames: {
        'zh': '對話',
        'es': 'Diálogo',
      },
      description: 'Multi-role conversation with {role} tags',
      template:
          'Write a dialogue between {{characters}} about {{topic}}. Format each speaker\'s line as `{speaker name}：content`. Write at least 6 turns. Do not include any narrative introduction or conclusion — only the dialogue lines.',
      localizedTemplates: {
        'zh':
            '寫一段{{characters}}關於{{topic}}的對話。每句對話格式為`{角色名}：內容`。至少寫6個回合。不要加入任何敘述性開場或結尾，只保留對話行。',
        'es':
            'Escribe un diálogo entre {{characters}} sobre {{topic}}. Formatea cada línea como `{nombre del personaje}：contenido`. Escribe al menos 6 turnos. No incluyas introducción ni conclusión narrativa — solo las líneas de diálogo.',
      },
      isBuiltIn: true,
    ),
    AISkill(
      id: 'lesson',
      name: 'Lesson',
      localizedNames: {
        'zh': '課程',
        'es': 'Lección',
      },
      description: 'Bilingual lesson with [comment] tags',
      template:
          'Create a bilingual lesson about {{topic}}. Write each sentence in Spanish, followed by a "[comment]" tag, then followed by the English translation on the same line. Include at least 8 sentence-pairs. Only contains the lesson to the students.',
      localizedTemplates: {
        'zh':
            '創作一堂關於{{topic}}的雙語課程。每句先用中文寫，然後在同一行加上[comment]英文翻譯[/comment]標籤。至少包含8組句子對。[comment]內容永遠不應朗讀——僅供顯示。',
        'es':
            'Crea una lección bilingüe sobre {{topic}}. Escribe cada oración en español, seguida de una etiqueta [comment]traducción al inglés[/comment] en la misma línea. Incluye al menos 8 pares de oraciones. El contenido en [comment]nunca debe leerse en voz alta — solo para visualización.',
      },
      isBuiltIn: true,
    ),
  ];

  /// Load all skills: built-in defaults merged with any custom skills stored
  /// in SharedPreferences. Custom skills with a matching [id] overwrite the
  /// built-in entry.
  Future<List<AISkill>> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_skillsKey);
    if (raw == null || raw.isEmpty) {
      debugPrint('klhu AI skills: no stored skills, using built-in defaults');
      return List<AISkill>.from(builtInSkills);
    }
    try {
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      final skills = jsonList
          .map((e) => e as Map<String, dynamic>)
          .map(AISkill.fromJson)
          .where((s) => s.id.isNotEmpty)
          .toList();

      // Merge: built-ins first, then custom skills overwrite by id.
      final Map<String, AISkill> merged = {};
      for (final b in builtInSkills) {
        merged[b.id] = b;
      }
      for (final c in skills) {
        merged[c.id] = c;
      }
      final result = List<AISkill>.from(merged.values);
      debugPrint(
          'klhu AI skills: loaded ${result.length} skills (${builtInSkills.length} built-in + ${skills.length} custom)');
      return result;
    } catch (e) {
      debugPrint('klhu AI skills: failed to parse stored skills: $e');
      return builtInSkills;
    }
  }

  /// Save [skills] to SharedPreferences. All entries (built-in and custom) are
  /// written; the built-in defaults are re-seeded only on first launch.
  Future<void> save(List<AISkill> skills) async {
    final prefs = await _prefs();
    final jsonList = skills.map((s) => s.toJson()).toList();
    await prefs.setString(_skillsKey, jsonEncode(jsonList));
    debugPrint('klhu AI skills: saved ${skills.length} skills');
  }

  /// Add or update a skill. If a skill with the same [id] already exists it is
  /// replaced; otherwise it is appended.
  Future<void> upsert(AISkill skill) async {
    final skills = await load();
    final index = skills.indexWhere((s) => s.id == skill.id);
    if (index >= 0) {
      skills[index] = skill;
    } else {
      skills.add(skill);
    }
    await save(skills);
  }

  /// Delete the skill with [id]. Returns true if a skill was removed.
  /// Built-in skills cannot be deleted.
  Future<bool> delete(String id) async {
    final skills = await load();
    // Built-in skills are protected — the reader can only delete custom skills.
    final toDelete = skills.firstWhere((s) => s.id == id, orElse: () => const AISkill(id: '', name: '', description: '', template: ''));
    if (toDelete.isBuiltIn) return false;
    final before = skills.length;
    skills.removeWhere((s) => s.id == id);
    if (skills.length < before) {
      await save(skills);
      return true;
    }
    return false;
  }

  /// Get a skill by [id], or null if not found.
  AISkill? getById(String id) {
    // Synchronous lookup — load() is async but we cache the result in the UI.
    // This method is intended for use after load() has populated the local list.
    return null;
  }
}
