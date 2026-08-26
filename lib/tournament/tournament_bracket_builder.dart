import 'dart:math';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_models.dart';
import 'tournament_store.dart';

/// Builds a 16-team tournament: four random groups of four, then knockout.
class TournamentBracketBuilder {
  TournamentBracketBuilder({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Each team plays every group opponent twice (home and away).
  static const int groupMatchesPerTeam = 6;

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
    final userFixtures = <TournamentFixture>[];
    var fixtureIndex = 0;
    for (final group in groups) {
      final teams = group.teams;
      for (var leg = 0; leg < 2; leg++) {
        for (var i = 0; i < teams.length; i++) {
          for (var j = i + 1; j < teams.length; j++) {
            final a = leg == 0 ? teams[i] : teams[j];
            final b = leg == 0 ? teams[j] : teams[i];
            final userInA = teamsMatch(a, userTeam);
            final userInB = teamsMatch(b, userTeam);
            final fixture = TournamentFixture(
              id: 'group-${group.index}-$fixtureIndex',
              round: TournamentRound.groupStage,
              indexInRound: fixtureIndex,
              groupIndex: group.index,
              teamA: a,
              teamB: b,
              isUserFixture: userInA || userInB,
              userIsTeamA: userInA,
            );
            groupFixtures.add(fixture);
            if (fixture.isUserFixture) userFixtures.add(fixture);
            fixtureIndex++;
          }
        }
      }
    }

    assignUserGroupFixtureOrder(userFixtures, userTeam, random: _random);

    final nonUserFixtures =
        groupFixtures.where((f) => !f.isUserFixture).toList();
    assignShuffledDisplayOrder(
      nonUserFixtures,
      random: _random,
      startAt: groupMatchesPerTeam,
    );

    final rounds = <TournamentRound, List<TournamentFixture>>{
      TournamentRound.groupStage: groupFixtures,
      TournamentRound.quarterFinal:
          _emptyRound(TournamentRound.quarterFinal, 4),
      TournamentRound.semiFinal: _emptyRound(TournamentRound.semiFinal, 2),
      TournamentRound.finalMatch: _emptyRound(TournamentRound.finalMatch, 1),
    };

    final moderatePicks = List.generate(groupMatchesPerTeam, (i) => i)
      ..shuffle(_random);

    return TournamentBracket(
      userTeam: userTeam,
      groups: groups,
      rounds: rounds,
      moderateGroupMatchIndices: moderatePicks.take(2).toSet(),
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

/// Orders the user's six group fixtures so no opponent appears back-to-back.
void assignUserGroupFixtureOrder(
  List<TournamentFixture> userFixtures,
  Team userTeam, {
  required Random random,
}) {
  if (userFixtures.isEmpty) return;

  final byOpponent = <String, List<TournamentFixture>>{};
  for (final fixture in userFixtures) {
    final opponent = opponentInFixture(fixture, userTeam);
    byOpponent.putIfAbsent(opponent.countryCode, () => []).add(fixture);
  }

  final queues = byOpponent.values.toList()..shuffle(random);
  final ordered = <TournamentFixture>[];
  String? lastOpponentCode;

  while (ordered.length < userFixtures.length) {
    final available = queues.where((q) => q.isNotEmpty).toList();
    var candidates = available.where((queue) {
      final code = opponentInFixture(queue.first, userTeam).countryCode;
      return lastOpponentCode == null || code != lastOpponentCode;
    }).toList();
    if (candidates.isEmpty) candidates = available;
    candidates.shuffle(random);

    final fixture = candidates.first.removeAt(0);
    ordered.add(fixture);
    lastOpponentCode = opponentInFixture(fixture, userTeam).countryCode;
  }

  for (var i = 0; i < ordered.length; i++) {
    ordered[i].displayOrder = i;
  }
}

Team opponentInFixture(TournamentFixture fixture, Team userTeam) {
  if (fixture.teamA == null || fixture.teamB == null) {
    throw StateError('Fixture teams must be set');
  }
  return teamsMatch(fixture.teamA!, userTeam) ? fixture.teamB! : fixture.teamA!;
}
