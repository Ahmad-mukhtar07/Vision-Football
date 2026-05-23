import 'dart:math';
import 'dart:ui';

/// Projects penalty-area geometry into screen space using a single vanishing
/// point behind the goal center.
///
/// Depth runs from 0 (goal line, top/far) to 1 (near camera / ball).
/// Width grows linearly from far to near to simulate perspective.
class PenaltyAreaPerspective {
  PenaltyAreaPerspective({
    required this.screenSize,
    required this.goalRect,
    required this.goalBottomY,
    required this.ballSpawnY,
  }) {
    _vpX = goalRect.center.dx;
    _vpY = goalRect.top - screenSize.height * 0.06;

    _goalLineY = goalBottomY;
    _nearY = ballSpawnY + screenSize.height * 0.06;

    _farHalfWidth = goalRect.width * 0.52;
    _nearHalfWidth = screenSize.width * 0.48;
  }

  final Size screenSize;
  final Rect goalRect;
  final double goalBottomY;
  final double ballSpawnY;

  late final double _vpX;
  late final double _vpY;
  late final double _goalLineY;
  late final double _nearY;
  late final double _farHalfWidth;
  late final double _nearHalfWidth;

  Offset get vanishingPoint => Offset(_vpX, _vpY);

  double yAtDepth(double depth) {
    return _goalLineY + (_nearY - _goalLineY) * depth;
  }

  double halfWidthAtDepth(double depth) {
    return _farHalfWidth + (_nearHalfWidth - _farHalfWidth) * depth;
  }

  Offset leftAtDepth(double depth) {
    final y = yAtDepth(depth);
    return Offset(_vpX - halfWidthAtDepth(depth), y);
  }

  Offset rightAtDepth(double depth) {
    final y = yAtDepth(depth);
    return Offset(_vpX + halfWidthAtDepth(depth), y);
  }

  /// Normalized depth fractions for real-world penalty area geometry.
  /// 6-yard box is ~6/18 = 0.33 of the 18-yard area.
  static const double goalLineDepth = 0.0;
  static const double sixYardDepth = 0.33;
  static const double penaltySpotDepth = 0.67;
  static const double eighteenYardDepth = 1.0;

  /// 6-yard box is narrower: roughly 60% of the width at that depth.
  double sixYardHalfWidth(double depth) => halfWidthAtDepth(depth) * 0.52;

  /// Project a point given as (normalizedX in [-1..1], depth 0..1) to screen.
  Offset project(double normalizedX, double depth) {
    final y = yAtDepth(depth);
    final hw = halfWidthAtDepth(depth);
    return Offset(_vpX + normalizedX * hw, y);
  }

  /// Generate an arc path at a given depth, bulging toward the camera.
  /// [arcRadius01] is the bulge depth (fraction of total depth range).
  Path arcAtDepth(double centerDepth, double arcRadius01, {int segments = 20}) {
    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = pi * t;
      final x = cos(angle);
      final depthOffset = sin(angle) * arcRadius01;
      final d = centerDepth + depthOffset;
      final hw = halfWidthAtDepth(centerDepth) * 0.72;
      final pt = Offset(_vpX + x * hw, yAtDepth(d));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path;
  }
}
