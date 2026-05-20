import 'dart:ui';

/// Flight path shape — extend for inswing/outswing later.
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
  });

  final Offset targetPosition;
  final double flightDurationSeconds;
  final double peakArcHeight;
  final double targetScale;
  final CurveType curveType;
}
