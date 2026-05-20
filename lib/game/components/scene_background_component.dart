import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../layout_constants.dart';

/// Placeholder sky band (replaced with stadium art later).
class SkyBackgroundComponent extends PositionComponent {
  SkyBackgroundComponent({required GameLayout layout})
      : super(
          position: Vector2.zero(),
          size: Vector2(layout.width, layout.skyRect.height),
          anchor: Anchor.topLeft,
        );

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF87CEEB),
    );
  }
}

/// Placeholder pitch band (replaced with grass art later).
class PitchBackgroundComponent extends PositionComponent {
  PitchBackgroundComponent({required GameLayout layout})
      : super(
          position: Vector2(0, layout.pitchRect.top),
          size: Vector2(layout.width, layout.pitchRect.height),
          anchor: Anchor.topLeft,
        );

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF1B5E20),
    );
  }
}
