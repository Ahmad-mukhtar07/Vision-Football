/// Responsive layout for keeper-mode penalty and free-kick spots.
///
/// Ball centre Y is a fraction of screen height from the top (matches pitch
/// markings on the stadium background). The shooter's feet sit slightly
/// above the ball's lower edge (see [shooterFootAboveBallFraction]).
abstract final class KeeperLayoutConstants {
  /// Ball centre — penalty spot marking on the pitch art.
  static const double penaltyBallYFraction = 0.62;

  /// Ball centre — free-kick spot marking (higher on screen / closer to goal).
  static const double freeKickBallYFraction = 0.57;

  /// Nudge ball/shooter right of screen centre (fraction of screen width).
  static const double ballCenterXOffsetFraction = 0.012;

  /// How far above the ball's lower edge the shooter's foot line sits,
  /// as a fraction of the ball diameter (responsive across screen sizes).
  static const double shooterFootAboveBallFraction = 0.14;

  /// Penalty spot uses full size; free kick matches shooting-mode scale.
  static const double penaltyVisualScale = 1.0;
  static const double freeKickVisualScale = 0.72;

  /// Base shooter sprite height as a fraction of screen height (penalty).
  static const double shooterHeightFraction = 0.22;

  /// Resting ball radius at penalty (flight still grows to [penaltyBallMaxRadius]).
  static const double penaltyBallRestRadius = 16.0;
  static const double penaltyBallMaxRadius = 46.0;

  static double ballYFraction(KeeperSpotType spot) => switch (spot) {
        KeeperSpotType.penalty => penaltyBallYFraction,
        KeeperSpotType.freeKick => freeKickBallYFraction,
      };

  static double visualScale(KeeperSpotType spot) => switch (spot) {
        KeeperSpotType.penalty => penaltyVisualScale,
        KeeperSpotType.freeKick => freeKickVisualScale,
      };

  static double ballRestRadius(KeeperSpotType spot) =>
      penaltyBallRestRadius * visualScale(spot);
}

/// Penalty spot vs free-kick spot for the distant shooter.
enum KeeperSpotType { penalty, freeKick }
