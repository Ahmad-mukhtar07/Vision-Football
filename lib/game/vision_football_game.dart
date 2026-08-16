import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/game_settings.dart';
import '../models/goal_event.dart';
import '../models/kick_event.dart';
import '../models/team.dart';
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
    this.userTeam,
    this.opponentKeeper,
    this.rollingBallsMode = false,
    this.captureRollingKick,
  }) : _kickStream = kickStream;

  final Stream<KickEvent> _kickStream;
  final MatchController matchController;
  final VoidCallback? onBallBecameIdle;

  /// User's team — the shooter taking each kick is read from its line-up so
  /// power/accuracy/curve scale the ball. Null in standalone/neutral play.
  final Team? userTeam;

  /// Opposing keeper whose reflex/prediction stats drive the AI keeper.
  final GoalkeeperRating? opponentKeeper;

  /// Rolls the ball in from the keeper before each kick instead of placing it
  /// on the marker.
  final bool rollingBallsMode;

  /// Reads the player's leg motion at the instant the rolling ball reaches the
  /// pass circle. Null means the leg wasn't moving — no shot is taken.
  final KickEvent? Function()? captureRollingKick;

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
    _goalkeeper =
        GoalkeeperComponent(layout: _layout, keeperRating: opponentKeeper);
    _ball = BallComponent(
      goal: _goal,
      goalkeeper: _goalkeeper,
      layout: _layout,
      onFlightEnd: _onFlightEnd,
      onBecameIdle: onBallBecameIdle,
      onRollingTimedOut: rollingBallsMode ? _onRollingTimedOut : null,
      onReachedPassCircle:
          rollingBallsMode ? _onRollingBallReachedCircle : null,
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
    // Rolling balls are struck only from the leg snapshot taken when the ball
    // reaches the circle, never from a detected thrust.
    if (rollingBallsMode) return;
    if (!_ball.isReadyForKick) {
      debugPrint('[KD] strike ignored (ball busy)');
      return;
    }
    debugPrint('[KD] >>> BALL SHOT <<<');
    _launchShot(event);
  }

  /// The rolling ball's centre is on the circle right now: whatever the leg is
  /// doing at this instant becomes the shot.
  void _onRollingBallReachedCircle() {
    final event = captureRollingKick?.call();
    if (event == null) {
      debugPrint('[KD] rolling ball passed the circle untouched');
      return;
    }
    debugPrint('[KD] >>> ROLLING BALL SHOT <<<');
    _launchShot(event);
  }

  void _launchShot(KickEvent event) {
    GamePlaySound.playBallKick();
    matchController.onBallInFlight();
    _ball.strike(event, shooter: _currentShooter());
    _goalkeeper.reactToKick(event, ballTarget: _ball.resolvedTargetScreen);
  }

  /// The shooter taking the current kick (by line-up order). The same index
  /// logic used by the on-screen player labels: kicks already completed maps
  /// to the next taker.
  Player? _currentShooter() {
    final team = userTeam;
    if (team == null || team.shooters.isEmpty) return null;
    final index =
        matchController.state.kicksTaken.clamp(0, team.shooters.length - 1);
    return team.shooters[index];
  }

  void _onFlightEnd({
    required bool isGoal,
    required bool isSave,
    required bool hitCrossbar,
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
      if (hitCrossbar) {
        // Lead with the woodwork thud and duck the crowd's groan so it's clear.
        GamePlaySound.playCrossbar();
        GamePlaySound.playBoo(volume: 0.35);
        commentary = CommentarySound.playMissCrossbar();
      } else {
        GamePlaySound.playBoo();
        commentary = CommentarySound.playMiss();
      }
    }

    // Small tail so the ball/banner doesn't vanish the instant audio ends.
    final hold = commentary + const Duration(milliseconds: 500);
    _ball.holdResultFor(hold.inMilliseconds / 1000.0);
    matchController.kickTaken(
      result,
      holdFor: hold,
      goalScorer: isGoal ? _currentShooter()?.name : null,
    );

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
    } else if (rollingBallsMode && state.phase == MatchPhase.readyToKick) {
      _ball.beginRollFromKeeper();
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
    _ball.rollingBallsMode = rollingBallsMode;
    final spawn = Vector2(
      _layout.width * LayoutConstants.ballSpawnXFraction,
      spawnY,
    );
    if (rollingBallsMode) {
      _ball.prepareRollingAtKeeper(spawn, _keeperRollOrigin());
    } else {
      _ball.resetToSpawn(spawn);
    }
    // Free kicks are tougher: rare chance the shot misses just outside the
    // post / over the bar. Penalties always stay on target. Easy mode keeps
    // every shot on target regardless of type.
    final easy = GameSettings.isEasyMode;
    _ball.easyMode = easy;
    _ball.missProbability = (isPenalty || easy) ? 0.0 : 0.15;
    _ball.isPenalty = isPenalty;
  }

  Vector2 _keeperRollOrigin() {
    final goal = _goal.effectiveGoalRect;
    return Vector2(
      goal.center.dx,
      goal.bottom + _layout.height * 0.025,
    );
  }

  void _onRollingTimedOut() {
    GamePlaySound.playBoo();
    final commentary = CommentarySound.playMiss();
    final hold = commentary + const Duration(milliseconds: 500);
    matchController.onBallInFlight();
    matchController.kickTaken(KickResult.miss, holdFor: hold);
  }

  @override
  void onRemove() {
    _kickSubscription?.cancel();
    _matchSubscription?.cancel();
    _goalController.close();
    super.onRemove();
  }
}
