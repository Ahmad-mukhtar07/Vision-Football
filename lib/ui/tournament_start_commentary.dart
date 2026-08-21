import '../tournament/tournament_models.dart';

/// Tournament-only first-half kick-off lines (QF / SF / Final).
class TournamentStartCommentary {
  TournamentStartCommentary._();

  static const _quarterFinal = [
    'sounds/commentary/tournament/general/comm-tourn-quarters-start1.wav',
    'sounds/commentary/tournament/general/comm-tourn-quarters-start2.wav',
  ];

  static const _semiFinal = [
    'sounds/commentary/tournament/general/comm-tourn-semis-start1.wav',
    'sounds/commentary/tournament/general/comm-tourn-semis-start2.wav',
  ];

  static const _finalMatch = [
    'sounds/commentary/tournament/general/comm-tourn-final-start1.wav',
    'sounds/commentary/tournament/general/comm-tourn-final-start2.wav',
  ];

  static const allAssets = [
    ..._quarterFinal,
    ..._semiFinal,
    ..._finalMatch,
  ];

  /// Returns a clip path for [round], or `null` when the round uses the
  /// standard Full Match opener (group stage).
  static List<String>? poolForRound(TournamentRound round) {
    switch (round) {
      case TournamentRound.groupStage:
        return null;
      case TournamentRound.quarterFinal:
        return _quarterFinal;
      case TournamentRound.semiFinal:
        return _semiFinal;
      case TournamentRound.finalMatch:
        return _finalMatch;
    }
  }
}
