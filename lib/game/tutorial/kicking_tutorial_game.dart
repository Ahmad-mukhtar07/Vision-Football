import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import '../../models/kick_event.dart';
import '../../ui/game_play_sound.dart';
import '../components/ball_component.dart';
import '../components/goal_component.dart';
import '../components/scene_background_component.dart';
import '../goalkeeper_component.dart';
import '../layout_constants.dart';
import '../match_state.dart';

/// Which half of the goal mouth is the valid (green) target.
enum GoalHalf { left, right }

/// Minimal shooting scene for the kicking tutorial: sky + pitch + an empty
/// goal split into a green (valid) and red (invalid) half. No keeper, no
/// crowd — the ball simply flies where the player aims and the game reports
/// whether it landed in the goal and on the green side.
class KickingTutorialGame extends FlameGame {
  KickingTutorialGame({
    required this.onShotResolved,
    this.onBallBecameIdle,
    GoalHalf greenHalf = GoalHalf.left,
  }) : _greenHalf = greenHalf;

  /// Reports the outcome of a struck shot. [inGoal] is whether the ball
  /// crossed into the goal mouth; [inGreen] is whether that was the green half.
  final void Function({required bool inGoal, required bool inGreen})
      onShotResolved;

  /// Called when the ball has fully reset to the spawn spot (ready again).
  final VoidCallback? onBallBecameIdle;

  GoalHalf _greenHalf;

  set greenHalf(GoalHalf half) {
    _greenHalf = half;
    if (isLoaded) _halfOverlay.greenHalf = half;
  }

  GoalHalf get greenHalf => _greenHalf;

  late GameLayout _layout;
  late final SkyBackgroundComponent _sky;
  late final PitchBackgroundComponent _pitch;
  late final GoalComponent _goal;
  late final GoalkeeperComponent _goalkeeper;
  late final BallComponent _ball;
  late final _GoalHalfOverlay _halfOverlay;

  bool get canAcceptKick => isLoaded && _ball.isReadyForKick;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _layout = GameLayout(size);
    _sky = SkyBackgroundComponent(layout: _layout);
    _pitch = PitchBackgroundComponent(layout: _layout);
    _goal = GoalComponent(layout: _layout);
    // Constructed so the ball has a valid reference, but never added to the
    // tree and never told to react — so it neither renders nor saves.
    _goalkeeper = GoalkeeperComponent(layout: _layout);
    _ball = BallComponent(
      goal: _goal,
      goalkeeper: _goalkeeper,
      layout: _layout,
      onFlightEnd: _onFlightEnd,
      onBecameIdle: () => onBallBecameIdle?.call(),
    );
    _halfOverlay = _GoalHalfOverlay(goal: _goal, greenHalf: _greenHalf);

    await add(_sky);
    await add(_pitch);
    await add(_goal);
    await add(_ball);
    await add(_halfOverlay);

    _configurePenaltyScene();
  }

  void _configurePenaltyScene() {
    final spawnY = _layout.height * LayoutConstants.ballSpawnYFraction;
    _goal.applyVisualScale(1.0);
    _sky.crowdZoom = LayoutConstants.penaltyCrowdZoom;
    _pitch.shotType = ShotType.penalty;
    _pitch.ballSpawnY = spawnY;
    _pitch.goalBottomY = _goal.visualBottomY;
    _pitch.visualScale = 1.0;
    _ball.resetToSpawn(Vector2(
      _layout.width * LayoutConstants.ballSpawnXFraction,
      spawnY,
    ));
    _ball.missProbability = 0;
  }

  /// Strikes the ball for [event] if it is idle. Returns true if accepted.
  bool handleKick(KickEvent event) {
    if (!isLoaded || !_ball.isReadyForKick) return false;
    GamePlaySound.playBallKick();
    _ball.strike(event);
    return true;
  }

  void _onFlightEnd({
    required bool isGoal,
    required bool isSave,
    required KickEvent kick,
    required Offset landingPosition,
  }) {
    final goalRect = _goal.effectiveGoalRect;
    final landedHalf =
        landingPosition.dx < goalRect.center.dx ? GoalHalf.left : GoalHalf.right;
    final inGreen = isGoal && landedHalf == _greenHalf;

    if (inGreen) {
      GamePlaySound.playGoalDing();
      _goal.flashColor(
        Colors.greenAccent,
        const Duration(milliseconds: 300),
        particleOrigin: landingPosition,
      );
    }

    // Brief hold so the result reads before the ball resets to the spot.
    _ball.holdResultFor(1.1);
    onShotResolved(inGoal: isGoal, inGreen: inGreen);
  }
}

/// Translucent red / green halves drawn across the goal mouth.
class _GoalHalfOverlay extends PositionComponent {
  _GoalHalfOverlay({required this.goal, required GoalHalf greenHalf})
      : _greenHalf = greenHalf,
        super(priority: 5);

  final GoalComponent goal;
  GoalHalf _greenHalf;

  set greenHalf(GoalHalf half) => _greenHalf = half;

  @override
  void render(Canvas canvas) {
    final r = goal.effectiveGoalRect;
    final mid = r.center.dx;
    final leftRect = Rect.fromLTRB(r.left, r.top, mid, r.bottom);
    final rightRect = Rect.fromLTRB(mid, r.top, r.right, r.bottom);

    final greenRect = _greenHalf == GoalHalf.left ? leftRect : rightRect;
    final redRect = _greenHalf == GoalHalf.left ? rightRect : leftRect;

    canvas.drawRect(
      greenRect,
      Paint()..color = const Color(0xFF1FE07A).withValues(alpha: 0.32),
    );
    canvas.drawRect(
      redRect,
      Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: 0.32),
    );

    // Center divider line.
    canvas.drawLine(
      Offset(mid, r.top),
      Offset(mid, r.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );
  }
}
