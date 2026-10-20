import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

/// Draws a score picture (1080 x 1350) and returns it as PNG bytes.
/// Everything is drawn here on the phone, nothing is downloaded.
Future<Uint8List> renderShareCard({
  required Pow2Palette palette,
  required int score,
  required int tile,
  required String modeLabel,
}) async {
  const width = 1080.0;
  const height = 1350.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = palette.background,
  );

  _text(
    canvas,
    TextSpan(
      text: 'Pow',
      style: TextStyle(
        fontSize: 120,
        fontWeight: FontWeight.w800,
        color: palette.text,
      ),
      children: [TextSpan(text: '2', style: TextStyle(color: palette.accentText))],
    ),
    const Offset(width / 2, 150),
  );

  final style = palette.tileStyle(tile);
  const tileSize = 520.0;
  final tileRect = Rect.fromCenter(
    center: const Offset(width / 2, 560),
    width: tileSize,
    height: tileSize,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(tileRect, const Radius.circular(80)),
    Paint()..color = style.background,
  );
  final digits = '$tile'.length;
  final tileFont = digits <= 2 ? 240.0 : digits == 3 ? 200.0 : digits == 4 ? 160.0 : 120.0;
  _text(
    canvas,
    TextSpan(
      text: '$tile',
      style: TextStyle(
        fontSize: tileFont,
        fontWeight: FontWeight.w800,
        color: style.foreground,
      ),
    ),
    tileRect.center,
  );

  _text(
    canvas,
    TextSpan(
      text: 'SCORE',
      style: TextStyle(
        fontSize: 38,
        letterSpacing: 4,
        fontWeight: FontWeight.w700,
        color: palette.mutedText,
      ),
    ),
    const Offset(width / 2, 950),
  );
  _text(
    canvas,
    TextSpan(
      text: formatNumber(score),
      style: TextStyle(
        fontSize: 130,
        fontWeight: FontWeight.w800,
        color: palette.text,
      ),
    ),
    const Offset(width / 2, 1040),
  );
  _text(
    canvas,
    TextSpan(
      text: modeLabel,
      style: TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        color: palette.accentText,
      ),
    ),
    const Offset(width / 2, 1150),
  );
  _text(
    canvas,
    TextSpan(
      text: 'Offline · No ads · github.com/lumio-apps/pow2',
      style: TextStyle(fontSize: 32, color: palette.mutedText),
    ),
    const Offset(width / 2, 1270),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Could not draw the picture');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void _text(Canvas canvas, TextSpan span, Offset center) {
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
    ..layout(maxWidth: 1000);
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}
