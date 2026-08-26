import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/tournament/tournament_models.dart';
import 'package:vision_football/ui/tournament_result_commentary.dart';

void main() {
  group('TournamentResultCommentary', () {
    test('quarter-final win goal line is chosen 66% of the time', () {
      var goalPicks = 0;
      const trials = 6000;
      for (var i = 0; i < trials; i++) {
        final clip = TournamentResultCommentary.pickWin(
          TournamentRound.quarterFinal,
          TournamentWinAction.goal,
          random: Random(i),
        );
        if (clip!.contains('quarters-win-goal')) goalPicks++;
      }
      expect(goalPicks / trials, closeTo(0.66, 0.03));
    });

    test('quarter-final win save line is chosen 66% of the time', () {
      var savePicks = 0;
      const trials = 6000;
      for (var i = 0; i < trials; i++) {
        final clip = TournamentResultCommentary.pickWin(
          TournamentRound.quarterFinal,
          TournamentWinAction.save,
          random: Random(i + 99),
        );
        if (clip!.contains('quarters-win-save')) savePicks++;
      }
      expect(savePicks / trials, closeTo(0.66, 0.03));
    });

    test('quarter-final lose lines split evenly', () {
      var lose1 = 0;
      const trials = 4000;
      for (var i = 0; i < trials; i++) {
        final clip = TournamentResultCommentary.pickLose(
          TournamentRound.quarterFinal,
          random: Random(i + 7),
        );
        if (clip!.contains('quarters-lose1')) lose1++;
      }
      expect(lose1 / trials, closeTo(0.5, 0.05));
    });

    test('final win lines split evenly', () {
      var win1 = 0;
      const trials = 4000;
      for (var i = 0; i < trials; i++) {
        final clip = TournamentResultCommentary.pickWin(
          TournamentRound.finalMatch,
          TournamentWinAction.basic,
          random: Random(i + 3),
        );
        if (clip!.contains('final-win1')) win1++;
      }
      expect(win1 / trials, closeTo(0.5, 0.05));
    });

    test('group stage returns no knockout result lines', () {
      expect(
        TournamentResultCommentary.pickWin(
          TournamentRound.groupStage,
          TournamentWinAction.goal,
        ),
        isNull,
      );
      expect(
        TournamentResultCommentary.pickLose(TournamentRound.groupStage),
        isNull,
      );
    });
  });
}
