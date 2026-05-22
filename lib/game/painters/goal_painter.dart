import 'dart:math';

import 'package:flutter/material.dart';

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
