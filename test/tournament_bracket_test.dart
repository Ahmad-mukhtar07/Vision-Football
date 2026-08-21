import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_football/data/teams_data.dart';
import 'package:vision_football/models/team.dart';
import 'package:vision_football/tournament/tournament_bracket_builder.dart';
import 'package:vision_football/tournament/tournament_group_standings.dart';
import 'package:vision_football/tournament/tournament_models.dart';
import 'package:vision_football/tournament/tournament_progression.dart';
import 'package:vision_football/tournament/tournament_simulator.dart';
import 'package:vision_football/tournament/tournament_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TournamentBracketBuilder', () {
    test('builds four groups of four with round-robin fixtures', () {
      const seed = 42;
      final builder = TournamentBracketBuilder(random: Random(seed));
      final bracket = builder.build(userTeam: brazil);

      expect(bracket.groups, hasLength(4));
      for (final group in bracket.groups) {
        expect(group.teams, hasLength(4));
      }

      final allTeams = bracket.groups.expand((g) => g.teams).toList();
      expect(allTeams, hasLength(16));
      expect(allTeams.toSet(), hasLength(16));

      expect(bracket.fixturesFor(TournamentRound.groupStage), hasLength(24));
      expect(bracket.fixturesFor(TournamentRound.quarterFinal), hasLength(4));
      expect(bracket.currentRound, TournamentRound.groupStage);
      expect(bracket.userGroup.teams.any((t) => teamsMatch(t, brazil)), isTrue);
    });
  });

  group('TournamentGroupStandings', () {
    test('awards 3/1/0 points and sorts by points then goal difference', () {
      final bracket =
          TournamentBracketBuilder(random: Random(1)).build(userTeam: brazil);
      final group = bracket.groups.first;
      final fixtures = bracket
          .fixturesFor(TournamentRound.groupStage)
          .where((f) => f.groupIndex == group.index)
          .toList();
      final t0 = group.teams[0];
      final t1 = group.teams[1];
      final t2 = group.teams[2];
      final t3 = group.teams[3];

      TournamentFixture fixture(Team a, Team b) {
        return fixtures.firstWhere(
          (f) =>
              (teamsMatch(f.teamA!, a) && teamsMatch(f.teamB!, b)) ||
              (teamsMatch(f.teamA!, b) && teamsMatch(f.teamB!, a)),
        );
      }

      void record(Team a, Team b, int scoreA, int scoreB) {
        final f = fixture(a, b);
        final aIsHome = teamsMatch(f.teamA!, a);
        f.scoreA = aIsHome ? scoreA : scoreB;
        f.scoreB = aIsHome ? scoreB : scoreA;
      }

      record(t0, t1, 2, 0);
      record(t2, t3, 1, 1);
      record(t0, t2, 1, 0);
      record(t1, t3, 0, 3);
      record(t0, t3, 3, 0);
      record(t1, t2, 1, 1);

      final standings = TournamentGroupStandings.forGroup(
        group: group,
        fixtures: fixtures,
      );

      expect(standings.first.team, t0);
      expect(standings.first.points, 9);
      expect(standings.first.goalDifference, greaterThan(0));
    });
  });

  group('TournamentStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('round-trips group stage state', () async {
      final bracket =
          TournamentBracketBuilder(random: Random(1)).build(userTeam: spain);
      final fixture = bracket.userFixture!;
      fixture.scoreA = 2;
      fixture.scoreB = 1;
      fixture.winner = fixture.teamA;

      await TournamentStore.save(bracket: bracket, matchInProgress: false);
      final loaded = await TournamentStore.load();

      expect(loaded, isNotNull);
      expect(loaded!.bracket.groups, hasLength(4));
      expect(loaded.bracket.currentRound, TournamentRound.groupStage);
      expect(fixture.isPlayed, isTrue);
      expect(loaded.bracket.fixturesFor(TournamentRound.groupStage), hasLength(24));

      await TournamentStore.clear();
    });
  });

  group('TournamentProgression', () {
    test('group stage loss does not eliminate the user', () {
      final bracket =
          TournamentBracketBuilder(random: Random(7)).build(userTeam: japan);
      final progression = TournamentProgression(
        simulator: _AlwaysFirstTeamWinsSimulator(),
      );

      final fixture = bracket.userFixture!;
      progression.recordUserMatch(
        bracket: bracket,
        userWon: false,
        userGoals: 1,
        opponentGoals: 2,
      );

      expect(bracket.userEliminated, isFalse);
      expect(fixture.isPlayed, isTrue);
    });

    test('group stage draw records equal scores without a winner', () {
      final bracket =
          TournamentBracketBuilder(random: Random(3)).build(userTeam: usa);
      final progression = TournamentProgression();

      final fixture = bracket.userFixture!;
      progression.recordUserMatch(
        bracket: bracket,
        userWon: false,
        userGoals: 2,
        opponentGoals: 2,
      );

      expect(fixture.isDraw, isTrue);
      expect(fixture.winner, isNull);
      expect(bracket.userEliminated, isFalse);
    });

    test('advances user through knockout round after win', () {
      final bracket =
          TournamentBracketBuilder(random: Random(3)).build(userTeam: usa);
      final progression = TournamentProgression(
        simulator: _AlwaysFirstTeamWinsSimulator(),
      );

      bracket.currentRound = TournamentRound.quarterFinal;
      final qf = bracket.fixturesFor(TournamentRound.quarterFinal).first
        ..teamA = usa
        ..teamB = japan
        ..isUserFixture = true
        ..userIsTeamA = true;

      progression.recordUserMatch(
        bracket: bracket,
        userWon: true,
        userGoals: 4,
        opponentGoals: 2,
      );
      for (final fixture in bracket.fixturesFor(TournamentRound.quarterFinal)) {
        if (!fixture.isPlayed) {
          fixture.scoreA = 1;
          fixture.scoreB = 0;
          fixture.winner = fixture.teamA;
        }
      }
      progression.advanceRound(bracket);

      expect(bracket.currentRound, TournamentRound.semiFinal);
      expect(qf.isPlayed, isTrue);
    });
  });

  group('TournamentStore clear', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('clear removes saved tournament', () async {
      final bracket =
          TournamentBracketBuilder(random: Random(1)).build(userTeam: spain);
      bracket.userEliminated = true;

      await TournamentStore.save(bracket: bracket, matchInProgress: false);
      expect(await TournamentStore.hasSavedTournament(), isTrue);

      await TournamentStore.clear();
      expect(await TournamentStore.hasSavedTournament(), isFalse);
      expect(await TournamentStore.load(), isNull);
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
