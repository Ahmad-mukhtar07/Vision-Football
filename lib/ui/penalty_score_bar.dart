import 'package:flutter/material.dart';

/// Outcome of a single penalty in the shoot-out strip.
enum PenaltySpotStatus {
  pending,
  scored,
  missed,
}

/// Shared top score bar: team name + penalty spot indicators.
class PenaltyScoreBar extends StatelessWidget {
  const PenaltyScoreBar({
    super.key,
    required this.teamName,
    required this.spots,
  });

  final String teamName;
  final List<PenaltySpotStatus> spots;

  static List<PenaltySpotStatus> initialSpots(int count) =>
      List.filled(count, PenaltySpotStatus.pending, growable: false);

  static const Color _pendingGray = Color(0xFF6B6B6B);
  static const Color _scoredGreen = Color(0xFF7CFF7C);
  static const Color _missedRed = Color(0xFFFF3333);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            teamName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < spots.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _SpotDot(status: spots[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotDot extends StatelessWidget {
  const _SpotDot({required this.status});

  final PenaltySpotStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PenaltySpotStatus.pending => PenaltyScoreBar._pendingGray,
      PenaltySpotStatus.scored => PenaltyScoreBar._scoredGreen,
      PenaltySpotStatus.missed => PenaltyScoreBar._missedRed,
    };

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: status == PenaltySpotStatus.pending
            ? Border.all(color: Colors.white24, width: 1)
            : null,
        boxShadow: status != PenaltySpotStatus.pending
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}
