import '../data/teams_data.dart';
import 'tournament_models.dart';
import 'tournament_simulator.dart';
import 'tournament_store.dart';

/// Advances bracket state: simulates AI fixtures and propagates winners.
class TournamentProgression {
  TournamentProgression({TournamentSimulator? simulator})
      : _simulator = simulator ?? TournamentSimulator();

  final TournamentSimulator _simulator;

  /// Records the user's live match result on their current fixture.
  void recordUserMatch({
    required TournamentBracket bracket,
    required bool userWon,
    required int userGoals,
    required int opponentGoals,
  }) {
    final fixture = bracket.userFixture ??
        _lastUserFixtureInRound(bracket, bracket.currentRound);
    if (fixture == null) return;

    if (fixture.userIsTeamA) {
      fixture.scoreA = userGoals;
      fixture.scoreB = opponentGoals;
    } else {
      fixture.scoreA = opponentGoals;
      fixture.scoreB = userGoals;
    }

    if (bracket.currentRound == TournamentRound.groupStage) {
      if (userGoals == opponentGoals) {
        fixture.winner = null;
      } else if (userWon) {
        fixture.winner =
            fixture.userIsTeamA ? fixture.teamA : fixture.teamB;
      } else {
        fixture.winner =
            fixture.userIsTeamA ? fixture.teamB : fixture.teamA;
      }
      return;
    }

    if (userGoals == opponentGoals) return;

    if (userWon) {
      fixture.winner = fixture.userIsTeamA ? fixture.teamA : fixture.teamB;
    } else {
      bracket.userEliminated = true;
      fixture.winner = fixture.userIsTeamA ? fixture.teamB : fixture.teamA;
    }
  }

  /// Simulates every unplayed fixture in [round].
  void simulateRound(TournamentRound round, TournamentBracket bracket) {
    for (final fixture in bracket.fixturesFor(round)) {
      if (!fixture.isPlayed) {
        _simulator.resolveFixture(fixture);
      }
    }
  }

  /// After a round is fully played, fills the next round's team slots.
  void advanceRound(TournamentBracket bracket) {
    final round = bracket.currentRound;
    if (!bracket.isRoundComplete(round)) return;

    if (round == TournamentRound.groupStage) {
      // Group-to-knockout qualification will be wired in a follow-up change.
      return;
    }

    final next = round.next;
    if (next == null) {
      final finalFix = bracket.fixturesFor(TournamentRound.finalMatch).single;
      bracket.champion = finalFix.winner;
      return;
    }

    _populateNextRound(bracket, from: round, to: next);
    bracket.currentRound = next;
  }

  /// Runs every remaining AI fixture until the cup has a champion.
  void simulateToCompletion(TournamentBracket bracket) {
    while (!bracket.isComplete) {
      simulateRound(bracket.currentRound, bracket);
      if (bracket.isRoundComplete(bracket.currentRound)) {
        advanceRound(bracket);
      } else {
        break;
      }
    }
  }

  /// After the user finishes a match: sim rest of round, advance if ready.
  void completeUserRoundStep(TournamentBracket bracket) {
    simulateRound(bracket.currentRound, bracket);
    while (bracket.isRoundComplete(bracket.currentRound) &&
        bracket.currentRound.next != null &&
        bracket.currentRound != TournamentRound.groupStage) {
      advanceRound(bracket);
    }
    if (bracket.isRoundComplete(TournamentRound.finalMatch)) {
      advanceRound(bracket);
    }
  }

  void _populateNextRound(
    TournamentBracket bracket, {
    required TournamentRound from,
    required TournamentRound to,
  }) {
    final prev = bracket.fixturesFor(from);
    final nextFixtures = bracket.fixturesFor(to);
    for (var i = 0; i < nextFixtures.length; i++) {
      final a = prev[i * 2].winner;
      final b = prev[i * 2 + 1].winner;
      final fixture = nextFixtures[i];
      fixture.teamA = a;
      fixture.teamB = b;
      fixture.winner = null;
      fixture.scoreA = null;
      fixture.scoreB = null;

      final userInA = a != null && teamsMatch(a, bracket.userTeam);
      final userInB = b != null && teamsMatch(b, bracket.userTeam);
      fixture.isUserFixture = userInA || userInB;
      fixture.userIsTeamA = userInA;
    }
    assignShuffledDisplayOrder(nextFixtures);
  }

  TournamentFixture? _lastUserFixtureInRound(
    TournamentBracket bracket,
    TournamentRound round,
  ) {
    for (final fixture in bracket.fixturesFor(round)) {
      if (fixture.isUserFixture) return fixture;
    }
    return null;
  }
}
