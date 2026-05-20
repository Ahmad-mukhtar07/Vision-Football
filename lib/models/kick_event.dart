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
    required this.type,
    required this.timestamp,
    this.mirrorPreviewAim = false,
  });

  /// When true, horizontal aim is flipped to match the mirrored selfie preview.
  final bool mirrorPreviewAim;

  /// Where on screen the kick registered (0.0–1.0, origin top-left).
  final Offset footPositionNormalized;

  /// Foot movement over the strike window (normalized coords; magnitude ≈ power).
  final Offset strikeDeltaNormalized;

  /// Peak normalized foot speed during the STRIKE frame.
  final double strikeSpeed;

  final KickType type;

  final DateTime timestamp;

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    return '[KICK] type=${type.name} speed=${strikeSpeed.toStringAsFixed(3)} '
        'position=(${footPositionNormalized.dx.toStringAsFixed(2)}, '
        '${footPositionNormalized.dy.toStringAsFixed(2)}) '
        'delta=(${strikeDeltaNormalized.dx.toStringAsFixed(3)}, '
        '${strikeDeltaNormalized.dy.toStringAsFixed(3)}) at $time';
  }
}
