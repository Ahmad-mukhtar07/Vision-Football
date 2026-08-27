import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/keeper_stadium.dart';
import '../data/player_stats_store.dart';
import '../data/stadium_unlock_store.dart';
import 'glass_panel.dart';
import 'main_page_sound.dart';
import 'rewarded_ad_helpers.dart';
import '../data/stadium_ad_unlock_store.dart';

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Explains how to unlock a stadium location.
Future<void> showStadiumUnlockDialog(
  BuildContext context, {
  required KeeperStadiumLocation location,
  required PlayerStats stats,
}) {
  const accent = Color(0xFFC2FF1F);
  const cyan = Color(0xFF00E5FF);
  final requirement = StadiumUnlockStore.unlockRequirement(location, stats);
  final progress = StadiumUnlockStore.progressHint(location, stats);

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
              Icon(
                Icons.lock_outline_rounded,
                color: accent.withValues(alpha: 0.95),
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                '${location.label.toUpperCase()} LOCKED',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                requirement,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                Text(
                  progress,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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

/// Prompts the player to watch a rewarded ad before using a new stadium.
Future<bool> showStadiumAdUnlockDialog(
  BuildContext context, {
  required KeeperStadiumLocation location,
}) async {
  const accent = Color(0xFFC2FF1F);

  final watch = await showDialog<bool>(
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
              Icon(
                Icons.play_circle_outline_rounded,
                color: accent.withValues(alpha: 0.95),
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                'UNLOCK ${location.label.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You met the requirements for ${location.label}! '
                'Watch a short ad to start using this stadium.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () {
                    _tap();
                    Navigator.of(ctx).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text(
                    'Watch ad',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _tap();
                  Navigator.of(ctx).pop(false);
                },
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (watch != true || !context.mounted) return false;

  final earned = await watchRewardedAd(context);
  if (!earned) return false;

  await StadiumAdUnlockStore.markWatched(location);
  return true;
}
