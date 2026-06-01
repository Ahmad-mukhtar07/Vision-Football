import 'package:flutter/material.dart';

import 'keeper_match_state.dart';

/// Top score bar + center status banner for goalkeeper mode.
class KeeperHud extends StatelessWidget {
  const KeeperHud({
    super.key,
    required this.state,
    required this.onPausePressed,
    this.calibrationSecondsLeft = 0,
  });

  final KeeperMatchState state;
  final VoidCallback onPausePressed;
  final int calibrationSecondsLeft;

  static const _saveGreen = Color(0xFF7CFF7C);
  static const _goalRed = Color(0xFFFF3333);
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    if (state.phase == KeeperPhase.matchOver ||
        state.phase == KeeperPhase.notStarted) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.pause_rounded, color: Colors.white),
                iconSize: 28,
                tooltip: 'Pause',
                onPressed: onPausePressed,
              ),
            ),
          ),
          if (state.phase != KeeperPhase.calibrating)
          Positioned(
            top: 8,
            left: 16,
            right: 56,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    '🥅 ${state.shotsTaken} / ${state.totalShots}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '🧤 ${state.saves}',
                    style: const TextStyle(
                      color: _saveGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '⚽ ${state.goalsConceded}',
                    style: const TextStyle(
                      color: _goalRed,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.phase == KeeperPhase.calibrating)
            _buildCalibrationBanner(),
          if (state.phase == KeeperPhase.waitingForReady) _buildHint('GET READY'),
          if (state.phase == KeeperPhase.shotIncoming)
            _buildHint('INCOMING!', color: _gold),
          if (state.phase == KeeperPhase.resultPause) _buildResultBanner(),
        ],
      ),
    );
  }

  Widget _buildCalibrationBanner() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'POSITION YOURSELF',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stand in front of the camera\nand raise both hands',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$calibrationSecondsLeft',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(String text, {Color color = Colors.white}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final result = state.lastResult;
    if (result == null) return const SizedBox.shrink();
    final saved = result == KeeperShotResult.saved;
    return Center(
      child: Text(
        saved ? 'SAVED! 🧤' : 'GOAL CONCEDED!',
        style: TextStyle(
          color: saved ? _saveGreen : _goalRed,
          fontSize: 50,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(blurRadius: 10, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
