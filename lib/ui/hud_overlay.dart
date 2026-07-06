import 'dart:async';

import 'package:flutter/material.dart';

import '../game/match_state.dart';
import '../models/team.dart';
import 'game_play_sound.dart';
import 'match_scoreboard.dart';
import 'match_player_labels.dart';
import 'penalty_score_bar.dart';

/// Match-aware HUD with styled top bar and phase animations.
class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.initialMatchState,
    required this.matchStateStream,
    required this.kickingFootVisibleStream,
    required this.onPausePressed,
    this.userTeam,
    this.opponentTeam,
    this.opponentScore,
  });

  /// Current match snapshot — the stream does not replay the last value.
  final MatchState initialMatchState;
  final Stream<MatchState> matchStateStream;
  final Stream<bool> kickingFootVisibleStream;
  final VoidCallback onPausePressed;

  /// Full Match teams; when both are set the dual-flag scoreboard is shown.
  final Team? userTeam;
  final Team? opponentTeam;

  /// Opponent's completed goals (from the keeping half), or null if not played.
  final int? opponentScore;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with TickerProviderStateMixin {
  MatchState _state = const MatchState();
  StreamSubscription<MatchState>? _subscription;
  StreamSubscription<bool>? _footVisibleSub;
  bool _kickingFootVisible = true;

  late final AnimationController _goController;
  late final Animation<double> _goScale;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;
  late final AnimationController _missFadeController;
  late final Animation<double> _missOpacity;

  Timer? _goFadeTimer;
  bool _showGo = false;

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);
  static const _saveRed = Color(0xFFFF3333);
  static const _waitCyan = Color(0xFF00E5FF);
  static const _waitGreen = Color(0xFF1FE07A);

  bool get _showWaitBanner =>
      _state.phase == MatchPhase.runUp &&
      _state.kicksTaken == 0 &&
      !_showGo;

  bool get _showFindingFootBanner =>
      _state.phase == MatchPhase.runUp &&
      _state.kicksTaken > 0 &&
      !_kickingFootVisible;

  @override
  void initState() {
    super.initState();
    _state = widget.initialMatchState;
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
    _footVisibleSub = widget.kickingFootVisibleStream.listen((visible) {
      if (!mounted) return;
      setState(() => _kickingFootVisible = visible);
    });
  }

  void _onMatchState(MatchState state) {
    if (!mounted) return;

    final wasReady = _state.phase == MatchPhase.readyToKick;
    final wasResult = _state.phase == MatchPhase.resultPause;
    setState(() => _state = state);

    if (state.phase == MatchPhase.readyToKick && !wasReady) {
      GamePlaySound.playStartWhistle();
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
      } else       if (state.lastResult == KickResult.miss) {
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

  Shader _cyanGradientShader(double fontSize, {double width = 320}) {
    return const LinearGradient(
      colors: [_waitCyan, _waitGreen],
    ).createShader(Rect.fromLTWH(0, 0, width, fontSize * 1.2));
  }

  Widget _buildCyanGradientBanner(
    String text, {
    required double fontSize,
    double letterSpacing = 1.2,
    double shaderWidth = 320,
  }) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: letterSpacing,
          foreground: Paint()
            ..shader = _cyanGradientShader(fontSize, width: shaderWidth)
            ..style = PaintingStyle.fill,
          shadows: const [
            Shadow(blurRadius: 14, color: Colors.black87, offset: Offset(2, 3)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _footVisibleSub?.cancel();
    _goFadeTimer?.cancel();
    _goController.dispose();
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
            left: 12,
            right: 64,
            child: (widget.userTeam != null && widget.opponentTeam != null)
                ? MatchScoreboard(
                    userTeam: widget.userTeam!,
                    opponentTeam: widget.opponentTeam!,
                    userIsShooting: true,
                    liveSpots: _state.penaltySpots,
                    totalKicks: _state.totalKicks,
                    otherSideScore: widget.opponentScore,
                  )
                : PenaltyScoreBar(
                    teamName: 'YOU',
                    spots: _state.penaltySpots.length >= _state.totalKicks
                        ? _state.penaltySpots
                        : PenaltyScoreBar.initialSpots(_state.totalKicks),
                  ),
          ),
          if (_showFindingFootBanner)
            _buildFindingFootBanner()
          else if (_showWaitBanner)
            _buildWaitBanner(),
          if (_showGo) _buildGoBanner(),
          if (_state.phase == MatchPhase.resultPause) _buildResultBanner(),
          if (widget.userTeam != null && widget.opponentTeam != null)
            Builder(
              builder: (context) {
                final names = MatchPlayerLabelNames.forShootingHalf(
                  userTeam: widget.userTeam!,
                  opponentTeam: widget.opponentTeam!,
                  state: _state,
                );
                return MatchPlayerLabels(
                  leftName: names.left,
                  rightName: names.right,
                  leftIsKeeper: names.leftIsKeeper,
                  rightIsKeeper: names.rightIsKeeper,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWaitBanner() {
    return _buildCyanGradientBanner(
      'WAIT',
      fontSize: 80,
      letterSpacing: 6,
      shaderWidth: 260,
    );
  }

  Widget _buildFindingFootBanner() {
    return _buildCyanGradientBanner(
      'Finding your foot',
      fontSize: 48,
      letterSpacing: 1.0,
      shaderWidth: 420,
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
