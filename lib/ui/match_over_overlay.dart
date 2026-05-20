import 'package:flutter/material.dart';

import '../game/match_state.dart';

/// Full-time summary after all penalties are taken.
class MatchOverOverlay extends StatelessWidget {
  const MatchOverOverlay({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onChangeFoot,
  });

  final MatchState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onChangeFoot;

  String _rating(int goals, int total) {
    if (goals >= total) return 'Perfect! 🏆';
    if (goals >= total - 1) return 'Clinical! ⚽';
    if (goals >= 3) return 'Decent 👍';
    return 'Keep practicing 💪';
  }

  @override
  Widget build(BuildContext context) {
    final goals = state.goalsScored;
    final total = state.totalKicks;

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FULL TIME',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$goals / $total goals',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _rating(goals, total),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 260,
                  child: FilledButton(
                    onPressed: onPlayAgain,
                    child: const Text('Play Again'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 260,
                  child: OutlinedButton(
                    onPressed: onChangeFoot,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('Change Foot'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
