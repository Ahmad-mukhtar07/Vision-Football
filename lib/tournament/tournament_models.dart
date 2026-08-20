import '../data/teams_data.dart';
import '../models/team.dart';

/// Knockout stage in the 16-team cup.
enum TournamentRound {
  roundOf16,
  quarterFinal,
  semiFinal,
  finalMatch,
}

extension TournamentRoundX on TournamentRound {
  String get label {
    switch (this) {
      case TournamentRound.roundOf16:
        return 'Round of 16';
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
      case TournamentRound.roundOf16:
        return 8;
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
      case TournamentRound.roundOf16:
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

/// One penalty-shootout fixture in the bracket tree.
class TournamentFixture {
  TournamentFixture({
    required this.id,
    required this.round,
    required this.indexInRound,
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
  Team? teamA;
  Team? teamB;
  Team? winner;
  int? scoreA;
  int? scoreB;
  bool isUserFixture;
  bool userIsTeamA;
  int displayOrder;

  bool get isPlayed => winner != null;

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

/// Full knockout tree for one tournament run.
class TournamentBracket {
  TournamentBracket({
    required this.userTeam,
    required this.rounds,
    this.currentRound = TournamentRound.roundOf16,
    this.userEliminated = false,
    this.champion,
  });

  final Team userTeam;
  final Map<TournamentRound, List<TournamentFixture>> rounds;
  TournamentRound currentRound;
  bool userEliminated;
  Team? champion;

  List<TournamentFixture> fixturesFor(TournamentRound round) =>
      rounds[round] ?? const [];

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
