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

/// Real-world geometry (metres).
const double _goalWidthM = 7.32;
const double _sixYardBoxWidthM = 18.32;
const double _sixYardDepthM = 5.5;
const double _eighteenYardBoxWidthM = 40.32;
const double _eighteenYardDepthM = 16.5;
const double _penaltySpotDepthM = 11.0;

/// xNorm values: goal half-width = 1.0
const double _sixYardXNorm = _sixYardBoxWidthM / 2 / (_goalWidthM / 2);
const double _eighteenXNorm = _eighteenYardBoxWidthM / 2 / (_goalWidthM / 2);

/// Max real-world depth visible for each mode.
const double _penaltyMaxDepthM = 13.0;
const double _freekickMaxDepthM = 22.0;

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
    required this.visualScale,
    required this.isFreeKick,
  });

  final Size size;
  final double fullScreenWidth;
  final double fullScreenHeight;
  final double ballSpawnX;
  final double ballSpawnY;
  final Rect goalRect;
  final double goalBottomY;
  final double visualScale;
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
    _drawPerspectiveMarkings(canvas, topOffset);
  }

  void _drawMowingBands(Canvas canvas, double w, double h, double topOffset) {
    final goalLineLocalY = goalBottomY - topOffset;
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

  void _drawPerspectiveMarkings(Canvas canvas, double topOffset) {
    final persp = PenaltyAreaPerspective(
      screenSize: Size(fullScreenWidth, fullScreenHeight),
      goalRect: goalRect,
      goalBottomY: goalBottomY,
      ballSpawnY: ballSpawnY,
      visualScale: visualScale,
    );

    Offset p(double x, double d) {
      final s = persp.project(x, d);
      return Offset(s.dx, s.dy - topOffset);
    }

    final brightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    if (isFreeKick) {
      _drawFreeKickMarkings(canvas, p, brightPaint, dimPaint, topOffset);
    } else {
      _drawPenaltyMarkings(canvas, p, brightPaint);
    }
  }

  /// Penalty mode: goal line edge-to-edge + 6-yard box. No spot, 18-yard, or arc.
  void _drawPenaltyMarkings(
    Canvas canvas,
    Offset Function(double x, double d) p,
    Paint linePaint,
  ) {
    const sixD = _sixYardDepthM / _penaltyMaxDepthM;

    // Goal line — extends to screen edges (large xNorm, canvas clips)
    canvas.drawLine(p(-20.0, 0), p(20.0, 0), linePaint);

    // 6-yard box sides
    canvas.drawLine(p(-_sixYardXNorm, 0), p(-_sixYardXNorm, sixD), linePaint);
    canvas.drawLine(p(_sixYardXNorm, 0), p(_sixYardXNorm, sixD), linePaint);

    // 6-yard box front
    canvas.drawLine(p(-_sixYardXNorm, sixD), p(_sixYardXNorm, sixD), linePaint);
  }

  /// Free kick mode: 18-yard + 6-yard + penalty arc through ball.
  void _drawFreeKickMarkings(
    Canvas canvas,
    Offset Function(double x, double d) p,
    Paint innerPaint,
    Paint outerPaint,
    double topOffset,
  ) {
    const sixD = _sixYardDepthM / _freekickMaxDepthM;
    const eighteenD = _eighteenYardDepthM / _freekickMaxDepthM;
    const spotD = _penaltySpotDepthM / _freekickMaxDepthM;

    // 18-yard box (outer, dimmer) — sides extend off-screen
    canvas.drawLine(p(-_eighteenXNorm, 0), p(_eighteenXNorm, 0), outerPaint);
    canvas.drawLine(p(-_eighteenXNorm, 0), p(-_eighteenXNorm, eighteenD), outerPaint);
    canvas.drawLine(p(_eighteenXNorm, 0), p(_eighteenXNorm, eighteenD), outerPaint);

    // Third horizontal line — full screen width (arc meets it at the edges)
    final eighteenY = p(0, eighteenD).dy;
    canvas.drawLine(
      Offset(0, eighteenY),
      Offset(fullScreenWidth, eighteenY),
      outerPaint,
    );

    // 6-yard box (inner, bright)
    canvas.drawLine(p(-_sixYardXNorm, 0), p(_sixYardXNorm, 0), innerPaint);
    canvas.drawLine(p(-_sixYardXNorm, 0), p(-_sixYardXNorm, sixD), innerPaint);
    canvas.drawLine(p(_sixYardXNorm, 0), p(_sixYardXNorm, sixD), innerPaint);
    canvas.drawLine(p(-_sixYardXNorm, sixD), p(_sixYardXNorm, sixD), innerPaint);

    // Penalty spot (11 m) — between 6-yard and 18-yard lines; ball is not here.
    canvas.drawCircle(
      p(0, spotD),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Penalty arc: ends off-screen, above the 18-yard line; apex through ball centre.
    final ballLocal = Offset(ballSpawnX, ballSpawnY - topOffset);
    const edgeOutset = 72.0;
    const endpointLiftPx = 10.0;

    final leftEnd = Offset(-edgeOutset, eighteenY - endpointLiftPx);
    final rightEnd = Offset(
      fullScreenWidth + edgeOutset,
      eighteenY - endpointLiftPx,
    );
    // Quadratic control so B(0.5) == ballLocal exactly.
    final control = Offset(
      2 * ballLocal.dx - 0.5 * leftEnd.dx - 0.5 * rightEnd.dx,
      2 * ballLocal.dy - 0.5 * leftEnd.dy - 0.5 * rightEnd.dy,
    );
    final arcPath = Path()
      ..moveTo(leftEnd.dx, leftEnd.dy)
      ..quadraticBezierTo(control.dx, control.dy, rightEnd.dx, rightEnd.dy);
    canvas.drawPath(arcPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant StadiumPitchPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.ballSpawnX != ballSpawnX ||
      oldDelegate.ballSpawnY != ballSpawnY ||
      oldDelegate.goalRect != goalRect ||
      oldDelegate.goalBottomY != goalBottomY ||
      oldDelegate.visualScale != visualScale ||
      oldDelegate.isFreeKick != isFreeKick;
}

/// Records a static [ui.Picture] for a painter that never animates.
ui.Picture recordStaticPicture(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder.endRecording();
}
