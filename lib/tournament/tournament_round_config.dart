import '../data/game_settings.dart';
import '../data/keeper_stadium.dart';
import 'tournament_models.dart';

/// Per-round difficulty and stadium enforced during tournament fixtures.
class TournamentRoundSettings {
  const TournamentRoundSettings({
    required this.difficulty,
    required this.stadium,
  });

  final DifficultyMode difficulty;
  final KeeperStadiumLocation stadium;

  static TournamentRoundSettings forRound(TournamentRound round) {
    switch (round) {
      case TournamentRound.roundOf16:
      case TournamentRound.quarterFinal:
        return const TournamentRoundSettings(
          difficulty: DifficultyMode.easy,
          stadium: KeeperStadiumLocation.italy,
        );
      case TournamentRound.semiFinal:
        return const TournamentRoundSettings(
          difficulty: DifficultyMode.moderate,
          stadium: KeeperStadiumLocation.spain,
        );
      case TournamentRound.finalMatch:
        return const TournamentRoundSettings(
          difficulty: DifficultyMode.hard,
          stadium: KeeperStadiumLocation.usa,
        );
    }
  }
}

/// Temporarily applies tournament match settings without persisting them.
class TournamentMatchSettingsScope {
  TournamentMatchSettingsScope._(this._previousDifficulty, this._previousStadium);

  final DifficultyMode _previousDifficulty;
  final KeeperStadiumLocation _previousStadium;

  static TournamentMatchSettingsScope apply(TournamentRoundSettings settings) {
    final previousDifficulty = GameSettings.difficulty;
    final previousStadium = GameSettings.keeperStadium;
    GameSettings.difficulty = settings.difficulty;
    GameSettings.keeperStadium = settings.stadium;
    return TournamentMatchSettingsScope._(previousDifficulty, previousStadium);
  }

  void restore() {
    GameSettings.difficulty = _previousDifficulty;
    GameSettings.keeperStadium = _previousStadium;
  }
}
