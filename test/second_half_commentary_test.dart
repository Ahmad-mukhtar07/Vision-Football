import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/ui/second_half_commentary.dart';

void main() {
  group('SecondHalfStartCommentary', () {
    test('keeping 0-0 uses five-needed draw line in pool', () {
      final pool = SecondHalfStartCommentary.pool(
        userShooting: false,
        userScore: 0,
        opponentScore: 0,
      );
      expect(
        pool,
        contains(
          'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-5needed.wav',
        ),
      );
      expect(pool.length, 3);
    });

    test('shooting trailing 0-3 needs four goals', () {
      final pool = SecondHalfStartCommentary.pool(
        userShooting: true,
        userScore: 0,
        opponentScore: 3,
      );
      expect(
        pool,
        contains(
          'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-4needed.wav',
        ),
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
