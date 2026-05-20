import '../models/kick_event.dart';

/// Kick detection state machine: IDLE → WINDUP → STRIKE → COOLDOWN.
///
/// Never use single-frame speed thresholds; transitions are driven by
/// sustained pose signals in normalized coordinates.
enum KickPhase {
  idle,
  windup,
  strike,
  cooldown,
}

class KickDetector {
  KickPhase _phase = KickPhase.idle;

  KickPhase get phase => _phase;

  // TODO: Feed normalized pose landmarks each frame and emit KickEvent on strike.

  void reset() {
    _phase = KickPhase.idle;
  }

  KickEvent? onPoseFrame({
    required Map<String, double> normalizedLandmarks,
    required DateTime timestamp,
  }) {
    // TODO: Implement state machine transitions.
    return null;
  }
}
