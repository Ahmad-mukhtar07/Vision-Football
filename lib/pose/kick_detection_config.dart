/// Tunable thresholds for [KickDetector] (Z-depth + planted-foot model).
class KickDetectionConfig {
  const KickDetectionConfig({
    this.strikeSpeedThreshold = 0.016,

    /// ML Kit Z is in image pixels (same as x/y), not 0–1. Typical kick ≈ 15–80 px/frame.
    this.minZThrustPixels = 22.0,
    this.minZThrustRelative = 0.06,
    this.maxPlausibleMovement = 0.12,
    this.maxKickMotionPerFrame = 0.32,
    this.minConfidence = 0.68,
    this.plantedFootMaxMove = 0.018,
    this.cooldownDuration = const Duration(milliseconds: 1400),
    this.ankleSmoothingAlpha = 0.38,
    this.maxJumpBeforeHold = 0.07,

    // Aim
    this.aimReferenceDelta = 0.18,
    this.aimGoalHalfWidthFraction = 0.42,

    // Shot type (relative to neutral)
    this.aerialRelativeRise = 0.07,
    this.aerialMinRise = 0.03,
    this.aerialMinLift = 0.01,
    this.chipMaxSpeed = 0.04,

    // Power
    this.maxXyVelocityNorm = 2.5,

    // Planted foot
    this.maxPlantedMissingFrames = 5,

    // Sensor override
    this.flipAimXForDevice = false,
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
  final double plantedFootMaxMove;
  final Duration cooldownDuration;
  final double ankleSmoothingAlpha;
  final double maxJumpBeforeHold;

  /// Window lateral delta at this magnitude → aim lateral ≈ 1.0 in [KickEvent].
  final double aimReferenceDelta;
  final double aimGoalHalfWidthFraction;

  /// Foot height above neutral for aerial classification (no lift velocity needed).
  final double aerialRelativeRise;

  /// Minimum rise above neutral for aerial when combined with upward velocity.
  final double aerialMinRise;

  /// Minimum upward velocity for aerial (when rise ≥ [aerialMinRise]).
  final double aerialMinLift;

  /// Max XY speed for chip classification (slower contact than a full strike).
  final double chipMaxSpeed;

  /// XY velocity (norm units / sec) that maps to power = 1.0.
  final double maxXyVelocityNorm;

  /// How many frames the planted foot can be invisible before blocking kicks.
  final int maxPlantedMissingFrames;

  /// Runtime escape hatch: negate aim X if device sensor reports inverted.
  final bool flipAimXForDevice;

  // --- Not used by KickDetector; keeps overlay / StableFootTracker compiling. ---
  static const double minAnkleConfidence = 0.68;
  static const double maxAnkleJumpPerFrame = 0.06;
  static const double minAnkleBelowKneeFraction = 0.03;
}
