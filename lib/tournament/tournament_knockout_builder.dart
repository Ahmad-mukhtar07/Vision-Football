import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_group_standings.dart';
import 'tournament_models.dart';
import 'tournament_store.dart';

/// Builds knockout rounds from group-stage results.
class TournamentKnockoutBuilder {
  TournamentKnockoutBuilder._();

  /// Fills quarter-finals: top two from each group, no same-group pairings.
  ///
  /// Bracket layout keeps group rivals apart until at least the semi-finals:
  ///   QF0: A1 vs B2    QF1: D1 vs C2
  ///   QF2: B1 vs A2    QF3: C1 vs D2
  static void populateQuarterFinals(TournamentBracket bracket) {
    final first = List<Team?>.filled(4, null);
    final second = List<Team?>.filled(4, null);

    for (var g = 0; g < 4; g++) {
      final standings = TournamentGroupStandings.forGroupIndex(bracket, g);
      first[g] = standings[0].team;
      second[g] = standings[1].team;
    }

    final qf = bracket.fixturesFor(TournamentRound.quarterFinal);
    _assign(qf[0], first[0], second[1], bracket);
    _assign(qf[1], first[3], second[2], bracket);
    _assign(qf[2], first[1], second[0], bracket);
    _assign(qf[3], first[2], second[3], bracket);
    assignShuffledDisplayOrder(qf);
  }

  static void _assign(
    TournamentFixture fixture,
    Team? teamA,
    Team? teamB,
    TournamentBracket bracket,
  ) {
    fixture.teamA = teamA;
    fixture.teamB = teamB;
    fixture.winner = null;
    fixture.scoreA = null;
    fixture.scoreB = null;

    final userInA = teamA != null && teamsMatch(teamA, bracket.userTeam);
    final userInB = teamB != null && teamsMatch(teamB, bracket.userTeam);
    fixture.isUserFixture = userInA || userInB;
    fixture.userIsTeamA = userInA;
  }
}
