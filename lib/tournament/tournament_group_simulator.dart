import 'dart:math';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_bracket_builder.dart';
import 'tournament_group_standings.dart';
import 'tournament_knockout_builder.dart';
import 'tournament_models.dart';
import 'tournament_simulator.dart';

/// Simulates group-stage fixtures with realistic pacing and unique standings.
class TournamentGroupSimulator {
  TournamentGroupSimulator({
    TournamentSimulator? simulator,
    Random? random,
  })  : _simulator = simulator ?? TournamentSimulator(),
        _random = random ?? Random();

  final TournamentSimulator _simulator;
  final Random _random;

  static int userGroupMatchesPlayed(TournamentBracket bracket) {
    return bracket.fixturesFor(TournamentRound.groupStage).where(
          (f) => f.isUserFixture && f.isPlayed,
        ).length;
  }

  /// Resolves AI fixtures after the user completes a group match.
  void simulateProgressAfterUserMatch(
    TournamentBracket bracket, {
    required int userMatchesCompleted,
  }) {
    if (userMatchesCompleted >= TournamentBracketBuilder.groupMatchesPerTeam) {
      _simulateAllRemaining(bracket);
      _ensureUniqueStandingsAllGroups(bracket);
      return;
    }

    final allNonUser = bracket
        .fixturesFor(TournamentRound.groupStage)
        .where((f) => !f.isUserFixture);
    final totalNonUser = allNonUser.length;
    final playedNonUser = allNonUser.where((f) => f.isPlayed).length;

    final targetFraction =
        userMatchesCompleted / TournamentBracketBuilder.groupMatchesPerTeam;
    final jitter = _random.nextInt(5) - 2;
    final targetPlayed =
        (totalNonUser * targetFraction).round().clamp(0, totalNonUser);
    final toSimulate = (targetPlayed - playedNonUser + jitter)
        .clamp(0, _unplayedNonUserFixtures(bracket).length);

    final candidates = _unplayedNonUserFixtures(bracket)..shuffle(_random);
    for (final fixture in candidates.take(toSimulate)) {
      resolveGroupFixture(fixture, bracket);
    }
  }

  /// Finishes the group phase, fills the quarter-finals, and checks the user.
  void advanceFromGroupStage(TournamentBracket bracket) {
    _simulateAllRemaining(bracket);
    _ensureUniqueStandingsAllGroups(bracket);
    TournamentKnockoutBuilder.populateQuarterFinals(bracket);

    final rank = _userGroupRank(bracket);
    if (rank > 2) {
      bracket.userEliminated = true;
    }
    bracket.currentRound = TournamentRound.quarterFinal;
  }

  void resolveGroupFixture(
    TournamentFixture fixture,
    TournamentBracket bracket,
  ) {
    if (fixture.isPlayed ||
        fixture.groupIndex == null ||
        fixture.teamA == null ||
        fixture.teamB == null) {
      return;
    }

    for (var attempt = 0; attempt < 24; attempt++) {
      _clearFixture(fixture);
      _simulator.resolveFixture(fixture);
      if (!_createsDuplicatePtsGd(bracket, fixture.groupIndex!)) {
        return;
      }
    }

    _clearFixture(fixture);
    _resolveDecisiveWin(fixture, favour: fixture.teamA!);
    if (_createsDuplicatePtsGd(bracket, fixture.groupIndex!)) {
      _clearFixture(fixture);
      _resolveDecisiveWin(fixture, favour: fixture.teamB!);
    }
  }

  void _simulateAllRemaining(TournamentBracket bracket) {
    for (final fixture in _unplayedNonUserFixtures(bracket)) {
      resolveGroupFixture(fixture, bracket);
    }
  }

  List<TournamentFixture> _unplayedNonUserFixtures(TournamentBracket bracket) {
    return bracket
        .fixturesFor(TournamentRound.groupStage)
        .where((f) => !f.isPlayed && !f.isUserFixture)
        .toList();
  }

  void _ensureUniqueStandingsAllGroups(TournamentBracket bracket) {
    for (final group in bracket.groups) {
      var guard = 0;
      while (_groupHasDuplicatePtsGd(bracket, group.index) && guard++ < 48) {
        final adjustable = bracket
            .fixturesFor(TournamentRound.groupStage)
            .where(
              (f) =>
                  f.groupIndex == group.index &&
                  f.isPlayed &&
                  !f.isUserFixture,
            )
            .toList()
          ..shuffle(_random);
        if (adjustable.isEmpty) break;
        _clearFixture(adjustable.first);
        resolveGroupFixture(adjustable.first, bracket);
      }
    }
  }

  bool _createsDuplicatePtsGd(TournamentBracket bracket, int groupIndex) {
    return _groupHasDuplicatePtsGd(bracket, groupIndex);
  }

  bool _groupHasDuplicatePtsGd(TournamentBracket bracket, int groupIndex) {
    final standings =
        TournamentGroupStandings.forGroupIndex(bracket, groupIndex);
    final seen = <String>{};
    for (final row in standings) {
      final key = '${row.points}:${row.goalDifference}';
      if (seen.contains(key)) return true;
      seen.add(key);
    }
    return false;
  }

  int _userGroupRank(TournamentBracket bracket) {
    final standings = TournamentGroupStandings.forGroupIndex(
      bracket,
      bracket.userGroup.index,
    );
    for (var i = 0; i < standings.length; i++) {
      if (teamsMatch(standings[i].team, bracket.userTeam)) return i + 1;
    }
    return 4;
  }

  void _resolveDecisiveWin(TournamentFixture fixture, {required Team favour}) {
    final goals = 2 + _random.nextInt(2);
    if (teamsMatch(fixture.teamA!, favour)) {
      fixture.scoreA = goals;
      fixture.scoreB = max(0, goals - 1 - _random.nextInt(2));
      fixture.winner = fixture.teamA;
    } else {
      fixture.scoreB = goals;
      fixture.scoreA = max(0, goals - 1 - _random.nextInt(2));
      fixture.winner = fixture.teamB;
    }
  }

  void _clearFixture(TournamentFixture fixture) {
    fixture.scoreA = null;
    fixture.scoreB = null;
    fixture.winner = null;
  }
}
