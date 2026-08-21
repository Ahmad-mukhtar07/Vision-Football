import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/tournament/tournament_models.dart';
import 'package:vision_football/ui/tournament_start_commentary.dart';

void main() {
  group('TournamentStartCommentary', () {
    test('group stage uses standard opener', () {
      expect(
        TournamentStartCommentary.poolForRound(TournamentRound.groupStage),
        isNull,
      );
    });

    test('quarter final has two clips', () {
      final pool =
          TournamentStartCommentary.poolForRound(TournamentRound.quarterFinal);
      expect(pool, hasLength(2));
      expect(pool!.first, contains('quarters-start'));
    });

    test('semi final has two clips', () {
      final pool =
          TournamentStartCommentary.poolForRound(TournamentRound.semiFinal);
      expect(pool, hasLength(2));
      expect(pool!.first, contains('semis-start'));
    });

    test('final has two clips', () {
      final pool =
          TournamentStartCommentary.poolForRound(TournamentRound.finalMatch);
      expect(pool, hasLength(2));
      expect(pool!.first, contains('final-start'));
    });
  });
}
