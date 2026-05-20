/// Represents a detected kicking motion derived from pose landmarks.
class KickEvent {
  const KickEvent({
    required this.timestamp,
    required this.directionX,
    required this.directionY,
    required this.power,
  });

  final DateTime timestamp;

  /// Normalized horizontal kick direction (-1.0 left … 1.0 right).
  final double directionX;

  /// Normalized vertical component (-1.0 down … 1.0 up).
  final double directionY;

  /// Estimated kick strength (0.0–1.0).
  final double power;
}
