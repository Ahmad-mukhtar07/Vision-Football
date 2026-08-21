import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_models.dart';

/// One row in a group table.
class GroupStanding {
  GroupStanding({required this.team});

  final Team team;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get goalDifference => goalsFor - goalsAgainst;
  int get points => won * 3 + drawn;
}

/// Builds sorted group tables from completed group-stage fixtures.
class TournamentGroupStandings {
  TournamentGroupStandings._();

  static List<GroupStanding> forGroup({
    required TournamentGroup group,
    required Iterable<TournamentFixture> fixtures,
  }) {
    final byTeam = <String, GroupStanding>{
      for (final team in group.teams)
        team.countryCode: GroupStanding(team: team),
    };

    for (final fixture in fixtures) {
      if (fixture.groupIndex != group.index || !fixture.isPlayed) continue;
      final a = fixture.teamA;
      final b = fixture.teamB;
      final scoreA = fixture.scoreA!;
      final scoreB = fixture.scoreB!;
      if (a == null || b == null) continue;

      final standingA = byTeam[a.countryCode];
      final standingB = byTeam[b.countryCode];
      if (standingA == null || standingB == null) continue;

      standingA.played++;
      standingB.played++;
      standingA.goalsFor += scoreA;
      standingA.goalsAgainst += scoreB;
      standingB.goalsFor += scoreB;
      standingB.goalsAgainst += scoreA;

      if (scoreA > scoreB) {
        standingA.won++;
        standingB.lost++;
      } else if (scoreB > scoreA) {
        standingB.won++;
        standingA.lost++;
      } else {
        standingA.drawn++;
        standingB.drawn++;
      }
    }

    final rows = byTeam.values.toList()
      ..sort((a, b) {
        final byPts = b.points.compareTo(a.points);
        if (byPts != 0) return byPts;
        return b.goalDifference.compareTo(a.goalDifference);
      });
    return rows;
  }

  static List<GroupStanding> forGroupIndex(
    TournamentBracket bracket,
    int groupIndex,
  ) {
    final group = bracket.groups[groupIndex];
    final fixtures = bracket.fixturesFor(TournamentRound.groupStage);
    return forGroup(group: group, fixtures: fixtures);
  }
}
