// Spike S4's harness (2026-09-27): the stills and the numbers in
// breakpoint.md row 42 come from this file, kept beside S1's probe so the
// measurement can be repeated. Run it from the project root:
//
//   flutter test specs/012-reading-video/scripts/probe_scrim_stills.dart
//
// It writes the stills and measurements.tsv to the directory named in
// [outDir] below and prints the table. It is NOT part of the suite: it lives
// outside test/ on purpose.
//
// Renders the four candidate veils over the reader's own pictures with the
// app's REAL frame geometry and the app's REAL text style, writes the stills as
// PNGs, and measures WCAG contrast over the glyph pixels themselves.
//
// Geometry and style are lifted from lib/video_painter.dart (reference column
// 360, max column 88 % of the width, ±10 % margin, text at the reader's size ×
// the frame's scale) and from the theme lib/main.dart builds (one light theme,
// text #161D1C, background #F4FBF8).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String mediaDir = '/home/weihongzhang/Documents/GitHub/Multi-Media/归真/';
const String outDir = '/home/weihongzhang/.hermes/cache/scratch/klhu_scrim';

const Color textDark = Color(0xFF161D1C); // _contentTextStyle().color
const Color frameBg = Color(0xFFF4FBF8); // scaffoldBackgroundColor

const String sentenceEn =
    'He stood on the hillside and watched the sky go dark, one colour at a time.';
const String sentenceZh = '夕阳把山坡照得通红，他站在山顶上，看着远处慢慢暗下去的天空。';

class Shot {
  const Shot(this.name, this.file);
  final String name;
  final String file;
}

class Variant {
  const Variant(this.name, this.veil, this.opacity, this.text);
  final String name;
  final Color veil;
  final double opacity;
  final Color text;
}

const shots = <Shot>[
  Shot('02_发现银光虫', '${mediaDir}1/02_发现银光虫.png'),
  Shot('05_夕阳山坡', '${mediaDir}1/05_夕阳山坡.png'),
  Shot('scene_08', '${mediaDir}1/images_gen/scene_08.png'),
  Shot('10_04', '${mediaDir}10/10_04.jpg'),
  Shot('gradient', ''), // synthetic 0..255 ramp, the Python table's cross-check
  Shot('plain', ''), // no picture, no veil: the frame the app ships today
];

const variants = <Variant>[
  Variant('A-40black', Color(0xFF000000), 0.40, textDark),
  Variant('E-45lightveil', frameBg, 0.45, textDark),
  Variant('E-50lightveil', frameBg, 0.50, textDark),
  Variant('C-55lightveil', frameBg, 0.55, textDark),
  Variant('F-60lightveil', frameBg, 0.60, textDark),
  Variant('D-61black-lighttext', Color(0xFF000000), 0.61, frameBg),
];

double srgbToLin(double v) {
  final c = v / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relLum(double r, double g, double b) =>
    0.2126 * srgbToLin(r) + 0.7152 * srgbToLin(g) + 0.0722 * srgbToLin(b);

double ratio(double a, double b) {
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

Future<ui.Image> load(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> ramp(int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  for (var i = 0; i < 256; i++) {
    c.drawRect(
      Rect.fromLTWH(i * w / 256, 0, w / 256 + 1, h.toDouble()),
      Paint()..color = Color.fromARGB(255, i, i, i),
    );
  }
  final pic = rec.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  return img;
}

/// The text block, laid out exactly as `VideoPainter` lays a paragraph out.
TextPainter layout(Size frame, double fontSize, Color colour) {
  final columnWidth = math.min(frame.width * 0.88, frame.height);
  final style = TextStyle(color: colour, fontSize: fontSize, height: 1.0);
  final painter = TextPainter(
    text: TextSpan(
      children: [
        TextSpan(text: '$sentenceEn\n', style: style),
        TextSpan(text: sentenceZh, style: style),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: columnWidth);
  return painter;
}

Future<Uint8List> rgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

void main() {
  test('scrim stills', () async {
    Directory(outDir).createSync(recursive: true);
    final rows = <String>[];
    final aspects = <String, Size>{
      '16x9': const Size(1920, 1080),
      '9x16': const Size(1080, 1920),
    };

    for (final aspect in aspects.entries) {
      final frame = aspect.value;
      final columnWidth = math.min(frame.width * 0.88, frame.height);
      final scale = columnWidth / 360.0;
      final fontSize = 14.0 * scale;
      final marginY = frame.height * 0.10;
      final marginX = (frame.width - columnWidth) / 2;

      for (final shot in shots) {
        final shippedFrame = shot.name == 'plain';
        final picture = shippedFrame
            ? null
            : (shot.file.isEmpty
                ? await ramp(frame.width.toInt(), frame.height.toInt())
                : await load(shot.file));

        for (final v in variants) {
          TextPainter textFor(Color c) => layout(frame, fontSize, c);

          // 1. the frame: picture (cover) -> veil -> text
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, frame.width, frame.height),
            Paint()..color = frameBg,
          );
          if (picture != null) {
            // cover fit: centre-crop the picture to the frame's aspect
            final iw = picture.width.toDouble(), ih = picture.height.toDouble();
            final s = math.max(frame.width / iw, frame.height / ih);
            final sw = frame.width / s, sh = frame.height / s;
            canvas.drawImageRect(
              picture,
              Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh),
              Rect.fromLTWH(0, 0, frame.width, frame.height),
              Paint()..filterQuality = FilterQuality.high,
            );
            canvas.drawRect(
              Rect.fromLTWH(0, 0, frame.width, frame.height),
              Paint()..color = v.veil.withValues(alpha: v.opacity),
            );
          }
          final body = textFor(v.text);
          body.paint(canvas, Offset(marginX, marginY));
          final composed = rec.endRecording();
          final image = await composed.toImage(frame.width.toInt(), frame.height.toInt());
          composed.dispose();

          // 2. the glyph mask, same position and style, white on transparent
          final mrec = ui.PictureRecorder();
          final mcanvas = Canvas(mrec);
          textFor(const Color(0xFFFFFFFF)).paint(mcanvas, Offset(marginX, marginY));
          final mpic = mrec.endRecording();
          final mask = await mpic.toImage(frame.width.toInt(), frame.height.toInt());
          mpic.dispose();

          // 3. the plate: the same picture and veil with NO text on it. The
          //    contrast SC-004 asks about is the text against what is behind
          //    it, so the pixels to measure are the plate's, at the glyphs'
          //    positions — the composite's own pixels ARE the text colour,
          //    and measuring those would report 1.00:1 everywhere.
          final prec = ui.PictureRecorder();
          final pcanvas = Canvas(prec);
          pcanvas.drawRect(
            Rect.fromLTWH(0, 0, frame.width, frame.height),
            Paint()..color = frameBg,
          );
          if (picture != null) {
            final iw2 = picture.width.toDouble(), ih2 = picture.height.toDouble();
            final s2 = math.max(frame.width / iw2, frame.height / ih2);
            final sw2 = frame.width / s2, sh2 = frame.height / s2;
            pcanvas.drawImageRect(
              picture,
              Rect.fromLTWH((iw2 - sw2) / 2, (ih2 - sh2) / 2, sw2, sh2),
              Rect.fromLTWH(0, 0, frame.width, frame.height),
              Paint()..filterQuality = FilterQuality.high,
            );
            pcanvas.drawRect(
              Rect.fromLTWH(0, 0, frame.width, frame.height),
              Paint()..color = v.veil.withValues(alpha: v.opacity),
            );
          }
          final ppic = prec.endRecording();
          final plate = await ppic.toImage(frame.width.toInt(), frame.height.toInt());
          ppic.dispose();

          final px = await rgba(plate);
          final mx = await rgba(mask);
          final textLum = relLum(v.text.r * 255, v.text.g * 255, v.text.b * 255);

          var glyphs = 0, below = 0, belowBox = 0, box = 0;
          var minC = double.infinity, minBox = double.infinity;
          final ratios = <double>[];
          final w = frame.width.toInt();
          for (var y = 0; y < frame.height.toInt(); y++) {
            for (var x = 0; x < w; x++) {
              final i = (y * w + x) * 4;
              final c = ratio(
                textLum,
                relLum(px[i].toDouble(), px[i + 1].toDouble(), px[i + 2].toDouble()),
              );
              final inBox = x >= marginX - 1 &&
                  x <= marginX + columnWidth + 1 &&
                  y >= marginY - 1 &&
                  y <= marginY + body.height + 1;
              if (inBox) {
                box++;
                if (c < 4.5) belowBox++;
                if (c < minBox) minBox = c;
              }
              if (mx[i + 3] >= 128) {
                glyphs++;
                ratios.add(c);
                if (c < 4.5) below++;
                if (c < minC) minC = c;
              }
            }
          }
          ratios.sort();
          final p5 = ratios.isEmpty ? 0.0 : ratios[(ratios.length * 0.05).floor()];

          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final outName =
              '${aspect.key}_${shot.name}_${v.name}.png';
          File('$outDir/$outName').writeAsBytesSync(png!.buffer.asUint8List());

          rows.add('${aspect.key}\t${shot.name}\t${v.name}\t${(fontSize).toStringAsFixed(1)}\t'
              'glyphs=$glyphs\tmin=${minC.isFinite ? minC.toStringAsFixed(2) : "-"}\t'
              'p5=${p5.toStringAsFixed(2)}\tbelow4.5=${glyphs == 0 ? "-" : (100 * below / glyphs).toStringAsFixed(2)}%\t'
              'box_min=${minBox.isFinite ? minBox.toStringAsFixed(2) : "-"}\t'
              'box_below=${box == 0 ? "-" : (100 * belowBox / box).toStringAsFixed(2)}%');

          image.dispose();
          plate.dispose();
          mask.dispose();
        }
      }
    }
    File('$outDir/measurements.tsv').writeAsStringSync(
      'aspect\tshot\tvariant\tfont_px\tglyph_pixels\tmin_contrast\tp5\tbelow_4.5\ttext_box_min\ttext_box_below\n'
      '${rows.join('\n')}\n',
    );
    // ignore: avoid_print
    print('OUTDIR $outDir');
    for (final r in rows) {
      // ignore: avoid_print
      print(r);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
