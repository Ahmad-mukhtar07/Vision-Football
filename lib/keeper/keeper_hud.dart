import 'package:flutter/material.dart';

import '../ui/penalty_score_bar.dart';
import 'keeper_layout_constants.dart';
import 'keeper_match_state.dart';

/// Top score bar + center status banner for goalkeeper mode.
class KeeperHud extends StatelessWidget {
  const KeeperHud({
    super.key,
    required this.state,
    required this.onPausePressed,
    this.calibrationSecondsLeft = 0,
    this.calibrationWaitingForHands = false,
  });

  final KeeperMatchState state;
  final VoidCallback onPausePressed;
  final int calibrationSecondsLeft;
  final bool calibrationWaitingForHands;

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
              child: PenaltyScoreBar(
                teamName: 'OPPONENT',
                spots: state.penaltySpots.length >= state.totalShots
                    ? state.penaltySpots
                    : PenaltyScoreBar.initialSpots(state.totalShots),
              ),
            ),
          if (state.phase == KeeperPhase.calibrating)
            _buildCalibrationBanner(),
          if (state.phase == KeeperPhase.waitingForReady) ...[
            _buildSpotLabel(state.spotType),
            _buildHint('GET READY'),
          ],
          if (state.phase == KeeperPhase.shotIncoming)
            _buildHint('INCOMING!', color: _gold),
          if (state.phase == KeeperPhase.resultPause) _buildResultBanner(),
        ],
      ),
    );
  }

  Widget _buildCalibrationBanner() {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
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
                  'SHOW YOUR UPPER BODY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Line up with the outline,\nthen raise both hands',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (calibrationWaitingForHands)
                  const Icon(
                    Icons.back_hand_outlined,
                    color: Colors.white54,
                    size: 48,
                  )
                else
                  Text(
                    '$calibrationSecondsLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (calibrationWaitingForHands) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Waiting for both hands…',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotLabel(KeeperSpotType spot) {
    final isFreeKick = spot == KeeperSpotType.freeKick;
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFreeKick
                  ? const Color(0xFF42A5F5)
                  : const Color(0xFFFFD700),
              width: 1.5,
            ),
          ),
          child: Text(
            isFreeKick ? 'FREE KICK' : 'PENALTY',
            style: TextStyle(
              color: isFreeKick
                  ? const Color(0xFF42A5F5)
                  : const Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint(String text, {Color color = Colors.white}) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
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
      ),
    );
  }

  Widget _buildResultBanner() {
    final result = state.lastResult;
    if (result == null) return const SizedBox.shrink();
    final saved = result == KeeperShotResult.saved;
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            saved ? 'SAVED! 🧤' : 'GOAL CONCEDED!',
            style: TextStyle(
              color: saved ? _saveGreen : _goalRed,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(blurRadius: 10, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
