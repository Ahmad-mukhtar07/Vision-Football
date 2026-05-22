import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Visual layout bands (screen fractions). Game layout constants unchanged.
abstract final class StadiumVisualLayout {
  static const double cameraBandTop = 0.32;
  static const double cameraBandBottom = 0.62;
  /// Upper stadium (sky + stands) — covers former camera window too.
  static const double upperStadiumHeight = 0.62;
  static const double pitchBandTop = 0.62;
  static const double pitchBandHeight = 0.38;
}

/// Cached sky / stands scene for the upper band (replaces visible camera window).
class StadiumSkyPainter extends CustomPainter {
  StadiumSkyPainter({
    required this.size,
    required this.fullScreenHeight,
  });

  final Size size;
  final double fullScreenHeight;

  static const Color _navyTop = Color(0xFF0D1B2A);
  static const Color _horizonBlue = Color(0xFF1a3a5c);
  static const Color _pitchHorizon = Color(0xFF2a4a28);
  static const List<Color> _crowdColors = [
    Color(0xFF8B0000),
    Color(0xFF003366),
    Color(0xFF2d4a1e),
  ];

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = size.width;
    final h = size.height;

    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, h),
      [
        _navyTop,
        _horizonBlue,
        _horizonBlue.withValues(alpha: 0.95),
        _pitchHorizon,
      ],
      [0.0, 0.35, 0.72, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = gradient,
    );

    _drawMidStands(canvas, w, h);
    _drawCrowd(canvas, w, h);
    // Floodlights removed per design update
    _drawHorizonLine(canvas, w, h);
  }

  /// Deeper stands fill where the camera band used to show through the goal.
  void _drawMidStands(Canvas canvas, double w, double h) {
    final midTop = h * StadiumVisualLayout.cameraBandTop /
        StadiumVisualLayout.upperStadiumHeight;
    final midRect = Rect.fromLTWH(0, midTop, w, h - midTop);
    final midGrad = ui.Gradient.linear(
      Offset(0, midTop),
      Offset(0, h),
      [
        _horizonBlue.withValues(alpha: 0.0),
        const Color(0xFF152a45),
        const Color(0xFF1e3d32),
      ],
      [0.0, 0.45, 1.0],
    );
    canvas.drawRect(midRect, Paint()..shader = midGrad);

    final rng = Random(77);
    var y = midTop + h * 0.04;
    while (y < h * 0.92) {
      var x = 0.0;
      while (x < w) {
        final bw = 6 + rng.nextInt(14);
        final bh = 4 + rng.nextInt(8);
        canvas.drawRect(
          Rect.fromLTWH(x, y, bw.toDouble(), bh.toDouble()),
          Paint()
            ..color = _crowdColors[rng.nextInt(_crowdColors.length)]
                .withValues(alpha: 0.35 + rng.nextDouble() * 0.25),
        );
        x += bw + 3;
      }
      y += 10 + rng.nextInt(6);
    }
  }

  void _drawCrowd(Canvas canvas, double w, double h) {
    final rng = Random(42);
    const rowCount = 5;
    final rowHeight = h * 0.09;
    var y = h * 0.14;

    for (var row = 0; row < rowCount; row++) {
      var x = -w * 0.02 + row * 7.0;
      final color = _crowdColors[row % _crowdColors.length];
      while (x < w + 20) {
        final blockW = 8 + rng.nextDouble() * 22;
        final blockH = rowHeight * (0.55 + rng.nextDouble() * 0.55);
        final stagger = (row.isOdd ? 6.0 : 0.0) + rng.nextDouble() * 4;
        canvas.drawRect(
          Rect.fromLTWH(x + stagger, y - blockH, blockW, blockH),
          Paint()..color = color.withValues(alpha: 0.72 + rng.nextDouble() * 0.2),
        );
        x += blockW + 2 + rng.nextDouble() * 5;
      }
      y += rowHeight * 0.85;
    }
  }

  void _drawHorizonLine(Canvas canvas, double w, double h) {
    canvas.drawLine(
      Offset(0, h - 1),
      Offset(w, h - 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant StadiumSkyPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.fullScreenHeight != fullScreenHeight;
}

/// Cached pitch grass and penalty markings for the bottom band.
class StadiumPitchPainter extends CustomPainter {
  StadiumPitchPainter({
    required this.size,
    required this.fullScreenWidth,
    required this.fullScreenHeight,
    required this.ballSpawnX,
    required this.ballSpawnY,
    required this.goalRect,
  });

  final Size size;
  final double fullScreenWidth;
  final double fullScreenHeight;
  final double ballSpawnX;
  final double ballSpawnY;
  final Rect goalRect;

  static const Color _grassBase = Color(0xFF2d5a1b);
  static const Color _grassStripe = Color(0xFF336b20);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = size.width;
    final h = size.height;
    final topOffset = fullScreenHeight * StadiumVisualLayout.pitchBandTop;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _grassBase,
    );

    const stripeCount = 7;
    final stripeW = w / stripeCount;
    for (var i = 0; i < stripeCount; i++) {
      if (i.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTWH(i * stripeW, 0, stripeW, h),
        Paint()..color = _grassStripe,
      );
    }

    final localBallX = ballSpawnX;
    final localBallY = ballSpawnY - topOffset;
    final arcRadius = fullScreenHeight * 0.08;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(localBallX, localBallY),
        radius: arcRadius,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      Offset(localBallX, localBallY + 6),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    final boxW = fullScreenWidth * 0.70;
    final boxH = fullScreenHeight * 0.18;
    final boxLeft = (fullScreenWidth - boxW) * 0.5;
    final boxTop = goalRect.bottom + fullScreenHeight * 0.02 - topOffset;

    canvas.drawRect(
      Rect.fromLTWH(
        boxLeft,
        boxTop.clamp(0, h - boxH),
        boxW,
        boxH.clamp(8, h),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant StadiumPitchPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.ballSpawnX != ballSpawnX ||
      oldDelegate.ballSpawnY != ballSpawnY ||
      oldDelegate.goalRect != goalRect;
}

/// Records a static [ui.Picture] for a painter that never animates.
ui.Picture recordStaticPicture(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder.endRecording();
}
