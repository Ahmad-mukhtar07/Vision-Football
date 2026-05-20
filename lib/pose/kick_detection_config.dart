/// Tunable thresholds for [KickDetector] (Z-depth + planted-foot model).
class KickDetectionConfig {
  const KickDetectionConfig({
    this.strikeSpeedThreshold = 0.016,
    /// ML Kit Z is in image pixels (same as x/y), not 0–1. Typical kick ≈ 15–80 px/frame.
    this.minZThrustPixels = 18.0,
    this.minZThrustRelative = 0.06,
    this.maxPlausibleMovement = 0.12,
    this.maxKickMotionPerFrame = 0.32,
    this.minConfidence = 0.68,
    this.aerialYThreshold = 0.40,
    this.plantedFootMaxMove = 0.018,
    this.cooldownDuration = const Duration(milliseconds: 1400),
    this.ankleSmoothingAlpha = 0.38,
    this.maxJumpBeforeHold = 0.07,
    /// Window lateral delta at this magnitude → aim lateral ≈ 1.0 in [KickEvent].
    this.aimReferenceDelta = 0.08,
    this.aimGoalHalfWidthFraction = 0.42,
  });

  static const KickDetectionConfig defaults = KickDetectionConfig();

  /// Every-frame [KD] IDLE lines (~10/s). Keep false while playing.
  static const bool verboseFrameLogs = false;

  /// Log run-up rejections (throttled). Set false to hide RUNUP_STEP lines.
  static const bool logRunupSteps = true;

  final double strikeSpeedThreshold;
  final double minZThrustPixels;
  final double minZThrustRelative;
  final double maxPlausibleMovement;
  final double maxKickMotionPerFrame;
  final double minConfidence;
  final double aerialYThreshold;
  final double plantedFootMaxMove;
  final Duration cooldownDuration;
  final double ankleSmoothingAlpha;
  final double maxJumpBeforeHold;
  final double aimReferenceDelta;
  final double aimGoalHalfWidthFraction;

  // --- Not used by KickDetector; keeps overlay / StableFootTracker compiling. ---
  static const double minAnkleConfidence = 0.68;
  static const double maxAnkleJumpPerFrame = 0.06;
  static const double minAnkleBelowKneeFraction = 0.03;
}
