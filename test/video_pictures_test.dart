/// The reader's pictures, their schedule and their copies (spec 012 US4):
/// quickstart scenarios 43 and 48 — the schedule in the video's own frames,
/// changing only where a sentence changes, and the picks' copies into the
/// render's working directory.
///
/// **Re-cut 2026-09-27 on the reader's own rule**: no picture may land or lift
/// inside a sentence — "one sentence is the unit on screen" — so the first cut's
/// equal shares *of the video's frames* were wrong: a share boundary could fall
/// in the middle of a sentence. The schedule now shares the plan's **sentences**,
/// so a range is the run of frames those sentences occupy, each sentence's
/// trailing gap included and the end hold with the last one (FR-026, D14).
///
/// This cut's RED came in two steps and both are real. The new signature (`plan`
/// instead of `totalFrames`) first failed to compile — `+0 -1`, naming `plan` at
/// eight call sites — and then, with the *old* frame-sharing rule adapted to that
/// signature so the assertions could actually be exercised, **5 of the 8 schedule
/// cases failed**: `a.png starts mid-sentence (0)`, the title card carrying a
/// picture, and shares of three sentences where the reader's rule allows two.
/// The sentence-based rule is what made it green.
///
/// The plan fixture is the timeline's own: six sentences of one second each at
/// 30 fps, which puts the sentence starts at frames 75, 117, 159, 201, 243 and
/// 285 — 75 frames of title card first, a 12-frame gap after each sentence, a
/// 60-frame end hold — so the video's last frame is 374.
///
/// 48's last claim — that the copies are gone after *any* ending a render can
/// have, finished, cancelled or failed — is the renderer's own cleanup (it
/// deletes what it wrote, and the copies are written into that same directory).
/// What this file asserts is the unit half: every copy lands inside the working
/// directory and nowhere else, which is the only thing the renderer's own
/// delete can reach. The render-level rows are T046's and the device half is
/// row 49.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/video_aspect.dart';
import 'package:klhu/video_pictures.dart';
import 'package:klhu/video_timeline.dart';

/// Six sentences, one second of audio each: every frame number in this file
/// comes from this fixture, worked out rather than guessed.
const _content = 'One. Two. Three.\n\nFour. Five. Six.';

Future<VideoPlan> _plan() async {
  final sentences = await videoSentencesFrom(
    content: _content,
    position: 0,
    loadVoice: (language) async => null,
  );
  expect(sentences, hasLength(6), reason: 'fixture drift');
  return buildVideoPlan(
    title: 'Test',
    sentences: sentences,
    audioMs: [for (var _ in sentences) 1000],
    aspect: VideoAspect.vertical,
  );
}

/// A pick whose bytes are real and known, so what is stored can be checked
/// rather than counted.
PickedPicture _pick(String name, String body) => PickedPicture(
  name: name,
  read: () async => Uint8List.fromList(body.codeUnits),
);

/// A pick whose file has gone: storing it has to fail rather than write a hole.
PickedPicture _unreadable(String name) => PickedPicture(
  name: name,
  read: () async => throw const FileSystemException('the file has gone'),
);

/// Where [_held] stores its pictures: one directory for the whole file, so the
/// copies' own group can still count the files in its working directory.
Directory? _stored;

/// A picture the reader chose and the app has **stored**: a real file holding
/// [body], so what the page shows and the render copies is a file rather than a
/// claim about one (FR-025, D18).
///
/// The stored file is named for the picture's own name with every directory part
/// stripped — what [storePicks] does with it — while the [HeldPicture.name] keeps
/// the name the pick came with, hostile parts and all: putting up with that name
/// is the copy's own job, and a counter keeps two pictures of the same name out
/// of each other's file.
HeldPicture _held(String name, String body) {
  final dir = _stored ??= Directory.systemTemp.createTempSync('klhu_stored_picks');
  final parts = name
      .split(RegExp(r'[/\\]'))
      .where((part) => part.isNotEmpty && part != '.')
      .toList();
  final file = '${_heldSeq++}_${parts.isEmpty ? 'picture' : parts.last}';
  final path = '${dir.path}${Platform.pathSeparator}$file';
  File(path).writeAsStringSync(body);
  return HeldPicture(name: name, path: path);
}

/// The counter that keeps [_held]'s files apart.
int _heldSeq = 0;

/// How many of the plan's sentences a picture's range covers.
int _sentencesIn(VideoPlan plan, ScheduledPicture picture) => plan.sentences
    .where(
      (slot) =>
          slot.startFrame >= picture.startFrame &&
          slot.startFrame <= picture.endFrame,
    )
    .length;

/// Every frame of the spoken part — the first sentence's first frame to the
/// video's last, each sentence's gap included — is covered exactly once.
void _expectSpokenPartPartitioned(VideoPlan plan, PictureSchedule schedule) {
  for (var frame = plan.sentences.first.startFrame;
      frame < plan.totalFrames;
      frame++) {
    final matches = schedule.pictures
        .where((p) => frame >= p.startFrame && frame <= p.endFrame)
        .toList();
    expect(matches, hasLength(1), reason: 'frame $frame');
  }
}

void main() {
  late VideoPlan plan;
  late Directory work;

  setUp(() async {
    plan = await _plan();
    work = Directory.systemTemp.createTempSync('klhu_pictures');
  });

  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  group('the schedule is the video\'s sentences', () {
    test('a picture runs from a sentence to the frame before the next '
        'picture\'s sentence', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png'],
      );

      expect(schedule.pictures, hasLength(2));
      expect(schedule.pictures.first.path, 'a.png');
      expect(schedule.pictures.first.startFrame, plan.sentences[0].startFrame);
      expect(
        schedule.pictures.first.endFrame,
        plan.sentences[3].startFrame - 1,
        reason: 'the first picture gives way exactly where sentence 4 starts',
      );
      expect(schedule.pictures[1].startFrame, plan.sentences[3].startFrame);
      expect(
        schedule.pictures[1].endFrame,
        plan.totalFrames - 1,
        reason: 'the end frame is the video\'s last frame, and it is inclusive',
      );
    });

    test('no boundary falls inside a sentence', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png', 'c.png', 'd.png'],
      );

      // Every boundary a picture contributes — where it starts, and the frame
      // after where it ends — is a sentence's own first frame or the end of the
      // video. Nothing in between, which is the reader's own rule.
      final boundaries = {
        for (final slot in plan.sentences) slot.startFrame,
        plan.totalFrames,
      };
      for (final picture in schedule.pictures) {
        expect(
          boundaries,
          contains(picture.startFrame),
          reason: '${picture.path} starts mid-sentence (${picture.startFrame})',
        );
        expect(
          boundaries,
          contains(picture.endFrame + 1),
          reason: '${picture.path} ends mid-sentence (${picture.endFrame})',
        );
      }
    });

    test('the ranges partition the spoken part, and the title card stays '
        'plain', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png'],
      );

      _expectSpokenPartPartitioned(plan, schedule);

      // The title card is the app's own card, not a sentence: no picture.
      expect(schedule.at(0), isNull);
      for (var frame = 0; frame < plan.sentences.first.startFrame; frame++) {
        expect(schedule.at(frame), isNull, reason: 'title card frame $frame');
      }
      expect(schedule.at(plan.sentences.first.startFrame), isNotNull);
    });

    test('the shares are equal over sentences, in the order chosen', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['first.png', 'second.png', 'third.png'],
      );

      // Two sentences each, in the order chosen...
      for (final picture in schedule.pictures) {
        expect(_sentencesIn(plan, picture), 2);
      }
      expect(schedule.at(plan.sentences[0].startFrame)!.path, 'first.png');
      expect(schedule.at(plan.sentences[2].startFrame)!.path, 'second.png');
      expect(schedule.at(plan.sentences[4].startFrame)!.path, 'third.png');

      // ...and because a sentence's run carries the gap after it — and the
      // last one carries the end hold — equal sentences are not equal frames.
      // That is the price of never changing a picture inside a sentence.
      final lengths = [
        for (final p in schedule.pictures) p.endFrame - p.startFrame + 1,
      ];
      expect(lengths, [84, 84, 132]);

      // A number of pictures that does not divide the sentences: the extra
      // sentences go to the earlier pictures, and no sentence is left out.
      final uneven = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png', 'c.png', 'd.png'],
      );
      expect(
        [for (final p in uneven.pictures) _sentencesIn(plan, p)],
        [2, 2, 1, 1],
      );
      _expectSpokenPartPartitioned(plan, uneven);
    });

    test('the last picture holds to the video\'s last frame, end hold '
        'included', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png'],
      );

      // FR-008's own rule for the last sentence's run — the hold shows the
      // sentence just heard — extended to the picture behind it: the video does
      // not fall back to the plain background for its last two seconds.
      final hold = plan.slots.last;
      expect(plan.totalFrames - hold.startFrame, plan.framesFor(VideoPlan.holdMs));
      for (var frame = hold.startFrame; frame < plan.totalFrames; frame++) {
        expect(schedule.at(frame)!.path, 'b.png', reason: 'hold frame $frame');
      }
    });

    test('more pictures than sentences: the extras are not drawn', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const [
          'a.png', 'b.png', 'c.png', 'd.png', 'e.png',
          'f.png', 'g.png', 'h.png', 'i.png',
        ],
      );

      expect(
        schedule.pictures.where((p) => p.isDrawn),
        hasLength(6),
        reason: 'six sentences, one picture each',
      );
      expect(
        schedule.pictures.where((p) => !p.isDrawn),
        hasLength(3),
        reason: 'three pictures over six sentences received no sentence',
      );
      // Every sentence is still covered by exactly one picture...
      _expectSpokenPartPartitioned(plan, schedule);
      // ...and an undrawn picture is never returned for a frame.
      for (var frame = 0; frame < plan.totalFrames; frame++) {
        final picture = schedule.at(frame);
        if (picture != null) expect(picture.isDrawn, isTrue);
      }
    });

    test('no pictures is a valid schedule — the plain background', () {
      final schedule = buildPictureSchedule(plan: plan, paths: const []);

      expect(schedule.pictures, isEmpty);
      expect(schedule.at(plan.sentences.first.startFrame), isNull);
      expect(schedule.at(plan.totalFrames - 1), isNull);
    });

    test('a frame outside the video has no picture', () {
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: const ['a.png', 'b.png'],
      );

      expect(schedule.at(-1), isNull);
      expect(schedule.at(plan.totalFrames), isNull);
    });
  });

  group('a pick is stored once, at the pick (D18)', () {
    test('every pick is written where the app owns it, in the order chosen',
        () async {
      final dir = Directory('${work.path}/picks_0')..createSync();

      final held = await storePicks(
        picks: [_pick('one.png', 'first'), _pick('two.png', 'second')],
        dir: dir,
      );

      expect(held.map((p) => p.name), ['one.png', 'two.png']);
      expect(held.map((p) => File(p.path).readAsStringSync()),
          ['first', 'second'],
          reason: 'the page shows and the render copies the pick\'s own bytes, '
              'from the file the app wrote (FR-025, D18)');
      expect(
        held.map((p) => File(p.path).parent.absolute.path),
        everyElement(dir.absolute.path),
        reason: 'inside the one directory the page owns and removes (FR-025)',
      );
    });

    test('a pick nothing can be read from throws, and writes nothing',
        () async {
      final dir = Directory('${work.path}/picks_1')..createSync();

      await expectLater(
        storePicks(
          picks: [_pick('fine.png', 'bytes'), _unreadable('gone.png')],
          dir: dir,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(dir.listSync(), isEmpty,
          reason: 'a choice with a hole in it is not half a choice, and nothing '
              'half-stored is left for the page to show');
    });

    test('the stored picks are the page\'s to remove', () async {
      final dir = Directory('${work.path}/picks_2')..createSync();
      final held = await storePicks(picks: [_pick('one.png', 'first')], dir: dir);
      expect(File(held.single.path).existsSync(), isTrue);

      await discardPictures(dir);

      expect(dir.existsSync(), isFalse,
          reason: 'the picks belong to the prompt that chose them and to the '
              'render that used them, and to nothing after that (FR-025)');
      // And an ending that finds it already gone is not an ending that fails.
      await discardPictures(dir);
    });
  });

  group('the copies go with the working copy', () {
    test('each pick is copied into the working directory, once, in order', () async {
      final copies = await copyPictures(
        pictures: [_held('one.png', 'first'), _held('two.png', 'second')],
        workDir: work,
      );

      expect(copies, hasLength(2));
      expect(File(copies[0]).readAsStringSync(), 'first');
      expect(File(copies[1]).readAsStringSync(), 'second');
      expect(copies[0], contains('one.png'));
      expect(copies[1], contains('two.png'));
      expect(
        work.listSync().whereType<File>(),
        hasLength(2),
        reason: 'two files, not four: each pick is copied once',
      );
    });

    test('two picks with the same name do not collide', () async {
      final copies = await copyPictures(
        pictures: [_held('scene.png', 'bright'), _held('scene.png', 'dark')],
        workDir: work,
      );

      expect(copies.toSet(), hasLength(2));
      expect(File(copies[0]).readAsStringSync(), 'bright');
      expect(File(copies[1]).readAsStringSync(), 'dark');
    });

    test('a copy keeps a name the reader can recognise', () async {
      final copies = await copyPictures(
        pictures: [_held('02_发现银光虫.png', 'bytes')],
        workDir: work,
      );

      final name = copies.single.split(Platform.pathSeparator).last;
      expect(name, contains('02_发现银光虫.png'));
      expect(name, startsWith('picture_0_'));
    });

    test('a copy that fails leaves nothing behind', () async {
      await expectLater(
        copyPictures(
          pictures: [_held('fine.png', 'bytes')],
          workDir: work..deleteSync(recursive: true),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        work.existsSync(),
        isFalse,
        reason: 'a render with a hole in it is worse than a failed render, so '
            'the copies already written go too',
      );
    });

    test('every copy lands inside the working directory, whatever it is called', () async {
      final copies = await copyPictures(
        pictures: [
          _held('fine.png', 'bytes'),
          _held('../../etc/passwd', 'bytes'),
          _held('a/sub/dir/photo.png', 'bytes'),
        ],
        workDir: work,
      );

      for (final path in copies) {
        expect(
          File(path).absolute.parent.absolute.path,
          work.absolute.path,
          reason: 'the render deletes what it wrote in its own directory, so a '
              'copy outside it would outlive the render',
        );
        expect(File(path).existsSync(), isTrue);
      }
    });
  });

  group('choosing again adds, and nothing is capped', () {
    test('a second pick adds to the first rather than replacing it', () {
      final first = [_held('one.png', 'one'), _held('two.png', 'two')];
      final second = [_held('three.png', 'three')];

      final merged = mergePicks(first, second);

      expect(merged, hasLength(3),
          reason: 'the reader\'s second pick is added to what they had, not put '
              'in its place (FR-025)');
      expect(merged.map((p) => p.name), ['one.png', 'two.png', 'three.png'],
          reason: 'in the order chosen: the first pick keeps its place, so the '
              'schedule does not move under the reader');
    });

    test('a pick past what the cap used to be is taken whole', () {
      // The reader's own instruction of 2026-09-28 — "remove max 20 images
      // limit. keep all 30 images for now. user can delete images." — so the
      // pick that used to be refused (or trimmed) is neither: all of it is
      // kept, and a picture the reader no longer wants is taken back by its own
      // remove (FR-030).
      final held = [for (var i = 0; i < 15; i++) _held('a$i.png', 'a$i')];
      final picked = [for (var i = 0; i < 15; i++) _held('b$i.png', 'b$i')];

      final merged = mergePicks(held, picked);

      expect(merged, hasLength(30), reason: '15 + 15 is kept whole');
      expect(merged.map((p) => p.name), [
        ...held.map((p) => p.name),
        ...picked.map((p) => p.name),
      ], reason: 'and in the order chosen: nothing is trimmed and nothing is '
          'dropped');
    });
  });

  group('the reader can change the order (FR-032)', () {
    List<HeldPicture> three() => [
      _held('one.png', 'one'),
      _held('two.png', 'two'),
      _held('three.png', 'three'),
    ];

    test('a picture dropped on another cell lands there', () {
      final moved = movePicture(three(), 0, 2);

      expect(moved.map((p) => p.name), ['two.png', 'three.png', 'one.png'],
          reason: 'the first picture goes where the third was and the one it '
              'passed moves up — a move, not a rotation of the others');
      expect(moved, hasLength(3), reason: 'a reorder is not a copy');
    });

    test('the same move the other way', () {
      expect(movePicture(three(), 2, 0).map((p) => p.name),
          ['three.png', 'one.png', 'two.png'],
          reason: 'rightwards and leftwards are the same rule');
    });

    test('a drop on itself, or from nowhere, changes nothing', () {
      final pictures = three();
      final names = pictures.map((p) => p.name).toList();

      expect(movePicture(pictures, 1, 1).map((p) => p.name), names,
          reason: 'a gesture that ends where it started is not a move');
      expect(movePicture(pictures, -1, 0).map((p) => p.name), names);
      expect(movePicture(pictures, 3, 0).map((p) => p.name), names);
    });

    test('the order the reader set is the order the video draws', () async {
      // One contract, not two (FR-026/FR-032): the cells stand in the order the
      // schedule uses. The moved choice is handed to the schedule as it stands,
      // and each picture's range begins at the sentence its own place gives it.
      final pictures = movePicture(three(), 0, 2);
      final plan = await _plan();
      final schedule = buildPictureSchedule(
        plan: plan,
        paths: pictures.map((p) => p.name).toList(),
      );

      expect(schedule.pictures.map((p) => p.path),
          ['two.png', 'three.png', 'one.png']);
      expect(_sentencesIn(plan, schedule.pictures.first), 2,
          reason: 'the picture that moved to the front took the first '
              'sentences, as the first cell does');
      expect(schedule.pictures.last.path, 'one.png',
          reason: 'and the one that moved to the back is the one the video '
              'ends on');
    });
  });
}
