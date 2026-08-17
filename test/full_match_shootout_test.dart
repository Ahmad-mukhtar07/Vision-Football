import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/game/full_match_shootout.dart';

void main() {
  group('fullMatchShootoutDecided', () {
    test('half 2 keeping — user 0, opponent scores first goal', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 0,
          opponentScore: 1,
          userRemainingKicks: 0,
          opponentRemainingKicks: 4,
        ),
        isFalse,
      );
    });

    test('half 2 keeping — user 3, opponent cannot catch up', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 3,
          opponentScore: 0,
          userRemainingKicks: 0,
          opponentRemainingKicks: 2,
        ),
        isTrue,
      );
    });

    test('half 2 keeping — still level after two opponent goals', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 2,
          opponentScore: 2,
          userRemainingKicks: 0,
          opponentRemainingKicks: 3,
        ),
        isNull,
      );
    });

    test('half 2 shooting — user takes lead with one goal', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 1,
          opponentScore: 0,
          userRemainingKicks: 4,
          opponentRemainingKicks: 0,
        ),
        isTrue,
      );
    });

    test('half 2 shooting — opponent lead is insurmountable', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 0,
          opponentScore: 4,
          userRemainingKicks: 3,
          opponentRemainingKicks: 0,
        ),
        isFalse,
      );
    });

    test('half 2 shooting — user can still equalise', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 2,
          opponentScore: 4,
          userRemainingKicks: 3,
          opponentRemainingKicks: 0,
        ),
        isNull,
      );
    });

    test('half 2 shooting — user equalises on final kick scenario still open', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 4,
          opponentScore: 5,
          userRemainingKicks: 1,
          opponentRemainingKicks: 0,
        ),
        isNull,
      );
    });

    test('half 2 shooting — user cannot catch 5-0 with one kick left', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 0,
          opponentScore: 5,
          userRemainingKicks: 1,
          opponentRemainingKicks: 0,
        ),
        isFalse,
      );
    });

    test('draw still possible — not decided', () {
      expect(
        fullMatchShootoutDecided(
          userScore: 3,
          opponentScore: 3,
          userRemainingKicks: 2,
          opponentRemainingKicks: 0,
        ),
        isNull,
      );
    });
  });
}
