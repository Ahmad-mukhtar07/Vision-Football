import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game_progress_store.dart';
import 'glass_panel.dart';
import 'main_page_sound.dart';

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Explains how many full matches are left before Global Cup unlocks.
Future<void> showTournamentUnlockDialog(
  BuildContext context, {
  required int fullMatchesCompleted,
}) {
  final required = GameProgressStore.tournamentMatchesRequired;
  final remaining =
      GameProgressStore.tournamentMatchesRemaining(fullMatchesCompleted);
  final progress =
      GameProgressStore.tournamentUnlockProgress(fullMatchesCompleted);
  const accent = Color(0xFFC2FF1F);

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: accent,
                size: 36,
              ),
              const SizedBox(height: 14),
              const Text(
                'TOURNAMENT LOCKED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                remaining == 0
                    ? 'Play full matches to unlock Global Cup.'
                    : remaining == 1
                        ? 'Play 1 more full match to unlock Global Cup.'
                        : 'Play $remaining more full matches to unlock Global Cup.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$fullMatchesCompleted / $required full matches',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () {
                    _tap();
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
