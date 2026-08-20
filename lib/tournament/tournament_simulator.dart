import 'dart:math';

import '../models/team.dart';
import 'tournament_models.dart';

/// Simulates AI-vs-AI penalty shootouts using team overall ratings.
class TournamentSimulator {
  TournamentSimulator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Resolves [fixture] in place with shootout scores and a winner.
  void resolveFixture(TournamentFixture fixture) {
    final a = fixture.teamA;
    final b = fixture.teamB;
    if (a == null || b == null || fixture.isPlayed) return;

    final result = _simulateShootout(a, b);
    fixture.scoreA = result.$1;
    fixture.scoreB = result.$2;
    fixture.winner = result.$1 > result.$2
        ? a
        : result.$2 > result.$1
            ? b
            : (_random.nextBool() ? a : b);
  }

  (int, int) _simulateShootout(Team a, Team b) {
    var goalsA = 0;
    var goalsB = 0;
    const kicks = 5;

    for (var i = 0; i < kicks; i++) {
      if (_scoresKick(a, b)) goalsA++;
      if (_scoresKick(b, a)) goalsB++;
    }

    if (goalsA == goalsB) {
      while (goalsA == goalsB) {
        if (_scoresKick(a, b)) goalsA++;
        if (_scoresKick(b, a)) goalsB++;
      }
    }

    return (goalsA, goalsB);
  }

  bool _scoresKick(Team shooter, Team keeperSide) {
    final attack = shooter.overall + _random.nextDouble() * 10 - 5;
    final defence = keeperSide.overall + keeperSide.keeper.overall * 0.35;
    final diff = attack - defence;
    final probability = (0.52 + diff * 0.018).clamp(0.18, 0.88);
    return _random.nextDouble() < probability;
  }
}
