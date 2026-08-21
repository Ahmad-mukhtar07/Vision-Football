import '../data/teams_data.dart';
import '../models/team.dart';

/// Tournament stage — group phase then knockout rounds.
enum TournamentRound {
  groupStage,
  quarterFinal,
  semiFinal,
  finalMatch,
}

extension TournamentRoundX on TournamentRound {
  String get label {
    switch (this) {
      case TournamentRound.groupStage:
        return 'Group Stage';
      case TournamentRound.quarterFinal:
        return 'Quarter Finals';
      case TournamentRound.semiFinal:
        return 'Semi Finals';
      case TournamentRound.finalMatch:
        return 'Final';
    }
  }

  int get fixtureCount {
    switch (this) {
      case TournamentRound.groupStage:
        return 24;
      case TournamentRound.quarterFinal:
        return 4;
      case TournamentRound.semiFinal:
        return 2;
      case TournamentRound.finalMatch:
        return 1;
    }
  }

  TournamentRound? get next {
    switch (this) {
      case TournamentRound.groupStage:
        return TournamentRound.quarterFinal;
      case TournamentRound.quarterFinal:
        return TournamentRound.semiFinal;
      case TournamentRound.semiFinal:
        return TournamentRound.finalMatch;
      case TournamentRound.finalMatch:
        return null;
    }
  }
}

/// Four teams in one World-Cup-style group.
class TournamentGroup {
  TournamentGroup({
    required this.index,
    required this.teams,
  }) : assert(teams.length == 4);

  final int index;
  final List<Team> teams;

  String get label => 'Group ${String.fromCharCode(65 + index)}';
}

/// One fixture in the group phase or knockout tree.
class TournamentFixture {
  TournamentFixture({
    required this.id,
    required this.round,
    required this.indexInRound,
    this.groupIndex,
    this.teamA,
    this.teamB,
    this.winner,
    this.scoreA,
    this.scoreB,
    this.isUserFixture = false,
    this.userIsTeamA = true,
    int? displayOrder,
  }) : displayOrder = displayOrder ?? indexInRound;

  final String id;
  final TournamentRound round;
  final int indexInRound;
  final int? groupIndex;
  Team? teamA;
  Team? teamB;
  Team? winner;
  int? scoreA;
  int? scoreB;
  bool isUserFixture;
  bool userIsTeamA;
  int displayOrder;

  bool get isPlayed => scoreA != null && scoreB != null;

  bool get isDraw => isPlayed && scoreA == scoreB;

  Team? get loser {
    if (winner == null || teamA == null || teamB == null) return null;
    return teamsMatch(winner!, teamA!) ? teamB : teamA;
  }

  TournamentFixture copyWith({
    Team? teamA,
    Team? teamB,
    Team? winner,
    int? scoreA,
    int? scoreB,
  }) {
    return TournamentFixture(
      id: id,
      round: round,
      indexInRound: indexInRound,
      groupIndex: groupIndex,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      winner: winner ?? this.winner,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      isUserFixture: isUserFixture,
      userIsTeamA: userIsTeamA,
    );
  }
}

/// Full tournament state: group phase plus knockout bracket.
class TournamentBracket {
  TournamentBracket({
    required this.userTeam,
    required this.groups,
    required this.rounds,
    this.currentRound = TournamentRound.groupStage,
    this.userEliminated = false,
    this.champion,
  });

  final Team userTeam;
  final List<TournamentGroup> groups;
  final Map<TournamentRound, List<TournamentFixture>> rounds;
  TournamentRound currentRound;
  bool userEliminated;
  Team? champion;

  List<TournamentFixture> fixturesFor(TournamentRound round) =>
      rounds[round] ?? const [];

  TournamentGroup get userGroup =>
      groups.firstWhere(
        (g) => g.teams.any((t) => teamsMatch(t, userTeam)),
      );

  TournamentFixture? get userFixture {
    for (final fixture in fixturesFor(currentRound)) {
      if (fixture.isUserFixture && !fixture.isPlayed) return fixture;
    }
    return null;
  }

  bool get isComplete => champion != null;

  bool get userWonTournament =>
      champion != null && teamsMatch(champion!, userTeam);

  bool isRoundComplete(TournamentRound round) {
    final fixtures = fixturesFor(round);
    if (fixtures.isEmpty) return false;
    return fixtures.every((f) => f.isPlayed);
  }
}

/// Maps legacy save data to the current [TournamentRound] enum.
TournamentRound decodeTournamentRound(String name) {
  if (name == 'roundOf16') return TournamentRound.groupStage;
  return TournamentRound.values.byName(name);
}
