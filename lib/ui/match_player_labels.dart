import 'package:flutter/material.dart';

import '../game/match_state.dart';
import '../keeper/keeper_match_state.dart';
import '../models/team.dart';

/// Bottom-corner player name badges for Full Match gameplay.
class MatchPlayerLabels extends StatelessWidget {
  const MatchPlayerLabels({
    super.key,
    required this.leftName,
    required this.rightName,
    this.leftIsKeeper = false,
    this.rightIsKeeper = false,
  });

  final String leftName;
  final String rightName;
  final bool leftIsKeeper;
  final bool rightIsKeeper;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 12,
          child: _NameBadge(
            name: leftName,
            isKeeper: leftIsKeeper,
            alignRight: false,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _NameBadge(
            name: rightName,
            isKeeper: rightIsKeeper,
            alignRight: true,
          ),
        ),
      ],
    );
  }
}

class _NameBadge extends StatelessWidget {
  const _NameBadge({
    required this.name,
    required this.isKeeper,
    required this.alignRight,
  });

  final String name;
  final bool isKeeper;
  final bool alignRight;

  static const _cyan = Color(0xFF00E5FF);
  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final accent = alignRight ? _orange : _cyan;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.44,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(alignRight ? 0.08 : -0.08, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(name),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment:
                alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isKeeper)
                Text(
                  'GK',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves which names to show for the current kick in each half.
class MatchPlayerLabelNames {
  MatchPlayerLabelNames._();

  static int _kickIndex({
    required int completed,
    required bool isResultPause,
  }) {
    final index = isResultPause ? completed - 1 : completed;
    return index < 0 ? 0 : index;
  }

  /// User is shooting: left cycles through user shooters, right = opp keeper.
  static ({String left, String right, bool leftIsKeeper, bool rightIsKeeper})
      forShootingHalf({
    required Team userTeam,
    required Team opponentTeam,
    required MatchState state,
  }) {
    final index = _kickIndex(
      completed: state.kicksTaken,
      isResultPause: state.phase == MatchPhase.resultPause,
    ).clamp(0, userTeam.shooters.length - 1);
    return (
      left: userTeam.shooters[index].name,
      right: opponentTeam.keeper.name,
      leftIsKeeper: false,
      rightIsKeeper: true,
    );
  }

  /// User is keeping: left = user keeper, right cycles through opp shooters.
  static ({String left, String right, bool leftIsKeeper, bool rightIsKeeper})
      forKeeperHalf({
    required Team userTeam,
    required Team opponentTeam,
    required KeeperMatchState state,
  }) {
    final index = _kickIndex(
      completed: state.shotsTaken,
      isResultPause: state.phase == KeeperPhase.resultPause,
    ).clamp(0, opponentTeam.shooters.length - 1);
    return (
      left: userTeam.keeper.name,
      right: opponentTeam.shooters[index].name,
      leftIsKeeper: true,
      rightIsKeeper: false,
    );
  }
}
