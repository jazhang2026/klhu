/// The undecided working copy and its three decisions (spec 012 US3, FR-021,
/// FR-023).
///
/// A render produces a working copy in the app's own cache; this is what the
/// review offers to do with it. Keeping is the only path that writes into the
/// device's video library, and nothing here writes the record except through
/// [VideoRecordStore] (contract
/// `specs/012-reading-video/contracts/video-record-format.md`).
library;

import 'dart:io';

import 'package:klhu/platform/video_encoder.dart';
import 'package:klhu/video_record.dart';

class VideoReview {
  VideoReview({
    required this.workingPath,
    required this.contentKey,
    required this.displayName,
    required this.files,
    required this.records,
  });

  /// The working copy the render left behind: what is played and decided about.
  final String workingPath;

  /// The content this render was made from — the key the record is kept under.
  final String contentKey;

  /// What the library entry is called if the reader keeps it.
  final String displayName;

  /// The platform's file channel and the record's store: keeping goes through
  /// both, sharing and throwing away through the first alone.
  final VideoFileStore files;
  final VideoRecordStore records;

  /// Promote the working copy into the device's library and remember it
  /// (FR-011/FR-012), then let the working copy go: the kept file is the one
  /// that lives on.
  Future<KeptVideo> keep() async {
    final kept = await records.keep(
      contentKey,
      workingPath: workingPath,
      displayName: displayName,
    );
    await _discardWorkingCopy();
    return kept;
  }

  /// Hand the working copy to the platform's own share surface. Sharing is not
  /// keeping: nothing is written, and the reader may still decide either way
  /// afterwards (FR-023, A12).
  Future<void> share() => files.share(source: workingPath);

  /// Throw the render away: the working copy goes and nothing was ever written
  /// into the library (FR-021).
  Future<void> throwAway() => _discardWorkingCopy();

  Future<void> _discardWorkingCopy() async {
    final file = File(workingPath);
    // A platform that promoted the file by moving it has already taken it away.
    if (file.existsSync()) await file.delete();
  }
}
