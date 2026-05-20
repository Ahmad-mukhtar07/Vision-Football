import 'dart:async';

import 'package:flutter/material.dart';

import '../game/match_state.dart';

/// Match-aware HUD: kick counter, phase instructions, GO animation, results.
class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.matchStateStream,
  });

  final Stream<MatchState> matchStateStream;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with SingleTickerProviderStateMixin {
  MatchState _state = const MatchState();
  StreamSubscription<MatchState>? _subscription;
  late final AnimationController _goController;
  late final Animation<double> _goScale;
  Timer? _goFadeTimer;
  bool _showGo = false;

  @override
  void initState() {
    super.initState();
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _goScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_goController);

    _subscription = widget.matchStateStream.listen(_onMatchState);
  }

  void _onMatchState(MatchState state) {
    if (!mounted) return;

    final wasReady = _state.phase == MatchPhase.readyToKick;
    setState(() => _state = state);

    if (state.phase == MatchPhase.readyToKick && !wasReady) {
      _goFadeTimer?.cancel();
      setState(() => _showGo = true);
      _goController.forward(from: 0);
      _goFadeTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showGo = false);
      });
    }
  }

  String? _centerInstruction() {
    switch (_state.phase) {
      case MatchPhase.runUp:
        return 'Step back and run up';
      case MatchPhase.readyToKick:
        return null;
      case MatchPhase.ballInFlight:
        return null;
      case MatchPhase.resultPause:
        return switch (_state.lastResult) {
          KickResult.goal => 'GOAL! ⚽',
          KickResult.saved => 'SAVED! 🧤',
          KickResult.miss => 'MISS!',
          null => null,
        };
      case MatchPhase.notStarted:
      case MatchPhase.matchOver:
        return null;
    }
  }

  Color _centerColor() {
    if (_state.phase != MatchPhase.resultPause) {
      return Colors.white;
    }
    return switch (_state.lastResult) {
      KickResult.goal => Colors.yellow,
      KickResult.saved => Colors.redAccent,
      KickResult.miss => Colors.white,
      null => Colors.white,
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _goFadeTimer?.cancel();
    _goController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state.phase == MatchPhase.matchOver ||
        _state.phase == MatchPhase.notStarted) {
      return const SizedBox.shrink();
    }

    final centerText = _centerInstruction();

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚽ ${_state.kicksTaken} / ${_state.totalKicks}',
                  style: _topBarStyle,
                ),
                Text(
                  'GOALS: ${_state.goalsScored}',
                  style: _topBarStyle,
                ),
                Text(
                  'SAVES: ${_state.savesMade}',
                  style: _topBarStyle,
                ),
              ],
            ),
          ),
          if (_state.phase == MatchPhase.readyToKick && _showGo)
            Center(
              child: ScaleTransition(
                scale: _goScale,
                child: const Text(
                  'GO!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(blurRadius: 12, color: Colors.black),
                    ],
                  ),
                ),
              ),
            )
          else if (centerText != null)
            Center(
              child: Text(
                centerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _centerColor(),
                  fontSize: _state.phase == MatchPhase.resultPause ? 48 : 26,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _topBarStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
  );
}
