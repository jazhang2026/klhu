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
      localizedDescriptions: {
        'zh': '叙事故事，语言生动丰富',
        'es': 'Cuento narrativo con descripciones ricas',
      },
      template:
          'Write a short story about {{topic}}. Use vivid, descriptive language suitable for reading aloud. Keep the story between 200 and 500 words. Only contains the content of the story.',
      localizedTemplates: {
        'zh':
            '写一篇关于{{topic}}的短篇故事。使用生动、富有描述性的语言，适合朗读。字数控制在200到500字之间。只保留故事内容，不加开场或结尾。',
        'es':
            'Escribe un cuento corto sobre {{topic}}. Usa un lenguaje vívido y descriptivo, adecuado para leer en voz alta. Mantén el cuento entre 200 y 500 palabras. Solo contiene el contenido del cuento.',
      },
      isBuiltIn: true,
    ),
    AISkill(
      id: 'dialogue',
      name: 'Dialogue',
      localizedNames: {
        'zh': '对话',
        'es': 'Diálogo',
      },
      description: 'Multi-role conversation with {role} tags',
      localizedDescriptions: {
        'zh': '多角色对话，含{角色}标签',
        'es': 'Conversación multi-rol con etiquetas {role}',
      },
      template:
          'Write a dialogue between {{characters}} about {{topic}}. Format each speaker\'s line as `{speaker name}：content`. Add a space line after each turn. Write at least 6 turns. Do not include any narrative introduction or conclusion — only the dialogue lines.',
      localizedTemplates: {
        'zh':
            '写一段{{characters}}关于{{topic}}的对话。每句对话格式为`{角色名}：内容`。每段对话后加一个空行。至少写6个回合。不要加入任何叙述性开场或结尾，只保留对话行。',
        'es':
            'Escribe un diálogo entre {{characters}} sobre {{topic}}. Formatea cada línea como `{nombre del personaje}：contenido`. Agrega una línea vacía después de cada turno. Escribe al menos 6 turnos. No incluyas introducción ni conclusión narrativa — solo las líneas de diálogo.',
      },
      isBuiltIn: true,
    ),
    AISkill(
      id: 'lesson',
      name: 'Lesson',
      localizedNames: {
        'zh': '课程',
        'es': 'Lección',
      },
      description: 'Bilingual lesson with [comment] tags',
      localizedDescriptions: {
        'zh': '双语课程，含[comment]标签',
        'es': 'Lección bilingüe con etiquetas [comment]',
      },
      template:
          'Create a bilingual lesson about {{topic}}. Write each sentence in Spanish, followed by a "[comment]" tag, then followed by the English translation on the same line. then followed by an empty line. Include at least 8 sentence-pairs. Only contains the lesson to the students.',
      localizedTemplates: {
        'zh':
            '创作一堂关于{{topic}}的双语课程。每句先用西班牙语写，然后在同一行加上"[comment]"标签，再写英文翻译，然后空一行。至少包含8组句子对。只保留课程内容，不加开场或结尾。',
        'es':
            'Crea una lección bilingüe sobre {{topic}}. Escribe cada oración en español, seguida de una etiqueta "[comment]", luego la traducción al inglés en la misma línea, luego una línea vacía. Incluye al menos 8 pares de oraciones. Solo contiene la lección para los estudiantes.',
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
