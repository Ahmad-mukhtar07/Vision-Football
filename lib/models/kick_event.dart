import 'dart:ui';

/// Classification of kick trajectory at the moment of strike.
enum KickType {
  ground,
  aerial,
  chip,
}

/// Represents a detected kicking motion derived from pose landmarks.
class KickEvent {
  const KickEvent({
    required this.footPositionNormalized,
    required this.strikeDeltaNormalized,
    required this.strikeSpeed,
    required this.kickPower,
    required this.type,
    required this.timestamp,
    this.spinX = 0,
    this.loft = 0,
    this.lateralAim = 0,
  });

  /// Where on screen the kick registered (0.0–1.0, origin top-left).
  final Offset footPositionNormalized;

  /// Foot movement over the strike window (normalized coords; magnitude ≈ power).
  final Offset strikeDeltaNormalized;

  /// Peak normalized foot speed during the STRIKE frame.
  final double strikeSpeed;

  /// Combined XY-velocity + Z-thrust power, normalized 0–1.
  final double kickPower;

  final KickType type;

  /// Lateral spin amount in range [-1.0, +1.0].
  ///  - 0  → no swing, ball flies straight
  ///  - >0 → ball curves to the right (in screen / camera view)
  ///  - <0 → ball curves to the left
  /// Magnitude scales how pronounced the in-flight curve is.
  final double spinX;

  /// How high the kicking foot rose above its resting height at strike,
  /// normalized 0–1. Near 1 means the ball was hit very high (ballooned) and
  /// should clatter the crossbar rather than nestle into the top of the net.
  final double loft;

  /// Lateral aim magnitude clamped to ±1.6 (placement uses the ±1
  /// [strikeDeltaNormalized]). Values beyond ±1 mean the player swung well
  /// past a corner and the shot should miss wide of the post.
  final double lateralAim;

  final DateTime timestamp;

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    return '[KICK] type=${type.name} speed=${strikeSpeed.toStringAsFixed(3)} '
        'power=${kickPower.toStringAsFixed(2)} '
        'spin=${spinX.toStringAsFixed(2)} '
        'position=(${footPositionNormalized.dx.toStringAsFixed(2)}, '
        '${footPositionNormalized.dy.toStringAsFixed(2)}) '
        'delta=(${strikeDeltaNormalized.dx.toStringAsFixed(3)}, '
        '${strikeDeltaNormalized.dy.toStringAsFixed(3)}) at $time';
  }
}
