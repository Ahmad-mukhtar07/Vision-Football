import 'dart:math';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_models.dart';

/// Builds a 16-team knockout bracket with a favourable Round-of-16 draw for
/// the user's team.
class TournamentBracketBuilder {
  TournamentBracketBuilder({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Teams with overall at or above this rating are "too strong" for the
  /// user's opening fixture.
  static const int _strongOpponentOverall = 87;

  TournamentBracket build({required Team userTeam}) {
    final others = kStandardTeams
        .where((t) => !teamsMatch(t, userTeam))
        .toList()
      ..shuffle(_random);

    final softOpponents = others
        .where((t) => t.overall < _strongOpponentOverall)
        .toList();
    final userOpponentPool =
        softOpponents.isNotEmpty ? softOpponents : others;
    final opponent = (userOpponentPool.toList()..shuffle(_random)).first;

    final remaining = others.where((t) => !teamsMatch(t, opponent)).toList()
      ..shuffle(_random);

    final r16Teams = <Team>[userTeam, opponent, ...remaining];
    assert(r16Teams.length == 16);

    final r16 = <TournamentFixture>[];
    for (var i = 0; i < 8; i++) {
      final a = r16Teams[i * 2];
      final b = r16Teams[i * 2 + 1];
      final isUser = teamsMatch(a, userTeam) || teamsMatch(b, userTeam);
      r16.add(
        TournamentFixture(
          id: 'r16-$i',
          round: TournamentRound.roundOf16,
          indexInRound: i,
          teamA: a,
          teamB: b,
          isUserFixture: isUser,
          userIsTeamA: teamsMatch(a, userTeam),
        ),
      );
    }

    final rounds = <TournamentRound, List<TournamentFixture>>{
      TournamentRound.roundOf16: r16,
      TournamentRound.quarterFinal:
          _emptyRound(TournamentRound.quarterFinal, 4),
      TournamentRound.semiFinal: _emptyRound(TournamentRound.semiFinal, 2),
      TournamentRound.finalMatch: _emptyRound(TournamentRound.finalMatch, 1),
    };

    return TournamentBracket(
      userTeam: userTeam,
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
