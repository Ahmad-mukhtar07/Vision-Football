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
    test('builds four groups with double round-robin fixtures', () {
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

      expect(bracket.fixturesFor(TournamentRound.groupStage), hasLength(48));
      expect(
        bracket.fixturesFor(TournamentRound.groupStage).where((f) => f.isUserFixture),
        hasLength(6),
      );
      expect(bracket.fixturesFor(TournamentRound.quarterFinal), hasLength(4));
      expect(bracket.currentRound, TournamentRound.groupStage);
      expect(bracket.userGroup.teams.any((t) => teamsMatch(t, brazil)), isTrue);
    });

    test('user group fixtures never schedule the same opponent back-to-back', () {
      final bracket =
          TournamentBracketBuilder(random: Random(99)).build(userTeam: spain);
      final userFixtures = bracket
          .fixturesFor(TournamentRound.groupStage)
          .where((f) => f.isUserFixture)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      expect(userFixtures, hasLength(6));
      for (var i = 1; i < userFixtures.length; i++) {
        final prev = opponentInFixture(userFixtures[i - 1], spain);
        final curr = opponentInFixture(userFixtures[i], spain);
        expect(teamsMatch(prev, curr), isFalse);
      }
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

      List<TournamentFixture> fixturesBetween(Team a, Team b) {
        return fixtures
            .where(
              (f) =>
                  (teamsMatch(f.teamA!, a) && teamsMatch(f.teamB!, b)) ||
                  (teamsMatch(f.teamA!, b) && teamsMatch(f.teamB!, a)),
            )
            .toList();
      }

      void record(Team a, Team b, int scoreA, int scoreB) {
        for (final f in fixturesBetween(a, b)) {
          final aIsHome = teamsMatch(f.teamA!, a);
          f.scoreA = aIsHome ? scoreA : scoreB;
          f.scoreB = aIsHome ? scoreB : scoreA;
        }
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
      expect(standings.first.points, 18);
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
      expect(loaded.bracket.fixturesFor(TournamentRound.groupStage), hasLength(48));

      await TournamentStore.clear();
    });
  });

  group('TournamentProgression', () {
    test('group stage loss does not eliminate the user before six matches',
        () {
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
      progression.completeUserGroupMatch(bracket);

      expect(bracket.userEliminated, isFalse);
      expect(fixture.isPlayed, isTrue);
      expect(bracket.userGroupMatchesPlayed, 1);
      expect(bracket.userFixture, isNotNull);
      expect(bracket.currentRound, TournamentRound.groupStage);
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
      progression.completeUserGroupMatch(bracket);

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

  group('TournamentGroupSimulator', () {
    test('partial simulation after one user match leaves fixtures unplayed', () {
      final bracket =
          TournamentBracketBuilder(random: Random(11)).build(userTeam: brazil);
      final progression = TournamentProgression();

      progression.recordUserMatch(
        bracket: bracket,
        userWon: true,
        userGoals: 3,
        opponentGoals: 1,
      );
      progression.completeUserGroupMatch(bracket);

      final played = bracket
          .fixturesFor(TournamentRound.groupStage)
          .where((f) => f.isPlayed)
          .length;
      expect(played, greaterThan(1));
      expect(played, lessThan(48));
      expect(bracket.userGroupMatchesPlayed, 1);
    });

    test('all group fixtures complete after six user matches', () {
      final bracket =
          TournamentBracketBuilder(random: Random(5)).build(userTeam: spain);
      final progression = TournamentProgression();

      for (var i = 0; i < 6; i++) {
        progression.recordUserMatch(
          bracket: bracket,
          userWon: true,
          userGoals: 3,
          opponentGoals: 1,
        );
        progression.completeUserGroupMatch(bracket);
      }

      expect(bracket.userGroupMatchesPlayed, 6);
      expect(bracket.isRoundComplete(TournamentRound.groupStage), isTrue);
      expect(bracket.currentRound, TournamentRound.quarterFinal);
    });

    test('no duplicate points and goal difference within a group', () {
      final bracket =
          TournamentBracketBuilder(random: Random(9)).build(userTeam: usa);
      final progression = TournamentProgression();

      for (var i = 0; i < 6; i++) {
        progression.recordUserMatch(
          bracket: bracket,
          userWon: i.isEven,
          userGoals: i.isEven ? 2 : 0,
          opponentGoals: i.isEven ? 1 : 2,
        );
        progression.completeUserGroupMatch(bracket);
      }

      for (var g = 0; g < 4; g++) {
        final standings = TournamentGroupStandings.forGroupIndex(bracket, g);
        final keys = standings
            .map((s) => '${s.points}:${s.goalDifference}')
            .toSet();
        expect(keys, hasLength(4));
      }
    });

    test('every team in a group plays six matches when group stage ends', () {
      final bracket =
          TournamentBracketBuilder(random: Random(13)).build(userTeam: japan);
      final progression = TournamentProgression();

      for (var i = 0; i < 6; i++) {
        progression.recordUserMatch(
          bracket: bracket,
          userWon: true,
          userGoals: 2,
          opponentGoals: 1,
        );
        progression.completeUserGroupMatch(bracket);
      }

      for (final group in bracket.groups) {
        final standings = TournamentGroupStandings.forGroupIndex(
          bracket,
          group.index,
        );
        for (final row in standings) {
          expect(row.played, 6, reason: row.team.name);
        }
      }
    });
  });

  group('TournamentKnockoutBuilder', () {
    int groupOf(TournamentBracket bracket, Team team) {
      for (final group in bracket.groups) {
        if (group.teams.any((t) => teamsMatch(t, team))) return group.index;
      }
      throw StateError('Team not in bracket');
    }

    test('quarter-final pairings never match teams from the same group', () {
      final bracket =
          TournamentBracketBuilder(random: Random(2)).build(userTeam: brazil);
      final progression = TournamentProgression();

      for (var i = 0; i < 6; i++) {
        progression.recordUserMatch(
          bracket: bracket,
          userWon: true,
          userGoals: 3,
          opponentGoals: 0,
        );
        progression.completeUserGroupMatch(bracket);
      }

      for (final fixture
          in bracket.fixturesFor(TournamentRound.quarterFinal)) {
        expect(fixture.teamA, isNotNull);
        expect(fixture.teamB, isNotNull);
        expect(
          groupOf(bracket, fixture.teamA!),
          isNot(groupOf(bracket, fixture.teamB!)),
        );
      }
    });

    test('semi-final pairings never match teams from the same group', () {
      final bracket =
          TournamentBracketBuilder(random: Random(4)).build(userTeam: brazil);
      final progression = TournamentProgression(
        simulator: _AlwaysFirstTeamWinsSimulator(),
      );

      for (var i = 0; i < 6; i++) {
        progression.recordUserMatch(
          bracket: bracket,
          userWon: true,
          userGoals: 3,
          opponentGoals: 0,
        );
        progression.completeUserGroupMatch(bracket);
      }

      progression.simulateRound(TournamentRound.quarterFinal, bracket);
      progression.advanceRound(bracket);

      for (final fixture in bracket.fixturesFor(TournamentRound.semiFinal)) {
        expect(fixture.teamA, isNotNull);
        expect(fixture.teamB, isNotNull);
        expect(
          groupOf(bracket, fixture.teamA!),
          isNot(groupOf(bracket, fixture.teamB!)),
        );
      }
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
