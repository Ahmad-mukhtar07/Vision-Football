/// Full Match uses two sequential 5-kick halves (not alternating kicks).
/// Half 1 always plays out all 5; half 2 can end early once the aggregate
/// scoreline is decided — same unreachable math as a penalty shootout.
class FullMatchHalfConfig {
  const FullMatchHalfConfig({
    this.isSecondHalf = false,
    this.opponentScoreFromOtherHalf,
    this.userScoreFromOtherHalf,
    this.playAllSecondHalfKicks = false,
    this.secondHalfGeneralCommentaryOnly = false,
  });

  /// Standalone shooting / non–Full Match sessions.
  static const standalone = FullMatchHalfConfig();

  /// User shoots in half 2 after keeping in half 1 — opponent total is fixed.
  factory FullMatchHalfConfig.secondHalfShooting({
    required int opponentScore,
    bool playAllSecondHalfKicks = false,
    bool secondHalfGeneralCommentaryOnly = false,
  }) {
    return FullMatchHalfConfig(
      isSecondHalf: true,
      opponentScoreFromOtherHalf: opponentScore,
      playAllSecondHalfKicks: playAllSecondHalfKicks,
      secondHalfGeneralCommentaryOnly: secondHalfGeneralCommentaryOnly,
    );
  }

  /// User keeps in half 2 after shooting in half 1 — user total is fixed.
  factory FullMatchHalfConfig.secondHalfKeeping({
    required int userScore,
    bool playAllSecondHalfKicks = false,
    bool secondHalfGeneralCommentaryOnly = false,
  }) {
    return FullMatchHalfConfig(
      isSecondHalf: true,
      userScoreFromOtherHalf: userScore,
      playAllSecondHalfKicks: playAllSecondHalfKicks,
      secondHalfGeneralCommentaryOnly: secondHalfGeneralCommentaryOnly,
    );
  }

  final bool isSecondHalf;

  /// Opponent goals already on the board before this shooting half begins.
  final int? opponentScoreFromOtherHalf;

  /// User goals already on the board before this keeping half begins.
  final int? userScoreFromOtherHalf;

  /// When true, half 2 always runs all five kicks (group stage goal difference).
  final bool playAllSecondHalfKicks;

  /// When true, second-half result lines use first-half pools only (no 2H
  /// goal/save/miss folders). Kick-off still uses [second-half/general].
  final bool secondHalfGeneralCommentaryOnly;
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

/// Whether the current kick ends the Full Match after it resolves.
bool fullMatchEndsAfterShootingKick({
  required FullMatchHalfConfig config,
  required int totalKicks,
  required int kicksAfterThis,
  required int userGoalsInHalfAfter,
  required int opponentGoalsInHalfAfter,
}) {
  if (!config.isSecondHalf) return false;
  final remaining = totalKicks - kicksAfterThis;
  if (config.playAllSecondHalfKicks) {
    return kicksAfterThis >= totalKicks;
  }
  final decided = fullMatchShootoutDecided(
    userScore: userGoalsInHalfAfter,
    opponentScore: config.opponentScoreFromOtherHalf ?? 0,
    userRemainingKicks: remaining,
    opponentRemainingKicks: 0,
  );
  return kicksAfterThis >= totalKicks || decided != null;
}

/// Whether the current keeper shot ends the Full Match after it resolves.
bool fullMatchEndsAfterKeepingShot({
  required FullMatchHalfConfig config,
  required int totalShots,
  required int shotsAfterThis,
  required int userGoalsAfter,
  required int opponentGoalsAfter,
}) {
  if (!config.isSecondHalf) return false;
  final remaining = totalShots - shotsAfterThis;
  if (config.playAllSecondHalfKicks) {
    return shotsAfterThis >= totalShots;
  }
  final decided = fullMatchShootoutDecided(
    userScore: userGoalsAfter,
    opponentScore: opponentGoalsAfter,
    userRemainingKicks: 0,
    opponentRemainingKicks: remaining,
  );
  return shotsAfterThis >= totalShots || decided != null;
}
