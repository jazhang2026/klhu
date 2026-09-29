/// The reader's own pictures in the video: which one is drawn when, and the
/// copies the render reads (spec 012 US4, decisions D15 and FR-026–FR-028).
///
/// Two things live here and nothing else. The **schedule** is each picture's
/// inclusive run of the video's own frames — counted in frames, not seconds, so
/// that a later "move this picture's start frame" is expressed in the video's
/// own numbering (FR-026). The **copies** are the picks written once into the
/// render's working directory before any frame is painted, so what the render
/// reads is a file it owns for the length of the job rather than a handle whose
/// read grant may end with the picker's activity (D15).
library;

import 'dart:io';

import 'package:klhu/platform/picture_picker.dart';
import 'package:klhu/video_timeline.dart';

/// A picture the reader has chosen, as the app holds it between the pick and the
/// render: the **file the app wrote it into** when it was picked, and the name it
/// came with (FR-025, D18).
///
/// The pick's bytes are read once at the pick, while the picker's own read grant
/// is alive (D15), and written straight into a directory of the app's own — so
/// what the page shows and what the render copies are one file the app owns, and
/// a choice of thirty photographs is thirty paths rather than a few hundred
/// megabytes held in memory (the reader's own instruction of 2026-09-28:
/// "remove max 20 images limit. keep all 30 images for now. user can delete
/// images.").
class HeldPicture {
  const HeldPicture({required this.name, required this.path});

  /// The file's own name, with any directory stripped (`sunset.png`).
  final String name;

  /// The file inside the app's own directory that holds this picture.
  final String path;
}

/// Writes every pick into [dir] and answers the files it wrote, in the order
/// chosen (FR-025, D18).
///
/// This is the pick's own read, spent once: the bytes come from the picker while
/// its grant is alive and go into a file the app owns, which is what lets the page
/// show the picture (FR-030) and the render copy it without reading the pick
/// again. Every file is written inside [dir] and nowhere else, so the page's own
/// "delete what I stored" covers them (FR-025).
///
/// The first pick that cannot be read fails the whole call and deletes what it
/// already wrote: a choice with a hole in it is not half a choice, and the page
/// says so rather than showing a picture nothing can open.
Future<List<HeldPicture>> storePicks({
  required List<PickedPicture> picks,
  required Directory dir,
}) async {
  final held = <HeldPicture>[];
  final written = <String>[];
  try {
    for (var i = 0; i < picks.length; i++) {
      final name = _safeName(picks[i].name);
      final path = '${dir.path}${Platform.pathSeparator}pick_${i}_$name';
      await File(path).writeAsBytes(await picks[i].read());
      written.add(path);
      held.add(HeldPicture(name: picks[i].name, path: path));
    }
    return held;
  } catch (_) {
    for (final path in written) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone, or never readable: nothing left to clean.
      }
    }
    rethrow;
  }
}

/// Removes the directory the picks were stored in, and everything in it
/// (FR-025).
///
/// The picks belong to the prompt that chose them and to the render that used
/// them, and to nothing after that: they are never remembered, so the page takes
/// the whole directory away when the render is over — however it ended. A
/// directory that is already gone is not an error.
Future<void> discardPictures(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } on FileSystemException {
    // Never created, or already removed by an earlier ending.
  }
}

/// The pictures chosen so far plus [picked], in the order they were chosen
/// (FR-025).
///
/// A second pick **adds** to the first rather than replacing it — the reader's
/// own rule of 2026-09-28 — and **nothing is capped**: every picture the reader
/// chooses is kept, and the only way one leaves the choice is the reader's own
/// remove (FR-030). The cap of 20 this file used to carry is withdrawn
/// (2026-09-28: "remove max 20 images limit. keep all 30 images for now. user
/// can delete images."), together with the refusal and its warning: with no cap
/// there is no pick to refuse, and a picture the reader no longer wants is the
/// reader's own to take back rather than the app's to trim.
List<T> mergePicks<T>(List<T> chosen, List<T> picked) => <T>[...chosen, ...picked];

/// [pictures] with the one at [from] moved to [to] — the reader's own order,
/// which is the order the video draws the pictures in (FR-026, FR-032).
///
/// [to] is the index the picture lands **at** in the resulting list, which is
/// how a drop on a cell reads ("put this one where that one is"): moving the
/// first of three onto the last gives the last, first, second. Out-of-range
/// or nowhere-to-go moves hand the list back unchanged rather than throwing —
/// a gesture that ends on its own cell is a move the reader cancelled, not a
/// fault.
List<T> movePicture<T>(List<T> pictures, int from, int to) {
  if (from == to || from < 0 || from >= pictures.length) {
    return List<T>.of(pictures);
  }
  final moved = List<T>.of(pictures);
  final picture = moved.removeAt(from);
  moved.insert(to.clamp(0, moved.length), picture);
  return moved;
}

/// One picture's stretch of the video.
class ScheduledPicture {
  const ScheduledPicture({
    required this.path,
    required this.startFrame,
    required this.endFrame,
  });

  /// The copy inside the render's working directory that this range draws.
  final String path;

  /// The range, in the video's own frame numbers. [endFrame] is **inclusive**,
  /// which is how FR-026 states it and how a later edit moves it.
  final int startFrame;
  final int endFrame;

  /// How many frames this picture occupies; zero for a picture the video is too
  /// short to reach.
  int get frames => endFrame - startFrame + 1;

  /// Whether the video is long enough to draw this picture at all. FR-026's
  /// rule for more pictures than frames: the extras are not drawn, and every
  /// frame is still covered by one picture or the plain background (FR-028).
  bool get isDrawn => frames > 0;
}

/// Every picture's stretch, in the order the reader chose them (FR-026).
class PictureSchedule {
  const PictureSchedule(this.pictures);

  /// No pictures: the video is its plain background throughout (FR-028).
  static const PictureSchedule none = PictureSchedule(<ScheduledPicture>[]);

  /// The stretches, in the order chosen. May contain pictures the video is too
  /// short to reach; they are never drawn.
  final List<ScheduledPicture> pictures;

  /// The picture covering [frame], or null where the frame is the plain
  /// background — outside the video, or on a frame no picture reaches.
  ScheduledPicture? at(int frame) {
    for (final picture in pictures) {
      if (picture.isDrawn &&
          frame >= picture.startFrame &&
          frame <= picture.endFrame) {
        return picture;
      }
    }
    return null;
  }
}

/// The first cut's schedule (FR-026): the chosen pictures share the plan's
/// **sentences** equally, in the order chosen, and each picture's range is the
/// run of frames those sentences occupy.
///
/// A picture's run begins at its first sentence's own first frame and ends
/// immediately before the next picture's first sentence — never inside a
/// sentence, which is the reader's own rule (FR-026). Nothing is lost by that:
/// a sentence's run already carries the gap that follows it (D14), and the
/// video's last sentence carries the end hold, so the pictures cover the whole
/// spoken part and the video never falls back to the plain background between
/// two pictures or at its end. The frames before the first sentence — the title
/// card — stay plain: it is the app's own card, not a sentence (FR-008).
///
/// Two consequences worth knowing before reading the numbers: equal **sentences**
/// are not equal **frames** (a share holding the end hold is the longest), and a
/// length that does not divide gives the extra sentences to the earlier pictures.
/// More pictures than sentences leaves the extras undrawn rather than dropping a
/// sentence. Moving a picture's start or end frame is the reader's later
/// good-to-have — expressed as *which sentence* a picture starts at, since raw
/// frames would let the move land inside a sentence — and it renders again.
///
/// [VideoSlot.endFrame] is exclusive (`startFrame + frames`), while a picture's
/// range is inclusive as FR-026 states it, so every boundary here is written as
/// "the next sentence's start minus one".
PictureSchedule buildPictureSchedule({
  required VideoPlan plan,
  required List<String> paths,
}) {
  final sentences = plan.sentences;
  if (paths.isEmpty || sentences.isEmpty || plan.totalFrames <= 0) {
    return PictureSchedule.none;
  }
  final each = sentences.length ~/ paths.length;
  final extra = sentences.length % paths.length;
  final pictures = <ScheduledPicture>[];
  var first = 0;
  for (var i = 0; i < paths.length; i++) {
    final held = each + (i < extra ? 1 : 0);
    final startFrame = first < sentences.length
        ? sentences[first].startFrame
        : plan.totalFrames;
    final int endFrame;
    if (held == 0) {
      // No sentence reached this picture: it is not drawn at all (FR-026).
      endFrame = startFrame - 1;
    } else if (first + held < sentences.length) {
      endFrame = sentences[first + held].startFrame - 1;
    } else {
      // The last picture holds to the video's last frame: the end hold keeps
      // the sentence just heard (FR-008), and the picture behind it with it.
      endFrame = plan.totalFrames - 1;
    }
    pictures.add(
      ScheduledPicture(
        path: paths[i],
        startFrame: startFrame,
        endFrame: endFrame,
      ),
    );
    first += held;
  }
  return PictureSchedule(pictures);
}

/// Copies every pick's stored file into [workDir] and returns the copies' paths,
/// in the order chosen (D15, D18).
///
/// This is the whole reason the seam can promise as little as it does: a pick
/// only has to be readable the moment it is chosen, and after this call what the
/// render reads is an ordinary file of its own — a copy of the app's own stored
/// one, so the render's "delete what I wrote" takes the copies and the stored
/// picks are the page's to remove. Every copy is written **inside
/// [workDir] and nowhere else**, so the render's own "delete what I wrote"
/// covers them whatever the ending — finished, cancelled or failed (FR-009's
/// rule, extended to the picks).
///
/// A pick that cannot be read fails the whole call and deletes what it already
/// wrote: a video with a hole in it is worse than a failed render (US4's own
/// rule).
Future<List<String>> copyPictures({
  required List<HeldPicture> pictures,
  required Directory workDir,
}) async {
  final written = <String>[];
  try {
    for (var i = 0; i < pictures.length; i++) {
      final path =
          '${workDir.path}${Platform.pathSeparator}picture_${i}_${_safeName(pictures[i].name)}';
      await File(pictures[i].path).copy(path);
      written.add(path);
    }
    return written;
  } catch (_) {
    for (final path in written) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone, or never readable: nothing left to clean.
      }
    }
    rethrow;
  }
}

/// The pick's own name with every directory part removed.
///
/// The name crosses a platform boundary, so it is treated as data: a copy has to
/// stay inside the working directory whatever the platform called the file, or
/// it would outlive the render that wrote it.
String _safeName(String name) {
  final parts = name
      .split(RegExp(r'[/\\]'))
      .where((part) => part.isNotEmpty && part != '.')
      .toList();
  final base = parts.isEmpty ? '' : parts.last;
  return base.isEmpty ? 'picture' : base;
}
