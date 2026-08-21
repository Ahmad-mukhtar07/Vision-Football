import 'dart:math';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_models.dart';
import 'tournament_store.dart';

/// Builds a 16-team tournament: four random groups of four, then knockout.
class TournamentBracketBuilder {
  TournamentBracketBuilder({Random? random}) : _random = random ?? Random();

  final Random _random;

  TournamentBracket build({required Team userTeam}) {
    final pool = List<Team>.from(kStandardTeams)..shuffle(_random);
    assert(pool.length == 16);
    assert(pool.any((t) => teamsMatch(t, userTeam)));

    final groups = <TournamentGroup>[];
    for (var g = 0; g < 4; g++) {
      groups.add(
        TournamentGroup(
          index: g,
          teams: pool.sublist(g * 4, g * 4 + 4),
        ),
      );
    }

    final groupFixtures = <TournamentFixture>[];
    var fixtureIndex = 0;
    for (final group in groups) {
      final teams = group.teams;
      for (var i = 0; i < teams.length; i++) {
        for (var j = i + 1; j < teams.length; j++) {
          final a = teams[i];
          final b = teams[j];
          final userInA = teamsMatch(a, userTeam);
          final userInB = teamsMatch(b, userTeam);
          groupFixtures.add(
            TournamentFixture(
              id: 'group-${group.index}-$fixtureIndex',
              round: TournamentRound.groupStage,
              indexInRound: fixtureIndex,
              groupIndex: group.index,
              teamA: a,
              teamB: b,
              isUserFixture: userInA || userInB,
              userIsTeamA: userInA,
            ),
          );
          fixtureIndex++;
        }
      }
    }
    assignShuffledDisplayOrder(groupFixtures, random: _random);

    final rounds = <TournamentRound, List<TournamentFixture>>{
      TournamentRound.groupStage: groupFixtures,
      TournamentRound.quarterFinal:
          _emptyRound(TournamentRound.quarterFinal, 4),
      TournamentRound.semiFinal: _emptyRound(TournamentRound.semiFinal, 2),
      TournamentRound.finalMatch: _emptyRound(TournamentRound.finalMatch, 1),
    };

    return TournamentBracket(
      userTeam: userTeam,
      groups: groups,
      rounds: rounds,
    );
  }

  List<TournamentFixture> _emptyRound(TournamentRound round, int count) {
    return List.generate(
      count,
      (i) => TournamentFixture(
        id: '${round.name}-$i',
        round: round,
        indexInRound: i,
      ),
    );
  }
}
