import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Human-shaped goalkeeper figure (canvas only).
class GoalkeeperPainter {
  GoalkeeperPainter({
    required this.goalWidth,
    required this.goalHeight,
    required this.isDiving,
    required this.diveProgress,
    required this.diveDirectionSign,
    required this.saveFlashOpacity,
  });

  final double goalWidth;
  final double goalHeight;
  final bool isDiving;
  final double diveProgress;
  final double diveDirectionSign;
  final double saveFlashOpacity;

  static const Color _jersey = Color(0xFFFF6B00);
  static const Color _shorts = Color(0xFF1a1a2e);
  static const Color _skin = Color(0xFFFDBCB4);
  static const Color _glove = Color(0xFFFFD700);

  void paint(Canvas canvas, Size size) {
    final figureH = goalHeight * 0.82;
    final cx = size.width * 0.5;
    final footY = size.height * 0.5 + figureH * 0.5;

    final diveAngle = isDiving ? diveDirectionSign * 35 * pi / 180 : 0.0;
    final armSpread = isDiving ? 0.35 + diveProgress * 0.45 : 0.12;

    canvas.save();
    canvas.translate(cx, footY);
    canvas.rotate(diveAngle);
    canvas.translate(-cx, -footY);

    final headR = goalHeight * 0.055;
    final headCenter = Offset(cx, footY - figureH + headR);

    canvas.drawCircle(
      headCenter,
      headR,
      Paint()..color = _skin,
    );

    final torsoW = goalWidth * 0.12;
    final torsoH = goalHeight * 0.32;
    final torsoTop = headCenter.dy + headR * 0.6;
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, torsoTop + torsoH * 0.5),
        width: torsoW,
        height: torsoH,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(torsoRect, Paint()..color = _jersey);

    _drawLimb(
      canvas,
      shoulder: Offset(cx - torsoW * 0.45, torsoTop + torsoH * 0.15),
      length: goalHeight * 0.22,
      angle: -pi * 0.35 - armSpread,
      color: _jersey,
      endCap: _glove,
      capRadius: goalHeight * 0.045,
    );
    _drawLimb(
      canvas,
      shoulder: Offset(cx + torsoW * 0.45, torsoTop + torsoH * 0.15),
      length: goalHeight * 0.22,
      angle: -pi * 0.65 + armSpread,
      color: _jersey,
      endCap: _glove,
      capRadius: goalHeight * 0.045,
    );

    final legTop = torsoTop + torsoH;
    final legH = goalHeight * 0.28;
    final legW = torsoW * 0.32;
    _drawLeg(canvas, Offset(cx - legW * 0.9, legTop + legH * 0.5), legW, legH);
    _drawLeg(canvas, Offset(cx + legW * 0.9, legTop + legH * 0.5), legW, legH);

    if (saveFlashOpacity > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: saveFlashOpacity * 0.55),
      );
    }

    canvas.restore();
  }

  void _drawLimb(
    Canvas canvas, {
    required Offset shoulder,
    required double length,
    required double angle,
    required Color color,
    Color? endCap,
    double capRadius = 0,
  }) {
    final end = shoulder + Offset(cos(angle), sin(angle)) * length;
    final paint = Paint()
      ..color = color
      ..strokeWidth = length * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, end, paint);
    if (endCap != null && capRadius > 0) {
      canvas.drawCircle(end, capRadius, Paint()..color = endCap);
    }
  }

  void _drawLeg(Canvas canvas, Offset center, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: h * 0.55),
        const Radius.circular(4),
      ),
      Paint()..color = _shorts,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.32),
          width: w * 0.85,
          height: h * 0.35,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );
  }
}
