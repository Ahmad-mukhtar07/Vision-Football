import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Explains how the group stage works.
Future<void> showGroupStageInfoDialog(BuildContext context) async {
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
            const Text(
              'GROUP STAGE',
              style: TextStyle(
                color: _Pal.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Each team plays every other team in its group once — three '
              'matches in all.\n\n'
              'Every match is a five-kick shootout per side. You earn '
              '3 points for a win, 1 for a draw, and 0 for a loss. '
              'Teams level on points are ranked by goal difference.\n\n'
              'The top two teams from each group advance to the '
              'quarter-finals.',
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
