import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../perspective/penalty_area_perspective.dart';

/// Visual layout bands (screen fractions). Game layout constants unchanged.
abstract final class StadiumVisualLayout {
  static const double cameraBandTop = 0.32;
  static const double cameraBandBottom = 0.445;
  /// Upper stadium (sky + stands) — covers former camera window too.
  static const double upperStadiumHeight = 0.445;
  static const double pitchBandTop = 0.445;
  static const double pitchBandHeight = 0.555;
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

/// Cached pitch grass and perspective penalty-area markings.
class StadiumPitchPainter extends CustomPainter {
  StadiumPitchPainter({
    required this.size,
    required this.fullScreenWidth,
    required this.fullScreenHeight,
    required this.ballSpawnX,
    required this.ballSpawnY,
    required this.goalRect,
    required this.goalBottomY,
    required this.isFreeKick,
  });

  final Size size;
  final double fullScreenWidth;
  final double fullScreenHeight;
  final double ballSpawnX;
  final double ballSpawnY;
  final Rect goalRect;
  final double goalBottomY;
  final bool isFreeKick;

  static const Color _grassBase = Color(0xFF2d5a1b);
  static const Color _grassLight = Color(0xFF336b20);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = size.width;
    final h = size.height;
    final topOffset = fullScreenHeight * StadiumVisualLayout.pitchBandTop;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _grassBase,
    );

    _drawMowingBands(canvas, w, h, topOffset);
    _drawPerspectiveMarkings(canvas, w, h, topOffset);
  }

  void _drawMowingBands(Canvas canvas, double w, double h, double topOffset) {
    final goalLineLocalY = goalRect.bottom - topOffset;
    final bottomY = h;
    const bandCount = 6;
    final totalH = bottomY - goalLineLocalY;
    if (totalH <= 0) return;

    final bandH = totalH / bandCount;
    for (var i = 0; i < bandCount; i++) {
      if (i.isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(0, goalLineLocalY + i * bandH, w, bandH),
        Paint()..color = _grassLight.withValues(alpha: 0.35),
      );
    }
  }

  void _drawPerspectiveMarkings(Canvas canvas, double w, double h, double topOffset) {
    final persp = PenaltyAreaPerspective(
      screenSize: Size(fullScreenWidth, fullScreenHeight),
      goalRect: goalRect,
      goalBottomY: goalBottomY,
      ballSpawnY: ballSpawnY,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final faintLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    Offset local(Offset screen) => Offset(screen.dx, screen.dy - topOffset);

    // Goal line
    final glL = local(persp.leftAtDepth(PenaltyAreaPerspective.goalLineDepth));
    final glR = local(persp.rightAtDepth(PenaltyAreaPerspective.goalLineDepth));
    canvas.drawLine(glL, glR, linePaint);

    // 6-yard box
    const sixD = PenaltyAreaPerspective.sixYardDepth;
    final sixHW = persp.sixYardHalfWidth(sixD);
    final sixY = persp.yAtDepth(sixD) - topOffset;
    final vpx = persp.vanishingPoint.dx;

    final sixTL = Offset(vpx - persp.sixYardHalfWidth(0), glL.dy);
    final sixTR = Offset(vpx + persp.sixYardHalfWidth(0), glR.dy);
    final sixBL = Offset(vpx - sixHW, sixY);
    final sixBR = Offset(vpx + sixHW, sixY);

    canvas.drawLine(sixTL, sixBL, linePaint);
    canvas.drawLine(sixTR, sixBR, linePaint);
    canvas.drawLine(sixBL, sixBR, linePaint);

    // 18-yard box
    const eighteenD = PenaltyAreaPerspective.eighteenYardDepth;
    final eighteenL = local(persp.leftAtDepth(eighteenD));
    final eighteenR = local(persp.rightAtDepth(eighteenD));

    final outerPaint = isFreeKick ? linePaint : faintLinePaint;
    canvas.drawLine(glL, eighteenL, outerPaint);
    canvas.drawLine(glR, eighteenR, outerPaint);
    canvas.drawLine(eighteenL, eighteenR, outerPaint);

    // Penalty arc (outside the 18-yard line, toward the ball)
    final arcPath = persp.arcAtDepth(eighteenD, 0.18);
    final localArcPath = arcPath.shift(Offset(0, -topOffset));
    canvas.drawPath(localArcPath, isFreeKick ? linePaint : faintLinePaint);

    // Penalty spot (penalty mode only)
    if (!isFreeKick) {
      const spotD = PenaltyAreaPerspective.penaltySpotDepth;
      final spotScreen = persp.project(0, spotD);
      canvas.drawCircle(
        local(spotScreen),
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StadiumPitchPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.ballSpawnX != ballSpawnX ||
      oldDelegate.ballSpawnY != ballSpawnY ||
      oldDelegate.goalRect != goalRect ||
      oldDelegate.goalBottomY != goalBottomY ||
      oldDelegate.isFreeKick != isFreeKick;
}

/// Records a static [ui.Picture] for a painter that never animates.
ui.Picture recordStaticPicture(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder.endRecording();
}
