import '../game/full_match_shootout.dart';

/// Match totals and kick budget after a second-half kick resolves.
class SecondHalfCommentarySnapshot {
  const SecondHalfCommentarySnapshot({
    required this.userScore,
    required this.opponentScore,
    required this.userRemainingKicks,
    required this.opponentRemainingKicks,
    required this.isLastKickOfHalf,
  });

  final int userScore;
  final int opponentScore;
  final int userRemainingKicks;
  final int opponentRemainingKicks;
  final bool isLastKickOfHalf;

  bool get isDecided =>
      fullMatchShootoutDecided(
        userScore: userScore,
        opponentScore: opponentScore,
        userRemainingKicks: userRemainingKicks,
        opponentRemainingKicks: opponentRemainingKicks,
      ) !=
      null;

  bool? get userWins =>
      fullMatchShootoutDecided(
        userScore: userScore,
        opponentScore: opponentScore,
        userRemainingKicks: userRemainingKicks,
        opponentRemainingKicks: opponentRemainingKicks,
      );

  bool get isDraw => userScore == opponentScore && !isDecided && isLastKickOfHalf;

  /// How many consecutive saves from kick-off clinch a win (keeping), or
  /// `null` when five clean sheets are needed only to draw (0–0).
  static int? savesNeededToWinAtStart(int userScoreFromHalf1) {
    if (userScoreFromHalf1 <= 0) return null;
    for (var saves = 1; saves <= 5; saves++) {
      final remaining = 5 - saves;
      if (userScoreFromHalf1 > remaining) return saves;
    }
    return 5;
  }

  /// Goals the user must score in this half to win at kick-off (shooting).
  /// Returns `5` when only a perfect half earns a draw (trailing 0–5).
  static int goalsNeededAtStartShooting(int opponentScoreFromHalf1) {
    if (opponentScoreFromHalf1 >= 5) return 5;
    return opponentScoreFromHalf1 + 1;
  }
}

/// Picks second-half kick-off lines; `null` falls back to first-half pools.
class SecondHalfStartCommentary {
  SecondHalfStartCommentary._();

  static const _general = [
    'sounds/commentary/second-half/general/comm-2h-start1.wav',
    'sounds/commentary/second-half/general/comm-2h-start2.wav',
  ];

  static const _keep = {
    1: 'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-1needed.wav',
    2: 'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-2needed.wav',
    3: 'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-3needed.wav',
    4: 'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-4needed.wav',
    5: 'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-5needed.wav',
  };

  static const _shoot = {
    1: 'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-1needed.wav',
    2: 'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-2needed.wav',
    3: 'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-3needed.wav',
    4: 'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-4needed.wav',
    5: 'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-5needed.wav',
  };

  /// Builds the pool for [pickRandom] — specific need line plus general openers.
  static List<String> pool({
    required bool userShooting,
    required int userScore,
    required int opponentScore,
  }) {
    final specific = userShooting
        ? _shoot[SecondHalfCommentarySnapshot.goalsNeededAtStartShooting(
            opponentScore,
          )]
        : _keep[
            SecondHalfCommentarySnapshot.savesNeededToWinAtStart(userScore) ??
                5];
    if (specific == null) return List<String>.from(_general);
    return [specific, ..._general];
  }
}

/// Resolves conditional second-half result lines; `null` → first-half fallback.
class SecondHalfResultCommentary {
  SecondHalfResultCommentary._();

  static const _goalLevel = [
    'sounds/commentary/second-half/goal/comm-2h-goal-level1.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-level2.wav',
  ];

  static const _goalDraw = [
    'sounds/commentary/second-half/goal/comm-2h-goal-draw.wav',
  ];

  static const _goalWinFinalKick = [
    'sounds/commentary/second-half/goal/comm-2h-goal-win-finalkick.wav',
  ];

  static const _goalWin = [
    'sounds/commentary/second-half/goal/comm-2h-goal-win1.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win2.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win3.wav',
  ];

  static const _saveDraw = [
    'sounds/commentary/second-half/save/comm-2h-save-draw1.wav',
    'sounds/commentary/second-half/save/comm-2h-save-draw2.wav',
    'sounds/commentary/second-half/save/comm-2h-save-draw3.wav',
  ];

  static const _saveWin = [
    'sounds/commentary/second-half/save/comm-2h-save-win1.wav',
    'sounds/commentary/second-half/save/comm-2h-save-win2.wav',
    'sounds/commentary/second-half/save/comm-2h-save-win3.wav',
  ];

  static const _missDeadEnd = [
    'sounds/commentary/second-half/miss/comm-2h-miss-deadend1.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-deadend2.wav',
  ];

  static const _missLost = [
    'sounds/commentary/second-half/miss/comm-2h-miss-lost1.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-lost2.wav',
  ];

  static List<String>? goalPool(SecondHalfCommentarySnapshot snap) {
    final levelled =
        snap.userScore == snap.opponentScore &&
        (snap.userRemainingKicks > 0 || snap.opponentRemainingKicks > 0);

    if (snap.isLastKickOfHalf && snap.userScore == snap.opponentScore) {
      return _goalDraw;
    }

    if (snap.isLastKickOfHalf && snap.isDecided && snap.userWins != null) {
      return _goalWinFinalKick;
    }

    if (snap.isDecided) {
      return _goalWin;
    }

    if (levelled) {
      return _goalLevel;
    }

    return null;
  }

  static List<String>? savePool(SecondHalfCommentarySnapshot snap) {
    if (snap.isLastKickOfHalf && snap.userScore == snap.opponentScore) {
      return _saveDraw;
    }

    if (snap.userWins == true) {
      return _saveWin;
    }

    return null;
  }

  static List<String>? missPool(SecondHalfCommentarySnapshot snap) {
    final maxUserScore = snap.userScore + snap.userRemainingKicks;

    if (snap.userWins == false || maxUserScore < snap.opponentScore) {
      return _missLost;
    }

    if (maxUserScore == snap.opponentScore) {
      return _missDeadEnd;
    }

    return null;
  }
}
