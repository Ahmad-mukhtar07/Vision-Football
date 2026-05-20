import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/goal_event.dart';
import '../models/kick_event.dart';
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
  }) : _kickStream = kickStream;

  final Stream<KickEvent> _kickStream;
  final MatchController matchController;

  final StreamController<GoalEvent> _goalController =
      StreamController<GoalEvent>.broadcast();

  Stream<GoalEvent> get goalEvents => _goalController.stream;

  bool get canAcceptKick => _ball.isReadyForKick;

  late GameLayout _layout;
  late final GoalComponent _goal;
  late final GoalkeeperComponent _goalkeeper;
  late final BallComponent _ball;
  StreamSubscription<KickEvent>? _kickSubscription;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _layout = GameLayout(size);
    final sky = SkyBackgroundComponent(layout: _layout);
    final pitch = PitchBackgroundComponent(layout: _layout);
    _goal = GoalComponent(layout: _layout);
    _goalkeeper = GoalkeeperComponent(layout: _layout);
    _ball = BallComponent(
      goal: _goal,
      goalkeeper: _goalkeeper,
      layout: _layout,
      onFlightEnd: _onFlightEnd,
      onBecameIdle: () {},
    );

    await add(sky);
    await add(pitch);
    await add(_goal);
    await add(_goalkeeper);
    await add(_ball);

    _kickSubscription = _kickStream.listen(_onKick);
  }

  void _onKick(KickEvent event) {
    if (!_ball.isReadyForKick) {
      debugPrint('[KD] strike ignored (ball busy)');
      return;
    }
    debugPrint('[KD] >>> BALL SHOT <<<');
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

    matchController.kickTaken(result);

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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Components use layout from onLoad; full relayout on resize is a later step.
  }

  @override
  void onRemove() {
    _kickSubscription?.cancel();
    _goalController.close();
    super.onRemove();
  }
}
