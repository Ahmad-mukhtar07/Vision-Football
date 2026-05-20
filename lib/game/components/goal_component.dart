import 'dart:async' as async;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../layout_constants.dart';
import '../painters/goal_painter.dart';

/// Goal frame and net at the top of the screen.
class GoalComponent extends PositionComponent {
  GoalComponent({required GameLayout layout})
      : _layout = layout,
        super(
          position: Vector2(layout.goalRect.left, layout.goalRect.top),
          size: Vector2(layout.goalRect.width, layout.goalRect.height),
          anchor: Anchor.topLeft,
        );

  final GameLayout _layout;

  GameLayout get layout => _layout;

  double _netFlashOpacity = 0;
  final List<GoalParticle> _particles = [];
  async.Timer? _flashTimer;

  @override
  void update(double dt) {
    super.update(dt);
    for (final p in _particles) {
      p.life += dt;
    }
    _particles.removeWhere((p) => p.isDead);

    if (_netFlashOpacity > 0) {
      _netFlashOpacity = (_netFlashOpacity - dt * 2.5).clamp(0, 1);
    }
  }

  @override
  void render(Canvas canvas) {
    GoalPainter(
      size: Size(size.x, size.y),
      netFlashOpacity: _netFlashOpacity,
    ).paint(canvas);

    if (_particles.isNotEmpty) {
      paintGoalParticles(canvas, _particles);
    }
  }

  bool containsScreenPoint(Offset point) => _layout.goalRect.contains(point);

  /// Visual celebration on goal (net flash + particles). API unchanged for callers.
  void flashColor(Color color, Duration duration, {Offset? particleOrigin}) {
    _flashTimer?.cancel();
    _netFlashOpacity = 0.8;
    if (particleOrigin != null) {
      final local = particleOrigin - Offset(position.x, position.y);
      _particles.addAll(GoalParticle.burst(local));
    }
    _flashTimer = async.Timer(const Duration(milliseconds: 300), () {
      _netFlashOpacity = 0;
      _flashTimer = null;
    });
  }

  @override
  void onRemove() {
    _flashTimer?.cancel();
    super.onRemove();
  }
}
