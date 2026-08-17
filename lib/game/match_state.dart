import 'dart:async';
import 'dart:math';

import '../data/game_settings.dart';
import '../ui/penalty_score_bar.dart';
import 'full_match_shootout.dart';
import 'shot_type_schedule.dart';

/// Whether the current kick is a penalty or a free kick.
enum ShotType { penalty, freeKick }

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
    this.penaltySpots = const [],
    this.goalScorers = const [],
  });

  final int totalKicks;
  final int kicksTaken;
  final int goalsScored;
  final int savesMade;
  final MatchPhase phase;
  final KickResult? lastResult;
  final ShotType shotType;
  final List<PenaltySpotStatus> penaltySpots;

  /// Names of players who scored, in kick order.
  final List<String> goalScorers;

  MatchState copyWith({
    int? totalKicks,
    int? kicksTaken,
    int? goalsScored,
    int? savesMade,
    MatchPhase? phase,
    KickResult? lastResult,
    bool clearLastResult = false,
    ShotType? shotType,
    List<PenaltySpotStatus>? penaltySpots,
    List<String>? goalScorers,
  }) {
    return MatchState(
      totalKicks: totalKicks ?? this.totalKicks,
      kicksTaken: kicksTaken ?? this.kicksTaken,
      goalsScored: goalsScored ?? this.goalsScored,
      savesMade: savesMade ?? this.savesMade,
      phase: phase ?? this.phase,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      shotType: shotType ?? this.shotType,
      penaltySpots: penaltySpots ?? this.penaltySpots,
      goalScorers: goalScorers ?? this.goalScorers,
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

  /// Extra hold before the FIRST kick can be readied, so the kick-off
  /// commentary can finish before the starting whistle. Set before
  /// [startMatch]; only affects the first shot of the match.
  Duration introHold = Duration.zero;
  DateTime? _introReadyAt;

  /// The pause currently in effect after a result. Defaults to
  /// [resultPauseDuration] but is overridden per-shot when commentary needs
  /// the screen held longer (see [kickTaken]).
  Duration _activeResultPause = const Duration(milliseconds: 1800);

  final StreamController<MatchState> _stateController =
      StreamController<MatchState>.broadcast();

  Stream<MatchState> get stateStream => _stateController.stream;
  MatchState get state => _state;

  MatchState _state = const MatchState();
  StreamSubscription<bool>? _playerIsStillSub;
  Timer? _phaseTimer;
  Timer? _runUpTimeoutTimer;

  /// Pre-generated kick sequence for the current match (index = kicksTaken).
  List<ShotType> _shotSchedule = [];

  /// When set for a Full Match second-half shooting segment, the half can end
  /// before all 5 kicks once the aggregate score is decided.
  FullMatchHalfConfig _fullMatchConfig = FullMatchHalfConfig.standalone;

  bool _isPaused = false;
  MatchPhase? _pausedPhase;
  bool get isPaused => _isPaused;

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

  void startMatch({FullMatchHalfConfig? fullMatchConfig}) {
    _fullMatchConfig = fullMatchConfig ?? FullMatchHalfConfig.standalone;
    _isPaused = false;
    _pausedPhase = null;
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    _introReadyAt =
        introHold > Duration.zero ? DateTime.now().add(introHold) : null;
    const totalKicks = 5;
    _shotSchedule = ShotTypeSchedule.forShooting(
      mode: GameSettings.difficulty,
      totalKicks: totalKicks,
      random: _random,
    );
    _state = MatchState(
      totalKicks: totalKicks,
      phase: MatchPhase.runUp,
      kicksTaken: 0,
      goalsScored: 0,
      savesMade: 0,
      penaltySpots: PenaltyScoreBar.initialSpots(totalKicks),
    );
    _emit();
    _enterRunUp();
  }

  void restartMatch() {
    startMatch();
  }

  /// Freezes phase timers and disarms kick detection until [resumeMatch].
  void pauseMatch() {
    if (_isPaused) return;
    if (_state.phase == MatchPhase.matchOver ||
        _state.phase == MatchPhase.notStarted) {
      return;
    }
    _isPaused = true;
    _pausedPhase = _state.phase;
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);
  }

  /// Restores timers and kick arming for the phase that was active at pause.
  void resumeMatch() {
    if (!_isPaused) return;
    final phase = _pausedPhase ?? _state.phase;
    _isPaused = false;
    _pausedPhase = null;

    switch (phase) {
      case MatchPhase.runUp:
        _runUpTimeoutTimer = Timer(runUpTimeout, () {
          if (!_isPaused && _state.phase == MatchPhase.runUp) {
            playerInPosition();
          }
        });
      case MatchPhase.readyToKick:
        onArmKickDetection?.call();
        onBallKickGate?.call(true);
      case MatchPhase.resultPause:
        final kicksAtPause = _state.kicksTaken;
        _phaseTimer = Timer(_activeResultPause, () {
          if (_isPaused) return;
          _advanceAfterResultPause(kicksAtPause);
        });
      case MatchPhase.ballInFlight:
        // Ball may still be in the air; kick detection stays off until landing.
        onBallKickGate?.call(false);
      case MatchPhase.matchOver:
      case MatchPhase.notStarted:
        break;
    }
  }

  /// Ends the current match and resets to [MatchPhase.notStarted].
  void abandonMatch() {
    _isPaused = false;
    _pausedPhase = null;
    _phaseTimer?.cancel();
    _runUpTimeoutTimer?.cancel();
    _state = const MatchState(phase: MatchPhase.notStarted);
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);
  }

  void playerInPosition() {
    if (_isPaused) return;
    if (_state.phase != MatchPhase.runUp) return;
    // Hold the first ready/whistle until the kick-off commentary finishes.
    final introRemaining = _introRemaining();
    if (introRemaining > Duration.zero) {
      _runUpTimeoutTimer?.cancel();
      _phaseTimer?.cancel();
      _phaseTimer = Timer(introRemaining, () {
        if (_isPaused || _state.phase != MatchPhase.runUp) return;
        _enterReadyToKick();
      });
      return;
    }
    _runUpTimeoutTimer?.cancel();
    _enterReadyToKick();
  }

  /// Remaining kick-off commentary hold (only for the first shot).
  Duration _introRemaining() {
    final readyAt = _introReadyAt;
    if (readyAt == null || _state.kicksTaken > 0) return Duration.zero;
    final remaining = readyAt.difference(DateTime.now());
    return remaining > Duration.zero ? remaining : Duration.zero;
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

  void kickTaken(KickResult result, {Duration? holdFor, String? goalScorer}) {
    if (_state.phase != MatchPhase.ballInFlight) return;

    final kicksTaken = _state.kicksTaken + 1;
    var goals = _state.goalsScored;
    var saves = _state.savesMade;
    var scorers = List<String>.from(_state.goalScorers);
    switch (result) {
      case KickResult.goal:
        goals++;
        if (goalScorer != null && goalScorer.isNotEmpty) {
          scorers.add(goalScorer);
        }
      case KickResult.saved:
        saves++;
      case KickResult.miss:
        break;
    }

    final spots = List<PenaltySpotStatus>.from(_state.penaltySpots);
    spots[kicksTaken - 1] = result == KickResult.goal
        ? PenaltySpotStatus.scored
        : PenaltySpotStatus.missed;

    _state = _state.copyWith(
      kicksTaken: kicksTaken,
      goalsScored: goals,
      savesMade: saves,
      goalScorers: scorers,
      phase: MatchPhase.resultPause,
      lastResult: result,
      penaltySpots: spots,
    );
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);

    // Hold the result (ball in the goal / keeper's hands) at least as long as
    // the commentary line, so we never cut to the next run-up mid-sentence.
    _activeResultPause = (holdFor != null && holdFor > resultPauseDuration)
        ? holdFor
        : resultPauseDuration;

    _phaseTimer?.cancel();
    _phaseTimer = Timer(_activeResultPause, () {
      if (_isPaused) return;
      _advanceAfterResultPause(kicksTaken);
    });
  }

  void _advanceAfterResultPause(int kicksTaken) {
    if (_fullMatchConfig.isSecondHalf) {
      final remaining = _state.totalKicks - kicksTaken;
      final decided = fullMatchShootoutDecided(
        userScore: _state.goalsScored,
        opponentScore: _fullMatchConfig.opponentScoreFromOtherHalf ?? 0,
        userRemainingKicks: remaining,
        opponentRemainingKicks: 0,
      );
      if (decided != null) {
        _endMatch();
        return;
      }
    }
    if (kicksTaken >= _state.totalKicks) {
      _endMatch();
      return;
    }
    _enterRunUp();
  }

  void _endMatch() {
    _state = _state.copyWith(phase: MatchPhase.matchOver);
    _emit();
    onDisarmKickDetection?.call();
  }

  void _onPlayerStill(bool still) {
    if (_isPaused) return;
    if (_state.phase == MatchPhase.runUp && still) {
      playerInPosition();
    }
  }

  void _enterRunUp() {
    _phaseTimer?.cancel();
    final idx = _state.kicksTaken.clamp(0, _shotSchedule.length - 1);
    final nextShot = _shotSchedule.isNotEmpty
        ? _shotSchedule[idx]
        : ShotType.penalty;
    _state = _state.copyWith(
      phase: MatchPhase.runUp,
      clearLastResult: true,
      shotType: nextShot,
    );
    _emit();
    onDisarmKickDetection?.call();
    onBallKickGate?.call(false);

    _runUpTimeoutTimer?.cancel();
    _runUpTimeoutTimer = Timer(runUpTimeout, () {
      if (!_isPaused && _state.phase == MatchPhase.runUp) {
        playerInPosition();
      }
    });
  }

  void _enterReadyToKick() {
    if (_isPaused) return;
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
