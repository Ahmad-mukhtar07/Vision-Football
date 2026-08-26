import 'dart:math';

import '../tournament/tournament_models.dart';

/// How the user clinched a knockout win on the final kick.
enum TournamentWinAction { goal, save, basic }

/// Tournament-only win/lose lines on the final kick of a knockout fixture.
class TournamentResultCommentary {
  TournamentResultCommentary._();

  static const _qfWinGoal =
      'sounds/commentary/tournament/win/comm-tourn-quarters-win-goal.wav';
  static const _qfWinSave =
      'sounds/commentary/tournament/win/comm-tourn-quarters-win-save.wav';
  static const _qfWinBasic =
      'sounds/commentary/tournament/win/comm-tourn-quarters-win-basic.wav';

  static const _sfWinGoal =
      'sounds/commentary/tournament/win/comm-tourn-semis-win-goal.wav';
  static const _sfWinSave =
      'sounds/commentary/tournament/win/comm-tourn-semis-win-save.wav';
  static const _sfWinBasic =
      'sounds/commentary/tournament/win/comm-tourn-semis-win-basic.wav';

  static const _finalWin1 =
      'sounds/commentary/tournament/win/comm-tourn-final-win1.wav';
  static const _finalWin2 =
      'sounds/commentary/tournament/win/comm-tourn-final-win2.wav';

  static const _qfLose1 =
      'sounds/commentary/tournament/lose/comm-tourn-quarters-lose1.wav';
  static const _qfLose2 =
      'sounds/commentary/tournament/lose/comm-tourn-quarters-lose2.wav';
  static const _sfLose1 =
      'sounds/commentary/tournament/lose/comm-tourn-semis-lose1.wav';
  static const _sfLose2 =
      'sounds/commentary/tournament/lose/comm-tourn-semis-lose2.wav';
  static const _finalLose1 =
      'sounds/commentary/tournament/lose/comm-tourn-final-lose1.wav';
  static const _finalLose2 =
      'sounds/commentary/tournament/lose/comm-tourn-final-lose2.wav';

  static const allAssets = [
    _qfWinGoal,
    _qfWinSave,
    _qfWinBasic,
    _sfWinGoal,
    _sfWinSave,
    _sfWinBasic,
    _finalWin1,
    _finalWin2,
    _qfLose1,
    _qfLose2,
    _sfLose1,
    _sfLose2,
    _finalLose1,
    _finalLose2,
  ];

  /// Picks a win line for [round] on the match-winning kick.
  static String? pickWin(
    TournamentRound round,
    TournamentWinAction action, {
    Random? random,
  }) {
    final rng = random ?? Random();
    switch (round) {
      case TournamentRound.groupStage:
        return null;
      case TournamentRound.quarterFinal:
      case TournamentRound.semiFinal:
        return _pickKnockoutWin(
          action: action,
          goalClip: round == TournamentRound.quarterFinal
              ? _qfWinGoal
              : _sfWinGoal,
          saveClip:
              round == TournamentRound.quarterFinal ? _qfWinSave : _sfWinSave,
          basicClip: round == TournamentRound.quarterFinal
              ? _qfWinBasic
              : _sfWinBasic,
          random: rng,
        );
      case TournamentRound.finalMatch:
        return rng.nextBool() ? _finalWin1 : _finalWin2;
    }
  }

  static String _pickKnockoutWin({
    required TournamentWinAction action,
    required String goalClip,
    required String saveClip,
    required String basicClip,
    required Random random,
  }) {
    final roll = random.nextDouble();
    switch (action) {
      case TournamentWinAction.goal:
        return roll < 0.66 ? goalClip : basicClip;
      case TournamentWinAction.save:
        return roll < 0.66 ? saveClip : basicClip;
      case TournamentWinAction.basic:
        return basicClip;
    }
  }

  /// Picks a lose line for [round] on the match-losing kick (50/50).
  static String? pickLose(TournamentRound round, {Random? random}) {
    final rng = random ?? Random();
    switch (round) {
      case TournamentRound.groupStage:
        return null;
      case TournamentRound.quarterFinal:
        return rng.nextBool() ? _qfLose1 : _qfLose2;
      case TournamentRound.semiFinal:
        return rng.nextBool() ? _sfLose1 : _sfLose2;
      case TournamentRound.finalMatch:
        return rng.nextBool() ? _finalLose1 : _finalLose2;
    }
  }
}
