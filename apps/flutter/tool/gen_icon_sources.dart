// One-off helper: builds the app-icon source PNGs from the Figma export.
//   app_icon.png            — full-bleed 1024² opaque square (iOS + Android legacy)
//   adaptive_foreground.png — 1024² transparent, artwork inset to the adaptive safe zone
// Run: dart run tool/gen_icon_sources.dart <figma_export.png>
import 'dart:io';
import 'package:image/image.dart' as img;

// Brand background gradient (see docs/ui-mockups/README.md)
const topLeft = [0x0B, 0x13, 0x2B]; // #0B132B
const bottomRight = [0x1C, 0x25, 0x41]; // #1C2541

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void main(List<String> args) {
  final srcPath = args.isNotEmpty ? args[0] : 'tool/icon_src.png';
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  const size = 1024;

  // 1) Full-bleed square for iOS / Android legacy: diagonal gradient fills the
  //    rounded corners the Figma frame leaves transparent.
  final full = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * (size - 1));
      full.setPixelRgba(
        x,
        y,
        _lerp(topLeft[0], bottomRight[0], t),
        _lerp(topLeft[1], bottomRight[1], t),
        _lerp(topLeft[2], bottomRight[2], t),
        255,
      );
    }
  }
  final artFull = img.copyResize(src,
      width: size, height: size, interpolation: img.Interpolation.cubic);
  img.compositeImage(full, artFull);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // 1b) Gradient-only background for the adaptive icon (no artwork), so the
  //     foreground's own gradient blends seamlessly instead of butting against
  //     a flat fill.
  final bg = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * (size - 1));
      bg.setPixelRgba(
        x,
        y,
        _lerp(topLeft[0], bottomRight[0], t),
        _lerp(topLeft[1], bottomRight[1], t),
        _lerp(topLeft[2], bottomRight[2], t),
        255,
      );
    }
  }
  File('assets/icon/adaptive_background.png').writeAsBytesSync(img.encodePng(bg));

  // 2) Adaptive foreground: inset artwork to ~72% so nothing clips under the
  //    circular/squircle mask; background color is supplied via config.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  const inset = 0.72;
  final artSize = (size * inset).round();
  final artFg = img.copyResize(src,
      width: artSize, height: artSize, interpolation: img.Interpolation.cubic);
  final offset = ((size - artSize) / 2).round();
  img.compositeImage(fg, artFg, dstX: offset, dstY: offset);
  File('assets/icon/adaptive_foreground.png')
      .writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/app_icon.png and adaptive_foreground.png');
}
