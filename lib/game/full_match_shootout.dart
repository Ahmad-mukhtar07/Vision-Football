/// Full Match uses two sequential 5-kick halves (not alternating kicks).
/// Half 1 always plays out all 5; half 2 can end early once the aggregate
/// scoreline is decided — same unreachable math as a penalty shootout.
class FullMatchHalfConfig {
  const FullMatchHalfConfig({
    this.isSecondHalf = false,
    this.opponentScoreFromOtherHalf,
    this.userScoreFromOtherHalf,
  });

  /// Standalone shooting / non–Full Match sessions.
  static const standalone = FullMatchHalfConfig();

  /// User shoots in half 2 after keeping in half 1 — opponent total is fixed.
  factory FullMatchHalfConfig.secondHalfShooting({
    required int opponentScore,
  }) {
    return FullMatchHalfConfig(
      isSecondHalf: true,
      opponentScoreFromOtherHalf: opponentScore,
    );
  }

  /// User keeps in half 2 after shooting in half 1 — user total is fixed.
  factory FullMatchHalfConfig.secondHalfKeeping({
    required int userScore,
  }) {
    return FullMatchHalfConfig(
      isSecondHalf: true,
      userScoreFromOtherHalf: userScore,
    );
  }

  final bool isSecondHalf;

  /// Opponent goals already on the board before this shooting half begins.
  final int? opponentScoreFromOtherHalf;

  /// User goals already on the board before this keeping half begins.
  final int? userScoreFromOtherHalf;
}

/// Returns whether the Full Match is already decided after a half-2 kick.
///
/// [userScore] / [opponentScore] are match totals right now.
/// [userRemainingKicks] / [opponentRemainingKicks] are unused attempts still
/// available in the current half (0 for the side that is not shooting).
///
/// `true`  → user wins (half can end)
/// `false` → opponent wins (half can end)
/// `null`  → still in play
bool? fullMatchShootoutDecided({
  required int userScore,
  required int opponentScore,
  required int userRemainingKicks,
  required int opponentRemainingKicks,
}) {
  if (userScore > opponentScore + opponentRemainingKicks) {
    return true;
  }
  if (opponentScore > userScore + userRemainingKicks) {
    return false;
  }
  return null;
}
