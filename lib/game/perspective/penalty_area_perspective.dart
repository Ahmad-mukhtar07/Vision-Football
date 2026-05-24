import 'dart:math';
import 'dart:ui';

/// Tunable projection constants — adjust to change the camera feel.
/// >1 compresses lines near the goal (foreshortening), <1 spreads them.
const double kCamExp = 1.8;
const double kNearWidthMult = 3.8;

/// Low-camera perspective projection for penalty-area markings.
///
/// Depth 0 = goal line (horizon). Depth 1 = near camera (past ball).
/// Y uses `pow(depth, camExp)` for foreshortening.
/// Width at depth 0 = scaled goal half-width in pixels.
/// Width at depth 1 = goalHalfPx * [kNearWidthMult].
class PenaltyAreaPerspective {
  PenaltyAreaPerspective({
    required this.screenSize,
    required this.goalRect,
    required this.goalBottomY,
    required this.ballSpawnY,
    required this.visualScale,
  }) {
    _centerX = goalRect.center.dx;
    _horizonY = goalBottomY;
    _nearY = ballSpawnY + screenSize.height * 0.06;
    _goalHalfPx = (goalRect.width * visualScale) / 2;
    _nearHalfPx = _goalHalfPx * kNearWidthMult;
  }

  final Size screenSize;
  final Rect goalRect;
  final double goalBottomY;
  final double ballSpawnY;
  final double visualScale;

  late final double _centerX;
  late final double _horizonY;
  late final double _nearY;
  late final double _goalHalfPx;
  late final double _nearHalfPx;

  double get centerX => _centerX;

  /// All box corners, arc samples, and spots go through this single function.
  Offset project(double xNorm, double depth) {
    final screenY = _horizonY + (_nearY - _horizonY) * pow(depth, kCamExp);
    final halfW = _goalHalfPx + (_nearHalfPx - _goalHalfPx) * depth;
    final screenX = _centerX + xNorm * halfW;
    return Offset(screenX, screenY);
  }
}
