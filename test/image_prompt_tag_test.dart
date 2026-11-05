/// 031 — the image-prompt tag parser (data-model §1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/image_prompt_tag.dart';
import 'package:klhu/scene_tag.dart';

void main() {
  group('isImagePromptSpelling', () {
    test('recognises all four spellings, case-insensitive', () {
      expect(isImagePromptSpelling('image_prompt'), isTrue);
      expect(isImagePromptSpelling('IMAGE_PROMPT'), isTrue);
      expect(isImagePromptSpelling('Image_Prompt'), isTrue);
      expect(isImagePromptSpelling('图像提示'), isTrue);
      expect(isImagePromptSpelling('imagem'), isTrue);
      expect(isImagePromptSpelling('prompt_img'), isTrue);
    });

    test('rejects unknown spellings', () {
      expect(isImagePromptSpelling('scene'), isFalse);
      expect(isImagePromptSpelling('comment'), isFalse);
      expect(isImagePromptSpelling('foo'), isFalse);
    });
  });

  group('imagePromptTagsOf', () {
    test('finds one tag on its own line', () {
      const text = '[image_prompt] a tiger walking in the jungle\nSome dialog here.';
      final tags = imagePromptTagsOf(text);
      expect(tags.length, 1);
      expect(tags[0].spelling, 'image_prompt');
      expect(tags[0].promptIn(text), 'a tiger walking in the jungle');
    });

    test('finds multiple tags', () {
      const text = '''[image_prompt] scene one prompt
line after first

[scene] Scene 2
[image_prompt] scene two prompt''';
      final tags = imagePromptTagsOf(text);
      expect(tags.length, 2);
      expect(tags[0].promptIn(text), 'scene one prompt');
      expect(tags[1].promptIn(text), 'scene two prompt');
    });

    test('skips tags inside comments', () {
      const text = '[comment] not a real tag [image_prompt] ignored\nReal content.';
      final tags = imagePromptTagsOf(text, inside: [(0, text.length)]);
      expect(tags, isEmpty);
    });

    test('empty text returns empty list', () {
      expect(imagePromptTagsOf(''), isEmpty);
    });

    test('no tag line returns empty list', () {
      expect(imagePromptTagsOf('Just plain text.\nNo tags here.'), isEmpty);
    });

    test('spelling is stored as written', () {
      const text = '[圖像提示] traditional chinese prompt\n';
      final tags = imagePromptTagsOf(text);
      expect(tags.length, 1);
      expect(tags[0].spelling, '圖像提示');
    });
  });

  group('SceneWithPrompt', () {
    test('pairs scene with its image prompt', () {
      const text = '''[scene] Act 1
{Narrator}：Once upon a time.
[image_prompt] A dark forest at night

[scene] Act 2
{Hero}：I will find the treasure.
[image_prompt] A golden chest in a cave''';
      final scenes = scenesOf(text);
      final prompts = imagePromptTagsOf(text);
      final result = scenesWithPrompts(scenes, prompts);
      expect(result.length, 2);
      expect(result[0].imagePrompt, isNotNull);
      expect(result[0].imagePrompt!.promptIn(text), 'A dark forest at night');
      expect(result[1].imagePrompt, isNotNull);
      expect(result[1].imagePrompt!.promptIn(text), 'A golden chest in a cave');
    });

    test('scene without image prompt has null prompt', () {
      const text = '''[scene] Act 1
{Narrator}：Once upon a time.''';
      final scenes = scenesOf(text);
      final prompts = imagePromptTagsOf(text);
      final result = scenesWithPrompts(scenes, prompts);
      expect(result.length, 1);
      expect(result[0].imagePrompt, isNull);
    });

    test('orphaned image prompt (before any scene) is skipped', () {
      const text = '''[image_prompt] orphan prompt
[scene] Act 1
{Narrator}：Hello.''';
      final scenes = scenesOf(text);
      final prompts = imagePromptTagsOf(text);
      final result = scenesWithPrompts(scenes, prompts);
      expect(result.length, 1);
      expect(result[0].imagePrompt, isNull);
    });
  });

  group('imagePromptMasked', () {
    test('replaces tag line with spaces, keeps other text', () {
      const text = '[image_prompt] my prompt\nHello world.';
      final masked = imagePromptMasked(text);
      // Tag line is masked, content line is untouched.
      expect(masked.contains('Hello world'), isTrue);
      expect(masked.contains('my prompt'), isFalse);
    });

    test('empty text returns empty string', () {
      expect(imagePromptMasked(''), '');
    });
  });

  group('scenesWithPromptsOf', () {
    test('convenience function pairs scenes with prompts', () {
      const text = '''[scene] Act 1
{Hero}：Hello.
[image_prompt] Hero standing

[scene] Act 2
{Villain}：Never!
[image_prompt] Villain lurking''';
      final result = scenesWithPromptsOf(text);
      expect(result.length, 2);
      expect(result[0].imagePrompt, isNotNull);
      expect(result[1].imagePrompt, isNotNull);
    });
  });
}
