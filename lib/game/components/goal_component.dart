import 'dart:async' as async;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../layout_constants.dart';

/// Placeholder goal frame at the top of the screen.
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

  Color _outlineColor = Colors.white;
  async.Timer? _flashTimer;

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  bool containsScreenPoint(Offset point) => _layout.goalRect.contains(point);

  void flashColor(Color color, Duration duration) {
    _flashTimer?.cancel();
    _outlineColor = color;
    _flashTimer = async.Timer(duration, () {
      _outlineColor = Colors.white;
      _flashTimer = null;
    });
  }

  @override
  void onRemove() {
    _flashTimer?.cancel();
    super.onRemove();
  }
}
