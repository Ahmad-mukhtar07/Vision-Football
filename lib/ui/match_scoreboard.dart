import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../models/team.dart';
import 'penalty_score_bar.dart';

/// Full Match top scoreboard: both team flags pinned to the screen edges with
/// the live shooter's penalty indicators next to their flag, and the other
/// team showing only its running goal tally (or a dash before its turn).
///
/// - User flag sits on the left; opponent flag on the right (beside the pause
///   button, which the host HUD positions separately).
/// - When the user shoots, their dots fill left -> right from their flag.
/// - When the opponent shoots, dots sit to the left of their flag and fill
///   right -> left (kick 1 nearest the flag, later kicks extending leftward).
class MatchScoreboard extends StatelessWidget {
  const MatchScoreboard({
    super.key,
    required this.userTeam,
    required this.opponentTeam,
    required this.userIsShooting,
    required this.liveSpots,
    required this.totalKicks,
    required this.otherSideScore,
  });

  final Team userTeam;
  final Team opponentTeam;

  /// True during the shooting half (live side = user, left), false during the
  /// keeping half (live side = opponent, right).
  final bool userIsShooting;

  /// Penalty spots for whichever side is currently taking kicks.
  final List<PenaltySpotStatus> liveSpots;
  final int totalKicks;

  /// Completed goals of the non-live side, or null if they haven't played yet.
  final int? otherSideScore;

  @override
  Widget build(BuildContext context) {
    final spots = liveSpots.length >= totalKicks
        ? liveSpots
        : PenaltyScoreBar.initialSpots(totalKicks);

    final Widget leftContent = userIsShooting
        ? _Dots(spots: spots, fillFromRight: false)
        : _ScoreText(value: otherSideScore);
    final Widget rightContent = userIsShooting
        ? _ScoreText(value: otherSideScore)
        : _Dots(spots: spots, fillFromRight: true);

    // Pin each pill to its screen edge so dots never get squeezed under the
    // flag or trigger horizontal overflow stripes.
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SidePill(
                  team: userTeam,
                  flagOnLeft: true,
                  child: leftContent,
                ),
                const SizedBox(width: 12),
                _SidePill(
                  team: opponentTeam,
                  flagOnLeft: false,
                  child: rightContent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SidePill extends StatelessWidget {
  const _SidePill({
    required this.team,
    required this.flagOnLeft,
    required this.child,
  });

  final Team team;
  final bool flagOnLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flag = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CountryFlag.fromCountryCode(
        team.countryCode,
        theme: const ImageTheme(width: 28, height: 19),
      ),
    );

    // Opponent live dots always sit to the LEFT of their flag so results stay
    // visible; user live dots sit to the RIGHT of their flag.
    final children = flagOnLeft
        ? [flag, const SizedBox(width: 6), child]
        : [child, const SizedBox(width: 6), flag];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.spots, required this.fillFromRight});

  final List<PenaltySpotStatus> spots;

  /// When true, kick 1 is nearest the flag (rightmost dot in the row) and later
  /// kicks extend leftward.
  final bool fillFromRight;

  static const Color _pendingGray = Color(0xFF6B6B6B);
  static const Color _scoredGreen = Color(0xFF7CFF7C);
  static const Color _missedRed = Color(0xFFFF3333);

  @override
  Widget build(BuildContext context) {
    // fillFromRight: display oldest kick on the far left, newest next to flag.
    final ordered =
        fillFromRight ? spots.reversed.toList(growable: false) : spots;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          _dot(ordered[i]),
        ],
      ],
    );
  }

  Widget _dot(PenaltySpotStatus status) {
    final color = switch (status) {
      PenaltySpotStatus.pending => _pendingGray,
      PenaltySpotStatus.scored => _scoredGreen,
      PenaltySpotStatus.missed => _missedRed,
    };
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: status == PenaltySpotStatus.pending
            ? Border.all(color: Colors.white24, width: 1)
            : null,
        boxShadow: status != PenaltySpotStatus.pending
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 4)]
            : null,
      ),
    );
  }
}

class _ScoreText extends StatelessWidget {
  const _ScoreText({required this.value});

  /// Null renders as a dash (side has not taken its penalties yet).
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value == null ? '-' : '$value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}
