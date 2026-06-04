import 'dart:async';

import 'package:flutter/material.dart';

import '../game/match_state.dart';
import 'penalty_score_bar.dart';

/// Match-aware HUD with styled top bar and phase animations.
class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.matchStateStream,
    required this.onPausePressed,
  });

  final Stream<MatchState> matchStateStream;
  final VoidCallback onPausePressed;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with TickerProviderStateMixin {
  MatchState _state = const MatchState();
  StreamSubscription<MatchState>? _subscription;

  late final AnimationController _goController;
  late final Animation<double> _goScale;
  late final AnimationController _arrowController;
  late final Animation<double> _arrowOpacity;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;
  late final AnimationController _missFadeController;
  late final Animation<double> _missOpacity;

  Timer? _goFadeTimer;
  bool _showGo = false;

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);
  static const _saveRed = Color(0xFFFF3333);

  @override
  void initState() {
    super.initState();
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _goScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_goController);

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _arrowOpacity = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(_shakeController);

    _missFadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _missOpacity = Tween(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _missFadeController, curve: Curves.easeOut),
    );

    _subscription = widget.matchStateStream.listen(_onMatchState);
  }

  void _onMatchState(MatchState state) {
    if (!mounted) return;

    final wasReady = _state.phase == MatchPhase.readyToKick;
    final wasResult = _state.phase == MatchPhase.resultPause;
    setState(() => _state = state);

    if (state.phase == MatchPhase.readyToKick && !wasReady) {
      _goFadeTimer?.cancel();
      setState(() => _showGo = true);
      _goController.forward(from: 0);
      _goFadeTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showGo = false);
      });
    }
    if (state.phase != MatchPhase.readyToKick) {
      _showGo = false;
    }

    if (state.phase == MatchPhase.resultPause && !wasResult) {
      if (state.lastResult == KickResult.goal) {
        _shakeController.forward(from: 0);
      } else if (state.lastResult == KickResult.miss) {
        _missFadeController.forward(from: 0);
      }
    }

    if (state.phase != MatchPhase.resultPause) {
      _missFadeController.reset();
      _shakeController.reset();
    }
  }

  Shader _gradientShader(double fontSize) {
    return const LinearGradient(
      colors: [_gold, _orange],
    ).createShader(Rect.fromLTWH(0, 0, 200, fontSize * 1.2));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _goFadeTimer?.cancel();
    _goController.dispose();
    _arrowController.dispose();
    _shakeController.dispose();
    _missFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state.phase == MatchPhase.matchOver ||
        _state.phase == MatchPhase.notStarted) {
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
                onPressed: widget.onPausePressed,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 16,
            right: 56,
            child: PenaltyScoreBar(
              teamName: 'YOU',
              spots: _state.penaltySpots.length >= _state.totalKicks
                  ? _state.penaltySpots
                  : PenaltyScoreBar.initialSpots(_state.totalKicks),
            ),
          ),
          if (_state.phase == MatchPhase.runUp) _buildRunUpHint(),
          if (_showGo) _buildGoBanner(),
          if (_state.phase == MatchPhase.resultPause) _buildResultBanner(),
        ],
      ),
    );
  }

  Widget _buildRunUpHint() {
    final shotLabel = _state.shotType == ShotType.freeKick
        ? 'FREE KICK'
        : 'PENALTY';
    final shotColor = _state.shotType == ShotType.freeKick
        ? const Color(0xFF4FC3F7)
        : _gold;

    return Center(
      child: FadeTransition(
        opacity: _arrowOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: shotColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                shotLabel,
                style: TextStyle(
                  color: shotColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Step back and run up',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoBanner() {
    return Center(
      child: ScaleTransition(
        scale: _goScale,
        child: Text(
          'GO!',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = _gradientShader(80)
              ..style = PaintingStyle.fill,
            shadows: const [
              Shadow(blurRadius: 14, color: Colors.black87, offset: Offset(2, 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final result = _state.lastResult;
    if (result == null) return const SizedBox.shrink();

    Widget child;
    switch (result) {
      case KickResult.goal:
        child = AnimatedBuilder(
          animation: _shakeController,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(_shakeOffset.value, 0),
              child: Text(
                'GOAL! ⚽',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()..shader = _gradientShader(60),
                  shadows: const [
                    Shadow(blurRadius: 10, color: Colors.black),
                  ],
                ),
              ),
            );
          },
        );
      case KickResult.saved:
        child = const Text(
          'SAVED! 🧤',
          style: TextStyle(
            color: _saveRed,
            fontSize: 60,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 10, color: Colors.black)],
          ),
        );
      case KickResult.miss:
        child = FadeTransition(
          opacity: _missOpacity,
          child: const Text(
            'MISS!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 50,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
            ),
          ),
        );
    }

    return Center(child: child);
  }
}
