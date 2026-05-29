import 'dart:async';
import 'dart:math';

/// Whether the current kick is a penalty or a free kick.
enum ShotType { penalty, freeKick }

/// Ball delivery style selected by the player at game start.
enum BallMode {
  /// Ball sits stationary at the spawn point (classic penalty/free kick).
  fixed,

  /// Ball rolls toward the player; kick happens when it reaches them.
  rolling,
}

/// Outcome of a single penalty kick.
enum KickResult {
  goal,
  miss,
  saved,
}

/// Lifecycle of a penalty shoot-out.
enum MatchPhase {
  notStarted,
  runUp,
  readyToKick,
  ballInFlight,
  resultPause,
  matchOver,
}

/// Immutable snapshot of match progress for UI and game wiring.
class MatchState {
  const MatchState({
    this.totalKicks = 5,
    this.kicksTaken = 0,
    this.goalsScored = 0,
    this.savesMade = 0,
    this.phase = MatchPhase.notStarted,
    this.lastResult,
    this.shotType = ShotType.penalty,
    this.ballMode = BallMode.fixed,
  });

  final int totalKicks;
  final int kicksTaken;
  final int goalsScored;
  final int savesMade;
  final MatchPhase phase;
  final KickResult? lastResult;
  final ShotType shotType;
  final BallMode ballMode;

  MatchState copyWith({
    int? totalKicks,
    int? kicksTaken,
    int? goalsScored,
    int? savesMade,
    MatchPhase? phase,
    KickResult? lastResult,
    bool clearLastResult = false,
    ShotType? shotType,
    BallMode? ballMode,
  }) {
    return MatchState(
      totalKicks: totalKicks ?? this.totalKicks,
      kicksTaken: kicksTaken ?? this.kicksTaken,
      goalsScored: goalsScored ?? this.goalsScored,
      savesMade: savesMade ?? this.savesMade,
      phase: phase ?? this.phase,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      shotType: shotType ?? this.shotType,
      ballMode: ballMode ?? this.ballMode,
    );
  }
}

/// Owns match phases, run-up → kick → result loop, and kick-detector arming policy.
class MatchController {
  MatchController({
    required Stream<bool> playerIsStill,
    this.resultPauseDuration = const Duration(milliseconds: 1800),
    this.runUpTimeout = const Duration(seconds: 12),
    this.goDuration = const Duration(milliseconds: 600),
  }) : _playerIsStill = playerIsStill {
    _playerIsStillSub = _playerIsStill.listen(_onPlayerStill);
  }

  // TODO Step N: totalKicks configurable per game mode (sudden death, timed, etc.)
  // TODO Step N: gkPredictionAccuracy increases each match in career mode
  // TODO Step N: runUp phase will trigger player avatar run-up animation
  // TODO Step N: KickType (panenka, rabona) detected during readyToKick phase only

  final Stream<bool> _playerIsStill;
  final Duration resultPauseDuration;
  final Duration runUpTimeout;
  final Duration goDuration;
  final Random _random = Random();

  final StreamController<MatchState> _stateController =
      StreamController<MatchState>.broadcast();

  Stream<MatchState> get stateStream => _stateController.stream;
  MatchState get state => _state;

  MatchState _state = const MatchState();
  StreamSubscription<bool>? _playerIsStillSub;
  Timer? _phaseTimer;
  Timer? _runUpTimeoutTimer;

  /// Only [VisionFootballGame] should call these — no other file arms detection.
  void Function()? onArmKickDetection;
  void Function()? onDisarmKickDetection;
  void Function(bool ready)? onBallKickGate;

  void dispose() {
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    _playerIsStillSub?.cancel();
    _stateController.close();
  }

  BallMode _ballMode = BallMode.fixed;

  void startMatch({BallMode ballMode = BallMode.fixed}) {
    _ballMode = ballMode;
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    _state = MatchState(
      phase: MatchPhase.runUp,
      kicksTaken: 0,
      goalsScored: 0,
      savesMade: 0,
      ballMode: ballMode,
    );
    _emit();
    _enterRunUp();
  }

  void restartMatch() {
    startMatch(ballMode: _ballMode);
  }

  void playerInPosition() {
    if (_state.phase != MatchPhase.runUp) return;
    _runUpTimeoutTimer?.cancel();
    _enterReadyToKick();
  }

  void onBallInFlight() {
    if (_state.phase != MatchPhase.readyToKick &&
        _state.phase != MatchPhase.ballInFlight) {
      return;
    }
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    _state = _state.copyWith(phase: MatchPhase.ballInFlight);
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);
  }

  void kickTaken(KickResult result) {
    if (_state.phase != MatchPhase.ballInFlight) return;

    final kicksTaken = _state.kicksTaken + 1;
    var goals = _state.goalsScored;
    var saves = _state.savesMade;
    switch (result) {
      case KickResult.goal:
        goals++;
      case KickResult.saved:
        saves++;
      case KickResult.miss:
        break;
    }

    _state = _state.copyWith(
      kicksTaken: kicksTaken,
      goalsScored: goals,
      savesMade: saves,
      phase: MatchPhase.resultPause,
      lastResult: result,
    );
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);

    _phaseTimer?.cancel();
    _phaseTimer = Timer(resultPauseDuration, () {
      if (kicksTaken >= _state.totalKicks) {
        _state = _state.copyWith(phase: MatchPhase.matchOver);
        _emit();
        onDisarmKickDetection?.call();
        return;
      }
      _enterRunUp();
    });
  }

  void _onPlayerStill(bool still) {
    if (_state.phase == MatchPhase.runUp && still) {
      playerInPosition();
    }
  }

  void _enterRunUp() {
    _phaseTimer?.cancel();
    final nextShot = _random.nextBool() ? ShotType.penalty : ShotType.freeKick;
    _state = _state.copyWith(
      phase: MatchPhase.runUp,
      clearLastResult: true,
      shotType: nextShot,
      ballMode: _ballMode,
    );
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);

    _runUpTimeoutTimer?.cancel();
    _runUpTimeoutTimer = Timer(runUpTimeout, () {
      if (_state.phase == MatchPhase.runUp) {
        playerInPosition();
      }
    });
  }

  void _enterReadyToKick() {
    _runUpTimeoutTimer?.cancel();
    _state = _state.copyWith(phase: MatchPhase.readyToKick);
    _emit();
    onArmKickDetection?.call();
    onBallKickGate?.call(true);

    _phaseTimer?.cancel();
    _phaseTimer = Timer(goDuration, () {
      // Stay in readyToKick until kick; GO banner handled by HUD.
    });
  }

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
