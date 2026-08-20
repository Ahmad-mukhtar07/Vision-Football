import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/data/teams_data.dart';
import 'package:vision_football/tournament/tournament_bracket_builder.dart';
import 'package:vision_football/tournament/tournament_models.dart';
import 'package:vision_football/tournament/tournament_progression.dart';
import 'package:vision_football/tournament/tournament_simulator.dart';

void main() {
  group('TournamentBracketBuilder', () {
    test('builds 16-team bracket with favourable opening draw', () {
      const seed = 42;
      final builder = TournamentBracketBuilder(random: Random(seed));
      final bracket = builder.build(userTeam: brazil);

      expect(bracket.fixturesFor(TournamentRound.roundOf16), hasLength(8));
      expect(bracket.fixturesFor(TournamentRound.quarterFinal), hasLength(4));
      expect(bracket.fixturesFor(TournamentRound.semiFinal), hasLength(2));
      expect(bracket.fixturesFor(TournamentRound.finalMatch), hasLength(1));

      final userFixture = bracket.userFixture!;
      final opponent = userFixture.userIsTeamA
          ? userFixture.teamB!
          : userFixture.teamA!;
      expect(opponent.overall, lessThan(87));
    });
  });

  group('TournamentProgression', () {
    test('simulates remaining fixtures after user elimination', () {
      final bracket =
          TournamentBracketBuilder(random: Random(7)).build(userTeam: japan);
      final progression = TournamentProgression(
        simulator: _AlwaysFirstTeamWinsSimulator(),
      );

      progression.recordUserMatch(
        bracket: bracket,
        userWon: false,
        userGoals: 2,
        opponentGoals: 3,
      );
      bracket.userEliminated = true;
      progression.simulateToCompletion(bracket);

      expect(bracket.isComplete, isTrue);
      expect(bracket.champion, isNotNull);
    });

    test('advances user through round after win', () {
      final bracket =
          TournamentBracketBuilder(random: Random(3)).build(userTeam: usa);
      final progression = TournamentProgression(
        simulator: _AlwaysFirstTeamWinsSimulator(),
      );

      progression.recordUserMatch(
        bracket: bracket,
        userWon: true,
        userGoals: 4,
        opponentGoals: 2,
      );
      progression.completeUserRoundStep(bracket);

      expect(bracket.currentRound, TournamentRound.quarterFinal);
      expect(bracket.userFixture, isNotNull);
      expect(bracket.userFixture!.teamA, isNotNull);
      expect(bracket.userFixture!.teamB, isNotNull);
    });
  });
}

class _AlwaysFirstTeamWinsSimulator extends TournamentSimulator {
  @override
  void resolveFixture(TournamentFixture fixture) {
    final a = fixture.teamA;
    final b = fixture.teamB;
    if (a == null || b == null || fixture.isPlayed) return;
    fixture.scoreA = 3;
    fixture.scoreB = 1;
    fixture.winner = a;
  }
}
