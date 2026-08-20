import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/ui/second_half_commentary.dart';

void main() {
  group('SecondHalfStartCommentary', () {
    test('keeping 0-0 resolves five-needed draw line', () {
      expect(
        SecondHalfStartCommentary.specificClip(
          userShooting: false,
          userScore: 0,
          opponentScore: 0,
        ),
        'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-5needed.wav',
      );
    });

    test('shooting trailing 0-3 needs four goals', () {
      expect(
        SecondHalfStartCommentary.specificClip(
          userShooting: true,
          userScore: 0,
          opponentScore: 3,
        ),
        'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-4needed.wav',
      );
    });

    test('weighted pick prefers situational line on high roll', () {
      final clip = SecondHalfStartCommentary.pick(
        userShooting: true,
        userScore: 0,
        opponentScore: 3,
        random: _FixedRandom(0.7),
      );
      expect(
        clip,
        'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-4needed.wav',
      );
    });

    test('weighted pick uses first general opener on low roll', () {
      final clip = SecondHalfStartCommentary.pick(
        userShooting: false,
        userScore: 0,
        opponentScore: 0,
        random: _FixedRandom(0.1),
      );
      expect(
        clip,
        'sounds/commentary/second-half/general/comm-2h-start1.wav',
      );
    });

    test('weighted pick uses second general opener on mid roll', () {
      final clip = SecondHalfStartCommentary.pick(
        userShooting: false,
        userScore: 0,
        opponentScore: 0,
        random: _FixedRandom(0.3),
      );
      expect(
        clip,
        'sounds/commentary/second-half/general/comm-2h-start2.wav',
      );
    });
  });

  group('SecondHalfResultCommentary', () {
    test('goal levels when tied with kicks left', () {
      final pool = SecondHalfResultCommentary.goalPool(
        const SecondHalfCommentarySnapshot(
          userScore: 2,
          opponentScore: 2,
          userRemainingKicks: 2,
          opponentRemainingKicks: 0,
          isLastKickOfHalf: false,
        ),
      );
      expect(pool, isNotNull);
      expect(pool!.first, contains('goal-level'));
    });

    test('miss lost when user cannot reach opponent', () {
      final pool = SecondHalfResultCommentary.missPool(
        const SecondHalfCommentarySnapshot(
          userScore: 1,
          opponentScore: 4,
          userRemainingKicks: 1,
          opponentRemainingKicks: 0,
          isLastKickOfHalf: false,
        ),
      );
      expect(pool!.first, contains('miss-lost'));
    });

    test('save wins when user lead is insurmountable', () {
      final pool = SecondHalfResultCommentary.savePool(
        const SecondHalfCommentarySnapshot(
          userScore: 4,
          opponentScore: 2,
          userRemainingKicks: 0,
          opponentRemainingKicks: 1,
          isLastKickOfHalf: false,
        ),
      );
      expect(pool!.first, contains('save-win'));
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._next);

  final double _next;

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => _next;

  @override
  bool nextBool() => false;
}
