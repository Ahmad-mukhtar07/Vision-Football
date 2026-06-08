import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/goal_event.dart';
import '../models/kick_event.dart';
import '../ui/commentary_sound.dart';
import '../ui/game_play_sound.dart';
import 'components/ball_component.dart';
import 'components/goal_component.dart';
import 'components/scene_background_component.dart';
import 'goalkeeper_component.dart';
import 'layout_constants.dart';
import 'match_state.dart';

/// Flame layer: sky/pitch placeholders, goal, GK, and ball over the camera feed.
class VisionFootballGame extends FlameGame {
  VisionFootballGame({
    required Stream<KickEvent> kickStream,
    required this.matchController,
    this.onBallBecameIdle,
  }) : _kickStream = kickStream;

  final Stream<KickEvent> _kickStream;
  final MatchController matchController;
  final VoidCallback? onBallBecameIdle;

  final StreamController<GoalEvent> _goalController =
      StreamController<GoalEvent>.broadcast();

  Stream<GoalEvent> get goalEvents => _goalController.stream;

  bool get canAcceptKick => _ball.isReadyForKick;

  late GameLayout _layout;
  late final SkyBackgroundComponent _sky;
  late final PitchBackgroundComponent _pitch;
  late final GoalComponent _goal;
  late final GoalkeeperComponent _goalkeeper;
  late final BallComponent _ball;
  StreamSubscription<KickEvent>? _kickSubscription;
  StreamSubscription<MatchState>? _matchSubscription;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _layout = GameLayout(size);
    _sky = SkyBackgroundComponent(layout: _layout);
    _pitch = PitchBackgroundComponent(layout: _layout);
    _goal = GoalComponent(layout: _layout);
    _goalkeeper = GoalkeeperComponent(layout: _layout);
    _ball = BallComponent(
      goal: _goal,
      goalkeeper: _goalkeeper,
      layout: _layout,
      onFlightEnd: _onFlightEnd,
      onBecameIdle: onBallBecameIdle,
    );

    await add(_sky);
    await add(_pitch);
    await add(_goal);
    await add(_goalkeeper);
    await add(_ball);

    _kickSubscription = _kickStream.listen(_onKick);
    _matchSubscription = matchController.stateStream.listen(_onMatchState);
    // Apply current phase if the match started before onLoad finished.
    _onMatchState(matchController.state);
  }

  void _onKick(KickEvent event) {
    if (!_ball.isReadyForKick) {
      debugPrint('[KD] strike ignored (ball busy)');
      return;
    }
    debugPrint('[KD] >>> BALL SHOT <<<');
    GamePlaySound.playBallKick();
    matchController.onBallInFlight();
    _ball.strike(event);
    _goalkeeper.reactToKick(event);
  }

  void _onFlightEnd({
    required bool isGoal,
    required bool isSave,
    required KickEvent kick,
    required Offset landingPosition,
  }) {
    final result = isGoal
        ? KickResult.goal
        : isSave
            ? KickResult.saved
            : KickResult.miss;

    // Commentary plays on top of the effect/crowd sounds. The clip length
    // tells us how long to keep the ball at its result spot and hold the
    // match before the next run-up.
    Duration commentary;
    if (isSave) {
      GamePlaySound.playSave();
      GamePlaySound.playBoo();
      commentary = CommentarySound.playSave(_classifySave(landingPosition));
    } else if (isGoal) {
      commentary = CommentarySound.playGoal(
        placement: _classifyPlacement(landingPosition),
        isSlow: kick.kickPower < 0.35,
      );
      // Fade the longer cheer out to finish with the commentary line.
      GamePlaySound.playGoalCheer(fadeOutAlignedTo: commentary);
    } else {
      GamePlaySound.playBoo();
      commentary = CommentarySound.playMiss();
    }

    // Small tail so the ball/banner doesn't vanish the instant audio ends.
    final hold = commentary + const Duration(milliseconds: 500);
    _ball.holdResultFor(hold.inMilliseconds / 1000.0);
    matchController.kickTaken(result, holdFor: hold);

    _goalController.add(
      GoalEvent(
        isGoal: isGoal,
        isSave: isSave,
        kickThatScored: kick,
        ballLandingPosition: landingPosition,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Normalized landing position (0..1) within the visible goal mouth.
  Offset _normalizedInGoal(Offset landing) {
    final r = _goal.effectiveGoalRect;
    final nx = ((landing.dx - r.left) / r.width).clamp(0.0, 1.0);
    final ny = ((landing.dy - r.top) / r.height).clamp(0.0, 1.0);
    return Offset(nx, ny);
  }

  GoalPlacement _classifyPlacement(Offset landing) {
    final n = _normalizedInGoal(landing);
    final corner = n.dx < 0.30 || n.dx > 0.70;
    if (corner) {
      return n.dy < 0.50
          ? GoalPlacement.topCorner
          : GoalPlacement.bottomCorner;
    }
    return GoalPlacement.straight;
  }

  SaveKind _classifySave(Offset landing) {
    final n = _normalizedInGoal(landing);
    final corner = n.dx < 0.32 || n.dx > 0.68;
    if (n.dy < 0.40) return SaveKind.fingerTip; // high / top-corner saves
    if (corner) return SaveKind.diving; // wide saves, esp. low
    return SaveKind.straight; // central, straight at the keeper
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Components use layout from onLoad; full relayout on resize is a later step.
  }

  void _onMatchState(MatchState state) {
    if (state.phase == MatchPhase.runUp) {
      _applyShotType(state.shotType);
    }
  }

  void _applyShotType(ShotType shotType) {
    final isPenalty = shotType == ShotType.penalty;
    final scale = isPenalty ? 1.0 : LayoutConstants.freeKickVisualScale;
    final spawnY = isPenalty
        ? _layout.height * LayoutConstants.ballSpawnYFraction
        : _layout.height * LayoutConstants.freeKickBallSpawnYFraction;
    final crowdZoom =
        isPenalty ? LayoutConstants.penaltyCrowdZoom : 1.0;

    _goal.applyVisualScale(scale);
    _goalkeeper.visualScale = scale;
    _sky.crowdZoom = crowdZoom;
    _pitch.shotType = shotType;
    _pitch.ballSpawnY = spawnY;
    _pitch.goalBottomY = _goal.visualBottomY;
    _pitch.visualScale = scale;
    _ball.resetToSpawn(Vector2(
      _layout.width * LayoutConstants.ballSpawnXFraction,
      spawnY,
    ));
    // Free kicks are tougher: rare chance the shot misses just outside the
    // post / over the bar. Penalties always stay on target.
    _ball.missProbability = isPenalty ? 0.0 : 0.15;
  }

  @override
  void onRemove() {
    _kickSubscription?.cancel();
    _matchSubscription?.cancel();
    _goalController.close();
    super.onRemove();
  }
}
