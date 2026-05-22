import 'dart:ui';

import 'package:flame/extensions.dart';

/// Landscape first-person layout fractions (width = long axis).
abstract final class LayoutConstants {
  static const double goalWidthFraction = 0.88;
  static const double goalHeightFraction = 0.25;
  static const double goalTopFraction = 0.32;

  static const double ballSpawnYFraction = 0.80;
  static const double ballSpawnXFraction = 0.50;

  static const double skyHeightFraction = 0.30;
  static const double pitchHeightFraction = 0.40;

  static const double gkWidthInGoalFraction = 0.12;
  static const double gkHeightInGoalFraction = 0.85;

  static const double targetXMinFraction = 0.08;
  static const double targetXMaxFraction = 0.92;

  /// Lateral aim from calibrated neutral (0,0) + strike swipe.
  static const double ballAimFromFootFactor = 0.42;
  static const double ballAimFromStrikeFactor = 3.5;
  static const double maxStrikeDeltaForAim = 0.05;

  /// Vertical aim within goal mouth (0 = top of goal rect, 1 = bottom).
  static const double targetYCenterInGoalFraction = 0.55;
  static const double ballHeightFromFootFactor = 0.4;
  static const double ballHeightFromStrikeFactor = 5.0;

  static const double ballGroundArcHeightFraction = 0.06;
  static const double ballAerialArcHeightFraction = 0.18;
  static const double ballChipArcHeightFraction = 0.22;
  static const double chipTargetYInGoalFraction = 0.35;
}

/// Pixel layout derived from [screenSize] and [LayoutConstants].
class GameLayout {
  GameLayout(this.screenSize);

  final Vector2 screenSize;

  double get width => screenSize.x;
  double get height => screenSize.y;

  Rect get skyRect => Rect.fromLTWH(
        0,
        0,
        width,
        height * LayoutConstants.skyHeightFraction,
      );

  Rect get pitchRect => Rect.fromLTWH(
        0,
        height * (1 - LayoutConstants.pitchHeightFraction),
        width,
        height * LayoutConstants.pitchHeightFraction,
      );

  Rect get goalRect => Rect.fromLTWH(
        width * (1 - LayoutConstants.goalWidthFraction) / 2,
        height * LayoutConstants.goalTopFraction,
        width * LayoutConstants.goalWidthFraction,
        height * LayoutConstants.goalHeightFraction,
      );

  Vector2 get ballSpawn => Vector2(
        width * LayoutConstants.ballSpawnXFraction,
        height * LayoutConstants.ballSpawnYFraction,
      );

  Vector2 get goalCenter => Vector2(
        goalRect.center.dx,
        goalRect.center.dy,
      );
}
