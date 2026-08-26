import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tournament/tournament_models.dart';
import '../main_page_sound.dart';

class _Pal {
  const _Pal._();
  static const cyan = Color(0xFF00E5FF);
  static const lime = Color(0xFFC2FF1F);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// App-styled yes/no confirmation for tournament actions.
Future<bool> showTournamentConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Proceed',
  String cancelLabel = 'Cancel',
}) async {
  _tap();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF15102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _Pal.cyan.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _Pal.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _tap();
                      Navigator.of(ctx).pop(false);
                    },
                    child: Text(
                      cancelLabel.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _Pal.lime.withValues(alpha: 0.18),
                      foregroundColor: _Pal.lime,
                      side: BorderSide(color: _Pal.lime.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _tap();
                      Navigator.of(ctx).pop(true);
                    },
                    child: Text(
                      confirmLabel.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Explains how a tournament round works.
Future<void> showTournamentRoundInfoDialog(
  BuildContext context,
  TournamentRound round,
) async {
  final content = _roundInfoContent(round);
  _tap();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF15102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _Pal.cyan.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                color: _Pal.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _tap();
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'GOT IT',
                  style: TextStyle(
                    color: _Pal.lime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Explains how the group stage works.
Future<void> showGroupStageInfoDialog(BuildContext context) =>
    showTournamentRoundInfoDialog(context, TournamentRound.groupStage);

class _RoundInfoContent {
  const _RoundInfoContent({required this.title, required this.body});

  final String title;
  final String body;
}

_RoundInfoContent _roundInfoContent(TournamentRound round) {
  switch (round) {
    case TournamentRound.groupStage:
      return const _RoundInfoContent(
        title: 'GROUP STAGE',
        body:
            'Each team plays every other team in its group twice — six '
            'matches in all.\n\n'
            'Every match is a five-kick shootout per side. You earn '
            '3 points for a win, 1 for a draw, and 0 for a loss. '
            'Teams level on points are ranked by goal difference.\n\n'
            'The top two teams from each group advance to the '
            'quarter-finals.',
      );
    case TournamentRound.quarterFinal:
      return const _RoundInfoContent(
        title: 'QUARTER-FINALS',
        body:
            'Eight teams remain — the top two from every group. Each tie is '
            'a single Full Match knockout.\n\n'
            'You shoot five penalties in one half and keep five in the '
            'other. A coin toss decides which role you take first. Win to '
            'reach the semi-finals; lose and you are out of the Global Cup.\n\n'
            'Draws do not count — replay the match until there is a winner. '
            'Teams from the same group cannot be paired in this round.\n\n'
            'Matches are played in Greece on Easy difficulty.',
      );
    case TournamentRound.semiFinal:
      return const _RoundInfoContent(
        title: 'SEMI-FINALS',
        body:
            'Four teams remain. Each tie is a winner-takes-all Full Match — '
            'the same five-kick shootout format as the quarter-finals.\n\n'
            'Win to reach the Global Cup Final. Lose and your tournament '
            'run is over.\n\n'
            'Draws must be replayed until one team wins. Rivals from the '
            'same group still cannot meet in this round.\n\n'
            'Matches are played in Spain on Moderate difficulty.',
      );
    case TournamentRound.finalMatch:
      return const _RoundInfoContent(
        title: 'FINAL',
        body:
            'Two teams, one trophy. The Global Cup Final uses the same Full '
            'Match shootout format — five kicks as the shooter and five as '
            'the keeper.\n\n'
            'Win the match to become Global Cup champion. Lose and the '
            'other nation lifts the trophy.\n\n'
            'If the score is level after both halves, replay the match until '
            'someone wins.\n\n'
            'The Final is played in the USA on Hard difficulty.',
      );
  }
}
