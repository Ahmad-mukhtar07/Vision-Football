import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Simplified boot silhouette inside a marker circle.
class BootMarkerPainter extends CustomPainter {
  BootMarkerPainter({
    this.kickFlashActive = false,
    this.starBurstProgress = 0,
    this.starBurstOrigin = Offset.zero,
  });

  final bool kickFlashActive;
  final double starBurstProgress;
  final Offset starBurstOrigin;

  static const double _containerRadius = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);

    canvas.drawCircle(
      center,
      _containerRadius,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      _containerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: kickFlashActive ? 0.95 : 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    canvas.save();
    canvas.translate(center.dx - 8, center.dy);
    _drawShoe(canvas);
    canvas.restore();

    if (starBurstProgress > 0 && starBurstProgress < 1) {
      _drawStarBurst(canvas, starBurstOrigin, starBurstProgress);
    }
  }

  void _drawShoe(Canvas canvas) {
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final toe = Rect.fromCenter(
      center: const Offset(14, 2),
      width: 22,
      height: 14,
    );
    canvas.drawOval(toe, outline);

    final upper = Path()
      ..moveTo(6, 0)
      ..quadraticBezierTo(2, -8, 8, -12)
      ..lineTo(22, -10)
      ..quadraticBezierTo(28, 2, 22, 6)
      ..lineTo(8, 8)
      ..close();
    canvas.drawPath(upper, outline);

    canvas.drawLine(
      const Offset(4, 10),
      const Offset(26, 10),
      outline..strokeWidth = 1.5,
    );
  }

  void _drawStarBurst(Canvas canvas, Offset origin, double t) {
    const stars = 4;
    for (var i = 0; i < stars; i++) {
      final angle = i * pi / 2 + pi / 4;
      final dist = 28 * t;
      final pos = origin + Offset(cos(angle), sin(angle)) * dist;
      final opacity = (1 - t).clamp(0.0, 1.0);
      _drawStar(canvas, pos, 8 * (1 - t * 0.5), opacity);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, double opacity) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outer = center + Offset(cos(outerAngle), sin(outerAngle)) * size;
      final inner =
          center + Offset(cos(innerAngle), sin(innerAngle)) * size * 0.45;
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.yellow.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant BootMarkerPainter oldDelegate) =>
      oldDelegate.kickFlashActive != kickFlashActive ||
      oldDelegate.starBurstProgress != starBurstProgress ||
      oldDelegate.starBurstOrigin != starBurstOrigin;
}
