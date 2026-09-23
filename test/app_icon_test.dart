/// Contract test for the generated launcher icons (spec 009,
/// `specs/009-app-icon/`).
///
/// These assert relationships between the icon CONFIGURATION
/// (`pubspec.yaml` → `flutter_launcher_icons:`) and the artifacts it produces:
/// each density's declared pixel size, the adaptive descriptor's wiring, and the
/// iOS catalogue's internal consistency. They are not snapshots of the art — a
/// new source image regenerates every file without touching this test.
///
/// PNG dimensions and colour type are read straight from the IHDR bytes and the
/// JPEG's from its SOF marker, so no image-decoding dependency is added
/// (tasks.md T002).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _androidRes = 'android/app/src/main/res';
const _iosSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _source = 'images/kalahoo.jpeg';

/// Density → the legacy icon's pixel size (the generator's own table).
const _legacySizes = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// The adaptive layers are 108 dp, so their pixels scale with the density
/// (the generator's own table, `flutter_launcher_icons/lib/android.dart:21-27`).
const _adaptiveSizes = <String, int>{
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// PNG colour type 2 = RGB with no alpha channel.
const _rgbNoAlpha = 2;

({int width, int height, int colorType}) _png(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 26 ||
      bytes[0] != 0x89 ||
      String.fromCharCodes(bytes.sublist(1, 4)) != 'PNG') {
    throw StateError('not a PNG: $path');
  }
  int be32(int at) =>
      (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3];
  return (
    width: be32(16),
    height: be32(20),
    colorType: bytes[25],
  );
}

({int width, int height}) _jpegSize(String path) {
  final b = File(path).readAsBytesSync();
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) {
    throw StateError('not a JPEG: $path');
  }
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    // Standalone markers carry no length field.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    final length = (b[i + 2] << 8) | b[i + 3];
    final isStartOfFrame = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 && // DHT
        marker != 0xC8 && // JPG
        marker != 0xCC; // DAC
    if (isStartOfFrame) {
      return (
        height: (b[i + 5] << 8) | b[i + 6],
        width: (b[i + 7] << 8) | b[i + 8],
      );
    }
    i += 2 + length;
  }
  throw StateError('no start-of-frame marker in $path');
}

void main() {
  group('icon source (FR-001, I1)', () {
    test('the source exists, is square and large enough to scale down', () {
      final file = File(_source);
      expect(file.existsSync(), isTrue, reason: '$_source is the icon source');
      final size = _jpegSize(_source);
      expect(size.width, size.height,
          reason: 'a non-square source would be stretched into every icon');
      expect(size.width, greaterThanOrEqualTo(1024));
    });

    test('the source is not shipped as a Flutter asset (D4)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assets = pubspec.split('\nflutter:').last;
      expect(assets, isNot(contains('kalahoo.jpeg')),
          reason: 'the app never renders the source; bundling it is dead weight');
    });
  });

  group('Android legacy icons (FR-002, FR-004, I4)', () {
    for (final entry in _legacySizes.entries) {
      test('${entry.key} is ${entry.value}px', () {
        final path = '$_androidRes/mipmap-${entry.key}/ic_launcher.png';
        expect(File(path).existsSync(), isTrue, reason: path);
        final png = _png(path);
        expect(png.width, entry.value, reason: path);
        expect(png.height, entry.value, reason: path);
      });
    }
  });

  group('Android adaptive icon (FR-004, D3, C1–C5)', () {
    for (final entry in _adaptiveSizes.entries) {
      test('${entry.key} foreground layer is ${entry.value}px', () {
        final path = '$_androidRes/drawable-${entry.key}/ic_launcher_foreground.png';
        expect(File(path).existsSync(), isTrue, reason: path);
        final png = _png(path);
        expect(png.width, entry.value, reason: path);
        expect(png.height, entry.value, reason: path);
      });
    }

    test('the adaptive descriptor wires colour background + inset foreground', () {
      final xml = File('$_androidRes/mipmap-anydpi-v26/ic_launcher.xml');
      expect(xml.existsSync(), isTrue, reason: xml.path);
      final text = xml.readAsStringSync();
      expect(text, contains('<adaptive-icon'));
      expect(text, contains('@color/ic_launcher_background'));
      expect(text, contains('@drawable/ic_launcher_foreground'));
      expect(text, contains('android:inset="16%'),
          reason: 'the inset is what keeps the art inside the 72dp safe disc');
    });

    test('a colour background means no background PNG (C5)', () {
      for (final density in _legacySizes.keys) {
        final path = '$_androidRes/drawable-$density/ic_launcher_background.png';
        expect(File(path).existsSync(), isFalse,
            reason: 'colour and PNG backgrounds are mutually exclusive');
      }
    });

    test('colors.xml declares the configured background colour', () {
      final colors = File('$_androidRes/values/colors.xml');
      expect(colors.existsSync(), isTrue, reason: colors.path);
      final text = colors.readAsStringSync();
      expect(
        text,
        matches(RegExp(
            r'<color\s+name="ic_launcher_background"\s*>\s*#ffffff\s*</color>',
            caseSensitive: false)),
      );
    });
  });

  group('iOS icon set (FR-003, FR-004, C8–C10)', () {
    late List<Map<String, Object?>> entries;

    setUpAll(() {
      final contents = File('$_iosSet/Contents.json');
      expect(contents.existsSync(), isTrue, reason: contents.path);
      entries = ((json.decode(contents.readAsStringSync())
              as Map<String, Object?>)['images'] as List)
          .cast<Map<String, Object?>>();
    });

    test('every catalogue filename exists at size × scale, without alpha', () {
      final byName = <String, int>{};
      for (final e in entries) {
        final name = e['filename'] as String?;
        if (name == null) continue; // an unassigned slot in the catalogue
        final path = '$_iosSet/$name';
        expect(File(path).existsSync(), isTrue, reason: 'catalogue lists $name');
        final side = double.parse((e['size'] as String).split('x').first);
        final scale = int.parse((e['scale'] as String).replaceAll('x', ''));
        final expected = (side * scale).round();
        final png = _png(path);
        expect(png.width, expected, reason: '$name (${e['size']}@${e['scale']})');
        expect(png.height, expected, reason: name);
        expect(png.colorType, _rgbNoAlpha,
            reason: '$name must carry no alpha channel (App Store)');
        byName[name] = expected;
      }

      // The sizes a device and the App Store actually resolve must be there with
      // the right pixels — the catalogue the generator writes also carries the
      // legacy iPhone/iPad entries, so the set is asserted, not its length.
      const required = <String, int>{
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final e in required.entries) {
        expect(byName[e.key], e.value, reason: '${e.key} is required by iOS');
      }
    });
  });
}
