import 'dart:ui';

import 'kick_event.dart';

/// Emitted when a ball flight ends (goal, save, or miss).
class GoalEvent {
  const GoalEvent({
    required this.isGoal,
    required this.isSave,
    required this.kickThatScored,
    required this.ballLandingPosition,
    required this.timestamp,
  });

  final bool isGoal;
  final bool isSave;
  final KickEvent kickThatScored;
  final Offset ballLandingPosition;
  final DateTime timestamp;
}
