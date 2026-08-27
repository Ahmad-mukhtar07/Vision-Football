import 'package:flutter/material.dart';

import '../services/ad_service.dart';

/// Shows a rewarded ad and returns true only if the user earned the reward.
Future<bool> watchRewardedAd(BuildContext context) async {
  if (!AdService.instance.isRewardedReady) {
    _showAdUnavailable(context);
    return false;
  }

  final earned = await AdService.instance.showRewardedAndWaitForReward();
  if (!context.mounted) return earned;

  if (!earned) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Watch the full ad to earn your reward.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }
  return earned;
}

void _showAdUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Ad loading — try again in a moment.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
