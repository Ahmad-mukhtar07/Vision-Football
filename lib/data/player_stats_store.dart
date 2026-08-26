import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

/// Stage at which the player was eliminated from a Global Cup run.
enum TournamentExitStage {
  groupStage,
  quarterFinal,
  semiFinal,
  finalMatch,
}

/// Locally persisted career stats for full matches and tournaments.
class PlayerStats {
  const PlayerStats({
    this.easyPlayed = 0,
    this.easyWon = 0,
    this.moderatePlayed = 0,
    this.moderateWon = 0,
    this.hardPlayed = 0,
    this.hardWon = 0,
    this.tournamentsPlayed = 0,
    this.groupStageExits = 0,
    this.quarterFinalExits = 0,
    this.semiFinalExits = 0,
    this.finalExits = 0,
    this.tournamentsWon = 0,
    this.tournamentFixturesPlayed = 0,
    this.tournamentFixturesWon = 0,
  });

  final int easyPlayed;
  final int easyWon;
  final int moderatePlayed;
  final int moderateWon;
  final int hardPlayed;
  final int hardWon;
  final int tournamentsPlayed;
  final int groupStageExits;
  final int quarterFinalExits;
  final int semiFinalExits;
  final int finalExits;
  final int tournamentsWon;
  final int tournamentFixturesPlayed;
  final int tournamentFixturesWon;

  int get totalMatchesPlayed =>
      easyPlayed +
      moderatePlayed +
      hardPlayed +
      tournamentFixturesPlayed;

  int get totalMatchesWon =>
      easyWon + moderateWon + hardWon + tournamentFixturesWon;

  double get winningPercentage =>
      totalMatchesPlayed == 0 ? 0.0 : totalMatchesWon / totalMatchesPlayed;

  static const empty = PlayerStats();
}

class PlayerStatsStore {
  PlayerStatsStore._();

  static const _keyEasyPlayed = 'stats_easy_played';
  static const _keyEasyWon = 'stats_easy_won';
  static const _keyModeratePlayed = 'stats_moderate_played';
  static const _keyModerateWon = 'stats_moderate_won';
  static const _keyHardPlayed = 'stats_hard_played';
  static const _keyHardWon = 'stats_hard_won';
  static const _keyTournamentsPlayed = 'stats_tournaments_played';
  static const _keyGroupStageExits = 'stats_tournament_group_exits';
  static const _keyQuarterFinalExits = 'stats_tournament_qf_exits';
  static const _keySemiFinalExits = 'stats_tournament_sf_exits';
  static const _keyFinalExits = 'stats_tournament_final_exits';
  static const _keyTournamentsWon = 'stats_tournaments_won';
  static const _keyTournamentFixturesPlayed = 'stats_tournament_fixtures_played';
  static const _keyTournamentFixturesWon = 'stats_tournament_fixtures_won';

  static Future<PlayerStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerStats(
      easyPlayed: prefs.getInt(_keyEasyPlayed) ?? 0,
      easyWon: prefs.getInt(_keyEasyWon) ?? 0,
      moderatePlayed: prefs.getInt(_keyModeratePlayed) ?? 0,
      moderateWon: prefs.getInt(_keyModerateWon) ?? 0,
      hardPlayed: prefs.getInt(_keyHardPlayed) ?? 0,
      hardWon: prefs.getInt(_keyHardWon) ?? 0,
      tournamentsPlayed: prefs.getInt(_keyTournamentsPlayed) ?? 0,
      groupStageExits: prefs.getInt(_keyGroupStageExits) ?? 0,
      quarterFinalExits: prefs.getInt(_keyQuarterFinalExits) ?? 0,
      semiFinalExits: prefs.getInt(_keySemiFinalExits) ?? 0,
      finalExits: prefs.getInt(_keyFinalExits) ?? 0,
      tournamentsWon: prefs.getInt(_keyTournamentsWon) ?? 0,
      tournamentFixturesPlayed:
          prefs.getInt(_keyTournamentFixturesPlayed) ?? 0,
      tournamentFixturesWon: prefs.getInt(_keyTournamentFixturesWon) ?? 0,
    );
  }

  static Future<void> recordFullMatch({
    required DifficultyMode difficulty,
    required bool won,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final (playedKey, wonKey) = switch (difficulty) {
      DifficultyMode.easy => (_keyEasyPlayed, _keyEasyWon),
      DifficultyMode.moderate => (_keyModeratePlayed, _keyModerateWon),
      DifficultyMode.hard => (_keyHardPlayed, _keyHardWon),
    };
    await prefs.setInt(playedKey, (prefs.getInt(playedKey) ?? 0) + 1);
    if (won) {
      await prefs.setInt(wonKey, (prefs.getInt(wonKey) ?? 0) + 1);
    }
  }

  static Future<void> recordTournamentStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyTournamentsPlayed,
      (prefs.getInt(_keyTournamentsPlayed) ?? 0) + 1,
    );
  }

  static Future<void> recordTournamentFixture({required bool won}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyTournamentFixturesPlayed,
      (prefs.getInt(_keyTournamentFixturesPlayed) ?? 0) + 1,
    );
    if (won) {
      await prefs.setInt(
        _keyTournamentFixturesWon,
        (prefs.getInt(_keyTournamentFixturesWon) ?? 0) + 1,
      );
    }
  }

  static Future<void> recordTournamentWon() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyTournamentsWon,
      (prefs.getInt(_keyTournamentsWon) ?? 0) + 1,
    );
  }

  static Future<void> recordTournamentExit(TournamentExitStage stage) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (stage) {
      TournamentExitStage.groupStage => _keyGroupStageExits,
      TournamentExitStage.quarterFinal => _keyQuarterFinalExits,
      TournamentExitStage.semiFinal => _keySemiFinalExits,
      TournamentExitStage.finalMatch => _keyFinalExits,
    };
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEasyPlayed);
    await prefs.remove(_keyEasyWon);
    await prefs.remove(_keyModeratePlayed);
    await prefs.remove(_keyModerateWon);
    await prefs.remove(_keyHardPlayed);
    await prefs.remove(_keyHardWon);
    await prefs.remove(_keyTournamentsPlayed);
    await prefs.remove(_keyGroupStageExits);
    await prefs.remove(_keyQuarterFinalExits);
    await prefs.remove(_keySemiFinalExits);
    await prefs.remove(_keyFinalExits);
    await prefs.remove(_keyTournamentsWon);
    await prefs.remove(_keyTournamentFixturesPlayed);
    await prefs.remove(_keyTournamentFixturesWon);
  }
}
