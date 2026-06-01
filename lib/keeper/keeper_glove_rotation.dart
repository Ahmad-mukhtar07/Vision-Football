import 'dart:math' as math;
import 'dart:ui';

/// Computes glove rotation for keeper mode.
class KeeperGloveRotation {
  KeeperGloveRotation._();

  static const double _maxGameplayRadians = math.pi / 2; // 90°
  static const double _maxCalibrationRadians = 20 * math.pi / 180;

  /// Gameplay: lean toward the screen edge the hand is on; reach [90°] only
  /// when the hand is near the bottom of the goal mouth.
  static double forGameplay({
    required Offset position,
    required Size screen,
    required Rect goalMouth,
  }) {
    final centerX = screen.width * 0.5;
    final halfWidth = screen.width * 0.5;
    if (halfWidth <= 0) return 0;

    final horizontalNorm =
        ((position.dx - centerX) / halfWidth).clamp(-1.0, 1.0);
    if (horizontalNorm.abs() < 0.05) return 0;

    final mouthHeight = goalMouth.bottom - goalMouth.top;
    final verticalFactor = mouthHeight > 0
        ? ((position.dy - goalMouth.top) / mouthHeight).clamp(0.0, 1.0)
        : 0.0;

    final amount = horizontalNorm.abs() * verticalFactor;
    return horizontalNorm.sign * amount * _maxGameplayRadians;
  }

  /// Calibration: subtle tilt from horizontal position only.
  static double forCalibration({
    required Offset position,
    required Rect referenceRect,
  }) {
    final centerX = referenceRect.center.dx;
    final halfWidth = referenceRect.width * 0.5;
    if (halfWidth <= 0) return 0;

    final horizontalNorm =
        ((position.dx - centerX) / halfWidth).clamp(-1.0, 1.0);
    return horizontalNorm * _maxCalibrationRadians;
  }
}
