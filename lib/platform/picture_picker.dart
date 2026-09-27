/// The reader's own pictures, chosen from their files (spec 012 US4, decision
/// D15, FR-025).
///
/// The platform's own **file** dialog rather than the photo picker: the
/// reader's images are files — made on the phone, on a PC, or by an AI tool —
/// so the dialog that browses files is the one that finds them, and it is the
/// one selection UI every target the app builds for has (Android, iOS, Linux,
/// macOS, web, Windows), with folders to browse on each. The reader's decision
/// on 2026-09-27 chose this over the photo picker for exactly that reason.
///
/// What this seam promises is small on purpose. The render copies every pick
/// into its own working directory before it writes a frame (D15, FR-009), so
/// nothing downstream needs to know what a pick *was* — a content uri, a web
/// blob, a desktop path — or how long the picker's read grant lives. A
/// [PickedPicture] is a name and a way to read the bytes once.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// One chosen picture: what it is called, and how to read it.
class PickedPicture {
  const PickedPicture({required this.name, required this.read});

  /// The file's own name, with any directory stripped (`sunset.png`) — what
  /// the copy into the working directory is called.
  final String name;

  /// The picture's bytes.
  ///
  /// Read once, straight after choosing, while the picker's own read grant is
  /// alive; the caller copies the bytes and does not keep this handle (D15).
  final Future<Uint8List> Function() read;
}

/// Chooses pictures from the reader's files.
abstract class PicturePicker {
  /// The pictures the reader chose, in the order they chose them. Empty when
  /// the reader cancelled; throws when the picker itself failed, which the page
  /// reports rather than swallowing (FR-025's failure message).
  Future<List<PickedPicture>> pick();
}

/// The platform's own file dialog, through `file_selector` — flutter.dev's
/// plugin, so there is no platform half of ours and no new permission.
class FilePicturePicker implements PicturePicker {
  const FilePicturePicker();

  /// The kinds of file the dialog offers, built for the platform asking: the
  /// plugin rejects a type group whose filters its platform cannot honour
  /// (`extensions` is not an iOS filter, `mimeTypes` is not a Windows one), and
  /// the images the reader may want include what an AI tool wrote — png, jpg,
  /// webp, and whatever the next tool exports.
  static XTypeGroup imageTypes(TargetPlatform platform) {
    const List<String> extensions = <String>[
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
    ];
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const XTypeGroup(
          label: 'images',
          uniformTypeIdentifiers: <String>['public.image'],
        );
      case TargetPlatform.windows:
        return const XTypeGroup(label: 'images', extensions: extensions);
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const XTypeGroup(
          label: 'images',
          extensions: extensions,
          mimeTypes: <String>['image/*'],
        );
    }
  }

  @override
  Future<List<PickedPicture>> pick() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[
        imageTypes(defaultTargetPlatform),
      ],
    );
    return <PickedPicture>[
      for (final XFile file in files)
        PickedPicture(name: file.name, read: file.readAsBytes),
    ];
  }
}
