// Renders the brand PNGs in assets/brand/ from GradualMarkPainter.
//
// Run from the project root, then regenerate icons and splash:
//   flutter test tool/brand/render_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/theme/app_colors.dart';
import 'package:gradual/shared/widgets/gradual_mark.dart';

typedef _Draw = void Function(Canvas canvas, Size size);

Future<void> _write(String name, int px, _Draw draw, {String dir = 'assets/brand'}) async {
  final recorder = ui.PictureRecorder();
  final size = Size(px.toDouble(), px.toDouble());
  draw(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$dir/$name');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _gradient(Canvas canvas, Size size) {
  canvas.drawRect(Offset.zero & size, Paint()..shader = gradualIconGradient.createShader(Offset.zero & size));
}

/// Draws the mark centred, filling [fraction] of the canvas width.
void _mark(Canvas canvas, Size size, double fraction, Color color) {
  final side = size.width * fraction;
  canvas.save();
  canvas.translate((size.width - side) / 2, (size.height - side) / 2);
  GradualMarkPainter(color: color).paint(canvas, Size.square(side));
  canvas.restore();
}

void main() {
  test('render brand assets', () async {
    const white = Color(0xFFFFFFFF);

    // Full-bleed icon for legacy launchers, iOS and web.
    await _write('icon.png', 1024, (c, s) {
      _gradient(c, s);
      _mark(c, s, 0.6, white);
    });

    // Android adaptive icon layers. flutter_launcher_icons insets the
    // foreground by 16% and launchers show the inner 66%, so the mark is
    // drawn larger here to match the full-bleed icon.
    await _write('icon_background.png', 1024, _gradient);
    await _write('icon_foreground.png', 1024, (c, s) => _mark(c, s, 0.55, white));
    await _write('icon_monochrome.png', 1024, (c, s) => _mark(c, s, 0.55, white));

    // Splash marks. Android 12+ crops the splash icon to a circle, so its
    // image keeps the mark inside the centre two thirds.
    await _write('splash_light.png', 1152, (c, s) => _mark(c, s, 0.32, white));
    await _write('splash_dark.png', 1152, (c, s) => _mark(c, s, 0.32, AppColors.dark.brand));
    await _write('splash_android12_light.png', 960, (c, s) => _mark(c, s, 0.42, white));
    await _write('splash_android12_dark.png', 960, (c, s) => _mark(c, s, 0.42, AppColors.dark.brand));

    // Android status-bar icon for reminders: white on transparent, and the
    // system tints it. 24dp at each density.
    const densities = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96};
    for (final entry in densities.entries) {
      await _write(
        'ic_stat_gradual.png',
        entry.value,
        (c, s) => _mark(c, s, 0.92, white),
        dir: 'android/app/src/main/res/drawable-${entry.key}',
      );
    }

    // Large picture on the reminder: the full app icon. Android crops it to a
    // circle, so the mark stays well inside.
    await _write(
      'ic_reminder_large.png',
      256,
      (c, s) {
        _gradient(c, s);
        _mark(c, s, 0.5, white);
      },
      dir: 'android/app/src/main/res/drawable-nodpi',
    );
  });
}
