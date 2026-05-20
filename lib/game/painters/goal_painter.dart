import 'dart:math';

import 'package:flutter/material.dart';

/// Draws goal frame, perspective net, and optional net flash overlay.
class GoalPainter {
  GoalPainter({
    required this.size,
    this.netFlashOpacity = 0,
  });

  final Size size;
  final double netFlashOpacity;

  static const double _postWidth = 8;
  static const double _crossbarHeight = 8;
  static const double _gridStep = 14;

  void paint(Canvas canvas) {
    final w = size.width;
    final h = size.height;

    _drawNet(canvas, w, h, opacity: 0.25);
    _drawNet(canvas, w, h, opacity: 0.1, offset: const Offset(7, 7));
    if (netFlashOpacity > 0) {
      _drawNet(canvas, w, h, opacity: netFlashOpacity.clamp(0, 1));
    }
    _drawPosts(canvas, w, h);
  }

  void _drawPosts(Canvas canvas, double w, double h) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    void drawPost(Rect rect) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(const Offset(2, 2)), const Radius.circular(3)),
        shadow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = Colors.white,
      );
    }

    drawPost(Rect.fromLTWH(0, 0, _postWidth, h));
    drawPost(Rect.fromLTWH(w - _postWidth, 0, _postWidth, h));
    drawPost(Rect.fromLTWH(0, 0, w, _crossbarHeight));
  }

  void _drawNet(
    Canvas canvas,
    double w,
    double h, {
    required double opacity,
    Offset offset = Offset.zero,
  }) {
    final vanish = Offset(w * 0.5 + offset.dx, h * 1.2 + offset.dy);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;

    for (var y = 0.0; y <= h; y += _gridStep) {
      final t = y / h;
      final left = Offset(offset.dx, offset.dy + y);
      final right = Offset(w + offset.dx, offset.dy + y);
      final leftVanish = Offset.lerp(left, vanish, 0.35 + t * 0.25)!;
      final rightVanish = Offset.lerp(right, vanish, 0.35 + t * 0.25)!;
      canvas.drawLine(leftVanish, rightVanish, paint);
    }

    for (var x = 0.0; x <= w; x += _gridStep) {
      final top = Offset(offset.dx + x, offset.dy);
      final bottom = Offset(offset.dx + x, offset.dy + h);
      final topV = Offset.lerp(top, vanish, 0.2)!;
      final bottomV = Offset.lerp(bottom, vanish, 0.55)!;
      canvas.drawLine(topV, bottomV, paint);
    }
  }
}

/// Celebration particles emitted on goal.
class GoalParticle {
  GoalParticle({
    required this.origin,
    required this.velocity,
    required this.radius,
    required this.maxLife,
  });

  final Offset origin;
  final Offset velocity;
  final double radius;
  final double maxLife;
  double life = 0;

  bool get isDead => life >= maxLife;

  Offset positionAt(double life) =>
      origin + velocity * life;

  double opacityAt(double life) =>
      (1 - life / maxLife).clamp(0, 1);

  static List<GoalParticle> burst(Offset origin, {int count = 12}) {
    final rng = Random();
    return List.generate(count, (i) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 80 + rng.nextDouble() * 140;
      return GoalParticle(
        origin: origin,
        velocity: Offset(cos(angle), sin(angle)) * speed,
        radius: 3 + rng.nextDouble() * 3,
        maxLife: 0.6,
      );
    });
  }
}

void paintGoalParticles(Canvas canvas, List<GoalParticle> particles) {
  for (final p in particles) {
    if (p.isDead) continue;
    final o = p.opacityAt(p.life);
    canvas.drawCircle(
      p.positionAt(p.life),
      p.radius * (0.6 + 0.4 * o),
      Paint()..color = Colors.white.withValues(alpha: o * 0.9),
    );
  }
}
