import 'dart:ui';

/// Flight path shape.
enum CurveType {
  straight,
  swervLeft,
  swervRight,
}

/// Resolved ball flight parameters from a [KickEvent].
class TrajectoryParams {
  const TrajectoryParams({
    required this.targetPosition,
    required this.flightDurationSeconds,
    required this.peakArcHeight,
    required this.targetScale,
    required this.curveType,
    this.spinOffsetPx = 0,
  });

  final Offset targetPosition;
  final double flightDurationSeconds;
  final double peakArcHeight;
  final double targetScale;
  final CurveType curveType;

  /// Signed lateral offset (in screen pixels) applied to the Bézier control
  /// point. Positive = curves right; negative = curves left; zero = straight.
  final double spinOffsetPx;
}
