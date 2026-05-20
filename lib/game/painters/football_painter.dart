import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Drawn football with panel pattern, shading, and spin rotation.
class FootballPainter {
  FootballPainter({
    required this.radius,
    required this.rotationRadians,
    this.tintColor,
  });

  final double radius;
  final double rotationRadians;
  final Color? tintColor;

  void paint(Canvas canvas, Offset center) {
    final baseColor = tintColor ?? Colors.white;
    final shader = ui.Gradient.radial(
      center,
      radius,
      [
        baseColor,
        const Color(0xFFE0E0E0),
      ],
      [0.35, 1.0],
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationRadians);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..shader = shader,
    );

    _drawPanels(canvas);
    canvas.drawCircle(
      const Offset(-5, -5),
      radius * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );

    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawPanels(Canvas canvas) {
    final pentagon = Path();
    const pentR = 5.0;
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5;
      final p = Offset(cos(a) * pentR, sin(a) * pentR);
      if (i == 0) {
        pentagon.moveTo(p.dx, p.dy);
      } else {
        pentagon.lineTo(p.dx, p.dy);
      }
    }
    pentagon.close();
    canvas.drawPath(pentagon, Paint()..color = Colors.black87);

    for (var i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * 2 * pi / 5;
      final path = Path();
      path.moveTo(0, 0);
      path.arcTo(
        Rect.fromCircle(
          center: Offset(cos(angle) * 14, sin(angle) * 14),
          radius: 6,
        ),
        angle - 0.5,
        1.0,
        false,
      );
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.black.withValues(alpha: 0.85),
      );
    }
  }
}
